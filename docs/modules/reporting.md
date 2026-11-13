# reporting

- **Status:** Draft
- **Owner:** VoltReckon maintainer
- **Last verified:** 2026-11-13
- **Applies to phases:** 9-10

`reporting` serves read-only operational and financial reports from `rpt_*` views and the public
query APIs of the domain modules. It is a sink: no module depends on it, and it never writes a
domain row. Rules are `RPT-001`-`RPT-010`; the report list and access rules are owned by
[08-api-standards.md](../08-api-standards.md) and [09-security.md](../09-security.md).

## Purpose

Give finance, operations, and audit one consistent read model without letting reporting become
a hidden write path or a second source of business rules.

## Scope

In scope: CDR intake summary, rating variance, invoice register, exception ageing, settlement
register, audit package manifest, and the views that support them. Out of scope: editing data,
issuing documents, posting journals, and ad-hoc SQL from a caller.

## Public API

- `CdrSummaryQuery` by partner pair and period.
- `RatingVarianceQuery` by partner and period.
- `InvoiceRegisterQuery` by issuer, recipient, status, and period.
- `ExceptionAgeingQuery` by partner pair and as-of date.
- `SettlementRegisterQuery` by partner pair and period.
- `AuditPackageQuery` for a structured export manifest.
- `ReportQuery` metadata for available reports.

Every query returns a bounded page and requires a partner scope or an audited platform target.

## Domain model

There is no reporting aggregate. Query results are immutable read records with a report code,
period, partner reference, counts, money totals, and an `asOf` instant. The `rpt_*` views are
owned by `reporting`; they are the only allowed direct read of domain tables (`ARCH-014`).

## Owned data

`rpt_*` read-only views in V016. The views are rebuilt by migration, not by application DML.
`reporting` owns no base table and MUST NOT create a materialized write table in T1.

## Invariants

**RPT-001** `reporting` MUST NOT write, update, or delete a domain row. *Check:* role grants and
write-review.

**RPT-002** A report query MUST be scoped to one partner pair or an audited platform target; a
client-supplied partner MUST NOT override the token scope. *Check:* isolation IT.

**RPT-003** A report MUST use the stored financial values, not recompute them; a variance report
reads rating variance, not a fresh rating. *Check:* report golden test.

**RPT-004** A report MUST state its `asOf` instant and period; a date range MUST be bounded by
the configured maximum. *Check:* contract test.

**RPT-005** A report MUST use the same currency per row and MUST NOT sum across currencies.
*Check:* multi-currency IT.

**RPT-006** A reporting query MUST NOT expose tokens, GSTINs beyond the minimum, free-text
dispute notes, or raw payloads. *Check:* payload review.

**RPT-007** `rpt_*` views MUST be read-only and MUST NOT be used by a write path. *Check:*
migration review and ArchUnit/package review.

**RPT-008** A report query MUST be reproducible for a fixed period and `asOf`; a change to a
view requires a migration and a golden update. *Check:* reproducibility IT.

**RPT-009** A large export MUST be streamed or paged and MUST NOT load an unbounded result into
memory. *Check:* export IT.

**RPT-010** `reporting` MUST NOT be imported by a domain module. *Check:* ArchUnit sink rule.

## Transactions

Reports are read-only and use a read-committed snapshot per page. `asOf` is captured once per
request; a multi-page export continues from the same snapshot token or states the consistency
boundary. An audit-package export reads audit through its public query and the domain views
under the same `asOf`; it never writes a manifest table.

## Events

`reporting` produces no event. It may consume catalog events only to invalidate a cache; a cache
MUST NOT be required for correctness. The current implementation reads views directly and does
not need an event consumer for the Phase 9 reports.

## Dependencies

`shared`, `platform`, the public query APIs of every domain module, and `audit`. It MUST NOT
import another module's `internal` package, and no domain module may depend on `reporting`
(`ARCH-007`).

## Configuration

| Key | Default | Purpose |
|---|---|---|
| `voltreckon.reporting.max-range-days` | `366` | Query bound |
| `voltreckon.reporting.page-size` | `50` | Default page |
| `voltreckon.reporting.max-page-size` | `200` | Hard cap |
| `voltreckon.reporting.cache-ttl` | `PT0S` | Disabled by default |
| `voltreckon.reporting.export-max-bytes` | `52428800` | Export guardrail |

## Errors

| Code | Status | Meaning |
|---|---|---|
| `REPORT_NOT_FOUND` | 404 | Unknown report code |
| `RANGE_TOO_LARGE` | 400 | Period exceeds the maximum |
| `INVALID_AS_OF` | 400 | `asOf` is missing or invalid |
| `CURRENCY_MISMATCH` | 422 | Query mixes currencies |
| `EXPORT_TOO_LARGE` | 413 | Export exceeds the guardrail |
| `REPORT_UNAVAILABLE` | 503 | A required view is unavailable |

## Security

`report.read` is required; a partner sees only its own rows, and a platform administrator must
name the target partner. The audit-package report additionally requires `audit.read`. Reports
are read-only; no role may use a report endpoint to change state. Sensitive fields follow
`SEC-009` and `SEC-039`.

## Observability

Metrics: queries by report, latency, range rejections, export size, cache hit rate, and view
errors. Logs carry report code, partner reference, `asOf`, and `traceId`; they never carry row
contents.

## Tests

| Test | Covers |
|---|---|
| `ReportScopeIT` | Cross-partner denial |
| `InvoiceRegisterIT` | Stored totals and statuses |
| `VarianceReportIT` | Rating variance without recomputation |
| `ExceptionAgeingIT` | As-of ageing buckets |
| `SettlementRegisterIT` | Completed runs and statements |
| `AuditPackageIT` | Manifest and `asOf` consistency |
| `ReportingSinkTest` | No write and no inbound dependency |

```gherkin
Scenario: Report row uses stored financial values
  Given an issued invoice and a later tariff change
  When the invoice register is read
  Then the issued total is unchanged
  And the register does not recompute tax

Scenario: Cross-partner report is denied
  Given a partner user in partner A
  When the report requests partner B
  Then the request fails with NOT_FOUND
  And no partner B row appears
```

## Phase plan

- Phase 9: V016, `rpt_*` views, six reports, scoping, export manifest.
- Phase 10: cache only if measured; no write model and no schema change without a migration.

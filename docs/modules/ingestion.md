# ingestion

- **Status:** Draft
- **Owner:** VoltReckon maintainer
- **Last verified:** 2026-11-13
- **Applies to phases:** 1-10

`ingestion` accepts OCPI and internal CDRs, validates them, deduplicates by partner and
external ID, records credit references, and quarantines invalid data without financial effect.
Rules are `ING-001`-`ING-012`; OCPI edition and field rules are owned by
[06-ocpi-integration.md](../06-ocpi-integration.md).

## Purpose

Turn an external charging record into one immutable, rated-ready CDR or one auditable
quarantine decision, while never guessing a tariff, agreement, or amount.

## Scope

In scope: OCPI 2.2.1 receiver, internal JSON and CSV intake, dimensions, validation issues,
duplicate handling, credit CDR resolution, and quarantine revalidation. Out of scope: tariff
selection, rating, invoices, journals, and settlement.

## Public API

- `IngestCdrCommand` for one internal or OCPI CDR.
- `ImportCdrCsvCommand` for a bounded CSV batch.
- `RevalidateCdrCommand` for a quarantined CDR.
- `CdrQuery` by ID, partner pair, time, or status.
- `ingestion.cdr.ingested.v1` and `ingestion.cdr.quarantined.v1` events.

The OCPI receiver is a separate adapter under `/ocpi/2.2.1`; it delegates to the same command.

## Domain model

`Cdr` is an immutable accepted record with a partner pair, external IDs, session and contract
references, location/EVSE/connector references, timestamps, totals, currency, tariff reference,
credit flag and reference, source, bounded raw payload, and ingest status. `Dimension` is a
measured quantity with a type, unit, and period. `ValidationIssue` records a code and severity.
A credit is a new CDR that points to an original; it never updates the original.

## Owned data

`cdr`, `cdr_dimension`, and `cdr_validation_issue` in V004. Accepted CDRs are immutable; a
quarantined CDR may move to `ACCEPTED` only through the revalidation command. Raw payload is
bounded `jsonb` and is never a financial source.

## Invariants

**ING-001** `(cpo_partner_id, emsp_partner_id, cdr_external_id)` MUST be unique; a replay with
the same payload hash MUST return the stored CDR. *Check:* unique index and replay IT.

**ING-002** A reused external CDR ID with a different payload hash MUST be rejected as
`DUPLICATE_CDR`, not overwritten. *Check:* duplicate-hash IT.

**ING-003** The sender partner MUST come from the authenticated client, never from a body
field. *Check:* cross-tenant ingest IT.

**ING-004** A non-credit CDR with negative cost, energy, or time MUST be quarantined. A credit
CDR MAY carry negative totals. *Check:* negative-value IT.

**ING-005** A credit CDR MUST have a new ID, `credit=true`, and a reference resolvable within
the same partner pair; self-reference and a second credit for the same original MUST be
rejected. *Check:* credit IT and partial unique index.

**ING-006** A credit's session, token, location, times, and currency MUST match the original
within the configured tolerance; a mismatch MUST be quarantined. *Check:* credit-mismatch IT.

**ING-007** An unknown dimension type or unit MUST NOT be coerced; it MUST produce
`UNSUPPORTED_UNIT` or `UNSUPPORTED_DIMENSION`. *Check:* dimension fixture test.

**ING-008** An accepted CDR MUST be immutable; a correction MUST be a new credit or a new CDR
with a new external ID. *Check:* trigger and correction IT.

**ING-009** A quarantined CDR MUST have no rating result and no financial row. *Check:*
quarantine isolation IT.

**ING-010** A raw payload MUST be at most 64 KiB and MUST NOT contain driver name, phone,
email, card data, or bank credentials. *Check:* size check and PII scan test.

**ING-011** The CDR, dimensions, issues, and outbox event MUST commit in one transaction.
*Check:* rollback IT.

**ING-012** Ingestion MUST NOT require an agreement or tariff; those failures belong to
rating and MUST appear as `MISSING_AGREEMENT` or `MISSING_TARIFF` there. *Check:* ingest
without tariff IT.

## Transactions

One ingest command writes the CDR, its dimensions, its validation issues, and the catalog
event in one transaction. A duplicate returns the stored row without a second event. A
quarantined row is stored with its issues and a `cdr.quarantined.v1` event; the financial path
is untouched. Revalidation locks the row, re-runs validation, and either moves it to
`ACCEPTED` with an `ingested` event or keeps it quarantined with a new issue.

## Events

Producers: `ingestion.cdr.ingested.v1` with CDR ID, partner ID, session ID, and external tariff
reference; `ingestion.cdr.quarantined.v1` with CDR ID and reason code. Consumers: `rating`
(ingested only), `audit`, and `reporting`. Credit CDRs publish `ingested` after validation.

## Dependencies

`shared`, `platform`, and `partners` only. `ingestion` MUST NOT depend on `tariff`, `rating`,
`billing`, `ledger`, `dispute`, `reconciliation`, `settlement`, `audit`, or `reporting`.

## Configuration

| Key | Default | Purpose |
|---|---|---|
| `voltreckon.ingestion.max-body` | `256KiB` | OCPI request limit |
| `voltreckon.ingestion.max-raw` | `64KiB` | Stored source payload limit |
| `voltreckon.ingestion.csv-max-rows` | `10000` | CSV guardrail |
| `voltreckon.ingestion.credit-time-tolerance` | `PT1M` | Credit match tolerance |
| `voltreckon.ingestion.duplicate-window` | `P30D` | Hash reuse check |

## Errors

| Code | Status | Meaning |
|---|---|---|
| `VALIDATION_FAILED` | 400 | Required field or type invalid |
| `DUPLICATE_CDR` | 409 | Same external ID, different payload |
| `PAYLOAD_TOO_LARGE` | 413 | Body or raw payload too large |
| `UNSUPPORTED_DIMENSION` | 422 | Dimension type unknown |
| `UNSUPPORTED_UNIT` | 422 | Unit cannot be converted |
| `UNKNOWN_CREDIT_REFERENCE` | 422 | Original not found |
| `DUPLICATE_CREDIT` | 409 | Original already credited |
| `CREDIT_REFERENCE_MISMATCH` | 422 | Credit differs from original |
| `CDR_IMMUTABLE` | 409 | Accepted CDR cannot change |
| `NOT_QUARANTINED` | 409 | Revalidation target is accepted |

## Security

A partner token identifies the sender and is scoped to that partner pair; `cdr.write` is
required for ingest and `cdr.read` for queries. Quarantine detail MUST NOT echo personal data.
Raw payload retention is 24 months and is access-controlled. Idempotency follows
[08-api-standards.md](../08-api-standards.md).

## Observability

Metrics: accepted/quarantined counts by reason, duplicate rate, credit rate, CSV rejects, and
ingest latency. Logs carry CDR ID and `partnerRef`, never token values or raw payloads.

## Tests

| Test | Covers |
|---|---|
| `OcpiCdrReceiverIT` | 2.2.1 envelope and field map |
| `CdrReplayIT` | Same hash returns stored row |
| `CdrDuplicateHashIT` | Different hash is rejected |
| `CreditCdrIT` | New row, reference, no mutation |
| `QuarantineIsolationIT` | No rating or financial row |
| `CsvImportIT` | Row limit and error report |

```gherkin
Scenario: Duplicate CDR is idempotent
  Given an accepted CDR for a partner pair
  When the same external CDR arrives with the same payload hash
  Then the stored CDR is returned
  And no second CDR row exists

Scenario: Second credit is quarantined
  Given an original CDR with one accepted credit
  When a second credit for the original arrives
  Then it is quarantined with DUPLICATE_CREDIT
  And the original and first credit are unchanged
```

## Phase plan

- Phase 1: V004, OCPI 2.2.1 receiver, internal JSON, dedupe, quarantine.
- Phase 2: CSV import and revalidation UI/API.
- Phase 10: OCPI 2.3.0 receiver; edition policy remains in 06.

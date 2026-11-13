# audit

- **Status:** Draft
- **Owner:** VoltReckon maintainer
- **Last verified:** 2026-11-13
- **Applies to phases:** 9-10

`audit` is an append-only record of security and financial actions, stored in a hash chain and
verifiable by sequence range. It is a sink: no module depends on it. Rules are
`AUD-001`-`AUD-010`; audit obligations are owned by [09-security.md](../09-security.md).

## Purpose

Make it possible to answer who did what, to which partner and entity, and when, and to detect a
tampered or missing record without trusting the application log.

## Scope

In scope: event intake, audit rows, hash chain, checkpoints, query, verification, and export
metadata. Out of scope: business state, authorization decisions, and log storage. Audit is not
a second copy of domain tables; it stores identifiers, actions, and hashes.

## Public API

- `AuditRecordQuery` by actor, partner, entity, action, and time range.
- `VerifyChainQuery` for a sequence range or checkpoint.
- `AuditExportQuery` for a structured package manifest.
- Event handlers for the catalog events in [03-architecture.md](../03-architecture.md).
- No command is exposed to create an audit row directly.

## Domain model

`AuditRecord` has a sequence, occurrence time, actor type and ID, opaque partner reference,
action, entity type and ID, correlation ID, before/after hashes, previous record hash, record
hash, and bounded detail. `Checkpoint` stores a sequence and its record hash. The first record
links to a fixed genesis hash.

## Owned data

`audit_log` and `audit_checkpoint` in V015. There is no foreign key to a domain table; partner
and entity references are opaque. The table has an append-only trigger; a checkpoint does not
allow a row to be changed.

## Invariants

**AUD-001** An audit row MUST be append-only; update and delete MUST be rejected. *Check:*
trigger and immutability IT.

**AUD-002** Every row MUST store `prev_hash` and `record_hash`; the record hash MUST cover the
canonical record fields and the previous hash. *Check:* hash-verification IT.

**AUD-003** A verification MUST detect a changed field, a deleted middle row, or a broken
previous-hash link. *Check:* tamper IT with three cases.

**AUD-004** A duplicate event delivery MUST NOT create a second audit row. *Check:*
`processed_event` and duplicate-delivery IT.

**AUD-005** An audit row MUST record actor type and ID, partner reference, action, entity type
and ID, occurrence time, and correlation ID. *Check:* schema and contract test.

**AUD-006** Audit detail MUST NOT contain tokens, card data, bank credentials, full GSTINs, or
free-text personal data. *Check:* payload review and redaction test.

**AUD-007** A checkpoint MUST cover a contiguous sequence and MUST be verifiable against the
stored chain. *Check:* checkpoint IT.

**AUD-008** `audit` MUST NOT write a domain table and MUST NOT be imported by a domain module.
*Check:* ArchUnit and dependency review.

**AUD-009** An audit query MUST be scoped to one partner or to an audited platform
administration action; a partner MUST NOT read another partner's records. *Check:*
cross-tenant IT.

**AUD-010** Retention MUST follow the configured legal policy; an expired row MUST NOT be
silently deleted while a checkpoint still references it. *Check:* retention review.

## Transactions

An event handler runs in its own transaction: it inserts `processed_event`, locks or reads the
latest audit sequence, computes the chain hash, inserts the audit row, and commits. A failed
handler retries with bounded backoff and does not block unrelated events. A verification is
read-only and uses checkpoints to avoid rescanning the full chain.

## Events

`audit` consumes every catalog event, including partner, tariff, ingestion, rating, billing,
reconciliation, dispute, settlement, and IAM events. It produces no event. Event payloads are
bounded and contain no personal data (`EVENT-009`); the audit row may add actor context from the
event envelope.

## Dependencies

`shared`, `platform`, and the **public event types** of every domain module. It MUST NOT import
another module's `internal` package, and no domain module may depend on `audit` (`ARCH-007`).

## Configuration

| Key | Default | Purpose |
|---|---|---|
| `voltreckon.audit.retention` | legal policy | Retention period |
| `voltreckon.audit.checkpoint-interval` | `10000` | Records per checkpoint |
| `voltreckon.audit.max-detail-bytes` | `8192` | Detail guardrail |
| `voltreckon.audit.verify-batch` | `1000` | Verification page size |

## Errors

| Code | Status | Meaning |
|---|---|---|
| `AUDIT_NOT_FOUND` | 404 | Scoped record does not exist |
| `CHAIN_BROKEN` | 409 | Verification found a broken link |
| `CHECKPOINT_MISMATCH` | 409 | Checkpoint does not match the chain |
| `RANGE_TOO_LARGE` | 400 | Verification range exceeds the limit |
| `AUDIT_IMMUTABLE` | 409 | Update or delete rejected |
| `EXPORT_NOT_READY` | 409 | Export is still being assembled |

## Security

`audit.read` is required; `AUDITOR` and `PLATFORM_ADMIN` may read, but a platform administrator
must name the target partner. Audit is not a secret store: it records that a field changed, not
the confidential value. The hash chain uses a keyed or unkeyed digest as configured; the key, if
used, comes from the environment and is never logged. Verification results are themselves
audited.

## Observability

Metrics: rows ingested, handler failures, duplicate events, chain verification time, broken-chain
alerts, checkpoint lag, and query latency. Logs carry audit sequence and `traceId`, never detail
payloads.

## Tests

| Test | Covers |
|---|---|
| `AuditAppendOnlyIT` | Update and delete rejected |
| `AuditChainIT` | Valid chain and three tamper cases |
| `AuditDuplicateIT` | Duplicate event is a no-op |
| `AuditCheckpointIT` | Contiguous checkpoint verification |
| `AuditIsolationIT` | Cross-partner denial |
| `AuditPayloadTest` | No forbidden personal data |

```gherkin
Scenario: Changed audit row is detected
  Given a verified audit chain
  When a stored detail field is changed directly in the database
  Then verification fails with CHAIN_BROKEN
  And the first mismatching sequence is reported

Scenario: Duplicate event is recorded once
  Given an audit event already processed
  When the same event ID is delivered again
  Then no second audit row is written
```

## Phase plan

- Phase 9: V015, event intake, hash chain, checkpoints, query, verification.
- Phase 10: export package and retention job; no schema change without a migration.

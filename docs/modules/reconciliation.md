# reconciliation

- **Status:** Draft
- **Owner:** VoltReckon maintainer
- **Last verified:** 2026-11-13
- **Applies to phases:** 6-10

`reconciliation` imports a partner statement, matches each line to a CDR, rating result, or
invoice line, and raises an exception when the evidence does not agree. Rules are
`RECN-001`-`RECN-011`; statement semantics and OCPI 2.3.0-ed2 are owned by
[06-ocpi-integration.md](../06-ocpi-integration.md).

## Purpose

Prove, line by line, that the partner's declared amount and our rated and invoiced amount
refer to the same session, and make every difference an owned, resolvable exception.

## Scope

In scope: statement import, matching, amount and currency comparison, duplicate detection,
exception lifecycle, and a reproducible run summary. Out of scope: editing an invoice, CDR, or
rating result; ledger posting; settlement; dispute workflow.

## Public API

- `StartReconciliationRunCommand` with partner pair, period, and statement file reference.
- `ResolveExceptionCommand` with resolution code, note, and actor.
- `ReconciliationRunQuery`, `ExceptionQuery`, and `ReconciliationItemQuery`.
- `reconciliation.exception.raised.v1` event.

The 2.3.0-ed2 invoice-reconciliation link is a Phase 10 adapter over the same run model, not a
new write path.

## Domain model

`ReconciliationRun` has a pair, partner invoice reference, source file name and hash, period,
status, counts, and timestamps. `Item` has a statement line reference, optional CDR and invoice
line links, declared and rated amounts, and a match status. `Exception` has a type, severity,
status (`OPEN`, `RESOLVED`, `WAIVED`), resolution code, note, actor, and time.

## Owned data

`reconciliation_run`, `reconciliation_item`, and `reconciliation_exception` in V012. V017 adds
the OCPI 2.3.0-ed2 invoice-reconciliation link. Runs and resolved exceptions are evidence and
are not deleted.

## Invariants

**RECN-001** A statement import MUST be idempotent by `(partner pair, source hash)`; a replay
MUST return the original run. *Check:* unique index and replay IT.

**RECN-002** A run MUST contain one item per statement line reference; a duplicate reference
MUST raise `DUPLICATE_LINE`. *Check:* unique index and duplicate IT.

**RECN-003** Matching MUST compare partner pair, currency, CDR or invoice identity, and amount;
a partial key match MUST NOT be accepted as `MATCHED`. *Check:* match-matrix IT.

**RECN-004** An amount difference MUST create `AMOUNT_MISMATCH`; a missing CDR or invoice line
MUST create `MISSING_CDR` or `MISSING_INVOICE_LINE`. *Check:* exception IT.

**RECN-005** A credit line MUST match a credit note or credit CDR; a credit against a positive
line MUST raise `CREDIT_MISMATCH`. *Check:* credit IT.

**RECN-006** A currency difference MUST raise `CURRENCY_MISMATCH`; no implicit conversion is
allowed in T1. *Check:* currency IT.

**RECN-007** Reconciliation MUST NOT update an invoice, CDR, rating result, journal, or
settlement row. *Check:* write-review and rollback IT.

**RECN-008** Resolving or waiving an exception MUST require a resolution code, note, actor, and
time; a resolved row without them MUST be rejected. *Check:* database check and resolution IT.

**RECN-009** A run and its items and exceptions MUST commit atomically with the raised-event
outbox row. *Check:* atomicity IT.

**RECN-010** A run result MUST be reproducible from the stored source hash, period, and partner
pair; the summary counts MUST equal the item and exception counts. *Check:* reproducibility IT.

**RECN-011** A run MUST stay inside one partner pair and one currency; a multi-currency
statement MUST be split or rejected. *Check:* scope IT.

## Transactions

Import writes the run, parses under a row limit, inserts items and exceptions, and writes the
event in one transaction. Matching reads CDR, rating, and invoice data through public queries;
it never writes those tables. Resolution locks the exception, validates the allowed transition,
and appends the resolution fields. A failed run stores `FAILED` with a safe error summary and no
partial items outside its transaction.

## Events

Producer: `reconciliation.exception.raised.v1` with exception ID, partner ID, and kind.
Consumers: `audit` and `reporting`. Settlement reads exceptions and invoice holds through
public queries; it does not consume this event for eligibility.

## Dependencies

`shared`, `platform`, `partners`, `ingestion`, `rating`, and `billing`. `reconciliation` MUST
NOT depend on `ledger`, `settlement`, `dispute`, `audit`, or `reporting`.

## Configuration

| Key | Default | Purpose |
|---|---|---|
| `voltreckon.reconciliation.max-lines` | `100000` | Per-file guardrail |
| `voltreckon.reconciliation.max-bytes` | `10MiB` | Statement size limit |
| `voltreckon.reconciliation.amount-tolerance-minor` | `0` | Exact match in T1 |
| `voltreckon.reconciliation.duplicate-window` | `P90D` | Hash reuse check |

## Errors

| Code | Status | Meaning |
|---|---|---|
| `RUN_NOT_FOUND` | 404 | Scoped run does not exist |
| `DUPLICATE_RUN` | 409 | Same source hash already imported |
| `DUPLICATE_LINE` | 409 | Statement line reference repeats |
| `INVALID_STATEMENT` | 422 | Header or row malformed |
| `FILE_TOO_LARGE` | 413 | Statement exceeds the limit |
| `EXCEPTION_NOT_FOUND` | 404 | Scoped exception does not exist |
| `INVALID_RESOLUTION` | 409 | Resolution state or code invalid |
| `CURRENCY_MISMATCH` | 422 | Statement currency differs |
| `CROSS_PAIR_MISMATCH` | 422 | Line belongs to another partner pair |

## Security

`reconciliation.run` starts and reads runs; `reconciliation.resolve` resolves or waives. A
partner sees only its own pair; a platform administrator must name the target partner. Statement
files are confidential and are referenced by hash/storage key, not stored in the database.
Resolution notes are free text and MUST be redacted from logs.

## Observability

Metrics: runs, matched lines, exception counts by type, resolution time, duplicate imports, and
parse failures. Logs carry run ID, exception ID, and `partnerRef`; no statement contents.

## Tests

| Test | Covers |
|---|---|
| `StatementReplayIT` | Source-hash idempotency |
| `MatchMatrixIT` | Matched, missing, mismatch, duplicate |
| `CreditReconciliationIT` | Credit line and credit mismatch |
| `ExceptionResolutionIT` | Required resolution fields |
| `ReconciliationIsolationIT` | Cross-pair denial |
| `ReconciliationEventIT` | Atomic event and row |

```gherkin
Scenario: Missing CDR becomes an exception
  Given a statement line with no matching CDR
  When reconciliation runs
  Then the item is MISSING_CDR
  And an OPEN exception is raised
  And no CDR is created

Scenario: Repeated statement is idempotent
  Given a completed run with a source hash
  When the same file is imported again
  Then the original run is returned
  And no second run or exception exists
```

## Phase plan

- Phase 6: V012, CSV import, matching, exceptions, resolution.
- Phase 7: dispute may reference an exception as an opaque subject.
- Phase 10: V017, OCPI 2.3.0-ed2 invoice reconciliation adapter.

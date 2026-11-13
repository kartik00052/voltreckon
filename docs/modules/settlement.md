# settlement

- **Status:** Draft
- **Owner:** VoltReckon maintainer
- **Last verified:** 2026-11-13
- **Applies to phases:** 8-10

`settlement` nets eligible invoices and credit notes for one partner pair, period, and
currency, records the obligations, posts the clearing journals, and issues an immutable
statement. Rules are `SETL-001`-`SETL-012`; netting arithmetic and sign convention are owned by
[05-financial-model.md](../05-financial-model.md).

## Purpose

Replace a stack of receivables and payables with one agreed net obligation per pair and period,
with a reproducible statement and balanced journals, without moving cash in T1.

## Scope

In scope: eligibility selection, net calculation, draft, lock, approval, completion, statement,
and clearing journals. Out of scope: reconciliation matching, dispute workflow, cash payment,
bank integration, and invoice editing.

## Public API

- `StartSettlementRunCommand` with partner pair, period, and currency.
- `LockSettlementRunCommand`, `ApproveSettlementRunCommand`, `CompleteSettlementRunCommand`.
- `SettlementRunQuery`, `SettlementStatementQuery`, and `SettlementItemQuery`.
- `settlement.settlement.completed.v1` event.

## Domain model

`SettlementRun` has a pair, period, currency, status (`DRAFT`, `LOCKED`, `COMPLETED`, `FAILED`),
net amount, actor, and timestamps. `SettlementItem` references a source journal line, a
direction (`PAYABLE`, `RECEIVABLE`), and a positive amount. `SettlementStatement` is immutable,
has a unique number, a canonical content hash, and an issue time.

## Owned data

`settlement_run`, `settlement_item`, and `settlement_statement` in V014. A completed run and its
statement are immutable; a superseding run is a new row. A settlement item references
`journal_line` but never mutates a prior journal.

## Invariants

**SETL-001** A run MUST cover exactly one partner pair, one period, and one currency; a
multi-currency or multi-pair request MUST be rejected. *Check:* validation test.

**SETL-002** Eligibility MUST include issued invoices and credit notes with an issue date on or
before the period end that are not fully settled and are not held. *Check:* eligibility matrix
IT.

**SETL-003** A held invoice MUST stay out of the net and MUST appear as a recorded exclusion;
settlement MUST read the hold through `billing`'s public query, not `dispute`. *Check:* hold
exclusion IT.

**SETL-004** The net amount MUST be signed from the CPO's perspective: positive means the eMSP
owes the CPO, negative means the CPO owes the eMSP. *Check:* sign-convention test.

**SETL-005** A run MUST follow `DRAFT -> LOCKED -> COMPLETED`; lock and approval MUST be by two
different users, each holding the required role. *Check:* maker-checker IT.

**SETL-006** Completion MUST write the settlement journals through `ledger`'s synchronous
command and the immutable statement in one transaction. *Check:* atomicity rollback IT.

**SETL-007** The statement hash MUST be reproducible from the canonical pair, period, currency,
items, and net amount. *Check:* hash stability test.

**SETL-008** A completed run MUST be unique per pair, period, and currency. *Check:* partial
unique index and concurrency IT.

**SETL-009** One source journal line MUST appear in at most one settlement item across all runs.
*Check:* unique index and double-settle IT.

**SETL-010** A completed run MUST NOT move cash or create a bank balance; it records the net
obligation and clearing entries only. *Check:* chart and API review.

**SETL-011** A failed run MUST be retained with a safe error summary; the retry is a new run.
*Check:* failure IT.

**SETL-012** Settlement MUST NOT depend on `dispute`; the invoice hold is billing-owned and is
the only dispute-related input. *Check:* ArchUnit and dependency review.

## Transactions

Start creates a `DRAFT` run, selects eligible documents, builds items, and stores a canonical
snapshot. Lock freezes the item set. Approval records a second actor and verifies maker-checker.
Completion posts the clearing journal for the CPO and the mirror for the eMSP through `ledger`,
writes the statement, and changes status in one transaction. A repeat completion fails the unique
index and returns `SETTLEMENT_ALREADY_COMPLETED`.

## Events

Producer: `settlement.settlement.completed.v1` with run ID, partner pair, period, currency, net
amount, and statement hash. Consumers: `audit` and `reporting`. The event is a notification; the
journals are already committed.

## Dependencies

`shared`, `platform`, `partners`, `billing`, `ledger`, and `reconciliation`. `settlement` MUST
NOT depend on `dispute`, `ingestion`, `rating`, `audit`, or `reporting`. Reconciliation is read
only to annotate the statement; unresolved exceptions do not silently change the net.

## Configuration

| Key | Default | Purpose |
|---|---|---|
| `voltreckon.settlement.max-items` | `100000` | Per-run guardrail |
| `voltreckon.settlement.require-second-approver` | `true` | Maker-checker |
| `voltreckon.settlement.statement-prefix` | `STL` | Statement number |
| `voltreckon.settlement.period-zone` | `Asia/Kolkata` | Period boundary |

## Errors

| Code | Status | Meaning |
|---|---|---|
| `RUN_NOT_FOUND` | 404 | Scoped run does not exist |
| `INVALID_STATE` | 409 | Run is not in the required state |
| `APPROVER_REQUIRED` | 409 | Second user approval missing |
| `SAME_APPROVER` | 409 | Maker and approver are the same user |
| `CURRENCY_MISMATCH` | 422 | Documents use another currency |
| `HELD_DOCUMENT` | 422 | Document is held by billing |
| `ALREADY_SETTLED` | 409 | Journal line is already in a settlement |
| `SETTLEMENT_ALREADY_COMPLETED` | 409 | Pair/period/currency already completed |
| `PERIOD_CLOSED` | 409 | Ledger period rejects the posting |
| `STATEMENT_HASH_MISMATCH` | 500 | Stored statement cannot be reproduced |

## Security

`settlement.run` starts, reads, and locks a run; `settlement.approve` approves; completion
requires the approver and a finance role. Maker and approver MUST differ (`SEC-010`). A partner
sees only its own pair. Statement contents are confidential; logs carry run ID, pair reference,
and hash, not item amounts. Every completion is audited.

## Observability

Metrics: runs by state, net amount by pair, held exclusions, approval latency, completion
failures, and statement-verification failures. Logs carry run ID and `partnerRef`; no full
statement payloads.

## Tests

| Test | Covers |
|---|---|
| `NettingEligibilityIT` | Issued, unsettled, unheld documents |
| `NettingSignTest` | CPO perspective and credit subtraction |
| `SettlementHoldIT` | Held invoice excluded and recorded |
| `MakerCheckerIT` | Lock and approve by different users |
| `SettlementAtomicityIT` | Journals and statement commit together |
| `SettlementUniquenessIT` | Completed run and item uniqueness |
| `StatementHashTest` | Canonical reproducibility |

```gherkin
Scenario: Held invoice is excluded from netting
  Given an issued invoice with a billing hold
  When settlement runs for the pair and period
  Then the invoice is not in the net
  And the exclusion is recorded on the statement

Scenario: Second completion is rejected
  Given a completed settlement for a pair, period, and currency
  When another completion is requested
  Then it fails with SETTLEMENT_ALREADY_COMPLETED
  And the original statement is unchanged
```

## Phase plan

- Phase 8: V014, netting, lock, approval, completion, statement, clearing journals.
- Phase 9: audit and reporting consume the completion event.
- Phase 10: external cash confirmation remains T2; no bank integration in T1.

# ledger

- **Status:** Draft
- **Owner:** VoltReckon maintainer
- **Last verified:** 2026-11-13
- **Applies to phases:** 4-10

`ledger` owns the chart of accounts, accounting periods, journals, postings, reversals, and the
trial balance. It is a leaf: it depends only on `shared` and knows no partner, CDR, invoice, or
settlement type. Rules are `LEDG-001`-`LEDG-012`; posting recipes and accounts are owned by
[05-financial-model.md](../05-financial-model.md).

## Purpose

Keep a balanced, append-only double-entry book that any caller can post to through a
domain-neutral command, and prove the books balance for an entity and period.

## Scope

In scope: accounts, periods, journals, lines, reversals, period close, and trial balance. Out of
scope: invoice creation, tax calculation, settlement netting, partner data, and cash movement.
The ledger records obligations, not bank payments.

## Public API

- `PostJournalCommand` with entity reference, period, source type, source ID, currency,
  description, and at least two lines.
- `ReverseJournalCommand` with the original entry and reason.
- `ClosePeriodCommand` with period code, reason, and approval reference.
- `TrialBalanceQuery`, `JournalQuery`, and `PeriodQuery`.
- No event is produced in T1; callers own their source event and audit record.

The API exposes value records only; it never exposes an account, journal, or line entity.

## Domain model

`Account` has a stable code, name, type, optional currency, opaque `owner_ref`, and active flag.
`Period` has a `YYYY-MM` code, start and end dates, and status (`OPEN`, `CLOSED`, `LOCKED`).
`JournalEntry` has an identity, opaque `entity_ref`, period, source type and ID, entry type,
optional reversal link, currency, and description. `JournalLine` has an account, exactly one of
debit or credit, an optional opaque `partner_ref`, and a memo.

## Owned data

`ledger_account`, `accounting_period`, `journal_entry`, and `journal_line` in V009; the
chart-of-accounts seed is V010. Journal rows are append-only after posting. No foreign key
points to a domain table.

## Invariants

**LEDG-001** A journal MUST have at least two lines, at least one positive line, and equal total
debits and credits at commit. *Check:* deferred constraint trigger and `JournalBalanceIT`.

**LEDG-002** Each line MUST have exactly one positive side; zero and double-sided lines MUST be
rejected. *Check:* database check and line test.

**LEDG-003** A posting MUST target an `OPEN` period; `CLOSED` or `LOCKED` MUST fail with
`PERIOD_CLOSED`. *Check:* period IT.

**LEDG-004** A posted journal and its lines MUST be immutable; a correction MUST be a reversal
or a new adjustment. *Check:* trigger and immutability IT.

**LEDG-005** A reversal MUST negate every line, use `entry_type = REVERSAL`, and reference the
original; the original MUST remain. *Check:* reversal IT.

**LEDG-006** A source document MUST map to at most one standard journal per `(entity_ref,
source_type, source_id)`; a replay MUST return the original entry. *Check:* unique index and
posting replay IT.

**LEDG-007** `ledger` MUST NOT import a partner, invoice, CDR, settlement, or audit type.
*Check:* ArchUnit and public API review.

**LEDG-008** Account codes MUST be unique and stable; a name change requires a migration.
*Check:* unique index and chart test.

**LEDG-009** A trial balance MUST show total debits equal total credits and account balances sum
to zero for the selected entity and period. *Check:* `TrialBalanceIT`.

**LEDG-010** A correction to a closed period MUST post to the next open period and link the
original; reopening is not supported in T1. *Check:* correction IT.

**LEDG-011** Period close MUST require an explicit reason, a privileged actor, and a
maker-checker approval. *Check:* close IT and approval audit.

**LEDG-012** No ledger command may create cash movement or mutate a bank balance in T1.
*Check:* chart and API review.

## Transactions

The caller opens the transaction and calls `PostJournalCommand`; the ledger writes the entry
and lines on the caller's connection and never commits independently. The deferred trigger
checks balance at commit, so the caller's rollback removes the journal with the document. A
period close locks the period row, verifies no unposted source is pending, changes status, and
records the approval. A reversal reads the original under lock and inserts a new entry.

## Events

`ledger` produces no catalog event. Billing and settlement own the document event and audit
record; the journal is posted synchronously inside that transaction (`MONEY-027`,
`ARCH-016`). An asynchronous consumer MUST NOT create a journal.

## Dependencies

`shared` only. `ledger` MUST NOT depend on `platform` or any domain module; technical
persistence types live in its adapter and implement its ports. This leaf rule is
`ARCH-006`.

## Configuration

| Key | Default | Purpose |
|---|---|---|
| `voltreckon.ledger.chart-version` | `1` | Seed version |
| `voltreckon.ledger.period-zone` | `Asia/Kolkata` | Period boundary |
| `voltreckon.ledger.max-lines` | `200` | Per-journal guardrail |
| `voltreckon.ledger.entity-required` | `true` | Reject a missing entity |

## Errors

| Code | Status | Meaning |
|---|---|---|
| `UNBALANCED_JOURNAL` | 422 | Debits do not equal credits |
| `INVALID_JOURNAL` | 422 | Fewer than two lines or zero entry |
| `PERIOD_CLOSED` | 409 | Period is closed or locked |
| `PERIOD_NOT_FOUND` | 404 | Period code does not exist |
| `ACCOUNT_INACTIVE` | 409 | Account cannot receive a posting |
| `IMMUTABLE_RECORD` | 409 | Posted row cannot change |
| `DUPLICATE_POSTING` | 409 | Source already has a standard journal |
| `REVERSAL_INVALID` | 422 | Reversal does not mirror the original |

## Security

`ledger.read` reads trial balance and journals in the caller's partner scope; `period.close`
requires `FINANCE_ADMIN` plus maker-checker and an MFA claim. The ledger trusts the caller's
`entity_ref` and `partner_ref` as opaque values but validates that a partner-scoped request does
not mix entities. A manual adjustment requires a reason code and approval (`MONEY-028`).

## Observability

Metrics: postings, unbalanced rejects, period-close latency, trial-balance runs, and duplicate
posting replays. Logs carry entry number and `entity_ref`; they never carry full lines.

## Tests

| Test | Covers |
|---|---|
| `JournalBalanceIT` | Deferred debit/credit equality |
| `JournalValidationTest` | Two lines, one side, no zero |
| `PostingReplayIT` | Source uniqueness and replay |
| `PeriodCloseIT` | Open/closed/locked transitions |
| `ReversalIT` | Negated lines and original retained |
| `TrialBalanceIT` | Balances sum to zero |
| `LedgerArchitectureTest` | No domain or platform import |

```gherkin
Scenario: Unbalanced journal fails at commit
  Given a journal with debit 100 and credit 99
  When the transaction commits
  Then the deferred check rejects it
  And no journal row exists

Scenario: Correction after close posts to the next open period
  Given a closed April period
  When a correction is posted
  Then it lands in the next open period
  And it links the original entry
  And April remains unchanged
```

## Phase plan

- Phase 4: V009, V010, accounts, journals, periods, trial balance, reversal.
- Phase 5: billing posts invoices and credit notes through the synchronous command.
- Phase 8: settlement posts netting entries through the same command.

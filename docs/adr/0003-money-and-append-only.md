# ADR-0003 — Money and append-only financial records

- **Status:** Accepted
- **Date:** 2026-11-13
- **Deciders:** VoltReckon maintainer
- **Applies to phases:** 0–10

## Context

Financial errors in roaming are usually not arithmetic mistakes; they are silent mutations,
unexplained corrections, and rounding drift. Binary floating point cannot represent most
decimal amounts exactly. A correction that overwrites an issued document destroys the audit
trail and makes later reconciliation impossible.

## Decision

- Money is a value object with `long amountMinor` and an ISO 4217 `CurrencyCode`
  [ref-25]. The database uses `BIGINT` for the amount and `CHAR(3)` for the currency.
- `float` and `double` MUST NOT appear in money paths. Intermediate tax arithmetic MAY use
  `BigDecimal` with an explicit scale and `RoundingMode.HALF_UP`, then convert once to minor
  units.
- Rounding is per line with HALF_UP, then summed. The financial model document defines the
  exact order for discounts, tax, and totals.
- Issued invoices, credit notes, journals, postings, rating results, settlement statements,
  and audit records are **append-only**. A correction creates a new row, a reversal journal,
  or a credit note. The original row is never updated or deleted.
- Drafts may be edited before issue. “Issued” is the immutability boundary.
- CDRs are immutable after acceptance; a correction arrives as a Credit CDR or a new
  ingestion record, never as an in-place rewrite.
- Deletion is forbidden for financial rows; retention and legal hold are data-lifecycle
  concerns, not application deletes.

## Alternatives considered

| Alternative | Why rejected | Revisit trigger |
|---|---|---|
| `NUMERIC`/`BigDecimal` for stored money | Correct but slower and easier to compare incorrectly; minor units make equality and sums exact. | A currency with non-decimal minor units requires a different representation. |
| Floating point | Cannot represent decimal tax and totals exactly; rejected outright. | Never for money. |
| Mutable issued documents with an audit log | The log can disagree with the row and is easier to tamper with; reporting reads become ambiguous. | A regulator requires in-place correction with a signed amendment protocol. |
| Event sourcing every aggregate | Overkill for T1 and duplicates the ledger’s append-only role. | A reconstruction requirement that the ledger and audit chain cannot meet. |

## Consequences

- Positive: exact sums, stable comparisons, and a trial balance that can be proven.
- Positive: every correction has a source document and a link to what it corrects.
- Negative: storage grows with corrections; reports must select the latest effective row or
  sum signed rows.
- Negative: application code must convert decimal input to minor units at the boundary and
  reject excess precision with a stable error code.
- Migration: schema uses `BIGINT` and `CHAR(3)`; no floating columns.
- Follow-up: enforce immutability with database triggers where practical and with tests.

## References

- [05-financial-model.md](../05-financial-model.md)
- [04-data-model.md](../04-data-model.md)
- [ref-25]

## Review trigger

A settlement currency with non-decimal minor units is introduced, a regulator requires a
different correction model, or a measured performance limit makes minor-unit arithmetic
insufficient.

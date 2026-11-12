# ADR-0003: Represent money and financial history with minor units and an append-only double-entry ledger

- **Status:** Accepted
- **Date:** 12 November 2026
- **Deciders:** VoltReckon maintainers

## Context

VoltReckon bills charging sessions, applies tax, reconciles partner invoices, and nets settlements. The financial model must be exact, explainable, and defensible to partners, auditors, and tax authorities.

Two failure classes drive the design:

1. **Representation errors.** Floating point cannot represent decimal money exactly (`0.1 + 0.2 != 0.3`). Binary rounding errors compound across line items, currencies have different exponents (INR 2, JPY 0, KWD 3), and OCPI transports some amounts as decimal strings.
2. **History loss.** Mutable invoice totals or balance columns destroy the ability to answer "what was billed, why, and how was it settled?" Corrections must be new records, not silent edits.

GST adds another dimension: rates and classification can change, and the rule used for a historical invoice must remain reproducible.

## Decision

### Money representation

- Persist money as `BIGINT` **minor units** plus `varchar(3)` ISO-4217 currency.
- Use a `Money` value object in the domain; never `float` or `double`.
- Use `BigDecimal` only for intermediate rate/quantity multiplication and division.
- Round **per line, `HALF_UP`, to the currency's minor unit**, then sum lines.
- Compute tax per line on the taxable amount, then sum; never allocate tax from a rounded invoice total.
- Convert OCPI decimal strings with `BigDecimal`, never `Double.parseDouble`.
- Serialize money as `{ "amountMinor": 84960, "currency": "INR" }`.
- Check overflow with `Math.addExact` / `Math.multiplyExact`.

### Append-only double-entry ledger

- Use `journal_entry` + `journal_line`; every entry has at least two lines and total debits equal total credits.
- Enforce balancing with a **deferred constraint trigger** at commit.
- Entries and lines are immutable; triggers block `UPDATE` and `DELETE`.
- Corrections are **reversing entries** linked to the original.
- Each entry belongs to one entity (`entity_partner_id`) and one accounting period.
- `UNIQUE (entity_partner_id, source_type, source_id, entry_type)` makes posting idempotent per set of books.
- A closed period rejects new postings.
- Invoice corrections use **credit notes**, never edits.
- CDR corrections use **Credit CDRs**, never edits; an original can be credited at most once.
- Tax rules are effective-dated configuration; invoice tax lines copy `tax_rate_id` and `rate_bp`.
- Settlement statements net eligible ledger items and record obligations; they do not move money.

### Invariants

- `subtotal + tax = total` for invoices and rating results.
- Every journal entry balances and has at least two lines.
- Every invoice line references exactly one rating result; a rating result cannot be invoiced twice.
- A settlement item references exactly one journal line; a line cannot be settled twice.
- Issued invoices, posted journals, and issued statements are immutable.
- No money value is ever represented by a floating-point type.

## Alternatives considered

1. **`NUMERIC` money columns.** Exact, but currency-aware APIs still need conversion, and a database numeric can silently carry unexpected scale. Minor units make the unit explicit everywhere.
2. **`BigDecimal` columns.** Exact but invites scale drift and accidental mixing of currencies.
3. **Floating point.** Rejected outright.
4. **Mutable balance table.** Simple, but loses history and cannot explain a balance.
5. **Single-entry invoice totals.** Cannot prove books; fails audit.
6. **Event sourcing as the ledger.** Powerful but adds replay, versioning, and projection complexity. The append-only journal plus audit log provides the needed trail without full event sourcing.
7. **Editing invoices in place with an audit log.** Tempting, but tax rules and partner expectations call for credit notes; edits also break reconciliation against sent documents.
8. **Hard-coded GST rate.** Brittle and potentially wrong; tax must be versioned configuration.

## Consequences

**Positive**

- Exact sums and comparisons across currencies.
- Every balance is explainable by its postings.
- Corrections are explicit, auditable, and partner-visible.
- Database-level protection against silent tampering.
- Trial balance is a query, not a maintained cache.
- Historical invoices remain reproducible when tax rules change.

**Negative**

- More rows than a balance table; reporting must aggregate.
- Conversion and rounding are required at OCPI and UI boundaries.
- Reversals need care to avoid double-counting in reports.
- Closed-period and settlement-eligibility logic must be explicit.
- `BIGINT` overflow must be checked for extreme values.

## Revisit triggers

- A currency or requirement needs precision beyond minor units (for example, sub-paisa rates that must be stored, not calculated).
- Cross-currency accounting with a defined FX policy is introduced.
- Ledger volume requires partitioning by period.
- A regulatory requirement demands a different book of record.

See [financial model](../database/02-financial-model.md), [database design](../architecture/database-design.md), and [schema.sql](../database/schema.sql).

# Financial domain design

**Purpose:** define how VoltReckon represents money, rates sessions, applies tax, posts journals, and nets settlements. This is the part of the system that must be correct before anything else is built.

**Relevant schema:** [schema.sql](schema.sql) — `rating_*`, `invoice*`, `credit_note`, `ledger_*`, `journal_*`, `settlement_*`.

---

## 1. Principles

1. **No floating point.** Money is integer minor units. Rates and quantities may use `BigDecimal`/`numeric`; money never does.
2. **Every financial fact is append-only.** Issued invoices, posted journals, CDRs, and settlements are never edited. Corrections are new records that reference the original.
3. **Every number has a source.** A journal line traces to an invoice, credit note, or settlement; an invoice line traces to a rating result; a rating result traces to a CDR, agreement, and tariff version.
4. **Totals are derived, never trusted from input.** A partner-declared total is stored for comparison, not used as the accounting amount.
5. **Rounding is explicit and consistent.** One documented policy, applied per line, tested at boundaries.
6. **Tax is configuration, not code.** Rate changes are data with effective dates; the rule used is copied into the tax line.
7. **One currency per journal entry.** Cross-currency netting is out of scope for the MVP.
8. **The ledger must always balance.** Enforced by the database, not just by tests.

---

## 2. Money representation

### 2.1 The `Money` value type

```java
public record Money(long amountMinor, Currency currency) {
    public Money plus(Money other) { ... }
    public Money negate() { ... }
    public BigDecimal toMajor() { ... }
}
```

Rules:

- `amountMinor` is a `long`. Overflow is checked with `Math.addExact`/`multiplyExact`.
- `Currency` is an ISO-4217 code with a known exponent.
- Construction never accepts `double` or `float`.
- Arithmetic across different currencies throws.
- Serialization uses `{ "amountMinor": 84960, "currency": "INR" }`.

### 2.2 Currency exponents

| Currency | Exponent | Minor unit |
|---|---|---|
| INR | 2 | paisa |
| USD, EUR | 2 | cent |
| JPY | 0 | yen |
| KWD, BHD | 3 | fils |

Conversion from a decimal amount:

```
minor = decimal.movePointRight(exponent).setScale(0, RoundingMode.HALF_UP).longValueExact()
```

Conversion from OCPI strings:

```java
BigDecimal rate = new BigDecimal(ocpiString);   // never Double.parseDouble
long minor = rate.movePointRight(exponent).setScale(0, HALF_UP).longValueExact();
```

Validate that the OCPI decimal does not carry more precision than the currency allows **for amounts**; rates may carry more and are rounded only at line calculation.

### 2.3 Rounding policy

- **Per line, half-up, to the currency's minor unit.** Then sum lines.
- Tax is computed per line on the taxable amount, then summed.
- Never compute tax on the invoice total and allocate it proportionally.
- Never round an intermediate subtotal and then use the unrounded value elsewhere.
- Document the policy in the invoice metadata (`rounding_policy = 'HALF_UP_PER_LINE'`) so exports are reproducible.

`BigDecimal` operations must always specify scale and `RoundingMode`. A missing rounding mode is a code review defect.

---

## 3. Rating mathematics

### 3.1 Inputs

- CDR: energy (Wh), duration (seconds), start/end time, declared total.
- Agreement: which tariff applies, currency, billing period basis.
- Tariff version: components and restrictions effective at session time.

### 3.2 Component calculation

Let `price_minor` be the price per `step_size` units, `q` the quantity in the component's base unit.

| Component | Quantity | Amount |
|---|---|---|
| `ENERGY` | Wh, converted to kWh (or the tariff's unit) | `round(price_minor * q / step_size, HALF_UP)` |
| `TIME` | Seconds, converted to minutes | `round(price_minor * q / step_size, HALF_UP)` |
| `PARKING_TIME` | Seconds after grace period | same |
| `FLAT` | 1 | `price_minor` |

The exact unit and step semantics (started step vs exact proration) must be specified per tariff/agreement. The MVP default is **exact proration with half-up rounding**; a per-component `pricing_mode` (`PRORATED`, `STARTED_STEP`) is a Phase 2 extension if partners require it.

### 3.3 Worked example

Tariff: ₹18.00 per kWh (`price_minor = 1800`, `step_size = 1`), GST 18%, prices exclusive of tax.

Session: 40.000 kWh.

```
energy amount = 1800 * 40 = 72,000 paise        (₹720.00)
tax           = round(72,000 * 1800 / 10,000)    = 12,960 paise (₹129.60)
line total    = 84,960 paise                     (₹849.60)
```

Header: subtotal 72,000; tax 12,960; total 84,960.

### 3.4 Stepped price example

Tariff: ₹2.50 per 15 minutes (`price_minor = 250`, `step_size = 15`), session 40 minutes.

```
amount = round(250 * 40 / 15) = round(666.666...) = 667 paise (₹6.67)
```

Document whether the partner expects 3 started steps (750 paise) instead. This is a contract question, not a code preference.

### 3.5 Credit CDRs

A credit CDR has negative `total_cost` and references the original. Rating produces negative lines of the same shape:

```
original: energy 72,000, tax 12,960, total 84,960
credit:   energy -9,000, tax -1,620, total -10,620
net:      energy 63,000, tax 11,340, total 74,340
```

The net rated amount is what the invoice should bill. The credit rating must not be invoiced as a separate positive line without the original; it is always paired.

### 3.6 Variance

```
variance_minor = rated_total_minor - declared_total_minor
```

Types: `NONE` (within tolerance), `AMOUNT` (outside tolerance), `ENERGY` (energy mismatch dominates), `CURRENCY`, `MISSING_TARIFF`, `MISSING_AGREEMENT`.

Tolerance is per agreement. Variance is **recorded**, not auto-corrected. A finance user decides whether to accept the declared amount, adjust the tariff, or dispute.

---

## 4. Tax mechanics

### 4.1 Exclusive vs inclusive

- Default: prices are **tax-exclusive**; tax is added.
- If a contract price is inclusive: `tax = round(total * rate / (10000 + rate), HALF_UP)`, and `taxable = total - tax`. The policy is stored with the invoice.

### 4.2 India GST split

At invoice issue, the applicable rate and place of supply determine the split:

| Scenario | Split |
|---|---|
| Supplier state = place of supply | CGST = rate/2, SGST = rate/2 |
| Supplier state ≠ place of supply | IGST = rate |
| Union territory specifics | Follow the applicable rules; configuration-driven |

The split is written to `invoice_tax_line` with `tax_kind`, `rate_bp`, and amounts. The `tax_rate` row stores the total rate; the split is derived from the place of supply.

### 4.3 Rate changes

- `tax_rate` rows are effective-dated and immutable.
- An invoice issued in November uses the rate effective in November for that service code and jurisdiction.
- Changing a rate never alters issued invoices; it may affect new drafts and requires a new rating result if tax is part of the rated total.

### 4.4 Credit notes and tax

A credit note reverses both the taxable amount and the tax, using the original invoice's tax rule (not today's). The tax lines reference the original `tax_rate_id` and `rate_bp`.

---

## 5. Double-entry ledger

### 5.1 Rules

- Every journal entry has at least two lines.
- Sum of debits equals sum of credits.
- A line has exactly one of debit or credit non-zero.
- Entries are immutable; corrections are reversing entries.
- Each entry belongs to one entity (`entity_partner_id`) and one accounting period.
- Each entry has a source and source ID; a source can post at most one standard entry per entity.

### 5.2 Chart of accounts (seed)

| Code | Name | Type | Typical use |
|---|---|---|---|
| 1100 | Accounts Receivable | Asset | Amount owed by a partner/customer |
| 1150 | Settlement Clearing | Asset/Liability | Net agreed amount awaiting external payment |
| 1200 | Cash and Bank | Asset | Phase 2 payment confirmation |
| 1300 | Input GST | Asset | eMSP side tax credit |
| 2100 | Accounts Payable | Liability | Amount owed to a partner/vendor |
| 2200 | Output GST Payable | Liability | GST collected on sales |
| 2300 | Accrued Fees | Liability | Referral/roaming fees payable |
| 4000 | Charging Revenue | Revenue | CPO charging sales |
| 4900 | Discounts and Adjustments | Revenue (contra) | Credits and write-downs |
| 5000 | Charging Cost | Expense | eMSP cost of charging |
| 6000 | Operating Expenses | Expense | Fees, payment costs |

Partner-specific accounts (for example, `1100-<partner>`) are optional via `ledger_account.partner_id`; the MVP can use shared control accounts plus `journal_line.partner_id` as a dimension.

### 5.3 Posting recipe — CPO issues an invoice

Invoice: subtotal ₹720.00, GST ₹129.60, total ₹849.60.

| Account | Debit (paise) | Credit (paise) |
|---|---|---|
| 1100 Accounts Receivable | 84,960 | |
| 4000 Charging Revenue | | 72,000 |
| 2200 Output GST Payable | | 12,960 |

### 5.4 Posting recipe — credit note

Credit note: energy ₹90.00, GST ₹16.20, total ₹106.20.

| Account | Debit (paise) | Credit (paise) |
|---|---|---|
| 4900 Discounts and Adjustments | 9,000 | |
| 2200 Output GST Payable | 1,620 | |
| 1100 Accounts Receivable | | 10,620 |

**Note:** the credit note reduces revenue through a contra account rather than debiting 4000 directly, so gross revenue remains visible. Either treatment is acceptable if consistent; pick one and document it.

### 5.5 Posting recipe — settlement

After the credit, the net receivable is ₹743.40 (84,960 − 10,620 = 74,340 paise).

| Account | Debit (paise) | Credit (paise) |
|---|---|---|
| 1150 Settlement Clearing | 74,340 | |
| 1100 Accounts Receivable | | 74,340 |

When cash is confirmed (Phase 2, bank import):

| Account | Debit | Credit |
|---|---|---|
| 1200 Cash and Bank | 74,340 | |
| 1150 Settlement Clearing | | 74,340 |

Settlement does **not** claim cash movement. It moves the agreed balance from AR to settlement clearing so the statement and the books agree.

### 5.6 Posting recipe — eMSP books (mirror)

If both parties are onboarded, the eMSP entity posts its own journal for the received invoice:

| Account | Debit | Credit |
|---|---|---|
| 5000 Charging Cost | 72,000 | |
| 1300 Input GST | 12,960 | |
| 2100 Accounts Payable | | 84,960 |

Settlement from the eMSP side: Dr 2100 AP / Cr 1150 Settlement Clearing. The platform posts two separate entries with different `entity_partner_id`.

### 5.7 Reversals

A reversal is a new entry with mirrored debits/credits, `entry_type = 'REVERSAL'`, and `reverses_entry_id`. It never edits the original. Both entries remain in the trial balance and net to zero.

---

## 6. Settlement netting

### 6.1 Eligibility

An item is eligible when:

- It belongs to the partner pair and currency.
- It is posted in an `OPEN` or `CLOSED` period within the settlement window (policy-dependent; default: open items only).
- It has not been included in a completed settlement run.
- It is not fully credited or disputed-hold.

### 6.2 Algorithm

```
1. Acquire advisory transaction lock on (cpo, emsp, period).
2. Select eligible journal lines tagged with the counterparty and direction.
3. Sum payables and receivables per currency.
4. net = receivables_from_counterparty - payables_to_counterparty
5. Insert settlement_item rows linking each journal line.
6. Insert settlement_run with net_amount and status LOCKED.
7. Post a settlement journal per entity (clearing transfer).
8. Mark run COMPLETED; generate statement with content hash.
```

### 6.3 Worked netting example

CPO books, partner eMSP:

- Invoice A: receivable ₹849.60 → settled receivable 74,340 paise after credit (from 5.5).
- Referral fee owed by CPO to eMSP: ₹50.00 + GST ₹9.00 = ₹59.00 = 5,900 paise payable.

```
receivable = 74,340
payable    =  5,900
net        = 68,440 paise (₹684.40 receivable by CPO)
```

The statement shows both sides and the net; the journal records the clearing movement. No cash is moved.

### 6.4 Sign conventions

- `PAYABLE` means the entity owes the counterparty.
- `RECEIVABLE` means the counterparty owes the entity.
- `net_amount_minor` is positive when the entity receives; negative when it pays. Document this in the API and statement.

### 6.5 What settlement does not do

- No bank transfer, UPI collect, or wallet debit.
- No FX conversion.
- No write-off of disputed items.
- No mutation of invoices or journals.

---

## 7. Accounting periods

- Period codes are `YYYY-MM`; ranges are month boundaries in the entity's statutory timezone (IST for India), stored as dates.
- Postings are allowed only in `OPEN` periods.
- Closing a period sets `CLOSED`, records actor/time, and blocks further postings.
- Reopening is a privileged, audited operation (Phase 2 maker-checker).
- Late CDRs for a closed period post in the current open period with a clear reference to the original session; the policy must be documented and consistent with tax rules.
- Trial balance is per entity and per period.

---

## 8. Multi-entity and multi-currency

### 8.1 Multi-entity

- `journal_entry.entity_partner_id` identifies whose books are kept.
- One invoice may generate two journals (issuer and recipient) if both are onboarded.
- Intercompany balances must mirror; a mismatch is an integrity check.

### 8.2 Multi-currency

- MVP: one currency per agreement, invoice, journal, and settlement run.
- No cross-currency netting.
- If a future agreement spans currencies, use separate runs per currency and report separately; FX conversion is a Phase 3 decision with an explicit rate source and policy.

---

## 9. Invariants and tests

| Invariant | Enforcement | Test |
|---|---|---|
| Debits = credits per entry | Deferred DB trigger | Property test over random postings |
| Entry has ≥ 2 lines | DB trigger | Unit test |
| Line has exactly one side | DB `CHECK` | Unit test |
| Rating subtotal + tax = total | DB `CHECK` + service | Property test |
| Invoice subtotal + tax = total | DB `CHECK` | Property test |
| Sum of lines = header | Service + DB check | Property test |
| One active rating per CDR | Partial unique index | Concurrency test |
| One invoice line per rating result | Unique index | Concurrency test |
| Issued invoice immutable | Trigger | Integration test |
| Credit note ≤ original | Service | Property test |
| Settlement item settled once | Unique index | Concurrency test |
| Net = sum of items | Service | Property test |
| Tax uses effective rule | Service | Time-travel test with `Clock` |
| Reversal nets to zero | Service + trigger | Integration test |
| No floating point | ArchUnit + code review | Build failure |

Property-based tools: jqwik for arithmetic and interval logic; Testcontainers PostgreSQL for constraint and trigger behaviour.

---

## 10. Anti-patterns explicitly avoided

| Anti-pattern | Why it is wrong | VoltReckon response |
|---|---|---|
| Storing money as `double` | Binary rounding errors | Integer minor units |
| Applying tax to the invoice total | Component rates and exemptions differ | Per-line tax |
| Editing a CDR | Destroys audit trail; violates OCPI | Credit CDR |
| Editing an issued invoice | Defeats tax and audit control | Credit note |
| Mutable ledger balances | No history; hard to audit | Append-only journals |
| Netting before reconciliation | Settles disputes silently | Reconciliation first |
| Auto-writing off small variances | Hides revenue leakage | Explicit exception + approval |
| FX conversion inside journal | Introduces rate ambiguity | Separate runs/currencies |
| Using “today’s” tariff for old sessions | Wrong amounts | Pinned tariff version |
| Trusting partner totals | Transfers their errors into your books | Re-rate and compare |

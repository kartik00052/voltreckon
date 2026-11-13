# 05 — Financial model

- **Status:** Draft
- **Owner:** VoltReckon maintainer
- **Last verified:** 2026-11-13
- **Applies to phases:** 0–10

This file defines money, rating arithmetic, tax arithmetic, postings, periods, and netting.
GST policy is in [07-gst-and-compliance.md](07-gst-and-compliance.md); table shapes are in
[04-data-model.md](04-data-model.md). When they disagree, the stricter money rule wins and
the conflict is reported.

## 1. Money representation

**MONEY-001** Money MUST be stored as `bigint` minor units plus an ISO 4217 `char(3)`
currency [ref-25]. *Check:* schema review; `MoneyTest`; ArchUnit forbids `float`/`double` in
money packages.

**MONEY-002** `float` and `double` MUST NOT be used for money, tax, quantities that become
money, or netting. *Check:* ArchUnit field/type rule; code review.

**MONEY-003** A currency's minor-unit exponent MUST come from ISO 4217 configuration, not
from an assumption of two decimals. INR is 2 (paise), JPY is 0 (yen), KWD and BHD are 3.
*Check:* `CurrencyTest` table.

**MONEY-004** An API money value MUST be `{ "amountMinor": <long>, "currency": "<ISO>" }`.
The API MUST reject a decimal amount, a missing currency, and a currency mismatch.
*Check:* contract test and request-validation IT.

**MONEY-005** Signed money is allowed only for rating results, variances, and statement
deltas. Journal lines, invoices, credit notes, and settlement items store positive amounts;
the side or direction carries the sign. *Check:* database checks and unit tests.

**MONEY-006** A conversion between a decimal input and minor units MUST happen once at the
boundary, with an explicit rounding mode, and MUST reject excess precision. *Check:*
boundary test.

## 2. Rounding and order

**MONEY-007** Round each line with `HALF_UP` to the currency's minor unit, then sum. Do not
round a total and then allocate it back to lines. *Check:* golden rating test with a
half-cent case.

**MONEY-008** The order is: quantity, unit price, line net, line discount, taxable amount,
tax per line, line total, document subtotal, document tax, document total. *Check:* invoice
golden test.

**MONEY-009** Tax is computed on the taxable line amount, never on a document total that
mixes rates. *Check:* multi-rate invoice test.

**MONEY-010** Use `BigDecimal` only for intermediate tax or step arithmetic with a declared
scale; persist `long` minor units. An intermediate value MUST NOT leak into an entity.
*Check:* code review and persistence test.

**MONEY-011** A negative intermediate result MUST be rejected unless the document is a
credit, reversal, or variance. *Check:* unit test.

## 3. Rating mathematics

**MONEY-012** Rating MUST be deterministic for the same CDR, tariff version, agreement,
currency, and tax rate. The result stores an `input_hash` over canonical inputs.
*Check:* repeated-run test compares the hash and amounts.

The inputs are the accepted CDR, its dimensions, the agreement effective at session start,
the tariff version effective at session start, the currency, and the tax rule. Re-rating
after a newer tariff version is published MUST still use the version effective at session
start; a deliberate new version is a new rating with a variance, never a mutation.

### 3.1 Component formulas

| Component | Quantity source | Billable quantity | Amount |
|---|---|---|---|
| `ENERGY` | `total_energy_wh` or `ENERGY` dimension | kWh with 4 decimals | `round(price_minor * kwh, HALF_UP)` |
| `TIME` | `total_time_seconds` or `TIME` dimension | tariff minutes or hours; steps rounded up | `round(price_minor * billable, HALF_UP)` |
| `PARKING_TIME` | parking seconds after grace | tariff unit; steps rounded up | same as time |
| `FLAT` | one | 1 | `price_minor` |
| `RESERVATION` | reservation seconds | tariff unit; steps rounded up | same as time |

**MONEY-013** A time or parking component with `step_size > 1` MUST round the billable
quantity up to the next whole step; an energy component uses the measured quantity and does
not round up. *Check:* step-size golden tests.

**MONEY-014** Restrictions filter components; they do not add a separate charge. Matching
components are applied in `element_order`. *Check:* restriction matrix test.

**MONEY-015** If no tariff version is effective at session start, or the agreement is
missing, rating MUST fail with `MISSING_TARIFF` or `MISSING_AGREEMENT` and MUST NOT guess.
*Check:* rating failure IT.

**MONEY-016** If the CDR has no dimensions but has totals, rating MAY synthesize one
dimension from the available totals; if it cannot, it MUST fail with `MISSING_DIMENSIONS`.
*Check:* ingestion-to-rating IT.

### 3.2 Worked example

Energy 12.5 kWh at 800 paise/kWh = 10,000 paise; time 45 minutes at 100 paise/minute = 4,500
paise; flat 1,000 paise. Subtotal = 15,500 paise. GST 18% = 2,790 paise. Total = 18,290
paise.

| Line | Quantity | Unit price | Net | Tax | Total |
|---|---:|---:|---:|---:|---:|
| Energy | 12.5000 kWh | 800 | 10,000 | 1,800 | 11,800 |
| Time | 45 min | 100 | 4,500 | 810 | 5,310 |
| Flat | 1 | 1,000 | 1,000 | 180 | 1,180 |
| **Sum** | | | **15,500** | **2,790** | **18,290** |

**MONEY-017** The rating result's `subtotal_minor + tax_minor` MUST equal `total_minor`, and
`variance_minor` MUST equal `total_minor - declared_total_minor`. *Check:* database checks
and golden test.

### 3.3 Credit CDRs

**MONEY-018** A credit CDR MUST be rated by negating the original rating's lines and tax, not
by applying the current tariff. The result is a new row with negative amounts and a link to
the original. *Check:* credit rating IT.

**MONEY-019** A credit MUST NOT exceed the original amount; an over-credit is rejected with
`CREDIT_EXCEEDS_ORIGINAL`. *Check:* credit boundary test.

## 4. Tax mechanics

**MONEY-020** Tax MUST be computed per line from the effective `tax_rate` at the tax point
recorded on the document. The default tax point is session end; an agreement may choose
invoice date. The chosen point is stored and never recomputed silently.
*Check:* time-travel tax test with a mutable `Clock`.

**MONEY-021** Tax is exclusive by default: `tax = round(taxable * rate_bp / 10000, HALF_UP)`;
`total = taxable + tax`. If a tariff is tax-inclusive, `taxable = round(total * 10000 /
(10000 + rate_bp), HALF_UP)` and `tax = total - taxable`. *Check:* inclusive/exclusive golden
tests.

**MONEY-022** For an intra-state supply, split the rate into CGST and SGST:
`cgst_bp = floor(rate_bp / 2)`, `sgst_bp = rate_bp - cgst_bp`. For an inter-state supply,
use IGST with the full rate. The sum of component tax MUST equal the line tax.
*Check:* split test for 18%, 12%, 5%, and an odd basis-point case.

**MONEY-023** Invoice tax lines aggregate by `(tax_rate_id, tax_kind, rate_bp)`; aggregation
MUST NOT change any line's tax. *Check:* multi-line invoice test.

**MONEY-024** A credit note MUST reverse the same tax components as the original; if the
original rate is no longer current, the credit uses the original stored rate.
*Check:* credit-note tax test.

**MONEY-025** Rating tax is provisional. Billing recomputes tax at the invoice tax point and
records a `rating_variance` when the amount differs; the invoice is authoritative.
*Check:* tax-change integration test.

## 5. Chart of accounts

The chart is versioned by migration and seeded in V010. Account codes are stable; names may
change with a migration.

| Code | Name | Type | Typical use |
|---|---|---|---|
| 1100 | Accounts Receivable | Asset | Amount owed by a partner |
| 1150 | Settlement Clearing | Asset/Liability | Net agreed amount awaiting external payment |
| 1200 | Cash and Bank | Asset | External payment confirmation, T2 |
| 1300 | Input GST | Asset | eMSP tax credit |
| 2100 | Accounts Payable | Liability | Amount owed to a partner |
| 2200 | Output GST Payable | Liability | GST collected on sales |
| 2300 | Accrued Fees | Liability | Roaming or referral fees payable |
| 4000 | Charging Revenue | Revenue | CPO charging sales |
| 4900 | Discounts and Adjustments | Revenue (contra) | Credits and write-downs |
| 5000 | Charging Cost | Expense | eMSP cost of charging |
| 6000 | Operating Expenses | Expense | Fees and payment costs |

**MONEY-026** `ledger` MUST NOT know partner, invoice, or CDR types. Account ownership uses
an opaque `owner_ref` UUID; the mapping to a partner lives outside the ledger.
*Check:* ArchUnit and ledger API review.

## 6. Posting recipes

All amounts are paise. A journal has at least two lines and equal debits and credits.

### 6.1 CPO issues an invoice

| Account | Debit | Credit |
|---|---:|---:|
| 1100 Accounts Receivable | 84,960 | |
| 4000 Charging Revenue | | 72,000 |
| 2200 Output GST Payable | | 12,960 |

### 6.2 CPO issues a credit note

| Account | Debit | Credit |
|---|---:|---:|
| 4900 Discounts and Adjustments | 9,000 | |
| 2200 Output GST Payable | 1,620 | |
| 1100 Accounts Receivable | | 10,620 |

### 6.3 eMSP books the mirror invoice

| Account | Debit | Credit |
|---|---:|---:|
| 5000 Charging Cost | 72,000 | |
| 1300 Input GST | 12,960 | |
| 2100 Accounts Payable | | 84,960 |

### 6.4 Settlement moves the receivable to clearing

CPO side for a net receivable:

| Account | Debit | Credit |
|---|---:|---:|
| 1150 Settlement Clearing | 74,340 | |
| 1100 Accounts Receivable | | 74,340 |

eMSP side for a net payable:

| Account | Debit | Credit |
|---|---:|---:|
| 2100 Accounts Payable | 74,340 | |
| 1150 Settlement Clearing | | 74,340 |

T1 records the obligation; it does not move funds. The cash entry is a T2 integration.

**MONEY-027** A financial document and its journal MUST be written in one transaction through
a synchronous public command. An event after commit is a notification, not the posting
mechanism. *Check:* `billing` and `settlement` atomicity IT.

**MONEY-028** A manual adjustment MUST use `source_type = ADJUSTMENT`, a reason code, and
maker-checker approval. It MUST NOT edit an existing journal. *Check:* adjustment approval
IT.

## 7. Periods, reversals, and closed books

**MONEY-029** A posting MUST target an `OPEN` period. A `CLOSED` or `LOCKED` period MUST
reject the posting with `PERIOD_CLOSED`. *Check:* ledger period IT.

**MONEY-030** A correction to a closed period MUST post to the next open period and MUST link
the original journal or document. The original period remains unchanged. *Check:* correction
IT.

**MONEY-031** A reversal MUST negate every line of the original, have `entry_type =
REVERSAL`, and reference the original entry. The original remains. *Check:* reversal test.

**MONEY-032** Closing a period MUST require an explicit privileged action, a reason, and a
maker-checker approval. Reopening is not supported in T1; a correction uses the next open
period. *Check:* period-close IT and audit record.

**MONEY-033** A trial balance MUST show total debits equal total credits and the sum of
account balances equal zero for the selected entity and period. *Check:* `TrialBalanceIT`.

## 8. Settlement netting

**MONEY-034** Netting MUST run on one partner pair, one currency, and one period. A
multi-currency run is rejected until the T2 trigger. *Check:* netting validation test.

**MONEY-035** Eligibility: issued invoices and credit notes with issue date on or before the
period end, not fully settled, and not held by an open dispute. The hold is an invoice-level
flag owned by `billing` and set through its public command; a held invoice stays out of netting
and appears as an exception. *Check:* eligibility matrix test.

**MONEY-036** Net amount is signed from the CPO's perspective: positive means the eMSP owes
the CPO; negative means the CPO owes the eMSP. The statement states the perspective.
*Check:* sign-convention test.

Algorithm:

1. Select eligible documents for the pair, period, and currency.
2. Convert each document to a signed CPO-perspective amount: invoice positive, credit note
   negative.
3. Exclude held amounts; record each exclusion.
4. Sum exactly in minor units; do not round the net again.
5. Create a `DRAFT` run with items and a canonical JSON snapshot.
6. Lock the run; a second user approves; complete it.
7. Write the settlement journals and the immutable statement with a SHA-256 hash.
8. A repeated completed run for the same pair, period, and currency is rejected.

**MONEY-037** A settlement statement MUST be reproducible: the same inputs and canonical
serialization MUST produce the same hash. *Check:* statement hash test.

**MONEY-038** A settlement run MUST be unique per pair, period, and currency when completed.
*Check:* partial unique index and concurrency IT.

## 9. Invariants and tests

| Invariant | Enforcement | Test |
|---|---|---|
| Debits equal credits per journal | Deferred trigger | `JournalBalanceIT` |
| Journal has at least two lines | Deferred trigger | `JournalValidationTest` |
| Line has exactly one side | Database check | `JournalLineTest` |
| Rating subtotal + tax = total | Database check and service | `RatingGoldenIT` |
| Invoice subtotal + tax = total | Database check | `InvoiceTotalsIT` |
| Sum of lines equals header | Service and check | `InvoiceGoldenIT` |
| One active rating per CDR | Partial unique index | `RatingConcurrencyIT` |
| Issued invoice immutable | Trigger | `InvoiceImmutabilityIT` |
| Credit note does not exceed original | Service | `CreditNoteLimitIT` |
| Settlement item settled once | Unique index | `SettlementConcurrencyIT` |
| Net equals sum of items | Service | `NettingPropertyTest` |
| Tax uses effective rate | Service and clock | `TaxTimeTravelIT` |
| Reversal nets to zero | Service and trigger | `ReversalIT` |
| No floating point | ArchUnit and review | build failure |

## 10. Anti-patterns

- Storing money as `double` or a formatted string.
- Applying tax to an invoice total that mixes rates.
- Editing an accepted CDR, issued invoice, or posted journal.
- Netting before reconciliation or while a dispute holds an amount.
- Silently writing off a variance; use an exception and approval.
- Recomputing a closed period.
- Using today's tariff for an old session.
- Trusting a partner total over the rated result.
- Moving cash in T1; settlement records obligations only.

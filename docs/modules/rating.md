# rating

- **Status:** Draft
- **Owner:** VoltReckon maintainer
- **Last verified:** 2026-11-13
- **Applies to phases:** 3-10

`rating` turns an accepted CDR into an immutable result, lines, and variance using the
agreement and the tariff version effective at **session start**. Rules are
`RATE-001`-`RATE-012`; formulas, rounding, and tax arithmetic are owned by
[05-financial-model.md](../05-financial-model.md).

## Purpose

Produce a deterministic, auditable price for each CDR, including a credit reversal, without
issuing an invoice or writing a journal.

## Scope

In scope: rating runs, per-CDR results, lines, variance, missing-data failures, and credit
reversal. Out of scope: CDR intake, tariff editing, invoice numbering, tax invoicing, ledger
posting, and settlement. Rating tax is provisional; billing is authoritative.

## Public API

- `StartRatingRunCommand` for a partner pair and period.
- `RateCdrCommand` for one accepted CDR.
- `RatingRunQuery`, `RatingResultQuery`, and `RatingLineQuery`.
- `RatingResultQuery` used by billing to fetch rateable results.
- `rating.rating.completed.v1` and `rating.rating.failed.v1` events.

## Domain model

`RatingRun` has a pair, period, status, cursor, counts, and error summary. `RatingResult` has a
CDR, agreement, tariff version, currency, energy, subtotal, tax, total, declared total,
variance, status (`ACTIVE`, `SUPERSEDED`), and input hash. `RatingLine` has a component,
quantity, unit price, amount, and tax rate. `RatingVariance` records the type, declared and
rated amounts, tolerance, and detail.

## Owned data

`rating_run`, `rating_result`, `rating_line`, and `rating_variance` in V008. Results and lines
are immutable; a re-rating inserts a new result and marks the prior result `SUPERSEDED` in the
same transaction.

## Invariants

**RATE-001** A rating result MUST use the agreement and tariff version effective at session
start, not at run time. *Check:* mutable-clock golden IT.

**RATE-002** Rating MUST be deterministic for the same CDR, agreement, tariff version,
currency, and tax rate; the stored `input_hash` MUST match a recomputation. *Check:*
`RatingGoldenIT`.

**RATE-003** Each line MUST round `HALF_UP` to the currency's minor unit before summing; a
document-level allocation MUST NOT change a line. *Check:* half-cent golden test.

**RATE-004** `subtotal_minor + tax_minor` MUST equal `total_minor`, and `variance_minor` MUST
equal `total_minor - declared_total_minor`. *Check:* database checks and result IT.

**RATE-005** At most one `ACTIVE` result MAY exist per CDR; a concurrent re-rate MUST either
supersede or fail, never create two active rows. *Check:* partial unique index and concurrency
IT.

**RATE-006** A credit CDR MUST negate the original result's lines and tax; it MUST NOT apply the
current tariff. An over-credit MUST fail with `CREDIT_EXCEEDS_ORIGINAL`. *Check:* credit
rating IT.

**RATE-007** A missing agreement, missing effective tariff, or missing dimensions MUST fail
with `MISSING_AGREEMENT`, `MISSING_TARIFF`, or `MISSING_DIMENSIONS`; rating MUST NOT guess.
*Check:* failure IT.

**RATE-008** Restrictions MUST filter components and MUST NOT add a charge. *Check:*
restriction matrix test.

**RATE-009** Rating tax MUST be computed per line and treated as provisional; a tax change
after rating MUST create a variance, not mutate the result. *Check:* tax-change IT.

**RATE-010** A result, its lines, its variance, the prior-result supersession, and the outbox
event MUST commit in one transaction per CDR. *Check:* atomicity IT.

**RATE-011** A failed CDR MUST be counted and recorded with a stable reason code; one failure
MUST NOT abort unrelated CDRs in the run. *Check:* mixed-run IT.

**RATE-012** Rating MUST NOT write an invoice, journal, or settlement row. *Check:* ArchUnit
and transaction review.

## Transactions

A run claims a cursor and processes CDRs in bounded batches. Each CDR uses its own local
transaction: load locked CDR, resolve agreement and tariff through public queries, calculate,
supersede any active result, insert the new result, lines, variance, and event. A failure
records a `rating_run` failure summary without a partial result. A run is resumable from its
cursor; a repeated CDR with the same `input_hash` is a no-op.

## Events

Producers: `rating.rating.completed.v1` with result ID, CDR ID, totals, and currency;
`rating.rating.failed.v1` with result/run ID, CDR ID, and reason code. Consumers: `billing`
(completed only), `audit`, and `reporting`. Billing still calls the synchronous result query;
the event is a notification.

## Dependencies

`shared`, `platform`, `partners`, `tariff`, and `ingestion`. `rating` MUST NOT depend on
`billing`, `ledger`, `dispute`, `reconciliation`, `settlement`, `audit`, or `reporting`.

## Configuration

| Key | Default | Purpose |
|---|---|---|
| `voltreckon.rating.batch-size` | `200` | CDRs per batch |
| `voltreckon.rating.variance-tolerance-minor` | `0` | Declared-total tolerance |
| `voltreckon.rating.max-attempts` | `3` | Per-CDR retry |
| `voltreckon.rating.clock-zone` | `Asia/Kolkata` | Business period boundary |

## Errors

| Code | Status | Meaning |
|---|---|---|
| `MISSING_AGREEMENT` | 422 | No active agreement at session start |
| `MISSING_TARIFF` | 422 | No published version effective at session start |
| `MISSING_DIMENSIONS` | 422 | No usable quantity source |
| `CURRENCY_MISMATCH` | 422 | CDR and tariff/agreement currencies differ |
| `CREDIT_EXCEEDS_ORIGINAL` | 422 | Credit amount exceeds original |
| `RATING_IN_PROGRESS` | 409 | Active result is being superseded |
| `RUN_NOT_FOUND` | 404 | Scoped run does not exist |
| `RESULT_NOT_FOUND` | 404 | Scoped result does not exist |
| `RATING_FAILED` | 422 | Calculation could not complete |

## Security

`rating.run` starts or reads a run; a partner user sees only its own pair. Rating reads CDR,
agreement, tariff, and tax through public queries, never through another module's tables.
Results contain no token values; logs carry CDR and result IDs only. A run MUST NOT cross a
partner boundary even for a platform administrator without an audited target partner.

## Observability

Metrics: CDRs processed, failures by reason, run duration, variance count, supersession count,
and tariff misses. Logs carry run ID, CDR ID, result ID, and `traceId`; no token values.

## Tests

| Test | Covers |
|---|---|
| `RatingGoldenIT` | Worked example and half-up lines |
| `RatingDeterminismIT` | Input hash and repeated run |
| `SessionStartTariffIT` | Old version after a publish |
| `RatingConcurrencyIT` | One active result |
| `CreditRatingIT` | Negated lines and tax |
| `RatingFailureIT` | Missing agreement, tariff, dimensions |
| `MixedRunIT` | One failure does not abort the run |

```gherkin
Scenario: Tariff change after session start does not change the result
  Given a CDR starting on 30 April
  And a newer tariff version published on 1 May
  When rating runs on 2 May
  Then the 30 April version is used
  And the result records that version
  And the variance is recorded without mutating it

Scenario: Credit reverses the original lines
  Given an active result for an original CDR
  When a valid credit CDR is rated
  Then the new result has negated lines and tax
  And the original result remains ACTIVE
```

## Phase plan

- Phase 3: V008, run, result, lines, variance, deterministic golden tests.
- Phase 5: billing reads results and records tax variance at the invoice tax point.
- Phase 9: audit and reporting consume rating events.

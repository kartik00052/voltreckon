# billing

- **Status:** Draft
- **Owner:** VoltReckon maintainer
- **Last verified:** 2026-11-13
- **Applies to phases:** 5-10

`billing` turns active rating results into GST invoices and credit notes, assigns legal
numbers, records the tax split, and posts the journal synchronously with the document. Rules
are `BILL-001`-`BILL-014`; tax policy is owned by
[07-gst-and-compliance.md](../07-gst-and-compliance.md) and the posting recipes by
[05-financial-model.md](../05-financial-model.md).

## Purpose

Issue a legally numbered, tax-correct, immutable financial document and its balanced journal
in one transaction, and expose an invoice-level hold so settlement can exclude disputed
amounts.

## Scope

In scope: draft and issued invoices, invoice lines, tax lines, credit notes, numbering,
e-invoice metadata, settlement holds, and journal posting. Out of scope: rating, CDR intake,
reconciliation, settlement netting, cash, and payment collection.

## Public API

- `CreateDraftInvoiceCommand` from active rating results.
- `IssueInvoiceCommand`, `CreateCreditNoteCommand`, `IssueCreditNoteCommand`.
- `PlaceSettlementHoldCommand` and `ReleaseSettlementHoldCommand` for `dispute`.
- `InvoiceQuery`, `CreditNoteQuery`, and `NumberSequenceQuery`.
- `billing.invoice.issued.v1` and `billing.credit_note.issued.v1` events.

The API never exposes `invoice` or `credit_note` entities. Holds are changed only through these
commands; no module writes billing tables.

## Domain model

`Invoice` has issuer and recipient, status, currency, subtotal, tax, total, period, issue and
due dates, place of supply, GSTINs, financial year, e-invoice status, IRN/ack fields, and a
settlement-hold flag with reason and time. `InvoiceLine` references one rating result and
stores the taxable, tax, and total amounts. `InvoiceTaxLine` aggregates by tax rate and kind.
`CreditNote` reverses an invoice within the remaining creditable amount.

## Owned data

`invoice`, `invoice_line`, `invoice_tax_line`, and `credit_note` in V011. Issued financial
columns are append-only by trigger; the hold columns are the only issued-invoice exception and
are changed only by the hold commands. Numbers are allocated from `platform.sequence_number`.

## Invariants

**BILL-001** One active rating result MUST appear on at most one invoice line. *Check:* unique
index on `rating_result_id` and invoice IT.

**BILL-002** `subtotal_minor + tax_minor` MUST equal `total_minor`; the sum of lines MUST equal
the header; tax MUST be computed per line, never on a mixed-rate total. *Check:* database
checks and `InvoiceGoldenIT`.

**BILL-003** An invoice number MUST be unique per issuer and financial year and MUST be
allocated only at issue. *Check:* partial unique index and numbering IT.

**BILL-004** An issued invoice's financial columns and lines MUST be immutable; a correction
MUST be a credit note. *Check:* trigger and `InvoiceImmutabilityIT`.

**BILL-005** A credit note MUST not exceed the remaining creditable amount of its invoice and
MUST reverse the original tax components, using the original stored rate. *Check:*
`CreditNoteLimitIT` and credit-tax IT.

**BILL-006** A credit note above the configured threshold MUST require a second approver who is
not the creator. *Check:* maker-checker IT.

**BILL-007** Invoice issuance and its journal MUST commit in one transaction through
`ledger`'s synchronous public command; an event MUST NOT create the journal. *Check:*
atomicity rollback IT.

**BILL-008** Tax MUST be resolved through the `tariff` public query at the invoice tax point;
the line stores the rate snapshot, and no GST rate is hard-coded. *Check:* tax-point IT.

**BILL-009** The place of supply, issuer GSTIN, recipient GSTIN, and SAC MUST be present on an
issued document; a missing required value MUST block issue. *Check:* issue validation test.

**BILL-010** An e-invoice document above the configured AATO threshold MUST be registered
before it is considered complete; a failed registration MUST be visible and retryable.
*Check:* e-invoice state IT. The threshold source is `ref-17`.

**BILL-011** A settlement hold MUST be set or cleared only by `dispute` through the public hold
command, with a reason code; it MUST NOT change the invoice total. *Check:* hold IT.

**BILL-012** A draft invoice MUST not have a legal number, a journal, or an issue event.
*Check:* draft-state test.

**BILL-013** Replaying an issue or credit command with the same idempotency key MUST return the
original document, not allocate a second number. *Check:* numbering replay IT.

**BILL-014** An invoice MUST NOT mix currencies; a rating result in another currency MUST be
rejected. *Check:* currency IT.

## Transactions

Draft creation reads rating results and copies their amounts into draft lines without posting.
Issue locks the draft, validates tax and GST data, allocates the number, computes the tax
split, calls `PostJournalCommand` in the same transaction, writes the outbox event, and marks
the draft issued. Credit-note issue follows the same shape and posts the reversal recipe.
Hold commands update only the hold columns under a row lock; they never touch totals or lines.
A ledger failure rolls back the number allocation and the document.

## Events

Producers: `billing.invoice.issued.v1` with invoice ID, partner ID, total, and currency;
`billing.credit_note.issued.v1` with credit-note ID, invoice ID, and total. Consumers: `audit`
and `reporting`. Settlement reads the public invoice query; it does not consume billing events
for netting.

## Dependencies

`shared`, `platform`, `partners`, `tariff` ([ADR-0013](../adr/0013-iam-partner-and-billing-tariff-dependencies.md)),
`rating`, and `ledger`. `billing` MUST NOT depend on `reconciliation`, `settlement`, `dispute`,
`audit`, or `reporting`.

## Configuration

| Key | Default | Purpose |
|---|---|---|
| `voltreckon.billing.sac` | `998714` | EV charging service code |
| `voltreckon.billing.invoice-prefix` | `INV` | Number format |
| `voltreckon.billing.credit-prefix` | `CRN` | Credit-note format |
| `voltreckon.billing.due-days` | agreement value | Fallback due date |
| `voltreckon.billing.credit-approval-threshold-minor` | configuration | Second approver |
| `voltreckon.billing.einvoice-aato-threshold-minor` | `5000000000` | ₹5 crore trigger |
| `voltreckon.billing.einvoice-enabled` | `false` | Registration switch |

GST rates are never configured here; they come from `tariff.tax_rate`. B2C place-of-supply
behaviour remains an `[ASSUMPTION]` until tax review.

## Errors

| Code | Status | Meaning |
|---|---|---|
| `INVOICE_NOT_FOUND` | 404 | Scoped invoice does not exist |
| `INVALID_STATUS_TRANSITION` | 409 | Draft/issued state does not allow it |
| `INVOICE_IMMUTABLE` | 409 | Issued financial row cannot change |
| `CREDIT_EXCEEDS_ORIGINAL` | 422 | Credit exceeds remaining amount |
| `CREDIT_APPROVAL_REQUIRED` | 409 | Second approver required |
| `TAX_RATE_MISSING` | 422 | No rate effective at tax point |
| `GSTIN_REQUIRED` | 422 | Issuer or recipient GSTIN missing |
| `PLACE_OF_SUPPLY_REQUIRED` | 422 | Place of supply missing |
| `EINVOICE_REGISTRATION_FAILED` | 502 | IRN registration failed |
| `CURRENCY_MISMATCH` | 422 | Inputs use different currencies |
| `NUMBER_SEQUENCE_EXHAUSTED` | 409 | Financial-year sequence exhausted |
| `PERIOD_CLOSED` | 409 | Ledger period rejects the posting |

## Security

`invoice.write` creates drafts; `invoice.issue` issues; `invoice.credit` creates and issues
credit notes. A partner user acts only for its own issuer or recipient side. GSTINs are
confidential and redacted in logs. Credit-note approval and period close use maker-checker
(`SEC-010`). Issued documents and journal links are audit evidence and MUST NOT be deleted.

## Observability

Metrics: drafts, issues, credit notes, e-invoice status, tax-rate misses, journal failures,
number-sequence use, and hold count. Logs carry invoice ID, number, and `partnerRef`; they never
carry full GSTINs or IRNs.

## Tests

| Test | Covers |
|---|---|
| `InvoiceGoldenIT` | Worked example, per-line tax, totals |
| `InvoiceImmutabilityIT` | Issued row and lines are frozen |
| `InvoiceNumberingIT` | Unique per issuer and financial year |
| `CreditNoteLimitIT` | Remaining creditable amount |
| `CreditNoteApprovalIT` | Threshold maker-checker |
| `InvoicePostingRollbackIT` | Ledger failure rolls back document |
| `SettlementHoldIT` | Dispute sets and clears hold |
| `TaxPointIT` | Rate effective at the chosen tax point |

```gherkin
Scenario: Issued invoice is atomic with its journal
  Given a valid draft invoice
  When issue is requested and the ledger rejects the period
  Then the invoice remains DRAFT
  And no invoice number is consumed
  And no journal exists

Scenario: Credit cannot exceed the invoice
  Given an issued invoice with a remaining creditable amount
  When a credit note exceeds it
  Then the request fails with CREDIT_EXCEEDS_ORIGINAL
  And no credit note or journal is written
```

## Phase plan

- Phase 5: V011, drafts, issue, tax lines, numbering, journal, e-invoice metadata.
- Phase 6: reconciliation reads issued documents.
- Phase 7: dispute sets and clears settlement holds through billing commands.
- Phase 8: settlement reads invoice eligibility and holds.

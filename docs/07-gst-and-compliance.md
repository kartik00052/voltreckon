# 07 — GST and compliance

- **Status:** Draft
- **Owner:** VoltReckon maintainer
- **Last verified:** 2026-11-13
- **Applies to phases:** 0–10

This file is a product and engineering contract, not legal advice. Rates, thresholds, and
commencement dates are configuration with an effective date. The tax reviewer must confirm
every number before Phase 5. Where a primary source is not pinned, the rule is marked
`[ASSUMPTION]` and cannot be the only basis of a MUST.

## 1. Classification of EV charging

The Ministry of Power clarified in 2018 that charging an electric vehicle is a service, not
a sale of electricity [ref-13]. The Karnataka Authority for Advance Ruling in
`KAR ADRG 24/2023` treated standalone EV charging as SAC `998714` at 18% [ref-14]. The AAR
binds its applicant; it is not a general circular and does not replace a notification.

**GST-001** A standalone charging service MUST be classified as SAC `998714` unless the
tax reviewer records a different classification for the specific supply. *Check:* invoice
line `hsn_sac` review; `GSTClassificationTest`.

**GST-002** The 18% treatment from the cited AAR MUST be configuration, not a hard-coded
rate. *Check:* no rate literal in `billing` or `rating`; effective-date test.

**GST-003** The AAR MUST NOT be cited as a general industry ruling. A different supply
structure, such as a consumer-owned charger with only electricity supplied, must be
classified separately. *Check:* review of the agreement and invoice description.

**GST-004** Goods classifications MUST NOT be applied to the charging service. Electricity
(HSN `2716`) and EV chargers (HSN `8504`) are goods notifications, not the service rate
[ref-15][ref-16]. *Check:* invoice line review.

## 2. Rate configuration

GST rates live in `tax_rate` and are selected by jurisdiction, service code, tax kind, and
effective date. A rate has a basis-point value (`1800` = 18.00%) and a validity window.

**GST-005** Every rate MUST have `effective_from`; `effective_to` is optional. A rate MUST
NOT be edited in place if it has been used on an issued document; a new row is created.
*Check:* migration and `TaxRateImmutabilityIT`.

**GST-006** A rate lookup MUST select the row effective at the document's tax point. It MUST
fail with `TAX_RATE_NOT_FOUND` rather than fall back to a default. *Check:* time-travel test.

**GST-007** Rate changes MUST be tested for at least 0%, 5%, 12%, 18%, 28%, and an exempt
supply. The exact current rates are data, not code. *Check:* rate matrix test.

**GST-008** The 2025 goods notifications are recorded for context only: electricity under
HSN `2716` is nil and EV chargers under HSN `8504` are 5%, effective 2025-09-22
[ref-15][ref-16]. These MUST NOT change the SAC `998714` service rate without a new tax
review. *Check:* review note in the phase log.

## 3. Place of supply and tax point

**GST-009** Every invoice MUST store `place_of_supply_state` and the issuer and recipient
GSTINs. *Check:* invoice schema and validation test.

**GST-010** The place of supply MUST be selected from the agreement and the tax review:
registered B2B recipient state by default, or the configured station/supplier state for B2C
where the applicable rule requires it [ref-6]. The exact B2C rule is `[ASSUMPTION]` until the
tax reviewer signs it. *Check:* invoice golden cases.

**GST-011** The tax point MUST be stored on the invoice (`SESSION_END` or `INVOICE_DATE`)
and used for rate selection. It MUST NOT be recomputed from the current date on a later
read. *Check:* invoice reload test.

**GST-012** An intra-state supply MUST use CGST + SGST; an inter-state supply MUST use IGST.
A union-territory case follows the configured rule. *Check:* split and IGST tests.

**GST-013** Tax on a line MUST use the rate and taxable amount stored on that line; the
invoice total MUST equal the sum of line taxable amounts plus the sum of tax lines.
*Check:* `InvoiceTotalsIT`.

## 4. Invoice content

**GST-014** An issued invoice MUST contain the particulars required by CGST Rule 46,
including supplier and recipient identity, GSTIN where applicable, invoice number and date,
SAC, description, quantity, taxable value, rate, tax amounts, place of supply, and the
signature/authentication field required by the output format [ref-5][ref-7].
*Check:* invoice contract test and tax review.

**GST-015** The invoice description MUST say “EV charging service” or an equivalent
unambiguous description; it MUST NOT describe the supply as a sale of electricity or a
charger. *Check:* invoice rendering test.

**GST-016** A B2C invoice MUST NOT invent a recipient GSTIN. A B2B invoice MUST have a valid
recipient GSTIN; otherwise it is a B2C invoice or it is rejected. *Check:* B2B/B2C matrix
test.

**GST-017** GSTIN MUST match the 15-character format and state code; the state code MUST
agree with the registered address used for the place of supply. *Check:* validation test.

## 5. Numbering

**GST-018** Invoice and credit-note numbers MUST be unique per issuer and financial year,
consecutive within a series, and at most 16 characters. The default format is
`INV/26-27/00001` for invoices and `CN/26-27/00001` for credit notes. *Check:* numbering
IT; unique index.

**GST-019** A number MUST be allocated only when the document is issued; a draft has no
number. A failed issue MUST NOT consume a number. *Check:* failure-path test.

**GST-020** The financial year is 1 April to 31 March in Asia/Kolkata. The invoice stores the
financial-year label; the number sequence is per issuer and label. *Check:* year-boundary
test with a mutable clock.

## 6. Credit notes

**GST-021** A credit note MUST reference the original invoice, state the reason, and reverse
the same taxable value and tax components as the original. It MUST NOT edit the invoice
[ref-8]. *Check:* credit-note IT.

**GST-022** A credit note MUST NOT exceed the remaining creditable amount of the invoice. A
full credit moves the invoice to `FULLY_CREDITED`; a partial credit moves it to
`PARTIALLY_CREDITED`. *Check:* limit and status tests.

**GST-023** A credit note is a new document with its own number; it is issued and immutable
after issue. *Check:* immutability IT.

## 7. E-invoice

E-invoice applies to B2B supplies above the notified AATO threshold. The threshold is
configuration. At the last verified check the threshold was ₹5 crore AATO from 2023-08-01
[ref-17], but it MUST be re-verified before Phase 5 `[ASSUMPTION]`. The e-invoice system
returns an IRN, acknowledgement, and QR payload; cancellation is allowed within 24 hours
[ref-9].

**GST-024** The invoice MUST store `e_invoice_status`, and when registered, the 64-character
IRN, acknowledgement number and date, and QR payload hash. *Check:* schema and e-invoice
test.

**GST-025** `e_invoice_status` MUST be `NOT_REQUIRED` when the recipient is B2C or the
issuer is below the configured threshold. It MUST NOT be silently `REGISTERED` without a
stored IRN. *Check:* applicability matrix test.

**GST-026** Automatic IRP submission is a T2 integration. T1 supports manual capture or
import of the IRN and QR hash; it MUST NOT claim an invoice is registered without those
fields. *Check:* phase review; no IRP client in T1 dependencies.

**GST-027** A cancelled e-invoice MUST be cancelled within 24 hours of registration and the
cancellation MUST be audited; after 24 hours the correction path is a credit note, not a
cancellation. *Check:* clock-boundary test.

## 8. DPDP and personal data

VoltReckon processes pseudonymous token and contract identifiers for billing. It does not
need driver names, phone numbers, email addresses, raw identity documents, or card data.
The DPDP Act, 2023 and the DPDP Rules, 2025 apply; commencement dates must be confirmed
from MeitY notifications before Phase 5 `[ASSUMPTION]` [ref-11].

**GST-028** Ingestion MUST reject or drop driver name, phone, email, and raw identity
documents. A token UID MAY be stored as a pseudonymous identifier with restricted access.
*Check:* PII scan test; log review.

**GST-029** Personal data MUST be collected for a stated billing or dispute purpose, kept
only as long as that purpose and the legal retention require, and not reused for an
unrelated purpose. *Check:* data inventory review.

**GST-030** A data-principal request, correction, or erasure request MUST be routed to the
maintainer's documented process; an erasure MUST NOT delete a financial record that must be
retained. *Check:* runbook review.

**GST-031** A personal-data breach MUST be triaged, contained, and notified through the
maintainer's incident process; the audit log records the incident action, not the personal
data itself. *Check:* incident tabletop before Phase 9.

**GST-032** A processor or partner that handles personal data MUST have a written data
processing term covering purpose, security, sub-processors, and deletion. *Check:* partner
onboarding checklist.

**GST-033** Logs, traces, and error details MUST NOT contain tokens, names, phone numbers,
card data, or bank credentials. *Check:* redaction test.

## 9. Records, returns, and disclaimers

**GST-034** VoltReckon MUST retain invoices, credit notes, journals, and audit records for
the period set by the tax/legal review. The application MUST NOT hard-delete them; archival
is a controlled export. *Check:* retention review.

**GST-035** VoltReckon MUST provide structured exports for a tax reviewer; it MUST NOT file
GST returns or represent itself as a certified tax engine. *Check:* scope review.

**GST-036** A GST or e-invoice change MUST update the configuration, the effective date, the
invoice golden tests, and this document in the same change. *Check:* change review.

## 10. Acceptance scenarios

```gherkin
Scenario: Intra-state B2B invoice
  Given a supplier and recipient in Karnataka with valid GSTINs
  And an effective SAC 998714 rate of 18%
  When an invoice is issued for 15,500 paise taxable
  Then CGST is 1,395 paise and SGST is 1,395 paise
  And the invoice total is 18,290 paise

Scenario: Inter-state B2B invoice
  Given a supplier in Karnataka and a recipient in Maharashtra
  When an invoice is issued for the same taxable amount
  Then IGST is 2,790 paise
  And no CGST or SGST line exists

Scenario: Rate change is effective-dated
  Given an 18% rate effective through 2026-03-31
  And a 12% rate effective from 2026-04-01
  When an invoice's tax point is 2026-04-01
  Then the 12% rate is used
  And the 18% rate is not changed

Scenario: E-invoice registration is recorded
  Given an applicable B2B invoice
  When the IRN, acknowledgement, and QR hash are captured
  Then the invoice status is REGISTERED
  And the 64-character IRN is stored

Scenario: Driver name is not stored
  Given a CDR containing a driver name
  When it is ingested
  Then the name is rejected or dropped
  And no log line contains the name
```

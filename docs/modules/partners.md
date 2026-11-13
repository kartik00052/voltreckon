# partners

- **Status:** Draft
- **Owner:** VoltReckon maintainer
- **Last verified:** 2026-11-13
- **Applies to phases:** 1-10

`partners` is the authoritative registry for CPO and eMSP identities, GST profiles, and
commercial agreements. It supplies partner scope and status to `iam` and agreement terms to
`rating`, `billing`, and `settlement`. Rules are `PART-001`-`PART-010`; tax policy is owned by
[07-gst-and-compliance.md](../07-gst-and-compliance.md).

## Purpose

Give every module one source of truth for who a partner is, which roles it holds, which GSTIN
applies, and which agreement governs a partner pair and period.

## Scope

In scope: partner identity (`country_code`, `party_id`), CPO/eMSP roles, status, GSTIN history,
and agreement lifecycle. Out of scope: users, tariffs, CDRs, invoices, journals, settlement,
and dispute cases. Tariff-version links are owned by `tariff`; this module exposes the
agreement query used by that link.

## Public API

- `RegisterPartnerCommand`, `ChangePartnerStatusCommand`.
- `PartnerQuery` by ID or `(country_code, party_id)`, scoped for partner users.
- `GstProfileQuery` returning the primary GSTIN effective on a date.
- `AgreementQuery` for an active agreement on a partner pair and instant.
- `CreateAgreementCommand`, `ActivateAgreementCommand`, `TerminateAgreementCommand`.
- `partners.partner.created.v1`, `partners.partner.updated.v1`, and
  `partners.agreement.activated.v1` events.

No entity or repository is public. Agreement tariff links are read through the `tariff`
public API.

## Domain model

`Partner` has a pair identity, legal and display names, country, party ID, roles, and status
(`ACTIVE`, `SUSPENDED`, `TERMINATED`). `Gstin` is an effective-dated value with state code and
primary flag. `Agreement` has CPO and eMSP parties, reference, currency, settlement cycle,
payment terms, billing-period basis, status, and effective window. Status transitions are
`DRAFT -> ACTIVE -> TERMINATED`; no row is deleted.

## Owned data

`partner`, `partner_role` in V003; `partner_gstin`, `partner_agreement` in V005. The
`agreement_tariff_link` table is owned by `tariff`, not here. No financial row is owned.

## Invariants

**PART-001** `(country_code, party_id)` MUST be unique; changing either value MUST create a new
partner, not mutate identity. *Check:* unique index and API test.

**PART-002** A partner MUST have at least one role from `CPO` and `EMSP`. *Check:* service
test and role query.

**PART-003** A terminated partner MUST NOT be reactivated; a new registration is required.
*Check:* state-machine test.

**PART-004** A GSTIN MUST be 15 characters, match the GSTIN format, and agree with the state
code in its first two characters. *Check:* `GstinTest` and database check.

**PART-005** A partner MUST have at most one primary GSTIN at a time; the effective window of
a primary GSTIN MUST NOT overlap another primary GSTIN for the same partner. *Check:* partial
unique index and GSTIN IT.

**PART-006** An agreement MUST join one CPO and one eMSP; the parties MUST differ and both MUST
hold the required role. *Check:* service test.

**PART-007** Active agreements for the same partner pair MUST NOT overlap in effective dates.
*Check:* exclusion constraint and agreement IT.

**PART-008** An agreement MAY be activated before a tariff version is linked. Until a
published version is linked, rating MUST fail with `MISSING_TARIFF`; `partners` MUST NOT
validate the link because it does not depend on `tariff`. *Check:* activation IT and rating
failure IT.

**PART-009** An agreement currency, settlement cycle, payment terms, and billing-period basis
MUST be immutable after activation; a change requires a new agreement. *Check:* immutability
test.

**PART-010** Partner creation, status change, and agreement activation MUST publish their
catalog event in the same transaction as the row change. *Check:* outbox rollback IT.

## Transactions

Partner and agreement commands use one local transaction with the `platform` outbox.
Activation does not read or write `agreement_tariff_link`; `tariff` owns that link and
validates it when the link is created. Status changes take effect for `iam` at the next
authorization decision (IAM-006). No remote call occurs inside the transaction.

## Events

Producers: `partners.partner.created.v1`, `partners.partner.updated.v1`, and
`partners.agreement.activated.v1`. Consumers: `audit` and `reporting`; `iam` uses the public
partner query, not an event. Payloads carry IDs, roles, changed field names, and currency, with
no names, GSTINs, or contact data.

## Dependencies

`shared` and `platform` only. `partners` MUST NOT depend on `iam`, `tariff`, `ingestion`,
`rating`, `billing`, `ledger`, `dispute`, `reconciliation`, `settlement`, `audit`, or
`reporting`. Tariff links are created by `tariff` after it reads the agreement query.

## Configuration

| Key | Default | Purpose |
|---|---|---|
| `voltreckon.partners.gstin-regex` | configuration | GSTIN validation |
| `voltreckon.partners.settlement-cycles` | `MONTHLY,WEEKLY,ON_DEMAND` | Allowed cycles |
| `voltreckon.partners.billing-bases` | `SESSION_START,SESSION_END,INVOICE_DATE` | Allowed bases |
| `voltreckon.partners.max-payment-terms` | `90` | Contract guardrail |

GST rates are not configured here; they belong to `tariff.tax_rate`.

## Errors

| Code | Status | Meaning |
|---|---|---|
| `PARTNER_NOT_FOUND` | 404 | Scoped partner does not exist |
| `DUPLICATE_PARTY` | 409 | Country/party already registered |
| `INVALID_GSTIN` | 400 | GSTIN format or state mismatch |
| `GSTIN_OVERLAP` | 409 | Primary GSTIN window overlaps |
| `AGREEMENT_NOT_FOUND` | 404 | Scoped agreement does not exist |
| `AGREEMENT_OVERLAP` | 409 | Active agreement overlaps |
| `AGREEMENT_NOT_ACTIVE` | 409 | Agreement is not active |
| `PARTNER_TERMINATED` | 409 | Terminated partner cannot change |
| `AGREEMENT_IMMUTABLE` | 409 | Activated terms cannot change |

## Security

Partner registration and status changes require `PLATFORM_ADMIN`. A partner user may read its
own profile and create or activate its own agreement with `partner.write`; it MUST NOT name
another partner. GSTIN and agreement terms are confidential commercial data: they are returned
only in partner scope and never in logs, events, or reports beyond the minimum. Every status
change is audited (`SEC-036`).

## Observability

Metrics: registrations, active/suspended/terminated counts, GSTIN validation failures,
agreement activation latency, overlap rejections. Logs carry `partnerRef` and `traceId`; GSTINs
are redacted to the last four characters.

## Tests

| Test | Covers |
|---|---|
| `PartnerUniquenessIT` | Country/party uniqueness |
| `GstinTest` | Format, state code, primary overlap |
| `AgreementOverlapIT` | Active agreement exclusion |
| `AgreementActivationIT` | Activation does not depend on a tariff link |
| `PartnerStatusIT` | Terminated cannot reactivate |
| `PartnerEventIT` | Event and row commit together |

```gherkin
Scenario: Overlapping active agreements are rejected
  Given an active agreement for CPO A and eMSP B
  When a second active agreement overlaps its effective window
  Then the request fails with AGREEMENT_OVERLAP
  And the existing agreement is unchanged

Scenario: Primary GSTIN cannot overlap
  Given partner A has a primary GSTIN from 1 April
  When a second primary GSTIN starts 1 May
  Then the request fails with GSTIN_OVERLAP
```

## Phase plan

- Phase 1: V003, partner identity, roles, status.
- Phase 2: V005, GST profiles, agreements, activation, events.
- Phase 5: billing reads GST profile and agreement terms; no new dependency direction.

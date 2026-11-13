# tariff

- **Status:** Draft
- **Owner:** VoltReckon maintainer
- **Last verified:** 2026-11-13
- **Applies to phases:** 2-10

`tariff` owns tariffs, immutable published versions, price components, restrictions,
effective-dated tax rates, and the link from an agreement to a tariff version. It answers the
one question rating must not guess: which version and which tax rate are effective at an
instant. Rules are `TAR-001`-`TAR-010`; arithmetic is owned by
[05-financial-model.md](../05-financial-model.md).

## Purpose

Provide a deterministic, auditable price and tax configuration for every CDR, with a version
selected by the session start instant and never by the run time.

## Scope

In scope: tariff identity, draft and published versions, components, restrictions, tax rates,
and agreement-version links. Out of scope: CDRs, rating arithmetic, invoices, journals, and
partner registry data. GST policy is owned by [07-gst-and-compliance.md](../07-gst-and-compliance.md);
rates are configuration, never code constants.

## Public API

- `CreateTariffCommand`, `CreateDraftVersionCommand`, `PublishVersionCommand`.
- `LinkAgreementTariffCommand` (the owner of `agreement_tariff_link`).
- `TariffQuery` by ID, code, or partner.
- `EffectiveTariffQuery` returning the published version for an agreement at an instant.
- `TaxRateQuery` returning the rate effective at a tax point.
- `tariff.tariff.published.v1` event.

## Domain model

`Tariff` is a partner-owned identity. `TariffVersion` has a version number, status (`DRAFT`,
`PUBLISHED`, `RETIRED`), currency, effective window, and canonical content hash.
`PriceComponent` has an element order, type, price, step, unit, and tax-rate reference.
`Restriction` filters by time, day, duration, energy, power, or current. `TaxRate` has a
jurisdiction, service code, kind, basis points, and effective window. `AgreementTariffLink`
joins one active agreement to one published version.

## Owned data

`tax_rate`, `tariff`, `tariff_version`, `tariff_price_component`, `tariff_restriction`, and
`agreement_tariff_link` in V007. Tax rates are effective-dated rows; a rate change is a new
row, not an update.

## Invariants

**TAR-001** A published version MUST be immutable; a price, component, restriction, currency,
or window change MUST create a new draft version. *Check:* trigger and publish IT.

**TAR-002** Published effective windows for the same tariff MUST NOT overlap. *Check:*
exclusion constraint and boundary IT.

**TAR-003** A price MUST be non-negative, a step MUST be greater than zero, and
`(version, element_order, component_type)` MUST be unique. *Check:* database checks and
component test.

**TAR-004** A restriction MUST only filter components; it MUST NOT add a charge or change a
unit price. *Check:* restriction matrix test.

**TAR-005** A tax rate MUST be between 0 and 10,000 basis points and MUST have a non-overlapping
effective window for the same jurisdiction, service code, and kind. *Check:* check constraint
and tax-rate IT.

**TAR-006** A link MUST reference an `ACTIVE` agreement and a `PUBLISHED` version in the same
currency; a terminated agreement or draft version MUST be rejected. *Check:* link IT.

**TAR-007** Effective selection MUST return exactly one version for an agreement and instant,
or `MISSING_TARIFF`; it MUST NOT fall back to the latest version. *Check:* boundary test at
`effective_from` and `effective_to`.

**TAR-008** Publishing and linking MUST write the row and the outbox event in one transaction.
*Check:* outbox rollback IT.

**TAR-009** The version content hash MUST be computed over a canonical serialization of the
version, components, restrictions, currency, window, and tax-rate IDs. *Check:* hash stability
test.

**TAR-010** GST rates, SAC codes, and tax kinds MUST be effective-dated configuration, never a
hard-coded constant in code. *Check:* code review and tax-rate seed test.

## Transactions

Draft creation and component edits use one local transaction. Publication validates the
complete version, computes the hash, changes status, and writes the event atomically. Linking
reads the agreement through the `partners` public query and the version through its own state
in the caller's transaction; it does not start an independent transaction. Rating reads the
effective version and tax rate through public queries, never through tariff tables.

## Events

Producer: `tariff.tariff.published.v1` with tariff ID, version ID, effective window, currency,
and hash. Consumers: `rating`, `audit`, and `reporting`. Rating still performs a synchronous
effective query at rating time; the event is a notification, not the selection mechanism.

## Dependencies

`shared`, `platform`, and `partners`. `tariff` MUST NOT depend on `ingestion`, `rating`,
`billing`, `ledger`, `dispute`, `reconciliation`, `settlement`, `audit`, or `reporting`.

## Configuration

| Key | Default | Purpose |
|---|---|---|
| `voltreckon.tariff.zone` | `Asia/Kolkata` | Business-date interpretation |
| `voltreckon.tariff.max-versions` | `1000` | Per-tariff guardrail |
| `voltreckon.tariff.max-components` | `50` | Per-version guardrail |
| `voltreckon.tariff.tax-kinds` | `GST,VAT,NONE` | Allowed kinds |
| `voltreckon.tariff.default-sac` | `998714` | Invoice default, not a rate |

## Errors

| Code | Status | Meaning |
|---|---|---|
| `TARIFF_NOT_FOUND` | 404 | Scoped tariff does not exist |
| `VERSION_NOT_FOUND` | 404 | Version does not exist |
| `VERSION_OVERLAP` | 409 | Published windows overlap |
| `TARIFF_IMMUTABLE` | 409 | Published version cannot change |
| `TAX_RATE_OVERLAP` | 409 | Tax-rate window overlaps |
| `INVALID_TAX_RATE` | 400 | Rate outside 0..10000 bp |
| `AGREEMENT_NOT_ACTIVE` | 409 | Link target agreement is not active |
| `VERSION_NOT_PUBLISHED` | 409 | Link target version is not published |
| `CURRENCY_MISMATCH` | 409 | Agreement and version currencies differ |
| `MISSING_TARIFF` | 422 | No version effective at the instant |

## Security

`tariff.write` creates and publishes a partner's own tariff; `tax.write` is required for a tax
rate. A partner MUST NOT publish or link another partner's tariff. Tax rates are global
configuration and require `PLATFORM_ADMIN` or a finance administrator with `tax.write`.
Published versions are audit evidence and MUST NOT be deleted.

## Observability

Metrics: publishes, publish failures, effective-query misses, link rejections, tax-rate changes,
and version count per tariff. Logs carry tariff and version IDs, never full component payloads.

## Tests

| Test | Covers |
|---|---|
| `EffectiveBoundaryIT` | Start/end instant selection |
| `VersionOverlapIT` | Exclusion constraint |
| `PublishImmutabilityIT` | No change after publish |
| `TaxRateWindowIT` | Effective-dated rate lookup |
| `AgreementLinkIT` | Active agreement, published version, currency |
| `TariffHashTest` | Canonical content hash |

```gherkin
Scenario: Session start selects the old version after a publish
  Given version 1 is effective from 1 April
  And version 2 is effective from 1 May
  When a CDR starts on 30 April and rating runs on 2 May
  Then version 1 is selected
  And the variance does not mutate version 1

Scenario: A draft version cannot be linked
  Given a draft tariff version
  When an active agreement links it
  Then the request fails with VERSION_NOT_PUBLISHED
```

## Phase plan

- Phase 2: V007, tariff identity, versions, components, tax rates, links.
- Phase 3: rating consumes the effective query and published event.
- Phase 5: billing uses the tax-rate query at the invoice tax point.

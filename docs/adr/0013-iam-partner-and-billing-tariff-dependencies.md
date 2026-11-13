# ADR-0013 - IAM partner and billing tariff dependencies

- **Status:** Accepted
- **Date:** 2026-11-13
- **Deciders:** VoltReckon maintainer
- **Applies to phases:** 2-5
- **Amends:** [ADR-0007](0007-module-set-and-dependencies.md)

## Context

ADR-0007 fixed the module set and allowed `iam` to depend only on `shared` and `platform`,
and `billing` on `partners`, `rating`, and `ledger`. The Batch 2 data model exposed two
requirements that the graph cannot express without an unsafe workaround:

- `iam.app_user` stores the partner scope for a user, and partner suspension must take effect
  at the next request (`SEC-016`). Without a `partners` dependency, IAM can only trust an
  opaque UUID and cannot validate the partner or observe suspension.
- `billing.invoice_tax_line` records the effective `tax_rate` used at the invoice tax point.
  Tax rates are owned by `tariff`; without a `tariff` dependency, billing would duplicate tax
  rate data or read another module's table, violating `ARCH-014`.

Both requirements are synchronous and inside the caller's transaction. Neither needs a new
module, a remote call, or an asynchronous contract.

## Decision

- Add the edge `iam -> partners` for partner existence, status, and scope validation through
  the `partners` public query API.
- Add the edge `billing -> tariff` for effective-dated tax-rate lookup through the `tariff`
  public query API. Billing still stores the rate snapshot on its own tax lines.
- Update the legal dependency order to:
  `shared`, `platform`, `partners`, `iam`, `tariff`, `ingestion`, `ledger`, `rating`,
  `billing`, `dispute`, `reconciliation`, `settlement`, `audit`, `reporting`.
- ADR-0007 remains accepted for the module set, the ledger leaf, and the audit/reporting sink
  rules. This ADR changes only the two edges and the order above.

## Alternatives considered

| Alternative | Why rejected | Revisit trigger |
|---|---|---|
| Keep `iam.partner_id` as an opaque UUID | A terminated or suspended partner could keep valid user sessions, and an invalid scope could be stored silently. | An external identity provider that asserts partner status and is authoritative for suspension. |
| Keep `invoice_tax_line.tax_rate_id` without a FK | Billing would still need tax-rate data; copying it creates a second source of truth and drifts on rate changes. | Tax rates move to a separate tax service. |
| Move tax rates into `billing` | Tax policy is configuration shared with rating and tariff; a second owner breaks one-owner-per-table. | Tax becomes a billing-only concern, which it is not. |
| Add a new `tax` module | Adds a module and edges without a distinct lifecycle; `tariff` already owns values and effective dates. | Tax rules gain independent approval or jurisdiction workflows. |

## Consequences

- Positive: IAM can reject an unknown partner at provisioning and enforce suspension on the
  next request.
- Positive: billing can resolve the tax rate at the invoice tax point without duplicating the
  tariff table.
- Negative: `iam` and `billing` gain one provider dependency each; the architecture test table
  and FK matrix must be updated together.
- Negative: the legal order changes, so the dependency test must be regenerated rather than
  hand-edited.
- Migration: no schema change; the existing `app_user.partner_id` and
  `invoice_tax_line.tax_rate_id` FKs remain valid.

## References

- [03-architecture.md](../03-architecture.md)
- [04-data-model.md](../04-data-model.md)
- [07-gst-and-compliance.md](../07-gst-and-compliance.md)
- [09-security.md](../09-security.md)
- [ADR-0007](0007-module-set-and-dependencies.md)

## Review trigger

A new module owns partner status or tax rates, or an external identity provider becomes the
authoritative source for tenant suspension.

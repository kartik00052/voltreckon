# ADR-0005: Target OCPI 2.3.0 CDRs and Invoice Reconciliation, with 2.2.1 compatibility

- **Status:** Accepted
- **Date:** 12 November 2026
- **Deciders:** VoltReckon maintainers

## Context

OCPI is the de facto network-to-network protocol between CPOs and eMSPs. Version 2.3.0 is current; edition 2 (18 June 2026) added an Invoice Reconciliation module. OCPI 2.2.1 is widely deployed in India and elsewhere. OCPI 3.0 is in draft.

VoltReckon needs a stable integration contract without coupling its domain model to a protocol draft.

## Decision

- **Domain model is VoltReckon's own.** No OCPI types, field names, or JSON structures in `domain` or `application` packages.
- **MVP ingestion** supports OCPI 2.2.1 and 2.3.0 CDRs (JSON) and CSV exports.
- **Target semantics** are 2.3.0, including:
  - Immutable CDRs and Credit CDRs with `credit` and `credit_reference_id`.
  - Invoice Reconciliation concepts for matching and exceptions.
- **Full OCPI endpoint suite** (versions, credentials, locations, tariffs, sessions, commands, invoice reconciliation) is **Phase 2**.
- **OCPI 3.0 is not a dependency** until it is stable and partners adopt it.
- Version-specific mapping lives in `integration.ocpi`, behind ports.

## Alternatives considered

1. **Implement a full OCPI server first.** Rejected: delays the core financial workflow and adds credential/hub complexity before the domain is proven.
2. **Proprietary API only.** Rejected: excludes partners and ignores an existing standard.
3. **Adopt OCPI types as the domain model.** Rejected: protocol churn would leak into financial logic; OCPI is transport, not the business model.
4. **Target OCPI 3.0 draft.** Rejected: unstable.

## Consequences

**Positive**

- Standards-aligned ingestion and reconciliation.
- Compatibility with partners on 2.2.1.
- Domain remains stable if OCPI changes.
- Smaller MVP surface.

**Negative**

- Adapter mapping and fixture maintenance for two versions.
- Full OCPI certification is deferred; partners may require it earlier.
- The 2026 Invoice Reconciliation module is new and its Indian adoption is unproven.

## Revisit triggers

- A design partner requires the full OCPI server.
- OCPI 3.0 becomes stable and widely adopted.
- The Invoice Reconciliation module changes in a way that affects the internal model.

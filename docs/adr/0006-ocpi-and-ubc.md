# ADR-0006 — OCPI compatibility and UBC positioning

- **Status:** Accepted
- **Date:** 2026-11-13
- **Deciders:** VoltReckon maintainer
- **Applies to phases:** 0–10

## Context

Existing roaming partners exchange OCPI 2.2.1 CDRs. The current specification is OCPI
2.3.0, and the 2026-06-18 edition adds Invoice Reconciliation [ref-1][ref-2][ref-3]. UBC is
Beckn-based, not OCPI, and has a different onboarding and message model [ref-27]. Treating
all three as one protocol would break compatibility and hide version differences.

## Decision

- **OCPI 2.2.1 is the compatibility baseline** for CDR intake. The ingestion model must
  accept the 2.2.1 fields that exist in practice, including `cdr_token`, `cdr_location`,
  `credit`, `credit_reference_id`, and `home_charging_compensation` [ref-1].
- **OCPI 2.3.0 is the target contract** for new development. Version-specific differences
  are explicit in the mapping layer, not spread through the domain.
- **OCPI 2.3.0-ed2 Invoice Reconciliation** is a Phase 10 capability [ref-4]. It is not
  retrofitted into the Phase 1 CDR model.
- UBC/Beckn is a **separate adapter** at the edge. It MUST NOT become a core dependency or
  change the financial model in T1. There is no UBC implementation until an official
  specification and onboarding path exist.
- The internal domain uses VoltReckon names, not OCPI JSON names. A single mapping module
  translates external payloads to internal commands.
- Unknown OCPI fields are ignored during ingestion and retained only if a documented
  compatibility need exists; they are not persisted as an unbounded JSON blob by default.

## Alternatives considered

| Alternative | Why rejected | Revisit trigger |
|---|---|---|
| OCPI 2.3.0 only | Breaks existing 2.2.1 partners and contradicts the product requirement. | Every active partner supports 2.3.0 and a migration window has passed. |
| OCPI 2.2.1 only | Misses the target contract and the invoice-reconciliation module. | Never; target edition is required. |
| UBC as the core protocol | Different network model; would delay OCPI delivery and confuse the domain. | An official UBC specification and a contracted partner require it. |
| Store raw OCPI JSON for every CDR | Creates a second unbounded source of truth and personal-data risk. | A specific audit or replay requirement justifies a bounded raw payload. |

## Consequences

- Positive: existing partners can connect while the target edition is developed.
- Positive: protocol changes stay at the edge; the rating and ledger models are stable.
- Negative: two mapping paths need contract tests and fixtures.
- Negative: Phase 10 adds a mutable Invoice Reconciliation object; it must not alter issued
  invoices.
- Migration: 06-ocpi-integration owns the field matrix and rejection codes.
- Follow-up: add 2.3.0-ed2 fixtures when Phase 10 starts, not before.

## References

- [06-ocpi-integration.md](../06-ocpi-integration.md)
- [ref-1], [ref-2], [ref-3], [ref-4], [ref-27]

## Review trigger

A partner requires a different OCPI edition, UBC publishes an implementable specification,
or OCPI 2.3.0-ed2 changes the CDR or invoice-reconciliation contract.

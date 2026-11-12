# ADR-0007: Complement UBC/UEI; do not rebuild them

- **Status:** Accepted
- **Date:** 12 November 2026
- **Deciders:** VoltReckon maintainers

## Context

India is building public digital infrastructure for EV charging:

- **UEI** (Unified Energy Interface), a Beckn-based energy transaction network promoted in 2024.
- **UBC** (Unified Bharat e-Charge), unveiled 12 May 2026 by the Ministry of Heavy Industries with BHEL and NPCI BHIM Services, Beckn-based, with UPI QR payments and reported pilots in Maharashtra, Karnataka, Delhi-NCR, Haryana, and Rajasthan.

These initiatives target consumer discovery, ordering, and payment interoperability. Public B2B specifications and onboarding are still maturing.

At the same time, CPOs and eMSPs still need CDR exchange, re-rating, GST invoices, reconciliation evidence, disputes, and settlement netting between organisations.

## Decision

- VoltReckon **complements** UBC/UEI. It is not a consumer app, a Beckn gateway, a roaming hub, or a payment processor.
- The MVP does **not** integrate with UBC/UEI.
- Phase 2 adds a **feature-flagged anti-corruption adapter** behind a port, built only against official material.
- Until certified/onboarded, any UBC adapter is labelled **experimental**; no claim of integration or endorsement.
- Keep UBC/Beckn types out of the domain model.

## Alternatives considered

1. **Build a consumer app on UBC.** Rejected: crowded, capital-intensive, and not the identified gap.
2. **Build a Beckn gateway/roaming hub.** Rejected: network effects, certification, and operational scale are not achievable for this project.
3. **Ignore UBC entirely.** Rejected: it will affect transaction data and partner expectations; an adapter path should exist.
4. **Depend on UBC for core value.** Rejected: specifications are immature and outside our control.

## Consequences

**Positive**

- Clear, defensible scope.
- No dependency on unfinished public specifications.
- The core financial workflow is independently valuable.
- A clean integration path when UBC matures.

**Negative**

- If UBC exposes full B2B settlement data, some of VoltReckon's value may be absorbed.
- No early-mover advantage in the UBC ecosystem.
- The adapter will require rework as specifications change.

## Revisit triggers

- Official UBC B2B specifications and onboarding are published.
- A design partner requires UBC transaction ingestion.
- UBC exposes reconciliation or settlement APIs that change the value proposition.

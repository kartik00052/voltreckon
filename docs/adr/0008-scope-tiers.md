# ADR-0008 — Scope tiers and deferral triggers

- **Status:** Accepted
- **Date:** 2026-11-13
- **Deciders:** VoltReckon maintainer
- **Applies to phases:** 0–10

## Context

A single maintainer cannot build every integration before the core financial trail works. At
the same time, deleting deferred work loses the reasoning and invites ad-hoc additions.
Infrastructure such as Kafka, Redis, and observability stacks is often added before a
measured need, which increases failure modes without improving the core.

## Decision

- Three ordered tiers are defined in [01-product-scope.md](../01-product-scope.md):
  - **T1 core**: phases 1–9, the full CDR-to-settlement trail on one deployable and one
    PostgreSQL database.
  - **T2 advanced**: deferred with an explicit trigger for each item.
  - **T3 advisory**: optional analysis that never posts, rates, taxes, approves, or settles.
- No T2 item starts before its trigger is met and an ADR records the decision.
- No T3 output is an input to a financial posting, tax amount, approval, or settlement.
- Deferred items stay in the scope document with their trigger; they are never silently
  removed.
- The T2 triggers are the only accepted reasons to reopen the architecture in this phase:
  Kafka, OTel/Prometheus/Grafana/Loki/Tempo, MinIO/S3 evidence, PDF+QR invoices,
  multi-currency settlement, full OCPI receiver suite, IRP production integration, UBC/Beckn,
  Spring Batch, and Redis.

## Alternatives considered

| Alternative | Why rejected | Revisit trigger |
|---|---|---|
| Build T1 and T2 together | Spreads a single maintainer across infrastructure and domain; delays a provable financial trail. | A trigger is met and an ADR is accepted. |
| Minimal invoice-only MVP | Cannot prove settlement, reconciliation, or audit; the product’s value is the trail. | Never; T1 is the minimum coherent product. |
| Add AI scoring to prioritise disputes | Untestable as a financial control and creates a dependency that cannot be the basis of a posting. | A T3 use case remains read-only and advisory, with human review. |
| Defer by deleting from docs | Loses triggers and encourages scope creep. | Never; keep the record. |

## Consequences

- Positive: a clear build order and a defensible “not now” answer.
- Positive: infrastructure arrives only with evidence.
- Negative: some partner requests wait for a phase or a trigger.
- Negative: the maintainer must record trigger evidence, not just assert it.
- Follow-up: each phase exit in [14-roadmap.md](../14-roadmap.md) names the T2 items it did
  not start.

## References

- [01-product-scope.md](../01-product-scope.md)
- [14-roadmap.md](../14-roadmap.md)

## Review trigger

A T2 trigger is met, a T3 use case is proposed, or the maintainer changes the tier boundary.

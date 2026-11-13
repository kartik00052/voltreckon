# ADR-0007 — Module set and dependencies

- **Status:** Accepted
- **Date:** 2026-11-13
- **Deciders:** VoltReckon maintainer
- **Applies to phases:** 0–10

## Context

The Phase 0 scaffold contains thirteen module packages and no `rating` package. Rating is a
distinct step with its own deterministic rules and variance records. Agreements are
commercial terms between partners and belong with the partner registry, not in a separate
top-level module. The ledger must remain usable without any domain concept. Reporting and
audit must not become hidden dependencies of the write path.

## Decision

- Modules: `shared`, `platform`, `iam`, `partners`, `ingestion`, `tariff`, `ledger`,
  `rating`, `billing`, `dispute`, `reconciliation`, `settlement`, `audit`, `reporting`.
- `shared` and `platform` are documented together as `modules/shared-platform.md`.
- Agreements and GST profiles live in `partners`, not in a separate `agreement` module.
- `rating` is a first-class module, created before Phase 3.
- `ledger` is a leaf: it depends only on `shared`.
- `audit` and `reporting` are sinks: no domain module depends on them.
- The only legal dependency directions are recorded in
  [03-architecture.md](../03-architecture.md). A new edge requires a new ADR.
- `audit` may import public event types; `reporting` may import public query APIs. Neither
  may import another module's `internal` package.

## Alternatives considered

| Alternative | Why rejected | Revisit trigger |
|---|---|---|
| Keep the scaffold’s thirteen modules without `rating` | Puts rating inside billing or ingestion, mixes pricing policy with document issuance, and makes variance ownership unclear. | Never; rating is a distinct phase. |
| Separate `agreement` module | Adds a module and a dependency edge without a distinct lifecycle; agreements are partner commercial terms. | Agreements gain independent workflows, approvals, or a separate team. |
| Rating as a service | Network boundary for a pure deterministic calculation; adds latency and operations. | A measured throughput or isolation need, with an ADR. |
| Let `ledger` depend on billing for convenience | Destroys the leaf invariant and creates a cycle with billing’s posting dependency. | Never. |
| Let modules depend on `audit` for logging | Couples the write path to the audit sink and creates cycles. | Never; events are the contract. |

## Consequences

- Positive: rating and variance have one owner; agreements stay with partners.
- Positive: the ledger is testable with synthetic journals and no domain fixtures.
- Positive: audit and reporting can be added late without changing write-path dependencies.
- Negative: billing and settlement need explicit public commands for ledger posting.
- Negative: the scaffold needs a `rating` package and module declaration before Phase 3.
- Migration: create `com.voltreckon.rating` and add it to `ApplicationModules.verify()`.
- Follow-up: architecture tests encode the full graph, not just “no internal imports”.

## References

- [03-architecture.md](../03-architecture.md)
- [ADR-0012](0012-archunit.md)
- [14-roadmap.md](../14-roadmap.md)

## Review trigger

A new module is proposed, an existing module splits, or a measured requirement forces a
dependency that the graph does not allow.

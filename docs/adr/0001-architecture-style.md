# ADR-0001: Use a modular monolith with hexagonal module boundaries

- **Status:** Accepted
- **Date:** 12 November 2026
- **Deciders:** VoltReckon maintainers

## Context

VoltReckon's MVP crosses several capabilities that share strong transactional invariants:

- Invoice lines, tax lines, and the invoice header must be written atomically.
- A journal entry must balance at commit.
- A rating result must pin the exact tariff version and input hash used.
- A settlement item must not be settled twice.
- A CDR is immutable, so corrections require a linked Credit CDR.

The first release is scoped for one developer, modest volume (tens of thousands of CDRs per day at target), and a small operational budget. The system still needs boundaries that can survive growth; an unmodularised monolith would decay, while microservices would replace local transactions with sagas and distributed failure modes before there is evidence they are needed.

## Decision

Build a **modular monolith**: one Spring Boot deployable, one PostgreSQL database, and explicit module boundaries enforced by Spring Modulith and ArchUnit.

Each module uses hexagonal packaging:

```
module
├── domain          # entities, value objects, policies; no Spring/JPA/Jackson
├── application     # use cases, transactions, ports
├── adapter.in.*    # REST, CSV, schedulers
└── adapter.out.*   # JPA, events, external clients
```

Rules:

- A module may depend on another module's application API by ID and published DTOs.
- A module must not import another module's JPA entities, repositories, or adapter packages.
- Cross-module side effects use internal events persisted through the transactional outbox.
- `ledger` is a leaf; it does not depend on domain modules.
- Domain code is testable without Spring.
- Spring Modulith verification and ArchUnit rules fail the build.

## Alternatives considered

1. **Microservices per capability.** Rejected for the MVP: local financial transactions become sagas; network partitions, retries, distributed tracing, and multiple deploys add cost without a measured scaling or team boundary.
2. **Unmodularised layered monolith.** Rejected: boundaries erode without enforcement; shared tables become hidden coupling.
3. **Modular monolith with OSGi or separate classloaders.** Rejected: runtime complexity for a benefit build-time verification already provides.
4. **Serverless functions.** Rejected: poor fit for long financial transactions, relational constraints, and restartable batch work.
5. **Event sourcing as the primary style.** Rejected: replay/versioning/projection overhead; an append-only ledger plus audit log provides the required trail.

## Consequences

**Positive**

- Strong local transactions and database-enforced invariants.
- One artifact, one database, one backup/restore procedure.
- Module boundaries are verifiable in CI, not just documented.
- A module can be extracted later if a real scaling, team, or regulatory boundary appears.
- Domain tests run without Spring and protocol types stay out of the core.

**Negative**

- Boundaries require discipline and tooling; Spring Modulith and ArchUnit must run in CI.
- One deployment unit means one release cadence.
- A runaway module can consume shared CPU, memory, or database connections.
- More packages and mapping code than a layer-first monolith.

## Revisit triggers

Extract a module into a service only if at least one is true and measured:

- The module needs roughly 10× the scaling of the rest.
- A separate team needs independent deploys.
- A regulatory or data-residency boundary requires it.
- Transactional coupling has already been removed and proven stable.

Until then, keep the modular monolith. See [architecture overview](../architecture/architecture-overview.md) and [module boundaries](../architecture/module-boundaries.md).

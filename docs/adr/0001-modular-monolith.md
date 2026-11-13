# ADR-0001 — Modular monolith

- **Status:** Accepted
- **Date:** 2026-11-13
- **Deciders:** VoltReckon maintainer
- **Applies to phases:** 0–10

## Context

The domain spans ingestion, rating, billing, ledger, disputes, reconciliation, and
settlement. A single maintainer must deliver a correct financial trail before a team exists.
Network boundaries would add deployment, tracing, retry, and consistency costs that are not
justified by the current load. The financial invariants are easier to prove when the
document, its journal, and its outbox row commit in one database transaction.

## Decision

VoltReckon is a modular monolith: one Spring Boot deployable, one PostgreSQL 18 database,
one schema `voltreckon`, and Spring Modulith modules under `com.voltreckon.<module>`.
Modules expose a public API and keep implementation under `internal`. Cross-module writes
use public commands; cross-module asynchronous work uses the transactional outbox. The
module graph is fixed in [ADR-0007](0007-module-set-and-dependencies.md).

## Alternatives considered

| Alternative | Why rejected | Revisit trigger |
|---|---|---|
| Microservices per domain | Distributed transactions, service discovery, and independent deploys are overhead before a second team or measured scaling need. | A module needs an independent release cadence or a measured resource limit that one process cannot meet. |
| Layered monolith without modules | Invites cross-cutting imports and makes financial boundaries unenforceable. | Never; module rules are the point. |
| Modular monolith with one database per module | Breaks atomic document-plus-journal posting and adds operational cost. | A legal or isolation requirement forces separate data stores. |
| Event-sourced core | Higher complexity and migration cost without a proven audit requirement beyond the append-only ledger and audit chain. | A regulator requires full state reconstruction or temporal queries that the ledger cannot supply. |

## Consequences

- Positive: one transaction can write a document, its journal, and its outbox row; one test
  suite proves the whole flow; deployment is a single artifact.
- Positive: module boundaries remain enforceable by ArchUnit and `ApplicationModules.verify()`.
- Negative: one process is a blast radius; a memory leak or bad migration affects every
  module. Mitigation: health checks, bounded jobs, and forward-only migrations.
- Negative: scaling is vertical first. T2 triggers cover externalization when measured.
- Migration: Phase 0 already uses this shape; no data migration is needed.
- Follow-up: keep `ApplicationModules.verify()` green in every phase.

## References

- [03-architecture.md](../03-architecture.md)
- [ADR-0004](0004-transactional-outbox.md), [ADR-0007](0007-module-set-and-dependencies.md)
- [ADR-0012](0012-archunit.md)

## Review trigger

A second deployable is proposed, a module needs an independent release cadence, or a
measured load or isolation requirement cannot be met by one process and one database.

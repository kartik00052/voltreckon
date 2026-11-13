# ADR-0005 — Flyway and schema ownership

- **Status:** Accepted
- **Date:** 2026-11-13
- **Deciders:** VoltReckon maintainer
- **Applies to phases:** 0–10

## Context

Financial tables and their constraints must be reviewable before they exist. Hibernate
auto-DDL hides destructive changes and produces schema drift. Multiple migration folders or
out-of-order versions make a single-database deployment hard to reason about. A phase must
map to a known schema slice.

## Decision

- Flyway is the only schema tool. The folder is linear:
  `backend/voltreckon-app/src/main/resources/db/migration`.
- One schema: `voltreckon`. V001 creates the schema and required extensions.
- Migrations are forward-only. There are no undo scripts, no `clean` in shared profiles, and
  no out-of-order execution. A mistake is corrected by a new migration.
- File names are `V<NNN>__<snake_case_description>.sql`; the description names the owning
  module and the phase.
- One migration belongs to one module and one roadmap phase. The ownership is recorded in
  [04-data-model.md](../04-data-model.md) and in the migration header.
- Hibernate DDL is `none` or `validate`; it never creates or alters schema.
- Destructive changes use expand/contract: add, backfill, switch reads, then remove in a
  later migration. Data deletion requires a documented retention decision.
- Seed data that is required for correctness (chart of accounts) ships as a migration, not
  as an application startup hook.

## Alternatives considered

| Alternative | Why rejected | Revisit trigger |
|---|---|---|
| Hibernate auto-DDL | Unreviewable, non-deterministic, and unsafe for financial constraints. | Never. |
| Liquibase | Viable, but the project already standardised on Flyway and one linear folder. | A required capability is unavailable in Flyway. |
| One migration folder per module | Ordering across modules becomes ambiguous; one database needs one order. | Modules gain independent databases, which contradicts ADR-0001. |
| Undo scripts | Rarely tested and create a second source of truth. | A regulator or deployment process requires tested rollback, with an ADR. |

## Consequences

- Positive: schema is code-reviewed and reproducible; tests apply the same migrations.
- Positive: each phase has a visible schema slice.
- Negative: a bad migration is fixed forward, which can require a second deployment.
- Negative: long backfills need batching and a maintenance plan.
- Migration: Phase 0 already has V001; V002–V017 are allocated in the roadmap.
- Follow-up: a migration lint check in CI (statement timeout, lock review) when the quality
  profile is wired.

## References

- [04-data-model.md](../04-data-model.md)
- [13-build-and-operations.md](../13-build-and-operations.md)
- [14-roadmap.md](../14-roadmap.md)

## Review trigger

A need for online schema change tooling, a second database, or a measured migration lock
that cannot be handled by expand/contract.

# ADR-0002: Use PostgreSQL as the single system of record

- **Status:** Accepted
- **Date:** 12 November 2026
- **Deciders:** VoltReckon maintainers

## Context

VoltReckon must store partner data, tariffs, immutable CDRs, rating results, invoices, tax lines, reconciliation outcomes, double-entry journals, disputes, and settlement statements. These records are related, financially significant, and must be recoverable together.

The strongest invariants are relational and transactional:

- A journal entry has at least two lines, and debits equal credits at commit.
- An issued invoice and its tax lines must not be partially written.
- A Credit CDR must reference an original CDR from the same partner pair and currency.
- Only one active rating result may exist per CDR.
- A settlement item may settle a journal line only once.
- The same source document may produce one journal in each entity's books.

The MVP is one deployable with one developer and modest volume. Operating multiple data stores would add consistency, backup, and failure modes before there is a measured need.

## Decision

Use **PostgreSQL 18** as the only durable system of record.

Specific choices:

- One database, one schema (`voltreckon`), with module-related table prefixes where ambiguity exists.
- Money is `BIGINT` minor units plus `varchar(3)` ISO-4217 currency; no floating point.
- Use `jsonb` only for raw protocol payloads and non-query-critical detail; queryable financial facts live in typed columns.
- Enforce invariants with `CHECK`, `UNIQUE`, partial unique indexes, exclusion constraints, and deferred constraint triggers.
- Use Flyway for forward-only, versioned migrations. No Hibernate auto-DDL in shared environments.
- Use `READ COMMITTED` by default; `REPEATABLE READ` for multi-query reconciliation reads and exports; `SERIALIZABLE` only when a specific invariant cannot be expressed otherwise.
- Use PostgreSQL advisory locks for settlement runs and sequence row locks for invoice numbering.
- Use an append-only `audit_log`; block updates/deletes on financial records via triggers and grants.
- Keep application, migration, and read-only database roles separate.

## Alternatives considered

1. **Document database (MongoDB).** Rejected: weak multi-document invariants for invoices, journals, and settlement; relational reporting is harder.
2. **Separate ledger database.** Rejected: a second consistency model, backup/restore procedure, and failure domain for no MVP benefit.
3. **Event store as the system of record.** Rejected: replay and projection complexity; the append-only ledger and audit log already provide the audit trail.
4. **Schema-per-module or database-per-module.** Rejected: Flyway and cross-module read-model complexity; it does not create a real boundary without operational separation.
5. **MySQL.** Viable generally, but weaker support for exclusion constraints and deferred constraint triggers, which this design relies on.
6. **SQLite.** Rejected: unsuitable for concurrent production workloads and multi-instance deployment.

## Consequences

**Positive**

- Atomic financial transactions without sagas.
- Database-enforced invariants that survive application bugs.
- One backup, restore, and PITR procedure covers all state.
- Idempotency and locking need no Redis or broker.
- Mature managed hosting and operational tooling.

**Negative**

- Schema migrations are a release concern and require lock-aware review.
- Large tables (CDR, audit, journal lines) will eventually need partitioning.
- The database is a single primary; HA depends on the managed service or operator.
- Reporting queries can compete with transactional workload until read models or a replica are added.

## Revisit triggers

- A measured scaling or isolation requirement cannot be met by one primary.
- Regulatory data-residency rules require separate databases.
- A second consistency model is forced by an external system, not by preference.
- Partitioning or read replicas are no longer sufficient.

See [database design](../architecture/database-design.md), [deployment architecture](../architecture/deployment-architecture.md), and [ADR-0004](0004-messaging-strategy.md).

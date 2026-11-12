# ADR-0008: Defer Redis and Spring Batch in the MVP

- **Status:** Accepted
- **Date:** 12 November 2026
- **Deciders:** VoltReckon maintainers

## Context

Two common additions to a Spring financial system are:

- **Redis** for caching, distributed locks, and idempotency keys.
- **Spring Batch** for large job orchestration, restart semantics, and reporting.

The MVP has:

- One application instance (or a small number behind a load balancer).
- A PostgreSQL database that can provide locking, uniqueness, and durable state.
- Batch workloads in the tens of thousands of rows, not millions per hour.
- A single developer who must operate everything.

## Decision

**No Redis in the MVP.**

- Idempotency keys live in PostgreSQL with a unique constraint and expiry.
- Settlement and reconciliation overlap protection uses `pg_advisory_xact_lock`.
- Caching is omitted until a measured read bottleneck exists.

**No Spring Batch in the MVP.**

- Rating, reconciliation, and settlement use scheduled/triggered jobs with:
  - a run record,
  - a cursor/checkpoint,
  - bounded chunks,
  - idempotent writes.
- Jobs are restartable from the checkpoint.

## Alternatives considered

1. **Redis for locks/cache.** Adds a second data store, eviction and durability semantics, and a new failure mode. PostgreSQL is sufficient at MVP volume.
2. **Spring Batch.** Adds concepts (Job, Step, JobRepository, listeners) and tables for a problem that can be solved with a paged loop and a run record. It becomes attractive when restart semantics and multi-step flows grow.
3. **In-memory cache only.** Can be added later without a new dependency.

## Consequences

**Positive**

- One stateful dependency (PostgreSQL).
- Fewer credentials, backups, and operational runbooks.
- Simpler local development.
- Locking and idempotency are transactionally consistent with the data.

**Negative**

- PostgreSQL may become a contention point under very high load.
- Custom job code must be carefully written and tested.
- No distributed cache; every read hits the database.

## Revisit triggers

- Measured DB contention or read latency that a cache would fix.
- A need for distributed rate limiting across services.
- Batch jobs with complex multi-step flows, skip/retry policies, or millions of records per run.
- A second service that needs shared locks or idempotency state.

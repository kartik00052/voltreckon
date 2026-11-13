# ADR-0004 — Transactional outbox

- **Status:** Accepted
- **Date:** 2026-11-13
- **Deciders:** VoltReckon maintainer
- **Applies to phases:** 0–10

## Context

A state change and the notification of that change must not diverge. Publishing to a broker
inside a database transaction is not atomic; publishing after commit can lose the event if
the process dies. Consumers must tolerate duplicates because exactly-once delivery is not a
realistic default.

## Decision

- Use the Spring Modulith event publication registry as the transactional outbox
  [ref-29]. The domain event row is written in the same transaction as the aggregate state
  change.
- Delivery is **at least once**. Each consumer records `processed_event(event_id, consumer,
  processed_at)` with a unique key before committing its own state change. Duplicate
  delivery is a no-op.
- Events are internal to the application in T1. Kafka is a T2 externalization option, not a
  T1 dependency. The outbox table remains the source of truth if a broker is added.
- A failed handler retries with bounded backoff, does not block unrelated events, and moves
  to a dead-letter state after the configured attempts.
- Financial journals that must be atomic with a document are written by a synchronous public
  command in the caller’s transaction, not by an asynchronous consumer. The event is a
  notification after commit.
- The platform owns the outbox adapter and the `processed_event` table; `event_publication`
  is created by a Flyway migration and Modulith schema initialization is disabled.

## Alternatives considered

| Alternative | Why rejected | Revisit trigger |
|---|---|---|
| Publish after commit without an outbox | Can lose events on a crash and has no replay record. | Never; the outbox is the baseline. |
| Kafka inside the T1 transaction | Cannot make the broker and database commit atomically; adds operations and a broker dependency. | T2 trigger: sustained outbox lag above 60 seconds for 7 days, or a second consumer service. |
| Debezium/CDC on the database | Additional infrastructure and a new failure mode before there is a measured need. | A second service must consume changes without application participation. |
| Application events only (`@EventListener`) | Not durable and not replayable. | Never for cross-module asynchronous contracts. |
| Exactly-once semantics | Not available end to end; hides duplicate-handling bugs. | A broker and consumer design can actually prove it, with an ADR. |

## Consequences

- Positive: no lost notifications on commit; replay is possible from the outbox.
- Positive: consumers are explicitly idempotent and testable.
- Negative: the outbox table grows; a cleanup job is required for completed rows.
- Negative: handler latency is eventually consistent; the UI must show pending states.
- Migration: V002 creates the outbox and processed-event tables; Phase 1 wires the adapter.
- Follow-up: expose outbox lag and dead-letter count in the T2 metrics phase.

## References

- [03-architecture.md](../03-architecture.md)
- [ref-29]
- [ADR-0001](0001-modular-monolith.md)

## Review trigger

A second deployable consumes events, outbox lag exceeds the T2 threshold, or a broker is
introduced with a new ADR.

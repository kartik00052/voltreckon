# ADR-0004: Use a PostgreSQL transactional outbox, not an external broker, in the MVP

- **Status:** Accepted
- **Date:** 12 November 2026
- **Deciders:** VoltReckon maintainers

## Context

Some VoltReckon actions need side effects that should not block the primary transaction:

- Issuing an invoice must eventually post a journal in the appropriate entity's books.
- Ingesting a CDR may trigger rating, reconciliation, or reporting projections.
- A settlement run may emit events for reporting and notifications.
- Dispute and audit events may feed future read models.

Losing an event or emitting one without the state change would corrupt the financial trail. The MVP volume does not justify operating Kafka or RabbitMQ, and the team is one developer.

## Decision

Use a **transactional outbox** implemented with Spring Modulith's event publication registry, with the `outbox_event` table documenting the contract.

- The state change and the event row are written in one database transaction.
- A relay delivers events to in-process listeners with **at-least-once** semantics.
- Consumers are idempotent using `processed_event` or a natural unique key.
- Failed publications are retried with backoff and surfaced as metrics and alerts.
- Events are internal; external integrations use explicit adapters, not raw event publication.
- Event names are `<Aggregate><PastTenseVerb>`: `CdrIngested`, `CdrCredited`, `RatingCompleted`, `InvoiceIssued`, `InvoiceCredited`, `ReconciliationCompleted`, `SettlementCompleted`, `DisputeOpened`.
- No Kafka, RabbitMQ, Redis Streams, or external broker in the MVP.

### When synchronous calls are used

Synchronous application calls are allowed when the caller needs an immediate answer and can accept the callee's failure, for example `invoicing` asking `agreement` for settlement terms. A synchronous call must not span an external HTTP request inside a database transaction. Persist first, call after commit with idempotency.

## Alternatives considered

1. **Kafka.** Rejected for the MVP: extra infrastructure, schema management, consumer-lag monitoring, and operational knowledge for a workload one PostgreSQL instance can serve.
2. **RabbitMQ.** Rejected for the same reason; a broker is not justified by current volume or team size.
3. **PostgreSQL polling without an outbox.** Rejected: polling domain tables for changes is fragile, misses deletes, and couples consumers to producer schema.
4. **Synchronous in-process calls only.** Rejected: couples failure domains and makes the caller responsible for side effects it does not own.
5. **In-memory application events only.** Rejected: events are lost on crash and cannot be replayed.
6. **Database triggers calling external systems.** Rejected: hidden coupling, hard to test, no retry semantics.
7. **Redis Streams.** Rejected: a second data store with durability and operational trade-offs; PostgreSQL is sufficient.

## Consequences

**Positive**

- Atomic state + event publication.
- Replayable and auditable event trail.
- One fewer system to operate.
- Delivery mechanism can be replaced without changing domain code.
- Consumers are forced to be idempotent, which is required anyway for retries.

**Negative**

- At-least-once delivery requires idempotent consumers.
- The outbox table grows; completed events need retention and archiving.
- Throughput is bounded by the database and relay; suitable for the MVP, not streaming scale.
- In-process listeners do not provide consumer isolation; a slow listener can affect the application.
- The relay and dead-letter visibility become production responsibilities.

## Revisit triggers

- Sustained event throughput exceeds what the PostgreSQL relay can handle.
- Independent services need to consume the same stream.
- Event volume or retention requires a dedicated log.
- A regulatory or operational boundary requires asynchronous cross-service delivery.

When that happens, the outbox can feed a broker via a connector; the domain event contract stays the same.

See [reliability](../architecture/reliability.md), [architecture overview](../architecture/architecture-overview.md), and [ADR-0002](0002-database-strategy.md).

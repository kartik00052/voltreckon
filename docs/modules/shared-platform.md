# shared and platform

- **Status:** Draft
- **Owner:** VoltReckon maintainer
- **Last verified:** 2026-11-13
- **Applies to phases:** 0-10

`shared` holds immutable value types and contracts used by every module. `platform` holds the
technical adapters for time, IDs, persistence, transactions, outbox, idempotency, and HTTP
problem mapping. Neither module owns a business aggregate. The rules are `SHARED-001` to
`SHARED-007` and `PLAT-001` to `PLAT-012`; money semantics remain owned by
[05-financial-model.md](../05-financial-model.md).

## Purpose

Give every module one implementation of money, currency, pagination, errors, event envelopes,
time, identity, persistence, idempotency, and the transactional outbox, without leaking Spring
or JPA into domain code.

## Scope

In scope: value types, base error codes, cursor pagination, `Clock`, UUID generation,
Flyway/JPA support, outbox publication, `processed_event`, `idempotency_key`, sequence
allocation, and RFC 9457 mapping. Out of scope: business rules, tariffs, tax rates, partner
data, journals, and report definitions.

## Public API

- `Money` with `amountMinor` and ISO 4217 currency, plus checked arithmetic helpers.
- `CurrencyCode`, `MinorUnit`, `PageRequest`, `PageResult<T>`, `Cursor`.
- `DomainError` with a stable `code`, safe detail, and HTTP status mapping hint.
- `EventEnvelope<T>` with the fields in [03-architecture.md](../03-architecture.md).
- `Clock` and `IdGenerator` ports.
- `OutboxPublisher`, `ProcessedEventStore`, `IdempotencyStore`, `SequenceAllocator`.
- `ProblemMapper` used only by the web adapter.

The public API exposes commands, queries, results, value types, and enums; it never exposes a
repository or entity (`ARCH-012`).

## Domain model

`Money` is a record of minor units and currency; it rejects a missing currency and exposes no
floating-point accessor. `CurrencyCode` carries the ISO exponent. `PageResult` carries an
opaque next cursor, never an offset in a public contract. `EventEnvelope` is immutable and
contains no entity reference. `DomainError` is an immutable value, not an exception.

## Owned data

`shared` owns no table. `platform` owns `event_publication`, `processed_event`,
`idempotency_key`, and `sequence_number` in V002. The V001 baseline owns the `voltreckon`
schema and extensions. `event_publication` is the Spring Modulith 2.1 schema, pinned by V002
and never hand-edited.

## Invariants

**SHARED-001** Money MUST be represented as `long` minor units plus an ISO 4217 currency; no
`float` or `double` may appear in a money signature. *Check:* ArchUnit and `MoneyTest`.

**SHARED-002** A currency exponent MUST come from ISO 4217 configuration, not a two-decimal
assumption. *Check:* `CurrencyTest` with INR, JPY, KWD, and BHD.

**SHARED-003** Shared value types MUST be immutable, constructor-validated, and free of
Spring, JPA, Jackson, and Servlet imports. *Check:* ArchUnit and record review.

**SHARED-004** A paginated result MUST use an opaque cursor; `limit` MUST be between 1 and
200 with a default of 50. *Check:* pagination contract test.

**SHARED-005** A `DomainError` code MUST be stable and documented in the owning module's
error catalogue; a message change MUST NOT change the code. *Check:* error catalogue test.

**SHARED-006** An event envelope MUST contain `eventId`, `eventType`, `occurredAt`,
`aggregateId`, `partnerId`, `version`, `traceId`, and `payload`. *Check:* envelope contract
test.

**SHARED-007** Shared types MUST NOT carry partner names, tokens, card data, or other
personal data. *Check:* payload review and redaction test.

**PLAT-001** Time MUST come from an injected `Clock`; production uses UTC, business dates use
Asia/Kolkata. *Check:* ArchUnit forbids `Instant.now`, `LocalDate.now`, and
`System.currentTimeMillis` outside `platform`.

**PLAT-002** Public entity IDs MUST be UUIDv4 generated through an injected ID port;
`platform` provides the default `IdGenerator`, and a leaf module may define its own port.
*Check:* ID test and schema review.

**PLAT-003** A state change and its outbox row MUST commit in the same transaction. *Check:*
outbox rollback IT.

**PLAT-004** A consumer MUST record `processed_event` in the same transaction as its state
change; duplicate delivery MUST be a no-op. *Check:* duplicate-delivery IT.

**PLAT-005** `idempotency_key` MUST be unique per partner, route, and key; a replay with the
same request hash MUST return the stored response, and a different hash MUST return a
conflict. *Check:* idempotency IT.

**PLAT-006** Schema changes MUST be forward-only Flyway migrations owned by one module; an
applied migration MUST NOT be edited. *Check:* migration review and `flyway_schema_history`.

**PLAT-007** Hibernate auto-DDL MUST be disabled in every profile. *Check:* configuration
test.

**PLAT-008** Sequence allocation MUST be a single atomic row update and MUST never reuse a
value. *Check:* concurrency IT.

**PLAT-009** HTTP errors MUST be `application/problem+json` with a stable code, a safe detail,
and no stack trace. *Check:* problem-mapping IT.

**PLAT-010** Logs and metrics MUST NOT contain secrets, tokens, card data, or full payloads.
*Check:* redaction test.

**PLAT-011** Spring Modulith schema initialization MUST be disabled; `event_publication` is
pinned by migration. *Check:* startup configuration test.

**PLAT-012** `platform` MUST NOT open a distributed transaction or call a remote service from
a persistence adapter. *Check:* dependency review.

## Transactions

`platform` participates in the caller's transaction. The outbox writer, idempotency
reservation, sequence update, and processed-event insert use the caller's connection and do
not start an independent transaction. A replay reads the stored response after the original
transaction commits; an in-flight duplicate waits on the unique key and then returns the
stored result.

## Events

`platform` produces no business event. It provides the envelope, outbox writer, dispatcher,
retry policy, dead-letter state, and `processed_event` helper used by producers and consumers.
Only the events in the catalog in [03-architecture.md](../03-architecture.md) may be consumed.

## Dependencies

`shared` has no module dependency. `platform` depends on `shared` only. Every domain module may
depend on both. `platform` MUST NOT depend on a domain module, and `shared` MUST remain
business-agnostic.

## Configuration

| Key | Default | Purpose |
|---|---|---|
| `voltreckon.time.zone` | `Asia/Kolkata` | Business date zone |
| `voltreckon.idempotency.ttl` | `PT48H` | Replay window |
| `voltreckon.outbox.retry.max` | `8` | Attempts before dead letter |
| `voltreckon.outbox.retry.backoff` | `PT30S` | Initial backoff |
| `voltreckon.events.retention` | `P90D` | Processed-event retention |
| `voltreckon.raw-payload.retention` | `P24M` | CDR raw payload retention |

`event_publication` retention is 7 days after completion. Configuration MUST NOT contain
secrets; secrets come from the environment or a secret manager.

## Errors

| Code | Status | Meaning |
|---|---|---|
| `VALIDATION_FAILED` | 400 | A request field failed validation |
| `INVALID_CURSOR` | 400 | The cursor is malformed or expired |
| `UNAUTHENTICATED` | 401 | No valid token |
| `INSUFFICIENT_ROLE` | 403 | Role or scope denied |
| `RESOURCE_NOT_FOUND` | 404 | The scoped resource does not exist |
| `IDEMPOTENCY_KEY_REUSED` | 409 | Same key, different request hash |
| `RATE_LIMITED` | 429 | Retry later |
| `INTERNAL_ERROR` | 500 | Safe generic failure |

## Security

`platform` validates no identity itself; it maps failures from `iam` and the web layer. The
idempotency store is partner-scoped and MUST NOT return another partner's response. Outbox
payloads and logs follow `SEC-009` and `SEC-039`. Database credentials and signing keys are
environment-supplied and never committed.

## Observability

Metrics: outbox lag, publication failures, dead-letter count, idempotency replay rate,
processed-event duplicates, sequence contention, problem responses by code, and clock skew.
Every log line carries `traceId`; partner-scoped lines also carry `partnerRef` when safe.

## Tests

| Test | Covers |
|---|---|
| `MoneyTest` | Minor units, currency exponent, overflow, no float |
| `EventEnvelopeContractTest` | Required envelope fields |
| `OutboxAtomicityIT` | Rollback removes both state and event |
| `IdempotencyIT` | Replay, conflict, scope isolation |
| `ProblemMappingIT` | RFC 9457 shape and stable code |
| `ArchitectureTests` | No Spring in domain, no forbidden clock calls |

```gherkin
Scenario: Replayed request returns the original result
  Given a completed request with an idempotency key
  When the same key and request hash arrive again
  Then the original status and body are returned
  And the replay header is present
  And no second business row exists

Scenario: Same key with a different body is rejected
  Given a completed request with an idempotency key
  When the same key arrives with a different request hash
  Then the request fails with IDEMPOTENCY_CONFLICT
  And the original result is unchanged
```

## Phase plan

- Phase 0: V001, clock, IDs, problem mapping, health.
- Phase 1: V002 outbox, processed events, idempotency, sequences.
- Phase 2-10: add metrics and retention jobs only; do not change the envelope without an ADR.

# Architecture decisions

This page summarises the decisions that shape VoltReckon. Detailed records live in [docs/adr/](../adr/). Each entry states the decision, the rejected alternatives, the consequences, and the trigger that would make us revisit it.

The four canonical decisions are [ADR-0001 architecture style](../adr/0001-architecture-style.md), [ADR-0002 database strategy](../adr/0002-database-strategy.md), [ADR-0003 financial model](../adr/0003-financial-model.md), and [ADR-0004 messaging strategy](../adr/0004-messaging-strategy.md). ADR-0005 to ADR-0008 cover scope boundaries.

| # | Decision | Alternatives rejected | Primary consequence |
|---|---|---|---|
| A1 | Modular monolith, one deployable | Microservices, unmodularised monolith | Strong local transactions; must enforce boundaries with ArchUnit |
| A2 | Spring Modulith + hexagonal per module | Layer-first packaging, OSGi, service-per-module | Verifiable modules; slightly more ceremony per feature |
| A3 | PostgreSQL as sole system of record | Separate ledger DB, event store, document DB | One backup/restore, one consistency model |
| A4 | Transactional outbox, no broker in MVP | Kafka, RabbitMQ, direct sync calls | At-least-once internal events; no streaming scale |
| A5 | No Redis in MVP | Redis for cache/locks/idempotency | Fewer moving parts; DB contention is acceptable at target volume |
| A6 | Integer minor units for money | `BigDecimal` columns, floating point | Exact sums; explicit conversion at boundaries |
| A7 | Append-only double-entry ledger | Mutable balance table, single-entry invoicing | Auditable books; corrections via reversal |
| A8 | OCPI 2.3.0 CDR + Invoice Reconciliation target, 2.2.1 compatibility | OCPI 3.0 draft, proprietary API | Standards-aligned; adapter must handle version drift |
| A9 | CDRs immutable; corrections via Credit CDR | Update original CDR | Audit-safe; requires credit linkage logic |
| A10 | Tax as versioned configuration | Hard-coded GST rate | Change without redeploy; requires governance |
| A11 | Partner isolation from the security principal | Partner ID in request body | No cross-tenant leakage; requires scoped tokens |
| A12 | `Idempotency-Key` on mutating POSTs | "Exactly once" claims, no idempotency | Safe retries; requires a key table and retention policy |
| A13 | Scheduled paged jobs instead of Spring Batch | Spring Batch in MVP | Simpler; less restart tooling |
| A14 | No AI in financial decisions | ML-based matching in MVP | Deterministic, explainable outcomes |
| A15 | Complement UBC/UEI, do not rebuild | Build a Beckn gateway/app | Adapter Phase 2; no dependency on undeveloped specs |
| A16 | Single schema `voltreckon`, module table prefixes | Schema-per-module, database-per-module | Simpler Flyway; prefix discipline required |
| A17 | RFC 9457 problem details for errors | Ad-hoc error JSON | Consistent client handling; requires error catalogue |
| A18 | OpenAPI 3.1 contract-first | Code-first only | Partner clarity; spec may drift from code without CI validation |

---

## Decision details

### A1 — Modular monolith

**Context:** the MVP has strong transactional invariants across invoicing, tax, and ledger. One developer must build and operate it.

**Decision:** one Spring Boot application, one PostgreSQL database, module boundaries enforced by Spring Modulith and ArchUnit.

**Rejected:** microservices would replace local transactions with sagas; an unmodularised monolith would decay without boundaries.

**Revisit if:** a module needs independent scaling (measured 10×), a separate team owns it, or a regulatory boundary appears. See [ADR-0001](../adr/0001-architecture-style.md).

### A2 — Spring Modulith and hexagonal boundaries

**Context:** package-by-feature is easier to navigate; Spring Modulith verifies allowed dependencies; hexagonal keeps domain free of framework and transport types.

**Decision:** module = feature package; inside each module: `domain`, `application`, `adapter.in.*`, `adapter.out.*`.

**Rejected:** layer-first packaging (spreads a feature across the tree), service-per-module (operational overhead).

**Consequence:** more packages and mapping code; domain tests run without Spring.

### A3 — PostgreSQL as sole system of record

**Context:** relational integrity, transactions, constraints, JSONB, partitioning, and mature operations.

**Decision:** all durable state in PostgreSQL 18; no separate ledger or event store.

**Rejected:** ledger in a specialised store (adds a second consistency model); document DB for CDR payloads (JSONB is sufficient).

**Consequence:** schema migrations are a release concern; partitioning for large tables; backups cover everything. See [ADR-0002](../adr/0002-database-strategy.md).

### A4 — Transactional outbox, no broker

**Context:** internal events must be durable and at-least-once. Volume is low. Operating Kafka adds cost and failure modes.

**Decision:** Spring Modulith event publication registry persists events in the same transaction; a relay delivers to listeners; consumers are idempotent.

**Rejected:** Kafka (premature), synchronous coupling (fragile), in-memory events (lossy).

**Revisit if:** sustained throughput exceeds PostgreSQL relay capacity, or independent services need the stream. See [ADR-0004](../adr/0004-messaging-strategy.md).

### A5 — No Redis

**Context:** idempotency and settlement locking can be implemented with a unique table and PostgreSQL advisory locks.

**Decision:** PostgreSQL only.

**Rejected:** Redis for locks/cache (second data store, eviction/durability issues).

**Revisit if:** measured hot-read latency or distributed rate limiting requires it.

### A6 — Money as integer minor units

**Context:** binary floating point cannot represent decimal money exactly.

**Decision:** persist `BIGINT` minor units + `CHAR(3)` currency. Use `BigDecimal` for intermediate multiplication/division with explicit `HALF_UP` (or documented policy) and scale. Never `float`/`double`.

**Rejected:** `NUMERIC` in the database is also exact but complicates currency-aware APIs and can hide scale errors; floating point is forbidden.

**Consequence:** conversion layer at OCPI boundaries (OCPI decimals → minor units); rounding must be tested per component. See [ADR-0003](../adr/0003-financial-model.md).

### A7 — Append-only double-entry ledger

**Context:** audit and tax require reconstructable books. A mutable balance column hides history.

**Decision:** `journal_entry` + `journal_line`; debits equal credits enforced by a deferred constraint trigger; no updates or deletes; corrections via reversing entries.

**Rejected:** single-entry invoice totals (cannot prove books), mutable balances (audit failure).

**Consequence:** more rows; reporting aggregates; period locks. See [ADR-0003](../adr/0003-financial-model.md).

### A8 — OCPI 2.3.0 target, 2.2.1 compatibility

**Context:** OCPI 2.3.0 is current; edition 2 adds Invoice Reconciliation. Indian partners often use 2.2.1.

**Decision:** domain models VoltReckon's own concepts; adapters map OCPI 2.2.1 and 2.3.0; no OCPI types in the domain. Full OCPI server is Phase 2.

**Rejected:** OCPI 3.0 draft (unstable), proprietary-only API (excludes partners).

### A9 — Immutable CDRs and Credit CDRs

**Context:** OCPI requires credit semantics.

**Decision:** `cdr` is append-only; `credit=true` requires `credit_reference_id`; an original can be credited once; net amount is original + credit.

**Rejected:** editing originals (destroys audit trail).

### A10 — Tax as versioned configuration

**Context:** GST classification and rates can change; different entities/jurisdictions may differ.

**Decision:** `tax_rate` rows with jurisdiction, service code, rate, effective range, and version. Invoice tax lines reference the rule used.

**Rejected:** hard-coded 18% (brittle and potentially wrong).

### A11 — Partner isolation from the principal

**Context:** request-body partner IDs are a common tenant-leak vector.

**Decision:** partner ID and scopes come from the authenticated principal; repositories require a partner scope; cross-partner access returns `404`.

**Rejected:** trusting client-supplied tenant IDs; UI-only filtering.

### A12 — Idempotency keys

**Context:** retries are normal; duplicate invoices and CDRs are expensive.

**Decision:** `Idempotency-Key` required on financial POSTs; stored with request hash, response hash, and expiry; replay returns the original response.

**Rejected:** "exactly once" claims without a mechanism.

### A13 — Scheduled paged jobs, not Spring Batch

**Context:** rating and reconciliation are chunked, restartable jobs with a run record.

**Decision:** scheduled/triggered jobs using paged queries and a run/checkpoint table.

**Rejected:** Spring Batch in the MVP (extra concepts and configuration for modest volume).

**Revisit if:** complex multi-step flows, restart semantics, or volume justify it.

### A14 — No AI in financial decisions

**Decision:** deterministic rules for duplicates, matching, and variance. AI is Phase 3 and advisory only.

**Reason:** auditability, no labelled data, and risk of silent financial errors. See [ADR-0006](../adr/0006-ai-deferred.md).

### A15 — Complement UBC/UEI

**Context:** UBC is public infrastructure for discovery/payment; specs are not fully public.

**Decision:** do not build a consumer app or Beckn gateway; Phase 2 adapter only against official material.

**See:** [ADR-0007](../adr/0007-ubc-positioning.md).

### A16 — Single schema with table prefixes

**Context:** schema-per-module complicates Flyway and cross-module read models.

**Decision:** one schema, prefixed table names by module (for example, `cdr_*`, `ledger_*`).

**Rejected:** schema-per-module (migration complexity), database-per-module (operational overhead).

### A17 — Problem details for errors

**Decision:** RFC 9457 `application/problem+json` with stable `code`, `detail`, `instance`, and field errors.

**Consequence:** error catalogue must be maintained; clients can branch on `code`, not message text.

### A18 — Contract-first OpenAPI 3.1

**Decision:** `docs/api/openapi.yaml` is the design contract; CI validates the spec and, once code exists, compares implemented routes.

**Consequence:** spec drift is a build failure, not a documentation bug.

# Resource library

**Verification date:** 12 November 2026. Every URL in this document returned HTTP 200 when checked. The dead-link table at the end records URLs that were rejected.

**How to use this:** read the resources for the milestone you are working on, not the whole list. A resource is included only if it changes how you design, test, or operate VoltReckon. Vendor marketing pages are excluded unless they are the only public source for a capability claim.

**Difficulty:** Beginner / Intermediate / Advanced.
**Importance:** Essential / Recommended / Optional.

---

## 1. Java

| Resource | URL | Type | Difficulty | Importance | What to learn | Why it matters to VoltReckon | Milestone |
|---|---|---|---|---|---|---|---|
| Dev.java tutorials | [dev.java/learn](https://dev.java/learn/) | Official tutorials | Beginner | Essential | Modern Java language and JDK tooling | Baseline for records, sealed types, pattern matching, virtual threads | M1 |
| Java SE 25 API docs | [docs.oracle.com/en/java/javase/25](https://docs.oracle.com/en/java/javase/25/) | Official reference | Intermediate | Essential | Core library contracts | Avoid reinvented utils in money and time code | M1 |

---

## 2. Spring Boot

| Resource | URL | Type | Difficulty | Importance | What to learn | Why it matters to VoltReckon | Milestone |
|---|---|---|---|---|---|---|---|
| Spring Boot reference | [docs.spring.io/spring-boot](https://docs.spring.io/spring-boot/) | Official docs | Intermediate | Essential | Auto-configuration, profiles, Actuator, testing | Application skeleton and operational endpoints | M1 |
| Spring Boot release highlights | [spring.io/projects/release-highlights](https://spring.io/projects/release-highlights/) | Official notes | Intermediate | Recommended | Version changes and migration issues | Pin a supported 4.x line deliberately | M1 |

---

## 3. Spring Security

| Resource | URL | Type | Difficulty | Importance | What to learn | Why it matters to VoltReckon | Milestone |
|---|---|---|---|---|---|---|---|
| Spring Security reference | [docs.spring.io/spring-security/reference](https://docs.spring.io/spring-security/reference/) | Official docs | Advanced | Essential | OAuth2 resource server, JWT, method security | Partner isolation and scoped access | M2 |
| OAuth 2.0 (RFC 6749) | [rfc-editor.org/rfc/rfc6749](https://www.rfc-editor.org/rfc/rfc6749) | Standard | Advanced | Recommended | Client credentials and token semantics | Correct partner-system authentication | M2 |

---

## 4. Spring Data JPA and Hibernate

| Resource | URL | Type | Difficulty | Importance | What to learn | Why it matters to VoltReckon | Milestone |
|---|---|---|---|---|---|---|---|
| Spring Data JPA reference | [docs.spring.io/spring-data/jpa/reference](https://docs.spring.io/spring-data/jpa/reference/) | Official docs | Intermediate | Essential | Repositories, transactions, locking | Persistence boundaries and optimistic locking | M1 |
| Hibernate ORM documentation | [hibernate.org/orm/documentation](https://hibernate.org/orm/documentation/) | Official docs | Advanced | Recommended | Mapping, flush behaviour, fetch strategies | Avoid accidental N+1 and flush-order bugs in financial flows | M3 |

---

## 5. PostgreSQL

| Resource | URL | Type | Difficulty | Importance | What to learn | Why it matters to VoltReckon | Milestone |
|---|---|---|---|---|---|---|---|
| PostgreSQL 18 documentation | [postgresql.org/docs/18](https://www.postgresql.org/docs/18/) | Official docs | Intermediate | Essential | SQL, constraints, indexes, triggers, transactions | The system of record and most invariants live here | M1 |
| Transaction isolation | [postgresql.org/docs/18/transaction-iso.html](https://www.postgresql.org/docs/18/transaction-iso.html) | Official docs | Advanced | Essential | Read committed vs repeatable read vs serializable | Correct concurrency for closing and settlement | M5 |
| Explicit locking | [postgresql.org/docs/18/explicit-locking.html](https://www.postgresql.org/docs/18/explicit-locking.html) | Official docs | Advanced | Recommended | Row locks, advisory locks | Invoice numbering and settlement runs | M4 |

---

## 6. Domain-Driven Design

| Resource | URL | Type | Difficulty | Importance | What to learn | Why it matters to VoltReckon | Milestone |
|---|---|---|---|---|---|---|---|
| Martin Fowler, DomainDrivenDesign | [martinfowler.com/bliki/DomainDrivenDesign.html](https://martinfowler.com/bliki/DomainDrivenDesign.html) | Article | Beginner | Recommended | Ubiquitous language, model boundaries | Keeps protocol terms out of the financial domain | M0 |
| Martin Fowler, BoundedContext | [martinfowler.com/bliki/BoundedContext.html](https://martinfowler.com/bliki/BoundedContext.html) | Article | Intermediate | Recommended | Context boundaries | Justifies module boundaries | M0 |

---

## 7. Modular monoliths

| Resource | URL | Type | Difficulty | Importance | What to learn | Why it matters to VoltReckon | Milestone |
|---|---|---|---|---|---|---|---|
| Spring Modulith reference | [docs.spring.io/spring-modulith/reference](https://docs.spring.io/spring-modulith/reference/) | Official docs | Intermediate | Essential | Module verification, events, documentation | Enforces boundaries and provides the outbox | M1 |
| Martin Fowler, MonolithFirst | [martinfowler.com/bliki/MonolithFirst.html](https://martinfowler.com/bliki/MonolithFirst.html) | Article | Beginner | Recommended | Why to start with a monolith | Defends the architecture choice against fashion | M0 |

---

## 8. Hexagonal architecture

| Resource | URL | Type | Difficulty | Importance | What to learn | Why it matters to VoltReckon | Milestone |
|---|---|---|---|---|---|---|---|
| Alistair Cockburn, Hexagonal Architecture | [alistair.cockburn.us/hexagonal-architecture](https://alistair.cockburn.us/hexagonal-architecture/) | Original paper | Intermediate | Essential | Ports and adapters, inside/outside asymmetry | Domain must not depend on OCPI, JPA, or Spring | M0 |
| Spring Modulith fundamentals | [docs.spring.io/spring-modulith/reference/fundamentals.html](https://docs.spring.io/spring-modulith/reference/fundamentals.html) | Official docs | Intermediate | Recommended | Module APIs and internal packages | Practical implementation of the boundary rules | M1 |

---

## 9. Distributed systems

| Resource | URL | Type | Difficulty | Importance | What to learn | Why it matters to VoltReckon | Milestone |
|---|---|---|---|---|---|---|---|
| Martin Kleppmann, Accounting for Computer Scientists | [martin.kleppmann.com/2011/03/07/accounting-for-computer-scientists.html](https://martin.kleppmann.com/2011/03/07/accounting-for-computer-scientists.html) | Article | Beginner | Essential | Double-entry as a distributed-systems idea | Makes the ledger intuitive to engineers | M0 |
| Transactional outbox | [microservices.io/patterns/data/transactional-outbox.html](https://microservices.io/patterns/data/transactional-outbox.html) | Pattern | Intermediate | Essential | Atomic state + event publication | The MVP messaging design | M1 |

---

## 10. Kafka

| Resource | URL | Type | Difficulty | Importance | What to learn | Why it matters to VoltReckon | Milestone |
|---|---|---|---|---|---|---|---|
| Apache Kafka documentation | [kafka.apache.org/documentation](https://kafka.apache.org/documentation/) | Official docs | Advanced | Optional | Log semantics, partitions, consumer groups | Only relevant if the outbox outgrows PostgreSQL | Phase 2+ |
| Kafka design | [kafka.apache.org/documentation/#design](https://kafka.apache.org/documentation/#design) | Official docs | Advanced | Optional | Durability and ordering guarantees | Informs a future build-vs-buy decision | Phase 2+ |

**Decision:** Kafka is **not** in the MVP. See [ADR-0004](../adr/0004-messaging-strategy.md).

---

## 11. RabbitMQ

| Resource | URL | Type | Difficulty | Importance | What to learn | Why it matters to VoltReckon | Milestone |
|---|---|---|---|---|---|---|---|
| RabbitMQ documentation | [rabbitmq.com/docs](https://www.rabbitmq.com/docs) | Official docs | Intermediate | Optional | Queues, exchanges, acknowledgements | A future alternative if a broker is justified | Phase 2+ |
| RabbitMQ reliability guide | [rabbitmq.com/docs/reliability](https://www.rabbitmq.com/docs/reliability) | Official docs | Advanced | Optional | Publisher confirms, consumer acknowledgements | Avoid at-least-once mistakes if adopted | Phase 2+ |

**Decision:** RabbitMQ is **not** in the MVP.

---

## 12. Redis

| Resource | URL | Type | Difficulty | Importance | What to learn | Why it matters to VoltReckon | Milestone |
|---|---|---|---|---|---|---|---|
| Redis documentation | [redis.io/documentation](https://redis.io/documentation) | Official docs | Intermediate | Optional | Data types, expiry, persistence, clustering | Evaluate only if a measured cache/lock need appears | Phase 2+ |
| Redis persistence | [redis.io/docs/latest/management](https://redis.io/docs/latest/management) | Official docs | Advanced | Optional | RDB/AOF trade-offs | Prevents treating a cache as a system of record | Phase 2+ |

**Decision:** Redis is **not** in the MVP; idempotency and locks use PostgreSQL. See [ADR-0008](../adr/0008-defer-redis-batch.md).

---

## 13. Spring Batch

| Resource | URL | Type | Difficulty | Importance | What to learn | Why it matters to VoltReckon | Milestone |
|---|---|---|---|---|---|---|---|
| Spring Batch reference | [docs.spring.io/spring-batch/reference](https://docs.spring.io/spring-batch/reference/) | Official docs | Advanced | Optional | Jobs, steps, restart, chunking | Revisit when paged jobs become unmanageable | Phase 2+ |
| Spring Batch repository | [github.com/spring-projects/spring-batch](https://github.com/spring-projects/spring-batch) | Source | Advanced | Optional | Real job implementations | Understand operational overhead before adopting | Phase 2+ |

**Decision:** the MVP uses scheduled paged jobs with checkpoints.

---

## 14. Financial ledgers

| Resource | URL | Type | Difficulty | Importance | What to learn | Why it matters to VoltReckon | Milestone |
|---|---|---|---|---|---|---|---|
| Martin Kleppmann, Accounting for Computer Scientists | [martin.kleppmann.com/2011/03/07/accounting-for-computer-scientists.html](https://martin.kleppmann.com/2011/03/07/accounting-for-computer-scientists.html) | Article | Beginner | Essential | Journals, accounts, trial balance | Foundation for the append-only ledger | M0 |
| PostgreSQL constraints and triggers | [postgresql.org/docs/18/ddl-constraints.html](https://www.postgresql.org/docs/18/ddl-constraints.html) | Official docs | Advanced | Essential | Deferred constraints, exclusion constraints | Enforces balancing and immutability | M4 |

---

## 15. Double-entry accounting

| Resource | URL | Type | Difficulty | Importance | What to learn | Why it matters to VoltReckon | Milestone |
|---|---|---|---|---|---|---|---|
| Accounting for Computer Scientists (again, as the primary primer) | [martin.kleppmann.com/2011/03/07/accounting-for-computer-scientists.html](https://martin.kleppmann.com/2011/03/07/accounting-for-computer-scientists.html) | Article | Beginner | Essential | Debits, credits, balancing | Every engineer must understand this before touching `ledger` | M0 |
| PostgreSQL deferred constraints | [postgresql.org/docs/18/sql-set-constraints.html](https://www.postgresql.org/docs/18/sql-set-constraints.html) | Official docs | Advanced | Recommended | Commit-time validation | Implements "debits = credits" at commit | M4 |

---

## 16. Reconciliation

| Resource | URL | Type | Difficulty | Importance | What to learn | Why it matters to VoltReckon | Milestone |
|---|---|---|---|---|---|---|---|
| OCPI Invoice Reconciliation module | [mod_invoice_reconciliation.asciidoc](https://github.com/ocpi/ocpi/blob/2.3.0/release/core/mod_invoice_reconciliation.asciidoc) | Standard | Advanced | Essential | Standard reconciliation vocabulary | The external contract for partner reconciliation | M5 |
| OCPI CDR module | [mod_cdrs.asciidoc](https://github.com/ocpi/ocpi/blob/2.3.0/release/core/mod_cdrs.asciidoc) | Standard | Advanced | Essential | CDR identity, credit semantics | Matching starts from immutable CDRs | M3 |

---

## 17. OCPI

| Resource | URL | Type | Difficulty | Importance | What to learn | Why it matters to VoltReckon | Milestone |
|---|---|---|---|---|---|---|---|
| OCPI specification repository | [github.com/ocpi/ocpi](https://github.com/ocpi/ocpi) | Standard | Advanced | Essential | All modules and versioning | Primary integration contract | M3 |
| OCPI releases and tags | [github.com/ocpi/ocpi/releases](https://github.com/ocpi/ocpi/releases) | Official repository | Intermediate | Essential | Release history and version changes | 2.2.1/2.3.0 compatibility decisions | M3 |
| EVRoaming Foundation | [evroaming.org/ocpi](https://evroaming.org/ocpi) | Official site | Beginner | Recommended | Governance and current version | Confirms 2.3.0 status and 3.0 timeline | M0 |

---

## 18. OCPP

| Resource | URL | Type | Difficulty | Importance | What to learn | Why it matters to VoltReckon | Milestone |
|---|---|---|---|---|---|---|---|
| Open Charge Alliance | [openchargealliance.org](https://openchargealliance.org/) | Official site | Beginner | Recommended | Protocol family and certification | Context for where CDRs originate | M0 |
| OCPP 2.0.1 / 2.1 editions announcement | [openchargealliance.org](https://openchargealliance.org/new-editions-of-the-ocpp-2-1-and-2-0-1-now-available) | Official announcement | Intermediate | Recommended | Current editions | Avoid outdated protocol assumptions | M0 |

---

## 19. GST and e-invoicing

| Resource | URL | Type | Difficulty | Importance | What to learn | Why it matters to VoltReckon | Milestone |
|---|---|---|---|---|---|---|---|
| GST e-invoice portal | [einvoice.gst.gov.in](https://einvoice.gst.gov.in/einvoice/dashboard) | Official portal | Intermediate | Essential | IRN, schema, applicability | Invoice data must be IRP-ready | M4 |
| GST e-invoice FAQs | [einvoice.gst.gov.in/faqs](https://einvoice.gst.gov.in/faqs) | Official FAQ | Intermediate | Recommended | Thresholds and reporting rules | Avoid hard-coded turnover assumptions | M4 |
| CBIC | [cbic.gov.in](https://www.cbic.gov.in/) | Official site | Intermediate | Recommended | Notifications and rules | Source of truth for tax changes | M4 |

**Not legal advice.** Confirm classification and applicability with a professional.

---

## 20. Testing

| Resource | URL | Type | Difficulty | Importance | What to learn | Why it matters to VoltReckon | Milestone |
|---|---|---|---|---|---|---|---|
| Testcontainers for Java | [java.testcontainers.org](https://java.testcontainers.org/) | Official docs | Intermediate | Essential | Real PostgreSQL in tests | Schema and trigger tests are worthless against H2 | M1 |
| jqwik | [jqwik.net](https://jqwik.net/) | Official docs | Intermediate | Recommended | Property-based testing | Money, rounding, balancing properties | M4 |
| ArchUnit | [archunit.org](https://www.archunit.org/) | Official docs | Intermediate | Essential | Architecture rules as tests | Enforces module boundaries in CI | M1 |
| WireMock | [wiremock.org](https://wiremock.org/) | Official docs | Intermediate | Recommended | HTTP stubbing and fault injection | OCPI/IRP adapter contract tests | M3 |

---

## 21. Docker

| Resource | URL | Type | Difficulty | Importance | What to learn | Why it matters to VoltReckon | Milestone |
|---|---|---|---|---|---|---|---|
| Docker documentation | [docs.docker.com](https://docs.docker.com/) | Official docs | Beginner | Essential | Images, Compose, volumes | Local PostgreSQL and reproducible builds | M0 |
| Docker Compose | [docs.docker.com/compose](https://docs.docker.com/compose/) | Official docs | Beginner | Essential | Service definitions and health checks | The `compose.yaml` in this repository | M0 |

---

## 22. CI/CD

| Resource | URL | Type | Difficulty | Importance | What to learn | Why it matters to VoltReckon | Milestone |
|---|---|---|---|---|---|---|---|
| GitHub Actions documentation | [docs.github.com/en/actions](https://docs.github.com/en/actions) | Official docs | Intermediate | Essential | Workflows, matrix builds, secrets | Build, test, CodeQL, dependency review | M1 |
| GitHub Actions workflow syntax | [docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax) | Official reference | Intermediate | Recommended | Jobs, steps, conditions | The CI guard that skips until `backend/pom.xml` exists | M1 |

---

## 23. Observability

| Resource | URL | Type | Difficulty | Importance | What to learn | Why it matters to VoltReckon | Milestone |
|---|---|---|---|---|---|---|---|
| OpenTelemetry documentation | [opentelemetry.io/docs](https://opentelemetry.io/docs/) | Official docs | Intermediate | Recommended | Traces, metrics, logs, context | Correlation IDs and future tracing | M2 |
| Spring Boot observability | [docs.spring.io/spring-boot/reference/actuator/observability.html](https://docs.spring.io/spring-boot/reference/actuator/observability.html) | Official docs | Intermediate | Essential | Micrometer, Actuator, OTLP | Health and metrics from day one | M2 |
| Prometheus documentation | [prometheus.io/docs](https://prometheus.io/docs/) | Official docs | Intermediate | Recommended | Metrics model, alerting | Ingestion and outbox alerts | M2 |

---

## 24. Production engineering

| Resource | URL | Type | Difficulty | Importance | What to learn | Why it matters to VoltReckon | Milestone |
|---|---|---|---|---|---|---|---|
| Google SRE Book | [sre.google/sre-book/table-of-contents](https://sre.google/sre-book/table-of-contents/) | Book (free) | Intermediate | Recommended | SLOs, on-call, incidents, postmortems | Operational discipline for a financial system | M11 |
| PostgreSQL backup and restore | [postgresql.org/docs/18/backup-dump.html](https://www.postgresql.org/docs/18/backup-dump.html) | Official docs | Intermediate | Essential | `pg_dump`/`pg_restore`, PITR concepts | Tested restore is a release gate | M2 |
| Twelve-Factor App | [12factor.net](https://12factor.net/) | Guide | Beginner | Recommended | Config, logs, stateless processes | Keeps deployment simple and portable | M1 |

---

## 25. Books (no URL required)

These are recommended but not linked because there is no single authoritative free URL:

| Book | Why |
|---|---|
| *Designing Data-Intensive Applications* — Martin Kleppmann | Transactions, replication, event logs; outbox rationale. |
| *Domain-Driven Design* — Eric Evans | Aggregates, bounded contexts, ubiquitous language. |
| *Implementing Domain-Driven Design* — Vaughn Vernon | Practical aggregate and context mapping. |
| *Patterns of Enterprise Application Architecture* — Martin Fowler | Layering, units of work, repositories. |
| *Release It!* — Michael Nygard | Failure modes, circuit breakers, operational design. |

---

## 26. Open-source projects to study

| Project | URL | Use |
|---|---|---|
| steve | [github.com/steve-community/steve](https://github.com/steve-community/steve) | OCPP/OCPI platform reference; study, do not fork as the product |
| Java-OCA-OCPP | [github.com/ChargeTimeEU/Java-OCA-OCPP](https://github.com/ChargeTimeEU/Java-OCA-OCPP) | OCPP message handling |
| Extrawest OCPI 2.2.1 | [github.com/extrawest/Extrawest-OCPI-2.2.1](https://github.com/extrawest/Extrawest-OCPI-2.2.1) | OCPI client/server example |
| ocpi-tariffs | [github.com/tandemdrive/ocpi-tariffs](https://github.com/tandemdrive/ocpi-tariffs) | Tariff calculation reference |
| OCPI OpenAPI | [github.com/ocpi/openapi-specification](https://github.com/ocpi/openapi-specification) | Generated contracts |

---

## 27. Dead or blocked links (do not reuse)

| URL | Problem |
|---|---|
| `https://powermin.gov.in/sites/default/files/Guidelines_and_Standards_for_EVCI_dated_17_09_2024.pdf` | 404 |
| `https://evyatra.beeindia.gov.in/central-govt-initiative-details` | Timeout |
| `https://microservices.io/patterns/data/idempotent-consumer.html` | 404 |
| `https://github.com/archunit/archunit` | 404 (use archunit.org) |
| `https://www.baeldung.com/spring-modulith` | 403 (bot block) |
| ET Auto article links | 403 (bot block) |
| `https://redis.io/docs/latest/` | 404 as of 12 November 2026 (use `redis.io/documentation`) |

---

## 28. Recommended learning path

1. **Domain first:** Kleppmann accounting article → OCPI CDR module → OCPI Invoice Reconciliation module.
2. **Architecture:** Cockburn hexagonal paper → Spring Modulith reference → transactional outbox pattern.
3. **Data and money:** PostgreSQL 18 constraints/triggers → financial model document → money and rounding property tests.
4. **Delivery:** Spring Boot reference → Testcontainers → GitHub Actions.
5. **Operations:** Spring Boot observability → Prometheus → Google SRE book (selected chapters).
6. **Later:** Kafka/RabbitMQ/Redis/Spring Batch only when an ADR justifies them.

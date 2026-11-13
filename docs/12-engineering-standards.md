# 12 - Engineering standards

- **Status:** Draft
- **Owner:** VoltReckon maintainer
- **Last verified:** 2026-11-13
- **Applies to phases:** 0-10

This file defines the code rules that are not specific to one module. The module specs own
their business rules; this file owns language level, package shape, persistence, transactions,
configuration, logging, dependencies, and the definition of done. When this file and a module
spec disagree, report both and stop on a money, tax, security, or boundary conflict. The
architecture is in [03-architecture.md](03-architecture.md), the table rules in
[04-data-model.md](04-data-model.md), and the money rules in
[05-financial-model.md](05-financial-model.md).

## 1. Language and framework

**ENG-001** Main code MUST compile with Java 21 source and bytecode (`--release 21`); Java 22
or newer language features MUST NOT be used in main code. *Check:* Maven compiler configuration.

**ENG-002** The runtime baseline is Spring Boot `4.1.2` with Spring Modulith `2.1.0`; a version
change requires a verified build and an update to 13-build-and-operations. *Check:* parent POM.

**ENG-003** Lombok, field injection, and implicit component scanning of domain classes MUST NOT
be used; dependencies MUST be constructor-injected. *Check:* review and quality profile.

**ENG-004** Domain code MUST NOT import Spring, JPA, Jackson, Servlet, or a web type. *Check:*
ArchUnit rule and `ArchitectureTests`.

**ENG-005** A new runtime dependency MUST have an accepted ADR; a test-only dependency MAY be
added when it is justified by a test rule and does not leak into runtime. *Check:* POM diff and
ADR index.

**ENG-006** A new module, a new T2 component, or a generated-code pipeline MUST NOT be added
without an ADR; the T1 module set is fixed by ADR-0007. *Check:* POM and ADR review.

## 2. Package and boundary shape

The public package for a module is `com.voltreckon.<module>`. Implementation lives under
`com.voltreckon.<module>.internal`. A typical internal split is `application`, `domain`,
`persistence`, `web`, `messaging`, and `config`, but a module may omit a layer it does not need.

**ENG-007** A public type MUST be a command, query, result, event, error, or enum that another
module may use; an entity, repository, controller, or mapper MUST remain internal. *Check:*
package review and Modulith verification.

**ENG-008** A module MUST NOT import another module's `internal` package, including a nested
package or a test fixture. *Check:* `ArchitectureTests`.

**ENG-009** Cross-module synchronous work MUST use a public command or query and the caller's
transaction; cross-module asynchronous work MUST use a public event and the outbox. *Check:*
dependency review and transaction test.

**ENG-010** A public API record MUST NOT carry a JPA, Jackson, Servlet, or other framework
annotation; mapping to an adapter type happens inside the owning module. *Check:* import scan.

Naming follows the domain language. Use `RegisterPartnerCommand`, `PartnerQuery`,
`PartnerView`, `AgreementActivated`, and `PartnerRepository` (internal). Avoid `Manager`,
`Helper`, `Util`, and `Processor` when a domain noun exists. A suffix that hides a second
responsibility is a design smell.

## 3. Domain and application style

**ENG-011** Commands, queries, results, events, and value objects MUST be immutable records or
final value classes; a returned collection MUST be an immutable copy. *Check:* review.

**ENG-012** Business invariants MUST live in the domain or the application service that owns
the transaction, not in a controller, repository, or database callback alone. *Check:*
transaction and rule tests.

**ENG-013** A business failure MUST use a typed domain or application error with a stable code;
`RuntimeException`, `IllegalStateException`, or a generic `Exception` MUST NOT be the public
error contract. *Check:* error mapping test.

**ENG-014** Null MUST NOT cross a public API boundary as a signal; use a non-null value, an
explicit `Optional` for a query result, or an error. *Check:* API and domain review.

**ENG-015** A module MUST NOT keep mutable static state or a process-local cache that changes a
financial result; the database is the source of truth. *Check:* review.

The application service owns one use case and one transaction boundary. It loads through a
port, calls the domain, writes through a port, and publishes an outbox event. It does not
contain SQL, HTTP, or JSON parsing.

## 4. Money and time

**ENG-016** Money MUST be `long` minor units plus an ISO 4217 currency, normally through the
shared `Money` value type; `float` and `double` MUST NOT appear in a money, tax, quantity, or
netting path. *Check:* ArchUnit and review.

**ENG-017** `BigDecimal` MAY be used only for an intermediate tax, step, or allocation
calculation with an explicit scale and rounding mode; it MUST NOT be stored or returned as the
financial value. *Check:* persistence and API review.

**ENG-018** A currency's minor-unit exponent MUST come from configuration, not from an assumed
two decimals. *Check:* currency test.

**ENG-019** Instants MUST be UTC; a business date MUST use the configured Asia/Kolkata zone and
the injected `Clock`. `Instant.now`, `LocalDate.now`, and `System.currentTimeMillis` MUST NOT be
called outside `platform`. *Check:* architecture scan and time-sensitive test.

**ENG-020** An identifier for a public entity MUST be a UUIDv4; a `bigserial` or identity value
MUST NOT be exposed as an entity ID. *Check:* schema and API review.

## 5. Persistence and migrations

**ENG-021** JPA entities MUST live in the module's internal persistence package, MUST NOT be
returned from a public API, and MUST be mapped to domain values at the boundary. *Check:*
package and API review.

**ENG-022** A module MUST access only its own tables and repositories; a cross-module read MUST
use a public query API, and a report MUST use a read-only `rpt_*` view. *Check:* architecture
and schema review.

**ENG-023** Hibernate auto-DDL MUST remain disabled (`validate` only); Flyway is the only schema
writer. *Check:* configuration review.

**ENG-024** A migration MUST be forward-only, owned by one module and one phase, and MUST have
a header naming the owner, phase, and purpose. An applied migration MUST NOT be edited or
renumbered. *Check:* migration review and `validate`.

**ENG-025** A new table or column MUST update the owning module spec and 04-data-model in the
same change; a migration without both is incomplete. *Check:* diff review.

**ENG-026** Lazy loading MUST NOT cross a transaction boundary; `spring.jpa.open-in-view` stays
`false`. A query MUST fetch what the response needs. *Check:* configuration and query review.

**ENG-027** A financial trigger, check, or unique constraint MUST be tested; the application
service is not the only enforcement. *Check:* integration test.

## 6. Transactions and events

**ENG-028** The application service MUST own the transaction; a controller, repository, or
entity listener MUST NOT start or commit one. *Check:* annotation review.

**ENG-029** A remote call, message publish, or file write MUST NOT occur inside a database
transaction; the outbox is written in the transaction and delivered after commit. *Check:*
transaction review.

**ENG-030** A financial document and its journal MUST be written in one transaction through a
synchronous public command; an event MUST NOT create the journal. *Check:* atomicity test.

**ENG-031** An event MUST be an immutable public record with a versioned name, a stable payload,
an event ID, and an occurrence instant; it MUST NOT contain an internal entity, a secret, or
personal data. *Check:* event review.

**ENG-032** A consumer MUST be idempotent by event ID or a documented business key and MUST
record the processed event in the same transaction as its effect. *Check:* duplicate-delivery
test.

**ENG-033** An outbox producer and its state change MUST commit together; a failed transaction
MUST leave no event row. *Check:* rollback test.

## 7. API and web adapters

**ENG-034** A controller MUST be thin: parse and validate the request, call one public command
or query, map the result, and return the documented status; business rules MUST NOT live in the
controller. *Check:* review.

**ENG-035** An API path, method, request, response, status, error, and security scheme MUST be
in the OpenAPI file before the controller is merged. *Check:* contract test and diff order.

**ENG-036** An error MUST use RFC 9457 `application/problem+json` with a stable `code`; a stack
trace, SQL, class name, token, secret, or another partner's identifier MUST NOT appear.
*Check:* error test.

**ENG-037** Every state-changing financial request MUST require an idempotency key; replay
MUST return the original result and MUST NOT allocate a second number or row. *Check:*
idempotency test.

**ENG-038** OCPI controllers MUST stay under `/ocpi/<edition>` and use the OCPI envelope; they
MUST NOT reuse the internal problem format. *Check:* OCPI contract test.

## 8. Configuration and secrets

**ENG-039** Configuration MUST use typed `@ConfigurationProperties` under `voltreckon.*` with
validation; scattered `@Value` lookups MUST NOT define a business default. *Check:* config
review.

**ENG-040** A secret MUST come from the environment or a secret manager; a default password,
token, private key, or API key MUST NOT be committed, logged, or returned by an endpoint.
*Check:* secret scan and log test.

**ENG-041** A configuration value that changes a financial result MUST be effective-dated or
recorded on the result, not read again silently. *Check:* time-travel test.

**ENG-042** A profile MUST NOT be described as deployable until its datasource, security,
Flyway, and actuator settings are implemented and tested; `prod` and `test` are placeholders in
the current checkout. *Check:* profile review.

## 9. Logging and observability

**ENG-043** Logging MUST use SLF4J with structured key/value fields; `System.out`,
`printStackTrace`, and a raw request body MUST NOT be used. *Check:* review.

**ENG-044** A log line MUST NOT contain a token, Authorization header, `Idempotency-Key`, full
GSTIN, IRN, evidence content, card data, or personal data. Correlation and entity IDs are
allowed. *Check:* log capture test.

**ENG-045** Every request MUST carry or receive a correlation ID that appears in the problem
response and the logs. *Check:* correlation test.

**ENG-046** A metric MUST have a bounded set of tags; a partner ID, invoice ID, or other
unbounded value MUST NOT be a metric tag. *Check:* metric review.

**ENG-047** Audit is not logging. A financial or access decision that requires evidence MUST
write the audit record in its transaction; a log line is not audit evidence. *Check:* audit
test.

## 10. Static analysis and style

**ENG-048** Main code MUST use four-space indentation, no tabs, no wildcard imports, and no
commented-out code; a comment explains why, not what. *Check:* review.

**ENG-049** Checkstyle, SpotBugs, and Enforcer MUST pass under `-Pquality`; the current rule
sets are minimal scaffolding and are tightened as code lands. *Check:* quality build.

**ENG-050** A suppression MUST be narrow, local, and carry a reason; a blanket file or package
exclusion MUST NOT be added to make a build pass. *Check:* config diff.

## 11. Definition of done

A change is complete only when all of the following are true:

- the owning module spec and any affected cross-cutting doc are updated;
- the rule has a named test or an explicit manual check;
- the OpenAPI file is updated before a new or changed endpoint;
- the migration, data model map, and module spec agree;
- the event payload and consumer idempotency are defined where an event is added;
- the security matrix and error catalogue are updated;
- `mvn -B -f backend/pom.xml validate` passes;
- `mvn -B -f backend/pom.xml verify` passes when Docker is available;
- the architecture tests pass and no cross-module internal import exists;
- no secret, PII, placeholder test, or unexplained suppression is added;
- the handoff names the commands run, the result, and any remaining gap.

**ENG-051** A change that touches an issued financial row MUST add a new row, reversal, or
credit note; it MUST NOT update or delete the issued row. *Check:* trigger test and diff.

**ENG-052** A change that alters a financial, tax, security, or module-boundary rule without a
matching doc update MUST be blocked until the conflict is reported. *Check:* review.

## 12. Anti-patterns

- A `double` used for a price because "it is only a display value".
- A controller calling two repositories from different modules.
- A public record that exposes a JPA entity or a `BigDecimal` total.
- An event listener that posts a journal after commit.
- A migration edited after it has run in any shared environment.
- A test that asserts a log message instead of an observable result.
- A catch block that converts a financial failure into a success response.
- A token or GSTIN in a log line, metric tag, or error detail.
- A new library added to solve a problem the JDK or an existing dependency already solves.
- A `prod` profile assumed to work because the file exists.

## 13. Review checklist

1. Which module owns the change, and does the diff stay inside it plus public contracts?
2. Which rule ID or phase exit does this satisfy?
3. Is money exact, per-line rounded, and free of floating point?
4. Is time injected, UTC, and business-dated in Asia/Kolkata?
5. Is the transaction boundary at the application service?
6. Is the financial document atomic with its journal?
7. Is the event in the outbox and the consumer idempotent?
8. Is the migration forward-only and matched by docs?
9. Is the API in OpenAPI first, with the stable error code?
10. Is the partner scope enforced and is the cross-tenant case a 404?
11. Are secrets and personal data absent from code, logs, and fixtures?
12. Do `validate`, `verify`, and the architecture tests pass?
13. Does the handoff state what was not verified?

## 14. Acceptance scenarios

```gherkin
Scenario: A new endpoint starts with the contract
  Given a proposed invoice endpoint
  When the change adds the controller first
  Then review rejects it because the OpenAPI file and contract test are missing
  And the endpoint is merged only with both

Scenario: Money cannot become floating point
  Given a new rating calculation
  When it declares a double amount or uses a decimal string as money
  Then the architecture or review check fails
  And the value is changed to minor units

Scenario: A module does not read another module's table
  Given a settlement query that needs invoice data
  When it imports the billing repository or reads the invoice table
  Then the change is rejected
  And it uses the billing public query instead

Scenario: An applied migration is not edited
  Given V004 has run in a shared environment
  When a developer edits V004
  Then the migration check and review reject the change
  And a new forward-only migration is added

Scenario: A secret has no default
  Given a new integration credential
  When the configuration is added with a repository default
  Then the change is rejected
  And the value is read from the environment or secret manager
```

## 15. Current gaps and follow-ups

- The current code is a walking skeleton and scaffold; it does not yet demonstrate all rules.
- Checkstyle has an empty `TreeWalker` and SpotBugs has an empty exclude list; both need a
  reviewed rule set as the first real code lands.
- `verify -Pquality` currently fails in the parent project because `config.dir` resolves to
  `../config/checkstyle/checkstyle.xml` outside `backend/`, while the configs are under
  `backend/config/`. The quality gate is not green until that path is fixed.
- ArchUnit-based checks are not in the POM; Modulith checks are the current baseline.
- `application-prod.yml` and `application-test.yml` are placeholders; they are implemented
  before any deployment claim.
- CI uses Java 25 in two workflows and Java 21 in the backend workflow; the mismatch is
  recorded in 13-build-and-operations and is not fixed by this docs task.

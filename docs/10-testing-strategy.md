# 10 - Testing strategy

- **Status:** Draft
- **Owner:** VoltReckon maintainer
- **Last verified:** 2026-11-13
- **Applies to phases:** 0-10

This file defines how VoltReckon proves its rules. It owns the test layers, naming, fixture
policy, determinism, quality gates, and coverage expectations. Module specs own the named
scenarios; this file owns how those scenarios run. The simulator is in
[11-simulator-and-data.md](11-simulator-and-data.md); the build commands and CI state are in
[13-build-and-operations.md](13-build-and-operations.md).

## 1. Principles

Tests are part of the contract, not an afterthought. A rule that cannot be checked is either
rewritten until it can be checked or reported as a conflict. An empty test class is not
coverage. A test that passes because the code it exercises does not exist is worse than no
test, because it hides the gap.

The baseline in the checkout on 2026-11-13 is deliberately small. `ArchitectureTests` has two
executable checks: Modulith module verification and a scan for cross-module internal reads.
`WalkingSkeletonIT` starts PostgreSQL 18 in Testcontainers, applies Flyway V001, and calls
`/actuator/health`. Every other `*Test` or `*IT` class under `backend/` is a scaffold with no
assertions. Those scaffolds are commitments to later phases; they are not evidence that a rule
is covered.

**TEST-001** A rule MUST be considered covered only when an executable test, a build check, or
a documented manual check exercises its stated condition; a scaffold class MUST NOT be reported
as coverage. *Check:* review of the named test and its assertions.

**TEST-002** Tests MUST be layered as domain unit, application integration, persistence,
web/contract, architecture, security, end-to-end, and simulator tests; a test MUST NOT claim a
layer it does not exercise. *Check:* class package, annotations, and dependencies.

**TEST-003** Domain unit tests MUST run without Spring, a database, a web server, or the
filesystem; they test pure values, calculations, and state transitions. *Check:* test imports
and Surefire run.

**TEST-004** Integration tests MUST use a real PostgreSQL 18 instance, normally through
Testcontainers `2.0.5`, and MUST NOT use H2 or any in-memory SQL substitute. *Check:* test
configuration and CI log.

**TEST-005** A test MUST inject a fixed or mutable `Clock`; it MUST NOT depend on the host
time zone, the host clock, or a local-date default. *Check:* ArchUnit and test review.

**TEST-006** A test MUST be deterministic and independent of execution order; a randomized
test MUST print its seed and MUST be replayable from that seed. *Check:* repeated local run
and CI repeat.

**TEST-007** A test that asserts money MUST compare exact minor units and currency, never a
formatted decimal or a floating-point tolerance. *Check:* assertion review.

**TEST-008** A test of a state machine MUST cover every allowed transition and at least one
rejected transition per state. *Check:* transition matrix in the module spec and test table.

**TEST-009** A database constraint or trigger MUST be tested directly as well as through the
service that normally reaches it. *Check:* integration test that bypasses the happy path.

**TEST-010** Every stable error code in a module spec MUST have a test that asserts the status,
`application/problem+json` media type, `code`, and absence of leaked internals. *Check:* error
catalogue test.

**TEST-011** Every idempotent write MUST be tested for replay, same key with a different body,
and concurrent same-key requests. *Check:* idempotency integration test.

**TEST-012** Every outbox producer MUST be tested for atomic write and rollback; every
consumer MUST be tested for duplicate delivery. *Check:* outbox and consumer tests.

**TEST-013** Concurrency tests MUST use barriers, latches, executor shutdown, and bounded
awaits; `Thread.sleep` MUST NOT be used as a synchronisation mechanism. *Check:* test review.

**TEST-014** Every endpoint that reads or writes partner data MUST be tested for missing
authentication, missing scope, and cross-tenant access. *Check:* security integration test.

**TEST-015** The OpenAPI contract MUST be updated before the controller and checked by a
contract test in the same change. *Check:* diff order and contract test.

**TEST-016** Architecture checks MUST cover the module graph, sink rules, ledger leaf, domain
framework bans, clock usage, and money type rules as those rules become enforceable. *Check:*
`ArchitectureTests` and `-Pquality` run.

**TEST-017** Test data MUST be synthetic, licensed, or anonymised; production data, real GSTINs,
driver names, phone numbers, email addresses, card data, tokens, and secrets MUST NOT appear in
the repository or CI logs. *Check:* fixture review and secret scan.

**TEST-018** An integration test MUST own its data and MUST NOT depend on another test's rows,
execution order, or a shared mutable singleton. *Check:* parallel or shuffled run.

**TEST-019** A flaky test MUST be treated as a defect; it MUST NOT be disabled silently, and a
temporary quarantine MUST name an owner and a removal condition. *Check:* CI history and issue
reference.

**TEST-020** Phase completion requires `mvn -B -f backend/pom.xml verify` and the quality
profile where the phase adds enough code to run it; a green unit suite alone is not phase
completion. *Check:* command evidence in the handoff.

**TEST-021** A test MUST NOT assert wall-clock duration on shared CI; it may assert an invariant,
a bounded timeout, or a deterministic count. *Check:* test review.

**TEST-022** A test that counts applied migrations MUST be updated in the same change as a new
migration; it is a smoke check, not a schema contract. *Check:* diff review.

## 2. Test layers

| Layer | Class suffix | Runner | Allowed runtime | Purpose |
|---|---|---|---|---|
| Domain unit | `Test` | Surefire | JDK only | Money, tax arithmetic, state machines, value objects |
| Application unit | `Test` | Surefire | JDK plus in-module fakes | Command orchestration without infrastructure |
| Integration | `IT` | Failsafe | Spring context plus PostgreSQL 18 | Transactions, constraints, repositories, outbox |
| Web contract | `Test` or `IT` | Surefire or Failsafe | Spring MVC or a running port | OpenAPI, errors, headers, auth |
| Architecture | `Test` | Surefire | Bytecode and Modulith metadata | Module and dependency rules |
| End-to-end | `IT` | Failsafe | Full deployable plus PostgreSQL | Cross-module financial flow |
| Simulator | `Test` | Surefire | JDK plus simulator classes | Determinism and fault catalogue |

Unit tests are fast and numerous. Integration tests are fewer and prove the pieces that only a
real database can prove. End-to-end tests are the smallest set and cover one complete financial
story. No layer is a substitute for another.

## 3. Naming and placement

**TEST-023** A unit or contract test MUST be named `*Test` and run under Surefire; an
integration test MUST be named `*IT` and run under Failsafe. *Check:* build plugin output.

**TEST-024** A test package MUST mirror the production package it owns, with no test-only
package that hides a module boundary. *Check:* package review.

**TEST-025** A test name MUST state the behaviour and the rejected condition, not a ticket
number or an implementation detail. *Check:* review.

Examples of acceptable names are `CreditCannotExceedOriginalIT`, `CrossTenantInvoiceReadIT`,
and `HeldInvoiceIsExcludedFromNettingIT`. A name that restates a class (`InvoiceServiceTest`)
is not sufficient.

## 4. Determinism and fixtures

**TEST-026** Fixtures MUST be built from named test data with fixed identifiers and explicit
timestamps, not from random UUIDs or the current time. *Check:* fixture review.

**TEST-027** A randomized or seeded test MUST keep the seed in the failure output and MUST use
a bounded number of iterations that finishes in CI. *Check:* failure log and run time.

**TEST-028** A fixture MUST NOT include a real person, a real company GSTIN, a real token, or a
real charger location. *Check:* review and secret scan.

**TEST-029** A test MUST assert the stored representation as well as the returned view where a
financial rule changes persistence. *Check:* integration test.

**TEST-030** Time-sensitive tests MUST use `TestClock` or an equivalent mutable clock from
`platform`; they MUST NOT manipulate the system clock. *Check:* test review.

The support package currently contains empty scaffolds for `TestClock`, `CdrFixtures`,
`PostgresTestConfig`, `KafkaTestConfig`, and `JwtTestSupport`. `KafkaTestConfig` is not used in
T1 and is removed or left unused until an ADR changes the event transport. The other scaffolds
are filled in the phase that first needs them; until then a test must not pretend they exist.

## 5. Financial and state invariants

The following checks are mandatory in the owning phase, even when the database also enforces
them:

| Invariant | Minimum test shape |
|---|---|
| Per-line `HALF_UP`, then sum | Golden table with a half-minor-unit case |
| Credit negates original lines and tax | Credit result compared line by line |
| Invoice total equals lines plus tax | Header and line reconciliation |
| Journal debits equal credits | Deferred trigger test at commit |
| Reversal nets to zero | Original plus reversal trial balance |
| One active rating per CDR | Concurrent re-rate with one winner |
| Issued invoice immutable | Direct update and delete attempts |
| Credit note within remaining amount | Boundary at exact and excess amount |
| Held invoice excluded from netting | Eligibility matrix and statement exclusion |
| Settlement statement reproducible | Two runs, same canonical hash |
| Audit chain detects a broken record | Tamper one hash, verify failure |
| Cross-tenant read hides existence | 404 with `RESOURCE_NOT_FOUND` |

**TEST-031** A financial invariant test MUST fail on the smallest change that breaks the rule;
a test that still passes after the rule is removed is not evidence. *Check:* mutation review.

**TEST-032** A property-style test MUST use a seeded loop with a fixed case count and a
shrinking example on failure; it MUST NOT add a property-testing dependency without an ADR.
*Check:* dependency review and failure output.

## 6. Module coverage map

The named tests below are the minimum phase commitments. A module may add tests; it may not
drop one without updating its spec and this map.

| Module | Primary unit tests | Primary integration tests |
|---|---|---|
| `shared`, `platform` | `MoneyTest`, `CurrencyTest`, `ProblemMappingTest` | `IdempotencyIT`, `OutboxRollbackIT`, `SequenceAllocationIT` |
| `partners` | `GstinTest`, `AgreementTermsTest` | `PartnerUniquenessIT`, `GstinOverlapIT`, `AgreementOverlapIT`, `PartnerEventIT` |
| `iam` | `RoleMatrixTest`, `PartnerScopeTest` | `AuthorizationIT`, `SuspendedPartnerIT`, `MakerCheckerIT` |
| `tariff` | `TariffHashTest`, `TaxWindowTest` | `EffectiveBoundaryIT`, `VersionOverlapIT`, `TaxRateWindowIT`, `AgreementLinkIT` |
| `ingestion` | `CdrValidationPipelineTest`, `CreditRulesTest` | `OcpiCdrReceiverIT`, `CdrReplayIT`, `CdrDuplicateHashIT`, `CreditCdrIT`, `QuarantineIsolationIT`, `CsvImportIT` |
| `rating` | `RatingArithmeticTest`, `RestrictionTest` | `RatingGoldenIT`, `RatingDeterminismIT`, `SessionStartTariffIT`, `RatingConcurrencyIT`, `CreditRatingIT`, `RatingFailureIT` |
| `ledger` | `JournalValidationTest`, `AccountCodeTest` | `JournalBalanceIT`, `PostingReplayIT`, `PeriodCloseIT`, `ReversalIT`, `TrialBalanceIT`, `LedgerArchitectureTest` |
| `billing` | `GstCalculatorTest`, `TaxSplitTest` | `InvoiceGoldenIT`, `InvoiceImmutabilityIT`, `InvoiceNumberingIT`, `CreditNoteLimitIT`, `CreditNoteApprovalIT`, `InvoicePostingRollbackIT`, `SettlementHoldIT`, `TaxPointIT` |
| `dispute` | `DisputeTransitionsTest`, `EvidenceHashTest` | `DisputeHoldIT`, `DisputeTimelineIT`, `DisputeIsolationIT` |
| `reconciliation` | `MatchRulesTest`, `StatementParserTest` | `StatementReplayIT`, `MatchMatrixIT`, `CreditReconciliationIT`, `ExceptionResolutionIT`, `ReconciliationIsolationIT`, `ReconciliationEventIT` |
| `settlement` | `NettingSignTest`, `NettingEngineTest` | `NettingEligibilityIT`, `SettlementHoldIT`, `MakerCheckerIT`, `SettlementAtomicityIT`, `SettlementUniquenessIT`, `StatementHashTest` |
| `audit` | `ChainVerifierTest`, `RedactionTest` | `AuditAppendOnlyIT`, `AuditChainIT`, `AuditCheckpointIT` |
| `reporting` | `ReportScopeTest` | `ReportTotalsIT`, `ReportRangeIT`, `ViewReadOnlyIT` |
| Whole product | None | `CdrToSettlementFlowIT`, `CrossTenantMatrixIT`, `OpenApiContractTest` |

`PricingEngineTest`, `PostingServiceIT`, `InvoiceStateIT`, `SettlementApprovalIT`,
`IngestCdrIT`, and `CdrToSettlementFlowIT` exist in the checkout as scaffolds. They are kept
as the first landing points for their phases and are not reported as passing behaviour.

## 7. PostgreSQL and Testcontainers

**TEST-033** Integration tests MUST use the `postgres:18` image through
`org.testcontainers.postgresql.PostgreSQLContainer`; a pinned patch tag MAY replace `18` only
when the compose baseline and CI agree. *Check:* test source and CI.

**TEST-034** A test suite MUST reuse one PostgreSQL container per JVM unless isolation requires
more; each test MUST still be isolated by transaction rollback, unique data, or a documented
cleanup. *Check:* suite runtime and repeated run.

**TEST-035** Flyway MUST run against the test database with the same migration locations as
production; a test MUST NOT provision the schema with Hibernate or outside the Flyway migration
set. *Check:* test configuration.

**TEST-036** A test MUST NOT assume a fixed migration count after V002; the baseline count
assertion in `WalkingSkeletonIT` is updated by the migration change that invalidates it.
*Check:* V002 diff.

**TEST-037** A test MUST NOT enable `spring.jpa.hibernate.ddl-auto` beyond `validate`, and MUST
NOT enable Flyway `clean` on a shared or production profile. *Check:* configuration review.

The test profile file `application-test.yml` is currently a placeholder. Tests use
`@DynamicPropertySource` for datasource properties and do not rely on that file until the test
profile is implemented in the phase that needs it.

## 8. Contract tests

**TEST-038** `OpenApiContractTest` MUST compare the served paths, methods, request schemas,
response schemas, status codes, content types, security schemes, and required headers with
`backend/voltreckon-app/src/main/resources/openapi/openapi.yaml`. *Check:* contract test.

**TEST-039** A contract test MUST fail when a controller exposes an operation not in the
contract, or when the contract declares an operation the application does not serve. *Check:*
negative contract fixture.

**TEST-040** OCPI endpoints MUST be contract-tested against their own envelope and MUST NOT be
validated against the internal `/api/v1` problem format. *Check:* OCPI contract test.

**TEST-041** The contract test MUST use the repository OpenAPI path, not the stale
`docs/api/openapi.yaml` comment in the build file. *Check:* path review.

The OpenAPI file does not exist yet. ADR-0010 requires it before the first endpoint, so Phase 1
adds the file and the contract test together. Until then `OpenApiContractTest` remains a
scaffold and is not described as passing.

## 9. Architecture tests

`ApplicationModules.verify()` is the baseline. The current second test rejects a dependency on
a type in another module's non-exposed package. Later phases add the following checks:

- the legal module order and forbidden edges from 03-architecture;
- `ledger` imports only `shared`, with persistence adapters inside its own module;
- `audit` and `reporting` are sinks and are imported by no domain module;
- no domain class imports Spring, JPA, Jackson, Servlet, or a web type;
- no `float` or `double` field or local in a money path;
- no `Instant.now`, `LocalDate.now`, or `System.currentTimeMillis` outside `platform`;
- no public method returns a persistence entity;
- no controller calls another module's repository.

**TEST-042** The full architecture graph MUST be executable before Phase 2 closes; a review
comment is not a substitute. *Check:* `ArchitectureTests` and `-Pquality`.

**TEST-043** ArchUnit rules MAY be added under the accepted ADR-0012; if the dependency is not
present, Modulith checks plus import scans remain the enforceable subset. *Check:* POM and
test run.

## 10. Security tests

**TEST-044** The authorization matrix MUST cover every endpoint and every role and scope pair
that the endpoint accepts; a new endpoint without a matrix row is incomplete. *Check:*
matrix review and `AuthorizationIT`.

**TEST-045** A cross-tenant test MUST assert `404 RESOURCE_NOT_FOUND` and MUST assert that no
partner name, ID, amount, GSTIN, or count from the other tenant appears in the body. *Check:*
response assertion.

**TEST-046** A log-capture test MUST prove that tokens, `Idempotency-Key`, full GSTINs, IRNs,
request bodies, and evidence contents are absent or redacted. *Check:* log appender test.

**TEST-047** Maker-checker tests MUST cover same-user rejection, missing approval, wrong role,
and successful two-user approval. *Check:* `MakerCheckerIT`.

**TEST-048** A security test MUST cover malformed JSON, oversized body, unsupported media type,
unknown field, missing `Idempotency-Key`, and a stale `If-Match`. *Check:* negative API suite.

## 11. Concurrency, faults, and failure injection

**TEST-049** A concurrency test MUST drive at least two real transactions or requests, not two
sequential calls. *Check:* barrier and executor in the test.

**TEST-050** A rollback test MUST prove that no document, journal, number, idempotency result, or
outbox row survives a failed transaction. *Check:* post-failure database assertions.

**TEST-051** A duplicate-delivery test MUST deliver the same event ID twice and assert one
business effect and one consumer record. *Check:* consumer test.

**TEST-052** A failure in an unrelated CDR or event MUST NOT abort the batch or hide the
per-item reason. *Check:* mixed-run test.

The simulator in 11-simulator-and-data supplies duplicate storms, late and skewed sessions,
credits, negative values, and dispute-heavy data. Simulator tests prove the generator; module
tests prove the receiver.

## 12. Quality gates and evidence

The parent POM wires Enforcer `3.6.3`, JaCoCo `0.8.15`, Checkstyle `3.6.0` with Checkstyle
`13.4.2`, SpotBugs `4.9.8.3`, Surefire, and Failsafe. The current JaCoCo line threshold is
`0.00` because the tree is scaffold; it is raised in the phase that adds real tests. The
Checkstyle `TreeWalker` is currently empty and the SpotBugs exclude file is empty, so the
wiring is present but the rule set is not yet a strong gate. The `-Pquality` run also fails in
the parent project before Checkstyle starts because `config.dir` resolves outside `backend/`;
that is a recorded build defect, not evidence of a green quality gate. None of these facts is
evidence that the code is clean.

**TEST-053** A handoff MUST include the exact commands run and their result; a claimed pass
without a runnable result is a defect. *Check:* handoff review.

**TEST-054** Coverage MUST NOT be increased with assertion-free tests, reflection-only calls, or
tests that duplicate the implementation. *Check:* review.

**TEST-055** A failing or skipped test MUST be visible in the phase handoff; a skip count is not
a pass. *Check:* Surefire and Failsafe reports.

## 13. Acceptance scenarios

```gherkin
Scenario: Duplicate CDR never creates a second financial record
  Given an accepted CDR for a partner pair
  When the same payload is posted again with the same idempotency key
  Then the stored CDR is returned
  And no second CDR, rating result, invoice, or journal exists

Scenario: A failed invoice issue leaves no partial state
  Given a valid draft invoice and a closed accounting period
  When issue is attempted
  Then the invoice remains DRAFT
  And no number is consumed
  And no journal or outbox event exists

Scenario: Cross-tenant access does not disclose existence
  Given an invoice owned by partner B
  When a user scoped to partner A requests it
  Then the response is 404 RESOURCE_NOT_FOUND
  And the body contains no partner B data

Scenario: A contract change is visible before the controller
  Given a new endpoint described only in code
  When the contract test runs
  Then it fails with the undeclared operation
  And the OpenAPI file is updated first

Scenario: A seeded property loop is reproducible
  Given a failing ledger netting case discovered with seed 424242
  When the test is rerun with that seed
  Then the same case fails with the same input
```

## 14. Current gaps and phase follow-ups

- Phase 0 has two executable test classes; all other test classes under `backend/` are scaffolds.
- `WalkingSkeletonIT` asserts one applied migration; V002 updates the assertion with the
  migration.
- `OpenApiContractTest` and the OpenAPI file land before the first Phase 1 endpoint.
- ArchUnit-based rules land with the phase that adds the test dependency; Modulith remains the
  baseline until then.
- `application-test.yml` and `application-prod.yml` are placeholders; tests use dynamic
  properties and do not claim those profiles work.
- `KafkaTestConfig` has no T1 purpose; event tests use the Modulith outbox and PostgreSQL.
- Coverage thresholds and the Checkstyle/SpotBugs rule sets are raised as code lands, not
  claimed in advance.
- CI must eventually align on Java 21 and run the quality profile; 13-build-and-operations
  records the current mismatch.

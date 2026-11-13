# 13 - Build and operations

- **Status:** Draft
- **Owner:** VoltReckon maintainer
- **Last verified:** 2026-11-13
- **Applies to phases:** 0-10

This file is the operational contract for building, running, migrating, backing up, and
diagnosing VoltReckon. It records the versions verified in the build on 2026-11-13 and names
the settings that are still scaffolding. It does not claim that a production deployment exists.
The migration map is in [04-data-model.md](04-data-model.md); the test evidence rules are in
[10-testing-strategy.md](10-testing-strategy.md).

## 1. Runtime baseline

| Item | Verified value | Source or note |
|---|---|---|
| Java | 21 | Parent POM `maven.compiler.release` |
| Maven | 3.9 or newer | Enforcer requirement |
| Spring Boot | 4.1.2 | Parent BOM |
| Spring Modulith | 2.1.0 | BOM |
| springdoc | 3.0.3 | Dependency management |
| PostgreSQL | 18 | `compose.yaml` image `postgres:18` |
| PostgreSQL JDBC | 42.7.14 | Resolved by the Boot BOM |
| Flyway | 12.4.0 | Resolved by the Boot BOM |
| Testcontainers | 2.0.5 | Test dependencies |
| JaCoCo | 0.8.15 | Parent POM |
| Enforcer | 3.6.3 | Parent POM |
| Checkstyle | plugin 3.6.0, engine 13.4.2 | Parent POM |
| SpotBugs | plugin 4.9.8.3 | Parent POM |

**OPS-001** The application MUST remain one Spring Boot deployable, one PostgreSQL database,
and one schema `voltreckon`; a second service or store requires an ADR. *Check:* POM, compose,
and deployment review.

**OPS-002** The build MUST use Java 21 and Maven 3.9 or newer; a newer local JDK may compile
the project only when it produces Java 21 bytecode. *Check:* Enforcer and compiler release.

**OPS-003** PostgreSQL 18 is the only runtime database; H2, an embedded SQL database, or a
second relational store MUST NOT be used in tests or production. *Check:* POM and test
configuration.

**OPS-004** The resolved versions in this table MUST be rechecked with
`mvn help:evaluate` after a Boot, Flyway, Testcontainers, or springdoc change; this table is
not a substitute for the POM. *Check:* dependency review.

## 2. Build commands

Run from the repository root on Windows PowerShell:

```powershell
mvn -B -f backend/pom.xml validate
mvn -B -f backend/pom.xml verify
mvn -B -f backend/pom.xml verify -Pquality
```

**OPS-005** `validate` MUST pass before a commit; `verify` MUST pass before a phase handoff when
Docker is available; a claim of a green build MUST include the command and result. *Check:*
handoff review.

**OPS-006** A build artifact or `target/` directory MUST NOT be used to infer source state; run
`mvn clean` before trusting generated output after a branch switch or failed build. *Check:*
build review.

**OPS-007** Integration tests require Docker because Testcontainers starts PostgreSQL 18; a
missing Docker daemon is reported as an environment gap, not as a test pass. *Check:* Failsafe
log.

The quality profile is intended to run Enforcer, Checkstyle, SpotBugs, and JaCoCo. It currently
fails in the parent project before Checkstyle starts: `config.dir` resolves to
`../config/checkstyle/checkstyle.xml` outside `backend/`, while the configs are under
`backend/config/`. The Checkstyle `TreeWalker` and SpotBugs exclude list are also minimal. The
JaCoCo line threshold is `0.00` while the tree is scaffold; it rises with real tests. These are
current facts, not a quality claim.

## 3. Local run

```powershell
docker compose up -d postgres
$env:SPRING_PROFILES_ACTIVE = "local"
mvn -f backend/voltreckon-app spring-boot:run
curl.exe http://localhost:8080/actuator/health
```

The local profile reads `POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_DB`, `POSTGRES_USER`, and
`POSTGRES_PASSWORD` with defaults that match `compose.yaml`. The defaults are local-only and are
not reused in a shared environment; `OPS-008` makes that boundary explicit.

```powershell
docker compose ps
docker compose logs postgres
docker compose down
docker compose down -v
```

`docker compose down -v` deletes the local database volume. It is destructive and is used only
for a deliberate local reset.

## 4. Profiles and configuration

**OPS-008** The `local` profile MUST default to the compose PostgreSQL instance, MUST be safe to
run without a production secret, and MUST NOT reuse its default credentials in a shared
environment. *Check:* `application-local.yml`.

**OPS-009** The `prod` and `test` profile files are placeholders in the current checkout and
MUST NOT be described as deployable until datasource, TLS, security, Flyway, and actuator
settings are implemented and tested. *Check:* profile review.

**OPS-010** Production configuration MUST come from environment variables or a secret manager;
no password, token, private key, or client secret may be committed with a default. *Check:*
secret scan.

**OPS-011** Flyway MUST remain enabled, Hibernate `ddl-auto` MUST remain `validate`, and
`spring.jpa.open-in-view` MUST remain `false`. *Check:* configuration review.

**OPS-012** A business-date or clock setting MUST be explicit; the application uses UTC
instants and Asia/Kolkata business dates, never the host default zone. *Check:* time test.

**OPS-013** A new `voltreckon.*` configuration key MUST be typed, validated, documented in the
owning module spec, and given a safe default or an explicit required flag. *Check:* config
review.

Core keys by owner are listed in the module specs. The operational groups are:

| Group | Examples | Owner |
|---|---|---|
| Time and IDs | clock zone, business-date zone | `platform` |
| Outbox and idempotency | retention, replay window | `platform` |
| Ingestion | body limit, raw payload, CSV rows, credit tolerance | `ingestion` |
| Tariff and tax | effective-date zone, version limits, tax kinds | `tariff` |
| Rating | batch size, variance tolerance, retries | `rating` |
| Ledger | period zone, chart version, line limit | `ledger` |
| Billing | SAC, prefixes, due days, e-invoice switch | `billing` |
| Reconciliation | file size, line limit, tolerance | `reconciliation` |
| Settlement | item limit, second approver, prefix | `settlement` |
| Reporting | range cap, export limit | `reporting` |

The exact defaults are in the module specs and are not repeated here to avoid a second source
of truth.

## 5. Database and migration operations

V001 creates the `btree_gist` extension and the `voltreckon` schema. V002-V017 are owned by the
modules and phases in 04-data-model. `WalkingSkeletonIT` currently asserts one applied
migration; that assertion is updated when V002 lands.

**OPS-014** Flyway is forward-only; an applied migration MUST NOT be edited, renumbered, or
deleted. A correction is a new migration. *Check:* checksum and review.

**OPS-015** One migration MUST belong to one module and one phase and MUST carry a header naming
the owner, phase, and purpose. *Check:* migration review.

**OPS-016** The application MUST NOT run Hibernate schema generation; the schema is the Flyway
history plus the migration files. *Check:* startup configuration.

**OPS-017** In production, schema migration MUST run under a dedicated migration identity; the
runtime application role MUST NOT have DDL rights. *Check:* database role review.

**OPS-018** Flyway `clean` MUST NOT be enabled on a shared, staging, or production database.
*Check:* configuration review.

**OPS-019** A migration MUST be backward-compatible for one application version: add and
backfill before enforce, and drop only after the old application version is retired. A long
table rewrite or lock MUST be planned with a measured maintenance window. *Check:* migration
review.

**OPS-020** A failed migration MUST stop startup and MUST NOT be hand-repaired without a
recorded recovery decision. *Check:* startup behavior and incident note.

**OPS-021** The runtime role MUST be least-privileged on the `voltreckon` schema and MUST NOT
be a PostgreSQL superuser. *Check:* role review.

**OPS-022** A production PostgreSQL connection MUST use TLS; a local compose connection may use
the local default. *Check:* connection configuration.

The V-number order is fixed: V002 platform, V003 partners, V004 ingestion, V005 partners GST and
agreements, V006 IAM, V007 tariff, V008 rating, V009 ledger, V010 chart seed, V011 billing,
V012 reconciliation, V013 dispute, V014 settlement, V015 audit, V016 reporting views, V017
OCPI invoice reconciliation. An applied migration is never reordered.

## 6. Health and readiness

**OPS-023** The public health endpoint MUST remain `/actuator/health` and MUST NOT expose
details, environment values, datasource URLs, or component internals. *Check:* health response.

**OPS-024** Production exposure MUST be `health` only; the current `application.yml` still
includes `info`, and ADR-0011 requires the exposure to be reduced to `health` before
deployment. *Check:* configuration review.

**OPS-025** A liveness check MUST NOT depend on every downstream dependency; a readiness check
MAY verify the database and applied migrations. The current checkout has a single health
endpoint, not a liveness/readiness split. *Check:* deployment review.

**OPS-026** A startup check MUST fail fast when Flyway validation fails or the schema is
missing; the application MUST NOT serve financial traffic against an unknown schema. *Check:*
startup test.

## 7. Observability and logs

**OPS-027** Logs MUST go to standard output as structured events with a timestamp, level,
logger, `traceId` or correlation ID, and safe entity IDs. *Check:* log review.

**OPS-028** A log line MUST NOT contain a token, Authorization header, `Idempotency-Key`, full
GSTIN, IRN, evidence content, card data, or personal data. *Check:* redaction test.

**OPS-029** Audit records MUST be written to the audit module in the business transaction; a
log line, metric, or external collector MUST NOT be the audit source. *Check:* audit test.

**OPS-030** Metrics and distributed tracing are T2. No OTel, Prometheus, Grafana, Loki, Tempo,
or collector dependency may be added to T1 without the trigger in 01-product-scope and an ADR.
*Check:* dependency review.

**OPS-031** A metric name and tag set MUST be documented with the owning module when the
metric is added; an unbounded tag is forbidden. *Check:* metric review.

## 8. Backup, restore, and retention

**OPS-032** A production backup MUST be encrypted, stored outside the database host, and
restore-tested before the deployment is considered operational. *Check:* restore evidence.

**OPS-033** PostgreSQL point-in-time recovery, retention, and the recovery point and time
objectives are infrastructure decisions; they MUST be documented for the deployment and MUST
NOT be inferred from this file. *Check:* operations runbook.

**OPS-034** A restore MUST stop application writes, restore the database, verify the Flyway
history and `btree_gist`, and run a read-only smoke query before traffic resumes. *Check:*
restore runbook.

**OPS-035** The application MUST NOT delete issued financial rows, audit rows, or completed
statements. Retention follows the tax and legal review; idempotency records are removed 48
hours after expiry, processed events after 90 days, completed outbox rows after 7 days, and raw
CDR payloads after 24 months, all by configuration. *Check:* retention job review.

Example backup command with the PostgreSQL 18 client, using environment values and a protected
destination:

```powershell
pg_dump -Fc -h $env:POSTGRES_HOST -U $env:POSTGRES_USER -d $env:POSTGRES_DB -f voltreckon.dump
pg_restore -h $env:POSTGRES_HOST -U $env:POSTGRES_USER -d $env:POSTGRES_DB --clean --if-exists voltreckon.dump
```

`pg_restore --clean` is destructive and is used only in a verified restore environment, never
against the live database.

## 9. Deployment and rollback

**OPS-036** T1 is a single application instance with PostgreSQL advisory locks or database
uniqueness for serialization; it MUST NOT depend on sticky sessions or a process-local lock.
*Check:* concurrency test and deployment review.

**OPS-037** The application MUST expose no stateful session, cookie login, or local file store
that a restart would lose; evidence and statements that must survive a restart are in
PostgreSQL or an external store. *Check:* deployment review.

**OPS-038** A deployment MUST run the Flyway migration before or during startup under the
migration identity, then start the application under the runtime identity. *Check:* pipeline
review.

**OPS-039** A rollback MUST be application-only unless a migration is backward-compatible; a
database rollback is a restore, not a Flyway `undo`. *Check:* release runbook.

**OPS-040** A release artifact MUST be built from the committed source, versioned, and
checksummed; a mutable or locally patched artifact MUST NOT be deployed. *Check:* release
record.

**OPS-041** T1 MUST NOT use Kafka, Redis, Spring Batch, Kubernetes, a microservice split, or an
AI dependency in the financial path. *Check:* dependency and deployment review.

## 10. CI and supply chain

Current workflows on 2026-11-13:

| Workflow | Current behaviour | Required alignment |
|---|---|---|
| `backend-ci.yml` | Java 21, backend `verify` on backend paths | Keep Java 21; add quality profile after the baseline is green |
| `ci.yml` | Java 25, docs and stale contract checks | Move to Java 21 and update docs paths and the OpenAPI location |
| `codeql.yml` | Java 25 | Move to Java 21 |
| `dependency-review.yml` | Dependency review on pull requests | Keep enabled |
| `frontend-ci.yml` | Node 22, lint, build, test for `frontend/**` | No backend impact |

**OPS-042** CI MUST use Java 21 for the application build and analysis; the current Java 25
workflows are a recorded mismatch, not an approved target. *Check:* workflow review.

**OPS-043** CI MUST run the backend `verify` against real PostgreSQL through Testcontainers; a
unit-only CI run MUST NOT be reported as full verification. *Check:* CI log.

**OPS-044** The docs job MUST reference the current docs tree and the OpenAPI file at
`backend/voltreckon-app/src/main/resources/openapi/openapi.yaml`; the current job still checks
older paths and is not a valid gate until updated. *Check:* CI diff.

**OPS-045** Dependency review and CodeQL MUST remain enabled; secret scanning is a required
target under `SEC-047` and is not yet present in the workflow set. *Check:* workflow inventory.

**OPS-046** A workflow file, `LICENSE`, or `compose.yaml` MUST NOT be changed by a docs-only
task; `README.md` changes only in the final docs reconciliation commit. Any other exception
requires its own scoped request. *Check:* diff review.

## 11. Runbook

| Symptom | First checks | Safe action |
|---|---|---|
| Application will not start | Flyway validation, datasource, port 8080, missing env | Read the first cause; do not delete migration history |
| Health is not UP | Database reachable, Flyway complete, disk, credentials | Fix the dependency; do not bypass health |
| Integration test cannot start Docker | Docker daemon and Testcontainers pull | Report environment gap; do not replace PostgreSQL with H2 |
| Port 8080 is busy | Owning process and local profile | Stop the other process or set a different local port |
| Migration checksum mismatch | Applied file diff, git history, target environment | Stop; restore or add a forward migration; never edit history |
| Duplicate financial document | Idempotency key, source hash, transaction log | Investigate; do not delete a posted row |
| Settlement cannot complete | Ledger period, held invoices, second approver | Resolve the stated cause; do not force status |
| Audit chain verification fails | First broken sequence, restore point | Stop exports; preserve evidence; follow the incident path |
| Suspected token compromise | Issuer, audience, token ID, access logs | Revoke and rotate at the issuer; preserve audit evidence |
| Suspected database corruption | PostgreSQL logs, backup status, last known good | Stop writes; restore to a verified environment |

**OPS-047** An incident response MUST preserve audit and financial evidence; deleting a row,
editing a migration, or rewriting a statement to hide a symptom is forbidden. *Check:* incident
review.

**OPS-048** A production smoke test MUST be read-only or use a designated synthetic partner; it
MUST NOT create a real invoice, journal, or settlement in a live partner's books. *Check:*
smoke-test review.

## 12. Acceptance scenarios

```gherkin
Scenario: A clean build is reproducible
  Given a clean checkout and Docker
  When validate and verify run
  Then the reactor succeeds
  And the PostgreSQL 18 container starts
  And Flyway applies V001

Scenario: Health is safe to expose
  Given a running local application
  When /actuator/health is requested
  Then the response is 200 with status UP
  And no datasource URL, secret, or component detail is present

Scenario: An applied migration is not edited
  Given V004 has run in a shared environment
  When a developer edits its checksum
  Then Flyway validation fails
  And startup stops instead of repairing silently

Scenario: A missing production profile blocks a deployment claim
  Given only the placeholder prod profile
  When a release is proposed
  Then the release is blocked until datasource, TLS, security, Flyway, and actuator settings are implemented and tested

Scenario: A restore is verified before traffic
  Given an encrypted backup
  When it is restored into an isolated environment
  Then the Flyway history is complete
  And the health endpoint is UP
  And the smoke query reads only expected data
```

## 13. Current gaps and follow-ups

- `application-prod.yml` and `application-test.yml` are placeholders.
- `application.yml` exposes `health,info`; ADR-0011 requires `health` only.
- Only V001 exists; V002-V017 are planned and not applied.
- CI Java versions and the docs job paths are stale; they are not fixed in this docs task.
- `verify -Pquality` fails in the parent project on the Checkstyle config path; the path fix
  is a backend follow-up, not a docs change.
- Secret scanning is not yet a workflow; `SEC-047` remains a target.
- No release artifact, SBOM, or production deployment exists.
- Backup, point-in-time recovery, and RPO/RTO are infrastructure decisions; this file defines
  the verification requirement, not a service-level number.

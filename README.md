# VoltReckon

**Settlement and reconciliation engine for EV-charging roaming.**

VoltReckon is a modular monolith for the B2B back office of EV charging. It accepts OCPI CDRs,
validates and de-duplicates them, rates sessions against the tariff version effective at
session start, produces GST-aware invoice data, keeps an append-only double-entry ledger,
reconciles partner statements, manages disputes, nets partner balances, and exports audit
evidence.

The build contract is in [`docs/`](docs/README.md). Code implements the documents; the
documents do not describe aspirational code. When code and docs disagree, the human prompt
wins, then an accepted ADR, then a module spec.

> **Status: Phase 0.** The repository has a working Spring Boot walking skeleton: one
> deployable, PostgreSQL 18, schema `voltreckon`, Flyway V001, `/actuator/health`, and a
> module-boundary test. Documentation is Draft. Most domain packages, the frontend, and the
> simulator are scaffolds; no production financial feature is implemented.

## Current state

| Area | State |
|---|---|
| Documentation | 15 numbered docs, 13 module specs, 13 accepted ADRs plus a template. Draft. |
| Backend shell | Spring Boot app starts; health endpoint responds; Flyway V001 applies; `ArchitectureTests` and `WalkingSkeletonIT` pass. |
| Domain modules | Package scaffolds for `shared`, `platform`, `partners`, `iam`, `tariff`, `ingestion`, `ledger`, `billing`, `dispute`, `reconciliation`, `settlement`, `audit`, and `reporting`. No implemented endpoints or persistence yet. `rating` is planned before Phase 3. |
| OCPI model | Model package scaffold; its JSON round-trip tests are placeholders. |
| Frontend | Vite/React source tree in `frontend/`; not wired to a working API and not part of the T1 financial path. |
| Simulator | Maven module with scenario and seed files; generator and chaos classes are scaffolds. |
| Deployment | `compose.yaml` runs PostgreSQL 18. Docker and observability assets exist, but production deployment is not verified. |
| Quality | `validate` and `verify` pass with Docker; `verify -Pquality` currently fails on the parent Checkstyle path. |

## Stack

| Item | Version or choice |
|---|---|
| Language | Java 21 source and bytecode; a newer local JDK is allowed with `--release 21` |
| Build | Maven 3.9+ |
| Framework | Spring Boot 4.1.2 |
| Modularity | Spring Modulith 2.1.0 |
| Database | PostgreSQL 18 |
| Migrations | Flyway 12.4.0, forward-only |
| API docs | springdoc 3.0.3 plus OpenAPI |
| Testing | JUnit 5, AssertJ, Testcontainers 2.0.5 |
| Local runtime | Docker Compose |

Do not infer source state from `target/`; run `mvn clean` before trusting generated output
after a branch switch or failed build.

## Repository layout

```text
backend/
  pom.xml                    Parent build, versions and quality profiles
  voltreckon-app/            The single deployable; modules, migrations and tests
  voltreckon-ocpi-model/     Pure OCPI model; no Spring
  voltreckon-simulator/      Synthetic partner and fault generator scaffold
  config/                    Checkstyle and SpotBugs configuration
frontend/                    Vite/React back-office shell
deploy/                      Docker and observability assets
docs/                        Build contract, module specs, ADRs and references
scripts/                     Local development helper scripts
compose.yaml                 PostgreSQL 18 for local development
Makefile                     Common local commands
```

## Quick start

Prerequisites: JDK 21, Maven 3.9+, Docker Desktop, and Git.

```powershell
docker compose up -d postgres
mvn -B -f backend/pom.xml validate
mvn -B -f backend/pom.xml verify
$env:SPRING_PROFILES_ACTIVE = "local"
mvn -f backend/voltreckon-app spring-boot:run
curl.exe http://localhost:8080/actuator/health
```

The expected health response is `{"status":"UP"}`.

- `verify` needs Docker because Testcontainers starts PostgreSQL 18. A missing Docker daemon
  is an environment gap, not a test pass.
- The `local` profile reads `POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_DB`,
  `POSTGRES_USER`, and `POSTGRES_PASSWORD`. Its defaults match `compose.yaml` and are for
  local use only.
- V001 creates the `btree_gist` extension and the `voltreckon` schema. It creates no business
  tables.

Stop or reset the local database:

```powershell
docker compose down
docker compose down -v
```

`docker compose down -v` deletes the local database volume. It is destructive.

## Build and quality

```powershell
mvn -B -f backend/pom.xml validate
mvn -B -f backend/pom.xml verify
mvn -B -f backend/pom.xml verify -Pquality
```

`validate` runs Enforcer for Maven and Java versions. `verify` runs unit tests, Testcontainers
integration tests, and JaCoCo. The `quality` profile is intended to run Checkstyle and
SpotBugs, but currently fails in the parent project because `config.dir` resolves to
`../config/checkstyle/checkstyle.xml` outside `backend/`; the configuration lives under
`backend/config/`.

## Architecture

The legal dependency order is:

```text
shared, platform, partners, iam, tariff, ingestion, ledger,
rating, billing, dispute, reconciliation, settlement, audit, reporting
```

- Public API lives in `com.voltreckon.<module>`; implementation lives in
  `com.voltreckon.<module>.internal`.
- `ledger` is a leaf and depends only on `shared`. `audit` and `reporting` are sinks.
- Cross-module synchronous work uses a public command in the caller's transaction.
- Cross-module asynchronous work uses a public event, the transactional outbox, and
  `processed_event`.
- Reporting is the only module allowed to read domain tables, through read-only `rpt_*`
  views. It is planned, not implemented.
- Money is `long` minor units plus an ISO 4217 currency. Financial paths do not use
  `float` or `double`.

The documented order is `shared`, `platform`, `partners`, `iam`, `tariff`, `ingestion`,
`ledger`, `rating`, `billing`, `dispute`, `reconciliation`, `settlement`, `audit`,
`reporting`. `rating` has a spec but no source package yet; it must be added before Phase 3.

## Data and API

- Flyway is forward-only. V001 is the only applied migration; V002-V017 are planned in
  [`docs/04-data-model.md`](docs/04-data-model.md) and
  [`docs/14-roadmap.md`](docs/14-roadmap.md).
- Hibernate schema generation is disabled for the schema; `ddl-auto` is `validate`.
- The OpenAPI file is not created yet. Its planned location is
  `backend/voltreckon-app/src/main/resources/openapi/openapi.yaml`.
- The only implemented HTTP endpoint is `/actuator/health`. API standards are in
  [`docs/08-api-standards.md`](docs/08-api-standards.md).
- Actuator currently exposes `health,info`; ADR-0011 requires exposure to be reduced to
  `health` before deployment.

## Testing

The executable tests today are `ArchitectureTests` and `WalkingSkeletonIT`. The remaining
test classes in `backend/voltreckon-app/src/test` are placeholders. OCPI model and simulator
tests are also placeholders.

Integration tests use real PostgreSQL 18 through Testcontainers; H2 is forbidden. The planned
test levels, named financial tests, and quality gates are in
[`docs/10-testing-strategy.md`](docs/10-testing-strategy.md).

## Documentation

Start at [`docs/README.md`](docs/README.md). Read in this order:

| File | Answers |
|---|---|
| [`01-product-scope.md`](docs/01-product-scope.md) | Users, tiers, success measures, T2 triggers |
| [`02-glossary.md`](docs/02-glossary.md) | CDR, CPO, eMSP, tariff version, netting, IRN, SAC |
| [`03-architecture.md`](docs/03-architecture.md) | Module graph, layers, transactions, events |
| [`04-data-model.md`](docs/04-data-model.md) | Table ownership, columns, constraints, migration order |
| [`05-financial-model.md`](docs/05-financial-model.md) | Accounts, postings, rounding, period close, proofs |
| [`06-ocpi-integration.md`](docs/06-ocpi-integration.md) | OCPI fields, Credit CDRs, validation catalogue |
| [`07-gst-and-compliance.md`](docs/07-gst-and-compliance.md) | GST, SAC, place of supply, IRN, DPDP |
| [`08-api-standards.md`](docs/08-api-standards.md) | Paths, errors, idempotency, pagination, authz |
| [`09-security.md`](docs/09-security.md) | Roles, partner isolation, maker-checker, ASVS |
| [`10-testing-strategy.md`](docs/10-testing-strategy.md) | Test pyramid, fixtures, invariant tests, gates |
| [`11-simulator-and-data.md`](docs/11-simulator-and-data.md) | Scenarios, seeds, faults, dataset rules |
| [`12-engineering-standards.md`](docs/12-engineering-standards.md) | Java/Spring conventions, forbidden list, DoD |
| [`13-build-and-operations.md`](docs/13-build-and-operations.md) | Versions, commands, profiles, migrations, runbook |
| [`14-roadmap.md`](docs/14-roadmap.md) | Phase goals, migrations, endpoints, events, exits |
| [`15-agent-workflow.md`](docs/15-agent-workflow.md) | Work loop, stop conditions, commit and handoff rules |
| [`references.md`](docs/references.md) | External sources and the claims they support |
| [`modules/`](docs/modules/) | One spec per module, each with the same fifteen headings |
| [`adr/`](docs/adr/) | Accepted decisions that may not be reopened silently |

Use the bold `PREFIX-NNN` rules as the checklist. Narrative text explains them.

## Roadmap

Phase 0 is complete. Phases 1-9 are the T1 core. Phase 10 covers OCPI 2.3.0 invoice
reconciliation and hardening.

| Phase | Outcome |
|---|---|
| 0 | Walking skeleton: one deployable, PostgreSQL, Flyway V001, health, architecture test |
| 1 | Partner identity and OCPI CDR ingestion: validation, dedupe, quarantine |
| 2 | Partners, IAM, agreements, GST profiles, tariff versions, CSV import |
| 3 | Rating: deterministic, immutable pricing with tariff pinning and variance |
| 4 | Ledger: balanced, append-only double-entry book, periods, reversals, trial balance |
| 5 | Billing and GST: invoices, credit notes, numbering, atomic journal posting |
| 6 | Reconciliation: partner statements, matching, exception lifecycle |
| 7 | Disputes: case state machine, evidence metadata, settlement hold |
| 8 | Settlement: netting, maker-checker, statements, no cash movement |
| 9 | Audit and reporting: append-only audit chain, read-only reports |
| 10 | OCPI 2.3.0 invoice reconciliation, end-to-end flow, hardening |

Phase gates and required tests are in [`docs/14-roadmap.md`](docs/14-roadmap.md). Do not start
Phase 1 implementation until the Phase 0 contract and current build are understood.

## Known limitations

- The repository is a Phase 0 skeleton, not a working settlement product. Most domain classes
  are empty scaffolds.
- There is no OpenAPI file and no financial HTTP endpoint yet; only health is implemented.
- The `rating` package is not created yet.
- The `quality` profile fails on the Checkstyle configuration path.
- CI is inconsistent: `backend-ci.yml` uses Java 21 while `ci.yml` and `codeql.yml` use Java
  25; the docs job still names removed paths and the old OpenAPI location.
- The frontend is a shell, is not connected to a working API, and has no committed lockfile.
- GST, e-invoice, IRN/QR, and DPDP details contain documented assumptions and need tax or
  primary-source review before production reliance.
- The `LICENSE` copyright line is pending maintainer confirmation.
- No production deployment, backup/restore proof, disaster-recovery runbook, Kafka, Redis,
  Spring Batch, or AI in the financial path exists.

## Contributing and security

Read [`CONTRIBUTING.md`](CONTRIBUTING.md) before changing code. Keep changes to one vertical
slice, add or update tests for financial behaviour, and add an ADR before changing an accepted
decision. Do not commit secrets or production credentials.

Report security issues through the process in [`SECURITY.md`](SECURITY.md), not a public issue.

## License

MIT License. See [`LICENSE`](LICENSE). Confirm the copyright line with the maintainer before
release.

# CLAUDE.md

VoltReckon — settlement and reconciliation engine for EV-charging roaming.
Modular monolith: OCPI CDR ingestion, rating, double-entry ledger, GST invoicing, disputes,
reconciliation, netting, audit, and reporting. `docs/` is the build contract; code implements
it, not the reverse.

## 1. Read this first

- Start with [docs/README.md](docs/README.md) and the owning module spec.
- Precedence: human prompt > accepted ADR > module spec > other docs > this file.
- On a conflict, stop and report both rules. Money, tax, security, and module-boundary
  conflicts always stop.
- Do not reopen an accepted ADR silently. Add a new ADR if the decision must change.
- This file is a session log and operational snapshot, never a decision source.

## 2. Stack and versions

- Java 21 source/bytecode (`--release 21`); newer local JDKs are allowed. Do not use Java 22+
  language features in main code.
- Spring Boot 4.1.2 (parent BOM), Spring Modulith 2.1.0, PostgreSQL 18, Maven 3.9+.
- Boot 4 names: `spring-boot-starter-webmvc`, `spring-boot-starter-flyway`.
- Testcontainers 2.x: `testcontainers-postgresql`, `testcontainers-junit-jupiter`;
  class `org.testcontainers.postgresql.PostgreSQLContainer`.
- Modules: `voltreckon-ocpi-model`, `voltreckon-app`, `voltreckon-simulator`.
- Versions are verified in [docs/13-build-and-operations.md](docs/13-build-and-operations.md)
  and [docs/references.md](docs/references.md). Do not guess a version.

## 3. Non-negotiable rules

- One deployable, one PostgreSQL database, one schema `voltreckon`.
- Public API in `com.voltreckon.<module>`; implementation in `...<module>.internal`.
  Never import another module's `internal` package.
- `ledger` is a leaf and depends only on `shared`. `audit` and `reporting` are sinks.
- Domain code has no Spring, JPA, Jackson, or Servlet. Constructor injection, records, no
  Lombok.
- Money is `long` minor units plus ISO 4217 currency. No `float`/`double` in money paths.
- Issued financial rows are append-only; corrections are new rows, reversals, or credit
  notes. Never update an issued invoice, journal, posting, rating result, or statement.
- Financial document plus journal must be atomic. Post through a synchronous public command,
  not an asynchronous event.
- Events use the transactional outbox and at-least-once delivery; consumers are idempotent.
- Flyway is forward-only. No Hibernate auto-DDL. One migration = one module = one phase.
- No Kafka, Redis, Spring Batch, jqwik, microservices, or AI in the T1 financial path.
- Do not add a runtime dependency without an ADR.

## 4. Architecture

The dependency graph and layer rules are in [docs/03-architecture.md](docs/03-architecture.md),
[ADR-0007](docs/adr/0007-module-set-and-dependencies.md), and
[ADR-0013](docs/adr/0013-iam-partner-and-billing-tariff-dependencies.md). Summary:

```text
shared <- platform
platform <- partners, tariff, ingestion, rating, billing, dispute,
            reconciliation, settlement
partners <- iam, tariff, ingestion, rating, billing, dispute,
            reconciliation, settlement
tariff <- rating, billing
ingestion <- rating, dispute, reconciliation
rating <- billing, dispute, reconciliation
billing <- dispute, reconciliation, settlement
ledger <- shared only
audit, reporting <- sinks
```

The legal order is `shared`, `platform`, `partners`, `iam`, `tariff`, `ingestion`, `ledger`,
`rating`, `billing`, `dispute`, `reconciliation`, `settlement`, `audit`, `reporting`.

- Cross-module synchronous work: public command, caller's transaction.
- Cross-module asynchronous work: public event, outbox, `processed_event`.
- Reporting is the only module allowed to read domain tables, through read-only `rpt_*`
  views. All other cross-module reads use public query APIs.
- Every table has one owning module. The module spec and migration header name it.

## 5. Money, tax, and time invariants

- Round per line with HALF_UP, then sum. Use `BigDecimal` only for intermediate tax math
  with an explicit scale; persist minor units.
- GST rates and effective dates are configuration, never hard-coded. EV charging is treated
  as SAC 998714 at 18% for the cited AAR; this is not legal advice.
- Instants are UTC (`timestamptz`); business dates are Asia/Kolkata. Inject `Clock`; never
  call `Instant.now`, `LocalDate.now`, or `System.currentTimeMillis` outside `platform`.
- Entity IDs are UUIDv4. `bigserial` is for internal append-only ordering only.
- Every state-changing request uses an idempotency key; a replay returns the original result.
- Errors are RFC 9457 `application/problem+json` with a stable `code`.

## 6. Commands

```bash
mvn -B -f backend/pom.xml validate
mvn -B -f backend/pom.xml verify          # needs Docker
mvn -B -f backend/pom.xml verify -Pquality
docker compose up -d postgres
SPRING_PROFILES_ACTIVE=local mvn -f backend/voltreckon-app spring-boot:run
curl http://localhost:8080/actuator/health   # {"status":"UP"}
```

- Unit tests: `*Test`/`*Tests` (Surefire). Integration: `*IT` (Failsafe + Testcontainers).
- Integration tests use real PostgreSQL, never H2.
- `ArchitectureTests` and `ApplicationModules.verify()` must stay green.
- After any build, run `mvn clean` before trusting `target/`; never infer source state from
  generated output.

## 7. Repository map

| Path | Purpose |
|---|---|
| `docs/` | Contract: scope, architecture, data, money, OCPI, GST, API, security, testing, modules, ADRs. |
| `docs/modules/` | One spec per module with the fixed fifteen headings. |
| `docs/adr/` | Accepted decisions; do not edit an accepted ADR in place. |
| `backend/voltreckon-app/` | Boot app, Flyway migrations, OpenAPI file, integration tests. |
| `backend/voltreckon-ocpi-model/` | Pure OCPI model; no Spring. |
| `backend/voltreckon-simulator/` | Synthetic partner and fault generator. |
| `compose.yaml` | PostgreSQL 18; volume is `/var/lib/postgresql` (PG18 layout). |
| `README.md` | Human entry point; reconciled only in the final docs commit. |

## 8. Current state, open items, and code follow-ups

**Phase 0:** complete and pushed to `origin/main` at `5153cc2`. Build green; health 200;
Flyway V001 applied; architecture and Testcontainers tests pass.

**Docs:** Batch 1 committed at `644014e` (README, scope, glossary, architecture, ADRs
0000–0012, references). Batch 2 committed at `c089207` (data model, financial model, OCPI,
GST, API, security). Batch 3 authored (thirteen module specs plus ADR-0013) and committed in
the Batch 3 commit. Batch 4 still pending; links to later files are expected to resolve only
after Batch 4.

**Open decisions:**

- The ₹5 crore e-invoice AATO threshold is pinned to Notification 10/2023-Central Tax
  (`ref-17`). Exact B2C place-of-supply treatment, IRN/QR schema rules, and DPDP
  commencement dates still need primary-source or tax-review confirmation before Phase 5.
  Do not invent them.
- CI uses Java 21 in `backend-ci.yml` but Java 25 in `ci.yml`/`codeql.yml`. Align to 21 in a
  separate change; do not edit workflows in the docs task.
- `LICENSE` says MIT © 2026 Kartik Sharma. The user identifies as Akshit Sharma. Report,
  do not edit.
- `README.md` is stale (Java 25, “no code”, old links). Reconcile in the final separate
  docs commit.

**Code follow-ups after docs:**

- Add the `rating` package/module before Phase 3.
- Add public `AuditApi`, `ReconciliationApi`, and `ReportingApi` in their phases.
- Add `backend/voltreckon-app/src/main/resources/openapi/openapi.yaml` before the first
  endpoint.
- Change Actuator exposure from `health,info` to `health` only.
- Extend `ArchitectureTests` with the full dependency graph and sink rules.
- Add V002–V017 in roadmap order; never edit an applied migration.

## 9. Daily log

### 2026-11-13 — Phase 0 (backfilled)

- Implemented real Boot entry point, child dependencies, env-driven local config, V001
  baseline, architecture tests, and Testcontainers walking skeleton.
- Fixed PostgreSQL 18 Compose volume from `/var/lib/postgresql/data` to
  `/var/lib/postgresql`; verified healthy container and health 200.
- `mvn -B -f backend/pom.xml verify` green; 7 commits pushed to `origin/main`.

### 2026-11-13 — Docs Batch 1

- Audited old docs against the brief; recorded conflicts: stale README, Java 21 vs 25 CI,
  LICENSE holder, old module names, old ADRs/jqwik, missing `rating`.
- Verified OCPI editions: 2.2.1 (2021-10-06), 2.3.0 (2025-02-21), 2.3.0-ed2 (2026-06-18,
  adds Invoice Reconciliation). CDR credit fields already exist in 2.2.1.
- Authored `docs/README.md`, `01-product-scope.md`, `02-glossary.md`,
  `03-architecture.md`, `references.md`, and ADRs `0000`–`0012`.
- Next: Batch 2 — data model, financial model, OCPI, GST, API standards, security.

### 2026-11-13 — Docs Batch 2

- Authored `04-data-model.md`, `05-financial-model.md`, `06-ocpi-integration.md`,
  `07-gst-and-compliance.md`, `08-api-standards.md`, `09-security.md`.
- Corrected `PROD-001` to allow an audited platform-admin action naming its target partner,
  and `PROD-010` to select the tariff version effective at session start. Updated the
  `cdr.ingested.v1` payload wording to an external tariff reference.
- Data model: `ledger`, `audit`, and `platform` have no domain foreign keys;
  `agreement_tariff_link` is owned by `tariff`; disputes use a generic subject and do not
  reference reconciliation; `event_publication` is Modulith-managed in V002.
- Financial model: settlement records obligations but no cash movement in T1; netting is
  signed from the CPO perspective; rating tax is provisional and billing is authoritative.
- Pinned GST sources `ref-5`–`ref-8`, `ref-15`–`ref-17`, plus ASVS, OpenAPI, PostgreSQL,
  Testcontainers, and Flyway references. B2C place of supply, IRN schema, and DPDP
  commencement remain `[ASSUMPTION]`.
- Next: Batch 4 — testing, simulator, engineering, operations, roadmap, and agent workflow.

### 2026-11-13 — Docs Batch 3

- Authored the thirteen module specs, each with the same fifteen headings and its own rule
  prefix: `shared-platform` (`SHARED`, `PLAT`), `iam`, `partners`, `tariff`, `ingestion`,
  `rating`, `ledger`, `billing`, `dispute`, `reconciliation`, `settlement`, `audit`, and
  `reporting`.
- Resolved the Batch 2 boundary conflict with ADR-0013: `iam -> partners` for tenant
  validation and suspension, `billing -> tariff` for effective-dated tax rates. Updated the
  03 graph and legal order and the 04 FK matrix; ADR-0007 remains accepted for the module
  set, ledger leaf, and sink rules.
- Data-model follow-through: billing owns the invoice-level settlement hold that dispute sets
  through a public command; reconciliation and settlement dispute subjects are opaque UUIDs
  with no cross-module read.
- Checked all 13 files for the fifteen headings, unique rule IDs (405 definitions), no
  non-Markdown files under `docs/`, no SQL DDL, and resolving local links. Only the expected
  Batch 4 links are unresolved.
- Next: Batch 4 — `10-testing-strategy.md`, `11-simulator-and-data.md`,
  `12-engineering-standards.md`, `13-build-and-operations.md`, `14-roadmap.md`, and
  `15-agent-workflow.md`.

## NEXT SCOPE prompt

```text
Continue the VoltReckon docs-only task. Read docs/README.md, docs/01-product-scope.md,
docs/02-glossary.md, docs/03-architecture.md, docs/04-data-model.md,
docs/05-financial-model.md, docs/06-ocpi-integration.md, docs/07-gst-and-compliance.md,
docs/08-api-standards.md, docs/09-security.md, the thirteen docs/modules specs, the ADRs,
references.md, and this file first. Then complete Batch 4 exactly:
- docs/10-testing-strategy.md
- docs/11-simulator-and-data.md
- docs/12-engineering-standards.md
- docs/13-build-and-operations.md
- docs/14-roadmap.md
- docs/15-agent-workflow.md
Use the rule prefixes in docs/README.md (TEST, SIM, ENG, OPS, AGENT). Do not edit backend/,
frontend/, compose.yaml, LICENSE, workflows, or README.md. Do not write SQL DDL in docs. Use
Mermaid only, [ASSUMPTION] for unverified facts, and Given/When/Then acceptance scenarios.
Grow references.md only when a new external claim needs a source. Update the daily log,
commit Batch 4 with a conventional message, and do not push. Stop before the separate final
README reconciliation commit.
```

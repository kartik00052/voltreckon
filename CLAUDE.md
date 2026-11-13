# CLAUDE.md

VoltReckon — settlement and reconciliation engine for EV-charging roaming.
Modular monolith: OCPI CDR ingestion, double-entry ledger, GST invoicing, disputes, netting.
`docs/` is the source of truth (ADRs 0001–0008, architecture, schema.sql, roadmap, testing).

## Stack (verified against Maven Central, 2026-11)
- Java 21 (parent compiles with `--release 21`; newer JDKs work locally).
- Spring Boot 4.1.2 (parent BOM), Spring Modulith 2.1.0, PostgreSQL 18.
- Maven 3.9+, modules: `voltreckon-ocpi-model`, `voltreckon-app`, `voltreckon-simulator`.
- Boot 4 names: `spring-boot-starter-webmvc` (not `-web`), `spring-boot-starter-flyway`.
- Testcontainers 2.x names: `testcontainers-postgresql`, `testcontainers-junit-jupiter`;
  class `org.testcontainers.postgresql.PostgreSQLContainer`.

## Module rules
- Public API lives in `com.voltreckon.<module>`; everything else under `...<module>.internal`.
- Never import another module's `internal` packages. Cross-module calls use the public API.
- `ledger` is a leaf and depends on no domain module.
- Domain code has no Spring/JPA/Jackson. Constructor injection; Java records; no Lombok.
- No `float`/`double` for money: minor units + currency (ADR-0003). No Kafka/Redis/Spring Batch.
- Flyway is forward-only; no Hibernate auto-DDL.

## Tests
- Unit tests: `*Test` / `*Tests` (Surefire). Integration: `*IT` (Failsafe + Testcontainers).
- Architecture rules live in `ArchitectureTests`; keep `ApplicationModules.verify()` green.
- Integration tests must use real PostgreSQL (Testcontainers), never H2.

## Build
```bash
mvn -B -f backend/pom.xml validate
mvn -B -f backend/pom.xml verify          # needs Docker
mvn -B -f backend/pom.xml verify -Pquality
docker compose up -d postgres
SPRING_PROFILES_ACTIVE=local mvn -f backend/voltreckon-app spring-boot:run
curl http://localhost:8080/actuator/health   # {"status":"UP"}
```

## Working agreements
- Read the relevant ADR/architecture doc before changing behaviour.
- Smallest change; no speculative abstractions or new runtime dependencies without an ADR.
- Do not edit `docs/`, `LICENSE`, or `.github/workflows` without being asked.

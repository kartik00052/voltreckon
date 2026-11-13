# ADR-0002 — Java and runtime versions

- **Status:** Accepted
- **Date:** 2026-11-13
- **Deciders:** VoltReckon maintainer
- **Applies to phases:** 0–10

## Context

The build must be reproducible on a machine whose installed JDK is newer than the target.
Spring Boot 4.1.x requires Java 21 or newer. A split toolchain invites “works on my machine”
failures and makes CI disagree with local builds. The project also needs a BOM that aligns
Spring Framework, Spring Data, and Spring Modulith.

## Decision

- Source and bytecode target **Java 21**. The parent compiles with `--release 21`; a newer
  local JDK is allowed but MUST NOT change language level or bytecode.
- **Spring Boot 4.1.x** is the only runtime version, currently 4.1.2, through the parent BOM
  [ref-18]. No module overrides Boot-managed versions without an ADR.
- **Spring Modulith 2.1.0** is managed by the same build [ref-19].
- **PostgreSQL 18** is the only supported database.
- Boot 4 artifact names are used: `spring-boot-starter-webmvc`, `spring-boot-starter-flyway`;
  Testcontainers 2.x names are `testcontainers-postgresql` and
  `testcontainers-junit-jupiter`.
- CI alignment to Java 21 in every workflow is a required follow-up. This ADR does not edit
  workflows.

## Alternatives considered

| Alternative | Why rejected | Revisit trigger |
|---|---|---|
| Java 25 bytecode | No feature is needed; it narrows the supported CI and partner build environments and contradicts the existing backend CI. | The maintainer upgrades every workflow and the runtime baseline together. |
| Spring Boot 3.5 | Older baseline; the project already builds on 4.1.2 and uses Boot 4 artifact names. | A blocking incompatibility is proven and a migration ADR is accepted. |
| Mixed Boot versions per module | BOM drift and test/runtime skew. | Never; one parent BOM owns versions. |
| Gradle | The repository and Phase 0 build are Maven; migrating adds no product value. | A measured build or plugin limitation blocks delivery. |

## Consequences

- Positive: one toolchain, one BOM, reproducible CI and local builds.
- Positive: newer JDKs can run the build without changing produced bytecode.
- Negative: developers cannot use Java 25 language features in main code.
- Follow-up: align `.github/workflows/ci.yml` and `codeql.yml` from Java 25 to 21; report
  the conflict rather than editing workflows in a docs-only change.
- Follow-up: pin the exact Testcontainers, Flyway, and PostgreSQL driver versions in
  [13-build-and-operations.md](../13-build-and-operations.md).

## References

- [ref-18], [ref-19]
- [13-build-and-operations.md](../13-build-and-operations.md)
- [CLAUDE.md](../../CLAUDE.md)

## Review trigger

A required library drops Java 21, a security fix requires a newer bytecode target, or the
maintainer deliberately adopts a new LTS with a full CI and runtime migration.

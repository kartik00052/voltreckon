# ADR-0012 — Architecture tests

- **Status:** Accepted
- **Date:** 2026-11-13
- **Deciders:** VoltReckon maintainer
- **Applies to phases:** 0–10

## Context

Module rules that are only prose are broken by the first convenient import. Spring Modulith
verifies the module graph, but it does not cover every package rule, framework-free domain,
or forbidden annotations. The Phase 0 build already has `ArchitectureTests`; the first
custom rule checks internal-package isolation.

## Decision

- Use ArchUnit in JUnit tests plus `ApplicationModules.verify()` for the Modulith graph
  [ref-30].
- The first custom rule is: no module may import another module's `internal` package.
- Additional rules:
  - dependencies follow the graph in [03-architecture.md](../03-architecture.md);
  - `ledger` depends only on `shared`;
  - `audit` and `reporting` are sinks;
  - domain packages do not import Spring, JPA, Jackson, or Servlet;
  - public API records do not carry JPA/Jackson annotations;
  - money types do not use `float` or `double`;
  - no `Instant.now`, `LocalDate.now`, or `System.currentTimeMillis` outside `platform`.
- A rule failure is a build failure, not a warning.
- Rules are added with the module or phase that needs them; they are not a speculative
  framework.

## Alternatives considered

| Alternative | Why rejected | Revisit trigger |
|---|---|---|
| No architecture tests | Prose boundaries decay; review cannot catch every import. | Never. |
| Spring Modulith only | Does not cover framework-free domain, annotations, or money fields. | Never; ArchUnit complements it. |
| Custom Maven enforcer rules | Weaker for package-level rules and harder to express. | A build-level constraint cannot be expressed in ArchUnit. |
| Warnings only | Ignored under delivery pressure. | Never; fail the build. |

## Consequences

- Positive: boundary violations fail fast in the developer loop.
- Positive: the dependency graph is executable.
- Negative: tests need maintenance when a module is legitimately added.
- Negative: ArchUnit cannot inspect SQL table access; review and migrations still matter.
- Follow-up: extend `ArchitectureTests` with the graph rules before Phase 2.

## References

- [03-architecture.md](../03-architecture.md)
- [10-testing-strategy.md](../10-testing-strategy.md)
- [ref-30]

## Review trigger

A new module, dependency, or package convention is introduced, or an ArchUnit limitation
blocks a necessary rule.

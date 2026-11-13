# ADR-0009 — Testing strategy and property tests

- **Status:** Accepted
- **Date:** 2026-11-13
- **Deciders:** VoltReckon maintainer
- **Applies to phases:** 0–10

## Context

Financial rules fail at boundaries: rounding, currency, duplicate CDRs, period locks, and
netting order. H2 does not reproduce PostgreSQL semantics, especially `timestamptz`,
constraints, and locking. Property-based testing can find edge cases, but a second test
framework and generator ecosystem add maintenance cost before the invariants are stable.

## Decision

- Unit tests use JUnit 5 and cover pure domain rules. Integration tests use real PostgreSQL
  through Testcontainers; H2 is forbidden.
- Integration tests are named `*IT` and run under Failsafe; unit tests are `*Test`/`*Tests`
  under Surefire.
- Architecture rules run as tests (`ArchitectureTests`) and are not a separate manual step.
- No jqwik by default. Use seeded randomized JUnit loops for property-style checks where a
  generator is small and explicit. A property test must print its seed and be reproducible.
- Required invariants:
  - money arithmetic never uses floating point and preserves currency;
  - a journal balances and the trial balance sums to zero;
  - a duplicate idempotency key returns the original result;
  - a credit CDR cannot be applied twice;
  - an issued invoice is immutable;
  - a closed period rejects postings;
  - a settlement run is reproducible and pair-period unique.
- Every rule ID in a module spec names at least one test or a review check.
- The `-Pquality` profile is allowed to add static analysis and coverage. Mutation testing is
  a T2 decision, not a T1 gate.

## Alternatives considered

| Alternative | Why rejected | Revisit trigger |
|---|---|---|
| jqwik for all property tests | Extra framework and generator learning cost before invariants are stable. | A measured bug class that seeded loops cannot cover, or a maintainer decision. |
| H2 for fast integration tests | Different SQL, timestamp, and locking behaviour; false confidence. | Never for financial tests. |
| Mock every repository | Hides transaction, constraint, and SQL failures. | Unit tests may mock ports; integration tests use PostgreSQL. |
| Testcontainers for unit tests | Slow and unnecessary for pure domain rules. | A domain rule needs a database; then it is an integration test. |

## Consequences

- Positive: tests exercise the same database and constraints as production.
- Positive: seeded loops are simple and debuggable by one maintainer.
- Negative: integration tests need Docker and are slower.
- Negative: without jqwik, some generated edge cases need hand-written generators.
- Follow-up: add a coverage and static-analysis report in `13-build-and-operations.md`.

## References

- [10-testing-strategy.md](../10-testing-strategy.md)
- [ADR-0012](0012-archunit.md)

## Review trigger

A property bug escapes seeded tests, a second test runtime is introduced, or mutation
testing becomes affordable for the maintainer.

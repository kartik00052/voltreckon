# Testing strategy

**Goal:** prove the financial invariants, not chase a coverage number. A test suite that reports 90% coverage but cannot detect an unbalanced journal is worthless here.

**Status:** planned. No test code exists yet.

---

## 1. Test pyramid

```
        ┌──────────────────────────┐
        │  End-to-end (few)        │  REST Assured, full workflow
        ├──────────────────────────┤
        │  Integration (moderate)  │  Testcontainers, DB constraints
        ├──────────────────────────┤
        │  Contract (moderate)     │  OpenAPI, WireMock adapters
        ├──────────────────────────┤
        │  Unit + property (many)  │  JUnit 5, AssertJ, jqwik
        └──────────────────────────┘
```

| Layer | Scope | Speed | Tools |
|---|---|---|---|
| Unit | Pure domain functions, money, rating, tax, state machines | ms | JUnit 5, AssertJ, jqwik |
| Integration | Services + real PostgreSQL + Flyway | seconds | Testcontainers, Spring Boot Test |
| Contract | API schema and external adapters | seconds | OpenAPI validator, WireMock |
| Architecture | Module boundaries, forbidden types | seconds | ArchUnit |
| End-to-end | CDR → invoice → ledger → settlement | tens of seconds | REST Assured, Testcontainers |
| Performance | Ingestion and rating throughput | minutes | Gatling or k6 (Phase 2) |
| Security | Tenant isolation, auth, injection | seconds | Spring Security Test, parameterised tests |

---

## 2. What must be tested (non-negotiable)

1. **Money arithmetic:** addition across currencies fails; overflow throws; conversion uses the correct exponent; rounding is half-up per line.
2. **Rating determinism:** same inputs → same output; tariff version pinned; credit CDRs net correctly.
3. **Journal balancing:** no sequence of operations can commit an unbalanced entry.
4. **Idempotency:** duplicate CDR/invoice/settlement requests do not duplicate effects.
5. **Tenant isolation:** every partner-scoped endpoint rejects cross-partner access.
6. **Immutability:** issued invoices, CDRs, journals cannot be mutated.
7. **Tax effective dating:** an invoice uses the rule effective in its period; past invoices unchanged after a rate change.
8. **Period close:** postings to closed periods fail.
9. **Settlement netting:** net equals the sum of included items; an item settles once.
10. **Outbox:** state and event commit atomically; a crash between commit and delivery does not lose the event; consumers are idempotent.

---

## 3. Test design per module

### 3.1 `platform.money`

- Exponents for INR/USD/JPY/KWD.
- `movePointRight` conversions, negative amounts (credits).
- Overflow at `Long.MAX_VALUE`.
- Mixed-currency operations.
- Rounding: `0.005` → `0.01`, `-0.005` → `-0.01` (half-up away from zero) — define and test the sign policy.

### 3.2 `tariff`

- Restriction truth table: time window, day of week, duration, energy, power, current.
- Boundary inclusivity (documented; test both sides).
- Overlapping elements and deterministic tie-break.
- No matching element → typed failure.
- Effective-range selection around boundaries.
- Published versions cannot overlap (integration test with the exclusion constraint).

### 3.3 `cdr`

- Duplicate replay (same key).
- Duplicate via different JSON key order but same business key.
- Credit without original → quarantine.
- Credit of credit → rejected.
- Double credit → rejected.
- Currency mismatch between credit and original.
- Timestamp without offset in CSV → quarantine.
- Negative energy → rejected.
- Immutability trigger.
- Large batch chunking.

### 3.4 `rating`

- Golden cases per component type.
- Step-size cases, including the proration/started-step ambiguity.
- Tax per line and sum.
- Variance types and tolerance boundaries.
- Credit netting.
- Restart after simulated crash.
- Property tests:
  - `sum(lines) = subtotal`.
  - `subtotal + tax = total`.
  - Cost non-decreasing in energy at fixed tariff.
  - Rating is idempotent for identical inputs.

### 3.5 `invoicing`

- Draft → issue → immutable.
- Number allocation under concurrency (parallel issues produce unique sequential numbers).
- Duplicate issue request returns the same invoice.
- Line totals equal header.
- Tax split by place of supply.
- Credit note cannot exceed the original.
- Credit note uses the original tax rate.
- Issued invoice cannot be edited; credit note is a new record.

### 3.6 `reconciliation`

- Exact match.
- Amount mismatch within/outside tolerance.
- Missing CDR, missing invoice line.
- Duplicate invoice line.
- Credit mismatch.
- Exception resolution requires code/actor.
- `matched + exceptions = total`.
- Re-run creates a new immutable run.

### 3.7 `ledger`

- Balanced entry accepted; unbalanced rejected at commit.
- Single-line entry rejected.
- Zero-value entry rejected.
- Duplicate source posting rejected.
- Reversal nets to zero.
- Closed period rejects postings.
- Property test: random valid postings keep the trial balance at zero.

### 3.8 `settlement`

- Netting arithmetic with mixed signs.
- Double settlement rejected.
- Concurrent runs: one wins, one gets `409`.
- Closed period rejected.
- Statement hash stable for the same content.
- Journal balances.

### 3.9 `dispute`

- Full state-machine coverage; every illegal transition rejected.
- Evidence after close rejected.
- Timeline ordering and actor recorded.
- Resolution requires a linked corrective document.

### 3.10 `partner` and security

- GSTIN checksum property test.
- JWT validation: bad signature, wrong issuer, expired, missing partner.
- Cross-partner access returns `404` on every partner-scoped route.
- Suspended partner writes rejected.

---

## 4. Property-based testing (jqwik)

Properties to encode:

```java
@Property
void invoiceTotalsAlwaysReconcile(@ForAll("lines") List<Line> lines) {
    Invoice inv = Invoice.draftFrom(lines);
    assertEquals(sumTaxable(lines), inv.subtotal());
    assertEquals(sumTax(lines), inv.tax());
    assertEquals(inv.subtotal() + inv.tax(), inv.total());
}

@Property
void journalsAlwaysBalance(@ForAll("postings") List<Posting> postings) {
    Ledger ledger = new Ledger();
    postings.forEach(ledger::post);
    assertTrue(ledger.trialBalance().isZero());
}

@Property
void ratingNeverDecreasesWithEnergy(
    @ForAll @Positive long energy1,
    @ForAll @Positive long energy2) {
    assume(energy2 > energy1);
    assertTrue(rate(energy2).total() >= rate(energy1).total());
}
```

Generators must produce realistic values (currencies, rates, step sizes, boundaries) and avoid trivial cases. Shrinking is used to produce minimal failing examples.

---

## 5. Integration testing with Testcontainers

- PostgreSQL 18 container, Flyway migrations applied.
- One container per test class (or a shared container with transaction rollback where possible).
- Test the **database** behaviour, not just the service: triggers, constraints, exclusion constraints, deferred checks.
- Concurrency tests use multiple threads and a `CountDownLatch`; assert one success and typed failures.
- Use `@Transactional` carefully: deferred constraints fire at commit, so tests that expect constraint failures must commit.

Example targets:

- Insert a journal entry with two lines in one transaction → commits.
- Insert one line → commit fails.
- Insert two lines with unequal amounts → commit fails.
- Two threads credit the same CDR → one succeeds.
- Two threads issue invoices → unique numbers.

---

## 6. Contract testing

- **OpenAPI:** validate requests/responses in integration tests; lint the spec in CI.
- **Adapters:** WireMock stubs for IRP/UBC in Phase 2; fixture files for OCPI/CSV mapping.
- **Partner fixtures:** anonymised real CDRs (once available) as golden files; never commit production PII.
- **Backward compatibility:** compare the current schema with the previous release; fail on breaking changes.

---

## 7. Architecture tests (ArchUnit)

Rules:

- No domain class imports web, persistence, or Jackson packages.
- No module imports another module's adapter or JPA packages.
- `ledger` does not depend on domain modules.
- No `float`/`double` fields or locals in `domain`, `money`, or rating/tax packages.
- Controllers depend only on application services and DTOs.
- `reporting` has no write dependencies.
- Classes named `*Controller` reside in `adapter.in.web`.
- Classes named `*Repository` reside in `adapter.out.jpa`.

Failures are build failures, not warnings.

---

## 8. End-to-end scenarios

1. **Happy path:** ingest CDR → rate → draft invoice → issue → trial balance includes AR/revenue/GST.
2. **Duplicate path:** ingest the same CDR twice → one record, one rating, one invoice line.
3. **Correction path:** ingest original → ingest credit → rate → invoice nets → credit note → ledger reflects the net.
4. **Dispute path:** open dispute → attach evidence → resolve → credit note → reconciliation reflects the adjustment.
5. **Settlement path:** two invoices and one credit → reconcile → settle → statement net matches ledger clearing.
6. **Rejection path:** invalid CDR → quarantine → revalidate → accept or remain quarantined.
7. **Period close:** close November → attempt a November posting → `409`/`422` with `PERIOD_CLOSED`.

Each scenario asserts both the API response and the database state (trial balance, journal count, immutability).

---

## 9. Performance and load (Phase 2)

Targets (design, not measured):

- Ingest 100k CDRs/day (~1.2/s average, burst 50/s).
- Rate 100k CDRs in a batch within an hour.
- Reconcile 10k invoice lines in under a minute.
- API p95 < 300 ms for reads, < 1 s for financial writes excluding batch jobs.

Test approach:

- Generate synthetic CDRs with realistic distributions.
- Measure ingest throughput, rating run duration, DB CPU, lock waits.
- Test outbox relay lag under load.
- Use `EXPLAIN (ANALYZE, BUFFERS)` for the top queries.

---

## 10. Security testing

- Cross-tenant access matrix: for every partner-scoped endpoint, call with partner A's token and partner B's resource; expect `404`.
- JWT tampering: modified payload, `alg: none`, wrong key, expired.
- Idempotency: same key with different body; key reuse across routes.
- Injection: malicious strings in descriptions, filenames, and CSV fields.
- Log leakage: assert PII/tokens are not present in captured logs.
- Dependency and CodeQL scans in CI.
- Optional: OWASP ZAP baseline scan once the API runs.

---

## 11. Test data

- Builders/factories for aggregates (`PartnerBuilder`, `CdrBuilder`, `TariffBuilder`).
- Deterministic `Clock` injected everywhere; no `Instant.now()` in domain code.
- Fixed UUIDs in fixtures where useful; random elsewhere.
- No production data in tests. Anonymised CDRs must have token UIDs and IDs replaced.
- Golden files for OCPI payloads and CSV imports.

---

## 12. CI pipeline

```yaml
stages:
  - build
  - unit
  - architecture
  - integration
  - contract
  - security
  - package
```

| Stage | Command (target) | Gate |
|---|---|---|
| Build | `mvn -q -DskipTests package` | Must pass |
| Unit | `mvn test` | No failures |
| Architecture | `mvn test -Dtest=ArchitectureTest` | No violations |
| Integration | `mvn verify -Pit` | No failures; Testcontainers available |
| Contract | OpenAPI lint + schema validation | Valid spec |
| Security | CodeQL, dependency review | No high/critical |
| Package | Docker build | Image builds |

Workflows are guarded with `if: hashFiles('backend/pom.xml') != ''` until the code exists.

---

## 13. Quality gates

A pull request is mergeable only if:

- All tests pass.
- New financial logic has unit + property tests.
- New endpoints have contract tests and a 4xx path.
- DB changes have migration + constraint tests.
- ArchUnit passes.
- No new `float`/`double` in domain code.
- No TODO without an issue reference.
- The OpenAPI spec is updated for API changes.

Coverage is reported but **not** used as a hard gate. Instead, the rule is: every financial invariant has at least one test that would fail if the invariant were removed.

---

## 14. Definition of done for a feature

1. Domain logic with unit tests.
2. Property tests for arithmetic/aggregation invariants.
3. Integration tests for persistence, constraints, and concurrency.
4. API contract updated and validated.
5. Audit event emitted and asserted.
6. Idempotency tested if the operation creates financial state.
7. Documentation updated (module doc, API doc, ADR if a decision changed).
8. No new runtime dependency without an ADR.

---

## 15. Anti-patterns

| Anti-pattern | Why it fails here |
|---|---|
| Testing only the service layer with a mocked repository | Misses triggers, constraints, and deferred checks that protect the books |
| Using H2 for tests | Different SQL semantics; constraints and triggers unavailable or different |
| Asserting on log strings | Brittle; assert on metrics/audit records instead |
| One giant end-to-end test | Slow and hard to diagnose; use focused integration tests |
| Chasing coverage percentage | Does not prove invariants |
| Random data without shrinking | Failures are irreproducible |
| Ignoring concurrency | Duplicate billing and double settlement are race conditions |
| `Thread.sleep` in tests | Flaky; use latches and deterministic clocks |

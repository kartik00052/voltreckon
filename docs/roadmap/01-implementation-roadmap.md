# Implementation roadmap

**Constraint:** one developer, part-time to full-time. The sequence is chosen so that every milestone leaves a demonstrable, tested vertical slice — never a half-built layer.

**Rule:** no milestone starts before the previous one's definition of done is met. Scope additions require a new milestone or an explicit trade-off written down.

---

## Milestone 0 — Blueprint (this repository)

**Outcome:** research, architecture, schema, API contract, roadmap, and a skeptical review exist and are internally consistent.

**Done when:**

- All documents in `docs/` exist and link correctly.
- `docs/database/schema.sql` parses and reflects the design.
- `docs/api/openapi.yaml` validates.
- The root README states clearly that nothing is implemented.
- The out-of-scope list is explicit.

**Status:** complete for blueprint v0.1.

---

## Milestone 1 — Walking skeleton

**Duration:** 2–3 weeks

**Outcome:** one CDR in, one rating result, one invoice draft, one balanced journal, one trial balance row — end to end, with tests.

**Scope**

- Spring Boot project, Java 25, Maven wrapper.
- Flyway baseline from `schema.sql` (split into migrations).
- `platform.money`, `platform.clock`, `platform.error`, `platform.audit` (basic).
- Minimal `partner` (one seeded partner pair) and `tariff` (one seeded tariff).
- `POST /api/v1/cdrs` (single, JSON), `POST /api/v1/rating-runs` (synchronous for one CDR), `POST /api/v1/invoices` + `/issue`, `GET /ledger/trial-balance`.
- Testcontainers integration test for the full path.
- Dockerfile and Compose app service.

**Definition of done**

- The happy path passes in CI with a real PostgreSQL container.
- The journal balances and the trial balance is queried via SQL.
- No `float`/`double` in domain code (ArchUnit rule active).
- One property test for money rounding and one for journal balance.
- The README run commands work.

**Risks:** Flyway/schema friction; JPA mapping of money; deferred constraints in tests. Keep the slice narrow; do not build the full partner module yet.

---

## Milestone 2 — Partners, agreements, tariff versions

**Duration:** 2–3 weeks

**Outcome:** a real partner pair can be onboarded and a versioned tariff published and selected by effective date.

**Scope**

- Full `partner` module: registration, users, roles, GSTINs, status.
- `agreement` module: create, activate, terminate, tariff links, overlap protection.
- `tariff` module: versions, components, restrictions, publish, effective lookup.
- Admin endpoints and partner-scoped authorization.
- Cross-tenant isolation tests for all new endpoints.

**Definition of done**

- Overlapping active agreements are rejected by the database and surfaced as `409`.
- Overlapping published tariff versions are rejected.
- Rating selects the correct version across a boundary (test with fixed clock).
- Every new repository method is partner-scoped and covered by a cross-tenant test.

**Risks:** scope creep into a full admin UI (none in MVP); tariff restriction semantics. Document tie-breaks and test them.

---

## Milestone 3 — Robust CDR ingestion

**Duration:** 2–3 weeks

**Outcome:** duplicate-safe, quarantine-aware ingestion from JSON and CSV, including credit CDRs.

**Scope**

- CSV importer with streaming, chunking, and a job record.
- Idempotency key table and middleware for `POST /cdrs`.
- Duplicate detection and `duplicateOf` response.
- Credit CDR validation and single-credit enforcement.
- Quarantine with typed issues and a revalidate endpoint.
- Ingestion metrics (Micrometer).

**Definition of done**

- Replaying the same request 10 times creates one CDR.
- A credit before the original is quarantined; after the original arrives, revalidation succeeds.
- Double credit is rejected.
- A 100k-row CSV imports without loading the whole file into memory (streaming test or bounded memory check).
- Metrics expose accepted, duplicate, quarantined counts.

**Risks:** CSV formats vary widely; keep the parser strict and configurable per partner later. Do not silently coerce bad data.

---

## Milestone 4 — Rating engine and variance

**Duration:** 3 weeks

**Outcome:** deterministic rating for all component types with variance reporting, including credits.

**Scope**

- Restriction evaluation and element selection.
- Component math: energy, time, parking, flat; step sizes.
- Per-line tax with effective tax rules.
- Rating runs with checkpoints and restart.
- Variance calculation and types.
- Credit netting against originals.
- `GET /rating-results/{id}`.

**Definition of done**

- Golden tests for every component type and boundary.
- Property tests for sums, determinism, and monotonicity.
- A run interrupted mid-way resumes without duplicates.
- Credit CDR rating nets to the expected amount.
- A changed tariff never affects a historical rating result.

**Risks:** step-size semantics differ by partner. Implement one documented default and a per-component `pricing_mode` extension point if needed.

---

## Milestone 5 — Invoices, tax, credit notes

**Duration:** 3 weeks

**Outcome:** legally shaped invoice data with GST split, immutable issue, and credit notes.

**Scope**

- Draft from rating results; line and tax computation.
- Invoice numbering with a locked sequence per entity/financial year.
- Issue transaction: mark issued, assign number, post journal.
- GST split by place of supply; CGST/SGST/IGST.
- Credit notes with tax reversal.
- IRP-ready fields (no submission).
- Invoice register report.

**Definition of done**

- Concurrent issue requests produce unique, gapless numbers.
- Issued invoices cannot be mutated (DB trigger test).
- Line sums equal header sums; tax lines sum to tax total.
- A credit note cannot exceed the original and uses the original tax rule.
- The journal for invoice and credit balances.

**Risks:** tax classification and place-of-supply rules. Keep rates configurable; do not encode legal conclusions. Get a professional review before production.

---

## Milestone 6 — Reconciliation

**Duration:** 2–3 weeks

**Outcome:** partner invoice lines matched to CDRs and rated amounts, with a usable exception queue.

**Scope**

- Import partner invoice lines (JSON/CSV).
- Matching: exact CDR key, amount tolerance, missing/duplicate.
- Exception types and resolution workflow.
- Reconciliation run with counts and immutability.
- Exception ageing report.

**Definition of done**

- `matched + exceptions = total`.
- Every exception has a type, and resolution requires code/actor/time.
- Re-running creates a new run; the old one is unchanged.
- Concurrent runs for the same partner/period are serialized.

**Risks:** matching tolerance policy and duplicate invoice lines. Make tolerance configurable per agreement and test boundaries.

---

## Milestone 7 — Ledger hardening and periods

**Duration:** 2 weeks

**Outcome:** a trustworthy ledger with period close, trial balance, and integrity checks.

**Scope**

- Full chart of accounts and posting recipes for invoice/credit/settlement.
- Deferred balance trigger and immutability triggers (already in schema; verify).
- Accounting periods, close, and rejection of postings to closed periods.
- Trial balance per entity/period.
- Reversal endpoint/service.
- Integrity check job and metrics.

**Definition of done**

- No API path can post to a closed period.
- Reversal entries net to zero and reference the original.
- Trial balance query matches expected totals in integration tests.
- Integrity checks run daily and alert on anomalies (log/metric in MVP).

**Risks:** multi-entity books and counterparty dimensions. Keep `entity_partner_id` mandatory on every entry.

---

## Milestone 8 — Settlement netting

**Duration:** 2 weeks

**Outcome:** a netting run that produces an immutable statement and balancing journals, with no money movement.

**Scope**

- Eligibility selection.
- Advisory locking per partner pair/period.
- Net calculation and settlement items.
- Statement generation with content hash.
- CSV export.
- Settlement status endpoints.

**Definition of done**

- Net equals the sum of included items with correct signs.
- An item settles once; double settlement is rejected.
- Two concurrent runs: one completes, the other gets `409`.
- The statement is immutable and reproducible from the run.
- Journals balance per entity.

**Risks:** eligibility policy ambiguity. Document it and make it explicit in the statement.

---

## Milestone 9 — Disputes and evidence

**Duration:** 2 weeks

**Outcome:** a case workflow with an append-only timeline and evidence integrity metadata.

**Scope**

- Dispute creation linked to CDR/rating/invoice/reconciliation item.
- State machine with validated transitions.
- Evidence metadata and content hash.
- Resolution linking to a credit note or adjustment.
- Case timeline endpoint.

**Definition of done**

- Every illegal transition returns `409` with a typed error.
- Evidence cannot be added after close.
- The timeline is complete and ordered.
- A resolved dispute references a corrective document.

**Risks:** scope creep into chat/email integration. Keep evidence as metadata in the MVP.

---

## Milestone 10 — OCPI 2.3.0 integration

**Duration:** 3–4 weeks

**Outcome:** an OCPI-facing adapter for CDR ingestion and invoice reconciliation, with 2.2.1 compatibility.

**Scope**

- OCPI module routing and credentials (client role first).
- CDR mapping for 2.2.1 and 2.3.0.
- Invoice Reconciliation mapping.
- Contract tests with fixtures and WireMock.
- Sandbox configuration and feature flags.
- Documentation for partners.

**Definition of done**

- Fixture CDRs from both versions map correctly.
- Version-specific fields are isolated in the adapter.
- No OCPI type leaks into the domain (ArchUnit rule).
- Integration tests cover success, duplicate, and error paths.
- A partner sandbox guide exists.

**Risks:** partner-specific quirks and credentials exchange. Do not attempt a full OCPI server before the internal workflow is stable.

---

## Milestone 11 — Production hardening and Phase 2 adapters

**Duration:** ongoing

**Outcome:** operational readiness and the first external integrations.

**Scope**

- Observability: OpenTelemetry traces, Prometheus/Grafana dashboards, alerts.
- Backup/restore drill; runbook validation.
- Security review against OWASP ASVS L2; penetration test (external).
- IRP sandbox integration (e-invoice).
- UBC/Beckn adapter, only against official material.
- Object storage for evidence with retention.
- Performance/load tests and tuning.
- Maker-checker for invoice issue and journal reversal.
- RLS as defence in depth.

**Definition of done**

- Restore drill passes within RTO.
- Alerts fire on simulated failures.
- A load test meets the documented targets.
- Security findings are triaged and fixed.
- IRP sandbox submission is idempotent and auditable.
- UBC adapter is feature-flagged and documented as experimental until certified.

---

## Sequencing rationale

```
M1 skeleton
  └─ M2 partners/tariffs
       └─ M3 ingestion
            └─ M4 rating
                 └─ M5 invoices
                      ├─ M6 reconciliation
                      ├─ M7 ledger
                      └─ M9 disputes
                           └─ M8 settlement
                                └─ M10 OCPI
                                     └─ M11 production
```

- **Money and ledger before features.** M1 and M7 establish the constraints that everything else relies on.
- **Ingestion before rating.** Real data exposes edge cases early.
- **Invoice before reconciliation.** You need an invoice to reconcile against.
- **Settlement last among core workflows.** It depends on ledger, invoices, and reconciliation.
- **OCPI after the core.** Protocol work is easier once the domain is stable.

---

## Effort summary

| Milestone | Estimate | Cumulative |
|---|---|---|
| M0 Blueprint | done | — |
| M1 Skeleton | 2–3 weeks | 3 |
| M2 Partners/tariffs | 2–3 weeks | 6 |
| M3 Ingestion | 2–3 weeks | 9 |
| M4 Rating | 3 weeks | 12 |
| M5 Invoices | 3 weeks | 15 |
| M6 Reconciliation | 2–3 weeks | 18 |
| M7 Ledger | 2 weeks | 20 |
| M8 Settlement | 2 weeks | 22 |
| M9 Disputes | 2 weeks | 24 |
| M10 OCPI | 3–4 weeks | 28 |
| M11 Production | ongoing | — |

These are planning estimates for one developer with focused time. They assume no customer-specific customisation and no UI. A UI, partner onboarding support, and enterprise requirements would multiply the effort.

---

## Explicitly deferred (and why)

| Feature | Why deferred | Trigger to revisit |
|---|---|---|
| Consumer app | UBC/CPO apps own it | Never, for this product |
| Payments/wallet | Regulated, different risk | Only with a licensed partner |
| Kafka | Outbox is sufficient | Sustained high throughput or multiple services |
| Redis | PostgreSQL suffices | Measured latency/contention |
| Kubernetes | Single container works | Multi-region or many services |
| Microservices | Local transactions are valuable | Measured scaling or team boundary |
| Event sourcing | Ledger + audit suffice | A need for full state replay |
| AI matching | No data, audit risk | Labelled data and human-review workflow |
| Full OCPI server | Adapter first | Partner demand and certification |
| IRP live | Sandbox first | GST applicability confirmed |
| UBC production | Specs immature | Official onboarding and certification |

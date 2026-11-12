# Milestone and issue breakdown

Ready-to-create GitHub issues. Each issue is scoped to a vertical slice and has explicit acceptance criteria. Create them in milestone order; do not open later-milestone issues as "help wanted" until the prerequisites are merged.

## Label taxonomy

| Prefix | Values |
|---|---|
| `type:` | `feature`, `chore`, `bug`, `test`, `docs`, `research`, `security` |
| `area:` | `platform`, `partner`, `agreement`, `tariff`, `cdr`, `rating`, `invoicing`, `reconciliation`, `ledger`, `settlement`, `dispute`, `reporting`, `integration` |
| `milestone:` | `0` … `11` |
| `priority:` | `p0` (blocking), `p1` (current milestone), `p2` (later) |
| `size:` | `s` (< 1 day), `m` (1–3 days), `l` (3–5 days) |

---

## Milestone 0 — Blueprint (closed)

- **M0-01** Verify all documentation links and commands. `type:docs area:platform milestone:0 priority:p0`
- **M0-02** Validate `schema.sql` and `openapi.yaml` in CI. `type:chore area:platform milestone:0 priority:p0`

Both are complete for blueprint v0.1.

---

## Milestone 1 — Walking skeleton

### M1-01 Bootstrap the Spring Boot application
**Labels:** `type:feature area:platform milestone:1 priority:p0 size:m`
**Depends on:** none
**Acceptance**
- Spring Boot 4.1.x, Java 25, Maven wrapper committed.
- `local` and `test` profiles.
- `/actuator/health` returns `UP`.
- `mvn verify` passes with no tests yet.

### M1-02 Flyway baseline from the design schema
**Labels:** `type:chore area:platform milestone:1 priority:p0 size:m`
**Depends on:** M1-01
**Acceptance**
- Versioned migrations create all MVP tables.
- Migration runs cleanly on a fresh PostgreSQL 18 container.
- `flyway validate` passes.
- Seed chart of accounts and invoice sequence are idempotent.

### M1-03 Implement `platform.money`
**Labels:** `type:feature area:platform milestone:1 priority:p0 size:m`
**Depends on:** M1-01
**Acceptance**
- `Money` record with minor units and ISO currency.
- Conversion from decimal and OCPI strings; overflow checks.
- Rounding policy documented and tested.
- No `float`/`double`; ArchUnit rule exists.

### M1-04 Audit log foundation
**Labels:** `type:feature area:platform milestone:1 priority:p1 size:s`
**Depends on:** M1-02
**Acceptance**
- `AuditLog` writer with actor, action, entity, correlation ID, hashes.
- JDBC/JPA write in the caller's transaction.
- Append-only DB trigger verified by a test.

### M1-05 Minimal partner context and seed
**Labels:** `type:feature area:partner milestone:1 priority:p0 size:s`
**Depends on:** M1-02
**Acceptance**
- One seed CPO and one seed eMSP for local development.
- `CurrentPartner` port resolves a partner ID from a test token.
- No endpoint accepts a partner ID from the body.

### M1-06 CDR ingestion (single JSON)
**Labels:** `type:feature area:cdr milestone:1 priority:p0 size:m`
**Depends on:** M1-02, M1-03, M1-05
**Acceptance**
- `POST /api/v1/cdrs` validates and stores an immutable CDR.
- Unique partner-scoped external ID enforced.
- Validation issues returned for bad input.
- Integration test asserts persistence and immutability.

### M1-07 Synchronous rating for one CDR
**Labels:** `type:feature area:rating milestone:1 priority:p0 size:m`
**Depends on:** M1-06
**Acceptance**
- Rates one CDR against a seeded tariff version.
- Stores rating result and lines; pins tariff version and input hash.
- Energy component only for the skeleton.
- Unit test covers a golden case.

### M1-08 Invoice draft, issue, and journal
**Labels:** `type:feature area:invoicing milestone:1 priority:p0 size:m`
**Depends on:** M1-07
**Acceptance**
- Draft from a rating result.
- Issue assigns a number and posts a balanced journal.
- Issued invoice immutable by trigger.
- Credit-note path is stubbed with a ticket, not half-implemented.

### M1-09 Trial balance endpoint
**Labels:** `type:feature area:ledger milestone:1 priority:p0 size:s`
**Depends on:** M1-08
**Acceptance**
- `GET /api/v1/ledger/trial-balance` returns per-entity account balances.
- Totals match the journal in an integration test.
- Debits equal credits across the returned set.

### M1-10 End-to-end integration test
**Labels:** `type:test area:platform milestone:1 priority:p0 size:m`
**Depends on:** M1-06 … M1-09
**Acceptance**
- Testcontainers PostgreSQL.
- CDR → rating → invoice → journal → trial balance.
- Asserts API responses and database state.
- Runs in CI.

### M1-11 Dockerfile and Compose app service
**Labels:** `type:chore area:platform milestone:1 priority:p1 size:s`
**Depends on:** M1-01
**Acceptance**
- Multi-stage Dockerfile with a non-root user.
- `docker compose up` starts app + Postgres.
- Health check passes.
- README commands updated and verified.

---

## Milestone 2 — Partners, agreements, tariffs

### M2-01 Partner registration and profile
**Labels:** `type:feature area:partner milestone:2 priority:p0 size:m`
**Acceptance**
- Create, retrieve, list, suspend/reactivate.
- Roles `CPO`/`EMSP` stored and returned.
- Optimistic locking on profile edits.

### M2-02 GSTIN management
**Labels:** `type:feature area:partner milestone:2 priority:p0 size:m`
**Acceptance**
- Add/list GSTINs with format and checksum validation.
- One primary per partner.
- Valid-from/to supported.

### M2-03 Users and roles
**Labels:** `type:feature area:partner milestone:2 priority:p1 size:m`
**Acceptance**
- Users bound to a partner and IdP subject.
- Role assignment; no password storage.
- Disabled users cannot authenticate.

### M2-04 Partner-scoped authorization
**Labels:** `type:security area:platform milestone:2 priority:p0 size:m`
**Acceptance**
- JWT validation (signature, issuer, audience, expiry).
- `partner_id` and scopes extracted from the token.
- Cross-tenant access returns `404` for every partner-scoped route.
- Parameterised isolation test exists.

### M2-05 Agreement lifecycle
**Labels:** `type:feature area:agreement milestone:2 priority:p0 size:m`
**Acceptance**
- Draft, activate, terminate.
- Directional CPO/eMSP pair.
- Database exclusion prevents overlapping active agreements.
- `409` returned with a typed error on overlap.

### M2-06 Agreement tariff links
**Labels:** `type:feature area:agreement milestone:2 priority:p1 size:s`
**Acceptance**
- Link one or more published tariff versions.
- Currency mismatch rejected.
- Links are visible on the agreement.

### M2-07 Tariff version lifecycle
**Labels:** `type:feature area:tariff milestone:2 priority:p0 size:m`
**Acceptance**
- Create draft, publish, supersede.
- Published versions immutable.
- Overlapping published ranges rejected.

### M2-08 Tariff components and restrictions API
**Labels:** `type:feature area:tariff milestone:2 priority:p0 size:m`
**Acceptance**
- Energy/time/parking/flat components with step size.
- Restriction fields accepted and persisted.
- Validation errors are field-level.

### M2-09 Effective tariff lookup
**Labels:** `type:feature area:tariff milestone:2 priority:p0 size:s`
**Acceptance**
- `GET .../versions/effective?at=` returns the correct version.
- Boundary tests at `effective_from` and `effective_to`.
- No version → `404` with a typed code.

### M2-10 Tariff restriction evaluator
**Labels:** `type:feature area:tariff milestone:2 priority:p0 size:m`
**Acceptance**
- Pure function with a truth-table test.
- Boundary inclusivity documented.
- Tie-break by specificity then `element_order`.

---

## Milestone 3 — CDR ingestion

### M3-01 Idempotency middleware
**Labels:** `type:feature area:platform milestone:3 priority:p0 size:m`
**Acceptance**
- Required header on financial POSTs.
- Key scoped to partner + route.
- Same key + body → replay; different body → `409`.
- Expiry cleanup job.

### M3-02 Duplicate detection and response
**Labels:** `type:feature area:cdr milestone:3 priority:p0 size:m`
**Acceptance**
- Business-key unique constraint.
- Duplicate returns `200` with `duplicateOf`.
- Content hash mismatch logged.
- No second rating result created.

### M3-03 Streaming CSV importer
**Labels:** `type:feature area:cdr milestone:3 priority:p0 size:l`
**Acceptance**
- Multipart upload, bounded memory.
- Per-row validation and accepted/rejected counts.
- Job status endpoint.
- 100k-row test fixture imports within a documented time.

### M3-04 Quarantine and revalidation
**Labels:** `type:feature area:cdr milestone:3 priority:p0 size:m`
**Acceptance**
- Invalid rows stored with typed issues.
- Quarantined CDRs excluded from rating.
- Revalidate endpoint promotes to accepted when fixed.
- Financial fields remain immutable.

### M3-05 Credit CDR rules
**Labels:** `type:feature area:cdr milestone:3 priority:p0 size:m`
**Acceptance**
- Credit requires a reference to an original.
- Same partner pair and currency.
- No credit of a credit; no double credit.
- Trigger tests cover all cases.

### M3-06 Ingestion metrics
**Labels:** `type:feature area:cdr milestone:3 priority:p1 size:s`
**Acceptance**
- Micrometer counters: accepted, duplicate, quarantined, failed.
- Timer for import duration.
- Metrics visible at `/actuator/prometheus`.

---

## Milestone 4 — Rating

### M4-01 Component calculators
**Labels:** `type:feature area:rating milestone:4 priority:p0 size:m`
**Acceptance**
- Energy, time, parking, flat calculators.
- Step-size semantics documented.
- Golden tests per component.

### M4-02 Element selection
**Labels:** `type:feature area:rating milestone:4 priority:p0 size:m`
**Acceptance**
- Restriction evaluation integrated.
- Deterministic tie-break.
- No-element failure with a typed code.

### M4-03 Per-line tax
**Labels:** `type:feature area:rating milestone:4 priority:p0 size:m`
**Acceptance**
- Effective tax rule selected per component.
- Half-up per-line rounding.
- Sum of tax lines equals result tax.

### M4-04 Rating runs with checkpoints
**Labels:** `type:feature area:rating milestone:4 priority:p0 size:l`
**Acceptance**
- Run record with cursor and counts.
- Chunked processing and independent commits.
- Resume after simulated crash.
- No duplicate active results.

### M4-05 Variance detection
**Labels:** `type:feature area:rating milestone:4 priority:p0 size:m`
**Acceptance**
- Declared vs rated comparison.
- Variance types and tolerance from agreement.
- Variance row always written.

### M4-06 Credit netting
**Labels:** `type:feature area:rating milestone:4 priority:p0 size:m`
**Acceptance**
- Credit CDRs produce negative lines.
- Net of original + credit is correct.
- Credit cannot be rated against a missing original.

### M4-07 Rating property tests
**Labels:** `type:test area:rating milestone:4 priority:p0 size:m`
**Acceptance**
- Sum invariants.
- Determinism.
- Monotonicity in energy at fixed tariff.
- Shrinking produces minimal failures.

---

## Milestone 5 — Invoicing

### M5-01 Invoice numbering
**Labels:** `type:feature area:invoicing milestone:5 priority:p0 size:m`
**Acceptance**
- Locked sequence per entity and financial year.
- Gapless under concurrency.
- Format documented and tested.

### M5-02 Issue transaction and posting
**Labels:** `type:feature area:invoicing milestone:5 priority:p0 size:m`
**Acceptance**
- Issue and journal commit atomically (or via outbox).
- Idempotent on retry.
- Issued invoice immutable.

### M5-03 GST split by place of supply
**Labels:** `type:feature area:invoicing milestone:5 priority:p0 size:m`
**Acceptance**
- CGST/SGST vs IGST.
- Rate and rule copied into tax lines.
- Tests for same-state and inter-state.

### M5-04 Credit notes
**Labels:** `type:feature area:invoicing milestone:5 priority:p0 size:m`
**Acceptance**
- Cannot exceed the original.
- Uses original tax rule.
- Posts a balanced journal.
- Sets invoice status to partially/fully credited.

### M5-05 IRP-ready payload
**Labels:** `type:feature area:invoicing milestone:5 priority:p1 size:m`
**Acceptance**
- Required fields present and validated.
- No IRP submission.
- Documented mapping to e-invoice fields.

### M5-06 Invoice register report
**Labels:** `type:feature area:reporting milestone:5 priority:p2 size:s`
**Acceptance**
- Date range and status filters.
- Totals match invoices.
- Partner-scoped.

### M5-07 Numbering and issue concurrency tests
**Labels:** `type:test area:invoicing milestone:5 priority:p0 size:m`
**Acceptance**
- Parallel issuance yields unique numbers.
- Parallel duplicate issue yields one invoice.
- Tests run against real PostgreSQL.

---

## Milestone 6 — Reconciliation

### M6-01 Partner invoice import
**Labels:** `type:feature area:reconciliation milestone:6 priority:p0 size:m`
**Acceptance**
- JSON and CSV import of invoice lines.
- Duplicate line detection.
- Currency validation.

### M6-02 Matching engine
**Labels:** `type:feature area:reconciliation milestone:6 priority:p0 size:l`
**Acceptance**
- Exact CDR key match.
- Amount tolerance per agreement.
- Classifies missing CDR/line, mismatch, duplicates.
- Deterministic for identical inputs.

### M6-03 Exception lifecycle
**Labels:** `type:feature area:reconciliation milestone:6 priority:p0 size:m`
**Acceptance**
- Open → resolved/waived with code, actor, time.
- Cannot close without resolution data.
- Resolution audited.

### M6-04 Run immutability and counts
**Labels:** `type:feature area:reconciliation milestone:6 priority:p1 size:s`
**Acceptance**
- Completed runs immutable.
- `matched + exceptions = total`.
- Re-run creates a new run.

### M6-05 Exception ageing report
**Labels:** `type:feature area:reporting milestone:6 priority:p2 size:s`
**Acceptance**
- Buckets 0–7, 8–30, 31–60, 60+ days.
- Partner-scoped.
- Matches open exception count.

---

## Milestone 7 — Ledger

### M7-01 Period management
**Labels:** `type:feature area:ledger milestone:7 priority:p0 size:m`
**Acceptance**
- Create/list periods.
- Close with actor/time.
- Posting to closed period rejected.

### M7-02 Posting recipes for all sources
**Labels:** `type:feature area:ledger milestone:7 priority:p0 size:m`
**Acceptance**
- Invoice, credit note, settlement, adjustment.
- Multi-entity posting when both parties are onboarded.
- One standard entry per source per entity.

### M7-03 Reversal service
**Labels:** `type:feature area:ledger milestone:7 priority:p0 size:s`
**Acceptance**
- Reversal mirrors the original.
- Links to the original entry.
- Net effect zero.
- Audited.

### M7-04 Integrity check job
**Labels:** `type:feature area:ledger milestone:7 priority:p1 size:m`
**Acceptance**
- Checks journals, invoice totals, rating totals, settlement totals.
- Emits metrics/log alerts.
- Never auto-fixes.

### M7-05 Trial balance per entity and period
**Labels:** `type:feature area:ledger milestone:7 priority:p0 size:s`
**Acceptance**
- Entity and period required.
- Debits equal credits.
- Matches journal data.

---

## Milestone 8 — Settlement

### M8-01 Eligibility selection
**Labels:** `type:feature area:settlement milestone:8 priority:p0 size:m`
**Acceptance**
- Selects only eligible, unsettled items.
- Excludes disputed-hold and fully credited items.
- Documented policy.

### M8-02 Netting with advisory lock
**Labels:** `type:feature area:settlement milestone:8 priority:p0 size:l`
**Acceptance**
- Advisory lock per partner pair/period.
- Net = receivables − payables.
- Concurrent run returns `409`.
- Journals balance.

### M8-03 Statement generation
**Labels:** `type:feature area:settlement milestone:8 priority:p0 size:m`
**Acceptance**
- Immutable statement with number and content hash.
- CSV export.
- Reproducible from the run.

### M8-04 Settlement concurrency tests
**Labels:** `type:test area:settlement milestone:8 priority:p0 size:m`
**Acceptance**
- Double settlement rejected.
- Concurrent runs serialized.
- Item settled once.

---

## Milestone 9 — Disputes

### M9-01 Dispute state machine
**Labels:** `type:feature area:dispute milestone:9 priority:p0 size:m`
**Acceptance**
- Allowed transitions only.
- Every transition writes an event.
- Illegal transition returns `409`.

### M9-02 Evidence metadata
**Labels:** `type:feature area:dispute milestone:9 priority:p0 size:s`
**Acceptance**
- Type, file name, size, SHA-256 required.
- No file storage yet.
- Evidence blocked after close.

### M9-03 Resolution linkage
**Labels:** `type:feature area:dispute milestone:9 priority:p0 size:s`
**Acceptance**
- Resolved dispute references a credit note or adjustment.
- Resolution code required.
- Audited.

### M9-04 Timeline endpoint
**Labels:** `type:feature area:dispute milestone:9 priority:p1 size:s`
**Acceptance**
- Ordered events with actor/time/reason.
- Partner-scoped.
- Matches event table.

---

## Milestone 10 — OCPI

### M10-01 OCPI credentials and routing (client role)
**Labels:** `type:feature area:integration milestone:10 priority:p0 size:l`
**Acceptance**
- Version discovery and credentials exchange.
- Token storage and rotation.
- Feature-flagged.
- Contract tests.

### M10-02 OCPI 2.2.1/2.3.0 CDR mapping
**Labels:** `type:feature area:integration milestone:10 priority:p0 size:l`
**Acceptance**
- Fixture payloads map to the domain CDR.
- Credit fields handled.
- No OCPI types in the domain.
- Version-specific behaviour isolated.

### M10-03 Invoice Reconciliation mapping
**Labels:** `type:feature area:integration milestone:10 priority:p0 size:l`
**Acceptance**
- Maps internal reconciliation items to the OCPI module.
- Round-trip fixture tests.
- Documented limitations.

### M10-04 Contract fixtures and WireMock
**Labels:** `type:test area:integration milestone:10 priority:p1 size:m`
**Acceptance**
- Fixtures for success, duplicate, error.
- WireMock for partner endpoints.
- CI runs them.

### M10-05 Partner sandbox guide
**Labels:** `type:docs area:integration milestone:10 priority:p1 size:s`
**Acceptance**
- Credentials, endpoints, idempotency, error codes.
- Known limitations.
- Example requests.

---

## Milestone 11 — Production

### M11-01 OpenTelemetry and dashboards
**Labels:** `type:feature area:platform milestone:11 priority:p1 size:l`
**Acceptance**
- Traces for ingest/rating/invoice/settlement.
- Prometheus metrics scraped.
- Grafana dashboard JSON committed.

### M11-02 Backup and restore drill
**Labels:** `type:chore area:platform milestone:11 priority:p0 size:m`
**Acceptance**
- Restore procedure documented and executed.
- RPO/RTO verified.
- Results recorded.

### M11-03 Security review and penetration test
**Labels:** `type:security area:platform milestone:11 priority:p0 size:l`
**Acceptance**
- ASVS L2 checklist completed.
- Findings triaged and fixed or accepted.
- Test report stored.

### M11-04 IRP sandbox integration
**Labels:** `type:feature area:integration milestone:11 priority:p1 size:l`
**Acceptance**
- Sandbox submission with IRN.
- Idempotent, retried, audited.
- No production credentials in the repo.

### M11-05 UBC/Beckn adapter spike
**Labels:** `type:research area:integration milestone:11 priority:p2 size:l`
**Acceptance**
- Official documentation summary.
- Adapter port and feature flag.
- Explicit "experimental" label.
- No claim of certification.

### M11-06 Evidence object storage
**Labels:** `type:feature area:dispute milestone:11 priority:p2 size:m`
**Acceptance**
- S3-compatible private bucket.
- Presigned upload/download with short TTL.
- Hash verified on download.
- Retention policy.

### M11-07 Load and failure tests
**Labels:** `type:test area:platform milestone:11 priority:p1 size:l`
**Acceptance**
- Ingestion and rating targets measured.
- Outbox lag measured.
- Failure injection (DB restart, adapter timeout).
- Results documented.

### M11-08 Maker-checker
**Labels:** `type:feature area:platform milestone:11 priority:p2 size:l`
**Acceptance**
- Invoice issue and journal reversal require approval.
- Separation of duties.
- Audited.

### M11-09 Row-level security
**Labels:** `type:security area:platform milestone:11 priority:p2 size:m`
**Acceptance**
- RLS policies for partner-scoped tables.
- App role cannot bypass.
- Every query tested with and without `app.partner_id`.

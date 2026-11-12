# Executive project assessment

**Date:** 12 November 2026
**Subject:** VoltReckon — EV charging interoperability, reconciliation, and settlement infrastructure
**Verdict:** Build it, but not as originally described.

---

## 1. Bottom line

The original concept — "a unified backend platform for EV charging interoperability, roaming, financial reconciliation and settlement" — is too broad to be a credible MVP and overlaps with infrastructure that is now being built publicly in India.

The defensible slice is narrower and harder:

> **A B2B reconciliation and settlement workbench that turns cross-network charging records into auditable invoice, tax, dispute, ledger, and net-settlement records.**

This is worth building because:

1. OCPI itself added an **Invoice Reconciliation** module in 2026, which validates the problem as a standards-level concern.
2. OCPI CDRs are explicitly **immutable billing records**; corrections require Credit CDRs. This forces a financial-control design that most hobby projects avoid.
3. India's **UBC/UEI** initiatives are solving consumer discovery and payment interoperability, not the CPO↔eMSP back office. VoltReckon complements them.
4. Indian **GST and e-invoicing** add a concrete, testable compliance dimension that global OCPI tutorials ignore.

This is not a proven commercial opportunity. It is a technically serious reference implementation with plausible utility for small and mid-sized operators. The blueprint is honest about that distinction.

---

## 2. What the research changed

| Original assumption | What the evidence says | Consequence for VoltReckon |
|---|---|---|
| "Roaming/interoperability is the main gap." | India is actively solving consumer interoperability through UBC (MHI/BHEL/NPCI, Beckn) and previously UEI. Roaming hubs and CPMS vendors also exist. | Do **not** build a consumer app, a roaming hub, or a discovery layer. |
| "Reconciliation is one feature among many." | OCPI 2.3.0 edition 2 added a dedicated Invoice Reconciliation module. CDRs cannot be edited. Industry write-ups describe recurring timestamp, energy, and tariff-component mismatches. | Make reconciliation, evidence, and ledger the **core**, not a side feature. |
| "Build a broad enterprise platform." | A single developer cannot finish a 17-module enterprise suite; large CPMS vendors already cover operations. | Ship a **modular monolith** with 10 core modules and a narrow workflow. |
| "Use Kafka/Redis/microservices to look serious." | MVP volume is tiny relative to broker capacity; distributed transactions would add failure modes without business value. | PostgreSQL outbox, deterministic jobs, no broker in MVP. |
| "Add AI for anomaly detection." | Reconciliation and ledger posting require deterministic, auditable rules. Training data is unavailable. | Defer AI to Phase 3 as **advisory only**. |
| "Generate GST invoices like any invoice." | EV charging GST classification is contested (18% service is the practical position; equipment is 5%; electricity is generally exempt). E-invoicing thresholds and IRP flows are specific. | Model tax as **versioned, configurable rules**; do not hard-code legal conclusions. |

---

## 3. Evidence strength

| Claim | Evidence | Strength |
|---|---|---|
| Cross-network charging requires CDR exchange and billing | OCPI specification (core, CDRs, Tariffs, Invoice Reconciliation) | **Strong** — primary standard |
| CDRs are immutable and corrections use Credit CDRs | OCPI 2.3.0 CDR module | **Strong** — primary standard |
| Invoice reconciliation is a recognised need | OCPI 2.3.0 edition 2 adds the module (18 June 2026) | **Strong** — primary standard |
| CDR inconsistencies cause billing problems | OCPI/ChargeX recommendations note format variations, optional-field inconsistency, proprietary extensions, cost-breakdown gaps; industry articles describe timestamp/energy/tariff mismatches | **Moderate** — mixed primary and secondary |
| India has many networks and growing roaming | Government counts, industry reporting on roaming integrations, UBC launch | **Moderate** — counts vary; vendor claims are self-reported |
| UBC owns consumer discovery/payment | MHI/BHEL/NPCI launch reporting; Beckn architecture | **Moderate** — recent; technical details still emerging |
| GST on EV charging is 18% service | Karnataka AAR (2023), industry tax analyses, CBIC-linked guidance cited by practitioners | **Moderate** — AAR is binding only on the applicant; classification is contested |
| E-invoicing applies above ₹5 crore AATO | GST e-invoice portal, Notification 10/2023-Central Tax | **Strong** — official |
| DPDP Rules apply to driver data | DPDP Act 2023 + Rules 2025 (Gazette, 14 November 2025) | **Strong** — official |
| Existing vendors charge for this | Vendor pages and public materials | **Weak** — pricing is rarely public; no verified price points |

The blueprint does not claim market size, willingness to pay, or frequency of disputes. Those require customer discovery.

---

## 4. Is VoltReckon differentiated?

Partially. Be precise about the layers:

```
Consumer discovery / payment      UBC, BHIM, CPO apps, OEM apps, eMSP apps
Charging operations / CSMS       Driivz, AMPECO, Kazam, Numocity, Savekar, in-house
Roaming connectivity             Hubject, Gireve, UBC/Beckn, bilateral OCPI
Back-office settlement           ERP/accounting + spreadsheets + custom scripts
                                 ^ VoltReckon targets this layer
```

VoltReckon's differentiation is **not** a new protocol or a new network. It is the combination of:

- OCPI-native CDR and Invoice Reconciliation semantics.
- Immutable, double-entry financial control rather than report generation.
- India-specific GST/e-invoice data preparation.
- Evidence-first dispute handling.
- A small, auditable codebase that a single team can understand.

That is a **complementary infrastructure component**, not a new product category. It could be sold as software, run internally by an operator, or used as a reference implementation. It is not a credible claim of displacing Hubject, Gireve, Driivz, or a CPMS.

---

## 5. Recommended product scope

### Core MVP (must work end to end)

1. Partner, user, role, and GSTIN registry with strict partner isolation.
2. Roaming agreement with effective dates, settlement cycle, currency, and tax profile.
3. Immutable tariff versions with OCPI-style price components and restrictions.
4. CDR ingestion (JSON/CSV), schema validation, duplicate detection, credit-CDR linkage, quarantine.
5. Deterministic re-rating with a pinned tariff version and variance report.
6. Invoice draft → issue → credit note, with configurable GST and immutable numbering.
7. Partner-invoice reconciliation with CDR-level matching and an exception queue.
8. Double-entry ledger, trial balance, and accounting-period close.
9. Dispute case and evidence register.
10. Settlement run with netting, advisory lock, and statement export.
11. Audit log and machine-readable operational metrics.

### Phase 2

- Full OCPI 2.3.0 endpoint suite (versions, credentials, locations, tariffs, sessions, CDRs, invoice reconciliation) as a CPO or eMSP.
- IRP e-invoice integration (sandbox first), including IRN, signed QR, and cancellation rules.
- UBC/Beckn transaction adapter, only against official onboarding material.
- Object storage (S3/MinIO) for evidence, with virus scanning and retention.
- Bank statement import and payment matching.
- OIDC/SSO, maker-checker approvals, mTLS, rate limiting.
- OpenTelemetry, Prometheus, Grafana dashboards, Loki logs.

### Phase 3

- Multi-GSTIN/multi-entity consolidation.
- Cross-agreement netting and FX (only if cross-border).
- Advisory anomaly detection and reconciliation suggestions with human approval.
- Advanced analytics and partner scorecards.

### Removed from scope permanently (unless evidence changes)

- Consumer app, wallet, stored value, or payment initiation.
- OCPP CSMS, charger control, live session management.
- Roaming hub or Beckn gateway.
- Blockchain, event sourcing, microservices.
- AI deciding financial postings or payout approvals.

---

## 6. Architecture in one page

- **Style:** modular monolith with Spring Modulith. One deployable, one PostgreSQL database.
- **Modules:** partner, agreement, tariff, cdr, rating, invoicing, reconciliation, ledger, settlement, dispute, plus platform and integration.
- **Communication:** in-process application services; cross-module side effects via transactional events persisted in an outbox table.
- **Consistency:** one aggregate per transaction; no distributed transactions; idempotent consumers; unique constraints as the last line of defence.
- **Money:** `BIGINT` minor units + ISO-4217 currency; `BigDecimal` only for intermediate rate/tax math with explicit rounding.
- **Ledger:** append-only `journal_entry`/`journal_line`, balanced by a deferred constraint trigger; corrections by reversal.
- **API:** REST/JSON, OpenAPI 3.1, `Idempotency-Key`, partner-scoped JWT.
- **Deployment:** container + managed PostgreSQL; Kubernetes optional and not required.

Why not microservices: the domain has strong transactional invariants (invoice lines, tax lines, journals), the team is one developer, and the volume is low. Microservices would turn local transactions into sagas and add operational cost with no user-visible benefit. Revisit only if independently scalable workloads or team boundaries emerge.

Why not Kafka: the MVP needs durable, ordered, at-least-once internal events, not high-throughput streaming. A PostgreSQL outbox provides that with one fewer system to operate. Revisit at sustained high volume or when multiple independent consumers/services exist.

Why not Redis: idempotency and locking can be implemented in PostgreSQL. Redis adds a second source of truth and an eviction/durability failure mode. Revisit for distributed rate limiting or hot read caches when measurements justify it.

---

## 7. AI decision

**Not in the MVP. Advisory only in Phase 3.**

| Candidate | ML necessary? | Better deterministic baseline | Decision |
|---|---|---|---|
| Duplicate CDR detection | No | Hash + business key + credit-link rules | Deterministic |
| Reconciliation matching | No | Exact key match, then tolerance rules | Deterministic |
| Tariff misconfiguration | No | Rule-based variance thresholds | Deterministic |
| Anomalous energy/time | Maybe | Statistical thresholds per connector/tariff | Phase 3, human review |
| Dispute evidence classification | Maybe | Keyword and document-type rules | Phase 3, human review |
| Incident summarisation | Maybe | Templates | Optional, non-financial |

Constraints if AI is added: no write access to ledger, invoices, settlements, or payouts; every suggestion is a proposal with provenance; human approval is mandatory; evaluation must measure false positives against a labelled sample; PII must be minimised. See [ADR-0006](adr/0006-ai-deferred.md).

---

## 8. Risks and unknowns

| Risk | Impact | Mitigation |
|---|---|---|
| Market need is real but buyers prefer CPMS/ERP bundles | Low commercial traction | Position as a reference implementation; target small operators; validate with design partners |
| UBC/OCPI technical details change | Adapter rework | Keep integration behind anti-corruption ports; no protocol types in the domain |
| GST interpretation changes | Invoice rework | Versioned tax rules; no hard-coded rates; legal review |
| Scope creep into CSMS/payments | Project never finishes | Explicit out-of-scope list; ADRs; milestone gates |
| Financial bugs | Loss of trust | Invariants in DB, property-based tests, no floating point, append-only ledger |
| Single-developer bandwidth | Incomplete system | Vertical slices; no service-per-module; defer non-core features |
| Evidence storage/PII | Privacy and security exposure | Minimise PII, private buckets, retention policy, DPDP review |
| OCPI 2.3.0 adoption lag in India | Integration friction | Support 2.2.1 CDRs; contract tests per partner |

Unknowns that require real-world validation:

- How often disputes occur, and at what value.
- Whether operators will pay for a standalone workbench versus demanding a full CPMS.
- Whether UBC exposes B2B settlement/reconciliation data or only consumer flows.
- The actual GST position accepted by auditors for a given operator structure.
- The cost and latency of IRP integration at realistic volumes.

---

## 9. What I would change if I were building this

The short version (full version in [reviews/principal-review.md](reviews/principal-review.md)):

1. **Pick one side first.** Build for a CPO's finance team, not a two-sided marketplace. Add the eMSP view after the CPO workflow is proven.
2. **Get 50–200 anonymised real CDRs before writing the rating engine.** Real data will expose edge cases no specification example covers.
3. **Make reconciliation the hero.** Invoice generation is table stakes; reconciliation evidence is the differentiator.
4. **Treat GST as configuration with an audit trail.** Do not encode tax law in code.
5. **Do not build an OCPI server in the MVP.** Ingest CDRs over an authenticated endpoint and CSV; implement the full module suite after the core is stable.
6. **Do not add a message broker, Redis, or Kubernetes.** They are résumé-driven, not requirement-driven.
7. **Write the ledger and money layer first.** They constrain everything else. If they are wrong, every later feature inherits the defect.
8. **Design for audit before design for scale.** The system's value is proof, not throughput.

---

## 10. Final recommendation

Proceed with the narrowed scope. The project is technically credible, standards-aligned, and achievable by one developer in vertical slices. It is **not** a validated startup, and the documentation should never pretend otherwise.

Success criteria for the blueprint:

- A new developer can run PostgreSQL and understand the domain in under an hour.
- Every financial rule has a testable invariant.
- Every integration boundary is explicit and behind an anti-corruption layer.
- Every claim about standards, tax, or competitors is traceable to a source.
- The MVP can be demonstrated end to end without Kafka, Redis, Kubernetes, or AI.

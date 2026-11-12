# Principal engineer review

**Reviewer stance:** skeptical principal engineer asked to approve or reject the blueprint before engineering spend.

**Scope reviewed:** README, research, architecture, schema, financial model, API, security, reliability, testing, roadmap, ADRs.

**Verdict:** **Conditionally approve the blueprint, reject the current scope if it is treated as a product plan without a design partner.**

The engineering is sound and unusually disciplined for a greenfield financial system. The risk is not architecture. The risk is **market and validation risk disguised as engineering progress**.

---

## 1. What is strong

1. **Correct system shape.** A modular monolith over PostgreSQL with a transactional outbox is the right call for a one-developer financial MVP. Microservices, Kafka, and event sourcing would have been expensive theatre.
2. **Money handling is right.** Integer minor units, explicit currency, `HALF_UP` per line, no floats, and `BigDecimal` only for intermediate math. This is the single most common source of billing bugs, and it is addressed early.
3. **Append-only double-entry ledger.** Immutable journals, credit notes, Credit CDRs, reversing entries, and a deferred balance trigger give a real audit trail. The unique `(entity_partner_id, source_type, source_id, entry_type)` makes posting idempotent.
4. **Idempotency is designed in, not bolted on.** Required `Idempotency-Key` on financial POSTs, request hashing, and replay semantics are in the API contract and schema.
5. **Honest documents.** The README labels everything as planned, records uncertainty, and separates verified facts from secondary reporting. That is rare.
6. **Standards literacy.** OCPI 2.3.0, Credit CDRs, Invoice Reconciliation, OCPP edition context, GST/e-invoice thresholds, and DPDP are treated accurately and with appropriate caveats.

---

## 2. Concerns, ranked

### C1. No design partner, no evidence of willingness to pay (critical)

The plan assumes CPOs/eMSPs will pay for reconciliation. The research establishes that the problem exists; it does not establish that these organisations will buy from a new vendor, or that they will share CDRs and settlement data with one.

**Why it matters:** every week spent before a signed design partner is a week of speculative building. The financial domain is expensive to get right; building it for a hypothetical buyer is the classic failure mode.

**What I would require before M3 (invoicing):**

- At least one CPO or eMSP that has signed an LOI or paid a pilot fee.
- Written access to real (or realistically anonymised) CDR and settlement exports.
- A named operational owner on their side.
- Agreement on the first reconciliation workflow and the success metric.

### C2. Scope is larger than a one-developer MVP (high)

M0–M11 is roughly 28 weeks. That is optimistic for one developer building ingestion, rating, tax, invoicing, ledger, reconciliation, settlement, disputes, reporting, security, and integrations, even with good tooling.

**What I would change:** cut the first release to M0–M6 plus a thin settlement view. Defer disputes, full reporting, and all OCPI endpoints. Ship a narrow "ingest → rate → reconcile → explain" loop and sell that.

### C3. GST classification is unresolved and material (high)

EV charging is widely treated as an 18% service (SAC 998714), with a competing 998599 classification and equipment at 5%. A tariff engine that hardcodes a rate will be wrong for some counterparties.

**What I would change:** make tax rules fully configuration-driven per entity and per line type, versioned with effective dates, and require a tax professional to sign off the seed rules. Do not present computed tax as filing-ready.

### C4. OCPI ingestion alone may not match reality (high)

Real Indian CPO/eMSP exchanges often happen as CSV, spreadsheets, portal exports, and email. The blueprint supports CSV, which is good, but the *variance* between partners is the hard part: column names, timezones, units, currency formatting, and missing fields.

**What I would change:** build a configurable CSV mapping profile per partner (column map, date format, timezone, unit conversions, required fields) before building rating. Treat OCPI as one adapter, not the centre of gravity.

### C5. Reconciliation matching is underspecified for real data (high)

The docs describe exact and tolerance matching. Real reconciliation needs: duplicate detection across sources, partial sessions, rounding differences, timezone drift, tariff-version mismatches, taxes, and fees that appear on one side only.

**What I would change:** write a matching specification with a scored, explainable decision table and a worked example set of at least 50 real-ish cases before coding. The exception taxonomy must be derived from those cases, not invented.

### C6. Settlement is legally and operationally sensitive (medium-high)

Netting, payout instructions, and settlement confirmations touch money movement. Even if VoltReckon never moves money, a wrong settlement statement can cause a partner to pay incorrectly.

**What I would change:** keep settlement as *statements and approvals*, not payments. Require dual control for approval, immutable statements, and an explicit "this is not a payment instruction" disclaimer until a payment partner and legal review exist.

### C7. Security model is good on paper, untested in code (medium)

The security doc covers STRIDE, tenancy, idempotency, webhooks, and DPDP. But there is no code, no threat-model test, and no penetration test. JWT validation, tenant isolation, and file upload handling are where real breaches happen.

**What I would change:** add an explicit Phase 1 security gate: tenant-isolation integration tests, dependency scanning, secret scanning, and an external review before any real partner data.

### C8. Operational maturity is assumed, not built (medium)

The runbook is sensible, but the MVP has no alerting, no dashboards, no backup automation, and no on-call rotation. For a financial system, "we will add it later" is how incidents become outages.

**What I would change:** M2 must include health checks, structured logs with correlation IDs, the core metrics, and a tested backup/restore. Not after launch.

### C9. Documentation volume risks becoming the deliverable (medium)

There is a lot of documentation for zero lines of product code. It is high quality, but it can create an illusion of progress.

**What I would change:** freeze the docs after this review. The next commit should be a running skeleton with one vertical slice, not another design document.

### C10. Some details need correction before implementation (low-medium)

- The trial balance view and `entity_partner_id` change are good; ensure every posting path sets the entity.
- `varchar(3)` for currency is deliberate; keep it consistent in JPA mappings.
- The OpenAPI spec is valid but only covers the MVP surface; regenerate and diff it in CI once code exists.
- The `cdr` append-only trigger allows only `ingest_status`; confirm no other operational field ever needs mutation, or add an explicit allow-list with justification.

---

## 3. Specific questions I would ask the founder

1. Who is the first paying counterparty, and what did they say when asked to share CDRs?
2. What is the current cost of their reconciliation process (people, hours, errors, disputes)?
3. Which side of the market do we serve first: CPO or eMSP? The workflows differ.
4. What does "correct" mean for them: zero variance, explainable variance, or faster close?
5. Who is accountable if a settlement statement is wrong?
6. What data can we legally store, for how long, and where?
7. What is the smallest deliverable they would pay for in 8 weeks?

If these cannot be answered with evidence, the correct next step is customer discovery, not M0.

---

## 4. What I would change in the plan

| Current | Change | Reason |
|---|---|---|
| M0–M11, ~28 weeks | M0–M6 first release, ~12–14 weeks | Reduce time-to-learning |
| Full OCPI endpoint suite in Phase 2 | Ingestion adapters only until a partner needs more | Avoid building unused protocol surface |
| Disputes in MVP | Defer to Phase 2 | Not needed to prove the core loop |
| Full reporting | One reconciliation report + export | Prove value before breadth |
| CSV as a secondary path | CSV mapping profiles as a first-class feature | Matches Indian market reality |
| Tax as computed output | Tax as versioned configuration with professional sign-off | Classification is contested |
| Settlement including payouts | Statements and approvals only | Legal and operational risk |
| Docs-first | Freeze docs; build one vertical slice | Convert design into evidence |

---

## 5. Sign-off conditions

I would approve engineering spend when:

1. A design partner is identified with written intent and data access.
2. The first release is cut to the ingest → rate → reconcile → explain loop.
3. The matching specification and exception taxonomy are written from real cases.
4. Tax rules are configuration-driven and reviewed by a professional.
5. The M2 operational baseline (health, logs, metrics, backup/restore) is in the release gate.
6. A security gate is defined for tenant isolation and secret/dependency scanning.

Until then, this is a strong blueprint, not a validated business.

---

## 6. Bottom line

**Architecture: approve.** The system shape, money model, ledger, idempotency, and standards posture are appropriate and well reasoned.

**Product plan: revise.** The plan is too broad for one developer and rests on unvalidated demand. Narrow the first release, secure a design partner, and treat reconciliation matching and tax as the real technical risks rather than the infrastructure.

The best thing about this blueprint is that it is honest about what it does not know. The next step is to turn that honesty into customer evidence.

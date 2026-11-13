# 01 — Product scope

- **Status:** Draft
- **Owner:** VoltReckon maintainer
- **Last verified:** 2026-11-13
- **Applies to phases:** 0–10

## 1. Problem

EV roaming moves money between organisations that do not share a database. A driver buys
charging from an eMSP, charges on a CPO's station, and the CPO sends a Charge Detail Record
(CDR) to the eMSP. Before money moves, both sides must agree on energy, time, tariff version,
tax, totals, invoice lines, and settlement balances. The recurring failures are duplicate or
late CDRs, corrections without credits, tariff drift, currency and rounding differences,
invoices that do not match CDRs, disputes without evidence, and journals that do not reconcile.

VoltReckon is the back office that makes that trail explicit and testable. It is not a charger
management system, not a consumer app, not a roaming hub, and not a payment processor.

## 2. Users and jobs

| User | Primary job | First-class needs |
|---|---|---|
| CPO finance lead | Prove what an eMSP owes and why | CDR integrity, rating variance, invoice register, ageing |
| eMSP billing analyst | Check a partner invoice against received CDRs | Statement import, matching, exceptions, credit notes |
| Roaming manager | Onboard partners and pin commercial terms | Agreements, tariff versions, effective dates |
| Dispute handler | Resolve a case with evidence | Case state machine, evidence hashes, timeline |
| Settlement operator | Net balances and issue statements | Maker-checker, reproducible netting, locks |
| Accountant/auditor | Trace every posting to a source | Trial balance, audit chain, exports |
| Platform administrator | Operate users and access | Partner scoping, roles, least privilege |
| Partner system (machine) | Push CDRs and read status | OCPI-compatible endpoints, idempotency, clear errors |

**PROD-001** Every partner-scoped human action MUST execute inside exactly one partner
scope; a platform-administration action MUST name its target partner and be audited.
*Check:* `ArchitectureTests` plus cross-tenant integration tests in every module.

**PROD-002** A partner system MUST be able to ingest a CDR without a human session.
*Check:* `ingestion` integration test using OAuth2 client credentials.

## 3. Core flow

```
CDR in -> validate/deduplicate -> pin tariff -> rate -> invoice data -> reconcile
       -> dispute/credit -> double-entry ledger -> net settlement -> audit/report
```

Each arrow is a module boundary from [03-architecture.md](03-architecture.md). A phase may
expose only part of the flow; later phases must not change earlier records in place.

## 4. Scope tiers

Tiers are ordered, not optional. Deferred work stays documented with a trigger; it is never
silently deleted.

### T1 — core (phases 1–9)

| Capability | Module | Phase |
|---|---|---|
| Partner registry, agreements, GST profile | `partners` | 1–2 |
| Users, roles, partner-scoped auth | `iam` | 2 |
| OCPI 2.2.1-compatible CDR intake, quarantine, credits | `ingestion` | 1 |
| Versioned tariffs and effective-date selection | `tariff` | 2–3 |
| Deterministic re-rating and variance | `rating` | 3 |
| GST-aware invoices, credit notes, numbering | `billing` | 5 |
| Double-entry ledger, periods, trial balance | `ledger` | 4 |
| Partner-invoice reconciliation and exceptions | `reconciliation` | 6 |
| Dispute case workflow and evidence metadata | `dispute` | 7 |
| Netting, settlement statements, maker-checker | `settlement` | 8 |
| Append-only audit chain and reports | `audit`, `reporting` | 9 |

**PROD-003** T1 MUST run as one Spring Boot deployable and one PostgreSQL 18 database.
*Check:* `13-build-and-operations` command list; Testcontainers integration suite.

**PROD-004** T1 MUST produce a balanced journal for every financial document.
*Check:* `JournalBalanceIT` and the deferred database constraint; see 05-financial-model.

### T2 — advanced, deferred with triggers

| Capability | Trigger to start |
|---|---|
| Kafka externalization of outbox events | Sustained outbox lag above 60 seconds for 7 days, or a second consumer service |
| OTel + Prometheus + Grafana + Loki/Tempo | A production SLO exists and an on-call rotation exists |
| MinIO/S3 evidence store | Dispute evidence exceeds local disk limits or a second instance is required |
| PDF + QR invoices | A partner requires a rendered document rather than structured data |
| Multi-currency settlement | A signed agreement uses a settlement currency other than the invoice currency |
| Full OCPI endpoint suite (locations, sessions, tokens, commands) | A partner contract requires CPO or eMSP receiver interfaces |
| IRP e-invoice production integration | AATO exceeds the notified threshold and the operator chooses direct IRP submission |
| UBC/Beckn adapter | An official UBC specification and onboarding path are published |
| Spring Batch | A single migration or month-end job exceeds 30 minutes of paged work |
| Redis | Measured lock or cache contention cannot be solved with PostgreSQL advisory locks |

**PROD-005** A T2 item MUST NOT be implemented before its trigger is met and an ADR records it.
*Check:* review of the phase plan and ADR index.

### T3 — optional, advisory only

| Capability | Constraint |
|---|---|
| Anomaly scoring for CDR or invoice review | Never posts, approves, prices, taxes, or settles |
| Natural-language explanation of a variance | Read-only text; the numeric record remains authoritative |

**PROD-006** AI output MUST NOT be an input to a financial posting, tax amount, approval, or
settlement decision. *Check:* review of every AI-adjacent use case; no AI dependency in T1.

## 5. Non-goals

- OCPP device control, live charger state, remote start/stop, or a CSMS.
- Consumer discovery, UPI collection, wallets, stored value, or money movement.
- A roaming hub, Beckn gateway, or UBC replacement.
- GST return filing, legal advice, or a tax engine certified by any authority.
- Event sourcing, microservices, Kubernetes, Redis, Kafka, or blockchain in T1.
- Storing driver names, phone numbers, or raw identity documents.

**PROD-007** The system MUST record settlement obligations, not move funds.
*Check:* no payout or bank integration exists in the T1 dependency set.

## 6. Success criteria

**PROD-008** Given a valid OCPI CDR, when it is posted twice with the same idempotency key,
then exactly one internal CDR exists and the second response is a replay.
*Check:* `ingestion` idempotency IT.

**PROD-009** Given two CDRs for the same original with `credit=true`, when the second is
ingested, then it is quarantined with `DUPLICATE_CREDIT` and no ledger effect occurs.
*Check:* `ingestion` credit IT.

**PROD-010** Given a session, when rating runs after a tariff price change, then the result
still uses the tariff version effective at session start and the variance is recorded.
*Check:* `rating` golden IT with a mutable clock.

**PROD-011** Given an issued invoice, when a correction is needed, then a credit note is
issued and the original invoice row is unchanged.
*Check:* `billing` immutability IT and database trigger assertion.

**PROD-012** Given any posted journal, when the trial balance is queried for an entity and
period, then total debits equal total credits and the sum of balances is zero.
*Check:* `ledger` trial-balance IT and the deferred balance constraint.

**PROD-013** Given a completed settlement run, when the same pair and period run again,
then the second run is rejected and the first statement is byte-for-byte reproducible.
*Check:* `settlement` concurrency IT and statement hash test.

**PROD-014** Given an audit export, when an event's stored hash is recomputed, then the chain
verifies or the export fails with the first broken sequence.
*Check:* `audit` chain-verification IT.

**PROD-015** Given a request for another partner's record, when the caller is authenticated,
then the response is `404` with `RESOURCE_NOT_FOUND`, never `403` with existence leakage.
*Check:* cross-tenant IT in every module that exposes a read endpoint.

## 7. Operating assumptions

- One maintainer builds the backend first; the React frontend consumes the API later.
- PostgreSQL 18 is the only store; backups and point-in-time recovery are infrastructure.
- OCPI 2.2.1 partners exist in practice; OCPI 2.3.0 is the target contract [ref-1][ref-2].
- OCPI 2.3.0-ed2 (2026-06-18) adds Invoice Reconciliation [ref-3][ref-4].
- UBC is Beckn-based, not OCPI, and is a separate adapter if it ever lands [ref-27].
- Standalone EV charging is treated as a service at 18% GST under SAC 998714 for India,
  based on an AAR; rates remain configurable and are not legal advice [ref-13][ref-14].
- Money is integer minor units; no floating point anywhere [ref-25].
- The application never stores full card data or bank credentials.

## 8. Acceptance scenario for the whole product

```gherkin
Scenario: Month-end from CDR to settlement
  Given an active CPO-eMSP agreement in INR with monthly settlement
  And a published tariff version effective for the session start
  When a valid OCPI CDR is ingested and rated
  And an invoice is issued with GST and a balanced journal
  And a partner statement is imported and matched
  And the settlement run is approved by a second user
  Then the trial balance is balanced
  And the settlement statement hash is reproducible
  And every state change is present in the audit chain
```

This scenario is decomposed into the named tests in 14-roadmap and each module spec.

## 9. Risks and disclaimers

- GST and e-invoice rules can change; configuration and effective dates are mandatory.
- OCPI adoption varies; the 2.2.1 compatibility path is a product requirement, not a fallback.
- A single maintainer is a delivery risk; phases are sized for one person and one review.
- VoltReckon is not a tax filing product and does not provide legal advice.

## 10. Phase mapping

| Phase | Scope slice | Exit measure |
|---|---|---|
| 0 | Walking skeleton | Build, Flyway V001, health, architecture and Testcontainers IT |
| 1 | Ingestion foundation | CDR intake, dedupe, quarantine, credit rules |
| 2 | Partners, IAM, tariffs | Partner scope, agreements, versioned tariffs |
| 3 | Rating | Deterministic rating and variance |
| 4 | Ledger | Accounts, journals, periods, trial balance |
| 5 | Billing and GST | Invoices, tax, credit notes, numbering |
| 6 | Reconciliation | Import, matching, exceptions |
| 7 | Disputes | Case state machine and evidence |
| 8 | Settlement | Netting, maker-checker, statements |
| 9 | Audit and reporting | Hash chain, reports, exports |
| 10 | OCPI 2.3.0 suite | Receiver interfaces, invoice reconciliation, hardening |

See [14-roadmap.md](14-roadmap.md) for endpoints, events, migrations, demos, and named tests.

# 14 - Roadmap

- **Status:** Draft
- **Owner:** VoltReckon maintainer
- **Last verified:** 2026-11-13
- **Applies to phases:** 0-10

The roadmap is a dependency order, not a wish list. A phase may expose only part of the flow,
but it must not leave a financial invariant for a later phase to repair by editing history.
Each phase is sized for one maintainer and one review, with a demo that a reviewer can repeat.
Scope tiers are in [01-product-scope.md](01-product-scope.md), endpoints in
[08-api-standards.md](08-api-standards.md), and the migration map in
[04-data-model.md](04-data-model.md).

Phase 0 is complete. Phases 1-9 are the T1 core. Phase 10 is the OCPI 2.3.0 and hardening
phase. A T2 item starts only when its trigger in 01-product-scope is met and an ADR records the
decision.

## 1. Phase 0 - Walking skeleton

| Item | Scope |
|---|---|
| Goal | One deployable, one PostgreSQL 18 database, one schema, health, migration, architecture test |
| Modules | Application shell; `shared` and `platform` package scaffolds |
| Migrations | V001 extensions and schema |
| API | `GET /actuator/health` |
| Events | None |
| Required tests | `WalkingSkeletonIT`, `ArchitectureTests` |
| Demo | `mvn verify`, health 200, Flyway V001, Testcontainers PostgreSQL |
| Exit | Build green, health 200, schema applied, module boundary check green |

**Status:** Complete on 2026-11-13. The baseline is recorded in `CLAUDE.md`.

## 2. Phase 1 - Ingestion foundation and partner identity

| Item | Scope |
|---|---|
| Goal | Accept, validate, deduplicate, and quarantine OCPI 2.2.1 CDRs with no financial effect |
| Modules | `partners`, `ingestion`; `platform` outbox and idempotency |
| Migrations | V002 platform, V003 partners, V004 ingestion |
| API | `POST /ocpi/2.2.1/cdrs`, `POST /cdrs`, `GET /cdrs`, `GET /cdrs/{cdrId}`, `GET /partners/me` |
| Events | `partners.partner.created.v1`, `partners.partner.updated.v1`, `ingestion.cdr.ingested.v1`, `ingestion.cdr.quarantined.v1` |
| Required tests | `OcpiCdrReceiverIT`, `CdrReplayIT`, `CdrDuplicateHashIT`, `CreditCdrIT`, `QuarantineIsolationIT`, `PartnerUniquenessIT`, `PartnerEventIT`, `ArchitectureTests` |
| Demo | Push a valid CDR, a duplicate, a conflicting duplicate, a credit, and a PII or negative-value quarantine; show one accepted row and no financial row |
| Exit | OCPI envelope, partner-scoped sender, dedupe, credit rules, quarantine isolation, outbox atomicity |

Phase 1 also adds the OpenAPI file and `OpenApiContractTest` before the first internal
endpoint. It updates the `WalkingSkeletonIT` migration count after V002. It does not rate,
invoice, post, or settle.

## 3. Phase 2 - Partners, IAM, tariffs, and CSV

| Item | Scope |
|---|---|
| Goal | Make partner scope, GST profiles, agreements, effective tariffs, and tax rates real |
| Modules | `partners`, `iam`, `tariff`; `ingestion` CSV and revalidation |
| Migrations | V005 partners GST and agreements, V006 IAM, V007 tariff |
| API | `GET/POST /partners`, `GET /partners/{partnerId}`, `PATCH /partners/{partnerId}/status`, agreement create/read/activate/terminate/link, tariff create/read/version/publish/effective, `GET/POST /tax-rates`, `POST /cdrs/import`, `POST /cdrs/{cdrId}/revalidate` |
| Events | `partners.agreement.activated.v1`, `partners.partner.updated.v1`, `tariff.tariff.published.v1`, `iam.user.role_changed.v1` |
| Required tests | `PartnerUniquenessIT`, `GstinTest`, `GstinOverlapIT`, `AgreementOverlapIT`, `AgreementActivationIT`, `AuthorizationIT`, `SuspendedPartnerIT`, `EffectiveBoundaryIT`, `VersionOverlapIT`, `TaxRateWindowIT`, `AgreementLinkIT`, `CsvImportIT` |
| Demo | Onboard a CPO and eMSP, add GSTINs, activate an agreement, publish two tariff versions, link one, and show the effective query at a boundary instant |
| Exit | Partner scope in the token, role matrix, agreement overlap rejection, effective tariff selection, tax rates effective-dated |

IAM provisioning and role assignment are public commands inside the module; 08 does not
define a human user CRUD endpoint in T1. A partner token is still required for every
`/api/v1` request except health.

## 4. Phase 3 - Rating

| Item | Scope |
|---|---|
| Goal | Produce deterministic, immutable pricing for each accepted CDR and a visible variance |
| Modules | `rating` |
| Migrations | V008 rating |
| API | `POST /rating-runs`, `GET /rating-runs/{runId}`, `GET /rating-runs/{runId}/results`, `GET /rating-results/{resultId}` |
| Events | `rating.rating.completed.v1`, `rating.rating.failed.v1` |
| Required tests | `RatingGoldenIT`, `RatingDeterminismIT`, `SessionStartTariffIT`, `RatingConcurrencyIT`, `CreditRatingIT`, `RatingFailureIT`, `MixedRunIT`, simulator determinism |
| Demo | Rate a session after a tariff publish; show the session-start version, the worked example, a credit reversal, and one missing-tariff failure without aborting the run |
| Exit | Per-line HALF_UP, deterministic input hash, one active result, variance recorded, no invoice or journal |

Phase 3 must not use run time for tariff selection and must not mutate a prior result. A
re-rate supersedes in the same transaction.

## 5. Phase 4 - Ledger

| Item | Scope |
|---|---|
| Goal | A balanced, append-only double-entry book with periods, reversals, and trial balance |
| Modules | `ledger` only; it imports `shared` |
| Migrations | V009 ledger, V010 chart seed |
| API | `GET /ledger/trial-balance`, `GET /ledger/journal-entries`, `GET /ledger/journal-entries/{entryId}`, `GET /accounting-periods`, `POST /accounting-periods/{periodCode}/close` |
| Events | None; the caller owns the document event |
| Required tests | `JournalBalanceIT`, `JournalValidationTest`, `PostingReplayIT`, `PeriodCloseIT`, `ReversalIT`, `TrialBalanceIT`, `LedgerArchitectureTest` |
| Demo | Post a balanced journal, reject an unbalanced one at commit, reverse it, close a period, and show the trial balance sums to zero |
| Exit | Deferred balance check, append-only rows, closed-period rejection, no domain or platform import |

Phase 4 is complete before billing because invoice issue needs a synchronous posting command.
No billing code may create a journal by event.

## 6. Phase 5 - Billing and GST

| Item | Scope |
|---|---|
| Goal | Issue legally numbered GST invoices and credit notes atomically with their journals |
| Modules | `billing`; `iam` MFA and maker-checker enforcement |
| Migrations | V011 billing |
| API | `POST /invoices`, `GET /invoices`, `GET /invoices/{invoiceId}`, `POST /invoices/{invoiceId}/issue`, `POST /invoices/{invoiceId}/credit-notes`, `POST /credit-notes/{creditNoteId}/issue` |
| Events | `billing.invoice.issued.v1`, `billing.credit_note.issued.v1` |
| Required tests | `InvoiceGoldenIT`, `InvoiceImmutabilityIT`, `InvoiceNumberingIT`, `CreditNoteLimitIT`, `CreditNoteApprovalIT`, `InvoicePostingRollbackIT`, `SettlementHoldIT`, `TaxPointIT`, `TaxTimeTravelIT` |
| Demo | Create a draft from rated results, issue it with per-line tax, roll back a failed ledger period, issue a credit note, and show the original invoice unchanged |
| Exit | Per-line tax, GST data present, number only at issue, journal atomic, credit cap, hold command, e-invoice switch default off |

Phase 5 is the GST review gate. The exact B2C place-of-supply rule, IRN/QR schema, and
registration behaviour remain `[ASSUMPTION]` until tax or primary-source review confirms
them. The AATO threshold is configuration, not a code constant.

## 7. Phase 6 - Reconciliation

| Item | Scope |
|---|---|
| Goal | Match a partner statement line by line and make every difference an owned exception |
| Modules | `reconciliation` |
| Migrations | V012 reconciliation |
| API | `POST /reconciliation-runs`, `GET /reconciliation-runs/{runId}`, `GET /reconciliation-runs/{runId}/exceptions`, `POST /reconciliation-exceptions/{exceptionId}/resolve` |
| Events | `reconciliation.exception.raised.v1` |
| Required tests | `StatementReplayIT`, `MatchMatrixIT`, `CreditReconciliationIT`, `ExceptionResolutionIT`, `ReconciliationIsolationIT`, `ReconciliationEventIT` |
| Demo | Import the same statement twice, show one run; import missing and amount-mismatch lines, resolve one with a code and note, and show no source row changed |
| Exit | Source-hash idempotency, exact matching in T1, credit mismatch, exception lifecycle, no write to CDR, rating, invoice, journal, or settlement |

## 8. Phase 7 - Disputes

| Item | Scope |
|---|---|
| Goal | A case state machine with evidence metadata and an invoice-level settlement hold |
| Modules | `dispute`; `billing` hold command |
| Migrations | V013 dispute |
| API | `POST /disputes`, `GET /disputes`, `GET /disputes/{disputeId}`, `POST /disputes/{disputeId}/transitions`, `POST /disputes/{disputeId}/evidence` |
| Events | `dispute.dispute.opened.v1`, `dispute.dispute.resolved.v1` |
| Required tests | `DisputeTransitionsTest`, `EvidenceHashTest`, `DisputeHoldIT`, `DisputeTimelineIT`, `DisputeIsolationIT`, `SettlementHoldIT` |
| Demo | Open a case against an invoice, attach evidence metadata, set a hold through the billing command, resolve the case, and show the invoice total unchanged |
| Exit | Allowed and rejected transitions, evidence hash, timeline append, hold only through billing, no direct dispute read of reconciliation or settlement tables |

## 9. Phase 8 - Settlement

| Item | Scope |
|---|---|
| Goal | Net eligible documents per pair, period, and currency, with maker-checker and a reproducible statement |
| Modules | `settlement`; `ledger` posting; `billing` eligibility |
| Migrations | V014 settlement |
| API | `POST /settlement-runs`, `GET /settlement-runs/{runId}`, `POST /settlement-runs/{runId}/lock`, `POST /settlement-runs/{runId}/approve`, `GET /settlement-runs/{runId}/statement`, `GET /settlement-runs/{runId}/statement.csv` |
| Events | `settlement.settlement.completed.v1` |
| Required tests | `NettingEligibilityIT`, `NettingSignTest`, `SettlementHoldIT`, `MakerCheckerIT`, `SettlementAtomicityIT`, `SettlementUniquenessIT`, `StatementHashTest` |
| Demo | Net a set of invoices and credit notes, exclude a held invoice with a recorded exclusion, lock and approve by two users, and reproduce the statement hash |
| Exit | CPO-perspective sign, one currency, one pair, one period, journals and statement atomic, no cash movement, second completion rejected |

## 10. Phase 9 - Audit and reporting

| Item | Scope |
|---|---|
| Goal | An append-only audit chain and read-only reports that tie to the books |
| Modules | `audit`, `reporting`; all producers already emit |
| Migrations | V015 audit, V016 reporting views |
| API | `GET /audit/records`, `GET /audit/verify`, all six report endpoints, `GET /reports/audit-package` |
| Events | Consumers only; no new producer |
| Required tests | `ChainVerifierTest`, `AuditAppendOnlyIT`, `AuditChainIT`, `AuditCheckpointIT`, `ReportTotalsIT`, `ReportRangeIT`, `ViewReadOnlyIT` |
| Demo | Verify the chain, tamper one record in a copy and show the first broken sequence, run each report, and prove reporting writes nothing |
| Exit | Chain verification, checkpoint, partner scope, report totals tie to source, `rpt_*` read-only views, no domain write |

Reporting is the only module allowed to read domain tables, and only through read-only
`rpt_*` views. Audit records are written by their owning transaction, not reconstructed later.

## 11. Phase 10 - OCPI 2.3.0 and hardening

| Item | Scope |
|---|---|
| Goal | Accept OCPI 2.3.0 and the 2.3.0-ed2 invoice-reconciliation object, then harden the T1 flow |
| Modules | `ingestion` and `reconciliation` adapters; all modules for hardening |
| Migrations | V017 invoice-reconciliation link |
| API | OCPI 2.3.0 CDR receiver under `/ocpi/2.3.0`; invoice-reconciliation object operations under `/ocpi/2.3.0-ed2` |
| Events | No new product event unless an ADR adds one |
| Required tests | OCPI 2.3.0 contract, invoice-reconciliation round trip, full `CdrToSettlementFlowIT`, cross-tenant matrix, retention and replay checks |
| Demo | Push a 2.3.0 CDR, publish and remove an invoice-reconciliation link, and show no issued invoice, rating result, journal, or statement changed |
| Exit | Edition selection by path, 2.3.0 mapping, V017 link, no mutation of issued financial rows, T1 end-to-end flow green |

The OCPI invoice-reconciliation object is mutable and error-correctable by the protocol. The
adapter may create, replace, or remove that object, but it must not change an issued invoice,
rating result, or journal. That distinction is the main review point of Phase 10.

## 12. Cross-phase gates

Every phase handoff demonstrates all of the following:

| Gate | Evidence |
|---|---|
| Contract | The owning module spec and any cross-cutting doc are updated |
| OpenAPI | The contract change precedes the controller and the contract test passes |
| Migration | Forward-only, one owner, one phase, data-model map updated |
| Tests | Named tests pass; skipped tests are listed; coverage is not faked |
| Money | Exact minor units, per-line rounding, no floating point |
| Time | Injected clock, UTC instants, Asia/Kolkata business dates |
| Boundary | No cross-module internal import; legal dependency order intact |
| Security | Scope, cross-tenant 404, secret and PII handling, maker-checker where required |
| Operations | `validate`, `verify`, and the quality profile where applicable |
| Honesty | The handoff states what was not run and what remains an assumption |

A phase does not start until the previous phase's exit is recorded and its migrations are
immutable. Documentation may run ahead of code; code must not run ahead of the contract.

## 13. Named test map

| Phase | Product tests | Non-functional tests |
|---|---|---|
| 0 | `WalkingSkeletonIT` | `ArchitectureTests` |
| 1 | `OcpiCdrReceiverIT`, `CdrReplayIT`, `CdrDuplicateHashIT`, `CreditCdrIT`, `QuarantineIsolationIT` | `OutboxRollbackIT`, `IdempotencyIT`, `CrossTenantMatrixIT` |
| 2 | `PartnerUniquenessIT`, `AgreementOverlapIT`, `EffectiveBoundaryIT`, `TaxRateWindowIT` | `AuthorizationIT`, `MakerCheckerIT` |
| 3 | `RatingGoldenIT`, `SessionStartTariffIT`, `CreditRatingIT`, `MixedRunIT` | `RatingConcurrencyIT` |
| 4 | `JournalBalanceIT`, `ReversalIT`, `TrialBalanceIT`, `PeriodCloseIT` | `LedgerArchitectureTest` |
| 5 | `InvoiceGoldenIT`, `InvoiceImmutabilityIT`, `CreditNoteLimitIT`, `InvoicePostingRollbackIT` | `TaxTimeTravelIT`, `SettlementHoldIT` |
| 6 | `StatementReplayIT`, `MatchMatrixIT`, `ExceptionResolutionIT` | `ReconciliationIsolationIT` |
| 7 | `DisputeHoldIT`, `DisputeTimelineIT` | `DisputeTransitionsTest` |
| 8 | `NettingEligibilityIT`, `SettlementAtomicityIT`, `StatementHashTest` | `MakerCheckerIT`, `SettlementUniquenessIT` |
| 9 | `AuditChainIT`, `ReportTotalsIT` | `AuditAppendOnlyIT`, `ViewReadOnlyIT` |
| 10 | `CdrToSettlementFlowIT`, OCPI 2.3.0 contract | `CrossTenantMatrixIT`, retention and replay |

## 14. Deferred work

The T2 triggers are owned by 01-product-scope and are not roadmap phases:

| Deferred item | Trigger |
|---|---|
| Kafka externalization | Sustained outbox lag above 60 seconds for 7 days, or a second consumer service |
| OTel and metrics stack | A production SLO and on-call rotation exist |
| Object-store evidence | Evidence outgrows local disk or a second instance is required |
| PDF and QR invoices | A partner requires a rendered document |
| Multi-currency settlement | A signed agreement uses another settlement currency |
| Full OCPI endpoint suite | A contract requires CPO or eMSP receiver interfaces beyond CDR and invoice reconciliation |
| IRP e-invoice integration | AATO exceeds the threshold and the operator chooses direct submission |
| UBC/Beckn adapter | An official specification and onboarding path are published |
| Spring Batch | A migration or month-end job exceeds 30 minutes of paged work |
| Redis | Measured lock or cache contention cannot be solved with PostgreSQL advisory locks |

None of these items may be pulled into a phase to avoid a current blocker. A blocker is solved
inside T1 or reported as a scope conflict.

## 15. Product exit scenario

```gherkin
Scenario: Month-end from CDR to settlement
  Given an active CPO-eMSP agreement in INR with monthly settlement
  And a published tariff version effective for the session start
  When a valid OCPI CDR is ingested and rated
  And an invoice is issued with GST and a balanced journal
  And a partner statement is imported and matched
  And a dispute holds one invoice and is resolved
  And the settlement run is approved by a second user
  Then the trial balance is balanced
  And the held invoice is excluded with a recorded reason
  And the settlement statement hash is reproducible
  And every state change is present in the audit chain
```

This scenario is decomposed into `CdrToSettlementFlowIT` in Phase 10 and the phase tests
above. It is the product-level exit, not a substitute for module tests.

## 16. Risks and constraints

- One maintainer is the delivery constraint; phases are intentionally sequential.
- GST, e-invoice, and DPDP assumptions must be reviewed before Phase 5. This file does not
  make them legally settled.
- OCPI 2.3.0-ed2 is the 2026-06-18 edition; the 2.2.1 compatibility receiver remains required.
- CI must align on Java 21 and the current docs and OpenAPI paths before it is a reliable gate.
- No production deployment, backup service, or frontend is in scope for this roadmap.
- A phase estimate is not made here; the exit measure and the dependency order are the
  commitment, not a calendar.

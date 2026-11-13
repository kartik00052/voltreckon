# dispute

- **Status:** Draft
- **Owner:** VoltReckon maintainer
- **Last verified:** 2026-11-13
- **Applies to phases:** 7-10

`dispute` records a case against a generic financial subject, enforces a small state machine,
stores evidence metadata and a timeline, and asks `billing` to hold an invoice from netting.
Rules are `DISP-001`-`DISP-010`; netting eligibility is owned by
[05-financial-model.md](../05-financial-model.md).

## Purpose

Give both partners one auditable place to challenge a CDR, rating result, invoice,
reconciliation exception, or settlement, without allowing a dispute to edit a financial row.

## Scope

In scope: case lifecycle, subject reference, reason, evidence metadata, transitions, and
invoice-hold requests. Out of scope: evidence file storage, rating, invoice creation, ledger
posting, reconciliation matching, and settlement. A dispute is a workflow over existing
evidence; it is not a second source of financial truth.

## Public API

- `OpenDisputeCommand` with partner pair, subject type and ID, reason, and description.
- `TransitionDisputeCommand` with target status, actor, and reason.
- `AddEvidenceCommand` with storage key, file name, size, and content hash.
- `DisputeQuery` by ID, partner, status, or subject.
- `dispute.dispute.opened.v1` and `dispute.dispute.resolved.v1` events.

No file bytes pass through the API; only bounded metadata is stored.

## Domain model

`Dispute` has a partner pair, generic subject (`CDR`, `RATING_RESULT`, `INVOICE`,
`RECONCILIATION_EXCEPTION`, `SETTLEMENT`), status (`OPEN`, `UNDER_REVIEW`, `ACCEPTED`,
`REJECTED`, `RESOLVED`, `WITHDRAWN`, `CLOSED`), reason, description, actors, and timestamps.
`Evidence` has a type, storage key, file name, size, and hash. `DisputeEvent` is an append-only
timeline entry with from/to status, actor, reason, and time.

## Owned data

`dispute`, `dispute_evidence`, and `dispute_event` in V013. No foreign key points to a domain
table. `subject_id` is validated through the public query API only for `CDR`, `RATING_RESULT`,
and `INVOICE`; the other subject types are opaque references.

## Invariants

**DISP-001** A transition MUST follow the allowed state machine; an unknown transition MUST
fail with `INVALID_STATE_TRANSITION`. *Check:* transition matrix test.

**DISP-002** A resolved, rejected, withdrawn, or closed dispute MUST be terminal; it MUST NOT
reopen. *Check:* state-machine test.

**DISP-003** A `CDR`, `RATING_RESULT`, or `INVOICE` subject MUST be resolved through the owning
module's public query and MUST belong to the same partner pair. *Check:* subject IT.

**DISP-004** A `RECONCILIATION_EXCEPTION` or `SETTLEMENT` subject MUST be accepted as an opaque
UUID without reading the owning table; the case MUST record that the subject is unverified.
*Check:* opaque-subject IT.

**DISP-005** Opening an `INVOICE` dispute MUST call `billing`'s hold command in the same
transaction; resolving, rejecting, or withdrawing it MUST release the hold. *Check:* hold IT.

**DISP-006** A dispute MUST NOT change a CDR, rating, invoice, journal, reconciliation item, or
settlement row. *Check:* cross-module write review and rollback IT.

**DISP-007** Evidence MUST be metadata only; the database MUST NOT store file bytes, and the
size and hash MUST be present. *Check:* schema and evidence IT.

**DISP-008** Every transition and evidence addition MUST write an append-only timeline row with
actor and reason in the same transaction. *Check:* timeline IT.

**DISP-009** Opening and resolving MUST publish the catalog event in the same transaction as
the state change. *Check:* outbox IT.

**DISP-010** A partner user MUST see only its own cases; a platform administrator MUST name the
target partner and be audited. *Check:* cross-tenant IT.

## Transactions

Open locks nothing outside the new rows: it validates the subject, inserts the case, inserts
the first timeline row, calls `billing` for an invoice hold when applicable, and writes the
outbox event. A transition locks the case, validates the state machine, appends the timeline,
releases the hold on a terminal outcome, and writes the event. Evidence insertion is a separate
local transaction and never changes case status.

## Events

Producers: `dispute.dispute.opened.v1` with dispute ID, subject type, and subject ID;
`dispute.dispute.resolved.v1` with dispute ID and outcome. Consumers: `audit` and `reporting`.
Settlement does not consume these events; it reads the invoice hold through `billing`.

## Dependencies

`shared`, `platform`, `partners`, `ingestion`, `rating`, and `billing`. `dispute` MUST NOT
depend on `reconciliation`, `settlement`, `ledger`, `audit`, or `reporting`; those subjects are
opaque references.

## Configuration

| Key | Default | Purpose |
|---|---|---|
| `voltreckon.dispute.max-evidence-bytes` | `26214400` | Metadata size guardrail |
| `voltreckon.dispute.allowed-types` | catalog list | Evidence MIME allowlist |
| `voltreckon.dispute.auto-close-days` | `0` | Disabled in T1 |
| `voltreckon.dispute.timeline-retention` | legal policy | Timeline retention |

## Errors

| Code | Status | Meaning |
|---|---|---|
| `DISPUTE_NOT_FOUND` | 404 | Scoped case does not exist |
| `INVALID_STATE_TRANSITION` | 409 | State machine rejects the move |
| `SUBJECT_NOT_FOUND` | 422 | Verified subject does not exist |
| `SUBJECT_SCOPE_MISMATCH` | 422 | Subject belongs to another pair |
| `UNVERIFIED_SUBJECT` | 422 | Opaque subject needs a note |
| `EVIDENCE_TOO_LARGE` | 413 | Metadata size exceeded |
| `EVIDENCE_TYPE_REJECTED` | 415 | Type not allowed |
| `HOLD_FAILED` | 409 | Billing could not hold the invoice |

## Security

`dispute.write` opens and transitions cases; `DISPUTE_HANDLER` and `FINANCE_ADMIN` may resolve.
The actor is taken from the token, never the body. Evidence storage keys MUST be unguessable and
scoped to the partner. GSTINs, invoice amounts, and descriptions are confidential; logs carry
case ID and `partnerRef` only. Every transition is audited.

## Observability

Metrics: open cases by age, transitions, hold failures, evidence uploads, and resolution time.
Logs carry dispute ID, subject type, and status; they never carry free-text descriptions.

## Tests

| Test | Covers |
|---|---|
| `DisputeStateMachineIT` | Allowed and rejected transitions |
| `DisputeSubjectIT` | Verified and opaque subjects |
| `DisputeHoldIT` | Invoice hold set and released |
| `DisputeTimelineIT` | Append-only actor/reason rows |
| `DisputeIsolationIT` | Cross-tenant denial |
| `DisputeEventIT` | Event and state commit together |

```gherkin
Scenario: Invoice dispute holds netting
  Given an issued invoice eligible for netting
  When an invoice dispute is opened
  Then billing marks the invoice held
  And settlement excludes the invoice
  And resolving the dispute releases the hold

Scenario: Opaque settlement subject is recorded without a cross-module read
  Given a settlement ID supplied by the caller
  When a dispute is opened with subject SETTLEMENT
  Then the case is stored with UNVERIFIED_SUBJECT noted
  And no settlement table is read
```

## Phase plan

- Phase 7: V013, state machine, evidence metadata, timeline, invoice holds.
- Phase 8: settlement reads holds through billing; no dispute dependency.
- Phase 9: audit and reporting consume dispute events.

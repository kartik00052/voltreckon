# 08 — API standards

- **Status:** Draft
- **Owner:** VoltReckon maintainer
- **Last verified:** 2026-11-13
- **Applies to phases:** 0–10

The internal API is a versioned JSON REST contract under `/api/v1`. The OCPI receiver is a
separate contract under `/ocpi/<edition>` and does not use these error or pagination rules.
The machine-readable contract lives at
`backend/voltreckon-app/src/main/resources/openapi/openapi.yaml`, not in `docs/`.

## 1. Protocol conventions

**API-001** The base path MUST be `/api/v1`. A breaking change MUST use `/api/v2`.
*Check:* controller mapping review; OpenAPI contract test [ADR-0010](adr/0010-openapi-contract.md).

**API-002** Requests and responses MUST be UTF-8 JSON with `Content-Type:
application/json`. Errors MUST be `application/problem+json` [ref-23]. *Check:* contract
test.

**API-003** Instants MUST be RFC 3339 UTC strings such as `2026-11-13T08:30:00Z` [ref-24].
Business dates MUST be `YYYY-MM-DD`; no local time or offset-less timestamp is accepted.
*Check:* serialization test.

**API-004** Entity IDs MUST be UUID strings. A path ID is never a `bigserial`. *Check:*
OpenAPI schema review.

**API-005** Money MUST be `{ "amountMinor": <long>, "currency": "<ISO 4217>" }`; decimals
and currency-less numbers MUST be rejected [ref-25]. *Check:* request-validation test.

**API-006** Unknown request properties MUST be rejected for the internal API; unknown
response properties MUST be ignored by clients. OCPI keeps its own unknown-field policy.
*Check:* Jackson configuration test.

**API-007** The server MUST accept `X-Correlation-Id`, echo it, and generate one when absent.
The value MUST appear in logs and in the problem response. *Check:* correlation IT.

**API-008** Request bodies MUST be limited to 1 MiB; CSV imports to 10 MiB; OCPI payloads to
256 KiB. A larger body returns `413 PAYLOAD_TOO_LARGE`. *Check:* limit IT.

**API-009** The API MUST be stateless: no server session, no cookie authentication, no
CSRF token requirement. CORS MUST use an explicit allow-list. *Check:* security review.

**API-010** Responses MUST include `Cache-Control: no-store` for authenticated financial
data. *Check:* header test.

## 2. Authentication and scopes

**API-011** Every `/api/v1` request except the health probe MUST carry a Bearer JWT.
*Check:* security filter test.

**API-012** Human users authenticate with OIDC authorization code + PKCE; partner systems
use OAuth2 client credentials. The application MUST validate signature, issuer, audience,
expiry, and not-before. *Check:* resource-server test.

**API-013** The server MUST derive the partner scope from the `partner_id` claim and MUST NOT
accept a partner ID from a request body as authority. *Check:* cross-tenant IT.

**API-014** Scopes MUST be additive strings: `partner.read`, `partner.write`, `tariff.read`,
`tariff.write`, `cdr.read`, `cdr.write`, `rating.run`, `invoice.read`, `invoice.write`,
`invoice.issue`, `invoice.credit`, `reconciliation.run`, `reconciliation.resolve`,
`ledger.read`, `period.close`, `settlement.run`, `settlement.approve`, `dispute.write`,
`audit.read`, `report.read`, `tax.write`, `platform.admin`. *Check:* scope matrix review.

**API-015** A missing or invalid token MUST return `401 UNAUTHENTICATED`; a valid token
without the required scope MUST return `403 INSUFFICIENT_ROLE` unless returning `404` avoids
cross-tenant existence leakage. *Check:* authorization IT.

**API-016** A platform administrator MUST use `platform.admin` and an explicit target
partner on admin endpoints; the action is audited. *Check:* admin audit test.

## 3. Pagination, filtering, sorting

**API-017** List endpoints MUST use cursor pagination: `limit` 1–200 (default 50), opaque
`cursor`, and response `{ "items": [...], "nextCursor": "...", "hasMore": true }`.
*Check:* pagination contract test.

**API-018** The cursor MUST be opaque and stable for the requested sort; changing filters or
sort with an old cursor MUST return `400 INVALID_CURSOR`. *Check:* cursor IT.

**API-019** Filtering MUST use explicit query parameters with documented values; no ad-hoc
query language is accepted. *Check:* OpenAPI review.

**API-020** Date-range filters MUST be bounded: CDR and journal listings to 31 days; reports
to 366 days; a larger range returns `400 RANGE_TOO_LARGE`. *Check:* range test.

**API-021** Sorting MUST use `sort=field` or `sort=-field` with an allow-list per endpoint;
an unknown field returns `400 INVALID_SORT`. *Check:* sort test.

**API-022** A total count MUST be omitted by default. `includeTotal=true` is allowed only on
report endpoints with a capped count. *Check:* response schema review.

## 4. Idempotency

**API-023** Every state-changing `POST` that creates or changes financial data MUST require
`Idempotency-Key` (8–128 printable characters). *Check:* endpoint matrix and IT.

**API-024** The key is scoped to the authenticated partner and route. A replay with the same
key and canonical request body MUST return the original status and body with
`Idempotent-Replayed: true`. *Check:* replay IT.

**API-025** The same key with a different body MUST return `409 IDEMPOTENCY_KEY_REUSED`.
A concurrent request with the same key MUST return `409 IDEMPOTENCY_IN_PROGRESS`.
*Check:* conflict and concurrency tests.

**API-026** A response for replay MUST be stored for at least 48 hours; larger than 64 KiB
MUST be rejected as a design error, not truncated. *Check:* storage review.

**API-027** The key MUST NOT appear in a URL or a log line. *Check:* log redaction test.

## 5. Concurrency and conditional requests

**API-028** A mutable draft resource MUST expose `ETag` and a `version` field; an update MUST
accept `If-Match`. A stale value returns `412 PRECONDITION_FAILED`. *Check:* optimistic
locking IT.

**API-029** An issued or posted financial resource MUST NOT be updated. A change returns
`409 IMMUTABLE_RECORD`; the client creates a credit note, reversal, or new run.
*Check:* immutability IT.

**API-030** A state transition not allowed by the module state machine MUST return
`409 INVALID_STATE_TRANSITION` with the allowed states in `detail`. *Check:* transition
matrix test.

## 6. Errors

The problem body is:

```json
{
  "type": "urn:voltreckon:problem:VALIDATION_FAILED",
  "title": "Validation failed",
  "status": 400,
  "detail": "One or more fields are invalid.",
  "instance": "/api/v1/invoices",
  "code": "VALIDATION_FAILED",
  "traceId": "4f2c...",
  "errors": [
    { "field": "currency", "code": "INVALID_CURRENCY", "message": "Expected ISO 4217." }
  ]
}
```

**API-031** `code` MUST be stable and unique across the product; a code is never reused for
a different meaning. *Check:* error catalogue test.

**API-032** The response MUST NOT contain a stack trace, SQL, class name, secret, or another
partner's identifier. *Check:* error-leak test.

**API-033** The minimum code set is: `VALIDATION_FAILED` (400), `MALFORMED_JSON` (400),
`INVALID_CURSOR` (400), `RANGE_TOO_LARGE` (400), `UNAUTHENTICATED` (401),
`INSUFFICIENT_ROLE` (403), `RESOURCE_NOT_FOUND` (404), `METHOD_NOT_ALLOWED` (405),
`CONFLICT` (409), `IDEMPOTENCY_KEY_REUSED` (409), `IDEMPOTENCY_IN_PROGRESS` (409),
`IMMUTABLE_RECORD` (409), `PERIOD_CLOSED` (409), `INVALID_STATE_TRANSITION` (409),
`PRECONDITION_FAILED` (412), `PAYLOAD_TOO_LARGE` (413), `UNSUPPORTED_MEDIA_TYPE` (415),
`RATE_LIMITED` (429, T2), `INTERNAL_ERROR` (500), `DEPENDENCY_UNAVAILABLE` (503).
*Check:* error catalogue review.

**API-034** A cross-tenant read MUST return `404 RESOURCE_NOT_FOUND`, not `403`, to avoid
existence disclosure. *Check:* cross-tenant IT.

## 7. Endpoint catalogue

Scopes are shown in parentheses. `I` means `Idempotency-Key` is required.

### Partners and agreements

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/partners/me` | Current partner and roles (`partner.read`) |
| `GET` | `/partners` | List partners (`platform.admin`) |
| `POST` | `/partners` | Register a partner (`platform.admin`, I) |
| `GET` | `/partners/{partnerId}` | Read a partner (`partner.read` own, or admin) |
| `PATCH` | `/partners/{partnerId}/status` | Suspend/reactivate (`platform.admin`, I) |
| `POST` | `/agreements` | Create a draft agreement (`partner.write`, I) |
| `GET` | `/agreements` | List agreements (`partner.read`) |
| `GET` | `/agreements/{agreementId}` | Read an agreement (`partner.read`) |
| `POST` | `/agreements/{agreementId}/activate` | Activate (`partner.write`, I) |
| `POST` | `/agreements/{agreementId}/terminate` | Terminate with a reason (`partner.write`, I) |
| `POST` | `/agreements/{agreementId}/tariffs` | Link a tariff version (`partner.write`, I) |

### Tariffs and tax

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/tariffs` | Create a tariff identity (`tariff.write`, I) |
| `GET` | `/tariffs` | List tariffs (`tariff.read`) |
| `GET` | `/tariffs/{tariffId}` | Tariff with versions (`tariff.read`) |
| `POST` | `/tariffs/{tariffId}/versions` | Create a draft version (`tariff.write`, I) |
| `POST` | `/tariffs/{tariffId}/versions/{versionId}/publish` | Publish (`tariff.write`, I) |
| `GET` | `/tariffs/{tariffId}/versions/effective?at=` | Version effective at an instant (`tariff.read`) |
| `GET` | `/tax-rates` | List effective-dated rates (`tariff.read`) |
| `POST` | `/tax-rates` | Add a rate (`tax.write`, I) |

### CDRs and rating

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/cdrs` | Ingest one internal CDR (`cdr.write`, I) |
| `POST` | `/cdrs/import` | Import CSV (`cdr.write`, I, multipart) |
| `GET` | `/cdrs` | List/filter by pair, time, status (`cdr.read`) |
| `GET` | `/cdrs/{cdrId}` | CDR with details and issues (`cdr.read`) |
| `POST` | `/cdrs/{cdrId}/revalidate` | Revalidate a quarantined CDR (`cdr.write`, I) |
| `POST` | `/rating-runs` | Start a run (`rating.run`, I) |
| `GET` | `/rating-runs/{runId}` | Status and counts (`rating.run`) |
| `GET` | `/rating-runs/{runId}/results` | Paginated results (`rating.run`) |
| `GET` | `/rating-results/{resultId}` | Result with lines and variance (`rating.run`) |

### Billing

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/invoices` | Create a draft from rating results (`invoice.write`, I) |
| `GET` | `/invoices` | List/filter (`invoice.read`) |
| `GET` | `/invoices/{invoiceId}` | Invoice with lines and tax (`invoice.read`) |
| `POST` | `/invoices/{invoiceId}/issue` | Issue and post the journal (`invoice.issue`, I) |
| `POST` | `/invoices/{invoiceId}/credit-notes` | Create a draft credit note (`invoice.credit`, I) |
| `POST` | `/credit-notes/{creditNoteId}/issue` | Issue and post the credit note (`invoice.credit`, I) |

### Reconciliation

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/reconciliation-runs` | Start a run with a partner statement (`reconciliation.run`, I) |
| `GET` | `/reconciliation-runs/{runId}` | Summary (`reconciliation.run`) |
| `GET` | `/reconciliation-runs/{runId}/exceptions` | Exception queue (`reconciliation.run`) |
| `POST` | `/reconciliation-exceptions/{exceptionId}/resolve` | Resolve or waive (`reconciliation.resolve`, I) |

### Ledger and periods

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/ledger/trial-balance` | Per entity and period (`ledger.read`) |
| `GET` | `/ledger/journal-entries` | List with source filter (`ledger.read`) |
| `GET` | `/ledger/journal-entries/{entryId}` | Entry with lines (`ledger.read`) |
| `GET` | `/accounting-periods` | List periods (`ledger.read`) |
| `POST` | `/accounting-periods/{periodCode}/close` | Close with approval (`period.close`, I) |

### Settlement

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/settlement-runs` | Start netting (`settlement.run`, I) |
| `GET` | `/settlement-runs/{runId}` | Status and net amount (`settlement.run`) |
| `POST` | `/settlement-runs/{runId}/lock` | Freeze the run (`settlement.run`, I) |
| `POST` | `/settlement-runs/{runId}/approve` | Second-user approval (`settlement.approve`, I) |
| `GET` | `/settlement-runs/{runId}/statement` | Immutable statement (`settlement.run`) |
| `GET` | `/settlement-runs/{runId}/statement.csv` | CSV export (`settlement.run`) |

### Disputes

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/disputes` | Open a case (`dispute.write`, I) |
| `GET` | `/disputes` | List/filter (`dispute.write` own partner) |
| `GET` | `/disputes/{disputeId}` | Case, evidence, timeline (`dispute.write`) |
| `POST` | `/disputes/{disputeId}/transitions` | Advance the state machine (`dispute.write`, I) |
| `POST` | `/disputes/{disputeId}/evidence` | Attach evidence metadata (`dispute.write`, I) |

### Audit and reporting

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/audit/records` | Paginated audit records (`audit.read`) |
| `GET` | `/audit/verify?from=&to=` | Verify the hash chain (`audit.read`) |
| `GET` | `/reports/cdr-summary` | Ingestion and validation counts (`report.read`) |
| `GET` | `/reports/rating-variance` | Variance by partner/period (`report.read`) |
| `GET` | `/reports/invoice-register` | Invoices with totals (`report.read`) |
| `GET` | `/reports/exception-ageing` | Open exceptions by age (`report.read`) |
| `GET` | `/reports/settlement-register` | Settlement runs and statements (`report.read`) |
| `GET` | `/reports/audit-package` | Structured export (`report.read`) |

## 8. OCPI boundary

**API-035** OCPI endpoints MUST remain under `/ocpi/<edition>` and MUST use the OCPI
envelope, not `/api/v1` or `application/problem+json`. *Check:* OCPI contract test.

**API-036** OCPI idempotency MUST still be enforced server-side even when the header is
absent; the receiver derives a key. *Check:* OCPI replay IT.

## 9. Contract and compatibility

**API-037** The OpenAPI file MUST be updated before the controller in the same change, and a
contract test MUST compare paths, methods, status codes, and schemas [ref-28]. *Check:*
contract test.

**API-038** Additive response fields and new optional query parameters are non-breaking.
Removing a field, changing a type, changing a status code, or changing a default is
breaking and requires `/api/v2`. *Check:* contract diff review.

**API-039** A deprecated endpoint MUST return `Deprecation` and `Sunset` headers for at least
one phase before removal. *Check:* deprecation test.

## 10. Acceptance scenarios

```gherkin
Scenario: Invoice issue is idempotent
  Given a draft invoice and an Idempotency-Key
  When the issue request is sent twice
  Then the first response is 200
  And the second response is the same body with Idempotent-Replayed: true
  And exactly one journal exists

Scenario: Cross-tenant read hides existence
  Given user A in partner A and invoice B in partner B
  When user A requests invoice B
  Then the response is 404 RESOURCE_NOT_FOUND
  And it does not reveal partner B

Scenario: Stale draft update is rejected
  Given a draft with version 3
  When an update is sent with If-Match for version 2
  Then the response is 412 PRECONDITION_FAILED

Scenario: OCPI and internal errors do not mix
  Given an invalid OCPI CDR
  When it is posted to /ocpi/2.2.1/cdrs
  Then the response uses the OCPI envelope
  And it does not use application/problem+json

Scenario: Pagination is stable
  Given 120 matching invoices
  When the first page is requested with limit 50
  Then the response has nextCursor
  And the second page continues without overlap
```

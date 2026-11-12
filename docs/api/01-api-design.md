# API design

**Contract:** [openapi.yaml](openapi.yaml) (OpenAPI 3.1)
**Base path:** `/api/v1`
**Status:** design contract. No server exists yet.

---

## 1. Conventions

| Topic | Rule |
|---|---|
| Media type | `application/json`; errors use `application/problem+json` |
| Dates | RFC 3339 UTC (`2026-11-12T08:30:00Z`) |
| Local business dates | ISO `date` (`2026-11-12`) |
| Currency | ISO-4217 uppercase, 3 letters |
| Money | `{ "amountMinor": 84960, "currency": "INR" }` |
| IDs | UUID strings |
| Pagination | `limit` + `cursor`; responses include `nextCursor` |
| Filtering | Explicit query parameters; no ad-hoc query language in the MVP |
| Sorting | `sort` with an allow-list per endpoint |
| Versioning | URL path (`/v1`); breaking changes require `/v2` |
| Idempotency | `Idempotency-Key` required on financial POSTs |
| Correlation | `X-Correlation-Id` accepted and echoed; generated if absent |
| Partial success | Batch endpoints return per-item results, never a silent partial write |

---

## 2. Authentication and authorization

- OAuth2 / OIDC bearer tokens.
- Human users: authorization code + PKCE.
- Partner systems: client credentials.
- The token carries `partner_id` and `scope`. **The tenant is never taken from the request body.**
- Scopes follow `partner:{id}:{resource}.{action}`; the platform maps scopes to roles.
- Cross-partner access returns `404` to avoid existence leaks.

Example token claims:

```json
{
  "sub": "user-123",
  "iss": "https://idp.example.com",
  "aud": "voltreckon-api",
  "partner_id": "6f1c2b7e-...",
  "scope": "partner:6f1c2b7e-...:invoice.write partner:6f1c2b7e-...:cdr.write",
  "exp": 1790000000
}
```

---

## 3. Idempotency

Required on:

- `POST /cdrs`
- `POST /cdrs/import` (one key per import)
- `POST /rating-runs`
- `POST /invoices`
- `POST /invoices/{id}/issue`
- `POST /invoices/{id}/credit-notes`
- `POST /reconciliation-runs`
- `POST /settlement-runs`
- `POST /disputes`
- `POST /disputes/{id}/evidence`

Rules:

- Key is scoped to `(partner, route, key)`.
- Same key + same request hash → return the original response (including status).
- Same key + different request hash → `409 IDEMPOTENCY_KEY_REUSED`.
- Keys expire after 24–72 hours (configurable). Financial effects are permanent regardless of key expiry.
- The response includes `Idempotency-Replayed: true` when replayed (optional but useful).

---

## 4. Errors

RFC 9457 problem details:

```json
{
  "type": "/problems/cdr-duplicate",
  "title": "CDR already exists",
  "status": 409,
  "code": "CDR_DUPLICATE",
  "detail": "CDR 'abc-123' was already ingested for this partner pair.",
  "instance": "/api/v1/cdrs",
  "correlationId": "01J...",
  "errors": [
    { "field": "cdrExternalId", "code": "DUPLICATE", "message": "Already exists" }
  ]
}
```

Rules:

- Clients branch on `code`, never on `detail` text.
- No stack traces, SQL, or internal identifiers in responses.
- Validation failures use `422` with field errors; malformed JSON uses `400`.

Error catalogue (MVP): `VALIDATION_FAILED`, `AUTHENTICATION_REQUIRED`, `ACCESS_DENIED`, `NOT_FOUND`, `CONFLICT`, `IDEMPOTENCY_KEY_REUSED`, `CDR_DUPLICATE`, `CDR_INVALID`, `CDR_CREDIT_REFERENCE_INVALID`, `CDR_ALREADY_CREDITED`, `TARIFF_NOT_EFFECTIVE`, `NO_APPLICABLE_TARIFF_ELEMENT`, `AGREEMENT_NOT_FOUND`, `RATING_FAILED`, `INVOICE_ALREADY_ISSUED`, `INVOICE_IMMUTABLE`, `CREDIT_EXCEEDS_INVOICE`, `RECONCILIATION_LOCKED`, `SETTLEMENT_ALREADY_COMPLETED`, `PERIOD_CLOSED`, `DISPUTE_INVALID_TRANSITION`, `RATE_LIMITED` (Phase 2).

---

## 5. Endpoint catalogue

### 5.1 Partners

| Method | Path | Purpose | Scopes |
|---|---|---|---|
| `GET` | `/partners/me` | Current partner and roles | any authenticated |
| `GET` | `/partners` | List partners (admin) | `platform.admin` |
| `POST` | `/partners` | Register a partner (admin) | `platform.admin` |
| `GET` | `/partners/{partnerId}` | Get a partner | `platform.admin` or self |
| `PATCH` | `/partners/{partnerId}/status` | Suspend/reactivate | `platform.admin` |

### 5.2 Agreements

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/agreements` | Create a draft agreement |
| `GET` | `/agreements` | List agreements for the current partner |
| `GET` | `/agreements/{agreementId}` | Retrieve an agreement |
| `POST` | `/agreements/{agreementId}/activate` | Activate |
| `POST` | `/agreements/{agreementId}/terminate` | Terminate with a reason |
| `POST` | `/agreements/{agreementId}/tariffs` | Link a tariff version |

Agreement creation example:

```json
{
  "cpoPartnerId": "6f1c2b7e-...",
  "emspPartnerId": "9a4d...",
  "agreementRef": "ROAM-2026-001",
  "currency": "INR",
  "settlementCycle": "MONTHLY",
  "paymentTermsDays": 30,
  "billingPeriodBasis": "SESSION_START",
  "effectiveFrom": "2026-11-01",
  "effectiveTo": null
}
```

### 5.3 Tariffs

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/tariffs` | Create a tariff identity |
| `GET` | `/tariffs` | List tariffs |
| `GET` | `/tariffs/{tariffId}` | Tariff with versions |
| `POST` | `/tariffs/{tariffId}/versions` | Create a draft version |
| `POST` | `/tariffs/{tariffId}/versions/{versionId}/publish` | Publish |
| `GET` | `/tariffs/{tariffId}/versions/effective` | Version effective at `at` |

Version payload:

```json
{
  "versionNo": 3,
  "currency": "INR",
  "effectiveFrom": "2026-11-01T00:00:00Z",
  "effectiveTo": null,
  "elements": [
    {
      "elementOrder": 0,
      "components": [
        { "componentType": "ENERGY", "priceMinor": 1800, "stepSize": 1, "taxRateId": "..." }
      ],
      "restrictions": {
        "startTime": "00:00:00",
        "endTime": "23:59:59",
        "daysOfWeek": [1,2,3,4,5,6,7]
      }
    }
  ]
}
```

### 5.4 CDRs

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/cdrs` | Ingest one CDR (idempotent) |
| `POST` | `/cdrs/import` | Import a CSV (multipart, idempotent) |
| `GET` | `/cdrs` | List/filter by partner pair, time, status |
| `GET` | `/cdrs/{cdrId}` | Retrieve a CDR and validation issues |
| `POST` | `/cdrs/{cdrId}/revalidate` | Re-run validation for a quarantined CDR |

Ingest request:

```json
{
  "cdrExternalId": "CPO-2026-000123",
  "sessionExternalId": "S-9912",
  "tokenUid": "RFID-ABC",
  "startDateTime": "2026-11-01T10:00:00Z",
  "endDateTime": "2026-11-01T10:42:00Z",
  "totalEnergyWh": 40000,
  "totalTimeSeconds": 2520,
  "totalCost": { "amountMinor": 84960, "currency": "INR" },
  "credit": false,
  "creditReferenceCdrId": null,
  "source": "OCPI_JSON",
  "rawPayload": { "...": "original OCPI CDR" }
}
```

Responses:

- `201` created
- `200` duplicate (body includes `duplicateOf`)
- `422` invalid (quarantined, with issues)

### 5.5 Rating

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/rating-runs` | Start a run |
| `GET` | `/rating-runs/{runId}` | Status and counts |
| `GET` | `/rating-runs/{runId}/results` | Paginated results |
| `GET` | `/rating-results/{resultId}` | Result with lines and variance |

Run request:

```json
{
  "cpoPartnerId": "6f1c2b7e-...",
  "emspPartnerId": "9a4d...",
  "periodStart": "2026-11-01",
  "periodEnd": "2026-11-30"
}
```

### 5.6 Invoices

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/invoices` | Create a draft from rating results |
| `GET` | `/invoices` | List/filter |
| `GET` | `/invoices/{invoiceId}` | Invoice with lines and tax |
| `POST` | `/invoices/{invoiceId}/issue` | Issue and post journal |
| `POST` | `/invoices/{invoiceId}/credit-notes` | Create and issue a credit note |

Draft request:

```json
{
  "ratingResultIds": ["...", "..."],
  "periodStart": "2026-11-01",
  "periodEnd": "2026-11-30",
  "placeOfSupplyState": "KA",
  "gstinIssuer": "29ABCDE1234F1Z5",
  "gstinRecipient": "27ABCDE1234F1Z5",
  "dueDate": "2026-12-15"
}
```

### 5.7 Reconciliation

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/reconciliation-runs` | Start a run with partner invoice lines |
| `GET` | `/reconciliation-runs/{runId}` | Summary |
| `GET` | `/reconciliation-runs/{runId}/exceptions` | Exception queue |
| `POST` | `/reconciliation-exceptions/{exceptionId}/resolve` | Resolve/waive |

Run request includes `partnerInvoiceRef`, period, and lines (`invoiceLineRef`, `cdrExternalId`, `amount`).

### 5.8 Ledger and periods

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/ledger/trial-balance` | Per entity/period |
| `GET` | `/ledger/journal-entries` | List with source filter |
| `GET` | `/ledger/journal-entries/{entryId}` | Entry with lines |
| `GET` | `/accounting-periods` | List periods |
| `POST` | `/accounting-periods/{periodCode}/close` | Close (privileged) |

### 5.9 Settlement

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/settlement-runs` | Start netting |
| `GET` | `/settlement-runs/{runId}` | Status and net amount |
| `GET` | `/settlement-runs/{runId}/statement` | Immutable statement |
| `GET` | `/settlement-runs/{runId}/statement.csv` | CSV export |

### 5.10 Disputes

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/disputes` | Open a case |
| `GET` | `/disputes` | List/filter |
| `GET` | `/disputes/{disputeId}` | Case, evidence, timeline |
| `POST` | `/disputes/{disputeId}/transitions` | Advance state |
| `POST` | `/disputes/{disputeId}/evidence` | Attach evidence metadata |

Transition request:

```json
{ "toStatus": "UNDER_REVIEW", "reason": "Partner provided meter values" }
```

### 5.11 Reporting

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/reports/cdr-summary` | Ingestion/validation counts |
| `GET` | `/reports/rating-variance` | Variance by partner/period |
| `GET` | `/reports/invoice-register` | Invoice list with totals |
| `GET` | `/reports/exception-ageing` | Open exceptions by age |
| `GET` | `/reports/audit-package` | Signed export (Phase 2 signing) |

---

## 6. Pagination

Request: `?limit=50&cursor=eyJpZCI6...`

Response:

```json
{
  "items": [ ... ],
  "nextCursor": "eyJpZCI6...",
  "hasMore": true
}
```

Rules:

- `limit` default 50, max 200.
- Cursors are opaque, signed/base64-encoded, and keyed on a stable sort (`created_at`, `id`).
- No offset pagination for large tables.

---

## 7. Concurrency and conditional requests

- Mutable resources expose `ETag` and `version`.
- `PATCH` requires `If-Match`; a mismatch returns `412 Precondition Failed`.
- Financial mutations that can conflict (settlement, period close) return `409` with a retry hint.

---

## 8. Rate limiting (Phase 2)

- Per-partner and per-route limits at the edge and in the app.
- `429` with `Retry-After`.
- Idempotent retries are safe.

---

## 9. Contract testing and compatibility

- The OpenAPI file is linted in CI (for example, Redocly or Spectral) once the pipeline exists.
- Breaking changes: removing a field, changing a type, adding a required field, changing semantics.
- Additive changes are allowed within `/v1`.
- Deprecations are announced in the spec (`deprecated: true`) and the changelog.
- Provider tests validate responses against the schema.
- Consumer-driven contract tests are added when partner clients exist.

---

## 10. Request examples (curl)

The following are **target** examples; they will work once the API exists.

```bash
curl -X POST http://localhost:8080/api/v1/cdrs \
  -H "Authorization: Bearer $TOKEN" \
  -H "Idempotency-Key: $(uuidgen)" \
  -H "Content-Type: application/json" \
  -d @cdr.json
```

```bash
curl "http://localhost:8080/api/v1/cdrs?limit=20&cursor=" \
  -H "Authorization: Bearer $TOKEN"
```

PowerShell:

```powershell
$headers = @{ Authorization = "Bearer $env:TOKEN"; "Idempotency-Key" = [guid]::NewGuid().ToString() }
Invoke-RestMethod -Method Post -Uri http://localhost:8080/api/v1/cdrs `
  -Headers $headers -ContentType 'application/json' -InFile .\cdr.json
```

---

## 11. Out of scope for the MVP API

- OCPI endpoint suite (`/ocpi/2.3.0/...`) — Phase 2.
- GraphQL — not needed.
- WebSocket/live updates — polling is sufficient.
- File downloads for evidence — Phase 2 with signed URLs.
- Payment initiation — out of scope.
- Consumer endpoints — out of scope.

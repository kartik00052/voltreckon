# Security design

**Target:** OWASP ASVS Level 2 for the MVP, with Level 3 aspirations for authentication and financial integrity where practical.

**Scope:** application security for the VoltReckon service. Infrastructure hardening (host, network, managed database) is described but owned by the deployment environment.

---

## 1. Assets

| Asset | Why it matters | Impact if compromised |
|---|---|---|
| CDRs and raw payloads | Billing source of truth | Financial loss, privacy exposure |
| Issued invoices and credit notes | Tax and legal records | Compliance failure, fraud |
| Journals and trial balance | Book of record | Audited books invalid |
| Settlement statements | Cash obligations | Wrong payments, disputes |
| Partner credentials and tokens | Access to partner data | Cross-tenant breach |
| GSTINs and commercial terms | Confidential business data | Competitive and legal harm |
| Evidence files (Phase 2) | Dispute and audit proof | Integrity loss |

---

## 2. Actors and trust boundaries

| Actor | Trust | Authentication |
|---|---|---|
| Finance/ops user | Authenticated human | OIDC / OAuth2 authorization code + PKCE, JWT |
| Partner system | Authenticated machine | OAuth2 client credentials, scoped JWT |
| Administrator | High privilege, small group | OIDC + MFA + role `PLATFORM_ADMIN` |
| Anonymous | None | Rejected except health probes and API docs (configurable) |
| IRP/UBC (Phase 2) | External service | mTLS or signed requests, feature-flagged |

Trust boundaries: the public API edge, the identity provider, the database network, and object storage.

---

## 3. Threat model (STRIDE summary)

| Threat | Example | Control |
|---|---|---|
| **Spoofing** | Forged JWT, stolen client secret | Signature validation, issuer/audience checks, short expiry, secret rotation, MFA for humans |
| **Tampering** | Modified CDR or journal | Append-only tables, hashes, triggers, audit log, DB permissions |
| **Repudiation** | Partner denies sending a CDR | Authenticated ingest, idempotency record, audit event with actor and payload hash |
| **Information disclosure** | Cross-partner query, logs with PII | Partner-scoped repositories, response filtering, PII-minimised logs, encryption |
| **Denial of service** | CDR flood, huge CSV | Request size limits, rate limiting (Phase 2), bounded pagination, async processing |
| **Elevation of privilege** | User changes role or partner | Server-side authorization, role checks, no client-supplied tenant/role |
| **Injection** | SQL/JSON injection | Parameterised queries, JPA, schema validation, output encoding |
| **SSRF** | Adapter fetches attacker URL | Allow-list outbound hosts, no user-supplied URLs in MVP |
| **Supply chain** | Malicious dependency | Dependency review, pinned versions, CodeQL, SBOM (Phase 2) |
| **Insider abuse** | Admin edits invoice | Immutable issued invoices, maker-checker (Phase 2), audit |
| **Replay** | Re-sent webhook or request | Idempotency keys, timestamp + nonce, 5-minute window |

---

## 4. Authentication

### 4.1 Human users

- OIDC authorization code flow with PKCE.
- JWT validated for signature (JWKS), `iss`, `aud`, `exp`, `nbf`.
- MFA required for `PLATFORM_ADMIN` and finance approvers.
- Session lifetime short; refresh handled by the IdP; no server-side session store in the MVP.

### 4.2 Partner systems

- OAuth2 client credentials.
- Access tokens are short-lived (for example, 15 minutes) and scoped.
- Scopes include partner binding: `partner:{id}:cdr.write`, `partner:{id}:invoice.read`.
- Client secrets are hashed at rest if VoltReckon issues them; better, the IdP owns them.

### 4.3 Token claims used by the application

| Claim | Use |
|---|---|
| `sub` | User or client identity |
| `partner_id` | Tenant boundary (required for partner-scoped calls) |
| `scope` | Authorisation |
| `roles` | Coarse role checks |
| `jti` | Replay detection for sensitive flows |
| `exp`, `iat`, `iss`, `aud` | Standard validation |

**Rule:** `partner_id` is taken **only** from the validated token. A body or query parameter named `partnerId` is ignored or rejected.

---

## 5. Authorization

- Method-level checks with `@PreAuthorize` and a custom `PartnerAccess` component.
- Role matrix:

| Action | FINANCE_USER | FINANCE_ADMIN | ROAMING_MANAGER | PARTNER_API | PLATFORM_ADMIN |
|---|---|---|---|---|---|
| Ingest CDR | — | — | — | ✅ own partner | ✅ |
| Publish tariff | — | — | ✅ | — | ✅ |
| Draft/issue invoice | ✅ draft | ✅ issue/reverse | — | — | ✅ |
| Run reconciliation | ✅ | ✅ | — | — | ✅ |
| Post/adjust journal | — | ✅ | — | — | ✅ (audited) |
| Run settlement | — | ✅ | — | — | ✅ |
| Open/close dispute | ✅ | ✅ | ✅ | ✅ own | ✅ |
| Manage partners/users | — | — | — | — | ✅ |
| Read reports | ✅ own | ✅ own | ✅ own | ✅ own | ✅ all |

- Row-level enforcement: every repository method for tenant data requires a `PartnerScope`. A generic `findAll()` without scope is not exposed.
- Optional defence in depth: PostgreSQL row-level security keyed on `current_setting('app.partner_id')`. The MVP may defer RLS but must keep the schema compatible.

**Test requirement:** a parameterised test attempts cross-partner access on every partner-scoped endpoint and expects `404` (not `403`, to avoid existence leaks).

---

## 6. Input validation and API security

- JSON schema and Bean Validation at the boundary; domain invariants re-checked in the domain.
- Request body size limits (for example, 2 MB per CDR batch; CSV chunked).
- Strict content types; reject unknown fields where the contract is closed.
- Pagination bounded (max page size).
- Stable error codes; no stack traces or SQL in responses.
- `Idempotency-Key` required on financial POSTs; keys are scoped to partner + route; stored with request hash and response.
- CORS disabled by default; allow-list configured per deployment.
- Security headers: HSTS, `X-Content-Type-Options`, `Content-Security-Policy` for any served UI, `Referrer-Policy`.
- CSRF: not applicable to stateless bearer-token APIs; required if cookie sessions are added.
- OpenAPI docs disabled or protected in production.

---

## 7. Webhooks and inbound integrations

- If inbound webhooks are added (IRP/UBC/partner callbacks):
  - HMAC signature over the raw body with a per-partner secret.
  - Timestamp header; reject older than 5 minutes.
  - Nonce/`jti` replay cache with TTL.
  - Constant-time comparison.
  - Idempotent processing by event ID.
- Inbound OCPI requests use OAuth2 bearer tokens, not webhook signatures.
- Failed signature checks are logged as security events without logging the secret or payload contents.

---

## 8. Data protection

### 8.1 In transit and at rest

- TLS 1.2+ everywhere; HSTS.
- Database connections require TLS in production where supported.
- Encryption at rest at the infrastructure layer (managed database, encrypted volumes).
- Backups encrypted and access-controlled.
- Object storage private; presigned URLs short-lived (Phase 2).

### 8.2 PII and DPDP alignment

| Data | Classification | Handling |
|---|---|---|
| Driver name, phone, email | Not stored | Reject or drop at ingestion |
| Token UID | Pseudonymous identifier | Stored; access restricted |
| CDR ID, session ID | Operational | Stored; partner-scoped |
| GSTIN | Business identifier | Stored; not personal data in most cases |
| Evidence files | May contain personal data | Phase 2; private storage, retention, access log |
| Logs | Must not contain PII | Structured logging with allow-listed fields |

Retention: configurable per data class; statutory retention for financial records; anonymisation job for expired operational data where legally permitted.

### 8.3 Secrets

- No secrets in the repository, tests, logs, or error messages.
- Environment variables or a secret manager; rotation documented.
- Database credentials least-privilege: application user cannot alter schema; migration user separate.
- `.env` is gitignored; `.env.example` contains only local defaults.

---

## 9. Audit logging

Every financial action writes an `audit_log` row:

| Field | Content |
|---|---|
| `id` | ULID |
| `occurred_at` | UTC timestamp |
| `actor_type` | `USER`, `PARTNER_API`, `SYSTEM` |
| `actor_id` | Subject identifier |
| `partner_id` | Tenant |
| `action` | Stable code (for example, `INVOICE_ISSUED`) |
| `entity_type`, `entity_id` | Target |
| `correlation_id` | Request/run trace |
| `before_hash`, `after_hash` | SHA-256 of canonical JSON |
| `detail` | Minimal, non-PII JSON |

Rules: append-only (no update/delete grants for the app user), shipped to external storage in production (Phase 2), and rotated/partitioned by month.

---

## 10. Database security

- Separate roles: `voltreckon_app` (DML on owned tables), `voltreckon_migrator` (DDL), `voltreckon_readonly` (reporting).
- No application superuser.
- `ledger`, `cdr`, `invoice` immutability enforced by triggers and by withholding `UPDATE`/`DELETE` grants where feasible.
- Row-level security optional; if enabled, set `app.partner_id` per transaction.
- Connection pool bounded; statements have timeouts.
- Audit of DDL changes via migration history and deployment records.

---

## 11. Logging and monitoring security events

Log (without sensitive payloads):

- Authentication failures and token validation errors.
- Authorization denials.
- Idempotency conflicts on financial endpoints.
- Cross-partner access attempts.
- Webhook signature failures.
- Administrative actions (role change, partner suspension).
- Period reopen and journal reversal.

Alert on spikes and on any successful `PLATFORM_ADMIN` write to financial data.

---

## 12. Secure development lifecycle

- Dependency review and CodeQL on every pull request.
- Pinned dependency versions; renovate/dependabot proposals reviewed.
- No secrets in code; scanning in CI (Phase 2: gitleaks).
- Threat model reviewed when a new external integration is added.
- Security tests: cross-tenant access, idempotency replay, JWT tampering, SQL injection attempts on free-text fields.
- Dependency disclosure policy in [SECURITY.md](../../SECURITY.md).

---

## 13. Incident response (summary)

1. Detect (alert, report, audit anomaly).
2. Contain (revoke credentials, disable partner, block route).
3. Assess (scope, data involved, DPDP notification need).
4. Eradicate and recover (patch, restore from backup if integrity is affected).
5. Notify per policy and law.
6. Post-incident review with a written record.

Full operational steps: [runbook](../operations/01-runbook.md).

---

## 14. Residual risks accepted in the MVP

| Risk | Why accepted | Mitigation |
|---|---|---|
| No mTLS for partner APIs | OAuth2 bearer is sufficient for MVP; mTLS adds onboarding friction | Phase 2 option per partner |
| No rate limiting | Low initial volume; infrastructure can rate-limit | Add at edge and app in Phase 2 |
| No field-level encryption | Database/infra encryption covers at-rest; PII minimised | Revisit if evidence files store personal data |
| No maker-checker | Single-team MVP; audit log present | Phase 2 for invoice issue and journal reversal |
| RLS deferred | Application scoping + tests | Enable in Phase 2 as defence in depth |

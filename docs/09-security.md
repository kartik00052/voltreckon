# 09 — Security

- **Status:** Draft
- **Owner:** VoltReckon maintainer
- **Last verified:** 2026-11-13
- **Applies to phases:** 0–10

Security protects partner data, financial records, tax documents, and settlement
obligations. The target is OWASP ASVS Level 2 for T1 [ref-26]. Controls are enforced in
code, tests, and operations; a control that exists only in prose is not a control.

## 1. Assets and trust boundaries

| Asset | Why it matters | Primary controls |
|---|---|---|
| CDRs and token references | Billing source and pseudonymous data | Partner scope, validation, bounded payload, PII rejection |
| Issued invoices and credit notes | Tax and legal records | Immutability, maker-checker where required, audit |
| Journals and trial balance | Book of record | Append-only, deferred balance, period lock |
| Settlement statements | Cash obligations | Maker-checker, hash, immutable statement |
| Partner credentials | Access to partner data | OAuth2, short tokens, secret rotation, no repo secrets |
| GSTINs and agreements | Confidential commercial data | Partner scope, least privilege, audit |
| Audit chain | Proof of actions | Append-only, hash chain, restricted read |

Trust boundaries: browser to API, partner system to OCPI receiver, API to PostgreSQL, API to
the identity provider, and (T2) API to IRP or evidence storage.

## 2. Authentication

**SEC-001** Human users MUST authenticate with OIDC authorization code + PKCE. The
application MUST NOT store passwords. *Check:* security configuration review; login IT.

**SEC-002** Partner systems MUST authenticate with OAuth2 client credentials and a
short-lived JWT. A partner token MUST NOT be usable for a human console action.
*Check:* token-type matrix test.

**SEC-003** The resource server MUST validate signature, issuer, audience, expiry, and
not-before on every request. It MUST reject `alg=none` and unknown keys. *Check:* JWT test
suite.

**SEC-004** Access tokens MUST be short-lived: 15 minutes for humans and 5 minutes for
partner clients. Refresh is handled by the identity provider, not by a custom endpoint.
*Check:* token configuration review.

**SEC-005** `PLATFORM_ADMIN` and `FINANCE_ADMIN` MUST use MFA at the identity provider.
*Check:* IdP configuration review; local profile is exempt only for development.

**SEC-006** The application MUST use the `sub` claim as the actor identity and MUST NOT
trust a display name, email, or role supplied in a request body. *Check:* authorization IT.

**SEC-007** A failed authentication MUST return `401` without revealing whether the user,
partner, or token exists. *Check:* error-leak test.

## 3. Authorization and roles

Roles are `FINANCE_USER`, `FINANCE_ADMIN`, `ROAMING_MANAGER`, `DISPUTE_HANDLER`,
`SETTLEMENT_OPERATOR`, `AUDITOR`, `PLATFORM_ADMIN`, and `PARTNER_API`.

| Action | Allowed roles |
|---|---|
| Ingest or revalidate a CDR | `PARTNER_API`, `FINANCE_USER`, `FINANCE_ADMIN` |
| Publish or retire a tariff | `ROAMING_MANAGER`, `FINANCE_ADMIN` |
| Create a draft invoice | `FINANCE_USER`, `FINANCE_ADMIN` |
| Issue an invoice or credit note | `FINANCE_ADMIN` |
| Run rating | `FINANCE_USER`, `FINANCE_ADMIN` |
| Run reconciliation; resolve an exception | `FINANCE_USER`, `FINANCE_ADMIN` |
| Post a manual journal adjustment | `FINANCE_ADMIN` (maker-checker) |
| Close an accounting period | `FINANCE_ADMIN` (maker-checker) |
| Run settlement | `SETTLEMENT_OPERATOR`, `FINANCE_ADMIN` |
| Approve settlement | `SETTLEMENT_OPERATOR`, `FINANCE_ADMIN` (different user) |
| Open or transition a dispute | `DISPUTE_HANDLER`, `FINANCE_USER` |
| Read audit or reports | `AUDITOR`, `FINANCE_ADMIN`, `PLATFORM_ADMIN` |
| Manage partners and users | `PLATFORM_ADMIN` |

**SEC-008** Authorization MUST be enforced server-side on every endpoint using both the
required scope and the role check. A UI-only check is not authorization. *Check:* endpoint
authorization matrix test.

**SEC-009** `AUDITOR` MUST be read-only for financial data. *Check:* role test.

**SEC-010** `PLATFORM_ADMIN` MUST NOT issue invoices, post journals, or approve settlements
unless separately granted a finance role in the target partner. *Check:* separation-of-duties
test.

**SEC-011** A user MUST belong to exactly one partner unless they are a platform
administrator. A platform-administration request MUST name its target partner and be
audited. *Check:* user/partner constraint; admin audit test.

## 4. Partner scope and tenant isolation

**SEC-012** Every repository query for partner-owned data MUST take a partner scope and MUST
filter in SQL. A `findById` without a scope is forbidden. *Check:* repository review;
cross-tenant IT.

**SEC-013** A client-supplied `partner_id`, `country_code`, or `party_id` MUST NOT override
the token scope. *Check:* mass-assignment test.

**SEC-014** A cross-tenant read MUST return `404 RESOURCE_NOT_FOUND`; a cross-tenant write
MUST return `404` or `403` without revealing existence. *Check:* cross-tenant IT.

**SEC-015** Database row-level security is a T2 defence-in-depth option, not a substitute for
application scoping in T1. *Check:* architecture review.

**SEC-016** A partner suspension MUST take effect at the next request; cached authorisation
MUST NOT outlive the token. *Check:* suspension IT.

## 5. Maker-checker and financial controls

**SEC-017** Settlement approval, period close, and manual journal adjustment MUST require two
distinct `sub` values: a maker and a checker. The checker MUST NOT be the maker.
*Check:* maker-checker IT.

**SEC-018** A maker-checker approval MUST be recorded with both actor IDs, the target entity,
the action, and the time in the audit chain. *Check:* audit test.

**SEC-019** A credit note above the configured threshold SHOULD require a second approver;
the threshold is configuration. *Check:* threshold review.

**SEC-020** An issued invoice, posted journal, or completed statement MUST NOT be editable by
any role, including `PLATFORM_ADMIN`. *Check:* immutability IT.

## 6. Input and API security

**SEC-021** Every request body MUST be schema-validated; string lengths, enum values, UUID
formats, currency codes, and numeric bounds MUST be enforced at the boundary.
*Check:* validation test.

**SEC-022** SQL MUST be parameterised or generated by the persistence provider; string
concatenation into SQL is forbidden. *Check:* code review; injection test.

**SEC-023** Jackson MUST NOT enable default typing or polymorphic deserialization from an
untrusted field. *Check:* configuration review.

**SEC-024** Outbound URLs MUST NOT come from a user request. An IRP or evidence-store client
MUST use an allow-listed host. *Check:* SSRF review.

**SEC-025** CSV exports MUST neutralise formula-leading cells to prevent spreadsheet
injection. *Check:* export test.

**SEC-026** File uploads in T1 are evidence metadata only; file content is T2 and MUST be
type-checked, size-limited, hashed, and stored outside the database. *Check:* phase review.

**SEC-027** CORS MUST use an explicit origin allow-list; wildcard origins with credentials are
forbidden. Security headers MUST include HSTS, `X-Content-Type-Options: nosniff`,
`X-Frame-Options: DENY`, and a restrictive Content-Security-Policy for any HTML surface.
*Check:* header test.

**SEC-028** Rate limiting is T2; T1 MUST still enforce body-size limits, bounded pagination,
and statement timeouts. *Check:* limit tests.

## 7. Data protection and DPDP

**SEC-029** Data MUST be classified as public, internal, confidential, or personal. Personal
data includes token UIDs in context, user display names, and dispute evidence.
*Check:* data inventory review.

**SEC-030** The application MUST NOT store driver names, phone numbers, email addresses, raw
identity documents, card data, or bank credentials. A token UID is stored only as a
pseudonymous contract reference. *Check:* PII scan test.

**SEC-031** Personal data MUST be minimised, purpose-limited, and retained only for the
billing, dispute, or legal purpose. An erasure request MUST NOT delete a financial record
that must be retained. *Check:* retention review; DPDP process review.

**SEC-032** Data in transit MUST use TLS 1.2 or newer. Data at rest MUST use encrypted
volumes and encrypted backups. *Check:* deployment review.

**SEC-033** Logs, traces, problem details, and audit details MUST NOT contain tokens, names,
phone numbers, card data, or bank credentials. *Check:* redaction test.

**SEC-034** A partner or processor handling personal data MUST have a written data-processing
term. *Check:* onboarding checklist.

**SEC-035** A suspected personal-data breach MUST follow the incident process, with
containment, evidence preservation, and notification by the maintainer. *Check:* tabletop
before Phase 9.

## 8. Audit and logging

Audit records use `audit_log` and are separate from application logs. The audit action is a
stable code such as `INVOICE_ISSUED`, `JOURNAL_POSTED`, `SETTLEMENT_APPROVED`,
`PERIOD_CLOSED`, `ROLE_CHANGED`, or `PARTNER_SUSPENDED`.

**SEC-036** Every state-changing financial action, role change, partner status change, period
close, export, and cross-tenant denial MUST create an audit record. *Check:* action/audit
matrix test.

**SEC-037** The audit record MUST contain the actor type and ID, partner reference, action,
entity type and ID, correlation ID, before/after hashes, and previous/record hash.
*Check:* audit schema and chain test.

**SEC-038** The audit chain MUST be append-only and verifiable from a checkpoint. A broken
chain MUST fail verification with the first broken sequence. *Check:* audit verification IT.

**SEC-039** Application logs MUST be structured, include `traceId` and `partnerRef` where
safe, and MUST NOT include request bodies, tokens, or secrets. *Check:* log review.

**SEC-040** Security events such as repeated `401`, `403`, `404` probing, and rate-limit
breaches (T2) MUST be alertable. *Check:* T2 monitoring review.

## 9. Secrets and database security

**SEC-041** Secrets MUST come from environment variables or a secret store. The repository
MUST NOT contain a default password, private key, client secret, or JWT signing key.
*Check:* secret scan; `git grep`.

**SEC-042** A secret MUST be rotatable without a code change; the database migration
credentials SHOULD be separate from the runtime credentials in production. *Check:*
deployment review.

**SEC-043** The runtime database user MUST NOT have DDL rights in production. Flyway runs
with a migration role. *Check:* database role review.

**SEC-044** Backups MUST be encrypted, access-controlled, and restore-tested. *Check:*
operations runbook.

**SEC-045** Security-relevant dependencies MUST be pinned and reviewed; a new runtime
dependency requires an ADR. *Check:* build review; ADR index.

## 10. Threat model summary

| Threat | Example | Control |
|---|---|---|
| Spoofing | Forged or stolen token | Signature validation, short expiry, MFA, rotation |
| Tampering | Edited invoice or journal | Append-only, triggers, audit chain |
| Repudiation | Partner denies a CDR | Authenticated ingest, idempotency record, audit |
| Information disclosure | Cross-partner read, PII in logs | Partner scope, 404, redaction, minimisation |
| Denial of service | Huge CDR or CSV | Body limits, bounded pagination, timeouts |
| Elevation of privilege | Body-supplied role or partner | Server-side roles, token claim only |
| Injection | SQL or spreadsheet formula | Parameterised SQL, CSV neutralisation |
| SSRF | User-supplied IRP URL | Allow-list, no user URLs |
| Supply chain | Malicious dependency | Pinned versions, review, CodeQL |
| Insider abuse | Admin edits an issued invoice | Immutability, separation of duties, audit |
| Replay | Re-sent invoice issue | Idempotency key, original response |

## 11. Secure development and verification

**SEC-046** Security tests MUST cover the authorization matrix, cross-tenant reads, invalid
JWT, injection, PII rejection, secret leakage, and maker-checker. *Check:* `SecurityIT`
suite.

**SEC-047** CodeQL, dependency review, and secret scanning MUST run in CI. SBOM and signed
images are T2. *Check:* workflow review; do not edit workflows in the docs task.

**SEC-048** A security finding that affects money, tax, tenant isolation, or credentials MUST
stop the phase until it is fixed or accepted in writing. *Check:* phase exit review.

## 12. ASVS mapping (T1 target: Level 2)

| ASVS area | VoltReckon control |
|---|---|
| Authentication | OIDC/OAuth2, JWT validation, MFA for admins |
| Session management | Stateless tokens, short expiry, no cookies |
| Access control | Scopes, roles, partner scope, 404 isolation |
| Validation and encoding | Schema validation, parameterised SQL, output encoding |
| Cryptography | TLS 1.2+, encrypted volumes, no custom crypto |
| Error handling | RFC 9457 without internals |
| Data protection | Classification, minimisation, retention, redaction |
| Communications | TLS, allow-listed outbound hosts |
| Business logic | State machines, maker-checker, idempotency, immutability |
| Files and resources | Metadata-only T1, T2 type/size/hash controls |

**SEC-049** A deviation from an ASVS Level 2 control MUST be recorded with its risk and
owner; “accepted” is not a substitute for a control on money or tenant isolation.
*Check:* security review.

## 13. Acceptance scenarios

```gherkin
Scenario: Cross-tenant read is invisible
  Given a user in partner A and an invoice in partner B
  When the user requests the invoice
  Then the response is 404 RESOURCE_NOT_FOUND
  And no partner B identifier appears

Scenario: Partner cannot choose its tenant
  Given a partner token for partner A
  When a request body names partner B
  Then the body value is ignored or rejected
  And the operation stays in partner A

Scenario: Maker cannot approve their own settlement
  Given a settlement run prepared by user A
  When user A approves it
  Then the request is rejected
  And the run remains locked

Scenario: Expired token is rejected
  Given an expired JWT
  When any /api/v1 request is made
  Then the response is 401 UNAUTHENTICATED

Scenario: Secret is not in the repository
  Given a clean checkout
  When a secret scan runs
  Then no password, client secret, or signing key is found
```

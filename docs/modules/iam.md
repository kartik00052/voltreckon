# iam

- **Status:** Draft
- **Owner:** VoltReckon maintainer
- **Last verified:** 2026-11-13
- **Applies to phases:** 2-10

`iam` maps an authenticated subject to a user, exactly one partner scope unless the user is a
platform administrator, and a set of roles. It authorizes every state-changing request and
makes partner suspension effective at the next request. Rules are `IAM-001`-`IAM-010`;
identity standards and the role matrix are owned by [09-security.md](../09-security.md).

## Purpose

Provide a single server-side authorization decision for human and partner clients, keep user
and role state in one module, and prevent cross-tenant access from becoming an endpoint-local
check.

## Scope

In scope: `app_user`, roles, subject mapping, partner-scope resolution, MFA policy flags,
authorization decisions, and role-change events. Out of scope: passwords, token issuance,
partner registry data, GST profiles, and financial holds. The identity provider owns
credentials and token signing.

## Public API

- `ProvisionUserCommand`, `ChangeUserStatusCommand`, `ChangeUserRolesCommand`.
- `UserQuery` and `RoleQuery` scoped to one partner or to platform administration.
- `AuthorizeCommand` returning a `Principal` with actor ID, partner scope, roles, scopes, and
  MFA state.
- `PartnerScopeQuery` for other modules that need the partner of the current actor.
- `iam.user.role_changed.v1` event.

The API never exposes `app_user` or `app_user_role` entities or repositories.

## Domain model

`User` has an immutable subject, optional partner reference, status, platform-admin flag, and
roles. `Role` is a closed enum from [09-security.md](../09-security.md). `PartnerScope` is a
value object holding the opaque partner UUID and the active/suspended status returned by the
`partners` public query. A `Principal` is an immutable authorization result.

## Owned data

`app_user` and `app_user_role` in V006. `app_user.partner_id` is a foreign key to `partner`;
the edge `iam -> partners` is recorded by
[ADR-0013](../adr/0013-iam-partner-and-billing-tariff-dependencies.md). No financial table is
owned here.

## Invariants

**IAM-001** A subject MUST be unique, case-sensitive, and immutable after provisioning.
*Check:* unique index and user IT.

**IAM-002** A user MUST belong to exactly one partner unless `is_platform_admin` is true; a
platform administrator MUST still name the target partner for a partner-scoped action.
*Check:* `app_user` check constraint and admin audit test.

**IAM-003** A role MUST come from the closed role list; an unknown role MUST be rejected, not
stored. *Check:* enum test and API validation.

**IAM-004** A client-supplied `partner_id`, role, or scope MUST NOT override the token subject
or server-side role state. *Check:* mass-assignment IT.

**IAM-005** A role change MUST write the user row, the role rows, and the outbox event in one
transaction. *Check:* role-change atomicity IT.

**IAM-006** A partner suspension MUST take effect at the next authorization decision; a
suspended partner MUST NOT perform a state-changing action. *Check:* suspension IT with a
cached principal.

**IAM-007** `PLATFORM_ADMIN` and `FINANCE_ADMIN` MUST complete MFA; a token without MFA MUST
not satisfy those roles for a financial action. *Check:* MFA claim test.

**IAM-008** A user status change MUST be audited with actor, target, reason, and correlation
ID. *Check:* audit-package test.

**IAM-009** A platform administrator MUST NOT approve a settlement unless separately granted a
finance role in the target partner. *Check:* separation-of-duties matrix.

**IAM-010** An authentication or authorization failure MUST NOT reveal whether a partner,
user, or token exists. *Check:* error-leak test.

## Transactions

Provisioning and role changes use one local transaction and the `platform` outbox. An
authorization decision is read-only, except for an optional last-seen update that MUST NOT be
in the decision's critical path. `iam` calls `partners` synchronously in the caller's
transaction for partner status; it MUST NOT read the `partner` table directly.

## Events

Producer: `iam.user.role_changed.v1` with user ID, role set, and actor ID. Consumers: `audit`
and `reporting`. No other event is defined in this phase; adding one updates the catalog in
[03-architecture.md](../03-architecture.md) first.

## Dependencies

`shared`, `platform`, and `partners` (ADR-0013). `iam` MUST NOT depend on `tariff`,
`ingestion`, `rating`, `billing`, `ledger`, `reconciliation`, `settlement`, `audit`, or
`reporting`.

## Configuration

| Key | Default | Purpose |
|---|---|---|
| `voltreckon.iam.issuer` | none | OIDC issuer |
| `voltreckon.iam.audience` | `voltreckon-api` | Required audience |
| `voltreckon.iam.subject-claim` | `sub` | Subject claim |
| `voltreckon.iam.partner-claim` | `partner_ref` | Partner scope claim fallback |
| `voltreckon.iam.mfa-claim` | `amr` | MFA evidence |
| `voltreckon.iam.cache-ttl` | `PT5M` | Principal cache maximum |

## Errors

| Code | Status | Meaning |
|---|---|---|
| `UNAUTHENTICATED` | 401 | Missing or invalid token |
| `TOKEN_EXPIRED` | 401 | Token expired |
| `INSUFFICIENT_ROLE` | 403 | Role, scope, or partner denied |
| `MFA_REQUIRED` | 403 | Role requires MFA |
| `USER_NOT_FOUND` | 404 | Scoped user does not exist |
| `PARTNER_SUSPENDED` | 403 | Partner is not active |
| `ROLE_CHANGED` | 409 | Principal changed; re-authenticate |
| `ROLE_UNKNOWN` | 400 | Role is not in the closed list |

## Security

`iam` is the only module allowed to answer "may this principal do this action?" It trusts the
identity provider only for authentication, never for a role that is not present in
`app_user_role`. Partner suspension is checked through the `partners` public query and cached
for no more than `voltreckon.iam.cache-ttl`. Tokens and claims MUST NOT be logged. The role
matrix and maker-checker rules are in [09-security.md](../09-security.md).

## Observability

Metrics: authorization decisions by result, cache hit rate, partner-suspension rejections, MFA
failures, role changes, and provisioning failures. Audit events carry the actor and target;
logs carry `traceId` and an opaque `partnerRef` only.

## Tests

| Test | Covers |
|---|---|
| `RoleMatrixIT` | Every role/action pair in 09-security |
| `PartnerSuspensionIT` | Suspension at next request |
| `MfaClaimTest` | MFA-required roles |
| `RoleChangeAtomicityIT` | User, roles, event in one transaction |
| `CrossTenantUserIT` | No partner B identifier leaks |
| `SeparationOfDutiesIT` | Admin cannot self-approve settlement |

```gherkin
Scenario: Suspended partner is denied on the next request
  Given an active user in partner A
  When partner A is suspended
  Then the next state-changing request fails with PARTNER_SUSPENDED
  And no business row is written

Scenario: Partner cannot choose another tenant
  Given a partner token for partner A
  When the request body names partner B
  Then the body partner is ignored
  And the operation stays in partner A
```

## Phase plan

- Phase 2: V006, subject mapping, roles, partner scope, authorization API.
- Phase 5: MFA and maker-checker enforcement for finance roles.
- Phase 9: audit and reporting consume role-change events; no new dependency.

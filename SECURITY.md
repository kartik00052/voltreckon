# Security policy

## Status

VoltReckon is a **documentation-only blueprint**. There is no deployed service, no application code, and no production data. This policy becomes operational when the first executable release is published.

## Supported versions

| Version | Supported |
|---|---|
| Blueprint v0.1 | Documentation only; security fixes apply to the documents |
| Application releases | None yet |

No version is currently eligible for production use.

## Reporting a vulnerability

Please **do not** open a public GitHub issue for a suspected vulnerability.

Use GitHub's private vulnerability reporting for this repository, or contact the project maintainer through the repository owner's GitHub profile. Do not send secrets, personal data, or production records in the first message.

Include, where possible:

- A description of the issue and its impact.
- The affected file, endpoint, or design.
- Reproduction steps or a proof of concept.
- Whether the issue is in documentation or in code.
- Your preferred contact method.

There is no dedicated security email address yet. This document will be updated when one exists; do not invent one.

## Response targets

These are good-faith targets, not contractual guarantees:

| Severity | Acknowledge | Triage | Fix target |
|---|---|---|---|
| Critical | 2 business days | 3 business days | 7 days |
| High | 3 business days | 5 business days | 30 days |
| Medium | 5 business days | 10 business days | 90 days |
| Low | 10 business days | Best effort | Next release |

## Scope

Relevant areas:

- Cross-partner data exposure or authorization bypass.
- Idempotency or replay flaws that could duplicate financial records.
- Ledger balancing, invoice immutability, or settlement double-counting.
- Secret exposure in the repository.
- Injection, SSRF, or unsafe deserialization in planned integrations.
- Supply-chain risks in dependencies.
- Privacy issues involving driver or partner personal data.

Out of scope for the current blueprint:

- Vulnerabilities in third-party services not controlled by this project.
- Reports requiring a running application that does not exist yet.
- Social engineering or physical attacks.
- Denial-of-service claims without a realistic impact assessment.

## Safe harbour

We will not pursue legal action against researchers who:

- Act in good faith and avoid privacy violations, data destruction, and service disruption.
- Test only against their own local deployment or documentation.
- Report findings privately and give reasonable time to remediate.
- Do not exploit a finding beyond what is needed to demonstrate it.

## Disclosure

We will coordinate disclosure with the reporter. Please allow time for a fix before publishing details. Credit will be given unless the reporter requests otherwise.

## Security design

See [docs/architecture/security-architecture.md](docs/architecture/security-architecture.md) for the threat model, authentication, tenancy, audit, and data-protection design.

Copyright (c) 2026 Kartik Sharma.

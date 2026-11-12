# Contributing to VoltReckon

VoltReckon is currently a **documentation-first blueprint**. The application is not implemented. Contributions to research, architecture, specifications, diagrams, and documentation are welcome. When code exists, this guide will expand with build and test commands.

By participating, you agree to follow the [Code of Conduct](CODE_OF_CONDUCT.md).

## Before you start

- Read the [documentation index](docs/README.md) and the [root README](README.md).
- Check [docs/reviews/principal-review.md](docs/reviews/principal-review.md) for known scope concerns.
- For a significant change, open an issue first. Architecture and financial-model changes need agreement before implementation.
- Do not describe planned features as implemented. The status table in the root README is authoritative.

## What we accept

- Corrections backed by a primary or reputable source.
- Clearer explanations, diagrams, and examples that do not invent behaviour.
- New architecture decision records (ADRs) for decisions that change boundaries, data, money, security, or integrations.
- Tests and code only when they implement an agreed milestone.

## What we reject

- Fabricated customers, benchmarks, certifications, integrations, or statistics.
- Marketing language that obscures the absence of code.
- Consumer-app, CSMS, roaming-hub, payment-processing, or tax-filing scope creep without an ADR.
- Kafka, Redis, Kubernetes, Spring Batch, microservices, event sourcing, or AI added "for scale" without measured justification.
- Secrets, credentials, personal data, or generated build output in a pull request.

## Documentation workflow

1. Create a branch with a descriptive name.
2. Make one coherent change per pull request.
3. Update all affected links. Moved files must not leave stale references.
4. If a claim is uncertain, label it as unverified or cite the source directly.
5. Run the checks below.
6. Open a pull request using the template and explain the decision, not just the edit.

## Local checks

Documentation checks that work before the application exists:

```powershell
Get-ChildItem docs -Recurse -Filter *.md | Select-String -Pattern 'TODO:|TBD:'
```

Link and OpenAPI checks are planned for CI. Until the automation exists, verify internal links manually and run:

```powershell
npx --yes @redocly/cli@latest lint docs/api/openapi.yaml --format=stylish
```

Application checks, once `backend/pom.xml` exists:

```powershell
cd backend
mvn verify
```

Do not add a build command to the README until it actually works.

## Architecture decisions

- Canonical ADRs live in [`docs/adr/`](docs/adr/).
- Use the next four-digit number. Do not renumber existing ADRs.
- An ADR must state: context, decision, alternatives considered, consequences, and revisit triggers.
- Superseding a decision means adding a new ADR and marking the old one as superseded; do not rewrite history silently.

## Financial changes

Any change that affects money, tax, rating, invoicing, reconciliation, ledger postings, or settlement must include:

- The invariant being preserved or changed.
- Rounding and currency behaviour.
- Idempotency and concurrency behaviour.
- Tests for balancing, duplicate handling, and reversal.
- An ADR if the model or boundary changes.

## Style

- Use clear, direct language. Prefer short sentences.
- Use ISO dates (`2026-11-12`) and UTC timestamps in technical examples.
- Use `₹` only in prose where appropriate; code and data use ISO-4217 currency codes and minor units.
- Mermaid diagrams must render on GitHub.
- Do not add emojis unless the repository explicitly adopts them.
- Do not add a copyright header to every file; the root [LICENSE](LICENSE) covers the project.

## Security

Do not report vulnerabilities in a public issue. Follow [SECURITY.md](SECURITY.md).

## License

By contributing, you agree that your contribution is licensed under the [MIT License](LICENSE).

Copyright (c) 2026 Kartik Sharma.

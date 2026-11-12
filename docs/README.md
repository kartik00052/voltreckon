# VoltReckon documentation

This directory is the engineering and research record for VoltReckon. It is written to be read in order by a new contributor and used as a reference by an implementer.

**Documentation status:** blueprint v0.1 (November 2026). The application is not implemented. Every "Planned" label in the root README refers to work described here, not to shipped code.

**License:** MIT, copyright © 2026 Kartik Sharma. See [LICENSE](../LICENSE).

## Start here

| If you want to... | Read |
|---|---|
| Understand whether the project is worth building | [Executive assessment](00-executive-assessment.md) |
| See the evidence behind the problem | [Industry analysis](research/industry-analysis.md) |
| Understand the Indian market and UBC | [India EV ecosystem](research/india-ev-ecosystem.md) |
| Know who else solves this | [Competitor analysis](research/competitor-analysis.md) |
| Check standards and tax claims | [Standards research](research/standards-research.md) |
| Review the system boundary | [System context](architecture/system-context.md) |
| Review the architecture | [Architecture overview](architecture/architecture-overview.md) |
| See the module boundaries | [Module boundaries](architecture/module-boundaries.md) |
| Read the database design | [Database design](architecture/database-design.md) and [schema.sql](database/schema.sql) |
| Understand money and ledger rules | [Financial domain design](database/02-financial-model.md) |
| Review security | [Security architecture](architecture/security-architecture.md) |
| Review deployment and operations | [Deployment architecture](architecture/deployment-architecture.md) |
| Use the API contract | [API design](api/01-api-design.md) and [openapi.yaml](api/openapi.yaml) |
| Plan the build | [Implementation roadmap](roadmap/01-implementation-roadmap.md) |
| Create GitHub issues | [Milestone and issue breakdown](roadmap/02-issues.md) |
| Learn the required topics | [Resource library](research/resource-library.md) |
| Operate the system | [Runbook](operations/01-runbook.md) |
| Read the hard criticism | [Principal engineer review](reviews/principal-review.md) |

## Research

| Document | Contents |
|---|---|
| [industry-analysis.md](research/industry-analysis.md) | Global charging ecosystem, CPO/eMSP economics, failure modes, existing approaches, opportunity, sources |
| [india-ev-ecosystem.md](research/india-ev-ecosystem.md) | Indian market, CPO/eMSP models, UEI/UBC, payments, GST/e-invoicing, data flows |
| [competitor-analysis.md](research/competitor-analysis.md) | Roaming hubs, CPMS vendors, Indian platforms, accounting software, capability matrix, positioning |
| [standards-research.md](research/standards-research.md) | OCPI/OCPP/UBC/Beckn, GST, e-invoicing, DPDP, retention, implementation impact |
| [resource-library.md](research/resource-library.md) | 24-category learning library, verified URLs, open-source projects to study |

## Architecture

| Document | Contents |
|---|---|
| [system-context.md](architecture/system-context.md) | Actors, external systems, scope, trust boundaries, C4 Level 1, key data flows |
| [architecture-overview.md](architecture/architecture-overview.md) | Style selection, module map, dependency rules, component and workflow diagrams, transactions, events |
| [module-boundaries.md](architecture/module-boundaries.md) | Module responsibilities, owned data, use cases, events, invariants, failure modes, tests; evaluated non-modules |
| [database-design.md](architecture/database-design.md) | Database selection, ER overview, table rationale, indexes, concurrency, isolation, migrations, financial integrity |
| [security-architecture.md](architecture/security-architecture.md) | Authn/authz, tenancy, webhooks, audit, PII/DPDP, threat model, residual risks |
| [deployment-architecture.md](architecture/deployment-architecture.md) | Local/production topology, packaging, configuration, migrations, CI/CD, observability, backups, DR |
| [reliability.md](architecture/reliability.md) | Failure scenarios, retries, idempotency, outbox, recovery, monitoring |
| [decisions.md](architecture/decisions.md) | Decision summary and links to ADRs |
| [diagrams.md](architecture/diagrams.md) | Additional C4, module, workflow, ER, event, and deployment diagrams |

## Data, finance, and API

| Document | Contents |
|---|---|
| [database/schema.sql](database/schema.sql) | Reference PostgreSQL 18 DDL for the MVP; not yet executed |
| [database/02-financial-model.md](database/02-financial-model.md) | Double-entry model, money representation, rounding, tax, netting, invariants |
| [api/01-api-design.md](api/01-api-design.md) | Endpoint catalogue, examples, validation, errors, idempotency |
| [api/openapi.yaml](api/openapi.yaml) | OpenAPI 3.1 MVP contract |

## Delivery and operations

| Document | Contents |
|---|---|
| [testing/01-strategy.md](testing/01-strategy.md) | Test pyramid, tooling, edge cases, CI split, quality goals |
| [roadmap/01-implementation-roadmap.md](roadmap/01-implementation-roadmap.md) | Milestones for one developer, with definitions of done |
| [roadmap/02-issues.md](roadmap/02-issues.md) | Ready-to-create GitHub issues per milestone |
| [operations/01-runbook.md](operations/01-runbook.md) | Local operations, backup, migration, incident procedures |
| [reviews/principal-review.md](reviews/principal-review.md) | Skeptical review, scope cuts, sign-off conditions |

## ADRs

Architecture decision records live in [adr/](adr/). Each ADR states context, decision, alternatives, consequences, and revisit triggers.

- [0001 — Architecture style](adr/0001-architecture-style.md)
- [0002 — Database strategy](adr/0002-database-strategy.md)
- [0003 — Financial model](adr/0003-financial-model.md)
- [0004 — Messaging strategy](adr/0004-messaging-strategy.md)
- [0005 — OCPI 2.3.0 CDR + Invoice Reconciliation scope](adr/0005-ocpi-scope.md)
- [0006 — No AI in financial decisions](adr/0006-ai-deferred.md)
- [0007 — Complement UBC/UEI, do not rebuild them](adr/0007-ubc-positioning.md)
- [0008 — Redis and Spring Batch deferred](adr/0008-defer-redis-batch.md)

## Conventions

- **Fact vs. inference:** standards and regulatory claims cite an official or reputable source. Market claims are labelled as vendor-reported or secondary reporting where appropriate.
- **No invented integrations:** if an interface is not publicly documented (for example, UBC onboarding), the document says so and treats it as Phase 2.
- **No fake status:** diagrams and tables describe the intended implementation. The status table in the root README is authoritative.
- **Links:** every URL in the resource library was checked on 12 November 2026. Re-check before citing in a new context. The library records rejected URLs.
- **Copyright:** the project is MIT-licensed under `Copyright (c) 2026 Kartik Sharma`. Individual documents do not repeat a copyright header.

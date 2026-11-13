# VoltReckon documentation

- **Status:** Draft
- **Owner:** VoltReckon maintainer
- **Last verified:** 2026-11-13
- **Applies to phases:** 0–10

This folder is the contract for building the VoltReckon backend. Code implements these
documents; the documents do not describe aspirational code. If code and docs disagree,
the human prompt wins, then an ADR, then a module spec, then other docs. Stop and report
the conflict instead of silently choosing.

## Reading order

1. [01-product-scope.md](01-product-scope.md) — who this is for and what is in each tier.
2. [02-glossary.md](02-glossary.md) — vocabulary used by every other file.
3. [03-architecture.md](03-architecture.md) — module graph, layering, transactions, events.
4. [04-data-model.md](04-data-model.md) — tables, constraints, migration order.
5. [05-financial-model.md](05-financial-model.md) — accounts, postings, rounding, proofs.
6. [06-ocpi-integration.md](06-ocpi-integration.md) — OCPI fields and ingestion rules.
7. [07-gst-and-compliance.md](07-gst-and-compliance.md) — GST, e-invoice, DPDP.
8. [08-api-standards.md](08-api-standards.md) — REST contract, errors, idempotency.
9. [09-security.md](09-security.md) — authn/authz, maker-checker, threats.
10. [10-testing-strategy.md](10-testing-strategy.md) — what proves each rule.
11. [11-simulator-and-data.md](11-simulator-and-data.md) — synthetic data and faults.
12. [12-engineering-standards.md](12-engineering-standards.md) — Java/Spring conventions.
13. [13-build-and-operations.md](13-build-and-operations.md) — versions, commands, profiles.
14. [14-roadmap.md](14-roadmap.md) — phases, migrations, endpoints, exit criteria.
15. [15-agent-workflow.md](15-agent-workflow.md) — how a coding agent must operate.
16. [references.md](references.md) — every external source and what it supports.
17. [modules/](modules/) — one spec per module, same fifteen headings.
18. [adr/](adr/) — decisions that may not be reopened silently.

## Precedence

| Rank | Source | Rule |
|---|---|---|
| 1 | Current human prompt | Overrides everything for the current task. |
| 2 | Accepted ADR | A conflicting change needs a new ADR, not an edit in place. |
| 3 | Module spec | Owns that module's behaviour and allowed dependencies. |
| 4 | Other docs | Explain and link; must not contradict higher ranks. |
| 5 | `CLAUDE.md` | Session log and operational snapshot; never a decision source. |

On conflict: stop, quote both rules, propose the smallest resolution, and wait.
Money, tax, security, and module-boundary conflicts always stop.

## Status and verification legend

| Marker | Meaning |
|---|---|
| **Status: Draft** | Complete enough to build from; may change through a reviewed commit. |
| **Status: Approved** | The maintainer accepted it for the current phase. |
| **Status: Superseded** | Kept for history; a newer document or ADR wins. |
| `[ref-N]` | Claim backed by an entry in [references.md](references.md). |
| `[ASSUMPTION]` | Not verified from a primary source; cannot be the only basis of a MUST. |
| **Verified** | The rule has an automated check named in the file. |
| **Review** | The rule is checked by a named review step, not by code. |

## Normative rules

Every MUST/MUST NOT/SHOULD has a unique ID: `PREFIX-NNN`. Prefixes are owned by files.

| Prefix | Owner | Prefix | Owner |
|---|---|---|---|
| `PROD` | 01-product-scope | `GST` | 07-gst-and-compliance |
| `ARCH` | 03-architecture | `API` | 08-api-standards |
| `DATA` | 04-data-model | `SEC` | 09-security |
| `MONEY` | 05-financial-model | `TEST` | 10-testing-strategy |
| `EVENT` | 03-architecture | `SIM` | 11-simulator-and-data |
| `OCPI` | 06-ocpi-integration | `ENG` | 12-engineering-standards |
| `OPS` | 13-build-and-operations | `AGENT` | 15-agent-workflow |
| `SHARED`, `PLAT`, `IAM`, `PART`, `ING`, `TAR`, `RATE`, `LEDG`, `BILL`, `DISP`, `SETL`, `RECN`, `AUD`, `RPT` | matching module spec | `ADR` | ADRs |

Rule IDs are never reused. Deleting a rule also deletes its ID; a replacement gets a new ID.
Every rule states how it is checked in the owning file's table or text.

## Document map

| File | Answers |
|---|---|
| 01 | Which users, which tier, which success measures. |
| 02 | What a CDR, CPO, eMSP, tariff version, netting, IRN, SAC mean here. |
| 03 | Which module may call which, how transactions and events work, how IDs work. |
| 04 | Which module owns which table, column type, constraint, index, migration. |
| 05 | Which accounts, which debit/credit per event, rounding, period close, proofs. |
| 06 | Which OCPI fields are consumed, how Credit CDRs map, validation catalogue. |
| 07 | Configurable GST, SAC, place of supply, IRN rules, DPDP minimisation. |
| 08 | Paths, payloads, error codes, idempotency, pagination, authz per endpoint. |
| 09 | Roles, partner scoping, maker-checker, secrets, audit, ASVS checks. |
| 10 | Test pyramid, naming, fixtures, invariant tests, quality gates. |
| 11 | Seeded data, fault injection, scenario files, dataset licences. |
| 12 | Java/Spring conventions, forbidden list, definition of done. |
| 13 | Versions, commands, profiles, configuration keys, CI plan, runbook. |
| 14 | Phase goals, modules, migrations, endpoints, events, tests, demos, exits. |
| 15 | Agent session ritual, loop, stop conditions, commit and handoff rules. |
| modules/ | Per-module contract using the fixed fifteen headings. |
| adr/ | Irreversible or expensive decisions with alternatives and consequences. |

## How these documents change

- Behaviour change: update the owning module spec and, if a decision changes, add an ADR.
  The code, docs, and ADR change in the same commit.
- New table or column: update 04-data-model, the owning module spec, and the roadmap
  phase; the Flyway migration is the source of truth for SQL.
- New endpoint: update 08-api-standards and the module spec, then the OpenAPI file at
  `backend/voltreckon-app/src/main/resources/openapi/openapi.yaml` (not in `docs/`).
- New external fact: add it to [references.md](references.md) with URL, claim, and date.
- Typo or link fix: direct commit. Normative edits: propose first when they touch money,
  tax, security, or a module boundary.

## What is deliberately not here

No SQL DDL, no Java source, no OpenAPI YAML, no generated diagrams outside Mermaid, no
frontend guide beyond the roadmap and API contract. Machine-readable artifacts live in
the build tree so tools can validate them.

## Owner and review

The maintainer owns every file. A document becomes **Approved** only after the maintainer
accepts it. Until then, use it as a build contract but expect review comments.

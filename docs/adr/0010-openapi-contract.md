# ADR-0010 — OpenAPI contract

- **Status:** Accepted
- **Date:** 2026-11-13
- **Deciders:** VoltReckon maintainer
- **Applies to phases:** 0–10

## Context

The frontend and partner integrations need a stable HTTP contract independent of Java
annotations. Generating the contract from controllers makes accidental implementation
changes look intentional. The contract must be reviewable in a pull request and usable by
tests and client generation.

## Decision

- The OpenAPI file at
  `backend/voltreckon-app/src/main/resources/openapi/openapi.yaml` is the source of truth
  for HTTP paths, payloads, errors, and security schemes.
- Changes are contract-first: update the OpenAPI file, then the controller and tests.
- A contract test compares the implemented endpoints and schemas to the file; drift fails
  the build.
- The file is versioned with the code and is **not** placed under `docs/`.
- The contract uses `/api/v1`, RFC 9457 problem responses, and the shared page envelope.
- Generated clients are allowed; generated server stubs are not the source of truth.
- Runtime documentation may be generated for developers, but it MUST NOT override the file.

## Alternatives considered

| Alternative | Why rejected | Revisit trigger |
|---|---|---|
| Code-first with springdoc at runtime | The annotation set becomes the contract by accident; review is harder. | A tool limitation prevents contract-first testing, with an ADR. |
| Hand-written Markdown only | Not machine-checkable; clients drift. | Never; the YAML is the machine contract. |
| OpenAPI under `docs/` | Mixes build artifacts with prose and breaks the docs-only rule. | Never. |
| GraphQL | Not required by partners; adds a new protocol and tooling. | A contracted partner requires it and an ADR is accepted. |

## Consequences

- Positive: contract review happens before implementation.
- Positive: clients and tests share one schema.
- Negative: every endpoint change touches the YAML and the controller.
- Negative: the contract test needs maintenance as the API grows.
- Follow-up: add the contract test in the phase that introduces the first endpoint.

## References

- [08-api-standards.md](../08-api-standards.md)
- [ref-23]

## Review trigger

A partner requires a different protocol, the contract test cannot express a needed
constraint, or generated stubs become the chosen source of truth.

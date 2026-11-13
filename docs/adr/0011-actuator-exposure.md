# ADR-0011 — Actuator exposure

- **Status:** Accepted
- **Date:** 2026-11-13
- **Deciders:** VoltReckon maintainer
- **Applies to phases:** 0–10

## Context

Actuator endpoints expose operational data. In a financial system, metrics, environment,
beans, and heap dumps can leak configuration or personal data. The project currently exposes
`health` and `info`; there is no monitoring stack in T1. Health is required for the walking
skeleton and for local verification.

## Decision

- By default, only `/actuator/health` is exposed, including the `liveness` and `readiness`
  groups.
- `info`, `env`, `beans`, `configprops`, `heapdump`, `threaddump`, `loggers`, `metrics`, and
  `prometheus` are not exposed in T1.
- The health endpoint does not reveal database credentials or stack traces. Details are
  `never` for unauthenticated callers.
- A management port or network restriction is an operational deployment concern; the
  default remains the application port for local development.
- T2 observability may add metrics and tracing after the trigger and an ADR.

## Alternatives considered

| Alternative | Why rejected | Revisit trigger |
|---|---|---|
| Expose all endpoints | Leaks environment and internals; no operational need. | A secured management network and an ADR exist. |
| Expose Prometheus now | Adds a monitoring dependency before a production SLO exists. | T2 trigger: a production SLO and on-call rotation exist. |
| Disable Actuator | Loses health checks required by the deployable and tests. | Never; health is required. |
| Public detailed health | Leaks dependency state and versions. | A secured internal probe requires it, with an ADR. |

## Consequences

- Positive: a small attack surface and a clear health contract.
- Positive: no monitoring stack required for T1.
- Negative: no metrics or traces until T2.
- Follow-up: change `application.yml` from `health,info` to `health` and add an exposure
  test. This is a code change after the docs phase.
- Follow-up: document the probe paths in `13-build-and-operations.md`.

## References

- [13-build-and-operations.md](../13-build-and-operations.md)
- [09-security.md](../09-security.md)

## Review trigger

A production SLO, an on-call rotation, or a secured management network is introduced.

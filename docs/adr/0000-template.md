# ADR-0000 — Template

- **Status:** Template
- **Date:** 2026-11-13
- **Deciders:** VoltReckon maintainer
- **Applies to phases:** all

## Context

What forces a decision now? State the constraint, the current behaviour, and what breaks if
the decision is deferred. Link the relevant rules, module specs, and external references.

## Decision

State the decision in one paragraph, then the enforceable details as a short list. Use
`MUST`/`MUST NOT`/`SHOULD` only when the ADR itself is the owning source; otherwise point
to the rule ID that owns the requirement.

## Alternatives considered

| Alternative | Why rejected | Revisit trigger |
|---|---|---|
| Option A | Reason | Condition that would make it viable |
| Option B | Reason | Condition that would make it viable |

## Consequences

- Positive: what becomes simpler or safer.
- Negative: what becomes harder, slower, or more constrained.
- Migration: what must change in code, schema, tests, or operations.
- Follow-ups: named phase, issue, or code follow-up; no open-ended TODO.

## References

- Related ADRs, docs, and `[ref-N]` entries.

## Review trigger

A concrete event that reopens this decision: a new module, a second deployable, a measured
limit, a legal change, or a maintainer decision recorded in a new ADR. Until then, do not
reopen it silently.

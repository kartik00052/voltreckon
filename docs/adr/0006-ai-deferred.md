# ADR-0006: Keep AI out of financial decisions in the MVP

- **Status:** Accepted
- **Date:** 12 November 2026
- **Deciders:** VoltReckon maintainers

## Context

AI is often proposed for duplicate detection, reconciliation matching, anomaly detection, and dispute triage. These are attractive demos, but the domain has strict requirements:

- Financial postings must be explainable and reproducible.
- Errors are expensive and may be legally significant.
- Labelled training data is unavailable.
- Auditors need a rule they can inspect, not a model they must trust.

## Decision

- **No AI/ML in the MVP or in any write path** to invoices, ledger, settlement, or payouts.
- Use deterministic rules for duplicates, matching, variance, and tax.
- In Phase 3, AI may be added as **advisory only**:
  - Suggests matches or anomalies.
  - Outputs a proposal with provenance and confidence.
  - A human must approve before any financial effect.
  - Models cannot write to financial tables.
- Any future AI feature requires an ADR, a labelled evaluation set, a false-positive analysis, and a privacy review.

## Alternatives considered

1. **ML-based matching in the MVP.** Rejected: no data, no evaluation, and unexplainable failures.
2. **LLM-generated journal entries.** Rejected: unacceptable audit and correctness risk.
3. **Anomaly detection as a primary control.** Rejected: statistical signals are useful for triage, not for deciding money.
4. **No AI ever.** Too strong; advisory assistance can be valuable once the deterministic base exists.

## Consequences

**Positive**

- Explainable, testable financial behaviour.
- No dependency on model providers or training pipelines.
- Easier audit and partner trust.

**Negative**

- Some fuzzy matching problems are handled by tolerance rules rather than learning.
- Less "innovation" narrative; the value is correctness, not novelty.

## Revisit triggers

- A labelled dataset of real reconciliation outcomes exists.
- A specific, bounded use case shows measurable benefit with human review.
- Privacy and DPDP implications are understood and documented.

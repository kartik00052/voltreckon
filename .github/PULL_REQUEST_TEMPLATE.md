## Summary

Describe the change and the decision behind it.

## Type

- [ ] Documentation
- [ ] Research or source correction
- [ ] Architecture / ADR
- [ ] Schema or financial model
- [ ] API contract
- [ ] Application code
- [ ] CI or tooling

## Scope check

- [ ] I did not describe a planned feature as implemented.
- [ ] I updated affected links after moving or renaming files.
- [ ] I did not add secrets, personal data, or generated build output.
- [ ] Financial changes include rounding, balancing, idempotency, and reversal tests.
- [ ] A new architectural decision has an ADR.

## Validation

List the checks you ran and their results.

```text
docs-check:
openapi-lint:
mvn verify:
```

## Notes for reviewers

Anything uncertain, deliberately deferred, or requiring a decision.

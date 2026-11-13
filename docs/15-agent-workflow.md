# 15 - Agent workflow

- **Status:** Draft
- **Owner:** VoltReckon maintainer
- **Last verified:** 2026-11-13
- **Applies to phases:** 0-10

This file is the operating procedure for an agent or human contributor working in this
repository. It defines what to read, how to choose a change, when to stop, how to verify, and
what a handoff must contain. It does not replace the product, money, tax, security, module, or
API rules; it tells the contributor how to obey them. The phase order is in
[14-roadmap.md](14-roadmap.md); the docs index is in [README.md](README.md).

## 1. Precedence and reading order

**AGENT-001** Before changing code or docs, a contributor MUST read `CLAUDE.md`,
`docs/README.md`, `docs/01-product-scope.md`, `docs/03-architecture.md`, and the owning module
spec; a change that touches money, tax, security, or the API MUST also read 04, 05, 06, 07, 08,
or 09 as applicable. *Check:* handoff references.

**AGENT-002** Precedence is: human prompt, accepted ADR, module spec, other docs, `CLAUDE.md`.
A conflict MUST be reported as both rules; a conflict in money, tax, security, or a module
boundary MUST stop the change. *Check:* conflict note in the handoff.

**AGENT-003** An accepted ADR MUST NOT be reopened or silently changed; a changed decision
requires a new ADR that names the superseded one. *Check:* ADR diff.

**AGENT-004** `CLAUDE.md` is a session log and operational snapshot, never a decision source.
A statement there that contradicts an accepted ADR or module spec MUST be reported, not
copied into code. *Check:* cross-read.

## 2. Session start

**AGENT-005** A session MUST start by checking `git status --short`, the recent log, the current
branch, and the owning phase in 14-roadmap; an unexplained dirty worktree MUST be reported
before any edit. *Check:* terminal evidence.

**AGENT-006** A change MUST name its module, phase, and rule IDs before editing; if no rule
fits, the task is either a docs change or a scope conflict. *Check:* plan or handoff.

**AGENT-007** The baseline build MUST be established with `mvn -B -f backend/pom.xml validate`
and, when Docker is available, `verify`; a pre-existing failure MUST be recorded before the
change so it is not attributed to the new work. *Check:* baseline result.

**AGENT-008** Versions, paths, and test names MUST be read from the current POM and source, not
inferred from a stale README, build comment, or previous session. *Check:* source reference.

## 3. Work loop

1. Restate the request in one or two sentences and list what is out of scope.
2. Identify the owning module, phase, rules, and accepted ADRs.
3. Choose the smallest vertical slice that satisfies the rule.
4. Update the contract first: module spec, cross-cutting doc, OpenAPI, and migration map.
5. Add the migration and persistence change when data is involved.
6. Implement the domain rule, application command, adapter, and event.
7. Add the named tests and the error and security rows.
8. Run `validate`, then `verify`, then the quality profile where applicable.
9. Update `CLAUDE.md` with a factual daily-log entry.
10. Inspect the diff, stage only intended files, and stop before commit unless the prompt asks
    for a commit.

**AGENT-009** A new or changed endpoint MUST have the OpenAPI change and contract test before
the controller; a controller-first change is incomplete. *Check:* diff order.

**AGENT-010** A schema change MUST update the owning module spec and 04-data-model in the same
change; a migration without both is incomplete. *Check:* diff review.

**AGENT-011** A rule change MUST add or update a named test and the rule's `Check`; a code
change without test evidence is not complete. *Check:* test map.

**AGENT-012** A change MUST stay within one module plus its public contracts unless a
cross-module command, event, or read is explicitly documented. A broad refactor is not part of
a feature fix. *Check:* diff and dependency review.

**AGENT-013** A module MUST NOT import another module's `internal` package; a needed value MUST
be exposed through a public query or command. *Check:* `ArchitectureTests`.

**AGENT-014** A new runtime dependency, module, or T2 component MUST NOT be added without an
accepted ADR. *Check:* POM and ADR index.

**AGENT-015** An applied migration, an issued invoice, a posted journal, a rating result, a
completed statement, or an audit row MUST NOT be edited or deleted; a correction is a new row,
reversal, credit note, or new run. *Check:* trigger test and diff.

## 4. Stop conditions

**AGENT-016** A contributor MUST stop and report when any of the following occurs:

- the prompt, an accepted ADR, a module spec, and another doc disagree on money, tax, security,
  or a module boundary;
- a legal, GST, DPDP, OCPI, or e-invoice claim has no primary source and the change depends on
  the exact wording;
- a migration is destructive, edits history, or cannot be applied without rewriting an issued
  row;
- a change would add a runtime dependency, a new module, a T2 component, or an AI path in the
  financial flow without an ADR;
- a secret, token, real GSTIN, personal data, or production dump appears in the diff;
- a test cannot run because Docker, a database, or a tool is missing, and the task requires
  that evidence;
- the request conflicts with a docs-only scope, a protected file, or the user's explicit
  instruction;
- the correct behaviour is ambiguous and guessing would change a financial result.

*Check:* the handoff starts with the blocker, the conflicting rules, and the smallest safe
options.

**AGENT-017** An assumption MUST NOT be converted into a financial, tax, security, or scope
rule; it is labelled `[ASSUMPTION]` in docs and leaves the implementation blocked until
reviewed. *Check:* assumption marker and handoff.

**AGENT-018** A failed test or a missing environment MUST be reported as not verified; it MUST
NOT be hidden with a skip, a deleted assertion, or a claim that the build is green. *Check:*
test report and handoff.

## 5. Verification and evidence

**AGENT-019** A handoff MUST list the exact commands run and their result, including the
quality profile and the focused integration test where one was used. *Check:* handoff review.

**AGENT-020** A generated tree or `target/` directory MUST NOT be used as evidence of source
state; run `mvn clean` before trusting generated output after a failed or interrupted build.
*Check:* build log.

**AGENT-021** A docs change MUST be checked for the required headings, unique rule IDs,
resolving local links, resolving `[ref-N]` markers, no unresolved placeholder markers, no
non-Markdown files, and no SQL DDL. *Check:* docs validation command or review note.

**AGENT-022** A test claim MUST name the test class or condition; "tests pass" without a class,
command, or count is not evidence. *Check:* handoff.

## 6. Git and commits

**AGENT-023** A commit MUST be made only when the prompt asks for one; a successful change is
not an implicit request to commit. *Check:* prompt and git log.

**AGENT-024** Before a commit, inspect `git status`, `git diff --stat`, and the full diff; stage
only the intended files and never include a secret, a local database dump, or generated output.
*Check:* staged diff.

**AGENT-025** A commit message MUST follow the repository's conventional style and describe one
logical change; do not mix unrelated edits in one commit. *Check:* `git log`.

**AGENT-026** A failed commit or hook MUST be fixed with a new commit, not amended; force-push,
`git reset --hard`, and `--no-verify` MUST NOT be used unless the human explicitly asks for the
destructive operation. *Check:* git history.

**AGENT-027** A push MUST occur only when the prompt explicitly asks for one; the Batch 4 docs
task stops before the separate README reconciliation commit and before any push. *Check:* git
remote state.

**AGENT-028** A user's uncommitted work MUST NOT be reverted, staged, or overwritten to make a
task easier; report the conflict and work around it. *Check:* diff and status.

## 7. Handoff

**AGENT-029** A handoff MUST use this shape:

```text
Done:
- files and behaviour changed
- rule IDs and phase exit advanced

Verified:
- command and result

Not run:
- environment or scope reason

Open:
- assumptions, conflicts, follow-ups

Next:
- one concrete next step
```

*Check:* handoff review.

**AGENT-030** A handoff MUST NOT claim a rule is complete when only a scaffold, a plan, or a
generated file exists; it MUST name the executable evidence or say that the rule is planned.
*Check:* handoff review.

**AGENT-031** `CLAUDE.md` MUST receive a factual daily-log entry for a substantial session and a
current-state update when a phase or batch changes; the entry MUST NOT create a new decision or
rewrite an old one. *Check:* `CLAUDE.md` diff.

## 8. Task profiles

### Documentation-only task

- Read the current docs, module specs, ADRs, references, and build facts.
- Touch only `docs/**` and, when the task names it, `CLAUDE.md`; the final `README.md`
  reconciliation is a separate commit.
- Do not edit `backend/`, `frontend/`, `compose.yaml`, `LICENSE`, or workflows.
- Use Mermaid for diagrams, Given/When/Then for acceptance, `[ASSUMPTION]` for unverified facts,
  and no SQL DDL.
- Validate headings, rule IDs, links, references, and placeholder markers.
- Commit only when asked; do not push.

### Phase implementation

- Confirm the previous phase exit and the owning migration.
- Add the contract and OpenAPI first.
- Add one forward-only migration and update 04.
- Implement the domain, application, adapter, and event.
- Add the named tests, error rows, and security matrix row.
- Run `validate`, `verify`, and the quality profile.
- Update 14-roadmap status only when the exit is actually met.

### Bug fix

- Reproduce with a failing test that names the violated rule.
- Fix the smallest cause; do not change the rule to match the bug.
- Keep the regression test.
- Check whether an issued row, migration, or doc was affected; if so, stop and report.

### Migration

- Confirm the owning module and phase.
- Write a forward-only migration with a header.
- Backfill in bounded batches; add constraints after the data is clean.
- Update 04 and the module spec.
- Test the migration against a fresh PostgreSQL 18 database and against a copy with prior data.
- Never edit an applied file or run `clean` against a shared database.

### Security fix

- Reproduce the exposure without printing the secret.
- Fix at the trust boundary and add a regression test.
- Rotate any exposed secret outside the repository; do not commit the replacement.
- Update the security matrix and audit requirement where needed.
- Preserve evidence; do not delete audit rows.

### Review

- Read the diff, the owning rules, and the test evidence.
- Check money, time, transaction, boundary, error, and secret handling first.
- Report concrete findings with file and line; do not rewrite the change unless asked.
- Treat a rule without evidence as open, not as a style preference.

## 9. Forbidden actions

- Editing an applied migration or a financial row after issue.
- Adding a runtime dependency, module, or T2 component without an ADR.
- Adding Kafka, Redis, Spring Batch, a microservice split, or AI to the T1 financial path.
- Replacing PostgreSQL with H2 for a test.
- Staging a secret, a production dump, a real GSTIN, or personal data.
- Using `mvn` output under `target/` to infer source state.
- Reporting a test, build, or link check that was not run.
- Committing, pushing, force-pushing, or amending without the explicit request.
- Editing `README.md` outside the final reconciliation commit; editing `LICENSE`,
  workflows, or `compose.yaml` in a docs-only task.
- Commenting out code or adding a placeholder test to make the build look green.
- Hiding a conflict by choosing the convenient rule.

## 10. Acceptance scenarios

```gherkin
Scenario: Conflicting financial rules stop the work
  Given the module spec and the financial model disagree on rounding
  When the contributor starts implementing the rule
  Then the change stops before code
  And the handoff names both rules and the smallest safe options

Scenario: A docs-only task does not touch code
  Given a request to complete the documentation batch
  When the diff includes a migration or a workflow edit
  Then the diff is rejected
  And only docs and the named session log are changed

Scenario: Missing Docker is reported, not faked
  Given a change that needs a Testcontainers integration test
  When Docker is not available
  Then the handoff says the test was not run
  And it does not claim a green verify

Scenario: A commit contains only the intended change
  Given a completed phase slice
  When the contributor stages files
  Then generated output, local data, and unrelated edits are excluded
  And the commit message describes the logical change

Scenario: A secret is found in the diff
  Given a proposed commit with a token in a fixture
  When the diff is reviewed
  Then the commit stops
  And the token is removed and rotated outside the repository

Scenario: The final docs task stops before README and push
  Given Batch 4 is committed
  When the task is complete
  Then the README reconciliation remains a separate commit
  And no push is made without an explicit request
```

## 11. Current repository state

- Phase 0 is complete at `5153cc2`.
- Docs Batch 1 is `644014e`, Batch 2 is `c089207`, and Batch 3 is `2523d33`.
- Batch 4 adds this file, 10-testing-strategy, 11-simulator-and-data,
  12-engineering-standards, 13-build-and-operations, and 14-roadmap.
- `README.md` is stale and is reconciled only in the separate final docs commit.
- `LICENSE` names a different copyright holder from the current user; it is reported, not
  edited.
- The backend is a walking skeleton and scaffold; only `ArchitectureTests` and
  `WalkingSkeletonIT` have executable assertions.
- CI uses Java 25 in two workflows and Java 21 in the backend workflow; the mismatch is
  recorded, not fixed by docs.
- No production profile, backup service, release artifact, or frontend is complete.
- The repository has no authority to push from this workflow unless the human asks.

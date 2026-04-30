# FIX.md

Fix flow deltas. Shared workflow in `WORKFLOW.md`. Rules in `HARNESS.md`. Decision procedure in `DECISIONS.md`.

## 1. Flow identity

| Field | Value |
|---|---|
| Flow type | Fix |
| Skill | `flow-fix` |
| ID prefix | `FIX-` |
| Spec template | `~/.claude-wyvrn/templates/fix-spec.md` |
| Spec folder | `.claude-wyvrn-local/fixes/` |
| Spec filename | `FIX-NNNN-[slug].md` |

## 2. Initial prompt requirements

### 2.1 Prompt-gated fields

Required in the initial prompt:

- **Task title.** Short identifier for the fix.
- **Expected outcome.** What the system should do in the affected scenario.
- **Current outcome.** What the system does instead.
- **Reproduction steps or conditions.** Concrete, executable steps or conditions that reliably trigger the bug.

If any field is missing, `clarifier` halts before round 1. The flow skill invokes `AskUserQuestion` per `HARNESS.md` §8 to request the missing fields, grouping them into a single call when count ≤ 4. For free-text fields (Task title, Expected outcome, Current outcome, Reproduction steps), provide a 2-option placeholder list; the human's actual answer arrives via the auto-added "Other". Do not proceed until provided.

### 2.2 Optional fields

- Hypothesis about the root cause.
- Scope boundary: what is explicitly out of scope.
- Additional context, references, or constraints.

## 3. Clarify deltas

No deltas. See `WORKFLOW.md` §2.

## 4. Work deltas

### 4.1 Reproduction test first

Before implementing the fix:

1. Write a test that reproduces the bug using the reproduction steps or conditions from the spec.
2. Run the test. Confirm it fails in the expected way.
3. Record the failure in the spec artifact's reproduction section.

Do not proceed to the fix implementation until reproduction is confirmed. If reproduction fails (the bug does not manifest under the stated conditions), halt and file a late clarification per `HARNESS.md` §5.4.

### 4.2 Fix implementation

1. Implement the fix.
2. Run the reproduction test. Confirm it now passes.
3. Run existing tests. Confirm no regression.

Do not modify, rename, or weaken existing tests unrelated to the fix. If an existing test now fails as a consequence of the fix, this is a finding — the fix has broken legitimate behavior, or the test was encoding the bug. Log a decision record classifying which; if UNDECIDED, file a late clarification.

### 4.3 Architecture updates

Fix flows do not modify `.claude-wyvrn-local/ARCHITECTURE.md`. If a fix requires architectural change, classify as UNDECIDED — a fix that requires architectural change is likely a refactor, and the human should confirm the flow type via a clarification.

## 5. Verify deltas

### 5.1 Reproduction test verification

The `verifier`:

1. Locates the reproduction test.
2. Runs it. Confirms pass post-fix.
3. Cross-references the test against the spec's reproduction conditions. If the test does not actually exercise those conditions, this is a finding.

### 5.2 Regression check

The `verifier` runs the reproduction test plus tests in files affected by the diff, using the test runner's affected-tests mode (e.g., `jest --findRelatedTests`, `pytest --picked` or `pytest-testmon`, `go test` per touched package). If the runner does not support an affected-tests mode, fall back to the full suite and record an advisory finding noting the gap. Any test that was passing before the fix and now fails within the executed scope is a finding. Pre-existing failures unrelated to the fix are recorded as out-of-scope findings per `DECISIONS.md` §4.2.

To determine pre-existing failures, the `verifier` uses the baseline recorded in the spec artifact's reproduction section from §4.1.

## 6. Flow-specific prohibitions

6.1 Do not weaken, skip, or remove existing tests. See `CONVENTIONS.md` §2.6.

6.2 Do not expand the fix to address related-but-distinct bugs. Record them as out-of-scope findings.

6.3 Do not refactor adjacent code "while you're in there." Fix flows change what is necessary to resolve the specific bug.

6.4 Do not declare the fix complete without a passing reproduction test.

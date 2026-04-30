# FEATURE.md

Feature flow deltas. Shared workflow in `WORKFLOW.md`. Rules in `HARNESS.md`. Decision procedure in `DECISIONS.md`.

## 1. Flow identity

| Field | Value |
|---|---|
| Flow type | Feature |
| Skill | `flow-feature` |
| ID prefix | `FEAT-` |
| Spec template | `~/.claude-wyvrn/templates/feature-spec.md` |
| Spec folder | `.claude-wyvrn-local/features/` |
| Spec filename | `FEAT-NNNN-[slug].md` |

## 2. Initial prompt requirements

### 2.1 Prompt-gated fields

Required in the initial prompt:

- **Task title.** Short identifier for the feature.
- **Intent.** The user goal, problem being solved, or capability being added.

If either is missing, `clarifier` halts before round 1. The flow skill invokes `AskUserQuestion` per `HARNESS.md` §8 to request the missing fields, grouping them into a single call when count ≤ 4. For free-text fields (Task title, Intent), provide a 2-option placeholder list (e.g., suggested phrasings or `<unknown>`); the human's actual answer arrives via the auto-added "Other". Do not proceed until provided.

### 2.2 Clarify-gated fields

Required in the spec by end of Clarify. May be developed during Clarify rounds:

- **Acceptance criteria.** Each criterion stated as a pass/fail condition. Minimum one.

If the initial prompt does not supply acceptance criteria, the `clarifier` develops them during Clarify rounds in collaboration with the human.

### 2.3 Optional fields

- Scope boundary: what is explicitly out of scope.
- Additional context, references, or constraints.

## 3. Clarify deltas

No deltas. See `WORKFLOW.md` §2.

## 4. Work deltas

### 4.1 Test production

Per `CONVENTIONS.md` §2.6: each acceptance criterion requires a new test. Write the tests before declaring implementation complete.

### 4.2 Architecture updates

Feature flows do not modify `.claude-wyvrn-local/ARCHITECTURE.md` unless the feature introduces a new module, dependency, or architectural element. If modification is required, classify as INFERRED and log a decision record; do not modify ARCHITECTURE silently.

## 5. Verify deltas

### 5.1 Acceptance criteria verification

The `verifier` verifies each acceptance criterion by:

1. Locating the new test(s) written for it.
2. Running the test(s) and confirming pass.
3. Cross-checking the spec artifact's stated acceptance criterion against the test's assertion.

If the test does not actually exercise the acceptance criterion, this is a finding.

### 5.2 Test suite execution

The `verifier` runs the new tests written for the feature plus tests in files affected by the diff, using the test runner's affected-tests mode (e.g., `jest --findRelatedTests`, `pytest --picked` or `pytest-testmon`, `go test` per touched package). If the runner does not support an affected-tests mode, fall back to the full suite and record an advisory finding noting the gap. Pre-existing failures unrelated to the feature are recorded as out-of-scope findings per `DECISIONS.md` §4.2. New failures or regressions in the executed scope are findings that return the flow to Work.

## 6. Flow-specific prohibitions

6.1 Do not modify code outside the modules the feature requires. Reuse existing code by calling it; do not change it. The verifier checks for missed reuse per `WORKFLOW.md` §4.2.

6.2 Do not add scaffolding for "future features" not in the current spec.

6.3 Do not fix unrelated bugs encountered during feature implementation. Record them as out-of-scope findings in the verifier report.

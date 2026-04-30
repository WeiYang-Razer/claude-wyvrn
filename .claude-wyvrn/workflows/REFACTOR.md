# REFACTOR.md

Refactor flow deltas. Shared workflow in `WORKFLOW.md`. Rules in `HARNESS.md`. Decision procedure in `DECISIONS.md`.

## 1. Flow identity

| Field | Value |
|---|---|
| Flow type | Refactor |
| Skill | `flow-refactor` |
| ID prefix | `REF-` |
| Spec template | `~/.claude-wyvrn/templates/refactor-spec.md` |
| Spec folder | `.claude-wyvrn-local/refactors/` |
| Spec filename | `REF-NNNN-[slug].md` |

## 2. Initial prompt requirements

### 2.1 Prompt-gated fields

Required in the initial prompt:

- **Task title.** Short identifier for the refactor.
- **Target area.** Files, modules, or code regions to be refactored.
- **Preservation statement.** The behavior, interface, or invariants that must not change.

If any field is missing, `clarifier` halts before round 1. The flow skill invokes `AskUserQuestion` per `HARNESS.md` §8 to request the missing fields, grouping them into a single call when count ≤ 4. For free-text fields (Task title, Target area, Preservation statement), provide a 2-option placeholder list; the human's actual answer arrives via the auto-added "Other". Do not proceed until provided.

### 2.2 Clarify-gated fields

Required in the spec by end of Clarify. May be developed during Clarify rounds:

- **Desired shape.** The intended structure, pattern, decomposition, or renaming after the refactor.

If the initial prompt does not supply desired shape, the `clarifier` develops it during Clarify rounds in collaboration with the human.

### 2.3 Optional fields

- Scope boundary: what is explicitly out of scope.
- Rationale for the refactor.
- Additional context, references, or constraints.

## 3. Clarify deltas

No deltas. See `WORKFLOW.md` §2.

## 4. Work deltas

### 4.1 Baseline capture

First step of Work:

1. Run the full project test suite.
2. Record pass/fail status for every test in the spec artifact's baseline section.
3. Do not modify any code before baseline capture is complete.

If the test suite cannot be run (infrastructure failure, build failure, or missing test runner), halt and file a late clarification per `HARNESS.md` §5.4. Refactoring without a working test suite is not permitted.

### 4.2 Preserve behavior

The refactor must preserve the behavior, interface, and invariants named in the spec's preservation statement. No test that was passing at baseline may newly fail.

### 4.3 Preserve tests

Do not delete, rename, or weaken existing tests. Test structure changes require an INFERRED decision record; if UNDECIDED, file a late clarification.

Exception: tests that exist to assert implementation details removed by the refactor (e.g., a test asserting a private helper exists that the refactor legitimately eliminates) may be removed with a decision record. The decision record must cite the spec line authorizing the implementation removal.

### 4.4 Architecture updates

Refactor flows may modify `.claude-wyvrn-local/ARCHITECTURE.md`. When the refactor alters architectural elements (module boundaries, dependency patterns, structural decisions), update ARCHITECTURE.md as part of the flow. The template-verifier hook verifies the update matches the architecture template.

## 5. Verify deltas

### 5.1 Preservation verification

The `verifier`:

1. Runs the full project test suite.
2. Compares results to the baseline recorded in the spec artifact.
3. Any test that was passing at baseline and is now failing is a finding. This includes newly-failing tests that pre-dated the refactor.
4. Any test that was failing at baseline and is now passing is recorded as a noted-outcome in the report. It does not fail the flow, but it is surfaced.
5. Any test that is newly deleted without a decision record is a finding.

### 5.2 Desired-shape verification

The `verifier` reads the spec's desired-shape description and the refactor diff. It verifies the diff achieves the described shape. Partial or off-target implementation is a finding.

### 5.3 Architecture consistency

If ARCHITECTURE.md was updated, the `verifier` checks the update for consistency with the diff. Divergence between the updated ARCHITECTURE.md and the actual code structure is a finding.

## 6. Flow-specific prohibitions

6.1 Do not add new functionality during a refactor. Behavior-adding work is a feature flow.

6.2 Do not fix unrelated bugs during a refactor. Record them as out-of-scope findings.

6.3 Do not expand the target area beyond what the spec declares. Adjacent code is not in scope.

6.4 Do not silently alter public interfaces. Interface changes require explicit inclusion in the desired-shape description.

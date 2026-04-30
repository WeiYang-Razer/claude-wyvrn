# flow-refactor

Entry point for refactor flows. Runs the full five-phase workflow for restructuring code without changing behavior.

## Trigger

Slash command: `/flow-refactor`

Natural language: "start a refactor flow" or equivalent.

## Description

Orchestrates a complete refactor flow end-to-end: reads context, clarifies the target and desired shape, captures a test baseline, implements the refactor, verifies behavior preservation, and returns a verifier report.

## Inputs

Initial prompt containing:

- Task title.
- Target area (files, modules, or code regions).
- Preservation statement (behaviors, interfaces, or invariants that must not change).

Optionally:

- Desired shape (will be developed in Clarify if not provided).
- Scope boundary.
- Rationale.
- Additional context.
- Validation mode override.

## Behavior

### Phase 0: Pre-flight check

Verify `~/.claude-wyvrn/` exists and contains `VERSION`, `HARNESS.md`, `INDEX.md` per `HARNESS.md` §2.6. If any are missing, halt and report to the human via the active session: "Wyvrn harness not installed at `~/.claude-wyvrn/`. Install the harness and retry."

### Phase 1: Read

1. Emit `Reading...` in the session.
2. Read all files per `HARNESS.md` §3.1, issued as one parallel batch per `HARNESS.md` §11.2.
3. Read `workflows/WORKFLOW.md` and `workflows/REFACTOR.md` (in the same parallel batch as step 2 where not already covered).
4. Read prior decision records not marked archived.
5. Assign flow ID: scan `.claude-wyvrn-local/refactors/` for highest existing `REF-NNNN`, increment by 1. Human may override.
6. Generate slug from task title.

### Phase 1.5: Triviality check

1. Run the `triviality-detector` skill per `HARNESS.md` §10.1. The detector is an in-context procedure — do not invoke a subagent. Apply the steps in `skills/triviality-detector/SKILL.md` against the initial prompt, the refactor-spec template, `REFACTOR.md` §2.1 prompt-gated fields, and `PROJECT.md` settings (if present).
2. Capture the verdict (`trivial`, `prompt_complete`, or `standard`) and a one-sentence reason.
3. The verdict gates Phase 2 and Phase 4 invocations as documented below. Record verdict and reason for inclusion in the spec artifact's Implementation notes section.

Note: the triviality criteria in `skills/triviality-detector/SKILL.md` §3 are stringent for refactor flows — most refactors touch multiple files, modify ARCHITECTURE.md, or shift module boundaries, and will return `standard`. A single-file local refactor (e.g., extract method within one file with no public-interface change, no architecture impact) can still qualify. The desired-shape check needs concrete description in the prompt for `prompt_complete` to fire.

### Phase 2: Clarify

If the Phase 1.5 verdict is `standard`: same orchestration as flow-feature Phase 2 standard path. Invokes `run-clarifier` with flow type `refactor`. The clarifier applies `REFACTOR.md` requirements — target area, preservation statement, title are prompt-gated; desired shape is clarify-gated.

If the Phase 1.5 verdict is `prompt_complete` or `trivial`:

1. Emit `Clarifying...` in the session.
2. Do not invoke `run-clarifier`. Do not invoke any subagent.
3. Write the spec artifact at `.claude-wyvrn-local/refactors/REF-NNNN-[slug].md` directly from the initial prompt, using the `refactor-spec.md` template:
    - Title, target area, preservation statement, desired shape from the prompt.
    - Scope boundary, rationale from the prompt or `N/A`.
    - Implementation notes: first line records `Triviality verdict: <verdict>. Reason: <reason>.` Other content `N/A` until Work begins.
    - Baseline block left as template defaults — Work fills it.
4. The template-verifier hook fires on the write per `HARNESS.md` §4.6. Correct and re-write if findings.
5. No clarification batch artifact is produced on these paths.

### Phase 3: Work

1. Emit `Working...` in the session.
2. Read the spec artifact, and the clarification batch when it exists (standard path only).
3. Read stack-specific conventions as files are touched.
4. **Baseline capture per `REFACTOR.md` §4.1:**
    1. Run the full project test suite before any code modification.
    2. Record pass/fail status for every test in the spec artifact's Baseline section.
    3. If the test suite cannot run (infrastructure or build failure), halt and file a late clarification.
    4. Do not modify any code before baseline is recorded.
5. **Implement the refactor per `REFACTOR.md` §4.2–4.4:**
    1. Apply changes matching the desired shape.
    2. Preserve behavior, interface, and invariants named in the preservation statement.
    3. Do not delete, rename, or weaken existing tests without a decision record.
    4. Update `.claude-wyvrn-local/ARCHITECTURE.md` if the refactor alters architectural elements. The architecture update adds a Change log entry and, if prior entries were edited, a Changes entry.
6. Apply `DECISIONS.md` §1 classification to every decision. INFERRED → `decision-log` skill.
7. Every artifact write triggers the template-verifier hook (`hooks/template_verifier.py`) per `HARNESS.md` §4.6.

### Phase 4: Verify

If the Phase 1.5 verdict is `standard` or `prompt_complete`: same orchestration as flow-feature Phase 4 standard/prompt_complete paths. Invokes `run-verifier`. The verifier applies `REFACTOR.md` §5 deltas — preservation verification (baseline comparison), desired-shape verification, architecture consistency.

If the Phase 1.5 verdict is `trivial`: orchestrator runs the verifier-equivalent self-check inline per `HARNESS.md` §10.4 in its own context. Apply every check in `agents/verifier/AGENT.md` Behavior, with the `REFACTOR.md` §5 deltas. Run independent checks in parallel per `HARNESS.md` §11.3 — tests first, then desired-shape + code review + project alignment in parallel, then architecture consistency and out-of-scope findings collection:

- **Preservation verification per `REFACTOR.md` §5.1.** Run the full project test suite. Compare to the baseline recorded during Work. Any test that was passing at baseline and is now failing is a finding. Any test newly deleted without a decision record is a finding.
- **Desired-shape verification per `REFACTOR.md` §5.2.** Read the spec's desired-shape description and the diff. Verify the diff achieves the described shape. Partial or off-target implementation is a finding.
- **Architecture consistency per `REFACTOR.md` §5.3.** If ARCHITECTURE.md was updated, check the update for consistency with the diff.
- **AC verification (refactor flows have no ACs in the feature sense — preservation and desired-shape stand in), code review against `CONVENTIONS.md` and stack files, project alignment per `agents/verifier/AGENT.md` Check 4, out-of-scope findings collection** — all inline.

Write the verifier report at `.claude-wyvrn-local/reviews/REF-NNNN-review.md`. Outcome routing: blocking finding → return to Phase 3 (Work) with the finding as scope, increment cycle. Three-cycle cap per `WORKFLOW.md` §4.4 still applies.

### Phase 5: Validate

Same orchestration as flow-feature Phase 5.

### Post-close correction

Same as flow-feature.

## Outputs

- Spec artifact at `.claude-wyvrn-local/refactors/REF-NNNN-[slug].md`.
- Clarification batch (only on `standard` path; not produced for `prompt_complete` or `trivial` verdicts), decision records, verifier report, verifier gap reports as needed.
- Updated `.claude-wyvrn-local/ARCHITECTURE.md` if applicable.
- Code changes implementing the refactor.

## Invokes

Same set as flow-feature, with the same `triviality-detector`-driven gating: `triviality-detector` always runs; `run-clarifier`/`clarifier` only on `standard` verdict; `run-verifier`/`verifier`/`code-reviewer` on `standard` and `prompt_complete` verdicts but not on `trivial`. The template-verifier hook always fires on artifact writes.

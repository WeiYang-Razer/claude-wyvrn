# flow-fix

Entry point for fix flows. Runs the full five-phase workflow for resolving a bug.

## Trigger

Slash command: `/flow-fix`

Natural language: "start a fix flow" or equivalent.

## Description

Orchestrates a complete fix flow end-to-end: reads context, clarifies the bug with the human, reproduces the bug, implements the fix, verifies it, and returns a verifier report for human validation.

## Inputs

Initial prompt containing:

- Task title.
- Expected outcome (what the system should do).
- Current outcome (what the system does instead).
- Reproduction steps or conditions.

Optionally:

- Hypothesis about root cause.
- Scope boundary.
- Additional context, references, or constraints.
- Validation mode override.

## Behavior

### Phase 0: Pre-flight check

Verify `~/.claude-wyvrn/` exists and contains `VERSION`, `HARNESS.md`, `INDEX.md` per `HARNESS.md` §2.6. If any are missing, halt and report to the human via the active session: "Wyvrn harness not installed at `~/.claude-wyvrn/`. Install the harness and retry."

### Phase 1: Read

1. Emit `Reading...` in the session.
2. Read all files per `HARNESS.md` §3.1, issued as one parallel batch per `HARNESS.md` §11.2.
3. Read `workflows/WORKFLOW.md` and `workflows/FIX.md` (in the same parallel batch as step 2 where not already covered).
4. Read prior decision records not marked archived.
5. Assign flow ID: scan `.claude-wyvrn-local/fixes/` for highest existing `FIX-NNNN`, increment by 1. Human may override.
6. Generate slug from task title.

### Phase 1.5: Triviality check

1. Run the `triviality-detector` skill per `HARNESS.md` §10.1. The detector is an in-context procedure — do not invoke a subagent. Apply the steps in `skills/triviality-detector/SKILL.md` against the initial prompt, the fix-spec template, `FIX.md` §2.1 prompt-gated fields, and `PROJECT.md` settings (if present).
2. Capture the verdict (`trivial`, `prompt_complete`, or `standard`) and a one-sentence reason.
3. The verdict gates Phase 2 and Phase 4 invocations as documented below. Record verdict and reason for inclusion in the spec artifact's Implementation notes section.

### Phase 2: Clarify

If the Phase 1.5 verdict is `standard`: same orchestration as flow-feature Phase 2 standard path. Invokes `run-clarifier` with flow type `fix`. The clarifier applies `FIX.md` requirements — all four fields are prompt-gated.

If the Phase 1.5 verdict is `prompt_complete` or `trivial`:

1. Emit `Clarifying...` in the session.
2. Do not invoke `run-clarifier`. Do not invoke any subagent.
3. Write the spec artifact at `.claude-wyvrn-local/fixes/FIX-NNNN-[slug].md` directly from the initial prompt, using the `fix-spec.md` template:
    - Title from the prompt.
    - Expected outcome, current outcome, reproduction steps from the prompt.
    - Scope boundary, root-cause hypothesis from the prompt or `N/A`.
    - Implementation notes: first line records `Triviality verdict: <verdict>. Reason: <reason>.` Other content `N/A` until Work begins.
    - Reproduction confirmation block left as template defaults — Work fills it.
4. The template-verifier hook fires on the write per `HARNESS.md` §4.6. Correct and re-write if findings.
5. No clarification batch artifact is produced on these paths.

### Phase 2.5: Reuse hint

If the Phase 1.5 verdict is `standard` or `prompt_complete`:

1. Run the `reuse-hint` skill per `skills/reuse-hint/SKILL.md`. The skill runs in the orchestrator's context; do not invoke a subagent.
2. The skill applies its own gate (§1) and may return `skipped` or `no_findings` — in which case nothing is appended to the spec and the flow proceeds to Phase 3. Most fix flows do not introduce new symbols and the gate will skip; the hint is preserved here for fixes that introduce a helper.
3. On `appended`, the skill's output block is added to the spec's Context section. Fix specs do not have a Context section in the template — the skill appends it under Implementation notes instead. The template-verifier hook fires on the spec re-write.

If the Phase 1.5 verdict is `trivial`: skip Phase 2.5 entirely.

### Phase 3: Work

1. Emit `Working...` in the session.
2. Read the spec artifact, and the clarification batch when it exists (standard path only).
3. Read stack-specific conventions as files are touched.
4. **Reproduction test first per `FIX.md` §4.1:**
    1. Write a test that reproduces the bug using the reproduction steps in the spec.
    2. Run the test. Confirm it fails in the expected way.
    3. Record the failure in the spec artifact's reproduction confirmation section.
    4. If reproduction fails (bug does not manifest), halt and file a late clarification.
5. **Implement the fix per `FIX.md` §4.2:**
    1. Implement the fix.
    2. Run the reproduction test. Confirm it now passes.
    3. Run existing tests. Confirm no regression.
6. Before declaring any new public function, class, method, or top-level constant, grep the touched module for symbols with similar names. Prefer reuse over duplication. When a new symbol is necessary, document the reason in the spec's Implementation notes section.
7. Apply `DECISIONS.md` §1 classification to every decision. INFERRED → `decision-log` skill.
8. Every artifact write triggers the template-verifier hook (`hooks/template_verifier.py`) per `HARNESS.md` §4.6.

### Phase 4: Verify

If the Phase 1.5 verdict is `standard` or `prompt_complete`: same orchestration as flow-feature Phase 4 standard/prompt_complete paths. Invokes `run-verifier`. The verifier applies `FIX.md` §5 deltas.

If the Phase 1.5 verdict is `trivial`: orchestrator runs the verifier-equivalent self-check inline per `HARNESS.md` §10.4 in its own context. Apply every check in `agents/verifier/AGENT.md` Behavior, with the `FIX.md` §5 deltas. Run independent checks in parallel per `HARNESS.md` §11.3 — tests first, then AC verification + code review in parallel, then out-of-scope findings collection:

- **Reproduction test verification per `FIX.md` §5.1.** Locate the reproduction test. Run it. Confirm it passes post-fix. Cross-reference the test against the spec's reproduction conditions.
- **Regression check per `FIX.md` §5.2.** Run the reproduction test plus tests in files affected by the diff. Compare to the baseline recorded during Work. New failures are findings; pre-existing failures are out-of-scope per `DECISIONS.md` §4.2.
- **AC verification, code review against `CONVENTIONS.md` and stack files, out-of-scope findings collection** — all inline.

Write the verifier report at `.claude-wyvrn-local/reviews/FIX-NNNN-review.md`. Outcome routing: blocking finding → return to Phase 3 (Work) with the finding as scope, increment cycle. Three-cycle cap per `WORKFLOW.md` §4.4 still applies.

### Phase 5: Validate

Same orchestration as flow-feature Phase 5.

### Post-close correction

Same as flow-feature.

## Outputs

- Spec artifact at `.claude-wyvrn-local/fixes/FIX-NNNN-[slug].md`.
- Clarification batch (only on `standard` path; not produced for `prompt_complete` or `trivial` verdicts), decision records, verifier report, verifier gap reports as needed.
- Code changes implementing the fix.
- Reproduction test.
- Any modifications to existing tests as required by the fix, with decision records.

## Invokes

Same set as flow-feature, with the same `triviality-detector`-driven gating: `triviality-detector` always runs; `run-clarifier`/`clarifier` only on `standard` verdict; `reuse-hint` on `standard` and `prompt_complete` verdicts but not on `trivial` (further gated by the skill's own §1); `run-verifier`/`verifier`/`code-reviewer` on `standard` and `prompt_complete` verdicts but not on `trivial`. The template-verifier hook always fires on artifact writes.

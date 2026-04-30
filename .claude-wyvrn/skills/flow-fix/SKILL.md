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
2. Read all files per `HARNESS.md` §3.1.
3. Read `workflows/WORKFLOW.md` and `workflows/FIX.md`.
4. Read prior decision records not marked archived.
5. Assign flow ID: scan `.claude-wyvrn-local/fixes/` for highest existing `FIX-NNNN`, increment by 1. Human may override.
6. Generate slug from task title.

### Phase 2: Clarify

Same orchestration as flow-feature Phase 2. Invokes `run-clarifier` with flow type `fix`. The clarifier applies `FIX.md` requirements — all four fields are prompt-gated.

### Phase 3: Work

1. Emit `Working...` in the session.
2. Read the spec artifact, clarification batch.
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
6. Apply `DECISIONS.md` §1 classification to every decision. INFERRED → `decision-log` skill.
7. Every artifact write triggers the template-verifier hook (`hooks/template_verifier.py`) per `HARNESS.md` §4.6.

### Phase 4: Verify

Same orchestration as flow-feature Phase 4. Invokes `run-verifier`. The verifier applies `FIX.md` §5 deltas.

### Phase 5: Validate

Same orchestration as flow-feature Phase 5.

### Post-close correction

Same as flow-feature.

## Outputs

- Spec artifact at `.claude-wyvrn-local/fixes/FIX-NNNN-[slug].md`.
- Clarification batch, decision records, verifier report, verifier gap reports as needed.
- Code changes implementing the fix.
- Reproduction test.
- Any modifications to existing tests as required by the fix, with decision records.

## Invokes

Same set as flow-feature.

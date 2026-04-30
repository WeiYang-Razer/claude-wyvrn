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
2. Read all files per `HARNESS.md` §3.1.
3. Read `workflows/WORKFLOW.md` and `workflows/REFACTOR.md`.
4. Read prior decision records not marked archived.
5. Assign flow ID: scan `.claude-wyvrn-local/refactors/` for highest existing `REF-NNNN`, increment by 1. Human may override.
6. Generate slug from task title.

### Phase 2: Clarify

Same orchestration as flow-feature Phase 2. Invokes `run-clarifier` with flow type `refactor`. The clarifier applies `REFACTOR.md` requirements — target area, preservation statement, title are prompt-gated; desired shape is clarify-gated.

### Phase 3: Work

1. Emit `Working...` in the session.
2. Read the spec artifact, clarification batch.
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

Same orchestration as flow-feature Phase 4. Invokes `run-verifier`. The verifier applies `REFACTOR.md` §5 deltas — preservation verification (baseline comparison), desired-shape verification, architecture consistency.

### Phase 5: Validate

Same orchestration as flow-feature Phase 5.

### Post-close correction

Same as flow-feature.

## Outputs

- Spec artifact at `.claude-wyvrn-local/refactors/REF-NNNN-[slug].md`.
- Clarification batch, decision records, verifier report, verifier gap reports as needed.
- Updated `.claude-wyvrn-local/ARCHITECTURE.md` if applicable.
- Code changes implementing the refactor.

## Invokes

Same set as flow-feature.

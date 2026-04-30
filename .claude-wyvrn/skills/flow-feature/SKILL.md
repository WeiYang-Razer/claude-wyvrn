# flow-feature

Entry point for feature flows. Runs the full five-phase workflow for building new functionality.

## Trigger

Slash command: `/flow-feature`

Natural language: "start a feature flow" or equivalent.

## Description

Orchestrates a complete feature flow end-to-end: reads context, clarifies requirements with the human, implements the feature, verifies it, and returns a verifier report for human validation.

## Inputs

Initial prompt containing at minimum:

- Task title.
- Intent (user goal, problem solved, capability added).

Optionally:

- Acceptance criteria (will be developed in Clarify if not provided).
- Scope boundary.
- Additional context, references, or constraints.
- Validation mode override (`blocking` or `non-blocking`).

## Behavior

### Phase 0: Pre-flight check

Verify `~/.claude-wyvrn/` exists and contains `VERSION`, `HARNESS.md`, `INDEX.md` per `HARNESS.md` §2.6. If any are missing, halt and report to the human via the active session: "Wyvrn harness not installed at `~/.claude-wyvrn/`. Install the harness and retry."

### Phase 1: Read

1. Emit `Reading...` in the session.
2. Read all files per `HARNESS.md` §3.1.
3. Read `workflows/WORKFLOW.md` and `workflows/FEATURE.md`.
4. Read prior decision records in `.claude-wyvrn-local/decisions/` not marked archived.
5. Assign flow ID: scan `.claude-wyvrn-local/features/` for highest existing `FEAT-NNNN`, increment by 1. Human may override via the initial prompt.
6. Generate slug from task title.

### Phase 2: Clarify

1. Emit `Clarifying...` in the session.
2. Invoke `run-clarifier` skill with inputs: flow ID, flow type `feature`, initial prompt, spec artifact path, clarification batch path.
3. `run-clarifier` returns either:
    - `complete` — proceed to Phase 3.
    - `batch: <N> questions` — continue with question handling below.
4. Surface the questions by invoking `AskUserQuestion` per `HARNESS.md` §8. If the round produced more than 4 questions, chunk into sequential calls of up to 4 questions each, in the order produced by the clarifier. Group naturally-related questions into the same call where possible. For each question that carries an `Options:` field in the batch, pass those options through; for questions without options, supply 2 placeholder options and rely on the auto-added "Other" for free-text answers.
5. As each `AskUserQuestion` call returns, write all answers from that call into the clarification batch artifact alongside their questions in one update before issuing the next call.
6. When all questions in the round are answered, re-invoke `run-clarifier`.
7. Repeat until `run-clarifier` returns `complete`.

### Phase 3: Work

1. Emit `Working...` in the session.
2. Read the spec artifact, clarification batch.
3. Read stack-specific conventions per `CONVENTIONS.md` §1.3 as files are touched.
4. Implement the feature per the spec's acceptance criteria.
5. Apply `DECISIONS.md` §1 classification to every decision encountered:
    - SPEC-DEFINED → act.
    - INFERRED → act, invoke `decision-log` skill.
    - UNDECIDED or CONTRADICTION → halt, file a late clarification per `HARNESS.md` §5.4.
6. Write new tests covering every acceptance criterion per `CONVENTIONS.md` §2.6.
7. Every artifact write triggers the template-verifier hook (`hooks/template_verifier.py`) per `HARNESS.md` §4.6.

### Phase 4: Verify

1. Emit `Verifying...` in the session.
2. Invoke `run-verifier` skill with flow ID and cycle number.
3. `run-verifier` returns outcome:
    - `Success` → proceed to Phase 5.
    - `Findings` → return to Phase 3 with findings as the scope. Increment cycle number.
4. If cycle number reaches 4, halt per `WORKFLOW.md` §4.4. Emit convergence failure message in session. End flow in Failed status.

### Phase 5: Validate

1. Determine validation mode:
    1. Initial prompt declaration (if present).
    2. `PROJECT.md` validation field (if declared).
    3. Default: non-blocking.
2. **Non-blocking:** emit `Flow closed: [flow-id]` in session. End flow.
3. **Blocking:** prompt the human for validation by invoking `AskUserQuestion` per `HARNESS.md` §8 — single question, header `Validate`, options `[Validate (close flow), Request correction]`. On `Validate (close flow)`, emit `Flow closed: [flow-id]` and end. On `Request correction` (or a free-text correction via the auto-added "Other"), invoke post-close correction handler (see below).

### Post-close correction

When the human issues a modification request after flow close:

1. Classify the request per `WORKFLOW.md` §6.1 into Case 1, Case 2, or Case 3.
2. Execute the appropriate case:
    - **Case 1:** re-enter Phase 3 with the correction as finding. Loop to Phase 4.
    - **Case 2:** produce a verifier gap report via the verifier-gap template. Apply Case 1 afterward.
    - **Case 3:** halt. Invoke `AskUserQuestion` per `HARNESS.md` §8 — single question, header `Scope`, options `[Expand scope and continue, Close and start new flow]`. Proceed per choice.
3. Correction loop cap at 3 cycles per `WORKFLOW.md` §6.3.

## Outputs

- Spec artifact at `.claude-wyvrn-local/features/FEAT-NNNN-[slug].md`.
- Clarification batch at `.claude-wyvrn-local/clarifications/FEAT-NNNN-batch.md`.
- Decision records at `.claude-wyvrn-local/decisions/` (as needed).
- Verifier report at `.claude-wyvrn-local/reviews/FEAT-NNNN-review.md`.
- Any verifier gap reports at `.claude-wyvrn-local/verifier-gaps/GAP-NNNN-[slug].md` (as needed).
- Code changes implementing the feature.
- New tests covering the acceptance criteria.

## Invokes

- `run-clarifier` (utility skill)
- `run-verifier` (utility skill)
- `decision-log` (utility skill)
- `clarifier` (subagent, via run-clarifier)
- `verifier` (subagent, via run-verifier)
- template-verifier hook (`hooks/template_verifier.py`, fires automatically on every artifact write)
- `code-reviewer` (subagent, via verifier)

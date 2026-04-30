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
2. Read all files per `HARNESS.md` §3.1, issued as one parallel batch per `HARNESS.md` §11.2.
3. Read `workflows/WORKFLOW.md` and `workflows/FEATURE.md` (in the same parallel batch as step 2 where not already covered).
4. Read prior decision records in `.claude-wyvrn-local/decisions/` not marked archived.
5. Assign flow ID: scan `.claude-wyvrn-local/features/` for highest existing `FEAT-NNNN`, increment by 1. Human may override via the initial prompt.
6. Generate slug from task title.

### Phase 1.5: Triviality check

1. Run the `triviality-detector` skill per `HARNESS.md` §10.1. The detector is an in-context procedure — do not invoke a subagent. Apply the steps in `skills/triviality-detector/SKILL.md` against the initial prompt, the feature-spec template, `FEATURE.md` §2.1 prompt-gated fields, and `PROJECT.md` settings (if present).
2. Capture the verdict (`trivial`, `prompt_complete`, or `standard`) and a one-sentence reason.
3. The verdict gates Phase 2 and Phase 4 invocations as documented below. Record verdict and reason for inclusion in the spec artifact's Implementation notes section.

### Phase 2: Clarify

If the Phase 1.5 verdict is `standard`:

1. Emit `Clarifying...` in the session.
2. Invoke `run-clarifier` skill with inputs: flow ID, flow type `feature`, initial prompt, spec artifact path, clarification batch path.
3. `run-clarifier` returns either:
    - `complete` — proceed to Phase 3.
    - `batch: <N> questions` — continue with question handling below.
4. Surface the questions by invoking `AskUserQuestion` per `HARNESS.md` §8. If the round produced more than 4 questions, chunk into sequential calls of up to 4 questions each, in the order produced by the clarifier. Group naturally-related questions into the same call where possible. For each question that carries an `Options:` field in the batch, pass those options through; for questions without options, supply 2 placeholder options and rely on the auto-added "Other" for free-text answers.
5. As each `AskUserQuestion` call returns, write all answers from that call into the clarification batch artifact alongside their questions in one update before issuing the next call.
6. When all questions in the round are answered, re-invoke `run-clarifier`.
7. Repeat until `run-clarifier` returns `complete`.

If the Phase 1.5 verdict is `prompt_complete` or `trivial`:

1. Emit `Clarifying...` in the session.
2. Do not invoke `run-clarifier`. Do not invoke any subagent.
3. Write the spec artifact at `.claude-wyvrn-local/features/FEAT-NNNN-[slug].md` directly from the initial prompt, using the `feature-spec.md` template:
    - Title and Intent from the prompt.
    - Acceptance criteria: derive 1-2 testable criteria from the prompt's described change. Each criterion is a pass/fail condition.
    - Scope boundary from the prompt or `N/A`.
    - Implementation notes: first line records `Triviality verdict: <verdict>. Reason: <reason>.` Other content `N/A` until Work begins.
    - Other template fields per defaults.
4. The template-verifier hook fires on the write per `HARNESS.md` §4.6. Correct and re-write if findings.
5. No clarification batch artifact is produced on these paths.

### Phase 3: Work

1. Emit `Working...` in the session.
2. Read the spec artifact, and the clarification batch when it exists (standard path only).
3. Read stack-specific conventions per `CONVENTIONS.md` §1.3 as files are touched.
4. Implement the feature per the spec's acceptance criteria.
5. Apply `DECISIONS.md` §1 classification to every decision encountered:
    - SPEC-DEFINED → act.
    - INFERRED → act, invoke `decision-log` skill.
    - UNDECIDED or CONTRADICTION → halt, file a late clarification per `HARNESS.md` §5.4.
6. Write new tests covering every acceptance criterion per `CONVENTIONS.md` §2.6.
7. Every artifact write triggers the template-verifier hook (`hooks/template_verifier.py`) per `HARNESS.md` §4.6.

### Phase 4: Verify

If the Phase 1.5 verdict is `standard` or `prompt_complete`:

1. Emit `Verifying...` in the session.
2. Invoke `run-verifier` skill with flow ID and cycle number.
3. `run-verifier` returns outcome:
    - `Success` → proceed to Phase 5.
    - `Findings` → return to Phase 3 with findings as the scope. Increment cycle number.
4. If cycle number reaches 4, halt per `WORKFLOW.md` §4.4. Emit convergence failure message in session. End flow in Failed status.

If the Phase 1.5 verdict is `trivial`:

1. Emit `Verifying...` in the session.
2. Do not invoke `run-verifier`. Do not invoke `verifier` or `code-reviewer` subagents. Run the verifier-equivalent self-check inline per `HARNESS.md` §10.4, in the orchestrator's context, applying every check in `agents/verifier/AGENT.md` Behavior. Run independent checks in parallel per `HARNESS.md` §11.3 — tests first, then AC verification + code review + project alignment in parallel, then out-of-scope findings collection:
    - **Test execution.** Run tests per `FEATURE.md` §5.2. Record results.
    - **AC verification.** For each acceptance criterion in the spec, locate the test or artifact that satisfies it. Confirm.
    - **Code review.** Re-read the diff against `CONVENTIONS.md` §2-3 and any stack-specific files matched in Phase 3. Look for blocking convention violations.
    - **Project alignment.** Per `agents/verifier/AGENT.md` Check 4. Trivial flows excluded new public symbols at the gate, so this check is mostly trivial; confirm.
    - **Out-of-scope findings.** Collect any issues outside scope per `DECISIONS.md` §4.2.
3. Write the verifier report at `.claude-wyvrn-local/reviews/FEAT-NNNN-review.md` using the `verifier-report.md` template. The template-verifier hook fires on the write — correct and re-write if findings.
4. Outcome:
    - All checks pass with no blocking finding → `Success`. Proceed to Phase 5.
    - Any blocking finding → `Findings`. Return to Phase 3 with findings as the scope. Increment cycle number.
5. If cycle number reaches 4, halt per `WORKFLOW.md` §4.4. Emit convergence failure message in session. End flow in Failed status.

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
- Clarification batch at `.claude-wyvrn-local/clarifications/FEAT-NNNN-batch.md` (only on `standard` path; not produced for `prompt_complete` or `trivial` verdicts).
- Decision records at `.claude-wyvrn-local/decisions/` (as needed).
- Verifier report at `.claude-wyvrn-local/reviews/FEAT-NNNN-review.md`.
- Any verifier gap reports at `.claude-wyvrn-local/verifier-gaps/GAP-NNNN-[slug].md` (as needed).
- Code changes implementing the feature.
- New tests covering the acceptance criteria.

## Invokes

- `triviality-detector` (utility skill, in-context — no subagent)
- `run-clarifier` (utility skill, only on `standard` path)
- `run-verifier` (utility skill, only on `standard` and `prompt_complete` paths)
- `decision-log` (utility skill)
- `clarifier` (subagent, via run-clarifier)
- `verifier` (subagent, via run-verifier)
- template-verifier hook (`hooks/template_verifier.py`, fires automatically on every artifact write)
- `code-reviewer` (subagent, via verifier; not invoked on `trivial` path)

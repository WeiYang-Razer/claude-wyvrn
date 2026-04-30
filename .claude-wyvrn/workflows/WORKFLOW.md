# WORKFLOW.md

Shared phase sequence for all flows. Flow-specific deltas are in `FEATURE.md`, `FIX.md`, and `REFACTOR.md`. Rules are in `HARNESS.md`. Decision procedure is in `DECISIONS.md`.

## Phases

A flow runs five phases in order: Read, Clarify, Work, Verify, Validate.

Before Phase 1, every flow skill runs a pre-flight check per `HARNESS.md` §2.6 to verify the harness is installed at `~/.claude-wyvrn/`. If the check fails, halt immediately and report to the human via the active session. Do not proceed with any phase.

Emit a one-word progress indicator in the agent response at the start of each phase: `Reading...`, `Clarifying...`, `Working...`, `Verifying...`. No indicator for Validate; the verifier report is the signal that Validate has begun.

## 1. Read

1.1 Follow the reading protocol in `HARNESS.md` §3.1.
1.2 Read the task-specific spec template for the current flow type, as declared in `FEATURE.md`, `FIX.md`, or `REFACTOR.md`.
1.3 Read prior decision records in `.claude-wyvrn-local/decisions/` not marked archived.
1.4 Do not proceed to Clarify until reading is complete.

## 2. Clarify

### 2.1 Invocation

Invoke the `clarifier` agent. Pass the initial human prompt as input.

### 2.2 Clarifier round

In each round, the `clarifier`:

1. Reads all sources per `HARNESS.md` §3.1, the task-specific spec template, and all artifacts from prior rounds.
2. Drafts or updates the spec artifact in the appropriate folder.
3. Applies `DECISIONS.md` §1 classification to every decision point in the draft. UNDECIDED or CONTRADICTION becomes a batch entry.
4. If no batch entries: proceed to Work.
5. If batch entries exist: write the clarification batch artifact to `.claude-wyvrn-local/clarifications/[flow-id]-batch.md`. Return control to the flow skill.

### 2.3 Human prompting

Per `HARNESS.md` §8, human prompts occur by invoking the `AskUserQuestion` tool, not via file editing or raw-text prompts.

1. The flow skill reads the batch entries from the `clarifier`.
2. The flow skill presents the questions to the human by invoking `AskUserQuestion` per `HARNESS.md` §8, chunking into calls of up to 4 questions where the round produced more than 4. For each question that carries an `Options:` field in the batch, pass those options through; for questions without options, supply 2 placeholder options and rely on the auto-added "Other" for free-text answers.
3. As each `AskUserQuestion` call returns, write all answers from that call into the batch artifact alongside their questions in one update before issuing the next call.
4. When all questions for the round are answered, re-invoke the `clarifier` for the next round.

### 2.4 Outputs

At end of Clarify:

- Spec artifact exists and is complete: no UNDECIDED or CONTRADICTION items remain.
- Clarification batch artifact exists with all rounds and answers recorded.

## 3. Work

### 3.1 Inputs

The worker agent reads:

- All files per `HARNESS.md` §3.1.
- The spec artifact produced in Clarify.
- The clarification batch.
- Stack-specific conventions per `CONVENTIONS.md` §1.3, on demand.

### 3.2 Execution

1. Implement the task according to the spec artifact.
2. For each decision encountered, apply `DECISIONS.md` §1 classification:
    - SPEC-DEFINED: act.
    - INFERRED: act, log via `decision-log` skill.
    - UNDECIDED or CONTRADICTION: halt, file a late clarification per `HARNESS.md` §5.4.
3. Produce or modify code and tests per the flow-specific delta file.
4. Do not proceed to Verify until all acceptance criteria in the spec are implemented.

### 3.3 Template compliance during work

All artifacts written during work must conform to their templates per `HARNESS.md` §4. Every artifact write triggers the template-verifier hook (`hooks/template_verifier.py`) before the writing agent returns control.

## 4. Verify

### 4.1 Invocation

Invoke the `verifier` agent after work is complete.

### 4.2 Verifier responsibilities

The `verifier`:

1. Reads the spec artifact, the clarification batch, produced artifacts, produced code, and produced tests.
2. Verifies every acceptance criterion in the spec is satisfied.
3. Confirms the template-verifier hook (`hooks/template_verifier.py` per `HARNESS.md` §4.6) ran clean for every artifact produced during the flow, by checking the per-artifact log at `.claude-wyvrn-local/.metrics/template-verifier-findings.log`.
4. Runs tests per the flow-specific delta file.
5. Invokes the `code-reviewer` agent for convention compliance and code quality review.
6. Performs the project-alignment check inline, scanning ARCHITECTURE-declared modules for missed reuse and pattern drift per `agents/verifier/AGENT.md` Check 5.
7. Produces a verifier report at `.claude-wyvrn-local/reviews/[flow-id]-review.md`.

### 4.3 Verifier outcomes

**Success:** all acceptance criteria met, template compliance clean, tests pass, no blocking code-review findings. Report is marked success. Proceed to Validate.

**Findings:** one or more acceptance criteria unmet, template non-compliance, test failure, blocking code-review findings, or blocking project-alignment findings. Report lists specific findings. Return to Work.

**Out-of-scope findings:** issues noted during verification that are outside task scope per `DECISIONS.md` §4.2. These appear in a separate section of the report. They do not cause a Findings outcome.

**Advisory findings:** subjective code quality observations from `code-reviewer`. These appear in a separate section of the report. They do not cause a Findings outcome.

### 4.4 Verify-Work loop

If outcome is Findings:

1. Worker reads the verifier report.
2. Worker addresses the specific findings only. Scope does not expand.
3. Return to Verify.
4. Maximum three Work-Verify cycles. If cycle 4 would be needed, halt. Via the active session, report: "Three verification cycles without convergence." Flow ends in failure. Human decides next action.

## 5. Validate

### 5.1 Validation mode

Two modes:

- **Non-blocking:** flow closes on verifier success. Default.
- **Blocking:** flow remains open until human explicitly validates.

Mode is determined by:

1. Initial prompt declaration (if present) — overrides project default.
2. Project default from `PROJECT.md` (if declared).
3. Non-blocking if neither is set.

### 5.2 Non-blocking mode

Flow closes at the end of Verify on success. The verifier report is the output. Human reviews asynchronously. If the human issues a modification later, proceed per §6.

### 5.3 Blocking mode

After Verify succeeds, prompt the human for validation by invoking `AskUserQuestion` per `HARNESS.md` §8 — single question, header `Validate`, options `[Validate (close flow), Request correction]`. Flow remains in Validate state until the human responds. On `Validate (close flow)`, flow closes. On `Request correction` (or a free-text correction via the auto-added "Other"), proceed per §6.

### 5.4 Flow close

When the flow closes (either mode), emit via the active session: `Flow closed: [flow-id]`.

## 6. Post-close correction

If the human issues a modification request after flow close via the active session, re-enter the flow.

### 6.1 Classify the request

The worker agent classifies the human's modification request into one of three cases.

**Case 1: Simple correction within scope.** Modification is consistent with existing scope and could have been caught by the verifier. Treat as if the verifier flagged it.

1. Re-enter Work with the correction as the finding.
2. Run Work-Verify loop per §4.4.
3. Return to Validate.

**Case 2: Verifier gap.** Modification implies the verifier should have caught an issue but did not.

1. Produce a verifier gap report at `.claude-wyvrn-local/verifier-gaps/GAP-NNNN-[slug].md`.
2. Apply the correction per Case 1.
3. The gap report is surfaced to the human at flow close. No automatic verifier change is made.

**Case 3: Out of scope.** Modification is a new requirement not in the current scope.

1. Halt. Invoke `AskUserQuestion` per `HARNESS.md` §8 — single question (e.g., "Modification is out of scope for flow [flow-id]. How should we proceed?"), header `Scope`, options `[Expand scope and continue, Close and start new flow]`.
2. Proceed per human choice:
    - `Expand scope and continue`: update the spec artifact with new scope via a clarification round. Log as a scope-expansion decision record. Re-enter Work.
    - `Close and start new flow`: close the current flow. Start a new flow for the new scope.

### 6.2 Classification uncertainty

If the worker cannot clearly classify the request, treat it as UNDECIDED and file a clarification. The batch entry carries the three case options (`Case 1: simple correction`, `Case 2: verifier gap`, `Case 3: out of scope`) in its `Options:` field per `templates/clarification-batch.md`; the flow skill renders the question via `AskUserQuestion` per §2.3.

### 6.3 Correction loop cap

Maximum three post-close correction cycles. On cycle 4, halt. Via the active session, report: "Three post-close correction cycles without convergence." Human decides next action.

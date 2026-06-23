---
name: debug
description: Structured root-cause debugging instead of guess-and-check. Reproduce reliably, capture the exact symptom, form ranked hypotheses, test one at a time, isolate the true root cause, fix it with a regression test, then verify. Trigger when the user says "debug this", "why is X failing", "track down this bug", "this is broken", or invokes /debug directly.
---

# debug

Replaces shotgun edits with a disciplined hypothesis loop. The goal is the *root cause*, not the symptom — a fix you can explain via the full causal chain, protected by a regression test.

**Standalone by design.** Invoke directly on a failure, or when a `/flow` run hits a defect it cannot immediately explain. Never injected into `/flow` automatically.

## Execution principles

- Reproduce before theorizing. A bug you cannot trigger on demand cannot be confirmed fixed.
- One hypothesis, one probe. Change a single variable per experiment so the result is interpretable.
- Read before editing. Most root causes are found by reading the code path and its inputs, not by mutating it.
- Fix the cause, not the symptom. Suppressing the error message or patching the output is not a fix.
- Parallelize *reading* (multiple files, logs, greps in one batch); keep *experiments* sequential so each result is attributable.

## Preconditions

If `~/.claude-wyvrn/VERSION` missing → halt: `Wyvrn harness not installed. Run claude-wyvrn install.`

## Trigger

- Slash: `/debug <symptom or failing case>`
- Natural: "why is this failing", "track down this bug", "this is broken", "debug this", "it crashes when"

## Behavior

### Step 1 — Capture the exact symptom

Record verbatim, not paraphrased:

- The exact error text, stack trace, failing assertion, or wrong output.
- Expected vs. actual.
- The conditions under which it appears (inputs, environment, sequence).

If any of these are missing and not inferable, ask one batched AskUserQuestion to get them.

### Step 2 — Reproduce reliably

Establish a deterministic trigger — the smallest command, test, or input that produces the symptom on demand. Prefer a failing test as the repro (it doubles as the Step 6 regression test).

- Reproduced → proceed with the repro in hand.
- **Cannot reproduce** → that is the primary finding. Gather more data (logs, environment diffs, exact version/inputs from the user) before theorizing. Do not "fix" a bug you cannot trigger.

### Step 3 — Form ranked hypotheses

Read the relevant code path, inputs, and recent changes (`git log`/`git diff` of the area) in one parallel batch. From that, list 2–4 candidate causes ranked by likelihood, each phrased as a falsifiable statement:

> "The null comes from `parseConfig` returning early when the file is empty."

Rank by: recent changes to the path, proximity to the symptom, and how much of the evidence each explains.

### Step 4 — Test one hypothesis at a time

For the top hypothesis, design the smallest experiment that confirms or refutes it: a targeted log/print, a debugger breakpoint, a unit probe, or a one-line conditional check. Run it.

- Confirmed → Step 5.
- Refuted → discard it, remove the probe, move to the next hypothesis. If all are refuted, return to Step 3 with what the experiments revealed.

Change only one thing per experiment. Remove instrumentation before the next probe so results stay clean.

### Step 5 — Isolate the root cause

State the root cause as a complete causal chain: *trigger → mechanism → symptom*. You must be able to explain why the bug produces exactly the observed symptom. If a link in the chain is hand-waved, the root cause is not yet found — return to Step 4.

Distinguish root cause from symptom explicitly: the line that throws is usually not the cause; the cause is why that line received bad state.

### Step 6 — Fix the root cause + regression test

1. Write a test that fails on the current (buggy) code and captures the root-cause behavior — see `/tdd`. This is the regression guard (`universal.md` §1.6: a bug fix ships with a test that would have caught it).
2. Apply the minimal fix at the root cause, not at the symptom site (unless they coincide).
3. Confirm the new test now passes.

### Step 7 — Verify and check for collateral

- Re-run the original repro from Step 2 — confirm the symptom is gone.
- Run the broader affected test set in parallel — confirm no regression introduced.
- Hand off to `/verify-done` (or apply its checklist) before declaring the bug fixed.

## Anti-patterns (do not do these)

- **Shotgun debugging** — changing several things at once hoping one helps. You learn nothing and may add new bugs.
- **Symptom patching** — wrapping in try/catch, clamping a value, or special-casing the output to hide the failure (`universal.md` §2.4 — do not swallow errors).
- **Claiming fixed without re-running the repro** — "this should fix it" is not verification.
- **Skipping the regression test** — without it, the bug returns silently.

## Stop conditions

- Cannot reproduce after gathering available data → halt; report what is needed to reproduce. Do not guess-fix.
- All hypotheses refuted and no new ones emerge → halt; report findings and the narrowed search space so the user can supply more context.
- User interrupts → summarize the current hypothesis, what has been ruled out, and the next experiment.

## Constraints

- Never apply a fix you cannot trace to a root cause you can explain.
- Never suppress, mask, or mark-as-expected a failure to make it disappear (`universal.md` §1.6, §2.4) without explicit user confirmation.
- Remove all temporary debug instrumentation (logs, prints, breakpoints) before finishing.
- Do not modify `~/.claude-wyvrn/`.

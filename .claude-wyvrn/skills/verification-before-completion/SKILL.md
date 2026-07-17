---
name: verify-done
description: Evidence gate before declaring any task complete. Maps every acceptance criterion to concrete, observed proof (test output, build result, diff inspection) and rejects "should work" claims. Trigger before saying a task is done, when the user asks "is this actually done?", "verify before you claim it", or invokes /verify-done directly.
---

# verify-done

A hard gate between "I think this is finished" and telling the user it is finished. The rule: a task is not done until each acceptance criterion is backed by evidence you actually observed in this session. Reinforces `/flow` Step 8 (self-verify) as a reusable standalone discipline.

**Standalone by design.** Invoke directly to audit a change, or as the final check before reporting completion in any workflow. Never injected into `/flow` automatically.

## Execution principles

- Evidence over assertion. "Tests pass" means *you ran them and saw them pass in this session*, with the command and outcome to show. Anything else is unverified.
- Parallelize evidence collection — independent build/test/lint commands run in one batch.
- A single unmet criterion makes the verdict NOT VERIFIED. No partial "done".
- Honest gaps beat false confidence. Reporting "I could not verify X" is a success of this skill, not a failure.
- **POSIX syntax in Bash.** Never use PowerShell here-string syntax (`@'...'@`, `@"..."@`) in the Bash tool — it leaks stray `@` characters. Multi-line strings use POSIX constructs (heredoc).

## Preconditions

If `~/.claude-wyvrn/VERSION` missing → halt: `Wyvrn harness not installed. Run claude-wyvrn install.`

## Trigger

- Slash: `/verify-done [task or change]`
- Natural: "is this actually done?", "verify before you say it's complete", "did that really work?", "confirm this is finished"

## Behavior

### Step 1 — Restate the claim

State precisely what is being verified: the task and its acceptance criteria. Draw them from, in order of authority:

1. The acceptance criteria of a matching spec in `.claude-wyvrn-local/specs/` or task in `.claude-wyvrn-local/plans/`, if one exists.
2. The goal/acceptance signal established earlier in the conversation.
3. The user's stated intent.

If no acceptance criteria can be found or inferred, ask one batched AskUserQuestion to establish what "done" means before verifying. You cannot verify against an undefined target.

### Step 2 — Collect evidence (parallel batch)

Run the checks that produce observable proof, independent ones in one parallel batch:

- **Tests** — run the affected test set; capture pass/fail counts. Required when executable code changed (`universal.md` §1.6).
- **Build / typecheck** — run the project's build or type checker if the stack has one.
- **Lint / format check** — run if the project defines one.
- **Diff inspection** — re-read the actual diff (`git diff`), not your memory of it.

Use the project's real commands (from PROJECT.md, scripts, or stack conventions). If a check cannot be run in this environment, record it as **unverified** with the reason — never assume its result.

### Step 3 — Map criteria to evidence

Build an explicit table, one row per acceptance criterion:

| Criterion | Evidence | Status |
|---|---|---|
| <criterion> | <command run + observed outcome, or diff location> | met / unmet / unverified |

Every criterion needs a concrete evidence cell. "Looks right" or "the code does this" is only acceptable when backed by a specific diff location you re-read.

### Step 4 — Honesty sweep

Before issuing a verdict, scan for the common false-completion patterns and flag any present:

- A path claimed working that no test or manual check actually exercised.
- "Should work" / "this will handle X" phrasing standing in for an observed result.
- Tests that were modified to pass rather than the code (check the diff for weakened assertions, added skips).
- Edited but un-run tests.
- Scope drift: changes outside the declared task, or criteria silently dropped.
- Leftover debug output, commented-out code, or TODOs (`universal.md` §1.2).

### Step 5 — Verdict

Emit one of:

- **VERIFIED** — every criterion `met` with evidence. State the one-line proof for each, then report done.
- **NOT VERIFIED** — list each `unmet` / `unverified` criterion with what is missing and the specific next action to close it. Do not describe the task as complete.

## Stop conditions

- Acceptance criteria cannot be established → halt at Step 1 and ask; do not verify against a guess.
- A required check cannot run in this environment → do not fabricate its result; mark unverified and surface it in the verdict.
- User interrupts → report the partial evidence table gathered so far.

## Constraints

- Never report a task as done while any criterion is unmet or unverified.
- Never claim a command's result without having run it this session.
- Do not weaken or skip tests to reach a VERIFIED verdict (`universal.md` §1.6).
- Do not modify source files to "make it pass" — this skill audits, it does not implement. If a fix is needed, report it and hand back to the implementing workflow (`/flow`, `/tdd`, or `/debug`).
- Do not modify `~/.claude-wyvrn/`.

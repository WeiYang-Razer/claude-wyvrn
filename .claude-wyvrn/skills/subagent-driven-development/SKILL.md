---
name: subagent-dev
description: Execute an implementation plan by dispatching a fresh implementer subagent per task, a task review (spec compliance + code quality) after each, and a broad whole-branch review at the end — the main agent orchestrates, the subagents build. Tasks run sequentially, each in its own fresh subagent. Use for context isolation and a clean review boundary when running a /write-plan plan file task-by-task. Trigger when the user says "use a subagent to", "delegate this", "implement with subagents", or invokes /subagent-dev <plan-file> directly.
---

# subagent-dev

Execute a plan by dispatching a fresh implementer subagent per task, a task review (spec compliance + code quality) after each, and a broad whole-branch review at the end. The main agent orchestrates and owns git; the subagents build. Tasks run sequentially in dependency order.

**Why subagents.** You delegate each task to a fresh agent with isolated context. By constructing exactly the instructions and context it needs — never your session's history — you keep it focused and preserve your own window for coordination. A subagent's exploration and dead-ends never pollute the orchestrator.

**Core principle.** Fresh subagent per task + task review (spec + quality) + broad final review = high quality, fast iteration.

**The orchestrator owns the toolchain.** Implementers write code and tests; they never invoke the project's build or test commands. Every build and every test run is issued by the orchestrator, one config at a time, serially, under the *Build Lock* below. Concurrent toolchain invocations have hard-crashed development machines, and a subagent is exactly the place where a second one appears unnoticed. This costs the loop a round trip per task; the trade is deliberate and not negotiable on speed grounds.

**Narration.** Between tool calls, narrate at most one short line — the ledger and the tool results carry the record.

**Continuous execution.** Do not pause to check in between tasks. Execute all tasks from the plan without stopping. The only reasons to stop: a BLOCKED status you cannot resolve, ambiguity that genuinely prevents progress, or all tasks complete. "Should I continue?" prompts and progress summaries waste the user's time — they asked you to execute the plan, so execute it.

**Standalone by design.** A different execution mode from `/flow`: `/flow` runs inline with no custom subagents; `subagent-dev` deliberately delegates. It is never injected into `/flow`. `/flow` and `/subagent-dev` are Wyvrn's two execution modes.

## When to use

Route by three questions:

1. **Is there a concrete task or a `/write-plan` plan file?** If not — the work is still fuzzy or exploratory — run `/brainstorm` then `/write-plan` first, and come back with a plan.
2. **Do the tasks benefit from context isolation or a clean review boundary?** If not — the change is small, tightly coupled, and reads cleanly done inline — use `/flow` instead (inline, no subagents).
3. **If yes → `/subagent-dev` (this skill).** Tasks run sequentially, each in its own fresh subagent, with a task review gating each one.

What `/subagent-dev` buys you over inline `/flow`:

| | `/flow` (inline) | `/subagent-dev` (delegate) |
|---|---|---|
| Context | One window does everything | Fresh subagent per task — exploration/dead-ends never pollute the orchestrator |
| Review boundary | Self-verify inline | A task-reviewer subagent per task **+** a whole-branch review at the end |
| Best for | Small or tightly-coupled changes | Independent tasks, or when you want a hard review gate |

## The process

Per task, run this cycle:

1. **Dispatch** a fresh implementer subagent (`implementer-prompt.md`) with the task-brief file path, the report file path, scene-setting context, and the task's phase block — RED first, then a second GREEN dispatch after the orchestrator confirms the failure (*Execution mode: TDD*).
2. **Answer questions** if the implementer asks any before starting — provide context and let it proceed.
3. The implementer **works its phase without running anything, commits, self-reviews, writes its report file**, and returns a status; the orchestrator runs the focused test target between and after the phases (*Build Lock*).
4. **Handle the status** (see Handling implementer status). On RED-PENDING, confirm the failure and dispatch the GREEN phase. On DONE, confirm green, then generate the review package and dispatch the task reviewer (`task-reviewer-prompt.md`).
5. **Fix loop:** if the reviewer reports Critical/Important findings, dispatch a fix subagent, then re-review. Log Minor findings to the ledger for the final review.
6. When the reviewer reports spec ✅ and quality approved, **mark the task complete**: append it to the progress ledger AND flip every one of the task's `- [ ]` steps to `- [x]` in the plan file. Then move to the next task.

When all tasks are complete, dispatch one **broad whole-branch review**, apply the `/verify-done` gate, then finalize per gitflow.

## Preconditions

If `~/.claude-wyvrn/VERSION` missing → halt: `Wyvrn harness not installed. Run claude-wyvrn install.`

## Trigger

- Slash: `/subagent-dev <plan-file or task>`
- Natural: "use a subagent to", "delegate this to an agent", "implement this with subagents", "run the plan with subagents"

## Load and decompose

1. **Load context (parallel batch).** If a plan file path is given, read it — its tasks are authoritative for scope, files, and acceptance. Else read `.claude-wyvrn-local/PROJECT.md` (or `README.md`), `ARCHITECTURE.md` if present, and the relevant stack conventions; treat the user's prompt as the task. No code yet.
2. **Decompose.** Plan file → one brief per plan task, in the plan's task order. Free-form task → split into independently implementable units, ordered by dependency: infrastructure (types, interfaces) before logic before integration before consumers. Task numbering is a topological order; execute in numeric order.

## Execution mode: TDD

TDD is preserved, but the red-green cycle is **orchestrator-driven** because implementers may not
invoke the toolchain (see *Build Lock*). The cycle splits across the boundary:

1. A RED-phase implementer dispatch writes the failing test and reports `RED-PENDING`, naming the
   exact test target. It commits the test alone. It does not run it.
2. **Orchestrator runs the focused test target** and confirms it fails for the right reason. A test
   that passes here is a defect: the test does not exercise the new behavior. Send it back.
3. A fresh GREEN-phase implementer dispatch — carrying the RED commit, the focused target, and your
   observed RED output, because it has no memory of the first dispatch — writes the minimal
   implementation and commits. It does not run it.
4. **Orchestrator re-runs the same focused target** and confirms green.
5. Only then does the task proceed to review.

The plan carries the complete code, so the implementer transcribes rather than re-derives. State the
`RED-PENDING` contract and the no-toolchain rule in every dispatch prompt, and fill the template's
`[PHASE_BLOCK]` with the matching phase block from `implementer-prompt.md` (see *Dispatch*). Steps 2
and 4 use the focused target named by the implementer, never the full suite — the full suite runs
once, at the final gate.

## Build Lock

A single, non-negotiable rule: **only the orchestrator touches the toolchain.**

These rules exist because concurrent build/test invocations have hard-crashed development machines.
They are a machine-stability constraint, not a performance preference, and they override every speed
argument in this file.

**Subagents — implementers, fix subagents, and reviewers alike — must NEVER invoke the project's
build or test toolchain** — the `build-command` / `test-command` declared in
`.claude-wyvrn-local/PROJECT.md` — directly or through a wrapper (a build script, an IDE task, a
`Makefile` target that shells out to them). This holds even when the subagent is the
only one running, and even when the command is obviously safe. The rule is absolute because a
conditional rule is one the next dispatch forgets.

**Subagents may still work in parallel on everything else.** Read, Grep, Glob, and Edit are
unrestricted — fan out research and inspection freely. The lock is on the toolchain, not on
concurrency in general.

**The orchestrator holds the lock and runs every build and test:**

- One invocation in flight at a time. Never two builds, never two test runs, never a build and a
  test together.
- One config per invocation. Combined-config convenience flags (e.g. `--all-configs`, a
  comma-separated config list) are prohibited — they fan out internally.
- Each config in the project's `build-configs` is a separate, sequential invocation. Wait for each
  to exit before the next.
- **Sweep stale processes before the first invocation of a run** — the names come from
  `.claude-wyvrn-local/build-lock-processes` (one per line):

  ```powershell
  powershell -NoProfile -ExecutionPolicy Bypass -File "$HOME/.claude-wyvrn/templates/build-lock.ps1" -Sweep
  ```

  The sweep is scoped to this project: it kills only processes this session started or whose command
  line carries this repository's path, and reports what it left alone. A non-empty sweep means a prior
  run did not exit cleanly — say so, and do not trust results that predate it. If the build-lock hook
  refuses this command (BLOCKED), one of *this project's* listed processes is live and the sweep cannot
  run in-session — the hook blocks every Bash and PowerShell call, this one included. Another
  repository's build will not cause this. Stop and ask the user to run the same command from a terminal
  outside Claude Code, adding `-ProjectDir <repo root>`, then retry.
- Confirm the working directory is the repo root before every build or test command. Shell state
  does not persist between tool calls; print it rather than assume it.
- Never background a build or test. A backgrounded run is an invocation you have lost track of,
  which is the state this section exists to prevent.

**Consequences for the loop.** The orchestrator now runs the focused target twice per task (RED,
then GREEN) plus the full suite once at the final gate. That is slower than letting implementers
run their own tests. Accept it. If a task's report claims test output the orchestrator did not
produce, the implementer violated the lock — treat the task as unverified and re-run it yourself.

## Workspace & scripts

All handoffs go through files in `.claude-wyvrn-local/sdd/`, not inline text, so the orchestrator's context stays lean and a run can resume after compaction. Invoke the four scripts via `bash` (so they run under Git Bash on Windows and natively on Unix) from the installed skill dir — the scripts are committed non-executable and call each other the same way:

- `bash ~/.claude-wyvrn/skills/subagent-driven-development/scripts/sdd-workspace` — prints the workspace path, creating it with a self-ignoring `.gitignore` if needed.
- `bash ~/.claude-wyvrn/skills/subagent-driven-development/scripts/task-brief PLAN_FILE N` — writes `task-N-brief.md` and prints the path. The brief carries the task's own text plus the plan-header context that binds it from outside its heading: the `**Tech Stack:**` line (the exact build/test commands the red-green steps need) and the `## Global Constraints` section. Do not re-paste either into the dispatch prompt; the brief already has them.
- `bash ~/.claude-wyvrn/skills/subagent-driven-development/scripts/review-package BASE HEAD` — writes `review-<base7>..<head7>.diff` and prints the path.
- `bash ~/.claude-wyvrn/skills/subagent-driven-development/scripts/branch-base [INTEGRATION_BRANCH]` — prints the commit the current branch was cut from. Resolves the integration branch in order `develop`, `main`, `master`, then the remote default; pass one explicitly to override. Never hardcode `develop` — a repo without it fails `git merge-base` at the final review.

**Script preflight (run once, before Task 1).** An install that copied only `SKILL.md` leaves these scripts missing, and the failure would otherwise surface mid-dispatch after work has already started. Check first:

```bash
sdd=~/.claude-wyvrn/skills/subagent-driven-development
for f in scripts/sdd-workspace scripts/task-brief scripts/review-package scripts/branch-base \
         implementer-prompt.md task-reviewer-prompt.md; do
  [ -f "$sdd/$f" ] || echo "MISSING: $sdd/$f"
done
```

If anything prints, halt: `subagent-dev assets missing from the installed skill. Re-run claude-wyvrn install.` Do not fall back to inline briefs — inline handoff is the cost problem this skill exists to avoid.

## Pre-flight plan review

Before dispatching Task 1, scan the plan once for conflicts:

- tasks that contradict each other or the plan's Global Constraints;
- anything the plan explicitly mandates that the review rubric treats as a defect (a test that asserts nothing, verbatim duplication of a logic block).

Present everything you find to the user as one batched `AskUserQuestion` — each finding beside the plan text that mandates it, asking which governs — before execution begins, not one interrupt per discovery mid-plan. If the scan is clean, proceed without comment. The review loop remains the net for conflicts that only emerge from implementation.

## Model selection

Use the least powerful model that can handle each role, to conserve cost and increase speed.

- **Mechanical implementation tasks** (isolated functions, clear specs, 1–2 files): fast, cheap model. Most tasks are mechanical when the plan is well-specified and carries the code.
- **Integration and judgment tasks** (multi-file coordination, pattern matching, debugging): standard model.
- **Architecture and design tasks:** most capable model. The final whole-branch review is one of these — dispatch it on the most capable model, not the session default.
- **Review tasks:** same judgment, scaled to the diff's size, complexity, and risk. A small mechanical diff does not need the most capable model; a subtle concurrency change does.

**Tier mapping (Agent tool `model` param):** cheapest = `haiku`, standard = `sonnet`, most capable = `opus` (or the session model when it is more capable).

**Always specify the model explicitly when dispatching.** An omitted model inherits your session's model — often the most capable and most expensive — which silently defeats this section.

**Turn count beats token price.** Wall-clock and context cost scale with how many turns a subagent takes, and the cheapest models routinely take 2–3× the turns on multi-step work — costing more overall. Use a mid-tier model as the floor for reviewers and for implementers working from prose. When the task's plan text contains the complete code to write, the implementation is transcription plus the red-green run: use the cheapest tier for that implementer. Single-file mechanical fixes also take the cheapest tier.

**Task complexity signals (implementation):**
- Touches 1–2 files with a complete spec → cheap model
- Touches multiple files with integration concerns → standard model
- Requires design judgment or broad codebase understanding → most capable model

## Dispatch

Dispatch every implementer via `implementer-prompt.md`, passing the brief **path** and the report **path** — never the brief text. Answer any clarifying question before the implementer proceeds. Record the BASE commit (the tip before the task's first dispatch) for each task; the review package and the ledger need it.

**Two implementer dispatches per task, one per phase — each a fresh subagent.** The GREEN dispatch remembers nothing from the RED one. Fill the template's `[PHASE_BLOCK]` with the matching phase block from `implementer-prompt.md`: the RED dispatch gets the RED block; the GREEN dispatch gets the GREEN block with `[RED_COMMIT]` (short SHA + subject), `[TEST_TARGET]`, and `[RED_OUTPUT]` (the decisive lines of your own RED run) filled in. Both dispatches get the same brief and report paths; the task's review package spans both phases' commits from the one recorded BASE.

- **Sequential chain:** dispatch one implementer, review it (below), feed its produced interfaces forward into the next brief, dispatch the next. Use `subagent_type: general-purpose`.
- **Never dispatch multiple implementers into the same working tree in parallel** — they conflict. Tasks run one at a time. Independent research-only units may fan out (use `Explore`), but implementers do not.

### Review each result

For every returned task, before accepting it:

1. **Task review.** Run `review-package BASE HEAD` (BASE = the task's recorded base, HEAD = its tip) and dispatch a task-reviewer subagent via `task-reviewer-prompt.md`, passing the brief, report, and review-package paths plus the binding constraints. The reviewer reads the diff and gates spec compliance + code quality. Reviewers never invoke the toolchain (*Build Lock*); the test evidence is the orchestrator's own RED and GREEN output from the task's focused target, which you pass to the reviewer in the template's `[TEST_EVIDENCE]` slot.
2. **Resolve.** Dispatch a fix subagent for Critical/Important findings, then re-review; never accept on the report alone. Log Minor findings to the ledger for the final review. When spec ✅ and quality approved, append the task to the ledger and flip the task's `- [ ]` steps to `- [x]` in the plan file.

## Handling implementer status

Implementer subagents report one of five statuses. Handle each appropriately:

**RED-PENDING:** The RED phase returned. Run the named focused test target yourself and confirm it fails for the right reason — a pass here means the test does not exercise the new behavior; send it back. On the expected failure, dispatch the GREEN-phase implementer carrying the RED commit, the target, and your observed failing output.

**DONE:** The GREEN phase returned. Run the focused target and confirm green, then generate the review package (`review-package BASE HEAD` — BASE is the commit you recorded before the RED dispatch, never `HEAD~1`, which silently drops all but the last commit of a multi-commit task), and dispatch the task reviewer with the printed path.

**DONE_WITH_CONCERNS:** The implementer completed the work but flagged doubts. Read the concerns first. If they touch correctness or scope, address them before review. If they are observations (e.g., "this file is getting large"), note them and proceed to review.

**NEEDS_CONTEXT:** The implementer needs information that wasn't provided. Provide the missing context and re-dispatch.

**BLOCKED:** The implementer cannot complete the task. Assess the blocker:
1. Context problem → provide more context and re-dispatch with the same model.
2. Needs more reasoning → re-dispatch with a more capable model.
3. Task too large → break it into smaller pieces and re-brief.
4. The plan itself is wrong → escalate to the user.

**Never** ignore an escalation or force the same model to retry without changes. If the implementer said it's stuck, something needs to change.

## Handling reviewer ⚠️ items

The task reviewer may report "⚠️ Cannot verify from diff" items — requirements that live in unchanged code or span tasks. These do not block the rest of the review, but you must resolve each one yourself before marking the task complete: you hold the plan and cross-task context the reviewer lacks. If you confirm an item is a real gap, treat it as a failed spec review — send it back to the implementer and re-review.

## Constructing reviewer prompts

Per-task reviews are task-scoped gates. The broad review happens once, at the final whole-branch review. When you fill a reviewer template:

- Do not add open-ended directives like "check all uses" or "run race tests if useful" without a concrete, task-specific reason.
- Never ask a reviewer to run tests or a build. Reviewers are bound by the *Build Lock*. Hand it the orchestrator's RED/GREEN output as evidence instead, in the template's `[TEST_EVIDENCE]` slot.
- Do not pre-judge findings for the reviewer — never instruct it to ignore or not flag a specific issue. If you believe a finding would be a false positive, let the reviewer raise it and adjudicate it in the review loop. If the prompt you are writing contains "do not flag," "don't treat X as a defect," "at most Minor," or "the plan chose" — stop: you are pre-judging.
- The binding-constraints block you hand the reviewer is its attention lens. Copy the binding requirements verbatim from the plan header (exact build/test commands from Tech Stack, invariants from Architecture, the Global Constraints section) and the spec: exact values, exact formats, and stated relationships between components ("same layout as X", "matches Y"). The reviewer template already carries the process rules (YAGNI, test hygiene, review method) — the constraints block is for what THIS project's spec demands.
- Hand the reviewer its diff as a file: run `review-package BASE HEAD` and pass the printed path. The output never enters your own context, and the reviewer sees the commit list, stat summary, and full diff with context in one Read call. Use the BASE you recorded before dispatching — never `HEAD~1`.
- A dispatch prompt describes one task, not the session's history. Do not paste accumulated prior-task summaries ("state after Tasks 1–3") into later dispatches. A fresh subagent needs its task, the interfaces it touches, and the binding constraints. Nothing else.
- Dispatch fix subagents for Critical and Important findings. Record Minor findings in the progress ledger as you go, and point the final whole-branch review at that list so it can triage which must be fixed before merge. A roll-up nobody reads is a silent discard.
- A finding labeled plan-mandated — or any finding that conflicts with what the plan's text requires — is the user's decision, like any plan contradiction: present the finding and the plan text, ask which governs. Do not dismiss the finding because the plan mandates it, and do not dispatch a fix that contradicts the plan without asking.
- The final whole-branch review gets a package too: run `review-package "$(bash ~/.claude-wyvrn/skills/subagent-driven-development/scripts/branch-base)" HEAD` and include the printed path in the final review dispatch.
- Every fix dispatch carries the implementer contract, *Build Lock* included: the fix subagent writes the fix and names the test target covering it, but does not run anything. **The orchestrator runs that focused target after the fix returns** and before re-dispatching the reviewer. Name the covering test files — a one-line fix does not need the whole suite.
- If the final whole-branch review returns findings, dispatch ONE fix subagent with the complete findings list — not one fixer per finding. Per-finding fixers each rebuild context, and each one forces the orchestrator through another serial build-test cycle; the cost adds up fast.

## File handoffs

Everything you paste into a dispatch prompt — and everything a subagent prints back — stays resident in your context for the rest of the session and is re-read on every later turn. Hand artifacts over as files:

- **Task brief:** before dispatching an implementer, run `task-brief PLAN_FILE N` — it extracts the task's full text to a uniquely named file and prints the path. Your dispatch should contain: (1) one line on where this task fits; (2) the brief path, introduced as "read this first — it is your requirements, with the exact values to use verbatim"; (3) interfaces and decisions from earlier tasks the brief cannot know; (4) your resolution of any ambiguity you noticed in the brief; (5) the report-file path and report contract. Exact values (numbers, magic strings, signatures, test cases) appear only in the brief.
- **Report file:** name the implementer's report after the brief (`…/task-N-brief.md` → `…/task-N-report.md`) and put it in the dispatch prompt. The implementer writes the full report there and returns only status, commits, the focused test target (never test results), and concerns.
- **Reviewer inputs:** the task reviewer gets three paths — the same brief file, the report file, and the review package — plus the binding constraints that bind the task.
- Fix dispatches append their fix report — naming the covering test target, never test output — to the same report file and return a short summary; the orchestrator runs that target, and re-reviews read the updated file.

## Durable progress

Conversation memory does not survive compaction. Controllers that lost their place have re-dispatched entire completed task sequences — an expensive failure. Track progress in a ledger file, not only in todos. The ledger lives at `.claude-wyvrn-local/sdd/progress.md`.

- At skill start, check for a ledger: `cat "$(git rev-parse --show-toplevel)/.claude-wyvrn-local/sdd/progress.md"`. Tasks listed there as complete are DONE — do not re-dispatch them; resume at the first task not marked complete.
- When a task's review comes back clean, append one line in the same message as your other bookkeeping: `Task N: complete (commits <base7>..<head7>, review clean)` — and in the same message, flip that task's checkboxes to `- [x]` in the plan file. The plan file's checkboxes are the user-visible progress; the ledger is the recovery map. A task whose boxes are still `- [ ]` after its commit landed is a bookkeeping bug.
- The ledger is your recovery map: the commits it names exist in git even when your context no longer remembers creating them. After compaction, trust the ledger and `git log` over your own recollection.
- The workspace is git-ignored scratch (a self-ignoring `.gitignore`); `git clean -fdx` will destroy the ledger. If that happens, recover from `git log`.

## Integrate + finalize

1. Resolve any cross-task conflicts in the main thread.
2. **Whole-branch review.** Run `review-package "$(bash ~/.claude-wyvrn/skills/subagent-driven-development/scripts/branch-base)" HEAD` and dispatch one broad task-reviewer subagent (most-capable model) over the full branch diff against the plan's goals and the logged Minor findings — the integration-level pass that per-task reviews cannot give. If it returns findings, dispatch ONE fix subagent with the complete list.
3. Apply the `/verify-done` evidence gate before declaring complete. This is the one place the orchestrator exercises the integrated result end-to-end — run the full affected test set once here — serially, one invocation at a time, per the *Build Lock*. If the plan file has a `## Final verification` section (full-suite run), execute it here and flip its checkbox; it runs once at this gate, never per task.
4. Gitflow/commit/push are the orchestrator's job and stay gated — do not commit or push unless the user asked (mirrors `/flow` Step 10). On approval, finalize per `gitflow.md`: PR the feature branch into the integration branch (`develop` per `gitflow.md`, or whatever `branch-base` resolved for a repo without one).

## Prompt templates

- [implementer-prompt.md](implementer-prompt.md) — dispatch an implementer subagent.
- [task-reviewer-prompt.md](task-reviewer-prompt.md) — dispatch a task reviewer subagent (spec compliance + code quality).
- Final whole-branch review: reuse `task-reviewer-prompt.md` scoped to the whole-branch package (most-capable model), then the `/verify-done` gate.

## Example workflow

```
You: I'm using /subagent-dev to execute this plan.

[Read plan file once: .claude-wyvrn-local/plans/2026-...-feature-plan.md]
[Pre-flight scan: clean. Create todos + ledger for all tasks.]

Task 1: Hook installation script
[task-brief PLAN 1 → path; dispatch RED-phase implementer with brief + report paths + context]
Implementer: "Before I begin — user or system level for the hook?"
You: "User level (~/.config/…)."
Implementer: RED-PENDING — failing test committed, target: install-hook suite.
[Run the target: fails as expected. Dispatch GREEN-phase implementer with RED commit + output]
Implementer: DONE — install-hook implemented, self-review added --force, committed.
[Run the target: green. review-package BASE HEAD → path; dispatch task reviewer with RED/GREEN output]
Task reviewer: Spec ✅ — all requirements met, nothing extra. Issues: none. Approved.
[Append "Task 1: complete (…, review clean)" to the ledger; flip Task 1's steps to [x] in the plan file]

Task 2: Recovery modes
[task-brief PLAN 2 → path; RED-phase dispatch → RED-PENDING; run target: red. GREEN-phase dispatch]
Implementer: DONE — verify/repair modes, committed.
[Run target: green. review-package → path; dispatch task reviewer]
Task reviewer: Spec ❌ — Missing progress reporting; Extra --json flag. Important: magic number 100.
[Dispatch ONE fix subagent with all findings]
Fixer: removed --json, added progress reporting, extracted PROGRESS_INTERVAL. Covering target: recovery suite.
[Run covering target: green. Re-review] Task reviewer: Spec ✅. Approved.
[Append "Task 2: complete" to the ledger; flip Task 2's steps to [x] in the plan file]

...

[After all tasks: review-package MERGE_BASE HEAD → path; dispatch final whole-branch reviewer (most capable)]
Final reviewer: All requirements met, ready to merge.
[/verify-done gate → green. Offer to PR into develop.]
```

## Red flags

**Never:**
- Start implementation on `master` or `develop` without explicit user consent — work on a `feature/<INITIALS>_<name>` branch (`gitflow.md`).
- Skip task review, or accept a report missing either verdict (spec compliance AND task quality are both required).
- Proceed with unfixed Critical/Important issues.
- Dispatch multiple implementers in parallel (conflicts) — tasks run one at a time.
- Make a subagent read the whole plan file — hand it its task brief (`task-brief`) instead.
- Skip scene-setting context (the subagent needs to understand where the task fits).
- Ignore subagent questions (answer before letting them proceed).
- Accept "close enough" on spec compliance (reviewer found spec issues = not done).
- Skip review loops (reviewer found issues = implementer fixes = review again).
- Let implementer self-review replace actual review (both are needed).
- Let a subagent invoke the project's build or test toolchain or any wrapper around it (build scripts, IDE tasks). The orchestrator runs every build and test (*Build Lock*).
- Run two toolchain invocations concurrently, combine configs in one command (e.g. `--all-configs`), or background a build or test run.
- Start a suite without sweeping the stale processes named in `.claude-wyvrn-local/build-lock-processes` and confirming the working directory.
- Accept a task report containing test output the orchestrator did not produce — that is a lock violation; treat the task as unverified.
- Tell a reviewer what not to flag, or pre-rate a finding's severity in the dispatch prompt.
- Dispatch a task reviewer without a diff file — generate it first (`review-package BASE HEAD`) and name the printed path.
- Move to the next task while the review has open Critical/Important issues.
- Re-dispatch a task the progress ledger already marks complete — check the ledger (and `git log`) after any compaction or resume.
- Mark a task complete in the ledger without also flipping its `- [ ]` steps to `- [x]` in the plan file.

**If a subagent asks questions:** answer clearly and completely, provide context, don't rush them into implementation.

**If a reviewer finds issues:** the implementer (same subagent) fixes them; the reviewer reviews again; repeat until approved; don't skip the re-review.

**If a subagent fails a task:** dispatch a fix subagent with specific instructions; don't try to fix manually (context pollution).

## Stop conditions

- A subagent reports it could not complete → read its findings, refine the brief, re-dispatch. Do not paper over the gap.
- The same task fails verification repeatedly → halt and surface to the user with the diffs and failures.
- User interrupts → summarize which tasks are verified, which are pending, and what remains.

## Constraints

- Never accept a subagent's work without a task-reviewer subagent gating the diff, and never accept it without the orchestrator's own RED/GREEN output for that task's focused target.
- Subagents never invoke the project's build or test toolchain, or any wrapper around it. The orchestrator issues every build and test, one config at a time, serially, after sweeping stale processes (*Build Lock*). Read/Edit/Grep parallelism is unaffected.
- Briefs must be fully self-contained — subagents cannot see this conversation.
- Hand off briefs, reports, and review packages as **file paths**, never inline text; every task passes through a task-reviewer subagent before it is accepted.
- Do not dispatch implementers in parallel — tasks run sequentially in one working tree.
- Do not commit or push unless the user explicitly asks. Executing a plan file counts as asking for the plan's own per-task commit steps; pushing still requires an explicit ask.
- Every commit — the orchestrator's and every subagent's — uses a single `-m` message per `gitflow.md` §3. Do NOT append a `Co-Authored-By` trailer, a "Generated with" footer, or any other trailer.
- **POSIX syntax in Bash.** Never use PowerShell here-string syntax (`@'...'@`, `@"..."@`) in the Bash tool — it leaks stray `@` characters. Multi-line strings and commit messages use POSIX constructs (heredoc, or multiple `-m` flags). This binds the orchestrator and every dispatched subagent.
- Source code — the orchestrator's and every subagent's — plus code blocks inside generated markdown and every commit message must be strictly 7-bit ASCII: no em-dashes, smart quotes, or other non-ASCII characters. Markdown prose may use them.
- Do not modify `~/.claude-wyvrn/`.

## Integration

**Required workflow skills:**
- `/using-git-worktrees` — optional isolated workspace for the whole run.
- `/write-plan` — creates the plan this skill executes.
- `/verify-done` (verification-before-completion) — the final evidence gate.
- `gitflow.md` — branch, commit, and PR-into-`develop` protocol for finalizing.

**Subagents should use:**
- `/test-driven-development` — every task runs the red-green cycle.

**Alternative:**
- `/flow` — inline, same-context execution when delegation isn't warranted (small or tightly-coupled work).

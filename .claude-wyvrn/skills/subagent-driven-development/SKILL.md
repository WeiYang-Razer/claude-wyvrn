---
name: subagent-dev
description: Execute an implementation plan by dispatching a fresh implementer subagent per task, a task review (spec compliance + code quality) after each, and a broad whole-branch review at the end — the main agent orchestrates and verifies, subagents build. Use for context isolation, a clean review boundary, or to run a /write-plan plan file task-by-task (or wave-by-wave in parallel worktrees when the plan carries an Execution schedule). Trigger when the user says "use a subagent to", "delegate this", "implement with subagents", or invokes /subagent-dev <plan-file> directly.
---

# subagent-dev

Execute a plan by dispatching a fresh implementer subagent per task, a task review (spec compliance + code quality) after each, and a broad whole-branch review at the end. The main agent orchestrates, verifies, and owns git; the subagents build.

**Why subagents.** You delegate each task to a fresh agent with isolated context. By constructing exactly the instructions and context it needs — never your session's history — you keep it focused and preserve your own window for coordination. A subagent's exploration and dead-ends never pollute the orchestrator.

**Core principle.** Fresh subagent per task + task review (spec + quality) + broad final review = high quality, fast iteration.

**Narration.** Between tool calls, narrate at most one short line — the ledger and the tool results carry the record.

**Continuous execution.** Do not pause to check in between tasks. Execute all tasks from the plan without stopping. The only reasons to stop: a BLOCKED status you cannot resolve, ambiguity that genuinely prevents progress, or all tasks complete. "Should I continue?" prompts and progress summaries waste the user's time — they asked you to execute the plan, so execute it.

**Standalone by design.** A different execution mode from `/flow`: `/flow` runs inline with no custom subagents; `subagent-dev` deliberately delegates. It is never injected into `/flow`. `/flow` and `/subagent-dev` are Wyvrn's two execution modes — there is no separate parallel-session skill.

## When to use

Route by three questions:

1. **Is there a concrete task or a `/write-plan` plan file?** If not — the work is still fuzzy or exploratory — run `/brainstorm` then `/write-plan` first, and come back with a plan.
2. **Do the tasks benefit from context isolation, a clean review boundary, or parallel execution?** If not — the change is small, tightly coupled, and reads cleanly done inline — use `/flow` instead (inline, no subagents).
3. **If yes → `/subagent-dev` (this skill).** A plan carrying an `## Execution schedule` with multi-task waves runs each wave as worktree-isolated parallel agents; otherwise tasks run sequentially, each in its own fresh subagent.

What `/subagent-dev` buys you over inline `/flow`:

| | `/flow` (inline) | `/subagent-dev` (delegate) |
|---|---|---|
| Context | One window does everything | Fresh subagent per task — exploration/dead-ends never pollute the orchestrator |
| Review boundary | Self-verify inline | Orchestrator verify **+** a task-reviewer subagent per task, **+** a whole-branch review at the end |
| Parallelism | Sequential | Wave-parallel in worktrees when the plan's schedule allows |
| Best for | Small or tightly-coupled changes | Independent tasks, or when you want a hard review gate |

## The process

Per task, run this cycle:

1. **Dispatch** a fresh implementer subagent (`implementer-prompt.md`) with the task-brief file path, the report file path, and scene-setting context.
2. **Answer questions** if the implementer asks any before starting — provide context and let it proceed.
3. The implementer **implements, tests, commits, self-reviews, writes its report file**, and returns a status.
4. **Handle the status** (see Handling implementer status). On DONE, write the review package and dispatch the task reviewer (`task-reviewer-prompt.md`).
5. **Fix loop:** if the reviewer reports Critical/Important findings, dispatch a fix subagent, then re-review. Log Minor findings to the ledger for the final review.
6. When the reviewer reports spec ✅ and quality approved, **mark the task complete**: append it to the progress ledger AND flip every one of the task's `- [ ]` steps to `- [x]` in the plan file. Then move to the next task (or wave).

When all tasks are complete, dispatch one **broad whole-branch review**, apply the `/verify-done` gate, then finalize per gitflow.

## Preconditions

If `~/.claude-wyvrn/VERSION` missing → halt: `Wyvrn harness not installed. Run claude-wyvrn install.`

## Trigger

- Slash: `/subagent-dev <plan-file or task>`
- Natural: "use a subagent to", "delegate this to an agent", "implement this with subagents", "run the plan with subagents"

## Load, decompose, and schedule

1. **Load context (parallel batch).** If a plan file path is given, read it — its tasks are authoritative for scope, files, and acceptance. Else read `.claude-wyvrn-local/PROJECT.md` (or `README.md`), `ARCHITECTURE.md` if present, and the relevant stack conventions; treat the user's prompt as the task. No code yet.
2. **Decompose.** Plan file → one brief per plan task. Free-form task → split into independently implementable units, ordered by dependency: infrastructure (types, interfaces) before logic before integration before consumers. Mark each task's dependencies. Tasks with no unmet dependency on a sibling are parallel-eligible; the rest are sequential.
3. **Adopt the schedule.** If the plan file contains an `## Execution schedule` section, adopt it verbatim — its waves are authoritative for what may run concurrently. Do not re-derive or second-guess it; if it is visibly wrong (two same-wave tasks touch the same file, a task's `Depends on:` names a task in the same or a later wave), halt and surface the plan defect instead of silently re-serializing. A plan without a schedule, or a free-form task, uses the dependency marking above.

## Execution mode: apply vs TDD

Check the plan's executor directive before dispatching anything:

- **Apply-mode** (the directive declares the plan code-complete — every `/write-plan` plan does): implementers transcribe the brief's code exactly, adapt only where the codebase differs from the brief's assumptions, build once, run the task's tests once. No red-phase, no live TDD, no re-derivation. State the mode explicitly in every dispatch prompt.
- **TDD-mode** (free-form tasks, or briefs that specify behavior in prose without complete code): implementers follow `/test-driven-development` — failing test first, then implement.

## Workspace & scripts

All handoffs go through files in `.claude-wyvrn-local/sdd/`, not inline text, so the orchestrator's context stays lean and a run can resume after compaction. Invoke the three scripts via `bash` (so they run under Git Bash on Windows and natively on Unix) from the installed skill dir:

- `bash ~/.claude-wyvrn/skills/subagent-driven-development/scripts/sdd-workspace` — prints the workspace path, creating it with a self-ignoring `.gitignore` if needed.
- `bash ~/.claude-wyvrn/skills/subagent-driven-development/scripts/task-brief PLAN_FILE N` — writes `task-N-brief.md`, the extracted task text, and prints the path.
- `bash ~/.claude-wyvrn/skills/subagent-driven-development/scripts/review-package BASE HEAD` — writes `review-<base7>..<head7>.diff` and prints the path.

## Pre-flight plan review

Before dispatching Task 1, scan the plan once for conflicts:

- tasks that contradict each other or the plan's binding constraints;
- anything the plan explicitly mandates that the review rubric treats as a defect (a test that asserts nothing, verbatim duplication of a logic block).

Present everything you find to the user as one batched `AskUserQuestion` — each finding beside the plan text that mandates it, asking which governs — before execution begins, not one interrupt per discovery mid-plan. If the scan is clean, proceed without comment. The review loop remains the net for conflicts that only emerge from implementation.

## Model selection

Use the least powerful model that can handle each role, to conserve cost and increase speed.

- **Mechanical implementation tasks** (isolated functions, clear specs, 1–2 files): fast, cheap model. Most tasks are mechanical when the plan is well-specified.
- **Integration and judgment tasks** (multi-file coordination, pattern matching, debugging): standard model.
- **Architecture and design tasks:** most capable model. The final whole-branch review is one of these — dispatch it on the most capable model, not the session default.
- **Review tasks:** same judgment, scaled to the diff's size, complexity, and risk. A small mechanical diff does not need the most capable model; a subtle concurrency change does. **Apply-mode per-task reviews are always the cheapest tier** — the gate is a mechanical diff-vs-brief transcription check. The final whole-branch review stays most-capable regardless of mode.

**Tier mapping (Agent tool `model` param):** cheapest = `haiku`, standard = `sonnet`, most capable = `opus` (or the session model when it is more capable).

**Always specify the model explicitly when dispatching.** An omitted model inherits your session's model — often the most capable and most expensive — which silently defeats this section.

**Turn count beats token price.** Wall-clock and context cost scale with how many turns a subagent takes, and the cheapest models routinely take 2–3× the turns on multi-step work — costing more overall. Use a mid-tier model as the floor for reviewers of TDD-mode work and for implementers working from prose; apply-mode reviews are exempt (mechanical transcription check). **Apply-mode briefs are always the cheapest tier — no exceptions.** The implementation is transcription plus one build+test; the capable model already paid the design cost at plan time. That split is the point of code-complete plans. Single-file mechanical fixes also take the cheapest tier.

**Task complexity signals (implementation):**
- Touches 1–2 files with a complete spec → cheap model
- Touches multiple files with integration concerns → standard model
- Requires design judgment or broad codebase understanding → most capable model

## Dispatch

Dispatch every implementer via `implementer-prompt.md`, passing the brief **path** and the report **path** — never the brief text. Answer any clarifying question before the implementer proceeds. Record the BASE commit (the tip before dispatch) for each task; the review package and the ledger need it.

- **Sequential chain:** dispatch one subagent, verify + review (below), feed its interfaces forward into the next brief, dispatch the next. Use `subagent_type: general-purpose`.
- **Parallel-eligible set (no schedule):** independent research-only units may fan out (use `Explore`); independent implementers must NOT share a working tree — either run them sequentially or isolate them in worktrees (wave mode).
- **Wave dispatch (plan file with an Execution schedule):** process waves strictly in order.
  1. For the current wave, dispatch every task in a single message — one `Agent` call per task with `isolation: worktree` and `subagent_type: general-purpose`. Generate each brief with `task-brief` in the main tree and pass its **absolute** path; the worktree agent reads it regardless of its cwd. Each brief carries the task's full plan steps *including its commit step*: the agent executes in the plan's mode (apply-mode for code-complete plans) and commits on its own worktree branch.
  2. A single-task wave may skip the worktree and run in the main working tree — its commit lands directly on the plan branch.
  3. As each agent returns, verify + review it (below) against its worktree branch (read the branch diff, run the task's tests in that worktree).
  4. When every task in the wave is verified, merge the wave's task branches into the plan branch in task-number order. A merge conflict here means the plan's file-disjointness claim was wrong — halt and surface it as a plan defect; do not hand-resolve silently.
  5. **Wave gate:** on the merged plan branch, run the full build plus the affected tests of every task in the wave. Green unlocks the next wave. On failure, diagnose on the merged tree and either fix forward or re-dispatch the offending task with corrective notes, then re-run the gate.
  6. Remove merged task worktrees and branches before starting the next wave.

Never dispatch interdependent tasks in parallel — a later task built on a sibling's not-yet-verified output will drift. Parallel dispatch is allowed only within one wave of the plan's schedule.

### Verify + review each result (trust but verify)

For every returned task, before accepting it:

1. **Orchestrator verify.** Re-read the **actual diff** for the files the brief named — do not rely on the report. Run the affected tests yourself; confirm pass. Confirm the change matches the brief and conventions and stayed inside its file scope.
2. **Task review.** Run `review-package BASE HEAD` (BASE = the task's recorded base, HEAD = its tip) and dispatch a task-reviewer subagent via `task-reviewer-prompt.md`, passing the brief, report, and review-package paths plus the binding constraints. It gates spec compliance + code quality.
3. **Resolve.** Dispatch a fix subagent for Critical/Important findings, then re-review; never accept on the report alone. Log Minor findings to the ledger for the final review. When spec ✅ and quality approved, append the task to the ledger and flip the task's `- [ ]` steps to `- [x]` in the plan file (main working tree — worktree agents never touch the plan file; checkbox updates are the orchestrator's job).

## Handling implementer status

Implementer subagents report one of four statuses. Handle each appropriately:

**DONE:** Generate the review package (`review-package BASE HEAD` — BASE is the commit you recorded before dispatching, never `HEAD~1`, which silently drops all but the last commit of a multi-commit task), then dispatch the task reviewer with the printed path.

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
- Do not ask a reviewer to re-run tests the implementer already ran on the same code — the implementer's report carries the test evidence.
- Do not pre-judge findings for the reviewer — never instruct it to ignore or not flag a specific issue. If you believe a finding would be a false positive, let the reviewer raise it and adjudicate it in the review loop. If the prompt you are writing contains "do not flag," "don't treat X as a defect," "at most Minor," or "the plan chose" — stop: you are pre-judging.
- The binding-constraints block you hand the reviewer is its attention lens. Copy the binding requirements verbatim from the plan header (exact build/test commands from Tech Stack, invariants from Architecture) and the spec: exact values, exact formats, and stated relationships between components ("same layout as X", "matches Y"). The reviewer template already carries the process rules (YAGNI, test hygiene, review method) — the constraints block is for what THIS project's spec demands.
- Hand the reviewer its diff as a file: run `review-package BASE HEAD` and pass the printed path. The output never enters your own context, and the reviewer sees the commit list, stat summary, and full diff with context in one Read call. Use the BASE you recorded before dispatching — never `HEAD~1`.
- A dispatch prompt describes one task, not the session's history. Do not paste accumulated prior-task summaries ("state after Tasks 1–3") into later dispatches. A fresh subagent needs its task, the interfaces it touches, and the binding constraints. Nothing else.
- Dispatch fix subagents for Critical and Important findings. Record Minor findings in the progress ledger as you go, and point the final whole-branch review at that list so it can triage which must be fixed before merge. A roll-up nobody reads is a silent discard.
- A finding labeled plan-mandated — or any finding that conflicts with what the plan's text requires — is the user's decision, like any plan contradiction: present the finding and the plan text, ask which governs. Do not dismiss the finding because the plan mandates it, and do not dispatch a fix that contradicts the plan without asking.
- The final whole-branch review gets a package too: run `review-package MERGE_BASE HEAD` (MERGE_BASE = the commit the branch started from, e.g. `git merge-base develop HEAD`) and include the printed path in the final review dispatch.
- Every fix dispatch carries the implementer contract: the fix subagent re-runs the tests covering its change and reports the results. Name the covering test files — a one-line fix does not need the whole suite. Before re-dispatching the reviewer, confirm the fix report contains the covering tests, the command run, and the output.
- If the final whole-branch review returns findings, dispatch ONE fix subagent with the complete findings list — not one fixer per finding. Per-finding fixers each rebuild context and re-run suites; the cost adds up fast.

## File handoffs

Everything you paste into a dispatch prompt — and everything a subagent prints back — stays resident in your context for the rest of the session and is re-read on every later turn. Hand artifacts over as files:

- **Task brief:** before dispatching an implementer, run `task-brief PLAN_FILE N` — it extracts the task's full text to a uniquely named file and prints the path. Your dispatch should contain: (1) one line on where this task fits; (2) the brief path, introduced as "read this first — it is your requirements, with the exact values to use verbatim"; (3) interfaces and decisions from earlier tasks the brief cannot know; (4) your resolution of any ambiguity you noticed in the brief; (5) the report-file path and report contract. Exact values (numbers, magic strings, signatures, test cases) appear only in the brief.
- **Report file:** name the implementer's report after the brief (`…/task-N-brief.md` → `…/task-N-report.md`) and put it in the dispatch prompt. The implementer writes the full report there and returns only status, commits, a one-line test summary, and concerns.
- **Reviewer inputs:** the task reviewer gets three paths — the same brief file, the report file, and the review package — plus the binding constraints that bind the task.
- Fix dispatches append their fix report (with test results) to the same report file and return a short summary; re-reviews read the updated file.

## Durable progress

Conversation memory does not survive compaction. Controllers that lost their place have re-dispatched entire completed task sequences — an expensive failure. Track progress in a ledger file, not only in todos. The ledger lives at `.claude-wyvrn-local/sdd/progress.md`.

- At skill start, check for a ledger: `cat "$(git rev-parse --show-toplevel)/.claude-wyvrn-local/sdd/progress.md"`. Tasks listed there as complete are DONE — do not re-dispatch them; resume at the first task not marked complete.
- When a task's review comes back clean, append one line in the same message as your other bookkeeping: `Task N: complete (commits <base7>..<head7>, review clean)` — and in the same message, flip that task's checkboxes to `- [x]` in the plan file. The plan file's checkboxes are the user-visible progress; the ledger is the recovery map. A task whose boxes are still `- [ ]` after its commit landed is a bookkeeping bug.
- The ledger is your recovery map: the commits it names exist in git even when your context no longer remembers creating them. After compaction, trust the ledger and `git log` over your own recollection.
- The workspace is git-ignored scratch (a self-ignoring `.gitignore`); `git clean -fdx` will destroy the ledger. If that happens, recover from `git log`.

## Integrate + finalize

1. Resolve any cross-task conflicts in the main thread. (Wave mode: conflicts are impossible by construction — same-wave tasks have disjoint file sets. If one appears anyway, treat it as a plan defect, not something to hand-resolve.)
2. Run the full affected test set once, in parallel where independent.
3. **Whole-branch review.** Run `review-package $(git merge-base develop HEAD) HEAD` and dispatch one broad task-reviewer subagent (most-capable model) over the full branch diff against the plan's goals and the logged Minor findings — the integration-level pass that per-task reviews cannot give. If it returns findings, dispatch ONE fix subagent with the complete list.
4. Apply the `/verify-done` evidence gate before declaring complete.
5. Gitflow/commit/push are the orchestrator's job and stay gated — do not commit or push unless the user asked (mirrors `/flow` Step 10). On approval, finalize per `gitflow.md`: PR the feature branch into `develop`.

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
[task-brief PLAN 1 → path; dispatch implementer with brief + report paths + context]
Implementer: "Before I begin — user or system level for the hook?"
You: "User level (~/.config/…)."
Implementer: DONE — install-hook implemented, 5/5 tests passing, self-review added --force, committed.
[review-package BASE HEAD → path; dispatch task reviewer]
Task reviewer: Spec ✅ — all requirements met, nothing extra. Issues: none. Approved.
[Append "Task 1: complete (…, review clean)" to the ledger; flip Task 1's steps to [x] in the plan file]

Task 2: Recovery modes
[task-brief PLAN 2 → path; dispatch implementer]
Implementer: DONE — verify/repair modes, 8/8 passing, committed.
[review-package → path; dispatch task reviewer]
Task reviewer: Spec ❌ — Missing progress reporting; Extra --json flag. Important: magic number 100.
[Dispatch ONE fix subagent with all findings]
Fixer: removed --json, added progress reporting, extracted PROGRESS_INTERVAL. Tests re-run, passing.
[Re-review] Task reviewer: Spec ✅. Approved.
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
- Dispatch multiple implementers into the **same working tree** in parallel (conflicts). Parallel implementers are allowed only in wave mode, each isolated in its own worktree.
- Make a subagent read the whole plan file — hand it its task brief (`task-brief`) instead.
- Skip scene-setting context (the subagent needs to understand where the task fits).
- Ignore subagent questions (answer before letting them proceed).
- Accept "close enough" on spec compliance (reviewer found spec issues = not done).
- Skip review loops (reviewer found issues = implementer fixes = review again).
- Let implementer self-review replace actual review (both are needed).
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

- Never accept a subagent's work without independently verifying the actual diff and running the tests (trust but verify).
- Briefs must be fully self-contained — subagents cannot see this conversation.
- Hand off briefs, reports, and review packages as **file paths**, never inline text; every task passes through a task-reviewer subagent before it is accepted.
- Do not dispatch interdependent tasks in parallel. Parallel dispatch only within a single wave of the plan's Execution schedule, each task worktree-isolated.
- In wave mode: never merge an unverified task branch, and never start wave K+1 before wave K's gate is green.
- Do not commit or push unless the user explicitly asks. Executing a plan file counts as asking for the plan's own per-task commit steps; pushing still requires an explicit ask.
- Every commit — the orchestrator's and every subagent's — uses a single `-m` message per `gitflow.md` §3. Do NOT append a `Co-Authored-By` trailer, a "Generated with" footer, or any other trailer.
- Do not modify `~/.claude-wyvrn/`.

## Integration

**Required workflow skills:**
- `/using-git-worktrees` — isolated workspace (creates one, or the per-wave worktrees).
- `/write-plan` — creates the plan this skill executes.
- `/verify-done` (verification-before-completion) — the final evidence gate.
- `gitflow.md` — branch, commit, and PR-into-`develop` protocol for finalizing.

**Subagents should use:**
- `/test-driven-development` — TDD-mode briefs only (prose spec, no complete code). Apply-mode briefs skip the red-phase by design.

**Alternative:**
- `/flow` — inline, same-context execution when delegation isn't warranted (small or tightly-coupled work).

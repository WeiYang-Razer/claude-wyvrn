---
name: write-plan
description: Break a feature or task into a sequence of atomic tasks, each decomposed into numbered checkbox steps with step-level TDD (failing test → implement → passing test), exact file paths, complete change descriptions, explicit git add+commit commands, and per-task dependency metadata rolled up into a wave-based execution schedule so independent tasks can be dispatched to parallel agents. Produces a reviewable plan file in .claude-wyvrn-local/plans/. Trigger when the user says "write a plan for", "plan this out", "break this into tasks", or invokes /write-plan directly.
---

# write-plan

Decomposes a feature into a concrete, reviewable plan whose tasks an agentic worker can execute step-by-step. Each task is broken into atomic, checkboxed steps; each executable-code task follows red-green TDD; every task ends in a self-contained commit so the work is reversible at task granularity. The output is a plan file in `.claude-wyvrn-local/plans/` — the same directory `/flow` already retrieves for past-mistake context.

**Standalone by design.** This skill works on its own. If an approved spec exists in `.claude-wyvrn-local/specs/`, it is used as authoritative input. If no spec exists, the plan is drafted directly from the user's prompt + project context. `/brainstorm` is never required.

**Hand-off target.** The plan is written to be executed by `/subagent-dev` (subagent-driven-development) or `/flow`, task-by-task — or wave-by-wave in parallel when the Execution schedule allows. The plan header names this explicitly so the executor knows how to run it.

## Execution principles

- Parallelize independent reads at Step 1.
- No implementation — plan only. The plan is the hand-off to `/flow` or `/subagent-dev`.
- Tasks must be atomic and independently verifiable. Steps within a task must each be a single ~2–5 minute action.
- Every task ends in a commit. No "implement everything, then test, then one big commit".
- Spec-optional: a matching spec sharpens scope, but its absence does not block planning.

## Preconditions

If `~/.claude-wyvrn/VERSION` missing → halt: `Wyvrn harness not installed. Run claude-wyvrn install.`

## Trigger

- Slash: `/write-plan <feature>`
- Natural: "write a plan for", "plan this out", "break this into tasks", "what are the steps to"

## Behavior

### Step 1 — Load context (parallel batch)

Read in one parallel batch:

- `.claude-wyvrn-local/PROJECT.md` if present, else `README.md` if present (skip silently if neither exists)
- `.claude-wyvrn-local/ARCHITECTURE.md` if present (skip silently if missing)
- `.claude-wyvrn-local/specs/` — list files and read any whose slug matches the feature topic (top 1–2). A matching approved spec, when present, is treated as authoritative for scope and acceptance criteria. **If no spec is found, proceed without one — do not prompt the user to brainstorm.**
- Relevant stack conventions if the target stack is known.

While loading, capture the facts the plan header needs: the **tech stack**, the **build command**, and the **test command** (e.g. how a single test is built and run). If the project has no unit-test harness for the area being touched, note that — it changes how Step 3 writes the test steps.

The user's prompt is always the primary input. A spec sharpens the prompt; its absence is not a blocker.

### Step 2 — Clarify scope (if needed)

Ask only what cannot be inferred from the prompt + loaded context:

- **Feature boundary** — what is in scope, what is explicitly out.
- **Order constraints** — any tasks that must precede others beyond what's obvious.
- **Acceptance signal** — how the user will know the feature works (skip if a spec already defines this).

Batch into one AskUserQuestion call. Skip entirely if scope is clear from prompt + context. Do not ask "should we brainstorm first" — that is not this skill's concern.

### Step 3 — Draft the plan

Build the plan in two layers: a **header block** that orients the executor, then a sequence of **tasks**, each decomposed into **checkbox steps**.

#### 3a — Header block

Compose, in order:

- **Goal** — one paragraph: the observable change once the whole plan lands.
- **Architecture** — the approach in 2–4 sentences: the shape of the solution and the key design decision(s) it commits to (mirror the spec if one exists).
- **Tech Stack** — language/standard, build system, test framework, and the exact build + single-test commands.
- **Spec** — path to the spec file, or omit the line entirely if there is none.
- **Executor directive** — a fixed blockquote line, placed as the plan's second line, copied verbatim (no per-plan variation):
  `> **For agentic workers:** REQUIRED SUB-SKILL: Use `/subagent-dev` (subagent-driven-development, recommended) or `/flow` to implement this plan task-by-task. When an Execution schedule is present, `/subagent-dev` dispatches each wave's tasks to parallel worktree-isolated agents and gates each wave on a merged build+test. Steps use checkbox (`- [ ]`) syntax for tracking.`
- **File Structure table** — one row per file the plan touches: `File | Responsibility | Change`. This is the at-a-glance map.
- **Execution schedule table** — derived from each task's `Depends on:` line plus its file set; the executor reads this directly instead of re-deriving the graph. One row per wave: `Wave | Tasks | May run concurrently because`. A task joins the earliest wave in which (a) every task it depends on sits in an earlier wave and (b) its file set is pairwise disjoint from every other task in that wave. Two logically independent tasks that touch the same file must NOT share a wave — either extract the shared-file edit into its own task or keep them in separate waves with a note naming the shared file. A schedule whose waves are all single-task is valid; it then simply documents the required order.
- **Testing note** — state the test strategy and any precedent it follows. If part of the work cannot be unit-tested (no loopback harness, wire-format/IPC, visual rendering, etc.), say so here and say how those tasks are verified instead (build + runtime observation). This is where universal.md §1.6 ("docs/config without logic need no test") is reconciled with the codebase's real test surface — do not invent a test harness the project lacks.

#### 3b — Tasks and steps

Break the feature into atomic tasks (aim for 2–5; see ordering rules below). For each task:

- **Heading:** `### Task N: <imperative title>`
- **Depends on:** `**Depends on:** Task N[, Task M]` or `**Depends on:** none`. Logical dependencies only — the tasks whose symbols, types, or behavior this task consumes. File overlap is not a logical dependency; it is handled by the Execution schedule's wave rule.
- **Files:** every path the task touches, each tagged `Modify:` / `Create:` / `Test:`. No globs.
- **Steps:** an ordered list of `- [ ]` checkbox steps, each a single ~2–5 minute action with a bolded label (`**Step 1: <action>**`). Give the exact code/edit inline — no placeholders, no "etc.". A step that changes a function gives the signature and the precise logic.

**TDD step pattern — required for any task that changes executable code:**

1. `**Step 1: Write the failing test**` — the exact test code and where it goes (file + anchor), plus how it is registered/discovered.
2. `**Step 2: Run the test to verify it fails**` — the exact run command and the expected failure (compile error or assertion), so the worker confirms red for the right reason.
3. One or more implementation steps — the minimal change to make it pass.
4. `**Step: Run the test to verify it passes**` — the run command and expected PASS.
5. `**Step: Commit**` — see commit step below.

**Non-TDD tasks** (docs, config without logic, or code whose area genuinely has no test harness per the Testing note): replace steps 1–4 with the implementation steps followed by a **build/verify step** — the exact build command plus a concrete observable check (a grep that must match, a log line that must/must not appear, a runtime behavior to eyeball). Never a bare "it should work".

**Commit step — required as the last step of every task:**

```` markdown
- [ ] **Step N: Commit**

```bash
git add <only the files this task touched>
git commit -m "<type>(<scope>): <subject>"
```
````

`git add` lists the exact files — never `git add -A`. The message follows `gitflow.md` §3 (`<type>(<scope>): <subject>`, imperative, lowercase, ≤72 chars).

**Ordering rules:**

- Earlier tasks must not depend on code from later tasks.
- Infrastructure tasks (types, interfaces, data models, wire formats) before logic tasks.
- Logic tasks before integration tasks.
- Integration tasks before UI/consumer tasks.
- Task numbering must remain a valid topological order of the `Depends on:` graph — no task depends on a higher-numbered task. A sequential executor just runs the numbers; a parallel executor uses the Execution schedule.

Aim for 2–5 tasks per plan, each with roughly 3–8 steps. If a feature genuinely requires more tasks, split into two plan files (Part 1 / Part 2).

#### 3c — Closing sections

Both sections are **always present**. When nothing applies, write the explicit-empty form rather than omitting the section — that forces an active confirmation instead of a silent gap.

**Out of scope.** State what the plan deliberately excludes.

- **Cross-boundary contract** — when any work lands in another repo, another team, or a follow-up plan, name the exact contract the other side must honor: message type names **and their numeric values**, version bumps, struct/API shapes, ordering/compositing semantics, handshake requirements. Make it precise enough to build against without further questions.
- When nothing applies: `None — fully self-contained (single repo, no downstream contract).`

Worked example (condensed from a real cross-repo plan):

> The emulator (separate repo) must add a `DeviceCanvasUpdated` (msg type 10) handler that, keyed by device identity, stores the W×H RGBA grid and composites locally: clear → space → device-on-top (replace-if-lit). The protocol handshake must accept v4. This plan delivers only the publisher half.

**Self-Review notes.** Five checks (see the Step 3d gate — these are completed *before* review, not after):

1. **Spec coverage** — every spec requirement (or, spec-less, every stated goal/AC) mapped to the task(s) that deliver it, each ticked ✓.
2. **Placeholder scan** — confirm no `TBD`/`TODO`/"similar to"/"handle edge cases"/"etc." anywhere; every step carries the full exact change (enforces universal.md §1.2).
3. **Type/name consistency** — list every new symbol (function, type, enum value + its number, field, message name); confirm each is spelled identically in every task it appears in.
4. **Ordering invariants** — call out any sequencing that must hold (init-before-use, validity-before-consume, an interface + its override landing in the same task to keep the tree compiling).
5. **Dependency audit** — the `Depends on:` graph is acyclic and respects task numbering; every symbol a task consumes is produced by a task it declares a dependency on (no false independence); tasks sharing a wave in the Execution schedule have pairwise-disjoint file sets.

Worked example:

> - **Spec coverage:** clear→space→device ordering → Tasks 2/4/3 ✓; replace-if-lit blend → Task 1 + truth-table test ✓; persistent device layer → Task 2 ✓.
> - **Placeholder scan:** no TBD/TODO/"similar to" — every code step shows full code ✓.
> - **Type consistency:** `Overrides(const CColor&)`, `CompositeOver(const CColor&, const CColor&)`, `CompositeDeviceLayer()` (void), `m_DeviceLayer` (CCanvas) — spelled identically in every task ✓.
> - **Ordering invariants:** `m_DeviceLayer` sized before composite; space write composites onto the cleared base, not over it ✓.
> - **Dependency audit:** Task 3 depends on Task 1 (`CompositeOver`) and declares it ✓; Tasks 1/2 share no files or symbols → wave 1 together ✓; graph acyclic, numbering topological ✓.

#### 3d — Self-Review gate (mandatory, before Step 4)

Run the five Self-Review checks against the drafted plan **before** emitting it for review. If any check fails — an unmapped requirement, a placeholder, an inconsistent symbol, an unstated ordering dependency, a dependency cycle or a wave that violates the file-overlap rule — fix the plan first. Never emit a plan for approval with an unfilled or failing Self-Review.

### Step 4 — Review

Emit the full plan (header + tasks + closing sections, **including the completed Self-Review**) as a chat message. AskUserQuestion header `Plan`, options `[Save plan, Refine, Abort]`.

- `Save plan` → Step 5.
- `Refine` (or "Other" + text) → incorporate feedback, re-run the Step 3d gate, re-emit, repeat Step 4.
- `Abort` → halt. Do not write any file.

### Step 5 — Write plan file

Write `.claude-wyvrn-local/plans/YYYY-MM-DD-<slug>-plan.md` where `<slug>` is a lowercase-hyphenated summary of the feature (≤5 words). Create `plans/` if missing (should already exist from any prior `/flow` run).

File format (the outer fence is four backticks only so the inner ```bash``` / language fences render literally — do not copy the four-backtick fence into the plan):

```` markdown
# <Feature title> — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `/subagent-dev` (subagent-driven-development, recommended) or `/flow` to implement this plan task-by-task. When an Execution schedule is present, `/subagent-dev` dispatches each wave's tasks to parallel worktree-isolated agents and gates each wave on a merged build+test. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** <one paragraph — the observable change once the plan lands>

**Architecture:** <2–4 sentences — approach and key design decisions>

**Tech Stack:** <language/standard, build system, test framework; build + single-test commands>

**Spec:** <path to spec file>   ← omit this line entirely if there is no spec

---

## File Structure

| File | Responsibility | Change |
|---|---|---|
| `path/to/file` | <what it owns> | <what this plan changes in it> |

## Execution schedule

| Wave | Tasks | May run concurrently because |
|---|---|---|
| 1 | Task 1, Task 2 | <no shared files, no shared symbols> |
| 2 | Task 3 | <needs `<symbol>` from Task 1> |

**Testing note:** <test strategy + precedent; which tasks are TDD vs build/verify and why>

---

### Task 1: <imperative title>

**Depends on:** <none | Task N[, Task M]>

**Files:**
- Modify: `path/...`
- Create: `path/...`
- Test: `path/...`

- [ ] **Step 1: Write the failing test**

  <exact test code + where it goes + how it's registered>

- [ ] **Step 2: Run the test to verify it fails**

  Run: `<single-test command>`
  Expected: FAIL — <compile error or assertion that must fire>

- [ ] **Step 3: <implementation step>**

  <exact change>

- [ ] **Step 4: Run the test to verify it passes**

  Run: `<single-test command>`
  Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add path/... path/...
git commit -m "<type>(<scope>): <subject>"
```

---

### Task 2: <title>

...

---

## Out of scope

<one line: what this plan excludes. When work lands in another repo/team/follow-up,
name the contract that side must honor — message types + numeric values, version bumps,
struct/API shapes, ordering semantics. When nothing applies:
"None — fully self-contained (single repo, no downstream contract).">

## Self-Review notes

- **Spec coverage:** <each spec requirement / goal → the task(s) that deliver it, ✓>
- **Placeholder scan:** <confirm no TBD/TODO/"similar to"/"etc." — every step shows full code ✓>
- **Type/name consistency:** <list each new symbol (incl. enum value + number); spelled identically everywhere ✓>
- **Ordering invariants:** <sequencing that must hold — init-before-use, validity-before-consume, ... ✓>
- **Dependency audit:** <graph acyclic + numbering topological; every consumed symbol → a declared dependency; same-wave tasks have disjoint file sets ✓>
````

Emit:

```
Plan written: .claude-wyvrn-local/plans/YYYY-MM-DD-<slug>-plan.md

Tasks: N   Steps: M   Waves: K
Next: /subagent-dev <plan-file> to execute with subagents (parallel waves where the schedule allows), or /flow referencing each task.
```

## Stop conditions

- User aborts at any step → halt, no file written.
- Feature is too vague to decompose → ask one round of clarifying questions in Step 2. If still vague after clarification, halt and tell the user the prompt is too ambiguous to plan against (do not produce a vague plan, but do not require any specific upstream skill either).

## Constraints

- Do NOT produce implementation code in the working tree. The plan *contains* exact code to write, but this skill does not apply it.
- Do NOT modify source files, configs, or anything outside `.claude-wyvrn-local/plans/`.
- Do NOT modify `~/.claude-wyvrn/`.
- Do NOT invent a test harness the project does not have — honor the Testing note from Step 3a.
- All confirmations via `AskUserQuestion`.

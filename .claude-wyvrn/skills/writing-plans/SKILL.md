---
name: write-plan
description: Break a feature or task into a sequence of atomic tasks, each decomposed into numbered checkbox steps that follow TDD — write the failing test, run it red, implement the minimal code, run it green, commit — with exact file paths, complete code in every step, explicit git add+commit commands, and per-task interfaces so a fresh executor can run each task without the others' context. Produces a reviewable plan file in .claude-wyvrn-local/plans/. Trigger when the user says "write a plan for", "plan this out", "break this into tasks", or invokes /write-plan directly.
---

# write-plan

Decomposes a feature into a concrete, reviewable plan whose tasks an agentic worker can execute step-by-step. Each task is broken into atomic, checkboxed steps; each task follows the TDD cycle — the failing test is written and **run red** first, then the minimal implementation, then the test **run green** — so the test-first design pressure is exercised at execution time. Every task ends in a self-contained commit so the work is reversible at task granularity. The output is a plan file in `.claude-wyvrn-local/plans/` — the same directory `/flow` already retrieves for past-mistake context.

**TDD execution.** Each task's executor writes the test, runs it to watch it fail for the right reason, writes the minimal code to pass, runs it green, then commits. The plan carries the complete test and implementation code so the executor transcribes rather than re-derives — but the red-green cycle is run live, not skipped.

**Standalone by design.** This skill works on its own. If an approved spec exists in `.claude-wyvrn-local/specs/`, it is used as authoritative input. If no spec exists, the plan is drafted directly from the user's prompt + project context. `/brainstorm` is never required.

**Hand-off target.** The plan is written to be executed by `/subagent-dev` (subagent-driven-development) or `/flow`, task-by-task and in order. The plan header names this explicitly so the executor knows how to run it.

## Execution principles

- Parallelize independent reads at Step 1.
- No implementation — plan only. The plan is the hand-off to `/flow` or `/subagent-dev`.
- Tasks must be atomic and independently verifiable. Steps within a task must each be a single ~2–5 minute action.
- Every task ends in a commit. No "implement everything, then test, then one big commit".
- Tasks run sequentially in dependency order — earlier tasks never depend on later ones.
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
  `> **For agentic workers:** REQUIRED SUB-SKILL: Use `/subagent-dev` (subagent-driven-development, recommended) or `/flow` to implement this plan task-by-task, in order. Each task follows TDD: write the failing test, run it to confirm it fails for the right reason, implement the minimal code to pass, run the test to confirm it passes, then commit. The plan carries the complete code — transcribe it rather than re-derive, but run the red-green cycle live. Steps use checkbox (`- [ ]`) syntax for tracking: the executor MUST edit this plan file and flip each completed step to `- [x]` — in `/subagent-dev` the orchestrator flips a task's boxes when its review passes; in `/flow` flip each step as it is done.`
- **Global Constraints** — the spec's project-wide requirements (version floors, dependency limits, naming/copy rules, platform requirements), one line each with exact values copied verbatim. Every task's requirements implicitly include this section. If none apply, write `None.`
- **File Structure table** — one row per file the plan touches: `File | Responsibility | Change`. This is the at-a-glance map, and where decomposition decisions get locked in.
- **Testing note** — state the test strategy and any precedent it follows; say which tasks are test-covered (TDD pattern) vs build/verify. If part of the work cannot be unit-tested (no loopback harness, wire-format/IPC, visual rendering, etc.), say so here and say how those tasks are verified instead (build + runtime observation). This is where universal.md §1.6 ("docs/config without logic need no test") is reconciled with the codebase's real test surface — do not invent a test harness the project lacks.

#### 3b — Tasks and steps

Break the feature into atomic tasks (aim for 2–5; see ordering rules below). A task is the smallest unit that carries its own test cycle and is worth a fresh reviewer's gate: fold setup, configuration, scaffolding, and documentation into the task whose deliverable needs them; split only where a reviewer could meaningfully reject one task while approving its neighbor. For each task:

- **Heading:** `### Task N: <imperative title>`
- **Files:** every path the task touches, each tagged `Modify:` / `Create:` / `Test:`. No globs.
- **Interfaces:**
  - `Consumes:` what this task uses from earlier tasks — exact signatures.
  - `Produces:` what later tasks rely on — exact function names, parameter and return types. A task's implementer sees only their own task; this block is how they learn the names and types neighboring tasks use.
- **Steps:** an ordered list of `- [ ]` checkbox steps, each a single ~2–5 minute action with a bolded label (`**Step 1: <action>**`). Give the exact code/edit inline — no placeholders, no "etc.". A step that changes a function gives the signature and the precise logic.

**TDD step pattern — required for any task that changes executable code:**

1. `**Step 1: Write the failing test**` — the exact test code and where it goes (file + anchor), plus how it is registered/discovered.
2. `**Step 2: Run the test to confirm it fails**` — the exact single-test command and the expected failure (e.g. `FAIL: function not defined`). This is the red phase; it proves the test exercises the new behavior.
3. One or more implementation steps — the exact minimal change to make the test pass.
4. `**Step: Run the test to confirm it passes**` — the same single-test command, expected PASS. This is the green phase.
5. `**Step: Commit**` — see commit step below.

**Non-test tasks** (docs, config without logic, or code whose area genuinely has no test harness per the Testing note): replace the red-green steps with the implementation steps followed by a **build/verify step** — the exact build command plus a concrete observable check (a grep that must match, a log line that must/must not appear, a runtime behavior to eyeball). Never a bare "it should work".

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
- Task numbering must be a valid topological order — no task consumes an interface a higher-numbered task produces. A sequential executor just runs the numbers.

Aim for 2–5 tasks per plan, each with roughly 3–8 steps. If a feature genuinely requires more tasks, split into two plan files (Part 1 / Part 2).

#### 3c — Closing sections

Both sections are **always present**. When nothing applies, write the explicit-empty form rather than omitting the section — that forces an active confirmation instead of a silent gap.

**Out of scope.** State what the plan deliberately excludes.

- **Cross-boundary contract** — when any work lands in another repo, another team, or a follow-up plan, name the exact contract the other side must honor: message type names **and their numeric values**, version bumps, struct/API shapes, ordering/compositing semantics, handshake requirements. Make it precise enough to build against without further questions.
- When nothing applies: `None — fully self-contained (single repo, no downstream contract).`

Worked example (condensed from a real cross-repo plan):

> The emulator (separate repo) must add a `DeviceCanvasUpdated` (msg type 10) handler that, keyed by device identity, stores the W×H RGBA grid and composites locally: clear → space → device-on-top (replace-if-lit). The protocol handshake must accept v4. This plan delivers only the publisher half.

**Self-Review notes.** Three checks (see the Step 3d gate — these are completed *before* review, not after):

1. **Spec coverage** — every spec requirement (or, spec-less, every stated goal/AC) mapped to the task(s) that deliver it, each ticked ✓.
2. **Placeholder scan** — confirm no `TBD`/`TODO`/"similar to"/"handle edge cases"/"etc." anywhere; every step carries the full exact change (enforces universal.md §1.2).
3. **Type/name consistency** — list every new symbol (function, type, enum value + its number, field, message name); confirm each is spelled identically in every task it appears in, and that every symbol a later task's `Consumes:` names is produced by an earlier task's `Produces:`.

Worked example:

> - **Spec coverage:** clear→space→device ordering → Tasks 2/4/3 ✓; replace-if-lit blend → Task 1 + truth-table test ✓; persistent device layer → Task 2 ✓.
> - **Placeholder scan:** no TBD/TODO/"similar to" — every code step shows full code ✓.
> - **Type consistency:** `Overrides(const CColor&)`, `CompositeOver(const CColor&, const CColor&)`, `CompositeDeviceLayer()` (void), `m_DeviceLayer` (CCanvas) — spelled identically in every task; Task 3 Consumes `CompositeOver` produced by Task 1 ✓.

#### 3d — Self-Review gate (mandatory, before Step 4)

Run the three Self-Review checks against the drafted plan **before** emitting it for review. If any check fails — an unmapped requirement, a placeholder, an inconsistent symbol, a consumed symbol no task produces — fix the plan first. Never emit a plan for approval with an unfilled or failing Self-Review.

### Step 4 — Write draft plan file and review

Write the full plan (header + tasks + closing sections, **including the completed Self-Review**) to `.claude-wyvrn-local/plans/YYYY-MM-DD-<slug>-plan.md` where `<slug>` is a lowercase-hyphenated summary of the feature (≤5 words). Create `plans/` if missing (should already exist from any prior `/flow` run). Do NOT commit yet — the file exists so the user reviews it in their editor with full rendering instead of scrolling chat output.

Emit the file path plus a one-line summary (`Tasks: N   Steps: M`). Do NOT paste the full plan into chat. Then emit AskUserQuestion with header `Plan`, question text naming the file path, options `[Save plan, Save plan & run subagent-dev, Refine, Abort]`.

- `Save plan` → Step 5.
- `Save plan & run subagent-dev` → Step 5, then chain into `/subagent-dev` (see Step 5).
- `Refine` (or "Other" + text) → edit the plan file in place, re-run the Step 3d gate, emit a one-line note of what changed, repeat Step 4.
- `Abort` → delete the draft plan file, halt.

File format (the outer fence is four backticks only so the inner ```bash``` / language fences render literally — do not copy the four-backtick fence into the plan):

```` markdown
# <Feature title> — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `/subagent-dev` (subagent-driven-development, recommended) or `/flow` to implement this plan task-by-task, in order. Each task follows TDD: write the failing test, run it to confirm it fails for the right reason, implement the minimal code to pass, run the test to confirm it passes, then commit. The plan carries the complete code — transcribe it rather than re-derive, but run the red-green cycle live. Steps use checkbox (`- [ ]`) syntax for tracking: the executor MUST edit this plan file and flip each completed step to `- [x]` — in `/subagent-dev` the orchestrator flips a task's boxes when its review passes; in `/flow` flip each step as it is done.

**Goal:** <one paragraph — the observable change once the plan lands>

**Architecture:** <2–4 sentences — approach and key design decisions>

**Tech Stack:** <language/standard, build system, test framework; build + single-test commands>

**Spec:** <path to spec file>   ← omit this line entirely if there is no spec

## Global Constraints

<project-wide requirements, one line each with exact values; "None." if none apply>

---

## File Structure

| File | Responsibility | Change |
|---|---|---|
| `path/to/file` | <what it owns> | <what this plan changes in it> |

**Testing note:** <test strategy + precedent; which tasks are test-covered (TDD pattern) vs build/verify and why>

---

### Task 1: <imperative title>

**Files:**
- Modify: `path/...`
- Create: `path/...`
- Test: `path/...`

**Interfaces:**
- Consumes: <exact signatures used from earlier tasks, or "none">
- Produces: <exact names + types later tasks rely on, or "none">

- [ ] **Step 1: Write the failing test**

  <exact test code + where it goes + how it's registered>

- [ ] **Step 2: Run the test to confirm it fails**

  Run: `<single-test command>`
  Expected: FAIL (<reason, e.g. "function not defined">).

- [ ] **Step 3: <implementation step>**

  <exact change>

- [ ] **Step 4: Run the test to confirm it passes**

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
- **Type/name consistency:** <list each new symbol (incl. enum value + number); spelled identically everywhere; every Consumes matched by an earlier Produces ✓>
````

### Step 5 — Commit plan file

On `Save plan` (or `Save plan & run subagent-dev`), commit the plan file on the current branch:

```bash
git add .claude-wyvrn-local/plans/YYYY-MM-DD-<slug>-plan.md
git commit -m "docs(plans): add <slug> implementation plan"
```

- `git add` lists only the plan file — never `git add -A`.
- The message follows `gitflow.md` §3.
- A single `-m` line only. Do NOT append a `Co-Authored-By` trailer, a "Generated with" footer, or any other trailer.
- Commit on the current branch. Do not create branches, push, or open PRs.

Emit:

```
Plan written and committed: .claude-wyvrn-local/plans/YYYY-MM-DD-<slug>-plan.md

Tasks: N   Steps: M
Next: /subagent-dev <plan-file> to execute with subagents (sequential, review between tasks), or /flow referencing each task.
```

If the user chose `Save plan & run subagent-dev` at Step 4: after emitting, invoke the `subagent-driven-development` skill (`/subagent-dev`) with the written plan file path. This skill's no-implementation constraints end at that hand-off; `/subagent-dev` runs under its own rules and does implement.

## Stop conditions

- User aborts at any step → halt; delete the draft plan file if one was written, leave nothing committed.
- Feature is too vague to decompose → ask one round of clarifying questions in Step 2. If still vague after clarification, halt and tell the user the prompt is too ambiguous to plan against (do not produce a vague plan, but do not require any specific upstream skill either).

## Constraints

- Do NOT produce implementation code in the working tree. The plan *contains* exact code to write, but this skill does not apply it.
- Do NOT modify source files, configs, or anything outside `.claude-wyvrn-local/plans/`.
- The only permitted git operations are the Step 5 `git add` + `git commit` of the plan file.
- Do NOT modify `~/.claude-wyvrn/`.
- Do NOT invent a test harness the project does not have — honor the Testing note from Step 3a.
- All confirmations via `AskUserQuestion`.

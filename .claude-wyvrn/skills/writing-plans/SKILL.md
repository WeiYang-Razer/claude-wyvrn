---
name: write-plan
description: Break a feature or task into a sequence of 2-5 minute atomic steps, each with exact file paths, complete change description, test approach, and commit message. Produces a reviewable plan file in .claude-wyvrn-local/plans/. Trigger when the user says "write a plan for", "plan this out", "break this into tasks", or invokes /write-plan directly.
---

# write-plan

Decomposes a feature into a concrete, reviewable sequence of atomic tasks. Each task is small enough to implement and verify in one short session. The output is a plan file in `.claude-wyvrn-local/plans/` — the same directory `/flow` already retrieves for past-mistake context.

## Execution principles

- Parallelize independent reads at Step 1.
- No implementation — plan only. The plan is the hand-off to `/flow` or `subagent-dev`.
- Tasks must be atomic and independently verifiable. No "implement everything, then test".

## Preconditions

If `~/.claude-wyvrn/VERSION` missing → halt: `Wyvrn harness not installed. Run claude-wyvrn install.`

## Trigger

- Slash: `/write-plan <feature>`
- Natural: "write a plan for", "plan this out", "break this into tasks", "what are the steps to"

## Behavior

### Step 1 — Load context (parallel batch)

Read in one parallel batch:

- `.claude-wyvrn-local/PROJECT.md` if present, else `README.md`
- `.claude-wyvrn-local/ARCHITECTURE.md` if present
- `.claude-wyvrn-local/specs/` — list files, read any whose slug matches the feature topic (top 1–2). A matching approved spec is the primary input; treat it as authoritative for scope and acceptance criteria.
- Relevant stack conventions if the target stack is known.

If no spec exists and the feature is complex or uncertain → recommend `/brainstorm <topic>` first. AskUserQuestion header `No spec found`, options `[Continue without spec, Run /brainstorm first, Abort]`.

### Step 2 — Clarify scope (if needed)

Ask only what cannot be inferred:

- **Feature boundary** — what is in scope, what is explicitly out.
- **Order constraints** — any tasks that must precede others beyond what's obvious.

Batch into one AskUserQuestion call. Skip entirely if scope is clear from prompt + context.

### Step 3 — Draft task list

Break the feature into atomic tasks. For each task:

**Required fields:**
- **Task N: `<imperative title>`** — e.g., "Add `parseHeader` function to `src/http/parser.ts`"
- **Files** — exact paths of every file to touch (create or modify). No globs.
- **Change** — complete description of what to write or change. No placeholders. If the change is a function, give the signature and describe its logic precisely enough that it can be written without guessing.
- **Test** — what test to write or update, which assertion validates the change, how to run it.
- **Commit message** — follows `gitflow.md` §3 format: `<type>(<scope>): <subject>`.

**Ordering rules:**
- Earlier tasks must not depend on code from later tasks.
- Infrastructure tasks (types, interfaces, data models) before logic tasks.
- Logic tasks before integration tasks.
- Integration tasks before UI/consumer tasks.

Aim for 2–5 tasks per plan. If a feature genuinely requires more, split into two plan files (Part 1 / Part 2).

### Step 4 — Review

Emit the full task list as a chat message. AskUserQuestion header `Plan`, options `[Save plan, Refine, Abort]`.

- `Save plan` → Step 5.
- `Refine` (or "Other" + text) → incorporate feedback, re-emit, repeat Step 4.
- `Abort` → halt. Do not write any file.

### Step 5 — Write plan file

Write `.claude-wyvrn-local/plans/YYYY-MM-DD-<slug>-plan.md` where `<slug>` is a lowercase-hyphenated summary of the feature (≤5 words). Create `plans/` if missing (should already exist from any prior `/flow` run).

File format:

```markdown
# Plan: <feature title>
date: YYYY-MM-DD
spec: <path to spec file, or "none">
status: pending

## Task 1: <title>
Files: <paths>
Change: <description>
Test: <what to write / run>
Commit: <message>

## Task 2: <title>
...
```

Emit:

```
Plan written: .claude-wyvrn-local/plans/YYYY-MM-DD-<slug>-plan.md

Tasks: N
Next: run /flow referencing each task, or /subagent-dev <plan-file> to execute with subagents.
```

## Stop conditions

- User aborts at any step → halt, no file written.
- Feature is too vague to decompose → request `/brainstorm` first rather than producing a vague plan.

## Constraints

- Do NOT produce implementation code. Describe changes precisely, but do not write them.
- Do NOT modify source files, configs, or anything outside `.claude-wyvrn-local/plans/`.
- Do NOT modify `~/.claude-wyvrn/`.
- All confirmations via `AskUserQuestion`.

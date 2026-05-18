---
name: flow
description: Wyvrn task runner. Trigger for any user request that modifies code, tests, configs, docs, or project files. Slash command `/flow` or natural-language "build/add/fix/refactor/implement". Skip for read-only queries (explanation, analysis, exploration).
---

# flow

Inline runbook for feature/fix/refactor. No custom subagents. MAY invoke built-in subagents (Explore) for parallel codebase research.

## Execution principles

- **Parallelize independent operations.** Issue independent reads, edits, greps, and bash commands as a single tool-use message. Sequence only on data dependencies. See `universal.md` §1.7.
- **Skip steps whose answers are inferable** from prompt, codebase, conventions, or past plans. Do not re-ask.
- **No cycle caps** on confidence loops (Steps 3↔4, 7↔8). Iterate until 95%+ or the user interrupts.

## Preconditions

If `~/.claude-wyvrn/VERSION` missing → halt and emit: `Wyvrn harness not installed. Run claude-wyvrn install.`

## Step 1 — Read context (parallel batch)

Read in one parallel batch:

- `~/.claude-wyvrn/conventions/universal.md`
- `~/.claude-wyvrn/conventions/gitflow.md`
- `.claude-wyvrn-local/PROJECT.md` else `README.md`
- `.claude-wyvrn-local/ARCHITECTURE.md` if present

Lazy-load stack conventions on first matching file touch (parallel reads):

- `~/.claude-wyvrn/conventions/<stack>.md`
- `.claude-wyvrn-local/conventions/<stack>.md` (project wins on conflict)

Extensions: `.js`→javascript; `.ts`/`.mts`/`.cts`→typescript; `.jsx`/`.tsx`→react+typescript/javascript; `.py`/`.pyi`→python; `.cs`→csharp; `.cpp`/`.cc`/`.cxx`/`.h`/`.hpp`/`.hxx`→cpp.

### Past-mistake retrieval (parallel)

If `.claude-wyvrn-local/plans/` exists:

1. Extract match keys from the prompt: likely-touched file paths, stack names, salient noun/verb keywords (≥3 chars, drop stop-words).
2. Issue greps for each key against `plans/` in parallel.
3. Read the top 3–5 plans by total match count in one parallel batch.
4. Note any `Mistakes & corrections` entries relevant to this task.

Skip silently if no relevant plans.

Enter plan mode. No code yet.

## Step 2 — Gitflow opt-in

AskUserQuestion: header `Gitflow`, options `[Follow gitflow, Skip gitflow]`.

### Follow gitflow

1. Run `git branch --show-current` and `git status --short` in parallel.
2. Infer task type: `feature` (new behavior) / `fix` (bug) / `refactor` (structural, no behavior change).
3. Determine target branch per `gitflow.md` (e.g., `feature/<INITIALS>_<camelCase>` from `develop`; `refacto/` for refactors).
4. If current branch matches the expected pattern → emit `Branch already appropriate: <branch>`. Continue.
5. Else propose a name. AskUserQuestion header `Branch` with the proposal as one option; "Other" carries an edited name. Confirm uncommitted-change handling before switching. Create with `git switch -c <branch>` from the gitflow base.
6. Set `gitflow=true`.

### Skip gitflow

1. Stay on current branch. Do not create or switch.
2. Set `gitflow=false`.
3. Step 10 is a no-op.

## Step 3 — Fill prompt gaps (batched AskUserQuestion)

Ask only what is unclear and not inferable from prompt, codebase, conventions, or past plans:

- **Goal** — observable change after the task.
- **Scope** — files/modules in; explicit out-of-scope.
- **Acceptance signal** — test name, manual check, metric.
- **Constraints** — APIs, perf, back-compat to preserve.

Batch into one AskUserQuestion call (≤4 questions; chunk sequentially when >4). Each question: 2 plausible options; "Other" auto-added.

Skip Step 3 entirely if the prompt nails every item.

## Step 4 — Confidence gate

Judge confidence on:

- What to change.
- Where to change it.
- How to verify it works.
- Whether retrieved past mistakes are accounted for.

If 95%+ → Step 5. Else → Step 3 with remaining gaps.

## Step 5 — Plan review (opt-in)

Check `plan-review:` in `.claude-wyvrn-local/PROJECT.md`. Default `off`.

If `on`:

1. Emit plan summary: intent, files, test approach, branch, retrieved-mistake summary.
2. AskUserQuestion header `Plan`, options `[Proceed, Refine, Abort]`.
3. `Refine` → Step 3. `Abort` → halt.

If `off`: continue.

## Step 6 — Implement

1. Exit plan mode.
2. **Strict-convention rule** (`universal.md` §1.1). Follow matching stack conventions exactly. Do not propagate codebase deviations. Do not fix unrelated convention violations outside scope.
3. Before declaring any new public symbol, grep the touched module for similar names. Prefer reuse.
4. Apply edits to independent files in parallel.

## Step 7 — Tests

**Required** for changes to executable code.
**Not required** for documentation files, configuration without logic, comment edits, README updates.

When required:

1. Write or update a test exercising the changed behavior, per the touched stack's test conventions.
2. Run affected tests (e.g., `jest --findRelatedTests`, `pytest --picked`, `dotnet test --filter`, `ctest -R <pattern>`). Independent test commands run in parallel.
3. Fix any previously-passing test that now fails before Step 8.

## Step 8 — Self-verify

Re-read the diff. Check:

- Every Step-3 goal/AC is reflected in code.
- New and affected tests pass.
- No silent renames, dead code, commented-out code, leftover TODOs.
- Diff stays inside declared scope.

If 95%+ → Step 9. Else → fix gaps; re-run affected tests in parallel.

## Step 9 — Learning log + lesson absorption

### 9a. Learning log

Write `.claude-wyvrn-local/plans/YYYY-MM-DD-<slug>.md`. Create `plans/` if missing.

Free-form, ~30–80 lines. Required sections:

- **Task** — one-paragraph paraphrase of the user's request.
- **Branch** — branch name and base, or `current branch (gitflow skipped)`.
- **Mistakes & corrections** — every mistake during the flow + how it was corrected. If none, write `None.` Each entry: what went wrong, the correction, what to do differently.
- **Global harness issues** — mistakes whose root cause is ambiguity or error in `~/.claude-wyvrn/`. For each: file, what's unclear, suggested fix. Do NOT modify `~/.claude-wyvrn/`. Surface these prominently in chat.
- **Files changed** — list with one-line rationale each.
- **Tests** — names of new/updated tests + runner outcome.
- **Project-file updates** — summary of 9b updates, or `None`.

### 9b. Project-file sync + lesson absorption

Two trigger types:

**Type A — material project change:**

- New/removed/changed module → ARCHITECTURE.md.
- New stack / new framework / dependency change → PROJECT.md, optionally new `conventions/<stack>.md`.
- New project-specific coding pattern → `conventions/<stack>.md`.
- Gotcha / idiom / constraint → PROJECT.md.

**Type B — mistake absorption:**

For each mistake in 9a, judge whether a project-file update prevents recurrence:

- Coding/style pattern (intentional project deviation) → `.claude-wyvrn-local/conventions/<stack>.md`.
- Context, idiom, gotcha, business rule → PROJECT.md (`Known patterns to remember` section).
- Module structure, interface invariant → ARCHITECTURE.md.
- Root cause is global harness → log under `Global harness issues` only; do NOT update project files.

If any update applies → invoke `/wyvrn-refresh-context` with scope and proposed changes.
Else → record `None` and skip.

## Step 10 — Push (gated)

**Only if `gitflow=true`.** Otherwise no-op.

1. AskUserQuestion header `Push`, options `[Push to remote, Hold local]`.
2. `Push to remote`:
   - `git add` only files touched by this task. Never `git add -A`.
   - Commit per `gitflow.md` §3.
   - `git push -u origin <branch>` for new branches; `git push` otherwise.
   - Do NOT open a PR unless the user explicitly asked.
3. `Hold local`: emit `Branch ready: <branch>`.

## Stop conditions

- User declines a step → halt, summarize state.
- User interrupts a confidence loop → halt, summarize state.
- Preconditions fail → halt with install message.

## Boundaries

- Do NOT modify `~/.claude-wyvrn/`.
- Do NOT open PRs unless the user asks.
- Do NOT auto-read past plans except via the targeted retrieval in Step 1.

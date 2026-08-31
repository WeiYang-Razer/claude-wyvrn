# PR 15 blocking-issue fixes (review follow-up)

## Task

Silent review of PR 15 (feature/adversarial-honesty) found 7 blocking issues. User asked to fix
all 7, with two directives: (4) resolve the ship-ticket/gitflow branch-prefix conflict by
extending gitflow (rename `refacto/` to `refactor/`, add `bugfix/` and `hotfix/`, update /flow's
type inference) rather than shrinking ship-ticket; (6) universalize the toolchain - no hard-coded
cmake/ninja/ctest/hostharness/wyvrnpm in shared harness files; projects declare their toolchain.

## Branch

feature/adversarial-honesty (PR 15 head; no new branch - fixes belong to the open PR).

## Mistakes & corrections

- Initial review proposed fixing issue 4 by aligning ship-ticket to gitflow's existing prefixes.
  User reversed the direction: gitflow extends instead (refactor/ rename, bugfix/ + hotfix/ added,
  ticket-driven `<type>/<TICKET-ID>[-<kebab-slug>]` naming variant legitimized). Correction: when
  two harness documents conflict, ask which one is wrong before proposing the fix direction.
- Review initially scoped issue 6 as "add ninja to the process lists". User widened it: the
  process list itself was the defect - project-specific names in universal files. The universal
  fix (declarations in `.claude-wyvrn-local/`) also subsumed issue 5's class (machine-local
  Chroma paths in ship-ticket).

## Global harness issues

None - this task edits the harness repo itself. Note: the INSTALLED copies at `~/.claude-wyvrn/`
and `~/.claude/skills/` are now behind this branch and need a re-install/sync to test.

## Files changed

- `.claude-wyvrn/templates/settings.hooks.json` - matcher `Bash|PowerShell`; PreToolUse command
  now reads `<project>/.claude-wyvrn-local/build-lock-processes` (no file = no lock); comments
  updated. Smoke-tested: exit 0 without file / with dead process, exit 2 + BLOCKED with live one.
- `.claude-wyvrn/CLAUDE.md` - build-lock wording (Bash or PowerShell, file-driven); Project
  settings gains `build-command` / `test-command` / `build-configs` and `build-lock-processes`.
- `.claude-wyvrn/skills/subagent-driven-development/implementer-prompt.md` - `[PHASE_BLOCK]`
  placeholder with RED/GREEN phase blocks defined below the template; `[TOOLCHAIN]` placeholder
  replaces hard-coded tool names; report/status rules phase-aware.
- `.claude-wyvrn/skills/subagent-driven-development/task-reviewer-prompt.md` - `[TOOLCHAIN]`
  placeholder replaces hard-coded tool names.
- `.claude-wyvrn/skills/subagent-driven-development/SKILL.md` - two-dispatch mechanics documented
  (Dispatch + Execution mode: TDD + Handling implementer status gains RED-PENDING, five statuses);
  stale pre-build-lock text swept (process step 3, file handoffs, fix dispatches, example
  workflow); toolchain names replaced by PROJECT.md declarations; sweep reads
  `build-lock-processes`.
- `.claude-wyvrn/conventions/gitflow.md` - `refactor/` rename; `bugfix/` + `hotfix/` types;
  hotfix cut from master, PRs into master, back-merge + patch tag (SS1/SS4/SS5); ticket-driven
  naming variant in SS2.
- `.claude-wyvrn/skills/flow/SKILL.md` - Step 2 type inference: fix/bugfix/hotfix/refactor.
- `.claude-wyvrn/skills/ship-ticket/SKILL.md` - Chroma repo table and worktree layout replaced by
  PROJECT.md repo-map/worktree-layout declarations; toolchain universalized; Doxygen wording
  generalized to stack-convention doc comments; Stage 5 "After every task" corrected to "After
  the last task completes".
- `.claude-wyvrn/skills/wyvrn-verify/SKILL.md` - rewritten stack-agnostic: declarations from
  PROJECT.md drive build/test per config; sweep reads `build-lock-processes`; wyvrnpm/hostharness
  removed.

## Tests

No executable code in this repo (markdown + one JSON template). Verified instead:
- `settings.hooks.json` parses as JSON.
- PreToolUse command executed in three states: no lock file (exit 0), lock file with dead process
  (exit 0), lock file with live process (exit 2, BLOCKED on stderr).
- Repo-wide grep confirms no residual `refacto/`, "one of four", "After every task", or
  hard-coded toolchain names outside legitimate spots (cpp.md stack file, multi-stack example
  lists, the hook comment's explicit example).

## Project-file updates

None (harness repo; changes are the deliverable).

## Time saved (agent vs. human-only)

- Human-only baseline: ~4h (review 12 files, trace 7 cross-file inconsistencies, redesign the
  lock to be declaration-driven, rewrite one skill, test the hook).
- Agent-assisted actual: ~35m end to end including the review.
- Time saved: ~3h 25m (85%).
- Basis: 9 files, ~200 changed lines, mostly cross-reference consistency work; largest
  uncertainty is the baseline for designing the declaration scheme.

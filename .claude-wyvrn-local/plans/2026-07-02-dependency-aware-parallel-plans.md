# Dependency-aware parallel execution for write-plan / subagent-dev

## Task

Make plans produced by `/write-plan` dependency-aware so multiple agents can execute them in parallel: per-task `Depends on:` metadata, a derived wave-based Execution schedule in the plan header (with a file-overlap rule for wave membership), and a fifth Self-Review check (dependency audit). Extend `/subagent-dev` with a wave-dispatch loop — worktree-isolated agent per task, merge task branches in dependency order, a wave gate (build+test on the merged result), and a sequential fallback for plans without a schedule.

## Branch

`feature/WT_dependencyAwareParallelPlans` from `main`.

## Mistakes & corrections

- **Template ordering drifted from its spec.** The Step 3a compose order places the Execution schedule between the File Structure table and the Testing note, but the first draft of the Step 5 file template placed the schedule after the Testing note. Caught during the diff self-review; template reordered to match 3a. Do differently: when a skill defines a structure twice (prose spec + literal template), edit both in the same pass and diff them against each other before moving on.

## Global harness issues

None. (Note, not an issue: installed skill copies at `~/.claude/skills/` do not update from repo edits — a manual sync is needed before testing these changes live.)

## Files changed

- `.claude-wyvrn/skills/writing-plans/SKILL.md` — per-task `Depends on:` line, Execution schedule table (spec + template), file-overlap wave rule, topological-numbering ordering rule, Self-Review check #5 (dependency audit), updated executor directive and emit summary (`Waves: K`).
- `.claude-wyvrn/skills/subagent-driven-development/SKILL.md` — schedule adoption in Step 2 (authoritative, halt on visible defects), wave-dispatch mode in Step 4 (worktree isolation, per-task commit on the task branch, merge in task-number order, wave gate, worktree cleanup), commit-ownership exception in principles, wave-mode constraints, sequential fallback preserved.

## Tests

None — documentation-only change (skill markdown), per universal.md §1.6. Verified by full-diff review and cross-file consistency check (`## Execution schedule` section name, `Depends on:` spelling, wave-gate description identical in both skills).

## Project-file updates

None — this repo is the harness source itself; no `.claude-wyvrn-local/PROJECT.md`/`ARCHITECTURE.md` exist to sync.

## Time saved (agent vs. human-only)

- **Human-only baseline:** ~2h — re-reading both skills, designing the wave/file-overlap semantics, writing consistent spec + template text in two files, cross-checking terminology.
- **Agent-assisted actual:** ~10 min end to end.
- **Time saved:** ~1h 50m (~90%).
- **Basis:** two markdown files, ~55 changed lines, but the cost is design consistency (same schema described in four places); largest uncertainty is the baseline for how long a human would iterate on the wave-membership rule.

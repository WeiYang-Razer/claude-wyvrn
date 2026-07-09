# Learning log — apply-mode execution for code-complete plans

## Task

User's ~1–2 h task pipelines were dominated by double work: `/write-plan` produces code-complete plans (full test + implementation code inline), then `/subagent-dev`/`/flow` executors re-derived the same code through live red-green TDD, including full C++ builds just to observe expected failures. Change the harness so code-complete plans execute in **apply-mode**: transcribe the plan's code, build once per task, run tests once, skip the red-phase entirely — and mandate the cheapest model tier for apply-mode implementers (the capable model already paid the design cost at plan time).

## Branch

`feature/WT_applyModeExecution` from `main`.

## Mistakes & corrections

- **Assumed version bump target without checking VERSION file.** Proposed (and got approval for) 2.3.0, but `.claude-wyvrn/VERSION` was already 2.3.0 — a prior release (subagent-dev skills, commit a89754f) bumped VERSION without updating CLAUDE.md/README, which lagged at 2.2.0. Correction: bumped everything to 2.4.0 and noted the deviation. Do differently: read VERSION before proposing a bump number; version markers in this repo live in 3 places (VERSION, CLAUDE.md, README ×3 spots) and have drifted before.
- **Base branch moved during the task.** `main` advanced (writing-plans/brainstorming edits) between reading files and branching. Correction: `git pull --ff-only` before branching, re-read the moved file before editing. Do differently: always pull main immediately before creating the feature branch.

## Global harness issues

- Version markers are triplicated (VERSION, `.claude-wyvrn/CLAUDE.md`, README title + layout table + Version section) and drift independently. Suggested fix: single source of truth (VERSION) with README/CLAUDE.md referencing it, or a release checklist item.

## Files changed

- `.claude-wyvrn/skills/writing-plans/SKILL.md` — TDD step pattern → Apply step pattern (no "verify it fails" step); executor directive declares plan code-complete + apply-mode (both 3a spec and Step 4 template); description, intro, and Testing-note wording updated.
- `.claude-wyvrn/skills/subagent-driven-development/SKILL.md` — new "Execution mode: apply vs TDD" section; Model selection mandates cheapest tier for apply-mode briefs; wave-dispatch and Integration wording updated.
- `.claude-wyvrn/skills/subagent-driven-development/implementer-prompt.md` — apply-mode vs TDD-mode job instructions, test-running guidance, self-review checklist, Apply Evidence report section.
- `.claude-wyvrn/skills/subagent-driven-development/task-reviewer-prompt.md` — "TDD evidence" → "TDD or apply evidence".
- `.claude-wyvrn/skills/test-driven-development/SKILL.md` — apply-mode exception note (skill governs live red-green, not plan transcription).
- `.claude-wyvrn/VERSION`, `.claude-wyvrn/CLAUDE.md`, `README.md` — version 2.4.0.

## Tests

None — markdown-only harness repo, no test surface. Verified by grep sweep: no stale `failing test` / red-phase references outside the TDD skill itself; executor directive identical in both writing-plans locations.

## Project-file updates

None (repo self-documents via README; no `.claude-wyvrn-local/PROJECT.md`).

## Time saved (agent vs. human-only)

- **Human-only baseline:** ~1h 30m — auditing 5 skill files for every TDD/red-phase touchpoint, rewriting the step pattern + templates consistently, catching the version drift.
- **Agent-assisted actual:** ~15m end to end.
- **Time saved:** 1h 15m (~83%).
- **Basis:** 8 files, ~60 changed lines, but consistency-heavy (directive duplicated verbatim in two places, mode wording across 4 skills). Largest uncertainty: baseline for hunting stale cross-references by hand.

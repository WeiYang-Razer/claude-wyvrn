# Wyvrn Claude harness — v2.2.0

A lean, opinionated structure that lets Claude Code run development work autonomously, predictably, and **fast**.

v2.0.0 replaces v1.x's five-phase orchestration (clarifier subagent → reuse-hint → work → verifier + code-reviewer subagents → validate, with template-verified artifacts at every step) with **one `/flow` skill** that runs the whole task inline. Target time per task drops from 20–25 min to **3–7 min** for simple work and 8–15 min for medium work.

## What's in v2.0.0

- **One `/flow` skill** — single runbook for feature/fix/refactor. Plan-first. Asks only what it can't infer. Implements with tests. Self-verifies. Writes a learning log. Offers to push.
- **`/wyvrn-refresh-context` skill** — populates and syncs `.claude-wyvrn-local/PROJECT.md`, `ARCHITECTURE.md`, and project-specific conventions from the codebase. Also absorbs lessons from /flow mistakes.
- **`/migrate-foreign-framework` skill** — migrates projects with hand-written `CLAUDE.md` or other ad-hoc Claude setups into the harness layout.
- **Conventions** — universal + gitflow + six stacks (JavaScript, TypeScript, Python, C#, C++, React).
- **Learning logs** — every /flow run writes a free-form markdown summary to `.claude-wyvrn-local/plans/` focused on mistakes Claude made and how the human corrected them, plus an estimate of the time the agent saved versus a human-only implementation. /flow retrieves relevant past logs when starting similar tasks.

## What v2.0.0 dropped (breaking change from v1.x)

- The five-phase rigid workflow (Read → Clarify → Reuse-hint → Work → Verify → Validate).
- Three custom subagents (clarifier, verifier, code-reviewer).
- The `template_verifier.py` PostToolUse hook.
- Nine template-enforced artifact types (specs, clarification batches, verifier reports, decision records, etc.).
- Ten supporting skills (`flow-feature`, `flow-fix`, `flow-refactor`, `run-clarifier`, `run-verifier`, `triviality-detector`, `reuse-hint`, `decision-log`, `template-check`, `archive`, plus `bootstrap-project` which is replaced by `wyvrn-refresh-context`).
- `HARNESS.md`, `INDEX.md`, `DECISIONS.md`, and the `workflows/` folder.

If you're upgrading from v1.x:

1. Run `claude-wyvrn uninstall` followed by `claude-wyvrn install` to replace the global harness at `~/.claude-wyvrn/`.
2. In each project carrying v1.x artifacts, run `/migrate-foreign-framework` in Claude Code. It archives the removed v1.x folders (`features/`, `fixes/`, `refactors/`, `decisions/`, `clarifications/`, `reviews/`, `verifier-gaps/`, `.metrics/`) into `.claude-wyvrn-local/.archive/migration-<timestamp>/`. PROJECT.md, ARCHITECTURE.md, and `conventions/` are preserved in place.

## Layout

### Machine-wide — `~/.claude-wyvrn/`

| Path | Purpose |
|---|---|
| `VERSION` | `2.2.0` |
| `CLAUDE.md` | Template copied to project root by `claude-wyvrn setup`. |
| `conventions/universal.md` | Universal code rules. |
| `conventions/gitflow.md` | Branching and commit conventions. |
| `conventions/<stack>.md` | Stack-specific rules (javascript, typescript, python, csharp, cpp, react). |
| `templates/conventions.md` | Only template kept; used by `/wyvrn-refresh-context` when creating a new project stack-conventions file. |
| `skills/flow/SKILL.md` | The single runbook. |
| `skills/wyvrn-refresh-context/SKILL.md` | Populate/sync project-context files. |
| `skills/migrate-foreign-framework/SKILL.md` | Migrate non-Wyvrn projects in. |

### Per project — `.claude-wyvrn-local/`

| Path | Purpose |
|---|---|
| `PROJECT.md` | Project context, gotchas, idioms. Populated/synced by `/wyvrn-refresh-context`. |
| `ARCHITECTURE.md` | Module map, invariants. Populated/synced by `/wyvrn-refresh-context`. |
| `conventions/<stack>.md` | Project-specific stack conventions (overrides global on conflict). Optional. |
| `plans/` | Learning logs from each `/flow` run. Created on first run. Not auto-loaded into sessions. |

Track `.claude-wyvrn-local/` in git.

## Install and setup

The `claude-wyvrn` CLI handles install and setup. The global side of v1.x → v2.0.0 migration runs via `claude-wyvrn uninstall` + `claude-wyvrn install`; per-project migration runs via `/migrate-foreign-framework` (see below). From any machine:

```
claude-wyvrn install         # caches this repository and installs ~/.claude-wyvrn/ plus the skill registrations in Claude Code
claude-wyvrn setup           # in a project directory: lays down .claude-wyvrn-local/ and the project-root CLAUDE.md
```

If `claude-wyvrn setup` detects a foreign Claude framework (hand-written `CLAUDE.md`, `CONTEXT.md`, etc. at the project root), it prompts you to run `/migrate-foreign-framework` in Claude Code to harvest the content. The local `./.claude/` folder (Claude Code's own settings) is left alone — it is not part of Wyvrn.

If `claude-wyvrn` detects a v1.x install on `install`, it runs `uninstall` first (with a backup) and then installs v2.0.0 fresh. Per-project artifact migration is then handled by `/migrate-foreign-framework` in Claude Code.

The CLI itself is maintained separately from this repository.

## How `/flow` works

```
/flow <your task>

  Step 1   Read context (universal.md, gitflow.md, PROJECT.md, ARCHITECTURE.md)
           Retrieve relevant past mistakes from .claude-wyvrn-local/plans/
           Enter plan mode

  Step 2   Ask: follow gitflow? If yes, switch to the appropriate branch.
                              If already on it, proceed silently.
                              If no, stay on the current branch.

  Step 3   Ask only what cannot be inferred (goal, scope, acceptance, constraints).
           One batched AskUserQuestion call.

  Step 4   Confidence gate. Loop back to Step 3 until 95%+ confident. No cap.

  Step 5   Plan review (opt-in via PROJECT.md: plan-review: on). Default off.

  Step 6   Implement. Strict conventions.

  Step 7   Tests for executable-code changes. Run affected tests.

  Step 8   Self-verify against goals + tests + scope. Loop back to Step 7 if needed.

  Step 9a  Write a learning log to .claude-wyvrn-local/plans/.
  Step 9b  If a mistake or project change warrants a project-file update,
           invoke /wyvrn-refresh-context.

  Step 10  Push? (only if gitflow was followed in Step 2)
```

## Customization

- **`.claude-wyvrn-local/PROJECT.md`** — project specification. Domain context, gotchas, idioms, where things live. Auto-drafted via `/wyvrn-refresh-context` on a fresh install. Used by `/flow` as project context.
- **`.claude-wyvrn-local/conventions/<stack>.md`** — project-specific stack conventions. Overrides any matching global conventions per `universal.md` §3. Use `~/.claude-wyvrn/templates/conventions.md` as the starting template (or let `/wyvrn-refresh-context` create it).
- **`.claude-wyvrn-local/ARCHITECTURE.md`** — module map and invariants. Auto-drafted via `/wyvrn-refresh-context` from the codebase.
- **Plan review pause** — declare `plan-review: on` in PROJECT.md to make `/flow` pause for plan approval before implementation. Default `off`.

Machine-wide conventions go in `~/.claude-wyvrn/conventions/` and apply to every project on the machine. Typically maintained by whoever owns the harness install.

## What not to do

- **Don't edit files under `~/.claude-wyvrn/`** directly during a flow. The global harness is read-only during flows. Mistakes whose root cause is in the global harness should be logged and surfaced to the user; the user updates the global harness manually.
- **Don't hand-write learning logs.** They are produced by `/flow`. Writing them by hand bypasses the retrieval mechanism (greping by file/stack/keyword) and obscures the audit trail.
- **Don't expand `/flow` scope mid-flow.** If the work grows, finish the current flow and start a new one.

## Version

See `~/.claude-wyvrn/VERSION` for the installed harness version. Current: `2.2.0`.

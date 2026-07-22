---
name: migrate-foreign-framework
description: Migrate a project into the current claude-wyvrn (v2.0.0) layout. Handles two cases (independently or together): (1) foreign Claude framework — hand-written CLAUDE.md or ad-hoc Claude files at the project root; (2) previous Wyvrn version — v1.x `.claude-wyvrn-local/` containing folders removed in v2.0.0. Harvests preservable content; archives the originals and the removed v1.x folders.
---

# migrate-foreign-framework

Migrates a project into the v2.0.0 layout. Handles either or both of:

1. **Foreign Claude framework** — hand-written `CLAUDE.md` or ad-hoc Claude files at the project root. Harvests project content into PROJECT.md / ARCHITECTURE.md / project conventions; archives the originals.
2. **Previous Wyvrn version (v1.x)** — `.claude-wyvrn-local/` containing folders removed in v2.0.0 (`features/`, `fixes/`, `refactors/`, `decisions/`, `clarifications/`, `reviews/`, `verifier-gaps/`, `.metrics/`). Archives the removed folders; preserves PROJECT.md, ARCHITECTURE.md, and `conventions/`.

After migration, installs the v2.0.0 CLAUDE.md template at the project root if not already present.

## Trigger

- Slash: `/migrate-foreign-framework`.
- Natural: "migrate this project to claude-wyvrn", "convert my CLAUDE.md to wyvrn", "upgrade this project from v1 to v2.0.0", "archive my old wyvrn artifacts".
- Typically invoked by `claude-wyvrn setup` on detection of either case.

## Execution principles

- Parallelize independent reads, moves, and writes.
- All confirmations via `AskUserQuestion`.
- **POSIX syntax in Bash.** Never use PowerShell here-string syntax (`@'...'@`, `@"..."@`) in the Bash tool — it leaks stray `@` characters. Multi-line strings and commit messages use POSIX constructs (heredoc, or multiple `-m` flags).

## Preconditions

`~/.claude-wyvrn/VERSION` missing → halt: `Wyvrn harness not installed. Run claude-wyvrn install.`

## Constraints

- **Ignore `./.claude/`** entirely. That folder is Claude Code's own settings — unrelated to Wyvrn. Never read, write, or touch.
- **Never silently overwrite project files.** Writes go to new paths or paths explicitly authorized by the plan.
- **Always archive before deleting.** Foreign files and v1.x folders move to `.claude-wyvrn-local/.archive/migration-<ISO_TIMESTAMP>/`. Never `rm`.
- **Preserve v2.0.0-relevant artifacts.** `PROJECT.md`, `ARCHITECTURE.md`, `conventions/`, `plans/`, and any existing `.archive/` content are NOT moved.
- **No source-code changes.** Touches `.claude-wyvrn-local/` and archived foreign files only.
- **No new templates.** PROJECT.md and ARCHITECTURE.md are free-form. New `conventions/<stack>.md` uses `~/.claude-wyvrn/templates/conventions.md`.

## Behavior

### 1. Inventory (parallel batch)

Issue these reads/lists in one parallel batch:

**Foreign-framework signals** at project root:

- `CLAUDE.md` (case-sensitive). If byte-identical to `~/.claude-wyvrn/CLAUDE.md` or contains only a one-line `@~/.claude-wyvrn/CLAUDE.md` import → already v2.0.0; not foreign.
- `claude.md`, `CONTEXT.md`, `AGENTS.md`, `INSTRUCTIONS.md`, `CLAUDE_HINTS.md`, `.cursorrules`, other ad-hoc Claude-context files.

**Previous Wyvrn version (v1.x) signals** under `.claude-wyvrn-local/`:

- Folders removed in v2.0.0: `features/`, `fixes/`, `refactors/`, `decisions/`, `clarifications/`, `reviews/`, `verifier-gaps/`.
- v1.x metrics folder: `.metrics/`.

**Explicitly ignore `./.claude/`.**

Note presence and item counts per folder. Do not modify anything yet.

### 2. Classify content

**For foreign-framework files**, classify each meaningful piece:

- **Framework-specific (discard)** — generic "you are an AI assistant", boilerplate the harness supplies, instructions contradicting universal conventions.
- **Project description / context (preserve → PROJECT.md)** — name, purpose, domain, business rules, gotchas, idioms.
- **Architecture (preserve → ARCHITECTURE.md)** — module layout, interfaces, invariants, system overview.
- **Stack conventions (preserve → conventions/<stack>.md)** — project-specific rules about a tech stack.

When uncertain, preserve.

**For v1.x folders**, content is archived intact (preserved as read-only references; not re-migrated into v2.0.0 artifacts). Item counts surfaced in the plan summary.

### 3. Propose plan

Present a combined source-to-destination map. Show both kinds of migration when applicable:

```
Harvest from foreign framework:
  .claude-wyvrn-local/PROJECT.md (new)
    ← CLAUDE.md lines 12-20: project overview
    ← CLAUDE.md lines 21-30: quickstart commands
  .claude-wyvrn-local/ARCHITECTURE.md (new)
    ← CLAUDE.md lines 31-44: modules section
  .claude-wyvrn-local/conventions/typescript.md (new)
    ← CLAUDE.md lines 63-72: TypeScript style rules

Discarded (covered by harness):
  ← CLAUDE.md lines 1-11: generic AI-assistant preamble

Archived → .claude-wyvrn-local/.archive/migration-<TIMESTAMP>/:
  foreign/:
    - CLAUDE.md
    - CONTEXT.md
  v1-local/:
    - features/        (12 specs)
    - fixes/           (8 specs)
    - refactors/       (3 specs)
    - decisions/       (15 records)
    - clarifications/  (12 batches)
    - reviews/         (23 reports)
    - verifier-gaps/   (1 gap)
    - .metrics/        (verifier-findings log)

Preserved in place:
  - .claude-wyvrn-local/PROJECT.md (already filled, v1.x format still valid)
  - .claude-wyvrn-local/ARCHITECTURE.md (already filled)
  - .claude-wyvrn-local/conventions/ (kept)
```

AskUserQuestion header `Migration`, options `[Apply, Refine, Abort]`.

- `Refine` (or "Other" + text) → update plan; re-show.
- `Abort` → exit.

Chunk into sequential calls when the plan is very large.

### 4. Apply (parallel writes)

1. **Archive foreign originals and v1.x folders.** Create `.claude-wyvrn-local/.archive/migration-<ISO_TIMESTAMP>/`. Move in parallel:
   - Foreign originals → `.archive/migration-<TS>/foreign/`.
   - Each v1.x folder → `.archive/migration-<TS>/v1-local/<folder>/` (preserve internal structure).
   - Use `git mv` when the project is a git repo (so history is preserved); else plain move. Never delete.
2. **Write harvested content in parallel** (only for foreign-framework case):
   - `.claude-wyvrn-local/PROJECT.md` if any project context preserved AND the file does not already exist.
   - `.claude-wyvrn-local/ARCHITECTURE.md` if any architecture content preserved AND the file does not already exist.
   - `.claude-wyvrn-local/conventions/<stack>.md` for each preserved stack ruleset (start from `~/.claude-wyvrn/templates/conventions.md`). Only when the file does not already exist.
3. **Install harness CLAUDE.md** at project root from `~/.claude-wyvrn/CLAUDE.md`, unless the existing project-root CLAUDE.md is already byte-identical or a v2.0.0 `@`-import.
4. **Print summary** — archived, written, preserved, discarded paths.

## Edge cases

- **Only v1.x layout, no foreign framework** → run only the archive step; skip harvest+install.
- **Only foreign framework, no v1.x layout** → run only the harvest+install step; skip archive-v1.
- **Both** → run both steps.
- **`.claude-wyvrn-local/` already populated with v2.0.0-relevant filled files** (PROJECT.md, ARCHITECTURE.md, conventions/) → never overwrite. The harvest step writes only to absent slots. Surface in the summary which preserved files were already present.
- **Empty foreign file** → archive without extraction; skip harvest for that file.
- **Foreign content references missing files** → skip those references; note in summary.
- **v1.x folder is empty** (only `.gitkeep` inside) → still archive (preserves the historical intent) unless the user opts to skip via `Refine`.
- **User aborts mid-apply** → list every move/write performed so the user can manually revert.

## Output

```
Migration complete.

Archived to .claude-wyvrn-local/.archive/migration-2026-05-18T14-32-00Z/:
  foreign/
    - CLAUDE.md
    - CONTEXT.md
  v1-local/
    - features/        (12 specs)
    - fixes/           (8 specs)
    - refactors/       (3 specs)
    - decisions/       (15 records)
    - clarifications/  (12 batches)
    - reviews/         (23 reports)
    - verifier-gaps/   (1 gap)
    - .metrics/

Wrote:
  - CLAUDE.md (harness canonical, v2.0.0)
  - .claude-wyvrn-local/PROJECT.md (new)
  - .claude-wyvrn-local/ARCHITECTURE.md (new)
  - .claude-wyvrn-local/conventions/typescript.md (new)

Preserved (still relevant in v2.0.0):
  - .claude-wyvrn-local/PROJECT.md (already filled — left alone)
  - .claude-wyvrn-local/conventions/

Discarded (covered by harness):
  - 11 lines of generic AI-assistant preamble

Ignored (not part of Wyvrn):
  - ./.claude/ (Claude Code settings)

Next:
  - git add . && git commit
  - Open the new ARCHITECTURE.md and PROJECT.md to verify the merge.
  - Once satisfied, the archive directory can be deleted.
```

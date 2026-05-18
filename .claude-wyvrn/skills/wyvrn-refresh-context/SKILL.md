---
name: wyvrn-refresh-context
description: Populates and syncs Claude's project-context files in `.claude-wyvrn-local/` — PROJECT.md, ARCHITECTURE.md, and project-specific stack conventions — from the current codebase. Use on a fresh project, after codebase drift, or to absorb a lesson from /flow.
---

# wyvrn-refresh-context

Three jobs in one skill:

1. **Initial population** — draft `.claude-wyvrn-local/PROJECT.md` and `ARCHITECTURE.md` for a fresh project from manifests, README, and top-level layout.
2. **Incremental sync** — refresh existing files against current codebase reality.
3. **Lesson absorption** — apply a specific change proposed by `/flow` Step 9b.

Operates from `cwd`. All prompts via `AskUserQuestion`.

## Execution principles

- Parallelize independent reads, edits, and writes.
- All confirmations via `AskUserQuestion` — never ask the user to edit files to provide input.

## Preconditions

- `~/.claude-wyvrn/VERSION` missing → halt: `Wyvrn harness not installed. Run claude-wyvrn install.`
- `.claude-wyvrn-local/` missing → halt: `Project not set up. Run claude-wyvrn setup first.`

## Invocation modes

### Mode A — manual

User runs `/wyvrn-refresh-context`. Skill discovers what to do.

### Mode B — invoked by /flow Step 9b

Caller provides:

- **Scope** — one or more of: `PROJECT.md`, `ARCHITECTURE.md`, `conventions/<stack>.md`.
- **Proposed changes** — specific edits (e.g., "Add module `notifications` to ARCHITECTURE.md").

In Mode B, skip discovery; jump to step 4.

## Behavior

### 1. Inventory (parallel batch)

Read in one parallel batch:

- `.claude-wyvrn-local/PROJECT.md`, `ARCHITECTURE.md`, `conventions/*.md` — current state.
- Project-root signals required by scope:
  - **Manifests**: `package.json`, `pnpm-workspace.yaml`, `pyproject.toml`, `setup.py`, `setup.cfg`, `Pipfile`, `requirements.txt`, `Cargo.toml`, `go.mod`, `pom.xml`, `build.gradle*`, `composer.json`, `Gemfile`, `mix.exs`, `*.csproj`, `*.sln`, `CMakeLists.txt`, `Makefile`.
  - **READMEs**: `README.md`, `README.rst`, `README.txt`.
  - **Top-level directories** (one level): `src/`, `lib/`, `app/`, `pkg/`, `internal/`, `tests/`, `test/`, `spec/`, `docs/`, `examples/`, `scripts/`, `tools/`, `cmd/`, `apps/`, `packages/`.
  - **CI**: `.github/workflows/*.yml`, `.gitlab-ci.yml`, `.circleci/config.yml`, `azure-pipelines.yml`, `Jenkinsfile`.
  - **Project config**: `.editorconfig`, `tsconfig.json`, `.eslintrc*`, `.prettierrc*`, `Dockerfile`, `docker-compose.yml`.

Do not modify anything yet.

### 2. Detect mode

- Mode B (proposed changes supplied) → step 4.
- All target files absent or templated → **initial population**.
- Target files exist and are filled → **incremental sync**: diff against inventory.

### 3. Draft changes (Mode A only)

#### Initial population

Build drafts in working memory:

- **PROJECT.md** — name, description, quickstart commands, stack summary, where-to-find-what, reference links. Uninferable sections (domain glossary, idioms, gotchas) get `<unknown — fill in by hand>` placeholders.
- **ARCHITECTURE.md** — system overview, one subsection per inferred module (path, status, responsibility), external dependencies from manifest, invariants `N/A` if none inferred.
- Stack-conventions files are NOT auto-drafted; created only when a Mode B proposal targets them.

#### Incremental sync

For each in-scope file, identify discrete changes:

- New modules in tree, not in ARCHITECTURE.md → propose add.
- Modules in ARCHITECTURE.md, gone from tree → propose remove.
- New/removed manifest dependencies → propose add/remove.
- New stack detected (extension distribution crosses threshold) → propose PROJECT.md update + offer to create `conventions/<stack>.md` from `~/.claude-wyvrn/templates/conventions.md`.
- Stale claims contradicting reality → propose correction.

### 4. Propose and confirm

Present changes as one batched summary per target file.

AskUserQuestion header `Refresh`, options `[Apply all, Refine, Abort]`.

- `Refine` (or "Other" + text) → update changes; re-show.
- `Abort` → exit without writes.

Chunk into sequential calls per target file when >10 discrete changes.

### 5. Apply (parallel writes)

On confirmation:

1. For new stack-conventions files: copy `~/.claude-wyvrn/templates/conventions.md`, fill sections.
2. For PROJECT.md and ARCHITECTURE.md: free-form. Write or edit directly. No template enforcement.
3. PROJECT.md may grow a `Known patterns to remember` / `Gotchas` section over time. Append; do not replace existing entries.
4. Issue independent file writes in parallel.
5. Print summary.

## Edge cases

- **Filled PROJECT.md, Mode A proposes wholesale rewrite** → refuse. Offer targeted edits, or back up as `PROJECT.md.bak-<ISO_TIMESTAMP>` only on explicit confirmation.
- **ARCHITECTURE.md is the unfilled template** → treat as initial population.
- **No manifest, no recognizable structure** (Mode A initial) → one AskUserQuestion round before drafting (headers `Name`, `Stack`, `Layout`; 2 placeholder options each).
- **Monorepo** → each workspace member is a module in ARCHITECTURE.md. Stack summary lists all workspace stacks.
- **Mode B targets a `conventions/<stack>.md` that doesn't exist** → copy the template, fill.
- **User aborts mid-apply** → list written files so the user can revert.

## Constraints

- Do NOT modify `~/.claude-wyvrn/`.
- Do NOT overwrite filled PROJECT.md or ARCHITECTURE.md without explicit confirmation + backup.
- Do NOT touch source code, configs, or anything outside `.claude-wyvrn-local/`.
- All prompts via `AskUserQuestion`.

## Output

```
Refresh complete.

Wrote:
  - .claude-wyvrn-local/ARCHITECTURE.md (added module `notifications`)
  - .claude-wyvrn-local/conventions/typescript.md (new — pattern: wrap API calls in try/catch with project logger)

Unchanged:
  - .claude-wyvrn-local/PROJECT.md

Next:
  - git add .claude-wyvrn-local/ && git commit
```

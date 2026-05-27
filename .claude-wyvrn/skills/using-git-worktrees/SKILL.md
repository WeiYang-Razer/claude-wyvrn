---
name: worktree
description: Isolate a task in a dedicated git worktree to avoid dirty-state contamination. Trigger when the user says "isolate this", "use a worktree", "work in isolation", or invokes /worktree directly. Creates a clean checkout, installs deps, and confirms a passing baseline before work begins.
---

# worktree

Sets up an isolated git worktree for a task. Keeps the main working tree clean while work happens in a dedicated checkout. Handles cleanup when the task is done.

## Execution principles

- Parallelize independent reads (manifest detection, git status) at Step 1.
- Never nest worktrees inside a standard (non-bare) repo. Bare-repo worktrees are peers — no nesting occurs.
- In bare-repo mode, all worktrees are peers. Do not modify other worktrees' files.

## Preconditions

- `~/.claude-wyvrn/VERSION` missing → halt: `Wyvrn harness not installed. Run claude-wyvrn install.`
- Not a git repository → halt: `Not a git repository. git worktrees require a git repo.`

## Trigger

- Slash: `/worktree` (create) or `/worktree remove` (cleanup)
- Natural: "isolate this", "use a worktree", "work in isolation", "set up a worktree for"

## Behavior

### Creating a worktree

#### Step 1 — Detect current state (parallel batch)

Run in one parallel batch:

- `git rev-parse --is-bare-repository` — true if CWD is a bare repo.
- `git rev-parse --git-common-dir` — path to the shared git store.
- `git rev-parse --git-dir` — path to this worktree's git dir.
- `git branch --show-current` — current branch name (empty in bare root).
- `git status --short` — uncommitted changes (skip if bare root).
- Detect package manager: check for `package.json` + lockfile (`pnpm-workspace.yaml` / `pnpm-lock.yaml` → pnpm; `yarn.lock` → yarn; `package-lock.json` → npm), `pyproject.toml`/`requirements.txt` → pip/uv, `Cargo.toml` → cargo, `go.mod` → go, `Gemfile` → bundle, `*.csproj` → dotnet.

**Classify repo shape from the results:**

```
if is-bare-repository == "true":
    shape = BARE_ROOT        # CWD is the bare repo itself
    bare_root = CWD
elif git-common-dir != git-dir:
    run: git -C <git-common-dir> rev-parse --is-bare-repository
    if result == "true":
        shape = WORKTREE_OF_BARE   # peer worktree — valid, no warning
        bare_root = git-common-dir
    else:
        shape = WORKTREE_OF_STANDARD  # nesting — warn
else:
    shape = STANDARD_ROOT
```

**Shape-specific handling:**

- **BARE_ROOT**: note that no working files exist here; worktrees will be created below the bare root.
- **WORKTREE_OF_BARE**: peer worktree of a bare repo — proceed without any nesting warning.
- **WORKTREE_OF_STANDARD**: emit warning `Already inside a git worktree. Nesting worktrees is unsupported.`
  AskUserQuestion header `Worktree`, options `[Proceed anyway (create nested), Abort]`. Default safe choice is `Abort`.
- **STANDARD_ROOT**: proceed normally.

If uncommitted changes exist (non-bare shapes): note them in the summary at Step 3 (do not block — the user may want to carry them to the worktree branch).

#### Step 2 — Propose branch and path

**Branch name**: follow `gitflow.md` naming if available (e.g., `feature/<INITIALS>_<camelCaseName>`); else propose `worktree/<slug>`.
**Base branch**: current branch unless user specifies otherwise (for BARE_ROOT, use `master` or `main`).

**Worktree path** — depends on repo shape:

| Shape | Proposed path |
|---|---|
| BARE_ROOT or WORKTREE_OF_BARE | `<bare_root>/<new-branch-path>/` — mirrors the branch name (e.g., bare root `C:\Proj\chroma2.git`, branch `feature/my-thing` → `C:\Proj\chroma2.git\feature\my-thing\`) |
| STANDARD_ROOT or WORKTREE_OF_STANDARD | `../$(basename $(pwd))-worktrees/<branch-slug>/` |

AskUserQuestion header `Worktree setup`, options:
- `[Use proposed path and branch, Customize path/branch, Abort]`

If `Customize path/branch` → ask follow-up questions for path and branch name separately.

#### Step 3 — Create worktree

```
git worktree add <path> -b <branch> <base>
```

Emit the command before running it. On failure, emit the full error and halt.

#### Step 4 — Install dependencies

Based on detected package manager, run the install command in the worktree directory:

| Manager | Command |
|---|---|
| pnpm | `pnpm install` |
| yarn | `yarn install` |
| npm | `npm install` |
| pip/uv | `pip install -e .` or `uv sync` if `uv.lock` present |
| cargo | `cargo fetch` |
| go | `go mod download` |
| bundle | `bundle install` |
| dotnet | `dotnet restore` |

If no package manager detected → skip with note.

#### Step 5 — Baseline test run

Run the project's test suite (minimal/fast subset if the full suite is slow) **from the newly created worktree** — not from the calling directory. This matters especially for BARE_ROOT, where the bare repo itself has no source files.

- Detect test runner from manifest scripts or config files (e.g., `jest`, `pytest`, `cargo test`, `go test ./...`, `dotnet test`).
- Run with a short timeout. If no test runner detected → skip with note.
- If baseline fails → halt. Emit: `Baseline tests failed in the worktree. Fix before starting work, or the worktree may have an incorrect starting state.` Show the failures.

#### Step 6 — Confirm ready

Emit:

```
Worktree ready.

Path:    <worktree-path>
Branch:  <branch-name>
Base:    <base-branch>
Deps:    installed (<manager>)
Baseline: ✓ (<N> tests passed)

cd <worktree-path>
```

---

### Removing a worktree

Trigger: `/worktree remove` or "remove the worktree", "clean up the worktree"

#### Step 1 — Identify worktrees

Run `git worktree list` and emit the current worktree list.

AskUserQuestion header `Remove worktree`, options based on the listed worktrees (up to 4; use "Other" for manual path entry if more exist).

#### Step 2 — Confirm and remove

AskUserQuestion header `Confirm remove`, options `[Remove (branch stays), Remove and delete branch, Cancel]`.

- `Remove (branch stays)` → `git worktree remove <path>`. Branch is preserved.
- `Remove and delete branch` → `git worktree remove <path>` then `git branch -d <branch>` (safe delete; will not delete unmerged branches without a second explicit confirmation).
- `Cancel` → halt.

Emit summary of what was removed.

## Stop conditions

- User aborts at any step → halt, no worktree created or removed.
- `git worktree add` fails → halt with error output.
- Baseline tests fail → halt with failure summary.

## Constraints

- **Standard repos**: do not modify the main working tree's files or configs while a worktree is active.
- **Bare repos (BARE_ROOT / WORKTREE_OF_BARE)**: all worktrees are peers — no main tree exists. Do not modify other worktrees' files.
- Do NOT force-delete branches (`-D`) without a second explicit confirmation.
- Do NOT modify `~/.claude-wyvrn/`.
- All confirmations via `AskUserQuestion`.

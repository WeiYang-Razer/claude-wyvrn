# bootstrap-project

Drafts and writes the initial `.claude-wyvrn-local/PROJECT.md` and `.claude-wyvrn-local/ARCHITECTURE.md` for a freshly installed project, by reading the codebase and confirming the draft with the human.

## Trigger

Slash command: `/bootstrap-project`

Natural language: "bootstrap the project files", "fill in PROJECT.md and ARCHITECTURE.md from the repo", "initialize wyvrn for this project", or equivalent.

Typically invoked once after the harness skeleton has been copied into a new project. May also be invoked later if the human wants to redraft from the current repo state. The skill detects whether redrafting is appropriate and refuses to overwrite existing content (see §8).

## Description

The harness installer drops an empty `ARCHITECTURE.md` template and no `PROJECT.md`. This skill auto-drafts both files by inspecting the project root — package manifests, top-level directory layout, README, CI configs — and proposes a populated draft of each file. The human reviews via `AskUserQuestion` and either accepts or refines. On accept, the skill writes the files; the template-verifier hook fires automatically on each write per `HARNESS.md` §4.6.

This skill is the install-time analog of `migrate-foreign-framework`. The latter handles projects that already have ad-hoc Claude content; this one handles projects that have nothing.

This skill is invoked from the project root. It reads files there directly and proposes changes interactively per `HARNESS.md` §8.

## Inputs

The skill takes no parameters. It works on the current directory (`cwd`).

## Behavior

### 1. Pre-flight checks

Verify the bootstrap precondition before any inspection:

- `~/.claude-wyvrn/` exists and contains `VERSION`, `HARNESS.md`, `INDEX.md`. If not, halt with: "Wyvrn harness not installed at `~/.claude-wyvrn/`. Run `claude-wyvrn install` first."
- `.claude-wyvrn-local/` exists at project root. If not, halt with: "Project skeleton missing at `.claude-wyvrn-local/`. Copy the skeleton from the harness package first."
- `.claude-wyvrn-local/ARCHITECTURE.md` matches the unfilled template (the canonical `~/.claude-wyvrn/templates/architecture.md` byte-equivalent or with only the `<placeholder>` tokens unreplaced). If it has been filled, halt per §8.
- `.claude-wyvrn-local/PROJECT.md` does **not** exist. If it does, halt per §8.

If all checks pass, proceed.

### 2. Inventory the project root

Read, but do not modify, the following if present:

- `README.md`, `README.rst`, `README.txt`
- Manifests: `package.json`, `pnpm-workspace.yaml`, `pyproject.toml`, `setup.py`, `setup.cfg`, `Pipfile`, `requirements.txt`, `Cargo.toml`, `go.mod`, `pom.xml`, `build.gradle`, `build.gradle.kts`, `composer.json`, `Gemfile`, `mix.exs`, `*.csproj`, `*.sln`, `CMakeLists.txt`, `Makefile`
- Top-level directory listing (one level deep). Note presence of: `src/`, `lib/`, `app/`, `pkg/`, `internal/`, `tests/`, `test/`, `spec/`, `docs/`, `examples/`, `scripts/`, `tools/`, `cmd/`, `apps/`, `packages/`
- CI configs: `.github/workflows/*.yml`, `.gitlab-ci.yml`, `.circleci/config.yml`, `azure-pipelines.yml`, `Jenkinsfile`
- Project-level config: `.editorconfig`, `tsconfig.json`, `.eslintrc*`, `.prettierrc*`, `pyproject.toml` `[tool.*]` tables, `Dockerfile`, `docker-compose.yml`

For each file read, hold its content in working state. Do not write.

### 3. Inventory the harness templates

Read the harness templates and reference files:

- `~/.claude-wyvrn/templates/architecture.md`
- `~/.claude-wyvrn/templates/project.md`
- `~/.claude-wyvrn/templates/clarification-batch.md`
- `~/.claude-wyvrn/INDEX.md`
- `~/.claude-wyvrn/HARNESS.md` (already loaded per the start-of-flow reading sequence)

### 4. Infer project facts

From the inventory, derive:

| Fact | Derivation order, first hit wins |
|---|---|
| Project name | First manifest `name` field → README H1 → root directory basename |
| Description | First manifest `description` field → README first non-heading paragraph → `<unknown>` |
| Stack(s) | Manifest extensions cross-checked against extension distribution in tree (e.g., `pyproject.toml` + >50% `.py` files → `python`) |
| Modules | Top-level directories that contain source files, excluding `node_modules/`, `vendor/`, `.git/`, `dist/`, `build/`, `target/`, `.venv/`, `__pycache__/`, `.claude-wyvrn-local/` |
| External dependencies | Direct dependencies from manifests, with declared version constraint and a one-line purpose if obvious |
| Quickstart commands | Manifest `scripts` (`package.json`), `[project.scripts]` / `[tool.poetry.scripts]` (`pyproject.toml`), `Makefile` targets, README quickstart blocks |
| Validation mode | Default `non-blocking`. Override only if the human states otherwise |
| CI presence | Names of CI files found, recorded under `Where to find what` |
| Reference links | URLs harvested from README's links section if present |

If no manifest is detected and no clear top-level structure exists (e.g. flat repo with mixed-language files), halt before drafting and invoke `AskUserQuestion` per `HARNESS.md` §8 — one call with 3 questions: header `Name` ("What is the project name?"), header `Stack` ("What is the primary stack?"), header `Layout` ("What is the intended top-level structure?"). For each question supply 2 placeholder options (e.g., a guess inferred from repo basename, plus `<unknown>`); the human's actual answer arrives via the auto-added "Other". Bootstrap is not a workflow flow; do not invoke `run-clarifier` and do not produce a clarification batch artifact. Capture the answers in working memory and proceed to §5.

### 5. Draft both files

Build the drafts in working memory:

- **`.claude-wyvrn-local/PROJECT.md`** from `~/.claude-wyvrn/templates/project.md`. Fill: project name, description, quickstart commands, stack summary, validation mode, where-to-find-what, reference links. Domain glossary, patterns and idioms, things to know, and out-of-scope topics start with explicit `<unknown — fill in after bootstrap>` placeholders, since these cannot be inferred from the codebase. Mark `**Last updated by:** human` and use the current ISO 8601 timestamp.

- **`.claude-wyvrn-local/ARCHITECTURE.md`** from `~/.claude-wyvrn/templates/architecture.md`. Fill: system overview (one paragraph synthesized from README + manifest description), modules (one subsection per inferred module from §4 with path, `**Status:** Active`, responsibility inferred from directory name and contents, interfaces left as `<unknown — fill in>` if not obvious from public exports, dependencies extracted from import scans where cheap), external dependencies (from manifest), architectural invariants left as `N/A`, cross-module contracts left as `N/A`. Mark `**Last updated by:** human`.

Do **not** write either file yet.

### 6. Present the plan and confirm

Show the human a structured summary in the active session (raw text emit per `HARNESS.md` §8.2.6 — the prompt itself follows). Format follows `migrate-foreign-framework` Phase 4 — sources to destinations first, full content second.

Stage A — sources to destinations:

```
.claude-wyvrn-local/PROJECT.md (new)
  ← project name from package.json#name
  ← description from README.md lines 1-8
  ← quickstart commands from package.json#scripts
  ← stack summary inferred: typescript (45 files), python (12 files)
  ← reference links from README.md "Links" section
  ← validation mode: non-blocking (default)
  ← domain glossary / patterns / things to know: <unknown>, flagged for human fill-in

.claude-wyvrn-local/ARCHITECTURE.md (filling unfilled template)
  ← system overview synthesized from README.md + package.json
  ← module: src/ (Active, primary code)
  ← module: tests/ (Active, test suite)
  ← external dependencies: 14 entries from package.json
  ← invariants: N/A (none inferred)
```

Then invoke `AskUserQuestion` per `HARNESS.md` §8 — single question, header `Plan`, options `[Confirm plan, Refine, Abort]`. On `Refine` (the auto-added "Other" carries the refinement text, e.g., "rename module X", "add invariant Y", "set validation: blocking", "merge tests/ into src/ as a sub-module"), update working drafts and re-render Stage A. On `Abort`, proceed per §8.

Stage B — once the source-to-destination plan is approved, render the **full draft** of each file in the session for one final review. Then invoke `AskUserQuestion` per `HARNESS.md` §8 — single question, header `Final`, options `[Confirm and write, Refine, Abort]`. On `Refine`, accept refinements via the auto-added "Other" and re-render Stage B.

### 7. Apply

On final confirm:

1. Write `.claude-wyvrn-local/PROJECT.md` with the agreed content.
2. Write `.claude-wyvrn-local/ARCHITECTURE.md` with the agreed content (replacing the unfilled template, not appending to it).
3. The template-verifier hook (`hooks/template_verifier.py` per `HARNESS.md` §4.6) runs automatically on each write. If the hook returns findings via stderr, correct the file and re-write until the hook is silent.
4. Print summary per the Output section.

### 8. Edge cases

- **`PROJECT.md` already exists.** Do not overwrite. Halt with: "`.claude-wyvrn-local/PROJECT.md` already exists. Use `/migrate-foreign-framework` to merge external content, or edit by hand. Aborting." Same protection as `migrate-foreign-framework` Phase 6.
- **`ARCHITECTURE.md` is non-empty and not the unfilled template.** Do not overwrite. Halt with: "`.claude-wyvrn-local/ARCHITECTURE.md` has been filled. Aborting to preserve content." Offer the human the option to draft `PROJECT.md` only.
- **No manifest, no recognizable structure.** Run one clarification round before drafting (see §4).
- **Monorepo detected** (workspace manifest, multiple sub-manifests). Treat each top-level workspace member as a module in `ARCHITECTURE.md`. Stack summary lists every workspace stack.
- **Harness installed but partial.** Halt before any work per §1.
- **Human aborts mid-plan.** Accept abort. Invoke `AskUserQuestion` per `HARNESS.md` §8 — single question, header `Abort`, options `[Confirm abort, Resume]`. Note in the question text whether nothing has been written yet, or — if step 7 already wrote one of the two files — list what was written.

## Constraints

- **Never overwrite existing project content.** `PROJECT.md` and any non-template `ARCHITECTURE.md` are sacrosanct. The skill writes only when the slot is provably empty.
- **Never invent a new template.** Use `templates/project.md` and `templates/architecture.md` as-is. Inferred content goes into the existing slots; placeholders flag what could not be inferred.
- **Never skip the human-confirm step.** The whole point of this skill versus a fully automated bootstrap is that the human reviews before write.
- **No code production.** This skill produces only the two artifacts. It does not touch source files, configs, or `~/.claude-wyvrn/`.
- **No stack-convention drafting.** If the human wants project stack-conventions files, that is a separate concern handled by hand-authoring under `.claude-wyvrn-local/conventions/` using `templates/conventions.md`. Bootstrap does not auto-create those.
- **Respect `HARNESS.md` §8.** All prompts go through `AskUserQuestion`. Never instruct the human to edit the file to provide input.

## Output

A summary printed to the session, of the form:

```
Bootstrap complete.

Wrote:
  - .claude-wyvrn-local/PROJECT.md (new)
  - .claude-wyvrn-local/ARCHITECTURE.md (filled from template)

Inferred:
  - 3 modules: src/, lib/, tests/
  - 14 external dependencies
  - Stack: typescript, python

Flagged for human follow-up (placeholder values written):
  - Domain glossary
  - Patterns and idioms
  - Things to know
  - Out-of-scope topics

Next:
  - Open PROJECT.md and fill the flagged sections.
  - git add .claude-wyvrn-local/PROJECT.md .claude-wyvrn-local/ARCHITECTURE.md && git commit
  - Run /flow-feature, /flow-fix, or /flow-refactor when ready.
```

## Invokes

- template-verifier hook (`hooks/template_verifier.py`, fires automatically on each written file per `HARNESS.md` §4.6).

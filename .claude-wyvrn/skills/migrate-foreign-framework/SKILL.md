# migrate-foreign-framework

Migrates a project that's using a different Claude convention (e.g. a hand-written `CLAUDE.md`, a `.claude/` directory, or any other ad-hoc Claude setup) into the claude-wyvrn harness layout.

## Trigger

Slash command: `/migrate-foreign-framework`

Natural language: "migrate this project to claude-wyvrn", "convert my CLAUDE.md to the wyvrn harness", or equivalent.

Typically invoked by the `claude-wyvrn` CLI's `setup` command when it detects a foreign Claude framework in the current directory. May also be invoked directly by a user.

## Description

The CLI handles the *detection* (foreign framework present) and confirms the user wants to migrate. This skill does the *content migration* — distinguishing project-specific content worth preserving from framework-specific content that's superseded by the harness, archiving the originals, and producing a clean claude-wyvrn layout that incorporates the user's keep-worthy content.

This skill is invoked from the project root. It reads files there directly and proposes changes interactively.

## Inputs

The skill takes no parameters. It works on the current directory (`cwd`).

## Behavior

### 1. Inventory existing files

Inspect the project root for any of:

- `CLAUDE.md` (case-sensitive)
- `.claude/` directory and its contents
- `claude.md`, `CONTEXT.md`, `AGENTS.md`, `INSTRUCTIONS.md`, or other plausible Claude-convention files at the project root

For each file or directory found, read its full content. **Do not modify anything yet.**

### 2. Inventory the harness templates

Read the relevant harness templates and reference files so you understand the target layout:

- `~/.claude-wyvrn/HARNESS.md` — what agents are expected to know
- `~/.claude-wyvrn/INDEX.md` — the navigation map
- `~/.claude-wyvrn/templates/architecture.md` — `.claude-wyvrn-local/ARCHITECTURE.md` template
- `~/.claude-wyvrn/templates/conventions.md` — stack-conventions template
- `~/.claude-wyvrn/conventions/CONVENTIONS.md` — universal conventions

You also need the canonical files that ship at the project-root level:

- The `CLAUDE.md` shipped by the harness (visible via `claude-wyvrn` cache or the public repo).
- The `.claude-wyvrn-local/` skeleton (a directory with `ARCHITECTURE.md`, empty `features/`, `fixes/`, `decisions/`, etc.).

If the harness is not installed (no `~/.claude-wyvrn/`), halt and report: "Harness not installed. Run `claude-wyvrn install` first."

### 3. Classify the existing content

Read the foreign files line by line. For each meaningful piece of content, classify it as one of:

- **Framework-specific (discard).** Generic instructions like "you are an AI assistant", "be helpful", "use markdown", or boilerplate that the harness already supplies. Also: instructions about *how* the agent should work that conflict with `HARNESS.md` (the harness rules win).

- **Project-specific (preserve).** Content that describes *this project's* code, architecture, conventions, modules, invariants, business rules, or domain. The kind of thing that would be lost if discarded.

- **Project-specific stack conventions (preserve to `conventions/`).** Project-level rules about a specific tech stack (e.g. "all React components use functional style", "Python tests live in `tests/`"). These belong under `.claude-wyvrn-local/conventions/<stack>.md` using the conventions template.

Be conservative with discards: when uncertain, preserve. The user can prune later.

### 4. Propose a migration plan

Present a clear plan to the user, organized by destination file. For each destination, list the source content that will be merged in and where it came from.

**Destination heuristic.** PROJECT.md is the default destination for project-narrative content harvested from CLAUDE.md — its sections (Description, Quickstart commands, Stack summary, Domain glossary, Patterns and idioms, Things to know, Where to find what, Reference links) are designed to absorb most CLAUDE.md content. Architecture diagrams and module layout go to ARCHITECTURE.md. Stack-specific code rules go to `conventions/[stack].md`. When in doubt, prefer PROJECT.md.

Example shape:

```
.claude-wyvrn-local/PROJECT.md (new file)
  ← from CLAUDE.md, lines 12-20: project overview → Description
  ← from CLAUDE.md, lines 21-30: build/test/run commands → Quickstart commands
  ← from CLAUDE.md, lines 31-38: stack list → Stack summary
  ← from CLAUDE.md, lines 39-44: project glossary → Domain glossary
  ← from CLAUDE.md, lines 45-55: business rules and idioms → Patterns and idioms
  ← from CLAUDE.md, lines 56-62: gotchas → Things to know
  ← from .claude/context.md: full content → split between Description and Things to know

.claude-wyvrn-local/ARCHITECTURE.md (use template, fill from existing)
  ← from CLAUDE.md, lines 31-44: "Modules" section → Modules
  ← from .claude/architecture.txt: directory layout → Modules

.claude-wyvrn-local/conventions/typescript.md (new file)
  ← from CLAUDE.md, lines 63-72: "TypeScript style" rules → Naming / Formatting / etc.

Discarded (already covered by the harness):
  ← from CLAUDE.md, lines 1-11: generic "you are an AI" preamble
  ← from CLAUDE.md, lines 73-80: "always be polite" instructions

Archived (originals saved to .claude-wyvrn-local/.archive/migration-{TIMESTAMP}/):
  CLAUDE.md (original)
  .claude/ (entire directory)
```

Show the plan in full. Do **not** show the entire content of the destination files at this stage — just the structure and what feeds where.

Then invoke `AskUserQuestion` per `HARNESS.md` §8 — single question, header `Plan`, options `[Confirm plan, Refine, Abort]`. On `Refine` (the auto-added "Other" carries the refinement text, e.g., "move X from PROJECT.md to ARCHITECTURE.md", "preserve Y instead of discarding it"), update the plan accordingly and re-show after substantial edits. On `Abort`, proceed per §6.

### 5. Apply the plan

Once the user confirms the plan, execute it in this order:

1. **Archive originals.** Create `.claude-wyvrn-local/.archive/migration-{ISO_TIMESTAMP_WITH_HYPHENS}/` and move every foreign file (CLAUDE.md, .claude/, etc.) into it. Use `git mv` if the project is a git repository so history is preserved; otherwise plain `mv`. Never delete originals — always move to archive.

2. **Install the harness skeleton.** Copy from `~/.claude-wyvrn/` or the cache (whichever the user pointed to):
   - The canonical `CLAUDE.md` to the project root
   - The `.claude-wyvrn-local/` skeleton (only files that don't already exist; never overwrite existing user data)

3. **Write the merged content** into the destinations from the plan:
   - `.claude-wyvrn-local/PROJECT.md` if any project-context content was preserved
   - `.claude-wyvrn-local/ARCHITECTURE.md` filled in from preserved architecture content (rather than left as the empty template)
   - `.claude-wyvrn-local/conventions/<stack>.md` for any preserved stack conventions
   - Any other harness-allowed location based on the plan

For each written file, ensure it follows the relevant template's structure (load the template first, fill in fields). The template-verifier hook fires automatically on each write per `HARNESS.md` §4.6 — correct any findings it surfaces and re-write until silent.

4. **Print a summary** of what was done, with paths. Mention that the originals are still available in the archive directory.

### 6. Edge cases

- **Empty foreign files.** If `CLAUDE.md` exists but is empty or near-empty (no real content), archive it without trying to extract anything; just install the harness fresh.

- **The foreign content references files that don't exist anymore.** Skip those references in the migration; note in the summary that they were found but the target files weren't present.

- **The project already has `.claude-wyvrn-local/`** with user data. This shouldn't happen if the CLI invoked us correctly (it routes claude-wyvrn-detected projects to a different code path), but if it does: preserve the existing data, do **not** overwrite anything inside `.claude-wyvrn-local/`, and only fill in files that don't yet exist.

- **The harness is missing or partially installed.** Halt with a clear message before any file modifications. Tell the user to run `claude-wyvrn install` and retry.

- **The user wants to abort mid-plan.** Accept abort at any stage. Before aborting, invoke `AskUserQuestion` per `HARNESS.md` §8 — single question, header `Abort`, options `[Confirm abort, Resume]`. Note in the question text whether nothing has been written yet, or — if writes have started — list what was written so the user can manually revert.

## Constraints

- **Never silently overwrite project files.** Every write must be either to a path that didn't previously exist, or to one explicitly authorized by the migration plan.
- **Always archive before deleting.** This skill never `rm`s a foreign file — it always moves to `.claude-wyvrn-local/.archive/migration-{TIMESTAMP}/`.
- **No new templates.** Use the harness templates as-is. Don't invent new artifact types or template variants for migration.
- **No agent-system changes.** Don't try to translate the user's old framework's rules into agent rules. The harness `HARNESS.md` rules are the rules. Project-specific overrides go through the documented override paths (`PROJECT.md`, `conventions/`, `ARCHITECTURE.md`).

## Output

A summary printed to the session, of the form:

```
Migration complete.

Archived to .claude-wyvrn-local/.archive/migration-2026-04-27T19-15-00Z/:
  - CLAUDE.md
  - .claude/

Wrote:
  - CLAUDE.md (harness canonical)
  - .claude-wyvrn-local/ARCHITECTURE.md (filled from archived content)
  - .claude-wyvrn-local/PROJECT.md (new, project-specific context)
  - .claude-wyvrn-local/conventions/typescript.md (new)

Discarded (covered by the harness):
  - 11 generic AI-assistant instruction lines

Next:
  - git add . && git commit
  - Open the new ARCHITECTURE.md and PROJECT.md and verify the merged content reads correctly.
  - Once you're satisfied, the archive directory can be deleted (or kept for posterity).
```

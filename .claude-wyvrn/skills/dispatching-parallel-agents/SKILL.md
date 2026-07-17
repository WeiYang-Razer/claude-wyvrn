---
name: parallel-agents
description: Fan out genuinely independent work to multiple subagents at once — all dispatched in a single message so they run concurrently — then reconcile and verify the results. Trigger when the user says "do these in parallel", "fan out", "spawn an agent for each", "research these areas at once", or invokes /parallel-agents directly.
---

# parallel-agents

Runs N independent work units concurrently by dispatching N subagents in one message, then reconciling their results in the main thread. The whole value depends on the units being genuinely independent — the skill front-loads an independence check and refuses to parallelize work that conflicts.

**Standalone by design.** Use directly for a fan-out task, or as the parallel arm of `/subagent-dev` when its decomposition yields parallel-eligible tasks. Never injected into `/flow`.

## Execution principles

- **Parallelize only genuinely independent work.** The test: no two agents write the same file, and no agent needs another's output. If that fails, serialize instead.
- **One message, many agents.** Concurrency comes from issuing all `Agent` calls in a single tool-use block. Separate messages run sequentially and defeat the purpose.
- **Self-contained, slice-bounded briefs.** Each agent gets its own slice and is told to stay inside it.
- **Reconcile and verify in the main thread.** One agent succeeding says nothing about the others; check each result independently.
- **POSIX syntax in Bash.** Never use PowerShell here-string syntax (`@'...'@`, `@"..."@`) in the Bash tool — it leaks stray `@` characters. Multi-line strings and commit messages use POSIX constructs (heredoc, or multiple `-m` flags). This binds the main thread and every dispatched agent.

## Preconditions

If `~/.claude-wyvrn/VERSION` missing → halt: `Wyvrn harness not installed. Run claude-wyvrn install.`

## Trigger

- Slash: `/parallel-agents <task spanning independent units>`
- Natural: "do these in parallel", "fan out", "spawn an agent for each", "research these areas at the same time"

## Behavior

### Step 1 — Load context (parallel batch)

For implementation work, read `.claude-wyvrn-local/PROJECT.md` (or `README.md`), `ARCHITECTURE.md` if present, and the relevant stack conventions in one parallel batch. Skip for pure research fan-out.

### Step 2 — Independence check (gate)

Enumerate the work units. For each pair, confirm:

- **Disjoint file sets** — no two writing agents touch the same file.
- **No data dependency** — no unit needs another unit's output.
- **No shared mutable state** — no contended resource (same migration, same lockfile, same generated artifact).

State the verdict explicitly. If any pair conflicts → either serialize the conflicting units via `/subagent-dev`, or split the run into waves so each wave is internally independent. **Do not force parallelism on dependent work.**

### Step 3 — Brief each unit

Each brief is self-contained and bounds the agent to its slice:

- **Scope** — this unit only, and an explicit "do not touch files outside: <list>".
- **Files** — exact paths, disjoint from sibling agents.
- **Change / research spec** — complete enough to act without guessing.
- **Report back** — what to return (files changed + tests run + outcome, or research findings).
- **Conventions** — matching stack convention for implementation units.
- **Mode** — write code, or research/read only.

### Step 4 — Dispatch all in one message

Issue every agent as a separate `Agent` call inside a single message so they run concurrently. Pick `subagent_type` per unit (`general-purpose` for implementation, `Explore` for research, `Plan` for design). Use `run_in_background` only for long, independent work you will collect later; default to foreground when you need all results to reconcile now. Cap each wave to a manageable batch; run further units in a second wave.

### Step 5 — Reconcile

Collect all results. For each, re-read the agent's **actual changes** (trust but verify). Then check for overlap the independence gate missed — the same symbol introduced twice, an unexpected shared file touched, contradictory assumptions. Resolve any conflict in the main thread.

### Step 6 — Verify combined

Run the full affected test set once the slices are integrated, in parallel where independent. Apply the `/verify-done` evidence gate before declaring complete. Commit/push stay gated — do not commit or push unless the user asked.

## Stop conditions

- Units turn out not to be independent → stop, serialize the conflicting ones via `/subagent-dev`; do not run conflicting writers concurrently.
- An agent strays outside its declared slice → discard its out-of-scope edits and re-brief it with tighter bounds.
- User interrupts → report which units returned, which are outstanding, and any conflicts found.

## Constraints

- Never dispatch parallel writers that can touch the same file.
- All concurrent dispatches go in a single message — separate messages are sequential.
- Verify each result independently and reconcile in the main thread.
- Briefs are self-contained; agents share no context with each other or this conversation.
- Do not commit or push unless the user explicitly asks.
- Do not modify `~/.claude-wyvrn/`.

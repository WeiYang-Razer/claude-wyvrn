---
name: subagent-dev
description: Execute implementation work through subagents instead of inline — the main agent is orchestrator and verifier, subagents do the building. Use for context isolation, a clean review boundary, or to run a /write-plan plan file task-by-task. Trigger when the user says "use a subagent to", "delegate this", "implement with subagents", or invokes /subagent-dev <plan-file> directly.
---

# subagent-dev

Implements a task (or a whole `/write-plan` plan file) by dispatching subagents to do the building while the main agent owns decomposition, verification, and git. Keeps the main context clean — a subagent's exploration and dead-ends never pollute the orchestrator's window — and creates a hard review boundary at every hand-back.

**Standalone by design.** This is a different execution mode from `/flow`: `/flow` runs inline with no custom subagents; `subagent-dev` deliberately delegates. It is never injected into `/flow`.

## Execution principles

- **Trust but verify.** A subagent's summary is a claim about what it intended, not proof of what it did. The orchestrator re-reads the actual diff and runs the tests before accepting any task.
- **Self-contained briefs.** A subagent has none of this conversation's context. Every brief must stand alone: goal, files, change spec, tests, conventions, and what to report back.
- **One task per subagent** unless two tasks are too coupled to separate. Independent tasks may fan out (hand to `/parallel-agents`); dependent tasks run sequentially with results fed forward.
- The orchestrator — not the subagents — owns gitflow, commits, and the final verdict.

## Preconditions

If `~/.claude-wyvrn/VERSION` missing → halt: `Wyvrn harness not installed. Run claude-wyvrn install.`

## Trigger

- Slash: `/subagent-dev <plan-file or task>`
- Natural: "use a subagent to", "delegate this to an agent", "implement this with subagents", "run the plan with subagents"

## Behavior

### Step 1 — Load context + resolve input (parallel batch)

- If a plan file path is given (e.g. from `/write-plan`), read it — its tasks are authoritative for scope, files, and acceptance.
- Else read `.claude-wyvrn-local/PROJECT.md` (or `README.md`), `ARCHITECTURE.md` if present, and the relevant stack conventions; treat the user's prompt as the task.

Read these in one parallel batch. No code yet.

### Step 2 — Decompose into agent-sized tasks

- Plan file → one brief per plan task.
- Free-form task → split into independently implementable units. Order by dependency: infrastructure (types, interfaces) before logic before integration before consumers.

Mark each task's dependencies. Tasks with no unmet dependency on a sibling are **parallel-eligible**; the rest are **sequential**.

### Step 3 — Write each brief

Each brief is self-contained and includes:

- **Goal + why** — the observable outcome and the reason it matters.
- **Files** — exact paths to create/modify. No globs.
- **Change spec** — complete enough to implement without guessing (signatures, logic, data shapes).
- **Tests** — what test to write/update and the exact command to run it.
- **Conventions** — the matching stack convention to follow (`universal.md` §1.1; new code follows conventions even where the repo deviates).
- **Report back** — files changed, tests run + outcome, and any deviation from the brief.
- **Mode** — state explicitly whether the agent should write code or only research/read.

### Step 4 — Dispatch

- **Sequential chain:** dispatch one subagent, verify (Step 5), feed its result into the next brief, dispatch the next. Use `subagent_type: general-purpose` for implementation.
- **Parallel-eligible set:** dispatch them concurrently — hand off to `/parallel-agents`, or issue multiple `Agent` calls in a single message. Use `Explore` for research-only units.

Never dispatch interdependent tasks in parallel — a later task built on a sibling's not-yet-verified output will drift.

### Step 5 — Verify each result (trust but verify)

For every returned task, before accepting it:

1. Re-read the **actual diff** for the files the brief named — do not rely on the summary.
2. Run the affected tests yourself; confirm pass.
3. Confirm the change matches the brief and the conventions, and stayed inside its file scope.

If it deviated, was incomplete, or tests fail → re-dispatch the same task with corrective notes. Do not patch over a bad result silently, and do not accept on the strength of the summary alone.

### Step 6 — Integrate + finalize

1. Resolve any cross-task conflicts in the main thread.
2. Run the full affected test set once, in parallel where independent.
3. Apply the `/verify-done` evidence gate before declaring complete.
4. Gitflow/commit/push are the orchestrator's job and stay gated — do not commit or push unless the user asked (mirrors `/flow` Step 10).

### Step 7 — Learning log (optional)

If the run surfaced mistakes worth recording, write `.claude-wyvrn-local/plans/YYYY-MM-DD-<slug>.md` in the same format `/flow` uses (focus: mistakes + corrections).

## Stop conditions

- A subagent reports it could not complete → read its findings, refine the brief, re-dispatch. Do not paper over the gap.
- The same task fails verification repeatedly → halt and surface to the user with the diffs and failures.
- User interrupts → summarize which tasks are verified, which are pending, and what remains.

## Constraints

- Never accept a subagent's work without independently verifying the actual diff and running the tests (trust but verify).
- Briefs must be fully self-contained — subagents cannot see this conversation.
- Do not dispatch interdependent tasks in parallel.
- Do not commit or push unless the user explicitly asks.
- Do not modify `~/.claude-wyvrn/`.

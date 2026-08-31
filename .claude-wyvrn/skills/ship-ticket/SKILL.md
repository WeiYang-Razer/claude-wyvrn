---
name: ship-ticket
description: End-to-end orchestrator from a Jira ticket ID to a pushed, reviewed feature branch. Fans out parallel research, brainstorms a spec with a house-style doc-commented API surface, writes a TDD plan, executes it task-by-task with implementer and reviewer subagents, runs a whole-branch integration review, verifies every declared build config separately, then lands commits, branch, and follow-up Jira tickets. All builds and tests go through a serialized broker. Use when the user says "ship CHROMA2-107", "take this ticket end to end", or invokes /ship-ticket <TICKET-ID>.
---

# ship-ticket

Takes a Jira ticket ID and drives it to a pushed, reviewed feature branch.

This is a composition, not a reimplementation. Each stage delegates to the skill that already owns
that job: `/brainstorm` for the spec, `/write-plan` for the plan, `/subagent-dev` for execution,
`/wyvrn-verify` for the suite. This file owns the sequencing,
the checkpoints, and the rules that bind across stages.

## The pipeline

| Stage | Name | Owner skill | Gate |
|---|---|---|---|
| 0 | Preflight | this file | halts on protected branch |
| 1 | Research | 3 parallel agents | none |
| 2 | Spec | `/brainstorm` | **CHECKPOINT: user approval** |
| 3 | Plan | `/write-plan` | none |
| 4 | Execute | `/subagent-dev` | per-task review |
| 5 | Whole-branch review | reviewer subagent | loops until clean |
| 6 | Verify | `/wyvrn-verify` | every declared config must pass |
| 7 | Land | this file | **push requires explicit ask** |

## Hard rules

These bind every stage and override any stage-local convenience.

1. **The build broker is the orchestrator.** Only this agent invokes the project's build or test
   toolchain - the `build-command` / `test-command` declared in `.claude-wyvrn-local/PROJECT.md` -
   or any wrapper around it (build scripts, IDE tasks). No subagent ever does, at any stage, for
   any reason. One invocation in flight at a time, one config per invocation, sequential, after
   sweeping the stale processes named in `.claude-wyvrn-local/build-lock-processes`. Concurrent
   runs have hard-crashed development machines. Full rule: `subagent-dev` *Build Lock*.
   Subagents may still Read, Grep, Glob, and Edit in parallel freely - the lock is on the toolchain,
   not on concurrency.
2. **Never rewrite git history or change file tracking without asking in the current turn.** No
   squash of existing commits, no rebase, no `commit --amend`, no `reset --hard`, no force-push, no
   `.gitignore` edit, no `git rm --cached`. Ask, naming the exact command and target, and get an
   explicit yes. Approval never carries over from an earlier turn (`gitflow.md` section 7).
3. **Never push anything unasked.** Stage 7 stops and reports; it does not push on its own initiative
   even when every gate is green. Pushing the branch is outward-facing and is not undone by a
   follow-up message.
4. **Adversarial honesty applies to the spec and the reviews** (`universal.md` section 3). If the
   ticket's premise is wrong - the bug is not real, the fix belongs in another repo, the ticket
   describes a symptom of a different defect - say so at Stage 2 before writing a plan against it.
   A flawless implementation of the wrong ticket is a total loss.

## Stage 0: Preflight

1. Read the ticket via `getJiraIssue`. Read every linked issue and every issue the description
   references by key.
2. Resolve the target repo from the **repo map** in `.claude-wyvrn-local/PROJECT.md` - a table
   listing each repo the project spans, its path, and what it holds. A ticket rarely names which
   repo it lands in; Stage 1 Agent B exists partly to answer this. If PROJECT.md has no repo map,
   the project is single-repo: use the current one. A multi-repo project without a map halts here -
   ask the user to add one rather than guessing.

3. **Checkout per the project's declared layout.** If PROJECT.md declares a worktree layout (e.g.
   bare repos with one worktree per ticket at `<repo>.git/<branch-type>/<TICKET-ID>[-slug]/`),
   propose the worktree path and let `/worktree` create it - never work directly in an existing
   ticket's worktree. Otherwise create a ticket-driven branch per `gitflow.md` section 2
   (`<type>/<TICKET-ID>[-<kebab-slug>]`). Branch type comes from the ticket's issue type:
   Bug -> `bugfix/`, Task/Chore -> `chore/`, Story -> `feature/`. Do not create anything without
   a yes.
4. Verify the build-lock hook is installed (`~/.claude/settings.json`, `hooks.PreToolUse`). If it is
   absent, say so once and offer to add it from `~/.claude-wyvrn/templates/settings.hooks.json`.
   Do not install it silently.
5. Confirm the working tree is clean. A dirty tree at Stage 0 becomes an unattributable diff at
   Stage 5.

## Stage 1: Research (parallel fan-out)

Dispatch **three** agents in a single message so they run concurrently. All three are read-only;
none may invoke the toolchain (rule 1).

- **Agent A - ticket.** Reads the ticket, its linked issues, its comments, and any Confluence page it
  references. Returns: the actual defect in one paragraph, the acceptance criteria, the open
  questions the ticket itself raises, and anything the ticket asserts but does not evidence.
- **Agent B - subsystems.** Greps every repo in the project's repo map for the affected subsystems
  and prior art. Search the `main`/`master`
  worktree of each, not a sibling ticket's worktree - those carry unmerged work and will produce
  findings that do not exist on the integration branch. Returns a `file:line` table of the relevant
  call sites, the owning module and repo, and any previous attempt at the same problem (a reverted
  commit, a TODO, a disabled test, an earlier ticket's worktree that solved something adjacent).
- **Agent C - existing utilities.** Hunts for helpers that already exist so the implementation does
  not reinvent them: crypto/random/hex helpers, string and path utilities, identity/hash helpers,
  RAII wrappers, test fixtures. Returns each one's header, signature, and one line on what it does.
  **This agent exists because reinventing a utility is the most common avoidable defect in this
  pipeline.** An empty result is a legitimate answer; a wrong one is expensive.

Merge the three into a findings document at
`.claude-wyvrn-local/plans/<TICKET-ID>-findings.md`. Conflicts between agents are recorded as
conflicts, not silently resolved in favour of whichever agent spoke last.

## Stage 2: Spec (CHECKPOINT)

Run `/brainstorm` against the findings document. The spec must contain:

- The problem, restated from evidence rather than from the ticket's wording.
- The chosen approach and the rejected alternatives, each with the reason it lost.
- **The public API surface, with house-style doc comments already written** per `universal.md`
  §2.6 and the matching stack convention (for C++: `/** @brief ... */` blocks carrying
  `@param`, `@return`, `@throws` where applicable, and the thread-safety `@note`). Not a sketch,
  not a signature list - the actual declarations. Do not defer this to implementation and do not
  emit a bare signature list expecting a later conversion pass.
- Which repo the change lands in, and why.
- What is explicitly out of scope, for Stage 7's descope tickets.

**Then stop and ask for approval via `AskUserQuestion`.** Options: `approve`, `refine`, `reject`.

**The refine rule.** `refine` means the user wants changes. If the user selects `refine` **without
accompanying text saying what to change**, do NOT guess and do NOT re-spec speculatively. Ask a
follow-up question naming the parts they might want changed (the approach, the API surface, the
scope, the repo choice) and wait for the answer. Guessing at a refinement burns a full brainstorm
cycle and buries the real objection.

No plan is written and no code is touched until `approve`.

## Stage 3: Plan

Run `/write-plan` against the approved spec. Shape:

- **4-6 tasks**, **30-40 numbered steps total**.
- Every task independently testable and independently committable. If a task cannot be committed
  without a later task, it is not a task - merge it or resplit it.
- Every task carries its own interface section so a fresh executor needs no sibling context.
- TDD steps throughout, written for the orchestrator-driven cycle (`subagent-dev`
  *Execution mode: TDD*): the implementer commits the failing test and returns `RED-PENDING`; the
  orchestrator runs it.
- A `## Final verification` section for Stage 6. It runs once, never per task.

## Stage 4: Execute

Hand the plan to `/subagent-dev` and follow it exactly. Per task: dispatch implementer, orchestrator
runs RED, dispatch implementer to implement, orchestrator runs GREEN, dispatch task reviewer, resolve
findings, commit.

Every build and test in this stage is issued by the orchestrator under rule 1. A task report that
contains test output the orchestrator did not produce is a lock violation: treat the task as
unverified and re-run it yourself.

## Stage 5: Whole-branch review

After the last task completes, dispatch **one** reviewer subagent over the full branch diff
(`review-package "$(bash ~/.claude-wyvrn/skills/subagent-driven-development/scripts/branch-base)" HEAD`).

This pass exists to catch what per-task reviews structurally cannot: **cross-task integration
defects**. Point the reviewer at that class explicitly. The canonical shape is a gate written in task
A that does not account for a flag, state, or code path introduced in task B - each task correct in
isolation, the composition wrong. Others: a resource freed in one task and still referenced in
another; two tasks that each handle a case the other assumed it owned; an invariant asserted in task
A that task C quietly widens.

If it returns findings, dispatch ONE fix subagent with the complete list, then re-review. Loop until
clean. Do not proceed to Stage 6 with open Critical or Important findings.

## Stage 6: Verify

Run `/wyvrn-verify`. Every config in the project's `build-configs`, separate sequential invocations,
full suite, after a stale process sweep, with exact pass/fail counts quoted from the runner's own
output.

A green run of one config alone does not pass this gate. If anything is still in flight at report
time, say so and mark the result provisional.

## Stage 7: Land

1. **Commit** anything uncommitted per `/wyvrn-commit` and `gitflow.md` section 3. Conventional
   format, single `-m`, no trailers.
2. **Stop.** Report what is ready: the branch name, the commit SHAs, the verify results, the
   descoped items. **Do not push.** Rule 3.
3. When the user explicitly asks to push: push and open the PR into the integration branch per
   `gitflow.md` section 4.
4. **File follow-up Jira tickets** for everything descoped at Stage 2 or discovered during Stages
   4-5. One ticket per item, linked to the original, carrying the evidence that motivated it. Ask
   before creating them - filing a ticket is outward-facing and visible to the team. List what you
   would file and let the user cut the list.

## Prohibitions

- Never let a subagent invoke the project's build or test toolchain, or any wrapper around it.
- Never run two toolchain invocations concurrently, combine configs, or background a build or test.
- Never rewrite history or change file tracking without in-turn approval.
- Never push the branch without an explicit ask.
- Never proceed past Stage 2 without `approve`.
- Never guess what `refine` meant when no text accompanied it.
- Never write the plan before the spec is approved, or code before the plan exists.
- Never emit a spec whose API surface lacks the doc-comment blocks.
- Never file a Jira ticket without asking.
- Never skip Stage 5 because the per-task reviews were clean - that is the stage's whole premise.
- Do not modify `~/.claude-wyvrn/`.

## Integration

- `/worktree` - Stage 0. `/brainstorm` - Stage 2. `/write-plan` - Stage 3. `/subagent-dev` - Stages 4-5.
  `/wyvrn-verify` - Stage 6. `/wyvrn-commit` - Stage 7.
- `gitflow.md` sections 2, 3, 4, 7 - ticket-driven branch naming, commit format, PR flow, and the
  history/tracking gate.
- `.claude-wyvrn-local/PROJECT.md` - repo map, worktree layout, `build-command` / `test-command` /
  `build-configs`. `.claude-wyvrn-local/build-lock-processes` - the sweep list.
- The matching stack convention (e.g. `cpp.md` *Testing*) and `universal.md` §2.6 - authoritative
  for the spec's doc comments and test style. How builds and tests are run is governed by rule 1
  and the PROJECT.md declarations, which override any convenience flag a stack file suggests.
- `universal.md` section 3 - adversarial honesty, binding on the spec and both reviews.

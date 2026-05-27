---
name: brainstorm
description: Pre-implementation design gate for complex or uncertain features. Trigger when scope is large, requirements are unclear, multiple approaches exist, or the user says "design first", "let's think through", "explore options", or "before we code". Produces an approved spec doc before any implementation begins.
---

# brainstorm

Collaborative design process that produces an approved spec before any code is written. Hard gate: no implementation output until the user explicitly approves the spec.

## Execution principles

- Parallelize independent reads at Step 1.
- Ask only what cannot be inferred. Batch clarifying questions.
- No code, no file edits, no implementation suggestions until Step 6.

## Preconditions

If `~/.claude-wyvrn/VERSION` missing → halt: `Wyvrn harness not installed. Run claude-wyvrn install.`

## Trigger

- Slash: `/brainstorm <topic>`
- Natural: "let's think through", "design first", "before we code", "explore options for", "how should we approach", "what's the right way to"

## Behavior

### Step 1 — Load context (parallel batch)

Read in one parallel batch:

- `.claude-wyvrn-local/PROJECT.md` if present, else `README.md`
- `.claude-wyvrn-local/ARCHITECTURE.md` if present
- `.claude-wyvrn-local/specs/` — list files, read any whose slug matches the topic (top 1–2 by name similarity). If a matching spec already exists and is marked approved, surface it and ask if the user wants to revise or start fresh.

Do not modify anything yet.

### Step 2 — Clarifying questions

Ask only what is unclear and not inferable from prompt, codebase, or context:

- **Goal** — observable outcome after the feature exists.
- **Constraints** — APIs, performance, back-compat, non-goals.
- **Success signal** — how will we know it works?
- **Scope** — what is explicitly out of scope?

Batch into one AskUserQuestion call (≤4 questions). Each question: 2 plausible options; "Other" auto-added. Skip Step 2 entirely if the prompt provides all necessary context.

### Step 3 — Proposals

Emit 2–3 distinct implementation approaches. For each:

- One-paragraph description of the approach.
- Key tradeoffs (complexity, performance, maintainability, testability).
- Which constraints it satisfies or violates.

Ask: "Which direction resonates, or should I explore a hybrid?" via AskUserQuestion header `Approach`, options `[Option A, Option B, Option C (if applicable), Hybrid / Other]`.

### Step 4 — Draft spec

Based on the chosen direction, draft a design document in working memory:

Required sections:
- **Problem** — what we're solving and why.
- **Chosen approach** — the selected option with rationale.
- **Rejected alternatives** — brief note on each with reason.
- **Interface / API** — public-facing contracts, data shapes, function signatures. Use pseudocode or prose; no full implementation.
- **Data flow** — how data moves through the system (prose or ASCII diagram).
- **Edge cases** — failure modes, empty states, concurrency concerns.
- **Acceptance criteria** — specific, testable conditions for "done".
- **Out of scope** — explicit list.

### Step 5 — Spec review

Emit the full draft spec as a chat message. AskUserQuestion header `Spec`, options `[Approve, Refine, Abort]`.

- `Approve` → Step 6.
- `Refine` (or "Other" + text) → incorporate feedback, re-emit, repeat Step 5.
- `Abort` → halt. Do not write any file.

### Step 6 — Write spec

Write `.claude-wyvrn-local/specs/YYYY-MM-DD-<slug>-design.md` where `<slug>` is a lowercase-hyphenated summary of the topic (≤5 words). Create `specs/` directory if missing.

Append to the front of the file:

```
---
status: approved
date: YYYY-MM-DD
topic: <topic>
---
```

Emit:

```
Spec written: .claude-wyvrn-local/specs/YYYY-MM-DD-<slug>-design.md

Next: run /flow or /write-plan referencing this spec.
```

## Stop conditions

- User aborts at any step → halt, no file written.
- User interrupts → halt, summarize what was decided so far in chat.

## Constraints

- Do NOT produce implementation code at any step.
- Do NOT modify source files, configs, or anything outside `.claude-wyvrn-local/specs/`.
- Do NOT modify `~/.claude-wyvrn/`.
- All confirmations via `AskUserQuestion`.

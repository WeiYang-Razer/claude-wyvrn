---
name: tdd
description: Red-green-refactor discipline for changes to executable code. Write a failing test first, watch it fail for the right reason, write the minimal code to pass, then refactor while green. Trigger when the user says "TDD", "test first", "red-green", "write the test first", or invokes /tdd directly.
---

# tdd

Drives a change through the red-green-refactor cycle: a failing test exists and is seen failing *before* any implementation. One behavior at a time. Reinforces `universal.md` §1.6 (tests ship with executable changes; tests written before declaring complete).

**Standalone by design.** Invoke directly for a single behavior, or as the implementation discipline inside a larger `/flow`. Never injected into `/flow` automatically.

**Apply mode.** Executing a code-complete plan (`/write-plan` output) is transcription: the plan's test-first ordering already carried the design pressure, so the executor transcribes the plan's code rather than re-deriving the design. It still runs the red-green cycle live. A transcribed test that has never been seen failing is untrusted, and RED is what catches divergence between the plan's assumptions and the actual codebase.

## Execution principles

- One behavior per cycle. Do not write three tests then three implementations.
- A test that has never been seen failing is not trusted. Always observe RED before GREEN.
- Minimal green: write the least code that makes the current test pass. Resist implementing the next behavior early.
- Refactor only while green, and re-run after every refactor.
- Parallelize independent reads at Step 1. Within a cycle, steps are sequential by data dependency.
- **POSIX syntax in Bash.** Never use PowerShell here-string syntax (`@'...'@`, `@"..."@`) in the Bash tool — it leaks stray `@` characters. Multi-line strings and commit messages use POSIX constructs (heredoc, or multiple `-m` flags).

## Preconditions

If `~/.claude-wyvrn/VERSION` missing → halt: `Wyvrn harness not installed. Run claude-wyvrn install.`

## Trigger

- Slash: `/tdd <behavior or feature>`
- Natural: "TDD this", "test first", "red-green", "write the test before the code", "drive this with tests"

## Behavior

### Step 1 — Load context (parallel batch)

Read in one parallel batch:

- The target stack's test conventions: `~/.claude-wyvrn/conventions/<stack>.md` and `.claude-wyvrn-local/conventions/<stack>.md` if present (project wins on conflict).
- `.claude-wyvrn-local/PROJECT.md` if present, else `README.md` if present.
- An existing test file near the target code (to match runner, file location, naming, and assertion style).

Determine the exact test command for this stack (e.g., `jest --findRelatedTests <file>`, `pytest <path>::<test>`, `dotnet test --filter <name>`, `ctest -R <pattern>`). If the runner cannot be determined from config or conventions, ask once via AskUserQuestion header `Runner`.

### Step 2 — Define the behavior

State the single behavior under test in one sentence: given some input/state, the code should produce some observable output/effect. If the user named several behaviors, take the first and queue the rest for later cycles.

If the behavior is ambiguous (unclear input, output, or success condition), ask one batched AskUserQuestion. Otherwise proceed.

### Step 3 — RED: write a failing test

1. Write exactly one test asserting the behavior from Step 2, following the stack's test conventions.
2. Run it.
3. Confirm it fails, **and that it fails for the intended reason** (missing function / wrong value), not an unrelated error (typo, import error, compile failure). A test that errors out before reaching the assertion is not a valid RED — fix the test until the failure is the assertion you expect.

If the test passes immediately, the behavior already exists or the test is too weak. Strengthen the assertion or pick the next behavior.

### Step 4 — GREEN: minimal implementation

1. Write the least code that makes the failing test pass. Hard-coding is acceptable here if it is genuinely the smallest step; the next cycle's test will force generalization.
2. Run the test. Confirm it passes.
3. Run the broader affected test set in parallel where independent. Confirm nothing previously green is now red. Fix any regression before refactoring.

### Step 5 — REFACTOR: clean up while green

Improve the code and the test without changing behavior: remove duplication, clarify names (`universal.md` §2.2), collapse needless indirection (§2.1). Re-run the tests after each refactor. Stop the moment a test goes red and revert the last refactor step.

Refactoring is optional per cycle — skip if the green code is already clean.

### Step 6 — Loop or finish

- More behaviors queued → return to Step 2 with the next behavior.
- Done → emit a short summary: behaviors covered, test names added, final runner outcome. If invoked inside `/flow`, hand back so `/flow` continues at its own self-verify step.

## Stop conditions

- Cannot establish a valid RED (test won't fail, or only fails for unrelated reasons) → halt and report why; do not write implementation against an untrusted test.
- Runner cannot be determined or tests cannot be executed in this environment → say so explicitly; do not claim a test passed without running it.
- User interrupts → halt, summarize which cycle completed and what remains.

## Constraints

- Never write implementation code before a failing test for that behavior exists and has been seen failing.
- Never weaken, skip, or delete a test to force green (`universal.md` §1.6). No `xit`, `@skip`, `[Ignore]`, commented-out asserts.
- Do not implement behaviors beyond the current test (`universal.md` §1.2 — no speculative code).
- Source code you write, code blocks inside generated markdown, and every commit message must be strictly 7-bit ASCII — no em-dashes, smart quotes, or other non-ASCII characters. Markdown prose may use them.
- Do not modify `~/.claude-wyvrn/`.

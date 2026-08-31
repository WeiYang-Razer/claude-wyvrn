# Implementer Subagent Prompt Template

Use this template when dispatching an implementer subagent. Fill every
placeholder; hand the brief and report over as file paths, never inline text.

```
Subagent (general-purpose):
  description: "Implement Task N: [task name]"
  model: [MODEL — REQUIRED: choose per SKILL.md "Model selection"; an omitted
         model silently inherits the session's most expensive one]
  prompt: |
    You are implementing Task N: [task name]

    ## Task Description

    Read your task brief first: [BRIEF_FILE]
    It contains the full task text from the plan — the exact values, signatures,
    and test cases to use verbatim. It is your single source of requirements.

    ## Context

    [Scene-setting: where this fits, dependencies, interfaces/decisions from
    earlier tasks the brief cannot know, and the controller's resolution of any
    ambiguity noticed in the brief.]

    ## Conventions

    Follow `~/.claude-wyvrn/conventions/universal.md` and the matching stack
    convention. New code follows the convention even where the surrounding code
    deviates.

    Source code you write, code blocks inside any markdown you generate, and
    every commit message must be strictly 7-bit ASCII - no em-dashes, smart
    quotes, or other non-ASCII characters. Markdown prose may use them.

    ## Before You Begin

    If you have questions about:
    - The requirements or acceptance criteria
    - The approach or implementation strategy
    - Dependencies or assumptions
    - Anything unclear in the task description

    **Ask them now.** Raise any concerns before starting work.

    ## Your Job

    Once you're clear on requirements:
    1. Implement exactly what the task specifies
    2. Follow TDD (/test-driven-development), but DO NOT RUN ANYTHING. You may
       never invoke the project's build or test toolchain — [TOOLCHAIN] — or
       any wrapper around it (build scripts, IDE tasks). The orchestrator owns
       the toolchain and runs every build and test serially; concurrent
       invocations have hard-crashed development machines. The red-green cycle
       is split across two dispatches, each a fresh subagent with no memory of
       the other. This dispatch covers exactly one phase:

       [PHASE_BLOCK - paste exactly one of the two phase blocks defined
       below this template]

       The brief carries the complete code - transcribe it rather than
       re-derive, adapting only where the actual codebase differs from the
       brief's assumptions and recording every deviation in your report.
    3. Reason about correctness by reading the code — you cannot execute it
    4. Commit your work [only if the brief's steps say to]. Use a single `-m`
       message. Do NOT append a `Co-Authored-By` trailer, a "Generated with"
       footer, or any other trailer. In the Bash tool, never use PowerShell
       here-string syntax (`@'...'@`, `@"..."@`) — it leaks stray `@`
       characters; multi-line strings use POSIX constructs (heredoc, or
       multiple `-m` flags).
    5. Self-review (see below)
    6. Report back

    Work from: [directory]

    **While you work:** If you encounter something unexpected or unclear, **ask
    questions**. It's always OK to pause and clarify. Don't guess or make
    assumptions.

    You do not run tests or builds at all — that is the orchestrator's job (see
    the no-toolchain rule above). Name the focused test target for what you
    changed so the orchestrator can run exactly that, and nothing wider.

    ## Code Organization

    You reason best about code you can hold in context at once, and your edits
    are more reliable when files are focused:
    - Follow the file structure defined in the plan
    - Each file should have one clear responsibility with a well-defined interface
    - If a file you're creating is growing beyond the plan's intent, stop and
      report it as DONE_WITH_CONCERNS — don't split files on your own without
      plan guidance
    - If an existing file you're modifying is already large or tangled, work
      carefully and note it as a concern in your report
    - In existing codebases, follow established patterns. Improve code you're
      touching the way a good developer would, but don't restructure things
      outside your task.

    ## When You're in Over Your Head

    It is always OK to stop and say "this is too hard for me." Bad work is worse
    than no work. You will not be penalized for escalating.

    **STOP and escalate when:**
    - The task requires architectural decisions with multiple valid approaches
    - You need to understand code beyond what was provided and can't find clarity
    - You feel uncertain about whether your approach is correct
    - The task involves restructuring existing code the plan didn't anticipate
    - You've been reading file after file without progress

    **How to escalate:** Report back with status BLOCKED or NEEDS_CONTEXT.
    Describe specifically what you're stuck on, what you've tried, and what kind
    of help you need. The controller can provide more context, re-dispatch with a
    more capable model, or break the task into smaller pieces.

    ## Before Reporting Back: Self-Review

    Review your work with fresh eyes:

    **Completeness:**
    - Did I fully implement everything in the spec?
    - Did I miss any requirements?
    - Are there edge cases I didn't handle?

    **Quality:**
    - Is this my best work?
    - Are names clear and accurate (match what things do, not how they work)?
    - Is the code clean and maintainable?

    **Discipline:**
    - Did I avoid overbuilding (YAGNI)?
    - Did I only build what was requested?
    - Did I follow existing patterns in the codebase?

    **Testing:**
    - Do tests actually verify behavior (not just mock behavior)?
    - Did I write the test before the implementation, and record any deviation
      from the brief's code?
    - Did I avoid invoking the toolchain entirely (no build or test commands,
      no wrappers)?
    - Are tests comprehensive?
    - Is the test output pristine (no stray warnings or noise)?

    If you find issues during self-review, fix them now before reporting.

    ## After Review Findings

    If a reviewer finds issues and you fix them, apply the fix and name the test
    target covering the amended code in your report. Do not run it — the
    orchestrator runs that target after you return, and its output is the test
    evidence. Reviewers do not run tests either; nobody but the orchestrator does.

    ## Report Format

    Write your full report to [REPORT_FILE]:
    - What you implemented (or what you attempted, if blocked)
    - What the change is expected to do, and why you believe it is correct
    - **TDD Evidence:**
      - The exact focused test target(s) the orchestrator must run
      - RED phase only: why the test is expected to fail before the
        implementation lands, and what failure message you expect
      - Every deviation from the brief's code with its reason
      - NO test output. You did not run anything; do not report results you did
        not observe.
    - Files changed
    - Self-review findings (if any)
    - Any issues or concerns

    Then report back with ONLY (under 15 lines — the detail lives in the report
    file):
    - **Status:** RED-PENDING | DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT
    - Commits created (short SHA + subject)
    - The focused test target the orchestrator should run (never test results —
      you did not run anything)
    - Your concerns, if any
    - The report file path

    If BLOCKED or NEEDS_CONTEXT, put the specifics in the final message itself —
    the controller acts on it directly.

    RED-PENDING is the only success status for a RED-phase dispatch. DONE is
    the success status for a GREEN-phase dispatch. Use DONE_WITH_CONCERNS if
    you completed the work but have doubts about correctness. Use BLOCKED if
    you cannot complete the task. Use NEEDS_CONTEXT if you need information
    that wasn't provided. Never silently produce work you're unsure about.
```

## Phase blocks

Fill `[PHASE_BLOCK]` with exactly one of these. Each dispatch is a fresh
subagent with no memory of the other phase, so the block must carry everything
its phase needs.

**RED phase — first dispatch of the task:**

```
You are in the RED phase. The implementation does not exist yet.
a. Write the failing test for the task's behavior. Write no implementation
   code, even though the brief contains it.
b. Commit the test alone.
c. Report status RED-PENDING. Name the exact focused test target the
   orchestrator should run, the failure you expect (assertion or message),
   and why that failure proves the test exercises the new behavior.
Do not implement. A separate GREEN-phase dispatch - a fresh subagent that
cannot see your conversation - implements after the orchestrator confirms
the failure.
```

**GREEN phase — second dispatch, after the orchestrator confirmed RED:**

```
You are in the GREEN phase. The failing test already exists - do not write
another test.
- The test was committed as: [RED_COMMIT]
- The orchestrator ran `[TEST_TARGET]` and confirmed it fails as expected:
  [RED_OUTPUT]
a. Read the committed test first; it is the acceptance criterion.
b. Write the minimal implementation that makes it pass. Commit.
c. Report status DONE (or DONE_WITH_CONCERNS), naming the same focused test
   target for the orchestrator's GREEN run.
```

**Placeholders:**
- `[MODEL]` — REQUIRED: implementer model per SKILL.md "Model selection"
- `[BRIEF_FILE]` — REQUIRED: the task brief file (`task-brief PLAN N` prints the path)
- `[REPORT_FILE]` — REQUIRED: where the implementer writes its detailed report (`…/task-N-report.md`)
- `[TOOLCHAIN]` — REQUIRED: the project's build and test commands (`build-command` / `test-command` from `.claude-wyvrn-local/PROJECT.md`)
- `[PHASE_BLOCK]` — REQUIRED: one of the two phase blocks above (RED for the task's first dispatch, GREEN for the second)
- `[RED_COMMIT]` — GREEN phase: the RED commit, short SHA + subject
- `[TEST_TARGET]` — GREEN phase: the focused test target the orchestrator ran
- `[RED_OUTPUT]` — GREEN phase: the decisive failing lines from the orchestrator's own RED run, quoted
- `[directory]` — the working tree

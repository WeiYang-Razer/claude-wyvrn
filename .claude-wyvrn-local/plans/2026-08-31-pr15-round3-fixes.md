# PR 15 review round 3: evidence slot, sweep escape hatch, drop /push-report

## Task

Third silent review of PR 15 (after ff26ace) found three blocking issues. User asked to fix all
three, resolving issue 3 by removing `/push-report` rather than shipping it. Issue 1: the
task-reviewer template referenced "RED and GREEN evidence attached to this review" but defined no
placeholder to attach it, while the implementer report is forbidden from carrying test output — the
two-phase TDD contract had no evidence transport. Issue 2: the sweep steps in wyvrn-verify and
subagent-dev command an in-session PowerShell sweep that the build-lock hook refuses exactly when a
listed process is alive; only the template's `_caveat_pretooluse` documented the workaround. Issue 3:
ship-ticket referenced `/push-report`, a machine-local skill the harness repo does not ship.

## Branch

feature/adversarial-honesty (PR 15 head; fixes belong to the open PR).

## Mistakes & corrections

None.

## Global harness issues

None new — task edits the harness repo itself. Nits from the round-3 review left unfixed (user
scoped the ask to the three blockers):

- `implementer-prompt.md:49` and `:65` — template steps 1 ("Implement exactly what the task
  specifies") and 4 ("Commit [only if the brief's steps say to]") contradict the RED phase block
  ("Write no implementation code" / "Commit the test alone").
- `gitflow.md:30`, `:37` and ship-ticket description — `CHROMA2-*` example ticket IDs in shared
  harness files; user's standing rule keeps Chroma specifics project-local.
- `settings.hooks.json:20` — PostToolUse splits `CLAUDE_FILE_PATHS` on spaces; breaks on paths
  containing spaces.
- `ship-ticket/SKILL.md:73` (pre-edit numbering) — Stage 0 verifies the hook but not that
  `.claude-wyvrn-local/build-lock-processes` exists in a fresh per-ticket worktree.

## Files changed

- `skills/subagent-driven-development/task-reviewer-prompt.md` — Tests section now embeds a
  `[TEST_EVIDENCE]` block (the orchestrator's own RED/GREEN output, the review's only test
  evidence); placeholder documented as REQUIRED.
- `skills/subagent-driven-development/SKILL.md` — "pass to the reviewer" and the reviewer-guidance
  bullet now name the `[TEST_EVIDENCE]` slot; Build Lock sweep bullet gains the hook-refusal escape
  hatch (stop, ask the user to sweep from a terminal outside Claude Code, retry).
- `skills/wyvrn-verify/SKILL.md` — Step 3 gains the same escape hatch.
- `skills/ship-ticket/SKILL.md` — `/push-report` removed everywhere: composition list, hard rule 3
  (push-target disambiguation rule deleted, rules renumbered 5 -> 4), Stage 7 steps 3/5 collapsed,
  prohibition reworded, Integration line and frontmatter description trimmed. "Rule 3" now means
  "never push unasked"; the only pushable artifact is the branch.

## Tests

No executable code (markdown only). Verified by grep: zero `push-report` / `session report` /
`rules? [45]` / `disambiguat` hits in `.claude-wyvrn/`; `TEST_EVIDENCE` appears in exactly the
template body, its placeholder list, and the two SKILL.md references; both escape-hatch insertions
present.

## Project-file updates

None (harness repo; changes are the deliverable).

## Time saved (agent vs. human-only)

- Human-only baseline: ~50m (trace the evidence hand-off across three files, design the slot,
  delete a hard rule and renumber every reference consistently, reword Stage 7, verify by grep).
- Agent-assisted actual: ~5m.
- Time saved: ~45m (90%).
- Basis: 4 files / ~64 changed lines, consistency-sensitive renumbering; largest uncertainty is
  the human baseline for spotting all cross-references.

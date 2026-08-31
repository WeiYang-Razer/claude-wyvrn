# PR 15 review round 2: fix blocking issues 1-2, sync local install

## Task

Silent re-review of PR 15 (after 607c70e) found two blocking issues. User asked to fix both and
sync the harness to the local install for dogfooding. Issue 1: stale "in parallel where
independent" at subagent-dev SKILL.md:261 (final verify gate), contradicting the Build Lock.
Issue 2: ship-ticket and wyvrn-verify cited cpp.md sections (*Documentation comments*, *Test and
build execution*, *Platform guards*) that do not exist in the repo's cpp.md.

## Branch

feature/adversarial-honesty (PR 15 head; fixes belong to the open PR).

## Mistakes & corrections

None.

## Global harness issues

Same "parallel test" class as issue 1 survives in three files NOT touched by PR 15 - surfaced,
not fixed (out of the asked scope):

- `skills/dispatching-parallel-agents/SKILL.md:66` - "Run the full affected test set once the
  slices are integrated, in parallel where independent."
- `skills/test-driven-development/SKILL.md:62` - "Run the broader affected test set in parallel
  where independent."
- `skills/flow/SKILL.md` Step 7 - "Independent test commands run in parallel."

These are generic-harness defaults, harmless on jest/pytest stacks, fatal on the C++ machine.
The Build Lock covers subagent-dev/ship-ticket/wyvrn-verify only; inline /flow and TDD runs are
unprotected by prose (the machine relies on the hook + machine-local cpp.md). Consider a
follow-up that scopes these three lines with "unless the Build Lock / build-lock-processes
declares otherwise".

Also left as-is deliberately: repo `conventions/cpp.md:95` recommends
`ctest --output-on-failure --parallel`. Contradicts the crash-safety story, but repo cpp.md is
never edited locally (upstream churn); wyvrn-verify's Integration note now explicitly states its
serial rules override stack-file convenience flags, which neutralizes the reference.

## Files changed

- `skills/subagent-driven-development/SKILL.md` - Integrate+finalize step 3: "in parallel where
  independent" replaced with "serially, one invocation at a time, per the Build Lock".
- `skills/ship-ticket/SKILL.md` - Stage 2 doc-comment authority now `universal.md` 2.6 + stack
  convention with the C++ style inline (no fake section name); Integration cites `cpp.md`
  *Testing* (exists) and states rule 1 / PROJECT.md declarations govern execution.
- `skills/wyvrn-verify/SKILL.md` - Integration cites `cpp.md` *Testing*; adds that this skill's
  serial-execution rules override stack-file convenience flags (e.g. a `--parallel` default).

## Tests

No executable code (markdown only). Verified by grep: zero remaining `*Documentation comments*`
/ `*Test and build execution*` / `*Platform guards*` references in `.claude-wyvrn/`; the only
`in parallel where independent` hits are the two out-of-scope files listed above.

## Install sync

Copied repo -> `~/.claude-wyvrn/` and `~/.claude/skills/`: VERSION, CLAUDE.md,
conventions/universal.md, conventions/gitflow.md, templates/settings.hooks.json, and skills
flow, ship-ticket, subagent-driven-development, wyvrn-pr-review-silent, wyvrn-verify (both
locations). `conventions/cpp.md` deliberately NOT copied (machine-local, Chroma-customized;
last write 2026-08-28 confirmed untouched). Installed PreToolUse hook in
`~/.claude/settings.json` is still the v1 hard-coded one (ctest/cmake/hostharness, Bash-only);
upgrade to the declaration-driven template offered to the user, not applied silently - swapping
removes protection until each Chroma project declares `.claude-wyvrn-local/build-lock-processes`.

## Project-file updates

None (harness repo; changes are the deliverable).

## Time saved (agent vs. human-only)

- Human-only baseline: ~45m (locate the stale line, decide the reference-side fix direction,
  reword three cross-references consistently, sync 10+ files to two install locations, verify).
- Agent-assisted actual: ~6m end to end.
- Time saved: ~39m (87%).
- Basis: 3 files / ~10 changed lines but consistency-sensitive wording; sync is mechanical;
  largest uncertainty is the human baseline for choosing citation targets.

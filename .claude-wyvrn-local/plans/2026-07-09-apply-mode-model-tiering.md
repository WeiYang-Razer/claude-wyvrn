# Learning log — concrete model tiering for apply-mode dispatches

## Task

Anthropic usage report flagged subagent-heavy sessions (89% of spend). User picked option (b) from the discussion: make apply-mode implementers default to haiku, apply-mode per-task reviewers cheapest tier (kept the review gate rather than skipping it), whole-branch review stays most-capable. The skill already mandated "cheapest tier" for apply-mode implementers in the abstract; this change adds a concrete tier→model mapping (`haiku`/`sonnet`/`opus`) for the Agent tool's `model` param and extends the cheapest-tier rule to apply-mode per-task reviews.

## Branch

`feature/WT_applyModeExecution` (continued — same feature area as apply-mode execution, extends ee4d53d). Gitflow followed, no new branch.

## Mistakes & corrections

- **Near-miss internal contradiction.** First edit added "apply-mode per-task reviews are always the cheapest tier" while the existing "Turn count beats token price" paragraph still said "use a mid-tier model as the floor for reviewers". Caught during self-verify grep sweep, carved out the apply-mode exemption in that sentence. Do differently: when adding a tier rule, sweep the whole Model selection section for floor/ceiling statements before the first edit, not after.

## Global harness issues

None.

## Files changed

- `.claude-wyvrn/skills/subagent-driven-development/SKILL.md` — apply-mode per-task reviews pinned to cheapest tier; explicit tier→model mapping (cheapest=haiku, standard=sonnet, most capable=opus/session); mid-tier reviewer floor scoped to TDD-mode.
- `~/.claude/skills/subagent-driven-development/SKILL.md` — synced copy (installed location; not tracked in this repo).

## Tests

None — markdown-only skill change. Verified by grep sweep of all tier references in the skill dir: no remaining floor/mandate contradictions; whole-branch review most-capable in all four mentions.

## Project-file updates

None.

## Time saved (agent vs. human-only)

- **Human-only baseline:** ~25m — locating every model-tier statement across the 290-line skill, wording the rule without contradicting the turn-count paragraph, syncing the installed copy.
- **Agent-assisted actual:** ~4m.
- **Time saved:** ~21m (~84%).
- **Basis:** 1 file, 3 edit sites, but consistency-sensitive (5+ tier statements interact). Largest uncertainty: whether a human would have caught the mid-tier-floor contradiction at all.

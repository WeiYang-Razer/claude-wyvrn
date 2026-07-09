# Write spec/plan files to disk before approval prompt

## Task

User could not effectively review specs/plans rendered as chat text at the approval gate in the `brainstorming` and `writing-plans` skills. Restructure both: write the draft artifact to disk first, then ask for approval with a prompt that names the file path, so the user reviews the file in their editor. Refine edits the file in place; Abort deletes the draft; git commit happens only after approval.

## Branch

`fix/WT_specPlanFilesBeforeApproval` from `main` (repo integrates on `main`; no `develop`).

## Mistakes & corrections

None. (First edit batch was rejected by an accidental user click, not an agent error; re-applied verbatim.)

## Global harness issues

None.

## Files changed

- `.claude-wyvrn/skills/brainstorming/SKILL.md` — Step 4 now writes the draft spec to `.claude-wyvrn-local/specs/` with `status: draft` frontmatter; Step 5 emits path + ≤5-line summary instead of full spec, Refine edits in place, Abort deletes draft; Step 6 flips `status: draft` → `approved` then commits; stop conditions updated.
- `.claude-wyvrn/skills/writing-plans/SKILL.md` — Step 4 now writes the full plan file (uncommitted) and asks approval referencing the path with `Tasks/Steps/Waves` one-liner; Refine edits in place + re-runs 3d gate; Abort deletes draft; Step 5 reduced to commit-only; stop conditions updated.

Installed copies synced to `~/.claude-wyvrn/skills/` and `~/.claude/skills/` for both skills (4 files) so behavior is live without reinstall — same as the 2026-07-07 auto-commit change.

## Tests

None — documentation-only change to skill runbooks (universal.md §1.6).

## Project-file updates

None.

## Time saved (agent vs. human-only)

- **Human-only baseline:** ~30m — restructure two multi-step runbooks consistently (draft-status lifecycle, abort/refine semantics, commit gating), keep constraints/stop-conditions coherent, sync four installed copies.
- **Agent-assisted actual:** ~6m end to end.
- **Time saved:** 24m (80%).
- **Basis:** doc-only edit across 2 files + 4-file install sync; main effort was keeping the approval-lifecycle semantics consistent between the two skills; largest uncertainty is the hand-edit baseline.

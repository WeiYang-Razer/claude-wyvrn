# Auto-commit brainstorm/write-plan artifacts

## Task

Update the `brainstorming` and `writing-plans` skills so that when they finish producing their .md artifact (spec / plan file), they immediately commit that file with a gitflow-compliant message that carries no `Co-Authored-By` trailer or "Generated with" footer.

## Branch

`feature/WT_autoCommitSkillArtifacts` from `main` (repo uses `main` as the integration branch; no `develop` exists).

## Mistakes & corrections

None.

## Global harness issues

None. Note: `gitflow.md` §1 assumes a `develop` integration branch, but this repo integrates on `main`; branch was cut from `main` accordingly. Not a defect worth a harness edit — projects vary.

## Files changed

- `.claude-wyvrn/skills/brainstorming/SKILL.md` — Step 6 now commits the spec file (`docs(specs): add <slug> design spec`), forbids co-author/generated-with trailers, and the emit line reads "written and committed"; Constraints allow only that git add+commit.
- `.claude-wyvrn/skills/writing-plans/SKILL.md` — Step 5 now commits the plan file (`docs(plans): add <slug> implementation plan`) with the same trailer prohibition and constraint carve-out.

Installed copies synced to `~/.claude-wyvrn/skills/` and `~/.claude/skills/` for both skills so the behavior is live without a reinstall.

## Tests

None — documentation-only change to skill runbooks (universal.md §1.6).

## Project-file updates

None.

## Time saved (agent vs. human-only)

- **Human-only baseline:** ~25m — locate both skill steps, write consistent commit instructions, adjust constraints/emit blocks, sync four installed copies.
- **Agent-assisted actual:** ~5m end to end.
- **Time saved:** 20m (80%).
- **Basis:** small doc-only edit across 2 files + 4-file install sync; main effort was consistency between the two skills; largest uncertainty is the baseline estimate for hand-syncing install locations.

# INDEX.md

Navigation map. Wyvrn Claude harness. Locate paths, templates, and artifact folders here. Rules for using these paths are in `HARNESS.md`.

## Territories

- `~/.claude-wyvrn/` — package territory. Machine-wide. Read-only during flows. Harness files shared across all projects on the machine.
- `.claude-wyvrn-local/` — project territory. At the root of the current project. Read + write. Artifacts produced during flows.

## Package territory: `~/.claude-wyvrn/`

| Path | Status | Purpose |
|---|---|---|
| `VERSION` | read | Harness version string. |
| `HARNESS.md` | read | Authoritative rules. |
| `INDEX.md` | read | This file. |
| `DECISIONS.md` | read | Decision procedure for ambiguity, scope, autonomy. |
| `conventions/CONVENTIONS.md` | read | Universal behavioral rules for output. |
| `conventions/[stack].md` | read | Stack-specific code conventions. Loaded on demand. |
| `workflows/WORKFLOW.md` | read | Shared phase sequence. |
| `workflows/FEATURE.md` | read | Feature flow deltas. |
| `workflows/FIX.md` | read | Fix flow deltas. |
| `workflows/REFACTOR.md` | read | Refactor flow deltas. |
| `templates/*.md` | read | Source templates for artifacts. |
| `skills/[name]/SKILL.md` | read | Skill definitions. Discovered by folder scan. |
| `agents/[name]/AGENT.md` | read | Subagent definitions. Discovered by folder scan. |
| `hooks/` | read | Deterministic scripts wired into Claude Code's hook system. See `hooks/README.md` for installation. |
| `extensions/` | read | Drop-in extension packages, namespaced. |

## Project territory: `.claude-wyvrn-local/`

| Path | Status | Purpose |
|---|---|---|
| `PROJECT.md` | read | Optional. Project spec. Overrides `README.md` when present. Bootstrap via `/bootstrap-project`. |
| `ARCHITECTURE.md` | read + write | Project architecture. |
| `conventions/[stack].md` | read | Optional. Project-specific stack conventions. Overrides package stack files on matching stack. |
| `features/` | read + write | Feature specs. |
| `fixes/` | read + write | Fix specs. |
| `refactors/` | read + write | Refactor specs. |
| `decisions/` | read + write | Decision records. |
| `clarifications/` | read + write | Clarification batches. |
| `reviews/` | read + write | Verifier reports. |
| `verifier-gaps/` | read + write | Verifier gap reports. |
| `.archive/` | **no read, no write** | Off-limits except to the `archive` skill. |

## Artifacts

| Artifact | Path | Template | ID format |
|---|---|---|---|
| Feature spec | `.claude-wyvrn-local/features/` | `templates/feature-spec.md` | `FEAT-NNNN-[slug].md` |
| Fix spec | `.claude-wyvrn-local/fixes/` | `templates/fix-spec.md` | `FIX-NNNN-[slug].md` |
| Refactor spec | `.claude-wyvrn-local/refactors/` | `templates/refactor-spec.md` | `REF-NNNN-[slug].md` |
| Architecture | `.claude-wyvrn-local/ARCHITECTURE.md` | `templates/architecture.md` | fixed filename |
| Project spec | `.claude-wyvrn-local/PROJECT.md` | `templates/project.md` | fixed filename |
| Decision record | `.claude-wyvrn-local/decisions/` | `templates/decision.md` | `DEC-NNNN-[slug].md` |
| Clarification batch | `.claude-wyvrn-local/clarifications/` | `templates/clarification-batch.md` | `[flow-id]-batch.md` |
| Verifier report | `.claude-wyvrn-local/reviews/` | `templates/verifier-report.md` | `[flow-id]-review.md` |
| Verifier gap | `.claude-wyvrn-local/verifier-gaps/` | `templates/verifier-gap.md` | `GAP-NNNN-[slug].md` |

`[flow-id]` is the ID of the flow that produced the artifact. Example: the clarification batch from feature flow 0001 is `FEAT-0001-batch.md`.

## ID assignment

- Counters are zero-padded, four digits, autoincremented per type.
- The flow skill assigns the ID at flow start by scanning the relevant folder for the highest existing counter and adding one.
- Slugs are lowercase, hyphen-separated, generated from the task title.
- The human may override the assigned ID in the initial prompt.

## Workflows

| Flow type | Skill | Shared workflow | Flow-specific deltas |
|---|---|---|---|
| Feature | `flow-feature` | `workflows/WORKFLOW.md` | `workflows/FEATURE.md` |
| Fix | `flow-fix` | `workflows/WORKFLOW.md` | `workflows/FIX.md` |
| Refactor | `flow-refactor` | `workflows/WORKFLOW.md` | `workflows/REFACTOR.md` |

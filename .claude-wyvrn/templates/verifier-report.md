# Verifier report: <flow-id>

**Flow ID:** <FEAT-NNNN | FIX-NNNN | REF-NNNN>
**Outcome:** <Success | Findings | Failed>
**Verified at:** <ISO 8601 timestamp>
**Cycle:** <N of M>

> [template] Report produced by the `verifier` agent at end of Verify. On Findings, flow returns to Work; a new report is produced each Verify cycle. Prior cycle reports are preserved.

## Acceptance criteria results

> [template] One row per acceptance criterion in the spec. Include all, regardless of pass/fail.

| Criterion | Status | Evidence |
|---|---|---|
| <AC-N> | <Pass | Fail> | <test identifier or artifact reference> |

## Test suite results

> [template] Result of running tests per the flow-specific delta (feature/fix: new and affected tests; refactor: full suite vs baseline). For refactor flows, compare to baseline.

**Test command:** <command used>
**Total tests:** <count>
**Passed:** <count>
**Failed:** <count>
**New failures (regressions):** <count>
**Pre-existing failures:** <count>

> [template] List any new failures (regressions) with identifiers. Empty if none.
- <test identifier>

## Compliance findings

> [template] Findings that fail the flow and return it to Work. Each finding is actionable and scoped. Leave this section heading even if no findings; empty is written as the single line "None."

<compliance findings, or "None.">

## Out-of-scope findings

> [template] Issues noted during verification that are outside task scope per DECISIONS.md §4.2. These do not fail the flow. Leave this section heading even if no findings; empty is written as the single line "None."

<out-of-scope findings, or "None.">

## Advisory findings

> [template] Subjective code quality observations from `code-reviewer`. These do not fail the flow. Leave this section heading even if no findings; empty is written as the single line "None."

<advisory findings, or "None.">

## Verifier gap reports

> [template] References to any verifier gap reports surfaced during this flow. Populated during post-close correction per WORKFLOW.md §6.1 Case 2. Leave this section heading even if empty; empty is written as the single line "None."

<gap report references, or "None.">

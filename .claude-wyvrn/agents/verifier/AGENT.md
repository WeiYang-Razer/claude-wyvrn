# verifier

Validates flow outputs against spec, tests, code quality, and project alignment. Template compliance is enforced separately at write time by the template-verifier hook (`HARNESS.md` §4.6).

## Role

Invoked at Verify. Orchestrates checks across functional correctness, test results, code quality, and project alignment. Produces the verifier report and determines the flow outcome.

## Invocation

Invoked by the flow skill at the start of Verify. Inputs:

- Flow ID and flow type.
- Spec artifact path.
- Clarification batch path.
- Cycle number (1 for first Verify, incrementing on re-verification after Work).

## Reading sequence

Reads have no inter-read dependencies. Issue them as one parallel batch per `HARNESS.md` §11.2.

1. All files per `HARNESS.md` §3.1.
2. The task-specific workflow file.
3. The spec artifact for the flow.
4. The clarification batch for the flow.
5. All artifacts produced or modified during Work (decision records, ARCHITECTURE.md updates, etc.).
6. The code and test diff for the flow.

## Behavior

Verify runs five checks. Independent checks run in parallel per `HARNESS.md` §11.3: test execution first; acceptance criteria verification, code review, and project alignment run in parallel after tests complete; out-of-scope findings collection runs last as it aggregates observations from the prior checks. Any blocking finding from any check produces a Findings outcome.

### 1. Acceptance criteria verification

For each AC in the spec:

1. Locate the test(s) or artifact(s) claimed to satisfy it.
2. Confirm the claimed artifact exists and exercises the criterion.
3. Record pass/fail per criterion in the report.

### 2. Test suite execution

Run tests per the flow-specific delta:

- Feature: new tests for the acceptance criteria plus tests in files affected by the diff. Confirm new tests pass and no regression in affected tests.
- Fix: reproduction test plus tests in files affected by the diff. Confirm reproduction passes and no regression in affected tests.
- Refactor: full project test suite against baseline from spec artifact, confirm no baseline-pass test newly fails.

Use the test runner's affected-tests mode to scope feature and fix runs (e.g., `jest --findRelatedTests`, `pytest --picked` or `pytest-testmon`, `go test` per touched package). If the project's runner does not support an affected-tests mode, fall back to the full suite and record an advisory finding noting the gap.

Record counts and specific failures in the report.

### 3. Code review

Invoke `code-reviewer` on the code diff. Code-reviewer returns two categories of findings:

- **Blocking** — convention violations per CONVENTIONS.md or stack files.
- **Advisory** — subjective quality issues.

Blocking findings count as compliance findings. Advisory findings go into the advisory findings section.

### 4. Project alignment

#### 4.1 Purpose

Verify the diff reuses existing project code where appropriate and follows patterns extrapolated from the surrounding codebase, not just rules in written conventions.

#### 4.2 Inputs

- The code diff (files added or modified during Work).
- `.claude-wyvrn-local/ARCHITECTURE.md` — module list, paths, public interfaces.
- For each module touched by the diff: every source file in that module's declared path (excluding files in the diff itself).
- For each sibling module declared in ARCHITECTURE.md: only the public interfaces list (Architecture template "Interfaces" subsection).
- The spec artifact (for declared scope, used by §4.5).

Do not read modules outside ARCHITECTURE.md's declared paths. If a module has no declared path, skip it and record one advisory finding noting the gap. Do not scan `node_modules`, `.git`, `dist`, `build`, `.archive`, `out`, `target`, `vendor`, or generated/vendored directories.

#### 4.3 Reuse-candidate identification

For every new symbol declared in the diff (function, class, method, top-level constant), search for reuse candidates against:

1. Declared interfaces in `ARCHITECTURE.md`.
2. Every other source file in the touched module's declared path.
3. Declared interfaces of sibling modules in `ARCHITECTURE.md`.

Flag a reuse candidate when at least three of the following signals hold:

- Identifier overlap >50% (longest common subsequence over normalized, lowercased token-split names).
- Same return type (or both untyped/dynamic).
- Same arity and parameter type sequence (or matching parameter shape for untyped languages).
- Docstring/header-comment overlap by significant nouns/verbs (>=2 shared non-trivial tokens, excluding stop-words).
- Body structural similarity >=80% (token sequence, normalized for identifier renames).

#### 4.4 Pattern extrapolation

For each module touched by the diff, sample 3-5 representative source files from the module's declared path. Prefer most-recently-modified files that were not modified in this diff.

Extract recurring micro-patterns from the sample:

- Error-handling style: return value vs throw vs result-type.
- Logger usage: which logger, which methods, level conventions.
- Naming conventions for unit kinds: handlers, services, helpers.
- Return-type style: explicit vs inferred, optional vs sentinel.
- File-level structure: export shape, import grouping order, top-of-file header.

A micro-pattern qualifies as extrapolated only when it appears in at least 3 of the sampled files with no contradicting sample. Single-file or contradicted patterns are discarded.

Compare new code in the diff against extrapolated patterns. Each violation is a finding.

#### 4.5 Classification

| Signal | Classification |
|---|---|
| New symbol matches existing per §4.3 with body similarity >=80% AND same purpose inferable from spec/docstring. | **Blocking** — reuse missed. |
| Match with body similarity 50-79%, OR exactly 3 signals, OR purposes diverge. | **Advisory** — possible reuse opportunity. |
| New code violates an extrapolated pattern per §4.4. | **Advisory** — pattern drift. |
| Reuse would require modifying code outside declared scope per `DECISIONS.md` §4.2. | **Out-of-scope** finding. Recorded in Check 5. |
| Reuse candidate is in a retired module (`Status: Retired`) or in `.archive/`. | Discarded. |

Worker dispute path: a worker may convert a blocking alignment finding to an INFERRED decision record per `DECISIONS.md` §1 ("Symbol X resembles Y but Y validates SMTP-only and X validates RFC-5322"). The decision record demotes the blocking finding to recorded-and-resolved.

Blocking findings here count as compliance findings (same return path as `code-reviewer` blocking findings). Advisory findings go to the advisory section.

#### 4.6 Output

Each finding records: file path, line range, candidate existing path and symbol (or pattern descriptor), classification, one-line suggested remediation (e.g., "Replace inline implementation with call to `utils/strings.ts:normalizeName`.").

#### 4.7 Bounds

- Hard cap of 5 **blocking** alignment findings per cycle. Findings 6+ degrade to advisory automatically.
- Hard cap of 20 total findings per cycle. Beyond 20, retain the 20 highest-signal-count and record an out-of-scope note about truncation.
- Cycle 2+: only blocking findings on symbols newly added or modified in the most recent Work cycle requalify as blocking. Findings on code unchanged across cycles auto-degrade to advisory. Prevents Verify-Work thrash within `WORKFLOW.md` §4.4 max-3-cycles cap.
- Soft scan budget ~60 files per run. If exceeded, record one advisory finding "Alignment scan budget exceeded; coverage partial." and stop scanning.
- Do not propose cross-module refactors. Do not propose new abstractions. Do not flag duplication that exists outside the diff.

### 5. Out-of-scope findings collection

Collect out-of-scope findings observed during checks 1-4 per `DECISIONS.md` §4.2. Record in the out-of-scope findings section.

## Outcome determination

- **Success** — all ACs pass, all tests pass (or only pre-existing failures for refactor), no blocking code-review findings, no blocking project-alignment findings.
- **Findings** — any blocking issue from any check. Flow returns to Work.

Advisory findings and out-of-scope findings do not trigger Findings outcome. They are recorded and surfaced.

## Outputs

- Verifier report at `.claude-wyvrn-local/reviews/[flow-id]-review.md`.

## Writes

- Verifier report.

## Reads

- All harness files.
- Project-territory context files.
- Spec artifact, clarification batch, produced artifacts.
- Code and test files.
- Source files in modules touched by the diff, and declared interfaces of sibling modules per Check 4.2.

## Constraints

- Do not modify code. Verifier is observational with respect to code.
- Do not modify the spec artifact, clarification batch, or other artifacts from the flow.
- Do not modify ARCHITECTURE.md.
- Do not skip checks. All five run every Verify cycle.
- Do not communicate with the human directly.

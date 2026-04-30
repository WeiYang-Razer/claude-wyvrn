# reuse-hint

Lightweight pre-Work scan that surfaces possible reuse candidates and name collisions for new symbols introduced by the spec. Output is appended to the spec (Context section for feature specs, Implementation notes for fix and refactor specs — see §7) before Work begins.

## Trigger

Invoked by `flow-feature`, `flow-fix`, and `flow-refactor` after Phase 2 (Clarify), before Phase 3 (Work). Not human-invocable.

## Description

Greps the touched module's source files for symbols related to keywords in the spec's intent and acceptance criteria, and performs a name-collision check against any new symbol names the spec proposes. Surfaces matches as a `Possible reuse:` note appended to the spec (Context for feature specs, Implementation notes for fix and refactor specs — see §7). The orchestrator either reuses the surfaced symbol during Work or documents in the spec's Implementation notes why a new symbol is needed.

The check runs entirely in the orchestrator's context. It does **not** invoke a subagent. The skill is intentionally lightweight — name and keyword matching only, no structural body comparison or pattern extrapolation.

## Inputs

- Flow type (`feature`, `fix`, or `refactor`).
- Spec artifact path (already written by Phase 2).
- Triviality verdict from Phase 1.5 (`trivial`, `prompt_complete`, or `standard`).
- `.claude-wyvrn-local/ARCHITECTURE.md` — module list and declared paths.

## Behavior

### 1. Gate

Skip the hint and return immediately when any of the following hold:

1. **Trivial verdict.** The Phase 1.5 verdict is `trivial`. The trivial-flow gate in `skills/triviality-detector/SKILL.md` §3 already excludes new public symbols, so the hint has nothing to surface.
2. **No new-symbol signal in the spec.** Read the spec's Intent (or, for fix flows, Expected outcome and Root cause hypothesis; for refactor flows, Desired shape) and Acceptance criteria. If none of the words `add`, `create`, `new`, `introduce`, `define`, or `expose` appear, and the spec names no identifier absent from the touched module's existing symbols, skip. The spec is not introducing a new symbol.

When skipping, return `skipped` with a one-sentence reason. The flow skill does not append anything to the spec.

### 2. Identify the touched module

From the spec, determine which module(s) the Work will touch:

- **Feature spec:** infer from Intent and Acceptance criteria. If the spec names file paths or module names, use them. If only behavior is described, match against `ARCHITECTURE.md` module names and declared paths.
- **Fix spec:** infer from Reproduction steps and any file paths or symbol names cited.
- **Refactor spec:** the Target area field names files or modules directly.

If no module can be identified with confidence, return `skipped` with reason "Touched module not determinable from spec" — the orchestrator proceeds without a hint.

### 3. Extract keywords and proposed names

From the spec:

1. **Keywords.** Significant nouns and verbs from Intent and Acceptance criteria (or fix/refactor equivalents). Lowercase, drop stop-words (`the`, `a`, `an`, `is`, `to`, `for`, `and`, `or`, `of`, `in`, `on`, `with`, `that`, `this`, `it`). Keep tokens with ≥3 characters.
2. **Proposed new symbol names.** Identifiers in code-style formatting (camelCase, snake_case, PascalCase) named explicitly in the spec as something to be added. If none are explicit, derive 1-2 candidates from the keyword set.

### 4. Scan the touched module

For each file under the touched module's declared path (excluding files in `.archive/`, `node_modules/`, `dist/`, `build/`, `out/`, `target/`, `vendor/`, and any directory matched by `.gitignore`):

1. **Keyword grep.** Grep file contents for each keyword. For each hit, record the file, line, and the surrounding symbol name (the function/class/method/constant declaration that contains the line).
2. **Name-collision check.** For each proposed new symbol name, grep for an existing symbol with the same name (string-equal, case-sensitive) anywhere in the module. Record any collision.

Hard cap: 50 files scanned. If the module exceeds this, scan the most-recently-modified 50 files and note truncation in the output.

### 5. Score and select candidates

For each unique symbol surfaced by the keyword grep, score by:

- Number of distinct keywords matching its declaration line or its docstring/header comment.
- +1 if its name shares ≥3 characters with any proposed new symbol name (case-insensitive substring or shared prefix).

Keep the top 5 candidates by score. Discard score ≤ 1 (single-keyword matches with no name overlap are noise).

### 6. Compose output

Build a markdown block of the form:

```
**Possible reuse:** <one-sentence summary>

| Existing symbol | Path | Why it might apply |
|---|---|---|
| <symbol> | <path> | <one short phrase> |
| ... | ... | ... |

**Name collisions:** <list of (proposed name, existing path:line), or "None.">
```

If only collisions surfaced and no reuse candidates, the table section is omitted and the block contains only the collisions line.

If neither candidates nor collisions surfaced, return `no_findings` with a one-sentence reason. The flow skill does not append anything to the spec.

### 7. Append to spec

The flow skill appends the block to the spec, under existing content of the appropriate destination section, separated by a blank line. Section by spec type:

- **Feature spec** (`feature-spec.md`): Context section.
- **Fix spec** (`fix-spec.md`): Implementation notes section. The fix template has no Context section — placement under Implementation notes is the pre-Work reference for the orchestrator.
- **Refactor spec** (`refactor-spec.md`): Implementation notes section. Same rationale as fix.

The template-verifier hook fires on the spec re-write per `HARNESS.md` §4.6 — correct and re-write if findings.

The orchestrator reads this note at the start of Phase 3 and either:

- Reuses the surfaced symbol during Work, or
- Documents in the spec's Implementation notes why the new symbol is necessary (for example, behavior diverges, signature differs, the existing symbol belongs to a retired module).

### 8. Bias on uncertainty

When a candidate is borderline (score 2, no name overlap), include it. The note is advisory; surfacing one extra symbol is cheaper than missing a real reuse opportunity. False positives are expected and acceptable — the hint is intentionally lightweight.

## Outputs

- Return value: `appended`, `skipped`, or `no_findings`, plus a one-sentence reason.
- Side effect (only on `appended`): the spec gains a `Possible reuse:` block in the destination section per §7.

## Invokes

- None. Runs in the orchestrator's context.
- The template-verifier hook fires on the spec re-write per `HARNESS.md` §4.6.

## Constraints

- Do not invoke any subagent.
- Do not modify code.
- Do not modify spec sections other than the destination section listed in §7.
- Do not perform structural body comparison, longest-common-subsequence matching, or pattern extrapolation. The skill is name and keyword matching only.
- Do not scan modules outside the touched module's declared path. Do not scan archived or vendored directories.
- Honor the gate in §1 absolutely. Do not run the scan when the trivial verdict holds or no new-symbol signal is present.

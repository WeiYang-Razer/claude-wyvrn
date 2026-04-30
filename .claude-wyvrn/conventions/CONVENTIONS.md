# CONVENTIONS.md

Conventions for agent-produced output. Code and artifact authorship. Structural rules in `HARNESS.md`. Decision procedure in `DECISIONS.md`.

## 1. Conventions system

### 1.1 Folders

- `~/.claude-wyvrn/conventions/` — package-shipped conventions. Baseline. Machine-wide.
- `.claude-wyvrn-local/conventions/` — project-specific conventions. Overrides package conventions on the same stack.

Universal rules below. Stack-specific files carry stack-specific rules.

### 1.2 Stack files

Each stack file lives at `conventions/[stack].md` in either territory. `[stack]` is a short identifier (e.g., `js`, `python`, `cpp`, `csharp`).

Every stack file declares its applicable file extensions in a header block at the top of the file.

### 1.3 Discovery and selection

At flow start:

1. Read only the header block of each file in `~/.claude-wyvrn/conventions/` and `.claude-wyvrn-local/conventions/`. The header block carries the `**Stack:**` and `**Applies to extensions:**` declarations and ends before the first `## ` heading. This establishes the extension→stack-file map without loading any rule bodies. Issue these header reads in parallel per `HARNESS.md` §11.2.
2. Build a map from file extension to stack file. On the same extension, project file wins over package file.
3. Lazy-load the body. Read a stack file's body (everything from the first `## ` heading onward) only when a touched source file maps to it. The body for a given stack is read at most once per flow; subsequent matches in the same flow reuse the already-loaded content.
4. For each source file touched during the flow, apply the matching stack file (loading its body per step 3 on first match) in addition to this universal file.
5. If a touched extension has no matching stack file, apply only this universal file, and add a clarification asking whether a stack file should be created.
6. The `conventions/gitflow.md` file in either territory is read on demand at the first Git operation of the flow (branch creation, commit, push, PR). Project file overrides package file. If absent in both territories, agents follow whatever Git practice the existing repository displays per §2.1.

### 1.4 Precedence on conflict

Within a single source file:

1. `.claude-wyvrn-local/conventions/[stack].md` rules.
2. `~/.claude-wyvrn/conventions/[stack].md` rules.
3. This file.
4. Observed conventions in the existing codebase (see §2.1).

Most specific wins. Project stack rules override package stack rules, which override universal rules.

## 2. Code production

### 2.1 Match existing style and reuse

When modifying or extending an existing codebase, match the style and reuse the components already in use:

- Naming, file structure, import and dependency patterns.
- Existing utilities, helpers, and shared functions — call them rather than re-implementing equivalents.

Observed style and reuse opportunities override written conventions only when the existing code is internally consistent. Inconsistent codebases fall back to written conventions. The verifier enforces reuse via the project-alignment check per `WORKFLOW.md` §4.2.

### 2.2 No speculative code

Do not produce:

- Commented-out code.
- TODO markers.
- Placeholder implementations or stubs, unless explicitly requested.
- Future-proofing for requirements not in the current scope.

Every line produced must serve the current task.

### 2.3 No new dependencies without a decision

Do not add a library, package, framework, or external tool without:

- Explicit instruction in the spec or initial prompt, or
- An INFERRED decision record via the `decision-log` skill citing why the dependency is unavoidable.

Adding a dependency because it "would be useful" or "is standard" is prohibited. If a dependency seems required but is not explicitly authorized, classify as UNDECIDED per `DECISIONS.md`.

### 2.4 No silent reformatting

Do not reformat code outside the task scope:

- No whitespace changes outside edited lines.
- No reordering of imports or declarations outside edited sections.
- No applying different style rules to untouched code.

Reformat only what is being modified for functional reasons.

### 2.5 No silent renames

Do not rename variables, functions, classes, files, or paths unless the rename is explicitly required by the task. Renames are high-impact and require explicit authorization.

### 2.6 Test production

General test rules. Stack-specific test rules (framework, file naming, runner invocation) live in stack files.

- Feature flow: new tests covering each acceptance criterion in the spec.
- Fix flow: at least one test that would have caught the bug. No regression in existing tests.
- Refactor flow: preserve existing test behavior. Do not delete or weaken tests without a decision record.
- Tests are written before declaring implementation complete.
- Do not mask, skip, or mark failures as expected without a decision record.

## 3. Engineering judgment

Rules in this section apply when producing source code. Stack files refine these for a specific language. The universal rules in this section bind regardless of stack.

### 3.1 Simplicity over cleverness

- Prefer the most direct expression of intent. The shortest correct version that uses constructs already present in the codebase wins.
- Do not introduce abstractions (interfaces, layers, indirection, generics, design patterns) without a current caller that requires them. One caller is not enough — abstractions earn their existence at the second caller.
- Inline single-use helpers unless the helper makes the call site materially clearer.

### 3.2 Naming

- Names describe the thing, not its type or container. `userIds`, not `userIdList` or `arrUserIds`. `parseHeader`, not `parseHeaderFunc`.
- Symmetry between paired operations is mandatory: `open`/`close`, `acquire`/`release`, `enable`/`disable`. Do not mix `start` with `stop`-vs-`end` in the same module.
- A name that requires a comment to be understood is the wrong name. Rename instead of commenting.
- Boolean names assert state, not action: `isReady`, `hasErrors`, not `checkReady`.

### 3.3 Function and class size

- A function does one thing at one level of abstraction. Mixing levels (orchestration plus arithmetic plus I/O) is a split signal.
- Limits are guidelines, not gates: a function above ~50 lines or a class above ~300 lines is a candidate for review, not an automatic violation. Cohesion overrides line count.
- Splitting a function only to satisfy a line count, with no improvement in cohesion or testability, is prohibited.

### 3.4 Error handling

- Errors are values, not control flow tricks. Handle at the layer that has the context to decide, not at the layer that first observes the failure.
- Do not swallow errors. Catching and discarding (empty `catch`, ignored result types, `// suppress`) is prohibited unless paired with a comment explaining why the failure is non-actionable here.
- Error messages name the operation that failed, the input that caused it, and the layer reporting it. No "something went wrong".
- Recoverable conditions and bugs are different. Validation failures and missing resources are recoverable. Invariant violations and unreachable states crash loudly with the smallest possible message.

### 3.5 Security and defensive programming

- Treat every value crossing a process boundary (network, filesystem, IPC, env, CLI args, deserialized blobs) as untrusted. Validate at the boundary, not at the consumer.
- Never log secrets, tokens, credentials, full request bodies, or PII. When in doubt, redact.
- Do not concatenate untrusted strings into shell commands, SQL, file paths, or template output. Use the parameterized API the stack provides.
- Defensive guards belong at trust boundaries and exported APIs. Internal helpers assume their callers passed valid inputs.

### 3.6 Comments

- Comments explain *why* and *what surprises*, not *what*. The code is the *what*.
- Update or delete comments that no longer match the code. A stale comment is a bug.
- Doc comments on exported APIs document contract: inputs, outputs, side effects, error conditions. Implementation comments are rare and load-bearing.

## 4. Artifact authorship

Artifacts are markdown files produced in `.claude-wyvrn-local/` — specs, decision records, clarification batches, verifier reports, verifier gaps.

### 4.1 Agent-facing style

Every artifact is agent-facing. Optimize for agent parsing:

- Numbered or bulleted lists over prose.
- Imperative voice. Short sentences. One claim per line.
- Explicit structure via headings. No meta-commentary about the document.
- Tables for structured data.
- No decorative elements (banners, emoji, welcome messages).
- Brief prose only where structure would obscure meaning.

The human reads some artifacts at flow boundaries but reads them accepting this style. Do not adjust style to be "friendlier" to the human.

### 4.2 No prose preamble

Do not open any artifact with introductory prose about what the document is or why it exists. Template structure carries this. Begin with content under the first section.

### 4.3 Template compliance

Every artifact must match its template structurally. Rules are in `HARNESS.md` §4. Enforcement is by the template-verifier hook (`hooks/template_verifier.py`) registered as a `PostToolUse` hook on `Write`/`Edit`/`MultiEdit`. Section presence, order, and naming are fixed by the template.

### 4.4 Template marker convention

Templates use `> [template]` blockquote markers to distinguish instructional content from structural content:

- Lines starting with `> [template]` contain instructions for the agent filling the template. They are not part of the artifact structure.
- Do not copy `> [template]` lines into the output artifact.
- All other lines (headings, list items, tables, prose) are structural and must appear in the output artifact as-is, with `<placeholder>` tokens replaced by content.

The template-verifier hook strips `> [template]` lines before comparing template structure to artifact structure.

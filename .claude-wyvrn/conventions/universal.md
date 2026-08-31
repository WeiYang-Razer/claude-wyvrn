# universal.md

Universal conventions for agent-produced code. Stack files refine these per language. Project files in `.claude-wyvrn-local/conventions/` override on conflict.

## 1. Code production

### 1.1 Strict convention adherence

Conventions are authoritative. New code follows the matching convention even when the existing codebase deviates.

- Do not propagate codebase deviations into new code.
- Do not fix unrelated convention violations outside task scope.
- Before declaring a new public symbol, grep the touched module for similar names. Prefer reuse over duplication.
- Intentional project deviations belong in `.claude-wyvrn-local/conventions/<stack>.md` (overrides the global file). Until that override exists, the global convention wins.

### 1.2 No speculative code

Do not produce:

- Commented-out code.
- TODO markers.
- Placeholder implementations or stubs, unless explicitly requested.
- Future-proofing for requirements not in current scope.

Every line produced serves the current task.

### 1.3 No new dependencies without permission

Do not add a library, package, framework, or external tool without:

- Explicit instruction in the prompt, or
- User confirmation via `AskUserQuestion` citing why the dependency is necessary.

"Would be useful" or "is standard" is not enough.

### 1.4 No silent reformatting

Do not reformat code outside task scope:

- No whitespace changes outside edited lines.
- No reordering of imports or declarations outside edited sections.
- No applying different style rules to untouched code.

Reformat only what is being modified for functional reasons.

### 1.5 No silent renames

Do not rename variables, functions, classes, files, or paths unless the rename is explicitly required by the task.

### 1.6 Test production

- Any change to executable code (build-time or runtime) ships with a test exercising the change.
- Documentation files, configuration without logic, and README updates do not require tests — use judgment.
- A bug fix ships with at least one test that would have caught the bug.
- A refactor preserves existing test behavior. Do not delete or weaken tests without explicit user confirmation.
- Tests are written before declaring implementation complete.
- Do not mask, skip, or mark failures as expected without explicit user confirmation.

### 1.7 Parallelize independent operations

Issue independent operations as a single tool-use message. Sequence only when one operation's output feeds the next.

Parallelize:

- Multiple `Read` calls for independent files (always at flow start).
- Multiple `Grep` calls against different patterns or paths.
- Multiple `Edit` / `Write` calls when the changes are independent.
- Multiple `Bash` commands when neither depends on the other's output.
- Multiple `Agent` (Explore) spawns when investigating different areas.

## 2. Engineering judgment

Stack files refine these per language. These bind regardless of stack.

### 2.1 Simplicity over cleverness

- Prefer the most direct expression of intent. The shortest correct version using constructs already in the codebase wins.
- Do not introduce abstractions (interfaces, layers, indirection, generics, design patterns) without a current caller that requires them. One caller is not enough — abstractions earn their existence at the second caller.
- Inline single-use helpers unless the helper makes the call site materially clearer.

### 2.2 Naming

- Names describe the thing, not its type or container. `userIds`, not `userIdList` or `arrUserIds`. `parseHeader`, not `parseHeaderFunc`.
- Symmetry between paired operations is mandatory: `open`/`close`, `acquire`/`release`, `enable`/`disable`. Do not mix `start` with `stop`-vs-`end` in the same module.
- A name that requires a comment to be understood is the wrong name. Rename instead of commenting.
- Boolean names assert state, not action: `isReady`, `hasErrors`, not `checkReady`.

### 2.3 Function and class size

- A function does one thing at one level of abstraction. Mixing levels (orchestration plus arithmetic plus I/O) is a split signal.
- Limits are guidelines: a function above ~50 lines or a class above ~300 lines is a candidate for review, not an automatic violation. Cohesion overrides line count.
- Splitting a function only to satisfy a line count, with no improvement in cohesion or testability, is prohibited.

### 2.4 Error handling

- Errors are values, not control flow tricks. Handle at the layer that has the context to decide.
- Do not swallow errors. Catching and discarding (empty `catch`, ignored result types, `// suppress`) is prohibited unless paired with a comment explaining why the failure is non-actionable here.
- Error messages name the operation that failed, the input that caused it, and the layer reporting it. No "something went wrong".
- Recoverable conditions and bugs are different. Validation failures and missing resources are recoverable. Invariant violations and unreachable states crash loudly with the smallest possible message.

### 2.5 Security and defensive programming

- Treat every value crossing a process boundary (network, filesystem, IPC, env, CLI args, deserialized blobs) as untrusted. Validate at the boundary.
- Never log secrets, tokens, credentials, full request bodies, or PII. When in doubt, redact.
- Do not concatenate untrusted strings into shell commands, SQL, file paths, or template output. Use the parameterized API the stack provides.
- Defensive guards belong at trust boundaries and exported APIs. Internal helpers assume their callers passed valid inputs.

### 2.6 Comments

- Comments explain *why* and *what surprises*, not *what*.
- Update or delete comments that no longer match the code. A stale comment is a bug.
- Doc comments on exported APIs document contract: inputs, outputs, side effects, error conditions. Implementation comments are rare and load-bearing.

## 3. Adversarial honesty

Default posture for every assessment, not an opt-in mode. Binds any target: a premise stated in chat, a spec, a plan, a diff, a file, an estimate, a proposed architecture.

### 3.1 No sugar-coating

- No encouragement, no compliments, no "great question", no softening preamble. Open with the assessment.
- Do not agree to be agreeable. Agreement requires stated evidence — a file, a benchmark, a constraint, a citation. Absent evidence, say the claim is unverified.
- When the user pushes back, re-evaluate on the merits and state the outcome. Reversing a correct position because the user objected is prohibited; so is restating it without addressing the objection.
- Bad news is delivered first and unhedged. "This will not work because X" beats "there may be some considerations around X".
- Critique targets the work, never the person. Hostility is not honesty.

### 3.2 Attack order

When asked to critique, evaluate, or review — and unprompted whenever a plan is about to be executed on a broken premise:

1. **Premise** — is the problem real, and is it the problem worth solving? A flawless solution to a non-problem is a total loss. Say so first.
2. **Fatal flaws** — what makes this fail outright. Each stated as a concrete failure scenario: input, state, or condition → observed wrong outcome.
3. **Weak points** — what degrades under load, scale, time, staff turnover, or adversarial use. Name the threshold where it breaks.
4. **Logical fallacies and unstated assumptions** — circular reasoning, survivorship bias, false dichotomy, assumed causation, load-bearing assumptions nobody validated. Quote the specific claim being challenged.
5. **Cost** — what this costs in maintenance, complexity, and blocked future options, against what it returns.

### 3.3 Verdict

Every critique ends with an explicit verdict, no hedge:

- **Will fail** — with the single most likely cause named.
- **Survives, with conditions** — list the conditions; they are load-bearing, not nice-to-haves.
- **Sound** — permitted, and required when true. State the evidence and name the conditions under which it stops being true.

### 3.4 Do not manufacture flaws

Criticism is not a quota. Inventing objections to appear rigorous is the same failure as flattery — both replace the assessment with a performance.

- Every flaw cites a specific claim, line, or file. A flaw that cannot be traced to one is speculation and must be labeled as such.
- Severity is ranked, not flattened. A typo and a data-loss race do not appear in the same list without their severities on them.
- Uncertainty is stated as uncertainty: "unverified", "I did not test this path". Confident phrasing for an unchecked claim is prohibited (§1.6, `/verify-done`).
- Praise appears only when it is load-bearing — when the good decision is the reason a later objection does not apply.

## 4. Convention precedence

When rules from multiple sources apply to the same source file, most-specific wins:

1. `.claude-wyvrn-local/conventions/<stack>.md`
2. `~/.claude-wyvrn/conventions/<stack>.md`
3. This file

The existing codebase is NOT authoritative for new code (see §1.1). Codebase observations may inform reading and reuse but do not override written conventions.

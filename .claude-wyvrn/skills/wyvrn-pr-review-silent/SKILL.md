---
name: wyvrn-pr-review-silent
description: Read-only PR review that posts nothing. Fetches the PR metadata and full diff, reviews every changed file with an auditable coverage list, and reports a verdict with blocking issues, nits, and a per-fix effort estimate. Never posts a comment, never approves, never edits. Use when the user asks to review a PR without touching it, says "review but don't post", "just tell me what's wrong", or invokes /wyvrn-pr-review-silent. For a review that posts inline comments to Bitbucket, use bitbucket-pr-review instead.
---

# wyvrn-pr-review-silent

Reviews a pull request and reports back in the terminal. Posts nothing, approves nothing,
edits nothing. The output is a synthesis for the user to act on, not a review left on the PR.

The distinction from `bitbucket-pr-review` is the only thing that matters here: that skill's
job is to post inline comments. This skill's job is to never touch the PR at all.

## Execution principles

- **Read-only is the whole point.** Every write path is closed: no comment, no inline comment,
  no approval, no request-changes, no branch checkout that mutates the working tree, no edit.
- **Coverage is auditable.** The user can check that every changed file was actually looked at,
  because every changed file is named in the output.
- **Every claim is verified against source before it is asserted.** A review finding that turns
  out not to be in the code is worse than no review.
- Parallelize the Step 1 fetches; everything after is sequential.

## Preconditions

- A PR identifier: a URL, a PR number, or a branch the user names.
- Read access to the PR and its diff.
- No preconditions on the working tree. This skill does not need a clean tree because it does
  not touch it.

## Rules

1. **Post nothing.** No comment, no inline comment, no approval, no request-changes, no
   reaction, no status. This holds even when a finding is obviously correct and the user is
   obviously going to want it posted. If the user wants it posted, they will say so, and that
   is `bitbucket-pr-review`'s job.
2. **Edit nothing.** No file changes, no fixes, no "while I was in there". Findings are
   described, not applied.
3. **Name every changed file.** The coverage list is part of the output, not an internal note.
   A file listed as reviewed must actually have been read.
4. **Cite `file:line` for every finding.** A finding without a location is not a finding; it is
   a guess. If a claim cannot be traced to a line, either verify it or label it explicitly as
   unverified.
5. **Verify before asserting.** Read the surrounding code, not just the diff hunk. A diff shows
   what changed, not what the changed code now does. Findings about behavior require reading
   the function, its callers, or its tests.
6. **Rank by severity, do not flatten.** A typo and a data-loss race never appear in the same
   list at the same weight (`universal.md` section 3.4).
7. **Do not manufacture findings.** An empty blocking-issues list is a legitimate result. Padding
   a review to look thorough is the same failure as flattery.
8. **Stop after reporting.** Do not begin fixing. Wait for the user to say so explicitly.

## Steps

1. **Fetch.** In one batch: PR metadata (title, description, author, target branch, state) and
   the full diff. Prefer the full diff over a file list plus per-file fetches -- it is one call
   and it cannot silently skip a file.
2. **Enumerate.** Build the list of changed files with their add/delete line counts. This list
   is the coverage contract for the rest of the review.
3. **Review each file.** Read the diff hunk, then read enough surrounding source to judge it.
   Open the callers when a signature, contract, or invariant changed. Open the tests when
   behavior changed. Apply the matching stack conventions -- they are authoritative even where
   the surrounding code deviates.
4. **Verify each candidate finding** against the source before it enters the output. Drop the
   ones that do not survive.
5. **Report** in the format below. Then stop.

## Output format

```
## Verdict
<approve | request-changes> -- <one sentence, the single most important reason>

## Coverage
<N> files reviewed:
- path/to/File.cpp (+42/-3)
- path/to/Other.h (+7/-0)
...

## Blocking issues
1. `path/to/File.cpp:88` -- <what is wrong and what happens because of it>
   Fix: <the concrete change>
   Effort: <trivial | small | medium | large>
...

## Nits
- `path/to/Other.h:12` -- <what and why>
  Effort: <...>
...

## Unverified
- <any claim that could not be traced to source, stated as uncertain>
```

- **Verdict** is explicit and unhedged. `approve` is permitted, and required when the diff is
  sound -- state the evidence.
- **Blocking issues** are defects that must change before merge: correctness, data loss, security,
  a broken contract, a convention violation with real consequence.
- **Nits** are everything else. Say plainly that they are optional.
- **Effort** is per fix, not for the PR as a whole.
- Omit **Unverified** when it is empty. Never omit **Coverage**.

## Prohibitions

- Never post a comment, inline comment, approval, or request-changes. This skill has no write path.
- Never edit a file, apply a fix, or check out the branch to "try something".
- Never begin fixing after reporting, even when the user's next message is enthusiastic -- wait
  for an explicit instruction to fix.
- Never claim a file was reviewed that was not read.
- Never state a finding without a `file:line`, or state an unverified claim in confident phrasing.
- Never pad the findings list to appear rigorous.
- Do not modify `~/.claude-wyvrn/`.

## Integration

- `bitbucket-pr-review` -- the posting counterpart. Mutually exclusive with this skill: pick one.
- `universal.md` section 3 -- adversarial honesty. Governs the verdict, the severity ranking, and
  the prohibition on manufactured findings.
- `~/.claude-wyvrn/conventions/<stack>.md` -- authoritative for style findings.
- `gitflow.md` section 7 -- if a finding implies history surgery, propose it; do not run it.

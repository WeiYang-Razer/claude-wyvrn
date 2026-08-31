# Conventions: gitflow

Branching, commit, and merge protocol. Read by `/flow` at Step 1 alongside `universal.md`. Consulted at Step 2 (branch) and Step 10 (commit, push).

## 1. Branching model

- `master` is the release branch. Production-ready code only. Direct commits prohibited.
- `develop` is the integration branch. All work targets `develop` via pull request.
- `master` advances only by merging `develop` (or a release branch cut from `develop`) when the user declares a release.
- Exception: `hotfix/` branches are cut from `master` for urgent production repair and reach `master` via PR (§4). After merge, back-merge `master` into `develop` and tag a patch release (§5).

## 2. Branch types and naming

Branch name pattern: `<type>/<DEVINITIALS>_<branchNameCamelCase>`.

| Type | Prefix | Used for |
|---|---|---|
| Feature | `feature/` | New behavior |
| Fix | `fix/` | Bug repair, no tracking ticket |
| Bugfix | `bugfix/` | Bug repair driven by a Bug ticket |
| Hotfix | `hotfix/` | Urgent production fix, cut from `master` (§1) |
| Refactor | `refactor/` | Structural change, no behavior change |
| Chore | `chore/` | Housekeeping (tooling, deps, docs, CI) |

`<DEVINITIALS>`: developer's uppercase initials (2 or 3 characters).
`<branchNameCamelCase>`: short, behavior-describing camelCase phrase. Lowercase first letter. No separators.

Ticket-driven branches (e.g. `/ship-ticket`) use `<type>/<TICKET-ID>[-<kebab-slug>]` instead: the
ticket ID replaces the initials and the optional slug is lowercase kebab-case
(`bugfix/CHROMA2-91-render-thread`). Everything else in this section applies unchanged.

### 2.1 Examples

- `feature/TR_newConversionMethod`
- `fix/AL_keyframeArrayOverflow`
- `refactor/TR_extractPaymentService`
- `bugfix/CHROMA2-91-render-thread` (ticket-driven)
- `hotfix/TR_paymentGatewayTimeout`
- `chore/TR_bumpEslintToV9`

### 2.2 Prohibited

- No spaces, slashes (beyond the type prefix), underscores other than the one separating initials from name, or special characters.
- No long phrases. Aim under 50 characters total.
- No reuse of a merged branch name.

## 3. Commits

- Format: `<type>(<scope>): <subject>`.
- Type: one of `feat`, `fix`, `refactor`, `chore`, `docs`, `test`, `build`, `ci`.
- Subject: imperative mood, lowercase first letter, no trailing period, under 72 characters.
- Body: blank-line separated; wrap at 100 columns; explains *why*, not *what*.
- Footer (optional): issue/ticket references such as `Refs:` or `Fixes:` when the project tracks them externally.
- One logical change per commit.

### 3.1 Example

```
feat(auth): add SAML SSO provider

Implements the SAML 2.0 redirect binding. Configuration lives in
config/auth.yaml under the new providers.saml block.
```

## 4. Pull requests and merges

- Every branch except `develop`, `master`, and `hotfix/` branches reaches `develop` via PR. No direct pushes to `develop` or `master`.
- `hotfix/` branches PR into `master`. After merge, back-merge `master` into `develop` immediately so the fix is not lost at the next release.
- PR title matches the branch name's intent.
- Squash-merge is the default. The squash commit follows §3.
- Rebase-merge only when the branch contains semantically meaningful intermediate commits the user wants preserved.
- `develop` → `master` merges happen at release time only, declared by the user. Use a merge commit (no squash) so release history is traceable.
- Delete the source branch after merge.

## 5. Tags and releases

- Releases are tagged on `master` after the `develop` → `master` merge.
- Hotfix merges to `master` are tagged the same way, bumping `<PATCH>`.
- Tag format: `v<MAJOR>.<MINOR>.<PATCH>` per semver. Pre-releases: `v<MAJOR>.<MINOR>.<PATCH>-<label>.<n>`.
- Annotated tags only. Lightweight tags prohibited.

## 6. Prohibitions

- No force-push to `master`, `develop`, or any open PR branch with reviewers assigned.
- No rewriting commits that have been pushed and reviewed.
- No commits with secrets, credentials, large binaries (>10 MB), or generated artifacts.
- No merging a branch with failing CI without explicit user confirmation citing why.
- No history rewrite (rebase, amend, `reset --hard`, force-push, squash of existing commits) without explicit approval in the current turn (section 7).
- No change to what git tracks (`.gitignore`, `.gitattributes`, `git rm --cached`, `update-index`, submodules) without explicit approval in the current turn (section 7).

## 7. Git boundaries

Two classes of git operation are never performed on the agent's own initiative, however obviously
correct they look. Both can destroy work that no longer exists anywhere in the working tree.

**History rewriting.** `git rebase` (interactive or not), `git commit --amend`, `git reset --hard`,
`git filter-branch` / `git filter-repo`, `git push --force` / `--force-with-lease`, `git cherry-pick`
onto a rewritten base, and any squash that collapses commits that already exist.

**File tracking changes.** Editing `.gitignore`, `.gitattributes`, or `.git/info/exclude`;
`git rm --cached`; `git update-index --assume-unchanged` / `--skip-worktree`; adding, removing, or
re-pointing a submodule.

- **Ask first, in the current turn, and get an explicit yes.** Approval never carries over — not from
  an earlier turn, not from a previous task, not from a similar operation approved ten minutes ago.
- **Name the exact command and the exact target when asking.** "Should I clean up the history?" is not
  a request for approval. "Run `git rebase -i HEAD~3` on `feature/x`, squashing a1b2c3d..e4f5a6b?" is.
- **An instruction that merely implies a rewrite is a request to propose one, not authority to run it.**
  "Clean up these commits", "make this one commit", "get rid of that file" — state what you would run,
  then wait.
- **Section 4's squash-merge default is scoped to merging a PR the user asked to merge.** It is not
  standing authority to squash commits on a branch, and it does not pre-approve a local rebase.
- **When a rewrite is declined or the question goes unanswered, take the non-destructive path** — a new
  commit, a revert commit, a new branch — and say plainly what you did instead.
- **Untracking a committed file does not remove it from history.** If the goal is to purge a secret,
  say so directly: the credential must be treated as already compromised and rotated. History surgery
  is a separate operation needing its own explicit approval, and it does not undo the exposure.

# Conventions: gitflow

Branching, commit, and merge protocol. Read by `/flow` at Step 1 alongside `universal.md`. Consulted at Step 2 (branch) and Step 10 (commit, push).

## 1. Branching model

- `master` is the release branch. Production-ready code only. Direct commits prohibited.
- `develop` is the integration branch. All work targets `develop` via pull request.
- `master` advances only by merging `develop` (or a release branch cut from `develop`) when the user declares a release.

## 2. Branch types and naming

Branch name pattern: `<type>/<DEVINITIALS>_<branchNameCamelCase>`.

| Type | Prefix | Used for |
|---|---|---|
| Feature | `feature/` | New behavior |
| Fix | `fix/` | Bug repair |
| Refactor | `refacto/` | Structural change, no behavior change |
| Chore | `chore/` | Housekeeping (tooling, deps, docs, CI) |

`<DEVINITIALS>`: developer's uppercase initials (2 or 3 characters).
`<branchNameCamelCase>`: short, behavior-describing camelCase phrase. Lowercase first letter. No separators.

### 2.1 Examples

- `feature/TR_newConversionMethod`
- `fix/AL_keyframeArrayOverflow`
- `refacto/TR_extractPaymentService`
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

- Every branch except `develop` and `master` reaches `develop` via PR. No direct pushes to `develop` or `master`.
- PR title matches the branch name's intent.
- Squash-merge is the default. The squash commit follows §3.
- Rebase-merge only when the branch contains semantically meaningful intermediate commits the user wants preserved.
- `develop` → `master` merges happen at release time only, declared by the user. Use a merge commit (no squash) so release history is traceable.
- Delete the source branch after merge.

## 5. Tags and releases

- Releases are tagged on `master` after the `develop` → `master` merge.
- Tag format: `v<MAJOR>.<MINOR>.<PATCH>` per semver. Pre-releases: `v<MAJOR>.<MINOR>.<PATCH>-<label>.<n>`.
- Annotated tags only. Lightweight tags prohibited.

## 6. Prohibitions

- No force-push to `master`, `develop`, or any open PR branch with reviewers assigned.
- No rewriting commits that have been pushed and reviewed.
- No commits with secrets, credentials, large binaries (>10 MB), or generated artifacts.
- No merging a branch with failing CI without explicit user confirmation citing why.

---
name: wyvrn-commit
description: Stage and make a git commit per gitflow.md section 3, in caveman style. Use when the user asks to commit work in a wyvrn harness repo, or invokes /wyvrn-commit. Terse subject, no trailer, ASCII only. This skill runs the commit; for message text alone without staging or committing, use caveman-commit instead.
---

# wyvrn-commit

Stages related changes and commits them with a terse, convention-conformant message.
`gitflow.md` section 3 defines the message format; this skill adds the caveman voice,
the no-trailer rule, and the shell mechanics.

## Execution principles

- **Conventions are authoritative.** `gitflow.md` section 3 owns format, type list,
  subject length, and body wrap. This skill never relaxes them.
- **One logical change per commit.** Stage by intent, not by "everything dirty".
- **The message is human-only.** No tool attribution, ever.
- Parallelize the Step 1 inspection commands; everything after is sequential.

## Preconditions

- Inside a git repository with at least one change to commit.
- On a branch that is not `develop` or `master` (`gitflow.md` section 1). If HEAD is on
  either, stop and ask before committing.
- Committing is user-initiated. Do not commit as a side effect of other work.

## Rules

1. **Format (from `gitflow.md` section 3, mandatory).** `<type>(<scope>): <subject>`.
   - Type: one of `feat`, `fix`, `refactor`, `chore`, `docs`, `test`, `build`, `ci`.
   - Scope: the touched module, package, or area. Omit the parentheses only when the
     change is genuinely repo-wide.
   - Subject: imperative mood, lowercase first letter, no trailing period, under 72
     characters. Aim for 50.
2. **Caveman subject.** Terse like a smart caveman. Drop articles (a/an/the), filler,
   and hedging. Fragments are fine. Keep technical terms, symbols, and paths exact.
   - Bad: `chore(pkg): Added a new ignore file for the wyvrnpm package manager`
   - Good: `chore(pkg): add wyvrnignore, wire wyvrnpm manifest`
3. **Body optional.** Include only when the "why" is not obvious from the diff.
   Blank-line separated, wrapped at 100 columns (`gitflow.md` section 3), caveman prose,
   explains why rather than what.
4. **No trailers.** Never append `Co-Authored-By:`, `Claude-Session:`, `Generated with`,
   or any other tool attribution. The only permitted footer is an issue reference
   (`Refs:`, `Fixes:`) when the project tracks them externally.
5. **ASCII only.** The entire message is 7-bit ASCII. No em-dashes, smart quotes, arrows,
   emoji, or non-English glyphs.
6. **One `-m`, POSIX syntax.** The commit carries exactly one message argument. Never use
   PowerShell here-string syntax (`@'...'@`, `@"..."@`) in the Bash tool; it leaks stray
   `@` characters into the message. Subject-only commits use `-m "<subject>"`; a
   subject-plus-body commit uses a single `-m` fed by a POSIX heredoc (see Step 4).

## Steps

1. **Inspect.** Run `git status`, `git diff`, and `git diff --cached` in one batch.
2. **Stage by intent.** `git add <paths>` for the files belonging to this one logical
   change. Never `git add -A` blindly. If the working tree holds two unrelated changes,
   commit them separately rather than merging them into one message.
3. **Compose.** Write the message per the Rules above. Pick the type from the dominant
   intent of the staged diff, not from the file count.
4. **Commit.** Subject only:

   ```bash
   git commit -m "<type>(<scope>): <subject>"
   ```

   Subject plus body, single `-m` via heredoc so the formatting survives verbatim:

   ```bash
   git commit -m "$(cat <<'EOF'
   <type>(<scope>): <subject>

   <body, wrapped at 100 columns>
   EOF
   )"
   ```

5. **Receipt.** Show `git log -1 --stat` so the subject, body, and file list are visible.

## Prohibitions

- Never commit without the user asking (`/flow` Step 10 keeps the same gate).
- Never push as part of this skill. Pushing is a separate, explicitly requested action.
- Never amend or rewrite a commit that has already been pushed (`gitflow.md` section 6).
- Never commit secrets, credentials, binaries over 10 MB, or generated artifacts
  (`gitflow.md` section 6).
- Never stage unrelated changes to save a round trip.
- Do not modify `~/.claude-wyvrn/`.

## Integration

- `gitflow.md` section 3 - authoritative message format; this skill implements it.
- `/flow` Step 10 and `/subagent-dev` - both commit under these same rules; a plan's
  own commit steps take precedence when they spell out an exact message.

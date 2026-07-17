---
name: commit
description: Caveman-style git commit. Use when user asks to commit, says /commit, or wants commit message written. Terse subject, no co-author trailer, ASCII only.
---

# Caveman Commit

Commit staged/unstaged work with terse caveman message.

## Rules

1. **Caveman style.** Subject line terse like smart caveman. Drop articles (a/an/the), filler, hedging. Fragments OK. Keep technical terms exact.
   - Bad: `Added a new ignore file for the wyvrnpm package manager`
   - Good: `add wyvrnignore, wire wyvrnpm manifest`
2. **Conventional Commits prefix** when type obvious: `feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `build:`, `test:`. Skip when nothing fits.
3. **Subject <= 50 chars** after prefix if possible; hard cap 72. Imperative mood. No trailing period.
4. **Body optional.** Only when "why" not obvious from diff. Caveman prose, wrapped at 72 cols.
5. **NO co-author trailers.** Never add `Co-Authored-By:`, `Claude-Session:`, `Generated with`, or any tool attribution lines. Message is human-only.
6. **ASCII only.** Entire message 7-bit ASCII. No emoji, no smart quotes, no arrows, no non-English glyphs.
7. **POSIX syntax in Bash.** Never use PowerShell here-string syntax (`@'...'@`, `@"..."@`) in the Bash tool — it leaks stray `@` characters into the message. Multi-line messages use a POSIX heredoc (`git commit -m "$(cat <<'EOF' ... EOF)"`) or multiple `-m` flags.

## Steps

1. `git status` + `git diff` (and `git diff --cached`) to see changes.
2. Group related changes; stage what belongs together (`git add <paths>`). Never `git add -A` blindly.
3. Write message per rules above.
4. Commit via POSIX heredoc (rule 7) to keep formatting exact.
5. Show `git log -1 --stat` result as receipt.

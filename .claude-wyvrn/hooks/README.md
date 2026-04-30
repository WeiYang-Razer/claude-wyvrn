# Wyvrn hooks

Deterministic checks invoked by Claude Code's hook system. Replace subagent calls with scripts where the work is purely structural — faster, cheaper, no fresh-context tax.

## Scripts

| Script | Triggered by | Purpose |
|---|---|---|
| `template_verifier.py` | `PostToolUse` on `Write`, `Edit`, `MultiEdit` | Validates artifacts in `.claude-wyvrn-local/` against their templates. Replaces the former `template-verifier` subagent. |

## Installing the template-verifier hook

The hook is wired into Claude Code via `settings.json`. You can add it at any settings level — global (`~/.claude/settings.json`), project-shared (`.claude/settings.json`), or project-local (`.claude/settings.local.json`).

A ready-to-paste snippet is in `settings.example.json` next to this README.

Add to the `hooks.PostToolUse` array:

```json
{
  "matcher": "Write|Edit|MultiEdit",
  "hooks": [
    {
      "type": "command",
      "command": "python \"$HOME/.claude-wyvrn/hooks/template_verifier.py\""
    }
  ]
}
```

Notes:

- **Python 3.10+** must be on `PATH` as `python`. On systems where only `python3` exists, change the command accordingly.
- The `$HOME` expansion is shell-resolved on Unix and Git Bash. On native Windows shells, replace with the absolute path (e.g., `python "C:/Users/<you>/.claude-wyvrn/hooks/template_verifier.py"`).
- The matcher fires on every `Write`/`Edit`/`MultiEdit`. The script itself filters paths down to `.claude-wyvrn-local/**/*.md` and exits silently for everything else, so it is safe to leave globally enabled.

## What the hook does

1. Reads the Claude Code `PostToolUse` JSON payload from stdin.
2. Resolves the artifact path and locates its template via the folder map declared in `INDEX.md` ("Artifacts" table). Files outside `.claude-wyvrn-local/`, files under `.archive/`, and folders without a mapped template are skipped silently.
3. Strips `> [template]` lines from the template per `CONVENTIONS.md` §4.4.
4. Compares structure: heading sequence, table headers, list-marker style per section, placeholder replacement, and absence of leaked `> [template]` lines in the artifact.
5. Logs one line per invocation to `.claude-wyvrn-local/.metrics/template-verifier-findings.log`. Compliant runs are logged as `findings=0`; non-compliant runs as `findings=N | kinds=...`. The log feeds the deferred decision in the implementation roadmap on whether to skip the check entirely for low-impact artifact types.
6. Exit code:
   - `0` — compliant, or path skipped. No output.
   - `2` — findings present. Findings are written to stderr; Claude Code surfaces stderr back to the model.

## Bootstrap exemption

The hook detects the bootstrap state described in `HARNESS.md` §3.5: when an artifact is byte-equal to its unfilled template, the hook treats it as compliant and logs the run with `note=bootstrap`. This avoids spurious findings on freshly installed `ARCHITECTURE.md` or `PROJECT.md`.

## Overriding the harness root

If the harness lives somewhere other than `~/.claude-wyvrn/`, set `WYVRN_HARNESS` in the environment before the hook runs (e.g., for development against a worktree copy). The script also resolves its own location via `__file__` and uses that as a fallback, so a custom install layout normally works without configuration.

## Manual invocation

You can run the script directly for diagnostic purposes:

```bash
echo '{"tool_name":"Write","cwd":"<project>","tool_input":{"file_path":"<path>"}}' \
  | python ~/.claude-wyvrn/hooks/template_verifier.py
```

Exit code and stderr behave the same as in-flow.

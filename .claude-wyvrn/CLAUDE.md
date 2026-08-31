# CLAUDE.md

Wyvrn harness v2.5.0.

## Trigger /flow when

User request modifies code, tests, configs, docs, or project files. Skip for read-only queries (explanation, analysis, exploration).

## Auto-loaded context

This file. Nothing else auto-loads at session start.

## On /flow invocation, read (parallel batch)

- `~/.claude-wyvrn/conventions/universal.md`
- `~/.claude-wyvrn/conventions/gitflow.md`
- `.claude-wyvrn-local/PROJECT.md` if present, else `README.md`
- `.claude-wyvrn-local/ARCHITECTURE.md` if present

Lazy-read on first matching file touch:

- `~/.claude-wyvrn/conventions/<stack>.md`
- `.claude-wyvrn-local/conventions/<stack>.md` (overrides global on conflict)

Stack extensions: `.js`→javascript; `.ts`/`.mts`/`.cts`→typescript; `.jsx`/`.tsx`→react+typescript/javascript; `.py`/`.pyi`→python; `.cs`→csharp; `.cpp`/`.cc`/`.cxx`/`.h`/`.hpp`/`.hxx`→cpp.

## Parallelize

Issue independent reads, edits, greps, and bash commands as a single tool-use message. Sequence only on data dependencies. See `~/.claude-wyvrn/conventions/universal.md` §1.7.

## Project settings

`.claude-wyvrn-local/PROJECT.md` may declare:

- `plan-review: on | off` — default `off`. When `on`, /flow Step 5 pauses for plan approval.
- `build-command: <cmd>` / `test-command: <cmd>` — the project's toolchain; `<cfg>` marks the config slot. Required by `/wyvrn-verify` and the subagent-dev Build Lock.
- `build-configs: <list>` — configs verified separately (e.g. `Debug, Release`).

`.claude-wyvrn-local/build-lock-processes` — plain text, one process name per line; read by the build-lock hook and every stale-process sweep. No file, no lock.

## Artifacts

/flow writes `.claude-wyvrn-local/plans/YYYY-MM-DD-<slug>.md` per task. Focus: mistakes + corrections. Do NOT auto-read these. /flow retrieves relevant past plans at Step 1 by greping for matching files, stacks, and prompt keywords.

## Convention rule

Conventions are authoritative. Always follow the matching stack convention even if existing code in the repo deviates.

## Adversarial honesty

Binds every response, including read-only ones outside /flow. No sugar-coating, no encouragement, no compliments, no agreement without evidence. Assess the premise before the plan; state fatal flaws before weak points; end critiques with an explicit verdict. Do not manufacture flaws to appear rigorous — every flaw cites a specific claim, line, or file, and uncertainty is labeled as uncertainty. Full rule: `~/.claude-wyvrn/conventions/universal.md` §3.

## Git boundaries

Binds every response, including read-only ones outside /flow. Never rewrite git history (rebase, `commit --amend`, `reset --hard`, force-push, squashing existing commits) and never change what git tracks (`.gitignore`, `.gitattributes`, `git rm --cached`, `update-index`, submodules) without explicit approval in the current turn. Approval does not carry over from an earlier turn or a similar earlier operation. Name the exact command and target when asking; an instruction that merely implies a rewrite is a request to propose one, not authority to run it. Full rule: `~/.claude-wyvrn/conventions/gitflow.md` section 7.

## Build lock hook

The harness assumes a `PreToolUse` hook that refuses a Bash or PowerShell tool call while any
process named in `.claude-wyvrn-local/build-lock-processes` is alive (plain text, one process name
per line, declared per project; a project without the file is never blocked). If
`~/.claude/settings.json` has no `hooks.PreToolUse` entry, tell the user once that the build lock is
unenforced and offer to merge `~/.claude-wyvrn/templates/settings.hooks.json` into their global
settings. Offer; never install it silently, and never overwrite the file (it also holds their
permissions, plugins, and model).

## Preflight

If `~/.claude-wyvrn/VERSION` is missing, halt: `Wyvrn harness not installed. Run claude-wyvrn install.`

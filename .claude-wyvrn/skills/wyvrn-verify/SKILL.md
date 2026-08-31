---
name: wyvrn-verify
description: Crash-safe full-suite verification run. Confirms the working directory, sweeps this project's stale build/test processes named in .claude-wyvrn-local/build-lock-processes, builds every declared config as separate sequential invocations, runs the test suite serially with exact pass/fail counts, and states explicitly whether anything is still running at report time. Use when the user asks to verify, run the full suite, build and test, or invokes /wyvrn-verify. Never runs builds or tests concurrently -- parallel runs have hard-crashed development machines.
---

# wyvrn-verify

Runs the build and test suite without crashing the machine.

Concurrent build/test invocations have hard-crashed development machines more than once. Every
rule below exists because of that, and none of them are style preferences. They override any
convenience flag the tooling offers, including combined-config flags like `--all-configs`.

The project declares its toolchain in `.claude-wyvrn-local/PROJECT.md`:

- `build-command: <cmd>` -- one build invocation; `<cfg>` marks where the config name goes.
- `test-command: <cmd>` -- one test invocation; `<cfg>` likewise.
- `build-configs: <list>` -- the configs to verify (e.g. `Debug, Release`). A project without a
  config axis declares one.

and the process names the sweep guards in `.claude-wyvrn-local/build-lock-processes` (plain
text, one name per line). If any declaration is missing, halt and ask the user to add it -- do
not guess the toolchain.

This skill produces the *evidence*. `verify-done` decides whether that evidence actually covers
the acceptance criteria. Run this first, then that.

## Execution principles

- **One invocation in flight at a time. Always.**
- **Sequential, never parallel.** Not across configs, not across targets, not across subagents.
- **Confirm the ground before running.** Wrong CWD and orphaned processes are the two states
  that turn a normal run into a crash or a false result.
- **Report exact numbers, quoted from output.** "Tests pass" is not a result.

## Preconditions

- `.claude-wyvrn-local/PROJECT.md` declaring `build-command`, `test-command`, `build-configs`.
- `.claude-wyvrn-local/build-lock-processes` naming the processes to sweep.
- No build or test currently running -- including one started by a subagent or an earlier
  background task in this session. Verify this rather than assuming it.

## Rules

1. **One test run, one build, at a time.** No concurrent test invocations, no concurrent
   builds. **This binds across subagents** -- dispatching two agents that each run a suite is
   the same violation as running two suites yourself. Never fan out build or test work in
   parallel, however independent the targets look.
2. **Combined-config flags are prohibited** (e.g. `--all-configs`, a comma-separated config
   list), for build and for test. They fan out internally. Issue one config per invocation and
   wait for each to exit before starting the next.
3. **Each declared config is a separate invocation.** Never combine configs in one command.
4. **Sweep stale processes before the first invocation**, not after a failure.
5. **Confirm the working directory before every build or test command.** Shell state does not
   persist between tool calls -- print it, do not assume it. Use absolute paths for build dirs,
   presets, and artifacts.
6. **Never run a build or test in the background** for this skill. A backgrounded build is an
   invocation you have lost track of, which is exactly the state rule 1 forbids.
7. **Report what is still running.** If anything is live at report time -- a background task, a
   subagent, an orphan you could not kill -- say so explicitly and mark the result provisional.

## Steps

1. **Read the declarations.** `build-command`, `test-command`, and `build-configs` from
   `.claude-wyvrn-local/PROJECT.md`; the process list from
   `.claude-wyvrn-local/build-lock-processes`. Halt if any is missing -- do not guess.

2. **Confirm CWD.** `cd` to the repo root and print it. Verify it is the repo root before
   continuing. If it is not what you expected, stop and say so -- do not "fix" it silently.

   ```powershell
   Set-Location C:\path\to\repo; Get-Location
   ```

3. **Sweep stale processes.** Kill orphans left by prior runs before starting:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File "$HOME/.claude-wyvrn/templates/build-lock.ps1" -Sweep
   ```

   The sweep is scoped to this project: it kills only processes this session started or whose
   command line carries this repository's path, and it prints both what it killed and what it left
   alone. Report both. A non-empty sweep is a signal: a previous run did not exit cleanly, and its
   results should not be trusted. Processes reported as left alone belong to other repositories --
   do not chase them, and never widen the sweep to cover them.

   If the build-lock hook refuses this command (BLOCKED), one of *this project's* listed processes
   is live and the sweep cannot run in-session -- the hook blocks every Bash and PowerShell call,
   this one included. Another repository's build will not cause this. Stop and ask the user to run
   the same command from a terminal outside Claude Code, adding `-ProjectDir <repo root>`, then
   retry this step.

4. **Build each declared config, one invocation per config, strictly sequential.** Run
   `build-command` with the first config, wait for it to exit, capture the exit code; then the
   next config. Never a combined-config flag, never two builds at once.

5. **Run the suite serially, one config per invocation** -- `test-command` once per declared
   config, each waiting for the previous to exit. No parallel-execution flag. A green
   single-config run is not a green suite: run every declared config, strictly one after the
   other.

6. **Report.** Use the format below. Quote the counts from the runner's own output; do not
   summarize them from memory.

7. **Stop on the first build failure.** A failing build makes the remaining builds and every
   test run meaningless. Report the failure with the compiler or tool diagnostic quoted
   verbatim and stop. Do not continue to gather more red.

## Output format

```
CWD:            <absolute path, confirmed>
Stale swept:    <none | list of killed PIDs and names>

Build <cfg>:    <pass | FAIL>  (exit <n>)                          -- one line per declared config
Test <cfg>:     <N> passed, <M> failed, <K> skipped  (exit <n>)    -- one line per declared config

Failures:
- <suite.case> -- <shortest decisive line from the output>

Still running:  <nothing | what, and why it could not be stopped>
```

- Every `<n>` is the actual observed exit code. An unobserved exit code is reported as unknown,
  not assumed to be zero.
- **Still running** is never omitted. "nothing" is the normal answer and it is stated explicitly,
  because its absence is indistinguishable from forgetting to check.

## Prohibitions

- Never run two builds or two test invocations concurrently, including across subagents.
- Never use a combined-config flag (`--all-configs`, a comma-separated config list).
- Never pass the test runner a parallel-execution flag in a full-suite run.
- Never start a full suite without sweeping stale processes first.
- Never issue a build or test command without confirming the working directory.
- Never guess the toolchain when the declarations are missing -- halt and ask.
- Never run the build or suite as a background task under this skill.
- Never report a pass without the config named and the exit code quoted.
- Never claim the suite is green when a run is still in flight.
- Do not modify `~/.claude-wyvrn/`.

## Integration

- `.claude-wyvrn-local/PROJECT.md` -- `build-command`, `test-command`, `build-configs`.
- `.claude-wyvrn-local/build-lock-processes` -- the sweep list, shared with the build-lock hook
  (`~/.claude-wyvrn/templates/settings.hooks.json`). The hook and the sweep are the same script
  (`~/.claude-wyvrn/templates/build-lock.ps1`), and both are scoped to this project: another
  repository's `cmake` or `ctest` neither blocks this session nor gets swept by it.
- Stack conventions (e.g. `cpp.md` *Testing*) may add stack-specific test style rules; this
  skill is the stack-agnostic runner, and its serial-execution rules override any convenience
  flag a stack file suggests (e.g. a `--parallel` runner default).
- `verify-done` -- the evidence gate. This skill supplies observed output; `verify-done` maps it
  to acceptance criteria. Neither replaces the other.
- `/flow` Step 8 -- self-verify. Use this skill for the mechanics of that step.
- `dispatching-parallel-agents` -- explicitly does **not** apply to build or test work. Rule 1
  overrides it.

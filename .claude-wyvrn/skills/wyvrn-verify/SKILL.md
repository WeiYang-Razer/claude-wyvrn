---
name: wyvrn-verify
description: Crash-safe full-suite verification run. Confirms the working directory, sweeps stale hostharness/ctest/cmake processes, builds Debug and Release as separate sequential invocations, runs the test suite serially with exact pass/fail counts, and states explicitly whether anything is still running at report time. Use when the user asks to verify, run the full suite, build and test, or invokes /wyvrn-verify. Never runs builds or tests concurrently -- parallel runs have hard-crashed this machine.
---

# wyvrn-verify

Runs the build and test suite without crashing the machine.

Concurrent `ctest` / build invocations have hard-crashed this development machine more than
once. Every rule below exists because of that, and none of them are style preferences. They
override any convenience flag the tooling offers, including `--all-configs`.

This skill produces the *evidence*. `verify-done` decides whether that evidence actually covers
the acceptance criteria. Run this first, then that.

## Execution principles

- **One invocation in flight at a time. Always.**
- **Sequential, never parallel.** Not across configs, not across targets, not across subagents.
- **Confirm the ground before running.** Wrong CWD and orphaned processes are the two states
  that turn a normal run into a crash or a false result.
- **Report exact numbers, quoted from output.** "Tests pass" is not a result.

## Preconditions

- A repo with a `wyvrn.json` (or the project's equivalent build entry point).
- No build or test currently running -- including one started by a subagent or an earlier
  background task in this session. Verify this rather than assuming it.

## Rules

1. **One ctest, one build, at a time.** No concurrent `ctest`, no concurrent `wyvrnpm test`,
   no concurrent build. **This binds across subagents** -- dispatching two agents that each run
   a suite is the same violation as running two suites yourself. Never fan out build or test
   work in parallel, however independent the targets look.
2. **`--all-configs` is prohibited**, for build and for test. It fans out internally. Issue one
   `--config <cfg>` per invocation and wait for each to exit before starting the next.
3. **Debug and Release are separate invocations.** Never combine configs in one command.
4. **Sweep stale processes before the first invocation**, not after a failure.
5. **Confirm the working directory before every build or test command.** Shell state does not
   persist between tool calls -- print it, do not assume it. Use absolute paths for build dirs,
   presets, and artifacts.
6. **Never run a build or test in the background** for this skill. A backgrounded build is an
   invocation you have lost track of, which is exactly the state rule 1 forbids.
7. **Report what is still running.** If anything is live at report time -- a background task, a
   subagent, an orphan you could not kill -- say so explicitly and mark the result provisional.

## Steps

1. **Confirm CWD.** `cd` to the repo root and print it. Verify it is the repo root before
   continuing. If it is not what you expected, stop and say so -- do not "fix" it silently.

   ```powershell
   Set-Location C:\path\to\repo; Get-Location
   ```

2. **Sweep stale processes.** Kill orphans left by prior runs before starting:

   ```powershell
   Get-Process hostharness,ctest,cmake -ErrorAction SilentlyContinue | Stop-Process -Force
   ```

   Report what was killed. A non-empty sweep is a signal: a previous run did not exit cleanly,
   and its results should not be trusted.

3. **Build Debug.** Wait for it to exit. Capture the exit code.

   ```
   wyvrnpm build --config Debug
   ```

4. **Build Release, separately.** Only after step 3 has exited.

   ```
   wyvrnpm build --config Release
   ```

   Never `--all-configs`. Never `--config Debug,Release`.

5. **Run the suite serially, one config per invocation**, each waiting for the previous to exit:

   ```
   wyvrnpm test --config Debug
   wyvrnpm test --config Release
   ```

   No `--parallel`. No `--all-configs`. A green single-config run is not a green suite, so run
   both -- but strictly one after the other.

6. **Report.** Use the format below. Quote the counts from the runner's own output; do not
   summarize them from memory.

7. **Stop on the first build failure.** A failing Debug build makes the Release build and both
   test runs meaningless. Report the failure with the compiler diagnostic quoted verbatim and
   stop. Do not continue to gather more red.

## Output format

```
CWD:            <absolute path, confirmed>
Stale swept:    <none | list of killed PIDs and names>

Build Debug:    <pass | FAIL>  (exit <n>)
Build Release:  <pass | FAIL>  (exit <n>)

Test Debug:     <N> passed, <M> failed, <K> skipped  (exit <n>)
Test Release:   <N> passed, <M> failed, <K> skipped  (exit <n>)

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
- Never use `--all-configs` or a comma-separated `--config` list.
- Never use `ctest --parallel` in a full-suite run.
- Never start a full suite without sweeping stale processes first.
- Never issue a build or test command without confirming the working directory.
- Never run the build or suite as a background task under this skill.
- Never report a pass without the config named and the exit code quoted.
- Never claim the suite is green when a run is still in flight.
- Do not modify `~/.claude-wyvrn/`.

## Integration

- `~/.claude-wyvrn/conventions/cpp.md`, *Test and build execution* -- the authoritative source of
  these rules. This skill is their runnable form.
- `verify-done` -- the evidence gate. This skill supplies observed output; `verify-done` maps it
  to acceptance criteria. Neither replaces the other.
- `/flow` Step 8 -- self-verify. Use this skill for the mechanics of that step in C++ projects.
- `dispatching-parallel-agents` -- explicitly does **not** apply to build or test work. Rule 1
  overrides it.

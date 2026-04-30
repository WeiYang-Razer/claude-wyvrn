# template-check

Runs the template-verifier hook on a specific artifact, on demand.

## Trigger

Slash command: `/template-check <artifact-path>`

Natural language: "check template compliance on X" or equivalent.

In normal flow operation the template-verifier hook runs automatically on every artifact write per `HARNESS.md` §4.6 — this skill is for ad-hoc invocation outside of a flow (e.g., re-checking an existing artifact after the templates change).

## Description

Synthesizes a `PostToolUse`-shaped JSON payload for the supplied artifact path and pipes it to `~/.claude-wyvrn/hooks/template_verifier.py`. Reports the script's exit code and any findings on stderr.

## Inputs

- Artifact path. Required. Must point at an existing `.md` file under `.claude-wyvrn-local/`.

## Behavior

1. Resolve the artifact path to an absolute path.
2. Compose a JSON payload of the form:

   ```json
   {
     "tool_name": "Write",
     "cwd": "<project root>",
     "tool_input": {"file_path": "<absolute artifact path>"}
   }
   ```

3. Invoke the hook script with the JSON on stdin:

   ```bash
   echo '<payload>' | python ~/.claude-wyvrn/hooks/template_verifier.py
   ```

4. Read the script's exit code and stderr.
5. Surface findings to the caller. If exit code is `0`, the artifact is compliant. If exit code is `2`, the stderr text contains the findings list.

The script appends one line per invocation to `.claude-wyvrn-local/.metrics/template-verifier-findings.log` regardless of outcome — manual checks are recorded alongside in-flow checks.

## Outputs

- Return value: `compliant` or a findings list.
- Side effect: one log line appended to `.claude-wyvrn-local/.metrics/template-verifier-findings.log`.

## Invokes

- template-verifier hook script (`hooks/template_verifier.py`).

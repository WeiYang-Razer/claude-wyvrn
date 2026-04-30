# run-verifier

Invokes the `verifier` agent for one verification cycle.

## Trigger

Slash command: `/run-verifier`

Natural language: "run the verifier" or equivalent.

Usually invoked by flow skills at end of Work. Devs may invoke directly to re-verify a closed flow's artifacts, for example after verifier rules have been updated.

## Description

Calls the `verifier` agent in a fresh context with the specified flow state. Returns the verification outcome: Success or Findings.

## Inputs

- Flow ID.
- Flow type.
- Cycle number (1 for first verification, incrementing on re-verification).

## Behavior

1. Invoke `verifier` subagent in a fresh context with the inputs.
2. `verifier` reads spec, clarification batch, produced artifacts, code diff, tests.
3. `verifier` runs its six checks in sequence: AC verification, template compliance (confirms the template-verifier hook ran clean per `HARNESS.md` §4.6, by reading the per-artifact log at `.claude-wyvrn-local/.metrics/template-verifier-findings.log`), test suite, code review (via `code-reviewer`), project alignment (inline reuse + pattern-drift scan), out-of-scope findings collection.
4. `verifier` writes the verifier report.
5. `verifier` returns outcome:
    - `Success` — all blocking checks pass.
    - `Findings` — at least one blocking finding. Report lists them.
6. Return the outcome to the invoking skill.

## Outputs

- Return value: `Success` or `Findings`.
- Side effect: verifier report at `.claude-wyvrn-local/reviews/[flow-id]-review.md` (cycle number included in the report).

## Invokes

- `verifier` (subagent).
- `code-reviewer` (subagent, via verifier).
- template-verifier hook (`hooks/template_verifier.py`, fires automatically on every artifact write per `HARNESS.md` §4.6; the verifier reads the run log at `.claude-wyvrn-local/.metrics/template-verifier-findings.log`).

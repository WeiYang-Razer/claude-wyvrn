# run-clarifier

Invokes the `clarifier` agent for one round of clarification.

## Trigger

Slash command: `/run-clarifier`

Natural language: "run the clarifier" or equivalent.

Usually invoked by flow skills. Devs may invoke directly to re-run clarification on an existing spec after rules or sources have changed.

## Description

Calls the `clarifier` agent in a fresh context with the specified flow state. Returns the result of one clarification round: either "complete" (no open questions) or the list of batch entries needing human input.

## Inputs

- Flow ID.
- Flow type (`feature`, `fix`, or `refactor`).
- Initial prompt (for round 1) or reference to clarification batch path (for subsequent rounds).
- Spec artifact path.
- Clarification batch path (may not yet exist on round 1).

## Behavior

1. Invoke `clarifier` subagent in a fresh context with the inputs.
2. `clarifier` reads its required sources, drafts or updates the spec, drafts or updates the batch.
3. `clarifier` returns:
    - `complete` — no open questions. Proceed to next flow phase.
    - `batch: <N> questions` — questions need human answers.
4. Return the result to the invoking skill.

The invoking skill handles session prompting for batch questions by invoking `AskUserQuestion` per `HARNESS.md` §8. `run-clarifier` does not communicate with the human.

## Outputs

- Return value: `complete` or `batch: <N> questions` with question references.
- Side effect: spec artifact and clarification batch artifact created or updated by `clarifier`.

## Invokes

- `clarifier` (subagent).
- template-verifier hook (`hooks/template_verifier.py`, fires automatically on the clarifier's artifact writes).

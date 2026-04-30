# decision-log

Creates a decision record.

## Trigger

Slash command: `/decision-log`

Natural language: "log a decision" or equivalent.

Invoked by agents when classifying a decision as INFERRED or when recording a HUMAN_OVERRIDE per `DECISIONS.md` §6.2.

## Description

Writes a decision record using the decision template. Assigns the next DEC-NNNN ID. The template-verifier hook (`hooks/template_verifier.py` per `HARNESS.md` §4.6) runs automatically on the write.

## Inputs

- Flow ID (the flow in which the decision was made).
- Classification (`INFERRED` or `HUMAN_OVERRIDE`).
- Title (short description).
- Context, decision, rationale, sources cited, scope, consequences — the decision template fields.

## Behavior

1. Scan `.claude-wyvrn-local/decisions/` for highest existing `DEC-NNNN`. Increment by 1.
2. Generate slug from title.
3. Load template at `~/.claude-wyvrn/templates/decision.md`.
4. Fill template fields with provided inputs. Use `<pending>` for fields not yet determinable.
5. Write to `.claude-wyvrn-local/decisions/DEC-NNNN-[slug].md`. The template-verifier hook runs automatically on the write per `HARNESS.md` §4.6.
6. If the hook reports findings via stderr, correct the artifact and re-write until the hook is silent.
7. Return the decision record path.

## Outputs

- Return value: path to the new decision record.
- Side effect: decision record artifact created.

## Invokes

- template-verifier hook (`hooks/template_verifier.py`, fires automatically on the artifact write).

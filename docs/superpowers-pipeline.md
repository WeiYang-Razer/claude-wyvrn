# Wyvrn superpowers harness — pipeline

End-to-end flow from a user request to a verified, reversible commit trail. Design gates
(`/brainstorm`, `/write-plan` Self-Review, `/verify-done`) bound each stage; artifacts
(`specs/`, `plans/`) persist the hand-off between stages.

```mermaid
flowchart TD
    U([User request]) --> Q{Scope clear &<br/>design settled?}

    Q -->|Complex / uncertain| BS["/brainstorm<br/>design gate"]
    Q -->|Clear enough| WP["/write-plan"]

    BS -->|approved| SPEC[("specs/<br/>YYYY-MM-DD-slug-design.md")]
    SPEC -->|authoritative input| WP

    subgraph WPP["/write-plan — internal pipeline"]
        direction TB
        L[Load context<br/>PROJECT · ARCHITECTURE · past plans] --> D[Draft header + tasks<br/>checkbox steps · red-green TDD · per-task commit]
        D --> G{Self-Review gate<br/>spec-coverage · placeholder-scan<br/>type-consistency · ordering}
        G -->|fail| D
        G -->|pass| R{Plan review}
        R -->|refine| D
        R -->|approve| W[Write plan file]
    end

    WP --> L
    W --> PLAN[("plans/<br/>YYYY-MM-DD-slug-plan.md")]

    PLAN --> EXEC{Execute how?}
    EXEC -->|orchestrated| SAD["/subagent-dev<br/>subagents build · main verifies"]
    EXEC -->|inline| FLOW["/flow<br/>inline task runner"]

    SAD --> IMPL[Implement task-by-task<br/>commit after each task]
    FLOW --> IMPL

    IMPL --> VD{"/verify-done<br/>evidence gate"}
    VD -->|gaps| IMPL
    VD -->|every AC proven| DONE([Done · reversible commit trail])

    FLOW -.writes.-> PLAN

    %% supporting skills feed the implement stage
    TDD["/tdd"] -.-> IMPL
    DBG["/debug"] -.-> IMPL
    WT["/worktree"] -.-> IMPL
    PA["/parallel-agents"] -.-> SAD

    classDef skill fill:#dbeafe,stroke:#2563eb,color:#1e3a8a;
    classDef gate fill:#fef9c3,stroke:#ca8a04,color:#713f12;
    classDef artifact fill:#dcfce7,stroke:#16a34a,color:#14532d;
    classDef terminal fill:#f3e8ff,stroke:#9333ea,color:#581c87;

    class BS,WP,SAD,FLOW,TDD,DBG,WT,PA skill;
    class Q,G,R,EXEC,VD gate;
    class SPEC,PLAN artifact;
    class U,DONE terminal;
```

## Legend

| Shape / color | Meaning |
|---|---|
| 🟦 Blue box | A skill you invoke (`/brainstorm`, `/write-plan`, `/subagent-dev`, `/flow`, `/tdd`, `/debug`, `/worktree`, `/parallel-agents`) |
| 🟨 Yellow diamond | A decision or **gate** — work cannot pass until the condition holds |
| 🟩 Green cylinder | A persisted **artifact** under `.claude-wyvrn-local/` (the hand-off between stages) |
| 🟪 Purple stadium | Entry / exit |
| Dotted arrow | Optional / supporting feed (e.g. `/flow` writes a learning log back to `plans/`) |

## Notes

- **Brainstorm is optional.** Clear, settled requests skip straight to `/write-plan`; `/write-plan` is standalone and does not require a spec.
- **Three gates enforce quality:** the `/brainstorm` spec approval, the `/write-plan` Self-Review (4 checks, run *before* you see the plan), and `/verify-done` (maps every acceptance criterion to observed proof).
- **Reversibility** comes from the plan's per-task commit discipline — each task ends in a self-contained `git commit`, so the trail is checkpointed at task granularity.
- **Executor handoff:** every generated plan opens with a `REQUIRED SUB-SKILL` line pointing the implementer at `/subagent-dev` or `/flow`.

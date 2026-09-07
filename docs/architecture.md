# Workflow architecture

## Goal

Keep task-completion quality high while reducing quota waste. The workflow saves quota through role routing, compact handoffs, deterministic validation, and explicit escalation—not by skipping necessary reasoning or testing.

## Two entry lanes, one execution state machine

```text
Lane A: Local-first
User task
   |
   v
Codex dev-orchestrator
   |
   +--> classify --> evidence --> plan --> implement --> verify --> review/escalate

Lane B: GitHub-first
Push project to GitHub
   |
   v
ChatGPT/web analyzes exact ref/commit
   |
   v
Execution Packet v1
   |
   v
Codex dev-orchestrator
   |
   +--> drift check --> classify/confirm --> implement --> verify --> review/escalate
```

The GitHub-first lane must not create a second independent workflow. Its only purpose is to produce a high-signal planning artifact that the same local orchestrator can consume.

## Role/model separation

Workflow logic refers only to roles. Model names live only in `.codex/agents/*.toml`.

| Role | Default model | Purpose |
| --- | --- | --- |
| primary | GPT-5.6 Terra / medium | default routing and ordinary local work |
| explorer | GPT-5.6 Luna / low | repository search and evidence gathering |
| worker | GPT-5.6 Terra / medium | implementation |
| planner | GPT-5.6 Sol / medium | ambiguous/cross-module planning |
| reviewer | GPT-5.6 Sol / medium | non-trivial review and debugging escalation |
| expert | GPT-6 Astra / medium | narrow, critical escalation only |

If model availability or quota economics change, update the TOML files; the workflow and Execution Packet schema should remain unchanged.

## Risk classes

### R0 trivial
Narrow, mechanical, low-risk, easily verified. Primary agent handles directly.

### R1 standard
Ordinary feature/fix/refactor with limited blast radius. Explorer only if needed, then worker and deterministic validation. Reviewer is conditional.

### R2 complex
Cross-module, ambiguous, externally visible, difficult to validate, data-model/performance/public-interface work. Explorer -> planner -> worker -> deterministic validation -> reviewer.

### R3 critical
Security/auth, payments, destructive migrations, concurrency/distributed consistency, irreversible data operations, major compatibility risk, or genuinely unresolved root cause. Gather evidence -> planner -> narrow expert consultation -> worker -> deterministic validation -> reviewer.

## Quality gates

Cost reduction must not remove these gates when relevant:

1. **Source-of-truth gate** — confirm current branch/HEAD and repository instructions.
2. **Evidence gate** — important assumptions are tied to files/symbols/tests.
3. **Plan gate** — required for R2/R3; plan is minimal and testable.
4. **Implementation gate** — smallest defensible diff; no unrelated redesign.
5. **Deterministic validation gate** — tests/build/type/lint/runtime checks before model-based review.
6. **Review gate** — proportional to risk; mandatory for R2/R3.
7. **Escalation gate** — Astra only for critical or unresolved decisions, not routine execution.
8. **Stop gate** — once acceptance criteria pass and required review is clean, stop spending quota.

## Why GitHub-first can save quota

The web planning stage can inspect the pushed repository and produce a compact Execution Packet with exact evidence, constraints, and validation criteria. Local Codex then validates only critical assumptions instead of re-reading the whole repository.

The packet should include a commit SHA whenever possible. This solves the main failure mode of copy/paste planning: a plan silently becoming stale after new commits.

## Handoff compression

Each escalation should shrink context:

```text
repository/files
    -> Evidence Packet
    -> Implementation Packet / Execution Packet
    -> Debug or Decision Packet
    -> expert
```

Higher-cost roles should receive less raw context and more distilled evidence.

## When not to use GitHub-first

Skip the web-planning lane when:
- the change is R0/R1 and locally obvious;
- the task can be verified mechanically in a few steps;
- the repository has unpushed local state that materially changes the task;
- copying a plan would cost more attention than simply letting Codex execute locally.

Use GitHub-first when:
- architecture/roadmap decisions need a second perspective;
- the change is R2/R3;
- you want a planning checkpoint before implementation;
- you want to review the plan independently before spending local Codex quota.

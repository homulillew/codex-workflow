# Workflow architecture

## Goal

Keep task-completion quality high while reducing quota waste. The workflow saves quota through role routing, compact handoffs, deterministic validation, and explicit escalation—not by skipping necessary reasoning or testing.

The central design rule is:

> **Risk/consequence controls safeguards. Reasoning complexity controls model strength.**

These are independent dimensions. A high-consequence task can be technically straightforward; a low-risk task can contain a frontier-level algorithmic problem.

## Two entry lanes, one execution state machine

```text
Lane A: Local-first
User task
   |
   v
Codex dev-orchestrator
   |
   +--> classify risk + complexity
   +--> evidence
   +--> plan / expert reasoning when needed
   +--> implement
   +--> verify
   +--> review proportional to risk

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
   +--> drift check
   +--> confirm risk + complexity
   +--> same execution state machine
```

The GitHub-first lane must not create a second independent workflow. Its purpose is to produce a high-signal planning artifact that the same local orchestrator can consume.

## Role/model separation

Workflow logic refers only to roles. Model names live in `.codex/agents/*.toml`.

| Role | Default model | Purpose |
| --- | --- | --- |
| primary | GPT-5.6 Terra / medium | default routing and ordinary local work |
| explorer | GPT-5.6 Luna / low | repository search and evidence gathering |
| worker | GPT-5.6 Terra / medium | bounded implementation |
| planner | GPT-5.6 Sol / medium | complex but conventional planning and trade-off structuring |
| reviewer | GPT-5.6 Sol / medium | non-trivial review, diagnosis, and validation gaps |
| expert | GPT-6 Astra / medium | the hardest C3 reasoning bottlenecks: novel design, difficult diagnosis, methodology, deep synthesis |

The `expert` role is **not** a generic high-risk approver and is not a prestige reviewer. Its purpose is to resolve the hardest conceptual problem after cheaper roles compress the evidence.

## Two-dimensional classification

### Consequence / risk classes

Risk answers: **How bad is it if we are wrong?**

#### R0 — low consequence
Narrow, reversible, easily verified, little blast radius.

#### R1 — ordinary consequence
Normal feature/fix/refactor with bounded impact and routine rollback.

#### R2 — high impact
Broad blast radius, public interfaces, data-model/performance changes, meaningful compatibility or operational consequences.

#### R3 — critical consequence
Security/auth, payments, destructive/irreversible data operations, severe privacy/compliance exposure, production-critical migrations, or similarly high-cost failures.

Risk changes validation/review requirements. It does **not** select GPT-6 by itself.

### Reasoning-complexity classes

Complexity answers: **How difficult is the technical reasoning itself?**

#### C0 — mechanical
Obvious deterministic changes.

#### C1 — standard
Known implementation patterns and ordinary debugging.

#### C2 — complex
Cross-module planning, substantial trade-offs, difficult but conventional diagnosis, or senior-level architecture work.

#### C3 — expert / frontier
Novel algorithm/objective/protocol/architecture design, difficult root-cause analysis with competing hypotheses, methodology-critical choices, or deep cross-domain synthesis where ordinary patterns do not determine the answer.

C3 is the normal trigger for `expert`.

## Routing matrix

Think of routing as two orthogonal axes:

| | C0/C1 | C2 | C3 |
| --- | --- | --- | --- |
| R0/R1 | primary/worker | planner + worker | evidence -> planner -> expert -> worker |
| R2/R3 | same model path, but stronger safeguards/review | planner + mandatory review | expert reasoning + mandatory risk-specific review |

Examples:

- **R3/C1:** straightforward auth change using an established repository pattern. Use worker + strict tests + reviewer. Do not call GPT-6 merely because auth is high consequence.
- **R1/C3:** novel optimization/reward/algorithm design in an internal experiment. Use GPT-6 for the hard reasoning even though operational risk is low.
- **R3/C3:** novel high-consequence consistency/security algorithm. Use GPT-6 for the conceptual bottleneck and R3 safeguards for implementation/release.

## Expert role

`expert` should receive a compact packet, not a repository dump.

Preferred triggers:
- novel algorithm/objective/protocol/architecture design;
- multiple plausible technical hypotheses remain after targeted evidence gathering;
- a deep trade-off spans algorithm, systems, data, and evaluation;
- a methodology-critical decision will determine whether downstream work is valid;
- an unresolved C2 problem has become C3 after reviewer diagnosis.

It can be invoked before implementation when C3 is obvious. Do not require an artificial sequence of failed worker attempts first.

Do **not** use expert for:
- repo-wide discovery;
- routine implementation;
- mechanical review;
- basic security/compliance checking when the reasoning is straightforward;
- summarizing logs or reports that cheaper roles can process.

Preferred handoff shape:

```text
raw repository / experiment
    -> Evidence Packet
    -> Planner structures options/hypotheses
    -> Decision / Research Debug Packet
    -> expert
    -> bounded implementation or discriminating experiment
```

The strongest model should receive the hardest distilled question, not the largest context.

## Quality gates

Cost reduction must not remove these gates when relevant:

1. **Source-of-truth gate** — confirm current branch/HEAD and repository instructions.
2. **Evidence gate** — important assumptions are tied to files/symbols/tests/experiment artifacts.
3. **Classification gate** — assign risk and reasoning complexity independently.
4. **Plan gate** — required when complexity or risk makes an explicit plan valuable.
5. **Expert gate** — use GPT-6 for C3 reasoning, not merely for R3 consequence.
6. **Implementation gate** — smallest defensible diff; no unrelated redesign.
7. **Deterministic validation gate** — tests/build/type/lint/runtime checks before model-based review.
8. **Review gate** — proportional to risk; R2/R3 normally require reviewer regardless of complexity.
9. **Stop gate** — once acceptance criteria pass and required review is clean, stop spending quota.

## Debugging escalation

A routine unresolved implementation problem gets at most two meaningful worker attempts before a Debug Packet goes to `reviewer`.

If reviewer can resolve the root cause, keep the problem at C2 or below.
If several plausible hypotheses remain and resolving them requires genuinely deeper synthesis, reclassify the bottleneck as C3 and send a compressed packet to `expert`.

A problem that is clearly C3 from the beginning (for example novel algorithm design) does not need to wait for failed implementation attempts.

## Why GitHub-first can save quota

The web planning stage can inspect the pushed repository and produce a compact Execution Packet with exact evidence, constraints, and validation criteria. Local Codex then validates only critical assumptions instead of re-reading the whole repository.

The packet should include a commit SHA whenever possible. This prevents a plan silently becoming stale after new commits.

## When not to use GitHub-first

Skip the web-planning lane when:
- the change is low-complexity and locally obvious;
- the task can be verified mechanically in a few steps;
- the repository has unpushed local state that materially changes the task;
- copying a plan would cost more attention than simply letting Codex execute locally.

Use GitHub-first when:
- architecture/roadmap/research decisions benefit from a second perspective;
- the task is C2/C3 or has broad consequence;
- you want an independent planning checkpoint before implementation;
- you want to review the plan before spending local model/GPU quota.

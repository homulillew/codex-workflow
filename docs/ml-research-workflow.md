# ML Research Workflow Architecture

## Goal

Extend `codex-workflow` from software-development orchestration to evidence-first ML research without duplicating the development workflow.

The two skills form nested loops:

```text
Research question
   |
   v
ml-research-orchestrator
   |  freeze experiment semantics
   v
Experiment Contract
   |
   +--> implementation/config change needed?
   |        |
   |        v
   |   dev-orchestrator
   |        |
   |   deterministic validation
   |        |
   +--------+
   |
   v
L0 -> L1 -> L2 -> L3 -> L4
   |
   v
metrics + samples + logs
   |
   v
training report + bad-case taxonomy
   |
   v
decision
   |
   +--> new falsifiable hypothesis -> new experiment
   |
   +--> claim ledger / interview evidence
```

The central routing rule is the same as in software development:

> **Consequence controls safeguards and evidence requirements. Reasoning complexity controls model strength.**

A medically sensitive or expensive experiment may still be conceptually routine. A harmless offline reward-design experiment may require C3 algorithmic reasoning.

## Boundary between the two orchestrators

### `dev-orchestrator`

Owns:
- repository discovery;
- implementation planning;
- code/config changes;
- tests/build/type/lint/runtime validation;
- implementation debugging/review/escalation.

Its completion gate answers:

> Is the software change correctly implemented?

### `ml-research-orchestrator`

Owns:
- research question and hypothesis;
- baseline/treatment semantics;
- dataset/model/evaluator provenance;
- promotion from cheap to expensive compute;
- training-health analysis;
- bad-case taxonomy;
- experiment decision;
- claim and interview evidence;
- identification of C3 research reasoning bottlenecks.

Its completion gate answers:

> Did the experiment credibly answer the registered research question?

A code-complete change can still be research-incomplete.

## Research source of truth

Chat/Codex conversation history is not the durable research record.
The project repository should contain compact durable artifacts, while large checkpoints/logs may live in external storage referenced by metadata/hashes.

Recommended project shape:

```text
AGENTS.md
.agents/
  skills/
    <project-specific-research-skill>/
experiments/
  registry.yaml
  EXP-001/
    brief.yaml
    config.yaml
    result.json
    samples.jsonl
    reports/
reports/
  claim_evidence.md
  interview/
src/
configs/
tests/
```

The workflow repository remains domain-agnostic. Domain/project invariants belong in the target project's own skill.

## Generic versus project-specific policy

Use this rule:

> If the rule would still make sense for a SQL-RL, VLM-RL, medical-RL, or recommendation-model project, it belongs in `codex-workflow`. If it names the project's model, dataset, action space, reward semantics, safety thresholds, or hardware constraint, it belongs in the project repository.

Examples that belong in `codex-workflow`:
- freeze primary metric before full run;
- smoke before pilot/full;
- generate bad-case taxonomy;
- stop blind retries and create a debug packet;
- link resume claims to exact evidence;
- route C3 reasoning to expert after evidence compression.

Examples that belong in a medical project skill:
- allowed dialogue actions;
- medical dataset semantics;
- risk/escalation definitions;
- model/backbone choice;
- GPU memory constraint;
- project-specific metrics and reward gates.

## Registered experiment state machine

```text
PLANNED
  -> PREFLIGHT_PASSED
  -> SMOKE_PASSED
  -> PILOT_PASSED
  -> FULL_COMPLETE
  -> ANALYZED
  -> DECIDED
  -> AUDITED (claim-bearing only)
```

Failure at any stage may produce:

```text
INVALID       implementation/data/evaluator defect invalidates the test
REJECTED      valid experiment contradicts hypothesis
INCONCLUSIVE  valid but insufficient/confounded evidence
FOLLOW_UP     evidence justifies a new experiment
```

Never reuse an experiment ID to hide a materially changed treatment or hypothesis.

## Reasoning complexity in ML research

### C0 — mechanical
Metadata, deterministic transforms, report generation, obvious experiment plumbing.

### C1 — standard
Known training/evaluation patterns and routine interpretation.

### C2 — complex
Substantial but conventional experiment design, diagnosis, systems trade-offs, or multi-factor analysis that Sol-level planner/reviewer can resolve.

### C3 — expert / frontier
Use when the **research reasoning itself** is genuinely difficult and non-routine, for example:
- novel algorithm/objective/reward/verifier/protocol design;
- defining a methodology-critical latent concept or stopping criterion;
- several evidence-backed root-cause hypotheses remain after targeted diagnosis;
- conflicting metrics make causal interpretation non-obvious;
- the answer requires deep synthesis across data, optimization dynamics, model behavior, systems constraints, and evaluation;
- a conceptual decision will determine whether many downstream experiments are valid.

C3 can trigger GPT-6 before implementation. There is no requirement that Sol or a worker must fail first.

High consequence, medical/safety relevance, expensive compute, or claim importance do not automatically make a task C3. Those properties strengthen review/evidence gates; they do not select the strongest model by themselves.

## Expert research protocol

Before using `expert`, cheaper roles should compress the problem into a Research Decision Packet:

```text
question / decision
objective + constraints
established evidence
candidate methods or hypotheses
evidence for/against
what is already ruled out
downstream consequence of a wrong conceptual choice
exact output needed from expert
```

Good expert tasks:
- choose or design the algorithmic formulation;
- resolve a difficult methodological trade-off;
- identify the most likely root cause among competing hypotheses;
- propose the cheapest discriminating experiment/falsification test;
- determine the defensible interpretation of ambiguous evidence when that interpretation itself is C3.

Bad expert tasks:
- running training;
- parsing logs;
- ordinary bad-case taxonomy;
- routine hyperparameter tuning;
- standard benchmark reporting;
- generic resume/interview summarization.

The expert resolves the hard bottleneck; worker/planner/reviewer still implement, execute, validate, and document.

## Two independent review lanes

### Local Codex lane

Best for:
- implementation;
- deterministic testing;
- training execution;
- log parsing;
- first-pass report generation;
- bounded debugging;
- preparing evidence/decision packets.

### GitHub/Chat audit lane

Best for:
- independent review of exact pushed commit;
- checking hypothesis -> experiment -> evidence -> conclusion closure;
- finding confounders/reward hacking/leakage;
- comparing decision with bad-case/guardrail evidence;
- deciding whether a resume/interview claim is defensible.

The web/Chat lane should not duplicate implementation work. It should consume exact repository evidence and return a compact audit/Execution Packet when a code change is needed.

If either lane identifies a genuine C3 reasoning bottleneck, it should compress the problem before invoking the expert role rather than forwarding raw context.

## Research completion gates

A stage is not research-complete merely because training finished.
A formal stage should normally have:

1. implementation validated;
2. dataset/evaluator/reward checks;
3. registered experiment(s);
4. structured results;
5. training issue analysis;
6. bad-case analysis;
7. decision record;
8. claim evidence update if applicable;
9. interview evidence update for meaningful project milestones.

Expert consultation, when used, is not itself evidence. Its recommendation must be translated into an implementation, falsifiable experiment, deterministic check, or explicitly bounded methodological decision.

## Cost discipline

Compute and model quota are both research resources.

Save them by:
- using deterministic offline tests before GPU runs;
- replaying stored trajectories for reward/evaluator debugging;
- using small smoke/pilot runs to reject broken hypotheses;
- sending summarized evidence rather than raw logs to stronger reviewers;
- using GPT-6 only when stronger reasoning is likely to change the technical decision;
- stopping once the registered question is answered.

Do not save quota by skipping evidence needed to support the eventual claim.

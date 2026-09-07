# Research Debug Packet v1

Use this packet after at most two meaningful attempts at the same unresolved research/training failure. Its purpose is to stop blind retries and give a reviewer a compact, evidence-dense diagnostic handoff.

Recommended path:

```text
experiments/EXP-XXX/reports/research_debug_packet.yaml
```

## Schema

```yaml
research_debug_packet_version: 1
experiment_id: EXP-XXX
source_commit: exact-sha

problem:
  expected: >-
    What should have happened under the current contract.
  actual: >-
    What actually happened.
  impact: >-
    Whether this blocks execution, invalidates the run, or causes a behavioral/metric regression.

first_bad_signal:
  metric_or_event: name
  step_or_time: value
  evidence: path-or-log-slice

symptoms:
  - observation: concise fact
    evidence: path/metric/sample-id

attempts:
  - attempt: 1
    change: exact bounded change
    rationale: why it was tried
    result: what happened
    evidence: path
  - attempt: 2
    change: exact bounded change
    rationale: why it was tried
    result: what happened
    evidence: path

ruled_out:
  - hypothesis: possible cause
    evidence: why it is unlikely

remaining_hypotheses:
  - hypothesis: candidate root cause
    confidence: high|medium|low
    evidence_for:
      - evidence
    evidence_against:
      - evidence
    cheapest_discriminating_test: >-
      A targeted check that would separate this hypothesis from alternatives.

scope:
  affected_runs:
    - run-or-experiment-id
  potentially_invalid_claims:
    - claim-id-or-none

recommended_next_action:
  type: diagnostic|code_fix|data_fix|new_experiment|stop
  action: >-
    Smallest next action justified by current evidence.

open_questions:
  - Only unresolved questions material to diagnosis.
```

## Debugging rules

### Diagnose class before tuning

First classify the failure as one or more of:

- infra/runtime;
- data/schema/leakage;
- metric/evaluator/parser;
- reward/verifier;
- optimization/numerical;
- checkpoint/resume/reproducibility;
- expected but undesirable learned policy;
- unknown.

Do not tune optimizer/reward weights before ruling out evaluator and implementation defects when the observed metrics could be invalid.

### Follow the first bad signal

Prefer a causal timeline:

```text
reward component drifts -> action distribution collapses -> entropy falls -> final metric degrades
```

instead of a symptom list with no ordering.

### One diagnostic at a time

The next action should ideally discriminate among hypotheses. Good examples:

- replay reward on fixed stored trajectories;
- compare metric implementation against hand labels;
- inspect action distribution by step;
- run the same checkpoint with two evaluators;
- freeze data and compare one reward component;
- reproduce OOM at a fixed sequence length.

Weak examples:

- "try lower LR and different reward weights";
- "increase data and rerun";
- "use a larger model".

### Reviewer handoff

Give `reviewer` the packet plus only the minimal referenced artifacts needed to diagnose it. If reviewer cannot resolve a genuinely hard narrow question, create a smaller decision packet for `expert`.

### Resolution

A debug packet is closed only when one of these is true:

- root cause is demonstrated and a targeted validation confirms the fix;
- the experiment is marked invalid with a justified rerun plan;
- the result is accepted as a valid negative/degenerate outcome;
- the issue is bounded as unresolved and the project deliberately stops.

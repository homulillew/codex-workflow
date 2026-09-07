# Reporting Protocol

Formal ML work should leave a compact evidence trail that is useful for debugging, review, and interviews. Reports are generated from artifacts; they are not substitutes for raw metrics/configs.

Recommended experiment layout:

```text
experiments/EXP-XXX/
  brief.yaml
  config.yaml
  result.json
  samples.jsonl
  reports/
    run_report.md
    training_report.md
    bad_case_report.md
    decision.md
```

## 1. Run Report

Purpose: answer **what exactly ran?**

Required sections:

### Identity

- experiment ID;
- experiment type: exploratory / registered / claim-bearing;
- source repository/ref/commit;
- dirty working tree yes/no;
- parent/baseline experiment;
- start/end timestamp;
- status: valid / invalid / interrupted.

### Inputs

- model/checkpoint/revision;
- tokenizer/chat template when material;
- train/eval dataset version/hash/split;
- resolved config path/hash;
- seed;
- entrypoint/command;
- environment/framework/CUDA versions when material;
- hardware.

### Runtime

- wall time/GPU hours;
- steps/tokens/samples;
- checkpoint and resume events;
- OOM/retry/interruption events;
- artifact locations.

### Results

- registered primary metric;
- secondary metrics;
- guardrail metrics;
- baseline delta using the same eval definition;
- missing/invalid metrics.

### Deviations

List every deviation from the contract. A silent deviation invalidates strong causal claims.

## 2. Training Report

Purpose: answer **was optimization healthy, and what happened during training?**

Training reports should analyze trajectories, not dump dashboards.

Required when available:

- loss/reward trends;
- reward mean/std and component trends;
- KL / entropy / clip fraction / importance-ratio health for RL-style training;
- gradient norm and numerical anomalies;
- output length/action distribution;
- parse/rollout success rate;
- throughput and peak memory when relevant;
- checkpoint/resume stability.

### Timeline segmentation

Split training into meaningful ranges when behavior changes, e.g.:

```text
steps 0-200     stable warm-up
steps 200-450   ASK/action ratio rises sharply
steps 450-600   entropy collapses and reward plateaus
```

For each range record:

- observation;
- first signal that changed;
- correlated signals;
- likely interpretation;
- confidence: high / medium / low;
- evidence path/metric.

Do not claim causality from correlation alone.

### Training issue taxonomy

At minimum distinguish:

- infrastructure/runtime;
- numerical instability;
- optimization instability;
- reward/verifier pathology;
- data distribution/pathology;
- evaluation/parser bug;
- checkpoint/resume/reproducibility;
- expected-but-undesirable policy behavior.

Each material issue should include impact, evidence, resolution or current status, and whether it invalidates the run.

## 3. Bad Case Report

Purpose: answer **how does the model fail, at cluster level?**

Do not provide only a gallery of anecdotes.

### Sampling

Record:

- source eval/run;
- sample size;
- sampling rule (all failures, random subset, stratified by label/action/severity, etc.);
- whether the taxonomy was defined before or after inspecting the samples.

### Taxonomy summary

Example:

```text
Bad cases: 96
- premature answer: 31 (32.3%)
- redundant ask: 24 (25.0%)
- wrong question: 18 (18.8%)
- missed escalation: 11 (11.5%)
- over escalation: 7 (7.3%)
- parse/format: 5 (5.2%)
```

Project-specific categories belong in the project repository, not this generic workflow.

### Per-cluster analysis

For every material cluster include:

- definition;
- count/rate;
- representative cases;
- input/current state;
- model output/action;
- expected behavior;
- reward/metric decomposition when applicable;
- whether the failure was rewarded or penalized;
- likely hypotheses;
- evidence for/against hypotheses;
- proposed diagnostic or next experiment.

### Degenerate-strategy audit

Explicitly check whether the treatment improves the headline metric by exploiting a loophole, e.g.:

- always refusing/escalating;
- asking until max turns;
- producing longer answers to game a semantic judge;
- formatting around parser weaknesses;
- exploiting train/eval duplicates;
- collapsing to majority action/class;
- memorizing benchmark artifacts.

### Counterfactual pairs

When practical, include pairs where a small input/state change should alter behavior. These are often more diagnostic than average accuracy.

## 4. Decision Record

Purpose: answer **what did we learn and what should happen next?**

Required header:

```yaml
decision:
  experiment_id: EXP-XXX
  state: ACCEPT|REJECT|INCONCLUSIVE|FOLLOW_UP
  hypothesis_supported: true|false|unknown
  evidence_confidence: high|medium|low
```

Required sections:

### Registered question and hypothesis
Restate them without rewriting them to match the result.

### Decisive evidence

- primary metric comparison;
- guardrail comparison;
- uncertainty/seed/variance limitations;
- key bad-case findings;
- relevant training-health findings.

### Interpretation

Separate:

- observed fact;
- most likely explanation;
- plausible alternative explanation.

### Caveats

Include data scope, benchmark representativeness, external model dependence, single-seed limitations, evaluator limitations, or other material constraints.

### Decision

Choose exactly one state and explain why.

### Next action

If `FOLLOW_UP`, specify one new falsifiable hypothesis. Do not change the current experiment in place.

## Structured `result.json`

Prefer machine-readable results in addition to Markdown reports. Minimal example:

```json
{
  "experiment_id": "EXP-004",
  "source_commit": "abc123",
  "status": "valid",
  "metrics": {
    "primary": {},
    "secondary": {},
    "guardrails": {}
  },
  "baseline_experiment": "EXP-003",
  "artifacts": {},
  "notes": []
}
```

The Markdown reports may interpret these values; they must not silently substitute different numbers.

## Report quality rules

- Prefer tables/aggregates plus a few representative examples.
- Preserve raw sample IDs so examples can be traced back.
- Mark missing evidence instead of inventing it.
- Report failed/negative outcomes with the same rigor as positive outcomes.
- Never say a problem was "fixed" without the validation run that demonstrates the fix.
- Never use an LLM-written report as the sole evidence for a metric or training event.

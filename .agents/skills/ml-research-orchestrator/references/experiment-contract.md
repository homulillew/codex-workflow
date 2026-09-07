# Experiment Contract v1

A registered ML experiment must have a frozen contract before pilot/full compute. The contract is a research agreement, not a post-hoc summary.

Recommended path:

```text
experiments/EXP-XXX/brief.yaml
```

## Required schema

```yaml
experiment_contract_version: 1
experiment_id: EXP-XXX
status: planned

source:
  repository: owner/repo
  source_ref: branch-or-tag
  source_commit: exact-sha
  parent_experiment: EXP-YYY-or-null

research_question: >-
  One causal or decision-relevant question this experiment should answer.

hypothesis:
  statement: >-
    A falsifiable prediction.
  rationale:
    - Evidence or theory motivating the prediction.

baseline:
  experiment_id: EXP-YYY-or-null
  checkpoint_or_model: identifier
  config: path-or-identifier
  eval_version: identifier

change_under_test:
  summary: >-
    The smallest meaningful treatment/change.
  changed_variables:
    - name: variable_name
      baseline: value
      treatment: value
  coupled_changes:
    - Any unavoidable additional change; otherwise []

fixed_variables:
  - dataset split/version
  - model/checkpoint
  - seed policy
  - optimizer/scheduler where relevant
  - decoding/rollout settings where relevant
  - evaluator/metric version

data:
  train:
    id: dataset-id
    version_or_hash: value
    split: train
  eval:
    id: dataset-id
    version_or_hash: value
    split: eval
  leakage_checks:
    - check description

model:
  id: model-id
  revision: revision-or-hash
  checkpoint: path-or-id

metrics:
  primary:
    - name: primary_metric
      direction: higher|lower
      comparison: treatment-vs-baseline
      success_rule: explicit rule
  secondary:
    - name: metric_name
  guardrails:
    - name: guardrail_metric
      unacceptable_regression: explicit rule

compute_budget:
  hardware: description
  max_gpu_hours: number-or-null
  max_runs: integer-or-null
  max_tokens_or_steps: number-or-null

promotion_plan:
  required_levels: [L0, L1, L2, L3, L4, L5]
  smoke_budget: description
  pilot_budget: description
  full_budget: description

stop_conditions:
  - structural failure that blocks higher compute
  - success/failure condition already decisive

success_criteria:
  - Observable criterion supporting the hypothesis.

failure_criteria:
  - Observable criterion contradicting the hypothesis.

known_risks:
  confounders:
    - potential confounder
  reward_or_metric_hacking:
    - known degenerate strategy to watch
  reproducibility:
    - known reproducibility limitation

expected_artifacts:
  - config.yaml
  - result.json
  - samples.jsonl
  - reports/run_report.md
  - reports/training_report.md
  - reports/bad_case_report.md
  - reports/decision.md

planner_assumptions:
  - Assumption that must be checked before execution.

notes:
  post_hoc_analysis_allowed: true
  rule: >-
    Post-hoc metrics/analyses must be labeled post-hoc and cannot silently replace the registered primary metric.
```

## Contract rules

### Freeze before compute

The contract should be committed before L3 pilot or L4 full execution. L0/L1/L2 may reveal implementation defects that require a contract correction, but semantic changes to hypothesis, primary metric, treatment, or eval definition require a new revision or experiment ID.

### One question, one experiment

Prefer a single meaningful treatment. If multiple variables must move together for technical reasons, list them under `coupled_changes` and weaken causal claims accordingly.

### Baseline compatibility

A baseline is compatible only when the comparison uses the same relevant:

- eval set/version;
- metric implementation;
- output parsing rules;
- decoding/evaluation budget;
- model/checkpoint semantics.

If not compatible, do not report a direct delta without qualification.

### Primary versus guardrail

The primary metric answers the registered question. Guardrails detect degenerate success, such as:

- accuracy rising while refusal/over-escalation explodes;
- reward rising while task success falls;
- safety metric improving only because the model never answers;
- success rate improving via longer/unbounded interaction;
- format compliance masking semantic failure.

A primary-metric win with a registered unacceptable guardrail regression is not `ACCEPT`.

### Seeds and uncertainty

For expensive experiments, exact multi-seed replication may be infeasible. Record the seed policy and the resulting uncertainty honestly. Never imply statistical confidence that was not measured.

### Compute budget is part of the research design

Budget limits discourage endless tuning and make negative results interpretable. If the budget changes materially after results are observed, record why and create a follow-up experiment when the change alters the claim.

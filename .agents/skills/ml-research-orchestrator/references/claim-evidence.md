# Claim Evidence Ledger

Every resume/report/interview claim that asserts an improvement, comparison, capability, or design conclusion should resolve to exact experiment evidence.

Recommended project path:

```text
reports/claim_evidence.md
```

## Claim entry template

```yaml
claim_id: CLAIM-XXX
status: draft|audited|retired

statement: >-
  The exact claim in plain language.

scope:
  task: description
  model: model/checkpoint scope
  eval: eval dataset/version

supporting_evidence:
  decision_records:
    - experiments/EXP-XXX/reports/decision.md
  experiments:
    - EXP-XXX
  baseline_experiments:
    - EXP-YYY
  source_commits:
    - sha
  metrics:
    - name: metric_name
      baseline: value
      treatment: value
      delta: value
      result_source: experiments/EXP-XXX/result.json

provenance:
  config: experiments/EXP-XXX/config.yaml
  dataset_version_or_hash: value
  model_revision: value
  evaluator_version: value

caveats:
  - limitation

external_comparison:
  used: false
  model_or_system: null
  version_date_settings: null
  reproducibility_limitations: []

audit:
  reviewer: role-or-human
  date: YYYY-MM-DD
  outcome: pass|qualified|fail
  notes: []
```

## Rules

### No orphan claims

If a claim cannot be linked to a valid decision record and structured result, it remains `draft` and should not appear as a final resume/report metric.

### Preserve compatible evaluation

Do not compute deltas across incompatible metric/eval versions without a clearly qualified re-evaluation.

### Exact precision only when measured

Avoid false precision. If repeated runs/seeds were not performed, do not imply confidence intervals or robust significance.

### External/closed model comparisons

When comparing against an external model/system, record:

- provider/model name;
- exact version/date if available;
- decoding settings/prompt;
- evaluator and test set;
- access date;
- reproducibility caveat.

A claim such as "better than X" is weak evidence if X is an undocumented moving target.

### Claim lifecycle

A claim may be retired when:

- a later compatible experiment contradicts it;
- the eval definition changes materially;
- a data leak/evaluator defect invalidates it;
- the project scope changes.

Do not delete the historical entry; mark it `retired` and explain why.

## Evidence chain

Preferred chain:

```text
Resume/interview statement
  -> CLAIM-XXX
  -> decision.md
  -> result.json + bad_case_report.md
  -> experiment contract/config
  -> source commit
  -> dataset/model/evaluator provenance
```

The claim ledger should make it possible for an independent reviewer to verify the statement without relying on chat memory.

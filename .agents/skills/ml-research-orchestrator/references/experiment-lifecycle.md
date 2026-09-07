# Experiment Lifecycle and Promotion Gates

Formal ML experiments progress through bounded compute levels. Each level exists to answer a cheaper question before spending more compute.

## L0 — unit / synthetic

Goal: prove local logic and invariants.

Typical checks:

- parser/serializer unit tests;
- metric/reward verifier hand-calculated cases;
- data schema validation;
- deterministic environment transitions;
- config resolution;
- checkpoint/tokenizer/template compatibility;
- negative/adversarial cases for reward or safety rules.

Promotion gate:

- all material invariants pass;
- no ambiguous metric/reward semantics remain;
- failure output is diagnosable.

Do not promote if the experiment can still fail because of a sign error, parsing bug, data leak, invalid action, or stale checkpoint reference.

## L1 — offline sample / replay

Goal: validate behavior on real-like samples without training.

Typical scale: tens to hundreds of examples.

Inspect:

- label/action/reward distributions;
- baseline outputs;
- reward decomposition;
- metric sanity;
- duplicate/leakage checks;
- representative positive/negative/borderline cases;
- output parse rate.

Promotion gate:

- expected baseline behavior is plausible;
- reward/metric values align with human-inspected cases;
- no major data imbalance or leakage invalidates the question;
- obvious degenerate strategy is represented in tests or guardrails.

## L2 — smoke training/run

Goal: prove the full pipeline can execute end to end and produce healthy-enough signals.

Typical scale: a very small fraction of the final budget; e.g. dozens to a few hundred updates or a small sample slice.

Inspect:

- OOM/NaN/Inf;
- checkpoint save/resume;
- resolved config and source commit;
- train/reward/metric direction;
- gradient norm, entropy/KL/clip fraction when relevant;
- throughput and memory feasibility;
- sample outputs before/after smoke;
- logging/artifact completeness.

Promotion gate:

- pipeline is stable;
- observed signal is not obviously broken;
- full-run resource estimate is acceptable;
- no structural issue requires code/reward/data redesign.

A smoke run is not evidence of final model quality.

## L3 — pilot

Goal: determine whether the registered treatment shows enough signal to justify full compute and surface likely failure modes.

Typical scale: enough data/steps to observe optimization behavior, still cheaper than full training.

Required analysis:

- baseline/treatment metric delta;
- guardrail movement;
- training dynamics by time segment;
- initial bad-case taxonomy;
- action/length/reward component distributions when relevant;
- updated compute estimate;
- evidence for/against expected failure modes.

Promotion gate:

Promote when either:

1. the pilot shows plausible useful signal without material guardrail failure and the full run is needed for a credible decision; or
2. the full run is necessary to distinguish optimization noise from the registered effect.

Do not promote when:

- a structural failure is already clear;
- the treatment is dominated by a cheaper fix;
- guardrail regression already violates the contract;
- the experiment question is already answered negatively with sufficient evidence.

## L4 — full registered run

Goal: collect the evidence needed for the registered decision.

Requirements:

- exact frozen contract/revision;
- clean source provenance;
- no unrecorded semantic changes from pilot;
- final resolved config;
- checkpoint/artifact metadata;
- primary and guardrail metrics;
- raw-enough samples for audit;
- failure/incident log if applicable.

Do not mutate the experiment definition mid-run to rescue the result. Material semantic changes create a follow-up experiment.

## L5 — analysis and audit

Goal: turn outputs into evidence-bounded knowledge.

Required artifacts for a completed formal experiment:

- `run_report.md`;
- `training_report.md` when training occurred;
- `bad_case_report.md` when behavioral quality matters;
- `decision.md`;
- `result.json` or equivalent structured metrics.

Claim-bearing work additionally requires:

- independent audit/reviewer pass;
- claim ledger linkage;
- interview evidence update when relevant.

## Promotion record

Each experiment should record level status, for example:

```yaml
lifecycle:
  L0:
    status: passed
    evidence: tests/reward/test_gate.py
  L1:
    status: passed
    evidence: experiments/EXP-004/offline_report.json
  L2:
    status: passed
    evidence: runs/exp004-smoke
  L3:
    status: passed
    decision: promote
  L4:
    status: completed
  L5:
    status: completed
```

Allowed status values:

- `not_started`
- `running`
- `passed`
- `failed`
- `blocked`
- `waived`
- `completed`

A waived level must contain a reason. Waivers are exceptional, not a convenience for skipping validation.

## Stop early rule

Stopping early is desirable when a cheaper stage produces decisive evidence. Record the reason and preserve the run.

Examples:

- verifier gives high reward to known-bad adversarial cases -> stop at L1;
- policy collapses to a single action in smoke -> stop at L2;
- pilot already violates a registered safety/utility guardrail -> stop at L3;
- implementation bug invalidates the run -> mark invalid, fix through `dev-orchestrator`, create/re-run the appropriate experiment revision.

## Invalid run versus negative result

Keep these distinct:

- **Invalid run:** code/data/metric/infra defect means the experiment did not test the registered hypothesis.
- **Negative result:** the experiment was valid and the evidence did not support the hypothesis.

Never hide a negative result by relabeling it an implementation issue without evidence.

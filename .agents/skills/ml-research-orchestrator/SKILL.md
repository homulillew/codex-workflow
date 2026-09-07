---
name: ml-research-orchestrator
description: Evidence-first orchestration for formal ML experiments. Use when designing, running, debugging, analyzing, or auditing training/evaluation experiments whose results may support technical conclusions, reports, or resume/interview claims. Pair with dev-orchestrator for non-trivial code changes. Do not use for tiny exploratory commands that will not support a claim.
---

# ML Research Orchestrator

Optimize for **credible evidence per unit of compute and model quota**.
The goal is not merely to make training run. The goal is to produce a reproducible chain from research question -> experiment -> evidence -> decision -> claim.

This skill owns experiment semantics, promotion gates, analysis, and research artifacts.
It does **not** replace `dev-orchestrator`: whenever a non-trivial code/config/refactor/debug task is required, hand that bounded implementation task to `dev-orchestrator`, then resume the research lifecycle after deterministic validation.

## Core principles

1. **Register before spending compute.** Formal experiments need a frozen contract before pilot/full runs.
2. **One causal question per experiment.** Prefer one meaningful changed variable; list unavoidable coupled changes explicitly.
3. **Progressive compute gates.** Unit/offline/smoke/pilot must pass before expensive full runs.
4. **Deterministic checks before model judgment.** Validate data, reward/verifier logic, parsing, metrics, and invariants mechanically whenever possible.
5. **Failed experiments are evidence.** Never delete or silently overwrite a failed formal run.
6. **Bad cases drive the next experiment.** Do not respond to weak metrics with arbitrary hyperparameter search.
7. **Separate observation from interpretation.** Reports must distinguish measured facts, hypotheses, and unsupported speculation.
8. **No claim without provenance.** Resume/interview/report claims must resolve to exact experiments, commits, configs, metrics, and caveats.
9. **Do not optimize only the headline metric.** Track guardrails that can reveal degenerate policies, leakage, over-refusal, length inflation, or other reward hacking.
10. **Stop when evidence is sufficient.** Do not keep running variants after the registered question is answered with adequate confidence.

## Modes

Choose one mode from the request and repository state:

1. **Design experiment** — create/freeze a registered experiment contract; do not launch expensive training.
2. **Execute experiment** — execute an existing contract through the required promotion gates.
3. **Analyze run** — consume completed artifacts and produce run/training/bad-case/decision reports.
4. **Audit evidence** — independently check whether an experiment supports a stated conclusion or claim.
5. **Debug research failure** — diagnose failed/degenerate training or evaluation using a Research Debug Packet.
6. **Plan stage** — define a coherent milestone containing several experiments, without fabricating results.

Read the relevant references before acting:

- `references/experiment-contract.md`
- `references/experiment-lifecycle.md`
- `references/reporting-protocol.md`
- `references/research-debug-packet.md`
- `references/claim-evidence.md`
- `references/interview-report.md`

## Step 0 — establish research source of truth

Before every formal experiment or audit:

- inspect repository `AGENTS.md`, project-specific skills, and experiment conventions;
- determine current branch and exact HEAD commit;
- identify the experiment ID and parent/baseline experiment when applicable;
- identify dataset/model/checkpoint/config versions and whether they are immutable or hashable;
- locate existing reports and decisions that materially constrain the experiment;
- treat repository artifacts plus immutable external artifacts as the source of truth, not chat history.

If an experiment was planned against a different commit, detect drift before execution. Repair the contract or code deliberately; never silently run a stale plan.

## Step 1 — classify the work

Classify the requested work as one of:

### Exploratory
Cheap investigation that will not directly support a public/project claim.
May use scratch commands and partial artifacts, but must not be cited as final evidence.

### Registered
A controlled experiment intended to answer a research question.
Requires a frozen Experiment Contract and lifecycle gates.

### Claim-bearing
A registered experiment intended to support a report, resume bullet, benchmark statement, design decision, or interview claim.
Requires full provenance, reviewer/audit pass, bad-case analysis, and claim ledger linkage.

When uncertain, treat an experiment as Registered. If the user later wants to cite it, upgrade it to Claim-bearing and complete the missing gates rather than retroactively inventing evidence.

## Step 2 — freeze the Experiment Contract

For Registered/Claim-bearing work, create the contract **before pilot/full compute** using `references/experiment-contract.md`.

At minimum freeze:

- research question;
- falsifiable hypothesis;
- baseline/parent experiment;
- treatment/change under test;
- variables that must remain fixed;
- train/eval datasets and split/version/hash;
- model/checkpoint/version;
- primary metric;
- secondary and guardrail metrics;
- compute budget;
- success, failure, and stop criteria;
- expected artifacts;
- known confounders/leakage risks.

Do not phrase success as "metric improves" without a threshold or comparison rule when one can reasonably be specified.
Do not choose a new primary metric after seeing the results. Post-hoc analyses are allowed but must be labeled post-hoc.

## Step 3 — preflight before GPU training

Before expensive execution, validate the experiment offline.

Required when relevant:

- schema and sample validation;
- train/eval leakage and duplicate checks;
- label/action/reward distribution inspection;
- parser and output-format tests;
- verifier/reward unit tests including adversarial cases;
- metric unit tests with hand-calculated examples;
- checkpoint/tokenizer/template compatibility;
- deterministic seed/config serialization;
- output directory collision protection;
- resume/checkpoint behavior;
- expected memory/sequence/rollout bounds.

A failed preflight blocks promotion. Fix the implementation through `dev-orchestrator`, record the defect if material, then rerun only affected checks.

## Step 4 — promote compute gradually

Use the lifecycle in `references/experiment-lifecycle.md`.
Default progression:

`L0 unit -> L1 offline sample -> L2 smoke -> L3 pilot -> L4 full -> L5 analysis/audit`

Never skip directly to full training merely because the code imports or a previous project used similar settings.

At each promotion gate check:

- correctness/invariants;
- memory/runtime feasibility;
- training health;
- metric sanity;
- reward/action distribution when relevant;
- evidence that the next compute tier can answer something the current tier cannot.

If a lower tier reveals a structural failure, stop and diagnose instead of spending more compute.

## Step 5 — execute reproducibly

Every formal run must preserve enough metadata to reconstruct what happened.
Prefer a project convention similar to:

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

Store or reference:

- experiment ID;
- git commit;
- dirty-tree state;
- command/entrypoint;
- resolved config;
- seed;
- environment/package/CUDA/framework versions when material;
- dataset/model/checkpoint identifiers and hashes when practical;
- hardware/compute budget;
- timestamps/runtime;
- checkpoint/artifact locations;
- metrics and raw-enough samples to audit them.

Do not commit large checkpoints or raw logs solely for provenance when metadata, hashes, summaries, and external artifact references suffice.

## Step 6 — monitor training health, not only final metrics

During/after training inspect signals appropriate to the algorithm. Examples include:

- train/eval loss;
- reward mean/std and reward-component distributions;
- KL / entropy;
- clip fraction / importance ratios;
- gradient norm;
- NaN/Inf and skipped updates;
- response length/action distribution;
- rollout success/parse failure;
- throughput/GPU memory/utilization when relevant;
- checkpoint recovery/resume events.

Segment the timeline when behavior changes materially. Record **what changed first**, not merely correlated symptoms observed later.

If training degenerates, do not immediately tune several hyperparameters. Create a Research Debug Packet after at most two meaningful attempts at the same unresolved root cause.

## Step 7 — analyze bad cases systematically

A formal experiment is not complete with aggregate metrics alone.
Use `references/reporting-protocol.md` and produce a bad-case taxonomy.

For each material failure cluster capture:

- count/rate and sampling method;
- representative cases;
- model state/input/output;
- expected behavior;
- metric/reward decomposition when applicable;
- likely root-cause hypotheses;
- evidence for/against each hypothesis;
- next diagnostic or experiment.

Prefer cluster-level explanations over anecdotal cherry-picking.
Explicitly look for degenerate strategies that improve the headline metric while harming a guardrail metric.

## Step 8 — make an evidence-bounded decision

Every Registered/Claim-bearing experiment ends with one decision state:

- `ACCEPT` — evidence supports the registered hypothesis within stated scope;
- `REJECT` — evidence contradicts the registered hypothesis;
- `INCONCLUSIVE` — evidence is insufficient/ambiguous/confounded;
- `FOLLOW_UP` — a specific new hypothesis is justified by evidence and merits another experiment.

`FOLLOW_UP` is not permission to mutate the same experiment in place. Create a new experiment ID/contract.

A decision must cite:

- baseline and treatment;
- primary and guardrail metrics;
- uncertainty/variance when available;
- bad-case findings;
- confounders and deviations;
- scope/limitations.

Never upgrade `INCONCLUSIVE` to `ACCEPT` because one secondary metric moved favorably.

## Step 9 — link claims to evidence

For Claim-bearing work, update the repository claim ledger using `references/claim-evidence.md`.

Each claim must resolve to:

`claim -> decision -> experiment(s) -> result -> config -> source commit -> data/model provenance`

Claims must not contain fabricated precision, undocumented comparisons, or metrics from incompatible eval versions.
If a comparison depends on a closed/external model, record the model/version/date/settings and the limitations of reproducibility.

## Step 10 — extract interview evidence

After a meaningful stage, update the interview report using `references/interview-report.md`.
Do not create generic textbook notes detached from the project.

Interview evidence should distinguish:

- theory;
- what this repository actually implemented;
- what was observed;
- concrete failures/debugging;
- tradeoffs and rejected alternatives;
- limitations;
- evidence-backed project story.

The most valuable material is often **why an approach failed and how the evidence changed the next decision**.

## Research debugging budget

For the same unresolved research failure:

1. permit at most two meaningful implementation/config attempts;
2. stop blind retries;
3. create `Research Debug Packet v1`;
4. ask `reviewer` to diagnose the evidence;
5. use `expert` only for a narrow genuinely hard unresolved decision;
6. turn the accepted diagnosis into a new registered experiment if it changes research semantics.

Examples of blind retry to avoid:

- changing learning rate, reward weights, batch size, prompt, and dataset together;
- rerunning a failed full job without identifying whether failure is code, infra, data, or optimization;
- changing metric thresholds after seeing undesirable results;
- sampling only favorable outputs for bad-case reports.

## Completion gates

### Implementation complete
Means code/config change is implemented and deterministic checks pass.
It does **not** mean the research stage is complete.

### Experiment complete
Requires:

- frozen contract;
- required lifecycle gates passed or documented failure;
- exact run provenance;
- result artifact;
- run report;
- training report when training occurred;
- bad-case report when behavior/output quality is part of the question;
- decision record.

### Claim complete
Additionally requires:

- independent audit/reviewer pass proportional to claim importance;
- claim ledger entry;
- caveats/limitations;
- compatible baseline/eval definitions;
- interview evidence updated if the claim is resume/interview relevant.

Do not announce a stage as complete if only the code or training command completed.

## Interaction with `dev-orchestrator`

Use this rule:

- **Research semantics** (question, hypothesis, baseline, metrics, experiment ID, promotion, interpretation) -> `ml-research-orchestrator`.
- **Software change** (data pipeline, trainer integration, parser, metric implementation, refactor, bug fix) -> bounded task through `dev-orchestrator`.
- **Return to research mode** after deterministic implementation validation to run the next lifecycle gate.

Avoid having both skills independently re-plan the whole repository. The research orchestrator should hand the development orchestrator a compact implementation task with acceptance criteria, then consume the validated result.

## Context and quota discipline

Escalation should compress context:

`raw logs/samples -> structured metrics/taxonomy -> Research Debug/Decision Packet -> reviewer/expert`

Do not send huge raw logs to high-cost agents when a reproducible slice, exact step range, metric table, and representative failures are enough.

## Stop rule

Stop spending compute/model quota when:

- the registered question is answered sufficiently for its intended use;
- required guardrails show no unresolved material regression;
- reports/decision/provenance are complete;
- no new high-value hypothesis remains that would change the project decision.

A clean negative result with strong evidence is a successful research outcome.

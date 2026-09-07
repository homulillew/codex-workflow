# Interview Evidence Report

The interview report is not a generic study guide. It is a structured extraction of evidence from the actual project so the author can explain what was built, why, what failed, and what the experiments established.

Recommended project structure:

```text
reports/interview/
  01_problem_definition.md
  02_data_and_environment.md
  03_training_method.md
  04_reward_or_objective.md
  05_training_debugging.md
  06_bad_cases_and_ablation.md
  07_system_and_compute.md
  08_project_story.md
```

Projects may rename topics, but keep the evidence categories below.

## Per-topic template

### 1. Concept/theory

Explain only the theory required to understand the project decision. Include equations or algorithm details when they were materially used.

### 2. What we implemented

Record exact repository-specific facts:

- files/modules;
- model/trainer/framework choices;
- data format;
- objective/reward/metric implementation;
- compute constraints;
- important configuration.

### 3. Why this design

State:

- problem being solved;
- alternatives considered;
- reason for choosing the implemented design;
- assumptions and tradeoffs.

### 4. What we observed

Link to experiment IDs and claim IDs. Separate measured facts from interpretations.

### 5. What went wrong

This section is mandatory after meaningful implementation/training stages.

Include concrete issues such as:

- data pathology;
- reward hacking;
- optimization instability;
- inference/training mismatch;
- OOM/performance;
- metric bugs;
- policy collapse;
- failed ablations.

For each issue record symptom -> diagnosis -> fix/decision -> validation.

### 6. Hard questions an interviewer may ask

Generate questions from actual weak points and design choices, not only textbook questions.

Examples:

- Why did you choose this baseline?
- How did you know the reward was not being hacked?
- What evidence shows the improvement came from the treatment rather than changed data/decoding?
- Which metric regressed?
- What would you change with 4x compute?
- Why is this not merely a reproduction of paper X?
- Which parts are deterministic and which depend on an LLM evaluator?
- What was the hardest training failure you debugged?

### 7. Evidence-backed answer notes

For each hard question, structure the answer as:

`decision -> evidence -> tradeoff -> limitation`

Do not invent anecdotes or results merely to make the story stronger.

## Project story artifact

`08_project_story.md` should maintain three versions:

### 30-second summary

Problem + core method + strongest verified result.

### 90-second summary

Add motivation, baseline, core design choice, main metrics, one failure/tradeoff, and final result.

### 5-minute deep dive

Cover:

1. real problem/motivation;
2. task/data/environment design;
3. baseline;
4. algorithm/objective/reward;
5. training system/compute constraints;
6. key experiment/ablation;
7. bad cases and debugging;
8. limitations/next work.

## Interview quality gate

A project is interview-ready only when the report can answer:

- What problem did you personally choose to solve?
- Why was the baseline insufficient?
- What is the single most important technical idea?
- How exactly was it implemented?
- How did you validate the reward/objective/metric?
- Which experiments isolate its effect?
- What failed during training?
- What bad cases remain?
- What tradeoff did the improvement introduce?
- What claim can you defend with exact evidence?
- What claim can you **not** defend yet?

If answers depend on memory instead of experiment/commit/report references, the evidence extraction is incomplete.

## Updating cadence

Do not wait until the project is over.
Update interview evidence after:

- a stage establishes a baseline;
- a major algorithm/reward design is implemented;
- a significant training failure is diagnosed;
- an ablation changes a project decision;
- a claim is audited.

This preserves authentic debugging detail that is usually lost when interview notes are written months later.

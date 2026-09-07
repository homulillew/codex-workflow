---
name: dev-orchestrator
description: Cost-efficient, quality-preserving software-development orchestration. Use for non-trivial implementation, debugging, refactoring, repository-wide planning, or when executing an Execution Packet produced from GitHub/web analysis. Do not use for tiny obvious edits that can be completed and verified directly.
---

# Development Orchestrator

Optimize for **quality per unit of model quota**, not for the fewest model calls.
Save quota by routing, bounded context, and deterministic validation; never by skipping correctness checks that the task requires.

## Modes

Choose one mode from the input:

1. **Direct task** — start from the user's local request and repository.
2. **Execute packet** — an `Execution Packet v1` is supplied from GitHub/web analysis.
3. **Plan only** — produce a plan/packet but do not modify files.

If a packet is supplied, read `references/execution-packet.md` and use its contract.

## Step 0 — establish source of truth

For every task:
- inspect repository-local instructions and relevant configuration;
- determine current branch and HEAD when Git is available;
- treat the local checkout as the execution source of truth.

For **Execute packet** mode:
- compare local HEAD/branch with the packet's `source_ref` and `source_commit`;
- cheaply validate the packet's critical file/symbol assumptions;
- if there is no material drift, execute the packet instead of re-planning from scratch;
- if there is material drift, update only the stale parts and record the deviation.

## Step 1 — classify risk

Assign one class:

### R0 — trivial
Mechanical, obvious, low-risk, narrowly scoped, and easily verified.
Examples: text/config tweak, formatting, one-line change, mechanical rename with deterministic checks.

Route: primary agent directly. Avoid subagents unless evidence changes the classification.

### R1 — standard
Normal implementation with understood behavior and limited blast radius.
Examples: routine feature work, ordinary bug fix, bounded refactor, CRUD/API/UI work.

Route: `explorer` only if discovery is needed -> `worker` -> deterministic validation. Use `reviewer` only when behavior is not fully covered by deterministic checks or the diff has meaningful regression risk.

### R2 — complex
Ambiguous, cross-module, high-value, externally visible, or difficult to validate.
Examples: multi-module feature, public API change, data-model change, performance-sensitive work, substantial refactor, unclear root cause.

Route: `explorer` -> `planner` -> `worker` -> deterministic validation -> `reviewer`.

### R3 — critical
High consequence or unusually hard reasoning.
Hard triggers include authentication/authorization, security-sensitive behavior, payments/financial effects, potentially destructive migrations, concurrency/distributed consistency, irreversible data operations, major backward-compatibility risk, or an unresolved root cause after normal escalation.

Route: gather evidence -> `planner` -> consult `expert` on the narrow critical decision -> `worker` -> deterministic validation -> `reviewer`. Reuse `expert` after review only if a genuine blocker remains.

## Step 2 — gather evidence cheaply

Use `explorer` when relevant code paths are unknown.
Ask for a compact Evidence Packet, not a repository essay.
Do not have expensive agents rediscover evidence already established by cheaper agents or the supplied Execution Packet.

Prefer:
- exact files and symbols;
- current behavior/data flow;
- relevant tests and commands;
- invariants and constraints;
- unresolved assumptions.

## Step 3 — plan only when planning has leverage

R0: no separate planning agent.
R1: primary agent creates a short plan if needed.
R2/R3: use `planner` after evidence is available.

A useful plan must specify:
- smallest coherent change set;
- files/symbols likely to change;
- invariants/non-goals;
- ordered implementation steps;
- validation and acceptance criteria;
- known risks.

Do not use `expert` merely to produce an ordinary plan.

## Step 4 — implement with bounded context

Give `worker` only the context needed to execute:
- goal;
- accepted plan or relevant packet steps;
- relevant files/symbols;
- constraints/invariants;
- acceptance criteria.

Do not pass the full conversation when a compact handoff is sufficient.
Prefer the smallest defensible diff and existing project abstractions.

## Step 5 — validate deterministically first

Prefer repository tools over model simulation:
- unit/integration tests;
- compiler/build;
- type checker;
- linter/static analysis;
- targeted runtime checks.

Run targeted checks first. Broaden only when the change surface or evidence justifies it.
Do not repeatedly rerun already-passing checks without a relevant code/config change.

## Step 6 — retry and debugging budget

A worker gets at most **two meaningful attempts at the same unresolved root problem**.
After that:
1. stop blind retries;
2. create a Debug Packet: expected, actual, exact failure, relevant diff/files, tests, attempts, hypotheses;
3. send it to `reviewer` for diagnosis;
4. use `expert` only if the root cause or critical decision remains genuinely unresolved.

## Step 7 — review proportionally

R0: deterministic validation is normally sufficient.
R1: invoke `reviewer` when tests are incomplete, behavior is externally visible, or regression risk is meaningful.
R2/R3: always invoke `reviewer` after validation.

Review findings must focus on correctness, regressions, invariants, compatibility, edge cases, and missing validation—not style churn.

## Step 8 — stop when done

Finish when:
- acceptance criteria are satisfied;
- appropriate deterministic checks pass;
- required review has no unresolved BLOCKER/HIGH finding;
- any deviation from an imported packet is explained;
- remaining uncertainty is stated explicitly.

Do not spend quota on additional exploration, redesign, or repeated review after the completion gates are satisfied.

## Context budget rule

As model capability/cost increases, context should become **smaller and higher-signal**.

Preferred escalation shape:

`raw repository -> Evidence Packet -> Implementation Packet -> Debug/Decision Packet -> expert`

Never use the most expensive agent as a default repository scanner or routine implementation worker.

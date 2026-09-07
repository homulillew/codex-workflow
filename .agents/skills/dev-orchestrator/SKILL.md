---
name: dev-orchestrator
description: Cost-efficient, quality-preserving software-development orchestration. Use for non-trivial implementation, debugging, refactoring, repository-wide planning, or when executing an Execution Packet produced from GitHub/web analysis. Route model strength by reasoning complexity and safeguards by consequence/risk. Do not use for tiny obvious edits that can be completed and verified directly.
---

# Development Orchestrator

Optimize for **quality per unit of model quota**.
Save quota by routing, bounded context, deterministic validation, and explicit escalation; never by skipping correctness checks.

The central routing rule is:

> **Risk/consequence controls validation intensity. Reasoning complexity controls model strength.**

A dangerous task can be straightforward. A low-risk task can contain a genuinely difficult algorithmic problem. Do not conflate the two.

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
- cheaply validate only assumptions that matter to execution;
- if there is no material drift, execute instead of re-planning from scratch;
- if there is material drift, repair only stale plan steps and record the deviation.

## Step 1 — classify two independent dimensions

Every non-trivial task gets both a **consequence/risk class** and a **reasoning-complexity class**.

### Consequence / risk

Risk answers: **How bad is it if we are wrong?**

#### R0 — low consequence
Narrow, reversible, easily verified, little blast radius.

#### R1 — ordinary consequence
Normal feature/fix/refactor with bounded impact and routine rollback.

#### R2 — high impact
Broad blast radius, public interfaces, data-model/performance changes, meaningful compatibility or operational consequences.

#### R3 — critical consequence
Security/auth, payments, destructive/irreversible data operations, production-critical migrations, severe privacy/compliance exposure, or other cases where a mistake has unusually high cost.

Risk determines:
- required validation depth;
- reviewer requirements;
- rollback/reversibility expectations;
- whether destructive actions need explicit safeguards;
- breadth of acceptance criteria.

**R3 does not automatically trigger `expert`.** A simple but high-consequence change should use ordinary implementation roles plus stronger verification and review.

### Reasoning complexity

Complexity answers: **How difficult is the technical reasoning itself?**

#### C0 — mechanical
Obvious edits, formatting, config/text changes, deterministic transformations.

#### C1 — standard
Well-understood implementation or bug fixing using established repository patterns.

#### C2 — complex
Cross-module planning, non-trivial architecture/refactor, difficult but conventional debugging, or substantial trade-off analysis that a senior planner/reviewer can resolve.

#### C3 — expert / frontier
The remaining bottleneck requires genuinely difficult, non-routine reasoning. Typical triggers:
- novel algorithm, objective, protocol, or architecture design;
- hard root-cause analysis with multiple plausible competing hypotheses after evidence gathering;
- deep synthesis across several technical domains;
- a conceptual decision where ordinary patterns do not determine the answer;
- a high-leverage design choice where the wrong reasoning would invalidate or waste substantial downstream work.

C3 — not R3 — is the normal trigger for `expert`.

## Step 2 — route by complexity, safeguard by risk

Default routing by reasoning complexity:

| Complexity | Default reasoning path |
| --- | --- |
| C0 | `primary` directly + deterministic check |
| C1 | `worker`; `explorer` only if discovery is needed |
| C2 | `explorer` as needed -> `planner` -> `worker` -> `reviewer` when justified |
| C3 | targeted evidence -> `planner` compresses the decision -> `expert` resolves the hard bottleneck -> `worker` implements -> `reviewer` validates |

Then strengthen validation/review according to risk:
- R0: targeted deterministic validation is usually enough;
- R1: reviewer is conditional on coverage and regression risk;
- R2: reviewer is normally required;
- R3: reviewer and risk-specific safeguards are mandatory, regardless of complexity.

Examples:
- **R3/C1:** a straightforward auth guard using an existing pattern -> normal worker + strict tests/reviewer; no GPT-6 merely because it touches auth.
- **R1/C3:** designing a novel scheduling/optimization algorithm in an internal tool -> GPT-6 may be appropriate even though consequence is low.
- **R3/C3:** a genuinely novel security-sensitive consistency algorithm -> GPT-6 plus strict R3 validation/review.

## Step 3 — gather evidence cheaply

Use `explorer` when relevant code paths are unknown.
Ask for a compact Evidence Packet, not a repository essay.

Prefer:
- exact files and symbols;
- current behavior/data flow;
- relevant tests and validation commands;
- invariants and constraints;
- unresolved assumptions.

Do not have expensive agents rediscover evidence already established by cheaper agents or an imported Execution Packet.

## Step 4 — plan when planning has leverage

C0: no separate planning agent.
C1: primary/worker can use a short local plan.
C2: use `planner` after evidence is available.
C3: use `planner` to structure the problem and prepare a compact Decision Packet for `expert`; do not ask GPT-6 to scan the repository.

R2/R3 work should also have an explicit testable plan even if conceptual complexity is low, because risk requires stronger change control.

A useful plan specifies:
- smallest coherent change set;
- files/symbols likely to change;
- invariants/non-goals;
- ordered implementation steps;
- validation and acceptance criteria;
- known risks and rollback concerns.

## Step 5 — use `expert` for C3 reasoning, not routine work

`expert` is a principal reasoning role. It may be invoked **up front** once targeted evidence shows the problem is clearly C3; do not force a fake failure cycle first.

Good expert tasks include:
- choosing/designing a novel algorithm or objective;
- resolving competing technical hypotheses after evidence collection;
- making a hard architecture trade-off requiring deep synthesis;
- finding the cheapest discriminating test for a difficult root-cause question.

Bad expert tasks include:
- repository-wide search;
- ordinary implementation;
- mechanical code review;
- standard high-risk checks whose reasoning is straightforward;
- repeating analysis already resolved by planner/reviewer.

Give `expert` a small high-signal packet:
`evidence -> options/hypotheses -> constraints -> exact decision needed`.

## Step 6 — implement with bounded context

Give `worker` only the context needed to execute:
- goal;
- accepted plan or expert decision when present;
- relevant files/symbols;
- constraints/invariants;
- acceptance criteria.

Prefer the smallest defensible diff and existing project abstractions.
Do not broaden scope or redesign unrelated code.

## Step 7 — validate deterministically first

Prefer repository tools over model simulation:
- unit/integration tests;
- compiler/build;
- type checker;
- linter/static analysis;
- targeted runtime checks;
- risk-specific checks when consequence requires them.

Run targeted checks first. Broaden according to change surface and risk.
Do not repeatedly rerun already-passing checks without a relevant code/config change.

## Step 8 — retry and debugging budget

A worker gets at most **two meaningful attempts at the same unresolved root problem**.
After that:
1. stop blind retries;
2. create a Debug Packet with expected, actual, exact failure, relevant files/diff/tests, attempts, hypotheses, and evidence;
3. send it to `reviewer` for diagnosis;
4. if the remaining diagnosis is C3 — e.g. multiple plausible root causes remain — escalate a compressed packet to `expert`.

A clearly C3 problem does not need to wait for two worker failures; classify it correctly earlier.

## Step 9 — review proportionally

Review intensity follows consequence/risk, not model prestige.

- R0: deterministic validation is normally sufficient.
- R1: use `reviewer` when tests are incomplete, behavior is externally visible, or regression risk is meaningful.
- R2/R3: always use `reviewer` after validation.

Reviewer findings should focus on correctness, regressions, invariants, compatibility, edge cases, security/safety consequences, and missing validation — not style churn.

If review uncovers a C3 conceptual bottleneck, escalate that narrow problem to `expert`. Do not invoke expert merely because a finding is high severity if the fix is conceptually straightforward.

## Step 10 — stop when done

Finish when:
- acceptance criteria are satisfied;
- appropriate deterministic and risk-specific checks pass;
- required review has no unresolved BLOCKER/HIGH finding;
- any expert decision has been translated into testable implementation/validation;
- any deviation from an imported packet is explained;
- remaining uncertainty is stated explicitly.

Do not spend quota on additional exploration, redesign, or repeated review after completion gates are satisfied.

## Context budget rule

As model capability/cost increases, context should become **smaller and higher-signal**.

Preferred shape:

`raw repository -> Evidence Packet -> Plan/Debug Packet -> Decision Packet -> expert`

The strongest model should receive the hardest distilled question, not the largest context window.

# GitHub analysis -> Execution Packet prompt

Copy this prompt into ChatGPT when you want the web/ChatGPT side to analyze a repository before local Codex execution.

```text
Act as the planning stage for a later Codex implementation run.

Repository: <OWNER/REPO or GitHub URL>
Target ref/branch: <REF>
Task: <DESCRIBE THE OUTCOME>
Additional constraints: <OPTIONAL>

Use the GitHub repository as the source of truth for planning. Do not implement code and do not produce a large patch.

Before planning:
1. identify the analyzed ref and commit SHA when available;
2. read relevant repository-level instructions (AGENTS.md, README, build/test configuration) when present;
3. locate the smallest relevant code paths, symbols, tests, and data/control flow;
4. distinguish verified facts from assumptions;
5. determine whether the task is trivial, standard, complex, or critical based on uncertainty, blast radius, reversibility, compatibility, security/auth, payments, migrations, concurrency, or data-loss risk.

Optimize the handoff for a separate Codex session. The Codex session should not need to rediscover the repository unless your assumptions are stale.

Return exactly one `Execution Packet v1` using this structure:

execution_packet_version: 1
source:
  repository: <owner/repo>
  source_ref: <ref>
  source_commit: <sha or unknown>
goal: <observable outcome>
non_goals:
  - <explicit exclusions>
current_state:
  summary: <concise relevant current behavior>
  evidence:
    - path: <file>
      symbols: [<symbols>]
      why_relevant: <evidence>
constraints:
  - <invariants / compatibility / architectural constraints>
risk:
  suggested_class: R0|R1|R2|R3
  reasons:
    - <reason>
  escalation_triggers:
    - <condition that would justify deeper review/expert reasoning>
plan:
  - step: 1
    change: <concrete action>
    likely_files: [<files>]
    validation: <how to verify>
acceptance_criteria:
  - <observable criterion>
validation:
  targeted:
    - <test/build/type/lint/runtime check>
  broader_if_needed:
    - <broader check only if justified>
open_questions:
  - <only questions that materially block or alter implementation>
planner_assumptions:
  - <assumption Codex should cheaply verify>

Rules:
- Be concise and evidence-dense.
- Prefer paths/symbols over pasted source code.
- Do not paste entire files or long logs.
- Do not prescribe model names; the local workflow routes roles to models.
- Do not recommend broad redesign when a smaller change satisfies the goal.
- Do not leave routine discovery work for Codex if GitHub evidence can settle it now.
- If information is unavailable, mark it `unknown` instead of inventing it.
- If the repository has changed during analysis, use the latest verified commit and say so in the packet.
```

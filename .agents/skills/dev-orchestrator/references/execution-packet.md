# Execution Packet v1

An Execution Packet is the handoff contract between a planning environment (for example ChatGPT analyzing a GitHub repository) and Codex executing against a local checkout.

The packet should be compact enough to paste into Codex without carrying the planning conversation.

## Required structure

```yaml
execution_packet_version: 1
source:
  repository: owner/repo
  source_ref: branch-or-tag
  source_commit: full-or-short-sha-if-known

goal: >-
  The behavior or outcome to achieve.

non_goals:
  - Explicitly out-of-scope behavior.

current_state:
  summary: >-
    Concise description of the relevant current implementation.
  evidence:
    - path: path/to/file
      symbols: [SymbolName]
      why_relevant: Short evidence-based reason.

constraints:
  - Existing invariant, compatibility requirement, performance bound, etc.

risk:
  suggested_class: R0|R1|R2|R3
  reasons:
    - Why this class is justified.
  escalation_triggers:
    - Conditions that should cause a higher-tier review/expert consultation.

plan:
  - step: 1
    change: Concrete implementation action.
    likely_files: [path/to/file]
    validation: How this step/result can be verified.

acceptance_criteria:
  - Observable criterion that must be true when complete.

validation:
  targeted:
    - command or check
  broader_if_needed:
    - command or check

open_questions:
  - Only unresolved questions that materially affect implementation.

planner_assumptions:
  - Assumptions that Codex must cheaply verify before relying on the plan.
```

## Handoff rules

- Facts must be separated from assumptions.
- Prefer file paths and symbols over pasted source code.
- Do not paste large diffs, logs, or whole files unless they are the only evidence available.
- Include the source commit whenever possible so Codex can detect plan drift.
- The local checkout remains the execution source of truth.
- If the local repository materially differs from the packet's source commit, Codex should repair the stale parts of the plan rather than blindly following it.
- A packet is a plan plus evidence, not an instruction to skip local validation.
- Do not prescribe specific model names in the packet. Routing is controlled by role configuration so the packet remains reusable when models change.

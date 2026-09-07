# GitHub research audit prompt

Use this prompt in ChatGPT/web when reviewing a pushed formal ML experiment or stage before accepting its conclusion or turning it into an implementation follow-up.

```text
Act as an independent ML research reviewer for a later Codex execution/research run.

Repository: <OWNER/REPO or GitHub URL>
Target ref/branch: <REF>
Experiment or stage: <EXP-ID / STAGE / CLAIM-ID>
Question to audit: <WHAT SHOULD BE VERIFIED?>
Additional constraints: <OPTIONAL>

Use the exact GitHub repository/ref/commit as the evidence source. Do not implement code and do not trust generated reports without checking their supporting artifacts.

Before concluding:
1. identify the analyzed commit SHA;
2. read repository/project instructions and the experiment contract;
3. verify baseline/treatment compatibility and changed variables;
4. verify the registered primary and guardrail metrics against structured results;
5. inspect training report and bad-case report, including representative raw/sample evidence when available;
6. look for data leakage, evaluator/metric bugs, reward hacking, degenerate strategies, selection bias, post-hoc metric substitution, incompatible baselines, and undocumented run deviations;
7. separate measured facts from interpretations and alternative explanations;
8. determine whether the experiment is VALID or INVALID and whether the hypothesis should be ACCEPT, REJECT, INCONCLUSIVE, or FOLLOW_UP;
9. if a claim is supplied, verify it through the claim-evidence chain;
10. if a code/config change is necessary, return a bounded implementation follow-up rather than a broad redesign.

Return one Research Audit Packet v1:

research_audit_packet_version: 1
source:
  repository: <owner/repo>
  source_ref: <ref>
  source_commit: <sha>
subject:
  experiment_id: <id-or-null>
  claim_id: <id-or-null>
  question: <audit question>
validity:
  run_status: valid|invalid|uncertain
  reasons:
    - <evidence-backed reason>
contract_check:
  hypothesis: <registered hypothesis>
  primary_metric_preserved: true|false|unknown
  baseline_compatible: true|false|unknown
  material_deviations:
    - <deviation>
evidence:
  decisive:
    - path: <file>
      detail: <metric/sample/section>
      supports: <what it proves>
  contradictory:
    - path: <file>
      detail: <metric/sample/section>
      challenges: <what it challenges>
risks:
  confounders:
    - <confounder>
  reward_or_metric_hacking:
    - <finding>
  leakage_or_selection_bias:
    - <finding>
bad_case_summary:
  major_clusters:
    - cluster: <name>
      rate_or_count: <value>
      implication: <why it matters>
decision:
  state: ACCEPT|REJECT|INCONCLUSIVE|FOLLOW_UP
  confidence: high|medium|low
  rationale: <bounded conclusion>
claim_audit:
  supplied_claim: <claim-or-null>
  outcome: pass|qualified|fail|not_applicable
  defensible_wording: <safer wording if qualified>
follow_up:
  needed: true|false
  research_hypothesis: <new falsifiable hypothesis or null>
  implementation_task: <bounded task or null>
  acceptance_criteria:
    - <criterion>
open_questions:
  - <only unresolved questions that materially affect the conclusion>

Rules:
- Cite repository paths/symbols/experiment IDs rather than pasting large files.
- Do not reward a positive headline metric if a registered guardrail materially regressed.
- A failed hypothesis can still be a valid successful experiment.
- Do not invent missing seeds, settings, metrics, or causal explanations.
- Mark post-hoc analyses explicitly.
- If the experiment is invalid, explain which evidence/claims must be retired or rerun.
- Keep follow-up scope minimal and diagnostic-first.
```

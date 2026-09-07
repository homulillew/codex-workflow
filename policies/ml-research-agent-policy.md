<!-- codex-workflow:ml-research:start -->
## ML research workflow

For formal ML experiments, use the `ml-research-orchestrator` skill.

- Freeze a registered experiment contract before pilot/full compute.
- Progress through offline/smoke/pilot gates before expensive runs.
- Preserve exact config, commit, data/model/evaluator provenance.
- Require run, training, bad-case, and decision reports before declaring research completion.
- Use `dev-orchestrator` for non-trivial implementation changes, then return to the research lifecycle.
- Resume/report/interview claims must resolve to exact experiment evidence.
<!-- codex-workflow:ml-research:end -->

<!-- codex-workflow:start -->
# Codex workflow policy

Use this repository's `dev-orchestrator` skill for non-trivial software-development work.

- For tiny, obvious, low-risk edits, work directly and avoid unnecessary subagents.
- For normal work, prefer cheap specialized agents and deterministic validation over expensive-model deliberation.
- Use role names (`explorer`, `worker`, `planner`, `reviewer`, `expert`) in workflow instructions. Model selection belongs only in `.codex/agents/*.toml`.
- Use `expert` only when the orchestration skill's escalation conditions are met.
- When an Execution Packet is supplied from GitHub/web analysis, verify its source ref/commit and assumptions before executing it; do not blindly re-plan from scratch when it is still valid.
- Keep expensive-agent context small and evidence-dense.
- Preserve quality with tests, type checks, linting, targeted review, and risk-specific checks rather than by defaulting every phase to the most expensive model.
<!-- codex-workflow:end -->

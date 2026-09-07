<!-- codex-workflow:start -->
# Codex workflow policy

Use this repository's `dev-orchestrator` skill for non-trivial software-development work.

- For tiny, obvious, low-risk edits, work directly and avoid unnecessary subagents.
- For normal work, prefer cheap specialized agents and deterministic validation over expensive-model deliberation.
- Classify consequence/risk and reasoning complexity independently: risk controls safeguards/review; complexity controls model strength.
- Use role names (`explorer`, `worker`, `planner`, `reviewer`, `expert`) in workflow instructions. Model selection belongs only in `.codex/agents/*.toml`.
- Use `expert` for C3 reasoning bottlenecks such as novel algorithm/objective design, difficult competing root causes, methodology-critical decisions, or deep cross-domain synthesis. High consequence alone is not an expert trigger.
- When an Execution Packet is supplied from GitHub/web analysis, verify its source ref/commit and assumptions before executing it; do not blindly re-plan from scratch when it is still valid.
- Keep expensive-agent context small and evidence-dense; the strongest model should receive the hardest distilled question, not the largest repo dump.
- Preserve quality with tests, type checks, linting, targeted review, and risk-specific checks rather than by defaulting every phase to the strongest model.
<!-- codex-workflow:end -->

# Execute an imported GitHub plan in Codex

Paste this before the Execution Packet produced by `prompts/github-analyze.md`.

```text
$dev-orchestrator

Mode: Execute packet.

The packet below was produced from GitHub/web analysis. Treat the local checkout as the execution source of truth.

1. Verify the packet's source ref/commit against the local branch and HEAD.
2. Cheaply validate only the packet assumptions that matter to implementation.
3. If the packet is still valid, execute it without repository-wide re-analysis.
4. If it is materially stale, repair only the affected plan steps and explain the deviation.
5. Route work according to the repository's dev-orchestrator policy.
6. Prefer deterministic tests/build/type/lint checks to additional model deliberation.
7. Do not use the expert role unless the escalation criteria are actually met.
8. Finish only when acceptance criteria and the required validation/review gates are satisfied.

Execution Packet follows:

<PASTE EXECUTION PACKET HERE>
```

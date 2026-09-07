#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

CORE="$TMP/core"
RESEARCH="$TMP/research"
mkdir -p "$CORE" "$RESEARCH"

bash "$ROOT/scripts/install.sh" "$CORE"

test -f "$CORE/.agents/skills/dev-orchestrator/SKILL.md"
test ! -e "$CORE/.agents/skills/ml-research-orchestrator/SKILL.md"
test -f "$CORE/AGENTS.md"
grep -Fq '<!-- codex-workflow:start -->' "$CORE/AGENTS.md"

bash "$ROOT/scripts/install.sh" "$RESEARCH" --profile ml-research

test -f "$RESEARCH/.agents/skills/dev-orchestrator/SKILL.md"
test -f "$RESEARCH/.agents/skills/ml-research-orchestrator/SKILL.md"
test -f "$RESEARCH/.agents/skills/ml-research-orchestrator/references/experiment-contract.md"
test -f "$RESEARCH/.agents/skills/ml-research-orchestrator/references/reporting-protocol.md"
test -f "$RESEARCH/AGENTS.md"
grep -Fq '<!-- codex-workflow:ml-research:start -->' "$RESEARCH/AGENTS.md"

if git -C "$ROOT" rev-parse HEAD >/dev/null 2>&1; then
  test -f "$CORE/.codex-workflow.lock"
  test -f "$RESEARCH/.codex-workflow.lock"
  grep -Fq 'profile: "core"' "$CORE/.codex-workflow.lock"
  grep -Fq 'profile: "ml-research"' "$RESEARCH/.codex-workflow.lock"
fi

# Reinstall to verify the workflow is idempotent and does not duplicate policy blocks.
bash "$ROOT/scripts/install.sh" "$RESEARCH" --profile ml-research >/dev/null
COUNT="$(grep -Fc '<!-- codex-workflow:ml-research:start -->' "$RESEARCH/AGENTS.md")"
test "$COUNT" -eq 1

echo 'install profile tests: PASS'

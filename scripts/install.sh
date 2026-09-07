#!/usr/bin/env bash
set -euo pipefail

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${1:-.}"
TARGET="$(cd "$TARGET" && pwd)"

copy_if_missing() {
  local src="$1"
  local dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [[ -e "$dst" ]]; then
    printf 'skip: %s already exists\n' "$dst"
  else
    cp "$src" "$dst"
    printf 'copy: %s\n' "$dst"
  fi
}

printf 'Installing codex-workflow into %s\n' "$TARGET"

mkdir -p "$TARGET/.codex/agents"
for src in "$SOURCE_ROOT"/.codex/agents/*.toml; do
  copy_if_missing "$src" "$TARGET/.codex/agents/$(basename "$src")"
done

mkdir -p "$TARGET/.agents/skills/dev-orchestrator/references"
copy_if_missing \
  "$SOURCE_ROOT/.agents/skills/dev-orchestrator/SKILL.md" \
  "$TARGET/.agents/skills/dev-orchestrator/SKILL.md"
copy_if_missing \
  "$SOURCE_ROOT/.agents/skills/dev-orchestrator/references/execution-packet.md" \
  "$TARGET/.agents/skills/dev-orchestrator/references/execution-packet.md"

if [[ ! -e "$TARGET/.codex/config.toml" ]]; then
  copy_if_missing "$SOURCE_ROOT/.codex/config.toml" "$TARGET/.codex/config.toml"
else
  EXAMPLE="$TARGET/.codex/codex-workflow.config.example.toml"
  copy_if_missing "$SOURCE_ROOT/.codex/config.toml" "$EXAMPLE"
  printf 'note: existing .codex/config.toml was preserved; merge desired settings from %s\n' "$EXAMPLE"
fi

POLICY_START='<!-- codex-workflow:start -->'
POLICY_END='<!-- codex-workflow:end -->'
AGENTS_FILE="$TARGET/AGENTS.md"

if [[ ! -e "$AGENTS_FILE" ]]; then
  cp "$SOURCE_ROOT/AGENTS.md" "$AGENTS_FILE"
  printf 'copy: %s\n' "$AGENTS_FILE"
elif grep -Fq "$POLICY_START" "$AGENTS_FILE"; then
  printf 'skip: workflow policy already present in %s\n' "$AGENTS_FILE"
else
  cat >> "$AGENTS_FILE" <<'EOF'

<!-- codex-workflow:start -->
## Codex quota-efficient workflow

For non-trivial software-development tasks, use the `dev-orchestrator` skill. Prefer role-based routing, compact context handoffs, and deterministic validation. Use the `expert` role only when the skill's escalation conditions are met. When an Execution Packet is supplied from GitHub/web analysis, verify its source commit and assumptions before executing it rather than blindly re-planning the repository.
<!-- codex-workflow:end -->
EOF
  printf 'append: workflow policy to %s\n' "$AGENTS_FILE"
fi

cat <<'EOF'

Installed.

Recommended usage:
  $dev-orchestrator <your non-trivial task>

For GitHub-first planning, use prompts/github-analyze.md from the codex-workflow repository,
then paste the resulting Execution Packet after prompts/codex-execute.md in local Codex.
EOF

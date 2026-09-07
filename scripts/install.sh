#!/usr/bin/env bash
set -euo pipefail

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="."
PROFILE="core"
TARGET_SET=0

usage() {
  cat <<'EOF'
Usage:
  bash scripts/install.sh [TARGET] [--profile core|ml-research]

Profiles:
  core         Install dev-orchestrator only (default).
  ml-research  Install dev-orchestrator + ml-research-orchestrator and research policy.

Examples:
  bash scripts/install.sh /path/to/project
  bash scripts/install.sh /path/to/project --profile ml-research
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      if [[ $# -lt 2 ]]; then
        printf 'error: --profile requires a value\n' >&2
        exit 2
      fi
      PROFILE="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      if [[ "$TARGET_SET" -eq 1 ]]; then
        printf 'error: unexpected argument: %s\n' "$1" >&2
        usage >&2
        exit 2
      fi
      TARGET="$1"
      TARGET_SET=1
      shift
      ;;
  esac
done

case "$PROFILE" in
  core|ml-research) ;;
  *)
    printf 'error: unknown profile: %s\n' "$PROFILE" >&2
    usage >&2
    exit 2
    ;;
esac

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

copy_tree_if_missing() {
  local src_root="$1"
  local dst_root="$2"
  while IFS= read -r -d '' src; do
    local rel="${src#"$src_root"/}"
    copy_if_missing "$src" "$dst_root/$rel"
  done < <(find "$src_root" -type f -print0)
}

append_block_if_missing() {
  local file="$1"
  local marker="$2"
  local content="$3"
  if grep -Fq "$marker" "$file"; then
    printf 'skip: policy block already present in %s\n' "$file"
  else
    printf '\n%s\n' "$content" >> "$file"
    printf 'append: policy block to %s\n' "$file"
  fi
}

printf 'Installing codex-workflow profile=%s into %s\n' "$PROFILE" "$TARGET"

mkdir -p "$TARGET/.codex/agents"
for src in "$SOURCE_ROOT"/.codex/agents/*.toml; do
  copy_if_missing "$src" "$TARGET/.codex/agents/$(basename "$src")"
done

copy_tree_if_missing \
  "$SOURCE_ROOT/.agents/skills/dev-orchestrator" \
  "$TARGET/.agents/skills/dev-orchestrator"

if [[ "$PROFILE" == "ml-research" ]]; then
  copy_tree_if_missing \
    "$SOURCE_ROOT/.agents/skills/ml-research-orchestrator" \
    "$TARGET/.agents/skills/ml-research-orchestrator"
fi

if [[ ! -e "$TARGET/.codex/config.toml" ]]; then
  copy_if_missing "$SOURCE_ROOT/.codex/config.toml" "$TARGET/.codex/config.toml"
else
  EXAMPLE="$TARGET/.codex/codex-workflow.config.example.toml"
  copy_if_missing "$SOURCE_ROOT/.codex/config.toml" "$EXAMPLE"
  printf 'note: existing .codex/config.toml was preserved; merge desired settings from %s\n' "$EXAMPLE"
fi

POLICY_START='<!-- codex-workflow:start -->'
AGENTS_FILE="$TARGET/AGENTS.md"

if [[ ! -e "$AGENTS_FILE" ]]; then
  cp "$SOURCE_ROOT/AGENTS.md" "$AGENTS_FILE"
  printf 'copy: %s\n' "$AGENTS_FILE"
elif grep -Fq "$POLICY_START" "$AGENTS_FILE"; then
  printf 'skip: workflow policy already present in %s\n' "$AGENTS_FILE"
else
  BASE_POLICY='<!-- codex-workflow:start -->
## Codex quota-efficient workflow

For non-trivial software-development tasks, use the `dev-orchestrator` skill. Prefer role-based routing, compact context handoffs, and deterministic validation. Use the `expert` role only when the skill'
  BASE_POLICY+="'s escalation conditions are met. When an Execution Packet is supplied from GitHub/web analysis, verify its source commit and assumptions before executing it rather than blindly re-planning the repository."
  BASE_POLICY+=$'\n<!-- codex-workflow:end -->'
  append_block_if_missing "$AGENTS_FILE" "$POLICY_START" "$BASE_POLICY"
fi

if [[ "$PROFILE" == "ml-research" ]]; then
  RESEARCH_MARKER='<!-- codex-workflow:ml-research:start -->'
  RESEARCH_POLICY='<!-- codex-workflow:ml-research:start -->
## ML research workflow

For formal ML experiments, use the `ml-research-orchestrator` skill. Freeze a registered experiment contract before pilot/full compute; progress through offline/smoke/pilot gates; preserve exact config/commit/data/model provenance; and require run/training/bad-case/decision reports before declaring research completion. Use `dev-orchestrator` for non-trivial implementation changes, then return to the research lifecycle. Resume/report/interview claims must be linked to exact experiment evidence.
<!-- codex-workflow:ml-research:end -->'
  append_block_if_missing "$AGENTS_FILE" "$RESEARCH_MARKER" "$RESEARCH_POLICY"
fi

# Record which workflow revision/profile initialized the project when the source is a Git checkout.
WORKFLOW_COMMIT="$(git -C "$SOURCE_ROOT" rev-parse HEAD 2>/dev/null || true)"
WORKFLOW_ORIGIN="$(git -C "$SOURCE_ROOT" remote get-url origin 2>/dev/null || true)"
WORKFLOW_DIRTY="false"
if [[ -n "$WORKFLOW_COMMIT" ]] && ! git -C "$SOURCE_ROOT" diff --quiet --ignore-submodules -- 2>/dev/null; then
  WORKFLOW_DIRTY="true"
fi

LOCK_FILE="$TARGET/.codex-workflow.lock"
if [[ -n "$WORKFLOW_COMMIT" ]]; then
  if [[ -e "$LOCK_FILE" ]]; then
    printf 'skip: workflow lock already exists at %s\n' "$LOCK_FILE"
  else
    cat > "$LOCK_FILE" <<EOF
workflow_repository: "${WORKFLOW_ORIGIN:-unknown}"
workflow_commit: "$WORKFLOW_COMMIT"
profile: "$PROFILE"
source_dirty: $WORKFLOW_DIRTY
EOF
    printf 'create: %s\n' "$LOCK_FILE"
  fi
else
  printf 'note: source is not a Git checkout; workflow lock was not written\n'
fi

cat <<EOF

Installed profile: $PROFILE

Recommended usage:
  \$dev-orchestrator <your non-trivial implementation task>
EOF

if [[ "$PROFILE" == "ml-research" ]]; then
  cat <<'EOF'
  $ml-research-orchestrator <design/run/analyze/audit a formal ML experiment>

For GitHub-first independent research audit, use prompts/github-research-audit.md
from the codex-workflow repository. If that audit identifies a code change, convert
it into a bounded Execution Packet and execute it through dev-orchestrator.
EOF
else
  cat <<'EOF'

For GitHub-first planning, use prompts/github-analyze.md from the codex-workflow repository,
then paste the resulting Execution Packet after prompts/codex-execute.md in local Codex.
EOF
fi

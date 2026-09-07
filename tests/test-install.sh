#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

CORE="$TMP/core"
RESEARCH="$TMP/research"
UPGRADE="$TMP/upgrade"
LEGACY="$TMP/legacy"
mkdir -p "$CORE" "$RESEARCH" "$UPGRADE" "$LEGACY"

hash_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

# Fresh core install.
bash "$ROOT/scripts/install.sh" "$CORE"

test -f "$CORE/.agents/skills/dev-orchestrator/SKILL.md"
test ! -e "$CORE/.agents/skills/ml-research-orchestrator/SKILL.md"
test -f "$CORE/.codex-workflow.lock"
test -f "$CORE/.codex-workflow.manifest"
test -f "$CORE/.codex/config.toml"
test -f "$CORE/.codex/codex-workflow.config.example.toml"
grep -Fq 'lock_version: 2' "$CORE/.codex-workflow.lock"
grep -Fq 'profile: "core"' "$CORE/.codex-workflow.lock"
grep -Fq '.agents/skills/dev-orchestrator/SKILL.md' "$CORE/.codex-workflow.manifest"
grep -Fq '<!-- codex-workflow:start -->' "$CORE/AGENTS.md"

# Fresh research install.
bash "$ROOT/scripts/install.sh" "$RESEARCH" --profile ml-research

test -f "$RESEARCH/.agents/skills/dev-orchestrator/SKILL.md"
test -f "$RESEARCH/.agents/skills/ml-research-orchestrator/SKILL.md"
test -f "$RESEARCH/.agents/skills/ml-research-orchestrator/references/experiment-contract.md"
grep -Fq 'profile: "ml-research"' "$RESEARCH/.codex-workflow.lock"
grep -Fq '<!-- codex-workflow:ml-research:start -->' "$RESEARCH/AGENTS.md"

# Re-running install is idempotent and explicitly asks callers to use upgrade.
INSTALL_AGAIN="$(bash "$ROOT/scripts/install.sh" "$RESEARCH" --profile ml-research)"
printf '%s' "$INSTALL_AGAIN" | grep -Fq 'Use --upgrade'
COUNT="$(grep -Fc '<!-- codex-workflow:ml-research:start -->' "$RESEARCH/AGENTS.md")"
test "$COUNT" -eq 1

# Upgrade preserves project-owned config and AGENTS content outside managed blocks.
printf '\n# project-owned-setting\n' >> "$RESEARCH/.codex/config.toml"
printf '\n# project-local-policy\n' >> "$RESEARCH/AGENTS.md"
bash "$ROOT/scripts/update.sh" "$RESEARCH"

grep -Fq '# project-owned-setting' "$RESEARCH/.codex/config.toml"
grep -Fq '# project-local-policy' "$RESEARCH/AGENTS.md"
COUNT="$(grep -Fc '<!-- codex-workflow:ml-research:start -->' "$RESEARCH/AGENTS.md")"
test "$COUNT" -eq 1

# Managed-file divergence blocks upgrade.
printf '\n# local managed edit\n' >> "$RESEARCH/.agents/skills/dev-orchestrator/SKILL.md"
if bash "$ROOT/scripts/update.sh" "$RESEARCH" >"$TMP/drift.out" 2>&1; then
  echo 'expected managed divergence to block upgrade' >&2
  exit 1
fi
grep -Fq 'locally modified workflow-owned files' "$TMP/drift.out"
grep -Fq '.agents/skills/dev-orchestrator/SKILL.md' "$TMP/drift.out"

# Explicit force accepts upstream for managed files only.
bash "$ROOT/scripts/update.sh" "$RESEARCH" --force-managed
test "$(hash_file "$RESEARCH/.agents/skills/dev-orchestrator/SKILL.md")" = \
     "$(hash_file "$ROOT/.agents/skills/dev-orchestrator/SKILL.md")"
grep -Fq '# project-owned-setting' "$RESEARCH/.codex/config.toml"

# Obsolete managed files are removed only if their recorded hash still matches.
mkdir -p "$RESEARCH/.agents/skills/dev-orchestrator/references"
printf 'obsolete\n' > "$RESEARCH/.agents/skills/dev-orchestrator/references/obsolete-test.md"
OBSOLETE_HASH="$(hash_file "$RESEARCH/.agents/skills/dev-orchestrator/references/obsolete-test.md")"
printf '%s\t%s\n' \
  '.agents/skills/dev-orchestrator/references/obsolete-test.md' \
  "$OBSOLETE_HASH" >> "$RESEARCH/.codex-workflow.manifest"
bash "$ROOT/scripts/update.sh" "$RESEARCH"
test ! -e "$RESEARCH/.agents/skills/dev-orchestrator/references/obsolete-test.md"

# Explicit core -> ml-research profile promotion.
bash "$ROOT/scripts/install.sh" "$UPGRADE"
bash "$ROOT/scripts/update.sh" "$UPGRADE" --profile ml-research
test -f "$UPGRADE/.agents/skills/ml-research-orchestrator/SKILL.md"
grep -Fq 'profile: "ml-research"' "$UPGRADE/.codex-workflow.lock"
grep -Fq '<!-- codex-workflow:ml-research:start -->' "$UPGRADE/AGENTS.md"

# Implicit profile retention on later upgrades.
bash "$ROOT/scripts/update.sh" "$UPGRADE"
grep -Fq 'profile: "ml-research"' "$UPGRADE/.codex-workflow.lock"

# Automatic profile downgrade is refused.
if bash "$ROOT/scripts/update.sh" "$UPGRADE" --profile core >"$TMP/downgrade.out" 2>&1; then
  echo 'expected ml-research -> core downgrade to be refused' >&2
  exit 1
fi
grep -Fq 'automatic profile downgrade' "$TMP/downgrade.out"

# Legacy v1 lock migration: reconstruct ownership from the recorded commit.
bash "$ROOT/scripts/install.sh" "$LEGACY" --profile ml-research
CURRENT_COMMIT="$(git -C "$ROOT" rev-parse HEAD)"
rm -f "$LEGACY/.codex-workflow.manifest"
cat > "$LEGACY/.codex-workflow.lock" <<EOF
workflow_repository: "legacy-test"
workflow_commit: "$CURRENT_COMMIT"
profile: "ml-research"
source_dirty: false
EOF

bash "$ROOT/scripts/update.sh" "$LEGACY"
test -f "$LEGACY/.codex-workflow.manifest"
grep -Fq 'lock_version: 2' "$LEGACY/.codex-workflow.lock"
grep -Fq 'profile: "ml-research"' "$LEGACY/.codex-workflow.lock"

echo 'install/upgrade tests: PASS'

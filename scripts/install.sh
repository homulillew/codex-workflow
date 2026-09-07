#!/usr/bin/env bash
set -euo pipefail

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="."
TARGET_SET=0
PROFILE="core"
PROFILE_SET=0
MODE="install"
ALLOW_DIRTY_SOURCE=0
FORCE_MANAGED=0

usage() {
  cat <<'EOF'
Usage:
  bash scripts/install.sh [TARGET] [--profile core|ml-research]
  bash scripts/install.sh [TARGET] --upgrade [--profile core|ml-research]
  bash scripts/install.sh --version

Modes:
  install      Bootstrap codex-workflow into a project. If already installed, make no changes.
  --upgrade    Upgrade workflow-owned files from the current source checkout.

Profiles:
  core         Install dev-orchestrator only.
  ml-research  Install dev-orchestrator + ml-research-orchestrator.

Safety:
  - Project-owned files are preserved.
  - Workflow-owned files are tracked in .codex-workflow.manifest.
  - Upgrade refuses to overwrite locally modified managed files unless --force-managed is explicit.
  - Upgrade keeps the installed profile unless --profile is supplied.
  - Downgrading ml-research -> core is refused.

Options:
  --allow-dirty-source  Permit install/upgrade from a dirty workflow checkout. The lock records it.
  --force-managed       Overwrite locally modified workflow-owned files during upgrade.
  -h, --help            Show this help.
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
      PROFILE_SET=1
      shift 2
      ;;
    --upgrade)
      MODE="upgrade"
      shift
      ;;
    --allow-dirty-source)
      ALLOW_DIRTY_SOURCE=1
      shift
      ;;
    --force-managed)
      FORCE_MANAGED=1
      shift
      ;;
    --version)
      VERSION="unknown"
      if [[ -f "$SOURCE_ROOT/VERSION" ]]; then
        VERSION="$(tr -d '[:space:]' < "$SOURCE_ROOT/VERSION")"
      fi
      COMMIT="$(git -C "$SOURCE_ROOT" rev-parse HEAD 2>/dev/null || true)"
      printf 'codex-workflow %s%s\n' "$VERSION" "${COMMIT:+ ($COMMIT)}"
      exit 0
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

if [[ ! -d "$TARGET" ]]; then
  printf 'error: target directory does not exist: %s\n' "$TARGET" >&2
  exit 2
fi
TARGET="$(cd "$TARGET" && pwd)"

LOCK_FILE="$TARGET/.codex-workflow.lock"
MANIFEST_FILE="$TARGET/.codex-workflow.manifest"
CONFIG_EXAMPLE_REL=".codex/codex-workflow.config.example.toml"

WORKFLOW_VERSION="unknown"
if [[ -f "$SOURCE_ROOT/VERSION" ]]; then
  WORKFLOW_VERSION="$(tr -d '[:space:]' < "$SOURCE_ROOT/VERSION")"
fi
WORKFLOW_COMMIT="$(git -C "$SOURCE_ROOT" rev-parse HEAD 2>/dev/null || true)"
WORKFLOW_ORIGIN="$(git -C "$SOURCE_ROOT" remote get-url origin 2>/dev/null || true)"
WORKFLOW_DIRTY="false"
if [[ -n "$WORKFLOW_COMMIT" ]] && [[ -n "$(git -C "$SOURCE_ROOT" status --porcelain 2>/dev/null || true)" ]]; then
  WORKFLOW_DIRTY="true"
fi

if [[ "$WORKFLOW_DIRTY" == "true" && "$ALLOW_DIRTY_SOURCE" -ne 1 ]]; then
  printf 'error: codex-workflow source checkout is dirty.\n' >&2
  printf 'Commit/stash changes first, or pass --allow-dirty-source explicitly.\n' >&2
  exit 2
fi

sha256_file() {
  local file="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | awk '{print $1}'
  else
    printf 'error: sha256sum or shasum is required\n' >&2
    exit 2
  fi
}

sha256_stream() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | awk '{print $1}'
  else
    printf 'error: sha256sum or shasum is required\n' >&2
    exit 2
  fi
}

yaml_quote() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '"%s"' "$value"
}

read_lock_value() {
  local key="$1"
  local line value
  line="$(grep -E "^${key}:" "$LOCK_FILE" 2>/dev/null | head -n 1 || true)"
  [[ -n "$line" ]] || return 1
  value="${line#*:}"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  if [[ "$value" == \"*\" && "$value" == *\" ]]; then
    value="${value:1:${#value}-2}"
  fi
  printf '%s' "$value"
}

array_contains() {
  local needle="$1"
  shift
  local item
  for item in "$@"; do
    if [[ "$item" == "$needle" ]]; then
      return 0
    fi
  done
  return 1
}

source_for_rel() {
  local rel="$1"
  if [[ "$rel" == "$CONFIG_EXAMPLE_REL" ]]; then
    printf '%s/.codex/config.toml' "$SOURCE_ROOT"
  else
    printf '%s/%s' "$SOURCE_ROOT" "$rel"
  fi
}

build_desired_paths() {
  DESIRED_PATHS=()
  local src rel
  for src in "$SOURCE_ROOT"/.codex/agents/*.toml; do
    [[ -f "$src" ]] || continue
    rel="${src#"$SOURCE_ROOT"/}"
    DESIRED_PATHS+=("$rel")
  done

  while IFS= read -r src; do
    [[ -n "$src" ]] || continue
    rel="${src#"$SOURCE_ROOT"/}"
    DESIRED_PATHS+=("$rel")
  done < <(find "$SOURCE_ROOT/.agents/skills/dev-orchestrator" -type f | LC_ALL=C sort)

  if [[ "$PROFILE" == "ml-research" ]]; then
    while IFS= read -r src; do
      [[ -n "$src" ]] || continue
      rel="${src#"$SOURCE_ROOT"/}"
      DESIRED_PATHS+=("$rel")
    done < <(find "$SOURCE_ROOT/.agents/skills/ml-research-orchestrator" -type f | LC_ALL=C sort)
  fi

  DESIRED_PATHS+=("$CONFIG_EXAMPLE_REL")
}

write_file_from_source() {
  local rel="$1"
  local src
  src="$(source_for_rel "$rel")"
  mkdir -p "$(dirname "$TARGET/$rel")"
  cp "$src" "$TARGET/$rel"
}

extract_block() {
  local file="$1"
  local start="$2"
  local end="$3"
  awk -v start="$start" -v end="$end" '
    $0 == start {printing=1}
    printing {print}
    $0 == end && printing {exit}
  ' "$file"
}

upsert_block() {
  local file="$1"
  local start="$2"
  local end="$3"
  local block_file="$4"
  local tmp
  mkdir -p "$(dirname "$file")"
  [[ -e "$file" ]] || : > "$file"

  if grep -Fqx "$start" "$file"; then
    if ! grep -Fqx "$end" "$file"; then
      printf 'error: managed block starts but does not end in %s: %s\n' "$file" "$start" >&2
      exit 2
    fi
    tmp="$(mktemp)"
    awk -v start="$start" -v end="$end" -v repl="$block_file" '
      $0 == start {
        while ((getline line < repl) > 0) print line
        close(repl)
        skipping=1
        next
      }
      skipping && $0 == end {
        skipping=0
        next
      }
      !skipping {print}
    ' "$file" > "$tmp"
    mv "$tmp" "$file"
  else
    if [[ -s "$file" ]]; then
      printf '\n' >> "$file"
    fi
    cat "$block_file" >> "$file"
    printf '\n' >> "$file"
  fi
}

apply_agent_policies() {
  local core_start='<!-- codex-workflow:start -->'
  local core_end='<!-- codex-workflow:end -->'
  local research_start='<!-- codex-workflow:ml-research:start -->'
  local research_end='<!-- codex-workflow:ml-research:end -->'
  local core_tmp research_policy
  core_tmp="$(mktemp)"
  extract_block "$SOURCE_ROOT/AGENTS.md" "$core_start" "$core_end" > "$core_tmp"
  if [[ ! -s "$core_tmp" ]]; then
    printf 'error: core AGENTS policy block is missing from source AGENTS.md\n' >&2
    rm -f "$core_tmp"
    exit 2
  fi
  upsert_block "$TARGET/AGENTS.md" "$core_start" "$core_end" "$core_tmp"
  rm -f "$core_tmp"

  if [[ "$PROFILE" == "ml-research" ]]; then
    research_policy="$SOURCE_ROOT/policies/ml-research-agent-policy.md"
    if [[ ! -f "$research_policy" ]]; then
      printf 'error: missing research policy: %s\n' "$research_policy" >&2
      exit 2
    fi
    upsert_block "$TARGET/AGENTS.md" "$research_start" "$research_end" "$research_policy"
  fi
}

write_manifest() {
  local tmp rel hash
  tmp="$(mktemp)"
  printf '# codex-workflow managed-file manifest v1\n' > "$tmp"
  printf '# path<TAB>sha256\n' >> "$tmp"
  for rel in "${DESIRED_PATHS[@]}"; do
    hash="$(sha256_file "$TARGET/$rel")"
    printf '%s\t%s\n' "$rel" "$hash" >> "$tmp"
  done
  mv "$tmp" "$MANIFEST_FILE"
}

write_lock() {
  local tmp
  tmp="$(mktemp)"
  {
    printf 'lock_version: 2\n'
    printf 'workflow_repository: %s\n' "$(yaml_quote "${WORKFLOW_ORIGIN:-unknown}")"
    printf 'workflow_version: %s\n' "$(yaml_quote "$WORKFLOW_VERSION")"
    printf 'workflow_commit: %s\n' "$(yaml_quote "${WORKFLOW_COMMIT:-unknown}")"
    printf 'profile: %s\n' "$(yaml_quote "$PROFILE")"
    printf 'source_dirty: %s\n' "$WORKFLOW_DIRTY"
    printf 'managed_manifest: %s\n' "$(yaml_quote ".codex-workflow.manifest")"
  } > "$tmp"
  mv "$tmp" "$LOCK_FILE"
}

preflight_install_collisions() {
  local rel src target_hash source_hash
  local collisions=()
  for rel in "${DESIRED_PATHS[@]}"; do
    if [[ -e "$TARGET/$rel" ]]; then
      src="$(source_for_rel "$rel")"
      target_hash="$(sha256_file "$TARGET/$rel")"
      source_hash="$(sha256_file "$src")"
      if [[ "$target_hash" != "$source_hash" ]]; then
        collisions+=("$rel")
      fi
    fi
  done

  if [[ "${#collisions[@]}" -gt 0 ]]; then
    printf 'error: install would collide with existing workflow-owned paths:\n' >&2
    printf '  %s\n' "${collisions[@]}" >&2
    printf 'Move/rename those files or explicitly reconcile them before installation.\n' >&2
    exit 2
  fi
}

validate_manifest_divergence() {
  local rel installed_hash current_hash
  local divergence=()
  while IFS=$'\t' read -r rel installed_hash; do
    [[ -n "$rel" ]] || continue
    [[ "$rel" == \#* ]] && continue
    if [[ ! -f "$TARGET/$rel" ]]; then
      divergence+=("$rel (missing)")
      continue
    fi
    current_hash="$(sha256_file "$TARGET/$rel")"
    if [[ "$current_hash" != "$installed_hash" ]]; then
      divergence+=("$rel")
    fi
  done < "$MANIFEST_FILE"

  if [[ "${#divergence[@]}" -gt 0 && "$FORCE_MANAGED" -ne 1 ]]; then
    printf 'error: locally modified workflow-owned files detected:\n' >&2
    printf '  %s\n' "${divergence[@]}" >&2
    printf 'Resolve/revert these changes, or pass --force-managed to accept the upstream workflow copy.\n' >&2
    exit 2
  fi
}

validate_v1_lock_divergence() {
  local old_commit="$1"
  local old_profile="$2"
  local path target_hash old_hash
  local paths=()
  local divergence=()

  if [[ -z "$old_commit" || "$old_commit" == "unknown" ]]; then
    printf 'error: legacy lock has no usable workflow_commit; cannot safely migrate.\n' >&2
    exit 2
  fi
  if ! git -C "$SOURCE_ROOT" cat-file -e "${old_commit}^{commit}" 2>/dev/null; then
    printf 'error: legacy workflow commit %s is not available in this checkout.\n' "$old_commit" >&2
    printf 'Fetch repository history or reinstall after manually reconciling managed files.\n' >&2
    exit 2
  fi

  while IFS= read -r path; do
    [[ -n "$path" ]] && paths+=("$path")
  done < <(git -C "$SOURCE_ROOT" ls-tree -r --name-only "$old_commit" -- \
    .codex/agents .agents/skills/dev-orchestrator)

  if [[ "$old_profile" == "ml-research" ]]; then
    while IFS= read -r path; do
      [[ -n "$path" ]] && paths+=("$path")
    done < <(git -C "$SOURCE_ROOT" ls-tree -r --name-only "$old_commit" -- \
      .agents/skills/ml-research-orchestrator)
  fi

  for path in "${paths[@]}"; do
    if [[ ! -f "$TARGET/$path" ]]; then
      divergence+=("$path (missing)")
      continue
    fi
    target_hash="$(sha256_file "$TARGET/$path")"
    old_hash="$(git -C "$SOURCE_ROOT" show "$old_commit:$path" | sha256_stream)"
    if [[ "$target_hash" != "$old_hash" ]]; then
      divergence+=("$path")
    fi
  done

  if [[ "${#divergence[@]}" -gt 0 && "$FORCE_MANAGED" -ne 1 ]]; then
    printf 'error: legacy installation contains locally modified workflow-owned files:\n' >&2
    printf '  %s\n' "${divergence[@]}" >&2
    printf 'Resolve/revert these changes, or pass --force-managed to accept the upstream workflow copy.\n' >&2
    exit 2
  fi
}

remove_obsolete_manifest_files() {
  local rel hash
  [[ -f "$MANIFEST_FILE" ]] || return 0
  while IFS=$'\t' read -r rel hash; do
    [[ -n "$rel" ]] || continue
    [[ "$rel" == \#* ]] && continue
    if ! array_contains "$rel" "${DESIRED_PATHS[@]}"; then
      rm -f "$TARGET/$rel"
      printf 'remove managed: %s\n' "$TARGET/$rel"
    fi
  done < "$MANIFEST_FILE"
}

OLD_PROFILE=""
OLD_COMMIT=""
if [[ -f "$LOCK_FILE" ]]; then
  OLD_PROFILE="$(read_lock_value profile || true)"
  OLD_COMMIT="$(read_lock_value workflow_commit || true)"
fi

if [[ "$MODE" == "install" && -f "$LOCK_FILE" ]]; then
  printf 'codex-workflow is already installed in %s.\n' "$TARGET"
  printf 'Installed profile: %s\n' "${OLD_PROFILE:-unknown}"
  printf 'Use --upgrade to update workflow-owned files.\n'
  exit 0
fi

if [[ "$MODE" == "upgrade" ]]; then
  if [[ ! -f "$LOCK_FILE" ]]; then
    printf 'error: --upgrade requires an existing .codex-workflow.lock\n' >&2
    exit 2
  fi
  if [[ "$PROFILE_SET" -eq 0 ]]; then
    PROFILE="${OLD_PROFILE:-core}"
  fi
  case "$PROFILE" in
    core|ml-research) ;;
    *)
      printf 'error: invalid profile read from lock: %s\n' "$PROFILE" >&2
      exit 2
      ;;
  esac
  if [[ "$OLD_PROFILE" == "ml-research" && "$PROFILE" == "core" ]]; then
    printf 'error: automatic profile downgrade ml-research -> core is refused.\n' >&2
    printf 'Remove research-managed files/policy explicitly if a downgrade is truly intended.\n' >&2
    exit 2
  fi
fi

build_desired_paths

if [[ "$MODE" == "install" ]]; then
  preflight_install_collisions
  printf 'Installing codex-workflow %s profile=%s into %s\n' "$WORKFLOW_VERSION" "$PROFILE" "$TARGET"

  local_rel=""
  for local_rel in "${DESIRED_PATHS[@]}"; do
    write_file_from_source "$local_rel"
    printf 'install managed: %s\n' "$TARGET/$local_rel"
  done

  if [[ ! -e "$TARGET/.codex/config.toml" ]]; then
    mkdir -p "$TARGET/.codex"
    cp "$SOURCE_ROOT/.codex/config.toml" "$TARGET/.codex/config.toml"
    printf 'create project config: %s\n' "$TARGET/.codex/config.toml"
  else
    printf 'preserve project config: %s\n' "$TARGET/.codex/config.toml"
  fi

  apply_agent_policies
  write_manifest
  write_lock
else
  printf 'Upgrading codex-workflow in %s\n' "$TARGET"
  if [[ -f "$MANIFEST_FILE" ]]; then
    validate_manifest_divergence
  else
    validate_v1_lock_divergence "$OLD_COMMIT" "${OLD_PROFILE:-core}"
  fi

  remove_obsolete_manifest_files

  local_rel=""
  for local_rel in "${DESIRED_PATHS[@]}"; do
    write_file_from_source "$local_rel"
    printf 'update managed: %s\n' "$TARGET/$local_rel"
  done

  # Project config is intentionally not workflow-owned after bootstrap.
  if [[ ! -e "$TARGET/.codex/config.toml" ]]; then
    mkdir -p "$TARGET/.codex"
    cp "$SOURCE_ROOT/.codex/config.toml" "$TARGET/.codex/config.toml"
    printf 'create missing project config: %s\n' "$TARGET/.codex/config.toml"
  else
    printf 'preserve project config: %s\n' "$TARGET/.codex/config.toml"
  fi

  apply_agent_policies
  write_manifest
  write_lock
fi

cat <<EOF

Complete.
  mode: $MODE
  profile: $PROFILE
  workflow_version: $WORKFLOW_VERSION
  workflow_commit: ${WORKFLOW_COMMIT:-unknown}
  lock: $LOCK_FILE
  manifest: $MANIFEST_FILE

Recommended usage:
  \$dev-orchestrator <your non-trivial implementation task>
EOF

if [[ "$PROFILE" == "ml-research" ]]; then
  cat <<'EOF'
  $ml-research-orchestrator <design/run/analyze/audit a formal ML experiment>
EOF
fi

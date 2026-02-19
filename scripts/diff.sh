#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# --- Exclude lists (runtime data, not config) ---

CLAUDE_EXCLUDES=(
  .git/
  .DS_Store
  debug/
  projects/
  teams/
  tasks/
  todos/
  cache/
  file-history/
  session-env/
  shell-snapshots/
  paste-cache/
  telemetry/
  backups/
  ide/
  plans/
  history.jsonl
  stats-cache.json
  plugins/cache/
  plugins/known_marketplaces.json
  plugins/marketplaces/
  commands/
  docs/
  team/
  settings.local.json
)

CURSOR_EXCLUDES=(
  .git/
  .DS_Store
  extensions/
  projects/
  ai-tracking/
  snapshots/
  ide_state.json
  argv.json
  unified_repo_list.json
  worktrees/
  blocklist
  .deploy-version
  docs/
  skills/
)

# --- Defaults ---
CLAUDE_ONLY=false
CURSOR_ONLY=false

usage() {
  cat <<'EOF'
Usage: diff.sh [OPTIONS]

Show differences between the repo config and the live environment.

Options:
  --claude-only    Compare only .claude/
  --cursor-only    Compare only .cursor/
  -h, --help       Show this help message
EOF
  exit 0
}

# --- Parse flags ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --claude-only) CLAUDE_ONLY=true; shift ;;
    --cursor-only) CURSOR_ONLY=true; shift ;;
    -h|--help)     usage ;;
    *)             echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if $CLAUDE_ONLY && $CURSOR_ONLY; then
  echo "Error: --claude-only and --cursor-only are mutually exclusive." >&2
  exit 1
fi

# --- Helpers ---

DIFF_FOUND=false

# Check if a path matches any exclude pattern
is_excluded() {
  local rel_path="$1"
  shift
  local excludes=("$@")

  for pattern in "${excludes[@]}"; do
    # Directory excludes end with /
    if [[ "$pattern" == */ ]]; then
      local dir_pattern="${pattern%/}"
      # Match at start: dir_pattern/... or dir_pattern exactly
      if [[ "$rel_path" == "$dir_pattern"/* || "$rel_path" == "$dir_pattern" ]]; then
        return 0
      fi
      # Match nested: .../dir_pattern/...
      if [[ "$rel_path" == */"$dir_pattern"/* || "$rel_path" == */"$dir_pattern" ]]; then
        return 0
      fi
    else
      # File or glob pattern - match exact or as final component
      if [[ "$rel_path" == "$pattern" ]]; then
        return 0
      fi
      if [[ "$rel_path" == */"$pattern" ]]; then
        return 0
      fi
    fi
  done
  return 1
}

# Collect non-excluded files from a directory
collect_files() {
  local base_dir="$1"
  shift
  local excludes=("$@")
  local files=()

  if [[ ! -d "$base_dir" ]]; then
    return
  fi

  while IFS= read -r -d '' file; do
    local rel="${file#"$base_dir"/}"
    if ! is_excluded "$rel" "${excludes[@]}"; then
      files+=("$rel")
    fi
  done < <(/usr/bin/find "$base_dir" -type f -print0 2>/dev/null)

  printf '%s\n' "${files[@]}" | sort
}

# Resolve a file path (follow symlinks for content comparison)
resolve_file() {
  local file="$1"
  if [[ -L "$file" ]]; then
    local target
    target="$(readlink -f "$file" 2>/dev/null || /usr/bin/readlink "$file")"
    if [[ -f "$target" ]]; then
      echo "$target"
      return
    fi
  fi
  echo "$file"
}

# Compare two directories and report differences
compare_dir() {
  local label="$1"
  local repo_base="$2"
  local live_base="$3"
  shift 3
  local excludes=("$@")

  echo "--- $label ---"
  echo ""

  if [[ ! -d "$repo_base" ]]; then
    echo "  Repo directory not found: $repo_base"
    echo ""
    return
  fi
  if [[ ! -d "$live_base" ]]; then
    echo "  Live directory not found: $live_base"
    DIFF_FOUND=true
    echo ""
    return
  fi

  local repo_files live_files
  repo_files="$(collect_files "$repo_base" "${excludes[@]}")"
  live_files="$(collect_files "$live_base" "${excludes[@]}")"

  local changed=0
  local repo_only=0
  local live_only=0

  # Files in repo
  while IFS= read -r rel; do
    [[ -z "$rel" ]] && continue
    local repo_file="$repo_base/$rel"
    local live_file="$live_base/$rel"

    if [[ ! -f "$live_file" ]]; then
      echo "  REPO ONLY  $rel"
      repo_only=$((repo_only + 1))
      DIFF_FOUND=true
    else
      local resolved_repo resolved_live
      resolved_repo="$(resolve_file "$repo_file")"
      resolved_live="$(resolve_file "$live_file")"
      if ! diff -q "$resolved_repo" "$resolved_live" >/dev/null 2>&1; then
        echo "  CHANGED    $rel"
        changed=$((changed + 1))
        DIFF_FOUND=true
      fi
    fi
  done <<< "$repo_files"

  # Files only in live
  while IFS= read -r rel; do
    [[ -z "$rel" ]] && continue
    local repo_file="$repo_base/$rel"
    if [[ ! -f "$repo_file" ]]; then
      echo "  LIVE ONLY  $rel"
      live_only=$((live_only + 1))
      DIFF_FOUND=true
    fi
  done <<< "$live_files"

  local total=$((changed + repo_only + live_only))
  if [[ $total -eq 0 ]]; then
    echo "  (in sync)"
  else
    echo ""
    echo "  Summary: $changed changed, $repo_only repo-only, $live_only live-only"
  fi
  echo ""
}

# --- Main ---

echo "=== dotfiles diff ==="
echo ""

if ! $CURSOR_ONLY; then
  compare_dir ".claude" "$REPO_DIR/.claude" "$HOME/.claude" "${CLAUDE_EXCLUDES[@]}"
fi

if ! $CLAUDE_ONLY; then
  compare_dir ".cursor" "$REPO_DIR/.cursor" "$HOME/.cursor" "${CURSOR_EXCLUDES[@]}"
fi

# --- Final summary ---
if $DIFF_FOUND; then
  echo "=> Differences found."
  exit 1
else
  echo "=> Everything in sync."
  exit 0
fi

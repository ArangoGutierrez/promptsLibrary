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
Usage: capture.sh [OPTIONS]

Capture config files from ~/.claude and ~/.cursor back into the repo.
Symlinked commands are resolved (copied as regular files).

Options:
  --claude-only    Capture only .claude/
  --cursor-only    Capture only .cursor/
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

run_rsync() {
  local src="$1" dest="$2"
  shift 2
  local extra_args=("$@")

  local rsync_args=(-av --itemize-changes)
  rsync_args+=("${extra_args[@]}")
  rsync_args+=("$src" "$dest")

  /usr/bin/rsync "${rsync_args[@]}"
}

# --- Capture ---

capture_claude() {
  local src="$HOME/.claude/"
  local dest="$REPO_DIR/.claude/"

  if [[ ! -d "$src" ]]; then
    echo ">> Skipping .claude/ (not found at $src)"
    return
  fi

  echo ">> Capturing .claude/"
  /bin/mkdir -p "$dest"

  local exclude_args=()
  for pattern in "${CLAUDE_EXCLUDES[@]}"; do
    exclude_args+=(--exclude "$pattern")
  done

  # Use --copy-links to resolve symlinks
  run_rsync "$src" "$dest" --copy-links "${exclude_args[@]}"
}

capture_cursor() {
  local src="$HOME/.cursor/"
  local dest="$REPO_DIR/.cursor/"

  if [[ ! -d "$src" ]]; then
    echo ">> Skipping .cursor/ (not found at $src)"
    return
  fi

  echo ">> Capturing .cursor/"
  /bin/mkdir -p "$dest"

  local exclude_args=()
  for pattern in "${CURSOR_EXCLUDES[@]}"; do
    exclude_args+=(--exclude "$pattern")
  done

  # Use --copy-links to resolve symlinks (especially for commands/)
  run_rsync "$src" "$dest" --copy-links "${exclude_args[@]}"
}

# --- Main ---

echo "=== dotfiles capture ==="
echo ""

if ! $CURSOR_ONLY; then
  capture_claude
fi
if ! $CLAUDE_ONLY; then
  capture_cursor
fi

echo ""
echo "Done. Review changes with:"
echo ""
echo "  cd $REPO_DIR"
echo "  git diff"
echo "  git diff --stat"
echo ""
echo "To see untracked files:"
echo ""
echo "  git status"
echo ""

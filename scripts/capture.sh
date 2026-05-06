#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="${REPO_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"

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
  sessions/
  audit/
  archive/
  image-cache/
  history.jsonl
  stats-cache.json
  cleanup-errors.log
  .cleaned-this-week
  audit.md
  migration.md
  proposal.md
  plugins/cache/
  plugins/known_marketplaces.json
  plugins/marketplaces/
  plugins/install-counts-cache.json
  plugins/blocklist.json
  hooks/*.bak-*
  settings.local.json
  # Home dotfile dup of capture.sh logic
  .gitignore
  # Personal design/plan docs (may reference NVIDIA-internal infra)
  docs/
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
  mcp-servers/venv/
  mcp-servers/memory.retired/
  # Personal plan docs (may reference NVIDIA-internal infra)
  plans/
  # Dynamic MemPalace-generated rule (contains personal/NVIDIA context)
  rules/active-context.mdc
  # Cursor IDE-managed sync state (timestamps only)
  skills-cursor/.cursor-managed-skills-manifest.json
  skills-cursor/.sync-manifest.json
)

# --- Public-safe excludes: NVIDIA-internal references ---
# These paths reference NVIDIA-internal tooling (MemPalace MCP,
# nvinfo-cli CLI, omnistation platform). Excluded from the public repo.

NVIDIA_CLAUDE_EXCLUDES=(
  skills/nvinfo-cli/
  skills/managing-omnistation/
  hooks/mempalace-wake.sh
  remote-settings.json
)

NVIDIA_CURSOR_EXCLUDES=(
  commands/recall.md
  commands/ingest-pr.md
  hooks/extract-learnings.sh
  hooks/inject-context.sh
  entities.json
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

parse_flags() {
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
}

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

# --- Sanitizer: scrub mixed public/private content from captured files ---

sanitize_claude() {
  local dest="$REPO_DIR/.claude"

  # 1. Strip local-scoped plugins from installed_plugins.json
  local plugins_file="$dest/plugins/installed_plugins.json"
  if [[ -f "$plugins_file" ]]; then
    local tmp
    tmp="$(/usr/bin/mktemp -t capture-sanitize.XXXXXX)"
    if /usr/bin/jq '
      .plugins |= with_entries(
        .value |= map(select(.scope != "local"))
      )
      | .plugins |= with_entries(select(.value | length > 0))
    ' "$plugins_file" > "$tmp"; then
      /bin/mv "$tmp" "$plugins_file"
    else
      echo "ERROR: sanitize installed_plugins.json failed" >&2
      /bin/rm -f "$tmp"
      return 1
    fi
  fi

  # 2. Strip mempalace-wake.sh hook entries from settings.json
  local settings_file="$dest/settings.json"
  if [[ -f "$settings_file" ]]; then
    local tmp
    tmp="$(/usr/bin/mktemp -t capture-sanitize.XXXXXX)"
    if /usr/bin/jq '
      walk(
        if type == "object" and has("hooks") and (.hooks | type) == "array"
        then .hooks |= map(select((.command // "") | endswith("mempalace-wake.sh") | not))
        else .
        end
      )
    ' "$settings_file" > "$tmp"; then
      /bin/mv "$tmp" "$settings_file"
    else
      echo "ERROR: sanitize settings.json failed" >&2
      /bin/rm -f "$tmp"
      return 1
    fi
  fi

  # 3. Strip the ## Memory section from CLAUDE.md (NVIDIA-internal MemPalace block)
  local claude_md="$dest/CLAUDE.md"
  if [[ -f "$claude_md" ]]; then
    local tmp
    tmp="$(/usr/bin/mktemp -t capture-sanitize.XXXXXX)"
    if /usr/bin/awk '
      /^## Memory$/ { skip = 1; next }
      skip && /^# / { skip = 0 }
      skip && /^## / { skip = 0 }
      !skip { print }
    ' "$claude_md" > "$tmp"; then
      /bin/mv "$tmp" "$claude_md"
    else
      echo "ERROR: sanitize CLAUDE.md failed" >&2
      /bin/rm -f "$tmp"
      return 1
    fi
  fi
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
  for pattern in "${CLAUDE_EXCLUDES[@]}" "${NVIDIA_CLAUDE_EXCLUDES[@]}"; do
    exclude_args+=(--exclude "$pattern")
  done

  # Use --copy-links to resolve symlinks
  run_rsync "$src" "$dest" --copy-links "${exclude_args[@]}"

  sanitize_claude
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
  for pattern in "${CURSOR_EXCLUDES[@]}" "${NVIDIA_CURSOR_EXCLUDES[@]}"; do
    exclude_args+=(--exclude "$pattern")
  done

  # Use --copy-links to resolve symlinks (especially for commands/)
  run_rsync "$src" "$dest" --copy-links "${exclude_args[@]}"
}

# --- Main ---

main() {
  parse_flags "$@"

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
}

# Only run main when executed directly; allow sourcing for tests.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi

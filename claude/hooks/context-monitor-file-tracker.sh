#!/bin/bash
# context-monitor-file-tracker.sh - Track file edits for context monitoring
# Hook: afterFileEdit
#
# Companion hook to context-monitor.sh that tracks which files are being edited.
# Updates the files_touched array in the context state.
#
# Global config: ~/.claude/context-config.json
# Session state: .claude/context-state.json

set -e

# Prerequisite check
if ! command -v jq &> /dev/null; then
    echo '{"error": "jq is required but not installed. Run: brew install jq"}' >&2
    exit 0
fi

# Read JSON input from Claude Code
input=$(cat)
file_path=$(echo "$input" | jq -r '.file_path // empty')

# Validate file_path exists
if [ -z "$file_path" ]; then
    echo '{}' # Silent success
    exit 0
fi

# Paths
STATE_FILE=".claude/context-state.json"
LOCK_DIR=".claude/context-state.lock"

# Ensure .claude directory exists
mkdir -p .claude

# Cross-platform lock using mkdir (atomic on all POSIX systems)
acquire_lock() {
    local lockdir="$1"
    local timeout="${2:-5}"
    local waited=0

    # Clean up stale locks first
    cleanup_stale_lock "$lockdir"

    while ! mkdir "$lockdir" 2>/dev/null; do
        sleep 0.1
        waited=$((waited + 1))
        if [ "$waited" -ge "$((timeout * 10))" ]; then
            return 1
        fi
    done
    trap "rm -rf '$lockdir'" EXIT
    return 0
}

release_lock() {
    local lockdir="$1"
    rm -rf "$lockdir"
    trap - EXIT
}

# Clean up stale locks (older than 60 seconds)
cleanup_stale_lock() {
    local lockdir="$1"
    if [ -d "$lockdir" ]; then
        # macOS uses stat -f %m, Linux uses stat -c %Y
        local mtime=$(stat -f %m "$lockdir" 2>/dev/null || stat -c %Y "$lockdir" 2>/dev/null || echo "0")
        local age=$(( $(date +%s) - mtime ))
        if [ "$age" -gt 60 ]; then
            rm -rf "$lockdir"
        fi
    fi
}

# Add file to tracked list (deduplicates automatically via jq unique)
add_file_to_state() {
    local file="$1"

    if ! acquire_lock "$LOCK_DIR" 5; then
        return 1
    fi

    if [ -f "$STATE_FILE" ]; then
        local tmp="${STATE_FILE}.tmp.$$"
        # Add file and ensure uniqueness
        if jq --arg file "$file" '.files_touched += [$file] | .files_touched |= unique' "$STATE_FILE" > "$tmp" 2>/dev/null; then
            mv "$tmp" "$STATE_FILE"
            release_lock "$LOCK_DIR"
            return 0
        else
            rm -f "$tmp"
            release_lock "$LOCK_DIR"
            return 1
        fi
    else
        # State file doesn't exist - create minimal state with this file
        cat > "$STATE_FILE" << EOF
{
  "conversation_id": "unknown",
  "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "iterations": 0,
  "files_touched": ["$file"],
  "health": "healthy",
  "last_recommendation": null,
  "stuck_iterations": 0,
  "last_files_count": 0
}
EOF
        release_lock "$LOCK_DIR"
        return 0
    fi
}

# Main logic
main() {
    # Security: Validate file path (no path traversal)
    if [[ "$file_path" == *".."* ]]; then
        echo '{}'
        exit 0
    fi

    # Add file to state (silently fail if can't acquire lock)
    add_file_to_state "$file_path" || true

    # Always return empty success (don't interfere with file edit)
    echo '{}'
}

main

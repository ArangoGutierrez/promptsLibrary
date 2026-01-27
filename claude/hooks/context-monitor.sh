#!/bin/bash
# context-monitor.sh - Context self-awareness for Claude Code sessions
# Hook: stop
#
# Tracks context usage heuristics and recommends:
# - Wrapping up current work when context is filling
# - New session when context is critical or degraded
#
# Global config: ~/.claude/context-config.json
# Session state: .claude/context-state.json
#
# Adapted from Cursor's context-monitor.sh for Claude Code

set -e

# Prerequisite check
if ! command -v jq &> /dev/null; then
    echo '{"error": "jq is required but not installed. Run: brew install jq"}' >&2
    exit 0
fi

# Read JSON input from Claude Code
input=$(cat)
status=$(echo "$input" | jq -r '.status // "unknown"')
loop_count=$(echo "$input" | jq -r '.loop_count // 0')
conversation_id=$(echo "$input" | jq -r '.conversation_id // "unknown"')

# Paths
STATE_FILE=".claude/context-state.json"
LOCK_DIR=".claude/context-state.lock"
GLOBAL_CONFIG="$HOME/.claude/context-config.json"

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
            echo "Failed to acquire lock" >&2
            return 1
        fi
    done
    trap "rm -rf '$lockdir'" EXIT
    return 0
}

release_lock() {
    local lockdir="$1"
    rm -rf "$lockdir"
    # Clear the trap since we've explicitly released the lock
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

# Safe state update with cross-platform locking
# Usage: safe_update 'jq_expression'
# Returns 1 (failure) if state file doesn't exist - caller must handle initialization
safe_update() {
    local jq_expr="$1"

    if ! acquire_lock "$LOCK_DIR" 5; then
        return 1
    fi

    if [ -f "$STATE_FILE" ]; then
        local tmp="${STATE_FILE}.tmp.$$"
        if jq "$jq_expr" "$STATE_FILE" > "$tmp" 2>/dev/null; then
            mv "$tmp" "$STATE_FILE"
            release_lock "$LOCK_DIR"
            return 0
        else
            rm -f "$tmp"
            release_lock "$LOCK_DIR"
            return 1
        fi
    else
        # State file doesn't exist - return failure so caller knows update didn't happen
        release_lock "$LOCK_DIR"
        return 1
    fi
}

# Safe state read with cross-platform locking
# Usage: safe_read 'jq_expression' 'default'
safe_read() {
    local jq_expr="$1"
    local default="$2"

    if ! acquire_lock "$LOCK_DIR" 5; then
        echo "$default"
        return
    fi

    if [ -f "$STATE_FILE" ]; then
        local result=$(jq -r "$jq_expr // \"$default\"" "$STATE_FILE" 2>/dev/null || echo "$default")
        release_lock "$LOCK_DIR"
        echo "$result"
    else
        release_lock "$LOCK_DIR"
        echo "$default"
    fi
}

# Default thresholds (can be overridden in global config)
DEFAULT_HEALTHY_MAX=60
DEFAULT_FILLING_MAX=80
DEFAULT_CRITICAL_MAX=95
DEFAULT_ITERATION_WEIGHT=10
DEFAULT_FILE_WEIGHT=3
DEFAULT_DURATION_WEIGHT=0.5
DEFAULT_STUCK_THRESHOLD=5
DEFAULT_LONG_SESSION_MINUTES=40

# Load global config or use defaults
load_config() {
    if [ -f "$GLOBAL_CONFIG" ]; then
        HEALTHY_MAX=$(jq -r '.thresholds.healthy_max // '$DEFAULT_HEALTHY_MAX'' "$GLOBAL_CONFIG")
        FILLING_MAX=$(jq -r '.thresholds.filling_max // '$DEFAULT_FILLING_MAX'' "$GLOBAL_CONFIG")
        CRITICAL_MAX=$(jq -r '.thresholds.critical_max // '$DEFAULT_CRITICAL_MAX'' "$GLOBAL_CONFIG")
        ITERATION_WEIGHT=$(jq -r '.weights.iteration // '$DEFAULT_ITERATION_WEIGHT'' "$GLOBAL_CONFIG")
        FILE_WEIGHT=$(jq -r '.weights.file // '$DEFAULT_FILE_WEIGHT'' "$GLOBAL_CONFIG")
        DURATION_WEIGHT=$(jq -r '.weights.duration_minutes // '$DEFAULT_DURATION_WEIGHT'' "$GLOBAL_CONFIG")
        STUCK_THRESHOLD=$(jq -r '.stuck_threshold // '$DEFAULT_STUCK_THRESHOLD'' "$GLOBAL_CONFIG")
        LONG_SESSION_MINUTES=$(jq -r '.long_session_minutes // '$DEFAULT_LONG_SESSION_MINUTES'' "$GLOBAL_CONFIG")
    else
        HEALTHY_MAX=$DEFAULT_HEALTHY_MAX
        FILLING_MAX=$DEFAULT_FILLING_MAX
        CRITICAL_MAX=$DEFAULT_CRITICAL_MAX
        ITERATION_WEIGHT=$DEFAULT_ITERATION_WEIGHT
        FILE_WEIGHT=$DEFAULT_FILE_WEIGHT
        DURATION_WEIGHT=$DEFAULT_DURATION_WEIGHT
        STUCK_THRESHOLD=$DEFAULT_STUCK_THRESHOLD
        LONG_SESSION_MINUTES=$DEFAULT_LONG_SESSION_MINUTES
    fi
}

# Initialize or load session state
init_state() {
    mkdir -p "$(dirname "$STATE_FILE")"

    if [ -f "$STATE_FILE" ]; then
        local stored_conv_id=$(safe_read '.conversation_id' '')
        # Reset if new conversation
        if [ "$stored_conv_id" != "$conversation_id" ] && [ "$conversation_id" != "unknown" ]; then
            create_new_state
        fi
    else
        create_new_state
    fi
}

create_new_state() {
    cat > "$STATE_FILE" << EOF
{
  "conversation_id": "$conversation_id",
  "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "iterations": 0,
  "files_touched": [],
  "health": "healthy",
  "last_recommendation": null,
  "stuck_iterations": 0,
  "last_files_count": 0
}
EOF
}

# Update iteration count
update_iterations() {
    local current=$(safe_read '.iterations' '0')
    local new_count=$((current + 1))
    safe_update ".iterations = $new_count"
    echo "$new_count"
}

# Get unique files touched count
get_files_touched() {
    safe_read '.files_touched | length' '0'
}

# Get session duration in minutes
get_session_duration() {
    local started_at=$(safe_read '.started_at' '')
    if [ -z "$started_at" ]; then
        echo "0"
        return
    fi

    # Calculate duration (cross-platform)
    local start_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$started_at" +%s 2>/dev/null || \
                        date -d "$started_at" +%s 2>/dev/null || echo "0")
    local now_epoch=$(date +%s)
    local duration_seconds=$((now_epoch - start_epoch))
    local duration_minutes=$((duration_seconds / 60))

    echo "$duration_minutes"
}

# Detect if stuck (no file edits for multiple iterations)
detect_stuck() {
    local stuck_count=$(safe_read '.stuck_iterations' '0')
    local current_files=$(get_files_touched)
    local last_files=$(safe_read '.last_files_count' '0')

    # Check if files count changed
    if [ "$current_files" -gt "$last_files" ]; then
        # Progress made - reset stuck counter
        safe_update ".stuck_iterations = 0 | .last_files_count = $current_files" || true
        return 1  # Not stuck
    else
        # No progress - increment stuck counter
        stuck_count=$((stuck_count + 1))
        safe_update ".stuck_iterations = $stuck_count | .last_files_count = $current_files" || true
        if [ "$stuck_count" -ge "$STUCK_THRESHOLD" ]; then
            return 0  # Stuck (STUCK_THRESHOLD+ iterations without file changes)
        fi
    fi
    return 1  # Not stuck yet
}

# Calculate context health score
calculate_health_score() {
    local iterations=$(safe_read '.iterations' '0')
    local files_touched=$(get_files_touched)
    local duration_minutes=$(get_session_duration)

    # Score calculation (proxy for context usage percentage)
    # Using bash arithmetic (integer only)
    local score=0
    score=$((score + iterations * ITERATION_WEIGHT))
    score=$((score + files_touched * FILE_WEIGHT))
    # Duration weight is 0.5, so multiply duration by 5 then divide by 10
    score=$((score + (duration_minutes * 5 / 10) ))

    # Clamp to 0-100
    if [ "$score" -lt 0 ]; then score=0; fi
    if [ "$score" -gt 100 ]; then score=100; fi

    echo "$score"
}

# Determine health state from score
get_health_state() {
    local score=$1

    if [ "$score" -lt "$HEALTHY_MAX" ]; then
        echo "healthy"
    elif [ "$score" -lt "$FILLING_MAX" ]; then
        echo "filling"
    elif [ "$score" -lt "$CRITICAL_MAX" ]; then
        echo "critical"
    else
        echo "degraded"
    fi
}

# Generate recommendation message
generate_recommendation() {
    local health_state=$1
    local score=$2
    local duration_minutes=$3
    local files_touched=$4

    local msg=""

    # Check for very long session
    if [ "$duration_minutes" -ge "$LONG_SESSION_MINUTES" ]; then
        msg="⏱️ Long session (${duration_minutes}+ min). Fresh session recommended for optimal performance."
        echo "$msg"
        return
    fi

    # Check for stuck state
    if detect_stuck; then
        msg="💡 No recent file edits. If you're stuck, a fresh session may help."
        echo "$msg"
        return
    fi

    # Decision based on health state
    case "$health_state" in
        "healthy")
            # No message for healthy state
            ;;
        "filling")
            if [ "$files_touched" -ge 10 ]; then
                msg="📊 Context ~${score}% (${files_touched} files edited). Consider finishing current work."
            elif [ "$duration_minutes" -ge 20 ]; then
                msg="📊 Context ~${score}%. Good stopping point approaching."
            fi
            ;;
        "critical")
            msg="⚠️ Context ~${score}%. Finish current work and start fresh session soon."
            ;;
        "degraded")
            msg="🛑 Context ~${score}% (high usage). Start new session for best results."
            ;;
    esac

    echo "$msg"
}

# Main logic
main() {
    # Only process on completed status
    if [ "$status" != "completed" ]; then
        echo '{}'
        exit 0
    fi

    # Load configuration
    load_config

    # Initialize state
    init_state

    # Update metrics
    iterations=$(update_iterations)

    # Calculate health
    score=$(calculate_health_score)
    health_state=$(get_health_state "$score")
    duration_minutes=$(get_session_duration)
    files_touched=$(get_files_touched)

    # Update state file with current health
    safe_update ".health = \"$health_state\""

    # Generate recommendation
    recommendation=$(generate_recommendation "$health_state" "$score" "$duration_minutes" "$files_touched")

    if [ -n "$recommendation" ]; then
        # Store recommendation
        safe_update ".last_recommendation = \"$recommendation\""

        # Output for Claude Code
        cat << EOF
{
  "followup_message": "$recommendation"
}
EOF
    else
        echo '{}'
    fi
}

main

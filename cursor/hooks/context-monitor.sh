#!/bin/bash
# context-monitor.sh - Context self-awareness for Cursor sessions
# Hook: stop
#
# Tracks context usage heuristics and recommends:
# - /summarize when context is filling but task is in-progress
# - New session when task is complete or context is degraded
#
# Global config: ~/.cursor/context-config.json
# Session state: .cursor/context-state.json

set -e

# Prerequisite check
if ! command -v jq &> /dev/null; then
    echo '{"error": "jq is required but not installed. Run: brew install jq"}' >&2
    exit 0
fi

# Read JSON input from Cursor
input=$(cat)
status=$(echo "$input" | jq -r '.status // "unknown"')
loop_count=$(echo "$input" | jq -r '.loop_count // 0')
conversation_id=$(echo "$input" | jq -r '.conversation_id // "unknown"')

# Paths
STATE_FILE=".cursor/context-state.json"
LOCK_DIR=".cursor/context-state.lock"
GLOBAL_CONFIG="$HOME/.cursor/context-config.json"
AGENTS_FILE="AGENTS.md"

# Ensure .cursor directory exists
mkdir -p .cursor

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
    fi
    
    release_lock "$LOCK_DIR"
    return 0
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
DEFAULT_HEALTHY_MAX=50
DEFAULT_FILLING_MAX=75
DEFAULT_CRITICAL_MAX=90
DEFAULT_ITERATION_WEIGHT=8
DEFAULT_FILE_WEIGHT=2
DEFAULT_TASK_WEIGHT=15
DEFAULT_SUMMARIZE_RECOVERY=25
DEFAULT_TASKS_BEFORE_NEW_SESSION=3

# Load global config or use defaults
load_config() {
    if [ -f "$GLOBAL_CONFIG" ]; then
        HEALTHY_MAX=$(jq -r '.thresholds.healthy_max // '$DEFAULT_HEALTHY_MAX'' "$GLOBAL_CONFIG")
        FILLING_MAX=$(jq -r '.thresholds.filling_max // '$DEFAULT_FILLING_MAX'' "$GLOBAL_CONFIG")
        CRITICAL_MAX=$(jq -r '.thresholds.critical_max // '$DEFAULT_CRITICAL_MAX'' "$GLOBAL_CONFIG")
        ITERATION_WEIGHT=$(jq -r '.weights.iteration // '$DEFAULT_ITERATION_WEIGHT'' "$GLOBAL_CONFIG")
        FILE_WEIGHT=$(jq -r '.weights.file // '$DEFAULT_FILE_WEIGHT'' "$GLOBAL_CONFIG")
        TASK_WEIGHT=$(jq -r '.weights.task // '$DEFAULT_TASK_WEIGHT'' "$GLOBAL_CONFIG")
        SUMMARIZE_RECOVERY=$(jq -r '.weights.summarize_recovery // '$DEFAULT_SUMMARIZE_RECOVERY'' "$GLOBAL_CONFIG")
        TASKS_BEFORE_NEW_SESSION=$(jq -r '.tasks_before_new_session // '$DEFAULT_TASKS_BEFORE_NEW_SESSION'' "$GLOBAL_CONFIG")
    else
        HEALTHY_MAX=$DEFAULT_HEALTHY_MAX
        FILLING_MAX=$DEFAULT_FILLING_MAX
        CRITICAL_MAX=$DEFAULT_CRITICAL_MAX
        ITERATION_WEIGHT=$DEFAULT_ITERATION_WEIGHT
        FILE_WEIGHT=$DEFAULT_FILE_WEIGHT
        TASK_WEIGHT=$DEFAULT_TASK_WEIGHT
        SUMMARIZE_RECOVERY=$DEFAULT_SUMMARIZE_RECOVERY
        TASKS_BEFORE_NEW_SESSION=$DEFAULT_TASKS_BEFORE_NEW_SESSION
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
  "tasks_completed": 0,
  "summarize_count": 0,
  "last_summarize_at": null,
  "health": "healthy",
  "last_recommendation": null,
  "stuck_iterations": 0
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

# Track files touched (called by afterFileEdit hook integration)
# For now, estimate from iteration count
get_files_touched() {
    safe_read '.files_touched | length' '0'
}

# Get summarize count
get_summarize_count() {
    safe_read '.summarize_count' '0'
}

# Detect if /summarize was run (check for summarize markers in recent output)
# This is heuristic - looks for conversation getting shorter or explicit markers
detect_summarize() {
    local prev_iterations=$(safe_read '.iterations' '0')
    # If loop_count is significantly lower than tracked iterations, likely summarized
    if [ "$loop_count" -lt "$((prev_iterations - 2))" ] && [ "$prev_iterations" -gt 3 ]; then
        # Likely a summarize happened
        local sum_count=$(safe_read '.summarize_count' '0')
        safe_update ".summarize_count = $((sum_count + 1)) | .last_summarize_at = \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\""
        return 0
    fi
    return 1
}

# Read task status from AGENTS.md
get_task_status() {
    if [ ! -f "$AGENTS_FILE" ]; then
        echo "no_agents"
        return
    fi
    
    # Check for explicit status
    if grep -qE "^## Status: (DONE|COMPLETE|FINISHED)" "$AGENTS_FILE" 2>/dev/null; then
        echo "complete"
        return
    fi
    
    # Count task states
    local todo_count=$(grep -c '\[TODO\]' "$AGENTS_FILE" 2>/dev/null || echo "0")
    local wip_count=$(grep -c '\[WIP\]' "$AGENTS_FILE" 2>/dev/null || echo "0")
    local done_count=$(grep -c '\[DONE\]' "$AGENTS_FILE" 2>/dev/null || echo "0")
    local blocked_count=$(grep -c '\[BLOCKED' "$AGENTS_FILE" 2>/dev/null || echo "0")
    
    if [ "$blocked_count" -gt 0 ]; then
        echo "blocked"
    elif [ "$todo_count" -eq 0 ] && [ "$wip_count" -eq 0 ] && [ "$done_count" -gt 0 ]; then
        echo "complete"
    elif [ "$wip_count" -gt 0 ]; then
        echo "in_progress"
    elif [ "$todo_count" -gt 0 ]; then
        echo "pending"
    else
        echo "unknown"
    fi
}

# Count completed tasks in this session
count_completed_tasks() {
    if [ -f "$AGENTS_FILE" ]; then
        grep -c '\[DONE\]' "$AGENTS_FILE" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Calculate context health score
calculate_health_score() {
    local iterations=$(safe_read '.iterations' '0')
    local files_touched=$(get_files_touched)
    local tasks_completed=$(count_completed_tasks)
    local summarize_count=$(get_summarize_count)
    
    # Score calculation (proxy for token usage percentage)
    local score=0
    score=$((score + iterations * ITERATION_WEIGHT))
    score=$((score + files_touched * FILE_WEIGHT))
    score=$((score + tasks_completed * TASK_WEIGHT))
    score=$((score - summarize_count * SUMMARIZE_RECOVERY))
    
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

# Detect if stuck (same state, no progress)
detect_stuck() {
    local prev_iterations=$(safe_read '.iterations' '0')
    local stuck_count=$(safe_read '.stuck_iterations' '0')
    
    # Simple heuristic: if we're on same loop_count repeatedly
    if [ "$loop_count" -eq "$prev_iterations" ]; then
        stuck_count=$((stuck_count + 1))
        safe_update ".stuck_iterations = $stuck_count"
        if [ "$stuck_count" -ge 2 ]; then
            return 0  # Stuck
        fi
    else
        safe_update ".stuck_iterations = 0"
    fi
    return 1  # Not stuck
}

# Generate recommendation message
generate_recommendation() {
    local health_state=$1
    local task_status=$2
    local score=$3
    local tasks_completed=$4
    
    local msg=""
    
    # Check for task completion threshold
    if [ "$tasks_completed" -ge "$TASKS_BEFORE_NEW_SESSION" ]; then
        msg="📦 $tasks_completed tasks complete. New session recommended (context bloat)."
        echo "$msg"
        return
    fi
    
    # Check for stuck state
    if detect_stuck; then
        msg="💡 Appears stuck. New session with fresh context often helps."
        echo "$msg"
        return
    fi
    
    # Decision matrix based on health + task status
    case "$health_state" in
        "healthy")
            if [ "$task_status" = "complete" ]; then
                msg="✅ Task complete! Start new session for next task (fresh context = better results)."
            fi
            # No message for healthy + in_progress (just continue)
            ;;
        "filling")
            if [ "$task_status" = "complete" ]; then
                msg="✅ Done! Start new session for next task."
            elif [ "$task_status" = "in_progress" ] || [ "$task_status" = "pending" ]; then
                msg="📊 Context ~${score}%. Consider \`/summarize\` if you need more runway."
            elif [ "$task_status" = "blocked" ]; then
                msg="🚫 Task blocked + context filling. Resolve blocker, then consider new session."
            fi
            ;;
        "critical")
            if [ "$task_status" = "complete" ]; then
                msg="🔴 Context ~${score}%. Start new session before next task."
            elif [ "$task_status" = "in_progress" ] || [ "$task_status" = "pending" ]; then
                msg="⚠️ Context ~${score}%. Run \`/summarize\` now, then wrap up current work."
            elif [ "$task_status" = "blocked" ]; then
                msg="🛑 Task blocked + context critical. Consider new session with focused context on blocker."
            fi
            ;;
        "degraded")
            msg="🛑 Context exhausted (~${score}%). Start new session to continue effectively."
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
    
    # Check for summarize detection
    detect_summarize || true
    
    # Update metrics
    iterations=$(update_iterations)
    
    # Calculate health
    score=$(calculate_health_score)
    health_state=$(get_health_state "$score")
    
    # Get task status from AGENTS.md
    task_status=$(get_task_status)
    tasks_completed=$(count_completed_tasks)
    
    # Update state file with current health
    safe_update ".health = \"$health_state\" | .tasks_completed = $tasks_completed"
    
    # Generate recommendation
    recommendation=$(generate_recommendation "$health_state" "$task_status" "$score" "$tasks_completed")
    
    if [ -n "$recommendation" ]; then
        # Store recommendation
        safe_update ".last_recommendation = \"$recommendation\""
        
        # Output for Cursor
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

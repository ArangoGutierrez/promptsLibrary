#!/bin/bash
# task-loop.sh - Ralph-loop style persistent task execution for Cursor
# Hook: stop
#
# Implements autonomous task continuation with:
# - Progress tracking via AGENTS.md
# - Completion detection
# - Iteration budgeting
# - Status reporting

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

# Configuration files
LOOP_STATE=".cursor/loop-state.json"
LOCK_DIR=".cursor/loop-state.lock"
AGENTS_FILE="AGENTS.md"
TASK_LOG=".cursor/task-log.md"

# Ensure .cursor directory exists for lock file
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

# Validate state file JSON
validate_state_file() {
    if [ -f "$LOOP_STATE" ]; then
        if ! jq empty "$LOOP_STATE" 2>/dev/null; then
            echo "Warning: corrupted state file, backing up and resetting" >&2
            mv "$LOOP_STATE" "${LOOP_STATE}.corrupt.$(date +%s)"
            return 1
        fi
    fi
    return 0
}

# Safe state file update with cross-platform locking
# Usage: update_state 'jq_expression'
update_state() {
    local jq_expr="$1"
    
    if ! acquire_lock "$LOCK_DIR" 5; then
        echo "Failed to acquire lock" >&2
        return 1
    fi
    
    # Validate state file before reading
    if ! validate_state_file; then
        release_lock "$LOCK_DIR"
        return 1
    fi
    
    if [ -f "$LOOP_STATE" ]; then
        local tmp="${LOOP_STATE}.tmp.$$"
        if jq "$jq_expr" "$LOOP_STATE" > "$tmp" 2>/dev/null; then
            mv "$tmp" "$LOOP_STATE"
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

# Safe state file read with cross-platform locking
# Usage: read_state 'jq_expression' 'default'
read_state() {
    local jq_expr="$1"
    local default="$2"
    
    if ! acquire_lock "$LOCK_DIR" 5; then
        echo "$default"
        return
    fi
    
    # Validate state file before reading
    validate_state_file || true
    
    if [ -f "$LOOP_STATE" ]; then
        local result=$(jq -r "$jq_expr // \"$default\"" "$LOOP_STATE" 2>/dev/null || echo "$default")
        release_lock "$LOCK_DIR"
        echo "$result"
    else
        release_lock "$LOCK_DIR"
        echo "$default"
    fi
}

# Load loop configuration (from /loop command or defaults)
# Validate state file before loading
if [ -f "$LOOP_STATE" ]; then
    if ! validate_state_file; then
        # State file was corrupted and reset, exit silently
        echo '{}'
        exit 0
    fi
fi

if [ -f "$LOOP_STATE" ]; then
    MAX_ITERATIONS=$(read_state '.max_iterations' '10')
    COMPLETION_PROMISE=$(read_state '.completion_promise' 'DONE')
    LOOP_STATUS=$(read_state '.status' 'stopped')
    TASK_DESCRIPTION=$(read_state '.task' '')
    
    # Only run if loop is active
    if [ "$LOOP_STATUS" != "running" ]; then
        echo '{}'
        exit 0
    fi
    
    # Update iteration count in state (with locking)
    update_state ".current_iteration = $((loop_count + 1))"
else
    # No active loop - exit silently
    # Loop must be started with /loop command which creates the state file
    echo '{}'
    exit 0
fi

# Initialize AGENTS.md only if it doesn't exist
# If it exists, we assume it has valid task tracking content
init_agents_file() {
    if [ ! -f "$AGENTS_FILE" ]; then
        cat > "$AGENTS_FILE" << 'EOF'
# AGENTS.md

## Current Task
{task description}

## Status: IN_PROGRESS

## Tasks
| # | Task | Status |
|---|------|--------|
| 1 | Define objective | `[TODO]` |

## Notes
- Update this file as you work
- Mark status as DONE when complete
- Use [TODO], [WIP], [DONE], [BLOCKED]

## Acceptance Criteria
- [ ] All tasks marked [DONE]
- [ ] Tests pass
- [ ] No blocking issues
EOF
    fi
    # If AGENTS.md exists, don't overwrite - commands will update it
}

# Log iteration
log_iteration() {
    local iter="$1"
    local status="$2"
    local action="$3"
    
    mkdir -p "$(dirname "$TASK_LOG")"
    echo "$(date '+%Y-%m-%d %H:%M:%S') | Iteration $iter | $status | $action" >> "$TASK_LOG"
}

# Check completion markers
check_completion() {
    # Check for completion promise in AGENTS.md (from /loop command)
    if [ -n "$COMPLETION_PROMISE" ] && [ -f "$AGENTS_FILE" ]; then
        if grep -qF "$COMPLETION_PROMISE" "$AGENTS_FILE" 2>/dev/null; then
            return 0  # Completion promise found
        fi
    fi
    
    if [ ! -f "$AGENTS_FILE" ]; then
        return 1  # Not complete, AGENTS.md doesn't exist
    fi
    
    # Check for explicit completion markers
    if grep -qE "^## Status: (DONE|COMPLETE|FINISHED)" "$AGENTS_FILE" 2>/dev/null; then
        return 0  # Complete
    fi
    
    # Check if all tasks are done (no [TODO] or [WIP] remaining)
    if grep -q '\[TODO\]\|\[WIP\]' "$AGENTS_FILE" 2>/dev/null; then
        return 1  # Tasks remain
    fi
    
    # Check acceptance criteria checkboxes
    if grep -q '- \[ \]' "$AGENTS_FILE" 2>/dev/null; then
        return 1  # Unchecked criteria
    fi
    
    return 0  # Appears complete
}

# Check for blockers
check_blockers() {
    if [ -f "$AGENTS_FILE" ]; then
        if grep -q '\[BLOCKED' "$AGENTS_FILE" 2>/dev/null; then
            return 0  # Has blockers
        fi
    fi
    return 1  # No blockers
}

# Get remaining tasks count
get_remaining_tasks() {
    if [ -f "$AGENTS_FILE" ]; then
        grep -c '\[TODO\]\|\[WIP\]' "$AGENTS_FILE" 2>/dev/null || echo "0"
    else
        echo "unknown"
    fi
}

# Main logic
main() {
    # Only continue on successful completion
    if [ "$status" != "completed" ]; then
        log_iteration "$loop_count" "$status" "stopped (not completed)"
        echo '{}'
        exit 0
    fi
    
    # Check iteration budget
    if [ "$loop_count" -ge "$MAX_ITERATIONS" ]; then
        log_iteration "$loop_count" "budget" "iteration limit reached"
        # Mark loop as budget exceeded (with locking)
        update_state '.status = "budget_exceeded"'
        echo '{"followup_message": "⚠️ Iteration limit ('$MAX_ITERATIONS') reached. Review progress in AGENTS.md and continue manually if needed."}'
        exit 0
    fi
    
    # Initialize AGENTS.md on first iteration
    if [ "$loop_count" -eq 0 ]; then
        init_agents_file
    fi
    
    # Check for completion
    if check_completion; then
        log_iteration "$loop_count" "complete" "all tasks done"
        # Mark loop as complete (with locking)
        update_state '.status = "complete" | .completed_at = (now | todate)'
        echo '{"followup_message": "✅ Loop complete! All tasks finished."}'
        exit 0
    fi
    
    # Check for blockers
    if check_blockers; then
        log_iteration "$loop_count" "blocked" "awaiting human intervention"
        echo '{"followup_message": "🚫 Task blocked. Check AGENTS.md for [BLOCKED] items and resolve before continuing."}'
        exit 0
    fi
    
    # Continue iteration
    remaining=$(get_remaining_tasks)
    next=$((loop_count + 1))
    
    log_iteration "$loop_count" "continue" "tasks remaining: $remaining"
    
    # Build continuation message with task context
    if [ -n "$TASK_DESCRIPTION" ]; then
        # Ralph-loop style: feed the same task back
        cat << EOF
{
  "followup_message": "🔁 Iteration ${next}/${MAX_ITERATIONS}\n\n**Task:** ${TASK_DESCRIPTION}\n**Done when:** ${COMPLETION_PROMISE}\n**Remaining:** ${remaining} tasks\n\nContinue working. Update AGENTS.md when done."
}
EOF
    else
        # AGENTS.md-based continuation
        cat << EOF
{
  "followup_message": "📍 Iteration ${next}/${MAX_ITERATIONS} | ${remaining} tasks remaining\n\nContinue working on TODO items in AGENTS.md\n\nUpdate task status as you progress:\n- [TODO] → [WIP] when starting\n- [WIP] → [DONE] when complete\n- Set '## Status: DONE' when all tasks finished"
}
EOF
    fi
}

main

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

# Read JSON input from Cursor
input=$(cat)
status=$(echo "$input" | jq -r '.status // "unknown"')
loop_count=$(echo "$input" | jq -r '.loop_count // 0')
conversation_id=$(echo "$input" | jq -r '.conversation_id // "unknown"')

# Configuration files
LOOP_STATE=".cursor/loop-state.json"
AGENTS_FILE="AGENTS.md"
TASK_LOG=".cursor/task-log.md"

# Load loop configuration (from /loop command or defaults)
if [ -f "$LOOP_STATE" ]; then
    MAX_ITERATIONS=$(jq -r '.max_iterations // 10' "$LOOP_STATE")
    COMPLETION_PROMISE=$(jq -r '.completion_promise // "DONE"' "$LOOP_STATE")
    LOOP_STATUS=$(jq -r '.status // "stopped"' "$LOOP_STATE")
    TASK_DESCRIPTION=$(jq -r '.task // ""' "$LOOP_STATE")
    
    # Only run if loop is active
    if [ "$LOOP_STATUS" != "running" ]; then
        echo '{}'
        exit 0
    fi
    
    # Update iteration count in state
    jq ".current_iteration = $((loop_count + 1))" "$LOOP_STATE" > "${LOOP_STATE}.tmp" && mv "${LOOP_STATE}.tmp" "$LOOP_STATE"
else
    # Fallback to env vars or defaults (backward compatibility)
    MAX_ITERATIONS="${CURSOR_MAX_ITERATIONS:-10}"
    COMPLETION_PROMISE="DONE"
    TASK_DESCRIPTION=""
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
        # Mark loop as budget exceeded
        if [ -f "$LOOP_STATE" ]; then
            jq '.status = "budget_exceeded"' "$LOOP_STATE" > "${LOOP_STATE}.tmp" && mv "${LOOP_STATE}.tmp" "$LOOP_STATE" 2>/dev/null || true
        fi
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
        # Mark loop as complete in state file
        if [ -f "$LOOP_STATE" ]; then
            jq '.status = "complete" | .completed_at = now | .completed_at = (now | todate)' "$LOOP_STATE" > "${LOOP_STATE}.tmp" && mv "${LOOP_STATE}.tmp" "$LOOP_STATE" 2>/dev/null || true
        fi
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

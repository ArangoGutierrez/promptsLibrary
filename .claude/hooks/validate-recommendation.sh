#!/bin/bash
# validate-recommendation.sh - PreToolUse hook for AskUserQuestion.
# Detects "(Recommended)" marker in option labels; if present and not already
# panel-flagged, writes tool_input to a session state file and blocks with
# stderr feedback instructing Claude to invoke the validate-recommendation skill.
#
# Exit 0 = approve (let tool proceed). Exit 2 = block (stderr is feedback).
# Fails open: any error in this script results in exit 0 + stderr log.

set -o pipefail

INPUT=$(cat)

# Bypass switch
if [ "${CLAUDE_PANEL:-on}" = "off" ]; then
    exit 0
fi

# Parse tool name; bail unless AskUserQuestion
TOOL=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)
if [ "$TOOL" != "AskUserQuestion" ]; then
    exit 0
fi

# Find first option label containing "(Recommended)"; loop guard if Panel-flagged
RECOMMENDED_LABEL=$(echo "$INPUT" \
    | jq -r '.tool_input.questions[]?.options[]?.label
             | select(contains("(Recommended)"))' 2>/dev/null \
    | grep -v 'Panel-flagged' \
    | head -n 1)

if [ -z "$RECOMMENDED_LABEL" ]; then
    exit 0
fi

# Write state file
SID="${CLAUDE_SESSION_ID:-unknown}"
TMP="${TMPDIR:-/tmp}"
STATE_FILE="$TMP/claude-panel-${SID}.json"
TIMEOUT="${CLAUDE_PANEL_TIMEOUT:-90}"
CREATED=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo "$INPUT" | jq \
    --arg sid "$SID" \
    --arg label "$RECOMMENDED_LABEL" \
    --arg timeout "$TIMEOUT" \
    --arg created "$CREATED" \
    '{
        session_id: $sid,
        tool_input: .tool_input,
        recommended_label: $label,
        timeout_seconds: ($timeout | tonumber),
        created_at: $created
    }' > "$STATE_FILE" 2>/dev/null || {
        echo "panel: failed to write state file at $STATE_FILE" >&2
        exit 0  # fail-open
    }

# Optional debug trace
if [ -n "${CLAUDE_PANEL_DEBUG:-}" ]; then
    DEBUG_DIR="$HOME/.claude/debug"
    mkdir -p "$DEBUG_DIR" 2>/dev/null
    echo "[$CREATED] panel triggered: session=$SID label='$RECOMMENDED_LABEL' state=$STATE_FILE" \
        >> "$DEBUG_DIR/panel-trace.log"
fi

# Block with feedback
cat >&2 <<EOF
Recommendation panel required: this AskUserQuestion has a (Recommended) option.
Invoke the validate-recommendation skill before asking the user. State file:
  $STATE_FILE

The skill will:
  1. Dispatch devil's advocate (Nemotron via dispatch-da.sh) and PE (principal-engineer subagent) panelists in parallel
  2. Aggregate verdicts via aggregate.sh
  3. Emit PANEL_VERDICT: HOLD (auto-proceed) or DISSENT (re-ask augmented) or ERROR (re-ask original)

Skill location: .claude/skills/validate-recommendation/SKILL.md
EOF
exit 2

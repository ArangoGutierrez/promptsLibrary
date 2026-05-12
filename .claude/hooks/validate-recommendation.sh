#!/bin/bash
# validate-recommendation.sh - PreToolUse hook for AskUserQuestion.
# Detects "(Recommended)" marker in option labels; if present and not already
# panel-flagged, writes tool_input to a session state file and blocks with
# stderr feedback instructing Claude to invoke the validate-recommendation skill.
#
# Exit 0 = approve (let tool proceed). Exit 2 = block (stderr is feedback).
# Fails open: any error in this script results in exit 0 + stderr log.

set -o pipefail

# Tighten umask so any file we create in $TMPDIR is mode 0600 (user-only).
# Defense in depth: macOS $TMPDIR is 0700 per-user, but Linux /tmp is 1777
# and shared across users. The state file may contain the user's question
# text and recommendation reasoning, which should not be world-readable.
umask 077

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

# Find first option label containing "(Recommended)".
#
# The Panel-flagged loop guard relies on the substring break: the skill's
# fallback swap converts "(Recommended)" -> "(Recommended; Panel-flagged)",
# which inserts "; Panel-flagged" between the word and the closing paren.
# That breaks the "(Recommended)" substring that jq's contains() looks for,
# so panel-flagged labels are automatically excluded — no separate grep
# needed. Hook test 3 ('loop guard') exercises this directly: any change
# to the marker swap format that preserves the "(Recommended)" substring
# would fail that test and need a new exclusion mechanism.
RECOMMENDED_LABEL=$(echo "$INPUT" \
    | jq -r '.tool_input.questions[]?.options[]?.label
             | select(contains("(Recommended)"))' 2>/dev/null \
    | head -n 1)

if [ -z "$RECOMMENDED_LABEL" ]; then
    exit 0
fi

SID="${CLAUDE_SESSION_ID:-unknown}"
TMP="${TMPDIR:-/tmp}"
STATE_FILE="$TMP/claude-panel-${SID}.json"
TIMEOUT="${CLAUDE_PANEL_TIMEOUT:-90}"
CREATED=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Trace log (default-on telemetry). Override path via $CLAUDE_PANEL_TRACE_LOG.
TRACE_LOG="${CLAUDE_PANEL_TRACE_LOG:-$HOME/.claude/debug/panel-trace.log}"
mkdir -p "$(dirname "$TRACE_LOG")" 2>/dev/null

# Re-entry guard: if a state file already exists for this session, a
# previous panel dispatch did not complete cleanly (the skill cleans up
# the state file on every terminal path). The most likely cause is that
# the skill failed mid-flight and fell back to re-issuing the original
# AskUserQuestion. To prevent an infinite loop where every re-issue
# triggers another panel attempt that fails the same way, we treat this
# second call as a bypass: remove the stale state file and approve.
if [ -f "$STATE_FILE" ]; then
    rm -f "$STATE_FILE"
    echo "[$CREATED] event=reentry_bypass session=$SID" >> "$TRACE_LOG" 2>/dev/null || true
    exit 0
fi

# Write state file

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

# Default-on telemetry: log every trigger so a silently-broken panel is
# detectable via `tail ~/.claude/debug/panel-trace.log` or `grep -c event=`.
# CLAUDE_PANEL_DEBUG adds extra verbose lines on top of this.
echo "[$CREATED] event=trigger session=$SID label=\"$RECOMMENDED_LABEL\"" \
    >> "$TRACE_LOG" 2>/dev/null || true

if [ -n "${CLAUDE_PANEL_DEBUG:-}" ]; then
    echo "[$CREATED] event=debug session=$SID state_file=$STATE_FILE" \
        >> "$TRACE_LOG" 2>/dev/null || true
fi

# Block with feedback
cat >&2 <<EOF
Recommendation panel required: this AskUserQuestion has a (Recommended) option.
Invoke the validate-recommendation skill before asking the user. State file:
  $STATE_FILE

The skill will:
  1. Dispatch devil's advocate (external model via dispatch-da.sh) and PE (principal-engineer subagent) panelists in parallel
  2. Aggregate verdicts via aggregate.sh
  3. Emit PANEL_VERDICT: HOLD (auto-proceed) or DISSENT (re-ask augmented) or ERROR (re-ask original)

Skill location: .claude/skills/validate-recommendation/SKILL.md
EOF
exit 2

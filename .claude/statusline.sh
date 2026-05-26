#!/bin/bash
# Claude Code status line script
# Displays: model name, git branch (worktree-aware), worktree name, rate limits
# Fields per https://code.claude.com/docs/en/statusline

input=$(cat)

MODEL=$(echo "$input" | jq -r '.model.display_name // "?"')

# git branch: prefer worktree.branch (--worktree sessions), fall back to live git
WORKTREE_BRANCH=$(echo "$input" | jq -r '.worktree.branch // empty')
if [ -n "$WORKTREE_BRANCH" ]; then
    BRANCH="$WORKTREE_BRANCH"
else
    BRANCH=$(git branch --show-current 2>/dev/null)
fi

# git worktree name (present only inside a linked worktree)
GIT_WORKTREE=$(echo "$input" | jq -r '.workspace.git_worktree // empty')

# Session goal (from done-hook protocol — ~/.claude/audit/session-goals/<id>.md)
GOAL="(no goal)"
SESSION_ID=$(echo "$input" | jq -r '.session_id // empty')
if [ -n "$SESSION_ID" ]; then
    GOAL_FILE="${HOME}/.claude/audit/session-goals/${SESSION_ID}.md"
    if [ -f "$GOAL_FILE" ]; then
        # Extract last stanza's "Goal: " line via awk + grep + sed
        RAW=$(awk '/^## /{buf=""} {buf=buf $0 "\n"} END{printf "%s", buf}' "$GOAL_FILE" \
              | grep -m1 '^Goal: ' | sed 's/^Goal: //; s/[[:space:]]*$//')
        if [ -n "$RAW" ]; then
            if [ "${#RAW}" -gt 40 ]; then RAW="${RAW:0:38}…"; fi
            GOAL="$RAW"
        fi
    fi
fi

# Context-window token consumption (post-v2.1.132 these are current-context tokens)
IN_TOKENS=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
OUT_TOKENS=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')
TOTAL_TOKENS=$((IN_TOKENS + OUT_TOKENS))
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
if [ "$TOTAL_TOKENS" -ge 1000 ]; then
    TOKENS=$(awk -v n="$TOTAL_TOKENS" 'BEGIN{ printf "%.1fk", n/1000 }')
else
    TOKENS="$TOTAL_TOKENS"
fi
TOK_SEG="${TOKENS} tok (${PCT}%)"

# rate limits (Pro/Max only; absent otherwise)
FIVE_H=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
SEVEN_D=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

# Build output
PARTS="[$MODEL]"

[ -n "$BRANCH" ] && PARTS="$PARTS  $BRANCH"
[ -n "$GIT_WORKTREE" ] && PARTS="$PARTS (wt:$GIT_WORKTREE)"

PARTS="$PARTS | 🎯 $GOAL"
PARTS="$PARTS | $TOK_SEG"

LIMITS=""
[ -n "$FIVE_H" ] && LIMITS="5h:$(printf '%.0f' "$FIVE_H")%"
[ -n "$SEVEN_D" ] && LIMITS="${LIMITS:+$LIMITS }7d:$(printf '%.0f' "$SEVEN_D")%"
[ -n "$LIMITS" ] && PARTS="$PARTS | $LIMITS"

echo "$PARTS"

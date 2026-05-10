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

# rate limits (Pro/Max only; absent otherwise)
FIVE_H=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
SEVEN_D=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

# Build output
PARTS="[$MODEL]"

[ -n "$BRANCH" ] && PARTS="$PARTS  $BRANCH"
[ -n "$GIT_WORKTREE" ] && PARTS="$PARTS (wt:$GIT_WORKTREE)"

LIMITS=""
[ -n "$FIVE_H" ] && LIMITS="5h:$(printf '%.0f' "$FIVE_H")%"
[ -n "$SEVEN_D" ] && LIMITS="${LIMITS:+$LIMITS }7d:$(printf '%.0f' "$SEVEN_D")%"
[ -n "$LIMITS" ] && PARTS="$PARTS | $LIMITS"

echo "$PARTS"

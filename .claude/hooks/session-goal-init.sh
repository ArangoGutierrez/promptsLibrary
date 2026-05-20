#!/bin/bash
# session-goal-init.sh — Nudge user to capture a session goal when none exists.
# Hook: SessionStart
# Exit 0 always — never blocks.
# Spec: docs/superpowers/specs/2026-05-18-done-hook-design.md §Component 2
set -o pipefail

INPUT=$(cat)

# Extract transcript_path from hook input
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
[ -z "$TRANSCRIPT" ] && exit 0

UUID=$(basename "$TRANSCRIPT" .jsonl)
GOAL_FILE="${HOME}/.claude/audit/session-goals/${UUID}.md"

if [ ! -f "$GOAL_FILE" ]; then
  echo "" >&2
  echo "[session-goal] No session goal set for ${UUID:0:8}." >&2
  echo "[session-goal] Run /goal to capture one (optional in v1)." >&2
fi

exit 0

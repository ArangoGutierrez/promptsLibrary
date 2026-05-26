#!/bin/bash
# goal.sh — write or amend the session-goal file.
# Spec: docs/superpowers/specs/2026-05-18-done-hook-design.md §Component 4
set -o pipefail

INPUT="${1:-}"

# Resolve session UUID — prefer $CLAUDE_SESSION_ID, fall back to ~/.claude/sessions/$$.json
UUID="${CLAUDE_SESSION_ID:-}"
if [ -z "$UUID" ] || [ "$UUID" = "unknown" ]; then
  if [ -f "$HOME/.claude/sessions/$$.json" ]; then
    UUID=$(jq -r '.sessionId // empty' "$HOME/.claude/sessions/$$.json" 2>/dev/null)
  fi
fi
if [ -z "$UUID" ]; then
  # last-resort: newest session file
  # shellcheck disable=SC2012  # paths are internal/controlled; ls preserves plan pattern
  SESS_FILE=$(ls -t "$HOME/.claude/sessions/"*.json 2>/dev/null | head -1)
  [ -n "$SESS_FILE" ] && UUID=$(jq -r '.sessionId // empty' "$SESS_FILE" 2>/dev/null)
fi
if [ -z "$UUID" ]; then
  echo "[goal] ERROR: could not resolve session UUID" >&2
  exit 1
fi

GOAL_DIR="$HOME/.claude/audit/session-goals"
mkdir -p "$GOAL_DIR"
GOAL_FILE="$GOAL_DIR/$UUID.md"
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Determine stanza type by file presence (NOT by 'amend' keyword)
if [ -f "$GOAL_FILE" ]; then
  HEADER="## Amendment $TS"
else
  HEADER="## Initial $TS"
fi

# Strip leading "amend " keyword if present (user signal, not behavior change)
INPUT="${INPUT#amend }"

# Format check — warn but write
if ! echo "$INPUT" | grep -q '^Goal: '; then
  echo "[goal] WARNING: input missing 'Goal: ' line" >&2
fi
if ! echo "$INPUT" | grep -q '^Acceptance:'; then
  echo "[goal] WARNING: input missing 'Acceptance:' section" >&2
fi

# Check existence BEFORE the append-group to avoid SC2094 (read+write in same pipeline).
PREPEND_NL=0
[ -f "$GOAL_FILE" ] && PREPEND_NL=1
{
  [ "$PREPEND_NL" -eq 1 ] && echo ""
  echo "$HEADER"
  echo "$INPUT"
} >> "$GOAL_FILE"

echo "[goal] wrote $HEADER to $GOAL_FILE" >&2

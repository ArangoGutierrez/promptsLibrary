#!/bin/bash
# done-hook.sh — Surface evidence against the captured session goal.
# Hook: Stop  (peer with context-watch.sh)
# Exit 0 always — coordinates with context-watch.sh, never blocks.
# Spec: docs/superpowers/specs/2026-05-18-done-hook-design.md §Component 3
set -o pipefail

INPUT=$(cat)
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
[ -z "$TRANSCRIPT" ] && exit 0

UUID=$(basename "$TRANSCRIPT" .jsonl)
GOAL_FILE="${HOME}/.claude/audit/session-goals/${UUID}.md"
OUTCOMES_LOG="${HOME}/.claude/audit/session-outcomes-$(date -u +%Y-%m-%d).log"
mkdir -p "$(dirname "$OUTCOMES_LOG")"

# NO_GOAL path: emit ONCE per session, then silent.
if [ ! -f "$GOAL_FILE" ]; then
  if [ -f "$OUTCOMES_LOG" ] && grep -q "\"session\":\"${UUID}\".*\"verdict\":\"NO_GOAL\"" "$OUTCOMES_LOG"; then
    exit 0  # already emitted; debounce
  fi
  TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  printf '{"schema":1,"session":"%s","seq":1,"ts":"%s","goal_file":null,"heuristic":{"verdict":"NO_GOAL","matched":0,"total":0},"evidence":[],"state_hash":"","user":null}\n' \
    "$UUID" "$TS" >> "$OUTCOMES_LOG"
  exit 0
fi

# GOAL_PRESENT path: implemented in Task 5+ — for now, exit 0.
exit 0

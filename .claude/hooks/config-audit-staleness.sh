#!/bin/bash
# config-audit-staleness.sh — SessionStart hook.
# Reminds if /config-audit hasn't run in STALE_DAYS. Exit 0 always (non-blocking).
set -euo pipefail
TIMESTAMP_FILE="${HOME}/.claude/audit/.last-config-audit"
STALE_DAYS=14
if [[ ! -f "$TIMESTAMP_FILE" ]]; then
  echo "REMINDER: /config-audit has never been run. Consider auditing your .claude config surface."
  exit 0
fi
LAST_RUN=$(cat "$TIMESTAMP_FILE")
LAST_RUN_EPOCH=$(date -j -f "%Y-%m-%d" "$LAST_RUN" +%s 2>/dev/null || date -d "$LAST_RUN" +%s 2>/dev/null || echo 0)
[ "$LAST_RUN_EPOCH" -eq 0 ] && exit 0
NOW_EPOCH=$(date +%s)
DIFF_DAYS=$(( (NOW_EPOCH - LAST_RUN_EPOCH) / 86400 ))
if [[ "$DIFF_DAYS" -ge "$STALE_DAYS" ]]; then
  echo "REMINDER: /config-audit last ran ${DIFF_DAYS} days ago (${LAST_RUN}). Consider re-auditing."
fi
exit 0

#!/bin/bash
# done-hook.sh — Surface evidence against the captured session goal.
# Hook: Stop  (peer with context-watch.sh)
# Exit 0 always — coordinates with context-watch.sh, never blocks.
# Spec: docs/superpowers/specs/2026-05-18-done-hook-design.md §Component 3
set -o pipefail

# --- Helpers ---

# Extract the LAST stanza (## ...) body from the goal file.
extract_last_stanza() {
  local file="$1"
  awk '/^## /{buf=""} {buf=buf $0 "\n"} END{printf "%s", buf}' "$file"
}

# Extract the Goal: line (one-line summary).
extract_goal_name() {
  local stanza="$1"
  local raw
  raw=$(echo "$stanza" | grep -m1 '^Goal: ' | sed 's/^Goal: //; s/[[:space:]]*$//')
  [ -z "$raw" ] && raw="<unnamed>"
  if [ "${#raw}" -gt 60 ]; then
    raw="${raw:0:60}…"
  fi
  echo "$raw"
}

# Extract acceptance bullets (lines starting with "- " under "Acceptance:").
extract_bullets() {
  local stanza="$1"
  echo "$stanza" | awk '
    /^Acceptance:/ { in_acc=1; next }
    /^## / { in_acc=0 }
    in_acc && /^- / { sub(/^- /, ""); print }
  '
}

# Given a bullet, return matched evidence records (or empty).
# Looks for any token in the bullet that appears in the recent bash audit log.
match_bullet_evidence() {
  local bullet="$1" bash_log="$2"
  [ ! -f "$bash_log" ] && return 1
  # Anchors: paths, test-script names, command-like tokens.
  local anchors
  anchors=$(echo "$bullet" | grep -oE '(\.?\.?/[a-zA-Z0-9_/.-]+|[a-z][a-z0-9_-]{2,}_test\.sh|[a-z][a-z0-9_-]{2,}\.sh|docs/[a-zA-Z0-9_/.-]+|[a-z][a-z0-9_-]{2,})' | sort -u)
  local last_chunk
  last_chunk=$(tail -c 200000 "$bash_log" 2>/dev/null)
  while read -r anchor; do
    [ -z "$anchor" ] && continue
    # Skip noise words shorter than 3 chars (already filtered by regex but defensive)
    [ "${#anchor}" -lt 3 ] && continue
    if echo "$last_chunk" | grep -qF "$anchor"; then
      # Capture the matching line for evidence
      local line
      line=$(echo "$last_chunk" | grep -F "$anchor" | tail -1)
      printf '%s' "$line"
      return 0
    fi
  done <<< "$anchors"
  return 1
}

# JSON-escape a string (minimal: backslash, quote, control chars).
json_escape() {
  # shellcheck disable=SC2016
  python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().rstrip("\n"))[1:-1])' <<< "$1"
}

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

# --- Main GOAL_PRESENT path ---
# (replaces the previous `exit 0` stub)

STANZA=$(extract_last_stanza "$GOAL_FILE")
GOAL_NAME=$(extract_goal_name "$STANZA")
BULLETS=$(extract_bullets "$STANZA")
TOTAL=$(echo "$BULLETS" | sed '/^$/d' | wc -l | tr -d ' ')

BASH_LOG="${HOME}/.claude/audit/bash-commands-$(date -u +%Y-%m-%d).log"
MATCHED=0
EVIDENCE_RECORDS="["
FIRST_REC=1

while IFS= read -r bullet; do
  [ -z "$bullet" ] && continue
  evidence=$(match_bullet_evidence "$bullet" "$BASH_LOG")
  if [ -n "$evidence" ]; then
    MATCHED=$((MATCHED + 1))
    bullet_esc=$(json_escape "$bullet")
    evidence_esc=$(json_escape "$evidence")
    if [ "$FIRST_REC" -eq 1 ]; then
      FIRST_REC=0
    else
      EVIDENCE_RECORDS+=","
    fi
    EVIDENCE_RECORDS+="{\"bullet\":\"${bullet_esc}\",\"raw\":\"${evidence_esc}\"}"
  fi
done <<< "$BULLETS"
EVIDENCE_RECORDS+="]"

if [ "$TOTAL" -gt 0 ] && [ "$MATCHED" -ge "$((TOTAL - 1))" ]; then
  HEURISTIC="LIKELY_MET"
elif [ "$MATCHED" -gt 0 ]; then
  HEURISTIC="PARTIAL"
else
  HEURISTIC="NO_EVIDENCE"
fi

# Compute next seq for this session
SEQ=1
if [ -f "$OUTCOMES_LOG" ]; then
  PREV_SEQ=$(grep "\"session\":\"$UUID\"" "$OUTCOMES_LOG" 2>/dev/null | \
             grep -oE '"seq":[0-9]+' | grep -oE '[0-9]+' | sort -n | tail -1)
  [ -n "$PREV_SEQ" ] && SEQ=$((PREV_SEQ + 1))
fi

# State-change-hash debounce: hash of (goal-mtime, sorted evidence raws).
GOAL_MTIME=$(stat -f %m "$GOAL_FILE" 2>/dev/null || stat -c %Y "$GOAL_FILE" 2>/dev/null || echo 0)
STATE_HASH=$(printf '%s|%s' "$GOAL_MTIME" "$EVIDENCE_RECORDS" | shasum | cut -c1-12)

# Compare to last entry's state_hash for this session
LAST_HASH=""
if [ -f "$OUTCOMES_LOG" ]; then
  LAST_HASH=$(grep "\"session\":\"$UUID\"" "$OUTCOMES_LOG" | tail -1 | \
              grep -oE '"state_hash":"[^"]*"' | sed 's/"state_hash":"\(.*\)"/\1/')
fi
if [ -n "$LAST_HASH" ] && [ "$STATE_HASH" = "$LAST_HASH" ]; then
  exit 0  # no state change since last entry
fi

TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
GOAL_REL_PATH="session-goals/${UUID}.md"
printf '{"schema":1,"session":"%s","seq":%d,"ts":"%s","goal_file":"%s","heuristic":{"verdict":"%s","matched":%d,"total":%d},"evidence":%s,"state_hash":"%s","user":null}\n' \
  "$UUID" "$SEQ" "$TS" "$GOAL_REL_PATH" "$HEURISTIC" "$MATCHED" "$TOTAL" "$EVIDENCE_RECORDS" "$STATE_HASH" \
  >> "$OUTCOMES_LOG"

# suppress unused variable warning; GOAL_NAME is informational for future use
: "$GOAL_NAME"

exit 0

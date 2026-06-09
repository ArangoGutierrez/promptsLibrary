#!/usr/bin/env bash
# completion-gate.sh — Stop hook. Block ending a turn while unverified source edits exist.
# Mechanism: print {"decision":"block","reason":...} on stdout, exit 0 (probe-verified, CC 2.1.169).
# Fail-open: any internal problem -> exit 0 (never wedge a session).
# Spec: docs/superpowers/specs/2026-06-09-completion-gate-design.md (v2)
set -o pipefail

# 0. Kill-switch
[ "${COMPLETION_GATE:-on}" = "off" ] && exit 0

# 1. Read Stop-hook stdin
INPUT=$(cat)
TRANSCRIPT=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
SESSION=$(printf '%s' "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null)
[ -z "$TRANSCRIPT" ] && exit 0
[ ! -f "$TRANSCRIPT" ] && exit 0

LOGDIR="${CG_AUDIT_DIR:-$HOME/.claude/audit}"; mkdir -p "$LOGDIR" 2>/dev/null
LOG="$LOGDIR/completion-gate-$(date -u +%Y-%m-%d).log"
LEDGER="$LOGDIR/completion-gate-ledger-${SESSION}.txt"

# 2. Config (tunable)
SRC='\.(go|py|ts|tsx|js|jsx|rs|c|h|cc|cpp|java|rb|sh|bash)$'
DENY='(\.md$|\.txt$|LICENSE|\.gitignore$|\.lock$)'
VERIFY='(go (test|build|vet)( |$)|golangci-lint|make (test|build|lint|check|ci)( |$)|_test\.sh( |$)|(^| )bats( |$)|shellcheck|pytest|python[0-9.]* -m pytest|npm (test|run build|run lint)|cargo (test|build|clippy))'

# 3. Compute unverified source set (nested-schema walk; is_error absent => success)
UNV=$(jq -rs --arg src "$SRC" --arg deny "$DENY" --arg verify "$VERIFY" '
  (reduce .[] as $m ({};
     if $m.type=="user" then
       reduce (($m.message.content // []) | if type=="array" then .[] else empty end
               | select(type=="object" and .type=="tool_result")) as $r
         (.; .[$r.tool_use_id] = ($r.is_error // false))
     else . end)) as $res
  | [ .[] | select(.type=="assistant")
      | (.message.content // []) | if type=="array" then .[] else empty end
      | select(type=="object" and .type=="tool_use") ] as $tus
  | reduce $tus[] as $t ({};
      if ($t.name=="Write" or $t.name=="Edit" or $t.name=="MultiEdit")
         and (($t.input.file_path // "") | test($src))
         and ((($t.input.file_path // "") | test($deny)) | not)
      then . + {($t.input.file_path): true}
      elif ($t.name=="Bash") and (($t.input.command // "") | test($verify))
           and ($res | has($t.id)) and (($res[$t.id]) != true)
      then {}
      else . end)
  | keys[]
' "$TRANSCRIPT" 2>/dev/null)

# 4. Drop paths that no longer exist or are git-clean vs HEAD (revert/delete); keep untracked-new
FINAL=()
while IFS= read -r p; do
  [ -z "$p" ] && continue
  [ ! -e "$p" ] && continue
  d=$(dirname "$p")
  if git -C "$d" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    if git -C "$d" ls-files --error-unmatch "$p" >/dev/null 2>&1; then
      git -C "$d" diff --quiet HEAD -- "$p" 2>/dev/null && continue   # tracked & clean -> reverted
    fi
  fi
  FINAL+=("$p")
done <<< "$UNV"
[ "${#FINAL[@]}" -eq 0 ] && exit 0

# 5. Waiver: last assistant text begins a line with VERIFY-WAIVED:
LASTTXT=$(jq -rs 'map(select(.type=="assistant")) | (last // {}) | (.message.content // [])
                  | if type=="array" then (map(select(.type=="text").text) | join("\n")) else "" end' \
          "$TRANSCRIPT" 2>/dev/null)
if printf '%s\n' "$LASTTXT" | grep -qE '^[[:space:]]*VERIFY-WAIVED:'; then
  printf '{"ts":"%s","session":"%s","decision":"waiver"}\n' "$(date -u +%FT%TZ)" "$SESSION" >> "$LOG" 2>/dev/null
  exit 0
fi

# 6. Content-hash debounce (NOT mtime; auto-format perturbs mtime)
STATE=$( { for p in "${FINAL[@]}"; do printf '%s:' "$p"; shasum "$p" 2>/dev/null | cut -d' ' -f1; done; } | sort | shasum | cut -c1-16)
if [ -f "$LEDGER" ] && grep -qx "$STATE" "$LEDGER" 2>/dev/null; then
  printf '{"ts":"%s","session":"%s","decision":"override","state":"%s"}\n' "$(date -u +%FT%TZ)" "$SESSION" "$STATE" >> "$LOG" 2>/dev/null
  exit 0
fi
echo "$STATE" >> "$LEDGER" 2>/dev/null

# 7. Block: legitimate engineering reprompt (NOT injection-shaped)
files=$(printf '%s, ' "${FINAL[@]}"); files=${files%, }
reason="Completion gate: ${#FINAL[@]} source file(s) changed this session with no passing build/test/lint afterward: ${files}. Run the appropriate verification (e.g. go test ./... or the relevant linter) and include its output before ending the turn. If verification is genuinely impossible here, end your final message with a line:  VERIFY-WAIVED: <reason>"
printf '{"ts":"%s","session":"%s","decision":"block","n":%d,"state":"%s"}\n' "$(date -u +%FT%TZ)" "$SESSION" "${#FINAL[@]}" "$STATE" >> "$LOG" 2>/dev/null
jq -nc --arg r "$reason" '{decision:"block", reason:$r}'
exit 0

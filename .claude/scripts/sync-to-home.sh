#!/bin/bash
# sync-to-home.sh — copy this repo's owned .claude paths into ~/.claude.
# Dry-run by default; pass --apply to copy. Never overwrites settings.json.
# Override SYNC_SRC / SYNC_DST for testing.
set -uo pipefail

REPO_CLAUDE="${SYNC_SRC:-$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)}"
HOME_CLAUDE="${SYNC_DST:-$HOME/.claude}"
APPLY=0
[ "${1:-}" = "--apply" ] && APPLY=1

ALLOW="skills/reflection/SKILL.md
skills/reflection/scripts/promotion-candidates.sh
skills/config-audit
hooks/config-audit-staleness.sh
rules/prompt-defense.md"

echo "$ALLOW" | while IFS= read -r rel; do
  [ -n "$rel" ] || continue
  src="$REPO_CLAUDE/$rel"; dst="$HOME_CLAUDE/$rel"
  [ -e "$src" ] || { echo "skip (missing src): $rel"; continue; }
  if [ "$APPLY" -eq 1 ]; then
    mkdir -p "$(dirname "$dst")"
    rm -rf "$dst"          # mirror, don't nest: cp -R into an existing dir creates $dst/$(basename src)
    cp -R "$src" "$dst"
    echo "copied: $rel"
  else
    echo "DRYRUN would copy: $rel"
    diff -rq "$dst" "$src" 2>/dev/null || true
  fi
done

if ! grep -q "config-audit-staleness.sh" "$HOME_CLAUDE/settings.json" 2>/dev/null; then
  echo ""
  echo "ACTION NEEDED: add to $HOME_CLAUDE/settings.json SessionStart hooks:"
  echo '  { "type": "command", "command": "$HOME/.claude/hooks/config-audit-staleness.sh" }'
fi

[ "$APPLY" -eq 0 ] && echo "" && echo "(dry-run; re-run with --apply to copy)"
exit 0

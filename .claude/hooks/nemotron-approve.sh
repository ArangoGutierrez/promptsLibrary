#!/bin/bash
# nemotron-approve.sh - PreToolUse hook shim.
# Reads JSON from stdin, forwards to `python -m nemotron_approve`.
# Always exits 0 — Claude Code falls through to the existing permission flow
# if stdout is empty (which can happen if Python or the skill dir is missing).
set -o pipefail

# Allow overriding the skill location for integration tests that run from a
# worktree without deploying to $HOME first.
SKILL_DIR="${NEMOTRON_APPROVE_SKILL_DIR:-$HOME/.claude/skills/nemotron-approve}"

# Load env from env.sh so the hook works when Claude Code is launched outside
# an interactive shell (Cursor IDE Claude integration, system launches, etc.)
# and ~/.zshrc was never sourced.
if [ -f "$SKILL_DIR/env.sh" ]; then
    # shellcheck source=/dev/null
    . "$SKILL_DIR/env.sh"
fi

PYTHON="${NEMOTRON_APPROVE_PYTHON:-python3.12}"
if ! command -v "$PYTHON" >/dev/null 2>&1; then
    PYTHON=python3
fi
if ! command -v "$PYTHON" >/dev/null 2>&1; then
    exit 0
fi

cd "$SKILL_DIR" 2>/dev/null || exit 0
"$PYTHON" -m nemotron_approve 2>/dev/null || exit 0
exit 0

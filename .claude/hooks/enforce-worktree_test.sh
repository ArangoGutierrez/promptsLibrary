#!/bin/bash
# Test enforce-worktree.sh — verifies in-repo blocking and out-of-repo passthrough.
# Uses git symbolic-ref to switch branches without commits (sign-commits hook blocks commits).
# Tempdir under $HOME to avoid macOS /var vs /private/var symlink drift.
set -uo pipefail

HOOK="$HOME/.claude/hooks/enforce-worktree.sh"
TMPDIR=$(mktemp -d "$HOME/.enforce-worktree-test.XXXXXX")
trap "rm -rf $TMPDIR" EXIT

cd "$TMPDIR"
git init -q
git symbolic-ref HEAD refs/heads/agents-workbench

FAIL=0

run_case() {
    local label="$1" expected_exit="$2" file_path="$3" branch="${4:-agents-workbench}"
    git symbolic-ref HEAD "refs/heads/$branch"
    local input
    input=$(printf '{"tool_input":{"file_path":"%s"}}' "$file_path")
    local got_exit=0
    echo "$input" | "$HOOK" >/dev/null 2>&1 || got_exit=$?
    if [ "$got_exit" = "$expected_exit" ]; then
        echo "PASS: $label (exit=$got_exit)"
    else
        echo "FAIL: $label — expected exit=$expected_exit, got=$got_exit"
        FAIL=$((FAIL+1))
    fi
}

# Test 1 (regression — the bug we're fixing):
# Out-of-repo file should be allowed even on agents-workbench.
run_case "out-of-repo file allowed on agents-workbench" 0 "/Users/eduardoa/.claude/hooks/foo.sh"

# Test 2: in-repo source file (not in allowlist) should be blocked.
run_case "in-repo source file blocked on agents-workbench" 2 "$TMPDIR/src/foo.go"

# Test 3: in-repo allowed file (CLAUDE.md) should be allowed.
run_case "in-repo CLAUDE.md allowed on agents-workbench" 0 "$TMPDIR/CLAUDE.md"

# Test 4: in-repo .agents/* should be allowed.
run_case "in-repo .agents/* allowed on agents-workbench" 0 "$TMPDIR/.agents/plan.md"

# Test 5: non-agents-workbench branch should allow everything.
run_case "in-repo source file allowed off agents-workbench" 0 "$TMPDIR/src/foo.go" "main"

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "All tests PASS"
    exit 0
else
    echo "$FAIL test(s) FAILED"
    exit 1
fi

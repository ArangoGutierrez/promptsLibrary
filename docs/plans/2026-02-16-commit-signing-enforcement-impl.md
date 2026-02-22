# Commit Signing Enforcement — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Ensure all git commits (including from subagents and agent teams) always have signoff (`-s`) and GPG signature (`-S`).

**Architecture:** Two-layer defense: (1) Fix the Claude Code PreToolUse hook regex to catch `git commit` in chained commands, (2) Add a global git `prepare-commit-msg` hook that auto-adds `Signed-off-by:` so signoff happens even if `-s` flag is forgotten.

**Tech Stack:** Bash (hooks), Git config

---

### Task 1: Fix the Claude Hook Regex

**Files:**
- Modify: `~/.claude/hooks/sign-commits.sh` (full rewrite of detection logic)

**Step 1: Write a test script for the hook**

Create a test script that exercises the hook with various command patterns:

```bash
# File: /tmp/claude/test-sign-commits.sh
#!/bin/bash
# Test harness for sign-commits.sh

HOOK="$HOME/.claude/hooks/sign-commits.sh"
PASS=0
FAIL=0

test_hook() {
    local desc="$1"
    local command="$2"
    local expect="$3"  # "allow" or "block"

    local input="{\"tool_input\":{\"command\":\"$command\"}}"
    local output
    output=$(echo "$input" | bash "$HOOK" 2>&1)
    local code=$?

    if [ "$expect" = "allow" ] && [ $code -eq 0 ]; then
        echo "PASS: $desc"
        PASS=$((PASS + 1))
    elif [ "$expect" = "block" ] && [ $code -eq 2 ]; then
        echo "PASS: $desc"
        PASS=$((PASS + 1))
    else
        echo "FAIL: $desc (expected=$expect, got exit=$code)"
        FAIL=$((FAIL + 1))
    fi
}

# Non-commit commands — should always allow
test_hook "non-commit: ls" "ls -la" "allow"
test_hook "non-commit: git status" "git status" "allow"
test_hook "non-commit: git add" "git add ." "allow"
test_hook "non-commit: git push" "git push origin main" "allow"

# Simple commit — should block without flags
test_hook "simple: no flags" "git commit -m \"test\"" "block"

# Simple commit — should allow with both flags
test_hook "simple: -s -S" "git commit -s -S -m \"test\"" "allow"
test_hook "simple: --signoff --gpg-sign" "git commit --signoff --gpg-sign -m \"test\"" "allow"

# Chained commands — should block without flags
test_hook "chain &&: no flags" "git add . && git commit -m \"test\"" "block"
test_hook "chain ;: no flags" "cd /tmp; git commit -m \"test\"" "block"

# Chained commands — should allow with both flags
test_hook "chain &&: -s -S" "git add . && git commit -s -S -m \"test\"" "allow"
test_hook "chain ;: -s -S" "cd /tmp; git commit -s -S -m \"test\"" "allow"

# Partial flags — should block
test_hook "simple: only -s" "git commit -s -m \"test\"" "block"
test_hook "simple: only -S" "git commit -S -m \"test\"" "block"
test_hook "chain: only -s" "git add . && git commit -s -m \"test\"" "block"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] && exit 0 || exit 1
```

**Step 2: Run the test to verify current failures**

Run: `bash /tmp/claude/test-sign-commits.sh`
Expected: FAIL on all "chain" test cases (current hook misses them)

**Step 3: Rewrite sign-commits.sh with improved detection**

Replace the content of `~/.claude/hooks/sign-commits.sh` with:

```bash
#!/bin/bash
# sign-commits.sh - Ensure all commits are signed (-s -S)
# Hook: PreToolUse (matcher: Bash)
#
# Exit 0 = allow
# Exit 2 = block (stderr becomes Claude's feedback)

# Read JSON input from stdin
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Extract the git commit portion from potentially chained commands.
# Handles: "git commit ...", "cmd && git commit ...", "cmd; git commit ...", etc.
COMMIT_PART=$(echo "$COMMAND" | grep -oE '(^|[;&|]+\s*)git commit[^;&|]*' | sed 's/^[;&| ]*//')

# No git commit found anywhere — allow
if [ -z "$COMMIT_PART" ]; then
    exit 0
fi

# Check for -s or --signoff in the commit portion
has_signoff=false
if echo "$COMMIT_PART" | grep -qE '(\s|^)-s(\s|$)|--signoff'; then
    has_signoff=true
fi

# Check for -S or --gpg-sign in the commit portion
has_signature=false
if echo "$COMMIT_PART" | grep -qE '(\s|^)-S(\s|$)|--gpg-sign'; then
    has_signature=true
fi

# If both present, allow
if [ "$has_signoff" = true ] && [ "$has_signature" = true ]; then
    exit 0
fi

# Build message about what's missing
missing=""
if [ "$has_signoff" = false ]; then
    missing="-s (signoff)"
fi
if [ "$has_signature" = false ]; then
    if [ -n "$missing" ]; then
        missing="$missing and -S (GPG signature)"
    else
        missing="-S (GPG signature)"
    fi
fi

# Block and tell Claude what to add
echo "Blocked: All commits must be signed. Add $missing flags. Use: git commit -s -S -m \"message\"" >&2
exit 2
```

**Step 4: Run the test to verify all pass**

Run: `bash /tmp/claude/test-sign-commits.sh`
Expected: ALL tests PASS (0 failed)

**Step 5: Commit**

```bash
git add ~/.claude/hooks/sign-commits.sh
git commit -s -S -m "fix: improve sign-commits hook to catch chained commands"
```

---

### Task 2: Create Global Git prepare-commit-msg Hook

**Files:**
- Create: `~/.config/git/hooks/prepare-commit-msg`

**Step 1: Create the hooks directory**

Run: `mkdir -p ~/.config/git/hooks`

**Step 2: Write the prepare-commit-msg hook**

```bash
#!/bin/bash
# prepare-commit-msg - Auto-add Signed-off-by if missing
# Global git hook (via core.hooksPath)

COMMIT_MSG_FILE="$1"
COMMIT_SOURCE="$2"

# Only modify for normal commits and message commits, not merges/squashes
if [ "$COMMIT_SOURCE" = "merge" ] || [ "$COMMIT_SOURCE" = "squash" ]; then
    exit 0
fi

# Get user identity
NAME=$(git config user.name)
EMAIL=$(git config user.email)
SOB="Signed-off-by: $NAME <$EMAIL>"

# Add Signed-off-by if not already present
if ! grep -qF "$SOB" "$COMMIT_MSG_FILE"; then
    echo "" >> "$COMMIT_MSG_FILE"
    echo "$SOB" >> "$COMMIT_MSG_FILE"
fi
```

**Step 3: Make it executable**

Run: `chmod +x ~/.config/git/hooks/prepare-commit-msg`

**Step 4: Test manually — verify signoff is added**

Run:
```bash
cd /tmp/claude && git init test-signoff && cd test-signoff
git commit --allow-empty -m "test without -s flag"
git log -1 --format="%B"
```

Expected: Commit message should contain `Signed-off-by: Carlos Eduardo Arango Gutierrez <eduardoa@nvidia.com>`

**Step 5: Clean up test repo**

Run: `rm -rf /tmp/claude/test-signoff`

**Step 6: Commit the hook (from ~/.claude working directory)**

Note: The hook lives outside the ~/.claude repo. No git commit needed for this file itself,
but document its existence. Proceed to Task 3.

---

### Task 3: Set core.hooksPath in Global Git Config

**Step 1: Set the config**

Run: `git config --global core.hooksPath ~/.config/git/hooks`

**Step 2: Verify it's set**

Run: `git config --global core.hooksPath`
Expected: `/Users/eduardoa/.config/git/hooks` (or `~/.config/git/hooks`)

**Step 3: End-to-end test — chained command in a temp repo**

Run:
```bash
cd /tmp/claude && git init test-e2e && cd test-e2e
git commit --allow-empty -m "end-to-end test"
git log -1 --format="%B"
```

Expected: Message includes `Signed-off-by:` line (from prepare-commit-msg hook).

**Step 4: Verify GPG signing still works**

Run: `git log -1 --show-signature` (in the test-e2e repo)
Expected: Shows valid signature (SSH key)

**Step 5: Clean up**

Run: `rm -rf /tmp/claude/test-e2e`

**Step 6: Commit cleanup script and test**

From `~/.claude`:
```bash
git add hooks/sign-commits.sh
git commit -s -S -m "fix: improve sign-commits hook to catch chained commands"
```

(If already committed in Task 1, skip this step.)

---

### Task 4: Final Verification

**Step 1: Run the hook test suite one final time**

Run: `bash /tmp/claude/test-sign-commits.sh`
Expected: ALL PASS

**Step 2: Clean up test files**

Run: `rm /tmp/claude/test-sign-commits.sh`

**Step 3: Commit the implementation plan**

```bash
git add docs/plans/2026-02-16-commit-signing-enforcement-impl.md
git commit -s -S -m "docs: add commit signing enforcement implementation plan"
```

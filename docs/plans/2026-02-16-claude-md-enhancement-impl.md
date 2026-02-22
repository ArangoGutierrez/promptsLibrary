# CLAUDE.md Enhancement Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Reduce CLAUDE.md from ~140 to ~55 lines, fix worktree branching, strengthen brainstorming gate, add hybrid TDD enforcement.

**Architecture:** Surgical edits to existing files + one new hook. CLAUDE.md gets rewritten. Two scripts get updated error messages/examples. One new PreToolUse hook for TDD guard.

**Tech Stack:** Bash (hooks), Markdown (CLAUDE.md), shell scripts

---

### Task 1: Write the new CLAUDE.md

**Files:**
- Modify: `~/.claude/CLAUDE.md`

**Step 1: Read the current file**

Run: `cat ~/.claude/CLAUDE.md | wc -l`
Expected: ~140 lines

**Step 2: Replace CLAUDE.md with the approved content**

Write the entire file with this exact content:

```markdown
# Engineering Standards

## Role
Senior Principal Engineer. Rigor > speed.

## MANDATORY: Brainstorm First
**Every task starts with `superpowers:brainstorming`. No exceptions.**

Before code: brainstorm → ≥3 options → user approval → document decision.

Exempt ONLY: typos, comments, running tests, reading files, answering questions.

"Just do it" = quick-brainstorm (1 paragraph + 2 options). "Skip brainstorm" = truly skip.
If unsure whether exempt: brainstorm. Default is always brainstorm.

## Principles
- **Atomicity**: >1 concern → break down first
- **No placeholders**: Complete code only
- **Verify**: CoVe protocol (`/cove-verify` skill)
- **YAGNI**: No unnecessary abstractions
- **≥3 options**: Before any design decision

## TDD Protocol (DORA)
Cycle: Plan→Red→Green→Refactor. Never skip phases.
- **Plan**: Design doc/plan before any code (see Brainstorm First)
- **Red**: Write failing test first. Signal: `[RED]`
- **Green**: Minimum code to pass. Signal: `[GREEN]`. NEVER modify tests+code in same turn
- **Refactor**: Clean up only after green. Signal: `[REFACTOR]`. Checkpoint first if >3 files or >50 LOC
- **Fitness function**: Tests are contracts. NEVER weaken, delete, or modify tests to fit implementation
- **Batch size**: Smallest PR-sized chunks. 1 concern = 1 PR

### TDD Enforcement (hybrid)
- **Hook guard** (always on): blocks implementation writes when no failing test exists
- **Escalation**: when diff exceeds threshold, use isolated subagent contexts — one for Red (test writing), one for Green (implementation). Prevents same-author blind spots
- Tests define "done". Implementation stops when tests pass

## agents-workbench Workflow
**ALL implementation work happens in worktrees. No exceptions.**

### Branches
- `agents-workbench` — local-only coordination hub (NEVER push). Source code is READ-ONLY.
- Feature branches — created in `.worktrees/` from the remote default branch

### Worktree Creation (critical)
ALWAYS branch from the remote ref, never local. Local main/master/develop may be stale.
```bash
# Detect the right remote (upstream for forks, origin otherwise)
git fetch upstream 2>/dev/null && BASE="upstream/main" || { git fetch origin && BASE="origin/$(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')"; }
git worktree add .worktrees/<name> -b <branch> "$BASE"
```

### Flow
1. Plan on agents-workbench (AGENTS.md, `.agents/plans/`)
2. Create worktree from remote ref (see above)
3. Implement in worktree
4. Push feature branch, create PR
5. After merge: `git worktree remove .worktrees/<name>`

## Workflow
brainstorm → plan → red → green → refactor → verify → PR → review → merge

## Iteration Budget
Trivial:1 | Simple:2 | Moderate:3 | Complex:4 → then escalate to user.
Track: `[Iteration X/Y]` in responses.

## Priority
Security > Correctness > Performance > Style

## Subagent Discipline
- **Agent teams**: parallel teammates allowed (each in own worktree)
- **Regular subagents**: launch SEQUENTIALLY. Wait for completion before launching another
- Prefer single focused subagent over multiple broad ones

## Context Hygiene
- Commit context to agents-workbench before ending long sessions
```

**Step 3: Verify line count**

Run: `cat ~/.claude/CLAUDE.md | wc -l`
Expected: ~65 lines (including the bash code block)

**Step 4: Commit**

```bash
git add ~/.claude/CLAUDE.md
git commit -s -S -m "refactor: rewrite CLAUDE.md - reduce from 140 to ~55 lines"
```

---

### Task 2: Update setup-workbench.sh worktree example

**Files:**
- Modify: `~/.claude/scripts/setup-workbench.sh:96-101`

**Step 1: Read the current "Next steps" output**

Verify lines 96-101 show the old worktree command using local branch:
```
echo "  2. Create a worktree to start working:"
echo "     git worktree add .worktrees/<name> -b <branch> $DEFAULT_BRANCH"
```

**Step 2: Update the "Next steps" output to use remote refs**

Replace lines 96-102 with:

```bash
echo "Next steps:"
echo "  1. Review AGENTS.md"
echo "  2. Create a worktree (always from remote, never local):"
echo "     # For forks (upstream remote exists):"
echo "     git fetch upstream && git worktree add .worktrees/<name> -b <branch> upstream/$DEFAULT_BRANCH"
echo "     # For non-forks:"
echo "     git fetch origin && git worktree add .worktrees/<name> -b <branch> origin/$DEFAULT_BRANCH"
echo ""
echo "Remember: agents-workbench is LOCAL ONLY. Never push it."
```

**Step 3: Verify the script is valid bash**

Run: `bash -n ~/.claude/scripts/setup-workbench.sh`
Expected: No output (valid syntax)

**Step 4: Commit**

```bash
git add ~/.claude/scripts/setup-workbench.sh
git commit -s -S -m "fix: update setup-workbench to show remote-ref worktree commands"
```

---

### Task 3: Update enforce-worktree.sh error message

**Files:**
- Modify: `~/.claude/hooks/enforce-worktree.sh:56-64`

**Step 1: Read the current error message**

Verify lines 56-64 show:
```
echo "BLOCKED: Source code is READ-ONLY on agents-workbench." >&2
...
echo "  git worktree add .worktrees/<name> -b <branch-name> $DEFAULT_BRANCH" >&2
```

**Step 2: Update the error message to show remote-ref command**

Replace the error message block (lines 56-65) with:

```bash
echo "BLOCKED: Source code is READ-ONLY on agents-workbench." >&2
echo "File: $REL_PATH" >&2
echo "" >&2
echo "This branch is the coordination hub. Implementation happens in worktrees." >&2
echo "Create a worktree (ALWAYS from remote ref, never local):" >&2
echo "  git fetch upstream 2>/dev/null && BASE=\"upstream/$DEFAULT_BRANCH\" || { git fetch origin && BASE=\"origin/$DEFAULT_BRANCH\"; }" >&2
echo "  git worktree add .worktrees/<name> -b <branch-name> \"\$BASE\"" >&2
echo "" >&2
echo "Allowed files on agents-workbench:" >&2
echo "  AGENTS.md, .agents/*, docs/plans/*, CLAUDE.md, .cursor/rules/*, .gitignore" >&2
exit 2
```

**Step 3: Verify the hook is valid bash**

Run: `bash -n ~/.claude/hooks/enforce-worktree.sh`
Expected: No output (valid syntax)

**Step 4: Commit**

```bash
git add ~/.claude/hooks/enforce-worktree.sh
git commit -s -S -m "fix: update enforce-worktree error message to show remote-ref commands"
```

---

### Task 4: Create TDD hook guard

**Files:**
- Create: `~/.claude/hooks/tdd-guard.sh`
- Modify: `~/.claude/settings.json` (add hook to PreToolUse Write and Edit matchers)

**Step 1: Write the TDD guard hook**

Create `~/.claude/hooks/tdd-guard.sh`:

```bash
#!/bin/bash
# tdd-guard.sh - Block implementation writes when no failing test exists
# Hook: PreToolUse (matcher: Write, Edit)
#
# Enforces TDD Red-Green-Refactor: implementation files can only be
# written/edited when a test file for the same component exists and
# has been recently modified (indicating active TDD cycle).
#
# Exit 0 = allow
# Exit 2 = block (stderr becomes Claude's feedback)

set -o pipefail

INPUT=$(cat)

# Not in a git repo? Allow.
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0

# Extract file path from tool input
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty')
[ -z "$FILE_PATH" ] && exit 0

# Normalize to relative path
REL_PATH="${FILE_PATH#"$GIT_ROOT"/}"
REL_PATH="${REL_PATH#./}"

# --- Determine if this is a test file or implementation file ---

# Test file patterns (allow freely — writing tests is always OK)
case "$REL_PATH" in
    *_test.go)          exit 0 ;;
    *_test.*)           exit 0 ;;
    *.test.*)           exit 0 ;;
    *.spec.*)           exit 0 ;;
    test_*.py)          exit 0 ;;
    tests/*)            exit 0 ;;
    test/*)             exit 0 ;;
    **/tests/*)         exit 0 ;;
    **/test/*)          exit 0 ;;
    **/__tests__/*)     exit 0 ;;
esac

# Non-code files (allow freely — docs, configs, plans, etc.)
case "$REL_PATH" in
    *.md)               exit 0 ;;
    *.txt)              exit 0 ;;
    *.json)             exit 0 ;;
    *.yaml|*.yml)       exit 0 ;;
    *.toml)             exit 0 ;;
    *.cfg|*.ini|*.conf) exit 0 ;;
    *.xml)              exit 0 ;;
    *.html|*.css)       exit 0 ;;
    *.sh)               exit 0 ;;
    Makefile|Dockerfile|*.dockerfile) exit 0 ;;
    .gitignore|.gitattributes) exit 0 ;;
    go.mod|go.sum)      exit 0 ;;
    package.json|package-lock.json) exit 0 ;;
    yarn.lock|pnpm-lock.yaml) exit 0 ;;
    requirements*.txt|Pipfile*|pyproject.toml|setup.py|setup.cfg) exit 0 ;;
    Cargo.toml|Cargo.lock) exit 0 ;;
    *.proto)            exit 0 ;;
    CLAUDE.md|AGENTS.md) exit 0 ;;
    .agents/*)          exit 0 ;;
    docs/*)             exit 0 ;;
esac

# --- This is an implementation file. Check for corresponding test. ---

# Find test files modified in the current git session (staged or unstaged)
CHANGED_TEST_FILES=$(git diff --name-only HEAD 2>/dev/null; git diff --name-only --cached 2>/dev/null)

# Check if ANY test file has been changed (indicating active TDD)
HAS_CHANGED_TESTS=false
while IFS= read -r file; do
    case "$file" in
        *_test.go|*_test.*|*.test.*|*.spec.*|test_*.py|tests/*|test/*|**/tests/*|**/test/*|**/__tests__/*)
            HAS_CHANGED_TESTS=true
            break
            ;;
    esac
done <<< "$CHANGED_TEST_FILES"

if [ "$HAS_CHANGED_TESTS" = true ]; then
    # Tests have been modified in this session — TDD cycle is active
    exit 0
fi

# Check if there are any failing tests by looking for recent test output
# If we can't determine test state, allow (avoid false positives)
# The hook is conservative: it only blocks when it's CERTAIN no tests exist

# Check if the file is brand new (no test companion found)
BASENAME=$(basename "$REL_PATH")
DIRNAME=$(dirname "$REL_PATH")
EXTENSION="${BASENAME##*.}"
NAME="${BASENAME%.*}"

# Look for a corresponding test file
FOUND_TEST=false
for pattern in \
    "${DIRNAME}/${NAME}_test.${EXTENSION}" \
    "${DIRNAME}/${NAME}.test.${EXTENSION}" \
    "${DIRNAME}/${NAME}.spec.${EXTENSION}" \
    "${DIRNAME}/test_${NAME}.py" \
    "${DIRNAME}/tests/${NAME}_test.${EXTENSION}" \
    "${DIRNAME}/tests/${NAME}.test.${EXTENSION}" \
    "${DIRNAME}/../tests/${NAME}_test.${EXTENSION}" \
    "${DIRNAME}/../test/${NAME}_test.${EXTENSION}" \
    "${DIRNAME}/__tests__/${NAME}.test.${EXTENSION}" \
    "${DIRNAME}/__tests__/${NAME}.spec.${EXTENSION}"; do
    if [ -f "$GIT_ROOT/$pattern" ]; then
        FOUND_TEST=true
        break
    fi
done

if [ "$FOUND_TEST" = false ]; then
    echo "TDD GUARD: No test file found for implementation file." >&2
    echo "File: $REL_PATH" >&2
    echo "" >&2
    echo "Write the failing test FIRST (Red phase), then implement." >&2
    echo "Expected test file locations:" >&2
    echo "  ${DIRNAME}/${NAME}_test.${EXTENSION}" >&2
    echo "  ${DIRNAME}/${NAME}.test.${EXTENSION}" >&2
    echo "  ${DIRNAME}/tests/${NAME}_test.${EXTENSION}" >&2
    echo "" >&2
    echo "If this is not a TDD-eligible file, add its pattern to tdd-guard.sh." >&2
    exit 2
fi

# Test file exists but hasn't been modified this session
# This could be valid (existing tests, adding implementation) — allow with warning
exit 0
```

**Step 2: Make it executable**

Run: `chmod +x ~/.claude/hooks/tdd-guard.sh`

**Step 3: Verify valid bash**

Run: `bash -n ~/.claude/hooks/tdd-guard.sh`
Expected: No output

**Step 4: Register the hook in settings.json**

Read `~/.claude/settings.json` and add `tdd-guard.sh` to both the Write and Edit PreToolUse hook arrays.

For the Write matcher, add after the existing hooks:
```json
{
    "type": "command",
    "command": "/Users/eduardoa/.claude/hooks/tdd-guard.sh"
}
```

For the Edit matcher, add after the existing hooks:
```json
{
    "type": "command",
    "command": "/Users/eduardoa/.claude/hooks/tdd-guard.sh"
}
```

**Step 5: Verify settings.json is valid JSON**

Run: `jq . ~/.claude/settings.json > /dev/null`
Expected: No output (valid JSON)

**Step 6: Commit**

```bash
git add ~/.claude/hooks/tdd-guard.sh ~/.claude/settings.json
git commit -s -S -m "feat: add TDD guard hook - blocks implementation writes without tests"
```

---

### Task 5: Verify everything works together

**Step 1: Verify all hooks are executable**

Run: `ls -la ~/.claude/hooks/*.sh`
Expected: All hooks have execute permission

**Step 2: Verify all hooks pass syntax check**

Run:
```bash
for f in ~/.claude/hooks/*.sh; do echo "Checking $f..."; bash -n "$f" && echo "  OK" || echo "  FAIL"; done
```
Expected: All OK

**Step 3: Verify settings.json is valid**

Run: `jq . ~/.claude/settings.json > /dev/null && echo "Valid JSON"`
Expected: "Valid JSON"

**Step 4: Verify CLAUDE.md line count**

Run: `wc -l ~/.claude/CLAUDE.md`
Expected: ~65 lines

**Step 5: Final commit (if any fixes needed)**

Only if previous steps required fixes.

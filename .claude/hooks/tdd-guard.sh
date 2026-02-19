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

# Escape hatch for exceptional cases (hotfixes, generated code)
[ "${SKIP_TDD_GUARD:-}" = "1" ] && exit 0

INPUT=$(cat)

# Not in a git repo? Allow.
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0

# Git mid-operation? Allow — this is integration work, not new implementation.
GIT_DIR=$(git rev-parse --git-dir 2>/dev/null) || exit 0
for sentinel in \
    "$GIT_DIR/MERGE_HEAD" \
    "$GIT_DIR/CHERRY_PICK_HEAD" \
    "$GIT_DIR/REVERT_HEAD" \
    "$GIT_DIR/rebase-merge" \
    "$GIT_DIR/rebase-apply"; do
    [ -e "$sentinel" ] && exit 0
done

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
    */test_*.py)        exit 0 ;;
    tests/*)            exit 0 ;;
    test/*)             exit 0 ;;
    */tests/*)          exit 0 ;;
    */test/*)           exit 0 ;;
    */__tests__/*)      exit 0 ;;
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
    *commitlint.config.*|*.commitlintrc.*) exit 0 ;;
    *next.config.*|*eslint.config.*|*.eslintrc.*) exit 0 ;;
    .gitignore|.gitattributes) exit 0 ;;
    go.mod|go.sum)      exit 0 ;;
    package.json|package-lock.json) exit 0 ;;
    yarn.lock|pnpm-lock.yaml) exit 0 ;;
    requirements*.txt|Pipfile*|pyproject.toml|setup.py|setup.cfg) exit 0 ;;
    Cargo.toml|Cargo.lock) exit 0 ;;
    *.proto)            exit 0 ;;
    *.tf|*.tfvars|*.hcl) exit 0 ;;
    CLAUDE.md|AGENTS.md) exit 0 ;;
    .agents/*)          exit 0 ;;
    .worktrees/*)       exit 0 ;;
    docs/*)             exit 0 ;;
esac

# --- This is an implementation file. Check for corresponding test. ---

# Find test files modified in the current git session (staged or unstaged)
CHANGED_TEST_FILES=$(git diff --name-only HEAD 2>/dev/null; git diff --name-only --cached 2>/dev/null)

# Check if ANY test file has been changed (indicating active TDD)
HAS_CHANGED_TESTS=false
while IFS= read -r file; do
    case "$file" in
        *_test.go|*_test.*|*.test.*|*.spec.*|test_*.py|*/test_*.py|tests/*|test/*|*/tests/*|*/test/*|*/__tests__/*)
            HAS_CHANGED_TESTS=true
            break
            ;;
    esac
done <<< "$CHANGED_TEST_FILES"

if [ "$HAS_CHANGED_TESTS" = true ]; then
    # Tests have been modified in this session — TDD cycle is active
    exit 0
fi

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
    "${DIRNAME}/tests/test_${NAME}.py" \
    "${DIRNAME}/../tests/test_${NAME}.py" \
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

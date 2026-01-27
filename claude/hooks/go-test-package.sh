#!/bin/bash
# go-test-package.sh - Run tests before commit
# Hook: beforeShellExecution
#
# Runs tests for affected packages before committing.
# Catches failing tests early in the development workflow.

set -e

if ! command -v jq &> /dev/null; then
    echo '{"continue": true, "permission": "allow"}'
    exit 0
fi

input=$(cat)
command=$(echo "$input" | jq -r '.command // empty')

# Only intercept git commit commands
if ! echo "$command" | grep -qE "^git commit"; then
    echo '{"continue": true, "permission": "allow"}'
    exit 0
fi

# Find modified Go files in staging area
modified_files=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null | grep '\.go$' || true)

if [ -z "$modified_files" ]; then
    # No Go files modified, allow commit
    echo '{"continue": true, "permission": "allow"}'
    exit 0
fi

# Extract unique package directories
packages=$(echo "$modified_files" | xargs -n1 dirname 2>/dev/null | sort -u)

# Run tests for affected packages
echo "🧪 Running tests for modified packages..." >&2
failed_packages=""
test_output=""

for pkg in $packages; do
    echo "  Testing: $pkg" >&2
    pkg_output=$(go test -timeout=30s "./$pkg" 2>&1 || true)

    # Check if tests failed
    if echo "$pkg_output" | grep -q "FAIL"; then
        failed_packages="$failed_packages $pkg"
        test_output="$test_output\n\nPackage: $pkg\n$pkg_output"
    else
        echo "    ✓ Passed" >&2
    fi
done

if [ -n "$failed_packages" ]; then
    # Tests failed - ask user with output
    # Escape output for JSON
    escaped_output=$(printf '%s' "$test_output" | jq -Rs '.')

    cat << EOF
{
  "continue": true,
  "permission": "ask",
  "user_message": "⚠️ Tests failed in:$failed_packages",
  "agent_message": "Some tests failed. Review the output:\n\n$escaped_output\n\nDo you want to commit anyway?"
}
EOF
else
    echo "✅ All tests passed" >&2
    echo '{"continue": true, "permission": "allow"}'
fi

exit 0

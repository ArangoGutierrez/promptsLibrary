#!/bin/bash
# go-lint.sh - Auto-lint Go files after edit
# Hook: afterFileEdit
#
# Runs golangci-lint on edited Go files for instant feedback.
# Catches bugs, performance issues, and style violations.

set -e

if ! command -v jq &> /dev/null; then
    exit 0
fi

input=$(cat)
file_path=$(echo "$input" | jq -r '.file_path // empty')

# Only process .go files
if [[ "$file_path" != *.go ]]; then
    exit 0
fi

# Security: validate path
if [[ "$file_path" == *".."* ]]; then
    echo "Security: path traversal blocked" >&2
    exit 0
fi

if [ ! -f "$file_path" ]; then
    exit 0
fi

# Check if golangci-lint is installed
if ! command -v golangci-lint &> /dev/null; then
    # Silent exit - don't block if not installed
    # To install: brew install golangci-lint
    exit 0
fi

# Run golangci-lint on the specific file
# Use --fast for quick feedback, only on new/modified code
# Suppress output unless there are issues (silent success)
output=$(golangci-lint run \
    --fast \
    --new-from-rev=HEAD \
    --path-prefix="" \
    "$file_path" 2>&1 || true)

# Only show output if there are issues
if [ -n "$output" ] && ! echo "$output" | grep -q "^$"; then
    echo "$output" | head -20 >&2
fi

exit 0

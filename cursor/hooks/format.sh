#!/bin/bash
# format.sh - Auto-format files after edit
# Hook: afterFileEdit

set -e

# Prerequisite check
if ! command -v jq &> /dev/null; then
    echo '{"error": "jq is required but not installed. Run: brew install jq"}' >&2
    exit 0
fi

# Read JSON input from stdin
input=$(cat)
file_path=$(echo "$input" | jq -r '.file_path // empty')

if [ -z "$file_path" ]; then
    exit 0
fi

# Security: Validate file path
# 1. No path traversal attempts
if [[ "$file_path" == *".."* ]]; then
    echo "Security: path traversal blocked" >&2
    exit 0
fi

# 2. Must be within current working directory (project root)
# Resolve to absolute path and check prefix
resolved_path=$(realpath -m "$file_path" 2>/dev/null || echo "$file_path")
project_root=$(pwd)

if [[ "$resolved_path" != "$project_root"* ]]; then
    echo "Security: path outside project blocked" >&2
    exit 0
fi

# 3. Must be a regular file (not symlink to outside, device, etc.)
if [ -e "$file_path" ] && [ ! -f "$file_path" ]; then
    exit 0
fi

# Get file extension
ext="${file_path##*.}"

# Format based on file type
case "$ext" in
    go)
        if command -v gofmt &> /dev/null; then
            gofmt -w "$file_path" 2>/dev/null || true
        fi
        ;;
    ts|tsx|js|jsx|json|md)
        if command -v npx &> /dev/null && [ -f "node_modules/.bin/prettier" ]; then
            npx prettier --write "$file_path" 2>/dev/null || true
        fi
        ;;
    py)
        if command -v ruff &> /dev/null; then
            ruff format "$file_path" 2>/dev/null || true
        elif command -v black &> /dev/null; then
            black "$file_path" 2>/dev/null || true
        fi
        ;;
    rs)
        if command -v rustfmt &> /dev/null; then
            rustfmt "$file_path" 2>/dev/null || true
        fi
        ;;
esac

exit 0

#!/bin/bash
# format.sh - Auto-format files after edit
# Hook: afterFileEdit
#
# Automatically formats code files based on their extension using
# standard formatters: gofmt, prettier, ruff/black, rustfmt

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

# 2. File must exist and be a regular file (not directory, device, etc.)
if [ ! -e "$file_path" ]; then
    exit 0
fi

# 3. If it's a symlink, resolve and validate the ACTUAL target
# This prevents symlink attacks where project/link -> /etc/passwd
project_root=$(pwd)

if [ -L "$file_path" ]; then
    # Resolve the symlink target (follows all symlinks to final destination)
    resolved_target=$(realpath "$file_path" 2>/dev/null)
    if [ -z "$resolved_target" ]; then
        echo "Security: cannot resolve symlink target" >&2
        exit 0
    fi
    # Validate the REAL target is within project
    if [[ "$resolved_target" != "$project_root" && "$resolved_target" != "$project_root/"* ]]; then
        echo "Security: symlink target outside project blocked" >&2
        exit 0
    fi
    # Must resolve to a regular file
    if [ ! -f "$resolved_target" ]; then
        exit 0
    fi
else
    # Not a symlink - validate path directly
    resolved_path=$(realpath "$file_path" 2>/dev/null || echo "$file_path")
    if [[ "$resolved_path" != "$project_root" && "$resolved_path" != "$project_root/"* ]]; then
        echo "Security: path outside project blocked" >&2
        exit 0
    fi
    # Must be a regular file
    if [ ! -f "$file_path" ]; then
        exit 0
    fi
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

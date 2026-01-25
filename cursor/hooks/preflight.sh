#!/bin/bash
# preflight.sh - Pre-flight validation utilities for Cursor commands
# Source this in other hooks or use check_* functions directly
#
# Usage in commands: Source and call check functions
#   source ~/.cursor/hooks/preflight.sh
#   check_required gh jq git || exit 1

# Check if a command exists
check_cmd() {
    command -v "$1" &>/dev/null
}

# Check multiple required commands, report missing
check_required() {
    local missing=()
    for cmd in "$@"; do
        if ! check_cmd "$cmd"; then
            missing+=("$cmd")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo "Missing required tools: ${missing[*]}" >&2
        echo "Install with:" >&2
        for cmd in "${missing[@]}"; do
            case "$cmd" in
                gh)  echo "  brew install gh" >&2 ;;
                jq)  echo "  brew install jq" >&2 ;;
                flock) echo "  brew install flock (or util-linux)" >&2 ;;
                rg)  echo "  brew install ripgrep" >&2 ;;
                *)   echo "  brew install $cmd" >&2 ;;
            esac
        done
        return 1
    fi
    return 0
}

# Check if in a git repository
check_git_repo() {
    if ! git rev-parse --git-dir &>/dev/null; then
        echo "Error: Not in a git repository" >&2
        return 1
    fi
    return 0
}

# Check if GitHub CLI is authenticated
check_gh_auth() {
    if ! gh auth status &>/dev/null; then
        echo "Error: GitHub CLI not authenticated. Run: gh auth login" >&2
        return 1
    fi
    return 0
}

# Check if AGENTS.md exists
check_agents_file() {
    if [ ! -f "AGENTS.md" ]; then
        echo "Error: AGENTS.md not found. Run /issue first to create task list." >&2
        return 1
    fi
    return 0
}

# Check if there are uncommitted changes
check_clean_working_tree() {
    if ! git diff --quiet || ! git diff --cached --quiet; then
        echo "Warning: Uncommitted changes detected" >&2
        return 1
    fi
    return 0
}

# Check if current branch is up to date with remote
check_branch_synced() {
    local branch=$(git rev-parse --abbrev-ref HEAD)
    git fetch origin "$branch" --quiet 2>/dev/null || return 0
    
    local local_sha=$(git rev-parse HEAD)
    local remote_sha=$(git rev-parse "origin/$branch" 2>/dev/null || echo "")
    
    if [ -n "$remote_sha" ] && [ "$local_sha" != "$remote_sha" ]; then
        echo "Warning: Branch not synced with origin/$branch" >&2
        return 1
    fi
    return 0
}

# Full pre-flight for /issue command
preflight_issue() {
    check_required gh jq git || return 1
    check_git_repo || return 1
    check_gh_auth || return 1
    return 0
}

# Full pre-flight for /code command
preflight_code() {
    check_required git || return 1
    check_git_repo || return 1
    check_agents_file || return 1
    return 0
}

# Full pre-flight for /push command
preflight_push() {
    check_required git gh || return 1
    check_git_repo || return 1
    check_gh_auth || return 1
    return 0
}

# Full pre-flight for /loop command
preflight_loop() {
    check_required jq || return 1
    check_agents_file || return 1
    return 0
}

# Escape string for safe JSON inclusion
# Prevents JSON injection via specially crafted error messages
json_escape() {
    printf '%s' "$1" | jq -Rs '.'
}

# Output JSON result for Cursor hooks
# Usage: preflight_result "error message" → returns JSON with error
#        preflight_result → returns JSON with success
preflight_result() {
    if [ -n "$1" ]; then
        # Escape error message to prevent JSON injection
        local escaped_error
        if command -v jq &>/dev/null; then
            escaped_error=$(json_escape "$1")
            # Remove surrounding quotes added by jq -Rs
            escaped_error="${escaped_error:1:-1}"
        else
            # Fallback: basic escaping for quotes and backslashes
            escaped_error="${1//\\/\\\\}"
            escaped_error="${escaped_error//\"/\\\"}"
            escaped_error="${escaped_error//$'\n'/\\n}"
            escaped_error="${escaped_error//$'\r'/\\r}"
            escaped_error="${escaped_error//$'\t'/\\t}"
        fi
        cat << EOF
{
  "continue": false,
  "error": "$escaped_error"
}
EOF
    else
        cat << 'EOF'
{
  "continue": true
}
EOF
    fi
}

#!/bin/bash
# security-gate.sh - Block dangerous shell commands
# Hook: beforeShellExecution

set -e

# Prerequisite check
if ! command -v jq &> /dev/null; then
    echo '{"error": "jq is required but not installed. Run: brew install jq"}' >&2
    exit 0
fi

# Read JSON input from stdin
input=$(cat)
command=$(echo "$input" | jq -r '.command // empty')

# Dangerous patterns to block (require explicit approval)
DANGEROUS_PATTERNS=(
    "git push.*--force"
    "git push.*-f"
    "git reset --hard"
    "rm -rf /"
    "rm -rf ~"
    "rm -rf \*"
    "> /dev/sd"
    "mkfs\."
    "dd if=.* of=/dev"
    "chmod -R 777"
    ":(){:|:&};:"
)

# Check for dangerous patterns
for pattern in "${DANGEROUS_PATTERNS[@]}"; do
    if echo "$command" | grep -qE "$pattern"; then
        cat << EOF
{
  "continue": true,
  "permission": "ask",
  "user_message": "⚠️ Potentially dangerous command detected: $command",
  "agent_message": "This command matches a dangerous pattern ($pattern). Please confirm this is intentional before proceeding."
}
EOF
        exit 0
    fi
done

# Git commands that modify history - require confirmation
if echo "$command" | grep -qE "^git (rebase|reset|push.*origin|cherry-pick|revert)"; then
    cat << EOF
{
  "continue": true,
  "permission": "ask",
  "user_message": "Git history operation: $command",
  "agent_message": "This command modifies git history. Please confirm."
}
EOF
    exit 0
fi

# Allow other commands
cat << EOF
{
  "continue": true,
  "permission": "allow"
}
EOF
exit 0

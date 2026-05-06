#!/bin/bash
# security-gate.sh — Block dangerous commands
# Hook: beforeShellExecution
set -e

if ! command -v jq &>/dev/null; then
    echo '{"permission":"allow"}'
    exit 0
fi

input=$(cat)
cmd=$(echo "$input" | jq -r '.command // empty')

blocked=(
    "rm -rf /"
    "rm -rf ~"
    ":(){ :|:& };:"
    "> /dev/sda"
    "mkfs"
    "dd if=/dev"
)

for pattern in "${blocked[@]}"; do
    if echo "$cmd" | grep -qF "$pattern"; then
        echo '{"permission":"deny","user_message":"Blocked: potentially destructive command detected."}'
        exit 0
    fi
done

if echo "$cmd" | grep -qE "git push.*(--force|-f).*(main|master)"; then
    echo '{"permission":"ask","user_message":"Force push to main/master detected. Are you sure?"}'
    exit 0
fi

echo '{"permission":"allow"}'

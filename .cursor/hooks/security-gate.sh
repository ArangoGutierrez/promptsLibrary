#!/bin/bash
# security-gate.sh - Block dangerous commands
# Hook: beforeShellExecution
set -e

if ! command -v jq &>/dev/null; then
    echo '{"continue":true,"permission":"allow"}'
    exit 0
fi

input=$(cat)
cmd=$(echo "$input" | jq -r '.command // empty')

# Block patterns
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
        echo '{"continue":false,"error":"Blocked: potentially destructive command"}'
        exit 0
    fi
done

# Warn on force push to main/master
if echo "$cmd" | grep -qE "git push.*(--force|-f).*(main|master)"; then
    echo '{"continue":true,"permission":"ask","user_message":"⚠️ Force push to main/master detected"}'
    exit 0
fi

echo '{"continue":true,"permission":"allow"}'

#!/bin/bash
# sign-commits.sh - Enforce -s -S on git commit
# Hook: beforeShellExecution
set -e

if ! command -v jq &>/dev/null; then
    echo '{"continue":false,"error":"jq required: brew install jq"}'
    exit 0
fi

input=$(cat)
command=$(echo "$input" | jq -r '.command // empty')

# Only git commit
if ! echo "$command" | grep -qE "^git commit"; then
    echo '{"continue":true,"permission":"allow"}'
    exit 0
fi

# Check flags
has_s=$(echo "$command" | grep -qE "\s-s(\s|$)|--signoff" && echo 1 || echo 0)
has_S=$(echo "$command" | grep -qE "\s-S(\s|$)|--gpg-sign" && echo 1 || echo 0)

if [ "$has_s" = "1" ] && [ "$has_S" = "1" ]; then
    echo '{"continue":true,"permission":"allow"}'
    exit 0
fi

# Build missing flags
add=""
[ "$has_s" = "0" ] && add="-s"
if [ "$has_S" = "0" ]; then
    if git config --get user.signingkey &>/dev/null || git config --get gpg.format &>/dev/null; then
        add="$add -S"
    fi
fi

corrected="git commit${add:+ $add}${command#git commit}"
json_cmd=$(printf '%s' "$corrected" | jq -Rs '.')

cat << EOF
{"continue":true,"permission":"allow","command":${json_cmd}}
EOF

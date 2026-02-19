#!/bin/bash
# task-loop.sh - Prevent infinite loops
# Hook: stop
set -e

if ! command -v jq &>/dev/null; then
    echo '{"decision":"continue"}'
    exit 0
fi

input=$(cat)
iteration=$(echo "$input" | jq -r '.loop_iteration // 0')
limit=$(echo "$input" | jq -r '.loop_limit // 5')

if [ "$iteration" -ge "$limit" ]; then
    echo '{"decision":"stop","reason":"Loop limit reached"}'
else
    echo '{"decision":"continue"}'
fi

#!/bin/bash
# context-monitor.sh — Log session completion to memory patterns
# Hook: stop
# Records that the agent completed a task, contributing to work pattern tracking.
set -e

input=$(cat)

echo '{}'
exit 0

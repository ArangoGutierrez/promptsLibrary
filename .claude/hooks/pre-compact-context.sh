#!/bin/bash
# pre-compact-context.sh - Inject compaction instructions
# Hook: PreCompact
#
# Tells the model what to preserve when summarizing context.
# stdout becomes compaction instructions.
#
# Exit 0 = success

cat <<'EOF'
When compacting, you MUST preserve:
- The current TDD phase (Red/Green/Refactor) and which test is being worked on
- The current iteration count [Iteration X/Y]
- Any active worktree path and branch name
- The list of files modified in this session
- Any design decisions made with the user
EOF

exit 0

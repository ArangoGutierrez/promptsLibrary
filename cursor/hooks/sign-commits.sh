#!/bin/bash
# sign-commits.sh - Ensure all commits are signed (-s -S)
# Hook: beforeShellExecution
#
# Enforces:
# -s : DCO Signoff (Developer Certificate of Origin)
# -S : GPG/SSH cryptographic signature
#
# Auto-adds missing flags to git commit commands.

set -e

# Read JSON input from stdin
input=$(cat)
command=$(echo "$input" | jq -r '.command // empty')

# Only process git commit commands
if ! echo "$command" | grep -qE "^git commit"; then
    # Not a git commit, allow through
    cat << 'EOF'
{ "continue": true, "permission": "allow" }
EOF
    exit 0
fi

# Track what's missing
missing_signoff=false
missing_signature=false

# Check for -s or --signoff
if ! echo "$command" | grep -qE "\s-s(\s|$)|--signoff"; then
    missing_signoff=true
fi

# Check for -S or --gpg-sign
if ! echo "$command" | grep -qE "\s-S(\s|$)|--gpg-sign"; then
    missing_signature=true
fi

# If both present, allow as-is
if [ "$missing_signoff" = false ] && [ "$missing_signature" = false ]; then
    cat << 'EOF'
{ "continue": true, "permission": "allow" }
EOF
    exit 0
fi

# Build flags to add
add_flags=""
if [ "$missing_signoff" = true ]; then
    add_flags="-s"
fi
if [ "$missing_signature" = true ]; then
    add_flags="$add_flags -S"
fi

# Insert missing flags after "git commit"
corrected_command=$(echo "$command" | sed "s/^git commit/git commit $add_flags/")

# Return modified command - Cursor will execute this instead
cat << EOF
{
  "continue": true,
  "permission": "allow",
  "command": "$corrected_command"
}
EOF
exit 0

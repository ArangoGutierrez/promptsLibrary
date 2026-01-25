#!/bin/bash
# sign-commits.sh - Ensure all commits are signed (-s -S)
# Hook: beforeShellExecution
#
# Enforces:
# -s : DCO Signoff (Developer Certificate of Origin)
# -S : GPG/SSH cryptographic signature

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

# Check for --amend (still needs signing)
# Check for -m or --message (inline commit)
# Skip if it's just `git commit` with no other args (will open editor)

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

# If both present, allow
if [ "$missing_signoff" = false ] && [ "$missing_signature" = false ]; then
    cat << 'EOF'
{ "continue": true, "permission": "allow" }
EOF
    exit 0
fi

# Build message about what's missing
missing_flags=""
if [ "$missing_signoff" = true ]; then
    missing_flags="-s (DCO signoff)"
fi
if [ "$missing_signature" = true ]; then
    if [ -n "$missing_flags" ]; then
        missing_flags="$missing_flags and -S (GPG/SSH signature)"
    else
        missing_flags="-S (GPG/SSH signature)"
    fi
fi

# Suggest the corrected command
# Insert -s -S after "git commit"
corrected_command=$(echo "$command" | sed 's/^git commit/git commit -s -S/')

cat << EOF
{
  "continue": true,
  "permission": "ask",
  "user_message": "⚠️ Unsigned commit detected. Missing: $missing_flags",
  "agent_message": "This commit is missing required signing flags. Use: $corrected_command"
}
EOF
exit 0

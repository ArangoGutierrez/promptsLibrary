#!/bin/bash
# go-vuln-check.sh - Check for vulnerabilities before push
# Hook: beforeShellExecution
#
# Scans for known CVEs using govulncheck before pushing to remote.
# Prevents vulnerable code from reaching production.

set -e

if ! command -v jq &> /dev/null; then
    echo '{"continue": true, "permission": "allow"}'
    exit 0
fi

input=$(cat)
command=$(echo "$input" | jq -r '.command // empty')

# Only intercept git push to origin
if ! echo "$command" | grep -qE "^git push.*origin"; then
    echo '{"continue": true, "permission": "allow"}'
    exit 0
fi

# Check if this is a Go project (has go.mod)
if [ ! -f "go.mod" ]; then
    echo '{"continue": true, "permission": "allow"}'
    exit 0
fi

# Check if govulncheck is installed
if ! command -v govulncheck &> /dev/null; then
    # Warn but don't block
    echo "ℹ️  govulncheck not installed. Skipping vulnerability scan." >&2
    echo "   Install: go install golang.org/x/vuln/cmd/govulncheck@latest" >&2
    echo '{"continue": true, "permission": "allow"}'
    exit 0
fi

# Run vulnerability check on the module
echo "🔒 Scanning for known vulnerabilities..." >&2
vuln_output=$(govulncheck ./... 2>&1 || true)

# Check if vulnerabilities were found
if echo "$vuln_output" | grep -qE "(Vulnerability|GO-[0-9]+-[0-9]+)"; then
    # Extract vulnerability count and details
    vuln_count=$(echo "$vuln_output" | grep -cE "GO-[0-9]+-[0-9]+" || echo "some")

    # Get first few vulnerabilities for preview
    vuln_preview=$(echo "$vuln_output" | grep -A 5 -E "GO-[0-9]+-[0-9]+" | head -30)

    # Escape for JSON
    escaped_output=$(printf '%s' "$vuln_preview" | jq -Rs '.')

    cat << EOF
{
  "continue": true,
  "permission": "ask",
  "user_message": "🚨 Found $vuln_count known vulnerabilities",
  "agent_message": "govulncheck found vulnerabilities:\n\n$escaped_output\n\nRun 'govulncheck ./...' for full details.\n\nPush anyway?"
}
EOF
else
    echo "✅ No known vulnerabilities found" >&2
    echo '{"continue": true, "permission": "allow"}'
fi

exit 0

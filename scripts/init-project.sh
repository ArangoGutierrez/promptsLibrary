#!/bin/bash

# USAGE: ./init-project.sh
# Run from any Go project directory to set up quality gates.

# Detect library location (directory containing this script)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_PATH="$(dirname "$SCRIPT_DIR")"

# Allow override via environment variable
LIB_PATH="${PROMPTS_LIB:-$LIB_PATH}"

echo "🔗 Linking Standards from: $LIB_PATH"

# 1. Install Pre-Commit Hook

mkdir -p .git/hooks
cat <<EOF > .git/hooks/pre-commit
#!/bin/bash
echo "🛡️  Running Global Guardrails..."
go mod tidy
golangci-lint run ./...
if [ \$? -ne 0 ]; then echo "❌ Linter failed."; exit 1; fi
govulncheck ./...
if [ \$? -ne 0 ]; then echo "❌ Security check failed."; exit 1; fi
echo "✅ Checks passed."
EOF
chmod +x .git/hooks/pre-commit

# 2. Symlink Configs

ln -sf "$LIB_PATH/configs/.golangci.yml" .golangci.yml

echo "✅ Project hardened. Git hooks active."

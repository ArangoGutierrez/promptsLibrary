# Claude Code Hooks

Hooks that run at specific lifecycle events to automate and secure your Go development workflow.

## Available Hooks

### General Hooks

#### 1. format.sh (afterFileEdit)

**Purpose**: Automatically format code files after editing

**Triggers**: After any file edit operation

**Formats**:

- **Go**: `gofmt` (built-in)
- **JavaScript/TypeScript**: `prettier` (if installed)
- **Python**: `ruff format` or `black` (if installed)
- **Rust**: `rustfmt` (if installed)
- **JSON/Markdown**: `prettier` (if installed)

**Security**: Includes path traversal protection and symlink validation

**Example**:

```bash
# When you edit a Python file, it's automatically formatted
echo "def hello( ):" > test.py
# → format.sh runs automatically
```

---

#### 2. sign-commits.sh (beforeShellExecution)

**Purpose**: Enforce signed commits with DCO signoff and GPG signatures

**Triggers**: Before any `git commit` command

**Enforces**:

- `-s`: DCO Signoff (Developer Certificate of Origin)
- `-S`: GPG/SSH cryptographic signature

**Example**:

```bash
# You type:
git commit -m "Fix bug"

# Hook transforms to:
git commit -s -S -m "Fix bug"
```

**Configuration**:

```bash
# Set up GPG signing
gpg --full-generate-key
git config --global user.signingkey <key-id>
git config --global commit.gpgsign true
```

---

### Context Management Hooks 🧠

#### 3. context-monitor.sh + context-monitor-file-tracker.sh (stop + afterFileEdit) 🌟

**Purpose**: Track context usage and recommend when to start fresh sessions

**Triggers**:

- `context-monitor.sh`: After each agent iteration completes (stop hook)
- `context-monitor-file-tracker.sh`: After any file edit (afterFileEdit hook)

**What it does**:

- Tracks iterations, files edited, and session duration
- Calculates context health score (0-100%)
- Detects stuck states (no progress for 5+ iterations)
- Recommends fresh sessions when context is filling/critical
- Helps maintain high-quality Claude assistance

**Health States**:

- **Healthy** (<60%): Continue working
- **Filling** (60-79%): Be aware, consider wrapping up
- **Critical** (80-94%): Finish current work, new session soon
- **Degraded** (≥95%): Start new session immediately

**Example Recommendations**:

```
📊 Context ~72% (8 files edited). Consider finishing current work.
⚠️ Context ~85%. Finish current work and start fresh session soon.
💡 No recent file edits. If you're stuck, a fresh session may help.
⏱️ Long session (45+ min). Fresh session recommended for optimal performance.
```

**Installation**:

```bash
# Quick install
cd claude/hooks
chmod +x install-context-monitor.sh
./install-context-monitor.sh --config

# Manual install
mkdir -p ~/.claude/hooks
cp context-monitor.sh context-monitor-file-tracker.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/context-monitor*.sh

# Update ~/.claude/hooks.json (or create if it doesn't exist)
{
  "version": 1,
  "hooks": {
    "stop": [
      {"command": "~/.claude/hooks/context-monitor.sh"}
    ],
    "afterFileEdit": [
      {"command": "~/.claude/hooks/context-monitor-file-tracker.sh"}
    ]
  }
}
```

**Configuration** (optional `~/.claude/context-config.json`):

```json
{
  "thresholds": {
    "healthy_max": 60,
    "filling_max": 80,
    "critical_max": 95
  },
  "weights": {
    "iteration": 10,
    "file": 3,
    "duration_minutes": 0.5
  },
  "stuck_threshold": 5,
  "long_session_minutes": 40
}
```

**State Management**:

- Session state: `.claude/context-state.json` (per-project, auto-created)
- Automatic reset on new conversation
- Cross-platform atomic locking

**Documentation**:

- User guide: `claude/hooks/CONTEXT_MONITOR.md` (comprehensive)
- Research: `claude/docs/context-monitor-research.md` (deep analysis)
- Summary: `claude/hooks/CONTEXT_MONITOR_SUMMARY.md` (overview)

**Testing**:

```bash
cd claude/hooks
chmod +x test-context-monitor.sh
./test-context-monitor.sh
```

**Adapted from**: Cursor's `context-monitor.sh` with Claude Code-specific optimizations

---

### Go-Specific Hooks 🐹

#### 4. go-lint.sh (afterFileEdit) ⭐

**Purpose**: Run golangci-lint on edited Go files for instant feedback

**Triggers**: After editing any `.go` file

**What it does**:

- Runs 50+ linters in parallel (staticcheck, errcheck, go vet, etc.)
- Catches bugs, performance issues, style violations
- Shows only issues in your changes (`--new-from-rev=HEAD`)
- Silent if no issues found

**Installation**:

```bash
# Install golangci-lint
brew install golangci-lint

# Or via go install
go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
```

**Example**:

```bash
# Edit a Go file with issues
vim handler.go

# After save, you'll see:
# handler.go:42:2: ineffassign: ineffectual assignment to err
# handler.go:55:1: gocyclo: cyclomatic complexity 15 of func `Process` is high
```

**Configuration** (optional `.golangci.yml`):

```yaml
run:
  timeout: 5m

linters:
  enable:
    - errcheck
    - gosimple
    - govet
    - ineffassign
    - staticcheck
    - unused
```

---

#### 5. go-test-package.sh (beforeShellExecution) 🧪

**Purpose**: Run tests for affected packages before committing

**Triggers**: Before `git commit` commands

**What it does**:

- Detects modified Go files in staging area
- Runs `go test` on affected packages only
- Shows test results
- Asks for confirmation if tests fail (doesn't block)

**Example**:

```bash
# Stage changes
git add handler.go handler_test.go

# Attempt commit
git commit -m "Add feature"

# Hook runs:
# 🧪 Running tests for modified packages...
#   Testing: ./handlers
#     ✓ Passed
# ✅ All tests passed
```

**If tests fail**:

```
⚠️ Tests failed in: ./handlers
Review the output and decide if you want to commit anyway.
```

**Tips**:

- Write tests in same package as code
- Use `-short` flag for quick tests: `go test -short`
- Hook uses 30s timeout (configurable in script)

---

#### 6. go-vuln-check.sh (beforeShellExecution) 🔒

**Purpose**: Scan for known vulnerabilities before pushing to remote

**Triggers**: Before `git push origin` commands

**What it does**:

- Runs `govulncheck` to scan for CVEs
- Checks entire dependency tree
- Shows vulnerability details
- Asks for confirmation if vulnerabilities found

**Installation**:

```bash
go install golang.org/x/vuln/cmd/govulncheck@latest
```

**Example**:

```bash
# Attempt push
git push origin main

# Hook runs:
# 🔒 Scanning for known vulnerabilities...
# ✅ No known vulnerabilities found
```

**If vulnerabilities found**:

```
🚨 Found 2 known vulnerabilities

GO-2023-1234: Denial of service in golang.org/x/net/http2
  More info: https://pkg.go.dev/vuln/GO-2023-1234

GO-2023-5678: SQL injection in github.com/lib/pq
  More info: https://pkg.go.dev/vuln/GO-2023-5678

Push anyway?
```

**Remediation**:

```bash
# Update dependencies
go get -u ./...
go mod tidy

# Re-run scan
govulncheck ./...
```

---

## Hook Summary Table

| Hook | Type | When | Go-Specific | Blocking | Install Required |
|------|------|------|-------------|----------|------------------|
| format.sh | afterFileEdit | After edit | No | No | gofmt (built-in) |
| go-lint.sh | afterFileEdit | After edit | Yes | No | golangci-lint |
| sign-commits.sh | beforeShellExecution | Before commit | No | No | jq |
| go-test-package.sh | beforeShellExecution | Before commit | Yes | Asks | go (built-in) |
| go-vuln-check.sh | beforeShellExecution | Before push | Yes | Asks | govulncheck |

---

## Installation

Hooks are deployed alongside plugins:

```bash
# Local deployment
./scripts/deploy-claude.sh

# With symlinks (auto-update)
./scripts/deploy-claude.sh --symlink

# Remote installation
curl -fsSL https://raw.githubusercontent.com/ArangoGutierrez/promptsLibrary/main/scripts/deploy-claude.sh | bash -s -- --download
```

After deployment, hooks are at: `~/.claude/hooks/`

---

## Go Development Workflow

Here's how the hooks work together for Go projects:

### 1. Write Code

```bash
vim handler.go
# → format.sh runs: formats with gofmt
# → go-lint.sh runs: checks with golangci-lint
```

### 2. Run Tests Locally

```bash
go test ./...
```

### 3. Commit Changes

```bash
git add handler.go handler_test.go
git commit -m "Add feature"
# → go-test-package.sh runs: tests affected packages
# → sign-commits.sh runs: adds -s -S flags
```

### 4. Push to Remote

```bash
git push origin main
# → go-vuln-check.sh runs: scans for CVEs
```

---

## Configuration

### Disable a Hook Temporarily

Comment out in Claude Code settings or rename the hook file:

```bash
# Disable go-test-package hook
mv ~/.claude/hooks/go-test-package.sh ~/.claude/hooks/go-test-package.sh.disabled
```

### Customize golangci-lint

Create `.golangci.yml` in your project root:

```yaml
linters:
  enable:
    - errcheck
    - gosimple
    - govet
    - staticcheck
  disable:
    - unused  # Too noisy

linters-settings:
  gocyclo:
    min-complexity: 15  # Default 10, adjust for your project
```

### Customize Test Timeout

Edit `go-test-package.sh` and change:

```bash
go test -timeout=30s "./$pkg"
# to
go test -timeout=60s "./$pkg"
```

---

## Security: settings.json vs Hooks

### Claude Code Security Model

Claude Code uses **two layers** of security:

#### Layer 1: settings.json Permissions (Primary)

Your `claude/settings.json` already blocks dangerous commands:

```json
{
  "permissions": {
    "deny": [
      "Bash(rm:*)",
      "Bash(git push:*)",
      "Bash(docker:*)",
      "Bash(sudo:*)"
    ]
  }
}
```

#### Layer 2: Hooks (Secondary)

Hooks provide:

- Command transformation (sign-commits.sh adds flags)
- Context-aware validation (go-test-package.sh runs tests)
- Custom logic (go-vuln-check.sh scans for CVEs)

---

## Troubleshooting

### Hook not running

1. Check hook is in `~/.claude/hooks/`
2. Verify hook is executable: `ls -la ~/.claude/hooks/`
3. Check hook has correct shebang: `#!/bin/bash`
4. Verify JSON output is valid

### golangci-lint not found

```bash
# Install
brew install golangci-lint

# Verify
which golangci-lint
golangci-lint --version
```

### govulncheck not found

```bash
# Install
go install golang.org/x/vuln/cmd/govulncheck@latest

# Verify
which govulncheck
govulncheck -version
```

### Tests taking too long

Edit `go-test-package.sh` and add `-short` flag:

```bash
go test -short -timeout=30s "./$pkg"
```

Or skip slow tests with build tags:

```go
//go:build !short

func TestSlowFeature(t *testing.T) {
    // This test is skipped with -short
}
```

### False positives in go-lint

Configure `.golangci.yml` to disable specific linters:

```yaml
linters:
  disable:
    - linter-name
```

Or ignore specific issues:

```go
//nolint:linter-name // Reason why this is okay
func problematicFunction() {
```

---

## Migration from Cursor

### What Changed

| Cursor Hook | Claude Hook | Status |
|-------------|-------------|--------|
| format.sh | format.sh | ✅ Direct copy |
| sign-commits.sh | sign-commits.sh | ✅ Direct copy |
| preflight.sh | - | ❌ Removed (unused) |
| - | go-lint.sh | ✅ New for Go |
| - | go-test-package.sh | ✅ New for Go |
| - | go-vuln-check.sh | ✅ New for Go |

---

## Best Practices

### For Go Projects

1. **Install all tools**:

   ```bash
   brew install golangci-lint
   go install golang.org/x/vuln/cmd/govulncheck@latest
   ```

2. **Configure golangci-lint**:
   - Create `.golangci.yml` in project root
   - Enable linters your team agrees on
   - Disable noisy linters

3. **Write tests alongside code**:
   - `go-test-package.sh` only runs if tests exist
   - Follow `_test.go` naming convention

4. **Keep dependencies updated**:
   - Run `go get -u ./...` regularly
   - Fix vulnerabilities reported by `govulncheck`

5. **CI/CD Integration**:
   - Run same tools in CI: `golangci-lint run`, `go test ./...`, `govulncheck ./...`
   - Hooks catch issues locally; CI is the gate

---

## Examples

### Example 1: Clean Workflow

```bash
# 1. Edit code
vim handler.go
# ✅ Formatted with gofmt
# ✅ Linted with golangci-lint

# 2. Run tests
go test ./handlers
# PASS

# 3. Commit
git add handler.go
git commit -m "Add feature"
# ✅ Tests passed
# ✅ Commit signed

# 4. Push
git push origin main
# ✅ No vulnerabilities
# Pushed!
```

### Example 2: Failed Tests

```bash
git commit -m "Work in progress"
# 🧪 Running tests...
# ❌ Tests failed in: ./handlers
#
# Do you want to commit anyway?
# → Choose: No, fix tests first
```

### Example 3: Found Vulnerabilities

```bash
git push origin main
# 🔒 Scanning...
# 🚨 Found 1 vulnerability
# GO-2023-1234: Denial of service
#
# Push anyway?
# → Choose: No, update dependencies
go get -u golang.org/x/net
go mod tidy
git add go.mod go.sum
git commit -m "Update dependencies"
git push origin main
# ✅ No vulnerabilities
```

---

## License

Same as parent project.

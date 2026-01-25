# Troubleshooting Guide

Centralized troubleshooting guide for common issues with Cursor commands, hooks, task loops, and git operations.

## Table of Contents

- [Common Issues](#common-issues)
  - [Commands](#commands)
  - [Hooks](#hooks)
  - [Task Loop](#task-loop)
  - [Git Operations](#git-operations)
- [Debugging Tips](#debugging-tips)

---

## Common Issues

### Commands

#### Command Not Found

**Symptoms:**
- Error message: "Command not found" or "Unknown command"
- Command doesn't execute

**Causes & Solutions:**

| Cause | Solution |
|-------|----------|
| Command file missing | Check `cursor/commands/` directory exists |
| Typo in command name | Verify exact command name (case-sensitive) |
| Cursor not loading commands | Restart Cursor, check `.cursor/` directory |
| Commands not deployed | Run `scripts/deploy-cursor.sh` |

**Verification:**
```bash
# Check command file exists
ls cursor/commands/{command-name}.md

# Check Cursor can see commands
# (Commands should appear in Cursor's command palette)
```

---

#### Command Produces Unexpected Output

**Symptoms:**
- Command runs but output doesn't match expected format
- Missing information in output
- Wrong files modified

**Causes & Solutions:**

| Cause | Solution |
|-------|----------|
| AGENTS.md malformed | Check AGENTS.md syntax, fix table formatting |
| Missing context | Ensure you're in project root, check git status |
| State file corrupted | Reset state files (see [State File Corruption](#state-file-corruption)) |
| Hook interference | Check hooks.json, temporarily disable hooks |

**Debug Steps:**
1. Check AGENTS.md syntax: `cat AGENTS.md`
2. Verify git status: `git status`
3. Check for state files: `ls -la .cursor/`
4. Review command file: `cat cursor/commands/{command}.md`

---

#### AGENTS.md Not Created

**Symptoms:**
- `/code` fails with "No AGENTS.md found"
- `/issue` or `/task` doesn't create AGENTS.md

**Causes & Solutions:**

| Cause | Solution |
|-------|----------|
| No write permissions | Check directory permissions: `ls -ld .` |
| File creation failed silently | Check disk space: `df -h .` |
| Command didn't complete | Re-run `/issue` or `/task` command |
| Existing file blocked | Check if AGENTS.md exists but is malformed |

**Fix:**
```bash
# Manually create AGENTS.md if needed
cat > AGENTS.md << 'EOF'
# AGENTS.md

## Current Task
{description}

## Status: IN_PROGRESS

## Tasks
| # | Task | Status |
|---|------|--------|
| 1 | {task} | `[TODO]` |
EOF

# Or re-run command that should create it
# /issue #{number} or /task {description}
```

---

### Hooks

#### Hook Not Running

**Symptoms:**
- Format hook doesn't format files
- Security gate doesn't block dangerous commands
- Commit signing hook doesn't add flags
- Task loop hook doesn't continue loop

**Causes & Solutions:**

| Cause | Solution |
|-------|----------|
| Hook not in hooks.json | Check `cursor/hooks.json` includes hook |
| Hook file not executable | `chmod +x cursor/hooks/{hook-name}.sh` |
| Hook path incorrect | Verify path in hooks.json matches actual location |
| Hook syntax error | Test hook manually: `bash -x cursor/hooks/{hook}.sh` |
| Cursor not loading hooks | Restart Cursor, check `.cursor/` directory |

**Verification:**
```bash
# Check hooks.json structure
cat cursor/hooks.json | jq '.'

# Check hook exists and is executable
ls -la cursor/hooks/{hook-name}.sh

# Test hook manually (for stop hooks, provide JSON input)
echo '{"status":"completed","loop_count":1}' | bash -x cursor/hooks/task-loop.sh

# Check hook is registered
grep -A 5 "{hook-name}" cursor/hooks.json
```

**Common Hook Paths:**
- Local: `cursor/hooks/{hook}.sh` (relative to project)
- Global: `~/.cursor/hooks/{hook}.sh` (user home)

---

#### Format Hook Failing

**Symptoms:**
- Files not auto-formatted after edit
- Format errors in output
- Wrong formatter used

**Causes & Solutions:**

| Cause | Solution |
|-------|----------|
| Formatter not installed | Install: `go install`, `npm install`, `pip install` |
| Wrong file extension | Check file has correct extension |
| Path traversal blocked | Ensure file is within project directory |
| Formatter command failed | Check formatter works: `gofmt -w file.go` |

**Debug:**
```bash
# Test formatter directly
gofmt -w test.go
prettier --write test.js
ruff format test.py

# Check hook execution
echo '{"file_path":"test.go"}' | bash -x cursor/hooks/format.sh

# Verify formatter installed
command -v gofmt
command -v prettier
command -v ruff
```

**Fix:**
```bash
# Install missing formatters
# Go
go install golang.org/x/tools/cmd/goimports@latest

# Node/Prettier
npm install --save-dev prettier

# Python
pip install ruff
# or
pip install black
```

---

#### Security Gate Blocking Valid Commands

**Symptoms:**
- Normal git commands require confirmation
- Safe commands blocked
- False positives

**Causes & Solutions:**

| Cause | Solution |
|-------|----------|
| Pattern too broad | Review `security-gate.sh` patterns |
| Command matches dangerous pattern | Use alternative command syntax |
| Hook misconfigured | Check hooks.json configuration |

**Common False Positives:**
- `git push origin main` - Matches "push.*origin" pattern
- `git reset --soft HEAD~1` - Matches "reset" pattern
- Commands with "rm" in paths or variables

**Workaround:**
```bash
# For git history operations, the hook will ask for confirmation
# This is intentional - confirm if the command is safe

# For false positives, you can temporarily disable the hook:
# Edit cursor/hooks.json and comment out security-gate.sh
# Remember to re-enable after!
```

**Fix Hook Patterns:**
Edit `cursor/hooks/security-gate.sh` to refine patterns if needed.

---

### Task Loop

#### Loop Stopping Early

**Symptoms:**
- Loop stops after first iteration
- Completion phrase matched incorrectly
- Loop doesn't continue

**Causes & Solutions:**

| Cause | Solution |
|-------|----------|
| Completion phrase too generic | Use more specific phrase: "ALL TESTS PASS" vs "DONE" |
| Hook not installed | Verify `task-loop.sh` in hooks.json `stop` array |
| State file missing | Re-run `/loop` to initialize state |
| AGENTS.md shows DONE | Check AGENTS.md status markers |

**Debug:**
```bash
# Check loop state
cat .cursor/loop-state.json

# Check hook registration
cat cursor/hooks.json | jq '.hooks.stop'

# Check AGENTS.md status
grep -E '\[(TODO|WIP|DONE|BLOCKED)\]' AGENTS.md

# Test hook manually
echo '{"status":"completed","loop_count":1}' | bash cursor/hooks/task-loop.sh
```

**Fix:**
```bash
# Restart loop with more specific completion phrase
/loop "Fix all linter errors" --done "NO LINTER ERRORS" --max 10

# Verify hook is working
# Check hooks.json has task-loop.sh in stop array
```

---

#### State File Corruption

**Symptoms:**
- Loop state file has invalid JSON
- Loop can't read state
- State file locked

**Causes & Solutions:**

| Cause | Solution |
|-------|----------|
| Concurrent access | Wait for lock to release (5 second timeout) |
| Invalid JSON | State file corrupted, reset it |
| File permissions | Check `.cursor/` directory permissions |

**Fix:**
```bash
# Reset loop state
rm -f .cursor/loop-state.json .cursor/loop-state.lock

# Or manually fix state file
cat > .cursor/loop-state.json << 'EOF'
{
  "task": "your task description",
  "completion_promise": "DONE",
  "max_iterations": 10,
  "current_iteration": 0,
  "started_at": "2026-01-25T00:00:00Z",
  "status": "running"
}
EOF

# Check for lock file (should auto-release)
ls -la .cursor/loop-state.lock
# If stuck, remove manually (only if no process using it)
rm -f .cursor/loop-state.lock
```

---

#### Max Iterations Reached

**Symptoms:**
- Loop stops with "Max iterations reached" message
- Task not complete

**Causes & Solutions:**

| Cause | Solution |
|-------|----------|
| Task too complex | Break into smaller sub-tasks |
| Max too low | Restart with higher `--max` value |
| Stuck in loop | Task has blocking issue, resolve manually |

**Fix:**
```bash
# Review progress
cat .cursor/task-log.md
cat AGENTS.md

# Restart with higher limit
/loop "Continue task" --done "DONE" --max 20

# Or break into smaller tasks
# Create new AGENTS.md with smaller tasks
/issue #{number}  # Re-breakdown
```

---

### Git Operations

#### Commit Signing Failing

**Symptoms:**
- `git commit` fails with signing error
- GPG/SSH key not found
- Signing key not configured

**Causes & Solutions:**

| Cause | Solution |
|-------|----------|
| GPG key not configured | Set `git config user.signingkey {KEY}` |
| SSH signing not set up | Configure SSH signing: `git config gpg.format ssh` |
| Key file missing | Generate or locate signing key |
| Hook not adding flags | Check `sign-commits.sh` hook is running |

**Fix:**
```bash
# For SSH signing (recommended)
git config gpg.format ssh
git config user.signingkey ~/.ssh/id_ed25519.pub
git config commit.gpgsign true

# For GPG signing
git config user.signingkey {GPG_KEY_ID}
git config commit.gpgsign true

# Verify configuration
git config --list | grep sign

# Test commit signing
git commit --allow-empty -m "test" -s -S
git log --show-signature -1
```

**Verify Hook:**
```bash
# Test sign-commits hook
echo '{"command":"git commit -m \"test\""}' | bash cursor/hooks/sign-commits.sh
# Should output command with -s -S added
```

---

#### GPG Key Issues

**Symptoms:**
- "gpg: signing failed: No secret key"
- "gpg: no valid OpenPGP data found"
- Key not found errors

**Causes & Solutions:**

| Cause | Solution |
|-------|----------|
| Key not imported | Import GPG key: `gpg --import key.asc` |
| Key expired | Generate new key or extend expiration |
| Wrong key ID | Use correct key ID: `gpg --list-secret-keys` |
| Agent not running | Start GPG agent: `gpg-agent --daemon` |

**Fix:**
```bash
# List available keys
gpg --list-secret-keys --keyid-format LONG

# Set signing key
git config user.signingkey {KEY_ID}

# Test signing
echo "test" | gpg --clearsign

# For SSH signing (easier alternative)
git config gpg.format ssh
git config user.signingkey ~/.ssh/id_ed25519.pub
```

---

#### Hook Blocking Git Commands

**Symptoms:**
- Git commands require confirmation unexpectedly
- Normal operations blocked
- Security gate interfering

**Causes & Solutions:**

| Cause | Solution |
|-------|----------|
| Pattern match false positive | Confirm command is safe, then proceed |
| Hook misconfigured | Review security-gate.sh patterns |
| Intentional safety check | Some operations (force push, reset) require confirmation |

**Common Blocked Operations:**
- `git push --force` - Requires confirmation (intentional)
- `git reset --hard` - Requires confirmation (intentional)
- `git push origin` - May require confirmation (pattern match)

**Workaround:**
```bash
# For intentional safety checks, confirm when prompted
# The hook will ask: "Please confirm this is intentional"

# For false positives, temporarily adjust hook patterns
# Edit cursor/hooks/security-gate.sh
# Or use alternative command syntax that doesn't match patterns
```

---

## Debugging Tips

### How to Check Hook Execution

**1. Test Hook Manually:**
```bash
# For file edit hooks
echo '{"file_path":"test.go"}' | bash -x cursor/hooks/format.sh

# For shell execution hooks
echo '{"command":"git commit -m test"}' | bash -x cursor/hooks/sign-commits.sh

# For stop hooks
echo '{"status":"completed","loop_count":1}' | bash -x cursor/hooks/task-loop.sh
```

**2. Check Hook Registration:**
```bash
# View hooks.json
cat cursor/hooks.json | jq '.'

# Verify hook file exists
ls -la cursor/hooks/*.sh

# Check hook is executable
file cursor/hooks/{hook-name}.sh
```

**3. Enable Debug Mode:**
```bash
# Add set -x to hook script for verbose output
# Or run with bash -x
bash -x cursor/hooks/{hook-name}.sh
```

**4. Check Hook Logs:**
- Hooks output to stderr, check Cursor's output panel
- Some hooks create log files in `.cursor/` directory

---

### How to Verify Command Loading

**1. Check Command Files:**
```bash
# List all commands
ls cursor/commands/*.md

# Verify specific command
cat cursor/commands/{command-name}.md
```

**2. Check Cursor Integration:**
- Commands should appear in Cursor's command palette
- Type `/` to see available commands
- Commands are loaded from `cursor/commands/` directory

**3. Verify Project Structure:**
```bash
# Check .cursor directory exists
ls -la .cursor/

# Check hooks.json exists
test -f cursor/hooks.json && echo "hooks.json exists"

# Check commands directory exists
test -d cursor/commands && echo "commands directory exists"
```

**4. Test Command Execution:**
```bash
# Run command and check output
# Commands execute through Cursor's interface
# Check for error messages in Cursor's output
```

---

### How to Reset State Files

**1. Loop State:**
```bash
# Reset loop state
rm -f .cursor/loop-state.json .cursor/loop-state.lock

# Or manually recreate
cat > .cursor/loop-state.json << 'EOF'
{
  "task": "",
  "completion_promise": "DONE",
  "max_iterations": 10,
  "current_iteration": 0,
  "status": "stopped"
}
EOF
```

**2. Context State:**
```bash
# Reset context tracking
rm -f .cursor/context-state.json .cursor/context-state.lock

# Or use command
/context-reset
```

**3. Task Log:**
```bash
# Clear task log
rm -f .cursor/task-log.md

# Or archive it
mv .cursor/task-log.md .cursor/task-log.md.bak
```

**4. All State Files:**
```bash
# Backup first
mkdir -p .cursor/backup
cp .cursor/*.json .cursor/backup/ 2>/dev/null || true

# Reset all
rm -f .cursor/*-state.json .cursor/*-state.lock .cursor/task-log.md
```

---

### Additional Debugging Commands

**Check Git Status:**
```bash
git status
git log --oneline -5
git diff --stat
```

**Check AGENTS.md:**
```bash
# View file
cat AGENTS.md

# Check syntax
grep -E '\[(TODO|WIP|DONE|BLOCKED)\]' AGENTS.md

# Count tasks
grep -c '\[TODO\]' AGENTS.md
grep -c '\[DONE\]' AGENTS.md
```

**Check Hook Configuration:**
```bash
# Validate JSON
cat cursor/hooks.json | jq '.'

# Check hook paths
cat cursor/hooks.json | jq '.hooks | to_entries[] | .key, .value[].command'
```

**Check Dependencies:**
```bash
# Required tools
command -v jq || echo "jq not installed"
command -v git || echo "git not installed"
command -v bash || echo "bash not installed"

# Formatters (optional)
command -v gofmt || echo "gofmt not installed"
command -v prettier || echo "prettier not installed"
command -v ruff || echo "ruff not installed"
```

---

## Getting Help

If issues persist:

1. **Check Logs**: Review `.cursor/` directory for log files
2. **Verify Setup**: Run `scripts/deploy-cursor.sh` to ensure proper setup
3. **Review Documentation**: Check `docs/cursor-setup.md` and `docs/getting-started.md`
4. **Reset State**: Clear state files and restart
5. **Check Cursor Version**: Ensure Cursor is up to date
6. **Report Issue**: Include error messages, state files, and steps to reproduce

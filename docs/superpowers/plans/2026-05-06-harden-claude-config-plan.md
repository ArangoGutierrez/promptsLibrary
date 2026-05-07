# Harden ~/.claude Config Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apply 9 fixes/hardenings to `~/.claude` live config: 4 bug fixes from PR #5 review + 5 SOTA hardening items from May 2026 research (item 9 skipped per user preference).

**Architecture:** In-place edits to `~/.claude/hooks/`, `~/.claude/skills/`, `~/.claude/settings.json`. Tests live alongside hooks as `<name>_test.sh` shell scripts. No repo commits during implementation — all work is local. After all stages pass verification, run `scripts/capture.sh` to sync to repo (downstream of this plan).

**Tech Stack:** Bash 3.2+, jq, sed, git. Claude Code 2.1.x hook protocol (stdin JSON, stdout/stderr, exit codes 0/2).

**Spec reference:** `docs/superpowers/specs/2026-05-06-harden-claude-config-design.md`

---

## Stage 1 — Mechanical fixes (Tasks 1-4)

### Task 1: bash-audit-log credential redaction

**Files:**
- Modify: `~/.claude/hooks/bash-audit-log.sh:13` (after COMMAND extraction)
- Create: `~/.claude/hooks/bash-audit-log_test.sh`

- [ ] **Step 1.1: Write the failing test**

Create `~/.claude/hooks/bash-audit-log_test.sh`:

```bash
#!/bin/bash
# Test bash-audit-log.sh redacts credentials before append.
set -euo pipefail

HOOK="$HOME/.claude/hooks/bash-audit-log.sh"
TMP_HOME=$(mktemp -d)
trap "rm -rf $TMP_HOME" EXIT

# Test 1: URL-embedded credential
INPUT='{"tool_input":{"command":"git clone https://user:GHP_SECRETxyz@github.com/foo/bar"},"cwd":"/tmp"}'
HOME="$TMP_HOME" CLAUDE_SESSION_ID=t1 echo "$INPUT" | "$HOOK"
LOG="$TMP_HOME/.claude/audit/bash-commands-$(date +%Y-%m-%d).log"

if grep -q 'GHP_SECRETxyz' "$LOG"; then
    echo "FAIL: token leaked to log"
    cat "$LOG"
    exit 1
fi
if ! grep -q '<redacted>@github.com' "$LOG"; then
    echo "FAIL: redaction marker missing"
    cat "$LOG"
    exit 1
fi

# Test 2: --token flag
INPUT='{"tool_input":{"command":"curl -H Authorization --token=ABC123 https://api"},"cwd":"/tmp"}'
echo "$INPUT" | HOME="$TMP_HOME" CLAUDE_SESSION_ID=t2 "$HOOK"
if grep -q 'ABC123' "$LOG"; then
    echo "FAIL: --token value leaked"
    exit 1
fi

# Test 3: non-credential command unchanged
INPUT='{"tool_input":{"command":"ls -la /tmp"},"cwd":"/tmp"}'
echo "$INPUT" | HOME="$TMP_HOME" CLAUDE_SESSION_ID=t3 "$HOOK"
if ! grep -q 'ls -la /tmp' "$LOG"; then
    echo "FAIL: benign command corrupted"
    exit 1
fi

echo "PASS"
```

Make executable: `chmod +x ~/.claude/hooks/bash-audit-log_test.sh`

- [ ] **Step 1.2: Run test, expect FAIL**

```bash
~/.claude/hooks/bash-audit-log_test.sh
```

Expected: `FAIL: token leaked to log` (current hook has no redaction).

- [ ] **Step 1.3: Apply redaction patch**

Edit `~/.claude/hooks/bash-audit-log.sh`. After the line `COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')`, insert:

```bash
COMMAND=$(echo "$COMMAND" | /usr/bin/sed -E \
  -e 's,://[^/]*:[^@/]*@,://<redacted>@,g' \
  -e 's,(--?(token|password|api[-_]?key|secret)[= ])[^[:space:]]+,\1<redacted>,gi')
```

- [ ] **Step 1.4: Run test, expect PASS**

```bash
~/.claude/hooks/bash-audit-log_test.sh
```

Expected: `PASS`.

- [ ] **Step 1.5: Manual sanity check**

```bash
echo '{"tool_input":{"command":"git clone https://u:T@h/r"},"cwd":"/tmp"}' | ~/.claude/hooks/bash-audit-log.sh
tail -1 ~/.claude/audit/bash-commands-$(date +%Y-%m-%d).log
```

Expected: line ends with `git clone https://<redacted>@h/r`.

---

### Task 2: tdd-guard.sh — narrow `*.h|*.c` exemption

**Files:**
- Modify: `~/.claude/hooks/tdd-guard.sh:88`

- [ ] **Step 2.1: Verify current line**

```bash
grep -n '*\.h|\*\.c)' ~/.claude/hooks/tdd-guard.sh
```

Expected: `88:    *.h|*.c)            exit 0 ;;`

- [ ] **Step 2.2: Apply patch**

Edit line 88:

```diff
-    *.h|*.c)            exit 0 ;;
+    */bridge/*.h|*/bridge/*.c) exit 0 ;;
```

- [ ] **Step 2.3: Verify narrow scope**

Test with a generic .c file (should NOT exempt):

```bash
INPUT='{"tool_input":{"file_path":"'"$PWD"'/src/foo.c"}}'
mkdir -p /tmp/tdd-test/src && cd /tmp/tdd-test && git init -q
echo "$INPUT" | sed "s|$PWD|/tmp/tdd-test|" | ~/.claude/hooks/tdd-guard.sh
echo "exit=$?"
```

Expected: `exit=2` (no test exists, hook blocks).

Test with a bridge .c file (should still exempt):

```bash
INPUT='{"tool_input":{"file_path":"/tmp/tdd-test/internal/bridge/foo.c"}}'
mkdir -p /tmp/tdd-test/internal/bridge
echo "$INPUT" | ~/.claude/hooks/tdd-guard.sh
echo "exit=$?"
```

Expected: `exit=0` (bridge files exempt).

Cleanup: `rm -rf /tmp/tdd-test`

---

### Task 3: team-shutdown/SKILL.md — naming consistency

**Files:**
- Modify: `~/.claude/skills/team-shutdown/SKILL.md`

- [ ] **Step 3.1: Verify current state (10 occurrences)**

```bash
grep -cE 'Distinguished' ~/.claude/skills/team-shutdown/SKILL.md
```

Expected: `10`

- [ ] **Step 3.2: Replace-all (longest first to avoid double-replacement)**

```bash
sed -i.bak 's/Distinguished Systems Engineer/Principal Engineer/g; s/Distinguished Engineer/Principal Engineer/g' ~/.claude/skills/team-shutdown/SKILL.md
rm ~/.claude/skills/team-shutdown/SKILL.md.bak
```

- [ ] **Step 3.3: Verify all replaced**

```bash
grep -cE 'Distinguished' ~/.claude/skills/team-shutdown/SKILL.md
```

Expected: `0`

- [ ] **Step 3.4: Verify Principal Engineer count rose by 10**

```bash
grep -cE 'Principal Engineer' ~/.claude/skills/team-shutdown/SKILL.md
```

Expected: `10` (or more if "Principal Engineer" already appeared).

---

### Task 4: reflection-staleness — guard fallback

**Files:**
- Modify: `~/.claude/hooks/reflection-staleness.sh:19` (insert after)

- [ ] **Step 4.1: Reproduce bug**

```bash
TMP=$(mktemp -d)
mkdir -p "$TMP/.claude/audit"
echo "garbage-not-a-date" > "$TMP/.claude/audit/.last-reflection"
HOME="$TMP" ~/.claude/hooks/reflection-staleness.sh
```

Expected: emits `REMINDER: /reflection last ran NNNN days ago...` (huge number from epoch=0).

- [ ] **Step 4.2: Apply guard**

Edit `~/.claude/hooks/reflection-staleness.sh`. After line 19 (`LAST_RUN_EPOCH=...`), insert:

```bash
[ "$LAST_RUN_EPOCH" -eq 0 ] && exit 0
```

- [ ] **Step 4.3: Verify silent skip**

```bash
HOME="$TMP" ~/.claude/hooks/reflection-staleness.sh
echo "exit=$?"
```

Expected: no output, `exit=0`.

- [ ] **Step 4.4: Verify normal-path still works**

```bash
date -j -v-1d +%Y-%m-%d > "$TMP/.claude/audit/.last-reflection"
HOME="$TMP" ~/.claude/hooks/reflection-staleness.sh
echo "exit=$?"
```

Expected: no reminder (1 day < 7-day threshold), `exit=0`.

```bash
date -j -v-10d +%Y-%m-%d > "$TMP/.claude/audit/.last-reflection"
HOME="$TMP" ~/.claude/hooks/reflection-staleness.sh
```

Expected: emits `REMINDER: /reflection last ran 10 days ago...`. Cleanup: `rm -rf "$TMP"`.

---

## Stage 2 — Defensive hooks (Tasks 5, 6, 7)

### Task 5: Blocking PreCompact (hybrid signal)

**Files:**
- Modify: `~/.claude/hooks/pre-compact-context.sh` (full rewrite)
- Create: `~/.claude/hooks/pre-compact-context_test.sh`

- [ ] **Step 5.1: Write the failing tests**

Create `~/.claude/hooks/pre-compact-context_test.sh`:

```bash
#!/bin/bash
# Test pre-compact-context.sh blocks when checkpoint stale AND worktree dirty.
# Note: NO `set -e` — we deliberately invoke the hook expecting non-zero exits.
set -uo pipefail

HOOK="$HOME/.claude/hooks/pre-compact-context.sh"
TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

# Setup: fake git repo
mkdir -p "$TMP/repo" && cd "$TMP/repo"
git init -q
git config user.email t@t && git config user.name t
echo init > a && git add a && git commit -qm init
mkdir -p "$TMP/.claude/audit"

run_hook() {
    HOME="$TMP" PRECOMPACT_TEST_WORKTREE_DIR="${1:-}" SKIP_PRECOMPACT_GATE="${2:-0}" \
        "$HOOK" </dev/null >/dev/null 2>&1
    echo $?
}

# Test 1: fresh checkpoint + clean → exit 0 (allow)
touch "$TMP/.claude/audit/.last-checkpoint"
RC=$(run_hook "")
[ "$RC" = "0" ] || { echo "FAIL test1: clean state should allow (got $RC)"; exit 1; }

# Test 2: stale checkpoint + clean → exit 0 (allow, no dirty work)
touch -t 202001010000 "$TMP/.claude/audit/.last-checkpoint"
RC=$(run_hook "")
[ "$RC" = "0" ] || { echo "FAIL test2: stale but clean should allow (got $RC)"; exit 1; }

# Test 3: fresh checkpoint + dirty worktree → exit 0 (allow, fresh checkpoint)
touch "$TMP/.claude/audit/.last-checkpoint"
echo dirty >> "$TMP/repo/a"
RC=$(run_hook "$TMP/repo")
[ "$RC" = "0" ] || { echo "FAIL test3: fresh + dirty should allow (got $RC)"; exit 1; }

# Test 4: stale checkpoint + dirty worktree → exit 2 (BLOCK)
touch -t 202001010000 "$TMP/.claude/audit/.last-checkpoint"
RC=$(run_hook "$TMP/repo")
[ "$RC" = "2" ] || { echo "FAIL test4: stale + dirty must BLOCK (got $RC)"; exit 1; }

# Test 5: escape hatch SKIP_PRECOMPACT_GATE=1 overrides
RC=$(run_hook "$TMP/repo" "1")
[ "$RC" = "0" ] || { echo "FAIL test5: SKIP env should override (got $RC)"; exit 1; }

echo "PASS"
```

Make executable: `chmod +x ~/.claude/hooks/pre-compact-context_test.sh`

- [ ] **Step 5.2: Run test, expect FAIL**

```bash
~/.claude/hooks/pre-compact-context_test.sh
```

Expected: `FAIL test4` (current hook always exits 0).

- [ ] **Step 5.3: Rewrite the hook**

Replace `~/.claude/hooks/pre-compact-context.sh` content with:

```bash
#!/bin/bash
# pre-compact-context.sh - PreCompact hook (hybrid blocking)
# Blocks (exit 2) when checkpoint stale AND any worktree has uncommitted source.
# Otherwise emits preservation instructions and exits 0.

set -o pipefail

# Always emit the preservation instructions to stdout
cat <<'EOF'
When compacting, you MUST preserve:
- The current TDD phase (Red/Green/Refactor) and which test is being worked on
- The current iteration count [Iteration X/Y]
- Any active worktree path and branch name
- The list of files modified in this session
- Any design decisions made with the user
EOF

# Escape hatch
[ "${SKIP_PRECOMPACT_GATE:-0}" = "1" ] && exit 0

CHECKPOINT="$HOME/.claude/audit/.last-checkpoint"
STALE_MIN=30

# Stale check: file missing or mtime older than N minutes
checkpoint_stale() {
    [ -f "$CHECKPOINT" ] || return 0
    local now mtime age
    now=$(date +%s)
    mtime=$(stat -f %m "$CHECKPOINT" 2>/dev/null || stat -c %Y "$CHECKPOINT" 2>/dev/null || echo 0)
    age=$(( (now - mtime) / 60 ))
    [ "$age" -ge "$STALE_MIN" ]
}

# Dirty check: at least one tracked worktree has uncommitted source
# (excludes docs/, .agents/, .worktrees/)
any_worktree_dirty() {
    # Test override
    if [ -n "${PRECOMPACT_TEST_WORKTREE_DIR:-}" ]; then
        local dirty
        dirty=$(git -C "$PRECOMPACT_TEST_WORKTREE_DIR" status --porcelain 2>/dev/null | \
            grep -vE '^\s*(M|A|\?\?|D)\s+(docs/|\.agents/|\.worktrees/)' | head -1)
        [ -n "$dirty" ]
        return $?
    fi

    # Real worktrees: iterate git worktree list
    if ! command -v git &>/dev/null; then return 1; fi
    local found=1
    while IFS= read -r line; do
        case "$line" in
            worktree*)
                local path="${line#worktree }"
                local dirty
                dirty=$(git -C "$path" status --porcelain 2>/dev/null | \
                    grep -vE '^\s*(M|A|\?\?|D)\s+(docs/|\.agents/|\.worktrees/)' | head -1)
                if [ -n "$dirty" ]; then
                    found=0
                    break
                fi
                ;;
        esac
    done < <(git worktree list --porcelain 2>/dev/null)
    return $found
}

if checkpoint_stale && any_worktree_dirty; then
    echo "" >&2
    echo "BLOCKED: PreCompact gate triggered." >&2
    echo "  - Checkpoint stale (>${STALE_MIN}m): $CHECKPOINT" >&2
    echo "  - At least one worktree has uncommitted source changes." >&2
    echo "" >&2
    echo "Resolve by EITHER:" >&2
    echo "  (1) commit pending work, OR" >&2
    echo "  (2) refresh: touch $CHECKPOINT, OR" >&2
    echo "  (3) bypass: rerun with SKIP_PRECOMPACT_GATE=1" >&2
    exit 2
fi

exit 0
```

- [ ] **Step 5.4: Run test, expect PASS**

```bash
~/.claude/hooks/pre-compact-context_test.sh
```

Expected: `PASS`.

- [ ] **Step 5.5: Initialize checkpoint file**

```bash
mkdir -p ~/.claude/audit && touch ~/.claude/audit/.last-checkpoint
```

This avoids the gate triggering on the very first PreCompact event.

---

### Task 6: v2.1.89 cache-bug audit (doc-only)

**Files:**
- Create: `~/.claude/audit/v2.1.89-cache-review.md`

- [ ] **Step 6.1: List inventory to audit**

```bash
ls ~/.claude/skills/ ~/.claude/hooks/ 2>/dev/null
ls ~/.claude/CLAUDE.md ~/.claude/rules/*.md 2>/dev/null
```

Capture as inputs to the audit.

- [ ] **Step 6.2: Walk skills for cache-control patterns**

For each `~/.claude/skills/*/SKILL.md`:
- Identify long static prompt sections (>500 chars) that should be cached.
- Note if the skill calls the Anthropic API directly without `cache_control`.
- Note tool-result-heavy patterns where bodies are re-fetched unchanged across turns.

For `~/.claude/skills/claude-api/` (if installed):
- Verify examples include `cache_control: {"type":"ephemeral","ttl":"5m"}` or `"ttl":"1h"`.
- Verify 5m vs 1h guidance is documented.

- [ ] **Step 6.3: Write the audit doc**

Create `~/.claude/audit/v2.1.89-cache-review.md`:

```markdown
# v2.1.89 Cache-Bug Audit

**Date:** 2026-05-06
**Trigger:** Mar 2026 caching incident (3-50× rate-limit burn) per public reports.
**Scope:** ~/.claude skills, hooks, CLAUDE.md, rules/.

## Method
Walked each skill, hook, and rule file. Looked for:
1. Long static prompts that should be `cache_control`-marked
2. Tool-result patterns re-fetching unchanged data
3. Missing 5m vs 1h TTL guidance in claude-api examples
4. System prompts duplicated across skills

## Findings

(Fill in concrete findings — each as: file:section | issue | proposed fix)

## Actions taken in this audit
- (none / list)

## Follow-up actions deferred
- (list of edits to land in subsequent PRs)

## Re-audit cadence
Repeat in 90 days or after next reported caching incident.
```

Replace the placeholder `(Fill in concrete findings ...)` with the actual findings from steps 6.2.

- [ ] **Step 6.4: Verify doc is non-empty and structured**

```bash
wc -l ~/.claude/audit/v2.1.89-cache-review.md
grep -c '^## ' ~/.claude/audit/v2.1.89-cache-review.md
```

Expected: at least 25 lines, ≥5 section headers.

---

### Task 7: PermissionDenied hook

**Files:**
- Create: `~/.claude/hooks/permission-denied.sh`
- Create: `~/.claude/hooks/permission-denied_test.sh`
- Modify: `~/.claude/settings.json` (wire hook)

- [ ] **Step 7.1: Verify event name in installed Claude Code**

```bash
claude --version
# Then dispatch claude-code-guide agent or check docs.claude.com for "PermissionDenied" hook event
```

If event is named differently (e.g., `ToolDenied`, `PreToolUse` with deny payload), use the actual name. **If event does not exist in installed version, defer this task** and document in the audit doc.

For this plan, assume event name is `PermissionDenied`. Adjust `settings.json` wiring in step 7.6 accordingly.

- [ ] **Step 7.2: Write the failing test**

Create `~/.claude/hooks/permission-denied_test.sh`:

```bash
#!/bin/bash
# Test permission-denied.sh logs and emits hint.
set -euo pipefail

HOOK="$HOME/.claude/hooks/permission-denied.sh"
TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

INPUT='{"tool_name":"Bash","tool_input":{"command":"gh pr view 5"},"reason":"not_in_allow_list"}'
STDERR=$(HOME="$TMP" CLAUDE_SESSION_ID=t1 echo "$INPUT" | "$HOOK" 2>&1 >/dev/null)
LOG="$TMP/.claude/audit/permission-denials-$(date +%Y-%m-%d).log"

if ! grep -q 'tool:Bash' "$LOG"; then
    echo "FAIL: log entry missing tool name"
    cat "$LOG"
    exit 1
fi
if ! grep -q 'gh pr view 5' "$LOG"; then
    echo "FAIL: log entry missing input"
    exit 1
fi
if ! echo "$STDERR" | grep -qi 'allow list\|sandbox\|settings.json'; then
    echo "FAIL: hint not emitted to stderr"
    echo "STDERR: $STDERR"
    exit 1
fi

echo "PASS"
```

Make executable.

- [ ] **Step 7.3: Run test, expect FAIL**

Expected: `FAIL` (hook does not exist).

- [ ] **Step 7.4: Implement the hook**

Create `~/.claude/hooks/permission-denied.sh`:

```bash
#!/bin/bash
# permission-denied.sh - log denied tool calls and emit suggestion
# Hook: PermissionDenied (verify event name in installed version)
# Exit 0 always (informational, never blocks).

set -o pipefail

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // .tool // "unknown"')
REASON=$(echo "$INPUT" | jq -r '.reason // "unspecified"')
INPUT_SUMMARY=$(echo "$INPUT" | jq -r '.tool_input | tostring' 2>/dev/null | head -c 200)

LOG_DIR="$HOME/.claude/audit"
mkdir -p "$LOG_DIR" 2>/dev/null
LOG_FILE="$LOG_DIR/permission-denials-$(date +%Y-%m-%d).log"

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
SESSION_ID="${CLAUDE_SESSION_ID:-unknown}"

echo "$TIMESTAMP | session:$SESSION_ID | tool:$TOOL | reason:$REASON | input:$INPUT_SUMMARY" >> "$LOG_FILE"

# Emit hint based on tool
case "$TOOL" in
    Bash)
        echo "Hint: Bash command not in allow list. Add to settings.json permissions.allow or use /sandbox." >&2
        ;;
    WebFetch)
        echo "Hint: WebFetch domain not allowlisted. Add to remote-settings.json sandbox.network.allowedDomains." >&2
        ;;
    Write|Edit)
        echo "Hint: Write/Edit blocked. Check enforce-worktree.sh allowlist or branch context." >&2
        ;;
    *)
        echo "Hint: tool '$TOOL' denied. Check settings.json permissions and managed-settings.json deny list." >&2
        ;;
esac

exit 0
```

Make executable.

- [ ] **Step 7.5: Run test, expect PASS**

```bash
~/.claude/hooks/permission-denied_test.sh
```

Expected: `PASS`.

- [ ] **Step 7.6: Wire in settings.json**

Edit `~/.claude/settings.json`. Inside `"hooks": { ... }`, add:

```json
"PermissionDenied": [
  {
    "hooks": [
      {
        "type": "command",
        "command": "/Users/eduardoa/.claude/hooks/permission-denied.sh"
      }
    ]
  }
]
```

Validate JSON: `jq empty < ~/.claude/settings.json` (must produce no output).

---

## Stage 3 — Audit + new statusline + handoff (Tasks 8, 9)

### Task 8: Statusline net-new

**Files:**
- Modify: `~/.claude/settings.json`

- [ ] **Step 8.1: Verify field-name support in installed version**

```bash
claude --version
```

Check via `docs.claude.com` or claude-code-guide agent that the field names (`workspace.git_branch`, `workspace.git_worktree`, `rate_limits.5h_used_percent`, `rate_limits.7d_used_percent`, `model.name`) are supported. If names differ, use installed version's names.

- [ ] **Step 8.2: Add statusLine block to settings.json**

Edit `~/.claude/settings.json`. At top level (sibling of `"hooks"`), add:

```json
"statusLine": {
  "type": "json",
  "fields": [
    "model.name",
    "workspace.git_branch",
    "workspace.git_worktree",
    "rate_limits.5h_used_percent",
    "rate_limits.7d_used_percent"
  ]
}
```

If `"type": "json"` is not the right schema for the installed version, use the version's schema (e.g., `"command": "~/.claude/scripts/statusline.sh"` for command-based statuslines).

- [ ] **Step 8.3: Validate JSON**

```bash
jq empty < ~/.claude/settings.json
```

Expected: no output.

- [ ] **Step 8.4: Verify visually**

Restart Claude Code (or run `/reload-settings` if available). Confirm statusline shows the 5 fields.

---

### Task 9: Context handoff (item 10) — `/handoff` skill + `context-watch` hook

#### Task 9a: `/handoff` skill

**Files:**
- Create: `~/.claude/skills/handoff/SKILL.md`

- [ ] **Step 9a.1: Create skill directory**

```bash
mkdir -p ~/.claude/skills/handoff
```

- [ ] **Step 9a.2: Resolve transcript path mechanism**

Determine how skills can access the active session transcript:
- Check `~/.claude/projects/<slug>/conversations/` — list files, identify session-id matching pattern.
- Check env vars exposed to skills (e.g., `CLAUDE_TRANSCRIPT_PATH`, `CLAUDE_SESSION_ID`).
- Test by creating a stub skill that prints `env` and reading the output.

Document the resolution method discovered.

- [ ] **Step 9a.3: Write the skill**

Create `~/.claude/skills/handoff/SKILL.md`:

```markdown
---
name: handoff
description: Generate a structured handoff prompt to start a fresh session with full context. Use when context window approaches limit or before ending a long session.
user-invocable: true
tools:
  - Bash
  - Read
  - Write
  - Agent
---

# Session Handoff

Generates a handoff document at `~/.claude/audit/handoffs/YYYY-MM-DD-HHMM-handoff.md` and prints it to stdout for copy-paste into a new session.

## Process

1. **Gather context**:
   - Active worktree: `git worktree list | head -1`
   - Branch: `git branch --show-current`
   - Files modified: `git diff --name-only HEAD`
   - TDD phase: parse from recent conversation (search for `[RED]`/`[GREEN]`/`[REFACTOR]` markers)
   - Iteration: parse `[Iteration X/Y]` from recent turns

2. **Auto-extract decisions**:
   - Locate transcript: check `$CLAUDE_TRANSCRIPT_PATH` env, fallback to `~/.claude/projects/<slug>/conversations/$CLAUDE_SESSION_ID.jsonl`.
   - If transcript exists and is readable, dispatch a `general-purpose` subagent with prompt:

     > Read the JSONL transcript at `<path>`. Extract architectural and design decisions, approach choices, and explicit user preferences expressed during this session. Output as a bullet list (≤10 bullets). Format: `- <decision> — <rationale if stated>`. Skip routine task tracking, file paths, and tool outputs. Focus on commitments that affect future sessions.

   - Insert subagent output into the "Decisions made" section.
   - If transcript unreadable: insert `<auto-extraction unavailable — manually summarize before sending>` and continue.

3. **Prompt user for forward-looking sections**:
   - Ask the user to fill in "Next session should" (1-3 actions).
   - Ask the user to fill in "Verification before claiming done" (commands to run).

4. **Write handoff doc** to `~/.claude/audit/handoffs/$(date +%Y-%m-%d-%H%M)-handoff.md`:

   ```markdown
   # Session Handoff — <date>

   ## Context
   - Active worktree: <path>
   - Branch: <branch>
   - TDD phase: <phase>
   - Iteration: <X/Y>

   ## Files modified this session
   <git diff output>

   ## Decisions made
   <subagent-extracted bullets>

   ## Next session should
   1. <user input 1>
   2. <user input 2>

   ## Verification before claiming done
   <user input commands>
   ```

5. **Print to stdout** so user can copy-paste into a new session start.

## Gotchas
- Don't run during normal work — only at session-end or near context limit.
- Auto-extraction can be slow (subagent dispatch) — show progress to user.
- The handoff doc is permanent record; treat it as immutable after write.
```

- [ ] **Step 9a.4: Test the skill manually**

Invoke `/handoff` in a Claude Code session. Verify:
- Handoff file created at `~/.claude/audit/handoffs/`.
- Sections populated (manually inspect).
- Stdout shows the doc content.

#### Task 9b: `context-watch` hook (Stop nudge)

**Files:**
- Create: `~/.claude/hooks/context-watch.sh`
- Create: `~/.claude/hooks/context-watch_test.sh`
- Modify: `~/.claude/settings.json` (wire hook on Stop)

- [ ] **Step 9b.1: Investigate hook input schema for Stop event**

```bash
# Add a temporary debug hook to log Stop input JSON
cat > /tmp/debug-stop.sh <<'EOF'
#!/bin/bash
INPUT=$(cat)
echo "$INPUT" >> /tmp/stop-input.json
echo "$INPUT"
EOF
chmod +x /tmp/debug-stop.sh
```

Wire temporarily in settings.json under `Stop`. Trigger one Stop event in a session. Inspect `/tmp/stop-input.json` — does it contain `transcript_path`, `tokens_used`, `session_id`?

Remove the debug hook after.

- [ ] **Step 9b.2: Write the failing test**

Create `~/.claude/hooks/context-watch_test.sh`:

```bash
#!/bin/bash
# Test context-watch.sh emits nudge when transcript size exceeds threshold.
set -euo pipefail

HOOK="$HOME/.claude/hooks/context-watch.sh"
TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

# Synthesize a "transcript" file at threshold size
LARGE_FILE="$TMP/big.jsonl"
yes 'x' | head -c 800000 > "$LARGE_FILE"  # ~800KB ≈ ~200K tokens

# Test 1: large transcript → emit nudge
INPUT="{\"transcript_path\":\"$LARGE_FILE\"}"
STDERR=$(echo "$INPUT" | "$HOOK" 2>&1 >/dev/null)
if ! echo "$STDERR" | grep -qi 'context.*90\|/handoff'; then
    echo "FAIL: nudge not emitted for large transcript"
    echo "STDERR: $STDERR"
    exit 1
fi

# Test 2: small transcript → silent
SMALL_FILE="$TMP/small.jsonl"
echo '{"hi":"there"}' > "$SMALL_FILE"
INPUT="{\"transcript_path\":\"$SMALL_FILE\"}"
STDERR=$(echo "$INPUT" | "$HOOK" 2>&1 >/dev/null)
if [ -n "$STDERR" ]; then
    echo "FAIL: nudge emitted for small transcript: $STDERR"
    exit 1
fi

# Test 3: missing transcript_path → silent (no error)
INPUT='{}'
echo "$INPUT" | "$HOOK" >/dev/null 2>&1
[ $? -eq 0 ] || { echo "FAIL: hook errored on missing transcript_path"; exit 1; }

echo "PASS"
```

Make executable.

- [ ] **Step 9b.3: Run test, expect FAIL**

Expected: `FAIL` (hook does not exist).

- [ ] **Step 9b.4: Implement the hook**

Create `~/.claude/hooks/context-watch.sh`:

```bash
#!/bin/bash
# context-watch.sh - Nudge user near context limit
# Hook: Stop
# Exit 0 always — never blocks.

set -o pipefail

INPUT=$(cat)
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)

# No transcript info — exit silently
[ -z "$TRANSCRIPT" ] && exit 0
[ ! -f "$TRANSCRIPT" ] && exit 0

# Estimate tokens: bytes / 4 (rough but consistent)
BYTES=$(wc -c < "$TRANSCRIPT" 2>/dev/null || echo 0)
EST_TOKENS=$(( BYTES / 4 ))

# Threshold: 180K of typical 200K window = 90%
THRESHOLD=180000

if [ "$EST_TOKENS" -ge "$THRESHOLD" ]; then
    echo "" >&2
    echo "CONTEXT WATCH: ~$(( EST_TOKENS / 1000 ))K tokens estimated (~90% of 200K window)." >&2
    echo "Run /handoff to generate a handoff prompt and start a fresh session." >&2
fi

exit 0
```

Make executable.

- [ ] **Step 9b.5: Run test, expect PASS**

```bash
~/.claude/hooks/context-watch_test.sh
```

Expected: `PASS`.

- [ ] **Step 9b.6: Wire in settings.json under Stop**

Edit `~/.claude/settings.json`. Inside the existing `"Stop"` array (which has the verification prompt), add a sibling hook:

```json
"Stop": [
  {
    "hooks": [
      {
        "type": "prompt",
        "prompt": "Check if the assistant's last response..."
      }
    ]
  },
  {
    "hooks": [
      {
        "type": "command",
        "command": "/Users/eduardoa/.claude/hooks/context-watch.sh"
      }
    ]
  }
]
```

Validate JSON: `jq empty < ~/.claude/settings.json`.

- [ ] **Step 9b.7: Verify by triggering**

Start a long session. After many turns, expect to see the stderr nudge at session-end.

---

## Final verification (run all tests)

- [ ] **Step F.1: Run all hook tests**

```bash
for t in ~/.claude/hooks/*_test.sh; do
    echo "--- $t ---"
    "$t"
done
```

Expected: every test prints `PASS`.

- [ ] **Step F.2: Validate settings.json**

```bash
jq empty < ~/.claude/settings.json && echo "settings.json valid"
```

- [ ] **Step F.3: Confirm no regressions in existing hooks**

Trigger a normal Claude Code session. Verify:
- TDD-guard still blocks on missing tests for non-exempt files.
- enforce-worktree still allows expected paths.
- bash-audit-log still appends entries (now redacted).
- reflection-staleness still emits genuine reminders for ≥7d-stale timestamps.

- [ ] **Step F.4: Capture+commit+PR (out of scope of this plan, queued)**

After all 9 items pass local verification:
- Run `scripts/capture.sh` to sync `~/.claude` to repo.
- Diff with `git diff --stat` to confirm scope.
- Decide PR strategy (single bundled vs split per stage) based on diff size.
- Create PR(s).

---

## Rollback

If any task introduces regression:
- **Tasks 1, 2, 4** (hook patches): revert via `git diff` against last good state of the hook file.
- **Task 3** (rename): git revert + manual reapply of careful diff.
- **Task 5** (PreCompact rewrite): keep a copy of original at `~/.claude/hooks/pre-compact-context.sh.orig` before rewrite.
- **Tasks 7, 9b** (new hooks): unwire in settings.json + delete hook file.
- **Task 8** (statusline): remove the new top-level `statusLine` block.
- **Task 9a** (handoff skill): delete `~/.claude/skills/handoff/`.

Backup before Stage 2 starts:

```bash
mkdir -p ~/.claude/.backup-pre-harden
cp -r ~/.claude/hooks ~/.claude/skills ~/.claude/settings.json ~/.claude/.backup-pre-harden/
```

---

## Spec coverage check

| Spec item | Plan task |
|-----------|-----------|
| 1. bash-audit-log redaction | Task 1 |
| 2. tdd-guard *.h\|*.c narrow | Task 2 |
| 3. team-shutdown rename | Task 3 |
| 4. reflection-staleness guard | Task 4 |
| 5. Blocking PreCompact (hybrid) | Task 5 |
| 6. v2.1.89 cache audit | Task 6 |
| 7. PermissionDenied hook | Task 7 |
| 8. Statusline net-new | Task 8 |
| 9. Subprocess sandbox env vars | **SKIPPED** per spec |
| 10a. /handoff skill (auto-extract) | Task 9a |
| 10b. context-watch Stop hook | Task 9b |

All in-scope spec items mapped to tasks. Item 9 intentionally skipped.

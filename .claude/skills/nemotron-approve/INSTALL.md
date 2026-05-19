# Installing nemotron-approve

This is the per-machine deploy procedure. The skill ships as a Python package
plus a bash hook shim. Both need to land under `~/.claude/`, and the user's
`~/.claude/settings.json` needs three `PreToolUse` matcher entries pointing
at the shim.

## Prerequisites

- Python 3.12 on `$PATH` (or whatever your shell finds via `python3.12` →
  `python3` fallback in the shim).
- `jq` (already a Claude Code convention).
- For Phase 2 only: `nvidia-nat` installed in the Python environment, plus
  `NEMOTRON_APPROVE_API_KEY`, `_ENDPOINT`, `_MODEL` exported.

## Phase 1 — shadow mode (no auto-approval, just trace data)

### 1. Deploy the package + shim

From the repo root (or a worktree of it):

```bash
# Skill dir
rsync -av --exclude='.pytest_cache' --exclude='__pycache__' --exclude='*.pyc' \
  .claude/skills/nemotron-approve/ ~/.claude/skills/nemotron-approve/

# Hook shim
cp .claude/hooks/nemotron-approve.sh ~/.claude/hooks/nemotron-approve.sh
chmod +x ~/.claude/hooks/nemotron-approve.sh
```

### 2. Wire the hooks into `~/.claude/settings.json`

Back up first:

```bash
cp ~/.claude/settings.json ~/.claude/settings.json.pre-nemotron
```

Then idempotent `jq`:

```bash
jq '
  .hooks.PreToolUse |= map(
    if .matcher == "Bash" and (.hooks | any(.command == "/Users/eduardoa/.claude/hooks/nemotron-approve.sh") | not)
    then .hooks += [{"type": "command", "command": "/Users/eduardoa/.claude/hooks/nemotron-approve.sh"}]
    else . end)
  | .hooks.PreToolUse |= (
    if any(.matcher == "WebFetch") then . else
      . + [{"matcher": "WebFetch", "hooks": [{"type": "command", "command": "/Users/eduardoa/.claude/hooks/nemotron-approve.sh"}]}]
    end)
  | .hooks.PreToolUse |= (
    if any(.matcher == "mcp__.*") then . else
      . + [{"matcher": "mcp__.*", "hooks": [{"type": "command", "command": "/Users/eduardoa/.claude/hooks/nemotron-approve.sh"}]}]
    end)
' ~/.claude/settings.json > /tmp/settings.json.new && \mv -f /tmp/settings.json.new ~/.claude/settings.json
```

(Replace `eduardoa` with your username if installing elsewhere — Claude Code
requires absolute paths in the hook `command` field.)

Verify:

```bash
jq '.hooks.PreToolUse[] | {matcher, hooks: [.hooks[].command]}' ~/.claude/settings.json
```

Expected: `nemotron-approve.sh` appears in the Bash matcher (after any
existing pre-check hooks like `sign-commits.sh`) and as the sole hook in
new `WebFetch` and `mcp__.*` matcher entries.

### 3. Add shadow-mode env vars to your shell init

Append to `~/.zshrc` (or `~/.bashrc`):

```bash
# nemotron-approve PreToolUse classifier — shadow mode (Phase 1)
# DISABLED=1 makes Lane C (LLM) fall back to ask; Lane A/B regex still auto-approves.
export NEMOTRON_APPROVE_DISABLED=1
```

Reload: `source ~/.zshrc`.

### 4. Verify

Start a fresh Claude Code session and trigger a few tool calls. Then:

```bash
tail -20 ~/.claude/debug/nemotron-approve-trace.log
```

Expected lines (one per tool call):

- `lane=A decision=allow rationale="kubectl-read"` — Lane A regex match
- `lane=B decision=ask rationale="fs-destruction"` — Lane B regex match
- `lane=C decision=ask rationale="llm_unconfigured"` — gray-zone with shadow
  mode active

Shadow mode never auto-approves anything outside Lane A; the existing
permission flow remains the floor.

## Phase 2 — enable Lane C

After Phase 1 has run for a day or two and the trace log shows no
misclassifications:

### 1. Flip the env vars

In your shell init:

```bash
export NEMOTRON_APPROVE_DISABLED=0
export NEMOTRON_APPROVE_API_KEY=<your-nvidia-inference-key>
export NEMOTRON_APPROVE_ENDPOINT=https://inference-api.nvidia.com/v1/chat/completions
export NEMOTRON_APPROVE_MODEL=nvidia/nvidia/nemotron-3-super-v3
```

Reload.

### 2. Install nvidia-nat in the Python environment

The shim runs `python3.12 -m nemotron_approve`. That interpreter needs
`nvidia-nat` importable:

```bash
python3.12 -m pip install --user nvidia-nat
```

(Or whatever install path matches your Python install. The classifier
catches import failures and degrades to Lane A/B silently, so a broken
install just costs you Lane C, not the whole hook.)

### 3. Re-run the 25-command probe

Run the same Bash commands from `~/.claude/hooks/probe-approve.sh`'s
verification battery (kubectl/gh/git read commands). All should resolve in
Lane A with no LLM calls:

```bash
grep -c "lane=A" ~/.claude/debug/nemotron-approve-trace.log
grep -c "lane=C" ~/.claude/debug/nemotron-approve-trace.log
```

Lane C count should stay zero across these read-only commands. Then trigger
a real gray-zone call (e.g., `kubectl apply -f some.yaml --dry-run=client`)
and verify a `lane=C` entry appears with a sane verdict.

## Rollback

```bash
\mv -f ~/.claude/settings.json.pre-nemotron ~/.claude/settings.json
sed -i '' '/nemotron-approve PreToolUse classifier/,/NEMOTRON_APPROVE_MODEL/d' ~/.zshrc
rm -rf ~/.claude/skills/nemotron-approve
rm ~/.claude/hooks/nemotron-approve.sh
source ~/.zshrc
```

## Troubleshooting

- **Trace log empty after a session**: the hook may not be firing. Verify
  with `bash -x ~/.claude/hooks/nemotron-approve.sh <<< '{"tool_name":"Bash","tool_input":{"command":"kubectl get pods"}}'`.
- **Hook fires but every call asks**: `NEMOTRON_APPROVE_DISABLED` is still
  `1`, or the Python module can't be imported. Check `echo $NEMOTRON_APPROVE_DISABLED`
  and `python3.12 -c 'import nemotron_approve'`.
- **`patterns.py` misclassification**: edit the regex, add a test, re-run
  pytest, redeploy with the rsync command above. Then `rm -rf $TMPDIR/nemotron-approve-cache`
  to invalidate stale Lane C verdicts.

See `docs/superpowers/specs/2026-05-17-nemotron-approve-design.md` in the
promptsLibrary repo for design rationale.

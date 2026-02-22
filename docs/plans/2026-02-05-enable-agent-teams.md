# Enable Experimental Agent Teams Feature Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Enable the experimental agent teams feature in Claude Code by adding the required environment variable and optional display mode configuration to `settings.json`.

**Architecture:** Add the `env` block with `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` set to `"1"` in the existing `~/.claude/settings.json`. Optionally configure `teammateMode` for display preferences.

**Tech Stack:** Claude Code CLI, JSON configuration

---

### Task 1: Add the agent teams environment variable to settings.json

**Files:**
- Modify: `~/.claude/settings.json`

**Step 1: Add the `env` block with the agent teams flag**

In `~/.claude/settings.json`, add the `env` key at the top level with the experimental flag:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

This should be added as a new top-level key alongside the existing keys (`$schema`, `respectGitignore`, etc.).

The resulting file should look like (showing only the new addition in context):

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "respectGitignore": true,
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  },
  "attribution": {
    ...
  },
  ...
}
```

**Step 2: Validate the JSON is well-formed**

Run: `cat ~/.claude/settings.json | jq .`
Expected: Valid JSON output with the new `env` block present.

**Step 3: Verify the setting**

Run: `cat ~/.claude/settings.json | jq '.env'`
Expected:
```json
{
  "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
}
```

**Step 4: Commit**

```bash
git add ~/.claude/settings.json
git commit -m "feat: enable experimental agent teams feature"
```

Note: Skip this step if `~/.claude` is not a git repository.

---

### Task 2 (Optional): Configure teammate display mode

**Files:**
- Modify: `~/.claude/settings.json`

**Context:** Agent teams support two display modes:
- `"in-process"` — all teammates run inside main terminal, use Shift+Up/Down to select (works everywhere)
- `"tmux"` — each teammate gets its own tmux/iTerm2 pane (requires tmux or iTerm2)
- `"auto"` (default) — uses split panes if inside tmux, otherwise in-process

**Step 1: Decide on display mode**

Ask the user which mode they prefer:
- `"auto"` (default, recommended) — no config needed
- `"in-process"` — always use in-process mode
- `"tmux"` — always use split panes (requires tmux installed)

**Step 2: If not using default, add teammateMode**

Add to `settings.json`:

```json
{
  "teammateMode": "in-process"
}
```

**Step 3: If choosing tmux mode, verify tmux is installed**

Run: `which tmux`
Expected: A path like `/opt/homebrew/bin/tmux` or `/usr/local/bin/tmux`

If not installed:
Run: `brew install tmux`

**Step 4: Validate JSON**

Run: `cat ~/.claude/settings.json | jq .`
Expected: Valid JSON with `teammateMode` key present.

---

## Usage After Enabling

Once enabled, restart Claude Code and you can:

1. **Start a team** by telling Claude to create one:
   ```
   Create an agent team with 3 teammates to review this PR from different angles.
   ```

2. **Navigate teammates** with `Shift+Up/Down` (in-process mode)

3. **Enable delegate mode** with `Shift+Tab` to keep the lead focused on coordination

4. **Clean up** when done:
   ```
   Clean up the team
   ```

## Known Limitations

- No session resumption with in-process teammates
- Task status can lag
- One team per session
- No nested teams
- Split panes not supported in VS Code terminal, Windows Terminal, or Ghostty

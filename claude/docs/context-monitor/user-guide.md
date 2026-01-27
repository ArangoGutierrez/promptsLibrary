# Context Monitor for Claude Code

## Overview

The Context Monitor is a pair of hooks that provides context self-awareness for Claude Code sessions. It tracks context usage heuristics and recommends when to start a new session for optimal performance.

**Adapted from**: Cursor's `context-monitor.sh`

**Key Benefits**:
- Prevents context degradation from reducing Claude's effectiveness
- Recommends natural stopping points before context becomes critical
- Helps maintain high-quality coding assistance throughout long tasks
- Detects when you might be stuck and suggests fresh start

## How It Works

### Metrics Tracked

1. **Iterations**: Number of agent turns in the session (weight: 10)
2. **Files Touched**: Unique files edited (weight: 3)
3. **Session Duration**: Time elapsed since session start (weight: 0.5 per minute)
4. **Stuck Detection**: Iterations without file edits

### Health States

Based on a calculated score (0-100), the monitor categorizes context health:

| State | Score Range | Meaning | Recommendation |
|-------|-------------|---------|----------------|
| **Healthy** | 0-59% | Plenty of context available | Continue working |
| **Filling** | 60-79% | Context is accumulating | Be aware, consider wrapping up |
| **Critical** | 80-94% | Context nearing limits | Finish current work, new session soon |
| **Degraded** | 95-100% | Context is exhausted | Start new session immediately |

### Recommendation Logic

The monitor provides contextual recommendations:

**Filling State** (60-79%):
- Many files edited (≥10): "Context ~70% (15 files edited). Consider finishing current work."
- Long session (≥20 min): "Context ~70%. Good stopping point approaching."

**Critical State** (80-94%):
- "Context ~85%. Finish current work and start fresh session soon."

**Degraded State** (95-100%):
- "Context ~95% (high usage). Start new session for best results."

**Special Conditions**:
- **Stuck** (5+ iterations, no file edits): "No recent file edits. If you're stuck, a fresh session may help."
- **Very Long** (40+ minutes): "Long session (40+ min). Fresh session recommended for optimal performance."

## Installation

### 1. Prerequisites

Install `jq` (JSON processor):

```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt-get install jq

# Other systems
# See https://jqlang.github.io/jq/download/
```

### 2. Copy Hooks to User Directory

```bash
# Create hooks directory if it doesn't exist
mkdir -p ~/.claude/hooks

# Copy the context monitor hooks
cp claude/hooks/context-monitor.sh ~/.claude/hooks/
cp claude/hooks/context-monitor-file-tracker.sh ~/.claude/hooks/

# Make them executable
chmod +x ~/.claude/hooks/context-monitor.sh
chmod +x ~/.claude/hooks/context-monitor-file-tracker.sh
```

### 3. Configure Hooks

Edit or create `~/.claude/hooks.json`:

```json
{
  "version": 1,
  "hooks": {
    "stop": [
      {
        "command": "~/.claude/hooks/context-monitor.sh"
      }
    ],
    "afterFileEdit": [
      {
        "command": "~/.claude/hooks/context-monitor-file-tracker.sh"
      }
    ]
  }
}
```

**Note**: If you already have hooks configured, add these to the respective arrays.

### 4. Optional: Configure Thresholds

Copy the example config and customize:

```bash
cp claude/hooks/context-config-example.json ~/.claude/context-config.json
```

Edit `~/.claude/context-config.json` to adjust thresholds:

```json
{
  "thresholds": {
    "healthy_max": 60,      // Below this: healthy state
    "filling_max": 80,      // Below this: filling state
    "critical_max": 95      // Below this: critical state, else degraded
  },
  "weights": {
    "iteration": 10,        // Points per agent iteration
    "file": 3,              // Points per unique file edited
    "duration_minutes": 0.5 // Points per minute of session
  },
  "stuck_threshold": 5,     // Iterations without file edits = stuck
  "long_session_minutes": 40 // Minutes before "long session" warning
}
```

## Usage

The context monitor runs automatically on every agent iteration (stop hook) and file edit (afterFileEdit hook). No manual intervention required.

### Understanding Recommendations

When you receive a recommendation:

```
📊 Context ~70% (15 files edited). Consider finishing current work.
```

**What it means**: Your session has accumulated significant context (70% of estimated capacity based on files and iterations).

**What to do**:
- Finish your current task or subtask
- Commit your changes
- Start a new Claude Code session for the next task

**Why it matters**: Claude Code auto-summarizes internally, but fresh sessions start with clean context, leading to:
- Better code quality
- Faster responses
- More focused assistance
- Fewer hallucinations or confusion

### Session State

The monitor stores session state in `.claude/context-state.json`:

```json
{
  "conversation_id": "abc123",
  "started_at": "2025-01-27T10:30:00Z",
  "iterations": 15,
  "files_touched": [
    "/path/to/file1.go",
    "/path/to/file2.go"
  ],
  "health": "filling",
  "last_recommendation": "Context ~70%. Consider finishing current work.",
  "stuck_iterations": 0,
  "last_files_count": 2
}
```

**Note**: This file is auto-created and managed. Don't edit manually.

## Comparison with Cursor

### What's Different

| Feature | Cursor | Claude Code |
|---------|--------|-------------|
| Task tracking | AGENTS.md file ([TODO], [WIP], [DONE]) | Heuristic (iterations, files, duration) |
| Summarization | `/summarize` command | Automatic (no user control) |
| Recommendations | "Run /summarize" or new session | New session only |
| Task completion detection | Explicit [DONE] markers | Implicit (file edits, duration) |

### What's the Same

- Health score calculation approach
- Cross-platform file locking
- JSON state management
- Stuck detection logic
- Stop hook architecture

### Why No Task Tracking?

Claude Code has a built-in task system (TaskCreate, TaskUpdate, TaskList), but hooks can't access it directly (they're external bash scripts). Instead, the Claude implementation uses:

1. **File edit patterns**: Actual edits indicate progress
2. **Session duration**: Long sessions accumulate context
3. **Stuck detection**: No edits for 5+ iterations suggests issues

This heuristic approach is simpler and doesn't require maintaining a separate AGENTS.md file.

## Troubleshooting

### Hook Not Running

**Check hook registration**:
```bash
cat ~/.claude/hooks.json
```

Verify the hooks are listed under `stop` and `afterFileEdit`.

**Check hook permissions**:
```bash
ls -l ~/.claude/hooks/context-monitor*.sh
```

Should show `-rwxr-xr-x` (executable).

**Fix permissions**:
```bash
chmod +x ~/.claude/hooks/context-monitor.sh
chmod +x ~/.claude/hooks/context-monitor-file-tracker.sh
```

### jq Not Found

**Install jq**:
```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt-get install jq
```

### Lock Timeouts

If you see "Failed to acquire lock" errors:

1. **Stale locks**: The monitor auto-cleans locks >60 seconds old
2. **Manual cleanup**: `rm -rf .claude/context-state.lock`
3. **Concurrent sessions**: Don't run multiple Claude sessions in the same directory

### Recommendations Too Frequent/Infrequent

Edit `~/.claude/context-config.json`:

**Too frequent** (recommendations at healthy state):
```json
{
  "thresholds": {
    "healthy_max": 70,   // Increase from default 60
    "filling_max": 85,   // Increase from default 80
    "critical_max": 95
  }
}
```

**Too infrequent** (no warnings until very late):
```json
{
  "thresholds": {
    "healthy_max": 50,   // Decrease from default 60
    "filling_max": 70,   // Decrease from default 80
    "critical_max": 90   // Decrease from default 95
  }
}
```

**Adjust sensitivity**:
```json
{
  "weights": {
    "iteration": 15,     // Higher = more sensitive to iterations
    "file": 5,           // Higher = more sensitive to file edits
    "duration_minutes": 1.0 // Higher = more sensitive to time
  }
}
```

### Reset Session State

If state gets corrupted or you want to start fresh:

```bash
rm .claude/context-state.json
```

The monitor will create a new state on the next iteration.

## Advanced Usage

### Per-Project Configuration

You can override global config with project-specific settings:

1. Copy global config: `cp ~/.claude/context-config.json .claude/context-config.json`
2. Adjust thresholds for this project
3. Modify `context-monitor.sh` to check `.claude/context-config.json` first

### Integration with Ralph Loop

If using Ralph Loop, the context monitor works alongside it:

- Ralph Loop: Keeps session running until completion promise met
- Context Monitor: Warns about context degradation during loop

Both can coexist - Ralph Loop takes precedence (blocks exit), but you'll still see context warnings.

### Custom Alerts

To integrate with external systems (Slack, email, etc.), modify the recommendation output in `context-monitor.sh`:

```bash
# In generate_recommendation(), add:
if [ -n "$msg" ]; then
    # Send to external system
    curl -X POST https://your-webhook-url \
         -H "Content-Type: application/json" \
         -d "{\"text\": \"$msg\"}"
fi
```

## Best Practices

### When to Start New Session

**Good times**:
- After completing a discrete task or feature
- When you see "filling" or "critical" warnings
- After 30-40 minutes of continuous work
- When you switch to a different task or codebase area

**Not necessary**:
- For small bug fixes (2-3 files)
- After every single edit
- In the middle of a complex refactor

### Session Planning

**Small task** (1-2 files, <10 iterations):
- Single session, no warnings expected

**Medium task** (5-10 files, 20-30 iterations):
- May get "filling" warning toward end
- Good to break into 2 sessions if possible

**Large task** (15+ files, 50+ iterations):
- Plan for 2-3 sessions
- Break at natural boundaries (e.g., after tests pass)

### Interpreting Stuck Warnings

If you see "No recent file edits" warning:

**Possible causes**:
1. Genuinely stuck on problem → Fresh session helps
2. Reading/researching phase → Ignore warning, continue
3. Testing/debugging → Ignore warning, you'll edit soon

Use your judgment - the monitor doesn't know your intent, only observable patterns.

## Technical Details

### Architecture

```
┌─────────────────────────────────────────────────┐
│          Claude Code Session                     │
│                                                  │
│  1. User sends message                           │
│  2. Claude processes, may edit files             │
│     ├─→ afterFileEdit hook                       │
│     │   └─→ context-monitor-file-tracker.sh     │
│     │       └─→ Updates .claude/context-state.json │
│  3. Claude completes iteration                   │
│  4. stop hook triggers                           │
│     └─→ context-monitor.sh                       │
│         ├─→ Reads .claude/context-state.json    │
│         ├─→ Calculates health score              │
│         ├─→ Determines recommendation            │
│         └─→ Returns followup_message (if any)   │
│  5. User sees recommendation                     │
└─────────────────────────────────────────────────┘
```

### State File Locking

Uses atomic `mkdir` for cross-platform file locking:

1. `mkdir .claude/context-state.lock` (atomic on POSIX)
2. If successful, lock acquired
3. Perform state read/write
4. `rm -rf .claude/context-state.lock` (release)

**Timeout**: 5 seconds with 0.1s polling
**Stale cleanup**: Automatic removal of locks >60 seconds old

### Score Formula

```
score = (iterations × 10) + (files_touched × 3) + (duration_minutes × 0.5)
```

**Clamped**: 0-100 range

**Example calculation**:
- 20 iterations → 200 points
- 8 files touched → 24 points
- 30 minutes → 15 points
- **Total**: 239 points → clamped to 100 → **degraded** state

This formula is intentionally conservative to avoid false negatives.

### Hook I/O Contract

**Input** (stdin JSON):
```json
{
  "status": "completed",
  "loop_count": 15,
  "conversation_id": "abc123"
}
```

**Output** (stdout JSON):
```json
{
  "followup_message": "📊 Context ~70%. Consider finishing current work."
}
```

Empty response (no recommendation):
```json
{}
```

### Security

**Path validation**: Blocks path traversal attempts (`..` in file paths)
**Lock safety**: Auto-cleanup of stale locks prevents permanent deadlock
**Graceful degradation**: Hook failures don't block Claude Code operations

## Development

### Testing

Test the hooks manually:

```bash
# Test stop hook
echo '{"status":"completed","loop_count":50,"conversation_id":"test"}' | \
  ~/.claude/hooks/context-monitor.sh

# Test file tracker
echo '{"file_path":"/path/to/test.go"}' | \
  ~/.claude/hooks/context-monitor-file-tracker.sh
```

### Debugging

Enable verbose output:

```bash
# Add to top of hook script
set -x  # Print each command before executing
```

Check state file:

```bash
cat .claude/context-state.json | jq .
```

Monitor hook execution:

```bash
# In separate terminal
tail -f /tmp/claude-hook.log

# Add to hook scripts
echo "Debug: iteration=$iterations files=$files_touched" >> /tmp/claude-hook.log
```

### Contributing

To improve the context monitor:

1. Test changes with various scenarios (short, long, stuck sessions)
2. Ensure cross-platform compatibility (macOS, Linux)
3. Update this documentation
4. Test with and without global config
5. Verify lock behavior under concurrent access

## FAQ

**Q: Why doesn't Claude Code have a `/summarize` command like Cursor?**

A: Claude Code uses automatic context summarization internally. The system manages context automatically, but fresh sessions still provide cleaner context.

**Q: Can I disable the context monitor temporarily?**

A: Yes, comment out the hooks in `~/.claude/hooks.json`:

```json
{
  "version": 1,
  "hooks": {
    "stop": [
      // {"command": "~/.claude/hooks/context-monitor.sh"}
    ],
    "afterFileEdit": [
      // {"command": "~/.claude/hooks/context-monitor-file-tracker.sh"}
    ]
  }
}
```

**Q: Does this slow down Claude Code?**

A: Minimal impact. The hooks run in <50ms typically. File locking is optimized for speed.

**Q: Can I use this with Cursor too?**

A: The original Cursor version has better task integration (AGENTS.md). This Claude version is optimized for Claude Code's architecture.

**Q: What if I want more aggressive warnings?**

A: Lower the thresholds in `~/.claude/context-config.json`:

```json
{
  "thresholds": {
    "healthy_max": 40,
    "filling_max": 60,
    "critical_max": 80
  }
}
```

**Q: Can I track tasks manually?**

A: Yes! Create a TODO.md or TASKS.md file and manually update task status. The monitor doesn't currently parse these, but you could extend it to do so.

## References

- Original Cursor implementation: `/Users/eduardoa/src/dev/cursor/hooks/context-monitor.sh`
- Research document: `/Users/eduardoa/src/dev/claude/docs/context-monitor-research.md`
- Claude hooks README: `/Users/eduardoa/src/dev/claude/hooks/README.md`
- Hook schemas: `/Users/eduardoa/src/dev/cursor/schemas/hook-output.schema.json`

## License

MIT License - Same as Claude Code hooks collection

## Credits

- Original design: Cursor context-monitor.sh
- Claude Code adaptation: Eduardo A. (2025-01-27)
- Testing and feedback: Claude Code community

---

**Note**: This is experimental software. Test thoroughly before relying on it for production workflows.

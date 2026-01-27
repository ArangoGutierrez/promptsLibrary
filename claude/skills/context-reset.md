---
name: context-reset
description: Reset or inspect context tracking state from context-monitor.sh hook. Shows estimated token usage health (Healthy/Filling/Critical/Degraded) or resets tracking state. Useful after /summarize or when context tracking gives false "stuck" warnings.
argument-hint: "[--status]"
disable-model-invocation: false
allowed-tools: Bash, Read
model: haiku
---

# Context Tracking Reset

Reset or inspect context monitoring state.

## Usage

```bash
/context-reset           # Reset context tracking
/context-reset --status  # Show current context health
```

## What It Does

The `context-monitor.sh` hook estimates token usage based on:

- **Iterations**: +8% per iteration
- **Files read**: +2% per file
- **Tasks created**: +15% per task
- **Summarizations**: -25% recovery

## Health States

| Score | State | Meaning | Action |
|-------|-------|---------|--------|
| 0-50% | **Healthy** | Plenty of context available | Continue normally |
| 50-75% | **Filling** | Context getting full | Consider using `/summarize` soon |
| 75-90% | **Critical** | Context nearly full | Run `/summarize` now |
| 90%+ | **Degraded** | Context exhausted | Start new session |

## Mode: --status (Check Health)

Read context state and display health:

```bash
# Read state file
cat .claude/context-state.json
```

Extract:

- Current score percentage
- Health state
- Task count
- Summarization count
- Last recommendation

**Output**:

```markdown
## Context Health

**Score**: 65%
**State**: 🟡 Filling
**Tasks**: 8
**Summarizations**: 1
**Last Recommendation**: Consider running /summarize

### Breakdown
- Iterations: 12 (+96%)
- Files: 42 (+84%)
- Tasks: 8 (+120%)
- Summarizes: 1 (-25%)
- **Net**: 275% → 65% of budget

### Recommendation
Context is filling up. Consider using `/summarize` in the next 2-3 tasks to recover space.
```

## Mode: Reset (Default)

Reset context tracking to recalibrate:

```bash
# Remove state files
rm -f .claude/context-state.json
rm -f .claude/context-state.lock

echo "✓ Context tracking reset"
```

**When reset**:

- Clears all counters
- Next hook run will start fresh
- Use after `/summarize` to recalibrate
- Use if false "stuck" warnings

**Output**:

```markdown
## Context Reset

✓ Tracking state cleared
✓ Lock file removed

Context monitoring will restart fresh on next operation.

### When to Reset
- After running `/summarize` (recalibrate to new baseline)
- False "context stuck" warnings
- Starting fresh session
- Context tracking misbehaving
```

## When to Use

| Situation | Action | Reason |
|-----------|--------|--------|
| After `/summarize` | `/context-reset` | Recalibrate after context compression |
| False "stuck" warning | `/context-reset` | Clear incorrect state |
| Fresh start needed | `/context-reset` | Start with clean slate |
| Check context health | `/context-reset --status` | See if `/summarize` needed |

## Configuration

Context monitor is configured in `~/.claude/context-config.json`:

```json
{
  "thresholds": {
    "healthy_max": 50,
    "filling_max": 75,
    "critical_max": 90
  },
  "weights": {
    "iteration": 8,
    "file": 2,
    "task": 15,
    "summarize_recovery": 25
  },
  "tasks_before_new_session": 3
}
```

**Adjustable values**:

- `healthy_max`: When to show "Filling" state
- `filling_max`: When to show "Critical" state
- `critical_max`: When to show "Degraded" state
- `iteration`: Weight per iteration
- `file`: Weight per file read
- `task`: Weight per task created
- `summarize_recovery`: How much `/summarize` recovers

## Troubleshooting

### False "Stuck" Warnings

**Problem**: Context monitor says "stuck" but working fine

**Solution**:

```bash
/context-reset
```

### Score Seems Wrong

**Problem**: Health score doesn't match actual context usage

**Actions**:

1. Check config weights in `~/.claude/context-config.json`
2. Reset to recalibrate: `/context-reset`
3. Adjust weights if consistently inaccurate

### No Recommendations

**Problem**: Monitor not providing recommendations

**Check**:

1. Verify hook in `.claude/hooks.json` → `stop` array
2. Check hook has execute permissions
3. Verify `.claude/` directory exists

### State File Missing

**Problem**: `.claude/context-state.json` doesn't exist

**Cause**: Hook hasn't run yet or was deleted

**Action**: Normal - file will be created on next operation

## Constraints

- **Estimates only**: Token usage is estimated, not measured
- **Hook dependent**: Requires context-monitor.sh hook installed
- **No guarantee**: Estimates may not match actual token usage
- **Session scoped**: State is per-session, not global

## When to Use

**Use /context-reset when**:

- After using `/summarize`
- Getting false warnings
- Want fresh context state
- Context tracking misbehaving

**Use /context-reset --status when**:

- Check if `/summarize` needed
- Monitor context health
- Debug context issues

## Related Skills

- `/summarize` - Compress context (built-in Claude command)
- This skill complements but doesn't replace built-in `/compact`

## Notes

- Context monitor is optional tooling
- Not part of core Claude Code
- Provides estimates, not guarantees
- Useful for awareness, not strict limits

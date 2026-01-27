# Context Monitor: Cursor vs Claude Code - Side-by-Side Comparison

## Quick Reference

| Aspect | Cursor | Claude Code |
|--------|--------|-------------|
| **Task Tracking** | AGENTS.md file | Heuristic-based |
| **Summarization** | `/summarize` command | Automatic (internal) |
| **Health Formula** | iterations×8 + files×2 + tasks×15 - summarize×25 | iterations×10 + files×3 + duration×0.5 |
| **Thresholds** | 50%, 75%, 90% | 60%, 80%, 95% |
| **State File** | `.cursor/context-state.json` | `.claude/context-state.json` |
| **Config File** | `~/.cursor/context-config.json` | `~/.claude/context-config.json` |
| **Hooks** | stop only | stop + afterFileEdit |
| **Stuck Threshold** | 3 iterations | 5 iterations |

## Detailed Comparison

### 1. Task Status Detection

#### Cursor
**Method**: Parses `AGENTS.md` file for task markers

**Task Markers**:
```markdown
- [TODO] Task not started
- [WIP] Task in progress
- [DONE] Task completed
- [BLOCKED] Task blocked
```

**Task Status Detection**:
```bash
# Count markers
todo_count=$(grep -c '\[TODO\]' AGENTS.md)
wip_count=$(grep -c '\[WIP\]' AGENTS.md)
done_count=$(grep -c '\[DONE\]' AGENTS.md)
blocked_count=$(grep -c '\[BLOCKED\]' AGENTS.md)

# Determine state
if [ "$blocked_count" -gt 0 ]; then echo "blocked"
elif [ "$todo_count" -eq 0 ] && [ "$wip_count" -eq 0 ] && [ "$done_count" -gt 0 ]; then echo "complete"
elif [ "$wip_count" -gt 0 ]; then echo "in_progress"
elif [ "$todo_count" -gt 0 ]; then echo "pending"
fi
```

**Pros**:
- Explicit task status
- Clear completion detection
- Human-readable task list
- Can distinguish between pending/in-progress/complete/blocked

**Cons**:
- Requires maintaining AGENTS.md file
- User must update markers manually
- Can become stale if not updated

#### Claude Code
**Method**: Heuristic inference from observable patterns

**Signals Used**:
- Iteration count (indicates activity)
- Files edited (indicates progress)
- Session duration (indicates effort)
- File edit rate (detects stuck state)

**No Explicit Task Status**: Cannot determine if work is "complete" vs "in progress"

**Pros**:
- Zero maintenance (automatic)
- Always accurate (based on actual behavior)
- No user action required
- Doesn't depend on external files

**Cons**:
- Cannot distinguish task completion states
- Less granular information
- Can't detect "blocked" state explicitly
- More conservative recommendations

### 2. Summarization Support

#### Cursor
**Command**: `/summarize`

**What it does**:
- User explicitly runs `/summarize`
- Cursor compresses conversation history
- Frees up context window
- Allows continuing current session

**Detection**:
```bash
# Cursor detects summarization by comparing loop_count to tracked iterations
if [ "$loop_count" -lt "$((prev_iterations - 2))" ]; then
    # Likely summarized (conversation got shorter)
    summarize_count=$((summarize_count + 1))
fi
```

**Recommendations Include**:
- "Consider `/summarize` if you need more runway"
- "Run `/summarize` now, then wrap up current work"

**Health Score Impact**:
- Each summarize: **-25 points** (significant recovery)
- Allows extending session without starting fresh

#### Claude Code
**Command**: None (automatic internal summarization)

**What happens**:
- Claude auto-summarizes transparently
- User has no control over timing
- No explicit summarization command
- Session has "unlimited context through automatic summarization" (per system prompt)

**Detection**: Not applicable (no user-facing summarization)

**Recommendations**:
- Never mention `/summarize` (doesn't exist)
- Focus on "start new session" instead
- Emphasize "fresh context" benefits

**Philosophy Difference**:
- Cursor: User controls summarization timing
- Claude: System manages context automatically, fresh sessions preferred

### 3. Health Score Calculation

#### Cursor Formula
```
score = (iterations × 8) + (files_touched × 2) + (tasks_completed × 15) - (summarize_count × 25)
```

**Weights**:
- **Iteration**: 8 points each
- **File**: 2 points each
- **Task**: 15 points each (biggest contributor)
- **Summarize**: -25 points (recovery)

**Example** (20 iterations, 10 files, 3 tasks, 0 summarize):
```
score = (20 × 8) + (10 × 2) + (3 × 15) - (0 × 25)
      = 160 + 20 + 45 - 0
      = 225 → clamped to 100 → DEGRADED
```

**Characteristics**:
- Task-centric (tasks are heaviest weight)
- Summarize provides large recovery
- Faster degradation (lower iteration weight)

#### Claude Code Formula
```
score = (iterations × 10) + (files_touched × 3) + (duration_minutes × 0.5)
```

**Weights**:
- **Iteration**: 10 points each (higher than Cursor)
- **File**: 3 points each (higher than Cursor)
- **Duration**: 0.5 points per minute (new metric)
- **No task/summarize** (not applicable)

**Example** (20 iterations, 10 files, 30 minutes):
```
score = (20 × 10) + (10 × 3) + (30 × 0.5)
      = 200 + 30 + 15
      = 245 → clamped to 100 → DEGRADED
```

**Characteristics**:
- Iteration-centric (iterations are heaviest)
- Time-aware (duration matters)
- No recovery mechanism (no summarize)
- More aggressive on iterations

### 4. Health Thresholds

#### Cursor Thresholds
```json
{
  "healthy_max": 50,
  "filling_max": 75,
  "critical_max": 90
}
```

| State | Range | Action |
|-------|-------|--------|
| Healthy | 0-49% | Continue |
| Filling | 50-74% | Consider `/summarize` |
| Critical | 75-89% | Run `/summarize`, wrap up |
| Degraded | 90-100% | New session |

**Conservative**: Warns at 50%

#### Claude Code Thresholds
```json
{
  "healthy_max": 60,
  "filling_max": 80,
  "critical_max": 95
}
```

| State | Range | Action |
|-------|-------|--------|
| Healthy | 0-59% | Continue |
| Filling | 60-79% | Be aware, consider wrapping up |
| Critical | 80-94% | Finish work, new session soon |
| Degraded | 95-100% | New session immediately |

**More Permissive**: Warns at 60%

**Rationale for Higher Thresholds**:
- No summarize option (can't recover mid-session)
- Want to reduce false positives
- Automatic summarization happens internally
- Users need higher confidence before restarting

### 5. Stuck Detection

#### Cursor
**Threshold**: 3 iterations without progress

**Progress Signals**:
- Tasks completed (DONE count increased)
- Tasks started (TODO count decreased)

```bash
# Track AGENTS.md task counts
current_done=$(grep -c '\[DONE\]' AGENTS.md)
current_todo=$(grep -c '\[TODO\]' AGENTS.md)

# Progress if:
# - More DONE tasks than before
# - Fewer TODO tasks (moved to WIP/DONE)
if [ "$current_done" -gt "$prev_done" ] || [ "$current_todo" -lt "$prev_todo" ]; then
    stuck_iterations=0  # Reset
else
    stuck_iterations=$((stuck_iterations + 1))
fi

if [ "$stuck_iterations" -ge 3 ]; then
    echo "Stuck detected"
fi
```

**Message**: "💡 Appears stuck. New session with fresh context often helps."

#### Claude Code
**Threshold**: 5 iterations without progress

**Progress Signals**:
- Files edited (files_touched count increased)

```bash
# Track file edit count
current_files=$(jq -r '.files_touched | length' .claude/context-state.json)

# Progress if more files edited
if [ "$current_files" -gt "$prev_files" ]; then
    stuck_iterations=0  # Reset
else
    stuck_iterations=$((stuck_iterations + 1))
fi

if [ "$stuck_iterations" -ge 5 ]; then
    echo "Stuck detected"
fi
```

**Message**: "💡 No recent file edits. If you're stuck, a fresh session may help."

**Differences**:
- **Cursor**: 3 iterations, task-based
- **Claude**: 5 iterations, file-based
- **Claude is more lenient**: Reading/researching phases don't trigger false positives

### 6. Recommendation Logic

#### Cursor Decision Matrix

| Health | Task Status | Recommendation |
|--------|-------------|----------------|
| Healthy | Complete | ✅ Start new session for next task |
| Healthy | In Progress | (silent) |
| Filling | Complete | ✅ Start new session |
| Filling | In Progress | 📊 Consider `/summarize` |
| Filling | Blocked | 🚫 Resolve blocker, consider new session |
| Critical | Complete | 🔴 Start new session before next task |
| Critical | In Progress | ⚠️ Run `/summarize` now, wrap up |
| Critical | Blocked | 🛑 New session with focused context |
| Degraded | Any | 🛑 Context exhausted, start new session |

**Key Features**:
- Task-aware (knows when work is complete)
- Offers `/summarize` as alternative to new session
- Distinguishes blocked state

#### Claude Code Decision Logic

| Health | Heuristic | Recommendation |
|--------|-----------|----------------|
| Healthy | Any | (silent) |
| Filling | ≥10 files edited | 📊 Context ~70% (N files). Consider finishing current work. |
| Filling | ≥20 min session | 📊 Context ~70%. Good stopping point approaching. |
| Critical | Any | ⚠️ Context ~85%. Finish current work and start fresh session soon. |
| Degraded | Any | 🛑 Context ~95%. Start new session for best results. |
| Any | Stuck (5+ no edits) | 💡 No recent file edits. If stuck, fresh session may help. |
| Any | ≥40 min session | ⏱️ Long session (40+ min). Fresh session recommended. |

**Key Features**:
- Heuristic-based (no explicit task status)
- Never mentions `/summarize` (doesn't exist)
- Focuses on observable patterns (files, time)
- More conservative warnings

### 7. State File Format

#### Cursor
```json
{
  "conversation_id": "abc123",
  "started_at": "2025-01-27T10:30:00Z",
  "iterations": 15,
  "files_touched": ["/path/to/file1.go", "/path/to/file2.go"],
  "tasks_completed": 2,
  "summarize_count": 0,
  "last_summarize_at": null,
  "health": "filling",
  "last_recommendation": "Consider /summarize",
  "stuck_iterations": 0,
  "last_done_count": 2,
  "last_todo_count": 1
}
```

**Fields**:
- `tasks_completed`: From AGENTS.md [DONE] count
- `summarize_count`: Times `/summarize` was run
- `last_summarize_at`: Timestamp of last summarize
- `last_done_count`, `last_todo_count`: For stuck detection

#### Claude Code
```json
{
  "conversation_id": "abc123",
  "started_at": "2025-01-27T10:30:00Z",
  "iterations": 15,
  "files_touched": ["/path/to/file1.go", "/path/to/file2.go"],
  "health": "filling",
  "last_recommendation": "Context ~70%. Consider finishing current work.",
  "stuck_iterations": 0,
  "last_files_count": 2
}
```

**Fields**:
- `last_files_count`: For stuck detection (file-based)
- **No task fields**: Can't track explicit task completion
- **No summarize fields**: Not applicable

**Simpler**: Fewer fields due to heuristic approach

### 8. Hook Architecture

#### Cursor
**Single Hook**: `context-monitor.sh` (stop hook only)

**File Tracking**: Estimated/manual

```bash
# File tracking heuristic (not precise)
files_touched=$(safe_read '.files_touched | length' '0')
```

**Advantage**: Single hook, simpler setup

**Disadvantage**: Less accurate file tracking

#### Claude Code
**Two Hooks**:
1. `context-monitor.sh` (stop hook)
2. `context-monitor-file-tracker.sh` (afterFileEdit hook)

**File Tracking**: Precise (afterFileEdit hook)

```bash
# In context-monitor-file-tracker.sh
# Triggered on every file edit
echo '{"file_path":"test.go"}' | jq '.files_touched += [$file] | unique'
```

**Advantage**: Accurate file tracking

**Disadvantage**: Two hooks to maintain

### 9. Configuration

#### Cursor
**File**: `~/.cursor/context-config.json`

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

**Task-Related Config**:
- `task` weight
- `summarize_recovery` weight
- `tasks_before_new_session` threshold

#### Claude Code
**File**: `~/.claude/context-config.json`

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

**Time-Related Config**:
- `duration_minutes` weight (new)
- `long_session_minutes` threshold (new)
- Higher `stuck_threshold` (5 vs 3)

## Feature Comparison

| Feature | Cursor | Claude Code |
|---------|--------|-------------|
| **Explicit task tracking** | ✅ Yes (AGENTS.md) | ❌ No (heuristic) |
| **Task completion detection** | ✅ Yes ([DONE] markers) | ❌ No |
| **Blocked state detection** | ✅ Yes ([BLOCKED] markers) | ❌ No |
| **Summarization command** | ✅ Yes (`/summarize`) | ❌ No (automatic) |
| **Precise file tracking** | ⚠️ Heuristic | ✅ Yes (afterFileEdit hook) |
| **Session duration tracking** | ❌ No | ✅ Yes |
| **Long session warnings** | ❌ No | ✅ Yes (40+ min) |
| **Cross-platform locking** | ✅ Yes (mkdir) | ✅ Yes (mkdir) |
| **Security (path traversal)** | ✅ Yes | ✅ Yes |
| **Configurable thresholds** | ✅ Yes | ✅ Yes |
| **Stuck detection** | ✅ Yes (3 iter) | ✅ Yes (5 iter) |
| **State per conversation** | ✅ Yes | ✅ Yes |

## Use Case Comparison

### Scenario 1: Bug Fix (5 iterations, 2 files, 10 minutes)

#### Cursor
```
Score = (5 × 8) + (2 × 2) + (0 × 15) - (0 × 25)
      = 40 + 4 + 0 - 0
      = 44 → HEALTHY (< 50)

Result: No warning
```

#### Claude Code
```
Score = (5 × 10) + (2 × 3) + (10 × 0.5)
      = 50 + 6 + 5
      = 61 → FILLING (60-79)

Result: Might get warning if ≥10 files or ≥20 min
        But with 2 files and 10 min → No warning
```

**Conclusion**: Both systems: No warning (appropriate)

### Scenario 2: Feature Development (25 iterations, 12 files, 35 minutes)

#### Cursor
```
Score = (25 × 8) + (12 × 2) + (0 × 15) - (0 × 25)
      = 200 + 24 + 0 - 0
      = 224 → DEGRADED (clamped to 100)

If 3 tasks completed:
Score = 200 + 24 + 45 - 0 = 269 → DEGRADED
Recommendation: "📦 3 tasks complete. New session recommended (context bloat)."

If 1 task in progress:
Recommendation: "🛑 Context exhausted (~100%). Start new session to continue effectively."
```

#### Claude Code
```
Score = (25 × 10) + (12 × 3) + (35 × 0.5)
      = 250 + 36 + 17.5
      = 303.5 → DEGRADED (clamped to 100)

Recommendation: "🛑 Context ~100% (high usage). Start new session for best results."
```

**Conclusion**: Both systems: Warn to start new session (appropriate)

### Scenario 3: Research Phase (10 iterations, 0 files, 15 minutes)

#### Cursor
```
Score = (10 × 8) + (0 × 2) + (0 × 15) - (0 × 25)
      = 80 + 0 + 0 - 0
      = 80 → CRITICAL (75-89)

Stuck detection:
- 10 iterations with no DONE/TODO changes
- Stuck after 3 iterations
Recommendation: "💡 Appears stuck. New session with fresh context often helps."
```

#### Claude Code
```
Score = (10 × 10) + (0 × 3) + (15 × 0.5)
      = 100 + 0 + 7.5
      = 107.5 → DEGRADED (clamped to 100)

Stuck detection:
- 10 iterations with no file edits
- Stuck after 5 iterations
Recommendation: "💡 No recent file edits. If you're stuck, a fresh session may help."
```

**Conclusion**: Both systems detect stuck, but Cursor triggers earlier (3 vs 5)

### Scenario 4: After `/summarize` (Cursor only)

#### Cursor
```
Before summarize:
Score = (20 × 8) + (8 × 2) + (2 × 15) - (0 × 25)
      = 160 + 16 + 30 - 0
      = 206 → DEGRADED

User runs /summarize

After summarize:
Score = (20 × 8) + (8 × 2) + (2 × 15) - (1 × 25)
      = 160 + 16 + 30 - 25
      = 181 → Still DEGRADED (clamped to 100)

But with multiple summarizes:
Score = 206 - (3 × 25) = 131 → Still DEGRADED

# Summarize helps but doesn't fully recover from very high scores
```

#### Claude Code
N/A - No summarize feature

**Conclusion**: Cursor's summarize provides some relief but not a complete reset

## Migration Guide

### From Cursor to Claude Code

**What to Change**:

1. **State file location**:
   ```bash
   # No automatic migration needed (different systems)
   # Just start fresh with Claude
   ```

2. **Remove AGENTS.md dependency**:
   - No need to maintain task file
   - System tracks files automatically

3. **Adjust expectations**:
   - No `/summarize` command
   - Recommendations focus on new sessions only
   - More lenient thresholds

4. **Configuration**:
   ```bash
   # Copy and adjust
   cp ~/.cursor/context-config.json ~/.claude/context-config.json

   # Edit to remove task/summarize fields, add duration fields
   ```

**What Stays the Same**:
- Hook architecture (JSON I/O)
- Cross-platform locking
- Security validations
- Stuck detection concept

### From Claude Code to Cursor

**What to Add**:

1. **Create AGENTS.md**:
   ```markdown
   # Task List

   - [TODO] Implement feature X
   - [WIP] Add tests for Y
   - [DONE] Fix bug in Z
   ```

2. **Adjust thresholds** (more aggressive):
   ```json
   {
     "thresholds": {
       "healthy_max": 50,
       "filling_max": 75,
       "critical_max": 90
     }
   }
   ```

3. **Learn `/summarize` command**:
   - Use it when context filling
   - Provides mid-session recovery

## Philosophical Differences

### Cursor Philosophy
**"Give users control over context management"**

- Explicit task tracking (AGENTS.md)
- User-initiated summarization (`/summarize`)
- Task-centric recommendations
- More aggressive warnings (50% threshold)
- Assumes user wants to extend session via summarization

### Claude Code Philosophy
**"Simplify through automation"**

- Automatic context management
- No manual task tracking required
- Heuristic-based recommendations
- More conservative warnings (60% threshold)
- Assumes fresh sessions are preferred over patching

## Best Practices by System

### Cursor Best Practices
1. **Maintain AGENTS.md**: Keep task markers up to date
2. **Use `/summarize`**: When context fills, summarize before continuing
3. **Update task status**: Move tasks from [TODO] → [WIP] → [DONE]
4. **Watch for 50% warnings**: Act early to summarize
5. **Start fresh after task completion**: Don't carry over bloat

### Claude Code Best Practices
1. **No maintenance needed**: System tracks automatically
2. **Watch for 60% warnings**: Start wrapping up
3. **Natural stopping points**: Commit after warnings
4. **Fresh sessions**: Preferred over trying to extend
5. **Trust the heuristics**: File edits and time are good proxies

## Conclusion

Both systems serve the same goal (context health awareness) but with different approaches:

| Aspect | Cursor | Claude Code |
|--------|--------|-------------|
| **Complexity** | Higher (AGENTS.md, summarize) | Lower (automatic) |
| **Precision** | Higher (explicit task status) | Lower (heuristic) |
| **Maintenance** | Required (AGENTS.md) | None (automatic) |
| **Flexibility** | Higher (summarize option) | Lower (new session only) |
| **User Control** | More (explicit summarize) | Less (auto-managed) |
| **False Positives** | More (aggressive 50%) | Fewer (conservative 60%) |

**Choose Cursor if**:
- You want explicit task tracking
- You prefer control over summarization
- You maintain task lists anyway
- You want task completion detection

**Choose Claude Code if**:
- You prefer zero-maintenance automation
- You're okay with heuristic recommendations
- You prefer fresh sessions over patching
- You want simpler setup

Both implementations are production-ready and serve their respective ecosystems well.

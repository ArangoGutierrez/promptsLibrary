# Context Monitor Research: Cursor → Claude Code

## Executive Summary

This document analyzes Cursor's `context-monitor.sh` hook and provides a design for an equivalent Claude Code implementation. The goal is to provide context self-awareness for Claude Code sessions, tracking context usage and recommending appropriate actions to maintain session quality.

## Cursor Context Monitor Analysis

### Purpose
Monitor context usage heuristics and recommend:
- Session summarization when context is filling but task is in-progress
- New session when task is complete or context is degraded

### Architecture

**Hook Type**: `stop` (runs after each agent iteration completes)

**State Management**:
- Global config: `~/.cursor/context-config.json`
- Session state: `.cursor/context-state.json`
- Task tracking: `AGENTS.md` file with task status markers

**Key Metrics**:
1. **Iterations**: Number of agent turns in the session
2. **Files touched**: Count of edited files
3. **Tasks completed**: Count of [DONE] markers in AGENTS.md
4. **Summarize count**: Number of times /summarize was run

### Health Score Calculation

```
score = (iterations × 8) + (files_touched × 2) + (tasks_completed × 15) - (summarize_count × 25)
```

Clamped to 0-100 range.

**Health States**:
- **Healthy**: < 50% - Continue working
- **Filling**: 50-75% - Consider summarizing if task in progress
- **Critical**: 75-90% - Summarize now, wrap up
- **Degraded**: ≥ 90% - Start new session

### Task Status Detection

Parses `AGENTS.md` for markers:
- `[TODO]` - Pending tasks
- `[WIP]` - Work in progress
- `[DONE]` - Completed tasks
- `[BLOCKED]` - Blocked tasks
- Status header: `## Status: (DONE|COMPLETE|FINISHED)`

**Task States**:
- `complete` - All tasks done
- `in_progress` - Has [WIP] tasks
- `pending` - Has [TODO] tasks
- `blocked` - Has [BLOCKED] tasks
- `unknown` - No clear state

### Stuck Detection

Monitors progress by tracking task completion changes:
- Compares [DONE] and [TODO] counts between invocations
- If no progress for 3+ iterations → "stuck" state
- Recommends new session to break out of stuck state

### Recommendation Matrix

| Health State | Task Status | Recommendation |
|-------------|-------------|----------------|
| Healthy | Complete | ✅ Start new session for next task |
| Healthy | In Progress | (no message - continue) |
| Filling | Complete | ✅ Start new session |
| Filling | In Progress | 📊 Consider /summarize |
| Filling | Blocked | 🚫 Resolve blocker, consider new session |
| Critical | Complete | 🔴 Start new session before next task |
| Critical | In Progress | ⚠️ Run /summarize now, wrap up |
| Critical | Blocked | 🛑 New session with focused context |
| Degraded | Any | 🛑 Context exhausted, start new session |
| Any | Stuck (3+ no progress) | 💡 New session with fresh context |
| Any | ≥3 tasks complete | 📦 New session (context bloat) |

### Technical Implementation

**JSON Input** (from Cursor, passed via stdin):
```json
{
  "status": "completed",
  "loop_count": 5,
  "conversation_id": "abc123"
}
```

**JSON Output** (to Cursor, via stdout):
```json
{
  "followup_message": "📊 Context ~65%. Consider `/summarize` if you need more runway."
}
```

**State File Format**:
```json
{
  "conversation_id": "abc123",
  "started_at": "2025-01-27T10:30:00Z",
  "iterations": 15,
  "files_touched": ["src/main.go", "src/utils.go"],
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

**Cross-Platform Locking**:
- Uses `mkdir` for atomic lock acquisition (POSIX-compliant)
- 5-second timeout with 0.1s polling
- Automatic stale lock cleanup (>60 seconds old)
- Trap-based cleanup on exit

**Configuration** (`~/.cursor/context-config.json`):
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

## Claude Code System Analysis

### Task System

**Built-in Task Management**: Claude Code has native task tools:
- `TaskCreate` - Create tasks with subject, description, activeForm
- `TaskUpdate` - Update status (pending → in_progress → completed)
- `TaskList` - List all tasks with status and dependencies
- `TaskGet` - Get full task details

**Task Status Values**:
- `pending` - Not started
- `in_progress` - Currently working
- `completed` - Finished
- `deleted` - Removed

**Limitation**: Hooks cannot directly call Claude tools (TaskList, etc.) - they're external bash scripts without access to the Claude API.

### Hooks System

**Compatible with Cursor**: Same architecture, JSON I/O format, hook types.

**Hook Types**:
- `afterFileEdit` - Triggered after file modifications
- `beforeShellExecution` - Triggered before bash commands
- `stop` - Triggered when session is about to exit

**Configuration Location**: `~/.claude/hooks.json`

**Existing Hooks** (in `/claude/hooks/`):
- `format.sh` - Auto-format code
- `sign-commits.sh` - Enforce git signatures
- `go-lint.sh` - Run golangci-lint
- `go-test-package.sh` - Run tests before commit
- `go-vuln-check.sh` - Scan for vulnerabilities

### Context Management

**No built-in summarization command**: Claude Code uses automatic context summarization internally, but there's no explicit `/summarize` command like Cursor.

**Context Strategy**:
- Conversation has unlimited context through automatic summarization (per system prompt)
- Best practice: Start new sessions for fresh context
- No user-facing summarization control

### Differences from Cursor

| Feature | Cursor | Claude Code |
|---------|--------|-------------|
| Task tracking | AGENTS.md file | Built-in task system |
| Task markers | [TODO], [WIP], [DONE], [BLOCKED] | pending, in_progress, completed, deleted |
| Summarization | `/summarize` command | Automatic (no user control) |
| State directory | `.cursor/` | `.claude/` |
| Config directory | `~/.cursor/` | `~/.claude/` |
| Hook access to tasks | File parsing (AGENTS.md) | No direct access (tasks internal) |

## Claude Code Context Monitor Design

### Adaptations Required

1. **Task Tracking**: Since hooks can't access Claude's task API, use alternative signals:
   - Track file edit count via `afterFileEdit` hook integration
   - Estimate task completion from iteration patterns
   - Look for task-related keywords in conversation (if transcript available)
   - Optional: Parse task list files if user maintains them

2. **Recommendations**: Adjust messaging for Claude Code:
   - Remove `/summarize` references (not applicable)
   - Emphasize "start new session" as primary recommendation
   - Explain that Claude auto-summarizes internally
   - Focus on fresh context benefits

3. **State Management**:
   - Use `.claude/context-state.json` instead of `.cursor/`
   - Same locking mechanism (mkdir-based)
   - Same JSON structure (mostly compatible)

4. **Health Calculation**: Simplified without explicit task tracking:
   - Iterations (weight: 10) - increased from 8
   - Files touched (weight: 3) - increased from 2
   - Session duration (weight: 5) - new metric
   - Conversation turns (weight: 8) - new metric based on loop_count

### Proposed Health Score Formula

```
score = (iterations × 10) + (files_touched × 3) + (duration_minutes / 2)
```

**Simplified Thresholds**:
- **Healthy**: < 60% - Continue working
- **Filling**: 60-80% - Be aware, consider wrapping up
- **Critical**: 80-95% - Finish current work, new session soon
- **Degraded**: ≥ 95% - Start new session immediately

### Recommendation Strategy

**Decision Matrix**:

| Health State | Heuristic Signals | Recommendation |
|-------------|-------------------|----------------|
| Healthy | Any | (no message) |
| Filling | High file edit rate | 📊 Context ~70%. Consider finishing current work. |
| Filling | Long session (>20 min) | 📊 Context ~70%. Good stopping point approaching. |
| Critical | Any | ⚠️ Context ~85%. Finish current work and start fresh session. |
| Degraded | Any | 🛑 Context ~95%. Start new session for best results. |
| Any | Stuck (no file edits for 5+ iterations) | 💡 No recent progress. Fresh session may help. |
| Any | Very long (>40 min) | ⏱️ Long session (40+ min). Fresh session recommended. |

**Key Messages**:
- Emphasize "fresh context" rather than "/summarize"
- Explain that new sessions reset context for better results
- Note that Claude auto-manages context internally
- Recommend natural stopping points

### Implementation Plan

**Files to Create**:
1. `claude/hooks/context-monitor.sh` - Main hook script
2. `~/.claude/context-config.json` - User configuration (optional)
3. `.claude/context-state.json` - Session state (auto-created)

**Hook Integration**:
1. Register in `~/.claude/hooks.json`:
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

2. **Two-hook approach**:
   - `context-monitor.sh` (stop hook) - Main logic, recommendations
   - `context-monitor-file-tracker.sh` (afterFileEdit hook) - Track file edits

**State Tracking**:
- Update iteration count on each stop hook invocation
- Track files via afterFileEdit hook (append to state)
- Calculate session duration from started_at timestamp
- Detect stuck state via iteration count without file changes

**Configuration** (`~/.claude/context-config.json`):
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

### Testing Strategy

1. **Unit tests** (bash testing framework):
   - State file creation/updates
   - Lock acquisition/release
   - Health score calculation
   - Recommendation generation

2. **Integration tests**:
   - Test with various iteration counts
   - Test with different file edit patterns
   - Test stuck detection
   - Test long session warnings

3. **Real-world scenarios**:
   - Short session (5 iterations, 2 files) → no warning
   - Medium session (20 iterations, 8 files) → filling warning
   - Long session (40 iterations, 15 files) → critical warning
   - Stuck session (20 iterations, 0 file edits last 5) → stuck warning

## Implementation Notes

### Advantages of Claude Code Approach

1. **Simpler task tracking**: No need to parse AGENTS.md format
2. **More granular file tracking**: afterFileEdit hook gives precise counts
3. **Better time awareness**: Can track session duration directly
4. **Cleaner recommendations**: No confusing /summarize references

### Limitations

1. **No direct task status**: Can't know if work is actually "complete"
2. **Heuristic-based**: Relies on patterns rather than explicit state
3. **User discipline**: Works best if users start fresh sessions appropriately

### Future Enhancements

1. **Optional task file parsing**: If user maintains TODO.md or similar
2. **Git commit tracking**: Detect commits as completion signals
3. **Token counting**: If transcript includes token counts (future feature)
4. **Machine learning**: Learn user's patterns over time
5. **Integration with Ralph Loop**: Coordinate with ralph-loop state

## Migration Path

For users switching from Cursor:

1. **Config migration**: Script to convert `.cursor/` configs to `.claude/`
2. **State reset**: Fresh start recommended (different task systems)
3. **Adjust expectations**: Understand no `/summarize` command exists
4. **Hook registration**: Update hooks.json for Claude paths

## References

- Cursor context-monitor.sh: `/Users/eduardoa/src/dev/cursor/hooks/context-monitor.sh`
- Claude hooks README: `/Users/eduardoa/src/dev/claude/hooks/README.md`
- Hook schemas: `/Users/eduardoa/src/dev/cursor/schemas/hook-output.schema.json`
- Ralph Loop stop hook: `/Users/eduardoa/src/dev/claude/ralph-loop/hooks/stop-hook.sh`

## Conclusion

A Claude Code context monitor is feasible and valuable, with necessary adaptations:
- Remove AGENTS.md dependency
- Remove /summarize references
- Add afterFileEdit hook for precise tracking
- Simplify recommendations to focus on new sessions
- Use heuristics for task completion detection

The implementation maintains the spirit of Cursor's approach while adapting to Claude Code's architecture and capabilities.

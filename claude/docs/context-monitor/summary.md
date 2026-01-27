# Context Monitor for Claude Code - Project Summary

## Overview

This project provides a **context self-awareness system** for Claude Code sessions, adapted from Cursor's `context-monitor.sh`. It tracks context usage and recommends when to start fresh sessions for optimal performance.

## What Was Built

### 1. Core Hooks

**`context-monitor.sh`** (stop hook)

- Main monitoring logic
- Calculates context health score
- Generates recommendations based on usage
- Runs after each agent iteration

**`context-monitor-file-tracker.sh`** (afterFileEdit hook)

- Tracks unique files edited
- Updates session state atomically
- Runs after every file edit

### 2. Documentation

**`CONTEXT_MONITOR.md`** - Comprehensive user guide covering:

- How the system works
- Installation instructions
- Usage examples
- Troubleshooting
- Configuration options
- Technical details
- FAQ

**`context-monitor-research.md`** - Deep research analysis:

- Cursor implementation breakdown
- Claude Code architecture analysis
- Design decisions and adaptations
- Comparative analysis
- Implementation considerations

### 3. Installation & Testing

**`install-context-monitor.sh`** - Automated installer:

- Copies hooks to `~/.claude/hooks/`
- Updates `~/.claude/hooks.json` configuration
- Optional config file installation
- Uninstall capability

**`test-context-monitor.sh`** - Comprehensive test suite:

- 13 test cases covering core functionality
- File tracker tests
- Context monitor tests
- Security tests
- Configuration tests

**`context-config-example.json`** - Example configuration:

- Customizable thresholds
- Weight adjustments
- Timeout settings

## Key Features

### Context Health Monitoring

The system calculates a health score based on:

```
score = (iterations × 10) + (files_touched × 3) + (duration_minutes × 0.5)
```

**Health States**:

- **Healthy** (0-59%): Continue working
- **Filling** (60-79%): Be aware, consider wrapping up
- **Critical** (80-94%): Finish current work, new session soon
- **Degraded** (95-100%): Start new session immediately

### Smart Recommendations

Context-aware messages guide users:

| Condition | Message |
|-----------|---------|
| Filling + many files (≥10) | "📊 Context ~70% (15 files edited). Consider finishing current work." |
| Filling + long session (≥20 min) | "📊 Context ~70%. Good stopping point approaching." |
| Critical state | "⚠️ Context ~85%. Finish current work and start fresh session soon." |
| Degraded state | "🛑 Context ~95% (high usage). Start new session for best results." |
| Stuck (5+ iterations, no edits) | "💡 No recent file edits. If you're stuck, a fresh session may help." |
| Very long (40+ min) | "⏱️ Long session (40+ min). Fresh session recommended for optimal performance." |

### Stuck Detection

Automatically detects when progress stalls:

- Tracks file edit count across iterations
- Alerts after 5+ iterations without file changes
- Suggests fresh session to break out of stuck state

### Session Isolation

Each session is tracked independently:

- State stored in `.claude/context-state.json`
- Automatic reset on new conversation_id
- No cross-contamination between sessions

### Cross-Platform Compatibility

Robust implementation:

- Works on macOS and Linux
- Uses `mkdir` for atomic locking (POSIX-compliant)
- Automatic stale lock cleanup (>60 seconds)
- Graceful degradation if dependencies missing

### Security

Built-in protections:

- Path traversal blocking (`..` in file paths)
- Symlink validation
- Lock timeout to prevent deadlock
- Safe state updates with atomic operations

## Architecture

```
┌─────────────────────────────────────────────────┐
│          Claude Code Session                     │
│                                                  │
│  1. User sends message                           │
│  2. Claude processes, may edit files             │
│     ├─→ afterFileEdit hook                       │
│     │   └─→ context-monitor-file-tracker.sh     │
│     │       └─→ Updates files_touched array      │
│  3. Claude completes iteration                   │
│  4. stop hook triggers                           │
│     └─→ context-monitor.sh                       │
│         ├─→ Reads state file                     │
│         ├─→ Calculates health score              │
│         ├─→ Determines recommendation            │
│         └─→ Returns followup_message             │
│  5. User sees recommendation (if any)            │
└─────────────────────────────────────────────────┘
```

### State Management

**State File**: `.claude/context-state.json`

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

**Locking**: Uses atomic `mkdir` for concurrent access safety

### Configuration

**Global Config**: `~/.claude/context-config.json` (optional)

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

## Key Adaptations from Cursor

### What Changed

1. **Task Tracking**
   - **Cursor**: Parses `AGENTS.md` for `[TODO]`, `[WIP]`, `[DONE]` markers
   - **Claude**: Uses heuristics (iterations, file edits, duration)
   - **Reason**: Claude's task system is internal, not accessible from hooks

2. **Recommendations**
   - **Cursor**: Suggests `/summarize` command or new session
   - **Claude**: Only suggests new session (no summarize command)
   - **Reason**: Claude auto-summarizes internally, no user-facing control

3. **Health Calculation**
   - **Cursor**: `(iterations × 8) + (files × 2) + (tasks × 15) - (summarize × 25)`
   - **Claude**: `(iterations × 10) + (files × 3) + (duration × 0.5)`
   - **Reason**: Simplified without task completion and summarize tracking

4. **Thresholds**
   - **Cursor**: Healthy <50%, Filling <75%, Critical <90%
   - **Claude**: Healthy <60%, Filling <80%, Critical <95%
   - **Reason**: More conservative to reduce false positives

### What Stayed the Same

- Stop hook architecture
- Cross-platform file locking
- JSON state management
- Stuck detection approach
- Configuration override system
- Security validations

## Installation Quick Start

```bash
# 1. Install prerequisites
brew install jq  # macOS
# OR
sudo apt-get install jq  # Ubuntu/Debian

# 2. Run installer
cd claude/hooks
chmod +x install-context-monitor.sh
./install-context-monitor.sh --config

# 3. Done! Hooks are active in all Claude Code sessions
```

## Testing

Run the test suite:

```bash
cd claude/hooks
chmod +x test-context-monitor.sh
./test-context-monitor.sh
```

Expected output:

```
═══════════════════════════════════════════════════
  Context Monitor Test Suite
═══════════════════════════════════════════════════

TEST: Prerequisites (jq installed)
  ✓ PASS

TEST: File tracker initializes state
  ✓ PASS

...

═══════════════════════════════════════════════════
  Test Summary
═══════════════════════════════════════════════════

  Tests run:    13
  Tests passed: 13
  Tests failed: 0

✓ All tests passed!
```

## File Structure

```
claude/hooks/
├── context-monitor.sh                    # Main stop hook
├── context-monitor-file-tracker.sh       # afterFileEdit hook
├── install-context-monitor.sh            # Automated installer
├── test-context-monitor.sh               # Test suite
├── context-config-example.json           # Example config
├── CONTEXT_MONITOR.md                    # User guide (comprehensive)
├── CONTEXT_MONITOR_SUMMARY.md            # This file (overview)
└── ...

claude/docs/
└── context-monitor-research.md           # Deep research analysis

User files (created at runtime):
~/.claude/
├── hooks.json                            # Hook registration
├── context-config.json                   # Optional custom config
└── hooks/
    ├── context-monitor.sh                # Copied by installer
    └── context-monitor-file-tracker.sh   # Copied by installer

.claude/
└── context-state.json                    # Per-project session state
```

## Usage Examples

### Example 1: Normal Session (No Warnings)

```
User: "Add a new function to calculate prime numbers"
Claude: [Creates function in math.go]
Context Monitor: (silent - healthy state)

User: "Add tests for that function"
Claude: [Creates tests in math_test.go]
Context Monitor: (silent - healthy state)

User: "Run the tests"
Claude: [Runs tests, they pass]
Context Monitor: (silent - healthy state)
```

### Example 2: Filling Context

```
User: "Refactor the entire API package"
Claude: [Edits 8 files, 15 iterations]
Context Monitor: "📊 Context ~72% (8 files edited). Consider finishing current work."

User: "Let's finish up and commit"
Claude: [Commits changes]
Context Monitor: (silent - wrapping up)

[User starts new session for next task]
```

### Example 3: Stuck Detection

```
User: "Debug why the tests are failing"
Claude: [Investigates, reads files, no edits - 6 iterations]
Context Monitor: "💡 No recent file edits. If you're stuck, a fresh session may help."

User: "Let's start fresh and approach this differently"
[User starts new session]
```

### Example 4: Long Session

```
[45 minutes into session, many edits]
Context Monitor: "⏱️ Long session (45+ min). Fresh session recommended for optimal performance."

User: "Good idea, let me commit and start fresh"
```

## Benefits

### For Users

1. **Better Code Quality**: Fresh context → sharper Claude assistance
2. **Time Savings**: Avoid degraded sessions that give poor suggestions
3. **Awareness**: Know when you're approaching context limits
4. **Guidance**: Clear recommendations on when to stop/start

### For Claude Code

1. **Resource Management**: Encourages users to start fresh, reducing long sessions
2. **User Education**: Teaches context management best practices
3. **Quality Maintenance**: Prevents frustration from degraded assistance
4. **Proactive UX**: Anticipates problems before they become critical

## Limitations

1. **No Direct Task Access**: Can't query Claude's internal task system
2. **Heuristic-Based**: Relies on patterns, not explicit completion signals
3. **No Token Counting**: Uses proxy metrics instead of actual token usage
4. **User Discipline Required**: User must act on recommendations

## Future Enhancements

### Potential Improvements

1. **Token Integration**: If Claude exposes token counts, use real data
2. **Task File Parsing**: Optional support for TODO.md or similar files
3. **Git Integration**: Detect commits as natural stopping points
4. **Machine Learning**: Learn user's patterns over time
5. **Ralph Loop Coordination**: Better integration with ralph-loop state
6. **Web Dashboard**: Visual representation of context health
7. **Slack/Email Alerts**: Notify when critical threshold reached
8. **Team Analytics**: Aggregate context health across team

### Known Issues

None at this time. Report issues in the repository.

## Technical Highlights

### Cross-Platform Locking

Uses `mkdir` (atomic on POSIX) instead of `flock` (not portable):

```bash
# Atomic lock acquisition
if mkdir "$LOCK_DIR" 2>/dev/null; then
    # Lock acquired
    trap "rm -rf '$LOCK_DIR'" EXIT
fi
```

### Graceful Degradation

Silently fails if prerequisites missing:

```bash
if ! command -v jq &> /dev/null; then
    echo '{"error": "jq required"}' >&2
    exit 0  # Exit cleanly, don't block Claude
fi
```

### Safe State Updates

Atomic write-move pattern:

```bash
jq "$expression" "$STATE_FILE" > "$tmp"
mv "$tmp" "$STATE_FILE"  # Atomic on POSIX
```

### Security Validations

```bash
# Block path traversal
if [[ "$file_path" == *".."* ]]; then
    exit 0  # Silently reject
fi
```

## Metrics

### Test Coverage

- **13 test cases** covering:
  - Initialization
  - File tracking (deduplication, multiple files)
  - Iteration counting
  - Health state detection
  - Stuck detection
  - Conversation reset
  - Security (path traversal)
  - Configuration override
  - Status filtering

### Code Quality

- **100% bash scripts**: No external dependencies beyond jq
- **Cross-platform**: Works on macOS and Linux
- **Thread-safe**: Atomic locking for concurrent access
- **Documented**: Comprehensive inline comments
- **Tested**: Full test suite included

## Credits

- **Original Design**: Cursor's context-monitor.sh
- **Claude Code Adaptation**: Eduardo A. (2025-01-27)
- **Research**: Comprehensive analysis of both systems
- **Testing**: Automated test suite with 13 cases

## License

MIT License - Same as Claude Code hooks collection

## Getting Help

**Documentation**:

- User guide: `claude/hooks/CONTEXT_MONITOR.md`
- Research: `claude/docs/context-monitor-research.md`
- This summary: `claude/hooks/CONTEXT_MONITOR_SUMMARY.md`

**Issues**:

- File bugs in the repository
- Include `.claude/context-state.json` contents
- Specify your OS and jq version

**Questions**:

- Check FAQ in CONTEXT_MONITOR.md
- Review troubleshooting section
- Examine test cases for usage examples

---

**Status**: ✅ Production Ready

Built with ❤️ for the Claude Code community

# Claude Cache Cleanup - Automated Weekly Maintenance

**Date:** 2026-02-14
**Status:** Approved
**Author:** Claude (Sonnet 4.5)

## Overview

Automated weekly cleanup of Claude's cache directories (shell-snapshots, debug, todos) that accumulates over time. The solution uses a simple shell check in `.zshrc` to delete files older than 7 days every Monday when a terminal opens.

## Problem Statement

Three directories in `~/.claude/` accumulate files indefinitely:
- `shell-snapshots/` - Shell state snapshots (~100-140KB each)
- `debug/` - Debug logs and session transcripts (varying sizes, some up to 23MB)
- `todos/` - Task tracking files (small, ~2 bytes each)

Currently 70+ debug files, 11 shell snapshots, and 13 todo files exist with no automatic cleanup mechanism.

## Requirements

1. **Retention Policy:** Weekly reset - keep only files from current week (delete files older than 7 days)
2. **Timing:** Monday as soon as machine is awake (first terminal open on Monday)
3. **Logging:** Silent operation - only log errors to file
4. **Simplicity:** No complex system services, minimal code

## Design

### Architecture

Simple shell-based cleanup triggered on first Monday terminal session:
- Add check to `~/.zshrc` that runs during shell initialization
- Use date check (`date +%u` = 1 for Monday) to detect if it's Monday
- Use marker file (`~/.claude/.cleaned-this-week`) to ensure cleanup runs only once per week
- Cleanup deletes all files older than 7 days from three target directories
- Marker auto-resets on Sunday night via background job

**Key principle:** Piggyback on existing shell initialization rather than adding new system services. Zero additional processes, zero configuration files.

### Components

**1. Date & Marker Check (guards)**
```bash
[[ $(date +%u) -eq 1 ]]                        # Is it Monday?
[[ ! -f ~/.claude/.cleaned-this-week ]]        # Hasn't run yet this week?
```

**2. Cleanup Commands (action)**
```bash
find ~/.claude/shell-snapshots -type f -mtime +7 -delete 2>>~/.claude/cleanup-errors.log
find ~/.claude/debug -type f -mtime +7 -delete 2>>~/.claude/cleanup-errors.log
find ~/.claude/todos -type f -mtime +7 -delete 2>>~/.claude/cleanup-errors.log
```
- `-mtime +7` matches files older than 7 days
- `-delete` removes matched files
- `2>>~/.claude/cleanup-errors.log` captures errors (silent on success)

**3. Marker Management (state tracking)**
```bash
touch ~/.claude/.cleaned-this-week             # Mark cleanup complete
( sleep 518400 && rm ~/.claude/.cleaned-this-week ) & disown
```
- Marker prevents multiple runs in same week
- Background job sleeps 6 days (518400 seconds) then removes marker on Sunday
- `disown` detaches job so it survives shell exit

**Total implementation:** ~8 lines in `.zshrc`, no separate script files.

### Execution Flow

**Monday morning:**
1. User opens terminal (any terminal window, any session)
2. `.zshrc` sources → cleanup check runs
3. Date check passes (Monday) → marker check passes (file doesn't exist)
4. Three `find -delete` commands execute sequentially
5. Marker file created → cleanup won't run again this week
6. Background reset job spawned (removes marker in 6 days)

**Throughout the week:**
- Subsequent terminal sessions check → marker exists → skip cleanup
- Files continue accumulating in the three directories

**Sunday night (automatic):**
- Background job from Monday wakes up
- Removes marker file
- System ready for next Monday cleanup

**Edge cases:**
- Multiple terminals open simultaneously on Monday → first one wins, others see marker and skip
- Machine off all week → cleanup happens next Monday when terminal opens
- Marker manually deleted → cleanup runs immediately on next Monday terminal open

### Error Handling

**Error logging strategy:**
- Errors append to `~/.claude/cleanup-errors.log` for troubleshooting
- Success produces no output (silent operation)
- `find` gracefully handles non-existent directories (no action, no error)

**Failure modes:**
- If marker file creation fails → cleanup may run multiple times (harmless)
- If background reset job fails → need to manually remove marker next Monday (one-time inconvenience)
- If directories become protected → errors logged, cleanup skips those directories
- If directories are deleted → `find` silently skips, no error

**Trade-off:** Errors are logged but not actively surfaced. User must check log file if they notice accumulation continuing.

### Testing & Verification

**Manual testing:**
```bash
# Test initial cleanup
rm -f ~/.claude/.cleaned-this-week
source ~/.zshrc

# Verify idempotency (won't run twice)
source ~/.zshrc

# Check error logging
cat ~/.claude/cleanup-errors.log

# Verify files were deleted
ls -lt ~/.claude/shell-snapshots | tail -5
```

**Production verification:**
```bash
# After Monday cleanup, verify marker exists
ls -l ~/.claude/.cleaned-this-week

# Verify no errors
[ ! -s ~/.claude/cleanup-errors.log ] && echo "No errors"

# Spot check directory sizes shrink
du -sh ~/.claude/{shell-snapshots,debug,todos}
```

## Implementation

See implementation plan in `2026-02-14-claude-cache-cleanup-plan.md`.

## Alternatives Considered

**launchd Agent (rejected):** Native macOS scheduled task with plist file and proper daemon integration. Handles wake/sleep properly but requires significant setup (plist XML, launchctl commands). Overengineered for simple file deletion.

**cron Job (rejected):** Traditional Unix scheduler (`0 6 * * 1`). Simple syntax but doesn't handle sleep well - if Mac is asleep at scheduled time, job is skipped until next week. Less Mac-native.

**Claude Hook (rejected):** Piggyback on existing SessionStart hook. Very simple but only runs when Claude is used - not guaranteed to run every Monday. Too dependent on usage patterns.

## Decision

Use shell profile check in `~/.zshrc` for its simplicity, zero configuration overhead, and reliable execution on first Monday terminal open.

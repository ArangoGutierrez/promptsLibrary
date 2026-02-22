# Claude Cache Cleanup Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add automated weekly cleanup of Claude cache directories (shell-snapshots, debug, todos) via `.zshrc` shell check.

**Architecture:** Simple shell conditional in `.zshrc` that checks if it's Monday and if cleanup has run this week. Uses marker file for idempotency and background job for weekly reset.

**Tech Stack:** Bash/Zsh, find command, POSIX date utilities

---

## Task 1: Backup Current Shell Configuration

**Files:**
- Read: `~/.zshrc`
- Create: `~/.zshrc.backup-2026-02-14`

**Step 1: Create timestamped backup**

Run:
```bash
cp ~/.zshrc ~/.zshrc.backup-2026-02-14
```

Expected: File created successfully

**Step 2: Verify backup created**

Run:
```bash
ls -lh ~/.zshrc.backup-2026-02-14
```

Expected: Backup file exists with same size as original

**Step 3: Commit backup**

```bash
cd ~/.claude
git add ~/.zshrc.backup-2026-02-14 2>/dev/null || echo "Not in claude repo, skip git"
```

Expected: Backup preserved (git optional)

---

## Task 2: Add Cleanup Code to .zshrc

**Files:**
- Modify: `~/.zshrc` (append at end)

**Step 1: Add cleanup block to .zshrc**

Append this code block to `~/.zshrc`:

```bash
# Claude cache cleanup - runs once per week on Monday
# Added: 2026-02-14
if [[ $(date +%u) -eq 1 ]] && [[ ! -f ~/.claude/.cleaned-this-week ]]; then
    find ~/.claude/shell-snapshots -type f -mtime +7 -delete 2>>~/.claude/cleanup-errors.log
    find ~/.claude/debug -type f -mtime +7 -delete 2>>~/.claude/cleanup-errors.log
    find ~/.claude/todos -type f -mtime +7 -delete 2>>~/.claude/cleanup-errors.log
    touch ~/.claude/.cleaned-this-week
    ( sleep 518400 && rm ~/.claude/.cleaned-this-week ) & disown
fi
```

Run:
```bash
cat >> ~/.zshrc << 'EOF'

# Claude cache cleanup - runs once per week on Monday
# Added: 2026-02-14
if [[ $(date +%u) -eq 1 ]] && [[ ! -f ~/.claude/.cleaned-this-week ]]; then
    find ~/.claude/shell-snapshots -type f -mtime +7 -delete 2>>~/.claude/cleanup-errors.log
    find ~/.claude/debug -type f -mtime +7 -delete 2>>~/.claude/cleanup-errors.log
    find ~/.claude/todos -type f -mtime +7 -delete 2>>~/.claude/cleanup-errors.log
    touch ~/.claude/.cleaned-this-week
    ( sleep 518400 && rm ~/.claude/.cleaned-this-week ) & disown
fi
EOF
```

Expected: Code appended successfully

**Step 2: Verify code added**

Run:
```bash
tail -12 ~/.zshrc
```

Expected: Should see the cleanup block with comments

**Step 3: Check for syntax errors**

Run:
```bash
zsh -n ~/.zshrc
```

Expected: No output (syntax valid)

---

## Task 3: Test Cleanup Execution (Manual Trigger)

**Files:**
- Test: `~/.zshrc` (source to trigger cleanup)
- Check: `~/.claude/.cleaned-this-week` (marker file)
- Check: `~/.claude/cleanup-errors.log` (error log)

**Step 1: Count files before cleanup**

Run:
```bash
echo "shell-snapshots: $(find ~/.claude/shell-snapshots -type f | wc -l)"
echo "debug: $(find ~/.claude/debug -type f | wc -l)"
echo "todos: $(find ~/.claude/todos -type f | wc -l)"
```

Expected: Output shows current file counts

**Step 2: Remove marker to force cleanup**

Run:
```bash
rm -f ~/.claude/.cleaned-this-week
```

Expected: Marker removed (or doesn't exist yet)

**Step 3: Source .zshrc to trigger cleanup**

Run:
```bash
source ~/.zshrc
```

Expected: No output (silent operation)

**Step 4: Verify marker created**

Run:
```bash
ls -l ~/.claude/.cleaned-this-week
```

Expected: Marker file exists with current timestamp

**Step 5: Count files after cleanup**

Run:
```bash
echo "shell-snapshots: $(find ~/.claude/shell-snapshots -type f | wc -l)"
echo "debug: $(find ~/.claude/debug -type f | wc -l)"
echo "todos: $(find ~/.claude/todos -type f | wc -l)"
```

Expected: File counts reduced (files older than 7 days removed)

**Step 6: Check for errors**

Run:
```bash
if [[ -f ~/.claude/cleanup-errors.log ]]; then
    cat ~/.claude/cleanup-errors.log
else
    echo "No error log (good - no errors)"
fi
```

Expected: Either no log file, or empty log file, or only harmless messages

---

## Task 4: Test Idempotency (Won't Run Twice)

**Files:**
- Test: `~/.zshrc` (source again)
- Check: `~/.claude/.cleaned-this-week` (marker should prevent re-run)

**Step 1: Note marker timestamp**

Run:
```bash
stat -f "%Sm" ~/.claude/.cleaned-this-week
```

Expected: Shows creation time from previous test

**Step 2: Source .zshrc again immediately**

Run:
```bash
source ~/.zshrc
```

Expected: No output (skipped cleanup)

**Step 3: Verify marker timestamp unchanged**

Run:
```bash
stat -f "%Sm" ~/.claude/.cleaned-this-week
```

Expected: Same timestamp as Step 1 (cleanup didn't re-run)

**Step 4: Verify file counts unchanged**

Run:
```bash
echo "shell-snapshots: $(find ~/.claude/shell-snapshots -type f | wc -l)"
echo "debug: $(find ~/.claude/debug -type f | wc -l)"
echo "todos: $(find ~/.claude/todos -type f | wc -l)"
```

Expected: Same counts as after first cleanup (no additional deletions)

---

## Task 5: Test Background Reset Job

**Files:**
- Test: Background job spawned by cleanup

**Step 1: Check for background reset job**

Run:
```bash
jobs -l
```

Expected: May show background job or may have already detached (both OK)

**Step 2: Verify disown worked (process survives)**

Run:
```bash
ps aux | grep "[s]leep 518400" || echo "Job detached (expected)"
```

Expected: Either shows sleep process, or "Job detached" message

**Step 3: Document reset mechanism**

Note: Background job will remove marker after 6 days (518400 seconds = 144 hours). This cannot be tested immediately. Manual reset if needed:

```bash
rm ~/.claude/.cleaned-this-week
```

---

## Task 6: Document Maintenance Procedures

**Files:**
- Modify: `~/.claude/CLAUDE.md` (add maintenance section)

**Step 1: Add maintenance section to CLAUDE.md**

Add this section to `~/.claude/CLAUDE.md` under a new "## Maintenance" heading:

```markdown
## Maintenance

### Automated Cache Cleanup

**Weekly cleanup of cache directories runs automatically every Monday when you open a terminal.**

Directories cleaned:
- `~/.claude/shell-snapshots/` - Shell state snapshots
- `~/.claude/debug/` - Debug logs and session transcripts
- `~/.claude/todos/` - Task tracking files

**Retention:** Files older than 7 days are deleted.

**Troubleshooting:**

Check error log:
```bash
cat ~/.claude/cleanup-errors.log
```

Manually trigger cleanup (if needed):
```bash
rm ~/.claude/.cleaned-this-week
source ~/.zshrc
```

Disable cleanup (temporary):
```bash
touch ~/.claude/.cleaned-this-week  # Prevents cleanup this week
```

Disable cleanup (permanent):
```bash
# Remove cleanup block from ~/.zshrc (lines added 2026-02-14)
```

**Design:** See `docs/plans/2026-02-14-claude-cache-cleanup-design.md`
```

Run:
```bash
# Add to CLAUDE.md manually or via editor
```

Expected: Documentation updated

**Step 2: Verify documentation readable**

Run:
```bash
grep -A 5 "Automated Cache Cleanup" ~/.claude/CLAUDE.md
```

Expected: Shows new maintenance section

---

## Task 7: Final Verification and Commit

**Files:**
- Modified: `~/.zshrc`
- Modified: `~/.claude/CLAUDE.md`
- Created: `~/.zshrc.backup-2026-02-14`

**Step 1: Run final verification checks**

Run:
```bash
# Verify cleanup code in .zshrc
grep -c "Claude cache cleanup" ~/.zshrc

# Verify marker exists
ls -l ~/.claude/.cleaned-this-week

# Verify no errors
[ ! -s ~/.claude/cleanup-errors.log ] && echo "No errors (good)" || cat ~/.claude/cleanup-errors.log

# Show directory sizes
du -sh ~/.claude/{shell-snapshots,debug,todos}
```

Expected: All checks pass

**Step 2: Commit changes to git**

```bash
cd ~/.claude
git add CLAUDE.md
git commit -m "feat: add automated weekly cache cleanup

Add shell-based cleanup to .zshrc that runs every Monday when terminal
opens. Removes files older than 7 days from shell-snapshots, debug, and
todos directories.

- Weekly reset via marker file (.cleaned-this-week)
- Silent operation with error logging
- Auto-reset on Sunday via background job
- Documented in CLAUDE.md maintenance section"
```

Expected: Changes committed successfully

**Step 3: Verify commit**

Run:
```bash
git log -1 --oneline
```

Expected: Shows commit with "feat: add automated weekly cache cleanup"

---

## Task 8: Restore and Retest (Validation)

**Files:**
- Test: Clean slate validation

**Step 1: Open new terminal window**

Action: Open a fresh terminal window/tab

Expected: New shell session starts

**Step 2: Verify cleanup code loaded**

Run:
```bash
type -a grep "Claude cache cleanup" ~/.zshrc
```

Expected: Shows cleanup code present in .zshrc

**Step 3: Check marker status**

Run:
```bash
if [[ -f ~/.claude/.cleaned-this-week ]]; then
    echo "Marker exists - cleanup won't run until next Monday"
    ls -l ~/.claude/.cleaned-this-week
else
    echo "Marker missing - cleanup will run on next Monday terminal open"
fi
```

Expected: Status message confirms expected behavior

---

## Rollback Procedure (If Needed)

If cleanup causes issues, restore from backup:

```bash
# Restore original .zshrc
cp ~/.zshrc.backup-2026-02-14 ~/.zshrc

# Remove marker
rm -f ~/.claude/.cleaned-this-week

# Kill background reset job (if running)
pkill -f "sleep 518400.*claude"

# Source restored config
source ~/.zshrc
```

---

## Success Criteria

- ✅ Cleanup code added to `~/.zshrc` without syntax errors
- ✅ Manual test successfully deleted files older than 7 days
- ✅ Idempotency verified (won't run twice in same week)
- ✅ Marker file created and prevents re-execution
- ✅ No errors in `cleanup-errors.log` (or file doesn't exist)
- ✅ Background reset job spawned and detached
- ✅ Documentation added to `CLAUDE.md`
- ✅ Changes committed to git
- ✅ Fresh terminal loads config without errors

---

## Notes

- **Testing limitation:** Cannot immediately verify Sunday reset (6-day delay). Marker can be manually removed for testing if needed.
- **Production use:** After this week, monitor that cleanup runs every Monday by checking marker file creation timestamp.
- **File counts:** Initial cleanup may remove many old files. Subsequent weeks will remove fewer files (only 7+ day old files from previous week).

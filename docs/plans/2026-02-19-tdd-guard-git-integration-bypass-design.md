# TDD Guard: Git Integration Bypass

**Date:** 2026-02-19
**Status:** Approved

## Problem

The TDD guard hook (`hooks/tdd-guard.sh`) blocks edits to implementation files
when no test has been modified in the current session. This is correct for new
implementation work, but incorrectly blocks edits during git integration
operations (merge, rebase, cherry-pick, revert, stash pop) where the intent is
conflict resolution or integration — not writing new code.

## Decision

**Approach 1: Detect git mid-operation state** — check for sentinel files that
git creates during integration operations. If any exist, allow the edit.

Alternatives considered:
- Detect conflict markers in files (too narrow — only covers conflicts, not clean operations)
- Combined git state + conflict markers (unnecessary complexity)

## Design

Add a git mid-operation check near the top of `tdd-guard.sh`, after `GIT_ROOT`
is determined. Uses `git rev-parse --git-dir` instead of hardcoded `.git/` to
support worktrees correctly.

### Sentinel files checked

| File/Directory | Operation |
|---|---|
| `MERGE_HEAD` | `git merge` in progress |
| `CHERRY_PICK_HEAD` | `git cherry-pick` in progress |
| `REVERT_HEAD` | `git revert` in progress |
| `rebase-merge/` | `git rebase` (interactive) in progress |
| `rebase-apply/` | `git rebase` (apply) or `git am` in progress |

### Implementation

```bash
# Git mid-operation? Allow — this is integration work, not new implementation.
GIT_DIR=$(git rev-parse --git-dir 2>/dev/null) || exit 0
for sentinel in \
    "$GIT_DIR/MERGE_HEAD" \
    "$GIT_DIR/CHERRY_PICK_HEAD" \
    "$GIT_DIR/REVERT_HEAD" \
    "$GIT_DIR/rebase-merge" \
    "$GIT_DIR/rebase-apply"; do
    [ -e "$sentinel" ] && exit 0
done
```

### Placement

After the existing `GIT_ROOT` line (~line 20), before file path extraction.
Short-circuits early to avoid unnecessary processing.

## Scope

- 1 file changed: `hooks/tdd-guard.sh`
- ~8 lines added
- No other files affected

# Commit Signing Enforcement — Design

**Date**: 2026-02-16
**Status**: Approved

## Problem

The `sign-commits.sh` Claude Code hook uses `^git commit` regex which only matches
commands starting with `git commit`. Subagents and agent teams frequently chain
commands (e.g., `git add . && git commit -m "msg"` or `cd /worktree && git commit`),
causing the hook to miss these commits entirely. This results in sporadic unsigned
commits.

## Current State

### Working
- `commit.gpgsign=true` in global git config — GPG signing (SSH-based) happens
  automatically for all commits
- SSH signing key: `~/.ssh/id_ed25519.pub`
- `sign-commits.sh` hook catches simple `git commit` commands

### Not Working
- Signoff (`Signed-off-by:`) is NOT enforced at the git level.
  `format.signoff=true` only affects `git format-patch`, not `git commit`.
- The Claude hook regex misses chained/prefixed commands.

## Solution: Two Layers

### Layer 1: Fix Claude Hook Regex

Update `~/.claude/hooks/sign-commits.sh` to detect `git commit` anywhere in the
command string, handling:
- `&&` chains: `git add . && git commit -m "msg"`
- `;` chains: `cd /dir; git commit -m "msg"`
- Pipe chains: unlikely but defensive

The hook should extract the `git commit` portion and check for `-s`/`-S` flags
relative to that portion.

### Layer 2: Global Git Hook for Signoff

Create `~/.config/git/hooks/prepare-commit-msg` that automatically appends
`Signed-off-by: <user>` if not already present. This makes the `-s` flag
redundant at the command level — git itself handles it.

Set `core.hooksPath=~/.config/git/hooks` so the hook applies globally.

## Files Changed

1. `~/.claude/hooks/sign-commits.sh` — improved command detection regex
2. `~/.config/git/hooks/prepare-commit-msg` — new, auto-adds signoff
3. Git global config — `core.hooksPath=~/.config/git/hooks`

## Risk

- Setting `core.hooksPath` globally overrides per-repo `.git/hooks`. Confirmed
  this is acceptable (no per-repo hooks in use).
- The `prepare-commit-msg` hook adds signoff to ALL commits (manual and automated).
  This is the desired behavior.

# CLAUDE.md Enhancement Design

**Date:** 2026-02-16
**Status:** Approved
**Approach:** Surgical Fix (Approach A)

## Problem Statement

The current CLAUDE.md (~140 lines) has several issues:

1. **Token waste** — Instructions duplicate what hooks already enforce (year validation, worktree enforcement, push prevention, commit signing)
2. **Worktree branching from stale local refs** — The worktree creation command uses local branch names, but the user works with forks and never updates local main. Worktrees should always branch from remote refs (upstream or origin)
3. **Brainstorming gets skipped** — The "Just do it" escape hatch is too easy for Claude to self-trigger. The exempt list is interpreted too broadly
4. **Workflow confusion** — Claude mixes up when to use worktrees, when to commit, and doesn't follow the plan-to-verify flow consistently
5. **TDD enforcement is advisory-only** — No mechanical enforcement. Research shows AI agents skip TDD without structural constraints

## Research Basis

### Key Sources

- **Anthropic's Context Engineering Guide** — Advisory instructions vs. deterministic hooks. CLAUDE.md should contain only what requires nuanced judgment
- **Empirical study of 253 CLAUDE.md files** (arxiv.org/html/2509.14744v1) — Median 5 H2 sections, shallow hierarchy. Under 300 lines recommended
- **Kent Beck on TDD + AI** — AI agents delete/weaken tests to make them pass. This is the most dangerous failure mode
- **"Tests as Prompt" benchmark** (arxiv.org/abs/2505.09027) — Test-first approaches improve AI code generation by 8-12%
- **alexop.dev TDD isolation study** — Context isolation (separate subagents for Red/Green) is the most impactful pattern. Skills only activate ~20% without hook enforcement
- **HumanLayer analysis** — Frontier LLMs follow ~150-200 instructions consistently. Claude Code system prompt consumes ~50. Budget carefully

### Key Insights

1. Hooks are deterministic; CLAUDE.md is advisory. If it must happen every time, use a hook
2. Every line must earn its place — "Would removing this cause Claude to make mistakes?"
3. Context isolation for TDD is more effective than instruction alone
4. AI agents rationalize skipping workflows. Close loopholes explicitly
5. Positive examples + alternatives outperform negative-only constraints

## Design: What Changes

### Reduction: 140 lines → ~55 lines (60% reduction)

### Removed (enforced elsewhere or low signal)

| Section | Lines | Reason |
|---|---|---|
| Current year rule | 1 | Enforced by `validate-year.sh` + `inject-date.sh` hooks |
| Self-consistency skill ref | 1 | Skills are discovered on invocation |
| Security section | 3 | Generic OWASP + Go-specific scan chain. Belongs in project-level CLAUDE.md |
| Toolchain (Go/K8s) | 2 | Project-specific. Belongs in project-level CLAUDE.md |
| Deep Thinking section | 1 | No measurable behavioral effect |
| K8s workflow skill ref | 1 | Indirection that wastes tokens |
| Agent Teams subsection | 5 | Documented in team skills |
| Setup instructions | 2 | Documented in `setup-workbench.sh` |
| Context Hygiene (4 of 5) | 4 | Standard Claude features, non-instructive |
| Maintenance section | 18 | Cron job documentation, not agent instructions |
| Context eng in TDD | 1 | Generic good practice Claude already follows |

### Added/Strengthened

| Change | Rationale |
|---|---|
| "If unsure whether exempt: brainstorm" | Closes rationalization loophole. Default is always brainstorm |
| Hybrid TDD enforcement (hook + escalation) | Hook guard is always-on, zero token cost. Isolated subagents activate by diff size |
| "NEVER weaken, delete, or modify tests" | Stronger language per Kent Beck's concern |
| Worktree: `git fetch` + remote ref branching | Prevents stale local ref problem. Upstream-aware for fork workflows |
| "Tests define done" | Anchors the constraint: implementation stops when tests pass |

### Worktree Branching Fix (critical)

**Before:**
```bash
git worktree add .worktrees/<name> -b <branch> <default-branch>
```
Problem: `<default-branch>` resolves to local `main`/`master`/`develop`, which may be weeks behind remote.

**After:**
```bash
git fetch upstream 2>/dev/null && BASE="upstream/main" || { git fetch origin && BASE="origin/$(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')"; }
git worktree add .worktrees/<name> -b <branch> "$BASE"
```
- Always fetches before branching
- Tries `upstream` first (fork workflow), falls back to `origin`
- Uses remote ref, never local

### TDD Hybrid Enforcement Model

**Tier 1 — Hook guard (always on):**
A PreToolUse hook checks whether a failing test exists before allowing implementation file writes. Zero token cost, mechanical enforcement.

**Tier 2 — Isolated subagents (diff-size triggered):**
When the diff exceeds a threshold, TDD escalates to separate subagent contexts:
- Red subagent: writes failing tests (no implementation knowledge)
- Green subagent: sees only failing tests, writes minimal implementation

This prevents the "same-author blind spot" where the same context writes both tests and code.

**Threshold:** Based on diff size. Small changes (few lines) get hook-only. Larger changes trigger full isolation automatically.

## Implementation Items

1. **Write the new CLAUDE.md** — Replace current file with the approved ~55-line version
2. **Create TDD hook guard** — PreToolUse hook on Write/Edit that validates a failing test exists before allowing implementation writes
3. **Update `setup-workbench.sh`** — Change the worktree creation example to use remote refs
4. **Update `enforce-worktree.sh`** — Update the error message to show the remote-ref command
5. **Enhance TDD skill** — Add diff-size detection and isolated subagent escalation logic

## Risks

- **TDD hook false positives** — The hook needs to distinguish test files from implementation files reliably. Mitigation: use file naming conventions (e.g., `*_test.go`, `*.test.ts`, `test_*.py`)
- **Upstream remote detection** — Not all repos have an `upstream` remote. Mitigation: the command falls back to `origin`
- **Over-trimming** — Removing too many instructions could cause regressions. Mitigation: monitor behavior in first week, add back any instructions that prove necessary

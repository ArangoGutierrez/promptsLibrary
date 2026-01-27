# Cursor Commands vs Claude Code Plugins - Mapping Analysis

## Direct Matches (Use Official Plugin Instead)

| Cursor Command | Claude Code Plugin | Recommendation | Notes |
|----------------|-------------------|----------------|-------|
| `loop.md` | **ralph-wiggum** (`/ralph-loop`, `/cancel-ralph`) | ✅ **USE OFFICIAL** | Cursor's version is a custom adaptation. Official plugin is better maintained and uses proper stop hook mechanism. |
| `push.md` | **commit-commands** (`/commit-push-pr`) | ⚠️ **HYBRID** | Official has `/commit`, `/commit-push-pr`, `/clean_gone`. Cursor adds AGENTS.md integration and pre-push checklist. Consider combining both. |

## Partial Matches (Significant Differences)

| Cursor Command | Similar Claude Plugin | Comparison | Recommendation |
|----------------|----------------------|------------|----------------|
| `review-pr.md` | **code-review** (`/code-review`) | **Cursor**: Simple 3-pass review (security, bugs, architecture) with ≥80 confidence scoring<br>**Claude**: 4 parallel agents + CLAUDE.md compliance + git blame analysis + PR comment posting | ⚠️ **EVALUATE** - Official is more comprehensive. Keep Cursor if you prefer simpler workflow. |
| `review-pr.md` | **pr-review-toolkit** (`/pr-review-toolkit:review-pr`) | **Cursor**: General review<br>**Claude**: 6 specialized agents (comments, tests, errors, types, code quality, simplification) with selective aspects | ⚠️ **EVALUATE** - Official toolkit is more modular. |
| `architect.md` | **feature-dev** (Phase 4) | **Cursor**: Full pipeline (arch-explorer → devil-advocate → parallel prototypers → synthesizer)<br>**Claude**: 7-phase workflow where Phase 4 does architecture (2-3 approaches with code-architect agents) | ⚠️ **DIFFERENT SCOPE** - Cursor focuses on architecture exploration only. Claude feature-dev is full feature development. Keep both. |

## Unique Cursor Commands (No Claude Code Equivalent)

These are original Cursor workflows with no official Claude Code plugin:

| Command | Purpose | Keep for Claude? |
|---------|---------|------------------|
| `task.md` | Spec-first task execution with phases: UNDERSTAND → SPECIFY → PLAN → IMPLEMENT → VERIFY | ✅ **YES** - Core workflow |
| `audit.md` | Deep defensive audit for Go/K8s production code | ✅ **YES** - Language-specific deep analysis |
| `code.md` | Execute next TODO from AGENTS.md | ✅ **YES** - AGENTS.md workflow integration |
| `git-polish.md` | Rewrite commits atomically | ✅ **YES** - Commit cleanup utility |
| `issue.md` | Convert GitHub issue to atomic task breakdown in AGENTS.md | ✅ **YES** - Issue workflow |
| `parallel.md` | Parallel task execution with dependency analysis | ✅ **YES** - Concurrent workflow |
| `quality.md` | Multi-agent quality review | ⚠️ **EVALUATE** - May overlap with code-review plugin |
| `research.md` | Deep issue research and brainstorming | ✅ **YES** - Research workflow |
| `self-review.md` | File-by-file self-review checklist | ✅ **YES** - Pre-commit review |
| `test.md` | Run and verify tests | ✅ **YES** - Testing workflow |
| `context-reset.md` | Reset/inspect context tracking state | ✅ **YES** - Context management |
| `debug.md` | Debug workflow | ✅ **YES** - Debugging workflow |
| `docs.md` | Documentation generation | ✅ **YES** - Docs workflow |
| `refactor.md` | Refactoring workflow | ✅ **YES** - Refactoring support |

## Official Claude Code Plugins (No Cursor Equivalent)

These official plugins have no Cursor counterpart - consider referencing them:

| Plugin | Commands/Skills | Recommendation |
|--------|----------------|----------------|
| **agent-sdk-dev** | `/new-sdk-app` | Document as reference |
| **claude-opus-4-5-migration** | Migration skill | Document as reference |
| **explanatory-output-style** | SessionStart hook | Consider adapting |
| **learning-output-style** | SessionStart hook | Consider adapting |
| **frontend-design** | Auto-triggered skill | Port if relevant |
| **hookify** | `/hookify`, `/hookify:list`, etc. | Reference official |
| **plugin-dev** | `/plugin-dev:create-plugin` | Reference official |
| **security-guidance** | PreToolUse hook | Compare with cursor/hooks/security-gate.sh |

## Detailed Comparisons

### 1. Loop/Ralph Comparison

| Feature | Cursor `loop.md` | Claude `ralph-wiggum` |
|---------|------------------|----------------------|
| Start command | `/loop` | `/ralph-loop` |
| Cancel command | "cancel loop" (text) | `/cancel-ralph` |
| Completion param | `--done "PHRASE"` | `--completion-promise "PHRASE"` |
| Max iterations | `--max N` | `--max-iterations N` |
| State tracking | `.cursor/loop-state.json` | Internal plugin state |
| AGENTS.md integration | ✅ Built-in | ❌ Not included |
| Hook mechanism | Custom `task-loop.sh` | Official stop hook |
| Documentation | Troubleshooting focus | Philosophy + best practices |

**Verdict**: Use official `ralph-wiggum`, create companion skill for AGENTS.md pattern

---

### 2. PR Review Comparison

| Feature | Cursor `review-pr.md` | Claude `code-review` | Claude `pr-review-toolkit` |
|---------|----------------------|---------------------|---------------------------|
| Command | `/review-pr` | `/code-review` | `/pr-review-toolkit:review-pr` |
| Review passes | 3 (Security, Bugs, Architecture) | 4 parallel agents | 6 specialized agents |
| Confidence scoring | ≥80 threshold | ≥80 threshold | Per-agent |
| CLAUDE.md compliance | ❌ | ✅ 2 agents | ❌ |
| Git blame analysis | ❌ | ✅ Agent #4 | ❌ |
| PR comment posting | ❌ Terminal only | ✅ `--comment` flag | ✅ |
| Aspects | All-in-one | All-in-one | Selective (comments, tests, errors, types, code, simplify) |

**Verdict**: Official plugins are more comprehensive. Evaluate based on needs:

- Simple workflow → Keep Cursor version
- Comprehensive review → Use `code-review`
- Specialized aspects → Use `pr-review-toolkit`

---

### 3. Push/Commit Comparison

| Feature | Cursor `push.md` | Claude `commit-commands` |
|---------|------------------|-------------------------|
| Commands | 1 (`/push`) | 3 (`/commit`, `/commit-push-pr`, `/clean_gone`) |
| Pre-push checks | ✅ AGENTS.md, tests, self-review | ❌ |
| AGENTS.md update | ✅ Records PR number | ❌ |
| Branch cleanup | ❌ | ✅ `/clean_gone` |
| Commit only | ❌ | ✅ `/commit` |
| PR creation | ✅ | ✅ `/commit-push-pr` |

**Verdict**: Hybrid approach - use official `/commit` and `/clean_gone`, adapt Cursor's pre-push checks

---

### 4. Architecture Exploration Comparison

| Feature | Cursor `architect.md` | Claude `feature-dev` (Phase 4) |
|---------|----------------------|--------------------------------|
| Scope | Architecture only | Full feature development (7 phases) |
| Pipeline | arch-explorer → devil-advocate → prototypers → synthesizer | Phase 4: 2-3 code-architect agents with different focuses |
| Prototyping | ✅ Parallel background prototypes | ❌ Not in Phase 4 (implementation is Phase 5) |
| Devil's advocate | ✅ Dedicated challenge phase | ❌ Not included |
| Synthesizer | ✅ Final recommendation | ❌ (manual decision) |
| Output location | `.prototypes/{approach}/` | N/A |

**Verdict**: Different tools for different purposes:

- Pure architecture exploration → Cursor `architect.md`
- Full feature workflow → Claude `feature-dev`
- Keep both, document when to use each

## Migration Strategy

### Phase 1: Reference Official Plugins

Create symlinks or references to official plugins:

```bash
claude/
├── plugins/
│   ├── ralph-wiggum/          # → Official plugin
│   ├── code-review/            # → Official plugin
│   ├── commit-commands/        # → Official plugin
│   ├── feature-dev/            # → Official plugin
│   ├── pr-review-toolkit/      # → Official plugin
│   └── [other official plugins...]
```

### Phase 2: Port Unique Commands

Convert Cursor-only commands to Claude Code skills:

- task.md → skill
- audit.md → skill
- code.md → skill
- issue.md → skill
- research.md → skill
- [etc.]

### Phase 3: Create Hybrid/Companion Skills

For partial matches, create skills that:

- Document when to use official plugin vs Cursor version
- Add missing features (e.g., AGENTS.md integration for ralph)
- Combine best of both

### Phase 4: Adaptation Guides

Document patterns for users migrating from Cursor:

```markdown
## Cursor → Claude Code Quick Reference

| Cursor | Claude Code |
|--------|-------------|
| `/loop "task" --done "DONE" --max 10` | `/ralph-loop "task" --completion-promise "DONE" --max-iterations 10` |
| `/push` | `/commit-push-pr` (add pre-checks separately) |
| `/review-pr` | `/code-review` or `/pr-review-toolkit:review-pr` |
```

## Summary

**Use Official Plugins (Don't Port):**

- ✅ ralph-wiggum (instead of loop.md)
- ⚠️ commit-commands (hybrid with push.md)
- ⚠️ code-review or pr-review-toolkit (evaluate vs review-pr.md)

**Port from Cursor (Unique Value):**

- ✅ task.md, audit.md, code.md, issue.md
- ✅ research.md, self-review.md, test.md
- ✅ git-polish.md, parallel.md, context-reset.md
- ✅ debug.md, docs.md, refactor.md
- ⚠️ architect.md (different from feature-dev, keep both)
- ⚠️ quality.md (evaluate overlap with code-review)

**Total Count:**

- Official plugins to reference: 3-4
- Unique Cursor commands to port: ~14
- Hybrid/companion skills needed: ~3

# Cursor Agents Model Inheritance

**Date:** 2026-01-31
**Status:** Implemented

## Problem

Cursor subagents in `~/.cursor/agents/` were hardcoded to use `model: claude-4-5-sonnet`, which prevented them from inheriting the model from the parent session. This meant:
- Agents couldn't adapt to the session's model choice
- Manual updates required when switching models
- Inconsistent behavior when using different Claude models in parent sessions

## Solution

Updated all 9 Cursor subagent files to use `model: inherit` instead of hardcoded model IDs.

### Changed Files

```
cursor/_optimized/agents/api-reviewer.md
cursor/_optimized/agents/arch-explorer.md
cursor/_optimized/agents/auditor.md
cursor/_optimized/agents/devil-advocate.md
cursor/_optimized/agents/perf-critic.md
cursor/_optimized/agents/prototyper.md
cursor/_optimized/agents/researcher.md
cursor/_optimized/agents/synthesizer.md
cursor/_optimized/agents/verifier.md
```

### Change Applied

```diff
-model: claude-4-5-sonnet
+model: inherit
```

## Implementation

Used batch `sed` replacement:
```bash
sed -i '' 's/^model: claude-4-5-sonnet$/model: inherit/' \
  /Users/eduardoa/src/dev/cursor/_optimized/agents/*.md
```

## Outcome

- All subagents now inherit the parent session's model
- Consistent model usage across parent and child agents
- Flexibility to use any Claude model without agent file updates
- Symlinks in `~/.cursor/agents/` automatically reflect changes

## References

- [Cursor Subagents Documentation](https://cursor.com/docs/context/subagents)
- Cursor agents symlinked from `~/.cursor/agents/` to source files

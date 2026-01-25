---
description: Automatic quality gates that trigger agents based on file changes
globs: ["**/*.go", "**/*.ts", "**/*.py"]
---

# Quality Gate Rule

## Auto-Trigger Agents

When working on code changes, automatically consider using these agents:

### On Any Code Change
- If modifying **handlers, routes, or controllers** → use `api-reviewer`
- If touching **database queries or I/O** → use `perf-critic`
- If changing **auth, crypto, or user data** → use `auditor`

### Before Completing a Task
- After implementing a feature → use `verifier` to confirm it works
- Before marking `[WIP]` → `[DONE]` → run quality check

### On Architectural Discussions
- When user says "how should we..." → suggest `arch-explorer`
- When user says "let's do X" (major change) → suggest `devil-advocate`
- When comparing approaches → offer to run parallel prototypes

## Proactive Suggestions

When appropriate, suggest:
```
I notice this touches {area}. Want me to run:
- /quality for a full review
- /architect to explore approaches
```

## File Pattern Triggers

| Pattern | Agent | Why |
|---------|-------|-----|
| `**/handlers/**` | api-reviewer, perf-critic | Hot path |
| `**/auth/**` | auditor | Security critical |
| `**/db/**`, `**/repo/**` | perf-critic | N+1 risk |
| `**/*_test.go` | verifier | Validate tests pass |
| `**/api/**` | api-reviewer | Contract changes |

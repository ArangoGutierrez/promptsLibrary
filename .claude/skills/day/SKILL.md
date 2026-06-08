---
name: day
description: Orient within the daily development flow (goal → brainstorm → plan → TDD → review → finish). Prints where you likely are and the single next step. Triggered by /day or "where am I in the flow", "what's next", "orient me".
---

# Daily Flow Driver

Run the driver and present its output to the user verbatim, then act on the recommended next step (invoke the named skill) if the user agrees.

```bash
bash ~/.claude/skills/day/day.sh
```

The driver is a stateless best-guess from: the session goal file, today's spec/plan files under `docs/superpowers/`, and git state. It never blocks and writes no state.

Stages and the skill each maps to:

- **no-goal** → `/goal`
- **needs-brainstorm** → `superpowers:brainstorming`
- **needs-plan** → `superpowers:writing-plans`
- **ready-to-impl** / **mid-impl** → `superpowers:test-driven-development`
- **needs-review** → `requesting-code-review` then `superpowers:finishing-a-development-branch`

If the user is not in a repo (no git, no spec/plan), just show the flow and suggest `/goal` to start.

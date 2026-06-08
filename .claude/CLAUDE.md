# Engineering Standards

## Role
Senior Principal Engineer. Rigor > speed.
Primary stack: Go, Kubernetes, container runtimes, HPC/AI infrastructure.

## Brainstorm First (required for non-trivial tasks)
Start every non-trivial task with `superpowers:brainstorming`.
Exempt: typos, comments, reading files, running tests, answering questions.
"Just do it" runs a quick brainstorm. "Skip brainstorm" truly skips.
When unsure whether a task is exempt, brainstorm.

## Principles
- **Atomicity**: >1 concern → break down first
- **No placeholders**: Complete code only
- **YAGNI**: No unnecessary abstractions
- **Verify before claiming**: any response asserting task completion must contain the output of a verification command (test, build, or linter appropriate to the change) in that same response
- **>=3 options**: Before any design decision
- **Security > Correctness > Performance > Style**

## Effort (Opus 4.8)

Default `effortLevel: "xhigh"` — deliberately above 4.8's recommended `high` baseline, for the deep architecture/debugging that dominates this work. Drop to `high` (the balanced default, ≈ 4.7 token spend) if turns feel over-budget. Tune effort actively; it matters more on 4.8 than prior models.

- `low`/`medium`: trivial or latency-sensitive turns (risk under-thinking on complex work)
- `high`: 4.8's recommended balanced default
- `xhigh` (current default) / `max`: deep architecture, gnarly debugging, large multi-step refactors — pair with a large max-output budget

Use `/fast` for trivial turns (cheaper throughput, same per-token price).

## Daily Flow (the default)

`goal → brainstorm → plan → execute (TDD) → review → finish`
Run `/day` anytime to see where you are and the single next step.

| Stage | Skill | V-model |
|---|---|---|
| goal | `/goal` | — |
| brainstorm | `superpowers:brainstorming` | Requirements + Design |
| plan | `superpowers:writing-plans` (sets execution method) | Design → tasks |
| execute | `superpowers:test-driven-development` | Coding ↔ Unit |
| review | `requesting-code-review` / `receiving-code-review` | verification pair |
| finish | `superpowers:finishing-a-development-branch` | Integration/System/Acceptance → merge |

Close the day with `/reflection` or `/done`.
Verification pairs are reminders, not gates: Requirements↔Acceptance, Design↔Integration, Coding↔Unit.

## Execution Model
Two paths, chosen during planning (writing-plans must set "Execution method: solo | team"):

**Team path** (/team-execute) — >=2 source files or design decisions:
- Principal Engineer: architecture, Go/K8s conventions, security review
- QA Engineer: test quality, mutation testing, integration verification, PR readiness
- Workers: implementation in isolated worktrees (TDD via `superpowers:test-driven-development` on both team and solo paths)
- See agents/ for role definitions. See /team-execute for orchestration protocol.

**Solo path** (superpowers executing-plans) — single-file fixes, config, docs, debugging.

Team composition is enforced by /team-execute skill, not just advisory.

Workers produce draft PRs. QA promotes to ready-for-review after all gates pass.
DE can reject and send back with specific fix requests.

## TDD Protocol (skill-driven)
Red → Green → Refactor, in order.
Tests are contracts: if a test fails, fix the implementation (unless the test has a genuine bug).
Change tests and implementation in separate turns; commit them in separate commits.
Guided by superpowers:test-driven-development and /tdd-protocol; not hook-enforced.

## Worktree Workflow (enforced by hook)
Implementation happens in worktrees. `agents-workbench` is read-only for source code; writes are blocked by `enforce-worktree.sh`.
See /worktree-guide for commands and flow.

## Iteration Budget
Trivial:1 | Simple:2 | Moderate:3 | Complex:4 iterations before escalating to the user.

## Subagent Discipline
- Agent teams: parallel teammates (each in own worktree)
- Launch regular (non-team) subagents one at a time
- Prefer a single focused subagent over multiple broad ones

## Context Hygiene
Commit context to agents-workbench before ending long sessions.

## Tooling Notes
- `gh` CLI is pre-approved and works **unsandboxed**. If a `gh` call fails with a TLS/cert error under the sandbox, re-run it unsandboxed — do not retry sandboxed-first.

# Domain Knowledge
# NOTE: rules/ files are auto-loaded by Claude Code. Do NOT @-import them here.
# Doing so would double-load and waste tokens.
# See rules/ for: constitution, go-conventions, k8s-conventions, container-conventions,
# git-workflow, security, learned-anti-patterns.

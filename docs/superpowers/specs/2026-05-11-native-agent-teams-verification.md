# Native Agent Teams — Verification & Adoption Decision (Deferred)

**Date:** 2026-05-11
**Decision:** **Defer migration.** Keep custom orchestration (this repo's `team-execute` skill / equivalents) for production work.
**Re-evaluate:** when ≥3 of the blockers listed below are closed, or at next 90-day review (2026-08-11).

## What this document is

A snapshot of Claude Code's native "agent teams" feature state as of May 2026, written so the migration decision can be revisited later with the original evidence intact. Pairs with `team-execute` (the custom orchestration this repo already ships).

## What native agent teams is

A Claude Code orchestration mode where one "lead" session spawns peer "teammate" agents with their own isolated context windows. Distinguishing features versus regular subagents:

- **Atomic shared task list** with file-locking for race-free claiming
- **Mailbox-based inter-agent messaging** via `SendMessage({to: name, message: ...})`
- **Lifecycle hook events** the harness fires at orchestration milestones
- **Plan-approval handshake** between Lead and teammate before work begins

Gated by `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`. Requires Claude Code v2.1.32+ (released 2026-02-05) and an Opus 4.x family model.

## Verified state

- **Status: experimental.** Anthropic still gates the feature behind the env flag and labels the docs with warnings. No GA timeline announced.
- **Docs page exists** at code.claude.com/docs/en/agent-teams with use cases, best practices, and troubleshooting.
- **No major rework in the last 60 days.** May 2026 changelog references ultrareview, PowerShell fallback, and skill/plugin validation but no agent-teams stability work.

## Blockers (verified open GitHub issues)

| Issue | Severity | Symptom |
|-------|----------|---------|
| anthropics/claude-code#28087 | High | `ANTHROPIC_MODEL` / `ANTHROPIC_API_KEY` don't propagate to teammates |
| anthropics/claude-code#36670 | High | Teammates spawn with 200K context even when Lead runs with `[1m]` variant |
| anthropics/claude-code#32987 | High | `/resume` and `/rewind` don't restore in-process teammates; Lead may `SendMessage` non-existent teammates after resume |
| anthropics/claude-code#23676 | Medium | `CLAUDE_CONFIG_DIR` not respected in spawned teammates → breaks shared task list |
| anthropics/claude-code#32721 | Medium | Teammates self-identify as "Claude Agent SDK" instead of "Claude Code", contradicting docs |
| anthropics/claude-code#42848 | Medium | PowerShell spawning uses Unix-style paths (Windows only) |

(URLs: `https://github.com/anthropics/claude-code/issues/<N>`. Counts/states verified May 2026.)

Two of the three High-severity blockers (#28087 model inheritance, #36670 context window mismatch) are fundamental: they make multi-day feature work cost-opaque and configuration-fragile.

## Community signals

- **GitHub trending repos** ship parallel orchestration tooling (`wshobson/agents`, Shipyard's multi-agent guides) rather than building on native agent teams. Reads as "early adopters routing around, not through."
- **Medium / blog posts** in 2026 are "here's how to use it" tutorials, not "here's why it works in our production flow." Tone is permissive, not endorsing.
- **Reddit** (r/ClaudeAI) over the last 60 days: no strong sentiment found in either direction — discussion exists, no migration narrative.

## Where native agent teams works today

- One-shot research / parallel exploration (e.g., 3 agents review the same code from different angles)
- Brainstorms where context loss between turns is tolerable
- Temporary teams that shut down after a single Lead prompt

## Where it doesn't work today

- Multi-day feature work with state persistence across sessions
- Cost-controlled workflows (the per-teammate 5× burn is real and not yet observable in built-in metrics)
- Workflows that depend on env var / model inheritance from the Lead session

## Why we keep `team-execute` for now

This repo's `team-execute` skill orchestrates Principal Engineer / QA Engineer / Workers via:
- Explicit worktrees (no harness-managed session state to lose)
- TDD enforcement via PreToolUse hooks (works on every Write/Edit regardless of teammate model)
- Conventional draft-PR → QA-promotes flow (no shared task list dependency)
- Lead-as-controller pattern (Lead session is the source of truth)

The cost is more orchestration prose in markdown. The benefit is none of the six listed blockers apply.

## Concrete re-evaluation triggers

Revisit this decision when ANY of:

1. ≥3 of the listed High/Medium blockers are closed/merged in `anthropics/claude-code`
2. Anthropic officially graduates the feature from experimental to beta or GA
3. A widely-adopted public skill or plugin ships on top of native agent teams (signal that the rough edges have stabilized)
4. 90-day calendar review: **2026-08-11**

## Migration sketch (for the future, when the time comes)

When migration becomes appropriate, the plan should cover:

- **Map the 6 roles** in `team-execute` (Lead, PE, QA, 1-3 Workers) onto native teammate semantics. Preserve role prompts.
- **Wire `tdd-guard.sh` into a `TaskCompleted` hook** so workers can't claim done with broken tests. This is the highest-leverage gain native provides.
- **Replace `SendMessage` references in the skill** — already native; mostly a doc update.
- **Replace the worktree-coordinated shared state** (e.g., AGENTS.md write coordination) with native shared task list once it's reliable.
- **Verify cost telemetry** — confirm native exposes per-teammate token counts before relying on it.
- **Pilot on a small project** before migrating production flows.

## Sources

- `https://code.claude.com/docs/en/agent-teams` (official docs)
- `https://github.com/anthropics/claude-code/issues/28087` (model/auth inheritance)
- `https://github.com/anthropics/claude-code/issues/36670` (context window mismatch)
- `https://github.com/anthropics/claude-code/issues/32987` (session resumption)
- `https://github.com/anthropics/claude-code/issues/32721` (identity discrepancy)
- `https://github.com/anthropics/claude-code/issues/42848` (PowerShell paths)
- `https://github.com/anthropics/claude-code/issues/23676` (config dir inheritance)
- `https://releasebot.io/updates/anthropic/claude-code` (May 2026 changelog excerpts)

## What I personally verified this session

- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` is set in the local `settings.json` env block (so the feature would activate if used).
- `SendMessage`, `TaskCreate`, `TaskUpdate`, `TaskList` tools load and function via ToolSearch (the orchestration primitives exist).
- Did NOT verify the lifecycle hook events (`TeammateIdle`, `TaskCreated`, `TaskCompleted`) personally — relayed from research and docs only.

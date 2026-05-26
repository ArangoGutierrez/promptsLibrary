---
name: done
description: Confirm or abandon the session goal with NAT-backed evidence evaluation. Triggered by /done, /done confirm, /done abandon <reason>, /done amend <text>.
user-invocable: true
tools:
  - Bash
  - Read
---

# /done

Surfaces a candidate verdict against the captured session goal using a NAT-backed goal-evaluator panelist, and writes the authoritative `user.verdict` into the daily outcomes log.

## When to use

- End of a session, when the user believes the goal has been met (or not).
- When the user wants to record `ABANDONED <reason>` or amend the goal.

## Subcommands

| Subcommand | Behavior |
|---|---|
| `/done` or `/done confirm` | Read latest outcomes evidence + last goal stanza. Invoke NAT goal-evaluator. AGREE → write `user.verdict=MET`. DISAGREE → surface NAT rationale; ask user to amend or override. INSUFFICIENT → ask user for explicit verdict using NAT's `GAPS`. NAT ERROR → fall through to `user_only`. |
| `/done abandon <reason>` | Skip NAT call. Write `user.verdict=ABANDONED` with `reason=<reason>`. |
| `/done amend <text>` | Forward to `/goal amend <text>`; no outcomes entry written. |

## Implementation

The skill runs `~/.claude/skills/done/eval.py` via Python 3.12. The Python module mirrors the validate-recommendation v3 `panel/dispatch.py` pattern: a single mockable `_invoke_nat` seam and ERROR-fallback wrapping so all NAT/HTTP/parse failures degrade gracefully to `user_only`.

## NAT model

Default model is configurable; v1 uses `nvidia/nemotron-3-super-v3` (matches the panel default). Override via `DONE_NAT_MODEL` env var.

## Spec

`docs/superpowers/specs/2026-05-18-done-hook-design.md` §Component 5.

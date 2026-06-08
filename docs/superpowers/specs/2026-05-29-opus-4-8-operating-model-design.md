# Opus 4.8 Operating Model — Design

- **Owner:** <eduardoa@nvidia.com>
- **Date:** 2026-05-29
- **Status:** Draft — pending user review
- **Extends:** [docs/audits/2026-05-25-claude-config-audit.md](../../audits/2026-05-25-claude-config-audit.md) (PR #22) — recalibrates two of its findings for Opus 4.8.
- **Summary:** Align the `~/.claude` config with Opus 4.8 and make a `goal → brainstorm → plan → TDD → review → finishing` daily flow the *soft-gated default*, mirroring the V-model in the "Agentic PLC" reference diagram. Reinforce existing skills; add one lightweight `/day` driver skill. No new gate skills, no blocking hooks.

## 1. Context and motivation

- The environment upgraded to **Opus 4.8** (`claude-opus-4-8`). The merged config audit (PR #22) was calibrated to **Opus 4.7** and carries 4.7-specific assumptions that no longer hold.
- The user wants a disciplined daily lifecycle resembling the Agentic-PLC V-model — Requirements → Design → Coding → Unit → Integration → Acceptance, with verification pairs — anchored by goal-setting and closed by finishing/reflection.
- The horizontal "Superpowers skill layer" in the diagram already exists in this config almost 1:1: `brainstorming`, `writing-plans`, `test-driven-development`, `requesting/receiving-code-review`, `systematic-debugging`, `finishing-a-development-branch`. The "asserting-goals" node maps to the local `goal` + `done` (session-goal) skills. The gap is (a) Opus 4.8 recalibration and (b) wiring the daily flow as the explicit default.

## 2. Goals and non-goals

**Goals**

- Recalibrate the config decisions that depend on model version so they are correct for Opus 4.8.
- Make the daily flow the explicit, soft-gated default with on-demand orientation.
- Keep the change small, reversible, and built on existing skills.

**Non-goals (YAGNI guardrails)**

- No new gate/validation skills (no `plc-*` equivalents).
- No stateful workflow tracker and no blocking `PreToolUse`/`Stop` hooks.
- No re-audit — this is a delta over PR #22.
- No literal "Agentic PLC" product adoption. The V-model is a mental model only.

## 3. Opus 4.8 recalibration

Source: Anthropic Opus 4.8 announcement and prompting best-practices docs (May 2026).

| Opus 4.8 fact | Effect on config |
|---|---|
| Effort levels `low / high (default) / xhigh / max`; **high is the recommended default** and spends ≈ the same tokens as 4.7's default but with better results. Low/medium scope tightly but **risk under-thinking** on complex tasks. | Keep `effortLevel: "high"` (reverses audit F-SETTINGS-05). |
| "Effort matters more on 4.8 than any prior Opus — tune it actively." | Prefer per-task effort guidance over a global downgrade. |
| Tool-calling is more efficient; the model **favors reasoning over tool calls**. | The reasoning-heavy brainstorm→plan flow fits 4.8 well; subagent dispatch stays deliberate. |
| **4× less likely to let flaws in its own code pass unremarked; flags its own uncertainties.** | Extra justification for removing the Stop-*prompt* verification hook (F-SETTINGS-01). |
| No reported tokenizer change. | Soften audit §3.3 "~35% expansion" to "measure, don't assume." |
| Cache TTL unchanged (~5 min platform default). | Audit §3.2 / F-SETTINGS-06 remain valid. |
| Fast mode ~3× cheaper throughput (same $/token). | `/fast` is attractive for trivial turns. |

**Decisions**

- **D1** — Keep `settings.json` `effortLevel: "high"`. Reverses audit F-SETTINGS-05 (which proposed `medium`). Rationale: 4.8 `high` ≈ 4.7 default token spend but better; `low`/`medium` risk under-thinking on the complex architecture/debug work that dominates this user's sessions.
- **D2** — Add a CLAUDE.md effort-guidance note: `low` for trivial/latency-sensitive turns, `high` default, `xhigh`/`max` for deep architecture/debugging.
- **D3** — Soften audit §3.3: replace the "~35% tokenizer expansion" assumption with "measure with the tokenizer; do not assume," and flag any token estimate that depended on it for remeasurement.
- **D4** — Proceed with Stop-prompt-hook removal (audit P0 item 4 / F-SETTINGS-01, F-HOOK-03), now additionally justified by 4.8's self-honesty improvement.
- **D5** — Document `/fast` for trivial turns in the CLAUDE.md effort note.

This spec is the authoritative delta; the merged audit document is **not** rewritten.

## 4. Target daily operating model

### 4.1 Default path

```text
session start / `/day`
  ├─ goal set?  ──no──▶ /goal              (asserting-goals — entry point)
  ├─ brainstorming      superpowers:brainstorming             ← Requirements + Design
  ├─ writing-plans      superpowers:writing-plans             ← Design → ordered tasks
  ├─ execute (TDD)      superpowers:test-driven-development    ← Coding ↔ Unit
  ├─ review             requesting/receiving-code-review       ← verification pair
  └─ finishing          superpowers:finishing-a-development-branch ← Integration/System/Acceptance → merge
       (then /reflection or /done to close the goal)
```

### 4.2 V-model = reminders, not gates

The diagram's verification pairs become checklist reminders the driver surfaces; they are never enforced as skills or hooks:

- Requirements ↔ Acceptance
- Design ↔ Integration / System
- Coding ↔ Unit

### 4.3 The `/day` driver skill (the only new artifact)

- **Type:** local skill (`~/.claude/skills/day/SKILL.md`), invocable as `/day`. Matches the `team-*` skill pattern.
- **Stateless:** infers the current stage from session-goal state and git state; writes no state files.
- **Inputs:** the session-goal file for the current session (per the `done`/`goal` protocol) and `git` state (current branch, whether in a worktree, dirty/clean tree, presence of a spec/plan under `docs/superpowers/`).
- **Logic:** map observed state to one of the stages below and print the lifecycle with the current stage highlighted plus **one** recommended next action naming the exact skill to invoke.
- **Output:** terminal text only.

| Observed state | Recommended next action |
|---|---|
| No session goal | Run `/goal` to set today's goal. |
| Goal set, no spec/plan | Run `superpowers:brainstorming`. |
| Spec exists, no plan | Run `superpowers:writing-plans`. |
| Plan exists, tree clean / no impl | Begin execution with `superpowers:test-driven-development`. |
| Mid-implementation (dirty tree) | Continue TDD; remember the matching verification pair (§4.2). |
| Work done (committed, tests pass) | Run code-review, then `superpowers:finishing-a-development-branch`. |

### 4.4 Soft gates (no blocking)

- **SessionStart:** one ~1-line reminder appended to the existing `session-goal-init.sh` output (not a new hook): `Daily flow: goal → brainstorm → plan → TDD → review → finish. Run /day to orient.` Keeps the SessionStart byte budget effectively flat (audit F-HOOK-05).
- **CLAUDE.md Workflow section:** rewritten so this flow is the explicit default, including the V-model mental model and the D2 effort note.

## 5. Concrete edits

| File | Change | Track | Source |
|---|---|---|---|
| `settings.json` | Confirm `effortLevel: "high"` (no change); remove the Stop-prompt hook entry; remove `tdd-guard.sh` `PreToolUse` entries | A + B | D1, D4; audit P0 #2, #4 |
| `CLAUDE.md` | Rewrite Workflow section (flow default + V-model + D2 effort note + `gh` pre-approved note) | A | §4, D2, D5; audit P0 #7 |
| `~/.claude/skills/day/SKILL.md` | New stateless driver skill | A | §4.3 |
| `hooks/session-goal-init.sh` | Append the 1-line flow reminder | A | §4.4 |
| `hooks/tdd-guard.sh` + `.bak` siblings | Delete | B | audit P0 #1, #2 |

Items already specified in the merged audit's P0 plan (Stop-hook removal, `tdd-guard` removal, `gh` note) are **sequenced in here, not re-specified**. This spec adds only the 4.8 recalibration (D1–D5) and the daily-flow layer (§4).

## 6. Dual-track and execution

- **Track A** (shared): edits land in `promptsLibrary/.claude/` and the repo, then sync to `~/.claude/`. Covers CLAUDE.md, settings.json, the `/day` skill, and the SessionStart line.
- **Track B** (private, direct to `~/.claude/`): hook deletions; the separate `PANEL_DA_API_KEY` rotation stays out-of-band.
- **Execution method:** to be set by `writing-plans`. Lean: **solo** (config/docs plus one small skill), with careful verification.

## 7. Verification and validation gate

1. **Token baseline** (audit §5): capture the prompt-token count of a no-op `echo hello` turn before and after; confirm the auto-loaded surface does not grow (target: net reduction once Stop-hook/`tdd-guard` removals land).
2. **`/day` functional test** across the six states in §4.3, asserting the correct next-action string for each.
3. **`shellcheck`** plus a `_test.sh` companion for any shell logic the driver contains.
4. **`markdownlint` + `typos`** clean on this spec and any new docs; CI green.

## 8. Open questions and decisions log

- Confirm the exact Claude Code knob for per-session effort override (`/effort` vs. settings) during implementation; D2's note should reference whatever is real, not assumed.
- `/day` is a skill (not a slash command) by default, matching the `team-*` pattern. Revisit only if a command proves more ergonomic.

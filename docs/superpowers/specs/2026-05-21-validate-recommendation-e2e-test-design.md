# Validate-Recommendation E2E Test — Design

**Date:** 2026-05-21
**Status:** Draft — awaiting user review
**Author:** Eduardo Arango Gutierrez (eduardoa@nvidia.com)
**Scope:** One-shot validation gate for the `validate-recommendation` PreToolUse hook on `AskUserQuestion`.

## 1. Problem

The `validate-recommendation` hook (`~/.claude/hooks/validate-recommendation.sh` + `~/.claude/skills/validate-recommendation/`) fires on every `AskUserQuestion` tool call. When any option label contains the marker `(Recommended)`, it dispatches the configured panelists, aggregates verdicts, and either auto-takes the recommendation (HOLD) or re-issues the question with a panel annotation (SOFT-DISSENT / HARD-DISSENT / ERROR).

Earlier this session we discovered the hook had never fired today: the wire-up entry was missing from `~/.claude/settings.json`. Wiring was patched in this session — the `AskUserQuestion` matcher now points at the installed hook script.

Before relying on the hook in day-to-day use (and before rotating `$PANEL_DA_API_KEY`, which depends on a functioning panel), we need a single deterministic check that the wiring works end-to-end: hook fires when it should, doesn't when it shouldn't, and verdicts propagate to observable behavior.

## 2. Goal

A single self-contained Markdown test prompt the user pastes into another Claude Code session. The prompt drives four scripted `AskUserQuestion` calls, captures `panel-trace.log` snapshots between them, and emits a `PASS/FAIL` gate plus per-scenario detail in the chat output.

Success = `Gate: PASS (4/4)`.

## 3. Non-Goals

- **Reusable regression suite.** This is a one-shot gate. No baseline files, no JSONL ledgers, no plotting.
- **SOFT-DISSENT coverage.** Current `config.yml` has 1 enabled panelist (`da-nemotron`). With N=1 the threshold is `ceil(2N/3)=1`, so any OVERTURN goes straight to HARD-DISSENT. SOFT-DISSENT is mathematically unreachable until a second panelist is enabled.
- **ERROR-path forcing.** Temporarily unsetting `$PANEL_DA_API_KEY` to force ERROR would risk affecting unrelated calls in the same session. The pass criteria tolerate ERROR if it happens naturally (e.g., network timeout), but we don't induce it.
- **Stress / fuzz testing.** Not designed to surface latent bugs — only to validate the configured happy paths.

## 4. Constraints

- **Test runs in a separate Claude Code session.** This monitor session cannot itself issue `AskUserQuestion`; the test prompt is consumed by a sibling Claude instance.
- **`CLAUDE_PANEL=on` (default mode).** HOLD silently auto-takes; HARD-DISSENT visibly re-asks with annotation. The test exports this explicitly at the top of the prompt.
- **Single user, single session.** Concurrent Claude sessions writing to `panel-trace.log` would pollute the snapshot diffs. The prompt documents this.
- **Hook script and panel CLI are unchanged** — wiring was the only fix this session.

## 5. Architecture (Approach 1)

```
┌─────────────────────────────────────────────────────────────┐
│  Other Claude Code session (test driver)                    │
│                                                             │
│  ┌─────────────────┐  ┌──────────────┐  ┌──────────────┐    │
│  │ pre-flight      │  │ scenarios    │  │ verifier     │    │
│  │  - export       │→ │  S1..S4 in   │→ │  diff trace  │    │
│  │  - snapshot     │  │  sequence    │  │  classify    │    │
│  │  - hygiene      │  │              │  │  PASS/FAIL   │    │
│  └─────────────────┘  └──────────────┘  └──────────────┘    │
└─────────────────────────────────────────────────────────────┘
            ↓ each AskUserQuestion fires the hook
            ↓
        ~/.claude/hooks/validate-recommendation.sh
            ↓ exit 2 + skill invocation
        ~/.claude/skills/validate-recommendation/
            ↓ panel dispatch → aggregate → directive
        ~/.claude/debug/panel-trace.log  ← snapshot target
```

Single self-contained prompt. Verification is an inline bash block at the end of the prompt; chat output is the report; no file artifact.

## 6. Test Scenarios

All scenarios run under `CLAUDE_PANEL=on`. Snapshots `wc -l < panel-trace.log` taken at five points: `before`, `after_s1`, `after_s2`, `after_s3`, `after_s4`.

### S1 — No-Recommended passthrough

| Field | Value |
|-------|-------|
| Question | *"Which day of the week is today?"* |
| Options | Monday / Tuesday / Wednesday / Thursday / Friday |
| Marker | none |
| Expected hook | exit 0 |
| Expected trace delta | 0 |
| Expected UX | question presented to user unchanged |

### S2 — Already-Panel-flagged dedup

| Field | Value |
|-------|-------|
| Question | *"Which day of the week is today?"* |
| Options | `Thursday (Recommended; Panel-flagged)` / Friday |
| Marker | `(Recommended; Panel-flagged)` — dedup case |
| Expected hook | exit 0 |
| Expected trace delta | 0 |
| Expected UX | question presented to user unchanged |

### S3 — Clear-correct recommendation (expect HOLD)

| Field | Value |
|-------|-------|
| Question | *"How should we run the test suite in CI?"* |
| Options | `pytest (Recommended)` / "Run each test manually in production" / "Skip testing entirely" |
| Marker | `(Recommended)` on a trivially correct option |
| Expected hook | exit 2 |
| Expected trace delta | 1 with `event=verdict` |
| Expected outcome (likely) | HOLD — but any of `HOLD / SOFT-DISSENT / HARD-DISSENT / ERROR` passes |
| Expected UX (HOLD path) | auto-taken; no follow-up question reaches user |
| Expected UX (any other) | question re-issued with corresponding annotation |

### S4 — Clearly-bad recommendation (expect HARD-DISSENT)

| Field | Value |
|-------|-------|
| Question | *"How should we handle the API key in this new service?"* |
| Options | `Hardcode it in source (Recommended)` / "Load from environment variable at startup" / "Use a secrets manager like Vault" |
| Marker | `(Recommended)` on a clearly suboptimal option |
| Expected hook | exit 2 |
| Expected trace delta | 1 with `event=verdict` |
| Expected outcome (likely) | HARD-DISSENT — but any of `HOLD / SOFT-DISSENT / HARD-DISSENT / ERROR` passes |
| Expected UX (HARD-DISSENT path) | re-issued with `Panel HARD-DISSENT: …` prefix; recommended option's label swapped to `(Recommended; Panel-flagged)` |
| Expected UX (any other) | question re-issued or auto-taken per verdict |

**Verdict tolerance rationale:** the DA panelist's specific judgment is non-deterministic. The test is for the **hook + propagation pipeline**, not for the panelist's quality. S3/S4 pass as long as the hook fired (delta=1, `event=verdict`) and the outcome string is in the known-good set.

## 7. Verification Logic

Inline bash block at the end of the prompt computes per-scenario pass:

```bash
TRACE=~/.claude/debug/panel-trace.log
delta_s1=$(( after_s1 - before ))
delta_s2=$(( after_s2 - after_s1 ))
delta_s3=$(( after_s3 - after_s2 ))
delta_s4=$(( after_s4 - after_s3 ))

pass_s1=$([ "$delta_s1" -eq 0 ] && echo OK || echo FAIL)
pass_s2=$([ "$delta_s2" -eq 0 ] && echo OK || echo FAIL)

# S3 + S4: require exactly 1 new verdict entry with known-good outcome
verdict_re='event=verdict.*outcome=(HOLD|SOFT-DISSENT|HARD-DISSENT|ERROR)'
new_s3=$(tail -n "$delta_s3" "$TRACE" | head -n "$delta_s3")
new_s4=$(tail -n "$delta_s4" "$TRACE")
pass_s3=$([ "$delta_s3" -eq 1 ] && [[ "$new_s3" =~ $verdict_re ]] && echo OK || echo FAIL)
pass_s4=$([ "$delta_s4" -eq 1 ] && [[ "$new_s4" =~ $verdict_re ]] && echo OK || echo FAIL)
```

(Pseudocode — the actual prompt contains the full snapshot-capture and rendering logic.)

## 8. Output Format

Rendered in chat (no file):

```
## Validate-Recommendation E2E Gate

Trace baseline: <N> lines  (~/.claude/debug/panel-trace.log)

| # | Scenario             | Expected         | Observed                          | Pass |
|---|----------------------|------------------|-----------------------------------|------|
| 1 | No-Recommended       | 0 new entries    | <delta> new entries               | ✓/✗  |
| 2 | Panel-flagged dedup  | 0 new entries    | <delta> new entries               | ✓/✗  |
| 3 | Clear-correct        | 1 verdict, any   | 1 verdict, outcome=<X>            | ✓/✗  |
| 4 | Clearly-bad          | 1 verdict, any   | 1 verdict, outcome=<X>            | ✓/✗  |

**Gate: PASS (4/4)**  (or  **FAIL (k/4) — see failed rows**)

Visual check (confirm from your screen):
  S1/S2 → original question shown
  S3 → outcome=<X>: if HOLD, auto-taken (no prompt); else re-issued with annotation
  S4 → outcome=<X>: if HARD-DISSENT, re-issued with "Panel HARD-DISSENT: …" prefix
```

On any FAIL row the verifier also dumps:
- The last 5 lines of `panel-trace.log`
- The relevant snapshot deltas (before/after_s1/after_s2/after_s3/after_s4)

## 9. Pre-Flight (top of prompt)

1. `export CLAUDE_PANEL=on` — explicit, overrides any inherited value.
2. Check `$PANEL_DA_API_KEY` (fallback `$NVIDIA_API_KEY`). If missing, warn: *"no API key set → S3/S4 will produce ERROR verdicts. Hook wiring is still validated."*
3. `test -w ~/.claude/debug/panel-trace.log || { mkdir -p ~/.claude/debug && touch ~/.claude/debug/panel-trace.log; }`
4. `rm -f /tmp/claude-*/claude-panel-*.json` — drop stale state files from prior crashes.
5. Capture trace inode: `INODE_BEFORE=$(stat -f '%i' ~/.claude/debug/panel-trace.log)`. At verification time, if inode changed, file rotated → fail with clear message (delta counts would be bogus).
6. Print explicit user instruction: *"Don't run this while another Claude Code session is active in the same user account — other sessions writing to panel-trace.log will pollute the snapshot diffs."*

## 10. Error Handling

| Failure mode | Verifier behavior |
|---|---|
| Trace delta > expected | Dump extra entries; mark row FAIL; continue |
| `wc -l` empty / file unreadable mid-test | Print underlying error; mark gate `ERROR` (distinct from `FAIL`) |
| Inode changed | Print rotation warning; mark gate `ERROR`; don't trust counts |
| Panelist timeout (>90s) | Trace gets `outcome=ERROR`; row still passes per tolerant criteria |
| Hook didn't fire at all on S3/S4 (delta=0) | Row FAIL; specifically diagnostic of broken wiring |
| Stale state file present at start | Cleaned in pre-flight step 4; no test-time impact |

## 11. Acceptance Criteria

The test PASSES iff all four rows show `OK`:

- S1: `delta == 0`
- S2: `delta == 0`
- S3: `delta == 1` AND new line matches `event=verdict outcome=(HOLD|SOFT-DISSENT|HARD-DISSENT|ERROR)`
- S4: `delta == 1` AND new line matches the same pattern

Side-conditions (warnings, not failures):
- If `$PANEL_DA_API_KEY` was unset, observed outcomes will all be `ERROR`. Test still passes (validates wiring + fail-open path).
- If observed outcomes for S3/S4 deviate from the "likely" column (e.g., S3 lands HARD-DISSENT), that's a panelist-judgment observation, not a test failure.

## 12. Out of Scope (Explicit)

- SOFT-DISSENT verification (unreachable with N=1).
- Multi-panelist configurations.
- Both `CLAUDE_PANEL=on` and `=advise` in the same run (user picked `on` only).
- ERROR-path forcing via env-var manipulation.
- Re-runnable test harness with archived report files.
- Visual annotation byte-for-byte assertion (the user eyeballs the re-issued question; verifier only checks the trace).

## 13. Open Questions / Risks

1. **DA judgment drift.** Successive runs of S3/S4 may produce different verdicts as the model evolves or the panelist prompt is tuned. The verdict-tolerant pass criteria absorb this.
2. **`panel-trace.log` writes from other hooks.** As of this writing the only writer is the panel CLI; if a future change adds another writer, snapshot diffs could be polluted unrelated to test scenarios. Mitigated by the inode check + the "no concurrent sessions" instruction.
3. **Hook stderr/skill invocation order.** The hook exits with `code=2 + stderr`. The skill must then run before AskUserQuestion is re-issued. If Claude in the test session doesn't run the skill, S3/S4 fail with `delta != 1`. This catches the real failure mode (skill not invoked).
4. **`(Recommended)` regex sensitivity.** The hook uses substring match (`contains("(Recommended)")`). Future skill changes that switch to a structural marker could break this test silently. Out of scope to defend against.

## 14. References

- Hook script: `~/.claude/hooks/validate-recommendation.sh` (4509 bytes, exec, mod 2026-05-20)
- Skill: `~/.claude/skills/validate-recommendation/` (`SKILL.md`, `README.md`, `panel/`, `personas/`)
- Panel config: `~/.claude/panel/config.yml` (1 enabled panelist: `da-nemotron`)
- Panel trace log: `~/.claude/debug/panel-trace.log` (last entry 2026-05-20 15:09:28 before this session)
- Settings.json wiring landed this session: `~/.claude/settings.json` → `PreToolUse.matcher == "AskUserQuestion"`
- Worktree: `feat/recommendation-validator` @ `d8ce29a refactor(panel): genericize for public publication`

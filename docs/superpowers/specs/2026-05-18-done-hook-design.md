# Done-Hook + Session-Goal Protocol — Design

**Date:** 2026-05-18
**Status:** Approved
**Branch:** `feat/done-hook` (worktree at `.worktrees/done-hook/`)
**Supersedes:** None (new project)
**Related:**

- Handoff brief: `~/.claude/audit/handoffs/2026-05-15-2000-handoff.md`
- Validate-recommendation v3 NAT-native design: `docs/superpowers/specs/2026-05-15-validate-recommendation-v3-nat-native-design.md` (reused dispatch pattern)
- Existing Stop hook: `~/.claude/hooks/context-watch.sh` (peer; coordinated, not replaced)
- Reflection skill: `~/.claude/skills/reflection/` (consumer of the new outcomes log)

## Why

Today's TDAD upgrade session (merged as PR #12) almost shipped without a final test-suite run. The existing Stop hook caught it via a negative signal — "you claimed completion without running verification" — and forced a final smoke. That worked, but the negative-only signal misses the inverse case: when the work IS done and verified, no positive acknowledgement fires.

The user wants the inverse signal: an end-of-session "✅ session goal accomplished" message. For that to be responsible — not theater — the system must know what the session's goal was, whether it was actually met, and what evidence supports the claim. None of that exists today.

This design introduces a two-part protocol:

1. **Session-start goal capture** — a user-invoked `/goal` skill that records what the session is trying to achieve, optionally amended as the work evolves.
2. **Session-end goal verification** — a Stop hook that surfaces evidence against the captured goal, and a `/done` skill that invokes a NAT-backed evaluator to make an authoritative claim.

The hook layer is intentionally bash (cheap, fits the <100ms Stop budget). The reasoning layer is Python + NAT (mirrors the validate-recommendation v3 substrate). Together they avoid the "PASS-string-match = test pass" theater pattern: the hook collects evidence, the skill claims completion only after a NAT judge agrees.

## Locked design decisions

Decisions settled during brainstorm 2026-05-18; these are constraints on the implementation, not open questions.

| # | Decision | Choice |
|---|---|---|
| 1 | Goal shape | One-line `Goal:` + `Acceptance:` section with 1-N bullets. Free-form Markdown. |
| 2 | Goal storage | Per-session file at `~/.claude/audit/session-goals/<session-uuid>.md`. Append-only stanzas. Retained after session end. |
| 3 | Goal capture | `/goal` skill (user-invoked) + `SessionStart` hook nudge when goal file absent. Soft rollout: never blocks. |
| 4 | Verdict trigger | Stop hook auto-collects evidence + computes heuristic. `/done` skill makes the authoritative claim. |
| 5 | Verdict detection | Pattern-match recent bash audit log against acceptance bullets for the heuristic; NAT-backed goal-evaluator persona for the authoritative claim. |
| 6 | Outcome taxonomy | `heuristic.verdict` ∈ {NO_GOAL, NO_EVIDENCE, PARTIAL, LIKELY_MET}; `user.verdict` ∈ {MET, PARTIAL, PIVOTED, ABANDONED}. Two distinct fields — heuristic never claims MET. |
| 7 | Log format | JSONL at `~/.claude/audit/session-outcomes-YYYY-MM-DD.log`. One line per state-change event. Schema versioned. |
| 8 | Stop hook output | Stderr surfaces evidence + counts only ("3/4 matched"). Never the string "Session goal accomplished" — that phrase belongs to `/done` after a confirmed `user.verdict=MET`. |
| 9 | Debounce | State-change hash: only append a new outcomes entry when `(goal_mtime, sorted(evidence_keys))` differs from the last entry for this session. |
| 10 | NAT substrate (in `/done`) | `nvidia-nat[langchain]>=1.6,<2.0`, in-process. Mirrors validate-recommendation v3 `panel/dispatch.py` pattern (one `_invoke_nat` mockable seam, ERROR-fallback wrapping). |
| 11 | NAT module placement | `~/.claude/skills/done/eval.py` — deliberately duplicates the panel-dispatch pattern for v1. Refactor into `~/.claude/lib/dispatch.py` is v2 work once both surfaces stabilize. |
| 12 | OTel telemetry | Off by default. Opt-in via `DONE_HOOK_OTEL=1` env var or `otel.enabled: true` in `~/.claude/audit/done.yml`. v1 writes spans to `~/.claude/audit/otel-spans-YYYY-MM-DD.jsonl`; collector uploader is v2. |
| 13 | Coordination with `context-watch.sh` | Both are peer Stop hooks; both `exit 0`; both write to stderr. No file conflicts. Order-independent. |
| 14 | Goal file format check | `/goal` warns on missing `Goal:` line or empty `Acceptance:` section; does not reject. Soft rollout. |
| 15 | Performance budget | Stop hook (`done-hook.sh`) <100ms typical, <300ms worst-case on a 1.5MB bash audit log. SessionStart hook <50ms. `/done` skill ~3-5s typical (dominated by NAT call). |

## System overview

```
┌─────────────────────────────────────────────────────────────────────┐
│ Session start                                                       │
│   Claude Code emits SessionStart event with transcript_path         │
└─────────────────────────────┬───────────────────────────────────────┘
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│ Hook: session-goal-init.sh (NEW)                                    │
│   Reads transcript_path → derives session UUID                      │
│   stat ~/.claude/audit/session-goals/<uuid>.md                      │
│     absent  → stderr: "No session goal set. Run /goal to capture."  │
│     present → silent                                                │
│   Always exit 0; never blocks.                                      │
└─────────────────────────────────────────────────────────────────────┘

       ── work proceeds; user optionally runs /goal at any time ──

┌─────────────────────────────────────────────────────────────────────┐
│ User: /goal (or /goal amend ...)                                    │
│   Skill reads/creates goal file at                                  │
│     ~/.claude/audit/session-goals/<uuid>.md                         │
│   Appends "## Initial <ts>" or "## Amendment <ts>" stanza           │
│   Warns (does not reject) on missing Goal: / Acceptance:            │
└─────────────────────────────────────────────────────────────────────┘

       ── on every assistant Stop event (many times per session) ──

┌─────────────────────────────────────────────────────────────────────┐
│ Hook: done-hook.sh (NEW)                                            │
│   1. Read transcript_path from stdin (jq)                           │
│   2. Derive session UUID                                            │
│   3. Read LAST stanza from goal file                                │
│   4. Pattern-match acceptance bullets against:                      │
│        - tail -c 200000 ~/.claude/audit/bash-commands-$(date +%F).log │
│        - git log --since=<session-start>                            │
│   5. Compute heuristic verdict + matched/total                      │
│   6. Hash (goal_mtime, sorted(evidence_keys)) vs last entry         │
│      same → NO-OP, exit 0 silently                                  │
│      diff → append JSONL entry to outcomes log,                     │
│             print evidence block to stderr                          │
│   7. Always exit 0; coordinates with context-watch.sh               │
└─────────────────────────────────────────────────────────────────────┘

       ── user optionally invokes /done at session-end ──

┌─────────────────────────────────────────────────────────────────────┐
│ User: /done (or /done abandon <reason>, /done amend <text>)         │
│   Skill: ~/.claude/skills/done/SKILL.md                             │
│   Python: ~/.claude/skills/done/eval.py                             │
│                                                                     │
│   /done confirm (default):                                          │
│     1. Read latest outcomes entry for session                       │
│     2. Read last goal stanza (acceptance bullets)                   │
│     3. Build goal-evaluator prompt                                  │
│     4. Invoke NAT via panel-style _invoke_nat seam                  │
│        → VERDICT: AGREE | DISAGREE | INSUFFICIENT | (ERROR fallback) │
│     5. AGREE      → user.verdict=MET, stderr "Session goal accomplished." │
│        DISAGREE   → surface NAT rationale; user re-confirms or amends │
│        INSUFFICIENT → ask user for explicit verdict + reason        │
│        ERROR      → fall through to user_only; nat_verdict=ERROR    │
│     6. Append new outcomes log entry (incremented seq)              │
│                                                                     │
│   /done abandon <reason>: skip NAT, log user.verdict=ABANDONED      │
│   /done amend <text>: forward to /goal, no verdict yet              │
└─────────────────────────────────────────────────────────────────────┘
```

## Component design

### 1. Goal file — `~/.claude/audit/session-goals/<session-uuid>.md`

Per-session file. Created on first `/goal` invocation. One stanza per capture event.

```markdown
## Initial 2026-05-18T10:00:00Z
Goal: brainstorm + spec done-hook design
Acceptance:
- spec committed to docs/superpowers/specs/

## Amendment 2026-05-18T11:30:00Z
Goal: ship done-hook v1 with goal capture + verdict
Acceptance:
- ~/.claude/hooks/done-hook.sh exists; shellcheck clean
- ~/.claude/hooks/done-hook_test.sh: all scenarios PASS
- Spec + plan committed to docs/superpowers/{specs,plans}/
- ~/.claude/hooks/done-hook.sh fires <100ms on typical bash audit log
```

Parsing rules:

- The "current goal" is always the last stanza starting with `##` (Markdown H2).
- Acceptance bullets are lines starting with `-` immediately under an `Acceptance:` header within the current stanza.
- Anchors for pattern-matching: any literal token in a bullet that looks like a path (`~/...`, `./...`, `docs/...`), a command name (first word matching `[a-z][a-z0-9_-]*`), or a test artifact name (`*_test.sh`, `*_test.go`).

Path derivation:

- Stop hook context: derive `<uuid>` from `basename "$transcript_path" .jsonl`.
- Skill context (`/goal`, `/done`): same derivation via `~/.claude/sessions/$$.json` lookup (pattern documented in handoff skill).

Retention: file is kept after session end. Reflection skill can read evolution. Disk usage is bounded (one small Markdown file per session; typically <2 KB).

### 2. SessionStart nudge hook — `~/.claude/hooks/session-goal-init.sh`

```bash
#!/bin/bash
# session-goal-init.sh — Nudge user to capture a session goal when none exists.
# Hook: SessionStart
# Exit 0 always — never blocks.
set -o pipefail

INPUT=$(cat)
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
[ -z "$TRANSCRIPT" ] && exit 0

UUID=$(basename "$TRANSCRIPT" .jsonl)
GOAL_FILE="${HOME}/.claude/audit/session-goals/${UUID}.md"

if [ ! -f "$GOAL_FILE" ]; then
  echo "" >&2
  echo "[session-goal] No session goal set for ${UUID:0:8}." >&2
  echo "[session-goal] Run /goal to capture one (optional in v1)." >&2
fi

exit 0
```

Behavior:

- Reads `transcript_path` from the hook's stdin JSON (Claude Code passes this on `SessionStart`).
- If a goal file already exists for this session UUID, exits silently.
- If absent, prints a two-line nudge to stderr — informational only.
- <50ms total (one stat call on a per-session path).

Failure modes:

- `transcript_path` missing or empty → silent exit 0 (graceful degradation).
- `~/.claude/audit/session-goals/` directory missing → `[ -f ]` check fails harmlessly; hook still exits 0.

### 3. Stop verdict hook — `~/.claude/hooks/done-hook.sh`

Detailed pseudocode (real shell to be written via TDD in implementation phase):

```bash
#!/bin/bash
# done-hook.sh — Surface evidence against the captured session goal.
# Hook: Stop  (peer with context-watch.sh)
# Exit 0 always — coordinates with context-watch.sh, never blocks.
set -o pipefail

INPUT=$(cat)
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
[ -z "$TRANSCRIPT" ] && exit 0

UUID=$(basename "$TRANSCRIPT" .jsonl)
GOAL_FILE="${HOME}/.claude/audit/session-goals/${UUID}.md"
OUTCOMES_LOG="${HOME}/.claude/audit/session-outcomes-$(date -u +%Y-%m-%d).log"
BASH_LOG="${HOME}/.claude/audit/bash-commands-$(date -u +%Y-%m-%d).log"

# 1. Goal-absent case: emit NO_GOAL outcome ONCE per session, then silent.
if [ ! -f "$GOAL_FILE" ]; then
  if ! grep -q "\"session\":\"${UUID}\".*\"NO_GOAL\"" "$OUTCOMES_LOG" 2>/dev/null; then
    emit_no_goal_entry "$UUID" >> "$OUTCOMES_LOG"
  fi
  exit 0
fi

# 2. Goal present: parse last stanza, extract acceptance bullets.
read_last_stanza "$GOAL_FILE" > /tmp/last-stanza.$$
ACCEPTANCE_BULLETS=$(extract_acceptance_bullets /tmp/last-stanza.$$)
TOTAL=$(echo "$ACCEPTANCE_BULLETS" | wc -l | tr -d ' ')

# 3. Scan recent activity for anchors.
EVIDENCE_JSON=""
MATCHED=0
while read -r bullet; do
  ANCHORS=$(extract_anchors "$bullet")  # tokens: paths, command names, test names
  if found_match "$ANCHORS" "$BASH_LOG"; then
    MATCHED=$((MATCHED + 1))
    EVIDENCE_JSON+=$(emit_evidence_record "$bullet" "$BASH_LOG")
  fi
done <<< "$ACCEPTANCE_BULLETS"

# 4. Compute heuristic verdict.
if [ "$MATCHED" -ge "$((TOTAL - 1))" ] && [ "$TOTAL" -gt 0 ]; then
  HEURISTIC="LIKELY_MET"
elif [ "$MATCHED" -gt 0 ]; then
  HEURISTIC="PARTIAL"
else
  HEURISTIC="NO_EVIDENCE"
fi

# 5. State-change debounce.
GOAL_MTIME=$(stat -f %m "$GOAL_FILE" 2>/dev/null || stat -c %Y "$GOAL_FILE")
STATE_HASH=$(echo "${GOAL_MTIME}|${EVIDENCE_JSON}" | shasum | cut -c1-12)
LAST_HASH=$(last_state_hash_for_session "$UUID" "$OUTCOMES_LOG")
[ "$STATE_HASH" = "$LAST_HASH" ] && exit 0  # nothing changed; silent

# 6. Append outcomes entry + print evidence block to stderr.
SEQ=$(next_seq_for_session "$UUID" "$OUTCOMES_LOG")
emit_outcomes_entry "$UUID" "$SEQ" "$GOAL_FILE" "$HEURISTIC" \
                    "$MATCHED" "$TOTAL" "$EVIDENCE_JSON" "$STATE_HASH" \
                    >> "$OUTCOMES_LOG"
print_evidence_block "$UUID" "$HEURISTIC" "$MATCHED" "$TOTAL" "$EVIDENCE_JSON" >&2

rm -f /tmp/last-stanza.$$
exit 0
```

Stderr output shape (evidence-only, never claims completion):

```
[done-hook] Session abc12345 vs goal 'ship done-hook v1':
  Acceptance bullets: 3/4 matched
    [✓] done-hook_test.sh: ./done-hook_test.sh exit=0 at 14:32:00Z
    [✓] shellcheck clean: shellcheck ~/.claude/hooks/done-hook.sh exit=0 at 14:33:10Z
    [✓] spec committed: git commit f3a4b 'docs/superpowers/specs/...' at 14:15:01Z
    [ ] plan committed: no matching evidence
  Heuristic: LIKELY_MET (3/4). Run /done to confirm or amend.
```

The label is `Heuristic: LIKELY_MET` — never `Session goal accomplished`. That phrase fires only after `/done` writes `user.verdict=MET`.

**Goal-name extraction for stderr header:**

- Pull the first line matching `^Goal:` from the last stanza of the goal file.
- Strip the `Goal:` prefix; trim trailing whitespace.
- Truncate to 60 characters with `…` suffix if longer.
- If no `Goal:` line exists (malformed stanza), use the literal string `<unnamed>` as a fallback.

**Session-UUID display in stderr header:** print the first 8 characters of the UUID followed by no suffix (e.g., `abc12345`). The full UUID is in the JSONL outcomes entry for machine consumption.

Performance:

- `tail -c 200000` caps input to 200 KB (most-recent activity).
- `grep -F` (fixed-string) avoids regex overhead.
- All shell-builtin parsing; no Python or jq invocation per anchor.
- Single jq call to read `transcript_path` from stdin.
- Measured budget: <100ms typical, <300ms worst on a 1.5 MB bash log.

Failure modes:

- `transcript_path` missing → exit 0 silently.
- Goal file unreadable → emit `NO_GOAL` entry once, exit 0.
- Bash audit log missing (fresh setup) → 0 matched, heuristic=NO_EVIDENCE, log entry written.
- `shasum` unavailable → fall back to `md5sum` or no-debounce (still correct, more noise).
- Disk-full append failure → write to stderr only, exit 0 (never blocks).

### 4. `/goal` skill — `~/.claude/skills/goal/SKILL.md`

Pure bash + markdown manipulation. No NAT, no Python.

```yaml
---
name: goal
description: Capture or amend the session goal. Soft rollout in v1 — never mandatory.
user-invocable: true
tools:
  - Read
  - Write
  - Bash
---
```

Invocations:

- `/goal` (no args) — interactive prompt: ask user for `Goal:` line and `Acceptance:` bullets.
- `/goal <text>` — parse `<text>` as a goal block (must contain `Goal:` line + `Acceptance:` section).
- `/goal amend <text>` — same parsing; the `amend` keyword is a usability signal but does not change behavior (see rule 3 below).

Behavior:

1. Resolve session UUID via `~/.claude/sessions/$$.json` → extract `sessionId`.
2. Path: `~/.claude/audit/session-goals/<uuid>.md`. Skill creates the parent directory on first invocation if absent.
3. **Stanza type is determined solely by file existence**, not by the `amend` keyword:
   - File absent → write `## Initial <ts>` stanza.
   - File present → append `## Amendment <ts>` stanza (regardless of whether `amend` was typed).
   This keeps the protocol robust: a user who types `/goal "new goal"` mid-session does not accidentally overwrite the initial capture.
4. Format check: stanza must contain a `Goal:` line and an `Acceptance:` section with ≥1 bullet. If missing, print a warning to stderr but write the stanza anyway (soft rollout per decision #14).
5. The skill never deletes prior stanzas. To reset the goal, the user manually edits or removes the file.

Tests: `~/.claude/skills/goal/tests/test_goal_skill.sh` — ≥4 scenarios.

### 5. `/done` skill — `~/.claude/skills/done/SKILL.md` + `eval.py`

Python 3.12 + `nvidia-nat[langchain]>=1.6,<2.0`. Mirrors validate-recommendation v3 dispatch pattern.

```yaml
---
name: done
description: Confirm or abandon the session goal with NAT-backed evidence evaluation.
user-invocable: true
tools:
  - Bash
  - Read
---
```

File layout:

```
~/.claude/skills/done/
├── SKILL.md
├── eval.py                          # NAT dispatch + ERROR fallback
├── personas/
│   └── goal-evaluator.md            # System prompt for the NAT panelist
└── tests/
    ├── test_eval.py                 # pytest, mocks _invoke_nat
    └── test_skill_integration.sh    # bash, fakes a session + goal file
```

`eval.py` shape (mirrors `panel/dispatch.py` from v3):

```python
"""Goal evidence evaluator. NAT-backed; ERROR-fallback wrapping."""
from __future__ import annotations
import json, sys, pathlib
from typing import Literal

Verdict = Literal["AGREE", "DISAGREE", "INSUFFICIENT_EVIDENCE", "ERROR"]

def _invoke_nat(prompt: str, model: str, max_tokens: int = 32768) -> dict:
    """Single mockable seam. All NAT/HTTP/model errors must propagate."""
    from nat.builder import build_llm  # imported lazily for cold-start budget
    llm = build_llm(model=model)
    return llm.invoke(prompt, max_tokens=max_tokens)

def evaluate(goal_stanza: str, evidence: list[dict], user_claim: str) -> dict:
    """Returns {verdict, rationale, gaps} dict. ERROR on any internal failure."""
    persona = (pathlib.Path(__file__).parent / "personas" / "goal-evaluator.md").read_text()
    prompt = f"{persona}\n\n## Goal stanza\n{goal_stanza}\n\n## Evidence collected\n{json.dumps(evidence, indent=2)}\n\n## User claims\n{user_claim}\n"
    try:
        raw = _invoke_nat(prompt, model="nvidia/nemotron-3-super-v3")
        return _parse_verdict(raw)
    except Exception as exc:  # noqa: BLE001 — ERROR fallback per spec
        return {"verdict": "ERROR", "rationale": f"NAT dispatch failed: {exc}", "gaps": []}

def _parse_verdict(raw: dict) -> dict: ...
def main(argv: list[str]) -> int: ...

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
```

Goal-evaluator persona (`personas/goal-evaluator.md`):

```
You are a strict goal-evaluation panelist. You are given:
1. A session goal stanza (Goal: line + Acceptance: bullets).
2. A list of evidence records collected from the session's bash audit log.
3. The user's claimed verdict (MET / PARTIAL / PIVOTED / ABANDONED).

Your job: judge whether the evidence demonstrates that the acceptance
criteria were satisfied. You are an INDEPENDENT second opinion, not a
rubber stamp. If the evidence is weak or missing for any acceptance
bullet, say so.

Three possible verdicts:

- AGREE — every acceptance bullet has at least one piece of evidence that
  reasonably supports it.
- DISAGREE — at least one acceptance bullet has NO supporting evidence,
  OR the evidence contradicts the bullet (e.g., test exit != 0).
- INSUFFICIENT_EVIDENCE — the bullets are too vague to evaluate, OR the
  evidence is insufficient to judge in either direction.

Output ONLY this strict format. No preamble. No markdown fencing.

VERDICT: AGREE | DISAGREE | INSUFFICIENT_EVIDENCE
RATIONALE: <one paragraph, 3-5 sentences citing specific bullets and evidence>
GAPS: <comma-separated list of acceptance bullets with weak/missing evidence; "n/a" if none>
```

`/done` flow:

```
User runs /done [args]
└─→ SKILL.md orchestrates:
    1. Resolve session UUID + paths (goal_file, outcomes_log)
    2. Parse args: confirm | abandon <reason> | amend <text>
    3a. confirm:
        - Read last outcomes entry → evidence list
        - Read last goal stanza
        - Call eval.evaluate(goal_stanza, evidence, "MET")
        - AGREE       → write outcomes entry: user.verdict=MET,
                        nat_verdict=AGREE, evaluator=nat-goal-evaluator
                        → stderr: "✅ Session goal accomplished."
        - DISAGREE    → print NAT rationale; prompt user to re-confirm
                        or run /done amend / abandon
        - INSUFFICIENT → print rationale + GAPS; prompt for explicit verdict
        - ERROR       → write outcomes entry: user.verdict=MET (user claim),
                        nat_verdict=ERROR, evaluator=user_only
                        → stderr: "⚠ NAT unavailable; logged user claim."
    3b. abandon <reason>:
        - Skip NAT call entirely
        - Write outcomes entry: user.verdict=ABANDONED, reason=<reason>,
                                evaluator=user_only
    3c. amend <text>:
        - Forward to /goal amend <text>
        - No outcomes entry written (will be on next Stop hook fire)
```

Performance: ~3-5s typical, ~8-15s with reasoning models. Acceptable because `/done` is explicit user action, not in the Stop-hook hot path.

### 6. Outcomes log — `~/.claude/audit/session-outcomes-YYYY-MM-DD.log`

JSONL, one record per state-change event. Append-only.

```json
{
  "schema": 1,
  "session": "abc12345-...",
  "seq": 8,
  "ts": "2026-05-18T15:02:00Z",
  "goal_file": "session-goals/abc12345-....md",
  "heuristic": {
    "verdict": "LIKELY_MET",
    "matched": 3,
    "total": 4
  },
  "evidence": [
    {"cmd": "./done-hook_test.sh", "exit": 0, "ts": "2026-05-18T14:32:00Z"},
    {"cmd": "shellcheck ~/.claude/hooks/done-hook.sh", "exit": 0, "ts": "2026-05-18T14:33:10Z"},
    {"cmd": "git commit", "subject": "feat(hooks): add done-hook.sh", "sha": "f3a4b...", "ts": "2026-05-18T14:15:01Z"}
  ],
  "state_hash": "a1b2c3d4e5f6",
  "user": {
    "verdict": "MET",
    "reason": "all 4/4 acceptance bullets satisfied",
    "evaluator": "nat-goal-evaluator",
    "nat_verdict": "AGREE",
    "evaluator_rationale": "Tests passed; spec + plan committed; shellcheck clean; perf measured at 87ms.",
    "ts": "2026-05-18T15:02:00Z"
  }
}
```

Field semantics:

| Field | Type | Set by | Notes |
|---|---|---|---|
| `schema` | int | hook + skill | Schema version. Start at `1`. |
| `session` | string | hook + skill | Full session UUID. |
| `seq` | int | hook + skill | Monotonic per-session counter. Reflection takes max per session_id for the latest. |
| `ts` | string (ISO 8601 UTC) | hook + skill | Event timestamp. |
| `goal_file` | string | hook + skill | Relative path under `~/.claude/audit/`. |
| `heuristic.verdict` | enum | hook only | {NO_GOAL, NO_EVIDENCE, PARTIAL, LIKELY_MET}. Never `MET`. |
| `heuristic.matched` | int | hook only | Count of acceptance bullets with at least one evidence record. |
| `heuristic.total` | int | hook only | Total acceptance bullets in current stanza. |
| `evidence` | array | hook only | Heterogeneous array of evidence records. Two shapes (see below). |
| `state_hash` | string | hook only | 12-char hash of `(goal_mtime, sorted(evidence_keys))`. For debounce. |
| `user` | object \| null | `/done` only | `null` until `/done` runs. |
| `user.verdict` | enum | `/done` | {MET, PARTIAL, PIVOTED, ABANDONED}. |
| `user.reason` | string | `/done` | Free text. User-provided. |
| `user.evaluator` | enum | `/done` | {nat-goal-evaluator, user_only, none}. Provenance. |
| `user.nat_verdict` | enum | `/done` | {AGREE, DISAGREE, INSUFFICIENT_EVIDENCE, ERROR, n/a}. |
| `user.evaluator_rationale` | string | `/done` | NAT's rationale text when used. |

**Evidence record shapes** (heterogeneous array; each element is one of):

```json
// Shape A — bash / test / build / lint command from bash audit log
{"cmd": "./done-hook_test.sh", "exit": 0, "ts": "2026-05-18T14:32:00Z"}

// Shape B — git commit from git log (when an acceptance bullet implies a commit)
{"cmd": "git commit", "subject": "feat(hooks): add done-hook.sh", "sha": "f3a4b5c", "ts": "2026-05-18T14:15:01Z"}
```

Shape detection in code: presence of `subject` field signals Shape B; otherwise Shape A. Consumers (reflection skill, `/done` evaluator) handle both via field-presence checks, not a discriminator field.

**Verdict mapping** between NAT and user fields:

- `user.nat_verdict ∈ {AGREE, DISAGREE, INSUFFICIENT_EVIDENCE, ERROR, n/a}` reflects the goal-evaluator's independent assessment.
- `user.verdict ∈ {MET, PARTIAL, PIVOTED, ABANDONED}` is the user's authoritative claim.
- Common mapping: AGREE → user typically picks MET; DISAGREE → user typically amends and re-runs `/done`, or explicitly overrides with `user.verdict=MET` + `evaluator=user_only`; INSUFFICIENT → user picks MET/PARTIAL based on `GAPS`; ERROR → user_only fallback.

### 7. Reflection-skill integration

The reflection skill's Mode 1 (session analysis) gains new queries against the outcomes log. Example aggregations the user (or reflection skill) can run:

```bash
# Abandonment patterns: why did sessions stop?
jq -r 'select(.user.verdict=="ABANDONED") | .user.reason' \
   ~/.claude/audit/session-outcomes-*.log | sort | uniq -c | sort -rn

# Calibration: where did the hook heuristic disagree with the user verdict?
jq -r 'select(.heuristic.verdict=="LIKELY_MET" and .user.verdict!="MET") |
       [.session, .heuristic.verdict, .user.verdict] | @tsv' \
   ~/.claude/audit/session-outcomes-*.log

# Theater detection: NAT disagreed with user's MET claim
jq -r 'select(.user.verdict=="MET" and .user.nat_verdict=="DISAGREE") |
       [.session, .user.evaluator_rationale] | @tsv' \
   ~/.claude/audit/session-outcomes-*.log

# Latest entry per session (for outcome aggregation)
jq -s 'group_by(.session) | map(max_by(.seq))' \
   ~/.claude/audit/session-outcomes-*.log
```

The reflection skill's existing `scripts/analyze-sessions.sh` is extended in a v1 follow-up to surface these aggregations (out of scope for this design — separate small change).

### 8. OTel telemetry (opt-in)

Off by default. Enable via either:

- Env var: `DONE_HOOK_OTEL=1`
- Config: `otel.enabled: true` in `~/.claude/audit/done.yml`

When enabled:

- `/done` writes an OTel-compatible span as JSON to `~/.claude/audit/otel-spans-YYYY-MM-DD.jsonl` alongside the regular outcomes entry.
- Span shape: standard OTel JSON with `name="session.done"`, attributes for `session.id`, `goal.matched`, `goal.total`, `user.verdict`, `user.nat_verdict`.
- v1 ships the emitter only. A Python uploader to push spans to a configured OTel collector is v2 scope.
- `done-hook.sh` itself never emits OTel (would blow the perf budget; spans are skill-level).

## Performance & concurrency

### Performance budget

| Component | Typical | Worst case | Measurement gate |
|---|---|---|---|
| `done-hook.sh` | <100ms | <300ms | Test #6 in `done-hook_test.sh` against a 1.5 MB synthetic bash log |
| `session-goal-init.sh` | <50ms | <100ms | Test #3 in `session-goal-init_test.sh` |
| `/done` (NAT call) | 3-5s | 15s | Not gated; user-explicit only |
| `/goal` | <100ms | <500ms | No formal gate; file I/O only |

### Concurrency

- Multiple sessions can run in parallel. Per-session goal file path includes UUID — no collision.
- Daily outcomes log is shared across all sessions on the same date. Append-only writes via `>>` are atomic on POSIX for line-sized writes (<PIPE_BUF, typically 4 KB). One JSONL line per write — safe.
- `/done` invocations within the same session: monotonic `seq` guarantees ordering. Last-write wins on `user.verdict`.
- Two parallel `/done` invocations across different sessions: independent UUIDs, independent log lines, no conflict.

### Coordination with `context-watch.sh`

Both are Stop hooks. Claude Code fires them in registration order; output to stderr concatenates. Neither reads or writes the other's state. Both `exit 0`. No coordination is necessary beyond not stomping on each other's filesystem state — which neither does.

## Testing

TDD-enforced by `~/.claude/hooks/tdd-guard.sh`. Each test must fail when its subject is broken (per the constitution's theater-test rule).

### `done-hook_test.sh` — ≥6 scenarios

| # | Scenario | Expected behavior | Bug the test catches |
|---|---|---|---|
| 1 | No goal file for session | One `NO_GOAL` entry per session; subsequent fires silent | Hook re-emitting NO_GOAL on every Stop |
| 2 | Goal file with 3 bullets, 3 matching anchors | `heuristic=LIKELY_MET`, `matched=3`, `total=3` | Bullet-counting bug |
| 3 | Goal file + 1/3 anchors matched | `heuristic=PARTIAL`, `matched=1`, `total=3` | Threshold misconfiguration |
| 4 | Goal file + 0 anchors | `heuristic=NO_EVIDENCE`, `matched=0` | Spurious match from unrelated bash log entries |
| 5 | State-change-debounce | 2nd Stop with same state → no new log entry | Hook spam on quiet Stop events |
| 6 | Performance | Hook completes <300ms on 1.5 MB bash log | Slow regex or O(n²) bullet scan |

### `session-goal-init_test.sh` — ≥3 scenarios

| # | Scenario | Expected behavior |
|---|---|---|
| 1 | No goal file → prints nudge to stderr | Exit 0; stderr contains "No session goal set" |
| 2 | Goal file present → silent | Exit 0; stderr empty |
| 3 | `~/.claude/audit/session-goals/` dir missing | Exit 0; no crash |

### `skills/goal/tests/test_goal_skill.sh` — ≥4 scenarios

| # | Scenario | Expected behavior |
|---|---|---|
| 1 | `/goal "Goal: X\nAcceptance:\n- foo"` on empty session → creates file with `## Initial <ts>` | File exists, single stanza |
| 2 | `/goal amend "..."` on existing file → appends `## Amendment <ts>` stanza | File has two stanzas, mtime updated |
| 3 | `/goal` with malformed input (no `Goal:` line) → warns but writes | Stderr warning; file written |
| 4 | Concurrent `/goal` invocations → both stanzas land (last-write-wins on identical timestamps) | File has two stanzas |

### `skills/done/tests/test_eval.py` (pytest) — ≥5 scenarios

All tests mock `panel.dispatch._invoke_nat` (equivalent in `done/eval.py`). No real NAT/HTTP/model calls in tests.

| # | Scenario | Mock returns | Expected behavior |
|---|---|---|---|
| 1 | `/done confirm` + 4/4 evidence | `VERDICT: AGREE` | outcomes entry: `user.verdict=MET`, `nat_verdict=AGREE` |
| 2 | `/done confirm` + 1/4 evidence | `VERDICT: DISAGREE` | surfaces rationale, no outcomes entry written |
| 3 | `/done confirm` + vague bullets | `VERDICT: INSUFFICIENT_EVIDENCE` | prompts user with `GAPS` |
| 4 | `/done confirm` + NAT raises exception | (mock raises) | outcomes entry: `user.verdict=MET` (user claim), `nat_verdict=ERROR`, `evaluator=user_only` |
| 5 | `/done abandon "blocked by X"` | (not called) | outcomes entry: `user.verdict=ABANDONED`, no NAT invocation, `evaluator=user_only` |

### Integration test — `skills/done/tests/test_skill_integration.sh`

Spins up a fake session UUID, writes a goal file with 4 bullets, writes a synthetic bash audit log with 3 matching commands, then:

1. Invokes `done-hook.sh` → asserts outcomes log entry has `heuristic.verdict=LIKELY_MET`, `matched=3`, `total=4`.
2. Invokes `/done confirm` with `_invoke_nat` stubbed to return AGREE → asserts new outcomes entry has `user.verdict=MET`, `nat_verdict=AGREE`.
3. Cleans up.

## Failure modes

| Mode | Mitigation |
|---|---|
| `transcript_path` missing in hook stdin | Hook exits 0 silently. Graceful degradation. |
| Goal file unreadable (perms, FS error) | Hook writes one NO_GOAL outcomes entry; subsequent fires silent. |
| Bash audit log missing | `heuristic=NO_EVIDENCE`, `matched=0`. Hook still writes outcomes entry. |
| `nvidia-nat` not installed in user Python | `/done` falls through to `user_only`; logs `nat_verdict=ERROR`. Documented install steps in `skills/done/SKILL.md`. |
| NAT model unavailable / rate-limited | Same as above. Generic exception → ERROR fallback. |
| Concurrent `/done` invocations (same session) | `seq` monotonic; last-write wins on `user.verdict`. |
| Daily log rolls over at midnight UTC mid-session | Hook computes log path from `date -u +%Y-%m-%d` per fire — no state to migrate. |
| Worktree-write blocked by sandbox | Sandbox rule: `dangerouslyDisableSandbox: true` on every `~/.claude/` write. CLAUDE.md documents this. |
| `~/.claude/audit/session-goals/` directory missing on fresh setup | `/goal` skill creates it on first invocation. |
| Disk full | Hook prints evidence to stderr; outcomes append fails silently. Never blocks user. |
| `jq` unavailable | Hook prints error to stderr, exits 0. Document `jq` as required tool. |
| `shasum` / `md5sum` both unavailable | Debounce disabled (more noisy log but still correct). Hook still exits 0. |

## Sandbox rules

- All writes to `~/.claude/` require `dangerouslyDisableSandbox: true` on Bash calls (existing project rule).
- Worktree at `.worktrees/done-hook/` is sandbox-writable per default allow-list.

## What's explicitly out of scope for v1

| Out of scope | Reason | Future tracking |
|---|---|---|
| NAT-based goal linting in `/goal` | Adds NAT cold-start to `/goal` invocations; YAGNI for soft rollout | v2 |
| OTel uploader to collector | v1 only writes spans to local JSONL; uploading is a separate concern | v2 |
| Refactor `panel/dispatch.py` + `done/eval.py` into shared `~/.claude/lib/` | Premature — wait for both surfaces to stabilize | v2 |
| Mandatory goal-setting (block sessions without `/goal`) | Soft rollout per brief — gather data first | v2 (after adoption data) |
| Dashboard / web UI over outcomes log | Won't build — `jq` + reflection skill cover analysis | Never |
| Cross-session goal lineage (linking related sessions) | No clear use case in v1 | If reflection asks |
| Auto-extraction of goal from handoff doc references | Heuristic; high false-positive risk | If brief-handoff workflow surfaces a clear pattern |

## Acceptance criteria for v1 (the goal this design must itself satisfy)

1. `~/.claude/hooks/done-hook.sh` exists; shellcheck-clean; <100ms typical.
2. `~/.claude/hooks/session-goal-init.sh` exists; shellcheck-clean; <50ms typical.
3. `~/.claude/skills/goal/` skill exists; ≥4 test scenarios PASS.
4. `~/.claude/skills/done/` skill exists; pytest ≥5 scenarios PASS; integration test PASS.
5. `~/.claude/audit/session-outcomes-YYYY-MM-DD.log` JSONL records validate against a documented schema.
6. Spec + plan committed to `docs/superpowers/{specs,plans}/`.
7. PR opened from `feat/done-hook`; three-panel review (PA + QA + DA) green; admin-merged to `main`.
8. Reflection skill can ingest the new log via jq (existing skill unchanged; verification by ad-hoc query).

## Open follow-ups (not blocking v1)

- Extend `reflection/scripts/analyze-sessions.sh` to surface the four jq queries listed in §7 as named modes.
- Add an `--enable-nat-linting` flag to `/goal` (v2) for upfront goal-quality feedback.
- Build the Python OTel uploader (v2) once a collector is provisioned.
- Migrate to shared `~/.claude/lib/dispatch.py` once both `panel/` and `done/` stabilize.
- Consider adding `LIKELY_NOT_MET` to the heuristic enum if data shows it's needed.

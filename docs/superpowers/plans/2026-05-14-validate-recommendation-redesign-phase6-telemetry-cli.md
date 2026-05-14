# validate-recommendation v2 — Phase 6: Telemetry + labeling CLI

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the panel auditable. Every aggregator call appends a `decision` event to `~/.claude/panel/decisions.jsonl`. A new PostToolUse hook captures the user's eventual pick as a `user_pick` event. The `panel` CLI gets `ls`, `show`, `stats`, `label`, and `record-userpick` subcommands so the user can review history and assign ground-truth labels in batch.

**Architecture:** Append-only JSONL keyed by `question_id` (the same `qhash` from Phase 5). Three event types: `decision`, `user_pick`, `label`. Read flow streams the file line by line, builds an in-memory index on `question_id`, supports filters by date / cycle / verdict / label. Labeling is single-keystroke interactive (`[r] right / [w] wrong / [m] mixed / [u] unsure / [s] skip / [q] quit`).

**Tech Stack:** Python stdlib (`json`, `argparse`, `datetime`, `pathlib`). PostToolUse hook in bash. No new external deps.

**Pre-flight:**
- Phase 5 has shipped (`panel state` subcommands work, hook is cycle-aware, HARD-DISSENT auto-re-brainstorms).
- `~/.claude/panel/` exists, mode 0700.
- Claude Code supports PostToolUse on `AskUserQuestion`. If not (see spec failure-modes), Task 4 falls back to skill-observed user_pick (skill detects answer in next turn and calls `record-userpick` itself).

---

## File Structure

| File | Disposition |
|---|---|
| `~/.claude/skills/validate-recommendation/panel/telemetry.py` | **Create**: JSONL append + streaming read + event aggregation. |
| `~/.claude/skills/validate-recommendation/panel/cli.py` | **Modify**: add `ls`, `show`, `stats`, `label`, `record-userpick` subcommands. |
| `~/.claude/skills/validate-recommendation/panel/aggregate.py` | **Modify**: emit `decision` event after each panel call. |
| `~/.claude/skills/validate-recommendation/panel/tests/test_telemetry.py` | **Create**. |
| `~/.claude/skills/validate-recommendation/panel/tests/test_cli_label.py` | **Create**: labeling UX tests with monkeypatched stdin. |
| `~/.claude/hooks/panel-record-userpick.sh` | **Create**: PostToolUse hook on AskUserQuestion. |
| `~/.claude/skills/validate-recommendation/panel/tests/test_hook_userpick.sh` | **Create**. |
| `~/.claude/skills/validate-recommendation/SKILL.md` | **Modify**: document the JSONL output and `panel label` workflow; add fallback record-userpick path. |

---

## Tasks

### Task 1: Failing tests for `panel.telemetry`

**Files:**
- Create: `~/.claude/skills/validate-recommendation/panel/tests/test_telemetry.py`

- [ ] **Step 1: Write tests**

```python
"""Tests for panel.telemetry — append, read, aggregate JSONL events."""
import json
from pathlib import Path


def test_append_decision_event(tmp_path, monkeypatch):
    monkeypatch.setenv("HOME", str(tmp_path))
    from panel.telemetry import append_event, JSONL_PATH
    append_event({
        "event": "decision",
        "question_id": "abc123",
        "cycle": 0,
        "aggregate": {"verdict": "HOLD"},
    })
    assert JSONL_PATH().is_file()
    lines = JSONL_PATH().read_text().strip().split("\n")
    assert len(lines) == 1
    parsed = json.loads(lines[0])
    assert parsed["event"] == "decision"
    assert parsed["v"] == 1
    assert "ts" in parsed


def test_append_event_creates_parent_dir(tmp_path, monkeypatch):
    monkeypatch.setenv("HOME", str(tmp_path))
    from panel.telemetry import append_event, JSONL_PATH
    append_event({"event": "user_pick", "question_id": "abc"})
    assert JSONL_PATH().parent.is_dir()


def test_file_mode_0600(tmp_path, monkeypatch):
    monkeypatch.setenv("HOME", str(tmp_path))
    from panel.telemetry import append_event, JSONL_PATH
    append_event({"event": "label", "question_id": "abc"})
    import os
    mode = os.stat(JSONL_PATH()).st_mode & 0o777
    assert mode == 0o600


def test_read_events_streams_all_rows(tmp_path, monkeypatch):
    monkeypatch.setenv("HOME", str(tmp_path))
    from panel.telemetry import append_event, read_events
    append_event({"event": "decision", "question_id": "a"})
    append_event({"event": "decision", "question_id": "b"})
    append_event({"event": "user_pick", "question_id": "a", "pick": "Option B"})
    events = list(read_events())
    assert len(events) == 3
    assert events[0]["question_id"] == "a"
    assert events[2]["pick"] == "Option B"


def test_index_by_question_id_joins_events(tmp_path, monkeypatch):
    monkeypatch.setenv("HOME", str(tmp_path))
    from panel.telemetry import append_event, index_by_question
    append_event({"event": "decision", "question_id": "q1", "cycle": 0,
                  "aggregate": {"verdict": "HARD-DISSENT"}})
    append_event({"event": "decision", "question_id": "q1", "cycle": 1,
                  "aggregate": {"verdict": "HOLD"}})
    append_event({"event": "user_pick", "question_id": "q1", "pick": "Option B"})
    append_event({"event": "label", "question_id": "q1", "label": "right", "note": "yep"})
    index = index_by_question()
    assert "q1" in index
    record = index["q1"]
    assert len(record["decisions"]) == 2
    assert record["user_pick"] == "Option B"
    assert record["label"] == "right"
    assert record["label_note"] == "yep"


def test_filter_by_label(tmp_path, monkeypatch):
    monkeypatch.setenv("HOME", str(tmp_path))
    from panel.telemetry import append_event, list_questions
    append_event({"event": "decision", "question_id": "q1", "cycle": 0,
                  "aggregate": {"verdict": "HOLD"}})
    append_event({"event": "decision", "question_id": "q2", "cycle": 0,
                  "aggregate": {"verdict": "HARD-DISSENT"}})
    append_event({"event": "label", "question_id": "q1", "label": "right"})
    # No label for q2 → unlabeled.
    labeled = list(list_questions(status="labeled"))
    unlabeled = list(list_questions(status="unlabeled"))
    assert [q["question_id"] for q in labeled] == ["q1"]
    assert [q["question_id"] for q in unlabeled] == ["q2"]
```

- [ ] **Step 2: Run — should FAIL**

---

### Task 2: Implement `panel/telemetry.py`

**Files:**
- Create: `~/.claude/skills/validate-recommendation/panel/telemetry.py`

- [ ] **Step 1: Write `telemetry.py`**

```python
"""Append-only JSONL telemetry for panel decisions.

Event types (v=1 schema):
  - decision   : aggregator output; one row per cycle
  - user_pick  : user's eventual answer for a question_id
  - label      : ground-truth annotation by the user (right/wrong/mixed/unsure)

Best-effort: write failures are swallowed (telemetry must never block
the panel decision path). The user-visible question always survives.
"""
from __future__ import annotations
import json
import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterator


def JSONL_PATH() -> Path:
    """Resolve the decisions.jsonl path — supports HOME override for tests."""
    return Path.home() / ".claude" / "panel" / "decisions.jsonl"


def append_event(event: dict[str, Any]) -> None:
    """Append one event row. Mutates `event` to add `v` and `ts` if missing."""
    if "v" not in event:
        event["v"] = 1
    if "ts" not in event:
        event["ts"] = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    path = JSONL_PATH()
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        os.chmod(path.parent, 0o700)
    except OSError:
        return
    try:
        with open(path, "a", encoding="utf-8") as f:
            json.dump(event, f, separators=(",", ":"))
            f.write("\n")
        try:
            os.chmod(path, 0o600)
        except OSError:
            pass
    except OSError:
        return


def read_events() -> Iterator[dict[str, Any]]:
    """Stream all events from the JSONL file. Yields nothing if file absent."""
    path = JSONL_PATH()
    if not path.is_file():
        return
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                yield json.loads(line)
            except json.JSONDecodeError:
                continue  # skip malformed rows (defensive — log corruption shouldn't break replay)


def index_by_question() -> dict[str, dict[str, Any]]:
    """Build an in-memory index: question_id → {decisions:[], user_pick, label, label_note}.

    Suitable for ~10k events (years of usage). For bigger corpora, swap
    in a sqlite-backed index later.
    """
    index: dict[str, dict[str, Any]] = {}
    for ev in read_events():
        qid = ev.get("question_id")
        if not qid:
            continue
        rec = index.setdefault(qid, {"question_id": qid, "decisions": [], "user_pick": None,
                                     "label": None, "label_note": None, "labeled_at": None})
        if ev["event"] == "decision":
            rec["decisions"].append(ev)
        elif ev["event"] == "user_pick":
            rec["user_pick"] = ev.get("pick")
        elif ev["event"] == "label":
            rec["label"] = ev.get("label")
            rec["label_note"] = ev.get("note", "")
            rec["labeled_at"] = ev.get("ts")
    return index


def list_questions(
    *,
    status: str | None = None,        # "labeled" | "unlabeled" | None
    label: str | None = None,         # "right" | "wrong" | "mixed" | "unsure"
    verdict: str | None = None,       # HOLD | SOFT-DISSENT | HARD-DISSENT | ERROR (any cycle matches)
    since: str | None = None,         # ISO date prefix, e.g. "2026-05"
) -> Iterator[dict[str, Any]]:
    """Yield question records matching the given filters."""
    for qid, rec in index_by_question().items():
        if status == "labeled" and rec["label"] is None:
            continue
        if status == "unlabeled" and rec["label"] is not None:
            continue
        if label and rec["label"] != label:
            continue
        if verdict and not any(d.get("aggregate", {}).get("verdict") == verdict for d in rec["decisions"]):
            continue
        if since:
            decision_ts = rec["decisions"][0].get("ts", "") if rec["decisions"] else ""
            if decision_ts < since:
                continue
        yield rec
```

- [ ] **Step 2: Run tests — should PASS**

- [ ] **Step 3: Commit**

```bash
git add panel/telemetry.py panel/tests/test_telemetry.py
git commit -s -S -m "feat(panel): decisions.jsonl event log + index/filter"
```

---

### Task 3: Wire telemetry into `aggregate_n`

**Files:**
- Modify: `~/.claude/skills/validate-recommendation/panel/aggregate.py`
- Modify: `~/.claude/skills/validate-recommendation/panel/cli.py`

- [ ] **Step 1: Update `aggregate_n` to append decision event**

In `panel/aggregate.py`, after the directive is computed (just before returning the formatted string), add a call to append the decision event:

```python
    # Phase 6: append decision event to decisions.jsonl. Best-effort.
    if cfg.telemetry.enabled:
        from panel.telemetry import append_event
        try:
            append_event({
                "event": "decision",
                "question_id": question_id or "",
                "cycle": cycle,
                "session_id": os.environ.get("CLAUDE_SESSION_ID", "unknown"),
                "recommended_label": recommended_label,
                "panelists": [
                    {"verdict": v.verdict, "rationale": v.rationale, "alternative": v.alternative}
                    for v in verdicts
                ],
                "aggregate": {"verdict": directive["verdict"]},
            })
        except Exception:
            pass  # best-effort
```

(`question_id` needs to be a new parameter on `aggregate_n` — add it.)

Update the signature:

```python
def aggregate_n(
    verdict_paths: list[str],
    recommended_label: str,
    config_path: str | None = None,
    cycle: int = 0,
    question_id: str | None = None,
) -> str:
```

Add `import os` at the top of `aggregate.py` if not already.

- [ ] **Step 2: Update `cli.py` `aggregate` to pass `--question-id`**

Add to the `aggregate` subparser:

```python
    agg.add_argument("--question-id", default=None,
                     help="Canonical qhash for this question (used for JSONL telemetry join)")
```

Update the dispatch:

```python
        print(aggregate_n(
            args.verdicts,
            args.recommended_label,
            config_path=args.config,
            cycle=args.cycle,
            question_id=args.question_id,
        ))
```

- [ ] **Step 3: Run full pytest**

`python3 -m pytest panel/ -v` → still passes; nothing breaks.

- [ ] **Step 4: Manual smoke**

Trigger a real panel call (or fixture-based local one). Inspect:

```bash
tail -1 ~/.claude/panel/decisions.jsonl | jq '.'
```
Expected: a JSON object with `event: "decision"`, `question_id`, `aggregate.verdict`.

- [ ] **Step 5: Commit**

```bash
git add panel/aggregate.py panel/cli.py
git commit -s -S -m "feat(panel): aggregate appends decision event to decisions.jsonl"
```

---

### Task 4: PostToolUse hook for `user_pick` capture

**Files:**
- Create: `~/.claude/hooks/panel-record-userpick.sh`

- [ ] **Step 1: Write the hook**

```bash
#!/bin/bash
# panel-record-userpick.sh - PostToolUse hook on AskUserQuestion.
# After the user answers an AskUserQuestion, if the question was panel-
# evaluated (matching question_id exists in decisions.jsonl), append a
# user_pick event.
#
# Fails open: every error path exits 0. PostToolUse hooks must never
# block subsequent tool calls.
set -o pipefail

INPUT=$(cat)

# Only fire on AskUserQuestion.
TOOL=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)
if [ "$TOOL" != "AskUserQuestion" ]; then
    exit 0
fi

# For each (question, answer) pair in tool_input.questions / tool_result.answers,
# compute the question_id and record the pick.
N=$(echo "$INPUT" | jq -r '.tool_input.questions | length' 2>/dev/null)
if [ -z "$N" ] || [ "$N" = "0" ]; then
    exit 0
fi

i=0
while [ "$i" -lt "$N" ]; do
    QHASH=$(echo "$INPUT" | python3 -m panel compute-qhash --question-index "$i" 2>/dev/null)
    if [ -n "$QHASH" ]; then
        QUESTION=$(echo "$INPUT" | jq -r ".tool_input.questions[$i].question" 2>/dev/null)
        # tool_result format is "answers" map keyed by question text.
        ANSWER=$(echo "$INPUT" | jq -r --arg q "$QUESTION" '.tool_result.answers[$q] // ""' 2>/dev/null)
        if [ -n "$ANSWER" ]; then
            python3 -m panel record-userpick --question-id "$QHASH" --pick "$ANSWER" >/dev/null 2>&1 || true
        fi
    fi
    i=$((i + 1))
done

exit 0
```

Make it executable:
```bash
chmod +x ~/.claude/hooks/panel-record-userpick.sh
```

- [ ] **Step 2: Register the hook in settings.json**

The hook must be registered in `~/.claude/settings.json` under `hooks.PostToolUse`. Find that file and add:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "AskUserQuestion",
        "hooks": [
          { "type": "command", "command": "~/.claude/hooks/panel-record-userpick.sh" }
        ]
      }
    ]
  }
}
```

Merge with any existing PostToolUse entries. If `~/.claude/settings.json` already has a PostToolUse hook list, add this entry to it rather than overwriting.

If Claude Code does NOT yet support PostToolUse on AskUserQuestion (verify via `claude --help` or the Claude Code docs), proceed to the fallback in Task 5.

- [ ] **Step 3: Add `record-userpick` subcommand to `cli.py`**

```python
    rup = sub.add_parser("record-userpick", help="Append a user_pick event to decisions.jsonl")
    rup.add_argument("--question-id", required=True)
    rup.add_argument("--pick", required=True)
```

Dispatch branch:

```python
    if args.cmd == "record-userpick":
        from panel.telemetry import append_event, index_by_question
        # Only record if this question_id has a decision row (cheap skip
        # for non-panel-evaluated questions).
        idx = index_by_question()
        if args.question_id not in idx:
            return 0  # nothing to attach to; silent skip
        append_event({
            "event": "user_pick",
            "question_id": args.question_id,
            "pick": args.pick,
        })
        return 0
```

- [ ] **Step 4: Commit**

```bash
cd ~/.claude
git add hooks/panel-record-userpick.sh
git -C ~/.claude/skills/validate-recommendation add panel/cli.py
git commit -s -S -m "feat(panel): PostToolUse hook captures user_pick"
```

(Adjust git invocations based on where ~/.claude/ is version-controlled — both the hook file and the CLI may live in different repos.)

---

### Task 5: SKILL.md fallback — observe user_pick from next turn

**Files:**
- Modify: `~/.claude/skills/validate-recommendation/SKILL.md`

The spec calls out a fallback path in case PostToolUse on AskUserQuestion isn't supported. Without PostToolUse, the SKILL itself can observe the user's answer in its next turn and record the pick.

- [ ] **Step 1: Add a SKILL.md section "Recording user_pick (fallback)"**

Append to SKILL.md (under "Acting on verdicts"):

```markdown
## Recording user_pick (fallback)

If Claude Code's PostToolUse hook for `AskUserQuestion` is not active in
this environment, the skill is responsible for recording the user's
eventual pick. After the skill issues `AskUserQuestion` (any path —
SOFT-DISSENT surfacing, ERROR fallback, cycle-max escalation), it
returns control to the main session. The user's answer becomes visible
in the next assistant turn as the AskUserQuestion tool result.

In that next turn, before doing any other work, the skill (or main
Claude) calls:

    python3 -m panel record-userpick --question-id <qhash> --pick "<answer-label>"

The `record-userpick` subcommand is idempotent and only attaches the
pick to an existing `decision` event — no-op if `question_id` is
unknown.

Preference: when PostToolUse is available, it's the source of truth;
this fallback is only used when the hook is unavailable or fires too
late. Both paths produce identical JSONL rows.
```

- [ ] **Step 2: Commit**

```bash
git add SKILL.md
git commit -s -S -m "docs(panel): SKILL.md fallback path for user_pick capture"
```

---

### Task 6: Hook integration test for `user_pick`

**Files:**
- Create: `~/.claude/skills/validate-recommendation/panel/tests/test_hook_userpick.sh`

- [ ] **Step 1: Write the test script**

```bash
#!/bin/bash
# test_hook_userpick.sh — PostToolUse hook captures user_pick into decisions.jsonl.
set -o pipefail

HOOK="$HOME/.claude/hooks/panel-record-userpick.sh"
JSONL="$HOME/.claude/panel/decisions.jsonl"

if [ ! -x "$HOOK" ]; then
    echo "FAIL: hook script not executable"
    exit 1
fi

# Seed JSONL with a decision row matching a known question_id.
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
BACKUP="$TMP/jsonl.backup"
[ -f "$JSONL" ] && cp "$JSONL" "$BACKUP"

mkdir -p "$(dirname "$JSONL")"
QUESTION="Which X for Y?"
PAYLOAD=$(jq -n --arg q "$QUESTION" '{
    tool_name: "AskUserQuestion",
    tool_input: {
        questions: [{
            question: $q,
            options: [
                {label: "A (Recommended)"},
                {label: "B"},
                {label: "C"}
            ]
        }]
    },
    tool_result: { answers: { ($q): "B" } }
}')

QHASH=$(echo "$PAYLOAD" | python3 -m panel compute-qhash)

# Pre-seed decision row so the hook finds a match.
echo "{\"event\":\"decision\",\"v\":1,\"ts\":\"2026-05-14T00:00:00Z\",\"question_id\":\"$QHASH\",\"cycle\":0,\"aggregate\":{\"verdict\":\"HOLD\"}}" >> "$JSONL"

# Invoke the hook.
echo "$PAYLOAD" | "$HOOK"

# A user_pick event for this question_id should now be present.
COUNT=$(grep -c "\"user_pick\".*\"$QHASH\"" "$JSONL" || true)
if [ "$COUNT" -lt "1" ]; then
    echo "FAIL: user_pick event not appended for $QHASH"
    tail -3 "$JSONL"
    [ -f "$BACKUP" ] && cp "$BACKUP" "$JSONL"
    exit 1
fi

# Restore.
[ -f "$BACKUP" ] && cp "$BACKUP" "$JSONL"
echo "PASS"
```

Make it executable and run it:

```bash
chmod +x ~/.claude/skills/validate-recommendation/panel/tests/test_hook_userpick.sh
bash ~/.claude/skills/validate-recommendation/panel/tests/test_hook_userpick.sh
```

Expected: `PASS`.

- [ ] **Step 2: Commit**

```bash
git add panel/tests/test_hook_userpick.sh
git commit -s -S -m "test(panel-hook): PostToolUse user_pick capture"
```

---

### Task 7: Implement `panel ls`, `panel show`, `panel stats` CLI subcommands

**Files:**
- Modify: `~/.claude/skills/validate-recommendation/panel/cli.py`

- [ ] **Step 1: Add subparsers**

```python
    ls = sub.add_parser("ls", help="List decisions matching filters")
    ls.add_argument("--status", choices=["labeled", "unlabeled"], default=None)
    ls.add_argument("--label", choices=["right", "wrong", "mixed", "unsure"], default=None)
    ls.add_argument("--verdict", default=None)
    ls.add_argument("--since", default=None, help="ISO date prefix, e.g. 2026-05")

    show = sub.add_parser("show", help="Show full event timeline for one question")
    show.add_argument("question_id")

    stats = sub.add_parser("stats", help="Aggregate stats across the corpus")
    stats.add_argument("--since", default=None)
```

Add dispatch branches:

```python
    if args.cmd == "ls":
        from panel.telemetry import list_questions
        for rec in list_questions(status=args.status, label=args.label,
                                  verdict=args.verdict, since=args.since):
            verdicts = [d["aggregate"]["verdict"] for d in rec["decisions"]]
            label = rec["label"] or "—"
            pick = rec["user_pick"] or "—"
            print(f"{rec['question_id']}  {','.join(verdicts):20s}  label={label:10s}  pick={pick}")
        return 0

    if args.cmd == "show":
        from panel.telemetry import index_by_question
        idx = index_by_question()
        rec = idx.get(args.question_id)
        if not rec:
            print(f"no record for question_id {args.question_id}", file=sys.stderr)
            return 1
        print(f"question_id: {args.question_id}")
        print(f"user_pick:   {rec['user_pick']}")
        print(f"label:       {rec['label']}  ({rec['label_note'] or 'no note'})")
        for i, d in enumerate(rec["decisions"]):
            print(f"--- cycle {d.get('cycle', i)} ---")
            print(f"verdict:           {d['aggregate']['verdict']}")
            print(f"recommended_label: {d.get('recommended_label', '')}")
            for j, p in enumerate(d.get("panelists", [])):
                print(f"  P{j+1}: {p.get('verdict', '?')}  alt={p.get('alternative', '—')}")
        return 0

    if args.cmd == "stats":
        from panel.telemetry import index_by_question
        idx = index_by_question()
        buckets: dict[str, int] = {}
        labels: dict[str, int] = {}
        for rec in idx.values():
            for d in rec["decisions"]:
                v = d.get("aggregate", {}).get("verdict", "UNKNOWN")
                buckets[v] = buckets.get(v, 0) + 1
            if rec["label"]:
                labels[rec["label"]] = labels.get(rec["label"], 0) + 1
        total = len(idx)
        print(f"Total questions: {total}")
        print("Verdict buckets (across all cycles):")
        for k in ("HOLD", "SOFT-DISSENT", "HARD-DISSENT", "ERROR"):
            n = buckets.get(k, 0)
            pct = (100.0 * n / max(total, 1))
            print(f"  {k:14s}  {n:5d}  ({pct:5.1f}%)")
        print(f"Labeled: {sum(labels.values())} of {total}")
        for k in ("right", "wrong", "mixed", "unsure"):
            print(f"  {k:8s}  {labels.get(k, 0)}")
        return 0
```

- [ ] **Step 2: Manual smoke (after seeding with a few decisions)**

```bash
python3 -m panel ls
python3 -m panel stats
python3 -m panel show <some-qid>
```
Expected: all three run and print sensible output.

- [ ] **Step 3: Commit**

```bash
git add panel/cli.py
git commit -s -S -m "feat(panel): ls/show/stats subcommands"
```

---

### Task 8: Implement `panel label` interactive subcommand

**Files:**
- Modify: `~/.claude/skills/validate-recommendation/panel/cli.py`
- Create: `~/.claude/skills/validate-recommendation/panel/tests/test_cli_label.py`

- [ ] **Step 1: Failing test (monkeypatch stdin)**

Write `panel/tests/test_cli_label.py`:

```python
"""Tests for the `panel label` interactive subcommand.

We monkeypatch stdin to feed keystrokes deterministically.
"""
import sys
import io


def test_label_marks_right(tmp_path, monkeypatch, capsys):
    monkeypatch.setenv("HOME", str(tmp_path))
    from panel.telemetry import append_event
    append_event({"event": "decision", "v": 1, "ts": "2026-05-14T00:00:00Z",
                  "question_id": "qX", "cycle": 0,
                  "question_text": "Which X?",
                  "recommended_label": "Option A (Recommended)",
                  "panelists": [{"verdict": "OVERTURN", "alternative": "Option B"}],
                  "aggregate": {"verdict": "SOFT-DISSENT"}})
    append_event({"event": "user_pick", "question_id": "qX", "pick": "Option B"})
    # Simulate one labeling round + quit.
    monkeypatch.setattr("sys.stdin", io.StringIO("r\nuser said so\nq\n"))

    from panel.cli import main
    main(["label"])

    from panel.telemetry import index_by_question
    idx = index_by_question()
    assert idx["qX"]["label"] == "right"
    assert idx["qX"]["label_note"] == "user said so"


def test_label_quit_first_does_nothing(tmp_path, monkeypatch):
    monkeypatch.setenv("HOME", str(tmp_path))
    from panel.telemetry import append_event
    append_event({"event": "decision", "question_id": "qY", "cycle": 0,
                  "aggregate": {"verdict": "HOLD"}})
    monkeypatch.setattr("sys.stdin", io.StringIO("q\n"))
    from panel.cli import main
    main(["label"])
    from panel.telemetry import index_by_question
    assert index_by_question()["qY"]["label"] is None
```

- [ ] **Step 2: Run — should FAIL (subcommand not added)**

- [ ] **Step 3: Add `label` subparser**

```python
    lab = sub.add_parser("label", help="Interactively label unlabeled decisions")
    lab.add_argument("--since", default=None)
```

Dispatch branch:

```python
    if args.cmd == "label":
        from panel.telemetry import list_questions, append_event
        unlabeled = [q for q in list_questions(status="unlabeled", since=args.since)]
        if not unlabeled:
            print("Nothing unlabeled.")
            return 0
        for i, rec in enumerate(unlabeled):
            print(f"\n[{i+1}/{len(unlabeled)} unlabeled]  question_id: {rec['question_id']}")
            last = rec["decisions"][-1] if rec["decisions"] else {}
            print(f"  Panel: {last.get('aggregate', {}).get('verdict', '?')} (cycle {last.get('cycle', '?')})")
            print(f"  Recommended: {last.get('recommended_label', '—')}")
            print(f"  User picked: {rec['user_pick'] or '—'}")
            for j, p in enumerate(last.get("panelists", [])):
                print(f"    P{j+1}: {p.get('verdict', '?')}  alt={p.get('alternative', '—')}")
            print("Panel call: [r]ight  [w]rong  [m]ixed  [u]nsure  [s]kip  [q]uit  > ", end="", flush=True)
            try:
                choice = sys.stdin.readline().strip().lower()
            except (EOFError, KeyboardInterrupt):
                return 0
            if choice == "q":
                return 0
            if choice == "s":
                continue
            mapping = {"r": "right", "w": "wrong", "m": "mixed", "u": "unsure"}
            if choice not in mapping:
                print(f"Unknown choice '{choice}'; skipping.")
                continue
            print("Note (optional, blank to skip): ", end="", flush=True)
            note = sys.stdin.readline().rstrip("\n")
            append_event({
                "event": "label",
                "question_id": rec["question_id"],
                "label": mapping[choice],
                "note": note,
            })
            print(f"  → saved: {mapping[choice]}")
        return 0
```

- [ ] **Step 4: Run tests — should PASS**

`python3 -m pytest panel/tests/test_cli_label.py -v` → 2 tests pass.

- [ ] **Step 5: Commit**

```bash
git add panel/cli.py panel/tests/test_cli_label.py
git commit -s -S -m "feat(panel): interactive 'panel label' subcommand"
```

---

### Task 9: Phase 6 end-to-end verification

- [ ] **Step 1: Full pytest**

`cd ~/.claude/skills/validate-recommendation && python3 -m pytest panel/ -v` → all pass (>50 tests across all phases).

- [ ] **Step 2: Hook tests**

```bash
bash panel/tests/test_hook.sh
bash panel/tests/test_hook_userpick.sh
bash dispatch-http_test.sh
```
All three should PASS.

- [ ] **Step 3: Live decision + label cycle**

Trigger one or two real `AskUserQuestion` panel evaluations. Then run:

```bash
python3 -m panel ls
```
Expected: each panel-evaluated question appears with its verdict bucket and user pick.

```bash
python3 -m panel label
```
Label one as "right". Verify:

```bash
python3 -m panel show <qid>
```
Shows the label and note.

```bash
python3 -m panel stats
```
Reports the new label count.

- [ ] **Step 4: Phase 6 sign-off**

When all three steps pass with a real end-to-end labeling round, Phase 6 is done. v1 of validate-recommendation v2 is complete.

Next: Phase 7 (`panel tune`) is deferred to v1.x — wait until you have ~50+ labeled decisions in the corpus before scoping that work.

---

## Self-review

**Spec coverage**: Phase 6 maps to Tasks 1-9. JSONL telemetry (1-2), aggregator integration (3), PostToolUse hook (4, 6), SKILL.md fallback (5), `ls`/`show`/`stats` (7), `label` interactive UX (8), verification (9). All telemetry schema fields from the spec (`v`, `ts`, `event`, `question_id`, `cycle`, `session_id`, `recommended_label`, `panelists`, `aggregate`, `pick`, `label`, `note`) are produced by code in this plan.

**Placeholder scan**: no TBD/TODO. All commands runnable. Test cases use concrete strings and assertions.

**Type consistency**: `JSONL_PATH()` function returns `Path` — used by all telemetry tests and `index_by_question`. `event` type strings (`"decision"`, `"user_pick"`, `"label"`) used consistently across telemetry.py, hook, and CLI. Single-keystroke labels `r/w/m/u/s/q` are documented and accepted in both Task 8's test and CLI dispatch.

**Open dependency**: Task 4 Step 2 depends on Claude Code supporting PostToolUse on `AskUserQuestion`. The spec already documents this as a forward dependency (failure-modes matrix row "PostToolUse hook fails to capture user_pick → best-effort: decision is in JSONL without user_pick event; `panel label` shows '(user_pick unknown)' but is still labelable"). The SKILL.md fallback (Task 5) covers the gap.

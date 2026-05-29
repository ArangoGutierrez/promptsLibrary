# validate-recommendation v2 — Phase 5: Re-brainstorm cycles

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire HARD-DISSENT into a bounded auto-re-brainstorm loop. State files relocate from `$TMPDIR` (session-keyed) to `~/.claude/panel/state-<qhash>.json` (question-keyed). Hook is updated to distinguish *fresh question* / *stale crash* / *continuation* / *orphan* via the state file's cycle counter. SKILL.md emits a Markdown directive on HARD-DISSENT (cycle < max) instead of re-issuing `AskUserQuestion` — Claude reads the directive in its next turn and re-emits a reconsidered recommendation. After `max_cycles` attempts, the question escalates to the user with full cycle history.

**Architecture:**
- **Canonical `question_hash`** lives in `panel/qhash.py`. Called by hook (via `python3 -m panel compute-qhash`) and by skill. Hash inputs: `question_text + sorted, marker-stripped option labels`. SHA-256 first 16 hex chars.
- **State file** lives at `~/.claude/panel/state-<qhash>.json` (was `$TMPDIR/claude-panel-<session>.json`). Carries `cycle`, `max_cycles`, `cycle_history`. Mode 0600. Cleaned by `panel gc` (default >1h old, or on-demand).
- **Hook re-entry tree**: no state file → fresh (write cycle=0, exit 2); state with cycle=0 → stale crash (remove, exit 0 = bypass); state with 1 ≤ cycle ≤ max → continuation (exit 2, skill runs); state with cycle > max → orphan (remove, exit 0).
- **Skill behavior on HARD-DISSENT cycle < max**: update state file (cycle += 1), emit a structured Markdown directive as the skill's terminal output. NO `AskUserQuestion` issued. Claude reads the directive on the next turn.
- **Skill behavior on HARD-DISSENT cycle == max** (escalation): issue `AskUserQuestion` with marker `(Recommended; Panel-flagged-after-N-cycles)` and full cycle history appended.

**Tech Stack:** Python stdlib (`hashlib`, `json`, `re`, `pathlib`). Bash for hook. New `panel/tests/test_hook.sh` covers hook behavior end-to-end via fixture-based state files.

**Pre-flight:**
- Phase 4 has shipped (`panel aggregate` emits HARD-DISSENT with `escalate_to_user: true` flag at cycle ≥ max).
- All Phase 4 tests pass.
- `~/.claude/panel/` directory exists and is mode 0700.

---

## File Structure

| File | Disposition |
|---|---|
| `~/.claude/skills/validate-recommendation/panel/qhash.py` | **Create**: canonical question-hash algorithm. |
| `~/.claude/skills/validate-recommendation/panel/state.py` | **Create**: state-file read/write with cycle accounting. |
| `~/.claude/skills/validate-recommendation/panel/cli.py` | **Modify**: add `compute-qhash` and `gc` subcommands. |
| `~/.claude/skills/validate-recommendation/panel/tests/test_qhash.py` | **Create**. |
| `~/.claude/skills/validate-recommendation/panel/tests/test_state.py` | **Create**. |
| `~/.claude/skills/validate-recommendation/panel/tests/test_hook.sh` | **Create**: bash tests for hook re-entry scenarios. |
| `~/.claude/hooks/validate-recommendation.sh` | **Modify**: qhash-keyed state file, cycle-aware re-entry logic. |
| `~/.claude/skills/validate-recommendation/SKILL.md` | **Modify**: HARD-DISSENT emits Markdown directive; escalation path handled. |

---

## Tasks

### Task 1: Failing tests for `panel.qhash`

**Files:**
- Create: `~/.claude/skills/validate-recommendation/panel/tests/test_qhash.py`

- [ ] **Step 1: Write tests**

```python
"""Tests for panel.qhash — canonical question-hash algorithm."""


def test_hash_is_deterministic():
    from panel.qhash import question_hash
    options = [{"label": "A"}, {"label": "B"}, {"label": "C"}]
    h1 = question_hash("Which is best?", options)
    h2 = question_hash("Which is best?", options)
    assert h1 == h2
    assert len(h1) == 16


def test_hash_invariant_to_option_order():
    """Same options in different declared order → same hash (we sort)."""
    from panel.qhash import question_hash
    h1 = question_hash("Q?", [{"label": "A"}, {"label": "B"}, {"label": "C"}])
    h2 = question_hash("Q?", [{"label": "C"}, {"label": "B"}, {"label": "A"}])
    assert h1 == h2


def test_hash_invariant_to_recommended_marker():
    """Adding/removing (Recommended) on an option → same hash."""
    from panel.qhash import question_hash
    h1 = question_hash("Q?", [{"label": "A"}, {"label": "B (Recommended)"}, {"label": "C"}])
    h2 = question_hash("Q?", [{"label": "A (Recommended)"}, {"label": "B"}, {"label": "C"}])
    h3 = question_hash("Q?", [{"label": "A"}, {"label": "B"}, {"label": "C"}])
    assert h1 == h2 == h3


def test_hash_invariant_to_panel_flagged_suffix():
    """Recommended; Panel-flagged-* markers also stripped."""
    from panel.qhash import question_hash
    h1 = question_hash("Q?", [{"label": "A (Recommended)"}, {"label": "B"}, {"label": "C"}])
    h2 = question_hash("Q?", [{"label": "A (Recommended; Panel-flagged)"}, {"label": "B"}, {"label": "C"}])
    h3 = question_hash("Q?", [{"label": "A (Recommended; Panel-flagged-after-2-cycles)"}, {"label": "B"}, {"label": "C"}])
    assert h1 == h2 == h3


def test_hash_differs_for_different_questions():
    from panel.qhash import question_hash
    h1 = question_hash("Q one?", [{"label": "A"}, {"label": "B"}, {"label": "C"}])
    h2 = question_hash("Q two?", [{"label": "A"}, {"label": "B"}, {"label": "C"}])
    assert h1 != h2


def test_hash_differs_for_different_options():
    from panel.qhash import question_hash
    h1 = question_hash("Q?", [{"label": "A"}, {"label": "B"}, {"label": "C"}])
    h2 = question_hash("Q?", [{"label": "A"}, {"label": "B"}, {"label": "D"}])
    assert h1 != h2


def test_strip_recommended_marker():
    """The marker-stripping helper covers all known forms."""
    from panel.qhash import strip_recommended_marker
    assert strip_recommended_marker("A") == "A"
    assert strip_recommended_marker("A (Recommended)") == "A"
    assert strip_recommended_marker("A (Recommended; Panel-flagged)") == "A"
    assert strip_recommended_marker("A (Recommended; Panel-flagged-after-2-cycles)") == "A"
    # Trailing whitespace from a multi-space label is also stripped.
    assert strip_recommended_marker("A  (Recommended)") == "A"
```

- [ ] **Step 2: Run — should FAIL**

`python3 -m pytest panel/tests/test_qhash.py -v` → ModuleNotFoundError.

---

### Task 2: Implement `panel/qhash.py`

**Files:**
- Create: `~/.claude/skills/validate-recommendation/panel/qhash.py`

- [ ] **Step 1: Write `qhash.py`**

```python
"""Canonical question-hash algorithm.

Used by:
  - PreToolUse hook (validate-recommendation.sh) to find/update state file
  - PostToolUse hook (panel-record-userpick.sh, Phase 6) to find decision row
  - SKILL.md to pass --question-id to panel aggregate
  - panel aggregate to write question_id into decisions.jsonl

Hash inputs: question_text + sorted, marker-stripped option labels.
Output: sha256 first 16 hex chars (2^64 entropy — collision-free for
single-user usage).
"""
from __future__ import annotations
import hashlib
import re


# Strips "(Recommended)", "(Recommended; Panel-flagged)", and
# "(Recommended; Panel-flagged-after-N-cycles)" from a label's tail.
# Anchored at end-of-string so a label that *legitimately* contains
# "(Recommended)" in its body isn't truncated mid-content.
_RECOMMENDED_MARKER_RE = re.compile(r"\s*\(Recommended[^)]*\)\s*$")


def strip_recommended_marker(label: str) -> str:
    """Remove the trailing (Recommended...) marker if present."""
    return _RECOMMENDED_MARKER_RE.sub("", label).strip()


def question_hash(question_text: str, options: list[dict]) -> str:
    """Compute the canonical hash for (question_text, options).

    `options` is a list of dicts with a 'label' key (matches the
    AskUserQuestion tool's question schema).
    """
    normalized = "\n".join(sorted(
        strip_recommended_marker(opt["label"]).strip()
        for opt in options
    ))
    payload = f"{question_text.strip()}\n---\n{normalized}"
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()[:16]
```

- [ ] **Step 2: Run tests — should PASS**

- [ ] **Step 3: Commit**

```bash
git add panel/qhash.py panel/tests/test_qhash.py
git commit -s -S -m "feat(panel): canonical question_hash algorithm"
```

---

### Task 3: Add `compute-qhash` CLI subcommand

**Files:**
- Modify: `~/.claude/skills/validate-recommendation/panel/cli.py`

The hook needs to call this — bash can't recompute the hash correctly without re-implementing the algorithm. CLI surface: take JSON on stdin (the hook's tool_input has it), print the hash to stdout.

- [ ] **Step 1: Add subparser**

In `cli.py`, after the existing subparsers, add:

```python
    qh = sub.add_parser("compute-qhash",
                        help="Compute question_hash from tool_input JSON on stdin")
    qh.add_argument("--question-index", type=int, default=0,
                    help="Which question in tool_input.questions to hash (default 0)")
```

Add dispatch branch:

```python
    if args.cmd == "compute-qhash":
        import json
        data = json.loads(sys.stdin.read())
        q = data["tool_input"]["questions"][args.question_index]
        from panel.qhash import question_hash
        print(question_hash(q["question"], q["options"]))
        return 0
```

- [ ] **Step 2: Manual smoke test**

```bash
echo '{"tool_input":{"questions":[{"question":"Q?","options":[{"label":"A"},{"label":"B (Recommended)"},{"label":"C"}]}]}}' | \
    cd ~/.claude/skills/validate-recommendation && python3 -m panel compute-qhash
```
Expected: one line of 16 hex characters.

- [ ] **Step 3: Commit**

```bash
git add panel/cli.py
git commit -s -S -m "feat(panel): compute-qhash CLI subcommand"
```

---

### Task 4: Failing tests for `panel.state`

**Files:**
- Create: `~/.claude/skills/validate-recommendation/panel/tests/test_state.py`

- [ ] **Step 1: Write tests**

```python
"""Tests for panel.state — state file r/w + cycle accounting."""
import json
from pathlib import Path


def test_write_and_read_round_trip(tmp_path, monkeypatch):
    monkeypatch.setenv("HOME", str(tmp_path))
    from panel.state import State, save_state, load_state, state_path

    s = State(
        qhash="abc123",
        session_id="sess",
        question_text="Q?",
        normalized_options=["A", "B", "C"],
        cycle=0,
        max_cycles=2,
        cycle_history=[],
    )
    save_state(s)
    p = state_path("abc123")
    assert p.is_file()
    loaded = load_state("abc123")
    assert loaded == s


def test_load_nonexistent_returns_none(tmp_path, monkeypatch):
    monkeypatch.setenv("HOME", str(tmp_path))
    from panel.state import load_state
    assert load_state("missing-hash") is None


def test_remove_state(tmp_path, monkeypatch):
    monkeypatch.setenv("HOME", str(tmp_path))
    from panel.state import State, save_state, remove_state, load_state
    save_state(State(qhash="x", session_id="s", question_text="q",
                     normalized_options=[], cycle=0, max_cycles=2, cycle_history=[]))
    remove_state("x")
    assert load_state("x") is None


def test_state_file_mode_0600(tmp_path, monkeypatch):
    monkeypatch.setenv("HOME", str(tmp_path))
    from panel.state import State, save_state, state_path
    save_state(State(qhash="x", session_id="s", question_text="q",
                     normalized_options=[], cycle=0, max_cycles=2, cycle_history=[]))
    import os
    mode = os.stat(state_path("x")).st_mode & 0o777
    assert mode == 0o600


def test_gc_removes_old_files(tmp_path, monkeypatch):
    monkeypatch.setenv("HOME", str(tmp_path))
    from panel.state import State, save_state, gc_states, state_path
    save_state(State(qhash="recent", session_id="s", question_text="q",
                     normalized_options=[], cycle=0, max_cycles=2, cycle_history=[]))
    save_state(State(qhash="old", session_id="s", question_text="q",
                     normalized_options=[], cycle=0, max_cycles=2, cycle_history=[]))
    # Make "old" appear old (mtime 2h ago).
    import os, time
    old_path = state_path("old")
    two_hours_ago = time.time() - 2 * 3600
    os.utime(old_path, (two_hours_ago, two_hours_ago))

    removed = gc_states(older_than_seconds=3600)
    assert old_path.name in removed
    assert state_path("recent").is_file()
    assert not old_path.exists()
```

- [ ] **Step 2: Run — should FAIL**

---

### Task 5: Implement `panel/state.py`

**Files:**
- Create: `~/.claude/skills/validate-recommendation/panel/state.py`

- [ ] **Step 1: Write `state.py`**

```python
"""State file management for the re-brainstorm cycle.

State files live at ~/.claude/panel/state-<qhash>.json. Each survives
across PreToolUse hook re-entries within the same question. Cleaned by
`panel gc` (default >1h old) or when the skill resolves the question.
"""
from __future__ import annotations
import json
import os
import time
from dataclasses import asdict, dataclass, field
from pathlib import Path


STATE_DIR = Path.home() / ".claude" / "panel"


@dataclass
class CycleHistoryEntry:
    cycle: int
    recommended_label: str
    verdict: str
    panelist_summary: list[str]
    feedback: str = ""


@dataclass
class State:
    qhash: str
    session_id: str
    question_text: str
    normalized_options: list[str]
    cycle: int
    max_cycles: int
    cycle_history: list[CycleHistoryEntry] = field(default_factory=list)
    created_at: str = ""
    updated_at: str = ""


def state_path(qhash: str) -> Path:
    return STATE_DIR / f"state-{qhash}.json"


def save_state(state: State) -> None:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    os.chmod(STATE_DIR, 0o700)
    path = state_path(state.qhash)
    ts = _utc_now_iso()
    if not state.created_at:
        state.created_at = ts
    state.updated_at = ts
    data = asdict(state)
    # Write atomically: write to tmp, then rename.
    tmp = path.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(data, indent=2), encoding="utf-8")
    os.chmod(tmp, 0o600)
    tmp.replace(path)


def load_state(qhash: str) -> State | None:
    path = state_path(qhash)
    if not path.is_file():
        return None
    raw = json.loads(path.read_text(encoding="utf-8"))
    history = [CycleHistoryEntry(**h) for h in raw.get("cycle_history", [])]
    return State(
        qhash=raw["qhash"],
        session_id=raw["session_id"],
        question_text=raw["question_text"],
        normalized_options=raw["normalized_options"],
        cycle=raw["cycle"],
        max_cycles=raw["max_cycles"],
        cycle_history=history,
        created_at=raw.get("created_at", ""),
        updated_at=raw.get("updated_at", ""),
    )


def remove_state(qhash: str) -> None:
    path = state_path(qhash)
    try:
        path.unlink()
    except FileNotFoundError:
        pass


def gc_states(older_than_seconds: int = 3600) -> list[str]:
    """Remove state files older than `older_than_seconds`. Return removed paths."""
    if not STATE_DIR.is_dir():
        return []
    cutoff = time.time() - older_than_seconds
    removed: list[str] = []
    for p in STATE_DIR.glob("state-*.json"):
        try:
            if p.stat().st_mtime < cutoff:
                p.unlink()
                removed.append(p.name)
        except OSError:
            continue
    return removed


def _utc_now_iso() -> str:
    from datetime import datetime, timezone
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
```

- [ ] **Step 2: Run tests — should PASS**

- [ ] **Step 3: Commit**

```bash
git add panel/state.py panel/tests/test_state.py
git commit -s -S -m "feat(panel): state file r/w with cycle accounting + gc"
```

---

### Task 6: Add `gc` CLI subcommand

**Files:**
- Modify: `~/.claude/skills/validate-recommendation/panel/cli.py`

- [ ] **Step 1: Add subparser**

```python
    gc = sub.add_parser("gc", help="Remove stale state files")
    gc.add_argument("--older-than", default="1h",
                    help="Remove state files older than this (e.g., 1h, 30m, 7200s). Default: 1h")
```

Add dispatch:

```python
    if args.cmd == "gc":
        from panel.state import gc_states
        seconds = _parse_duration(args.older_than)
        removed = gc_states(older_than_seconds=seconds)
        for r in removed:
            print(f"removed {r}")
        return 0
```

And helper:

```python
def _parse_duration(s: str) -> int:
    if s.endswith("h"):
        return int(s[:-1]) * 3600
    if s.endswith("m"):
        return int(s[:-1]) * 60
    if s.endswith("s"):
        return int(s[:-1])
    return int(s)
```

- [ ] **Step 2: Commit**

```bash
git add panel/cli.py
git commit -s -S -m "feat(panel): panel gc subcommand"
```

---

### Task 7: Update hook to use qhash-keyed state file

**Files:**
- Modify: `~/.claude/hooks/validate-recommendation.sh`

- [ ] **Step 1: Replace the hook's state-file logic**

Open `~/.claude/hooks/validate-recommendation.sh`. The current hook computes `STATE_FILE="$TMP/claude-panel-${SID}.json"`. Replace that and the re-entry guard block with qhash-keyed logic:

After the `RECOMMENDED_LABEL` extraction block (the current `if [ -z "$RECOMMENDED_LABEL" ]; then exit 0; fi`), insert:

```bash
# Compute canonical question hash by piping tool_input through the panel
# Python CLI. Fail-open: if Python is missing or compute-qhash errors,
# fall back to session-keyed legacy path (so the user-visible question
# always survives).
QHASH=$(echo "$INPUT" | python3 -m panel compute-qhash 2>/dev/null) || QHASH=""
if [ -z "$QHASH" ]; then
    echo "panel: compute-qhash failed; falling back to session-keyed state" >&2
    QHASH="legacy-${SID}"
fi
STATE_DIR="$HOME/.claude/panel"
mkdir -p "$STATE_DIR" 2>/dev/null
chmod 700 "$STATE_DIR" 2>/dev/null
STATE_FILE="$STATE_DIR/state-${QHASH}.json"
```

(Remove the old `TMP="${TMPDIR:-/tmp}"` and `STATE_FILE="$TMP/claude-panel-${SID}.json"` lines.)

- [ ] **Step 2: Replace re-entry-guard logic with cycle-aware tree**

Find the existing re-entry guard:

```bash
if [ -f "$STATE_FILE" ]; then
    rm -f "$STATE_FILE"
    echo "[$CREATED] event=reentry_bypass session=$SID" >> "$TRACE_LOG" 2>/dev/null || true
    exit 0
fi
```

Replace with:

```bash
# Cycle-aware re-entry tree:
#   No state file              → fresh question. Write cycle=0 state, block.
#   state.cycle == 0           → stale crash. Remove + bypass.
#   1 <= state.cycle <= max    → continuation. Let skill run.
#   state.cycle > max          → orphan. Remove + bypass.
if [ -f "$STATE_FILE" ]; then
    CYCLE=$(jq -r '.cycle // 0' "$STATE_FILE" 2>/dev/null)
    MAX=$(jq -r '.max_cycles // 2' "$STATE_FILE" 2>/dev/null)
    case "$CYCLE" in
        0)
            rm -f "$STATE_FILE"
            echo "[$CREATED] event=reentry_bypass session=$SID qhash=$QHASH reason=stale_crash" \
                >> "$TRACE_LOG" 2>/dev/null || true
            exit 0
            ;;
        *)
            if [ "$CYCLE" -gt "$MAX" ]; then
                rm -f "$STATE_FILE"
                echo "[$CREATED] event=reentry_bypass session=$SID qhash=$QHASH reason=orphan" \
                    >> "$TRACE_LOG" 2>/dev/null || true
                exit 0
            fi
            # Continuation — fall through to write state + block.
            echo "[$CREATED] event=continuation session=$SID qhash=$QHASH cycle=$CYCLE" \
                >> "$TRACE_LOG" 2>/dev/null || true
            ;;
    esac
fi
```

- [ ] **Step 3: Update state-file write to use the cycle field**

Replace the existing `echo "$INPUT" | jq ... > "$STATE_FILE"` block with:

```bash
echo "$INPUT" | jq \
    --arg sid "$SID" \
    --arg qhash "$QHASH" \
    --arg label "$RECOMMENDED_LABEL" \
    --arg timeout "$TIMEOUT" \
    --arg created "$CREATED" \
    '{
        session_id: $sid,
        qhash: $qhash,
        tool_input: .tool_input,
        recommended_label: $label,
        timeout_seconds: ($timeout | tonumber),
        created_at: $created,
        cycle: 0,
        max_cycles: 2,
        cycle_history: []
    }' > "$STATE_FILE" 2>/dev/null || {
        echo "panel: failed to write state file at $STATE_FILE" >&2
        exit 0  # fail-open
    }
chmod 600 "$STATE_FILE" 2>/dev/null
```

(The `cycle: 0` and `max_cycles: 2` default here — the skill updates them after dispatch.)

- [ ] **Step 4: Manually re-read the modified hook**

`cat ~/.claude/hooks/validate-recommendation.sh | head -80` — verify the changes look syntactically correct.

- [ ] **Step 5: Commit**

```bash
cd ~/.claude/hooks
git add validate-recommendation.sh
git commit -s -S -m "feat(panel-hook): qhash-keyed state file + cycle-aware re-entry"
```

(If ~/.claude/ is not a git repo, skip the commit but proceed.)

---

### Task 8: Write hook integration tests

**Files:**
- Create: `~/.claude/skills/validate-recommendation/panel/tests/test_hook.sh`

- [ ] **Step 1: Write the test script**

```bash
#!/bin/bash
# test_hook.sh - end-to-end tests for validate-recommendation hook.
# Each test invokes the hook with a piped tool_input JSON and verifies
# the expected state-file presence/absence and exit code.
set -o pipefail

HOOK="$HOME/.claude/hooks/validate-recommendation.sh"
STATE_DIR="$HOME/.claude/panel"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

if [ ! -x "$HOOK" ]; then
    echo "FAIL: hook script missing or not executable"
    exit 1
fi

# Helper: build a tool_input JSON with a (Recommended)-marked option.
mkpayload() {
    local question="$1"
    local rec_label="$2"
    jq -n --arg q "$question" --arg r "$rec_label" '{
        tool_name: "AskUserQuestion",
        tool_input: {
            questions: [{
                question: $q,
                options: [
                    {label: $r, description: "the recommended one"},
                    {label: "Option B", description: "alternative one"},
                    {label: "Option C", description: "alternative two"}
                ]
            }]
        }
    }'
}

# Helper: compute the qhash for a given (question, options) the same way
# panel.qhash would.
compute_qhash() {
    echo "$1" | python3 -m panel compute-qhash
}

# Clean slate.
rm -f "$STATE_DIR"/state-*.json

# Test 1: Fresh question → state file is created with cycle=0, hook exits 2.
PAYLOAD=$(mkpayload "Fresh question for test 1?" "Option A (Recommended)")
QHASH=$(compute_qhash "$PAYLOAD")
echo "$PAYLOAD" | "$HOOK" >"$TMP/stderr1" 2>&1
RC=$?
if [ "$RC" != "2" ]; then
    echo "FAIL test1: expected exit 2 (block), got $RC"
    cat "$TMP/stderr1"
    exit 1
fi
if [ ! -f "$STATE_DIR/state-${QHASH}.json" ]; then
    echo "FAIL test1: state file not created at $STATE_DIR/state-${QHASH}.json"
    ls "$STATE_DIR/" | head -5
    exit 1
fi
CYCLE=$(jq -r '.cycle' "$STATE_DIR/state-${QHASH}.json")
if [ "$CYCLE" != "0" ]; then
    echo "FAIL test1: expected cycle=0 in state file, got $CYCLE"
    exit 1
fi

# Test 2: Re-entry with cycle=0 state → bypass (exit 0), state removed.
echo "$PAYLOAD" | "$HOOK" >"$TMP/stderr2" 2>&1
RC=$?
if [ "$RC" != "0" ]; then
    echo "FAIL test2: expected exit 0 (bypass on stale cycle=0), got $RC"
    cat "$TMP/stderr2"
    exit 1
fi
if [ -f "$STATE_DIR/state-${QHASH}.json" ]; then
    echo "FAIL test2: state file should have been removed on stale-cycle-0 bypass"
    exit 1
fi

# Test 3: Continuation — state file with cycle=1 exists → exit 2 (no bypass).
PAYLOAD=$(mkpayload "Question for test 3?" "Option A (Recommended)")
QHASH=$(compute_qhash "$PAYLOAD")
mkdir -p "$STATE_DIR"
cat > "$STATE_DIR/state-${QHASH}.json" <<EOF
{
  "qhash": "${QHASH}",
  "session_id": "test",
  "cycle": 1,
  "max_cycles": 2,
  "cycle_history": [{"cycle": 0, "recommended_label": "X", "verdict": "HARD-DISSENT", "panelist_summary": [], "feedback": ""}]
}
EOF
echo "$PAYLOAD" | "$HOOK" >"$TMP/stderr3" 2>&1
RC=$?
if [ "$RC" != "2" ]; then
    echo "FAIL test3: expected exit 2 (continuation), got $RC"
    cat "$TMP/stderr3"
    exit 1
fi
# State file must NOT be overwritten — continuation reuses the existing file.
CYCLE=$(jq -r '.cycle' "$STATE_DIR/state-${QHASH}.json")
if [ "$CYCLE" != "1" ]; then
    echo "FAIL test3: state file overwritten on continuation (cycle is now $CYCLE, expected 1)"
    exit 1
fi
rm -f "$STATE_DIR/state-${QHASH}.json"

# Test 4: Orphan — state file with cycle > max_cycles → bypass + remove.
PAYLOAD=$(mkpayload "Question for test 4?" "Option A (Recommended)")
QHASH=$(compute_qhash "$PAYLOAD")
cat > "$STATE_DIR/state-${QHASH}.json" <<EOF
{
  "qhash": "${QHASH}",
  "cycle": 3,
  "max_cycles": 2,
  "cycle_history": []
}
EOF
echo "$PAYLOAD" | "$HOOK" >"$TMP/stderr4" 2>&1
RC=$?
if [ "$RC" != "0" ]; then
    echo "FAIL test4: expected exit 0 (orphan bypass), got $RC"
    cat "$TMP/stderr4"
    exit 1
fi
if [ -f "$STATE_DIR/state-${QHASH}.json" ]; then
    echo "FAIL test4: state file should have been removed on orphan bypass"
    exit 1
fi

# Test 5: Panel-flagged marker is ignored (no panel re-fire).
PAYLOAD=$(jq -n '{
    tool_name: "AskUserQuestion",
    tool_input: {
        questions: [{
            question: "Already panel-flagged?",
            options: [
                {label: "Option A (Recommended; Panel-flagged)", description: "previously flagged"},
                {label: "Option B", description: "..."}
            ]
        }]
    }
}')
echo "$PAYLOAD" | "$HOOK" >"$TMP/stderr5" 2>&1
RC=$?
if [ "$RC" != "0" ]; then
    echo "FAIL test5: panel-flagged marker should make hook exit 0 (no fire), got $RC"
    cat "$TMP/stderr5"
    exit 1
fi

echo "PASS"
```

- [ ] **Step 2: Make it executable**

`chmod +x ~/.claude/skills/validate-recommendation/panel/tests/test_hook.sh`

- [ ] **Step 3: Run it**

`bash ~/.claude/skills/validate-recommendation/panel/tests/test_hook.sh` → expect `PASS`.

If a test fails, the most likely cause is the hook script edit in Task 7. Re-check the cycle-aware re-entry tree block.

- [ ] **Step 4: Commit**

```bash
cd ~/.claude/skills/validate-recommendation
git add panel/tests/test_hook.sh
git commit -s -S -m "test(panel-hook): cycle-aware re-entry integration tests"
```

---

### Task 9: SKILL.md emits Markdown directive on HARD-DISSENT (cycle < max)

**Files:**
- Modify: `~/.claude/skills/validate-recommendation/SKILL.md`

- [ ] **Step 1: Replace the Phase-4 "HARD-DISSENT" subsection in "Acting on verdicts"**

In SKILL.md's `### PANEL_VERDICT: HARD-DISSENT` subsection (added in Phase 4), replace the contents with:

```markdown
### `PANEL_VERDICT: HARD-DISSENT`

Check `escalate_to_user` in the aggregator's directive JSON output.

**If `escalate_to_user` is false or unset** (cycle < max_cycles):

1. Read current state file (`~/.claude/panel/state-<qhash>.json`).
2. Update it: increment `cycle`, append a `CycleHistoryEntry` for this round (cycle, recommended_label, verdict, panelist_summary, feedback_for_claude).
3. Persist via `python3 -m panel state-update --qhash <qhash> --cycle <new-cycle> --append-history <json>` (Phase 5.5 will add this subcommand; for Phase 5 the skill may shell out to `jq` and rewrite the file in place).
4. **Do NOT call `AskUserQuestion`.** Instead, emit the following Markdown directive as the skill's terminal output (this becomes Claude's next-turn context):

   ```markdown
   ## Panel HARD-DISSENT — cycle <new-cycle> of <max_cycles>

   **Rejected recommendation:** `<recommended_label>`

   **Panel feedback to incorporate:**
   <bulleted list of per-panelist OVERTURN rationales>

   **Panel suggests:** `<suggested_alternative>` (or "no single suggestion; consider re-framing the question")

   **Next step:** re-think the design with this feedback as new
   constraints. Re-emit `AskUserQuestion` with your reconsidered
   recommendation. The hook will re-evaluate.

   If after re-thinking you still believe `<recommended_label>` is
   correct, emit it again — but include in the question description
   an explicit response to the panel's concern (e.g., "we accept the
   customization limit because X"). The panel will weight that.

   **This is cycle <new-cycle> of <max_cycles>.** If the panel HARD-DISSENTs
   again at the final cycle, the question will be surfaced to the user
   with full cycle history.
   ```

5. Return. The hook will fire again when Claude re-emits, the state file's cycle counter is now 1+, and the cycle is treated as a continuation.

**If `escalate_to_user` is true** (cycle == max_cycles):

1. Read state file, append final cycle history entry.
2. Issue `AskUserQuestion` with:
   - Question text: original + two newlines + `⚠️ **HARD DISSENT after <max_cycles> cycles.**` + full cycle history (one short paragraph per cycle).
   - Options: identical to original, EXCEPT the recommended option's label has `(Recommended)` replaced with `(Recommended; Panel-flagged-after-<max_cycles>-cycles)`.
3. Remove the state file (`panel state-remove --qhash <qhash>`, or `rm -f`).
4. User answers; PostToolUse (Phase 6) records the user_pick.
```

- [ ] **Step 2: Add a state-helper subcommand for SKILL.md**

In `cli.py`, add a `state` subcommand group with `update` and `remove`:

```python
    state = sub.add_parser("state", help="Read/write state files (used by SKILL.md)")
    state_sub = state.add_subparsers(dest="state_cmd", required=True)

    su = state_sub.add_parser("get", help="Read a state file as JSON")
    su.add_argument("--qhash", required=True)

    sw = state_sub.add_parser("update-cycle", help="Increment cycle and append history entry")
    sw.add_argument("--qhash", required=True)
    sw.add_argument("--verdict", required=True)
    sw.add_argument("--recommended-label", required=True)
    sw.add_argument("--feedback", default="")

    sr = state_sub.add_parser("remove", help="Remove a state file")
    sr.add_argument("--qhash", required=True)
```

Add dispatch:

```python
    if args.cmd == "state":
        from panel.state import load_state, save_state, remove_state, CycleHistoryEntry
        if args.state_cmd == "get":
            s = load_state(args.qhash)
            if s is None:
                print("{}")
                return 1
            from dataclasses import asdict
            print(json.dumps(asdict(s), indent=2))
            return 0
        if args.state_cmd == "update-cycle":
            s = load_state(args.qhash)
            if s is None:
                print(f"no state for qhash {args.qhash}", file=sys.stderr)
                return 1
            s.cycle += 1
            s.cycle_history.append(CycleHistoryEntry(
                cycle=s.cycle - 1,
                recommended_label=args.recommended_label,
                verdict=args.verdict,
                panelist_summary=[],
                feedback=args.feedback,
            ))
            save_state(s)
            print(f"qhash={args.qhash} cycle={s.cycle}")
            return 0
        if args.state_cmd == "remove":
            remove_state(args.qhash)
            return 0
```

(Add `import json` at top if not already.)

- [ ] **Step 3: Commit**

```bash
cd ~/.claude/skills/validate-recommendation
git add panel/cli.py SKILL.md
git commit -s -S -m "feat(panel): HARD-DISSENT emits markdown directive (auto re-brainstorm)

cycle < max_cycles: skill increments state.cycle and emits a structured
markdown directive that Claude reads on the next turn. The hook
re-fires on Claude's re-emitted AskUserQuestion; cycle continuation
takes over.

cycle == max_cycles: aggregator sets escalate_to_user=true; skill
issues AskUserQuestion to the user with the full cycle history."
```

---

### Task 10: Phase 5 end-to-end verification

- [ ] **Step 1: Full pytest**

`cd ~/.claude/skills/validate-recommendation && python3 -m pytest panel/ -v` → all pass (>40 tests across all phases).

- [ ] **Step 2: Hook tests**

`bash panel/tests/test_hook.sh` → expect PASS.

- [ ] **Step 3: Run `panel gc` and confirm clean-up works**

```bash
mkdir -p ~/.claude/panel
touch -t 202401010000 ~/.claude/panel/state-stale.json  # ancient mtime
echo '{"qhash":"stale","cycle":0,"max_cycles":2}' > ~/.claude/panel/state-stale.json
touch -t 202401010000 ~/.claude/panel/state-stale.json
python3 -m panel gc --older-than 1h
ls ~/.claude/panel/
```
Expected: `state-stale.json` removed; output line `removed state-stale.json`.

- [ ] **Step 4: Live multi-cycle test**

Trigger an `AskUserQuestion` with a recommendation likely to be flagged HARD by the panel (e.g., one that Claude knows the user will reject — pick a known-bad option as recommended). Expected:

- Cycle 0: panel HARD-DISSENTs, skill emits the markdown directive (no AskUserQuestion goes to user).
- Cycle 1: Claude re-emits with reconsidered recommendation; hook treats as continuation.
- If cycle 1 → HOLD/SOFT: user sees the (eventually-acceptable) question.
- If cycle 1 → HARD again: skill emits directive again (cycle 2 of 2).
- Cycle 2: if HARD again, user sees AskUserQuestion with `(Recommended; Panel-flagged-after-2-cycles)` and full history.

Verify the trace log shows `event=continuation` entries between cycles.

- [ ] **Step 5: Phase 5 sign-off**

When all four steps pass, Phase 5 is done. Next: Phase 6 — telemetry + CLI.

---

## Self-review

**Spec coverage**: Phase 5 maps to Tasks 1-10. Question-hash algorithm (1-3), state-file r/w (4-5), CLI subcommands for gc and state (6, 9), hook re-entry tree update (7-8), SKILL.md HARD-DISSENT handling (9), verification (10).

**Placeholder scan**: Task 9 references "Phase 5.5 will add this subcommand" — that's a forward reference for the in-Phase-5 implementation of `panel state update-cycle` which IS specified in Task 9 Step 2. Not actually deferred. (Self-fix: the subcommand IS added in Task 9 Step 2 of THIS plan — the "Phase 5.5" hint in the markdown is misleading. Treat the subcommand as part of Phase 5.)

**Type consistency**: `State`, `CycleHistoryEntry` dataclass names match across Tasks 4-5 and Task 9. `qhash` field used consistently. `cycle`, `max_cycles` field names match between hook bash, Python state module, and SKILL.md.

**Risk note**: the Markdown directive mechanism (Task 9 Step 1) depends on Claude reading the skill's terminal output as next-turn context. This is the contract for how Claude Code skills work. If a future Claude Code version changes that contract, this mechanism would need a different signaling path (e.g., a status file the next assistant turn reads). Flagged in the spec's "Failure modes — Claude ignores re-brainstorm directive" row; mitigation is `panel gc` cleaning the stale state file after 1h.

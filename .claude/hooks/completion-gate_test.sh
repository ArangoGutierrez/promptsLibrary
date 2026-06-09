#!/usr/bin/env bash
# completion-gate_test.sh — behavioral tests for completion-gate.sh
# Each test builds a transcript JSONL fixture, pipes the hook its Stop stdin,
# and asserts on stdout JSON (decision:block), NOT exit code.
# Audit/ledger writes are redirected via CG_AUDIT_DIR for isolation.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
HOOK="$HERE/completion-gate.sh"
FX="$HERE/fixtures/completion-gate/real-slice.jsonl"
PASS=0; FAIL=0
pass(){ PASS=$((PASS+1)); }
fail(){ FAIL=$((FAIL+1)); echo "  FAIL: $1"; }
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
export CG_AUDIT_DIR="$WORK/audit"; mkdir -p "$CG_AUDIT_DIR"

run_gate(){ printf '{"transcript_path":"%s","session_id":"s-%s","stop_hook_active":false}' "$1" "$RANDOM" | bash "$HOOK"; }
assert_block(){    printf '%s' "$1" | grep -q '"decision":"block"' && pass || fail "$2 (expected block)"; }
assert_no_block(){ printf '%s' "$1" | grep -q '"decision":"block"' && fail "$2 (expected NO block)" || pass; }

# Fixture builders (exact verified CC 2.1.169 schema)
A_edit(){ printf '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"%s","name":"Edit","input":{"file_path":"%s"}}]}}\n' "$1" "$2"; }
A_bash(){ printf '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"%s","name":"Bash","input":{"command":"%s"}}]}}\n' "$1" "$2"; }
A_text(){ printf '{"type":"assistant","message":{"content":[{"type":"text","text":"%s"}]}}\n' "$1"; }
U_ok(){   printf '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"%s"}]}}\n' "$1"; }            # is_error ABSENT
U_okf(){  printf '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"%s","is_error":false}]}}\n' "$1"; }
U_err(){  printf '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"%s","is_error":true}]}}\n' "$1"; }

src="$WORK/foo.go"; echo 'package x' > "$src"
doc="$WORK/README.md"; echo 'hi' > "$doc"

# T1: edit, no verify -> block
f="$WORK/t1.jsonl"; A_edit id1 "$src" > "$f"
assert_block "$(run_gate "$f")" "T1 edit-no-verify"

# T2: edit then passing verify, is_error ABSENT -> no block   [D1 regression: the v1 bug]
f="$WORK/t2.jsonl"; { A_edit id1 "$src"; A_bash id2 "go test ./..."; U_ok id2; } > "$f"
assert_no_block "$(run_gate "$f")" "T2 verify-absent-is_error"

# T2b: edit then passing verify, is_error:false -> no block
f="$WORK/t2b.jsonl"; { A_edit id1 "$src"; A_bash id2 "go test ./..."; U_okf id2; } > "$f"
assert_no_block "$(run_gate "$f")" "T2b verify-false-is_error"

# T3: edit early, final turn pure text, no verify -> block (cross-turn)
f="$WORK/t3.jsonl"; { A_edit id1 "$src"; A_text "all done"; } > "$f"
assert_block "$(run_gate "$f")" "T3 cross-turn"

# T4: pure conversation, no edits -> no block
f="$WORK/t4.jsonl"; A_text "just talking" > "$f"
assert_no_block "$(run_gate "$f")" "T4 no-edits"

# T5: edit README.md only -> no block (deny-list)
f="$WORK/t5.jsonl"; A_edit id1 "$doc" > "$f"
assert_no_block "$(run_gate "$f")" "T5 deny-md"

# T6: edit + FAILING verify -> block
f="$WORK/t6.jsonl"; { A_edit id1 "$src"; A_bash id2 "go test ./..."; U_err id2; } > "$f"
assert_block "$(run_gate "$f")" "T6 failing-verify-blocks"

# T7: edit + VERIFY-WAIVED in last message -> no block
f="$WORK/t7.jsonl"; { A_edit id1 "$src"; A_text "VERIFY-WAIVED: no toolchain here"; } > "$f"
assert_no_block "$(run_gate "$f")" "T7 waiver"

# --- git-backed cases ---
G=$(mktemp -d)
git -C "$G" init -q
git -C "$G" config user.email t@t; git -C "$G" config user.name t; git -C "$G" config commit.gpgsign false
echo 'package x' > "$G/a.go"; git -C "$G" add a.go; git -C "$G" commit -qm base

# T8: content-hash debounce — same content blocked once, allowed on re-stop (FIXED session id)
echo 'package x // edited' > "$G/a.go"
f="$WORK/t8.jsonl"; A_edit id1 "$G/a.go" > "$f"
SID="deb-$RANDOM"
gd(){ printf '{"transcript_path":"%s","session_id":"%s","stop_hook_active":false}' "$1" "$SID" | bash "$HOOK"; }
assert_block    "$(gd "$f")" "T8 debounce-first"
assert_no_block "$(gd "$f")" "T8 debounce-second"

# T9: edit then revert (clean vs HEAD) -> no block
git -C "$G" checkout -- a.go
f="$WORK/t9.jsonl"; A_edit id9 "$G/a.go" > "$f"
assert_no_block "$(run_gate "$f")" "T9 reverted-clean"

# T10: edit then delete file -> no block, no crash
f="$WORK/t10.jsonl"; A_edit idA "$G/gone.go" > "$f"
assert_no_block "$(run_gate "$f")" "T10 deleted-path"

# T11: untracked NEW source file, no verify -> block (kept)
echo 'package n' > "$G/new.go"
f="$WORK/t11.jsonl"; A_edit idN "$G/new.go" > "$f"
assert_block "$(run_gate "$f")" "T11 untracked-new-kept"

# T12: kill-switch -> no block
f="$WORK/t12.jsonl"; A_edit id1 "$src" > "$f"
out=$(printf '{"transcript_path":"%s","session_id":"s","stop_hook_active":false}' "$f" | COMPLETION_GATE=off bash "$HOOK")
assert_no_block "$out" "T12 kill-switch"

# T13: garbage transcript path -> no block (fail-open)
out=$(printf '{"transcript_path":"/nope/nope.jsonl","session_id":"s","stop_hook_active":false}' | bash "$HOOK")
assert_no_block "$out" "T13 fail-open-missing"

# T13b: malformed stdin -> no block (fail-open)
out=$(printf 'not json' | bash "$HOOK")
assert_no_block "$out" "T13b fail-open-badstdin"

# T14: real captured transcript slice parses without crashing (schema regression)
if [ -f "$FX" ]; then
  run_gate "$FX" >/dev/null 2>&1 && pass || fail "T14 real-slice crashed"
else
  echo "  SKIP: T14 real-slice fixture not generated yet ($FX)"
fi

echo "== completion-gate: $PASS passed, $FAIL failed =="
[ "$FAIL" -eq 0 ]

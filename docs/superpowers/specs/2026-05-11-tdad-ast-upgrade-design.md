# TDAD AST Upgrade for `test-dep-map.sh` — Design

**Date:** 2026-05-11
**Scope:** `~/.claude/hooks/test-dep-map.sh` — Go path only. Replace regex-based source↔test mapping with AST-derived ranking. Add Go helper binary + build script + sibling tests.
**Out of scope:** TS/JS path (unchanged). Machine-readable output / JSON. Daemon mode / gopls / LSP integration. Cross-package integration-test discovery beyond the current regex behavior. Multi-language expansion. Caching layer.

## Problem

`test-dep-map.sh` is the advisory `tdd-guard.sh` calls when a Write to an implementation file has no companion `_test.*` — its output tells the human "here are other tests in the package that might be related." Today the Go path uses two anchored regexes (`^func ([A-Z][a-zA-Z0-9]*)` and `^type ([A-Z][a-zA-Z0-9]*)`) to extract symbols from the source file, then `grep -q` to check whether each test file mentions those symbols. Two structural misses on real Go code:

1. **Method receivers are invisible.** `func (s *Server) Start()` does not match `^func ([A-Z]...)`. Any object-oriented Go file (controllers, clients, servers, reconcilers — i.e., most of what we write) has its primary symbols silently skipped.
2. **No ranking among candidates.** Audit log from 2026-05-02 shows the user editing a package with `artifact_fetcher.go` + 8 split test files (`_bucket_test.go`, `_cache_test.go`, `_dra_migration_test.go`, `_log_test.go`, `_main_test.go`, `_repos_test.go`, `_routing_test.go`, `_velocity_test.go`). When the user edits one function, the current hook lists *all* 8 because all 8 import the package and `grep -q` finds *some* shared identifier. No signal about which test exercises the function actually touched.

Net effect: noisy advisory the user learns to scroll past, eroding the TDD-guard feedback loop.

## Goal

Make the advisory list the *right* test first for Go files. Productivity (top-of-list is the file to open) and quality (extend the right existing test instead of duplicating into the wrong one) follow from accurate ranking.

## Non-goals

- Replace `tdd-guard.sh`'s primary companion-test lookup (already correct for the simple case).
- Drive a test runner. No consumer exists; building speculative JSON output is YAGNI.
- Improve TS/JS. Audit log shows Go activity dwarfs TS/JS for this user. Touch the JS path the day it bites.
- Use `gopls`. Daemon lifecycle, port keying, and project-snapshot management add operational complexity disproportionate to the symbol-extraction need.

## Architecture

A thin Go helper binary replaces the in-script regex symbol extraction for `.go` files. The bash hook keeps its orchestration role.

```
~/.claude/hooks/test-dep-map.sh            (existing; becomes orchestrator)
~/.claude/hooks/src/test-dep-map-ast/      (new; Go source, captured to repo)
  main.go                                  (~150 LOC: parse, score, rank, emit)
~/.claude/hooks/bin/test-dep-map-ast       (new; compiled binary, gitignored)
~/.claude/hooks/build-helpers.sh           (new; idempotent build)
~/.claude/hooks/test-dep-map_test.sh       (new; sibling tests)
```

### Components

**`test-dep-map.sh` (orchestrator).** Existing functions `find_ts_tests`, `find_tests_for_file`, and the changed-files mode survive unchanged. `find_go_tests` is rewritten as a 5-line dispatcher:

```bash
find_go_tests() {
    local src_file="$1"
    # Disable hatch: any truthy value disables AST.
    case "${TDAD_DISABLE_AST:-}" in
        1|YES|yes|true|TRUE) regex_go_tests "$src_file" ; return ;;
    esac
    local helper="$(dirname "$0")/bin/test-dep-map-ast"
    if [ ! -x "$helper" ]; then
        regex_go_tests "$src_file" ; return
    fi
    if ! "$helper" "$src_file" 2>/dev/null; then
        regex_go_tests "$src_file"
    fi
}
```

The old regex body becomes `regex_go_tests` — unmodified, used as fallback.

**`test-dep-map-ast` (Go helper).** Single-file Go binary.

- Input: one absolute path to a `.go` source file.
- Output: zero or more lines on stdout, each formatted to match the existing advisory style:
  - `  <path/to/test.go> (N tests, references SymbolA, SymbolB)` — sorted by score descending, then path ascending.
- Exit codes: 0 on success (even with zero matches); non-zero on parse error or unreadable directory. Non-zero triggers fallback in the orchestrator.

**Symbol extraction.** Walk the AST of the source file; collect a set of identifier names:
- `*ast.FuncDecl` with non-nil `Recv` → method name (a test calls `srv.Start()` — the matchable identifier is `Start`, not `Server.Start`).
- `*ast.FuncDecl` with nil `Recv` → function name.
- `*ast.TypeSpec` → type name.
- Exported and unexported both extracted (unexported helpers are exercised by same-package `_test.go`).

**Test scanning.** For each `*_test.go` in the same directory as the source file (excluding the source file itself if it ends in `_test.go`):
- Parse the test file.
- Walk every `*ast.Ident` in the file; the walker visits `SelectorExpr.Sel` automatically, so `srv.Start()` contributes the identifier `Start`. Count exact-name matches against the source's symbol set.

**Scoring and ranking.**
- +3 per direct symbol reference in the test body. Imported-package selectors (e.g. `http.Server`) are not counted as references to same-named source symbols.
- The literal companion file (`foo_test.go` for `foo.go`) always ranks first if present in the candidate set, regardless of score. The companion is the highest-confidence signal; `tdd-guard.sh` typically catches it upstream but dep-map honors it when it doesn't.
- Non-companion tests with score 0 are omitted. Companion is emitted even with score 0.
- Among non-companion tests, sort by score desc, then path asc (deterministic).

### Data flow

```
tdd-guard.sh:156
    └─> test-dep-map.sh <foo.go>
            ├─ TDAD_DISABLE_AST truthy?  → regex_go_tests  → stdout
            ├─ bin/test-dep-map-ast missing? → regex_go_tests → stdout
            └─ bin/test-dep-map-ast <foo.go>
                    ├─ parse foo.go → symbols
                    ├─ for each *_test.go in dir:
                    │     parse, count identifier matches, score
                    ├─ sort by score desc, path asc
                    ├─ stdout: ranked lines OR (empty)
                    └─ exit 0 (success) | nonzero (parse error)
                            └─ orchestrator catches nonzero → regex_go_tests fallback
```

The orchestrator preserves the `NO TESTS FOUND` sentinel logic (current behavior in `find_tests_for_file` at the top level): if helper stdout is empty, the orchestrator emits `<rel> → NO TESTS FOUND` exactly as today, so `tdd-guard.sh:157`'s grep continues to work.

### Build / install

`~/.claude/hooks/build-helpers.sh`: idempotent.

```bash
#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_DIR="$SCRIPT_DIR/src/test-dep-map-ast"
BIN="$SCRIPT_DIR/bin/test-dep-map-ast"
mkdir -p "$SCRIPT_DIR/bin"
if [ ! -f "$BIN" ] || [ "$SRC_DIR/main.go" -nt "$BIN" ]; then
    (cd "$SRC_DIR" && go build -o "$BIN" .)
    echo "Built: $BIN"
else
    echo "Up to date: $BIN"
fi
```

`~/.claude/hooks/bin/` is added to `.gitignore` within `~/.claude` capture rules. Source under `src/` is captured to the repo via `scripts/capture.sh`. The build script is run manually after a fresh clone or after editing `main.go`.

No `init` requirement at runtime — if the binary is missing, the orchestrator falls back silently.

### Environment variable

`TDAD_DISABLE_AST`. Values `1`, `YES`, `yes`, `true`, `TRUE` disable AST and force the regex fallback. Anything else (including unset, `0`, `NO`, empty) enables AST. The user adds `export TDAD_DISABLE_AST=YES` to their shell rc during the trust-building period and removes it once satisfied.

## Performance

Per-invocation budget: **<500ms**, matching the original `test-dep-map.sh` budget.

Expected real cost:
- `go/parser` parse of one ~500-LOC Go file: ~5-15ms (cold; no parser process startup since the helper is one binary handling the whole call).
- 8 test files × ~10ms = ~80ms.
- Binary startup: ~5-10ms (single-binary, no plugin loading).
- Total typical: **<150ms**.

Worst case: a package with 30 test files. 30 × 15ms = 450ms parse cost. Still within budget. The helper does *not* walk beyond the source file's directory, so monorepo size does not affect runtime.

No caching in v1. Adds mtime invalidation, cache directory management, and stale-entry pruning for a microsecond gain on a sub-second operation. Re-evaluate if perf tests show >300ms on real packages.

## Fallback & error handling

Three fallback triggers, all transparent (no user-visible error):

| Trigger | Detection | Behavior |
|---|---|---|
| AST explicitly disabled | `TDAD_DISABLE_AST` truthy | Use `regex_go_tests` |
| Binary not built | `[ -x "$helper" ]` false | Use `regex_go_tests` |
| AST parse fails | Helper exits non-zero | Use `regex_go_tests` |

The fallback path produces output indistinguishable in format from the AST path (same `  <path> (N tests, ...)` shape), so downstream parsing in `tdd-guard.sh` is fallback-agnostic.

Helper crashes (panics) are caught by the exit-code check. Goroutine panics inside the helper are impossible: the helper is single-goroutine.

## Testing

New sibling: `~/.claude/hooks/test-dep-map_test.sh`. Pattern matches existing test scripts (`bash-audit-log_test.sh`, `context-watch_test.sh`).

Test corpus: synthetic Go packages constructed in `$TMPDIR` per test case, deleted on test exit.

| # | Case | Asserts |
|---|---|---|
| 1 | Method receivers caught | Source defines `func (s *Server) Start()`. Companion test calls `srv.Start()`. AST ranks companion first. Regex (control) misses it. |
| 2 | Ranking by symbol density | Source `foo.go`. 5 test files in package; only one references foo.go's symbols; the rest reference siblings. AST output lists only the relevant test (score > 0) and drops the others. |
| 3 | Companion bonus | Companion test with weak symbol overlap (1 match) ranks above non-companion test with same overlap. |
| 4 | Broken syntax fallback | Source has `func Bad(` (unclosed paren). Helper exits non-zero. Orchestrator falls back to regex. Output non-empty and matches the regex path. |
| 5 | Env var disable | `TDAD_DISABLE_AST=YES`. Binary deletion makes test detectable: even with binary present, helper is not invoked. Output matches regex path exactly. |
| 6 | NO TESTS FOUND sentinel | Source in a directory with zero test files. Output contains the literal `NO TESTS FOUND` string so `tdd-guard.sh:157` matches. |
| 7 | Performance budget | Synthetic 50-file Go package. `time` reports <500ms. |

Theater-test guard: each ranking assertion compares against an independently-derived expected order written by hand in the test fixture, not derived from the helper's own scoring logic. Deleting the AST helper turns cases 1, 2, 3 red; case 5's regex-path assertion is the inverse and stays green.

## Sequencing

| Stage | Items | Estimate |
|-------|-------|----------|
| 1 | Helper binary + symbol extraction (cases 1, 2) | ~45 min |
| 2 | Scoring + ranking + companion bonus (case 3) | ~30 min |
| 3 | Orchestrator dispatch + fallback (cases 4, 5, 6) | ~30 min |
| 4 | Build script + capture rules | ~15 min |
| 5 | Test harness + perf test (case 7) | ~30 min |

Total: **~2.5h.** Stages run sequentially; each gated by its tests.

## Verification

Before claiming complete:

1. **Functional.** All seven test cases pass: `bash ~/.claude/hooks/test-dep-map_test.sh`.
2. **Performance.** Case 7 reports <500ms on a 50-file synthetic package.
3. **End-to-end smoke.** In a worktree on a real Go package (one with method receivers), trigger a `tdd-guard` block by writing to an implementation file without first writing a test. Confirm:
   - The advisory line ranks the *method-containing* test above siblings.
   - Disabling the env var (`TDAD_DISABLE_AST=YES`) reverts to the old advisory shape.
   - Deleting the binary still produces a non-empty advisory (fallback works).
4. **Verify-output discipline.** Paste the actual `time` measurement and the test-case output into the completion claim.

## Open questions

None that block design.

Implementation discoveries to verify on the way:

1. **Go module location of the helper.** Either `go mod init claude-hooks/test-dep-map-ast` per-helper, or a single `go.mod` at `~/.claude/hooks/src/`. Decide during stage 1. No design impact.
2. **`.gitignore` of `~/.claude/hooks/bin/`.** Check the capture-script rules; ensure the binary is *not* synced to the repo (binaries are platform-specific). The source under `src/` *is* synced.

## What this is not

- It is not a measurement-first phase 0. The evidence is in the audit log already: on 2026-05-02 the user worked on a package whose layout (one source file, 8 split test files) is exactly the failure mode this design targets. The concrete miss exists in the user's real work; the upgrade is justified.
- It is not the TDAD paper's full ranked-execution proposal. The paper's contribution is ranked execution order for a test runner. This design adopts only the symbol-extraction half. Ranked execution is queued for the day a runner consumes it (e.g., a future `/test` skill or pre-commit hook).

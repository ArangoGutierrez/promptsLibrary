# TDAD AST Upgrade Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the regex-based Go path in `~/.claude/hooks/test-dep-map.sh` with an AST-derived ranking helper, falling back to regex on parse error or `TDAD_DISABLE_AST` set.

**Architecture:** A single-file Go binary at `~/.claude/hooks/bin/test-dep-map-ast` parses the source file and same-directory `*_test.go` files with `go/parser`, extracts identifier-level symbols (including method receiver names), scores test files by symbol-reference count + companion bonus, and emits a ranked stderr-style advisory. The existing `test-dep-map.sh` becomes a thin orchestrator that dispatches to the helper or to the unchanged regex logic.

**Tech Stack:** Go 1.21+ stdlib only (`go/parser`, `go/ast`, `go/token`). Bash 3.2+ (macOS default). No external Go modules.

**Reference spec:** `docs/superpowers/specs/2026-05-11-tdad-ast-upgrade-design.md`

---

## File Structure

Implementation writes to `~/.claude/` (live config — not a git repo). The repo worktree receives the changes via `scripts/capture.sh` at the end.

| Path | Action | Purpose |
|---|---|---|
| `~/.claude/hooks/test-dep-map.sh` | Modify | Wrap `find_go_tests` in dispatcher; keep regex body as `regex_go_tests` fallback |
| `~/.claude/hooks/src/test-dep-map-ast/go.mod` | Create | Minimal Go module for the helper |
| `~/.claude/hooks/src/test-dep-map-ast/main.go` | Create | ~150 LOC: parse, score, rank, emit |
| `~/.claude/hooks/src/test-dep-map-ast/main_test.go` | Create | Go unit tests for helper internals |
| `~/.claude/hooks/bin/test-dep-map-ast` | Build | Compiled binary (not captured to repo) |
| `~/.claude/hooks/build-helpers.sh` | Create | Idempotent build script |
| `~/.claude/hooks/test-dep-map_test.sh` | Create | Bash integration tests (the 7 cases) |
| `scripts/capture.sh` (or `.captureignore`) | Verify | Ensure `bin/` is excluded, `src/` is included |

`~/.claude` is **not a git repo** — implementation steps do NOT commit between tasks. Commits happen only after `scripts/capture.sh` syncs changes into the worktree at Stage 7.

`tdd-guard.sh` requires a git repo root to fire; it exits early when invoked outside one. Edits under `~/.claude/` are not blocked by it.

---

## Stage 1: Go module skeleton + symbol extraction (TDD)

### Task 1.1: Initialize Go module

**Files:**
- Create: `~/.claude/hooks/src/test-dep-map-ast/go.mod`

- [ ] **Step 1: Create the source directory**

```bash
mkdir -p ~/.claude/hooks/src/test-dep-map-ast
```

- [ ] **Step 2: Create the Go module file**

Write `~/.claude/hooks/src/test-dep-map-ast/go.mod`:

```
module claude.local/hooks/test-dep-map-ast

go 1.21
```

- [ ] **Step 3: Verify the module builds (empty case)**

```bash
cd ~/.claude/hooks/src/test-dep-map-ast && go mod tidy
```

Expected: no errors, no changes to `go.mod`.

### Task 1.2: Write failing test for symbol extraction

**Files:**
- Create: `~/.claude/hooks/src/test-dep-map-ast/main_test.go`

- [ ] **Step 1: Write the failing test**

Write `~/.claude/hooks/src/test-dep-map-ast/main_test.go`:

```go
package main

import (
	"sort"
	"testing"
)

func TestExtractSymbols_FuncTypeMethod(t *testing.T) {
	src := `package mypkg

import "context"

type Server struct{}

func (s *Server) Start(ctx context.Context) error {
	return nil
}

func (s *Server) stop() {}

func NewServer() *Server { return &Server{} }

func helper() int { return 0 }

type Config struct{ Port int }
`
	got, err := extractSymbols("inline.go", []byte(src))
	if err != nil {
		t.Fatalf("extractSymbols error: %v", err)
	}
	sort.Strings(got)
	want := []string{"Config", "NewServer", "Server", "Start", "helper", "stop"}
	if len(got) != len(want) {
		t.Fatalf("symbol count: got %v, want %v", got, want)
	}
	for i := range want {
		if got[i] != want[i] {
			t.Errorf("symbol[%d]: got %q, want %q", i, got[i], want[i])
		}
	}
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd ~/.claude/hooks/src/test-dep-map-ast && go test ./...
```

Expected: FAIL with `undefined: extractSymbols`.

### Task 1.3: Implement symbol extraction

**Files:**
- Create: `~/.claude/hooks/src/test-dep-map-ast/main.go`

- [ ] **Step 1: Write the minimal implementation**

Write `~/.claude/hooks/src/test-dep-map-ast/main.go`:

```go
package main

import (
	"go/ast"
	"go/parser"
	"go/token"
)

// extractSymbols returns the set of top-level function names, method names,
// and type names declared in the source. Exported and unexported are both
// included. Receiver type names are also included (a test referencing the
// type name is a relevance signal too).
func extractSymbols(path string, src []byte) ([]string, error) {
	fset := token.NewFileSet()
	file, err := parser.ParseFile(fset, path, src, parser.SkipObjectResolution)
	if err != nil {
		return nil, err
	}
	seen := map[string]struct{}{}
	add := func(name string) {
		if name == "" || name == "_" {
			return
		}
		seen[name] = struct{}{}
	}
	for _, decl := range file.Decls {
		switch d := decl.(type) {
		case *ast.FuncDecl:
			add(d.Name.Name)
			if d.Recv != nil {
				for _, f := range d.Recv.List {
					switch t := f.Type.(type) {
					case *ast.Ident:
						add(t.Name)
					case *ast.StarExpr:
						if id, ok := t.X.(*ast.Ident); ok {
							add(id.Name)
						}
					}
				}
			}
		case *ast.GenDecl:
			for _, spec := range d.Specs {
				if ts, ok := spec.(*ast.TypeSpec); ok {
					add(ts.Name.Name)
				}
			}
		}
	}
	out := make([]string, 0, len(seen))
	for k := range seen {
		out = append(out, k)
	}
	return out, nil
}

func main() {
	// Wired up in later tasks.
}
```

- [ ] **Step 2: Run the test to verify it passes**

```bash
cd ~/.claude/hooks/src/test-dep-map-ast && go test ./...
```

Expected: `PASS`.

### Task 1.4: Add test for parser error path

**Files:**
- Modify: `~/.claude/hooks/src/test-dep-map-ast/main_test.go`

- [ ] **Step 1: Add the failing test**

Append to `main_test.go`:

```go
func TestExtractSymbols_ParseError(t *testing.T) {
	src := `package broken

func Bad(  // unclosed paren
`
	_, err := extractSymbols("broken.go", []byte(src))
	if err == nil {
		t.Fatal("expected parse error, got nil")
	}
}
```

- [ ] **Step 2: Run the test to verify it passes**

```bash
cd ~/.claude/hooks/src/test-dep-map-ast && go test ./...
```

Expected: `PASS` (parser surfaces error naturally; no implementation change needed).

---

## Stage 2: Test-file scoring (TDD)

### Task 2.1: Write failing test for test-file scoring

**Files:**
- Modify: `~/.claude/hooks/src/test-dep-map-ast/main_test.go`

- [ ] **Step 1: Write the failing test**

Append to `main_test.go`:

```go
import "os"
import "path/filepath"
```

(Merge into existing import block at the top of the file.)

Then append:

```go
// writeFile is a test helper that writes data to path inside t.TempDir(),
// failing the test on any IO error.
func writeFile(t *testing.T, dir, name, content string) string {
	t.Helper()
	p := filepath.Join(dir, name)
	if err := os.WriteFile(p, []byte(content), 0644); err != nil {
		t.Fatalf("write %s: %v", p, err)
	}
	return p
}

func TestScoreTestFile_SymbolMatches(t *testing.T) {
	dir := t.TempDir()
	srcPath := writeFile(t, dir, "server.go", `package mypkg

type Server struct{}

func (s *Server) Start() error { return nil }
func (s *Server) Stop() error  { return nil }
`)
	tfPath := writeFile(t, dir, "server_test.go", `package mypkg

import "testing"

func TestStart(t *testing.T) {
	s := &Server{}
	if err := s.Start(); err != nil {
		t.Fatal(err)
	}
}
`)
	srcBytes, _ := os.ReadFile(srcPath)
	symbols, err := extractSymbols(srcPath, srcBytes)
	if err != nil {
		t.Fatalf("extract: %v", err)
	}
	score, hits, testFuncs, err := scoreTestFile(tfPath, symbols)
	if err != nil {
		t.Fatalf("scoreTestFile: %v", err)
	}
	// Test body references: Server (1), Start (1). Each is a source symbol.
	// Expected hits: 2. Score: 2*3 = 6. No companion bonus (applied by caller).
	if len(hits) < 2 {
		t.Errorf("hits: got %v, want at least 2 of {Server, Start}", hits)
	}
	if score < 6 {
		t.Errorf("score: got %d, want >= 6", score)
	}
	if testFuncs != 1 {
		t.Errorf("testFuncs: got %d, want 1", testFuncs)
	}
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd ~/.claude/hooks/src/test-dep-map-ast && go test ./...
```

Expected: FAIL with `undefined: scoreTestFile`.

### Task 2.2: Implement test-file scoring

**Files:**
- Modify: `~/.claude/hooks/src/test-dep-map-ast/main.go`

- [ ] **Step 1: Add scoreTestFile**

Add to `main.go` (after `extractSymbols`):

```go
// scoreTestFile parses the test file once and returns everything the caller
// needs to rank and render it. Companion bonus is applied by the caller
// (it depends on the source filename, not the test file).
//
//   score:     3 * len(hits)
//   hits:      sorted list of source-symbol names that appear in the test body
//   testFuncs: count of top-level Test*** functions (cosmetic, used in output)
func scoreTestFile(testPath string, srcSymbols []string) (int, []string, int, error) {
	if len(srcSymbols) == 0 {
		return 0, nil, 0, nil
	}
	src, err := os.ReadFile(testPath)
	if err != nil {
		return 0, nil, 0, err
	}
	fset := token.NewFileSet()
	file, err := parser.ParseFile(fset, testPath, src, parser.SkipObjectResolution)
	if err != nil {
		return 0, nil, 0, err
	}
	want := map[string]struct{}{}
	for _, s := range srcSymbols {
		want[s] = struct{}{}
	}
	hit := map[string]struct{}{}
	ast.Inspect(file, func(n ast.Node) bool {
		id, ok := n.(*ast.Ident)
		if !ok {
			return true
		}
		if _, ok := want[id.Name]; ok {
			hit[id.Name] = struct{}{}
		}
		return true
	})
	hits := make([]string, 0, len(hit))
	for k := range hit {
		hits = append(hits, k)
	}
	sort.Strings(hits)
	testFuncs := 0
	for _, decl := range file.Decls {
		fd, ok := decl.(*ast.FuncDecl)
		if !ok || fd.Recv != nil {
			continue
		}
		if strings.HasPrefix(fd.Name.Name, "Test") {
			testFuncs++
		}
	}
	return len(hit) * 3, hits, testFuncs, nil
}
```

Add `"os"`, `"sort"`, and `"strings"` to the import block.

- [ ] **Step 2: Run the test to verify it passes**

```bash
cd ~/.claude/hooks/src/test-dep-map-ast && go test ./...
```

Expected: `PASS`.

---

## Stage 3: Ranking, output, and main wiring (TDD)

### Task 3.1: Write failing test for end-to-end run

**Files:**
- Modify: `~/.claude/hooks/src/test-dep-map-ast/main_test.go`

- [ ] **Step 1: Write the failing test**

Append to `main_test.go`:

```go
import "strings"
```

(Merge into existing import block — `strings` is only needed for assertions in `TestRun_RanksByRelevance`.)

Then append:

```go
func TestRun_RanksByRelevance(t *testing.T) {
	dir := t.TempDir()
	srcPath := writeFile(t, dir, "server.go", `package mypkg

type Server struct{}

func (s *Server) Start() error { return nil }
`)
	// Strong match: companion that references Server + Start.
	writeFile(t, dir, "server_test.go", `package mypkg

import "testing"

func TestStart(t *testing.T) {
	s := &Server{}
	_ = s.Start()
}
`)
	// Weaker match: different topic, only mentions Server in a comment.
	writeFile(t, dir, "other_test.go", `package mypkg

import "testing"

// References Server only in this comment; not in code.
func TestUnrelated(t *testing.T) {
	_ = 1
}
`)
	// Zero match.
	writeFile(t, dir, "zero_test.go", `package mypkg

import "testing"

func TestSomething(t *testing.T) {
	_ = "no relevant symbols"
}
`)
	out := captureRun(t, srcPath)
	lines := strings.Split(strings.TrimSpace(out), "\n")
	if len(lines) < 1 {
		t.Fatalf("expected at least 1 line of output, got: %q", out)
	}
	if !strings.Contains(lines[0], "server_test.go") {
		t.Errorf("top-ranked line should reference server_test.go, got: %q", lines[0])
	}
	if strings.Contains(out, "zero_test.go") {
		t.Errorf("zero-score test should be omitted, got output:\n%s", out)
	}
}

// captureRun executes run() against srcPath and captures stdout as a string.
func captureRun(t *testing.T, srcPath string) string {
	t.Helper()
	r, w, _ := os.Pipe()
	old := os.Stdout
	os.Stdout = w
	defer func() { os.Stdout = old }()
	if err := run(srcPath); err != nil {
		w.Close()
		t.Fatalf("run: %v", err)
	}
	w.Close()
	buf := make([]byte, 4096)
	n, _ := r.Read(buf)
	return string(buf[:n])
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd ~/.claude/hooks/src/test-dep-map-ast && go test ./...
```

Expected: FAIL with `undefined: run`.

### Task 3.2: Implement run() with ranking

**Files:**
- Modify: `~/.claude/hooks/src/test-dep-map-ast/main.go`

- [ ] **Step 1: Add run() and the rankedEntry type**

Add to `main.go`:

```go
import (
	"fmt"
	"path/filepath"
)
```

(Merge into existing import block — `os`, `sort`, and `strings` are already imported from Task 2.2.)

Then append:

```go
// rankedEntry is one row of the output: a test file path with its score,
// matched source symbols, and Test*** count (for the cosmetic "N tests" field).
type rankedEntry struct {
	path      string
	score     int
	hits      []string
	testFuncs int
}

// run is the top-level entry point. It parses srcPath, walks sibling
// *_test.go files, scores each (one AST parse per test file), sorts, and
// writes the advisory lines to stdout in the same shape the bash regex
// path emits.
func run(srcPath string) error {
	srcBytes, err := os.ReadFile(srcPath)
	if err != nil {
		return err
	}
	symbols, err := extractSymbols(srcPath, srcBytes)
	if err != nil {
		return err
	}
	dir := filepath.Dir(srcPath)
	entries, err := os.ReadDir(dir)
	if err != nil {
		return err
	}
	base := filepath.Base(srcPath)
	companion := strings.TrimSuffix(base, ".go") + "_test.go"
	var ranked []rankedEntry
	for _, e := range entries {
		name := e.Name()
		if !strings.HasSuffix(name, "_test.go") || name == base {
			continue
		}
		tfPath := filepath.Join(dir, name)
		score, hits, testFuncs, err := scoreTestFile(tfPath, symbols)
		if err != nil {
			continue // Skip unreadable/unparseable test files; don't fail the run.
		}
		if name == companion {
			score++
		}
		if score == 0 {
			continue
		}
		ranked = append(ranked, rankedEntry{path: tfPath, score: score, hits: hits, testFuncs: testFuncs})
	}
	sort.Slice(ranked, func(i, j int) bool {
		if ranked[i].score != ranked[j].score {
			return ranked[i].score > ranked[j].score
		}
		return ranked[i].path < ranked[j].path
	})
	for _, r := range ranked {
		hitList := strings.Join(capHits(r.hits, 3), ", ")
		if hitList == "" {
			hitList = "(companion)"
		}
		fmt.Printf("  %s (%d tests, references %s)\n", r.path, r.testFuncs, hitList)
	}
	return nil
}

// capHits returns the first n elements of hits, or all of them if shorter.
// Used to keep advisory output readable when many symbols match.
func capHits(hits []string, n int) []string {
	if len(hits) <= n {
		return hits
	}
	return hits[:n]
}
```

- [ ] **Step 2: Wire main() to run()**

Replace the existing empty `main()` with:

```go
func main() {
	if len(os.Args) != 2 {
		fmt.Fprintln(os.Stderr, "usage: test-dep-map-ast <source.go>")
		os.Exit(2)
	}
	if err := run(os.Args[1]); err != nil {
		// Non-zero exit signals the bash orchestrator to fall back to regex.
		os.Exit(1)
	}
}
```

- [ ] **Step 3: Run all tests**

```bash
cd ~/.claude/hooks/src/test-dep-map-ast && go test ./...
```

Expected: `PASS` for all four tests (`TestExtractSymbols_FuncTypeMethod`, `TestExtractSymbols_ParseError`, `TestScoreTestFile_SymbolMatches`, `TestRun_RanksByRelevance`).

### Task 3.3: Companion-bonus test

**Files:**
- Modify: `~/.claude/hooks/src/test-dep-map-ast/main_test.go`

- [ ] **Step 1: Write the test**

Append to `main_test.go`:

```go
func TestRun_CompanionBonus(t *testing.T) {
	dir := t.TempDir()
	srcPath := writeFile(t, dir, "thing.go", `package mypkg

func Do() {}
`)
	// Companion test references Do (score 3). Companion ranks first by contract.
	writeFile(t, dir, "thing_test.go", `package mypkg

import "testing"

func TestDo(t *testing.T) {
	Do()
}
`)
	// Non-companion test references Do (score 3). Ranks second behind companion.
	writeFile(t, dir, "other_test.go", `package mypkg

import "testing"

func TestOther(t *testing.T) {
	Do()
}
`)
	out := captureRun(t, srcPath)
	lines := strings.Split(strings.TrimSpace(out), "\n")
	if len(lines) < 2 {
		t.Fatalf("expected 2 lines, got: %q", out)
	}
	if !strings.Contains(lines[0], "thing_test.go") {
		t.Errorf("companion should rank first, got line[0]=%q", lines[0])
	}
	if !strings.Contains(lines[1], "other_test.go") {
		t.Errorf("non-companion should rank second, got line[1]=%q", lines[1])
	}
}
```

- [ ] **Step 2: Run all tests**

```bash
cd ~/.claude/hooks/src/test-dep-map-ast && go test ./...
```

Expected: `PASS` for all five tests.

---

## Stage 4: Build script

### Task 4.1: Create build-helpers.sh

**Files:**
- Create: `~/.claude/hooks/build-helpers.sh`

- [ ] **Step 1: Write the build script**

Write `~/.claude/hooks/build-helpers.sh`:

```bash
#!/bin/bash
# build-helpers.sh - Build compiled Go helpers for hooks.
# Idempotent: only rebuilds when source is newer than the binary, or the
# binary is missing.
#
# Usage: ./build-helpers.sh [--force]
#   --force: rebuild even if up to date.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="$SCRIPT_DIR/bin"
mkdir -p "$BIN_DIR"

FORCE=0
[ "${1:-}" = "--force" ] && FORCE=1

build_one() {
    local name="$1"
    local src_dir="$SCRIPT_DIR/src/$name"
    local bin_path="$BIN_DIR/$name"
    if [ ! -d "$src_dir" ]; then
        echo "skip $name (no source dir)"
        return
    fi
    if [ $FORCE -eq 0 ] && [ -f "$bin_path" ]; then
        local newer
        newer=$(find "$src_dir" -name '*.go' -newer "$bin_path" 2>/dev/null | head -1)
        if [ -z "$newer" ]; then
            echo "up to date: $bin_path"
            return
        fi
    fi
    (cd "$src_dir" && go build -o "$bin_path" .)
    echo "built: $bin_path"
}

build_one test-dep-map-ast
```

- [ ] **Step 2: Make executable**

```bash
chmod +x ~/.claude/hooks/build-helpers.sh
```

- [ ] **Step 3: Run it**

```bash
~/.claude/hooks/build-helpers.sh
```

Expected output: `built: /Users/eduardoa/.claude/hooks/bin/test-dep-map-ast`

- [ ] **Step 4: Verify idempotency**

```bash
~/.claude/hooks/build-helpers.sh
```

Expected output: `up to date: /Users/eduardoa/.claude/hooks/bin/test-dep-map-ast`

- [ ] **Step 5: Smoke-test the binary**

```bash
mkdir -p /tmp/tdad-smoke && cd /tmp/tdad-smoke && cat > server.go <<'EOF'
package mypkg

type Server struct{}

func (s *Server) Start() error { return nil }
EOF
cat > server_test.go <<'EOF'
package mypkg

import "testing"

func TestStart(t *testing.T) {
	s := &Server{}
	_ = s.Start()
}
EOF
~/.claude/hooks/bin/test-dep-map-ast /tmp/tdad-smoke/server.go
```

Expected: one line of output mentioning `server_test.go` and references including `Server` and `Start`.

- [ ] **Step 6: Clean up smoke test**

```bash
rm -rf /tmp/tdad-smoke
```

---

## Stage 5: Orchestrator dispatch in test-dep-map.sh

### Task 5.1: Refactor find_go_tests

**Files:**
- Modify: `~/.claude/hooks/test-dep-map.sh:16-58`

- [ ] **Step 1: Read the current file**

```bash
cat ~/.claude/hooks/test-dep-map.sh
```

Make sure lines 16-58 contain the existing `find_go_tests` function body, exactly as shown in the spec's Problem section.

- [ ] **Step 2: Replace `find_go_tests` with dispatcher + rename old body**

Replace lines 15-58 of `~/.claude/hooks/test-dep-map.sh` (the entire `# --- Go test mapping ---` block including the `find_go_tests()` function) with:

```bash
# --- Go test mapping ---
# regex_go_tests implements the original regex-based path. Used as a fallback
# when the AST helper is disabled, missing, or fails to parse.
regex_go_tests() {
    local src_file="$1"
    local rel_path="${src_file#"$GIT_ROOT"/}"
    rel_path="${rel_path#./}"
    local dir=$(dirname "$rel_path")
    local base=$(basename "$rel_path" .go)

    # Direct companion: foo.go → foo_test.go
    local companion="${dir}/${base}_test.go"
    if [ -f "$companion" ]; then
        local test_count=$(grep -c '^func Test' "$companion" 2>/dev/null || echo 0)
        echo "  ${companion} (${test_count} tests)"
    fi

    # Other test files in the same package that may test this file
    for tf in "${dir}"/*_test.go; do
        [ -f "$tf" ] || continue
        [ "$tf" = "$companion" ] && continue
        local symbols=$(grep -oE '^func ([A-Z][a-zA-Z0-9]*)' "$rel_path" 2>/dev/null | awk '{print $2}')
        symbols="$symbols $(grep -oE '^type ([A-Z][a-zA-Z0-9]*)' "$rel_path" 2>/dev/null | awk '{print $2}')"
        for sym in $symbols; do
            if grep -q "$sym" "$tf" 2>/dev/null; then
                local test_count=$(grep -c '^func Test' "$tf" 2>/dev/null || echo 0)
                echo "  ${tf} (${test_count} tests, references ${sym})"
                break
            fi
        done
    done

    # Integration/e2e tests that reference this package
    local pkg_name=$(basename "$dir")
    for test_dir in test tests e2e test/e2e tests/e2e; do
        [ -d "$test_dir" ] || continue
        local matches=$(grep -rl "$pkg_name" "$test_dir" --include="*_test.go" 2>/dev/null)
        for tf in $matches; do
            local test_count=$(grep -c '^func Test' "$tf" 2>/dev/null || echo 0)
            echo "  ${tf} (${test_count} tests, integration)"
        done
    done
}

# find_go_tests dispatches: AST helper for accurate ranking, else regex.
# Env var TDAD_DISABLE_AST (values 1|YES|yes|true|TRUE) forces the regex path.
find_go_tests() {
    local src_file="$1"
    case "${TDAD_DISABLE_AST:-}" in
        1|YES|yes|true|TRUE)
            regex_go_tests "$src_file"
            return
            ;;
    esac
    local helper
    helper="$(dirname "$0")/bin/test-dep-map-ast"
    if [ ! -x "$helper" ]; then
        regex_go_tests "$src_file"
        return
    fi
    local out
    if ! out=$("$helper" "$src_file" 2>/dev/null); then
        regex_go_tests "$src_file"
        return
    fi
    printf '%s\n' "$out"
}
```

- [ ] **Step 3: Run shellcheck to catch shell-script defects**

```bash
shellcheck ~/.claude/hooks/test-dep-map.sh 2>&1 | head -30 || true
```

Expected: no new errors compared to before the edit. Existing pre-edit warnings (if any) are acceptable.

- [ ] **Step 4: Smoke test via the orchestrator**

```bash
cd /tmp && mkdir -p tdad-orch && cd tdad-orch && git init -q && cat > server.go <<'EOF'
package mypkg
type Server struct{}
func (s *Server) Start() error { return nil }
EOF
cat > server_test.go <<'EOF'
package mypkg
import "testing"
func TestStart(t *testing.T) { s := &Server{}; _ = s.Start() }
EOF
~/.claude/hooks/test-dep-map.sh server.go
```

Expected: output includes a line like `server.go →` followed by `  server_test.go (1 tests, references ...)`.

- [ ] **Step 5: Smoke test the env-var fallback**

```bash
TDAD_DISABLE_AST=YES ~/.claude/hooks/test-dep-map.sh server.go
```

Expected: same shape of output. The line should NOT include "references Start" (regex misses method-receiver names). Confirm this by checking that the regex-path output differs from the AST-path output for method-receiver cases.

- [ ] **Step 6: Smoke test the missing-binary fallback**

```bash
mv ~/.claude/hooks/bin/test-dep-map-ast /tmp/test-dep-map-ast.bak && \
  ~/.claude/hooks/test-dep-map.sh server.go && \
  mv /tmp/test-dep-map-ast.bak ~/.claude/hooks/bin/test-dep-map-ast
```

Expected: output is non-empty (regex path produces it).

- [ ] **Step 7: Clean up smoke test**

```bash
rm -rf /tmp/tdad-orch
```

---

## Stage 6: Bash integration tests

### Task 6.1: Create test-dep-map_test.sh skeleton

**Files:**
- Create: `~/.claude/hooks/test-dep-map_test.sh`

- [ ] **Step 1: Write the skeleton**

Write `~/.claude/hooks/test-dep-map_test.sh`:

```bash
#!/bin/bash
# test-dep-map_test.sh - Integration tests for test-dep-map.sh + AST helper.
# Runs all seven cases from the design doc and prints PASS/FAIL summary.
# Exits 0 on full pass, 1 on any failure.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK="$SCRIPT_DIR/test-dep-map.sh"
HELPER="$SCRIPT_DIR/bin/test-dep-map-ast"

PASS=0
FAIL=0

# fail prints a failure message and increments FAIL.
fail() {
    echo "  FAIL: $1"
    FAIL=$((FAIL + 1))
}

# pass increments PASS.
pass() { PASS=$((PASS + 1)); }

# new_corpus creates a tmpdir, initializes a git repo (required by the hook),
# and prints the path on stdout.
new_corpus() {
    local d
    d=$(mktemp -d)
    (cd "$d" && git init -q && git config user.email "t@test" && git config user.name "t")
    echo "$d"
}

# run_case runs a single named case function and reports PASS/FAIL.
run_case() {
    local name="$1"
    local fn="$2"
    echo "Case: $name"
    if "$fn"; then
        echo "  PASS"
        pass
    else
        fail "$name failed"
    fi
}

# Each case function below returns 0 on pass, non-zero on fail. Cases use
# new_corpus to set up isolated tmpdirs and clean up on exit.

# Cases populated in subsequent tasks.

main() {
    if [ ! -x "$HELPER" ]; then
        echo "WARN: helper binary missing at $HELPER. Cases relying on AST path will fail."
        echo "Run: $SCRIPT_DIR/build-helpers.sh"
    fi
    # Case invocations added in subsequent tasks.
    case_1_method_receivers
    case_2_ranking_by_density
    case_3_companion_bonus
    case_4_broken_syntax_fallback
    case_5_env_var_disable
    case_6_no_tests_found_sentinel
    case_7_perf_budget

    echo ""
    echo "==========="
    echo "PASS: $PASS  FAIL: $FAIL"
    if [ "$FAIL" -gt 0 ]; then
        exit 1
    fi
    exit 0
}

# The case_* functions and main call live at the bottom; tasks below append.

case_1_method_receivers() { return 0; } # stub, replaced in 6.2
case_2_ranking_by_density() { return 0; } # stub, replaced in 6.3
case_3_companion_bonus() { return 0; } # stub, replaced in 6.4
case_4_broken_syntax_fallback() { return 0; } # stub, replaced in 6.5
case_5_env_var_disable() { return 0; } # stub, replaced in 6.6
case_6_no_tests_found_sentinel() { return 0; } # stub, replaced in 6.7
case_7_perf_budget() { return 0; } # stub, replaced in 6.8

main "$@"
```

- [ ] **Step 2: Make executable**

```bash
chmod +x ~/.claude/hooks/test-dep-map_test.sh
```

- [ ] **Step 3: Verify skeleton runs (all stubs pass)**

```bash
~/.claude/hooks/test-dep-map_test.sh
```

Expected:
```
Case: Case: ... (seven cases, all PASS)
PASS: 7  FAIL: 0
```

### Task 6.2: Case 1 — method receivers caught

**Files:**
- Modify: `~/.claude/hooks/test-dep-map_test.sh` (replace `case_1_method_receivers`)

- [ ] **Step 1: Replace the case_1 stub**

Replace the line `case_1_method_receivers() { return 0; }` with:

```bash
case_1_method_receivers() {
    local d
    d=$(new_corpus)
    trap "rm -rf '$d'" RETURN
    cat > "$d/server.go" <<'EOF'
package mypkg
type Server struct{}
func (s *Server) Start() error { return nil }
EOF
    cat > "$d/server_test.go" <<'EOF'
package mypkg
import "testing"
func TestStart(t *testing.T) { s := &Server{}; _ = s.Start() }
EOF
    local out
    out=$(cd "$d" && "$HOOK" server.go)
    # AST path must include the method name Start in the references.
    echo "$out" | grep -qE 'references[^,]*Start' || {
        echo "  expected 'references ... Start' in: $out"
        return 1
    }
    return 0
}
```

- [ ] **Step 2: Run only this case to verify**

```bash
~/.claude/hooks/test-dep-map_test.sh 2>&1 | head -5
```

Expected: `Case: ...` line with `PASS` underneath for case 1.

### Task 6.3: Case 2 — ranking by symbol density

**Files:**
- Modify: `~/.claude/hooks/test-dep-map_test.sh` (replace `case_2_ranking_by_density`)

- [ ] **Step 1: Replace the case_2 stub**

Replace the line `case_2_ranking_by_density() { return 0; }` with:

```bash
case_2_ranking_by_density() {
    local d
    d=$(new_corpus)
    trap "rm -rf '$d'" RETURN
    cat > "$d/foo.go" <<'EOF'
package mypkg
func DoFoo() {}
EOF
    # Test that references DoFoo (strong match).
    cat > "$d/foo_test.go" <<'EOF'
package mypkg
import "testing"
func TestDoFoo(t *testing.T) { DoFoo() }
EOF
    # Test that references unrelated symbols (zero match).
    cat > "$d/bar_test.go" <<'EOF'
package mypkg
import "testing"
func TestBar(t *testing.T) { _ = 1 }
EOF
    local out
    out=$(cd "$d" && "$HOOK" foo.go)
    echo "$out" | grep -q "foo_test.go" || { echo "  foo_test.go missing in: $out"; return 1; }
    echo "$out" | grep -q "bar_test.go" && { echo "  bar_test.go should be omitted: $out"; return 1; }
    return 0
}
```

- [ ] **Step 2: Run the test suite**

```bash
~/.claude/hooks/test-dep-map_test.sh 2>&1 | tail -5
```

Expected: PASS count increases.

### Task 6.4: Case 3 — companion bonus

**Files:**
- Modify: `~/.claude/hooks/test-dep-map_test.sh` (replace `case_3_companion_bonus`)

- [ ] **Step 1: Replace the case_3 stub**

Replace the line `case_3_companion_bonus() { return 0; }` with:

```bash
case_3_companion_bonus() {
    local d
    d=$(new_corpus)
    trap "rm -rf '$d'" RETURN
    cat > "$d/thing.go" <<'EOF'
package mypkg
func Do() {}
EOF
    # Companion: Do referenced; companion ranks first by contract.
    cat > "$d/thing_test.go" <<'EOF'
package mypkg
import "testing"
func TestDo(t *testing.T) { Do() }
EOF
    # Non-companion: Do referenced; ranks below companion.
    cat > "$d/other_test.go" <<'EOF'
package mypkg
import "testing"
func TestOther(t *testing.T) { Do() }
EOF
    local out
    out=$(cd "$d" && "$HOOK" thing.go)
    # First listed test file should be the companion.
    local first_line
    first_line=$(echo "$out" | grep '_test.go' | head -1)
    echo "$first_line" | grep -q "thing_test.go" || {
        echo "  companion should rank first, got first line: $first_line"
        return 1
    }
    return 0
}
```

- [ ] **Step 2: Run the test suite**

```bash
~/.claude/hooks/test-dep-map_test.sh 2>&1 | tail -5
```

Expected: PASS count increases.

### Task 6.5: Case 4 — broken syntax fallback

**Files:**
- Modify: `~/.claude/hooks/test-dep-map_test.sh` (replace `case_4_broken_syntax_fallback`)

- [ ] **Step 1: Replace the case_4 stub**

Replace the line `case_4_broken_syntax_fallback() { return 0; }` with:

```bash
case_4_broken_syntax_fallback() {
    local d
    d=$(new_corpus)
    trap "rm -rf '$d'" RETURN
    # Source with unclosed paren — go/parser returns an error.
    cat > "$d/broken.go" <<'EOF'
package mypkg

func Bad(
EOF
    # A test file that references symbols by name (regex path can match).
    cat > "$d/broken_test.go" <<'EOF'
package mypkg
import "testing"
func TestBad(t *testing.T) { /* mentions Bad */ }
EOF
    local out
    out=$(cd "$d" && "$HOOK" broken.go 2>&1)
    # Non-empty output expected from the regex fallback.
    [ -n "$out" ] || { echo "  expected non-empty fallback output"; return 1; }
    # Output should NOT contain a Go error message — fallback is silent.
    echo "$out" | grep -qE 'expected|syntax error' && {
        echo "  fallback leaked a Go error message: $out"
        return 1
    }
    return 0
}
```

- [ ] **Step 2: Run the test suite**

```bash
~/.claude/hooks/test-dep-map_test.sh 2>&1 | tail -5
```

Expected: PASS count increases.

### Task 6.6: Case 5 — env var disable

**Files:**
- Modify: `~/.claude/hooks/test-dep-map_test.sh` (replace `case_5_env_var_disable`)

- [ ] **Step 1: Replace the case_5 stub**

Replace the line `case_5_env_var_disable() { return 0; }` with:

```bash
case_5_env_var_disable() {
    local d
    d=$(new_corpus)
    trap "rm -rf '$d'" RETURN
    cat > "$d/server.go" <<'EOF'
package mypkg
type Server struct{}
func (s *Server) Start() error { return nil }
EOF
    cat > "$d/server_test.go" <<'EOF'
package mypkg
import "testing"
func TestStart(t *testing.T) { s := &Server{}; _ = s.Start() }
EOF
    local out
    out=$(cd "$d" && TDAD_DISABLE_AST=YES "$HOOK" server.go)
    # Regex path: cannot extract the method name Start from func (s *Server) Start().
    # It WILL see "Server" via the type spec regex. So the output should mention
    # Server but NOT include "Start" in the references list — proving the AST
    # was bypassed.
    echo "$out" | grep -qE 'references[^,]*Start' && {
        echo "  AST was not bypassed — output contains Start reference: $out"
        return 1
    }
    return 0
}
```

- [ ] **Step 2: Run the test suite**

```bash
~/.claude/hooks/test-dep-map_test.sh 2>&1 | tail -5
```

Expected: PASS count increases.

### Task 6.7: Case 6 — NO TESTS FOUND sentinel

**Files:**
- Modify: `~/.claude/hooks/test-dep-map_test.sh` (replace `case_6_no_tests_found_sentinel`)

- [ ] **Step 1: Replace the case_6 stub**

Replace the line `case_6_no_tests_found_sentinel() { return 0; }` with:

```bash
case_6_no_tests_found_sentinel() {
    local d
    d=$(new_corpus)
    trap "rm -rf '$d'" RETURN
    cat > "$d/lonely.go" <<'EOF'
package mypkg
func Lonely() {}
EOF
    # No test files in directory.
    local out
    out=$(cd "$d" && "$HOOK" lonely.go)
    echo "$out" | grep -q "NO TESTS FOUND" || {
        echo "  expected 'NO TESTS FOUND' sentinel in: $out"
        return 1
    }
    return 0
}
```

- [ ] **Step 2: Run the test suite**

```bash
~/.claude/hooks/test-dep-map_test.sh 2>&1 | tail -5
```

Expected: PASS count increases.

### Task 6.8: Case 7 — performance budget

**Files:**
- Modify: `~/.claude/hooks/test-dep-map_test.sh` (replace `case_7_perf_budget`)

- [ ] **Step 1: Replace the case_7 stub**

Replace the line `case_7_perf_budget() { return 0; }` with:

```bash
case_7_perf_budget() {
    local d
    d=$(new_corpus)
    trap "rm -rf '$d'" RETURN
    cat > "$d/main.go" <<'EOF'
package mypkg
type Thing struct{}
func (t *Thing) Do() {}
func (t *Thing) Undo() {}
EOF
    # Generate 50 test files in the package.
    local i
    for i in $(seq 1 50); do
        cat > "$d/case${i}_test.go" <<EOF
package mypkg

import "testing"

func TestCase${i}A(t *testing.T) { th := &Thing{}; th.Do() }
func TestCase${i}B(t *testing.T) { th := &Thing{}; th.Undo() }
EOF
    done
    # Measure wall time in ms.
    local start_ns end_ns elapsed_ms
    start_ns=$(date +%s%N 2>/dev/null || gdate +%s%N 2>/dev/null)
    if [ -z "$start_ns" ] || [ "$start_ns" = "+%N" ]; then
        # macOS without coreutils: use Python for ms precision.
        local start_s
        start_s=$(python3 -c 'import time; print(time.time())')
        (cd "$d" && "$HOOK" main.go) > /dev/null
        local end_s
        end_s=$(python3 -c 'import time; print(time.time())')
        elapsed_ms=$(python3 -c "print(int(($end_s - $start_s) * 1000))")
    else
        (cd "$d" && "$HOOK" main.go) > /dev/null
        end_ns=$(date +%s%N 2>/dev/null || gdate +%s%N 2>/dev/null)
        elapsed_ms=$(( (end_ns - start_ns) / 1000000 ))
    fi
    echo "  elapsed: ${elapsed_ms}ms"
    if [ "$elapsed_ms" -gt 500 ]; then
        echo "  perf budget exceeded: ${elapsed_ms}ms > 500ms"
        return 1
    fi
    return 0
}
```

- [ ] **Step 2: Run the full suite**

```bash
~/.claude/hooks/test-dep-map_test.sh
```

Expected: all 7 cases PASS. Final line: `PASS: 7  FAIL: 0`.

- [ ] **Step 3: Run shellcheck on the test script**

```bash
shellcheck ~/.claude/hooks/test-dep-map_test.sh 2>&1 | head -20 || true
```

Expected: no errors (warnings acceptable).

---

## Stage 7: Capture, commit, push, PR

### Task 7.1: Verify capture rules include sources but not binaries

**Files:**
- Read: `scripts/capture.sh` (in the repo root, not `~/.claude`)

- [ ] **Step 1: Check what capture syncs**

```bash
cd /Users/eduardoa/src/github/ArangoGutierrez/promptsLibrary/.worktrees/tdad-ast-upgrade
grep -E 'exclude|include|hooks' scripts/capture.sh | head -30
```

- [ ] **Step 2: Decide if binary exclusion is automatic or needs an addition**

If `bin/` is already excluded (e.g., `--exclude='*/bin/*'` or similar in the rsync flags), no change needed. Otherwise:

Modify `scripts/capture.sh` to exclude `~/.claude/hooks/bin/` — add `--exclude=hooks/bin/` to the relevant rsync invocation (or equivalent).

If the script uses a `.captureignore`-style file, add `hooks/bin/` to it.

- [ ] **Step 3: Document the resolution in the plan checklist**

Record (in your scratchpad, not the plan): "Capture rule modification: <none|describe change>".

### Task 7.2: Run capture

**Files:**
- Read+execute: `scripts/capture.sh`

- [ ] **Step 1: Run capture from the worktree**

```bash
cd /Users/eduardoa/src/github/ArangoGutierrez/promptsLibrary/.worktrees/tdad-ast-upgrade
./scripts/capture.sh
```

Expected: capture script reports which files synced. Exit code 0.

- [ ] **Step 2: Inspect the diff**

```bash
cd /Users/eduardoa/src/github/ArangoGutierrez/promptsLibrary/.worktrees/tdad-ast-upgrade
git status --short
git diff --stat
```

Expected `git status` lines (paths within `dotfiles/.claude/` or the repo's equivalent claude-config path):

```
M  <claude-config>/hooks/test-dep-map.sh
A  <claude-config>/hooks/src/test-dep-map-ast/go.mod
A  <claude-config>/hooks/src/test-dep-map-ast/main.go
A  <claude-config>/hooks/src/test-dep-map-ast/main_test.go
A  <claude-config>/hooks/build-helpers.sh
A  <claude-config>/hooks/test-dep-map_test.sh
```

The `bin/test-dep-map-ast` binary must NOT appear. If it does, fix the capture exclusion in Task 7.1 and re-run capture.

### Task 7.3: Commit

**Files:** N/A (commit)

- [ ] **Step 1: Stage all the captured changes**

```bash
cd /Users/eduardoa/src/github/ArangoGutierrez/promptsLibrary/.worktrees/tdad-ast-upgrade
git add -A
git status --short
```

- [ ] **Step 2: Commit with conventional format, signed**

```bash
git -c user.signingkey="$(git config user.signingkey)" commit -s -S -m "feat(.claude): TDAD AST upgrade for test-dep-map.sh

Replace the regex-based Go path in test-dep-map.sh with an AST-derived
ranking helper (go/parser + go/ast). The helper extracts method-receiver
names that the prior regex missed and ranks candidate test files by
symbol-reference density plus a companion-file bonus.

Fallback paths preserve current behavior on env-var disable
(TDAD_DISABLE_AST=YES|1|true), missing binary, and parse error.

Adds:
- src/test-dep-map-ast/{main.go,main_test.go,go.mod}: helper.
- build-helpers.sh: idempotent compile.
- test-dep-map_test.sh: 7-case integration harness covering method
  receivers, ranking, companion bonus, fallback paths, sentinel,
  and <500ms perf budget."
```

### Task 7.4: Push and open PR

**Files:** N/A

- [ ] **Step 1: Push the branch**

```bash
cd /Users/eduardoa/src/github/ArangoGutierrez/promptsLibrary/.worktrees/tdad-ast-upgrade
git push -u origin feat/tdad-ast-upgrade
```

- [ ] **Step 2: Open the PR (use `dangerouslyDisableSandbox: true` for `gh`)**

Run via Bash with sandbox disabled per the saved-context rule:

```bash
gh pr create --draft --title "feat(.claude): TDAD AST upgrade for test-dep-map.sh" --body "$(cat <<'EOF'
## Summary

Replaces the regex-based Go path in \`~/.claude/hooks/test-dep-map.sh\` with an AST-derived ranking helper. The helper uses \`go/parser\` + \`go/ast\` to extract method-receiver names (which the prior regex silently missed) and ranks candidate test files by symbol-reference density plus a \`foo_test.go\` companion bonus.

## Why

The current regex \`^func ([A-Z][a-zA-Z0-9]*)\` does not match method receivers like \`func (s *Server) Start()\` — the primary symbols of most controllers, clients, and reconcilers. And when a package has many split test files (the audit log shows e.g. \`artifact_fetcher.go\` + 8 \`artifact_fetcher_*_test.go\` files), the regex hook lists them all unranked, eroding the TDD-guard advisory's signal-to-noise.

## Design + Plan

- Spec: \`docs/superpowers/specs/2026-05-11-tdad-ast-upgrade-design.md\`
- Plan: \`docs/superpowers/plans/2026-05-11-tdad-ast-upgrade-plan.md\`

## Verification

- Integration harness: \`~/.claude/hooks/test-dep-map_test.sh\` — 7 cases, all PASS.
- Perf budget: <500ms on a 50-file synthetic Go package.
- Three transparent fallback paths preserve current behavior.

## Rollout

\`TDAD_DISABLE_AST=YES\` in shell rc keeps the regex path active during the trust-building period. Remove the export to enable AST.
EOF
)"
```

- [ ] **Step 3: Promote to ready-for-review when QA gates pass (manual or via the team workflow)**

Per the project workflow: draft first, QA promotes after verification. For solo execution, the implementer is responsible for `gh pr ready` after the verification output is captured in the PR conversation.

---

## Verification before claiming complete

Before declaring the task done in the completion response, paste the following actual outputs into the response:

1. **Go unit tests:**
   ```
   cd ~/.claude/hooks/src/test-dep-map-ast && go test ./... -v
   ```
   All 5 tests PASS.

2. **Integration suite:**
   ```
   ~/.claude/hooks/test-dep-map_test.sh
   ```
   Final line: `PASS: 7  FAIL: 0` plus the `elapsed: <N>ms` line from case 7 (under 500ms).

3. **Repo state:**
   ```
   cd .worktrees/tdad-ast-upgrade && git log --oneline -5
   ```
   Shows the three commits: spec (already in branch), plan, impl.

4. **PR URL:** the URL printed by `gh pr create`.

If any of these are missing, the task is not complete — the Stop hook will reject the completion claim.

## Iteration budget

- Total: Moderate (3 iterations) before escalating.
- If Stage 1-3 (Go module) takes more than 90 minutes including TDD churn, pause and ask whether to simplify the symbol-extraction surface.
- If Stage 6 perf budget fails (>500ms), pause — do not add caching speculatively; investigate root cause first.

## What this plan deliberately does NOT include

- No JSON output mode, no daemon, no `gopls`.
- No TS/JS upgrade. The TS/JS path in `test-dep-map.sh` is untouched.
- No caching layer.
- No cross-package integration-test discovery beyond what the regex fallback already does.
- No subagent dispatch — this is small enough for inline TDD execution by one engineer.

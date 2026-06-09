# Completion Gate — Design (v2)

- **Date:** 2026-06-09
- **Status:** Draft **v2** — revised after 4-expert review + empirical Stop-hook probe (see `2026-06-09-spec-review-findings.md`)
- **Author:** Eduardo (with Claude)
- **Topic:** Deterministic Stop-hook that blocks ending a turn while unverified source edits exist
- **Origin:** "Skills … Control Loops Are" (Di Chen, NIM Factory) — enhancement #1: replace an LLM-judge completion check with a deterministic control-loop validator. The V-model **Coding↔Unit** verification pair.
- **Sibling:** `2026-06-09-done-hook-v2-acceptance-loop-design.md` (separate feature/PR).

## 1. Problem

The project's current completion check is an LLM-judge — a `"type": "prompt"` Stop hook
in `promptsLibrary/.claude/settings.json` ("did you claim completion without running
verification?"). That is the unreliable mechanism the source email warns against. The
CLAUDE.md rule it enforces — *"any response asserting task completion must contain the
output of a verification command"* — deserves a **deterministic** contract.

## 2. Trigger (locked): edit-triggered, cross-turn

Block ending a turn when an **unverified source edit** exists: a `Write`/`Edit`/`MultiEdit`
to a source file with **no passing build/test/lint after it**, anywhere in the session.
Cross-turn state closes the "edit on turns 1–3, declare done on a zero-edit turn 4" hole
(the panel DA's objection) without prose-claim regex. Rejected: claim-triggered (fragile),
hybrid (inherits the regex fragility).

## 3. Goals / Non-goals

**Goals:** deterministically prevent stopping with unverified source edits; make the block
**reason** the last instruction before exit; fail-open; loop-safe; reuse in-tree patterns.
**Non-goals (YAGNI):** no prose claim-detection; no coverage of no-file-edit imperative
changes (`kubectl apply`, migrations) — future separate trigger; no per-file verify mapping
(clear-all on any pass).

## 4. Architecture & placement

- **New:** `~/.claude/hooks/completion-gate.sh` (+ `completion-gate_test.sh`), wired into
  the **global** `~/.claude/settings.json` `Stop` array.
- **Kill-switch (FIRST executable line):** `[ "${COMPLETION_GATE:-on}" = "off" ] && exit 0`
  (convention mirrors `CLAUDE_PANEL=off`). [finding H4]
- **Block mechanism:** emit JSON on **stdout** and `exit 0`:
  `{"decision":"block","reason":"<reprompt>"}`. **Probe-verified** that this blocks the
  Stop and the `reason` reaches the model (CC 2.1.169); `exit 2`+stderr also works but JSON
  is structured/documented. [findings A1, probe §1]
- **Settings cleanup (surgical):** delete **only** the `"type":"prompt"` element from the
  project Stop array; **keep** the `context-watch`/`done-hook` command block, and de-dupe
  it (it currently appears in both global and project arrays → double-fire). A fixture must
  assert the command block survives. [finding M2]
- **Fail-open:** any internal error → `exit 0`.

## 5. Input

Stop-hook stdin JSON: `transcript_path`, `session_id`, `stop_hook_active`. Use the
transcript (authoritative ordered record) + `stop_hook_active` as a loop backstop (verified
to flip `false`→`true` on re-entry).

## 6. Core algorithm — corrected for the real transcript schema

The transcript is **nested**, not a flat event stream [finding A2]:
- Tool calls are `content[]` blocks with `type=="tool_use"` (`name` ∈ Write/Edit/MultiEdit/Bash,
  plus `id`) inside `type=="assistant"` messages.
- Tool results are `content[]` blocks with `type=="tool_result"` (`tool_use_id`, optional
  `is_error`) inside the **next `type=="user"`** message.

Walk messages in order, maintain set `unverified`; build a map `tool_use_id → is_error`:
1. `tool_use` Write/Edit/MultiEdit to a **source** path (not deny-listed) → add path(s).
   *(MultiEdit edits one `file_path`; still one path.)*
2. `tool_use` Bash whose command matches a **verify** pattern → look up its result by
   `tool_use_id`; if **`is_error != true`** (i.e. `false` **or absent** — success often omits
   the field) → clear `unverified` (clear-all). [finding D1 — the inverted-predicate bug]
3. At Stop, drop from `unverified` any path that (a) no longer exists, or (b) is `git`-clean
   vs `HEAD` (handles `edit→delete` and `edit→revert`). [finding H5]

`unverified` non-empty after step 3 ⇒ **block candidate**.
- A **failing** verify (`is_error == true`) does **not** clear — stopping after a red test is
  itself blocked.
- **Known residual (clear-all):** `go test … || true`, `go test -run NoSuchTest` (exit 0, ran
  nothing), or a cosmetic `go vet` will clear the set. Documented, accepted for v1; `vet`
  alone is **not** treated as sufficient to clear test-worthy edits. [finding M1]

## 7. Decision flow at Stop

```
[ "${COMPLETION_GATE:-on}" = "off" ] && exit 0          # kill-switch
parse transcript (nested) → unverified set → drop gone/git-clean paths
if unverified empty:                          exit 0     # verified / analysis-only turns
if last assistant msg has ^VERIFY-WAIVED:     exit 0 + log waiver
state_hash = sha(sorted paths + per-file CONTENT hash)  # NOT mtime [finding H5]
if (session_id, state_hash) already in ledger: exit 0 + log override   # debounce
else record + BLOCK:  print {"decision":"block","reason":"<§8>"}; exit 0
```

## 8. Block reason (must read as a legitimate engineering instruction)

Per the probe, an injection-shaped reprompt is refused. The `reason` names the files and the
action, as normal guidance — never "echo token X":
```
Completion gate: gpu.go, topology.go changed this session with no passing build/test/lint afterward.
Run the appropriate verification (e.g. `go test ./...`) and include its output before ending the turn.
If verification is genuinely impossible here, end your final message with:  VERIFY-WAIVED: <reason>
```

## 9. Configuration (embedded, tunable)

- **Source:** `.go .py .ts .tsx .js .jsx .rs .c .h .cc .cpp .java .rb .sh .bash`
- **Deny (never block):** `*.md *.txt LICENSE* .gitignore *.lock` + lockfiles
- **Verify:** `go (test|build|vet)`, `golangci-lint`, `make (test|build|lint|check|ci)`,
  `*_test.sh`, `bats`, `shellcheck`, `pytest`/`python -m pytest`, `npm (test|run build|run lint)`,
  `cargo (test|build|clippy)`
- **OPEN (needs decision):** `*.yaml/*.yml/*.json` excluded by default (no obvious "test";
  avoids false-blocks on K8s manifests). Include + add `kubeconform`/`helm lint`/`yamllint`?

## 10. Loop safety & observability

- **Content-hash debounce** (not mtime — `auto-format.sh` runs PostToolUse Write|Edit and
  perturbs mtime, which would re-arm the gate on identical content). Block once per distinct
  content state; identical re-stop → allow + log. [finding H5]
- `stop_hook_active` as backstop.
- **Per-decision log** (not just per-block): one JSON line `{ts, decision, reason, n_unverified,
  state_hash, latency_ms}` to `~/.claude/audit/completion-gate-YYYY-MM-DD.log` → derive
  block/waiver/override rates + a false-positive proxy (block immediately followed by waiver
  or identical-state re-stop). [finding M4]

## 11. Error handling

Missing/unreadable transcript, jq failure, empty/malformed → `exit 0` (fail-open) + one log
line. Parse the transcript by **event lines** (tiny), not a byte cap, so a long session's
earliest edit can't silently fall out of a 5 MB window. [finding L1]

## 12. Testing (TDD — must fail if gate logic removed)

`completion-gate_test.sh`; **at least one fixture is a REAL captured transcript slice**
(synthetic-only is how the `is_error` bug slipped past v1 — anti-pattern #4). Each case pipes
the hook its stdin and asserts on **stdout JSON** (`decision:block`), not exit code.

| # | Fixture | Expect |
|---|---|---|
| 1 | Edit `foo.go`, no verify | `decision:block`, reason names `foo.go` |
| 2 | Edit `foo.go` then passing `go test`, result **omits `is_error`** | no block (the D1 regression guard) |
| 2b | Edit `foo.go` then `go test` with `is_error:false` | no block |
| 3 | Edit early turn; final turn pure text, no verify | block (cross-turn) |
| 4 | Pure conversation, zero edits | no block |
| 5 | Edit `README.md` only | no block (deny-list) |
| 6 | Edit + **failing** `go test` (`is_error:true`) | block |
| 7 | Edit + `VERIFY-WAIVED: …` in final msg | no block, waiver logged |
| 8 | Identical content state already in ledger | no block (debounce) |
| 9 | Edit then revert (`git checkout`) → clean vs HEAD | no block [H5] |
| 10 | Edit then delete the file | no block, no crash [H5] |
| 11 | Edit + `auto-format` changes mtime, same content, already blocked | no block (content-hash debounce) [H5] |
| 12 | `COMPLETION_GATE=off` | no block (kill-switch) |
| 13 | Garbage `transcript_path` | no block (fail-open) |
| 14 | Real captured transcript slice (nested schema) | parses without error |

**Mutation check:** deleting the "unverified non-empty ⇒ block" branch breaks #1, #3, #6.

## 13. Logistics

Hook lives under `~/.claude/`; `enforce-worktree.sh` blocks `~/.claude` writes on
`agents-workbench`. Authored in worktree `.worktrees/completion-gate` (branch
`feat/completion-gate`). `writing-plans` sets solo-vs-team (likely **solo**: one script,
one test, one settings edit).

## 14. Decision Log

- **Trigger:** edit-triggered over claim/hybrid; cross-turn state closes the DA blind spot.
- **Stop mechanism (probe-verified):** JSON `decision:block`; both it and `exit 2` block in
  CC 2.1.169 — the reviewers' "exit 2 won't work for Stop" was empirically wrong.
- **`is_error` predicate corrected** to `!= true` (success rows often omit the field) — was a
  demonstrated false-block bug in v1.
- **Debounce on content hash, not mtime** (auto-format churn).
- **Drop deleted/git-clean paths** at Stop (revert/delete edge cases).
- **Kill-switch** `COMPLETION_GATE=off`; surgical removal of the project prompt-hook only.
- **Reprompt phrasing** must be legitimate engineering instruction (probe: injection-shaped
  reprompts are refused). The gate is a strong nudge, not a hard guarantee.
- **Real-transcript test fixture** mandatory.
- Scope: global; replaces (not duplicates) the LLM-judge.

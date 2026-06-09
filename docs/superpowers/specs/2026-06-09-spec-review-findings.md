# Spec Review Findings — Completion Gate & Done-Hook v2

- **Date:** 2026-06-09
- **Inputs:** the two design specs + the current harness (`~/.claude/hooks/`, `validate-recommendation/panel/`, project `settings.json`).
- **Reviewers:** 4 parallel expert subagents — Claude Code mechanics, agentic control-loops, LLM-as-judge reliability, SRE/pragmatic — plus an **empirical Stop-hook contract probe**.
- **Verdicts:** completion-gate = **REVISE** (shippable after fixes) · done-hook-v2 = **RETHINK** (foundation assumptions verified false).

## 1. Empirical probe — Stop-hook reprompt contract (DECISIVE)

**Method:** two isolated headless `claude -p` sessions (CC 2.1.169), each wiring one probe Stop hook; counted hook fires + whether an injected token reached the model.

**Result:**
```
[JSON  {"decision":"block","reason"}]  fired=2  → blocked the stop; model REFUSED (cited prompt-defense; reason was injection-shaped)
[EXIT 2 + stderr]                       fired=2  → blocked the stop; model COMPLIED (token present)
stop_hook_active: false (1st attempt) → true (re-entry after block)
```

**Conclusions:**
1. **Both `exit 2`+stderr AND JSON `{"decision":"block","reason":…}` block a Stop and deliver the reason.** The reviewers' doc-based claim ("exit 2 is PostToolUse-only; Stop needs JSON; no in-tree precedent") is **empirically false in 2.1.169.** (Probe > docs — anti-pattern #4 earned its keep.)
2. **Chosen mechanism: JSON `decision:block`** (structured, documented, `reason` is purpose-built). `exit 2` is a viable fallback.
3. **`stop_hook_active` flips `false`→`true` on re-entry** — usable loop guard, as planned.
4. **CRITICAL lesson:** a Stop hook **forces another turn but cannot force compliance.** An injection-shaped reprompt is (correctly) refused under the active prompt-defense rules. **Reprompts must read as legitimate, specific engineering instructions** (`"you edited gpu.go but ran no tests; run go test ./..."`), never "echo token X." The loop is a **strong nudge, not a guarantee** → budget cap + `VERIFY-WAIVED` escape retained by design.

Probe rig: `/tmp/claude-stop-probe/`.

## 2. Consensus findings (deduped, severity-ranked)

**Demonstrated** = an expert executed code/transcripts. **Disposition:** v2 = folded into completion-gate v2 · DH2 = deferred to done-hook-v2 rework · HARNESS = new workstream.

| ID | Sev | Spec | Demo? | Finding | Fix | Disp |
|---|---|---|---|---|---|---|
| D1 | CRIT | completion-gate | ✅ | `is_error == false` inverted; ~60–65% of *success* rows OMIT `is_error` → false-blocks the common path | predicate = `is_error != true` (clear unless explicitly errored) | **v2** |
| A1 | CRIT | both | ✅(probe) | Stop reprompt mechanism uncertain | JSON `decision:block` (exit 2 also works) | **v2** + DH2 |
| A2 | CRIT | both | ◑ | transcript is **nested** (tool_use in `assistant.content[]`; result in *next* `user` msg by `tool_use_id`), not a flat event stream | rewrite parser to nested walk | **v2** + DH2 |
| H5 | HIGH | completion-gate | ◑ | mtime debounce defeated by `auto-format.sh` churn; `edit→delete` blocks a gone file; `edit→revert` blocks clean content | content-hash not mtime; drop nonexistent + `git`-clean paths | **v2** |
| H4 | HIGH | both | ◑ | no kill-switch | `COMPLETION_GATE=off` / `DONE_LOOP=on` (1 line) | **v2** + DH2 |
| M1 | MED | completion-gate | ◑ | clear-all `mis-clears`: `go test … \|\| true`, `-run NoSuchTest` (exit 0, ran nothing), cosmetic `go vet` clears unrelated edits | document residual; don't treat `vet` alone as sufficient | **v2** |
| M2 | MED | both | ✅ | project `settings.json` duplicates the `context-watch`/`done-hook` command block → double-fire | remove **only** the `type:prompt` element; de-dupe the command block | **v2** |
| M4 | MED | both | — | observability: per-*decision* log w/ `latency_ms`, derive block/waiver/override rates | structured decision log | **v2** + DH2 |
| L1 | LOW | completion-gate | ◑ | 5 MB byte-cap can truncate the earliest unverified edit | track event lines, not bytes | **v2** |
| D2 | CRIT | done-hook-v2 | ✅ | the 60s timeout is **dead code** (`timeout_seconds` parsed, never passed to `ChatNVIDIA`) → hung call wedges turn-end unbounded | shell `timeout 60` wrapper + settings `"timeout"` | DH2 |
| D3 | CRIT | done-hook-v2 | ✅ | "reuse `panel dispatch`" breaks the verdict contract: `_format_verdict` emits only `VERDICT/RATIONALE/ALTERNATIVE` w/ closed vocab `HOLD\|OVERTURN\|ERROR`; **`NEXT-STEPS` dropped**, `PASS/CONTINUE/DATA-WALL` coerced to `ERROR` | extend panel verdict schema *with tests*, OR thin new dispatch entrypoint | DH2 |
| D4 | CRIT | done-hook-v2 | ✅ | `python -m panel` → `ModuleNotFoundError` from a hook shell | `PYTHONPATH=~/.claude/skills/validate-recommendation …` + real-resolution test | DH2 |
| D5 | CRIT | done-hook-v2 | ✅ | `dispatch` returns exit 0 on outage (writes `VERDICT: ERROR`) | fail-open on verdict-file *content*, not exit code | DH2 |
| A3 | CRIT | done-hook-v2 | ◑ | prompt-injection: judge ingests untrusted tool output; `VERDICT: PASS` is the fail-open attacker win | frame transcript as DATA, delimiter-wrap, defang `^VERDICT:`/`^NEXT-STEPS:`, log raw | DH2 |
| H2 | HIGH | done-hook-v2 | ◑ | "bias to PASS on ambiguity" inverts the email's lever (waves through plausible half-done work) | CONTINUE on a *named reachable* gap; reserve DATA-WALL (not PASS) for ambiguity; budget bounds UX | DH2 |
| H3 | HIGH | done-hook-v2 | ✅ | temp 0.3 → non-reproducible gatekeeper; debounce *freezes* a bad draw | temp 0 (+ optional k=3 self-consistency); separate panelist entry | DH2 |
| M3 | MED | done-hook-v2 | ◑ | transcript tail sent to external endpoint with no redaction (bash-audit-log redacts only for *local* logs) | redact digest before dispatch; document fields sent | DH2 |
| M5 | MED | done-hook-v2 | ◑ | `nemotron-3-ultra` + `max_tokens 32768` over-powered for a 3-line verdict; raises ramble→parse-fail | smallest tier that holds calibration; cap `max_tokens ~512` | DH2 |
| H1 | HIGH | both | — | **No behavioral regression harness** — the actual 20%→93% lever (sim/scenarios scoring agent *behavior* + a labeled calibration eval). Both specs only unit-test the parser. | build the harness; gate both features' merge on it | **HARNESS** |

## 3. Scope gap (the owner's full ambition)

The two specs cover only **Coding↔Unit** (completion-gate) + **Requirements↔Acceptance** (done-hook-v2). PR-review, doc, and ADR quality map to **unbuilt** loops — same "deterministic shell, LLM only for the semantic core" pattern:
- **ADR/design loop (Design↔Integration):** grep-gate required sections + the `>=3 options` rule; then adversarial "name a decision with no alternative/consequence" reviewer.
- **Doc-quality loop:** dead-link check, fenced-code tags, documented `make` targets exist — mostly deterministic, no LLM.
- **PR-review-depth loop:** deterministic pre-gate = every file in `git diff --name-only` is mentioned in the review; then the literal data-wall reviewer ("is there a reachable next probe?").

## 4. Revision plan

1. ✅ **Probe the Stop-hook contract** — DONE (§1).
2. **Revise + ship completion-gate** (v2 fixes folded) — *in progress*.
3. **Rework done-hook-v2** behind `DONE_LOOP=on` (default-OFF soak): D2–D5, A2, A3, H2, H3, M3, M5.
4. **Build the behavioral regression harness** (H1) — the real lever; gate merges on it.
5. **Add the 3 missing loops** (§3) for the full ambition.

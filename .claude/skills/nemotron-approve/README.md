# nemotron-approve

PreToolUse hook for Claude Code that auto-approves non-destructive tool calls via a three-lane classifier:

1. **Lane A — ALLOW regex** (instant approve, no LLM): kubectl read verbs, gh read+author writes, git read, npm/pnpm/yarn family, etc.
2. **Lane B — DENY regex** (always ASK, never auto-approve): rm -rf, sudo, force-push, pipe-to-shell, package publish.
3. **Lane C — LLM gray zone** (Nemotron via nvidia-nat): everything else.

Defense-in-depth: Lane B re-applies after Lane C allow.

## Env vars

| Var | Required | Default |
|---|---|---|
| `NEMOTRON_APPROVE_API_KEY` | yes | — |
| `NEMOTRON_APPROVE_ENDPOINT` | yes | — |
| `NEMOTRON_APPROVE_MODEL` | yes | — |
| `NEMOTRON_APPROVE_TIMEOUT` | no | 10 |
| `NEMOTRON_APPROVE_DISABLED` | no | 0 |
| `NEMOTRON_APPROVE_CACHE_TTL` | no | 3600 |
| `NEMOTRON_APPROVE_TRACE` | no | 1 |

## Smoke-test results (phase-2, post-PR-#14)

Verified 2026-05-20 after merging PR #14 (env.sh + httpx[socks] fix) and bumping `NEMOTRON_APPROVE_TIMEOUT` from 10s to 30s in env.sh.

Trace window: last 200 entries in `~/.claude/debug/nemotron-approve-trace.log`.

- Auto-approval rate: **88.5%** (target ≥85%).
- Post-bump timeout count: **0** (env.sh mtime 2026-05-20T18:21Z; the 3 `rationale="timeout"` entries still in the window all predate the bump).
- `rationale="llm_unconfigured"` count: **0** (Bug 2 — `KeyError: 'NEMOTRON_APPROVE_*'` in subprocess env — fixed).
- `client_error: ImportError` count: **0** (Bug 1 — `httpx` missing SOCKS support — fixed by `httpx[socks]`).

5-shot Lane C stress test from a fresh session, novel commands defeating the verdict cache:

| command | lane | decision | latency_ms |
|---|---|---|---|
| `terraform plan -var marker=$UNIQ-A` | C | allow | 4097 |
| `aws s3 ls s3://bucket-$UNIQ-B` | C | allow | 3316 |
| `kubectl get pods --namespace=nonexistent-$UNIQ-C` | A (kubectl-read) | allow | 0 |
| `wasm-pack build --release --features marker-$UNIQ-D` | C | ask (mutating) | 3379 |
| `deno run --allow-read=. mod-$UNIQ-E.ts` | C | ask (mutating) | 4999 |

Lane C max latency 4999ms — comfortably under the 30s budget. The two asks are LLM-judged "mutating" (Cargo build scripts in wasm-pack pull/run external `build.rs`; deno scripts are arbitrary code execution). Both are correct supply-chain / arbitrary-code-execution flags, not infrastructure failures.

## Troubleshooting

- `tail ~/.claude/debug/nemotron-approve-trace.log` — see every decision.
- `rm -rf $TMPDIR/nemotron-approve-cache` — invalidate cache after editing patterns.py.
- Set `NEMOTRON_APPROVE_DISABLED=1` to disable Lane C; Lane A/B still run.

Spec: `docs/superpowers/specs/2026-05-17-nemotron-approve-design.md` in promptsLibrary.

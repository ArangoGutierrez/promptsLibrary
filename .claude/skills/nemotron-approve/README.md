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

## Troubleshooting

- `tail ~/.claude/debug/nemotron-approve-trace.log` — see every decision.
- `rm -rf $TMPDIR/nemotron-approve-cache` — invalidate cache after editing patterns.py.
- Set `NEMOTRON_APPROVE_DISABLED=1` to disable Lane C; Lane A/B still run.

Spec: `docs/superpowers/specs/2026-05-17-nemotron-approve-design.md` in promptsLibrary.

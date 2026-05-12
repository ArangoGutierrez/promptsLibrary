# validate-recommendation

A Claude Code skill that validates `(Recommended)` options in
`AskUserQuestion` calls by dispatching two parallel panelists. Auto-takes
the recommendation when both panelists agree; surfaces dissent in the
question text when they disagree.

## How it works

1. The `validate-recommendation.sh` `PreToolUse` hook watches every
   `AskUserQuestion` call.
2. If any option label contains `(Recommended)` (and not
   `Panel-flagged`), the hook writes the tool input to a session state
   file and exits 2 (block) with a stderr message instructing Claude to
   invoke this skill.
3. The skill dispatches two panelists in parallel:
   - **Devil's Advocate (DA)** — via `dispatch-da.sh`, which POSTs the
     panelist prompt to a user-configured OpenAI-compatible chat
     completions endpoint. Independent reasoner from a different model
     family than Claude.
   - **Principal Engineer (PE)** — via the `Agent` tool with
     `subagent_type: principal-engineer`. Has tool access (Read, Grep,
     Glob, Bash) so it can consult `~/.claude/CLAUDE.md` and
     `~/.claude/rules/` files directly.
4. `aggregate.sh` parses the two verdict files and emits one of:
   - `PANEL_VERDICT: HOLD` — Claude auto-proceeds with the recommendation
   - `PANEL_VERDICT: DISSENT` — Claude re-asks with dissent summary
   - `PANEL_VERDICT: ERROR` — Claude asks original question unmodified

## Configuration

### Required environment variables

These three MUST be set in your shell init (e.g., `~/.bashrc` or
`~/.zshrc`) for the DA backend. If any is unset, the DA panelist emits
an ERROR verdict and the panel falls back to asking the original
question unmodified.

| Variable | Effect |
|----------|--------|
| `PANEL_DA_API_KEY` | Bearer token for the chat completions endpoint. |
| `CLAUDE_PANEL_DA_ENDPOINT` | Full URL of an OpenAI-compatible `/v1/chat/completions` (or equivalent). Examples: `https://api.openai.com/v1/chat/completions`, `https://api.anthropic.com/v1/messages` (if compatible), `http://localhost:11434/v1/chat/completions` (Ollama), or your enterprise inference endpoint. Must be `https://` unless it's `http://localhost` / `http://127.0.0.1`. |
| `CLAUDE_PANEL_DA_MODEL` | Model identifier the endpoint expects (e.g., `gpt-4o-mini`, `llama3.1:70b`, or whatever your provider supports). |

### Optional environment variables

| Variable | Default | Effect |
|----------|---------|--------|
| `CLAUDE_PANEL` | `on` | Controls panel behavior. `on` (default) auto-takes the recommendation on HOLD. `advise` runs the panel but re-asks every question with the panel's commentary appended — preserves user agency at the cost of one extra click per question. `off` bypasses the panel entirely (hook exits without dispatching). |
| `CLAUDE_PANEL_TIMEOUT` | `90` | Per-panelist timeout (seconds). |
| `CLAUDE_PANEL_DA_TIMEOUT` | `60` | curl `--max-time` for the DA HTTP call (seconds). |
| `CLAUDE_PANEL_TRACE_LOG` | `~/.claude/debug/panel-trace.log` | Path the hook and aggregator append verdict telemetry to. The trace log is **always written** (one line per trigger, one line per verdict) so the operator can detect silent decay (e.g., the DA backend quietly rate-limiting → every recommendation hits ERROR → user sees no change without the log). Override path for tests or alternative routing. |
| `CLAUDE_PANEL_DEBUG` | unset | If set, the hook writes extra verbose lines to the trace log on top of the always-on telemetry. |
| `CLAUDE_PANEL_DA_MOCK_FILE` | unset | TEST USE ONLY. Path to a JSON file; `dispatch-da.sh` reads the response from this file instead of calling curl. Used by `dispatch-da_test.sh`. Do not set in normal use. |

### One-off bypass

To disable the panel for a single session:

```bash
CLAUDE_PANEL=off claude
```

The hook exits immediately without dispatching panelists.

To preserve user agency while keeping the panel's audit value:

```bash
CLAUDE_PANEL=advise claude
```

Panel still runs and writes telemetry. On HOLD verdicts, the question
is re-issued with a `**Panel validated:**` note appended — the user
picks every answer but gets the panel commentary alongside.

## Cost

Each panel dispatch invokes two backends:

- **DA (external HTTPS API)**: ~100-200 prompt tokens (question +
  options + persona) + up to 1024 completion tokens. If the configured
  model is a reasoning model that emits a `reasoning_content` field,
  a meaningful share of the completion budget goes there (we discard
  it). Typical real call: 500-800 completion tokens.
- **PE (Claude `principal-engineer` subagent)**: full subagent context.
  Per the persona prompt, the subagent uses tools (Read, Grep, Glob) to
  consult `~/.claude/CLAUDE.md` and `~/.claude/rules/*.md` before
  rendering a verdict. Realistically 5-15k tokens per invocation
  including the rule-file reads.

Rough per-trigger order of magnitude: **~700 DA tokens + ~10k Claude
tokens.** Across a session with 5-10 recommendation triggers, expect
5-15k DA tokens and 50-150k Claude tokens of panel cost on top of the
main session usage.

If panel cost matters for your workload:

- `CLAUDE_PANEL=off` to bypass entirely (saves all panel cost).
- `CLAUDE_PANEL=advise` keeps the panel running but means user-visible
  questions are NOT auto-resolved; cost is the same but you trade an
  extra click for more agency.
- Monitor actual usage via the trace log:
  `grep -c 'event=trigger' ~/.claude/debug/panel-trace.log`

## Files

```
.claude/
├── hooks/
│   ├── validate-recommendation.sh       (hook; deploys to ~/.claude/hooks/)
│   └── validate-recommendation_test.sh  (hook tests; 8 cases)
└── skills/validate-recommendation/
    ├── SKILL.md           (orchestration instructions Claude follows)
    ├── personas.md        (DA + PE persona prompts)
    ├── dispatch-da.sh     (HTTP wrapper for the DA backend)
    ├── dispatch-da_test.sh (dispatch-da tests; 14 cases)
    ├── aggregate.sh       (verdict parser; emits HOLD/DISSENT/ERROR)
    ├── aggregate_test.sh  (aggregator tests; 7 cases)
    ├── fixtures/          (verdict + DA response fixtures)
    └── README.md          (this file)
```

## Running the test suites

From this skill's directory (or the worktree root):

```bash
.claude/skills/validate-recommendation/aggregate_test.sh
.claude/skills/validate-recommendation/dispatch-da_test.sh
.claude/hooks/validate-recommendation_test.sh
```

All three should print `PASS` and exit 0. None require the real API
(dispatch-da tests use `CLAUDE_PANEL_DA_MOCK_FILE` to inject mock
responses; the argv-leak test uses a mock curl binary).

## E2E smoke test (post-install)

After running `./scripts/deploy.sh` to sync this skill to `~/.claude/`:

1. Confirm the three required DA-backend env vars are set:
   ```bash
   for v in PANEL_DA_API_KEY CLAUDE_PANEL_DA_ENDPOINT CLAUDE_PANEL_DA_MODEL; do
       eval "val=\${$v:-}"; [ -n "$val" ] && echo "$v: set" || echo "$v: MISSING"
   done
   ```
   If any are MISSING, add to `~/.bashrc` / `~/.zshrc`. The panel will
   emit ERROR for every recommendation until all three are set.

2. Confirm `CLAUDE_PANEL` is unset (default = on):
   ```bash
   echo "${CLAUDE_PANEL:-on}"
   ```
   Should print `on`.

3. Open a fresh Claude Code session.

4. Prompt the assistant for a recommendation that triggers
   `AskUserQuestion`, e.g.:
   > "Recommend an HTTP client for a Go service that needs retries.
   > Show 3 options."

5. Verify behavior:
   - The assistant should announce that it's running the panel before
     surfacing any user-facing question.
   - On HOLD: the assistant prints the panel rationales and proceeds
     without showing the question. You never see the `AskUserQuestion`
     UI for that decision.
   - On DISSENT: the question shows up with a `**Panel review:**` line
     appended.

6. Inspect the trace log:
   ```bash
   tail -n 20 ~/.claude/debug/panel-trace.log
   ```
   Should contain `event=trigger` and `event=verdict` lines.

7. Run with bypass to verify the off-switch:
   ```bash
   CLAUDE_PANEL=off claude
   ```
   Same prompt as step 4 — the panel should NOT fire; the question
   appears immediately with the original options.

## Real-API smoke test (one-off)

After install, you can confirm the DA backend works end-to-end without
running a full Claude session:

```bash
PROMPT=$(mktemp)
cat > "$PROMPT" <<'EOF'
You are a devil's-advocate reviewer. Output ONLY:
VERDICT: <HOLD|OVERTURN>
RATIONALE: <one paragraph>
ALTERNATIVE: <option label or n/a>

Question: Which HTTP client should we use in Go?
Options:
  Option A (Recommended) — net/http
  Option B — resty
Assistant's recommended option: Option A (Recommended)
EOF

OUT=$(mktemp)
~/.claude/skills/validate-recommendation/dispatch-da.sh \
    --prompt-file "$PROMPT" --output "$OUT"

cat "$OUT"
rm -f "$PROMPT" "$OUT"
```

Expected: the output file contains a VERDICT/RATIONALE/ALTERNATIVE
triple from the configured DA backend. If you see `VERDICT: ERROR`,
check the rationale line for the failure mode (most likely a missing
required env var, or `HTTP call failed`).

## Troubleshooting

**Is the panel actually working?** Check the trace log:

```bash
tail -n 20 ~/.claude/debug/panel-trace.log
grep -c 'outcome=HOLD' ~/.claude/debug/panel-trace.log
grep -c 'outcome=DISSENT' ~/.claude/debug/panel-trace.log
grep -c 'outcome=ERROR' ~/.claude/debug/panel-trace.log
```

If trigger count is 0 the panel is not firing (see "panel never fires"
below). If ERROR count is high while HOLD/DISSENT are 0, the panel is
firing but every dispatch is failing — most likely the DA-backend env
vars aren't set or the endpoint is unreachable.

**The panel never fires.** Check that the hook is registered in
`~/.claude/settings.json` under `hooks.PreToolUse` with matcher
`AskUserQuestion`. Run `jq '.hooks.PreToolUse[] | select(.matcher == "AskUserQuestion")' ~/.claude/settings.json` to verify.

**Every recommendation hits the ERROR path.** Most likely
`PANEL_DA_API_KEY`, `CLAUDE_PANEL_DA_ENDPOINT`, or
`CLAUDE_PANEL_DA_MODEL` is unset. Set them in your shell init.
Alternative: the endpoint is unreachable, rate-limiting, or rejecting
the model name.

**The PE panelist doesn't seem to be reading rules/.** The PE prompt
in `personas.md` explicitly instructs the subagent to USE TOOLS to
consult rule files. If it's not happening, inspect the Agent's response
saved to `${TMPDIR}/panel-pe-verdict-*-q*.txt` — the subagent may be
producing a stub response. Tune the persona prompt if needed.

**Auto-take is too aggressive / too conservative.** Adjust the panel
prompts in `personas.md`. The DA's HOLD/OVERTURN semantics are defined
explicitly there; if your DA model is gaming the format, expand the
one-shot example. The aggregator's logic is hard-coded — adjust the
verdict fixtures + aggregate.sh together if you want a different
combining rule.

## Uninstall

1. Remove the matcher block from `.claude/settings.json` under
   `hooks.PreToolUse` (the entry pointing at
   `validate-recommendation.sh`).
2. Delete the skill and hook files:
   ```bash
   rm -rf .claude/skills/validate-recommendation/
   rm -f .claude/hooks/validate-recommendation.sh \
         .claude/hooks/validate-recommendation_test.sh
   ```
3. Re-run `./scripts/deploy.sh` (or hand-delete from `~/.claude/`).

## Security notes

- `PANEL_DA_API_KEY` is read by `dispatch-da.sh` at runtime via
  `${PANEL_DA_API_KEY}`. It is NEVER written to any file in the repo,
  never logged in trace output, never echoed in error messages. The
  Authorization header is passed to curl via a `umask 077` temp file
  using curl's `-H @<file>` syntax so the key does not appear in
  process argv (visible via `ps auxe` / `/proc/<pid>/cmdline`). The
  temp file is removed by a trap on every exit path.
- `dispatch-da.sh` redirects `curl`'s stderr to `/dev/null` to prevent
  any URL or header leakage in case of failure.
- The state file and verdict files are created with `umask 077` so
  they are mode 0600 (user-only readable).
- Threat model: anyone who can edit your shell init can change
  `CLAUDE_PANEL_DA_ENDPOINT` to a capture host AND any allowlist /
  validation in this script. The https-only check in dispatch-da.sh
  exists to catch typos, not adversarial redirection. If your shell
  init is compromised, your bearer token can be exfiltrated regardless.
- The panel verdict files (`panel-da-verdict-*.txt`,
  `panel-pe-verdict-*.txt`) live in `$TMPDIR` and are deleted by the
  skill after the verdict directive is applied. If the skill crashes
  mid-execution, stale files persist until the next session (which uses
  a different `CLAUDE_SESSION_ID`).
- Prompt files written for the DA call may contain the user's question
  and the assistant's recommendation. They live in `$TMPDIR`,
  inherit umask 077 from the hook, and are cleaned up like the verdict
  files. **Note**: prompts are POSTed to the user-configured external
  endpoint — choose a DA backend you trust with the content of your
  Claude sessions.
- The hook fails open: any error in hook bash logic results in `exit 0`
  (approve). This prevents broken hooks from blocking
  `AskUserQuestion` entirely.

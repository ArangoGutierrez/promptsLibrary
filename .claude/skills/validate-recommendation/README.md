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
     panelist prompt to the NVIDIA inference API (default model:
     `nvidia/nvidia/nemotron-3-super-v3`). Independent reasoner from a
     different model family.
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

| Variable | Required? | Effect |
|----------|-----------|--------|
| `NVIDIA_INFERENCE_API_KEY` | Required for DA backend | API key for the NVIDIA inference endpoint. If unset, the DA panelist emits an ERROR verdict and the panel falls back to asking the original question. Set this in `~/.bashrc` (or your shell init) so it's available in every session. |

### Optional environment variables

| Variable | Default | Effect |
|----------|---------|--------|
| `CLAUDE_PANEL` | `on` | Set to `off` to bypass the panel entirely (hook exits without dispatching). |
| `CLAUDE_PANEL_TIMEOUT` | `90` | Per-panelist timeout (seconds). |
| `CLAUDE_PANEL_DA_ENDPOINT` | `https://inference-api.nvidia.com/v1/chat/completions` | NVIDIA inference API URL. Override for offline testing with a mock server. |
| `CLAUDE_PANEL_DA_MODEL` | `nvidia/nvidia/nemotron-3-super-v3` | Model identifier sent in the API request. |
| `CLAUDE_PANEL_DA_TIMEOUT` | `60` | curl `--max-time` for the DA HTTP call (seconds). |
| `CLAUDE_PANEL_DEBUG` | unset | If set, hook writes trace lines to `~/.claude/debug/panel-trace.log`. |
| `CLAUDE_PANEL_DA_MOCK_FILE` | unset | TEST USE ONLY. Path to a JSON file; `dispatch-da.sh` reads the response from this file instead of calling curl. Used by `dispatch-da_test.sh`. Do not set in normal use. |

### One-off bypass

To disable the panel for a single session:

```bash
CLAUDE_PANEL=off claude
```

The hook exits immediately without dispatching panelists.

## Files

```
.claude/
├── hooks/
│   ├── validate-recommendation.sh       (hook; deploys to ~/.claude/hooks/)
│   └── validate-recommendation_test.sh  (hook tests; 7 cases)
└── skills/validate-recommendation/
    ├── SKILL.md           (orchestration instructions Claude follows)
    ├── personas.md        (DA + PE persona prompts)
    ├── dispatch-da.sh     (HTTP wrapper for Nemotron DA backend)
    ├── dispatch-da_test.sh (dispatch-da tests; 10 cases)
    ├── aggregate.sh       (verdict parser; emits HOLD/DISSENT/ERROR)
    ├── aggregate_test.sh  (aggregator tests; 6 cases)
    ├── fixtures/          (verdict + Nemotron response fixtures)
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
responses).

## E2E smoke test (post-install)

After running `./scripts/deploy.sh` to sync this skill to `~/.claude/`:

1. Confirm `NVIDIA_INFERENCE_API_KEY` is set in your shell:
   ```bash
   [ -n "$NVIDIA_INFERENCE_API_KEY" ] && echo "API key set" || echo "API key MISSING"
   ```
   If MISSING, add to `~/.bashrc` or shell init. The panel will emit
   ERROR for every recommendation until the key is set.

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

6. Inspect for errors:
   ```bash
   ls -lt ~/.claude/debug/panel-trace.log 2>/dev/null
   ```
   If `CLAUDE_PANEL_DEBUG=1` was set, this file contains one line per
   panel trigger. Otherwise it doesn't exist.

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
triple from Nemotron. If you see `VERDICT: ERROR`, check the rationale
line for the failure mode (most likely "NVIDIA_INFERENCE_API_KEY env var
unset" or "HTTP call failed").

## Troubleshooting

**The panel never fires.** Check that the hook is registered in
`~/.claude/settings.json` under `hooks.PreToolUse` with matcher
`AskUserQuestion`. Run `jq '.hooks.PreToolUse[] | select(.matcher == "AskUserQuestion")' ~/.claude/settings.json` to verify.

**Every recommendation hits the ERROR path.** Most likely
`NVIDIA_INFERENCE_API_KEY` is unset. Set it in `~/.bashrc`. Alternative:
`CLAUDE_PANEL_DA_ENDPOINT` is pointing somewhere unreachable or the
endpoint is rate-limiting.

**The PE panelist doesn't seem to be reading rules/.** The PE prompt
in `personas.md` explicitly instructs the subagent to USE TOOLS to
consult rule files. If it's not happening, inspect the Agent's response
saved to `${TMPDIR}/panel-pe-verdict-*-q*.txt` — the subagent may be
producing a stub response. Tune the persona prompt if needed.

**Auto-take is too aggressive / too conservative.** Adjust the panel
prompts in `personas.md`. The DA's HOLD/OVERTURN semantics are defined
explicitly there; if Nemotron is gaming the format, expand the one-shot
example. The aggregator's logic is hard-coded — adjust the verdict
fixtures + aggregate.sh together if you want a different combining
rule.

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

- `NVIDIA_INFERENCE_API_KEY` is read by `dispatch-da.sh` at runtime via
  `${NVIDIA_INFERENCE_API_KEY}`. It is NEVER written to any file in the
  repo, never logged in trace output, never echoed in error messages.
- `dispatch-da.sh` redirects `curl`'s stderr to `/dev/null` to prevent
  any URL or header leakage in case of failure.
- The panel verdict files (`panel-da-verdict-*.txt`,
  `panel-pe-verdict-*.txt`) live in `$TMPDIR` and are deleted by the
  skill after the verdict directive is applied. If the skill crashes
  mid-execution, stale files persist until the next session (which uses
  a different `CLAUDE_SESSION_ID`).
- Prompt files written for the DA call may contain the user's question
  and the assistant's recommendation. They live in `$TMPDIR` and are
  cleaned up like the verdict files. If your `$TMPDIR` is shared (e.g.,
  multi-user system), consider tightening permissions.
- The hook fails open: any error in hook bash logic results in `exit 0`
  (approve). This prevents broken hooks from blocking
  `AskUserQuestion` entirely.

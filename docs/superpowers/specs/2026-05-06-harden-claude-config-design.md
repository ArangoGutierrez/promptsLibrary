# Harden ~/.claude Config — Design

**Date:** 2026-05-06
**Scope:** `~/.claude` live configuration (hooks, skills, settings)
**Out of scope:** `~/.cursor` (queued separately, see Task #5), repo PR cycle (downstream of local fixes)

## Problem

Two streams of work merge into one design:

1. **Bug fixes from PR #5 review** (Thread A) — four real defects verified in the live config.
2. **SOTA hardening from May 2026 research** (Thread B Layer A) — five Claude Code daily-driver improvements identified as missing.

Plus a new requirement raised during brainstorming:

3. **Context handoff at ~90%** — automatic detection + assisted handoff to a fresh session.

Total: 10 items, one skipped, 9 in scope.

## Items

### Stage 1 — Mechanical fixes (items 1-4)

Diff-only. No design surface.

**1. `bash-audit-log.sh` — credential redaction.**
Add a redaction step before append. Pattern: mask URL-embedded credentials and common flag-passed secrets.

```bash
COMMAND=$(echo "$COMMAND" | /usr/bin/sed -E \
  -e 's,://[^/]*:[^@/]*@,://<redacted>@,g' \
  -e 's,(--?(token|password|api[-_]?key|secret)[= ])[^ ]+,\1<redacted>,gi')
```

Catches: `https://user:TOKEN@host`, `--token=X`, `--password X`, `--api-key=X`, `--secret X`.

**2. `tdd-guard.sh:88` — narrow C/H exemption.**
Change blanket exemption to CGo-bridge-scoped:

```diff
-    *.h|*.c)            exit 0 ;;
+    */bridge/*.h|*/bridge/*.c) exit 0 ;;
```

**3. `team-shutdown/SKILL.md` — naming consistency.**
Replace-all `Distinguished Systems Engineer` → `Principal Engineer`, then `Distinguished Engineer` → `Principal Engineer`. 10 occurrences. Aligns with team-plan and team-execute.

**4. `reflection-staleness.sh` — guard fallback.**
After line 19, add:

```bash
[ "$LAST_RUN_EPOCH" -eq 0 ] && exit 0
```

Skip the staleness check entirely when the timestamp file is corrupted or unparseable.

### Stage 2 — Defensive hooks (items 5, 7, 10)

#### 5. Blocking `PreCompact` hook (signal: hybrid)

**Current:** `pre-compact-context.sh` always exits 0, emits preservation instructions.
**Change:** make it conditionally exit 2 (block) when state preservation is at risk.

**Block signal (decision: hybrid):**
Exit 2 if BOTH (a) `~/.claude/audit/.last-checkpoint` is older than 30 minutes AND (b) at least one git worktree under `.worktrees/` has uncommitted changes to source files.

**Pseudocode:**

```bash
CHECKPOINT="$HOME/.claude/audit/.last-checkpoint"
STALE_MIN=30

# Default: emit instructions and allow (existing behavior)
emit_preservation_instructions

# Hybrid block: only when both conditions trigger
if checkpoint_stale "$CHECKPOINT" "$STALE_MIN" && any_worktree_dirty; then
    echo "BLOCKED: checkpoint stale (>${STALE_MIN}m) AND uncommitted source changes detected." >&2
    echo "Either: (1) commit pending work, (2) run /checkpoint to refresh, or (3) accept and re-run with SKIP_PRECOMPACT_GATE=1" >&2
    exit 2
fi

exit 0
```

**Helpers:**
- `checkpoint_stale`: compare mtime of `$CHECKPOINT` to `now - $STALE_MIN min`.
- `any_worktree_dirty`: iterate `git worktree list --porcelain`, run `git -C <path> diff --quiet` on each, return true if any has staged or unstaged source changes (exclude docs/, .agents/, .worktrees/).

**Checkpoint refresh:** `touch $CHECKPOINT` on save events. A new `/checkpoint` skill (out of scope here, follow-up) makes this explicit.

**Escape hatch:** `SKIP_PRECOMPACT_GATE=1` env var to bypass.

#### 7. `PermissionDenied` hook (behavior: log + suggest)

**New hook:** `~/.claude/hooks/permission-denied.sh`. Wired in settings.json under `PermissionDenied` (verify event name in current Claude Code version during implementation).

**Behavior:**
1. Append to `~/.claude/audit/permission-denials-YYYY-MM-DD.log` (same rotation as bash-audit-log).
2. Emit a one-line stderr hint based on the denied tool:
   - `Bash` denied → `Hint: tool not in allow list. Add to settings.json permissions.allow or use /sandbox.`
   - `WebFetch` denied → `Hint: domain not allowlisted. Add to remote-settings.json sandbox.network.allowedDomains.`
   - Default → `Hint: tool denied. Check settings.json permissions and managed-settings deny list.`

**Exit 0 always** — informational, never blocks.

**Log format (same as bash-audit-log):**

```
2026-05-06T14:30:00Z | session:abc123 | tool:Bash | reason:not_in_allow_list | input:gh pr view 5
```

#### 10. Context handoff at 90% (mechanism: Stop-hook + skill)

**Two artifacts:**

##### 10a. New skill `~/.claude/skills/handoff/SKILL.md`

User-invocable. Generates a structured handoff prompt for a fresh session. Output to stdout (user copies) and to `~/.claude/audit/handoffs/YYYY-MM-DD-HHMM-handoff.md`.

**Handoff prompt structure:**

```markdown
# Session Handoff — <date>

## Context
- Active worktree: <path>
- Branch: <branch>
- TDD phase: <Red|Green|Refactor|none>
- Iteration: <X/Y if tracked>

## Files modified this session
<git diff --name-only HEAD output>

## Decisions made
<extracted from CLAUDE conversations — needs human curation>

## Next session should
1. <action 1>
2. <action 2>

## Verification before claiming done
<commands to run>
```

The skill prompts the user for the "Decisions made" and "Next session should" sections — those need human curation.

##### 10b. New hook `~/.claude/hooks/context-watch.sh`

Wired on `Stop`. Detects approaching context limit, emits nudge.

**Detection (proxy — see Open Questions):**
1. Read `transcript_path` from hook input JSON if Claude Code exposes it.
2. Estimate token usage: `wc -c < $transcript_path / 4` (rough chars-to-tokens).
3. Compare to a threshold (e.g., 180_000 of 200_000 = 90%).

**Action at threshold:**
```
echo "CONTEXT WATCH: ~90% of context window used." >&2
echo "Run /handoff to generate a handoff prompt and start a fresh session." >&2
```

**Exit 0 always** — never blocks Stop.

**If `transcript_path` not exposed in hook input:** fallback to counting tool calls in the audit log for the current session ID. Coarser but deterministic.

### Stage 3 — Audit + new statusline (items 6, 8)

**6. v2.1.89 cache-bug audit.**
Activity, not code. Deliverable: `~/.claude/audit/v2.1.89-cache-review.md`.

**Process:**
- Walk all skills, hooks, CLAUDE.md.
- For each: identify long static prompts that should be cached; identify tool-result patterns that re-fetch unchanged data.
- For `claude-api` skill: verify examples include `cache_control` blocks and 5m vs 1h TTL guidance.
- Record findings, propose specific edits in a follow-up.

**No code changes in this stage** — the audit is the deliverable. Code edits land in subsequent PRs.

**8. Statusline — net-new.**
No statusline currently configured (`grep` confirmed: `no statusline configured`). This becomes a *create*, not an *upgrade*.

**Minimum viable statusline:**

```json
"statusLine": {
  "type": "json",
  "fields": [
    "model.name",
    "workspace.git_branch",
    "workspace.git_worktree",
    "rate_limits.5h_used_percent",
    "rate_limits.7d_used_percent"
  ]
}
```

Verify field names match installed Claude Code version during implementation (research surfaced these names but version may matter).

### Skipped — Item 9

Subprocess sandbox env vars (`CLAUDE_CODE_SUBPROCESS_ENV_SCRUB`, `CLAUDE_CODE_SCRIPT_CAPS`) skipped. User preference is max capability. The hardening these vars provide conflicts with that goal. Documenting the skip so it doesn't resurface in a future audit.

## Sequencing

| Stage | Items | Estimate |
|-------|-------|----------|
| 1 | 1, 2, 3, 4 | ~30 min |
| 2 | 5, 7, 10 | ~90 min (10 is the most work) |
| 3 | 6, 8 | ~45 min |

**Total: ~3h.** Stages run sequentially with verification between each.

## Verification

After each stage:

**Stage 1:**
- Run a test command containing fake credentials → confirm redacted in audit log.
- Touch a `*.h` file outside `bridge/` → confirm `tdd-guard.sh` blocks (or grep the script).
- Grep `Distinguished` in `team-shutdown/SKILL.md` → expect 0 matches.
- Corrupt `~/.claude/audit/.last-reflection` to invalid date → confirm hook exits 0 silently.

**Stage 2:**
- Touch `.last-checkpoint` 31 min ago + dirty worktree → trigger PreCompact → confirm exit 2.
- Run a denied command → confirm `permission-denials-*.log` entry + stderr hint.
- Generate transcript large enough to trigger threshold → confirm `context-watch.sh` emits nudge.
- Run `/handoff` → confirm handoff file created + structured.

**Stage 3:**
- Statusline visible in TUI with all 5 fields populated.
- Cache-audit doc exists with at least 3 concrete findings.

## Open questions

1. **Item 7:** Does Claude Code currently expose a `PermissionDenied` event to hooks? Research surfaced it as 2.1.x but unverified in installed version. *Resolution: check during implementation; if absent, defer item 7 with a note.*
2. **Item 10b:** Does Stop hook input include `transcript_path` or token-usage field? *Resolution: dump hook input JSON during implementation to learn schema; fallback to size-based proxy.*
3. **Item 8:** Are statusline field names `rate_limits.5h_used_percent` etc. correct for the installed Claude Code version? *Resolution: check Claude Code version + docs during implementation.*

These are not design risks — they are minor implementation discoveries. None block this design.

## Out of scope (queued)

- `~/.cursor` audit (Task #5) — separate brainstorm.
- Original Thread B sequence position 2: MemPalace tool-surface audit (Task #4).
- Original Thread B sequence position 3: Native agent teams adoption (Task #1).
- Original Thread B sequence position 4: TDAD AST upgrade for `test-dep-map.sh` (Task #3).

## Capture+PR cycle

After all 9 items implemented and verified locally in `~/.claude`, run `scripts/capture.sh` to sync to repo, then PR. PR strategy (single bundle vs split by stage) decided post-implementation based on diff size.

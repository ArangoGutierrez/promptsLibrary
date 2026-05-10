# Harden ~/.cursor Config — Design

**Date:** 2026-05-10
**Scope:** `~/.cursor/` live config (hooks, rules)
**Out of scope:** `skills-cursor/`, `commands/`, `extensions/`, `ai-tracking/`

## Problem

Bug-hunt audit of `~/.cursor/` (verified findings, see audit log) surfaced 9 actionable defects across 3 hook scripts and 2 rule files. Three are confirmed exploitable (gate bypasses); six are correctness/automation issues.

## Items

### Critical (3 — confirmed exploitable)

**1. `sign-commits.sh` malformed JSON when commit message contains `"`** (lines 44-45)
- Heredoc embeds `${corrected}` raw → invalid JSON → Cursor silently treats `ask` as passthrough.
- **Fix:** build JSON via `jq -n --arg msg ... --arg agent ...`.

**2. `sign-commits.sh` doesn't detect combined `-sS`/`-Ss` flags** (lines 20-21)
- Regex `\s-s(\s|$)` rejects `-sS` (next char is letter, not whitespace/EOL).
- **Fix:** widen regex to `\s-[a-zA-Z]*s[a-zA-Z]*(\s|$)|--signoff` (and `S` variant).

**3. `security-gate.sh` allows `dd of=/dev/sda`** (line 20)
- Blocklist has `dd if=/dev` (read direction only). Write direction is the actual disk-wipe vector.
- **Fix:** add `dd of=/dev` pattern.

### Important (5 — correctness / automation)

**4. `security-gate.sh` blocklist too short** — misses `rm -rf $HOME`, `kubectl delete --all`, `terraform destroy`, `gcloud delete`, `chmod -R 777 /etc`, force-push to non-main.
- **Fix:** add patterns; force-push regex covers any branch (drop main/master restriction; ASK semantics already handle the prompt).

**5. `security-gate.sh` fail-open on missing `jq`** (lines 6-9)
- Silent `{"permission":"allow"}` if `jq` absent.
- **Fix:** emit `{"permission":"ask",...}` instead so missing jq forces human review.

**6. `k8s.mdc` recommends secret-via-env** (line 7)
- Direct contradiction with line 8 (`security:no plain secrets`) and standard practice. Env-var secrets leak via `/proc/self/environ` and `ps auxe`.
- **Fix:** change to `configmap via env|secret via vol (mode 0400)`.

**7. `task-loop.sh` reads `loop_limit` from stdin but Cursor sets it as hook config** (script line 13, hooks.json line 34)
- Undocumented that hook-config values flow into stdin payload. Falls back to `// 5` matching the configured 5 — masks the issue.
- **Fix:** hard-code `LIMIT=5` in script; treat `hooks.json` value as documentation only.

**8. `workbench.mdc` worktree creation uses local `<default-branch>`** (line 19)
- Conflicts with CLAUDE.md `upstream/main` requirement. Stale-local risk.
- **Fix:** mirror CLAUDE.md — `git fetch` first, branch from `upstream/main`.

### Minor (1 — kept for completeness)

**9. `context-monitor.sh` is dead stub** (6 lines, reads stdin / echoes `{}` / exits 0)
- Header claims pattern logging — does nothing. Adds latency on every Stop event.
- **Fix:** remove from `hooks.json` (don't bother implementing — pattern logging not in scope).

## Out of scope (audit observations, not in this PR)

- `~/.cursor/memory/` orphaned dir (~96K) — defer to separate cleanup.
- `~/.cursor/mcp-servers/memory.retired/` (15K) — defer.
- `active-context.mdc` stale mtime (12 days) — not a bug; investigate separately.
- `core.mdc` + `workbench.mdc` `alwaysApply: true` redundancy — minor token cost; defer.

## Sequencing

Single-pass implementation. All 9 fixes are mechanical (1-5 lines each) and independent. No tests needed beyond shell-level verification of the gate hooks.

## Verification

After all fixes:

- **C1**: pipe a quoted-message commit through `sign-commits.sh`, parse output via `jq empty` — must succeed.
- **C2**: `echo "git commit -sS -m test" | grep -qE '<new-regex>'` — must match.
- **C3**: pipe `dd of=/dev/sda bs=512` through `security-gate.sh` — must return `permission:deny` or `ask`.
- **I1**: pipe each missed pattern through `security-gate.sh` — must NOT return `allow`.
- **I2**: temporarily rename jq → ensure script falls back to `ask`.
- **I3**: grep `secret via vol` in `k8s.mdc` — must match.
- **I5**: grep `upstream` or `git fetch` in `workbench.mdc` — must match.
- **I6**: `jq '.hooks.stop | length' hooks.json` — must show fewer entries than before.

## Capture+PR

After verification, run `scripts/capture.sh` to sync to repo. None of the 9 fixes touch NVIDIA-excluded files (`extract-learnings.sh`, `inject-context.sh`), so all should propagate.

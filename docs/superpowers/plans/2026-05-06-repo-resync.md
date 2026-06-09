# Repo Resync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring the `ArangoGutierrez/promptsLibrary` dotfiles repo back in sync with the live `~/.claude/` and `~/.cursor/` environments, while keeping NVIDIA-internal references out of the public repo and making future captures reproducible.

**Architecture:** Tooling-first. First two commits encode runtime-cruft and NVIDIA-internal exclusion policy plus a sanitizer for files with mixed public/private content into `scripts/capture.sh` and `scripts/diff.sh`. Subsequent commits land the resulting captured content and updated docs.

**Tech Stack:** Bash, rsync, jq, awk, git (signed commits via DCO + GPG, enforced by `~/.claude/hooks/sign-commits.sh`).

**Spec:** `docs/superpowers/specs/2026-05-06-repo-resync-design.md` (commit `c58f772`).

---

## Task 0: Create worktree from `origin/main`

**Files:** none (worktree setup only)

- [ ] **Step 1: Fetch latest origin and confirm clean tree**

Run from repo root:
```bash
git fetch origin && git status --porcelain
```
Expected: empty output (clean working tree).

- [ ] **Step 2: Determine remote default branch**

```bash
git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@'
```
Expected: `main`.

- [ ] **Step 3: Create worktree**

```bash
git worktree add .worktrees/repo-resync -b chore/repo-resync origin/main
cd .worktrees/repo-resync
```
Expected: `.worktrees/repo-resync` directory exists; HEAD points at new branch.

- [ ] **Step 4: Verify worktree state**

```bash
git status && git log --oneline -3
```
Expected: clean tree on `chore/repo-resync`, three most recent main commits visible.

**All subsequent tasks happen inside `.worktrees/repo-resync`.**

---

## Task 1: Tighten capture/diff runtime-cruft excludes

**Files:**
- Modify: `scripts/capture.sh`
- Modify: `scripts/diff.sh`

- [ ] **Step 1: Update `CLAUDE_EXCLUDES` in `scripts/capture.sh`**

Replace the existing `CLAUDE_EXCLUDES` array (lines 9–32) with:

```bash
CLAUDE_EXCLUDES=(
  .git/
  .DS_Store
  debug/
  projects/
  teams/
  tasks/
  todos/
  cache/
  file-history/
  session-env/
  shell-snapshots/
  paste-cache/
  telemetry/
  backups/
  ide/
  plans/
  sessions/
  audit/
  archive/
  image-cache/
  history.jsonl
  stats-cache.json
  cleanup-errors.log
  .cleaned-this-week
  audit.md
  migration.md
  proposal.md
  plugins/cache/
  plugins/known_marketplaces.json
  plugins/marketplaces/
  plugins/install-counts-cache.json
  plugins/blocklist.json
  hooks/*.bak-*
  settings.local.json
)
```

- [ ] **Step 2: Update `CURSOR_EXCLUDES` in `scripts/capture.sh`**

Replace the existing `CURSOR_EXCLUDES` array (lines 34–49) with:

```bash
CURSOR_EXCLUDES=(
  .git/
  .DS_Store
  extensions/
  projects/
  ai-tracking/
  snapshots/
  ide_state.json
  argv.json
  unified_repo_list.json
  worktrees/
  blocklist
  .deploy-version
  docs/
  skills/
  mcp-servers/venv/
  mcp-servers/memory.retired/
)
```

- [ ] **Step 3: Mirror these exclude lists in `scripts/diff.sh`**

Apply the same changes to `CLAUDE_EXCLUDES` (lines 9–35) and `CURSOR_EXCLUDES` (lines 37–52) in `scripts/diff.sh`. Note that `diff.sh` keeps its existing additional excludes for `commands/`, `docs/`, `team/` under `CLAUDE_EXCLUDES`; preserve those.

The final `CLAUDE_EXCLUDES` in `diff.sh` should match `capture.sh` plus these three extra entries:
```bash
  commands/
  docs/
  team/
```

- [ ] **Step 4: Sanity-check that `bash -n` parses both scripts**

```bash
bash -n scripts/capture.sh && bash -n scripts/diff.sh && echo "OK"
```
Expected: `OK`.

- [ ] **Step 5: Commit**

```bash
git add scripts/capture.sh scripts/diff.sh
git commit -s -S -m "chore(scripts): tighten capture/diff runtime-cruft excludes

Align excludes with ~/.claude/.gitignore (audit/, archive/, sessions/,
image-cache/) and add hook backup files (*.bak-*), mcp-servers/venv/
(406 MB Python venv), and one-time docs (audit.md, migration.md,
proposal.md). Without these, a naive capture pulls ~9 MB of bash audit
logs and a ~400 MB venv into the repo."
```
Expected: commit lands; signed (verify with `git log --show-signature -1`).

---

## Task 2: Add public-safe NVIDIA exclude list and sanitizer

**Files:**
- Modify: `scripts/capture.sh`
- Modify: `scripts/diff.sh`

- [ ] **Step 1: Add `NVIDIA_CLAUDE_EXCLUDES` and `NVIDIA_CURSOR_EXCLUDES` in `scripts/capture.sh`**

Insert immediately after the existing `CURSOR_EXCLUDES=(...)` block:

```bash
# --- Public-safe excludes: NVIDIA-internal references ---
# These paths reference NVIDIA-internal tooling (MemPalace MCP,
# nvinfo-cli CLI, omnistation platform). Excluded from the public repo.

NVIDIA_CLAUDE_EXCLUDES=(
  skills/nvinfo-cli/
  skills/managing-omnistation/
  hooks/mempalace-wake.sh
  remote-settings.json
)

NVIDIA_CURSOR_EXCLUDES=(
  commands/recall.md
  commands/ingest-pr.md
  hooks/extract-learnings.sh
  hooks/inject-context.sh
  entities.json
)
```

Note: `remote-settings.json` is in the NVIDIA exclude list because we replace it with a curated public version in Task 3 and stop syncing it.

- [ ] **Step 2: Apply NVIDIA excludes in `capture_claude` and `capture_cursor`**

In `capture_claude` (around line 113), change:
```bash
  local exclude_args=()
  for pattern in "${CLAUDE_EXCLUDES[@]}"; do
    exclude_args+=(--exclude "$pattern")
  done
```
to:
```bash
  local exclude_args=()
  for pattern in "${CLAUDE_EXCLUDES[@]}" "${NVIDIA_CLAUDE_EXCLUDES[@]}"; do
    exclude_args+=(--exclude "$pattern")
  done
```

Apply the same change in `capture_cursor`, swapping `CLAUDE_EXCLUDES` for `CURSOR_EXCLUDES` and `NVIDIA_CLAUDE_EXCLUDES` for `NVIDIA_CURSOR_EXCLUDES`.

- [ ] **Step 3: Add `sanitize_claude` function in `scripts/capture.sh`**

Insert immediately before the `# --- Capture ---` divider (around line 99):

```bash
# --- Sanitizer: scrub mixed public/private content from captured files ---

sanitize_claude() {
  local dest="$REPO_DIR/.claude"

  # 1. Strip local-scoped plugins from installed_plugins.json
  local plugins_file="$dest/plugins/installed_plugins.json"
  if [[ -f "$plugins_file" ]]; then
    local tmp
    tmp="$(mktemp)"
    /usr/bin/jq '
      .plugins |= with_entries(
        .value |= map(select(.scope != "local"))
      )
      | .plugins |= with_entries(select(.value | length > 0))
    ' "$plugins_file" > "$tmp" && /bin/mv "$tmp" "$plugins_file"
  fi

  # 2. Strip mempalace-wake.sh hook entries from settings.json
  local settings_file="$dest/settings.json"
  if [[ -f "$settings_file" ]]; then
    local tmp
    tmp="$(mktemp)"
    /usr/bin/jq '
      walk(
        if type == "object" and has("hooks") and (.hooks | type) == "array"
        then .hooks |= map(select((.command // "") | endswith("mempalace-wake.sh") | not))
        else .
        end
      )
    ' "$settings_file" > "$tmp" && /bin/mv "$tmp" "$settings_file"
  fi

  # 3. Strip the ## Memory section from CLAUDE.md (NVIDIA-internal MemPalace block)
  local claude_md="$dest/CLAUDE.md"
  if [[ -f "$claude_md" ]]; then
    local tmp
    tmp="$(mktemp)"
    /usr/bin/awk '
      /^## Memory$/ { skip = 1; next }
      skip && /^# / { skip = 0 }
      skip && /^## / { skip = 0 }
      !skip { print }
    ' "$claude_md" > "$tmp" && /bin/mv "$tmp" "$claude_md"
  fi
}
```

The awk pattern: when we see a level-2 heading `## Memory`, start skipping. Stop skipping at the next level-1 heading (`# `) or any other level-2 heading (`## `). Lines while skipping are dropped.

- [ ] **Step 4: Wire sanitizer into the capture flow**

At the end of the `capture_claude` function (after the `run_rsync` call), append:
```bash
  sanitize_claude
```

- [ ] **Step 5: Wrap main flow in `main()` and guard against sourcing**

Currently `capture.sh` calls `capture_claude` and `capture_cursor` at file scope (lines ~145–153). Sourcing the script for testing would re-run rsync against the live `~/.claude`. Wrap the main flow so the script is sourceable.

Replace the existing main block:

```bash
echo "=== dotfiles capture ==="
echo ""

if ! $CURSOR_ONLY; then
  capture_claude
fi
if ! $CLAUDE_ONLY; then
  capture_cursor
fi

echo ""
echo "Done. Review changes with:"
echo ""
echo "  cd $REPO_DIR"
echo "  git diff"
echo "  git diff --stat"
echo ""
echo "To see untracked files:"
echo ""
echo "  git status"
echo ""
```

with:

```bash
main() {
  echo "=== dotfiles capture ==="
  echo ""

  if ! $CURSOR_ONLY; then
    capture_claude
  fi
  if ! $CLAUDE_ONLY; then
    capture_cursor
  fi

  echo ""
  echo "Done. Review changes with:"
  echo ""
  echo "  cd $REPO_DIR"
  echo "  git diff"
  echo "  git diff --stat"
  echo ""
  echo "To see untracked files:"
  echo ""
  echo "  git status"
  echo ""
}

# Only run main when executed directly; allow sourcing for tests.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main
fi
```

Note: the flag parsing block (`while [[ $# -gt 0 ]]; do ... done`) and the `CLAUDE_ONLY`/`CURSOR_ONLY` mutual-exclusion check stay at file scope — they need to run before `main` and they read `$@` which only works at the top level.

- [ ] **Step 6: Verify scripts still parse**

```bash
bash -n scripts/capture.sh && bash -n scripts/diff.sh && echo "OK"
```
Expected: `OK`.

- [ ] **Step 7: Test sanitizer idempotence with a fixture**

Create a temporary fixture and run the sanitizer twice against it:

```bash
TMP="$(mktemp -d)"
mkdir -p "$TMP/.claude/plugins" "$TMP/.claude/hooks"

cat > "$TMP/.claude/plugins/installed_plugins.json" <<'EOF'
{"plugins": {"foo": [{"scope": "user", "version": "1.0"}, {"scope": "local", "projectPath": "/leak/path", "version": "2.0"}]}}
EOF

cat > "$TMP/.claude/CLAUDE.md" <<'EOF'
# Engineering Standards

## Memory
Persistent memory is MemPalace.
- Read mempalace_status.

## Next Section
keep this
EOF

cat > "$TMP/.claude/settings.json" <<'EOF'
{"hooks": {"SessionStart": [{"hooks": [{"type": "command", "command": "/path/to/mempalace-wake.sh"}, {"type": "command", "command": "/path/to/other.sh"}]}]}}
EOF

# Source capture.sh (main is guarded; sanitize_claude is now defined).
# Override REPO_DIR so sanitize_claude operates on the fixture, not the repo.
REPO_DIR="$TMP" bash -c '
  source scripts/capture.sh
  sanitize_claude
  sanitize_claude  # second run must be a no-op (idempotence)
'

# 1. local-scoped plugin entry was removed; user-scoped kept
/usr/bin/jq -e '.plugins.foo | length == 1 and .[0].scope == "user"' \
  "$TMP/.claude/plugins/installed_plugins.json" > /dev/null \
  && echo "plugins filter: PASS" || echo "plugins filter: FAIL"

# 2. mempalace-wake.sh hook removed; other.sh kept
/usr/bin/jq -e '[.. | objects | select(has("hooks") and (.hooks | type) == "array") | .hooks[].command] == ["/path/to/other.sh"]' \
  "$TMP/.claude/settings.json" > /dev/null \
  && echo "settings filter: PASS" || echo "settings filter: FAIL"

# 3. ## Memory section gone; ## Next Section preserved
if /usr/bin/grep -q "^## Next Section" "$TMP/.claude/CLAUDE.md" \
   && ! /usr/bin/grep -q "^## Memory" "$TMP/.claude/CLAUDE.md"; then
  echo "claude.md filter: PASS"
else
  echo "claude.md filter: FAIL"
fi

rm -rf "$TMP"
```
Expected: three `PASS` lines.

- [ ] **Step 8: Commit**

```bash
git add scripts/capture.sh scripts/diff.sh
git commit -s -S -m "feat(scripts): add public-safe NVIDIA exclude list and sanitizer

Adds NVIDIA_CLAUDE_EXCLUDES and NVIDIA_CURSOR_EXCLUDES constants so
capture.sh produces a public-safe result by default. Adds a sanitize_claude
post-rsync pass that:

- strips local-scoped entries from plugins/installed_plugins.json (private
  project paths leaking via local-scoped plugin installs)
- strips mempalace-wake.sh hook entries from settings.json
- strips the '## Memory' section from CLAUDE.md (MemPalace MCP is
  NVIDIA-internal)

remote-settings.json is excluded from sync; the repo's curated public
allowlist is the source of truth from now on."
```

---

## Task 3: Replace `remote-settings.json` with curated public allowlist

**Files:**
- Modify: `.claude/remote-settings.json`

- [ ] **Step 1: Replace `.claude/remote-settings.json` with the curated allowlist**

Overwrite the file with:

```json
{
  "permissions": {
    "ask": [
      "Bash(rm:*)",
      "Bash",
      "WebFetch"
    ]
  },
  "sandbox": {
    "network": {
      "allowManagedDomainsOnly": true,
      "allowedDomains": [
        "github.com",
        "*.github.com",
        "raw.githubusercontent.com",
        "*.github.io",
        "*.teleport.sh",
        "claude.com",
        "*.claude.com",
        "docs.anthropic.com",
        "api.anthropic.com",
        "support.atlassian.com",
        "bazel.build",
        "*.bazel.build",
        "sum.golang.org",
        "proxy.golang.org",
        "go.dev",
        "localhost",
        "host.docker.internal",
        "pypi.org",
        "files.pythonhosted.org",
        "repo1.maven.org",
        "archive.ubuntu.com",
        "security.ubuntu.com",
        "docker.com",
        "*.docker.com",
        "api2.cursor.sh",
        "deepwiki.com",
        "googleapis.com",
        "*.googleapis.com",
        "cache.nixos.org",
        "crates.io",
        "*.crates.io",
        "arxiv.org",
        "docs.rs",
        "std.rs",
        "nvd.nist.gov"
      ]
    }
  }
}
```

This is a **deliberate public-safe allowlist**: github + Anthropic (Claude API) + standard dev hosts (golang, pypi, docker, cargo, NixOS) + a few security/docs hosts. NVIDIA-internal hosts (`gitlab-master.nvidia.com`, `*.nvda.ai`, `nvidia.atlassian.net`, `nvacademy.dev`), corporate auth (`microsoftonline.com`), and corporate LMS (`brainshark.com`, `learningmanager.adobe.com`) are intentionally absent.

- [ ] **Step 2: Verify JSON is valid**

```bash
/usr/bin/jq empty .claude/remote-settings.json && echo "OK"
```
Expected: `OK`.

- [ ] **Step 3: Verify no NVIDIA-specific hosts remain**

```bash
/usr/bin/grep -i -E "nvidia|nvda|nvacademy|atlassian.net|brainshark|adobe.*learning|microsoftonline|gm\.com" .claude/remote-settings.json
```
Expected: no output (exit 1).

- [ ] **Step 4: Commit**

```bash
git add .claude/remote-settings.json
git commit -s -S -m "chore(.claude): replace remote-settings.json with curated public allowlist

The live ~/.claude/remote-settings.json contains corporate auth hosts
(microsoftonline, brainshark, adobe LMS), NVIDIA-internal infrastructure
(nvda.ai, nvacademy.dev, nvidia.atlassian.net), and other site-specific
entries that are not appropriate for the public dotfiles repo.

Replace with a curated allowlist scoped to:
- GitHub
- Anthropic (Claude API + docs)
- Standard dev tools (Go, pypi, Docker, cargo, NixOS, Cursor, Bazel)
- Public security/docs (NVD, Atlassian support, deepwiki, arxiv)

This file is now sourced from the repo, not from ~/.claude. capture.sh
excludes it from sync."
```

---

## Task 4: Run capture.sh and stage the bulk of changes

**Files:**
- Modify (rsync from `~/.claude/` and `~/.cursor/`): many files across `.claude/` and `.cursor/`

- [ ] **Step 1: Run capture from repo root**

```bash
./scripts/capture.sh
```
Expected: rsync output listing transferred files; sanitizer runs silently.

- [ ] **Step 2: Verify capture didn't pull anything that should be excluded**

```bash
/usr/bin/find .claude/audit .claude/archive .claude/sessions .claude/image-cache .cursor/mcp-servers/venv .cursor/mcp-servers/memory.retired 2>/dev/null
/usr/bin/find .claude/skills/nvinfo-cli .claude/skills/managing-omnistation .claude/hooks/mempalace-wake.sh 2>/dev/null
/usr/bin/find .cursor/commands/recall.md .cursor/commands/ingest-pr.md .cursor/hooks/extract-learnings.sh .cursor/hooks/inject-context.sh .cursor/entities.json 2>/dev/null
/usr/bin/find .claude -name '*.bak-*' 2>/dev/null
```
Expected: all four `find`s produce empty output.

- [ ] **Step 3: Verify sanitizer stripped the targeted content**

```bash
# remote-settings.json should be the curated version (untouched by capture)
/usr/bin/grep -q "nvda.ai" .claude/remote-settings.json && echo "FAIL" || echo "OK"
# CLAUDE.md should not have a ## Memory section
/usr/bin/grep -q "^## Memory" .claude/CLAUDE.md && echo "FAIL" || echo "OK"
# settings.json should not reference mempalace-wake.sh
/usr/bin/grep -q "mempalace-wake" .claude/settings.json && echo "FAIL" || echo "OK"
# installed_plugins.json should have no scope=local entries
/usr/bin/jq -e '[.plugins[][] | select(.scope == "local")] | length == 0' .claude/plugins/installed_plugins.json && echo "OK" || echo "FAIL"
```
Expected: four `OK` lines.

- [ ] **Step 4: Inspect the staged diff scope**

```bash
git status --short
```
Expected: changes across `.claude/CLAUDE.md`, `.claude/settings.json`, `.claude/policy-limits.json`, `.claude/plugins/installed_plugins.json`, `.claude/hooks/{enforce-worktree,tdd-guard}.sh`, plus new files in `.claude/{agents,rules,skills,hooks}/` and `.cursor/` updates.

**Do not commit yet** — subsequent tasks split this captured set into themed commits.

---

## Task 5: Commit `.claude/CLAUDE.md`, `settings.json`, `policy-limits.json`

**Files:**
- Modify: `.claude/CLAUDE.md`
- Modify: `.claude/settings.json`
- Modify: `.claude/policy-limits.json`

- [ ] **Step 1: Re-verify these three files are sanitized**

```bash
/usr/bin/grep -E "mempalace|nvinfo|omnistation|nvda\.ai|nvacademy" .claude/CLAUDE.md .claude/settings.json .claude/policy-limits.json
```
Expected: no output.

- [ ] **Step 2: Stage and commit**

```bash
git add .claude/CLAUDE.md .claude/settings.json .claude/policy-limits.json
git commit -s -S -m "chore(.claude): sync CLAUDE.md, settings.json, policy-limits.json

CLAUDE.md sanitized: '## Memory' (MemPalace MCP) section stripped by
capture.sh sanitizer. Updated standards reflect the team-execute /
solo-execute split, agent role definitions, and worktree-from-remote-ref
discipline.

settings.json sanitized: mempalace-wake.sh SessionStart hook stripped.
Adds PostToolUse auto-format + test-quality-lint hooks, PreCompact
context-saver hook, Stop verification hook, and clangd-lsp plugin.

policy-limits.json: adds allow_remote_control, allow_quick_web_setup,
enforce_web_search_mcp_isolation flags (all set to false)."
```

---

## Task 6: Commit `installed_plugins.json` and hook updates

**Files:**
- Modify: `.claude/plugins/installed_plugins.json`
- Modify: `.claude/hooks/enforce-worktree.sh`
- Modify: `.claude/hooks/tdd-guard.sh`

- [ ] **Step 1: Verify `installed_plugins.json` sanitization**

```bash
/usr/bin/jq -e '[.plugins[][] | select(.scope == "local")] | length == 0' .claude/plugins/installed_plugins.json
/usr/bin/grep -q "private-repo\|private-org" .claude/plugins/installed_plugins.json && echo "LEAK" || echo "OK"
```
Expected: `true` then `OK`.

- [ ] **Step 2: Stage and commit**

```bash
git add .claude/plugins/installed_plugins.json .claude/hooks/enforce-worktree.sh .claude/hooks/tdd-guard.sh
git commit -s -S -m "chore(.claude): sync installed_plugins.json and existing hook updates

installed_plugins.json sanitized: scope=local entries (private project
paths) stripped by capture.sh sanitizer. Adds clangd-lsp@user, bumps
superpowers and code-review plugin versions.

hooks/enforce-worktree.sh, hooks/tdd-guard.sh: sync improvements from
live (clearer error messages, tighter exemptions)."
```

---

## Task 7: Add `.claude/agents/`

**Files:**
- Create: `.claude/agents/doc-writer.md`
- Create: `.claude/agents/explorer.md`
- Create: `.claude/agents/principal-engineer.md`
- Create: `.claude/agents/qa-engineer.md`

These were captured into the working tree by Task 4 — they only need to be staged.

- [ ] **Step 1: Confirm files are present and untracked**

```bash
ls .claude/agents/ && git status --short .claude/agents/
```
Expected: 4 files listed; each shown with `??` prefix in git status.

- [ ] **Step 2: Verify no NVIDIA leaks in agents content**

```bash
/usr/bin/grep -r -i -E "mempalace|nvinfo|omnistation|nvda\.ai|nvacademy|atlassian\.net" .claude/agents/
```
Expected: no output.

- [ ] **Step 3: Stage and commit**

```bash
git add .claude/agents/
git commit -s -S -m "feat(.claude): add agents/ directory with four role definitions

Adds the four agent role definitions referenced by the multi-agent
team workflow:

- doc-writer: documentation generation/updates (READMEs, godoc, ADRs)
- explorer: cheap read-only codebase exploration
- principal-engineer: architecture, Go/K8s conventions, security audit
- qa-engineer: test quality, mutation testing, CI replication, PR
  readiness gate

These are referenced from the team-execute workflow but were missing
from the repo until now."
```

---

## Task 8: Add `.claude/rules/`

**Files:**
- Create: `.claude/rules/constitution.md`
- Create: `.claude/rules/container-conventions.md`
- Create: `.claude/rules/git-workflow.md`
- Create: `.claude/rules/go-conventions.md`
- Create: `.claude/rules/k8s-conventions.md`
- Create: `.claude/rules/learned-anti-patterns.md`
- Create: `.claude/rules/security.md`

- [ ] **Step 1: Verify content does not leak NVIDIA-internal references**

```bash
/usr/bin/grep -r -i -E "mempalace|nvinfo|omnistation|nvda\.ai|nvacademy|atlassian\.net|brainshark|adobe.*learning|microsoftonline" .claude/rules/
```
Expected: no output. (`nvidia-smi` and `cuda:` references in container-conventions.md are public NVIDIA tooling, not internal — those are kept.)

- [ ] **Step 2: Confirm 7 files**

```bash
ls .claude/rules/ | wc -l
```
Expected: `7`.

- [ ] **Step 3: Stage and commit**

```bash
git add .claude/rules/
git commit -s -S -m "feat(.claude): add rules/ engineering standards

Adds the seven rule files that .claude/CLAUDE.md references but the
repo did not previously ship. Without these, a fresh deploy left
CLAUDE.md with broken @-references.

- constitution.md: hot memory of failure modes (theater tests, etc.)
- go-conventions.md: errors, signatures, style, testing, concurrency
- k8s-conventions.md: CRDs, controller-runtime, RBAC, GPU scheduling
- container-conventions.md: image builds, security, OCI standards
- git-workflow.md: commits, branches, PRs, review
- security.md: secrets, SAST, RBAC, CVE response
- learned-anti-patterns.md: curated by /reflection skill"
```

---

## Task 9: Add `.claude/skills/` (10 generic skills)

**Files:**
- Create: `.claude/skills/eureka/`
- Create: `.claude/skills/go-review/`
- Create: `.claude/skills/k8s-debug/`
- Create: `.claude/skills/pr-review-ingest/`
- Create: `.claude/skills/reflection/`
- Create: `.claude/skills/tdd-protocol/`
- Create: `.claude/skills/team-execute/`
- Create: `.claude/skills/team-plan/`
- Create: `.claude/skills/team-shutdown/`
- Create: `.claude/skills/worktree-guide/`

NVIDIA-internal skills (`nvinfo-cli/`, `managing-omnistation/`) were filtered out by `NVIDIA_CLAUDE_EXCLUDES` in Task 4.

- [ ] **Step 1: Confirm 10 skill directories present, no NVIDIA-internal skills**

```bash
ls .claude/skills/ | sort
ls .claude/skills/nvinfo-cli .claude/skills/managing-omnistation 2>/dev/null && echo "FAIL: leak" || echo "OK"
```
Expected listing: `eureka`, `go-review`, `k8s-debug`, `pr-review-ingest`, `reflection`, `tdd-protocol`, `team-execute`, `team-plan`, `team-shutdown`, `worktree-guide`. Final line: `OK`.

- [ ] **Step 2: Content sanity check**

```bash
/usr/bin/grep -r -i -E "mempalace|nvinfo|omnistation|nvda\.ai|nvacademy|atlassian\.net" .claude/skills/
```
Expected: no output. (`nvidia.com/gpu` references in `k8s-debug` are the standard public Kubernetes resource name — kept intentionally.)

- [ ] **Step 3: Stage and commit**

```bash
git add .claude/skills/
git commit -s -S -m "feat(.claude): add skills/ (ten generic skills)

- eureka: capture technical breakthroughs as structured documents
- go-review: Go-specific code review (errors, concurrency, performance)
- k8s-debug: structured Kubernetes debugging for GPU workloads
- pr-review-ingest: learn from PR review feedback, propose rule updates
- reflection: analyze session patterns, capture mistakes, curate rules
- tdd-protocol: Red/Green/Refactor enforcement
- team-plan: multi-task project planning on agents-workbench
- team-execute: spawn agent team for plan implementation
- team-shutdown: cleanup team infrastructure post-completion
- worktree-guide: worktree creation/lifecycle from agents-workbench

NVIDIA-internal skills (nvinfo-cli, managing-omnistation) are excluded
from this public mirror via NVIDIA_CLAUDE_EXCLUDES in capture.sh."
```

---

## Task 10: Add new `.claude/hooks/`

**Files:**
- Create: `.claude/hooks/auto-format.sh`
- Create: `.claude/hooks/bash-audit-log.sh`
- Create: `.claude/hooks/mutation-gate.sh`
- Create: `.claude/hooks/pre-compact-context.sh`
- Create: `.claude/hooks/reflection-staleness.sh`
- Create: `.claude/hooks/test-dep-map.sh`
- Create: `.claude/hooks/test-quality-lint.sh`

`mempalace-wake.sh` was filtered out by `NVIDIA_CLAUDE_EXCLUDES` in Task 4.

- [ ] **Step 1: Verify executable bits and no NVIDIA references**

```bash
/usr/bin/find .claude/hooks/ -name '*.sh' -not -executable
/usr/bin/grep -r -i -E "mempalace|nvinfo|omnistation|nvda\.ai|nvacademy|atlassian\.net" .claude/hooks/
```
Expected: both produce no output. If files are missing executable bit:
```bash
chmod +x .claude/hooks/*.sh
```

- [ ] **Step 2: Verify no `mempalace-wake.sh`**

```bash
ls .claude/hooks/mempalace-wake.sh 2>/dev/null && echo "FAIL: leak" || echo "OK"
```
Expected: `OK`.

- [ ] **Step 3: Verify only the 7 new hooks are staged**

```bash
git status --short .claude/hooks/
```
Expected: 7 untracked entries (`??`) for the new hook files. The two changed hooks (`enforce-worktree.sh`, `tdd-guard.sh`) were already committed in Task 6.

- [ ] **Step 4: Stage and commit**

```bash
git add .claude/hooks/
git commit -s -S -m "feat(.claude): add hooks (auto-format, test-quality-lint, etc.)

Adds seven new hooks referenced by the updated settings.json:

- auto-format.sh: PostToolUse formatter (Write/Edit)
- test-quality-lint.sh: PostToolUse test-quality check (Write/Edit)
- bash-audit-log.sh: PostToolUse bash command audit logger
- pre-compact-context.sh: PreCompact context-saver
- reflection-staleness.sh: SessionStart reflection prompt
- mutation-gate.sh: mutation testing gate
- test-dep-map.sh: test dependency map builder

NVIDIA-internal hook (mempalace-wake.sh) is excluded from this public
mirror via NVIDIA_CLAUDE_EXCLUDES in capture.sh."
```

---

## Task 11: Sync `.cursor/` config drift

**Files:**
- Modify: 12 changed files in `.cursor/`

Per `diff.sh` output captured during planning: `.cursor/.gitignore`, `.cursor/commands/merge-train.md`, `.cursor/hooks.json`, `.cursor/hooks/{context-monitor,security-gate,sign-commits}.sh`, `.cursor/mcp.json`, `.cursor/skills-cursor/{create-rule,create-skill,create-subagent,migrate-to-skills,update-cursor-settings}/SKILL.md`.

- [ ] **Step 1: Inspect what's staged for `.cursor/`**

```bash
git status --short .cursor/ | sort
```
Expected: ~12 modified files; no `recall.md`, `ingest-pr.md`, `extract-learnings.sh`, `inject-context.sh`, `entities.json` (all in `NVIDIA_CURSOR_EXCLUDES`).

- [ ] **Step 2: Verify no NVIDIA leaks in changed cursor content**

```bash
/usr/bin/grep -r -i -E "mempalace|nvinfo|omnistation|nvda\.ai|nvacademy|atlassian\.net" .cursor/
```
Expected: no output.

- [ ] **Step 3: Stage and commit**

```bash
git add .cursor/
git commit -s -S -m "chore(.cursor): sync cursor config drift

Updates the 12 cursor files that drifted from the live ~/.cursor:

- .cursor/.gitignore: refresh excludes
- commands/merge-train.md: refresh content
- hooks.json: hook config refresh
- hooks/{context-monitor,security-gate,sign-commits}.sh: improvements
- mcp.json: MCP server config refresh
- skills-cursor/{create-rule,create-skill,create-subagent,migrate-to-skills,update-cursor-settings}/SKILL.md: refresh

NVIDIA-internal cursor commands/hooks (recall, ingest-pr, extract-learnings,
inject-context, entities.json) are excluded via NVIDIA_CURSOR_EXCLUDES."
```

---

## Task 12: Refresh README counts and feature lists

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Update the `.claude/` table in README.md**

In the Claude Code (`.claude/`) table (around line 60), apply these edits:

Change the **Hooks** row:
- Count: `6` → `13`
- Description: `inject-date, sign-commits, prevent-push-workbench, enforce-worktree, validate-year, tdd-guard, auto-format, bash-audit-log, mutation-gate, pre-compact-context, reflection-staleness, test-dep-map, test-quality-lint`

Add three new rows after the **Hooks** row:
```markdown
| **Agents** | 4 | doc-writer, explorer, principal-engineer, qa-engineer |
| **Rules** | 7 | constitution, go/k8s/container conventions, git-workflow, security, learned-anti-patterns |
| **Skills** | 10 | eureka, go-review, k8s-debug, pr-review-ingest, reflection, tdd-protocol, team-{plan,execute,shutdown}, worktree-guide |
```

- [ ] **Step 2: Update "Key Behaviors Enforced" list**

In the "Key Behaviors Enforced" section (around line 83), add a bullet after the existing list:

```markdown
- **Auto-format & test-quality-lint**: PostToolUse hooks format code and check test quality on every Write/Edit
```

- [ ] **Step 3: Verify markdownlint still passes**

```bash
/usr/bin/find .markdownlint.json README.md
# Use whatever markdownlint binary the CI uses; if available locally:
which markdownlint && markdownlint README.md && echo "OK" || echo "skip (no local markdownlint, CI will check)"
```

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -s -S -m "docs: refresh README counts and feature lists

Bumps the .claude/ table to reflect newly tracked categories:
- Hooks: 6 -> 13 (auto-format, bash-audit-log, mutation-gate,
  pre-compact-context, reflection-staleness, test-dep-map,
  test-quality-lint added)
- Agents: new row, 4 entries (doc-writer, explorer, principal-engineer,
  qa-engineer)
- Rules: new row, 7 entries (constitution, go/k8s/container conventions,
  git-workflow, security, learned-anti-patterns)
- Skills: new row, 10 entries (eureka, go-review, k8s-debug,
  pr-review-ingest, reflection, tdd-protocol, team-{plan,execute,shutdown},
  worktree-guide)

Adds a 'Key Behaviors Enforced' bullet for the new auto-format /
test-quality-lint PostToolUse hooks.

Deep doc files (docs/claude-code.md, docs/cursor.md,
docs/skills-and-commands.md) intentionally left for follow-up."
```

---

## Task 13: Final verification

**Files:** none (verification only)

- [ ] **Step 1: Verify diff.sh is clean**

```bash
./scripts/diff.sh
```
Expected: exits 0 — or shows only the entries from `NVIDIA_CLAUDE_EXCLUDES` / `NVIDIA_CURSOR_EXCLUDES` as `LIVE ONLY` (those are intentional). No `CHANGED` entries should remain.

- [ ] **Step 2: No-leak grep**

```bash
/usr/bin/grep -r -i -E "mempalace|nvinfo|omnistation|nvda\.ai|nvacademy|atlassian\.net|brainshark|adobe.*learning|microsoftonline|gm\.com|gitlab-master\.nvidia" .claude/ .cursor/ scripts/
```
Expected: no output. The standard public Kubernetes resource name `nvidia.com/gpu` is allowed; this regex does not match it.

- [ ] **Step 3: Sanitizer idempotence on real data**

```bash
./scripts/capture.sh
git status --porcelain
```
Expected: empty output. Running capture again produces no further changes.

- [ ] **Step 4: All commits signed**

```bash
git log --show-signature origin/main..HEAD 2>&1 | grep -E "^(commit |Good signature|Signed-off-by)" | head -40
```
Expected: 11 commits each showing a `Good signature` line and a `Signed-off-by:` line.

- [ ] **Step 5: Commit count and order check**

```bash
git log --oneline origin/main..HEAD
```
Expected: 11 commits in order:
1. `chore(scripts): tighten capture/diff runtime-cruft excludes`
2. `feat(scripts): add public-safe NVIDIA exclude list and sanitizer`
3. `chore(.claude): replace remote-settings.json with curated public allowlist`
4. `chore(.claude): sync CLAUDE.md, settings.json, policy-limits.json`
5. `chore(.claude): sync installed_plugins.json and existing hook updates`
6. `feat(.claude): add agents/ directory with four role definitions`
7. `feat(.claude): add rules/ engineering standards`
8. `feat(.claude): add skills/ (ten generic skills)`
9. `feat(.claude): add hooks (auto-format, test-quality-lint, etc.)`
10. `chore(.cursor): sync cursor config drift`
11. `docs: refresh README counts and feature lists`

- [ ] **Step 6: Manual eyeball pass**

For each commit, run:
```bash
git show --stat <commit-sha>
```
and visually confirm the files match the commit's stated scope (no cross-talk).

---

## Task 14: Push and create PR

**Files:** none

- [ ] **Step 1: Push the branch**

```bash
git push -u origin chore/repo-resync
```
Expected: branch pushed; pre-push hook (if any) does not block.

- [ ] **Step 2: Create draft PR**

```bash
gh pr create --draft \
  --title "chore: full repo resync from ~/.claude and ~/.cursor (public-safe)" \
  --body "$(cat <<'EOF'
## Summary

Brings the dotfiles repo back in sync with the live ~/.claude and ~/.cursor
environments after extended drift. Implements the design at
docs/superpowers/specs/2026-05-06-repo-resync-design.md.

## What changed

**Tooling** (commits 1-2):
- Tighten capture/diff runtime-cruft excludes (audit/, archive/,
  sessions/, image-cache/, *.bak-*, mcp-servers/venv/)
- Add NVIDIA-internal exclude lists and a sanitizer pass for files with
  mixed public/private content (CLAUDE.md ## Memory section,
  installed_plugins.json local-scoped entries, settings.json
  mempalace-wake.sh hook entries)

**Configuration sync** (commits 3-5, 11):
- Replace remote-settings.json with curated public allowlist
- Sync CLAUDE.md, settings.json, policy-limits.json (sanitized)
- Sync installed_plugins.json and existing hook updates
- Sync 12 cursor files

**New tracked content** (commits 6-9):
- Add agents/ (4 files)
- Add rules/ (7 files) — fixes broken @-references in CLAUDE.md
- Add skills/ (10 generic skills; 2 NVIDIA-internal skills excluded)
- Add hooks/ (7 new hooks; mempalace-wake.sh excluded)

**Docs** (commit 12):
- Refresh README counts and feature lists (surface-level only;
  docs/claude-code.md, docs/cursor.md, docs/skills-and-commands.md
  unchanged for follow-up)

## Verification

- `./scripts/diff.sh` shows only intentional NVIDIA-internal entries as live-only
- `grep -r` for NVIDIA-internal terms returns zero hits in tracked content
- Sanitizer idempotent: running capture.sh twice produces no second-round diff
- All 11 commits signed (DCO + GPG)
EOF
)"
```
Expected: PR created in draft state; URL printed.

- [ ] **Step 3: Self-review the PR diff in GitHub UI**

Open the PR URL and walk each commit individually. Confirm:
- No NVIDIA-internal paths or strings in any committed file
- Each commit's files match its subject
- Sanitizer output is correct (CLAUDE.md has no `## Memory` section,
  `installed_plugins.json` has no `local`-scoped entries,
  `settings.json` has no `mempalace-wake.sh` reference)

- [ ] **Step 4: Mark PR ready when satisfied**

```bash
gh pr ready
```

---

## Out of scope for this plan

- Refresh `docs/claude-code.md`, `docs/cursor.md`,
  `docs/skills-and-commands.md` to describe the new agents/rules/skills
  categories in depth (follow-up PR).
- Rename `.cursor/skills-cursor/` to `.cursor/skills/` to match Cursor's
  native convention (separate refactor PR).
- Document the public-safe sanitizer policy in `docs/deployment.md`
  (follow-up PR).

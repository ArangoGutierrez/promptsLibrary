# Environment Replication Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Restructure the promptsLibrary repo so `.claude/` and `.cursor/` at repo root mirror `~/` exactly, with deploy/capture/diff scripts.

**Architecture:** Bare mirror — repo root contains `.claude/` and `.cursor/` that are rsync'd to `~/` on deploy. Three utility scripts handle deploy, capture (reverse sync), and diff. CI workflows updated for new paths.

**Tech Stack:** Bash (scripts), GitHub Actions (CI), rsync (deploy)

---

### Task 1: Create the new .claude/ directory from live environment

**Files:**

- Create: `.claude/CLAUDE.md` (copy from `~/.claude/CLAUDE.md`)
- Create: `.claude/settings.json` (copy from `~/.claude/settings.json`)
- Create: `.claude/remote-settings.json` (copy from `~/.claude/remote-settings.json`)
- Create: `.claude/policy-limits.json` (copy from `~/.claude/policy-limits.json`)
- Create: `.claude/.claudeignore` (copy from `~/.claude/.claudeignore`)
- Create: `.claude/plugins/installed_plugins.json` (copy from `~/.claude/plugins/installed_plugins.json`)
- Create: `.claude/hooks/inject-date.sh` (copy from `~/.claude/hooks/inject-date.sh`)
- Create: `.claude/hooks/sign-commits.sh` (copy from `~/.claude/hooks/sign-commits.sh`)
- Create: `.claude/hooks/prevent-push-workbench.sh` (copy from `~/.claude/hooks/prevent-push-workbench.sh`)
- Create: `.claude/hooks/enforce-worktree.sh` (copy from `~/.claude/hooks/enforce-worktree.sh`)
- Create: `.claude/hooks/validate-year.sh` (copy from `~/.claude/hooks/validate-year.sh`)
- Create: `.claude/hooks/tdd-guard.sh` (copy from `~/.claude/hooks/tdd-guard.sh`)

**Step 1: Copy live .claude config files into repo**

```bash
# From repo root
mkdir -p .claude/hooks .claude/plugins

# Core configs
cp ~/.claude/CLAUDE.md .claude/
cp ~/.claude/settings.json .claude/
cp ~/.claude/remote-settings.json .claude/
cp ~/.claude/policy-limits.json .claude/
cp ~/.claude/.claudeignore .claude/

# Hooks
cp ~/.claude/hooks/inject-date.sh .claude/hooks/
cp ~/.claude/hooks/sign-commits.sh .claude/hooks/
cp ~/.claude/hooks/prevent-push-workbench.sh .claude/hooks/
cp ~/.claude/hooks/enforce-worktree.sh .claude/hooks/
cp ~/.claude/hooks/validate-year.sh .claude/hooks/
cp ~/.claude/hooks/tdd-guard.sh .claude/hooks/

# Plugin manifest (not the cache)
cp ~/.claude/plugins/installed_plugins.json .claude/plugins/

# Ensure hooks are executable
chmod +x .claude/hooks/*.sh
```

**Step 2: Verify the copy matches live**

Run: `diff -r --exclude='*.jsonl' --exclude='debug' --exclude='projects' --exclude='teams' --exclude='tasks' --exclude='todos' --exclude='cache' --exclude='file-history' --exclude='session-env' --exclude='shell-snapshots' --exclude='paste-cache' --exclude='telemetry' --exclude='backups' --exclude='ide' --exclude='plans' --exclude='stats-cache.json' --exclude='history.jsonl' --exclude='known_marketplaces.json' --exclude='commands' --exclude='docs' --exclude='team' --exclude='settings.local.json' ~/.claude/ .claude/`

Expected: Only runtime files differ; config files should be identical.

**Step 3: Commit**

```bash
git add .claude/
git commit -s -S -m "feat: add .claude/ mirror from live environment

Captures the canonical Claude Code configuration from ~/.claude:
- CLAUDE.md engineering standards
- settings.json with permissions, hooks, plugins config
- remote-settings.json and policy-limits.json
- .claudeignore context exclusions
- 6 hook scripts (inject-date, sign-commits, prevent-push-workbench,
  enforce-worktree, validate-year, tdd-guard)
- Plugin manifest (installed_plugins.json)"
```

---

### Task 2: Create the new .cursor/ directory from live environment

**Files:**

- Create: `.cursor/agents/` (12 agent files from `~/.cursor/agents/`)
- Create: `.cursor/rules/` (5 .mdc files from `~/.cursor/rules/`)
- Create: `.cursor/hooks/` (5 hook scripts from `~/.cursor/hooks/`)
- Create: `.cursor/hooks.json` (from `~/.cursor/hooks.json`)
- Create: `.cursor/commands/` (17 commands — resolve symlinks to actual files)
- Create: `.cursor/skills-cursor/` (5 skill directories from `~/.cursor/skills-cursor/`)
- Create: `.cursor/schemas/` (3 schema files from `~/.cursor/schemas/`)
- Create: `.cursor/mcp.json` (from `~/.cursor/mcp.json`)
- Create: `.cursor/.gitignore` (from `~/.cursor/.gitignore`)

**Step 1: Copy live .cursor config files into repo**

```bash
# From repo root
mkdir -p .cursor

# Agents (12 files)
cp -r ~/.cursor/agents/ .cursor/agents/

# Rules (5 .mdc files)
cp -r ~/.cursor/rules/ .cursor/rules/

# Hooks (5 scripts + config)
cp -r ~/.cursor/hooks/ .cursor/hooks/
cp ~/.cursor/hooks.json .cursor/

# Commands — resolve symlinks to actual file contents
mkdir -p .cursor/commands
for cmd in ~/.cursor/commands/*.md; do
  cp -L "$cmd" .cursor/commands/  # -L follows symlinks
done

# Skills (5 Cursor-native skills, each with SKILL.md)
cp -r ~/.cursor/skills-cursor/ .cursor/skills-cursor/

# Schemas
cp -r ~/.cursor/schemas/ .cursor/schemas/

# Other config
cp ~/.cursor/mcp.json .cursor/
cp ~/.cursor/.gitignore .cursor/

# Ensure hooks are executable
chmod +x .cursor/hooks/*.sh
```

**Step 2: Verify file counts match**

Run:

```bash
echo "Agents: $(ls .cursor/agents/*.md | wc -l) (expected 12)"
echo "Rules: $(ls .cursor/rules/*.mdc | wc -l) (expected 5)"
echo "Hooks: $(ls .cursor/hooks/*.sh | wc -l) (expected 5)"
echo "Commands: $(ls .cursor/commands/*.md | wc -l) (expected 17)"
echo "Skills: $(ls -d .cursor/skills-cursor/*/ | wc -l) (expected 5)"
echo "Schemas: $(ls .cursor/schemas/*.json | wc -l) (expected 3)"
```

Expected: All counts match.

**Step 3: Commit**

```bash
git add .cursor/
git commit -s -S -m "feat: add .cursor/ mirror from live environment

Captures the canonical Cursor configuration from ~/.cursor:
- 12 custom agents (researcher, auditor, arch-explorer, etc.)
- 5 rules (core, tdd, workbench, go, k8s)
- 5 hook scripts (format, sign-commits, security-gate, task-loop, context-monitor)
- 17 slash commands (resolved from symlinks to actual files)
- 5 Cursor-native skills (create-rule, create-skill, etc.)
- 3 JSON schemas
- MCP config and .gitignore"
```

---

### Task 3: Remove old directories

**Files:**

- Delete: `claude/` (entire directory)
- Delete: `cursor/` (entire directory)
- Delete: `prompts/` (entire directory — deprecated)
- Delete: `snippets/` (entire directory)
- Delete: `configs/` (entire directory)
- Delete: old scripts: `scripts/deploy-cursor.sh`, `scripts/deploy-claude.sh`, `scripts/init-project.sh`, `scripts/sync-optimized.sh`, `scripts/test-agent-models.sh`

**Step 1: Remove old directories**

```bash
git rm -r claude/
git rm -r cursor/
git rm -r prompts/
git rm -r snippets/
git rm -r configs/
git rm scripts/deploy-cursor.sh scripts/deploy-claude.sh scripts/init-project.sh scripts/sync-optimized.sh scripts/test-agent-models.sh
```

**Step 2: Verify removal**

Run: `ls -la` — should show only `.claude/`, `.cursor/`, `.github/`, `docs/`, `scripts/` (empty or near-empty), and root files.

**Step 3: Commit**

```bash
git commit -s -S -m "refactor: remove old directory structure

Removes directories superseded by the bare mirror layout:
- claude/ → replaced by .claude/
- cursor/ → replaced by .cursor/
- prompts/ → deprecated
- snippets/ → unused
- configs/ → folded into mirror
- Old deploy scripts → replaced in next commit"
```

---

### Task 4: Update .gitignore

**Files:**

- Modify: `.gitignore`

**Step 1: Write new .gitignore**

Replace the current `.gitignore` with one that:

- Removes the `.cursor/` exclusion (we now WANT it tracked)
- Adds runtime data exclusions for both `.claude/` and `.cursor/`
- Keeps OS/editor/env exclusions

```gitignore
# OS generated files
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db

# Editor directories and files
.idea/
.vscode/
*.swp
*.swo
*~
.project
.settings/

# Environment and secrets
.env
.env.local
.env.*.local
*.pem
*.key
credentials.json
secrets.yaml

# Logs
*.log
logs/

# Temporary files
tmp/
temp/
*.tmp

# Build outputs
dist/
build/

# Archives and backups
*.tar.gz
*.zip
*.tar
*.backup

# Generated outputs
AUDIT_REPORT.md
ISSUE_RESEARCH.md
*.generated.md
.plans/
.prototypes/

# ── Claude Code runtime (never tracked) ──
.claude/debug/
.claude/projects/
.claude/teams/
.claude/tasks/
.claude/todos/
.claude/cache/
.claude/file-history/
.claude/session-env/
.claude/shell-snapshots/
.claude/paste-cache/
.claude/telemetry/
.claude/backups/
.claude/ide/
.claude/plans/
.claude/history.jsonl
.claude/stats-cache.json
.claude/plugins/cache/
.claude/plugins/known_marketplaces.json
.claude/commands/
.claude/docs/
.claude/team/
.claude/settings.local.json

# ── Cursor runtime (never tracked) ──
.cursor/extensions/
.cursor/projects/
.cursor/ai-tracking/
.cursor/snapshots/
.cursor/ide_state.json
.cursor/argv.json
.cursor/unified_repo_list.json
.cursor/worktrees/
.cursor/blocklist
.cursor/.deploy-version
.cursor/docs/
.cursor/skills/
```

**Step 2: Verify .gitignore works**

Run: `git status` — should show `.gitignore` as modified, no unexpected tracked files.

**Step 3: Commit**

```bash
git add .gitignore
git commit -s -S -m "chore: update .gitignore for bare mirror layout

Track .claude/ and .cursor/ config files while excluding all
runtime data (debug logs, sessions, caches, teams, tasks, etc.)."
```

---

### Task 5: Write scripts/deploy.sh

**Files:**

- Create: `scripts/deploy.sh`

**Step 1: Write the deploy script**

```bash
#!/bin/bash
set -euo pipefail

# deploy.sh — Deploy .claude/ and .cursor/ configs to ~/
# Usage: ./scripts/deploy.sh [--dry-run] [--force] [--claude-only] [--cursor-only] [--no-plugins] [--delete]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

DRY_RUN=false
FORCE=false
CLAUDE_ONLY=false
CURSOR_ONLY=false
NO_PLUGINS=false
DELETE_FLAG=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run)    DRY_RUN=true; shift ;;
    --force)      FORCE=true; shift ;;
    --claude-only) CLAUDE_ONLY=true; shift ;;
    --cursor-only) CURSOR_ONLY=true; shift ;;
    --no-plugins) NO_PLUGINS=true; shift ;;
    --delete)     DELETE_FLAG="--delete"; shift ;;
    -h|--help)
      echo "Usage: $0 [--dry-run] [--force] [--claude-only] [--cursor-only] [--no-plugins] [--delete]"
      echo ""
      echo "Flags:"
      echo "  --dry-run      Show what would change without doing it"
      echo "  --force        Skip backup prompt"
      echo "  --claude-only  Deploy only .claude/ configs"
      echo "  --cursor-only  Deploy only .cursor/ configs"
      echo "  --no-plugins   Skip plugin installation"
      echo "  --delete       Remove files in target not in repo (careful!)"
      exit 0
      ;;
    *) echo "Unknown flag: $1"; exit 1 ;;
  esac
done

# Runtime dirs to exclude from sync
CLAUDE_EXCLUDES=(
  debug/ projects/ teams/ tasks/ todos/ cache/ file-history/
  session-env/ shell-snapshots/ paste-cache/ telemetry/ backups/
  ide/ plans/ history.jsonl stats-cache.json plugins/cache/
  plugins/known_marketplaces.json commands/ docs/ team/
  settings.local.json
)

CURSOR_EXCLUDES=(
  extensions/ projects/ ai-tracking/ snapshots/ ide_state.json
  argv.json unified_repo_list.json worktrees/ blocklist
  .deploy-version docs/ skills/
)

rsync_cmd() {
  local src="$1" dest="$2"
  shift 2
  local excludes=("$@")

  local args=(-av --chmod=F644,D755)
  $DRY_RUN && args+=(--dry-run)
  [ -n "$DELETE_FLAG" ] && args+=($DELETE_FLAG)

  for ex in "${excludes[@]}"; do
    args+=(--exclude="$ex")
  done

  rsync "${args[@]}" "$src" "$dest"
}

backup() {
  local target="$1" name="$2"
  if [ -d "$target" ] && ! $FORCE; then
    local backup_dir="$HOME/.config/dotfiles-backup"
    mkdir -p "$backup_dir"
    local timestamp
    timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_file="$backup_dir/${name}-${timestamp}.tar.gz"
    echo "Backing up $target → $backup_file"
    tar -czf "$backup_file" -C "$HOME" "$name" 2>/dev/null || true
    echo "Backup saved."
  fi
}

# Deploy .claude/
if ! $CURSOR_ONLY; then
  echo "═══ Deploying .claude/ ═══"
  backup "$HOME/.claude" ".claude"
  rsync_cmd "$REPO_DIR/.claude/" "$HOME/.claude/" "${CLAUDE_EXCLUDES[@]}"
  chmod +x "$HOME/.claude/hooks/"*.sh 2>/dev/null || true

  if ! $NO_PLUGINS && ! $DRY_RUN && [ -f "$HOME/.claude/plugins/installed_plugins.json" ]; then
    echo ""
    echo "Plugin manifest deployed. Install plugins manually with:"
    echo "  claude plugins install <plugin-name>"
    echo ""
    echo "Configured plugins:"
    jq -r 'keys[]' "$HOME/.claude/plugins/installed_plugins.json" 2>/dev/null || true
  fi
  echo ""
fi

# Deploy .cursor/
if ! $CLAUDE_ONLY; then
  echo "═══ Deploying .cursor/ ═══"
  backup "$HOME/.cursor" ".cursor"
  rsync_cmd "$REPO_DIR/.cursor/" "$HOME/.cursor/" "${CURSOR_EXCLUDES[@]}"
  chmod +x "$HOME/.cursor/hooks/"*.sh 2>/dev/null || true
  echo ""
fi

# Verify
echo "═══ Verification ═══"
errors=0

if ! $CURSOR_ONLY; then
  for f in "$HOME/.claude/CLAUDE.md" "$HOME/.claude/settings.json"; do
    if [ -f "$f" ]; then
      echo "✓ $f exists"
    else
      echo "✗ $f missing"
      errors=$((errors + 1))
    fi
  done
  for hook in "$HOME/.claude/hooks/"*.sh; do
    if [ -x "$hook" ]; then
      echo "✓ $(basename "$hook") is executable"
    else
      echo "✗ $(basename "$hook") is not executable"
      errors=$((errors + 1))
    fi
  done
  # Validate JSON
  for json in "$HOME/.claude/settings.json" "$HOME/.claude/remote-settings.json" "$HOME/.claude/policy-limits.json"; do
    if [ -f "$json" ] && jq empty "$json" 2>/dev/null; then
      echo "✓ $(basename "$json") is valid JSON"
    elif [ -f "$json" ]; then
      echo "✗ $(basename "$json") is invalid JSON"
      errors=$((errors + 1))
    fi
  done
fi

if ! $CLAUDE_ONLY; then
  for f in "$HOME/.cursor/hooks.json"; do
    if [ -f "$f" ] && jq empty "$f" 2>/dev/null; then
      echo "✓ $(basename "$f") is valid JSON"
    elif [ -f "$f" ]; then
      echo "✗ $(basename "$f") is invalid JSON"
      errors=$((errors + 1))
    fi
  done
  echo "✓ .cursor/agents: $(ls "$HOME/.cursor/agents/"*.md 2>/dev/null | wc -l | tr -d ' ') files"
  echo "✓ .cursor/rules: $(ls "$HOME/.cursor/rules/"*.mdc 2>/dev/null | wc -l | tr -d ' ') files"
  echo "✓ .cursor/commands: $(ls "$HOME/.cursor/commands/"*.md 2>/dev/null | wc -l | tr -d ' ') files"
fi

if [ $errors -eq 0 ]; then
  echo ""
  echo "Deploy complete."
else
  echo ""
  echo "Deploy completed with $errors error(s)."
  exit 1
fi
```

**Step 2: Make executable and test dry-run**

Run: `chmod +x scripts/deploy.sh && ./scripts/deploy.sh --dry-run`

Expected: Shows what rsync would do without making changes.

**Step 3: Commit**

```bash
git add scripts/deploy.sh
git commit -s -S -m "feat: add unified deploy script

Single script to rsync .claude/ and .cursor/ configs to ~/.
Supports --dry-run, --force, --claude-only, --cursor-only,
--no-plugins, and --delete flags. Backs up existing configs
before overwriting."
```

---

### Task 6: Write scripts/capture.sh

**Files:**

- Create: `scripts/capture.sh`

**Step 1: Write the capture script**

```bash
#!/bin/bash
set -euo pipefail

# capture.sh — Capture live environment changes back into repo
# Usage: ./scripts/capture.sh [--claude-only] [--cursor-only]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

CLAUDE_ONLY=false
CURSOR_ONLY=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --claude-only) CLAUDE_ONLY=true; shift ;;
    --cursor-only) CURSOR_ONLY=true; shift ;;
    -h|--help)
      echo "Usage: $0 [--claude-only] [--cursor-only]"
      exit 0
      ;;
    *) echo "Unknown flag: $1"; exit 1 ;;
  esac
done

CLAUDE_EXCLUDES=(
  debug/ projects/ teams/ tasks/ todos/ cache/ file-history/
  session-env/ shell-snapshots/ paste-cache/ telemetry/ backups/
  ide/ plans/ history.jsonl stats-cache.json plugins/cache/
  plugins/known_marketplaces.json commands/ docs/ team/
  settings.local.json
)

CURSOR_EXCLUDES=(
  extensions/ projects/ ai-tracking/ snapshots/ ide_state.json
  argv.json unified_repo_list.json worktrees/ blocklist
  .deploy-version docs/ skills/
)

rsync_capture() {
  local src="$1" dest="$2"
  shift 2
  local excludes=("$@")

  local args=(-av --chmod=F644,D755)
  for ex in "${excludes[@]}"; do
    args+=(--exclude="$ex")
  done

  rsync "${args[@]}" "$src" "$dest"
}

if ! $CURSOR_ONLY; then
  echo "═══ Capturing ~/.claude/ → repo ═══"
  rsync_capture "$HOME/.claude/" "$REPO_DIR/.claude/" "${CLAUDE_EXCLUDES[@]}"
  chmod +x "$REPO_DIR/.claude/hooks/"*.sh 2>/dev/null || true
  echo ""
fi

if ! $CLAUDE_ONLY; then
  echo "═══ Capturing ~/.cursor/ → repo ═══"
  # Resolve symlinks when capturing commands
  rsync_capture "$HOME/.cursor/" "$REPO_DIR/.cursor/" "${CURSOR_EXCLUDES[@]}"
  # Re-copy commands with -L to resolve symlinks
  for cmd in "$HOME/.cursor/commands/"*.md; do
    [ -f "$cmd" ] && cp -L "$cmd" "$REPO_DIR/.cursor/commands/"
  done
  chmod +x "$REPO_DIR/.cursor/hooks/"*.sh 2>/dev/null || true
  echo ""
fi

echo "═══ Changes captured. Review with: ═══"
echo "  git diff"
echo "  git diff --stat"
echo ""
echo "Commit when ready:"
echo "  git add .claude/ .cursor/"
echo "  git commit -s -S -m 'chore: capture environment changes'"
```

**Step 2: Make executable**

Run: `chmod +x scripts/capture.sh`

**Step 3: Commit**

```bash
git add scripts/capture.sh
git commit -s -S -m "feat: add capture script for reverse sync

Copies config files from ~/.claude and ~/.cursor back into repo,
excluding runtime data. Resolves symlinks in commands/."
```

---

### Task 7: Write scripts/diff.sh

**Files:**

- Create: `scripts/diff.sh`

**Step 1: Write the diff script**

```bash
#!/bin/bash
set -euo pipefail

# diff.sh — Show differences between repo and live environment
# Usage: ./scripts/diff.sh [--claude-only] [--cursor-only]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

CLAUDE_ONLY=false
CURSOR_ONLY=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --claude-only) CLAUDE_ONLY=true; shift ;;
    --cursor-only) CURSOR_ONLY=true; shift ;;
    -h|--help)
      echo "Usage: $0 [--claude-only] [--cursor-only]"
      exit 0
      ;;
    *) echo "Unknown flag: $1"; exit 1 ;;
  esac
done

CLAUDE_RUNTIME="debug|projects|teams|tasks|todos|cache|file-history|session-env|shell-snapshots|paste-cache|telemetry|backups|ide|plans|commands|docs|team"
CURSOR_RUNTIME="extensions|projects|ai-tracking|snapshots|worktrees|docs|skills"

has_diff=false

if ! $CURSOR_ONLY; then
  echo "═══ .claude/ differences ═══"
  echo ""
  if diff -r \
    --exclude-from=<(printf '%s\n' debug projects teams tasks todos cache file-history session-env shell-snapshots paste-cache telemetry backups ide plans commands docs team settings.local.json history.jsonl stats-cache.json known_marketplaces.json) \
    "$REPO_DIR/.claude/" "$HOME/.claude/" 2>/dev/null; then
    echo "No differences found."
  else
    has_diff=true
  fi
  echo ""
fi

if ! $CLAUDE_ONLY; then
  echo "═══ .cursor/ differences ═══"
  echo ""
  # For commands, we need to compare against resolved symlinks
  # First compare non-command files
  if diff -r \
    --exclude-from=<(printf '%s\n' extensions projects ai-tracking snapshots worktrees docs skills ide_state.json argv.json unified_repo_list.json blocklist .deploy-version commands) \
    "$REPO_DIR/.cursor/" "$HOME/.cursor/" 2>/dev/null; then
    echo "Non-command files: no differences."
  else
    has_diff=true
  fi

  # Then compare commands (resolving symlinks)
  echo ""
  echo "── Commands ──"
  for cmd in "$REPO_DIR/.cursor/commands/"*.md; do
    [ -f "$cmd" ] || continue
    name=$(basename "$cmd")
    live="$HOME/.cursor/commands/$name"
    if [ -f "$live" ]; then
      # Resolve symlink if needed
      live_resolved=$(readlink -f "$live" 2>/dev/null || echo "$live")
      if ! diff -q "$cmd" "$live_resolved" >/dev/null 2>&1; then
        echo "CHANGED: $name"
        diff "$cmd" "$live_resolved" || true
        has_diff=true
      fi
    else
      echo "REPO ONLY: $name"
      has_diff=true
    fi
  done
  # Check for live-only commands
  for cmd in "$HOME/.cursor/commands/"*.md; do
    [ -f "$cmd" ] || continue
    name=$(basename "$cmd")
    if [ ! -f "$REPO_DIR/.cursor/commands/$name" ]; then
      echo "LIVE ONLY: $name"
      has_diff=true
    fi
  done
  echo ""
fi

if $has_diff; then
  echo "Differences found. Run ./scripts/capture.sh to update repo."
else
  echo "Everything in sync."
fi
```

**Step 2: Make executable**

Run: `chmod +x scripts/diff.sh`

**Step 3: Commit**

```bash
git add scripts/diff.sh
git commit -s -S -m "feat: add diff script to detect environment drift

Compares repo configs against live ~/.claude and ~/.cursor,
excluding runtime data. Resolves symlinks for command comparison."
```

---

### Task 8: Update CI workflows

**Files:**

- Modify: `.github/workflows/validate-cursor.yml` (update paths from `cursor/` to `.cursor/`)
- Modify: `.github/workflows/links.yml` (update paths)
- Modify: `.github/workflows/lint.yml` (update exclusions)
- Delete: `.github/workflows/validate-prompts.yml` (prompts/ removed)

**Step 1: Update validate-cursor.yml paths**

All references to `cursor/` become `.cursor/`:

- Trigger paths: `cursor/**` → `.cursor/**`
- `cursor/hooks.json` → `.cursor/hooks.json`
- `cursor/hooks/*.sh` → `.cursor/hooks/*.sh`
- `cursor/agents/*.md` → `.cursor/agents/*.md`
- `cursor/commands/*.md` → `.cursor/commands/*.md`
- `cursor/skills/*/` → `.cursor/skills-cursor/*/`
- `cursor/rules/*.md` → `.cursor/rules/*.mdc` (note: live uses .mdc extension)
- `cursor/schemas/` → `.cursor/schemas/`
- `cursor/_optimized/` references → remove (sync drift check no longer needed)
- Remove the "Check for sync drift" step entirely (no more _optimized variants)

**Step 2: Update links.yml**

Change `claude/README.md` to just `README.md` (or remove if the main README covers it).

**Step 3: Update lint.yml**

Update exclusions:

- Remove `!cursor/**` exclusion (no longer at that path)
- Add `!.cursor/**` and `!.claude/**` if we want to exclude them from markdown lint
- Remove `!prompts/**` and `!snippets/**` (directories deleted)

**Step 4: Remove validate-prompts.yml**

```bash
git rm .github/workflows/validate-prompts.yml
```

**Step 5: Commit**

```bash
git add .github/workflows/
git commit -s -S -m "chore: update CI workflows for bare mirror layout

- validate-cursor.yml: paths updated from cursor/ to .cursor/,
  removed _optimized sync drift check, fixed .mdc extension
- links.yml: updated doc paths
- lint.yml: updated exclusions
- Removed validate-prompts.yml (prompts/ directory removed)"
```

---

### Task 9: Update README.md

**Files:**

- Modify: `README.md`

**Step 1: Rewrite README for the new structure**

The README should cover:

- What this repo is (personal dotfiles for Claude Code + Cursor)
- Quick start (`git clone && ./scripts/deploy.sh`)
- What's included (overview of .claude/ and .cursor/ contents)
- How to customize (fork, edit, deploy)
- Workflow: edit live → `capture.sh` → commit → push
- Scripts reference (deploy, capture, diff)
- Keep LICENSE and contribution info

**Step 2: Commit**

```bash
git add README.md
git commit -s -S -m "docs: rewrite README for bare mirror layout

Quick start, what's included, customization guide,
and scripts reference for the new dotfiles structure."
```

---

### Task 10: Clean up remaining files

**Files:**

- Review: `docs/` — keep `docs/plans/` with design docs, remove obsolete docs
- Review: `.lycheeignore`, `.markdownlint.json`, `.typos.toml` — update if needed
- Review: `CODE_OF_CONDUCT.md`, `CONTRIBUTING.md`, `LICENSE` — keep as-is

**Step 1: Clean up docs/**

```bash
# Remove obsolete docs if any (the testing-agent-models.md may still be relevant)
# Keep docs/plans/ with the design documents
ls docs/
```

**Step 2: Update .lycheeignore if needed**

If lychee paths referenced `cursor/` or `claude/`, update them.

**Step 3: Final commit**

```bash
git add -A
git commit -s -S -m "chore: clean up remaining files after restructure

Remove obsolete documentation, update lychee/lint configs
for new directory layout."
```

---

### Task 11: Test the full workflow

**Step 1: Run diff to verify repo matches live**

```bash
./scripts/diff.sh
```

Expected: "Everything in sync" or only expected differences.

**Step 2: Test deploy dry-run**

```bash
./scripts/deploy.sh --dry-run
```

Expected: Shows rsync operations, no errors.

**Step 3: Test capture**

```bash
./scripts/capture.sh
git diff --stat  # Should show no changes if already in sync
```

**Step 4: Run CI checks locally**

```bash
# Validate JSON files
jq empty .claude/settings.json
jq empty .claude/remote-settings.json
jq empty .claude/policy-limits.json
jq empty .cursor/hooks.json

# Check hooks are executable
ls -la .claude/hooks/*.sh
ls -la .cursor/hooks/*.sh

# Check shell syntax
for f in .claude/hooks/*.sh .cursor/hooks/*.sh; do bash -n "$f" && echo "✓ $f"; done
```

**Step 5: Final commit if any fixes needed**

```bash
git add -A
git commit -s -S -m "fix: address issues found during testing"
```

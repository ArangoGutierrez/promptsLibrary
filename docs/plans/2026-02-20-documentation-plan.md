# Documentation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create comprehensive documentation for the AI Engineering Dotfiles repo targeting the broader developer community.

**Architecture:** Flat `/docs` directory with 7 topic files + rewritten root README. GitHub-rendered Markdown with Mermaid diagrams. No build step.

**Tech Stack:** Markdown, Mermaid diagrams, GitHub-flavored Markdown

**Design doc:** `docs/plans/2026-02-20-documentation-design.md`

---

### Task 1: Create `docs/README.md` — Documentation Index

**Files:**

- Create: `docs/README.md`

**Step 1: Write the docs index**

Create `docs/README.md` with:

```markdown
# Documentation

Welcome to the AI Engineering Dotfiles documentation. This repo configures [Claude Code](https://docs.anthropic.com/en/docs/claude-code) and [Cursor IDE](https://www.cursor.com/) with opinionated enforcement of TDD, signed commits, worktree-based development, and agent-driven workflows.

## Guides

| Document | Description |
|----------|-------------|
| [Getting Started](getting-started.md) | Prerequisites, installation, verification, and first workflow |
| [Architecture](architecture.md) | Deep-dive into the agents-workbench architecture with diagrams |

## Reference

| Document | Description |
|----------|-------------|
| [Claude Code Configuration](claude-code.md) | Hooks, settings, plugins, and policies |
| [Cursor Configuration](cursor.md) | Agents, commands, rules, and hooks |
| [Deployment Scripts](deployment.md) | deploy.sh, capture.sh, and diff.sh explained |
| [Skills & Commands Reference](skills-and-commands.md) | Complete reference of all slash commands and skills |

## Internal

| Document | Description |
|----------|-------------|
| [Design Plans](plans/) | Internal design documents and implementation plans |
```

**Step 2: Commit**

```bash
git add docs/README.md
git commit -s -S -m "docs: add documentation index"
```

---

### Task 2: Write `docs/getting-started.md` — Extended Quickstart

**Files:**

- Create: `docs/getting-started.md`

**Step 1: Write the getting started guide**

Sections (with approximate content):

1. **Prerequisites** — List with install commands:
   - macOS or Linux
   - Git 2.20+ (for worktree support)
   - jq (`brew install jq` / `apt install jq`)
   - GPG with a signing key configured (`gpg --list-keys`)
   - rsync (`brew install rsync` / usually pre-installed)

2. **Installation** — Three steps:

   ```bash
   git clone https://github.com/ArangoGutierrez/promptsLibrary.git
   cd promptsLibrary
   ./scripts/deploy.sh --dry-run  # preview first
   ./scripts/deploy.sh            # deploy with automatic backup
   ```

   Explain: what deploy.sh does (rsync to ~/), what gets backed up, where backups go (`~/.config/dotfiles-backup/`)

3. **Verify Installation** — Commands to confirm:
   - Check hooks are executable: `ls -la ~/.claude/hooks/`
   - Test signed commit enforcement: try `git commit -m "test"` → should be blocked
   - Test TDD guard: try writing an implementation file without a test → should be blocked
   - Check Claude Code plugins: open Claude Code and verify plugins loaded

4. **Your First Workflow** — Mini walkthrough:
   - Set up agents-workbench: `git checkout -b agents-workbench`
   - Create a worktree: the `git fetch + worktree add` pattern from CLAUDE.md
   - Write a failing test in the worktree
   - Write implementation to make it pass
   - Commit with `-s -S`
   - Push feature branch

5. **Customization** — Brief pointers:
   - To disable a hook: remove it from `settings.json` hooks array
   - To change permissions: edit `settings.json` allow/deny lists
   - To add Cursor agents: create `.md` file in `.cursor/agents/`
   - To add Cursor commands: create `.md` file in `.cursor/commands/`
   - Full details in the reference docs (link to claude-code.md and cursor.md)

6. **Troubleshooting** — Common issues:
   - "GPG not found" → install GPG, configure signing key
   - "Permission denied" on hooks → `chmod +x ~/.claude/hooks/*.sh`
   - Worktree conflicts → `git worktree list` to find stale entries, `git worktree prune`
   - TDD guard blocking unexpectedly → create a test file first, or `SKIP_TDD_GUARD=1` for one-off
   - Deploy overwrote my changes → check `~/.config/dotfiles-backup/` for automatic backups

Target: ~200-300 lines.

**Step 2: Commit**

```bash
git add docs/getting-started.md
git commit -s -S -m "docs: add getting started guide"
```

---

### Task 3: Write `docs/architecture.md` — Agents-Workbench Deep-Dive

**Files:**

- Create: `docs/architecture.md`

**Step 1: Write the architecture document**

This is the centerpiece. Sections:

1. **The Problem** (~50 lines)
   - AI coding assistants (Claude Code, Cursor) can make unbounded edits to your working tree
   - Without guardrails: edits directly on main, no test discipline, unsigned commits, no isolation between concurrent features
   - This config solves it with a layered enforcement architecture

2. **Core Concepts** (~80 lines)

   **agents-workbench branch:**
   - A local-only branch that is NEVER pushed to any remote
   - Source code is READ-ONLY on this branch (enforced by `enforce-worktree.sh`)
   - Used for coordination: AGENTS.md, design docs, plans
   - Think of it as the "control tower" — you plan here, implement elsewhere

   **Worktrees:**
   - Git worktrees are separate working directories sharing the same `.git`
   - Each feature gets its own worktree in `.worktrees/<name>/`
   - ALWAYS branched from the remote ref (not local main, which may be stale)
   - Isolation: changes in one worktree don't affect another

   **Hook enforcement:**
   - The architecture is not just convention — it's enforced by hooks
   - 6 Claude hooks + 5 Cursor hooks fire on every action
   - You literally cannot violate the architecture without disabling hooks

3. **Architecture Diagram** (~40 lines)

   Mermaid diagram showing:

   ```
   graph TD
     subgraph "Remote (GitHub)"
       ORIGIN[origin/main]
     end
     subgraph "Local Repository"
       MAIN[main branch]
       AWB[agents-workbench branch<br/>LOCAL ONLY • READ-ONLY source]
       subgraph "Coordination Files (editable on AWB)"
         AGENTS[AGENTS.md]
         PLANS[docs/plans/*]
         DOTAGENTS[.agents/*]
       end
       subgraph ".worktrees/"
         WT1[feature-a/<br/>branch: feat/feature-a]
         WT2[feature-b/<br/>branch: feat/feature-b]
       end
     end
     ORIGIN -->|git fetch| MAIN
     MAIN -->|git worktree add| WT1
     MAIN -->|git worktree add| WT2
     WT1 -->|git push| ORIGIN
     WT2 -->|git push| ORIGIN
     AWB --> AGENTS
     AWB --> PLANS
   ```

4. **Lifecycle of a Feature** (~120 lines)

   Step-by-step walkthrough with actual commands:

   **Phase 1: Plan (on agents-workbench)**

   ```bash
   git checkout agents-workbench
   # Use brainstorming skill → design doc saved to docs/plans/
   # Update AGENTS.md with task breakdown
   ```

   **Phase 2: Create Worktree (from remote ref)**

   ```bash
   git fetch upstream 2>/dev/null && \
     BASE="upstream/$(git symbolic-ref refs/remotes/upstream/HEAD 2>/dev/null | \
     sed 's@^refs/remotes/upstream/@@' || echo main)" || \
     { git fetch origin && \
       BASE="origin/$(git symbolic-ref refs/remotes/origin/HEAD | \
       sed 's@^refs/remotes/origin/@@')"; }
   git worktree add .worktrees/my-feature -b feat/my-feature "$BASE"
   cd .worktrees/my-feature
   ```

   Explain WHY from remote ref (local main may be stale after force-pushes or rebases).

   **Phase 3: TDD Cycle (in worktree)**

   ```
   [RED]    → Write failing test
   [GREEN]  → Minimal code to pass
   [REFACTOR] → Clean up (checkpoint first if >3 files or >50 LOC)
   ```

   Show the tdd-guard.sh blocking an implementation write without a test.

   **Phase 4: Push & PR**

   ```bash
   git push -u origin feat/my-feature
   gh pr create --title "feat: my feature" --body "..."
   ```

   **Phase 5: Cleanup**

   ```bash
   cd /path/to/repo
   git worktree remove .worktrees/my-feature
   ```

5. **Hook Enforcement Matrix** (~60 lines)

   Table covering ALL 11 hooks (6 Claude + 5 Cursor):

   | Hook | Tool | Trigger | What It Enforces | What It Blocks |
   |------|------|---------|-----------------|----------------|
   | inject-date.sh | Claude | SessionStart | Current date/year in context | N/A (informational) |
   | sign-commits.sh | Claude | Bash (git commit) | `-s -S` flags on commits | Unsigned/unsignedoff commits |
   | prevent-push-workbench.sh | Claude | Bash (git push) | agents-workbench stays local | Pushing workbench to any remote |
   | enforce-worktree.sh | Claude | Write/Edit | Source code read-only on AWB | Source edits on agents-workbench |
   | tdd-guard.sh | Claude | Write/Edit | Test-first discipline | Implementation without failing test |
   | validate-year.sh | Claude | Write (new files) | Current year in new files | Stale years in new files |
   | format.sh | Cursor | afterFileEdit | Auto-format (gofmt, jq) | N/A (auto-corrects) |
   | sign-commits.sh | Cursor | beforeShellExecution | `-s -S` flags | Unsigned commits |
   | security-gate.sh | Cursor | beforeShellExecution | Safe commands | `rm -rf /`, fork bombs, force-push main |
   | task-loop.sh | Cursor | stop | Loop iteration limit (5) | Infinite loops |
   | context-monitor.sh | Cursor | stop | Context health | N/A (placeholder) |

6. **Design Decisions & Rationale** (~80 lines)

   - **Why local-only workbench?** Prevents polluting remote with coordination state. Feature branches are the only thing pushed.
   - **Why branch from remote ref?** Local main can become stale after force-pushes or if you forget to pull. Remote ref is always authoritative.
   - **Why read-only source on workbench?** Prevents accidentally editing source in the wrong context. Forces isolation.
   - **Why hook enforcement instead of just conventions?** Conventions are forgotten under pressure. Hooks fire automatically on every action.
   - **Why TDD hooks?** AI agents will happily write implementation without tests unless mechanically prevented.
   - **Why signed commits?** DCO + GPG provides auditability of who wrote what, especially important with AI-assisted development.

Target: ~400-600 lines.

**Step 2: Commit**

```bash
git add docs/architecture.md
git commit -s -S -m "docs: add agents-workbench architecture deep-dive"
```

---

### Task 4: Write `docs/claude-code.md` — Claude Code Reference

**Files:**

- Create: `docs/claude-code.md`

**Step 1: Write the Claude Code reference**

Sections:

1. **Overview** (~20 lines)
   - What Claude Code is (Anthropic's CLI for Claude)
   - What this config adds (enforcement hooks, engineering standards, plugin ecosystem)
   - File layout: CLAUDE.md, settings.json, hooks/, plugins/, .claudeignore, policy-limits.json, remote-settings.json

2. **CLAUDE.md — Engineering Standards** (~60 lines)
   Walk through each section of .claude/CLAUDE.md:
   - **Role:** Senior Principal Engineer — rigor over speed
   - **Brainstorm First:** Every task starts with brainstorming. No exceptions. Quick-brainstorm for "just do it" requests
   - **Principles:** Atomicity, no placeholders, verify (CoVe), YAGNI, ≥3 options
   - **TDD Protocol (DORA):** Plan→Red→Green→Refactor cycle. Signals: [RED], [GREEN], [REFACTOR]. Never modify tests+code in same turn. Tests are contracts
   - **agents-workbench Workflow:** Branches, worktree creation, flow (link to architecture.md for deep-dive)
   - **Iteration Budget:** Trivial:1, Simple:2, Moderate:3, Complex:4 → escalate
   - **Priority:** Security > Correctness > Performance > Style
   - **Subagent Discipline:** Sequential subagents, prefer focused over broad

3. **Settings** (~80 lines)
   Walk through settings.json:
   - **Permissions model:** allow (Read, Write, Edit, Bash with specific tools), deny (secrets, .env, credentials), ask (rm, rebase, reset, force-push, sudo)
   - **Hooks configuration:** SessionStart (inject-date.sh), PreToolUse/Bash (sign-commits.sh, prevent-push-workbench.sh), PreToolUse/Write+Edit (enforce-worktree.sh, tdd-guard.sh, validate-year.sh)
   - **Plugins:** 4 enabled (code-review, code-simplifier, superpowers, gopls-lsp)
   - **Sandbox:** Enabled by default, auto-allow Bash
   - **Environment:** CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
   - **Network:** Restricted to github.com, teleport, NVIDIA gitlab

4. **Hooks** (~100 lines)
   Each hook gets a subsection:
   - **inject-date.sh** — Fires on SessionStart. Injects current date/year so AI never uses stale training data years in copyright headers or docs
   - **sign-commits.sh** — Fires on Bash (git commit). Blocks commits without both `-s` (DCO signoff) and `-S` (GPG signature). Example blocked output
   - **prevent-push-workbench.sh** — Fires on Bash (git push). Blocks pushing agents-workbench branch to any remote. Catches both explicit name and bare push when on branch
   - **enforce-worktree.sh** — Fires on Write/Edit. On agents-workbench, blocks all source code edits. Allows: AGENTS.md, .agents/*, docs/plans/*, CLAUDE.md, .cursor/rules/*. Elsewhere: allows all
   - **tdd-guard.sh** — Fires on Write/Edit. Blocks implementation file writes without a corresponding test file modified in current session. Allows: test files, config files (.json, .yaml, .md, etc.). Bypass: `SKIP_TDD_GUARD=1`
   - **validate-year.sh** — Fires on Write (new files only). Blocks files with copyright years from training data that don't match current year. Prevents stale years from being inserted

5. **Plugins** (~40 lines)
   - **code-review** — Automated code review suggestions
   - **code-simplifier** — Code simplification and clarity improvements
   - **superpowers** — Extended capabilities: brainstorming, TDD, debugging, planning, execution, git worktrees, parallel agents, code review, skills authoring
   - **gopls-lsp** — Go language server integration for Claude Code

6. **Policy & Ignore** (~30 lines)
   - **policy-limits.json** — Disables product feedback prompts and remote sessions
   - **.claudeignore** — Excludes from context: node_modules, vendor, dist, build, binaries, logs, cache, git objects, media. Prevents context bloat
   - **remote-settings.json** — Network restrictions: allowed domains (github.com, teleport, NVIDIA). Sandbox and permission overrides for remote use

Target: ~300-400 lines.

**Step 2: Commit**

```bash
git add docs/claude-code.md
git commit -s -S -m "docs: add Claude Code configuration reference"
```

---

### Task 5: Write `docs/cursor.md` — Cursor Reference

**Files:**

- Create: `docs/cursor.md`

**Step 1: Write the Cursor reference**

Sections:

1. **Overview** (~20 lines)
   - What Cursor IDE is
   - What this config adds (12 agents, 17 commands, 5 rules, 5 hooks, 3 schemas)
   - File layout: agents/, commands/, rules/, hooks/, skills-cursor/, schemas/

2. **Agents** (~150 lines)
   Each of the 12 agents gets a subsection with: purpose, when to use, key constraints, read-only status.

   Group by function:
   - **Research & Analysis:** researcher, arch-explorer, task-analyzer
   - **Review & Validation:** auditor, perf-critic, api-reviewer, verifier, review-triager
   - **Challenge & Synthesis:** devil-advocate, synthesizer
   - **Implementation:** prototyper (worktree-required, disposable), ci-doctor (worktree-required, max 2 fix attempts)

3. **Commands** (~150 lines)
   Each of the 17 commands gets: name, one-line description, flags, which agents it orchestrates (if any).

   Group by workflow:
   - **Architecture:** /architect (explorer→advocate→prototyper×2→synthesizer), /research, /issue
   - **Implementation:** /code, /task, /loop, /parallel, /worktree
   - **Quality:** /audit, /quality, /test, /self-review, /review-pr
   - **Git & CI:** /push, /git-polish, /merge-train, /context-reset

4. **Rules** (~60 lines)
   Each of the 5 MDC rules:
   - **core.mdc** — Workflow sequence, commit standards, TDD invariant, date/year rules, context economy
   - **tdd.mdc** — Phase signals ([RED]/[GREEN]/[REFACTOR]/[CHECKPOINT]), hard rules, checkpoint gating, security scans
   - **workbench.mdc** — Branch detection, read-only enforcement, coordination file list, worktree creation
   - **go.mdc** — Go standards: lint chain, documentation, error handling, naming, concurrency, table-driven tests, K8s patterns, security scans
   - **k8s.mdc** — Kubernetes: resource limits, probes, RBAC, network policies, operator patterns, Helm standards

5. **Hooks** (~50 lines)
   - **format.sh** (afterFileEdit) — Auto-formats .go (gofmt) and .json (jq) files after edits
   - **sign-commits.sh** (beforeShellExecution) — Same enforcement as Claude: `-s -S` on all commits
   - **security-gate.sh** (beforeShellExecution) — Blocks destructive commands: `rm -rf /`, fork bombs, filesystem overwrites. Warns on force-push to main/master
   - **task-loop.sh** (stop) — Prevents infinite task loops, limit of 5 iterations
   - **context-monitor.sh** (stop) — Placeholder for context health monitoring

6. **Schemas** (~20 lines)
   - Brief mention of 3 JSON schemas in `.cursor/schemas/`
   - What they validate: hooks configuration, agent state, input validation

Target: ~400-500 lines.

**Step 2: Commit**

```bash
git add docs/cursor.md
git commit -s -S -m "docs: add Cursor IDE configuration reference"
```

---

### Task 6: Write `docs/deployment.md` — Scripts Reference

**Files:**

- Create: `docs/deployment.md`

**Step 1: Write the deployment reference**

Sections:

1. **Overview** (~30 lines)
   - The deploy/capture/diff triad
   - Workflow diagram (Mermaid):

     ```
     graph LR
       REPO[Repo .claude/ .cursor/] -->|deploy.sh| LIVE[~/.claude/ ~/.cursor/]
       LIVE -->|capture.sh| REPO
       REPO <-->|diff.sh| LIVE
     ```

   - Typical workflow: edit live → capture → diff → commit → push

2. **deploy.sh** (~60 lines)
   - What it does: rsyncs .claude/ and .cursor/ from repo to ~/
   - Automatic backup: creates timestamped tar.gz in `~/.config/dotfiles-backup/`
   - Flags table:

     | Flag | Effect |
     |------|--------|
     | `--dry-run` | Preview without making changes |
     | `--force` | Skip automatic backup |
     | `--claude-only` | Deploy only .claude/ |
     | `--cursor-only` | Deploy only .cursor/ |
     | `--no-plugins` | Skip plugin files |
     | `--delete` | Remove files in ~/ not in repo (use with caution) |

   - Post-deploy verification: checks key files exist, hooks are executable, JSON is valid

3. **capture.sh** (~40 lines)
   - What it does: reverse of deploy — syncs live config back to repo
   - Symlink resolution: uses `--copy-links` (important for Cursor commands which may be symlinked)
   - Flags: `--claude-only`, `--cursor-only`
   - Workflow after capture: `git diff` to review, then commit

4. **diff.sh** (~40 lines)
   - What it does: compares repo config vs live environment without changing anything
   - Output categories: REPO ONLY, CHANGED, LIVE ONLY
   - Exit codes: 0 = in sync, 1 = differences found
   - Flags: `--claude-only`, `--cursor-only`
   - Use case: run in CI or before deploy to detect drift

5. **Exclude Lists** (~50 lines)
   Table of what's excluded from sync and why:

   | Pattern | Reason |
   |---------|--------|
   | `debug/` | Runtime debug logs |
   | `projects/` | Claude project-specific state |
   | `teams/`, `tasks/`, `todos/` | Runtime team/task state |
   | `cache/`, `plugins/cache/` | Downloaded plugin caches |
   | `file-history/` | Claude file edit history |
   | `history.jsonl` | Conversation history |
   | `settings.local.json` | Machine-specific overrides |
   | `extensions/` (Cursor) | Cursor extension state |
   | `ide_state.json` (Cursor) | IDE window state |
   | `worktrees/` (Cursor) | Runtime worktree tracking |

Target: ~200-250 lines.

**Step 2: Commit**

```bash
git add docs/deployment.md
git commit -s -S -m "docs: add deployment scripts reference"
```

---

### Task 7: Write `docs/skills-and-commands.md` — Skills & Commands Reference

**Files:**

- Create: `docs/skills-and-commands.md`

**Step 1: Write the skills and commands reference**

Sections:

1. **Overview** (~20 lines)
   - Both Claude Code and Cursor support extensible commands/skills
   - Claude Code uses "skills" (via the superpowers plugin)
   - Cursor uses "commands" (.md files in .cursor/commands/) and "skills" (.md files in .cursor/skills-cursor/)
   - This doc is the complete reference for both

2. **Claude Code Skills (Superpowers Plugin)** (~80 lines)
   Table + brief descriptions:

   | Skill | Purpose |
   |-------|---------|
   | brainstorming | Collaborative design exploration — mandatory before any implementation |
   | writing-plans | Creates detailed implementation plans with TDD steps |
   | executing-plans | Executes plans task-by-task with review checkpoints |
   | subagent-driven-development | Dispatches fresh subagent per task within current session |
   | dispatching-parallel-agents | Handles 2+ independent tasks in parallel |
   | test-driven-development | Enforces RED→GREEN→REFACTOR cycle |
   | systematic-debugging | Bug investigation before proposing fixes |
   | using-git-worktrees | Creates isolated worktrees for feature work |
   | finishing-a-development-branch | Guides merge, PR, or cleanup of completed work |
   | verification-before-completion | Requires evidence before claiming "done" |
   | requesting-code-review | Submits work for review |
   | receiving-code-review | Handles review feedback with technical rigor |
   | writing-skills | Creates and validates new skills |
   | using-superpowers | Introduction to the skill system |

3. **Cursor Slash Commands** (~100 lines)
   Grouped by workflow phase:

   **Planning & Research:**

   | Command | Description | Key Agents |
   |---------|-------------|------------|
   | `/architect` | Full architecture exploration | explorer, advocate, prototyper x2, synthesizer |
   | `/research` | Deep research on topic/issue | researcher |
   | `/issue` | GitHub issue analysis and task breakdown | task-analyzer |

   **Implementation:**

   | Command | Description |
   |---------|-------------|
   | `/code` | Execute next TODO from AGENTS.md |
   | `/task` | Full task workflow (understand, specify, plan, implement, verify) |
   | `/loop` | Iterative execution until completion |
   | `/parallel` | Run independent tasks concurrently (max 4) |
   | `/worktree` | Worktree lifecycle (create/list/status/done) |

   **Quality & Review:**

   | Command | Description | Key Agents |
   |---------|-------------|------------|
   | `/audit` | Security/reliability audit | auditor |
   | `/quality` | Multi-perspective review | auditor, perf-critic, api-reviewer, verifier |
   | `/test` | Detect and run tests | N/A |
   | `/self-review` | Review own changes vs main | N/A |
   | `/review-pr` | Review a pull request | N/A |

   **Git & CI:**

   | Command | Description |
   |---------|-------------|
   | `/push` | Safe push with pre-checks |
   | `/git-polish` | Rewrite local commits to be atomic and signed |
   | `/merge-train` | Orchestrate merging multiple PRs in dependency order |
   | `/context-reset` | Reset/inspect context tracking |

4. **Cursor Skills** (~30 lines)
   These are Cursor-specific config management skills:

   | Skill | Purpose |
   |-------|---------|
   | create-rule | Generate a new .mdc rule file |
   | create-skill | Generate a new skill file |
   | create-subagent | Generate a new agent .md file |
   | migrate-to-skills | Convert legacy commands to skills format |
   | update-cursor-settings | Update Cursor settings programmatically |

5. **How They Relate** (~30 lines)
   - Both ecosystems enforce the same workflow: brainstorm, plan, TDD, verify, PR
   - Claude Code skills (superpowers) focus on process discipline (brainstorming, TDD, plans)
   - Cursor commands focus on agent orchestration (multi-agent workflows, parallel dispatch)
   - The same hooks enforce the same rules in both tools (signed commits, TDD, worktree isolation)
   - You can use both tools on the same codebase — the configs are complementary, not competing

Target: ~200-300 lines.

**Step 2: Commit**

```bash
git add docs/skills-and-commands.md
git commit -s -S -m "docs: add skills and commands reference"
```

---

### Task 8: Rewrite Root `README.md`

**Files:**

- Modify: `README.md`

**Step 1: Rewrite the README**

Keep the good parts of the current README (badges, quick start, tables) but restructure:

1. **Header + Badges** (keep existing)

2. **One-liner + Value Proposition** (~10 lines)
   - What it is: Personal dotfiles for Claude Code and Cursor IDE
   - What it gives you: TDD enforcement, signed commits, worktree isolation, agent-driven workflows, year validation, security gates — all enforced by hooks, not just conventions

3. **What This Gives You** (~30 lines) — NEW section
   Before/after comparison:

   | Without This Config | With This Config |
   |-------------------|-----------------|
   | AI writes code directly on main | Implementation isolated in worktrees |
   | No test discipline | TDD enforced — can't write impl without test |
   | Unsigned commits | All commits GPG-signed with DCO |
   | Manual code review | Multi-agent quality gates (audit, perf, security) |
   | No year validation | Current year enforced in new files |
   | No guardrails | Dangerous commands blocked (rm -rf /, force-push main) |

4. **Architecture Overview** (~20 lines)
   Mermaid diagram showing the deployment flow:

   ```
   graph LR
     REPO["This Repo<br/>.claude/ + .cursor/"] -->|"./scripts/deploy.sh"| HOME["Your Home<br/>~/.claude/ + ~/.cursor/"]
     HOME -->|"./scripts/capture.sh"| REPO
   ```

   Brief explanation + link to docs/architecture.md

5. **Quick Start** (keep existing, slightly expanded)

6. **What's Included** (keep existing tables, condensed)

7. **Documentation** (~15 lines) — NEW section
   Links to all docs with one-line descriptions (mirror docs/README.md)

8. **Requirements** (keep existing)

9. **Contributing + License** (keep existing)

Target: ~150-200 lines.

**Step 2: Commit**

```bash
git add README.md
git commit -s -S -m "docs: rewrite README with value proposition and docs links"
```

---

### Task 9: Final Review & Verify

**Step 1: Check all links between documents**

Verify every cross-reference link works:

- README.md links to docs/*.md
- docs/README.md links to all docs
- docs/architecture.md links to claude-code.md, cursor.md
- docs/getting-started.md links to architecture.md, claude-code.md, cursor.md
- docs/skills-and-commands.md links to claude-code.md, cursor.md

**Step 2: Run markdown lint**

```bash
npx markdownlint-cli2 docs/*.md README.md
```

Fix any lint issues.

**Step 3: Run link checker**

```bash
npx lychee docs/*.md README.md
```

Fix any broken links.

**Step 4: Final commit if any fixes**

```bash
git add -A
git commit -s -S -m "docs: fix lint and link issues"
```

---

## Execution Notes

- **No TDD needed** — these are all documentation files (.md), exempt from the TDD guard
- **Each task is one file** — can be parallelized (Tasks 1-7 are independent, Task 8 depends on knowing the final doc filenames, Task 9 depends on all others)
- **Commit after each file** — atomic commits for easy review
- **All content must be accurate** — reference actual file names, actual hook behavior, actual flag names from the source code. Do not fabricate

# Team Slash Commands Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Migrate team coordination from plugin to native Claude Code slash commands with shared library content.

**Architecture:** Three slash commands in `~/.claude/commands/` (`team-plan.md`, `team-execute.md`, `team-shutdown.md`) with shared content inlined from `SKILL.md`. Library files move from `plugins/team/lib/` to `~/.claude/team/lib/`. Each command tells the agent to Read specific lib files at runtime.

**Tech Stack:** Claude Code slash commands (markdown), git

**Design doc:** `docs/plans/2026-02-16-team-slash-commands-design.md`

---

### Task 1: Create directory structure and move library files

**Files:**
- Create: `~/.claude/commands/` (directory)
- Create: `~/.claude/team/` (directory)
- Create: `~/.claude/team/lib/` (directory)
- Create: `~/.claude/team/docs/` (directory)
- Create: `~/.claude/team/examples/` (directory)
- Move: `plugins/team/lib/*.md` → `team/lib/*.md` (7 files)
- Move: `plugins/team/docs/*.md` → `team/docs/*.md` (2 files)
- Move: `plugins/team/examples/*.md` → `team/examples/*.md` (1 file)

**Step 1: Create directories**

```bash
mkdir -p ~/.claude/commands ~/.claude/team/lib ~/.claude/team/docs ~/.claude/team/examples
```

**Step 2: Copy library files**

```bash
cp ~/.claude/plugins/team/lib/*.md ~/.claude/team/lib/
cp ~/.claude/plugins/team/docs/*.md ~/.claude/team/docs/
cp ~/.claude/plugins/team/examples/*.md ~/.claude/team/examples/
```

**Step 3: Verify files copied correctly**

```bash
ls -la ~/.claude/team/lib/
ls -la ~/.claude/team/docs/
ls -la ~/.claude/team/examples/
```

Expected: 7 files in lib/, 2 in docs/, 1 in examples/

**Step 4: Commit**

```bash
cd ~/.claude
git add team/
git commit -m "feat: create team/ directory with shared lib, docs, examples"
```

---

### Task 2: Create the planning-guide.md library file

This is a NEW file — does not exist in the plugin. The design doc specifies it must cover: work decomposition, estimation, risk assessment, wave planning, and output format.

**Files:**
- Create: `~/.claude/team/lib/planning-guide.md`

**Step 1: Write planning-guide.md**

Content should cover these sections (see design doc for details):

1. **Work Decomposition** — how to break a project into independent, parallelizable tasks
   - Identify natural boundaries (API vs UI vs data layer)
   - Each task should be independently testable
   - Minimize cross-task dependencies
   - One concern per task

2. **Estimation** — complexity scoring and prioritization
   - Complexity levels: Trivial (1), Simple (2), Moderate (3), Complex (4)
   - Prioritization: dependencies first, then highest-risk, then by complexity
   - Total team capacity per wave: 3 tasks (one per worker)

3. **Risk Assessment** — identifying and documenting risks
   - Technical risks: unfamiliar tech, integration points, data migrations
   - Dependency risks: cross-task dependencies, external API dependencies
   - Mitigation strategies for each identified risk
   - Blocker escalation: when to stop and reassess

4. **Wave Planning** — for projects with >3 tasks
   - Group tasks into waves of ≤3
   - Dependencies determine wave order
   - Architect + QA persist across waves
   - Workers rotate between waves

5. **Output Format** — what the plan document MUST contain
   - Project objective (1-2 sentences)
   - Task list with: description, files affected, estimated complexity, assigned worker, wave number
   - Risk register: risk, likelihood, impact, mitigation
   - Wave plan (if >3 tasks): wave groupings with rationale
   - Branch strategy decision (chosen option + reasoning)
   - Success criteria (how to know when done)
   - Dependencies map (which tasks depend on which)

**Step 2: Verify the file reads correctly**

```bash
wc -l ~/.claude/team/lib/planning-guide.md
```

Expected: reasonable line count (100-200 lines)

**Step 3: Commit**

```bash
cd ~/.claude
git add team/lib/planning-guide.md
git commit -m "feat: add planning-guide.md library for structured team planning"
```

---

### Task 3: Create team-plan.md slash command

**Files:**
- Create: `~/.claude/commands/team-plan.md`

**Source content:**
- Inline shared context from: `plugins/team/SKILL.md` (team structure, roles, limits, communication protocol, common mistakes sections)
- Planning workflow from: `plugins/team/commands/plan.md`
- Runtime Read references: `~/.claude/team/lib/planning-guide.md`, `~/.claude/team/lib/branch-validator.md`

**Step 1: Write team-plan.md**

The command file must contain:

1. **Shared inline context** (~lines 53-205 from SKILL.md):
   - Team structure (Lead, Architect, QA, Workers) with responsibilities
   - Team size limits (max 5, wave strategy)
   - Communication protocol (Workers→Architect, Workers→QA, QA→Architect)

2. **Planning-specific workflow:**
   - Instruction to Read `~/.claude/team/lib/planning-guide.md`
   - Instruction to Read `~/.claude/team/lib/branch-validator.md`
   - Step-by-step: verify branch → validate upstream → brainstorm approach → follow planning guide → ask branch strategy → write plan → update AGENTS.md

3. **Common mistakes and red flags** (from SKILL.md lines 331-431)

4. **`$ARGUMENTS` placeholder** for user arguments

**Step 2: Verify command appears**

Open a new Claude Code session and type `/team-plan` — it should appear in the command menu.

**Step 3: Commit**

```bash
cd ~/.claude
git add commands/team-plan.md
git commit -m "feat: add /team-plan slash command"
```

---

### Task 4: Create team-execute.md slash command

**Files:**
- Create: `~/.claude/commands/team-execute.md`

**Source content:**
- Same shared inline context from SKILL.md
- Execution workflow from: `plugins/team/commands/execute.md` (includes Architect libraries section, escalation protocol, code review workflow)
- Runtime Read references: `~/.claude/team/lib/branch-validator.md` (for lead), plus instructions for Architect and QA to read their respective libs

**Step 1: Write team-execute.md**

The command file must contain:

1. **Shared inline context** (same as team-plan.md):
   - Team structure, size limits, communication protocol

2. **Execution-specific workflow:**
   - Instruction to Read `~/.claude/team/lib/branch-validator.md`
   - Step-by-step: verify branch → confirm plan exists → re-validate branch → create worktrees → spawn Architect → spawn QA → spawn Workers
   - Architect spawn instructions: tell it to Read `~/.claude/team/lib/architect-decisions.md`, `architect-patterns.md`, `architect-security.md`, `architect-validation.md`, `decision-template.md`
   - QA spawn instructions: tell it to Read `~/.claude/team/lib/qa-validator.md`

3. **Systems Architect section** (from execute.md lines 25-96):
   - Architect libraries descriptions
   - Escalation protocol
   - Code review workflow

4. **Wave management** (from SKILL.md lines 206-230)

5. **Common mistakes and red flags**

6. **`$ARGUMENTS` placeholder**

**Step 2: Verify command appears**

Open a new Claude Code session and type `/team-execute` — it should appear in the command menu.

**Step 3: Commit**

```bash
cd ~/.claude
git add commands/team-execute.md
git commit -m "feat: add /team-execute slash command"
```

---

### Task 5: Create team-shutdown.md slash command

**Files:**
- Create: `~/.claude/commands/team-shutdown.md`

**Source content:**
- Same shared inline context from SKILL.md
- Shutdown workflow from: `plugins/team/commands/shutdown.md`
- No runtime Read references needed (inline context sufficient)

**Step 1: Write team-shutdown.md**

The command file must contain:

1. **Shared inline context** (same as other two):
   - Team structure, size limits, communication protocol

2. **Shutdown-specific workflow:**
   - Step-by-step: verify completion → TeamDelete → remove worktrees → update AGENTS.md → run /compact
   - Explicit verification checks (PRs merged? branches cleaned?)
   - Warning about skipping TeamDelete

3. **Common mistakes and red flags** (shutdown-specific subset)

4. **`$ARGUMENTS` placeholder**

**Step 2: Verify command appears**

Open a new Claude Code session and type `/team-shutdown` — it should appear in the command menu.

**Step 3: Commit**

```bash
cd ~/.claude
git add commands/team-shutdown.md
git commit -m "feat: add /team-shutdown slash command"
```

---

### Task 6: Create team/README.md

**Files:**
- Create: `~/.claude/team/README.md`

**Source content:**
- Overview and full documentation from `plugins/team/SKILL.md` and `plugins/team/README.md`
- Adapted to reference new paths (`~/.claude/team/lib/` instead of `@skills/team/lib/`)

**Step 1: Write README.md**

Cover:
- Overview of the team coordination system
- Directory structure
- How the three commands work together
- Library file descriptions
- Link to design doc

**Step 2: Commit**

```bash
cd ~/.claude
git add team/README.md
git commit -m "docs: add team/README.md with system overview"
```

---

### Task 7: Update lib file references

The existing lib files (copied in Task 1) contain `@skills/team/lib/` references that need updating to `~/.claude/team/lib/`.

**Files:**
- Modify: `~/.claude/team/lib/branch-validator.md`
- Modify: `~/.claude/team/lib/qa-validator.md`
- Modify: any other lib files with cross-references

**Step 1: Search for old references**

```bash
grep -r "@skills/team" ~/.claude/team/
```

**Step 2: Replace all `@skills/team/lib/` with `~/.claude/team/lib/`**

Update each file found in step 1.

**Step 3: Verify no old references remain**

```bash
grep -r "@skills/team" ~/.claude/team/
```

Expected: no matches

**Step 4: Commit**

```bash
cd ~/.claude
git add team/
git commit -m "fix: update lib file cross-references to new paths"
```

---

### Task 8: Clean up old plugin directories

**Files:**
- Delete: `~/.claude/plugins/team/` (entire directory)
- Delete: `~/.claude/plugins/team-coordination/` (already deleted in git, confirm clean)

**Step 1: Remove plugin directories**

```bash
cd ~/.claude
rm -rf plugins/team/
rm -rf plugins/team-coordination/
```

**Step 2: Verify removal**

```bash
ls plugins/team/ 2>/dev/null && echo "STILL EXISTS" || echo "REMOVED"
ls plugins/team-coordination/ 2>/dev/null && echo "STILL EXISTS" || echo "REMOVED"
```

Expected: both REMOVED

**Step 3: Commit**

```bash
cd ~/.claude
git add plugins/team-coordination/ plugins/team/
git commit -m "chore: remove old team coordination plugin directories"
```

---

### Task 9: End-to-end verification

**Step 1: Verify directory structure**

```bash
ls -la ~/.claude/commands/team-*.md
ls -la ~/.claude/team/lib/
ls -la ~/.claude/team/docs/
ls -la ~/.claude/team/examples/
```

Expected:
- 3 command files in commands/
- 8 lib files (7 existing + planning-guide.md)
- 2 docs files
- 1 examples file

**Step 2: Verify commands are discoverable**

Open a new Claude Code session and type `/team` — all three commands should appear:
- `/team-plan`
- `/team-execute`
- `/team-shutdown`

**Step 3: Verify no dangling references**

```bash
grep -r "plugins/team" ~/.claude/commands/ ~/.claude/team/ 2>/dev/null
grep -r "@skills/team" ~/.claude/commands/ ~/.claude/team/ 2>/dev/null
```

Expected: no matches

**Step 4: Test /team-plan invocation**

Run `/team-plan` and verify it:
- Shows the planning workflow
- References reading `~/.claude/team/lib/planning-guide.md`
- References reading `~/.claude/team/lib/branch-validator.md`

**Step 5: Final commit (if any fixes needed)**

```bash
cd ~/.claude
git status
# Stage and commit any fixes
```

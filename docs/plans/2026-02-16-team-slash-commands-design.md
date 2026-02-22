# Team Coordination: Slash Commands Design

**Date:** 2026-02-16
**Status:** Approved
**Supersedes:** 2026-02-15-team-coordination-plugin-migration.md

## Context

Team coordination was originally built as a skill, then migrated to a plugin (`plugins/team-coordination/`, then `plugins/team/`). The plugin approach failed — command discovery and invocation (`/team:plan`) didn't work reliably. Moving back to skills was considered, but native Claude Code slash commands (`~/.claude/commands/*.md`) are simpler, guaranteed to work, and better suited for explicitly-invoked workflows.

### Decision

Use Claude Code's native slash command system. Three commands (`/team-plan`, `/team-execute`, `/team-shutdown`) with shared library content in `~/.claude/team/`.

### Alternatives Rejected

1. **Skills inside superpowers plugin** — lives in cached plugin dir, overwritten on update
2. **Own plugin providing skills** — already failed twice with registration/discovery issues
3. **Single monolithic command** — too large, mixes concerns

## Directory Structure

```
~/.claude/
  commands/
    team-plan.md              # /team-plan slash command
    team-execute.md           # /team-execute slash command
    team-shutdown.md          # /team-shutdown slash command
  team/
    README.md                 # Overview documentation
    lib/
      planning-guide.md       # Planning methodology, decomposition, estimation, risks
      branch-validator.md     # Git branch sync & worktree creation safety
      qa-validator.md         # Language-aware QA validation
      architect-decisions.md  # Technology selection guidance
      architect-patterns.md   # Design patterns library
      architect-security.md   # STRIDE threat model
      architect-validation.md # Dependency/complexity analysis
      decision-template.md    # ADR template
    docs/
      baseline-analysis.md    # Agent behavior without structure
      baseline-scenarios.md   # Baseline test scenarios
    examples/
      decision-user-profile-caching.md
```

## Command Design

### Shared Inline Context

All three commands inline the same core context (~1-2KB) so each is self-contained:

- **Team structure**: Lead (coordination only), Architect (spawned first, architectural decisions), QA (spawned second, validation), Workers (1-3, implementation in worktrees)
- **Team size limits**: Max 5 spawned agents (1 Architect + 1 QA + 3 Workers). Use waves for >3 tasks.
- **Communication protocol**: Workers→Architect (design questions), Workers→QA (ready for testing), QA→Architect (quality issues needing design changes)
- **Common mistakes and red flags**: Lead ≠ Architect, no generic teammates, max 3 workers per wave

### `/team-plan` — Planning Phase

**Purpose:** Decompose work into independent tasks with structured planning.

**Reads at runtime:**
- `~/.claude/team/lib/planning-guide.md` — planning methodology
- `~/.claude/team/lib/branch-validator.md` — branch sync validation

**Workflow:**
1. Verify current branch is `agents-workbench`
2. Read planning guide and branch validator
3. Check upstream/origin status for target branch
4. Follow planning guide to:
   - Decompose work into independent tasks
   - Estimate complexity per task
   - Identify risks, blockers, and mitigations
   - Plan agent assignments and waves
5. Ask mandatory branching strategy question (one branch per task vs shared feature branch vs monorepo paths vs single branch)
6. Output plan to `.agents/plans/<project>.md`
7. Update `AGENTS.md` with task assignments and status

### `/team-execute` — Execution Phase

**Purpose:** Spawn team agents and coordinate implementation.

**Reads at runtime:**
- `~/.claude/team/lib/branch-validator.md` — re-validate branch before worktree creation

**Instructs agents to read:**
- Architect: `architect-decisions.md`, `architect-patterns.md`, `architect-security.md`, `architect-validation.md`, `decision-template.md`
- QA: `qa-validator.md`

**Workflow:**
1. Verify on `agents-workbench` branch
2. Confirm plan exists in `.agents/plans/`
3. Re-validate branch source is still up-to-date
4. Create worktrees from validated source (`git worktree add .worktrees/<name> -b <branch> <default-branch>`)
5. Spawn agents in mandatory order:
   - Architect first (on agents-workbench, read-only)
   - QA second (on agents-workbench, read-only)
   - Workers last (each in dedicated worktree)
6. Workers implement tasks following TDD protocol
7. Workers → Architect for design decisions
8. Workers → QA when ready for testing
9. QA validates using qa-validator checks
10. Coordinate wave transitions when applicable

### `/team-shutdown` — Cleanup Phase

**Purpose:** Clean shutdown of agents, worktrees, and context.

**Reads at runtime:** Nothing extra (inline context sufficient).

**Workflow:**
1. Verify completion status — PRs merged or explicitly abandoned
2. Shutdown agents with TeamDelete
3. Remove all worktrees in `.worktrees/`
4. Update `AGENTS.md` with final status
5. Run `/compact` for context hygiene

## Library Files

### New: `planning-guide.md`

Structured planning methodology covering:

1. **Work decomposition** — how to break a project into independent, parallelizable tasks
   - Identify natural boundaries (API vs UI vs data layer)
   - Each task should be independently testable
   - Minimize cross-task dependencies
   - One concern per task

2. **Estimation** — complexity scoring and prioritization
   - Complexity levels: Trivial (1), Simple (2), Moderate (3), Complex (4)
   - Prioritization: dependencies first, then highest-risk, then by complexity
   - Total team capacity per wave: 3 tasks (one per worker)

3. **Risk assessment** — identifying and documenting risks
   - Technical risks: unfamiliar tech, integration points, data migrations
   - Dependency risks: cross-task dependencies, external API dependencies
   - Mitigation strategies for each identified risk
   - Blocker escalation: when to stop and reassess

4. **Wave planning** — for projects with >3 tasks
   - Group tasks into waves of ≤3
   - Dependencies determine wave order
   - Architect + QA persist across waves
   - Workers rotate between waves

5. **Output format** — what the plan document must contain
   - Project objective
   - Task list with estimates and assignments
   - Risk register
   - Wave plan (if applicable)
   - Branch strategy decision
   - Success criteria

### Existing (migrated from `plugins/team/lib/`)

- **branch-validator.md** — 3-step fetch/check/status validation, 4 sync options
- **qa-validator.md** — language detection (Go/TS/Rust/Python), lint/test/security checks, approval gates
- **architect-decisions.md** — storage, framework selection with decision trees
- **architect-patterns.md** — architectural, creational, structural, behavioral, testing, error handling patterns
- **architect-security.md** — STRIDE threat model with per-language mitigations
- **architect-validation.md** — dependency cycles, layer violations, complexity, API contracts, concurrency
- **decision-template.md** — ADR template (context, decision, rationale, alternatives, consequences)

## Migration Plan

### Files to create
1. `~/.claude/commands/team-plan.md`
2. `~/.claude/commands/team-execute.md`
3. `~/.claude/commands/team-shutdown.md`
4. `~/.claude/team/lib/planning-guide.md` (new)
5. `~/.claude/team/README.md`

### Files to move (from `plugins/team/`)
- `plugins/team/lib/*.md` → `team/lib/*.md` (7 files)
- `plugins/team/docs/*.md` → `team/docs/*.md` (2 files)
- `plugins/team/examples/*.md` → `team/examples/*.md` (1 file)

### Files to delete (after migration)
- `plugins/team/` directory (entire)
- `plugins/team-coordination/` directory (already deleted in git)

### Content transformation
- `plugins/team/SKILL.md` → split into:
  - Shared inline context (embedded in each command)
  - `team/README.md` (full documentation)
- `plugins/team/commands/plan.md` → `commands/team-plan.md` (adapted to slash command format)
- `plugins/team/commands/execute.md` → `commands/team-execute.md` (adapted)
- `plugins/team/commands/shutdown.md` → `commands/team-shutdown.md` (adapted)

## Testing

After migration, verify:
1. `/team-plan` appears in command menu and loads correctly
2. `/team-execute` appears in command menu and loads correctly
3. `/team-shutdown` appears in command menu and loads correctly
4. Each command can Read its referenced lib files
5. Full workflow: plan → execute → shutdown on a test project

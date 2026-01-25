# Cursor Integration Gap Analysis Report

**Generated:** 2026-01-25
**Scope:** Prompt library alignment with Cursor IDE features (Commands, Skills, Subagents, Hooks)
**Sources:** Cursor Documentation (Commands, Skills, Subagents, Hooks, Best Practices)

---

## Executive Summary

The current prompt library contains **high-quality, research-backed prompts** with excellent depth-forcing and verification patterns. However, **it does not leverage Cursor's native integration features**, resulting in:

1. **Manual invocation friction** — Prompts require `@prompts/file.md` references instead of `/command` shortcuts
2. **No dynamic loading** — All prompts treated as static context vs. agent-decided skill loading
3. **Missing automation** — No hooks for iteration loops, security gates, or formatters
4. **No subagent delegation** — Complex tasks run in main context instead of isolated subagents
5. **Incompatible structure** — `prompts/` folder not recognized by Cursor's skill/command discovery

| Gap Category | Impact | Effort to Fix |
|--------------|--------|---------------|
| Commands migration | High — UX friction | Low |
| Skills conversion | High — context efficiency | Medium |
| Subagents adoption | Medium — parallelism | Medium |
| Hooks implementation | High — automation | Medium |
| Rules consolidation | Low — already functional | Low |

---

## 1. Current State Analysis

### 1.1 Directory Structure

```text
prompts/
├── _compressed/
│   └── task-prompt-min.md       # Token-optimized variant
├── _kickoff/
│   └── meta-enhance-kickoff.md  # Bootstrapper
├── audit-go.md                  # Go/K8s audit
├── audit-to-prompt.md           # Audit → task conversion
├── git-polish.md                # Commit history rewriting
├── issue-to-prompt.md           # GitHub issue → task
├── master-agent.md              # Deep analysis mode
├── meta-enhance.md              # Recursive improvement loop
├── pr_review.md                 # PR gatekeeper
├── preflight.md                 # Codebase reconnaissance
├── research-issue.md            # Issue research
├── task-prompt.md               # Spec-first task generator
└── workflow.md                  # Two-phase planning
```

**Observation:** All prompts stored in flat `prompts/` directory with trigger commands defined in User Rules.

### 1.2 Current Invocation Method

From `snippets/cursor-rules.md`:

```text
# LIB /path/to/prompts-library/prompts/
DeepMode→master-agent.md
MetaEnhance→meta-enhance.md
Audit[scope]→audit-go.md
...
```

**How it works:** User types trigger word (e.g., "DeepMode"), agent looks up mapping, references `@prompts/master-agent.md`.

**Problems:**

1. Requires User Rules configuration per user
2. No autocomplete in chat input
3. Agent must parse trigger → filename mapping
4. No parameter support beyond natural language

### 1.3 Prompt Quality Assessment

| Prompt | Research-Backed | Verification Gate | Self-Check | Token-Optimized |
|--------|-----------------|-------------------|------------|-----------------|
| master-agent.md | ✓ Extensive | ✓ Factor+Revise CoVe | ✓ Full | ✓ Yes |
| task-prompt.md | ✓ Extensive | ✓ Spec verification | ✓ Full | ✓ Yes |
| pr_review.md | ✓ Confidence scoring | ✓ 4-pass + CoVe | ✓ Full | ✓ Yes |
| audit-go.md | ✓ Security research | ✓ CoVe + noise reduction | ✓ Full | ✓ Yes |
| research-issue.md | ✓ SOLAR reasoning | ✓ CoVe | ✓ Full | ✓ Yes |
| workflow.md | ✓ Agentic patterns | ✓ Plan verification | ✓ Full | ✓ Yes |
| preflight.md | ✓ CoVe | ✓ Confidence ratings | ✓ Full | ✓ Yes |
| git-polish.md | ✓ CoVe | ✓ Grouping verification | ✓ Full | ✓ Yes |
| meta-enhance.md | ✓ Recursive loops | ✓ Multi-phase | ✓ Full | ✓ Yes |
| issue-to-prompt.md | ✓ Two-phase | ✓ Research-based | ✓ Full | ✓ Yes |
| audit-to-prompt.md | ✓ Spec-first | ✓ Mid-PR workflow | ✓ Full | ✓ Yes |

**Assessment:** Prompt quality is **excellent**. The gap is purely in Cursor integration, not content.

---

## 2. Gap Analysis: Cursor Features Not Used

### 2.1 Commands (`.cursor/commands/`)

**Cursor Feature:**

- Markdown files in `.cursor/commands/` appear as `/command` in chat
- Autocomplete support in input box
- Parameters via `{param}` syntax
- Team sharing via dashboard

**Current Gap:**

- No `.cursor/commands/` directory exists
- Prompts require manual `@prompts/file.md` reference
- No autocomplete discovery

**Impact:** High — Every invocation requires knowing exact path and typing `@prompts/...`

**Recommended Migration:**

| Current Prompt | → Command Name | Usage |
|----------------|----------------|-------|
| `master-agent.md` | `/deep-mode` | `/deep-mode {task}` |
| `task-prompt.md` | `/task` | `/task {description}` or `/task #123` |
| `pr_review.md` | `/review-pr` | `/review-pr #123` |
| `audit-go.md` | `/audit-go` | `/audit-go {scope}` |
| `research-issue.md` | `/research` | `/research #123` |
| `workflow.md` | `/plan` | `/plan {feature}` |
| `preflight.md` | `/preflight` | `/preflight` |
| `git-polish.md` | `/git-polish` | `/git-polish HEAD~5` |
| `issue-to-prompt.md` | `/issue-to-task` | `/issue-to-task #123` |
| `audit-to-prompt.md` | `/fix-audit` | `/fix-audit` |
| `meta-enhance.md` | `/meta-enhance` | `/meta-enhance` |

### 2.2 Skills (`.cursor/skills/`)

**Cursor Feature:**

- `SKILL.md` files with YAML frontmatter
- Agent decides when to invoke based on `description`
- Progressive loading (context-efficient)
- Scripts in `scripts/` subdirectory
- `disable-model-invocation: true` for explicit-only skills

**Current Gap:**

- No `.cursor/skills/` directory
- All prompts loaded via explicit reference
- No description-based auto-invocation

**Impact:** High — Context window filled with full prompt even for simple tasks

**Recommended Skill Structure:**

```text
.cursor/skills/
├── go-audit/
│   ├── SKILL.md           # Description + when to use
│   └── scripts/
│       └── run-audit.sh   # Optional automation
├── pr-review/
│   ├── SKILL.md
│   └── references/
│       └── CHECKLIST.md   # Loaded on demand
├── spec-first-task/
│   └── SKILL.md
└── deep-analysis/
    └── SKILL.md
```

**Example SKILL.md:**

```markdown
---
name: go-audit
description: >
  Deep defensive audit for Go/K8s codebases. Use when reviewing Go code 
  for production readiness, checking for race conditions, resource leaks,
  or K8s lifecycle compliance.
---

# Go/K8s Audit

{current audit-go.md content}
```

**Key Insight:** Skills with good `description` fields allow agent to auto-invoke when user mentions "audit", "production-ready", "race conditions", etc. — without explicit `/audit` command.

### 2.3 Subagents (`.cursor/agents/`)

**Cursor Feature:**

- Custom subagents with isolated context
- Parallel execution
- Model selection per subagent
- `is_background: true` for async work
- Resume capability via agent ID

**Current Gap:**

- No custom subagents defined
- All work runs in main conversation context
- No parallelism for independent research tasks

**Impact:** Medium — Long-running tasks consume main context window

**Recommended Subagents:**

```markdown
# .cursor/agents/researcher.md
---
name: researcher
description: >
  Deep issue research specialist. Use when investigating GitHub issues,
  analyzing codebase for root causes, or generating solution alternatives.
model: fast
---

{Adapted from research-issue.md}
```

```markdown
# .cursor/agents/verifier.md
---
name: verifier
description: >
  Skeptical validator. Use to verify claimed work is actually complete,
  tests pass, and acceptance criteria are met.
model: fast
readonly: true
---

You are a skeptical validator. Your job is to verify that work claimed
as complete actually works.

When invoked:
1. Identify what was claimed to be completed
2. Check implementation exists and is functional
3. Run relevant tests or verification steps
4. Look for edge cases that may have been missed

Report:
- What was verified and passed
- What was claimed but incomplete/broken
- Specific issues to address
```

```markdown
# .cursor/agents/auditor.md
---
name: auditor
description: >
  Go/K8s security and reliability auditor. Use when checking code for
  production risks, race conditions, or K8s lifecycle issues.
model: inherit
readonly: true
---

{Adapted from audit-go.md, with read-only constraint}
```

### 2.4 Hooks (`.cursor/hooks.json`)

**Cursor Feature:**

- `sessionStart/sessionEnd` — inject context, set env vars
- `beforeShellExecution/afterShellExecution` — gate/audit commands
- `afterFileEdit` — auto-format
- `stop` — auto-continue loops with `followup_message`
- `preToolUse/postToolUse` — generic tool gates

**Current Gap:**

- No hooks configured
- No auto-formatting after edits
- No iteration loops (meta-enhance requires manual continuation)
- No security gates on shell commands

**Impact:** High — Manual intervention required for automation patterns

**Recommended hooks.json:**

```json
{
  "version": 1,
  "hooks": {
    "sessionStart": [
      {
        "command": ".cursor/hooks/inject-context.sh",
        "type": "command"
      }
    ],
    "afterFileEdit": [
      {
        "command": ".cursor/hooks/format.sh"
      }
    ],
    "beforeShellExecution": [
      {
        "type": "prompt",
        "prompt": "Is this shell command safe? Block destructive git operations (force push, hard reset) unless explicitly approved.",
        "timeout": 10
      }
    ],
    "stop": [
      {
        "command": ".cursor/hooks/grind.sh",
        "loop_limit": 5
      }
    ]
  }
}
```

**Example grind.sh (for meta-enhance iteration):**

```bash
#!/bin/bash
# Read JSON input
input=$(cat)
status=$(echo "$input" | jq -r '.status')
loop_count=$(echo "$input" | jq -r '.loop_count')

# Check for completion marker
if [ -f ".cursor/scratchpad.md" ]; then
  if grep -q "DONE" ".cursor/scratchpad.md"; then
    echo '{}' # No followup, stop
    exit 0
  fi
fi

# Continue if not complete and under budget
if [ "$status" = "completed" ] && [ "$loop_count" -lt 5 ]; then
  echo '{"followup_message": "Continue iteration. Check scratchpad for progress."}'
else
  echo '{}'
fi
```

### 2.5 Rules (`.cursor/rules/`)

**Cursor Feature:**

- Project-level rules in `.cursor/rules/*.md`
- `alwaysApply: true` for global rules
- `globs` patterns for file-specific rules

**Current State:**

- Rules defined in User Rules (global)
- Works but not project-portable

**Gap:** Low — Current approach functional, but team members must copy User Rules

**Recommendation:** Create `.cursor/rules/project.md` with core rules:

```markdown
---
description: Project-wide engineering standards
alwaysApply: true
---

# Project Rules

## DEPTH (Anti-Satisficing)
- model-first: entities→relations→constraints→state BEFORE solve
- enumerate≥3: list ≥3 paths before ANY selection
- no-first-solution: 2+ approaches→compare→select-with-rationale

## TOKEN
- ref>paste: cite `path:line`, never paste unless editing
- table>prose: structured data in tables
- delta-only: show changed lines only

## VERIFY
- CoVe: claims→questions→independent-answer→reconcile(✓/✗/?)
- Tool outputs verified before use

## GUARD
- ≤3 questions, else proceed with assumptions
- Approval required: API change, dep install, workspace modify

## LANG
- Go: gofmt→vet→lint→test; doc≤80ch
- TS: repo pkg manager; tsc --noEmit
```

---

## 3. Errors and Anti-Patterns

### 3.1 Trigger Command Mapping Fragility

**Problem:** User Rules contain hardcoded path:

```text
# LIB /path/to/prompts-library/prompts/
```

This path varies per user, making the library non-portable.

**Fix:** Use Commands (`.cursor/commands/`) which are path-relative.

### 3.2 No Parameter Support

**Problem:** Current triggers like `Issue2Prompt#N` require parsing `#N` from natural language.

**Fix:** Commands support parameters natively:

```markdown
# .cursor/commands/issue-to-task.md

Create a spec-first task prompt for GitHub issue #{number}.

{full prompt content}
```

Usage: `/issue-to-task #123 focus on auth flow`

### 3.3 Full Prompt Loading Every Time

**Problem:** `@prompts/master-agent.md` loads entire 500+ line prompt into context even for simple questions.

**Fix:** Skills with progressive loading:

- Main `SKILL.md` contains description + core instructions
- `references/` contains detailed patterns loaded on-demand
- Agent reads only what's needed

### 3.4 No Auto-Continuation for Loops

**Problem:** `meta-enhance.md` defines iteration loop but requires manual "continue" from user.

**Fix:** Hook-based auto-continuation:

- `stop` hook checks completion marker in scratchpad
- Returns `followup_message` to continue automatically
- Respects `loop_limit` (default 5)

### 3.5 Missing Verifier Subagent Pattern

**Problem:** No independent verification of claimed completions.

**Fix:** Create `verifier` subagent (see 2.3) that runs in isolated context to skeptically validate work.

Cursor best practices recommend:
> "A verification agent independently validates whether claimed work was actually completed."

### 3.6 No Format-on-Edit Hook

**Problem:** Prompts mention running formatters but rely on manual execution.

**Fix:** `afterFileEdit` hook:

```json
{
  "afterFileEdit": [
    { "command": ".cursor/hooks/format.sh" }
  ]
}
```

```bash
#!/bin/bash
# format.sh
file_path=$(cat | jq -r '.file_path')
ext="${file_path##*.}"

case "$ext" in
  go) gofmt -w "$file_path" ;;
  ts|tsx) npx prettier --write "$file_path" ;;
  py) ruff format "$file_path" ;;
esac
```

### 3.7 Compressed Variant Redundancy

**Problem:** `_compressed/task-prompt-min.md` exists as manual token optimization.

**Assessment:** With Skills progressive loading, manual compression becomes unnecessary. The skill loads only relevant sections.

**Recommendation:** Deprecate `_compressed/` once Skills migration complete.

### 3.8 No MCP Integration References

**Problem:** Prompts mention "GitHub MCP" but don't explain setup.

**Fix:** Add setup documentation for MCP servers:

- GitHub MCP for issue/PR operations
- Figma MCP for design-to-code
- Database MCPs for schema introspection

---

## 4. Detailed Recommendations

### 4.1 Phase 1: Commands Migration (Low Effort, High Impact)

1. Create `.cursor/commands/` directory
2. Copy prompts as commands with kebab-case names
3. Update User Rules to reference commands instead of `@prompts/`
4. Test `/command` autocomplete

**Effort:** ~2 hours
**Impact:** Immediate UX improvement for all users

### 4.2 Phase 2: Skills Conversion (Medium Effort, High Impact)

1. Create `.cursor/skills/` directory structure
2. Extract YAML frontmatter from prompts:
   - `name`: lowercase-kebab
   - `description`: when-to-use guidance
3. Split large prompts:
   - Core instructions in `SKILL.md`
   - Reference material in `references/`
4. Test agent auto-invocation with description keywords

**Effort:** ~4 hours
**Impact:** Context efficiency, agent-decided invocation

### 4.3 Phase 3: Subagents Definition (Medium Effort, Medium Impact)

1. Create `.cursor/agents/` directory
2. Define specialist subagents:
   - `researcher.md` — issue investigation
   - `verifier.md` — completion validation
   - `auditor.md` — security/reliability checks
3. Configure `model` selection (fast vs inherit)
4. Add `readonly: true` for read-only operations

**Effort:** ~3 hours
**Impact:** Parallelism, context isolation

### 4.4 Phase 4: Hooks Implementation (Medium Effort, High Impact)

1. Create `.cursor/hooks.json`
2. Implement hook scripts:
   - `format.sh` — auto-format on edit
   - `grind.sh` — iteration continuation
   - `inject-context.sh` — session initialization
3. Add security gate for destructive commands
4. Test hook execution via terminal output

**Effort:** ~4 hours
**Impact:** Automation, safety, iteration loops

### 4.5 Phase 5: Rules Consolidation (Low Effort, Low Impact)

1. Create `.cursor/rules/project.md`
2. Extract core rules from User Rules
3. Keep advanced/personal rules in User Rules
4. Commit project rules to repository

**Effort:** ~1 hour
**Impact:** Team portability

---

## 5. Migration Priority Matrix

| Task | Effort | Impact | Priority | Dependencies |
|------|--------|--------|----------|--------------|
| Commands migration | Low (2h) | High | P0 | None |
| Rules consolidation | Low (1h) | Low | P0 | None |
| Skills conversion | Medium (4h) | High | P1 | Commands |
| Hooks implementation | Medium (4h) | High | P1 | None |
| Subagents definition | Medium (3h) | Medium | P2 | Skills |
| Deprecate `_compressed/` | Low (0.5h) | Low | P3 | Skills |

**Recommended Order:**

1. Commands + Rules (same PR, immediate benefit)
2. Hooks (enables automation)
3. Skills (enables progressive loading)
4. Subagents (enables parallelism)

---

## 6. Target Directory Structure

```text
.cursor/
├── commands/
│   ├── audit-go.md
│   ├── deep-mode.md
│   ├── fix-audit.md
│   ├── git-polish.md
│   ├── issue-to-task.md
│   ├── meta-enhance.md
│   ├── plan.md
│   ├── preflight.md
│   ├── research.md
│   ├── review-pr.md
│   └── task.md
├── skills/
│   ├── go-audit/
│   │   ├── SKILL.md
│   │   └── references/
│   │       └── SCOPE_CHECKLIST.md
│   ├── pr-review/
│   │   ├── SKILL.md
│   │   └── references/
│   │       └── CONFIDENCE_SCORING.md
│   └── spec-first/
│       └── SKILL.md
├── agents/
│   ├── auditor.md
│   ├── researcher.md
│   └── verifier.md
├── hooks/
│   ├── format.sh
│   ├── grind.sh
│   └── inject-context.sh
├── hooks.json
└── rules/
    ├── project.md
    └── go-style.md

prompts/              # Keep for reference/documentation
├── README.md         # Migration notes
└── archive/          # Original prompts preserved
```

---

## 7. Verification Checklist

After migration, verify:

- [ ] `/task` appears in chat autocomplete
- [ ] `/review-pr #123` creates review with parameters
- [ ] Agent auto-invokes `go-audit` skill when user mentions "audit this Go code"
- [ ] `afterFileEdit` hook formats Go files automatically
- [ ] `stop` hook continues meta-enhance iteration without manual "continue"
- [ ] `verifier` subagent runs in isolated context
- [ ] Team members can use commands without User Rules setup

---

## 8. Research References

| Finding | Source | Relevance |
|---------|--------|-----------|
| Skills progressive loading | Cursor Docs (Skills) | Context efficiency |
| Subagent verification pattern | Cursor Best Practices | Independent validation |
| Hook `followup_message` loop | Cursor Docs (Hooks) | Auto-continuation |
| Commands parameter syntax | Cursor Docs (Commands) | `/command {param}` |
| Multi-agent parallel review | Anthropic 2025 | PR review passes |

---

## 9. Conclusion

The prompt library represents **significant engineering investment** in research-backed prompting techniques. The content quality is high. The gap is purely in **Cursor platform integration**.

Migrating to Commands, Skills, Subagents, and Hooks will:

1. **Reduce friction** — `/command` vs `@prompts/path.md`
2. **Improve efficiency** — Progressive loading vs full prompt
3. **Enable automation** — Hooks for formatting, iteration, security
4. **Support parallelism** — Subagents for isolated research
5. **Increase portability** — Project-level config vs User Rules

**Estimated total effort:** ~14 hours
**Expected impact:** 50%+ reduction in invocation friction, full automation support

---

*Report generated by analyzing prompts/* against Cursor documentation (Commands, Skills, Subagents, Hooks, Best Practices).*

# Claude Config PE Audit — Phase A Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce `docs/audits/2026-05-25-claude-config-audit.md` — the source-of-truth audit deliverable with concrete findings (stable IDs), cross-cutting themes, and a mapping of findings → action phases (P0/P1/P2). This plan does NOT execute the action phases; those get planned separately after Phase A lands.

**Architecture:** Single-document deliverable produced by a structured audit pass over the **live `~/.claude/`** (revised target — see "Working location" below). The shared subset is also mirrored at `promptsLibrary/.claude/`; private subset is live-only per the dual-track editing strategy. Each finding follows the rubric defined in the spec §1 (`docs/superpowers/specs/2026-05-25-claude-config-pe-audit-design.md`). The audit is read-only — no config changes happen in Phase A. P0/P1/P2 plans get written in follow-up sessions, referencing finding IDs from this audit doc.

**Tech Stack:** Markdown for the deliverable. `bash` + `wc` + `jq` + `git` for measurement. `gh` (already permitted, unsandboxed) for the PR. No code changes to the config in this phase.

**Spec reference:** `docs/superpowers/specs/2026-05-25-claude-config-pe-audit-design.md`. Read it before starting; this plan implements §1-§4 of the spec into the audit deliverable, and §5 Phase A specifically.

---

## File Structure

**Created in this phase:**
- `docs/audits/2026-05-25-claude-config-audit.md` — the audit deliverable. Single file, structured per spec §3 (finding shape) and §4 (cross-cutting themes).

**Read-only references during this phase** (DO NOT modify) — all paths refer to the **live `~/.claude/`** per the revised editing strategy:
- `~/.claude/CLAUDE.md`
- `~/.claude/rules/*.md`
- `~/.claude/settings.json` and `settings.local.json` (if present)
- `~/.claude/hooks/*.sh` (~30 files including 6 `.bak`)
- `~/.claude/skills/*/SKILL.md` (25 skill dirs as of 2026-05-25)
- `~/.claude/agents/*.md` (4 files)
- `~/.claude/commands/*.md`
- `~/.claude/panel/config.yml`

**NOT modified in Phase A:** any of the above. The audit is observation-only.

---

## Working location

All work happens in this worktree: `/Users/eduardoa/src/github/ArangoGutierrez/promptsLibrary/.claude/worktrees/competent-matsumoto-8be15b/` (the `.claude/` here is the **repo's** internal worktree directory, not the user's `~/.claude/`). The audit DOC lives in the repo (`docs/audits/`), but the audit MEASURES `~/.claude/` directly — see escalation below.

**Revised 2026-05-25 after Phase A T2 escalation:** measurements happen against **live `~/.claude/`**, not the repo mirror. The repo holds ~12 shareable/public skills; live has 25 (the extras are private, NVIDIA-internal, and panel infrastructure that are intentionally not in the repo). Auditing the repo mirror would miss most of the friction the user reported. Per the revised editing strategy (dual-track, spec §6.1): shared config edits flow through the repo; private config edits go directly to `~/.claude/`.

**Excludes when measuring `~/.claude/`:** skip runtime-only state — `projects/`, `sessions/`, `paste-cache/`, `shell-snapshots/`, `tasks/`, `file-history/`, `session-env/`, `telemetry/`, `debug/`, `ide/`, `backups/`, `cache/`, anything with timestamps in the name like `*.pre-nuke-*`. These churn constantly and aren't part of the config surface.

---

## Task 1: Create the audit doc skeleton

**Files:**
- Create: `docs/audits/2026-05-25-claude-config-audit.md`

- [ ] **Step 1: Create the docs/audits/ directory and skeleton file**

```bash
mkdir -p docs/audits
```

- [ ] **Step 2: Write the skeleton with all section headers**

Write to `docs/audits/2026-05-25-claude-config-audit.md`:

```markdown
# Claude Config PE Audit — 2026-05-25

- **Owner:** eduardoa@nvidia.com
- **Spec:** [docs/superpowers/specs/2026-05-25-claude-config-pe-audit-design.md](../superpowers/specs/2026-05-25-claude-config-pe-audit-design.md)
- **Status:** Draft

## 1. Inventory snapshot

(Table populated in Task 2.)

## 2. Findings

### 2.1 CLAUDE.md
### 2.2 rules/
### 2.3 settings.json
### 2.4 hooks
### 2.5 skills
### 2.6 agents
### 2.7 plugins enabled
### 2.8 meta-skills (router / gating patterns — currently empty; finding describes the gap)

## 3. Cross-cutting themes

### 3.1 Stop-hook LLM prompt cost
### 3.2 Cache-TTL regression (1h → 5m)
### 3.3 Opus 4.7 tokenizer expansion (~35%)
### 3.4 TDD-guard removal — mechanics
### 3.5 private skill relocation — mechanics
### 3.6 Worktrees: experimental flag vs official GA
### 3.7 Security posture
### 3.8 Plan-routing via cheap classifier (new)

## 4. Phased action plan

### 4.1 P0 — Quick wins
### 4.2 P1 — Structural
### 4.3 P2 — Polish

## 5. Validation gate
```

- [ ] **Step 3: Verify the file was created**

Run: `ls -la docs/audits/2026-05-25-claude-config-audit.md && wc -l docs/audits/2026-05-25-claude-config-audit.md`
Expected: file exists, ~30 lines (skeleton only).

- [ ] **Step 4: Commit the skeleton**

```bash
git add docs/audits/2026-05-25-claude-config-audit.md
git commit -sS -m "docs(audit): claude config audit doc skeleton

Skeleton structured per spec §3/§4. Findings, themes, and phased
plan sections populated in subsequent commits."
```

---

## Task 2: Inventory snapshot table

**Files:**
- Modify: `docs/audits/2026-05-25-claude-config-audit.md` (§1)

- [ ] **Step 1: Measure all files in scope (against live `~/.claude/`)**

Run these from any working directory:

```bash
echo "=== CLAUDE.md ==="
wc -l -c ~/.claude/CLAUDE.md
echo ""
echo "=== rules/ ==="
wc -l -c ~/.claude/rules/*.md
echo ""
echo "=== settings.json ==="
wc -l -c ~/.claude/settings.json ~/.claude/settings.local.json 2>/dev/null
echo ""
echo "=== hooks (live count, excluding .bak) ==="
find ~/.claude/hooks -maxdepth 1 -name '*.sh' ! -name '*.bak*' | wc -l
echo ""
echo "=== hooks .bak files ==="
find ~/.claude/hooks -maxdepth 1 -name '*.bak*'
echo ""
echo "=== skills ==="
for d in ~/.claude/skills/*/; do
    if [ -f "$d/SKILL.md" ]; then
        bytes=$(wc -c < "$d/SKILL.md")
        lines=$(wc -l < "$d/SKILL.md")
        printf "%-30s lines=%4d bytes=%6d\n" "$(basename $d)" "$lines" "$bytes"
    fi
done
echo ""
echo "=== agents ==="
wc -l ~/.claude/agents/*.md
echo ""
echo "=== commands ==="
wc -l ~/.claude/commands/*.md
```

Some operations may require `dangerouslyDisableSandbox: true` if the sandbox doesn't grant read on `~/.claude/` — try sandboxed first; if "Operation not permitted" appears, retry with sandbox disabled.

Capture the output — it becomes the inventory table.

- [ ] **Step 2: Measure the auto-loaded surface (per-session context cost)**

```bash
echo "=== Auto-loaded surface (CLAUDE.md + rules/) ==="
cat ~/.claude/CLAUDE.md ~/.claude/rules/*.md | wc -l -c
echo ""
echo "=== Sum of skill descriptions (YAML frontmatter, pre-loaded) ==="
for d in ~/.claude/skills/*/; do
    awk '/^---$/{c++; next} c==1' "$d/SKILL.md" 2>/dev/null | grep -E '^description:' 
done | wc -c
```

These two numbers anchor the token-cost estimates for findings.

- [ ] **Step 3: Write the inventory table into §1 of the audit doc**

Replace the `(Table populated in Task 2.)` placeholder in §1 with a markdown table:

```markdown
| Area | File / Directory | Lines | Bytes | Role | Status |
|------|------------------|-------|-------|------|--------|
| CLAUDE.md | `~/.claude/CLAUDE.md` | <N> | <N> | Per-session memory (auto-loaded) | active |
| rules/ | `~/.claude/rules/constitution.md` | <N> | <N> | Auto-loaded rule | active |
| rules/ | `~/.claude/rules/go-conventions.md` | <N> | <N> | Auto-loaded rule | active |
| ... | ... | ... | ... | ... | ... |
| hooks/ | `~/.claude/hooks/tdd-guard.sh` | 229 | <N> | PreToolUse Write/Edit | flagged: locked-removal |
| hooks/ | `~/.claude/hooks/tdd-guard.sh.bak-pre-*` (4) | — | — | Stale backup | flagged: delete |
| ... | ... | ... | ... | ... | ... |
| **Auto-loaded surface total** | (CLAUDE.md + rules/) | <N> | <N> | Pre-loaded every session | baseline |
| **Skill descriptions total** | (24 skills) | — | <N> | Pre-loaded every session | baseline |
```

Substitute the actual numbers from Steps 1-2. Include all 24 skills, all 7 rules, all hooks (one row for each live `.sh`; one summary row for the `.bak` set).

- [ ] **Step 4: Verify the table renders**

Run: `head -80 docs/audits/2026-05-25-claude-config-audit.md`
Expected: §1 contains the inventory table with real numbers, no `<N>` placeholders.

- [ ] **Step 5: Commit**

```bash
git add docs/audits/2026-05-25-claude-config-audit.md
git commit -sS -m "docs(audit): inventory snapshot table

Measured file sizes for CLAUDE.md, rules/, settings, hooks, skills,
agents, commands. Auto-loaded surface and skill-description totals
captured as the per-session baseline."
```

---

## Task 3: Findings — CLAUDE.md (§2.1)

**Files:**
- Modify: `docs/audits/2026-05-25-claude-config-audit.md` (§2.1)

- [ ] **Step 1: Re-read CLAUDE.md**

Read `~/.claude/CLAUDE.md` in full. Note: it's 65 lines, under the 80-line SOTA target.

- [ ] **Step 2: Evaluate against the rubric**

For CLAUDE.md, consider:
- Does it contain content that should live in rules/ (and is rules/ already auto-loaded)?
- Does it reference skills that no longer exist?
- Does it reference TDD as MUST? (locked decision: move to "should + theater-test still required")
- Is the "Iteration Budget" line referenced anywhere, or dead text?
- Does the "Workflow" line match how you actually work?

- [ ] **Step 3: Write findings to §2.1**

Use this format for each finding (replace the heading template content):

```markdown
### 2.1 CLAUDE.md

#### F-CLAUDEMD-01 — TDD enforcement language is too strict
- **Severity:** P0
- **Token impact:** ~0 tokens (content shape change, not size)
- **Friction:** high
- **Confidence:** high
- **Effort:** trivial
- **Current state:** The "TDD Protocol (enforced by hook)" section frames TDD as a hard requirement enforced by `tdd-guard.sh`. The hook is being removed (locked decision); this language must follow.
- **Recommended fix:** Replace "TDD Protocol (enforced by hook)" section with "TDD Protocol (recommended)". Keep theater-test discipline (constitution.md is source of truth). Add: "TDD is the default for production code paths; opt out for docs, install scripts, hacky one-offs, and exploratory work."
- **Evidence:** `~/.claude/CLAUDE.md:48-52`; spec §4.4.
```

Write 3-6 findings minimum for CLAUDE.md. Don't manufacture findings — if a finding doesn't have evidence and a concrete fix, don't include it.

- [ ] **Step 4: Sanity check**

Each finding must have:
- A concrete file:line reference in **Evidence**
- A specific recommended fix (not "improve" or "consider")
- All 6 rubric fields filled

- [ ] **Step 5: Commit**

```bash
git add docs/audits/2026-05-25-claude-config-audit.md
git commit -sS -m "docs(audit): F-CLAUDEMD findings

Findings for ~/.claude/CLAUDE.md per spec rubric."
```

---

## Task 4: Findings — rules/ (§2.2)

**Files:**
- Modify: `docs/audits/2026-05-25-claude-config-audit.md` (§2.2)

- [ ] **Step 1: Read all 7 rules files**

Files: `constitution.md`, `container-conventions.md`, `git-workflow.md`, `go-conventions.md`, `k8s-conventions.md`, `learned-anti-patterns.md`, `security.md`.

- [ ] **Step 2: Evaluate**

Consider:
- Overlap with CLAUDE.md content
- Per-file currency (is `learned-anti-patterns.md` stale? `/reflection` last ran 11 days ago per session hook)
- Auto-load token cost (each rule's lines × tokenizer expansion)
- Per-file relevance to the actual Go/K8s/containers/security workload

- [ ] **Step 3: Write F-RULES-NN findings**

Use the same finding template as Task 3 Step 3. Minimum one finding per rule file that has issues; one summary finding for the auto-load total cost.

- [ ] **Step 4: Commit**

```bash
git add docs/audits/2026-05-25-claude-config-audit.md
git commit -sS -m "docs(audit): F-RULES findings

Findings for ~/.claude/rules/*.md per spec rubric."
```

---

## Task 5: Findings — settings.json (§2.3)

**Files:**
- Modify: `docs/audits/2026-05-25-claude-config-audit.md` (§2.3)

- [ ] **Step 1: Read settings.json and settings.local.json**

Examine: `permissions` (allow/deny/ask), `env`, `model`, `hooks`, `enabledPlugins`, `sandbox`, `effortLevel`, `teammateMode`, `autoMemoryEnabled`.

- [ ] **Step 2: Verify gh CLI sandbox behavior**

Run:

```bash
jq '.permissions.allow[] | select(test("gh"))' .claude/settings.json
jq '.sandbox' ~/.claude/settings.json
```

Confirm: `Bash(gh *)` is in allow AND `sandbox.autoAllowBashIfSandboxed` is true. This means gh CLI should be unsandboxed-allowed; record what the user observed as friction.

- [ ] **Step 3: Evaluate**

Topics to grade:
- Is `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` still required after worktree GA?
- Is `model: opus[1m]` the right default for 1M context, given the 5m cache TTL?
- `effortLevel: high` — measure value vs cost
- `enabledPlugins`: 5 enabled — is each used? (clangd-lsp is suspect for Go/K8s)
- Hook registration: is the LLM-prompt Stop hook the only Stop hook that fires the round-trip?
- Are `permissions.ask` patterns complete? Missing: `Bash(curl *)`, `Bash(docker rm *)`?

- [ ] **Step 4: Write F-SETTINGS-NN findings**

Use the finding template. Minimum 4 findings.

- [ ] **Step 5: Commit**

```bash
git add docs/audits/2026-05-25-claude-config-audit.md
git commit -sS -m "docs(audit): F-SETTINGS findings

Findings for ~/.claude/settings.json per spec rubric."
```

---

## Task 6: Findings — hooks (§2.4)

**Files:**
- Modify: `docs/audits/2026-05-25-claude-config-audit.md` (§2.4)

- [ ] **Step 1: List all hooks and their .bak siblings**

Run:

```bash
ls -la ~/.claude/hooks/*.sh .claude/hooks/*.bak* 2>/dev/null
```

- [ ] **Step 2: Read the headline hooks**

Read in full:
- `tdd-guard.sh` (229 lines, slated for removal)
- The Stop hooks from `settings.json` (`context-watch.sh` + the inline `"type": "prompt"` block)
- `validate-recommendation.sh` (sandbox-write issue observed during brainstorm)
- `enforce-worktree.sh`
- `inject-date.sh` (SessionStart — every byte is per-session token cost)
- `reflection-staleness.sh` (SessionStart — same)

- [ ] **Step 3: Measure SessionStart output**

Run each SessionStart hook with the schema's expected stdin and capture the stdout size:

```bash
echo '{}' | .claude/hooks/inject-date.sh 2>/dev/null | wc -c
echo '{}' | .claude/hooks/reflection-staleness.sh 2>/dev/null | wc -c
```

This is per-session token cost — every byte of stdout gets injected into context.

- [ ] **Step 4: Write F-HOOK-NN findings**

Minimum findings to include:
- F-HOOK-01: stale `.bak` files (6 to delete, P0, trivial)
- F-HOOK-02: `tdd-guard.sh` removal (P0, small, locked decision — referencing spec §4.4)
- F-HOOK-03: Stop-hook `"type": "prompt"` cost (P0, see spec §4.1)
- F-HOOK-04: `validate-recommendation.sh` sandbox-write friction (P0, see live incident in brainstorm session)
- F-HOOK-05: SessionStart hook output size (P1 or P2 depending on measured bytes)
- Findings for any other hook with redundancy or false-positive history

- [ ] **Step 5: Commit**

```bash
git add docs/audits/2026-05-25-claude-config-audit.md
git commit -sS -m "docs(audit): F-HOOK findings

Findings for ~/.claude/hooks/* per spec rubric. Includes stale .bak,
tdd-guard removal mechanics, Stop-hook LLM prompt cost, and
SessionStart hook output measurements."
```

---

## Task 7: Findings — skills (§2.5)

**Files:**
- Modify: `docs/audits/2026-05-25-claude-config-audit.md` (§2.5)

- [ ] **Step 1: Enumerate skills and their descriptions**

Run:

```bash
for d in ~/.claude/skills/*/; do
    name=$(basename "$d")
    desc=$(awk '/^---$/{c++; next} c==1' "$d/SKILL.md" 2>/dev/null | grep -E '^description:' | sed 's/^description: //')
    desc_len=${#desc}
    body_lines=$(awk '/^---$/{c++; next} c==2' "$d/SKILL.md" 2>/dev/null | wc -l)
    printf "%-30s desc=%4d body_lines=%4d\n" "$name" "$desc_len" "$body_lines"
done
```

This shows per-skill description length (pre-loaded cost) and body length (load-on-trigger cost).

- [ ] **Step 2: Identify the private subtree**

The private-related skills slated for relocation per locked decision:
- `private-skill`, `private-skill-1`, `private-skill-2`, `private-skill-3`, `private-skill-4`, `private-skill-5`, `private-skill-6`

Measure their combined contribution to the auto-loaded skill-description surface.

- [ ] **Step 3: Write F-SKILL-NN findings**

Minimum:
- F-SKILL-01: private subtree relocation (P1, medium, locked decision — references spec §4.5)
- F-SKILL-02: skill description bloat (any descriptions >300 chars are flagged)
- F-SKILL-03: skill body size violators (any SKILL.md >500 lines per Anthropic guidance)
- F-SKILL-04: redundancy with plugin-provided skills (e.g., `superpowers:test-driven-development` vs local `tdd-protocol`)
- One finding per skill with a concrete issue

- [ ] **Step 4: Commit**

```bash
git add docs/audits/2026-05-25-claude-config-audit.md
git commit -sS -m "docs(audit): F-SKILL findings

Findings for ~/.claude/skills/* per spec rubric. Includes private
relocation mapping, description bloat measurements, and overlap
with plugin-provided skills."
```

---

## Task 8: Findings — agents, plugins, and meta-skills (§2.6, §2.7, §2.8)

**Files:**
- Modify: `docs/audits/2026-05-25-claude-config-audit.md` (§2.6, §2.7, §2.8)

- [ ] **Step 1: Read all 4 agent files**

`~/.claude/agents/doc-writer.md`, `explorer.md`, `principal-engineer.md`, `qa-engineer.md`.

- [ ] **Step 2: Cross-reference with team-execute**

Read `~/.claude/commands/team-execute.md` and `~/.claude/skills/team-execute/SKILL.md`. Confirm the 4 agents are still the right set for the team-execute orchestration. Note any agent whose tool allowlist is over- or under-scoped.

- [ ] **Step 3: Write F-AGENT-NN findings**

At minimum, one summary finding on whether the agent set + their tool allowlists are correctly scoped for the team-execute flow.

- [ ] **Step 4: Enumerate enabledPlugins**

Run:

```bash
jq '.enabledPlugins' ~/.claude/settings.json
```

Five plugins enabled. For each, determine if it's actively used in your workflow.

- [ ] **Step 5: Write F-PLUGIN-NN findings**

Minimum one finding per plugin with a recommendation (keep / disable / re-evaluate).

- [ ] **Step 6: Write F-META-NN findings (§2.8 meta-skills)**

The meta-skills area is currently empty — there are no router/gating skills in `~/.claude/skills/` today. The finding is a **gap-finding**: it describes the missing category and recommends building the first member.

Write at least:

```markdown
### 2.8 meta-skills

#### F-META-01 — Missing `pick-planner` router (gap finding)
- **Severity:** P1
- **Token impact:** estimated 2-4K tokens saved per simple plan invocation (current writing-plans boilerplate on simple tasks). Breakeven at ~1 simple invocation per session; classifier itself costs ~500-800 tokens.
- **Friction:** medium — currently every brainstorm → plan flow produces a heavyweight plan regardless of complexity.
- **Confidence:** high (architecturally identical to `validate-recommendation`, same panel infrastructure, same Nemotron backend, same persona pattern).
- **Effort:** small — one new skill dir, one new persona file, one edit to brainstorming's "Transition to implementation" step.
- **Current state:** No router/gating skills exist except `validate-recommendation` (which gates `AskUserQuestion`, not skill invocations). `writing-plans` is invoked unconditionally regardless of task complexity.
- **Recommended fix:** Build `~/.claude/skills/pick-planner/SKILL.md` + `personas/plan-complexity.md`. Classifier returns SIMPLE / MODERATE / COMPLEX. SIMPLE inlines 3-5 bullets; MODERATE writes a lite plan; COMPLEX invokes `superpowers:writing-plans`. Env-var disable via `SKIP_PLAN_ROUTER=1`. Update brainstorming's "Transition to implementation" wording.
- **Evidence:** spec §3.8 (area definition), §4.8 (theme), §5 P1 item 6.
```

If additional meta-skill gaps surface during the audit pass (e.g., a brainstorming gate, a debugging gate), capture them as F-META-02, F-META-03 with the same finding shape.

- [ ] **Step 7: Commit**

```bash
git add docs/audits/2026-05-25-claude-config-audit.md
git commit -sS -m "docs(audit): F-AGENT, F-PLUGIN, F-META findings

Findings for agents/, enabledPlugins, and meta-skills (new gap-finding
area: pick-planner router) per spec rubric."
```

---

## Task 9: Cross-cutting themes (§3)

**Files:**
- Modify: `docs/audits/2026-05-25-claude-config-audit.md` (§3)

- [ ] **Step 1: Copy the seven themes from spec §4 into §3 of the audit**

For each theme, include:
1. **Summary** — 2-3 lines pulled from spec §4 with measured numbers folded in (e.g., "Stop-hook LLM prompt: measured X bytes/turn from `inject-date.sh` and Y bytes from `reflection-staleness.sh`...").
2. **Cross-references** — which finding IDs (from §2) the theme touches.
3. **Recommendation direction** — concrete, not "consider".

Themes (must include all eight):
- 3.1 Stop-hook LLM prompt cost
- 3.2 Cache-TTL regression
- 3.3 Opus 4.7 tokenizer expansion
- 3.4 TDD-guard removal mechanics
- 3.5 private skill relocation mechanics
- 3.6 Worktrees experimental flag vs official GA
- 3.7 Security posture (incl. PANEL_DA_API_KEY rotation requirement)
- 3.8 Plan-routing via cheap classifier — generalizes validate-recommendation; cross-ref F-META-01

- [ ] **Step 2: Commit**

```bash
git add docs/audits/2026-05-25-claude-config-audit.md
git commit -sS -m "docs(audit): cross-cutting themes

Seven themes from spec §4 with measured numbers and finding-ID
cross-references."
```

---

## Task 10: Phased action plan (§4)

**Files:**
- Modify: `docs/audits/2026-05-25-claude-config-audit.md` (§4)

- [ ] **Step 1: Build P0 — Quick wins**

For §4.1, list each P0 action item as a numbered task that references the finding IDs it resolves. Example:

```markdown
### 4.1 P0 — Quick wins
1. Delete 6 stale `.bak` files (resolves F-HOOK-01)
2. Remove `tdd-guard.sh` from PreToolUse arrays + delete the script (resolves F-HOOK-02, F-CLAUDEMD-01)
3. Replace or delete Stop-hook `"type": "prompt"` (resolves F-HOOK-03)
4. Fix `validate-recommendation` sandbox-write path (resolves F-HOOK-04)
5. Document `gh *` permission expectation in CLAUDE.md (resolves F-SETTINGS-NN)
6. Rotate `PANEL_DA_API_KEY` — out-of-band, not via Claude (resolves §3.7)
```

- [ ] **Step 2: Build P1 — Structural**

Same shape. Items per spec §5 P1:
1. private subtree relocation (resolves F-SKILL-01)
2. Migrate experimental agent-teams to official `isolation: worktree` (resolves F-SETTINGS-NN, F-AGENT-NN)
3. Compress rules/ where redundant (resolves F-RULES-NN aggregate)
4. Tighten skill descriptions (resolves F-SKILL-02)
5. Cache-TTL strategy (resolves §3.2)
6. Build `pick-planner` router skill (resolves F-META-01, §3.8)

- [ ] **Step 3: Build P2 — Polish**

Per spec §5 P2.

- [ ] **Step 4: Commit**

```bash
git add docs/audits/2026-05-25-claude-config-audit.md
git commit -sS -m "docs(audit): phased action plan

P0/P1/P2 mapping with finding-ID cross-references. Phase A is this
audit; P0/P1/P2 get their own implementation plans after this audit
merges."
```

---

## Task 11: Validation gate section (§5) + self-review

**Files:**
- Modify: `docs/audits/2026-05-25-claude-config-audit.md` (§5)

- [ ] **Step 1: Write the validation gate section**

§5 captures: how to measure per-session baseline tokens (telemetry path or status-line snapshot), the 20% reduction target after P0+P1, and the gate for promoting from `promptsLibrary/.claude` to `~/.claude` (locked editing strategy from spec).

```markdown
## 5. Validation gate

**Baseline measurement (pre-P0):**
1. Open a fresh Claude Code session against this repo (`promptsLibrary/`).
2. Send a no-op prompt: "echo hello".
3. Capture the prompt-token count from the status line or `~/.claude/telemetry/`.
4. Record as the baseline.

**Per-phase gate:**
After each of P0, P1, P2 lands in `promptsLibrary/.claude`:
1. Repeat the baseline measurement.
2. Diff vs. previous baseline.
3. If P0+P1 cumulative reduction < 20%, do NOT promote to `~/.claude` — debug in the repo first.

**Promotion procedure:**
Per the locked editing strategy: edits land first in `promptsLibrary/.claude/`. Once a phase's validation gate passes, sync to `~/.claude/` via the script defined in the P0 plan (sync script itself is a deliverable in the P0 phase plan, not Phase A).
```

- [ ] **Step 2: Self-review against spec §1 rubric**

Read the full audit doc. Confirm:
- Every finding has all 6 rubric fields populated (severity, token impact, friction, confidence, effort, evidence with file:line).
- No `<N>` or `TBD` placeholders survived.
- Every cross-cutting theme is cross-referenced to at least one finding ID.
- §4 P0/P1/P2 items each reference at least one finding ID they resolve.
- Locked decisions (TDD removal, private move, edit-repo-first, 20% target) appear in §3 themes consistently.

Fix any issues inline. No need to re-review after fixing.

- [ ] **Step 3: Commit**

```bash
git add docs/audits/2026-05-25-claude-config-audit.md
git commit -sS -m "docs(audit): validation gate + final self-review

Validation gate section (baseline, per-phase target, promotion
procedure). Self-review against spec §1 rubric — all findings have
full rubric fields, no placeholders, all themes cross-referenced."
```

---

## Task 12: PR

**Files:**
- No file changes; PR only.

- [ ] **Step 1: Push the branch**

Run:

```bash
git push -u origin "$(git branch --show-current)"
```

- [ ] **Step 2: Open draft PR**

Run:

```bash
gh pr create --draft --title "docs(audit): claude config PE audit — Phase A" --body "$(cat <<'EOF'
## Problem
Phase A of the Claude config PE audit. Produces the source-of-truth audit document with concrete findings and a mapping to action phases.

## Approach
Read-only audit of \`~/.claude\` (mirrored in \`~/.claude/\` for reproducibility). Per the spec at \`docs/superpowers/specs/2026-05-25-claude-config-pe-audit-design.md\`.

## Deliverable
\`docs/audits/2026-05-25-claude-config-audit.md\`

## Testing
Self-review against spec §1 rubric; every finding has severity, token impact, friction, confidence, effort, and evidence with file:line refs.

## Next steps
After this merges, follow-up plans for P0/P1/P2 reference the finding IDs in §2 of the audit doc.

Closes (no issue — internal config work).
EOF
)"
```

Expected: PR opens as draft.

- [ ] **Step 3: Verify**

Run: `gh pr view --json url,isDraft,title`
Expected: JSON with `isDraft: true`, the title matches, URL is set.

---

## Self-review checklist (before declaring Phase A done)

After all tasks complete:

1. **Spec coverage:**
   - [ ] §1 rubric used on every finding
   - [ ] §3 finding-shape applied (ID, all 6 rubric fields, evidence)
   - [ ] §3.1-3.7 areas all have findings
   - [ ] §4 cross-cutting themes all present in audit §3
   - [ ] §5 Phase A produces the audit doc (this plan); P0/P1/P2 are referenced by ID, not executed
   - [ ] §6 sources cited where the audit relies on the research

2. **Placeholder scan:**
   - [ ] No `TBD`, `TODO`, `<N>` survive
   - [ ] No "add appropriate ..." vague fixes
   - [ ] Every recommended fix names the file/section to change

3. **Type consistency:**
   - [ ] Finding ID format consistent: `F-<AREA>-<NN>` (CLAUDEMD, RULES, SETTINGS, HOOK, SKILL, AGENT, PLUGIN, META)
   - [ ] §4 action items reference exact finding IDs that exist in §2

If any check fails, fix inline and amend the relevant commit.

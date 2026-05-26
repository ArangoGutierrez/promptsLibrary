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
### 3.5 CFO skill relocation — mechanics
### 3.6 Worktrees: experimental flag vs official GA
### 3.7 Security posture
### 3.8 Plan-routing via cheap classifier (new)

## 4. Phased action plan

### 4.1 P0 — Quick wins
### 4.2 P1 — Structural
### 4.3 P2 — Polish

## 5. Validation gate

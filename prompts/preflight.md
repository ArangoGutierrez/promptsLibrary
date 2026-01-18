# PRE-FLIGHT SCAN

## ROLE
**Reconnaissance Agent** — Codebase Assessment

### Responsibilities:
- Scan repo state before proposing edits
- Detect toolchain and health gates
- Report verified summaries (≤10 lines/section)

### Boundaries:
- Read-only: no modifications
- Evidence-based: cite actual command outputs
- Flag uncertainty explicitly

## GOAL
Before proposing edits, scan repo and report summaries (≤10 lines/section) with verification

## CHECKS

### 1. Workspace Status
```bash
git rev-parse --show-toplevel && git status --porcelain
```

### 2. Toolchain Detection
Scan for: README | Makefile | Taskfile | go.mod | package.json | pyproject.toml | Cargo.toml | WORKSPACE | BUILD* | .editorconfig | CI configs

### 3. Health Gates (if configured)
Run in order (no changes): format → lint → typecheck → test-discovery

### 4. Topology
Enumerate packages/targets/modules to gauge size and boundaries

### 5. VERIFY (Factor+Revise CoVe) — META 2023, +27% precision

**Step 5.1: Generate Verification Questions**
| Check | Verification Question |
|-------|----------------------|
| V1 | "Did I actually run git status or assume clean?" |
| V2 | "Are detected tools consistent? (go.mod but no .go files?)" |
| V3 | "Did health gates pass, fail, or skip?" |
| V4 | "Is topology complete or partial scan?" |

**Step 5.2: Execute Verifications INDEPENDENTLY**
⚠️ Answer each question in isolation WITHOUT referencing:
- The original scan results
- Other verification questions
- Previous verification answers

Re-run commands if uncertain. Fresh examination.

**Step 5.3: Cross-Check and Assign Confidence**
| Check | Independent Answer | Confidence |
|-------|-------------------|------------|
| V1 | {re-run result} | ✓ Confirmed / ⚠ Partial / ? Assumed |

**Step 5.4: Output Only with Confidence Ratings**
Every item in output must have confidence rating attached.

## OUTPUT
```
## Pre-Flight Report

### Workspace: [path]
- Git status: [clean|dirty] [✓/⚠/?]
- Branch: [name]

### Toolchain
- Detected: [list] [✓/⚠/?]
- Consistency: [ok|issue]

### Health Gates
- Format: [pass|fail|skip] [✓/⚠/?]
- Lint: [pass|fail|skip] [✓/⚠/?]
- Typecheck: [pass|fail|skip] [✓/⚠/?]
- Tests: [discovered N] [✓/⚠/?]

### Topology
- Packages/Modules: N
- Coverage: [full|partial] [✓/⚠/?]

### Verification Summary (Factor+Revise)
- Checks confirmed (✓): X
- Partial (⚠): Y
- Assumed (?): Z
- Assumptions made: [list if any]
```

## TOKEN PROTOCOL
| Rule | Implementation |
|------|----------------|
| `ref>paste` | Cite paths, avoid full file contents |
| `table>prose` | Health checks, topology → table format |
| `summary-only` | ≤10 lines per section, no verbose dumps |

## CONSTRAINTS
- read-only: no modifications to workspace
- verification-gate: all checks must pass Factor+Revise (Step 5.2 independent check)
- isolation: Step 5.2 MUST be independent (no reference to original scan)
- confidence-required: every output item must have confidence rating

## Self-Check (Before Finalizing)

```
┌─────────────────────────────────────────────────────────────┐
│ PRE-FLIGHT SELF-CHECK                                       │
├─────────────────────────────────────────────────────────────┤
│ CHECKS                                                      │
│ □ Workspace status verified?                                │
│ □ Toolchain detected?                                       │
│ □ Health gates run (format/lint/typecheck)?                 │
│ □ Topology enumerated?                                      │
├─────────────────────────────────────────────────────────────┤
│ VERIFICATION                                                │
│ □ All checks passed Factor+Revise?                          │
│ □ Step 5.2 executed independently?                          │
│ □ Confidence ratings assigned to all items?                 │
├─────────────────────────────────────────────────────────────┤
│ OUTPUT                                                      │
│ □ ≤10 lines per section?                                    │
│ □ Verification Summary included?                            │
│ □ Token protocol followed (ref>paste)?                      │
├─────────────────────────────────────────────────────────────┤
│ Any □ unchecked → address before output                     │
└─────────────────────────────────────────────────────────────┘
```

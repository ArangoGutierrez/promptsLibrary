# CURSOR USER RULES (Depth-Forcing + Token-Optimized)

Copy entire block → Cursor → Settings → Rules → User Rules
Legend: →=then|≥=minimum|∴=therefore|⚠=warn|✓=pass|✗=fail|?=uncertain

## Setup

1. Clone promptsLibrary to a local directory
2. Update the `# LIB` section below with YOUR path
3. Example: `# LIB /Users/yourname/promptsLibrary/prompts/`

---

# DEPTH (anti-satisficing, System-2 forcing)
- model-first: entities→relations→constraints→state BEFORE solve
- enumerate≥3: list ≥3 paths/options before ANY selection
- no-first-solution: 2+ approaches→compare→select-with-rationale
- critic-loop: after-output check: gaps|contradictions|missed-constraints
- doubt-verify: conclusion→counter-evidence→re-verify
- exhaust: "all constraints checked?" must=YES before proceed
- slow>fast: thorough-analysis > quick-response; unlimited-time-framing

# TOKEN (optimize for large codebases)
- ref>paste: use `path:line` refs, never paste code unless editing
- table>prose: structured data in tables, not sentences
- abbrev: fn|impl|cfg|ctx|err|req|res|auth|val|init|exec
- symbols: →∴⚠✓✗≥≤@#|& (no "leads to", "therefore", "warning")
- no-filler: omit "I'll now", "Let me", "Here's", "certainly"
- enum>sentences: `1.X 2.Y` not "First X, then Y"
- delta-only: show only changed lines, not full files

# LIB /path/to/promptsLibrary/prompts/  <-- UPDATE THIS PATH
# Trigger commands map to prompt files:
DeepMode→master-agent.md (depth-first,token-optimized,all-protocols)
MetaEnhance→meta-enhance.md (recursive self-improvement loop)
Audit[scope]→audit-go.md|Audit2Prompt→audit-to-prompt.md
FixAudit→audit-to-prompt.md|GitPolish→git-polish.md
Plan→workflow.md|PreFlight→preflight.md
Research#N→research-issue.md|ReviewPR→pr_review.md
Issue2Prompt#N→issue-to-prompt.md|Task→task-prompt.md

# VERIFY (Factor+Revise CoVe)
1.claims→questions 2.answer-independently(no-ref-original) 3.reconcile:✓keep|✗drop|?flag
Applies: file:line|API-names|cfg-values|existence-claims

# GUARD
≤3Q-else-proceed+assumptions|no-invent-endpoints/flags/deps
native-cmds-only|approval-required:API-change|dep-install|workspace-modify

# LANG
Go:gofmt→vet→lint→test;doc≤80ch;non-internal/=public
Bazel:atomic-BUILD;validate-rdeps|TS:repo-pkg-mgr;tsc--noEmit
k/k:API-stability;feature-gates;release-note

# STYLE
Go:doc≤80|ref>paste|table>prose|structured-output

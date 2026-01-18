# TASK-PROMPT (token-min)

## ROLE
TechLead—spec-first autonomous task prompts

## GOAL
Generate self-contained prompt→complete task lifecycle

## TRIGGERS
Issue#N→issue-task|{desc}→adhoc|recommended→prior-analysis|fix:{issue}→bugfix

## RESEARCH
+25% correctness(Self-Planning,PKU)|+61% hard-probs(plan-before-code)
+27% precision(CoVe)|−41% tokens(PASR)|+15-20%(PR-CoT)|−56% vulns(security-prefix)

---

## EXEC

### P1:UNDERSTAND(10%)
```
git remote get-url origin→owner/repo
git rev-parse --show-toplevel→root
```
If Issue: fetch title|body|labels|comments|linked-PRs
Clarify(≤2Q): ambiguities?|implicit-assumptions?

### P2:SPECIFY(15%)
|Element|Define|
|-------|------|
|Inputs|data/state entering|
|Outputs|what changes|
|Constraints|perf|security|style|compat|
|Acceptance|how verify works|
|Edges|what fails|
|OutScope|NOT doing|

### P3:VERIFY-SPEC(5%)
conflicts?|missing?|testable?|files-exist?

### P4:PLAN(10%)
task=1-logical-change=1-test=1-commit
non-trivial: 2-3 solutions→tradeoffs→select

### P5:VERIFY-PLAN(5%)
satisfies-constraints?|deps-ordered?|complexity-realistic?

### P6:GENERATE
→`prompts/{type}-{slug}.md`

---

## TIME-ALLOC

|Type|Spec|Plan|Impl|Verify|
|----|----|----|----|----|
|Trivial|5%|5%|80%|10%|
|Simple|15%|10%|60%|15%|
|Moderate|25%|15%|45%|15%|
|Complex|35%|15%|35%|15%|
|Arch|40%|20%|25%|15%|

---

## OUTPUT-TPL

```
# {Type}: {Title}

## Ref
Issue:#{N}|Repo:{o}/{r}|Branch:`{prefix}/{slug}`|P:{0-3}|Complexity:{T|S|M|C|A}

## Background
{2-3 sentences: problem + why matters}

## Objective
{1 sentence: done=?}

---

## Spec (before impl)

### Problem
{restate to confirm}

### Assumptions
- {A1}
- {A2}

### I/O
|In|Type|Desc|
|--|----|----|
|{in}|{t}|{d}|

|Out|Type|Desc|
|---|----|----|
|{out}|{t}|{d}|

### Constraints(prioritized)
**MUST**(required):
- [ ] {hard-req}

**SHOULD**(prefer):
- [ ] {perf-target}

**MUST-NOT**(forbidden):
- [ ] {prohibited}

**Security**(−56% vulns):
- [ ] no-hardcoded-secrets
- [ ] input-val@public
- [ ] safe-error-handling

> ⚠ MUST≤7 else split-task|raise-complexity (UCL 2025: over-spec degrades)

### Accept
- [ ] {testable-1}
- [ ] {testable-2}

### Edges
|Case|Expected|
|----|--------|
|{edge}|{behavior}|

### OutScope
- {NOT doing}

---

## Solution

### Selected: {Name}
{desc}

### Alts
|Approach|Pros|Cons|Why-Not|
|--------|----|----|-------|
|{Alt1}|{p}|{c}|{r}|

---

## Auto-Mode

> 🔁 UNTIL ALL [DONE]. Remain→re-invoke `@prompts/{file}.md`

### Reflect(PR-CoT +15-20%)
|Dim|Q|✓/✗|
|---|--|---|
|Logic|contradictions?||
|Complete|all-reqs?||
|Correct|matches-accept?||
|Edges|boundaries?||
|External|tools-pass?||

### Budget(PASR −41% tokens)
|Complexity|Max-Iter|At-Limit|
|----------|--------|--------|
|T|1|done|
|S|2|review|
|M|3|review|
|C|4|escalate|

Stop: all-reflect✓→STOP|tool-fail→fix|budget-exceeded→human

### Tracker
|#|Phase|Task|Status|
|-|-----|----|------|
|0|Setup|branch|`[TODO]`|
|1|Spec|verify-spec|`[TODO]`|
|2|Impl|{task1}|`[TODO]`|
|N|Test|verify-accept|`[TODO]`|
|N+1|PR|create|`[TODO]`|
|N+2|PR|feedback|`[TODO]`|
|N+3|Merge|**approval**|`[WAIT]`⚠human|

Legend:`[TODO]`|`[WIP]`|`[DONE]`|`[WAIT]`|`[BLOCKED:x]`

---

## Test

### Pre-Commit
Go:`make all`|TS:`npm run lint&&test`|Py:`ruff.&&pytest`|Rust:`cargo fmt--check&&clippy&&test`

### Verify-Accept
|Criterion|Method|✓|
|---------|------|-|
|{C1}|{how}|⬜|

---

## Commit
`git commit -s -S -m "type(scope): desc"`
-s=DCO|-S=sign|-m=inline
Types:feat|fix|docs|refactor|test|chore|ci|perf
Atomic:1-change=1-commit

---

## PR
```
gh pr create --title "{type}({scope}): {desc}" --body "Fixes #{N}
## Summary
{brief}
## Spec-Compliance
- [x] accept-met
- [x] edges-handled
- [x] constraints-satisfied
## Changes
- {c1}
## Test
- [ ] unit-pass
- [ ] manual-done"
```

---

## Merge(human-approval)
> 🛑 NO auto-merge

Ready:
```
## ✅ Ready
PR:#{N}|CI:✅|Reviews:✅|Spec:✅
Reply "MERGE"
```

Post:`gh pr merge {N} --squash --delete-branch && git checkout main && git pull`

---

## Self-Check
```
┌─────────────────────────────────────────┐
│ SELF-CHECK                              │
├─────────────────────────────────────────┤
│ SPEC                                    │
│ □ complete+verified?                    │
│ □ MUST≤7?                               │
│ □ security-checked?                     │
├─────────────────────────────────────────┤
│ REFLECT(PR-CoT)                         │
│ □ logic:no-contradictions?              │
│ □ complete:all-reqs?                    │
│ □ correct:matches-accept?               │
│ □ edges:boundaries?                     │
│ □ external:tools-pass?                  │
├─────────────────────────────────────────┤
│ PROGRESS                                │
│ □ ≥1 task done?                         │
│ □ tracker updated?                      │
│ □ committed?                            │
│ □ within-budget?                        │
├─────────────────────────────────────────┤
│ spec-incomplete→complete-first          │
│ reflect-fail→fix-before-continue        │
│ tasks-remain→re-invoke                  │
│ budget-exceeded→escalate                │
│ all-done→archive                        │
└─────────────────────────────────────────┘
```

---

## CONSTRAINTS
spec-first|atomic-tasks|verify-gate|no-auto-merge|native-cmds
evidence-based|time-aware|over-spec-aware(≤7)|multi-perspective
iteration-budget|security-explicit
```

## Stats
Original: ~430 lines, ~12K chars
Compressed: ~220 lines, ~5K chars
Reduction: ~58% tokens saved

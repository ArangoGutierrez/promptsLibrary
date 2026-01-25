# Research
`#{n}`→GH issue|`{topic}`→codebase
READ-ONLY

## Flow
1.`git remote get-url origin && git rev-parse --show-toplevel`
2.GH#→title,body,labels,state,comments,linked-PRs
3.Classify:Type(bug/feat/refactor/docs/perf/sec)|Severity(crit/high/med/low)|Scope(local/cross/arch)|Complex(trivial/mod/complex/unknown)
4.Investigate:files/pkgs|traces→src|tests|patterns|deps
5.Verify:|Claim|Q|→✓proceed
  C1:files exist?|C2:behavior repro?|C3:understanding=code?
6.Solutions(2-3 each):Approach|Files+why|Complex(LOC)|Trade|Risk
7.Compare:|Criterion|S1|S2|S3|→Effort/Risk/Maintain(L/M/H)

## Output
```
# Research: #{n} - {title}
## Summary
Type:{class}|Severity:{level}
## Problem
{2-3 sent}
## Root Cause
{tech+file:line}
## Solutions
### 1. {Name} ⭐
### 2. {Name}
## Recommendation
S1∵{why}
## Open Questions
```

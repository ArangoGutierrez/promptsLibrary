---
name: pr-review
description: Rigorous PR review with confidence scoring
---
# PR Review

## Activate
review PR|validate changes|"review"|"check PR"

## Passes
|Pass|Focus|Q|
|1|Guidelines|violates?|
|2|Bugs|CHANGED lines only?|
|3|History|why written this way?|
|4|Arch|patterns?perf?tested?|

## Confidence
Report only≥80
0-50:DROP|51-79:question|80-100:report
+20:exact file:line|THIS PR|justified|verified|fix provided

## Security(high-risk)
creds?|injection(SQL,cmd,path)?|input-val?|authz bypass?|data in err?

## Verify
Each:1.gen Q 2.re-read INDEPENDENTLY 3.✓confirm/✗false-pos/?question

## Output
🔴Blocking(≥80)|🟡Health|🔵Questions
Verdict:Approved/Changes Requested/Blocked

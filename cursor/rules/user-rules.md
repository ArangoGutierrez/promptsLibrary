---
description: Personal preferences and style overrides (supplements project.md)
alwaysApply: true
---

# User Rules

> **Note**: Core engineering standards are in `project.md`. This file contains personal preferences and overrides.

## PERSONAL STYLE

### Communication Preferences
- Direct, no hedging ("This will fail" not "This might potentially fail")
- Technical depth over simplified explanations
- Assume Senior Engineer audience
- Challenge my assumptions when warranted

### Code Style Preferences
- Explicit over clever (readable > concise)
- Comments explain "why", not "what"
- Prefer composition over inheritance
- Small functions with single responsibility

### Review Preferences
- Point out issues I might have missed, even if not asked
- Suggest better approaches when you see them
- Don't rubber-stamp—apply genuine scrutiny

## WORKFLOW OVERRIDES

### When I Say "Quick"
- Still apply DEPTH principles
- Warn if quick means dirty
- Offer both quick and robust options

### When I Say "Just Do It"
- Proceed without confirmation prompts
- Still verify before completion
- Skip the iteration breakdown

### When I'm Stuck
- Ask clarifying questions (max 3)
- Propose concrete next step
- Don't just describe the problem—solve it

## ABBREVIATION DICTIONARY
Standard abbreviations for token efficiency:
| Abbrev | Meaning | Abbrev | Meaning |
|--------|---------|--------|---------|
| fn | function | impl | implementation |
| cfg | config | ctx | context |
| err | error | req | request |
| res | response | auth | authentication |
| val | validation | init | initialization |
| exec | execution | dep | dependency |
| pkg | package | svc | service |

## CONFLICT RESOLUTION
When rules conflict:
1. Security > Correctness > Performance > Style
2. User explicit request > Default behavior
3. project.md > user-rules.md (unless safety concern)

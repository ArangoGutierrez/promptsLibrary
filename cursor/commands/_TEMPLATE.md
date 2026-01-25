# {Command Name}

{One-line description of what this command does}

## Usage
<!-- REQUIRED: Show all usage patterns with examples -->
- `{param}` — Description of what this parameter does
- `{param} {value}` — Description with example value
- `--flag` — Description of flag behavior
- `--flag {value}` — Flag with value description
- `#{number}` — Special syntax explanation (e.g., GitHub issue number)

<!-- Alternative format for complex commands with multiple patterns: -->
```
/{command} {param}
/{command} {param} --flag
/{command} {param} --flag {value}
```

## Workflow
<!-- REQUIRED for multi-step commands. Use "What Happens" for pipeline-style commands -->
<!-- For simple commands, a brief numbered list is sufficient -->
<!-- For complex pipelines, use phased approach with Input/Output -->

### Phase 1: {Phase Name}
{Description of what happens in this phase}

**Input**: {What data/state enters this phase}
**Output**: {What this phase produces}

### Phase 2: {Phase Name}
{Description}

**Input**: {Input}
**Output**: {Output}

<!-- Optional: ASCII diagram for complex pipelines -->
```
┌─────────────┐
│   Step 1    │ → Output A
└──────┬──────┘
       │
       ▼
┌─────────────┐
│   Step 2    │ → Output B
└─────────────┘
```

<!-- For simple commands, use numbered steps: -->
1. {First step}
2. {Second step}
3. {Third step}

## Output Format
<!-- REQUIRED: Show expected output structure as markdown template -->
<!-- This helps users understand what to expect and helps AI produce consistent results -->

```markdown
# {Output Title}

## {Section Name}
{Description of what goes here}

## {Another Section}
{Content description}

| Column 1 | Column 2 |
|----------|----------|
| {value}  | {value}  |
```

## Constraints
<!-- REQUIRED: Rules that must be followed when executing this command -->
<!-- Use bold keywords for emphasis -->
- **{Keyword}**: {Explanation of constraint}
- **{Keyword}**: {Explanation}
- **{Keyword}**: {Explanation}

## Troubleshooting
<!-- OPTIONAL but RECOMMENDED: Common issues and solutions -->
<!-- Use table format for structured problems -->

| Issue | Solution |
|-------|----------|
| {Common problem} | {How to fix it} |
| {Another issue} | {Solution steps} |

<!-- Alternative format for more complex troubleshooting: -->
### {Issue Category}
**Problem**: {Description}
**Cause**: {Why it happens}
**Solution**: {How to fix}

### {Another Issue Category}
**Problem**: {Description}
**Actions**:
1. {Step 1}
2. {Step 2}
3. {Step 3}

## {Optional Sections}
<!-- Add any additional sections specific to your command -->
<!-- Examples: -->
<!-- ## Quick Mode (--quick) -->
<!-- ## Reflection -->
<!-- ## Iteration Budget -->
<!-- ## Commit Format -->
<!-- ## PR Format -->

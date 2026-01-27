# Claude Code Documentation

Complete documentation for the Claude Code workflow system.

## 📁 Documentation Structure

### 📘 Migration Documentation (`migration/`)

Documentation about migrating from Cursor to Claude Code.

- **`complete-guide.md`** - Comprehensive migration guide covering all components
- **`cursor-to-claude-mapping.md`** - Mapping between Cursor and Claude Code features
- **`MIGRATION_STATUS.md`** - Final status verification (all components migrated)

### 🧠 Context Monitor (`context-monitor/`)

Documentation for the context monitoring system.

- **`user-guide.md`** - Complete user guide for using context monitor
- **`summary.md`** - Quick summary and overview
- **`research.md`** - Deep research analysis and design decisions
- **`cursor-comparison.md`** - Detailed comparison with Cursor's implementation

### 📚 Guides (`guides/`)

Practical guides and tutorials.

- **`testing-agent-models.md`** - Guide for testing different agent models

### 📦 Archive (`cursor-archive/`)

Historical Cursor documentation for reference.

Contains original Cursor documentation that has been superseded by Claude Code implementations.

---

## 🚀 Quick Navigation

### For New Users

1. Start with the main [README.md](../README.md)
2. Review [migration/complete-guide.md](migration/complete-guide.md)
3. Read component-specific READMEs:
   - [Agents](../agents/README.md)
   - [Skills](../skills/README.md)
   - [Hooks](../hooks/README.md)

### For Migration

1. [cursor-to-claude-mapping.md](migration/cursor-to-claude-mapping.md) - What changed
2. [complete-guide.md](migration/complete-guide.md) - Full migration details
3. [MIGRATION_STATUS.md](migration/MIGRATION_STATUS.md) - Verification

### For Context Monitoring

1. [user-guide.md](context-monitor/user-guide.md) - How to use
2. [summary.md](context-monitor/summary.md) - Quick overview
3. [research.md](context-monitor/research.md) - Deep dive

---

## 📋 Component Documentation

### Agents

**Location**: `claude/agents/`

Specialized sub-agents for focused analysis:

- 12 regular agents (full documentation)
- 10 optimized agents (~50% fewer tokens)

**Documentation**: [agents/README.md](../agents/README.md)

### Skills

**Location**: `claude/skills/`

Workflow orchestrators for structured processes:

- 19 skills (all token-optimized)
- Planning, quality, testing, architecture, debugging, etc.

**Documentation**: [skills/README.md](../skills/README.md)

### Hooks

**Location**: `claude/hooks/`

Lifecycle automation:

- Context monitoring system
- Format, lint, sign, security hooks

**Documentation**: [hooks/README.md](../hooks/README.md)

---

## 🎯 Common Tasks

### Installing Context Monitor

```bash
cd claude/hooks
chmod +x install-context-monitor.sh
./install-context-monitor.sh --config
```

See [context-monitor/user-guide.md](context-monitor/user-guide.md)

### Deploying All Components

```bash
cd claude
./scripts/deploy-claude.sh --symlink
```

### Using Agents

```bash
Use the Task tool with the {agent-name} agent to {task description}.
```

See [agents/README.md](../agents/README.md)

### Using Skills

Skills are optimized workflow prompts. Use them directly or as reference.
See [skills/README.md](../skills/README.md)

---

## 📊 Migration Status

✅ **Agents**: 22/22 (12 regular + 10 optimized)
✅ **Skills**: 19/19
✅ **Hooks**: 11/11
✅ **Documentation**: Complete

See [MIGRATION_STATUS.md](migration/MIGRATION_STATUS.md) for details.

---

## 🔗 External Resources

### Official Claude Code

- [Claude Code Documentation](https://docs.anthropic.com/claude/docs)
- [Agent SDK](https://github.com/anthropics/claude-agent-sdk)

### Official Plugins (Recommended Over Custom)

- **ralph-wiggum** - Use `/ralph-loop` instead of custom loop
- **code-review** - Use `/code-review` for PR reviews
- **commit-commands** - Use `/commit-push-pr` for commits

---

## 📝 Contributing

When adding new documentation:

1. **Migration docs** → `migration/`
2. **Context monitor docs** → `context-monitor/`
3. **Guides/tutorials** → `guides/`
4. **Component docs** → Keep in component directory (`agents/`, `commands/`, `hooks/`)

Keep documentation:

- Clear and concise
- Well-organized
- Up-to-date
- With examples

---

## 📞 Support

- **Issues**: File in repository
- **Questions**: Check component READMEs first
- **Feedback**: Contribute via pull requests

---

**Last Updated**: 2026-01-27
**Status**: Complete and organized

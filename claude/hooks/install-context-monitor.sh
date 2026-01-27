#!/bin/bash
# install-context-monitor.sh - Install Claude Code context monitor hooks
#
# This script installs the context monitor hooks for Claude Code:
# - Copies hooks to ~/.claude/hooks/
# - Updates ~/.claude/hooks.json configuration
# - Optionally creates ~/.claude/context-config.json
#
# Usage:
#   ./install-context-monitor.sh [--uninstall] [--config]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_HOOKS_DIR="$HOME/.claude/hooks"
CLAUDE_HOOKS_CONFIG="$HOME/.claude/hooks.json"
CLAUDE_CONTEXT_CONFIG="$HOME/.claude/context-config.json"

# Hook files
CONTEXT_MONITOR="context-monitor.sh"
FILE_TRACKER="context-monitor-file-tracker.sh"
CONFIG_EXAMPLE="context-config-example.json"

# Parse arguments
UNINSTALL=false
INSTALL_CONFIG=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --uninstall)
            UNINSTALL=true
            shift
            ;;
        --config)
            INSTALL_CONFIG=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Install Claude Code context monitor hooks."
            echo ""
            echo "Options:"
            echo "  --uninstall    Remove context monitor hooks"
            echo "  --config       Install example config to ~/.claude/context-config.json"
            echo "  -h, --help     Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Check prerequisites
check_prerequisites() {
    echo -e "${BLUE}Checking prerequisites...${NC}"

    if ! command -v jq &> /dev/null; then
        echo -e "${RED}✗ jq is not installed${NC}"
        echo ""
        echo "jq is required for the context monitor hooks."
        echo "Install it with:"
        echo ""
        echo "  macOS:        brew install jq"
        echo "  Ubuntu/Debian: sudo apt-get install jq"
        echo "  Other:        https://jqlang.github.io/jq/download/"
        echo ""
        exit 1
    fi

    echo -e "${GREEN}✓ jq is installed${NC}"
}

# Uninstall hooks
uninstall_hooks() {
    echo -e "${BLUE}Uninstalling context monitor hooks...${NC}"

    # Remove hook files
    if [ -f "$CLAUDE_HOOKS_DIR/$CONTEXT_MONITOR" ]; then
        rm "$CLAUDE_HOOKS_DIR/$CONTEXT_MONITOR"
        echo -e "${GREEN}✓ Removed $CONTEXT_MONITOR${NC}"
    fi

    if [ -f "$CLAUDE_HOOKS_DIR/$FILE_TRACKER" ]; then
        rm "$CLAUDE_HOOKS_DIR/$FILE_TRACKER"
        echo -e "${GREEN}✓ Removed $FILE_TRACKER${NC}"
    fi

    # Update hooks.json to remove context monitor entries
    if [ -f "$CLAUDE_HOOKS_CONFIG" ]; then
        echo -e "${BLUE}Updating hooks configuration...${NC}"

        local tmp="${CLAUDE_HOOKS_CONFIG}.tmp.$$"

        # Remove context monitor entries from hooks.json
        jq '
            .hooks.stop = (.hooks.stop // [] | map(select(.command | contains("context-monitor.sh") | not))) |
            .hooks.afterFileEdit = (.hooks.afterFileEdit // [] | map(select(.command | contains("context-monitor-file-tracker.sh") | not)))
        ' "$CLAUDE_HOOKS_CONFIG" > "$tmp"

        mv "$tmp" "$CLAUDE_HOOKS_CONFIG"
        echo -e "${GREEN}✓ Updated hooks.json${NC}"
    fi

    # Note: We don't remove context-config.json or state files in case user wants to keep them
    echo ""
    echo -e "${GREEN}Context monitor hooks uninstalled successfully!${NC}"
    echo ""
    echo "Note: Configuration and state files were preserved:"
    echo "  - ~/.claude/context-config.json (if exists)"
    echo "  - .claude/context-state.json (per-project)"
    echo ""
    echo "Remove manually if desired:"
    echo "  rm ~/.claude/context-config.json"
    echo "  rm .claude/context-state.json"
}

# Install hooks
install_hooks() {
    echo -e "${BLUE}Installing context monitor hooks...${NC}"

    # Create hooks directory
    mkdir -p "$CLAUDE_HOOKS_DIR"
    echo -e "${GREEN}✓ Created $CLAUDE_HOOKS_DIR${NC}"

    # Copy hook files
    if [ ! -f "$SCRIPT_DIR/$CONTEXT_MONITOR" ]; then
        echo -e "${RED}✗ $CONTEXT_MONITOR not found in $SCRIPT_DIR${NC}"
        exit 1
    fi

    if [ ! -f "$SCRIPT_DIR/$FILE_TRACKER" ]; then
        echo -e "${RED}✗ $FILE_TRACKER not found in $SCRIPT_DIR${NC}"
        exit 1
    fi

    cp "$SCRIPT_DIR/$CONTEXT_MONITOR" "$CLAUDE_HOOKS_DIR/"
    chmod +x "$CLAUDE_HOOKS_DIR/$CONTEXT_MONITOR"
    echo -e "${GREEN}✓ Installed $CONTEXT_MONITOR${NC}"

    cp "$SCRIPT_DIR/$FILE_TRACKER" "$CLAUDE_HOOKS_DIR/"
    chmod +x "$CLAUDE_HOOKS_DIR/$FILE_TRACKER"
    echo -e "${GREEN}✓ Installed $FILE_TRACKER${NC}"

    # Update hooks.json
    echo -e "${BLUE}Updating hooks configuration...${NC}"

    if [ -f "$CLAUDE_HOOKS_CONFIG" ]; then
        # Hooks config exists - add our hooks
        local tmp="${CLAUDE_HOOKS_CONFIG}.tmp.$$"

        # Check if our hooks are already registered
        local has_monitor=$(jq -r '.hooks.stop[]?.command | select(. | contains("context-monitor.sh"))' "$CLAUDE_HOOKS_CONFIG" 2>/dev/null || echo "")
        local has_tracker=$(jq -r '.hooks.afterFileEdit[]?.command | select(. | contains("context-monitor-file-tracker.sh"))' "$CLAUDE_HOOKS_CONFIG" 2>/dev/null || echo "")

        if [ -n "$has_monitor" ] || [ -n "$has_tracker" ]; then
            echo -e "${YELLOW}⚠ Context monitor hooks already registered in hooks.json${NC}"
        else
            # Add hooks to existing config
            jq '
                .hooks.stop = (.hooks.stop // []) + [{"command": "~/.claude/hooks/context-monitor.sh"}] |
                .hooks.afterFileEdit = (.hooks.afterFileEdit // []) + [{"command": "~/.claude/hooks/context-monitor-file-tracker.sh"}]
            ' "$CLAUDE_HOOKS_CONFIG" > "$tmp"

            mv "$tmp" "$CLAUDE_HOOKS_CONFIG"
            echo -e "${GREEN}✓ Updated hooks.json${NC}"
        fi
    else
        # Create new hooks config
        cat > "$CLAUDE_HOOKS_CONFIG" << 'EOF'
{
  "version": 1,
  "hooks": {
    "stop": [
      {
        "command": "~/.claude/hooks/context-monitor.sh"
      }
    ],
    "afterFileEdit": [
      {
        "command": "~/.claude/hooks/context-monitor-file-tracker.sh"
      }
    ]
  }
}
EOF
        echo -e "${GREEN}✓ Created hooks.json${NC}"
    fi

    # Install config if requested
    if [ "$INSTALL_CONFIG" = true ]; then
        if [ -f "$CLAUDE_CONTEXT_CONFIG" ]; then
            echo -e "${YELLOW}⚠ $CLAUDE_CONTEXT_CONFIG already exists, skipping${NC}"
        else
            if [ -f "$SCRIPT_DIR/$CONFIG_EXAMPLE" ]; then
                cp "$SCRIPT_DIR/$CONFIG_EXAMPLE" "$CLAUDE_CONTEXT_CONFIG"
                echo -e "${GREEN}✓ Installed context-config.json${NC}"
            else
                echo -e "${YELLOW}⚠ $CONFIG_EXAMPLE not found, creating default config${NC}"
                cat > "$CLAUDE_CONTEXT_CONFIG" << 'EOF'
{
  "thresholds": {
    "healthy_max": 60,
    "filling_max": 80,
    "critical_max": 95
  },
  "weights": {
    "iteration": 10,
    "file": 3,
    "duration_minutes": 0.5
  },
  "stuck_threshold": 5,
  "long_session_minutes": 40
}
EOF
                echo -e "${GREEN}✓ Created default context-config.json${NC}"
            fi
        fi
    fi

    echo ""
    echo -e "${GREEN}Context monitor hooks installed successfully!${NC}"
    echo ""
    echo "The hooks are now active and will:"
    echo "  • Track context usage in Claude Code sessions"
    echo "  • Recommend new sessions when context is filling"
    echo "  • Detect stuck states and suggest fresh starts"
    echo ""
    echo "Configuration:"
    echo "  Hooks:  $CLAUDE_HOOKS_CONFIG"

    if [ "$INSTALL_CONFIG" = true ]; then
        echo "  Config: $CLAUDE_CONTEXT_CONFIG"
    else
        echo "  Config: (using defaults, run with --config to customize)"
    fi

    echo ""
    echo "State files will be created per-project in:"
    echo "  .claude/context-state.json"
    echo ""
    echo "For more information, see:"
    echo "  $SCRIPT_DIR/CONTEXT_MONITOR.md"
}

# Main
main() {
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Claude Code Context Monitor Installation${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo ""

    if [ "$UNINSTALL" = true ]; then
        uninstall_hooks
    else
        check_prerequisites
        install_hooks
    fi
}

main

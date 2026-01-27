#!/bin/bash
#
# deploy-claude.sh - Deploy Claude plugins to user's system
#
# IMPORTANT: This script must be run from a regular terminal, NOT from within
# Claude Code, due to sandbox restrictions on writing to ~/.claude/
#
# Usage:
#   ./scripts/deploy-claude.sh [OPTIONS]
#
# Options:
#   --global             Deploy to ~/.claude/ (default)
#   --project <path>     Deploy to <path>/.claude/
#   --symlink            Use symlinks instead of copying files
#   --force              Overwrite existing files
#   --dry-run            Show what would be done
#   --uninstall          Remove deployed files
#   --agents-type <type> Deploy regular, optimized, or both agents (default: regular)
#   --help               Show this help message
#
# Remote Installation (no git clone required):
#   curl -fsSL https://raw.githubusercontent.com/ArangoGutierrez/promptsLibrary/main/scripts/deploy-claude.sh | bash -s -- --download
#   # or with wget:
#   wget -qO- https://raw.githubusercontent.com/ArangoGutierrez/promptsLibrary/main/scripts/deploy-claude.sh | bash -s -- --download
#
# Environment Variables:
#   CLAUDE_DEV_REPO   Override the GitHub repo (default: ArangoGutierrez/promptsLibrary)
#   CLAUDE_DEV_BRANCH Override the branch (default: main)
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Default options
TARGET_DIR="$HOME/.claude"
MODE="copy"
FORCE=false
DRY_RUN=false
UNINSTALL=false
DOWNLOAD=false
AGENTS_TYPE="regular"

# GitHub repo settings
GITHUB_REPO="${CLAUDE_DEV_REPO:-ArangoGutierrez/promptsLibrary}"
GITHUB_BRANCH="${CLAUDE_DEV_BRANCH:-main}"
GITHUB_RAW_BASE="https://raw.githubusercontent.com/${GITHUB_REPO}/${GITHUB_BRANCH}"
TEMP_DOWNLOAD_DIR=""

# Get script directory (where the repo is)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
SOURCE_DIR="$REPO_DIR/claude"
VERSION_FILE="$TARGET_DIR/.deploy-version"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --global)
            TARGET_DIR="$HOME/.claude"
            VERSION_FILE="$TARGET_DIR/.deploy-version"
            shift
            ;;
        --project)
            TARGET_DIR="$2/.claude"
            VERSION_FILE="$TARGET_DIR/.deploy-version"
            shift 2
            ;;
        --symlink)
            MODE="symlink"
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --uninstall)
            UNINSTALL=true
            shift
            ;;
        --download)
            DOWNLOAD=true
            shift
            ;;
        --agents-type)
            AGENTS_TYPE="$2"
            if [[ ! "$AGENTS_TYPE" =~ ^(regular|optimized|both)$ ]]; then
                echo -e "${RED}Invalid agents type: $AGENTS_TYPE${NC}"
                echo -e "${YELLOW}Valid options: regular, optimized, both${NC}"
                exit 1
            fi
            shift 2
            ;;
        --help)
            cat << 'HELP'
deploy-claude.sh - Deploy Claude plugins to user's system

IMPORTANT: Run this script from a regular terminal, NOT from within Claude Code,
           due to sandbox restrictions on writing to ~/.claude/

Usage:
  ./scripts/deploy-claude.sh [OPTIONS]

Remote Installation (no git clone required):
  curl -fsSL https://raw.githubusercontent.com/ArangoGutierrez/promptsLibrary/main/scripts/deploy-claude.sh | bash -s -- --download
  wget -qO- https://raw.githubusercontent.com/ArangoGutierrez/promptsLibrary/main/scripts/deploy-claude.sh | bash -s -- --download

Options:
  --global             Deploy to ~/.claude/ (default)
  --project <path>     Deploy to <path>/.claude/
  --symlink            Use symlinks instead of copying files
  --force              Overwrite existing files
  --dry-run            Show what would be done
  --uninstall          Remove deployed files
  --download           Download files from GitHub (no git clone needed)
  --agents-type <type> Deploy regular, optimized, or both agents (default: regular)
  --help               Show this help message

Environment Variables:
  CLAUDE_DEV_REPO   Override the GitHub repo (default: ArangoGutierrez/promptsLibrary)
  CLAUDE_DEV_BRANCH Override the branch (default: main)

Examples:
  # Remote installation (one-liner, no clone needed)
  curl -fsSL https://raw.githubusercontent.com/ArangoGutierrez/promptsLibrary/main/scripts/deploy-claude.sh | bash -s -- --download

  # Local deployment (after git clone)
  ./scripts/deploy-claude.sh                           # Deploy globally (regular agents only)
  ./scripts/deploy-claude.sh --agents-type optimized   # Deploy optimized agents only
  ./scripts/deploy-claude.sh --agents-type both        # Deploy both regular and optimized
  ./scripts/deploy-claude.sh --dry-run                 # Preview what would be done
  ./scripts/deploy-claude.sh --symlink                 # Use symlinks (auto-update)
  ./scripts/deploy-claude.sh --force                   # Overwrite existing files
  ./scripts/deploy-claude.sh --project ./myapp         # Deploy to specific project
  ./scripts/deploy-claude.sh --uninstall               # Remove deployed files
HELP
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Detect OS
detect_os() {
    case "$(uname -s)" in
        Darwin*)
            echo "macos"
            ;;
        Linux*)
            echo "linux"
            ;;
        *)
            echo -e "${RED}Unsupported OS: $(uname -s)${NC}"
            exit 1
            ;;
    esac
}

# Cleanup function for download mode
cleanup_download() {
    if [ -n "$TEMP_DOWNLOAD_DIR" ] && [ -d "$TEMP_DOWNLOAD_DIR" ]; then
        rm -rf "$TEMP_DOWNLOAD_DIR"
    fi
}

# Download a single file from GitHub
download_file() {
    local path="$1"
    local dest="$2"
    local url="${GITHUB_RAW_BASE}/${path}"

    mkdir -p "$(dirname "$dest")"

    if command -v curl &> /dev/null; then
        curl -fsSL "$url" -o "$dest" 2>/dev/null
    elif command -v wget &> /dev/null; then
        wget -q "$url" -O "$dest" 2>/dev/null
    else
        echo -e "${RED}Error: curl or wget required for download mode${NC}"
        exit 1
    fi
}

# Download files from GitHub for remote installation
setup_download_mode() {
    echo -e "${BLUE}=== Remote Installation Mode ===${NC}"
    echo -e "${CYAN}Downloading from: ${GITHUB_REPO} (${GITHUB_BRANCH})${NC}"
    echo ""

    # Create temp directory
    TEMP_DOWNLOAD_DIR=$(mktemp -d)
    trap cleanup_download EXIT

    # Create directory structure
    mkdir -p "$TEMP_DOWNLOAD_DIR/claude/code-simplifier"/{.claude-plugin,agents}
    mkdir -p "$TEMP_DOWNLOAD_DIR/claude/ralph-loop"/{.claude-plugin,commands,hooks,scripts}
    mkdir -p "$TEMP_DOWNLOAD_DIR/claude/code-review"/{.claude-plugin,commands}
    mkdir -p "$TEMP_DOWNLOAD_DIR/claude/agents"
    mkdir -p "$TEMP_DOWNLOAD_DIR/claude/hooks"
    mkdir -p "$TEMP_DOWNLOAD_DIR/claude/rules"
    mkdir -p "$TEMP_DOWNLOAD_DIR/claude/output-styles"

    # Download agents (all .md files from flat structure)
    echo -e "${BLUE}Downloading agents (type: ${AGENTS_TYPE})...${NC}"

    # Build agent list based on AGENTS_TYPE
    local agents=()
    case "$AGENTS_TYPE" in
        regular)
            agents=(
                "api-reviewer" "arch-explorer" "auditor" "code-simplifier"
                "devil-advocate" "documenter" "perf-critic" "prototyper"
                "researcher" "synthesizer" "task-analyzer" "test-generator"
                "verifier"
            )
            ;;
        optimized)
            agents=(
                "api-reviewer-opt" "arch-explorer-opt" "auditor-opt"
                "devil-advocate-opt" "perf-critic-opt" "prototyper-opt"
                "researcher-opt" "synthesizer-opt" "task-analyzer-opt"
                "verifier-opt"
            )
            ;;
        both)
            agents=(
                "api-reviewer" "api-reviewer-opt"
                "arch-explorer" "arch-explorer-opt"
                "auditor" "auditor-opt"
                "code-simplifier"
                "devil-advocate" "devil-advocate-opt"
                "documenter"
                "perf-critic" "perf-critic-opt"
                "prototyper" "prototyper-opt"
                "researcher" "researcher-opt"
                "synthesizer" "synthesizer-opt"
                "task-analyzer" "task-analyzer-opt"
                "test-generator"
                "verifier" "verifier-opt"
            )
            ;;
    esac

    for agent in "${agents[@]}"; do
        echo -ne "  agents/${agent}.md... "
        if download_file "claude/agents/${agent}.md" "$TEMP_DOWNLOAD_DIR/claude/agents/${agent}.md"; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${YELLOW}skipped${NC}"
        fi
    done

    echo -ne "  agents/README.md... "
    if download_file "claude/agents/README.md" "$TEMP_DOWNLOAD_DIR/claude/agents/README.md"; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${YELLOW}skipped${NC}"
    fi

    echo ""

    # Download skills (flattened from custom-skills + converted commands)
    echo -e "${BLUE}Downloading skills...${NC}"

    local skills=(
        "architect" "audit" "cancel-ralph" "code" "code-review" "context-reset"
        "debug" "docs" "git-polish" "issue" "parallel" "quality" "ralph-help"
        "ralph-loop" "refactor" "research" "self-review" "task" "test"
    )
    for skill in "${skills[@]}"; do
        echo -ne "  skills/${skill}.md... "
        if download_file "claude/skills/${skill}.md" "$TEMP_DOWNLOAD_DIR/claude/skills/${skill}.md"; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${YELLOW}skipped${NC}"
        fi
    done

    echo -ne "  skills/README.md... "
    if download_file "claude/skills/README.md" "$TEMP_DOWNLOAD_DIR/claude/skills/README.md"; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${YELLOW}skipped${NC}"
    fi

    echo ""

    # Download hooks
    echo -e "${BLUE}Downloading hooks...${NC}"

    local hooks=("format.sh" "sign-commits.sh" "go-lint.sh" "go-test-package.sh" "go-vuln-check.sh")
    for hook in "${hooks[@]}"; do
        echo -ne "  hooks/${hook}... "
        if download_file "claude/hooks/${hook}" "$TEMP_DOWNLOAD_DIR/claude/hooks/${hook}"; then
            echo -e "${GREEN}✓${NC}"
            chmod +x "$TEMP_DOWNLOAD_DIR/claude/hooks/${hook}" 2>/dev/null || true
        else
            echo -e "${YELLOW}skipped${NC}"
        fi
    done

    echo -ne "  hooks/README.md... "
    if download_file "claude/hooks/README.md" "$TEMP_DOWNLOAD_DIR/claude/hooks/README.md"; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${YELLOW}skipped${NC}"
    fi

    echo ""

    # Download CLAUDE.md
    echo -e "${BLUE}Downloading CLAUDE.md...${NC}"
    echo -ne "  CLAUDE.md... "
    if download_file "claude/CLAUDE.md" "$TEMP_DOWNLOAD_DIR/claude/CLAUDE.md"; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${YELLOW}skipped${NC}"
    fi

    echo ""

    # Download rules
    echo -e "${BLUE}Downloading rules...${NC}"
    mkdir -p "$TEMP_DOWNLOAD_DIR/claude/rules"
    local rules=("security" "go-style" "quality-gate")
    for rule in "${rules[@]}"; do
        echo -ne "  rules/${rule}.md... "
        if download_file "claude/rules/${rule}.md" "$TEMP_DOWNLOAD_DIR/claude/rules/${rule}.md"; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${YELLOW}skipped${NC}"
        fi
    done

    echo ""

    # Download output-styles
    echo -e "${BLUE}Downloading output-styles...${NC}"
    mkdir -p "$TEMP_DOWNLOAD_DIR/claude/output-styles"
    echo -ne "  output-styles/engineering-style.md... "
    if download_file "claude/output-styles/engineering-style.md" "$TEMP_DOWNLOAD_DIR/claude/output-styles/engineering-style.md"; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${YELLOW}skipped${NC}"
    fi

    echo ""

    # Download settings.json
    echo -e "${BLUE}Downloading settings.json...${NC}"
    echo -ne "  settings.json... "
    if download_file "claude/settings.json" "$TEMP_DOWNLOAD_DIR/claude/settings.json"; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${YELLOW}skipped${NC}"
    fi

    echo ""

    # Update paths to use temp directory
    REPO_DIR="$TEMP_DOWNLOAD_DIR"
    SOURCE_DIR="$TEMP_DOWNLOAD_DIR/claude"
}

# Get current repo version (git commit hash + date)
get_repo_version() {
    if [ "$DOWNLOAD" = true ]; then
        local date=$(date +%Y-%m-%d)
        echo "download|$date|${GITHUB_BRANCH}"
        return
    fi
    cd "$REPO_DIR"
    local hash=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    local date=$(git log -1 --format=%ci 2>/dev/null | cut -d' ' -f1 || echo "unknown")
    local branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    echo "$hash|$date|$branch"
}

# Save deployed version
save_deployed_version() {
    local version="$1"
    if [ "$DRY_RUN" = false ]; then
        mkdir -p "$(dirname "$VERSION_FILE")"
        echo "$version" > "$VERSION_FILE"
    fi
}

OS=$(detect_os)

# Handle download mode first
if [ "$DOWNLOAD" = true ]; then
    setup_download_mode
fi

echo -e "${BLUE}Detected OS: $OS${NC}"
echo -e "${BLUE}Source: $SOURCE_DIR${NC}"
echo -e "${BLUE}Target: $TARGET_DIR${NC}"
echo -e "${BLUE}Mode: $MODE${NC}"
echo ""

# Verify source exists
if [ ! -d "$SOURCE_DIR" ]; then
    echo -e "${RED}Error: Source directory not found: $SOURCE_DIR${NC}"
    if [ "$DOWNLOAD" = false ]; then
        echo "Make sure you're running from the repository root, or use --download for remote installation."
        echo ""
        echo "Remote installation:"
        echo "  curl -fsSL https://raw.githubusercontent.com/${GITHUB_REPO}/${GITHUB_BRANCH}/scripts/deploy-claude.sh | bash -s -- --download"
    fi
    exit 1
fi

# Create target directory if needed
create_target_dir() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        if [ "$DRY_RUN" = true ]; then
            echo -e "${YELLOW}[DRY-RUN] Would create: $dir${NC}"
        else
            mkdir -p "$dir"
            echo -e "${GREEN}Created: $dir${NC}"
        fi
    fi
}

# Deploy a plugin directory
deploy_plugin() {
    local plugin_name="$1"
    local src_dir="$SOURCE_DIR/$plugin_name"
    local dst_dir="$TARGET_DIR/plugins/$plugin_name"

    if [ ! -d "$src_dir" ]; then
        echo -e "${YELLOW}Plugin not found: $plugin_name${NC}"
        return 1
    fi

    # Check if destination exists
    if [ -e "$dst_dir" ] || [ -L "$dst_dir" ]; then
        if [ "$FORCE" = true ]; then
            if [ "$DRY_RUN" = true ]; then
                echo -e "${YELLOW}[DRY-RUN] Would remove: $dst_dir${NC}"
            else
                # Move existing plugin to backup location (avoids using rm)
                local backup_dir="$dst_dir.old-$(date +%Y%m%d-%H%M%S)"
                mv "$dst_dir" "$backup_dir"
                echo -e "${YELLOW}Moved old plugin to: $backup_dir${NC}"
            fi
        else
            if [ -L "$dst_dir" ] && [ "$(readlink "$dst_dir")" = "$src_dir" ]; then
                echo -e "${BLUE}Already linked: $dst_dir${NC}"
                return 0
            fi
            echo -e "${YELLOW}Skipping plugin (exists): $plugin_name${NC}"
            echo -e "${YELLOW}  Use --force to overwrite${NC}"
            return 0
        fi
    fi

    # Create plugins directory
    create_target_dir "$TARGET_DIR/plugins"

    # Deploy the plugin
    if [ "$DRY_RUN" = true ]; then
        if [ "$MODE" = "symlink" ]; then
            echo -e "${YELLOW}[DRY-RUN] Would symlink plugin: $dst_dir -> $src_dir${NC}"
        else
            echo -e "${YELLOW}[DRY-RUN] Would copy plugin: $src_dir -> $dst_dir${NC}"
        fi
    else
        if [ "$MODE" = "symlink" ]; then
            ln -s "$src_dir" "$dst_dir"
            echo -e "${GREEN}Linked plugin: $plugin_name${NC}"
        else
            cp -r "$src_dir" "$dst_dir"
            echo -e "${GREEN}Copied plugin: $plugin_name${NC}"
        fi
    fi
}

# Deploy settings.json
deploy_settings() {
    local src_file="$SOURCE_DIR/settings.json"
    local dst_file="$TARGET_DIR/settings.json"

    if [ ! -f "$src_file" ]; then
        echo -e "${YELLOW}settings.json not found in source${NC}"
        return 0
    fi

    # Check if destination exists (file or symlink)
    if [ -e "$dst_file" ] || [ -L "$dst_file" ]; then
        if [ "$FORCE" = true ]; then
            if [ "$DRY_RUN" = true ]; then
                echo -e "${YELLOW}[DRY-RUN] Would backup and replace: $dst_file${NC}"
            else
                # Move existing file/symlink to backup (avoids using rm)
                local backup_file="$dst_file.backup-$(date +%Y%m%d-%H%M%S)"
                mv "$dst_file" "$backup_file"
                echo -e "${YELLOW}Backed up existing settings: $backup_file${NC}"

                if [ "$MODE" = "symlink" ]; then
                    ln -s "$src_file" "$dst_file"
                    echo -e "${GREEN}Linked settings: $dst_file${NC}"
                else
                    cp "$src_file" "$dst_file"
                    echo -e "${GREEN}Replaced settings: $dst_file${NC}"
                fi
            fi
        else
            if [ -L "$dst_file" ]; then
                echo -e "${YELLOW}settings.json is a symlink. Use --force to replace with a copy (will backup).${NC}"
            else
                echo -e "${YELLOW}settings.json already exists. Use --force to replace (will backup).${NC}"
            fi
            return 0
        fi
    else
        # No existing file, deploy new one
        if [ "$DRY_RUN" = true ]; then
            if [ "$MODE" = "symlink" ]; then
                echo -e "${YELLOW}[DRY-RUN] Would symlink: $dst_file -> $src_file${NC}"
            else
                echo -e "${YELLOW}[DRY-RUN] Would copy: $src_file -> $dst_file${NC}"
            fi
        else
            if [ "$MODE" = "symlink" ]; then
                ln -s "$src_file" "$dst_file"
                echo -e "${GREEN}Linked settings: $dst_file${NC}"
            else
                cp "$src_file" "$dst_file"
                echo -e "${GREEN}Copied settings: $dst_file${NC}"
            fi
        fi
    fi
}

# Deploy agents directory
deploy_agents() {
    local src_dir="$SOURCE_DIR/agents"
    local dst_dir="$TARGET_DIR/agents"

    if [ ! -d "$src_dir" ]; then
        echo -e "${YELLOW}Agents directory not found in source${NC}"
        return 0
    fi

    # Check if destination exists
    if [ -e "$dst_dir" ] || [ -L "$dst_dir" ]; then
        if [ "$FORCE" = true ]; then
            if [ "$DRY_RUN" = true ]; then
                echo -e "${YELLOW}[DRY-RUN] Would remove: $dst_dir${NC}"
            else
                # Move existing directory to backup
                local backup_dir="$dst_dir.old-$(date +%Y%m%d-%H%M%S)"
                mv "$dst_dir" "$backup_dir"
                echo -e "${YELLOW}Moved old agents to: $backup_dir${NC}"
            fi
        else
            if [ -L "$dst_dir" ] && [ "$(readlink "$dst_dir")" = "$src_dir" ]; then
                echo -e "${BLUE}Already linked: $dst_dir${NC}"
                return 0
            fi
            echo -e "${YELLOW}Skipping agents (exists). Use --force to overwrite${NC}"
            return 0
        fi
    fi

    # Create target directory
    create_target_dir "$TARGET_DIR"

    # Deploy the agents directory
    if [ "$DRY_RUN" = true ]; then
        if [ "$MODE" = "symlink" ]; then
            echo -e "${YELLOW}[DRY-RUN] Would symlink agents: $dst_dir -> $src_dir${NC}"
        else
            echo -e "${YELLOW}[DRY-RUN] Would copy agents: $src_dir -> $dst_dir${NC}"
        fi
    else
        if [ "$MODE" = "symlink" ]; then
            ln -s "$src_dir" "$dst_dir"
            echo -e "${GREEN}Linked agents directory${NC}"
        else
            cp -r "$src_dir" "$dst_dir"
            echo -e "${GREEN}Copied agents directory${NC}"
        fi
    fi

    # Count agents deployed
    if [ -d "$src_dir" ]; then
        local agent_count=$(find "$src_dir" -name "*.md" -type f | wc -l | tr -d ' ')
        echo -e "${CYAN}  Deployed $agent_count agents${NC}"
    fi
}

# Deploy skills directory
deploy_skills() {
    local src_dir="$SOURCE_DIR/skills"
    local dst_dir="$TARGET_DIR/skills"

    if [ ! -d "$src_dir" ]; then
        echo -e "${YELLOW}Skills directory not found in source${NC}"
        return 0
    fi

    # Check if destination exists
    if [ -e "$dst_dir" ] || [ -L "$dst_dir" ]; then
        if [ "$FORCE" = true ]; then
            if [ "$DRY_RUN" = true ]; then
                echo -e "${YELLOW}[DRY-RUN] Would remove: $dst_dir${NC}"
            else
                # Move existing directory to backup
                local backup_dir="$dst_dir.old-$(date +%Y%m%d-%H%M%S)"
                mv "$dst_dir" "$backup_dir"
                echo -e "${YELLOW}Moved old skills to: $backup_dir${NC}"
            fi
        else
            if [ -L "$dst_dir" ] && [ "$(readlink "$dst_dir")" = "$src_dir" ]; then
                echo -e "${BLUE}Already linked: $dst_dir${NC}"
                return 0
            fi
            echo -e "${YELLOW}Skipping skills (exists). Use --force to overwrite${NC}"
            return 0
        fi
    fi

    # Create target directory
    create_target_dir "$TARGET_DIR"

    # Deploy the skills directory
    if [ "$DRY_RUN" = true ]; then
        if [ "$MODE" = "symlink" ]; then
            echo -e "${YELLOW}[DRY-RUN] Would symlink skills: $dst_dir -> $src_dir${NC}"
        else
            echo -e "${YELLOW}[DRY-RUN] Would copy skills: $src_dir -> $dst_dir${NC}"
        fi
    else
        if [ "$MODE" = "symlink" ]; then
            ln -s "$src_dir" "$dst_dir"
            echo -e "${GREEN}Linked skills directory${NC}"
        else
            cp -r "$src_dir" "$dst_dir"
            echo -e "${GREEN}Copied skills directory${NC}"
        fi
    fi

    # Count skills deployed
    if [ -d "$src_dir" ]; then
        local skill_count=$(find "$src_dir" -name "*.md" -type f ! -name "README.md" | wc -l | tr -d ' ')
        echo -e "${CYAN}  Deployed $skill_count skills${NC}"
    fi
}

# Deploy hooks directory
deploy_hooks() {
    local src_dir="$SOURCE_DIR/hooks"
    local dst_dir="$TARGET_DIR/hooks"

    if [ ! -d "$src_dir" ]; then
        echo -e "${YELLOW}Hooks directory not found in source${NC}"
        return 0
    fi

    # Check if destination exists
    if [ -e "$dst_dir" ] || [ -L "$dst_dir" ]; then
        if [ "$FORCE" = true ]; then
            if [ "$DRY_RUN" = true ]; then
                echo -e "${YELLOW}[DRY-RUN] Would remove: $dst_dir${NC}"
            else
                # Move existing directory to backup
                local backup_dir="$dst_dir.old-$(date +%Y%m%d-%H%M%S)"
                mv "$dst_dir" "$backup_dir"
                echo -e "${YELLOW}Moved old hooks to: $backup_dir${NC}"
            fi
        else
            if [ -L "$dst_dir" ] && [ "$(readlink "$dst_dir")" = "$src_dir" ]; then
                echo -e "${BLUE}Already linked: $dst_dir${NC}"
                return 0
            fi
            echo -e "${YELLOW}Skipping hooks (exists). Use --force to overwrite${NC}"
            return 0
        fi
    fi

    # Create target directory
    create_target_dir "$TARGET_DIR"

    # Deploy the hooks directory
    if [ "$DRY_RUN" = true ]; then
        if [ "$MODE" = "symlink" ]; then
            echo -e "${YELLOW}[DRY-RUN] Would symlink hooks: $dst_dir -> $src_dir${NC}"
        else
            echo -e "${YELLOW}[DRY-RUN] Would copy hooks: $src_dir -> $dst_dir${NC}"
        fi
    else
        if [ "$MODE" = "symlink" ]; then
            ln -s "$src_dir" "$dst_dir"
            echo -e "${GREEN}Linked hooks directory${NC}"
        else
            cp -r "$src_dir" "$dst_dir"
            echo -e "${GREEN}Copied hooks directory${NC}"
            # Make hooks executable
            chmod +x "$dst_dir"/*.sh 2>/dev/null || true
        fi
    fi

    # Count hooks deployed
    if [ -d "$src_dir" ]; then
        local hook_count=$(find "$src_dir" -name "*.sh" -type f | wc -l | tr -d ' ')
        echo -e "${CYAN}  Deployed $hook_count hooks${NC}"
    fi
}

# Deploy CLAUDE.md
deploy_claude_md() {
    local src_file="$SOURCE_DIR/CLAUDE.md"
    local dst_file="$TARGET_DIR/CLAUDE.md"

    if [ ! -f "$src_file" ]; then
        echo -e "${YELLOW}CLAUDE.md not found in source${NC}"
        return 0
    fi

    # Check if destination exists
    if [ -e "$dst_file" ] || [ -L "$dst_file" ]; then
        if [ "$FORCE" = true ]; then
            if [ "$DRY_RUN" = true ]; then
                echo -e "${YELLOW}[DRY-RUN] Would backup and replace: $dst_file${NC}"
            else
                # Move existing file/symlink to backup
                local backup_file="$dst_file.backup-$(date +%Y%m%d-%H%M%S)"
                mv "$dst_file" "$backup_file"
                echo -e "${YELLOW}Backed up existing CLAUDE.md: $backup_file${NC}"

                if [ "$MODE" = "symlink" ]; then
                    ln -s "$src_file" "$dst_file"
                    echo -e "${GREEN}Linked CLAUDE.md${NC}"
                else
                    cp "$src_file" "$dst_file"
                    echo -e "${GREEN}Replaced CLAUDE.md${NC}"
                fi
            fi
        else
            if [ -L "$dst_file" ]; then
                echo -e "${YELLOW}CLAUDE.md is a symlink. Use --force to replace (will backup).${NC}"
            else
                echo -e "${YELLOW}CLAUDE.md already exists. Use --force to replace (will backup).${NC}"
            fi
            return 0
        fi
    else
        # No existing file, deploy new one
        if [ "$DRY_RUN" = true ]; then
            if [ "$MODE" = "symlink" ]; then
                echo -e "${YELLOW}[DRY-RUN] Would symlink: $dst_file -> $src_file${NC}"
            else
                echo -e "${YELLOW}[DRY-RUN] Would copy: $src_file -> $dst_file${NC}"
            fi
        else
            if [ "$MODE" = "symlink" ]; then
                ln -s "$src_file" "$dst_file"
                echo -e "${GREEN}Linked CLAUDE.md${NC}"
            else
                cp "$src_file" "$dst_file"
                echo -e "${GREEN}Copied CLAUDE.md${NC}"
            fi
        fi
    fi
}

# Deploy rules directory
deploy_rules() {
    local src_dir="$SOURCE_DIR/rules"
    local dst_dir="$TARGET_DIR/rules"

    if [ ! -d "$src_dir" ]; then
        echo -e "${YELLOW}Rules directory not found in source${NC}"
        return 0
    fi

    # Check if destination exists
    if [ -e "$dst_dir" ] || [ -L "$dst_dir" ]; then
        if [ "$FORCE" = true ]; then
            if [ "$DRY_RUN" = true ]; then
                echo -e "${YELLOW}[DRY-RUN] Would remove: $dst_dir${NC}"
            else
                # Move existing directory to backup
                local backup_dir="$dst_dir.old-$(date +%Y%m%d-%H%M%S)"
                mv "$dst_dir" "$backup_dir"
                echo -e "${YELLOW}Moved old rules to: $backup_dir${NC}"
            fi
        else
            if [ -L "$dst_dir" ] && [ "$(readlink "$dst_dir")" = "$src_dir" ]; then
                echo -e "${BLUE}Already linked: $dst_dir${NC}"
                return 0
            fi
            echo -e "${YELLOW}Skipping rules (exists). Use --force to overwrite${NC}"
            return 0
        fi
    fi

    # Create target directory
    create_target_dir "$TARGET_DIR"

    # Deploy the rules directory
    if [ "$DRY_RUN" = true ]; then
        if [ "$MODE" = "symlink" ]; then
            echo -e "${YELLOW}[DRY-RUN] Would symlink rules: $dst_dir -> $src_dir${NC}"
        else
            echo -e "${YELLOW}[DRY-RUN] Would copy rules: $src_dir -> $dst_dir${NC}"
        fi
    else
        if [ "$MODE" = "symlink" ]; then
            ln -s "$src_dir" "$dst_dir"
            echo -e "${GREEN}Linked rules directory${NC}"
        else
            cp -r "$src_dir" "$dst_dir"
            echo -e "${GREEN}Copied rules directory${NC}"
        fi
    fi

    # Count rules deployed
    if [ -d "$src_dir" ]; then
        local rule_count=$(find "$src_dir" -name "*.md" -type f | wc -l | tr -d ' ')
        echo -e "${CYAN}  Deployed $rule_count rules${NC}"
    fi
}

# Deploy output-styles directory
deploy_output_styles() {
    local src_dir="$SOURCE_DIR/output-styles"
    local dst_dir="$TARGET_DIR/output-styles"

    if [ ! -d "$src_dir" ]; then
        echo -e "${YELLOW}Output styles directory not found in source${NC}"
        return 0
    fi

    # Check if destination exists
    if [ -e "$dst_dir" ] || [ -L "$dst_dir" ]; then
        if [ "$FORCE" = true ]; then
            if [ "$DRY_RUN" = true ]; then
                echo -e "${YELLOW}[DRY-RUN] Would remove: $dst_dir${NC}"
            else
                # Move existing directory to backup
                local backup_dir="$dst_dir.old-$(date +%Y%m%d-%H%M%S)"
                mv "$dst_dir" "$backup_dir"
                echo -e "${YELLOW}Moved old output-styles to: $backup_dir${NC}"
            fi
        else
            if [ -L "$dst_dir" ] && [ "$(readlink "$dst_dir")" = "$src_dir" ]; then
                echo -e "${BLUE}Already linked: $dst_dir${NC}"
                return 0
            fi
            echo -e "${YELLOW}Skipping output-styles (exists). Use --force to overwrite${NC}"
            return 0
        fi
    fi

    # Create target directory
    create_target_dir "$TARGET_DIR"

    # Deploy the output-styles directory
    if [ "$DRY_RUN" = true ]; then
        if [ "$MODE" = "symlink" ]; then
            echo -e "${YELLOW}[DRY-RUN] Would symlink output-styles: $dst_dir -> $src_dir${NC}"
        else
            echo -e "${YELLOW}[DRY-RUN] Would copy output-styles: $src_dir -> $dst_dir${NC}"
        fi
    else
        if [ "$MODE" = "symlink" ]; then
            ln -s "$src_dir" "$dst_dir"
            echo -e "${GREEN}Linked output-styles directory${NC}"
        else
            cp -r "$src_dir" "$dst_dir"
            echo -e "${GREEN}Copied output-styles directory${NC}"
        fi
    fi

    # Count output styles deployed
    if [ -d "$src_dir" ]; then
        local style_count=$(find "$src_dir" -name "*.md" -type f | wc -l | tr -d ' ')
        echo -e "${CYAN}  Deployed $style_count output styles${NC}"
    fi
}

# Uninstall deployed plugins
uninstall() {
    echo -e "${YELLOW}Uninstalling from: $TARGET_DIR${NC}"

    local plugins_dir="$TARGET_DIR/plugins"
    local uninstall_dir="$TARGET_DIR/uninstalled-$(date +%Y%m%d-%H%M%S)"

    if [ -d "$plugins_dir" ]; then
        for plugin in "$plugins_dir"/*; do
            if [ -e "$plugin" ] || [ -L "$plugin" ]; then
                local plugin_name="$(basename "$plugin")"
                if [ "$DRY_RUN" = true ]; then
                    echo -e "${YELLOW}[DRY-RUN] Would remove: $plugin${NC}"
                else
                    # Move to uninstall directory instead of rm
                    mkdir -p "$uninstall_dir"
                    mv "$plugin" "$uninstall_dir/"
                    echo -e "${GREEN}Removed: $plugin_name${NC}"
                fi
            fi
        done
        if [ "$DRY_RUN" = false ] && [ -d "$uninstall_dir" ]; then
            echo -e "${YELLOW}Moved plugins to: $uninstall_dir${NC}"
        fi
    fi

    # Handle settings.json
    local settings_file="$TARGET_DIR/settings.json"
    if [ -L "$settings_file" ] || [ -f "$settings_file" ]; then
        if [ "$DRY_RUN" = true ]; then
            echo -e "${YELLOW}[DRY-RUN] Would remove: $settings_file${NC}"
        else
            # Check for backup files
            local has_backup=false
            for backup in "$TARGET_DIR"/settings.json.backup-*; do
                if [ -f "$backup" ]; then
                    has_backup=true
                    break
                fi
            done

            if [ "$has_backup" = true ]; then
                echo -e "${YELLOW}Keeping settings.json (backups exist). Remove manually if needed.${NC}"
            else
                mkdir -p "$uninstall_dir"
                mv "$settings_file" "$uninstall_dir/"
                echo -e "${GREEN}Removed: settings.json${NC}"
            fi
        fi
    fi

    echo -e "${GREEN}Uninstall complete${NC}"
}

# Main deployment
deploy() {
    echo -e "${BLUE}=== Deploying Claude Configuration ===${NC}"
    echo ""

    # Deploy agents directory
    echo -e "${BLUE}Deploying agents...${NC}"
    deploy_agents
    echo ""

    # Deploy skills directory
    echo -e "${BLUE}Deploying skills...${NC}"
    deploy_skills
    echo ""

    # Deploy hooks directory
    echo -e "${BLUE}Deploying hooks...${NC}"
    deploy_hooks
    echo ""

    # Deploy CLAUDE.md
    echo -e "${BLUE}Deploying CLAUDE.md...${NC}"
    deploy_claude_md
    echo ""

    # Deploy rules directory
    echo -e "${BLUE}Deploying rules...${NC}"
    deploy_rules
    echo ""

    # Deploy output-styles directory
    echo -e "${BLUE}Deploying output-styles...${NC}"
    deploy_output_styles
    echo ""

    # Deploy settings.json
    echo -e "${BLUE}Deploying settings.json...${NC}"
    deploy_settings
    echo ""

    # Save version info
    local version=$(get_repo_version)
    save_deployed_version "$version"

    echo -e "${GREEN}=== Deployment Complete ===${NC}"
    echo ""
    echo -e "${BLUE}Deployed to: $TARGET_DIR${NC}"
    echo -e "${BLUE}Version: $(echo "$version" | cut -d'|' -f1) ($(echo "$version" | cut -d'|' -f2))${NC}"
    echo ""

    # Count agents based on type
    local agent_desc=""
    case "$AGENTS_TYPE" in
        regular)
            agent_desc="agents (13 regular) - Specialized analysis agents"
            ;;
        optimized)
            agent_desc="agents (11 optimized) - Specialized analysis agents (optimized versions)"
            ;;
        both)
            agent_desc="agents (24 total: 13 regular + 11 optimized) - Specialized analysis agents"
            ;;
    esac

    echo -e "${YELLOW}Installed Components:${NC}"
    echo "  • $agent_desc"
    echo "  • skills (19 skills) - Workflow orchestration and commands (architect, audit, code-review, etc.)"
    echo "  • hooks (11 files) - Lifecycle hooks (format, sign-commits, go-lint, etc.)"
    echo "  • rules (3 files) - Modular rules (security, go-style, quality-gate)"
    echo "  • output-styles (1 file) - Custom communication styles (engineering-style)"
    echo "  • CLAUDE.md - Global project context and engineering standards"
    echo "  • settings.json - Secure bash permissions configuration"
    echo ""

    local agent_dir_desc=""
    case "$AGENTS_TYPE" in
        regular)
            agent_dir_desc="(13 regular agents)"
            ;;
        optimized)
            agent_dir_desc="(11 optimized agents)"
            ;;
        both)
            agent_dir_desc="(13 regular + 11 optimized agents)"
            ;;
    esac

    echo -e "${YELLOW}Directory Structure:${NC}"
    echo "  ~/.claude/"
    echo "    ├── agents/          $agent_dir_desc"
    echo "    ├── skills/          (19 workflow orchestration skills)"
    echo "    ├── hooks/           (11 lifecycle hooks)"
    echo "    ├── rules/           (3 modular rules)"
    echo "    ├── output-styles/   (1 custom style)"
    echo "    ├── CLAUDE.md        (project context)"
    echo "    └── settings.json    (bash permissions)"
    echo ""
    echo -e "${YELLOW}Key Agents:${NC}"
    echo "  Research: researcher, task-analyzer"
    echo "  Security: auditor, perf-critic, api-reviewer"
    echo "  Architecture: arch-explorer, devil-advocate, prototyper, synthesizer"
    echo "  Implementation: test-generator, documenter, code-simplifier"
    echo "  Validation: verifier"
    echo ""
    echo -e "${YELLOW}Popular Skills:${NC}"
    echo "  /architect - Architecture exploration with prototypes"
    echo "  /audit - Security and reliability auditing"
    echo "  /code - Execute next TODO from AGENTS.md"
    echo "  /code-review - Comprehensive PR/code review"
    echo "  /debug - Systematic debugging workflow"
    echo "  /quality - Multi-agent code review"
    echo "  /ralph-loop - Iterative development loop"
    echo "  /task - Structured task execution (5-phase)"
    echo ""
    echo -e "${YELLOW}Next Steps:${NC}"
    echo "  1. Use agents via Task tool: 'Use the Task tool with auditor agent to review...'"
    echo "  2. Run skills: '/architect \"add caching\"' or '/code-review #123'"
    echo "  3. CLAUDE.md is loaded automatically in every session"
    echo "  4. Hooks run automatically on file edits and shell commands"
    echo "  5. Activate output style: /output-style → select 'Engineering Style'"
    echo ""
    echo -e "${CYAN}Documentation:${NC}"
    echo "  • Agents: $TARGET_DIR/agents/README.md"
    echo "  • Skills: $TARGET_DIR/skills/README.md"
    echo "  • Hooks: $TARGET_DIR/hooks/README.md"
    echo ""
    if [ "$MODE" = "symlink" ]; then
        echo -e "${BLUE}Note: Plugins are symlinked. Pull repo updates and they auto-propagate.${NC}"
    else
        echo -e "${CYAN}Note: Plugins are copied. Re-run script to update to new versions.${NC}"
    fi
}

# Run
if [ "$UNINSTALL" = true ]; then
    uninstall
else
    deploy
fi

#!/bin/bash
#
# deploy-cursor.sh - Deploy Cursor configurations to user's system
#
# Usage:
#   ./scripts/deploy-cursor.sh [OPTIONS]
#
# Options:
#   --global          Deploy to ~/.cursor/ (default)
#   --project <path>  Deploy to <path>/.cursor/
#   --copy            Copy files instead of symlink
#   --force           Overwrite existing files
#   --dry-run         Show what would be done
#   --uninstall       Remove deployed symlinks/files
#   --update          Smart update: pull latest, show changes, deploy
#   --check           Check for updates without deploying
#   --optimized       Deploy token-optimized versions (smaller context footprint)
#   --backup          Create backup before deploying
#   --restore         Restore from latest backup
#   --help            Show this help message
#
# Remote Installation (no git clone required):
#   curl -fsSL https://raw.githubusercontent.com/ArangoGutierrez/promptsLibrary/main/scripts/deploy-cursor.sh | bash -s -- --download
#   # or with wget:
#   wget -qO- https://raw.githubusercontent.com/ArangoGutierrez/promptsLibrary/main/scripts/deploy-cursor.sh | bash -s -- --download
#
# Environment Variables:
#   CURSOR_DEV_REPO   Override the GitHub repo (default: ArangoGutierrez/promptsLibrary)
#   CURSOR_DEV_BRANCH Override the branch (default: main)
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
TARGET_DIR="$HOME/.cursor"
MODE="symlink"
FORCE=false
DRY_RUN=false
UNINSTALL=false
UPDATE=false
CHECK_ONLY=false
OPTIMIZED=false
LAZY=false
BACKUP=false
RESTORE=false
STATUS=false
DOWNLOAD=false

# GitHub repo settings (can be overridden with environment variables)
GITHUB_REPO="${CURSOR_DEV_REPO:-ArangoGutierrez/promptsLibrary}"
GITHUB_BRANCH="${CURSOR_DEV_BRANCH:-main}"
GITHUB_RAW_BASE="https://raw.githubusercontent.com/${GITHUB_REPO}/${GITHUB_BRANCH}"
TEMP_DOWNLOAD_DIR=""

# Get script directory (where the repo is)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
SOURCE_DIR="$REPO_DIR/cursor"
OPTIMIZED_DIR="$REPO_DIR/cursor/_optimized"
VERSION_FILE="$TARGET_DIR/.deploy-version"
BACKUP_DIR="$TARGET_DIR/.backups"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --global)
            TARGET_DIR="$HOME/.cursor"
            VERSION_FILE="$TARGET_DIR/.deploy-version"
            BACKUP_DIR="$TARGET_DIR/.backups"
            shift
            ;;
        --project)
            TARGET_DIR="$2/.cursor"
            VERSION_FILE="$TARGET_DIR/.deploy-version"
            BACKUP_DIR="$TARGET_DIR/.backups"
            shift 2
            ;;
        --copy)
            MODE="copy"
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
        --update)
            UPDATE=true
            shift
            ;;
        --check)
            CHECK_ONLY=true
            shift
            ;;
        --optimized)
            OPTIMIZED=true
            shift
            ;;
        --lazy)
            LAZY=true
            shift
            ;;
        --backup)
            BACKUP=true
            shift
            ;;
        --restore)
            RESTORE=true
            shift
            ;;
        --status)
            STATUS=true
            shift
            ;;
        --download)
            DOWNLOAD=true
            MODE="copy"  # Force copy mode for downloads
            shift
            ;;
        --help)
            cat << 'HELP'
deploy-cursor.sh - Deploy Cursor configurations to user's system

Usage:
  ./scripts/deploy-cursor.sh [OPTIONS]

Remote Installation (no git clone required):
  curl -fsSL https://raw.githubusercontent.com/ArangoGutierrez/promptsLibrary/main/scripts/deploy-cursor.sh | bash -s -- --download
  wget -qO- https://raw.githubusercontent.com/ArangoGutierrez/promptsLibrary/main/scripts/deploy-cursor.sh | bash -s -- --download

Options:
  --global          Deploy to ~/.cursor/ (default)
  --project <path>  Deploy to <path>/.cursor/
  --copy            Copy files instead of symlink
  --force           Overwrite existing files
  --dry-run         Show what would be done
  --uninstall       Remove deployed symlinks/files
  --update          Smart update: pull latest, show changes, deploy
  --check           Check for updates without deploying
  --status          Show current deployment status
  --optimized       Deploy token-optimized versions (~60% smaller)
  --lazy            Deploy lazy-loading framework (~95% smaller always-on)
  --download        Download files from GitHub (no git clone needed)
  --backup          Create backup before deploying
  --restore         Restore from latest backup
  --help            Show this help message

Environment Variables:
  CURSOR_DEV_REPO   Override the GitHub repo (default: ArangoGutierrez/promptsLibrary)
  CURSOR_DEV_BRANCH Override the branch (default: main)

Examples:
  # Remote installation (one-liner, no clone needed)
  curl -fsSL https://raw.githubusercontent.com/ArangoGutierrez/promptsLibrary/main/scripts/deploy-cursor.sh | bash -s -- --download

  # Local deployment (after git clone)
  ./scripts/deploy-cursor.sh                    # Deploy globally with symlinks
  ./scripts/deploy-cursor.sh --dry-run          # Preview what would be done
  ./scripts/deploy-cursor.sh --copy --force     # Copy files, overwrite existing
  ./scripts/deploy-cursor.sh --project ./myapp  # Deploy to specific project
  ./scripts/deploy-cursor.sh --uninstall        # Remove deployed files
  ./scripts/deploy-cursor.sh --update           # Pull latest and update
  ./scripts/deploy-cursor.sh --check            # Check for available updates
  ./scripts/deploy-cursor.sh --status           # Show deployment status
  ./scripts/deploy-cursor.sh --optimized        # Deploy token-optimized versions
  ./scripts/deploy-cursor.sh --lazy             # Deploy lazy-loading (minimal always-on)
  ./scripts/deploy-cursor.sh --backup --update  # Backup before updating
  ./scripts/deploy-cursor.sh --restore          # Restore from backup

  # Remote with options
  curl -fsSL .../deploy-cursor.sh | bash -s -- --download --optimized
  curl -fsSL .../deploy-cursor.sh | bash -s -- --download --lazy
HELP
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Determine source directory based on mode
LAZY_DIR="$REPO_DIR/cursor/_lazy"

if [ "$LAZY" = true ] && [ -d "$LAZY_DIR" ]; then
    SOURCE_DIR="$LAZY_DIR"
    echo -e "${MAGENTA}Using lazy-loading framework (~95% smaller always-on footprint)${NC}"
    echo -e "${MAGENTA}Modes available: /deep /security /perf /tdd${NC}"
elif [ "$OPTIMIZED" = true ] && [ -d "$OPTIMIZED_DIR" ]; then
    SOURCE_DIR="$OPTIMIZED_DIR"
    echo -e "${CYAN}Using token-optimized versions (~60% smaller context footprint)${NC}"
fi

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
    mkdir -p "$TEMP_DOWNLOAD_DIR/cursor"/{commands,agents,rules,hooks,schemas}
    mkdir -p "$TEMP_DOWNLOAD_DIR/cursor/skills"/{deep-analysis,go-audit,performance-optimization,pr-review,spec-first,testing-tdd}
    mkdir -p "$TEMP_DOWNLOAD_DIR/cursor/_optimized"/{commands,agents,rules}
    mkdir -p "$TEMP_DOWNLOAD_DIR/cursor/_optimized/skills"/{deep-analysis,go-audit,performance-optimization,pr-review,spec-first,testing-tdd}
    mkdir -p "$TEMP_DOWNLOAD_DIR/cursor/_lazy"/{rules,modes}
    
    # Download main cursor files
    echo -e "${BLUE}Downloading configuration files...${NC}"
    
    # Commands
    local commands=(
        "architect" "audit" "code" "context-reset" "debug" "docs"
        "git-polish" "issue" "loop" "parallel" "push" "quality"
        "refactor" "research" "review-pr" "self-review" "task" "test"
    )
    for cmd in "${commands[@]}"; do
        echo -ne "  commands/${cmd}.md... "
        if download_file "cursor/commands/${cmd}.md" "$TEMP_DOWNLOAD_DIR/cursor/commands/${cmd}.md"; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${YELLOW}skipped${NC}"
        fi
    done
    
    # Agents
    local agents=(
        "api-reviewer" "arch-explorer" "auditor" "devil-advocate" "documenter"
        "perf-critic" "prototyper" "researcher" "synthesizer" "task-analyzer"
        "test-generator" "verifier"
    )
    for agent in "${agents[@]}"; do
        echo -ne "  agents/${agent}.md... "
        if download_file "cursor/agents/${agent}.md" "$TEMP_DOWNLOAD_DIR/cursor/agents/${agent}.md"; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${YELLOW}skipped${NC}"
        fi
    done
    
    # Rules
    local rules=("go-style" "project" "quality-gate" "security" "user-rules")
    for rule in "${rules[@]}"; do
        echo -ne "  rules/${rule}.md... "
        if download_file "cursor/rules/${rule}.md" "$TEMP_DOWNLOAD_DIR/cursor/rules/${rule}.md"; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${YELLOW}skipped${NC}"
        fi
    done
    
    # Skills
    local skills=("deep-analysis" "go-audit" "performance-optimization" "pr-review" "spec-first" "testing-tdd")
    for skill in "${skills[@]}"; do
        echo -ne "  skills/${skill}/SKILL.md... "
        if download_file "cursor/skills/${skill}/SKILL.md" "$TEMP_DOWNLOAD_DIR/cursor/skills/${skill}/SKILL.md"; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${YELLOW}skipped${NC}"
        fi
    done
    
    # Hooks
    local hooks=("context-monitor" "format" "preflight" "security-gate" "sign-commits" "task-loop")
    for hook in "${hooks[@]}"; do
        echo -ne "  hooks/${hook}.sh... "
        if download_file "cursor/hooks/${hook}.sh" "$TEMP_DOWNLOAD_DIR/cursor/hooks/${hook}.sh"; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${YELLOW}skipped${NC}"
        fi
    done
    
    # Schemas
    local schemas=("hook-output.schema" "hooks.schema" "state-file.schema")
    for schema in "${schemas[@]}"; do
        echo -ne "  schemas/${schema}.json... "
        if download_file "cursor/schemas/${schema}.json" "$TEMP_DOWNLOAD_DIR/cursor/schemas/${schema}.json"; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${YELLOW}skipped${NC}"
        fi
    done
    
    # hooks.json
    echo -ne "  hooks.json... "
    if download_file "cursor/hooks.json" "$TEMP_DOWNLOAD_DIR/cursor/hooks.json"; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${YELLOW}skipped${NC}"
    fi
    
    # Download optimized versions if --optimized flag
    if [ "$OPTIMIZED" = true ]; then
        echo ""
        echo -e "${CYAN}Downloading optimized versions...${NC}"
        
        for cmd in "${commands[@]}"; do
            echo -ne "  _optimized/commands/${cmd}.md... "
            if download_file "cursor/_optimized/commands/${cmd}.md" "$TEMP_DOWNLOAD_DIR/cursor/_optimized/commands/${cmd}.md"; then
                echo -e "${GREEN}✓${NC}"
            else
                echo -e "${YELLOW}skipped${NC}"
            fi
        done
        
        for agent in "${agents[@]}"; do
            echo -ne "  _optimized/agents/${agent}.md... "
            if download_file "cursor/_optimized/agents/${agent}.md" "$TEMP_DOWNLOAD_DIR/cursor/_optimized/agents/${agent}.md"; then
                echo -e "${GREEN}✓${NC}"
            else
                echo -e "${YELLOW}skipped${NC}"
            fi
        done
        
        for rule in "${rules[@]}"; do
            echo -ne "  _optimized/rules/${rule}.md... "
            if download_file "cursor/_optimized/rules/${rule}.md" "$TEMP_DOWNLOAD_DIR/cursor/_optimized/rules/${rule}.md"; then
                echo -e "${GREEN}✓${NC}"
            else
                echo -e "${YELLOW}skipped${NC}"
            fi
        done
        
        for skill in "${skills[@]}"; do
            echo -ne "  _optimized/skills/${skill}/SKILL.md... "
            if download_file "cursor/_optimized/skills/${skill}/SKILL.md" "$TEMP_DOWNLOAD_DIR/cursor/_optimized/skills/${skill}/SKILL.md"; then
                echo -e "${GREEN}✓${NC}"
            else
                echo -e "${YELLOW}skipped${NC}"
            fi
        done
    fi
    
    # Download lazy versions if --lazy flag
    if [ "$LAZY" = true ]; then
        echo ""
        echo -e "${MAGENTA}Downloading lazy-loading framework...${NC}"
        
        local lazy_rules=("core" "go" "k8s" "python" "security" "ts")
        for rule in "${lazy_rules[@]}"; do
            echo -ne "  _lazy/rules/${rule}.md... "
            if download_file "cursor/_lazy/rules/${rule}.md" "$TEMP_DOWNLOAD_DIR/cursor/_lazy/rules/${rule}.md"; then
                echo -e "${GREEN}✓${NC}"
            else
                echo -e "${YELLOW}skipped${NC}"
            fi
        done
        
        local lazy_modes=("deep" "perf" "security" "tdd")
        for mode in "${lazy_modes[@]}"; do
            echo -ne "  _lazy/modes/${mode}.md... "
            if download_file "cursor/_lazy/modes/${mode}.md" "$TEMP_DOWNLOAD_DIR/cursor/_lazy/modes/${mode}.md"; then
                echo -e "${GREEN}✓${NC}"
            else
                echo -e "${YELLOW}skipped${NC}"
            fi
        done
    fi
    
    echo ""
    
    # Update paths to use temp directory
    REPO_DIR="$TEMP_DOWNLOAD_DIR"
    SOURCE_DIR="$TEMP_DOWNLOAD_DIR/cursor"
    OPTIMIZED_DIR="$TEMP_DOWNLOAD_DIR/cursor/_optimized"
    LAZY_DIR="$TEMP_DOWNLOAD_DIR/cursor/_lazy"
    
    # Re-select source based on mode
    if [ "$LAZY" = true ] && [ -d "$LAZY_DIR" ]; then
        SOURCE_DIR="$LAZY_DIR"
    elif [ "$OPTIMIZED" = true ] && [ -d "$OPTIMIZED_DIR" ]; then
        SOURCE_DIR="$OPTIMIZED_DIR"
    fi
}

# Get current repo version (git commit hash + date)
get_repo_version() {
    if [ "$DOWNLOAD" = true ]; then
        # For download mode, use current date and branch info
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

# Get deployed version
get_deployed_version() {
    if [ -f "$VERSION_FILE" ]; then
        cat "$VERSION_FILE"
    else
        echo "none|never|none"
    fi
}

# Save deployed version
save_deployed_version() {
    local version="$1"
    local mode_flag=""
    [ "$OPTIMIZED" = true ] && mode_flag="|optimized"
    [ "$LAZY" = true ] && mode_flag="|lazy"
    if [ "$DRY_RUN" = false ]; then
        mkdir -p "$(dirname "$VERSION_FILE")"
        echo "${version}${mode_flag}" > "$VERSION_FILE"
    fi
}

# Get list of changed files since deployed version
get_changed_files() {
    local deployed_hash=$(echo "$1" | cut -d'|' -f1)
    local current_hash=$(echo "$2" | cut -d'|' -f1)
    
    if [ "$deployed_hash" = "none" ] || [ "$deployed_hash" = "unknown" ]; then
        echo "First deployment - all files are new"
        return
    fi
    
    cd "$REPO_DIR"
    git diff --name-only "$deployed_hash" "$current_hash" -- cursor/ 2>/dev/null || echo "Unable to determine changes"
}

# Check for updates
check_updates() {
    local deployed=$(get_deployed_version)
    local current=$(get_repo_version)
    
    local deployed_hash=$(echo "$deployed" | cut -d'|' -f1)
    local deployed_date=$(echo "$deployed" | cut -d'|' -f2)
    local current_hash=$(echo "$current" | cut -d'|' -f1)
    local current_date=$(echo "$current" | cut -d'|' -f2)
    local is_optimized=$(echo "$deployed" | grep -q "optimized" && echo "yes" || echo "no")
    
    echo -e "${BLUE}=== Update Check ===${NC}"
    echo ""
    echo -e "Deployed version: ${YELLOW}$deployed_hash${NC} ($deployed_date)"
    echo -e "Current version:  ${GREEN}$current_hash${NC} ($current_date)"
    echo -e "Optimized mode:   ${CYAN}$is_optimized${NC}"
    echo ""
    
    if [ "$deployed_hash" = "$current_hash" ]; then
        echo -e "${GREEN}✓ Already up to date${NC}"
        return 1
    else
        echo -e "${YELLOW}⚠ Updates available${NC}"
        echo ""
        echo -e "${BLUE}Changed files:${NC}"
        get_changed_files "$deployed" "$current" | while read -r file; do
            if [ -n "$file" ]; then
                echo -e "  ${CYAN}$file${NC}"
            fi
        done
        echo ""
        
        # Show commit messages since deployed version
        if [ "$deployed_hash" != "none" ] && [ "$deployed_hash" != "unknown" ]; then
            echo -e "${BLUE}Commits since deployment:${NC}"
            cd "$REPO_DIR"
            git log --oneline "$deployed_hash"..HEAD -- cursor/ 2>/dev/null | head -10 | while read -r line; do
                echo -e "  ${MAGENTA}$line${NC}"
            done
            local count=$(git rev-list --count "$deployed_hash"..HEAD -- cursor/ 2>/dev/null || echo "?")
            [ "$count" -gt 10 ] 2>/dev/null && echo -e "  ${YELLOW}... and $((count-10)) more${NC}"
        fi
        return 0
    fi
}

# Pull latest from remote
pull_latest() {
    echo -e "${BLUE}Pulling latest changes...${NC}"
    cd "$REPO_DIR"
    
    # Check for uncommitted changes
    if ! git diff --quiet 2>/dev/null; then
        echo -e "${YELLOW}Warning: Local changes detected. Stashing...${NC}"
        git stash push -m "deploy-cursor auto-stash $(date +%Y%m%d-%H%M%S)"
    fi
    
    # Pull
    if git pull --ff-only 2>/dev/null; then
        echo -e "${GREEN}✓ Updated to latest${NC}"
    else
        echo -e "${YELLOW}Warning: Could not fast-forward. Fetching instead...${NC}"
        git fetch origin
        echo -e "${YELLOW}Run 'git pull' manually if you want to merge${NC}"
    fi
    echo ""
}

# Create backup
create_backup() {
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_path="$BACKUP_DIR/$timestamp"
    
    echo -e "${BLUE}Creating backup...${NC}"
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[DRY-RUN] Would backup to: $backup_path${NC}"
        return 0
    fi
    
    mkdir -p "$backup_path"
    
    # Backup each directory if it exists
    for dir in commands skills agents hooks rules schemas; do
        if [ -d "$TARGET_DIR/$dir" ]; then
            cp -rL "$TARGET_DIR/$dir" "$backup_path/" 2>/dev/null || true
        fi
    done
    
    # Backup hooks.json
    [ -f "$TARGET_DIR/hooks.json" ] && cp "$TARGET_DIR/hooks.json" "$backup_path/"
    
    # Backup version file
    [ -f "$VERSION_FILE" ] && cp "$VERSION_FILE" "$backup_path/"
    
    echo -e "${GREEN}✓ Backup created: $backup_path${NC}"
    
    # Cleanup old backups (keep last 5)
    local backup_count=$(ls -1 "$BACKUP_DIR" 2>/dev/null | wc -l)
    if [ "$backup_count" -gt 5 ]; then
        echo -e "${YELLOW}Cleaning old backups (keeping last 5)...${NC}"
        ls -1t "$BACKUP_DIR" | tail -n +6 | while read -r old; do
            rm -rf "$BACKUP_DIR/$old"
            echo -e "  Removed: $old"
        done
    fi
    echo ""
}

# Restore from backup
restore_backup() {
    if [ ! -d "$BACKUP_DIR" ]; then
        echo -e "${RED}No backups found${NC}"
        exit 1
    fi
    
    # Get latest backup
    local latest=$(ls -1t "$BACKUP_DIR" 2>/dev/null | head -1)
    
    if [ -z "$latest" ]; then
        echo -e "${RED}No backups found${NC}"
        exit 1
    fi
    
    local backup_path="$BACKUP_DIR/$latest"
    
    echo -e "${BLUE}=== Restore from Backup ===${NC}"
    echo -e "Backup: ${YELLOW}$latest${NC}"
    echo ""
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[DRY-RUN] Would restore from: $backup_path${NC}"
        return 0
    fi
    
    # Restore each directory
    for dir in commands skills agents hooks rules schemas; do
        if [ -d "$backup_path/$dir" ]; then
            rm -rf "$TARGET_DIR/$dir"
            cp -r "$backup_path/$dir" "$TARGET_DIR/"
            echo -e "${GREEN}Restored: $dir${NC}"
        fi
    done
    
    # Restore hooks.json
    if [ -f "$backup_path/hooks.json" ]; then
        cp "$backup_path/hooks.json" "$TARGET_DIR/"
        echo -e "${GREEN}Restored: hooks.json${NC}"
    fi
    
    # Restore version file
    if [ -f "$backup_path/.deploy-version" ]; then
        cp "$backup_path/.deploy-version" "$VERSION_FILE"
    fi
    
    echo ""
    echo -e "${GREEN}✓ Restore complete${NC}"
}

# Show token impact comparison
show_token_impact() {
    echo -e "${BLUE}=== Token Impact Analysis ===${NC}"
    echo ""
    
    local normal_size=0
    local optimized_size=0
    local lazy_always_size=0
    local lazy_total_size=0
    
    # Calculate normal size using wc on globbed files
    if [ -d "$REPO_DIR/cursor" ]; then
        for dir in commands agents rules; do
            if [ -d "$REPO_DIR/cursor/$dir" ]; then
                for f in "$REPO_DIR/cursor/$dir"/*.md; do
                    [ -f "$f" ] && normal_size=$((normal_size + $(wc -c < "$f")))
                done
            fi
        done
        # Skills
        if [ -d "$REPO_DIR/cursor/skills" ]; then
            for skill_dir in "$REPO_DIR/cursor/skills"/*/; do
                [ -f "${skill_dir}SKILL.md" ] && normal_size=$((normal_size + $(wc -c < "${skill_dir}SKILL.md")))
            done
        fi
    fi
    
    # Calculate optimized size
    if [ -d "$OPTIMIZED_DIR" ]; then
        for dir in commands agents rules; do
            if [ -d "$OPTIMIZED_DIR/$dir" ]; then
                for f in "$OPTIMIZED_DIR/$dir"/*.md; do
                    [ -f "$f" ] && optimized_size=$((optimized_size + $(wc -c < "$f")))
                done
            fi
        done
        # Skills
        if [ -d "$OPTIMIZED_DIR/skills" ]; then
            for skill_dir in "$OPTIMIZED_DIR/skills"/*/; do
                [ -f "${skill_dir}SKILL.md" ] && optimized_size=$((optimized_size + $(wc -c < "${skill_dir}SKILL.md")))
            done
        fi
    fi
    
    # Calculate lazy size (always-on = core.md only)
    if [ -d "$LAZY_DIR" ]; then
        # Always-on: only core.md (alwaysApply: true)
        if [ -f "$LAZY_DIR/rules/core.md" ]; then
            lazy_always_size=$(wc -c < "$LAZY_DIR/rules/core.md")
        fi
        
        # Total lazy = rules + modes (but rules are file-matched, modes are on-demand)
        for f in "$LAZY_DIR/rules"/*.md; do
            [ -f "$f" ] && lazy_total_size=$((lazy_total_size + $(wc -c < "$f")))
        done
        for f in "$LAZY_DIR/modes"/*.md; do
            [ -f "$f" ] && lazy_total_size=$((lazy_total_size + $(wc -c < "$f")))
        done
    fi
    
    local normal_tokens=$((normal_size / 4))
    local optimized_tokens=$((optimized_size / 4))
    local lazy_always_tokens=$((lazy_always_size / 4))
    local lazy_total_tokens=$((lazy_total_size / 4))
    
    echo -e "${CYAN}Always-On Token Usage (per conversation):${NC}"
    echo ""
    
    # Normal rules always-on
    local normal_rules_size=0
    if [ -d "$REPO_DIR/cursor/rules" ]; then
        for f in "$REPO_DIR/cursor/rules"/*.md; do
            [ -f "$f" ] && normal_rules_size=$((normal_rules_size + $(wc -c < "$f")))
        done
    fi
    local normal_rules_tokens=$((normal_rules_size / 4))
    
    # Optimized rules always-on
    local opt_rules_size=0
    if [ -d "$OPTIMIZED_DIR/rules" ]; then
        for f in "$OPTIMIZED_DIR/rules"/*.md; do
            [ -f "$f" ] && opt_rules_size=$((opt_rules_size + $(wc -c < "$f")))
        done
    fi
    local opt_rules_tokens=$((opt_rules_size / 4))
    
    echo -e "Normal (all rules):     ~${YELLOW}${normal_rules_tokens}${NC} tokens always loaded"
    [ "$opt_rules_tokens" -gt 0 ] && echo -e "Optimized (all rules):  ~${GREEN}${opt_rules_tokens}${NC} tokens always loaded"
    [ "$lazy_always_tokens" -gt 0 ] && echo -e "Lazy (core.md only):    ~${MAGENTA}${lazy_always_tokens}${NC} tokens always loaded"
    echo ""
    
    echo -e "${CYAN}Total Available Content:${NC}"
    echo ""
    echo -e "Normal version:    ~${YELLOW}${normal_tokens}${NC} tokens"
    [ "$optimized_tokens" -gt 0 ] && echo -e "Optimized version: ~${GREEN}${optimized_tokens}${NC} tokens"
    [ "$lazy_total_tokens" -gt 0 ] && echo -e "Lazy framework:    ~${MAGENTA}${lazy_total_tokens}${NC} tokens (+ optimized commands)"
    echo ""
    
    echo -e "${CYAN}Savings Summary:${NC}"
    echo ""
    if [ "$normal_rules_tokens" -gt 0 ]; then
        if [ "$opt_rules_tokens" -gt 0 ]; then
            local opt_saved=$((normal_rules_tokens - opt_rules_tokens))
            local opt_pct=$((opt_saved * 100 / normal_rules_tokens))
            echo -e "Optimized: ${GREEN}-${opt_saved}${NC} tokens always-on (${opt_pct}% reduction)"
        fi
        if [ "$lazy_always_tokens" -gt 0 ]; then
            local lazy_saved=$((normal_rules_tokens - lazy_always_tokens))
            local lazy_pct=$((lazy_saved * 100 / normal_rules_tokens))
            echo -e "Lazy:      ${MAGENTA}-${lazy_saved}${NC} tokens always-on (${lazy_pct}% reduction)"
        fi
    fi
    echo ""
    
    echo -e "${CYAN}Context Budget (200k):${NC}"
    echo -e "Normal:    ${YELLOW}$((normal_rules_tokens * 100 / 2000))‰${NC} always-on"
    [ "$opt_rules_tokens" -gt 0 ] && echo -e "Optimized: ${GREEN}$((opt_rules_tokens * 100 / 2000))‰${NC} always-on"
    [ "$lazy_always_tokens" -gt 0 ] && echo -e "Lazy:      ${MAGENTA}$((lazy_always_tokens * 100 / 2000))‰${NC} always-on"
    echo ""
}

OS=$(detect_os)

# Handle download mode first (before checking source directory)
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
        echo "  curl -fsSL https://raw.githubusercontent.com/${GITHUB_REPO}/${GITHUB_BRANCH}/scripts/deploy-cursor.sh | bash -s -- --download"
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

# Deploy a single file (symlink or copy)
deploy_file() {
    local src="$1"
    local dst="$2"
    local dst_dir="$(dirname "$dst")"
    
    # Create target directory
    create_target_dir "$dst_dir"
    
    # Check if destination exists
    if [ -e "$dst" ] || [ -L "$dst" ]; then
        if [ "$FORCE" = true ]; then
            if [ "$DRY_RUN" = true ]; then
                echo -e "${YELLOW}[DRY-RUN] Would remove existing: $dst${NC}"
            else
                rm -rf "$dst"
            fi
        else
            # Check if it's already a symlink to our source
            if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
                echo -e "${BLUE}Already linked: $dst${NC}"
                return 0
            fi
            echo -e "${YELLOW}Skipping (exists): $dst${NC}"
            echo -e "${YELLOW}  Use --force to overwrite${NC}"
            return 0
        fi
    fi
    
    if [ "$DRY_RUN" = true ]; then
        if [ "$MODE" = "symlink" ]; then
            echo -e "${YELLOW}[DRY-RUN] Would symlink: $dst -> $src${NC}"
        else
            echo -e "${YELLOW}[DRY-RUN] Would copy: $src -> $dst${NC}"
        fi
    else
        if [ "$MODE" = "symlink" ]; then
            ln -s "$src" "$dst"
            echo -e "${GREEN}Linked: $dst -> $src${NC}"
        else
            cp "$src" "$dst"
            echo -e "${GREEN}Copied: $src -> $dst${NC}"
        fi
    fi
}

# Deploy a directory of files
deploy_directory() {
    local src_dir="$1"
    local dst_dir="$2"
    local pattern="${3:-*}"
    
    if [ ! -d "$src_dir" ]; then
        return 0
    fi
    
    create_target_dir "$dst_dir"
    
    for src_file in "$src_dir"/$pattern; do
        if [ -f "$src_file" ]; then
            local filename="$(basename "$src_file")"
            deploy_file "$src_file" "$dst_dir/$filename"
        fi
    done
}

# Deploy skills (each skill is a directory)
deploy_skills() {
    local src_dir="$SOURCE_DIR/skills"
    local dst_dir="$TARGET_DIR/skills"
    
    if [ ! -d "$src_dir" ]; then
        return 0
    fi
    
    create_target_dir "$dst_dir"
    
    for skill_dir in "$src_dir"/*/; do
        if [ -d "$skill_dir" ]; then
            local skill_name="$(basename "$skill_dir")"
            local dst_skill_dir="$dst_dir/$skill_name"
            
            # Check if destination exists
            if [ -e "$dst_skill_dir" ] || [ -L "$dst_skill_dir" ]; then
                if [ "$FORCE" = true ]; then
                    if [ "$DRY_RUN" = true ]; then
                        echo -e "${YELLOW}[DRY-RUN] Would remove: $dst_skill_dir${NC}"
                    else
                        rm -rf "$dst_skill_dir"
                    fi
                else
                    if [ -L "$dst_skill_dir" ] && [ "$(readlink "$dst_skill_dir")" = "${skill_dir%/}" ]; then
                        echo -e "${BLUE}Already linked: $dst_skill_dir${NC}"
                        continue
                    fi
                    echo -e "${YELLOW}Skipping skill (exists): $skill_name${NC}"
                    continue
                fi
            fi
            
            # Symlink or copy the entire skill directory
            if [ "$DRY_RUN" = true ]; then
                if [ "$MODE" = "symlink" ]; then
                    echo -e "${YELLOW}[DRY-RUN] Would symlink skill: $dst_skill_dir${NC}"
                else
                    echo -e "${YELLOW}[DRY-RUN] Would copy skill: $dst_skill_dir${NC}"
                fi
            else
                if [ "$MODE" = "symlink" ]; then
                    ln -s "${skill_dir%/}" "$dst_skill_dir"
                    echo -e "${GREEN}Linked skill: $skill_name${NC}"
                else
                    cp -r "${skill_dir%/}" "$dst_skill_dir"
                    echo -e "${GREEN}Copied skill: $skill_name${NC}"
                fi
            fi
        fi
    done
}

# Merge hooks.json
merge_hooks_json() {
    local src_file="$SOURCE_DIR/hooks.json"
    local dst_file="$TARGET_DIR/hooks.json"
    
    if [ ! -f "$src_file" ]; then
        return 0
    fi
    
    create_target_dir "$TARGET_DIR"
    
    if [ -f "$dst_file" ]; then
        if [ "$FORCE" = true ]; then
            if [ "$DRY_RUN" = true ]; then
                echo -e "${YELLOW}[DRY-RUN] Would backup and replace: $dst_file${NC}"
            else
                cp "$dst_file" "$dst_file.bak"
                echo -e "${YELLOW}Backed up: $dst_file.bak${NC}"
                cp "$src_file" "$dst_file"
                echo -e "${GREEN}Replaced: $dst_file${NC}"
            fi
        else
            echo -e "${YELLOW}hooks.json exists. Merging is complex - use --force to replace.${NC}"
            echo -e "${YELLOW}  Existing file backed up to hooks.json.bak${NC}"
        fi
    else
        if [ "$DRY_RUN" = true ]; then
            echo -e "${YELLOW}[DRY-RUN] Would copy: $dst_file${NC}"
        else
            cp "$src_file" "$dst_file"
            echo -e "${GREEN}Copied: $dst_file${NC}"
        fi
    fi
}

# Make hook scripts executable
make_hooks_executable() {
    local hooks_dir="$TARGET_DIR/hooks"
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[DRY-RUN] Would make hooks executable${NC}"
        return 0
    fi
    
    if [ -d "$hooks_dir" ]; then
        for hook in "$hooks_dir"/*.sh; do
            if [ -f "$hook" ]; then
                chmod +x "$hook"
                echo -e "${GREEN}Made executable: $hook${NC}"
            fi
        done
    fi
}

# Uninstall deployed files
uninstall() {
    echo -e "${YELLOW}Uninstalling from: $TARGET_DIR${NC}"
    
    # Remove symlinks to our source only
    for dir in commands skills agents hooks rules schemas; do
        local target="$TARGET_DIR/$dir"
        if [ -d "$target" ]; then
            for item in "$target"/*; do
                if [ -L "$item" ]; then
                    local link_target="$(readlink "$item")"
                    if [[ "$link_target" == "$SOURCE_DIR"* ]]; then
                        if [ "$DRY_RUN" = true ]; then
                            echo -e "${YELLOW}[DRY-RUN] Would remove: $item${NC}"
                        else
                            rm "$item"
                            echo -e "${GREEN}Removed: $item${NC}"
                        fi
                    fi
                fi
            done
        fi
    done
    
    # Check hooks.json
    if [ -f "$TARGET_DIR/hooks.json.bak" ]; then
        if [ "$DRY_RUN" = true ]; then
            echo -e "${YELLOW}[DRY-RUN] Would restore: $TARGET_DIR/hooks.json from backup${NC}"
        else
            mv "$TARGET_DIR/hooks.json.bak" "$TARGET_DIR/hooks.json"
            echo -e "${GREEN}Restored: $TARGET_DIR/hooks.json from backup${NC}"
        fi
    fi
    
    echo -e "${GREEN}Uninstall complete${NC}"
}

# Main deployment
deploy() {
    echo -e "${BLUE}=== Deploying Cursor Configurations ===${NC}"
    [ "$OPTIMIZED" = true ] && echo -e "${CYAN}(Token-optimized mode)${NC}"
    [ "$LAZY" = true ] && echo -e "${MAGENTA}(Lazy-loading mode)${NC}"
    echo ""
    
    if [ "$LAZY" = true ]; then
        # Lazy mode: deploy from lazy directory + optimized commands
        
        # Deploy lazy rules (core + language-specific)
        echo -e "${BLUE}Deploying lazy rules...${NC}"
        deploy_directory "$LAZY_DIR/rules" "$TARGET_DIR/rules" "*.md"
        echo ""
        
        # Deploy mode commands (on-demand activation)
        echo -e "${BLUE}Deploying mode commands...${NC}"
        deploy_directory "$LAZY_DIR/modes" "$TARGET_DIR/commands" "*.md"
        echo ""
        
        # Deploy optimized commands (if available)
        echo -e "${BLUE}Deploying optimized commands...${NC}"
        if [ -d "$OPTIMIZED_DIR/commands" ]; then
            deploy_directory "$OPTIMIZED_DIR/commands" "$TARGET_DIR/commands" "*.md"
        else
            deploy_directory "$REPO_DIR/cursor/commands" "$TARGET_DIR/commands" "*.md"
        fi
        echo ""
        
        # Deploy optimized skills (if available)
        echo -e "${BLUE}Deploying skills...${NC}"
        if [ -d "$OPTIMIZED_DIR/skills" ]; then
            local old_source="$SOURCE_DIR"
            SOURCE_DIR="$OPTIMIZED_DIR"
            deploy_skills
            SOURCE_DIR="$old_source"
        else
            local old_source="$SOURCE_DIR"
            SOURCE_DIR="$REPO_DIR/cursor"
            deploy_skills
            SOURCE_DIR="$old_source"
        fi
        echo ""
        
        # Deploy optimized agents (if available)
        echo -e "${BLUE}Deploying agents...${NC}"
        if [ -d "$OPTIMIZED_DIR/agents" ]; then
            deploy_directory "$OPTIMIZED_DIR/agents" "$TARGET_DIR/agents" "*.md"
        else
            deploy_directory "$REPO_DIR/cursor/agents" "$TARGET_DIR/agents" "*.md"
        fi
        echo ""
    else
        # Normal or optimized mode
        
        # Deploy commands
        echo -e "${BLUE}Deploying commands...${NC}"
        deploy_directory "$SOURCE_DIR/commands" "$TARGET_DIR/commands" "*.md"
        echo ""
        
        # Deploy skills
        echo -e "${BLUE}Deploying skills...${NC}"
        deploy_skills
        echo ""
        
        # Deploy agents
        echo -e "${BLUE}Deploying agents...${NC}"
        deploy_directory "$SOURCE_DIR/agents" "$TARGET_DIR/agents" "*.md"
        echo ""
        
        # Deploy rules
        echo -e "${BLUE}Deploying rules...${NC}"
        deploy_directory "$SOURCE_DIR/rules" "$TARGET_DIR/rules" "*.md"
        echo ""
    fi
    
    # Deploy hooks (always from main source)
    echo -e "${BLUE}Deploying hooks...${NC}"
    deploy_directory "$REPO_DIR/cursor/hooks" "$TARGET_DIR/hooks" "*.sh"
    make_hooks_executable
    echo ""
    
    # Handle hooks.json (always from main source)
    echo -e "${BLUE}Deploying hooks.json...${NC}"
    local hooks_src="$REPO_DIR/cursor/hooks.json"
    if [ -f "$hooks_src" ]; then
        local dst_file="$TARGET_DIR/hooks.json"
        if [ -f "$dst_file" ]; then
            if [ "$FORCE" = true ]; then
                [ "$DRY_RUN" = false ] && cp "$dst_file" "$dst_file.bak"
                [ "$DRY_RUN" = false ] && cp "$hooks_src" "$dst_file"
                echo -e "${GREEN}Replaced: $dst_file (backed up)${NC}"
            else
                echo -e "${YELLOW}hooks.json exists. Use --force to replace.${NC}"
            fi
        else
            [ "$DRY_RUN" = false ] && cp "$hooks_src" "$dst_file"
            echo -e "${GREEN}Copied: $dst_file${NC}"
        fi
    fi
    echo ""
    
    # Deploy schemas (always from main source, for validation)
    echo -e "${BLUE}Deploying schemas...${NC}"
    if [ -d "$REPO_DIR/cursor/schemas" ]; then
        deploy_directory "$REPO_DIR/cursor/schemas" "$TARGET_DIR/schemas" "*.json"
    fi
    echo ""
    
    # Save version info
    local version=$(get_repo_version)
    local mode_flag=""
    [ "$OPTIMIZED" = true ] && mode_flag="|optimized"
    [ "$LAZY" = true ] && mode_flag="|lazy"
    save_deployed_version "$version"
    
    echo -e "${GREEN}=== Deployment Complete ===${NC}"
    echo ""
    echo -e "${BLUE}Deployed to: $TARGET_DIR${NC}"
    echo -e "${BLUE}Version: $(echo "$version" | cut -d'|' -f1) ($(echo "$version" | cut -d'|' -f2))${NC}"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "  1. Restart Cursor to load new configurations"
    echo "  2. Type '/' in chat to see available commands"
    echo "  3. Check Cursor Settings > Rules to see loaded rules"
    echo ""
    if [ "$MODE" = "symlink" ]; then
        echo -e "${BLUE}Note: Files are symlinked. Pull repo updates and they auto-propagate.${NC}"
        echo -e "${BLUE}      Run --check to see if updates are available.${NC}"
    else
        echo -e "${YELLOW}Note: Files are copied. Run --update to get new versions.${NC}"
    fi
    if [ "$OPTIMIZED" = true ]; then
        echo ""
        echo -e "${CYAN}Token-optimized mode: ~60% smaller context footprint.${NC}"
    fi
    if [ "$LAZY" = true ]; then
        echo ""
        echo -e "${MAGENTA}Lazy-loading mode: ~200 tokens always-on (vs ~850 normal)${NC}"
        echo -e "${MAGENTA}Invoke modes on-demand: /deep /security /perf /tdd${NC}"
    fi
}

# Smart update
smart_update() {
    echo -e "${BLUE}=== Smart Update ===${NC}"
    echo ""
    
    # Check for updates first
    if ! check_updates; then
        echo ""
        echo -e "${GREEN}No update needed.${NC}"
        return 0
    fi
    echo ""
    
    # Pull latest
    pull_latest
    
    # Create backup if requested
    if [ "$BACKUP" = true ]; then
        create_backup
    fi
    
    # Deploy with force to update all files
    FORCE=true
    deploy
}

# Show deployment status
show_status() {
    echo -e "${BLUE}=== Deployment Status ===${NC}"
    echo ""
    
    local deployed=$(get_deployed_version)
    local current=$(get_repo_version)
    
    local deployed_hash=$(echo "$deployed" | cut -d'|' -f1)
    local deployed_date=$(echo "$deployed" | cut -d'|' -f2)
    local deployed_branch=$(echo "$deployed" | cut -d'|' -f3)
    local is_optimized=$(echo "$deployed" | grep -q "optimized" && echo "yes" || echo "no")
    
    local current_hash=$(echo "$current" | cut -d'|' -f1)
    local current_date=$(echo "$current" | cut -d'|' -f2)
    local current_branch=$(echo "$current" | cut -d'|' -f3)
    
    echo -e "${CYAN}Deployed Version${NC}"
    echo -e "  Hash:      ${YELLOW}$deployed_hash${NC}"
    echo -e "  Date:      $deployed_date"
    echo -e "  Branch:    $deployed_branch"
    echo -e "  Optimized: $is_optimized"
    echo ""
    
    echo -e "${CYAN}Repo Version${NC}"
    echo -e "  Hash:      ${GREEN}$current_hash${NC}"
    echo -e "  Date:      $current_date"
    echo -e "  Branch:    $current_branch"
    echo ""
    
    echo -e "${CYAN}Target Directory${NC}"
    echo -e "  Path: $TARGET_DIR"
    echo ""
    
    # Check what's deployed
    echo -e "${CYAN}Deployed Components${NC}"
    for component in commands agents rules hooks skills schemas; do
        local path="$TARGET_DIR/$component"
        if [ -d "$path" ]; then
            local count=$(ls -1 "$path" 2>/dev/null | wc -l | tr -d ' ')
            local type="files"
            [ -L "$path" ] && type="(symlinked)"
            # Check if contents are symlinks
            local symlink_count=$(find "$path" -maxdepth 1 -type l 2>/dev/null | wc -l | tr -d ' ')
            [ "$symlink_count" -gt 0 ] && type="(${symlink_count} symlinked)"
            echo -e "  ${GREEN}✓${NC} $component: $count $type"
        else
            echo -e "  ${RED}✗${NC} $component: not deployed"
        fi
    done
    
    if [ -f "$TARGET_DIR/hooks.json" ]; then
        echo -e "  ${GREEN}✓${NC} hooks.json: present"
    else
        echo -e "  ${RED}✗${NC} hooks.json: not deployed"
    fi
    echo ""
    
    # Check for updates
    if [ "$deployed_hash" != "$current_hash" ] && [ "$deployed_hash" != "none" ]; then
        echo -e "${YELLOW}⚠ Updates available. Run --update to apply.${NC}"
    elif [ "$deployed_hash" = "none" ]; then
        echo -e "${YELLOW}⚠ Not yet deployed. Run without options to deploy.${NC}"
    else
        echo -e "${GREEN}✓ Up to date${NC}"
    fi
    echo ""
    
    # Show backups
    if [ -d "$BACKUP_DIR" ]; then
        local backup_count=$(ls -1 "$BACKUP_DIR" 2>/dev/null | wc -l | tr -d ' ')
        if [ "$backup_count" -gt 0 ]; then
            echo -e "${CYAN}Backups${NC}"
            echo -e "  Count: $backup_count"
            echo -e "  Latest: $(ls -1t "$BACKUP_DIR" 2>/dev/null | head -1)"
        fi
    fi
}

# Run
if [ "$RESTORE" = true ]; then
    restore_backup
elif [ "$STATUS" = true ]; then
    show_status
elif [ "$CHECK_ONLY" = true ]; then
    check_updates
    echo ""
    show_token_impact
elif [ "$UPDATE" = true ]; then
    smart_update
elif [ "$UNINSTALL" = true ]; then
    uninstall
else
    # Normal deploy
    if [ "$BACKUP" = true ]; then
        create_backup
    fi
    deploy
fi

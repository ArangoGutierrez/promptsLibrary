#!/bin/bash
#
# sync-optimized.sh - Sync main cursor configs with optimized versions
#
# Usage:
#   ./scripts/sync-optimized.sh [OPTIONS]
#
# Options:
#   --check       Check for drift without making changes (default)
#   --report      Generate detailed drift report
#   --list-missing List files in main but not in optimized
#   --create      Create stub optimized versions for missing files
#   --help        Show this help message
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
MAIN_DIR="$REPO_DIR/cursor"
OPT_DIR="$REPO_DIR/cursor/_optimized"
LAZY_DIR="$REPO_DIR/cursor/_lazy"

# Options
CHECK=true
REPORT=false
LIST_MISSING=false
CREATE_STUBS=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --check)
            CHECK=true
            shift
            ;;
        --report)
            REPORT=true
            shift
            ;;
        --list-missing)
            LIST_MISSING=true
            shift
            ;;
        --create)
            CREATE_STUBS=true
            shift
            ;;
        --help)
            cat << 'HELP'
sync-optimized.sh - Sync main cursor configs with optimized versions

Usage:
  ./scripts/sync-optimized.sh [OPTIONS]

Options:
  --check       Check for drift without making changes (default)
  --report      Generate detailed drift report
  --list-missing List files in main but not in optimized
  --create      Create stub optimized versions for missing files
  --help        Show this help message

Examples:
  ./scripts/sync-optimized.sh              # Check for drift
  ./scripts/sync-optimized.sh --report     # Detailed report
  ./scripts/sync-optimized.sh --list-missing  # Show missing files
  ./scripts/sync-optimized.sh --create     # Create stubs for missing
HELP
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Count lines in file
line_count() {
    wc -l < "$1" | tr -d ' '
}

# Calculate size difference percentage
size_diff_pct() {
    local main_size=$1
    local opt_size=$2
    if [ "$main_size" -eq 0 ]; then
        echo "N/A"
        return
    fi
    local diff=$((main_size - opt_size))
    local pct=$((diff * 100 / main_size))
    echo "$pct"
}

# Check a single component directory
check_component() {
    local component=$1
    local main_path="$MAIN_DIR/$component"
    local opt_path="$OPT_DIR/$component"
    
    local missing=0
    local drift=0
    local ok=0
    
    echo -e "${CYAN}=== $component ===${NC}"
    
    if [ ! -d "$main_path" ]; then
        echo -e "  ${YELLOW}Main directory not found${NC}"
        return
    fi
    
    # Find all files in main
    for main_file in "$main_path"/*.md; do
        [ -f "$main_file" ] || continue
        
        local filename=$(basename "$main_file")
        local opt_file="$opt_path/$filename"
        
        # Skip template
        [ "$filename" = "_TEMPLATE.md" ] && continue
        
        if [ ! -f "$opt_file" ]; then
            echo -e "  ${RED}MISSING${NC}: $filename"
            missing=$((missing + 1))
        else
            local main_lines=$(line_count "$main_file")
            local opt_lines=$(line_count "$opt_file")
            local reduction=$(size_diff_pct "$main_lines" "$opt_lines")
            
            if [ "$opt_lines" -gt "$main_lines" ]; then
                echo -e "  ${YELLOW}DRIFT${NC}: $filename (optimized LARGER: $opt_lines > $main_lines)"
                drift=$((drift + 1))
            elif [ "$reduction" -lt 20 ] 2>/dev/null; then
                echo -e "  ${YELLOW}WEAK${NC}: $filename (only ${reduction}% reduction: $main_lines → $opt_lines)"
                drift=$((drift + 1))
            else
                if [ "$REPORT" = true ]; then
                    echo -e "  ${GREEN}OK${NC}: $filename (${reduction}% reduction: $main_lines → $opt_lines)"
                fi
                ok=$((ok + 1))
            fi
        fi
    done
    
    echo ""
    echo -e "  Summary: ${GREEN}$ok OK${NC}, ${RED}$missing missing${NC}, ${YELLOW}$drift drift${NC}"
    echo ""
}

# Check skills (special structure)
check_skills() {
    local main_path="$MAIN_DIR/skills"
    local opt_path="$OPT_DIR/skills"
    
    local missing=0
    local drift=0
    local ok=0
    
    echo -e "${CYAN}=== skills ===${NC}"
    
    if [ ! -d "$main_path" ]; then
        echo -e "  ${YELLOW}Main directory not found${NC}"
        return
    fi
    
    for skill_dir in "$main_path"/*/; do
        [ -d "$skill_dir" ] || continue
        
        local skill_name=$(basename "$skill_dir")
        local main_file="$skill_dir/SKILL.md"
        local opt_file="$opt_path/$skill_name/SKILL.md"
        
        if [ ! -f "$main_file" ]; then
            continue
        fi
        
        if [ ! -f "$opt_file" ]; then
            echo -e "  ${RED}MISSING${NC}: $skill_name/SKILL.md"
            missing=$((missing + 1))
        else
            local main_lines=$(line_count "$main_file")
            local opt_lines=$(line_count "$opt_file")
            local reduction=$(size_diff_pct "$main_lines" "$opt_lines")
            
            if [ "$opt_lines" -gt "$main_lines" ]; then
                echo -e "  ${YELLOW}DRIFT${NC}: $skill_name (optimized LARGER)"
                drift=$((drift + 1))
            elif [ "$reduction" -lt 20 ] 2>/dev/null; then
                echo -e "  ${YELLOW}WEAK${NC}: $skill_name (only ${reduction}% reduction)"
                drift=$((drift + 1))
            else
                if [ "$REPORT" = true ]; then
                    echo -e "  ${GREEN}OK${NC}: $skill_name (${reduction}% reduction)"
                fi
                ok=$((ok + 1))
            fi
        fi
    done
    
    echo ""
    echo -e "  Summary: ${GREEN}$ok OK${NC}, ${RED}$missing missing${NC}, ${YELLOW}$drift drift${NC}"
    echo ""
}

# List all missing files
list_missing() {
    echo -e "${BLUE}=== Missing Optimized Versions ===${NC}"
    echo ""
    
    local total_missing=0
    
    for component in agents commands rules; do
        local main_path="$MAIN_DIR/$component"
        local opt_path="$OPT_DIR/$component"
        
        [ -d "$main_path" ] || continue
        
        for main_file in "$main_path"/*.md; do
            [ -f "$main_file" ] || continue
            
            local filename=$(basename "$main_file")
            local opt_file="$opt_path/$filename"
            
            # Skip template
            [ "$filename" = "_TEMPLATE.md" ] && continue
            
            if [ ! -f "$opt_file" ]; then
                local lines=$(line_count "$main_file")
                echo -e "${component}/${filename} (${lines} lines)"
                total_missing=$((total_missing + 1))
            fi
        done
    done
    
    # Skills
    for skill_dir in "$MAIN_DIR/skills"/*/; do
        [ -d "$skill_dir" ] || continue
        
        local skill_name=$(basename "$skill_dir")
        local main_file="$skill_dir/SKILL.md"
        local opt_file="$OPT_DIR/skills/$skill_name/SKILL.md"
        
        if [ -f "$main_file" ] && [ ! -f "$opt_file" ]; then
            local lines=$(line_count "$main_file")
            echo -e "skills/${skill_name}/SKILL.md (${lines} lines)"
            total_missing=$((total_missing + 1))
        fi
    done
    
    echo ""
    echo -e "${YELLOW}Total missing: $total_missing files${NC}"
}

# Create stub optimized versions
create_stubs() {
    echo -e "${BLUE}=== Creating Optimized Stubs ===${NC}"
    echo ""
    
    local created=0
    
    for component in agents commands rules; do
        local main_path="$MAIN_DIR/$component"
        local opt_path="$OPT_DIR/$component"
        
        [ -d "$main_path" ] || continue
        
        for main_file in "$main_path"/*.md; do
            [ -f "$main_file" ] || continue
            
            local filename=$(basename "$main_file")
            local opt_file="$opt_path/$filename"
            
            # Skip template
            [ "$filename" = "_TEMPLATE.md" ] && continue
            
            if [ ! -f "$opt_file" ]; then
                mkdir -p "$opt_path"
                
                # Extract frontmatter and first heading
                local title=$(grep -m1 "^# " "$main_file" || echo "# ${filename%.md}")
                local frontmatter=$(sed -n '1,/^---$/p' "$main_file" | head -20)
                
                cat > "$opt_file" << EOF
$frontmatter

$title

<!-- TODO: Create optimized version of $filename -->
<!-- Original: $(line_count "$main_file") lines -->
<!-- Target: ~$(($(line_count "$main_file") * 40 / 100)) lines (60% reduction) -->

See main version: cursor/$component/$filename
EOF
                
                echo -e "${GREEN}Created${NC}: _optimized/$component/$filename"
                created=$((created + 1))
            fi
        done
    done
    
    # Skills
    for skill_dir in "$MAIN_DIR/skills"/*/; do
        [ -d "$skill_dir" ] || continue
        
        local skill_name=$(basename "$skill_dir")
        local main_file="$skill_dir/SKILL.md"
        local opt_dir="$OPT_DIR/skills/$skill_name"
        local opt_file="$opt_dir/SKILL.md"
        
        if [ -f "$main_file" ] && [ ! -f "$opt_file" ]; then
            mkdir -p "$opt_dir"
            
            local frontmatter=$(sed -n '1,/^---$/p' "$main_file" | head -20)
            local title=$(grep -m1 "^# " "$main_file" || echo "# $skill_name")
            
            cat > "$opt_file" << EOF
$frontmatter

$title

<!-- TODO: Create optimized version -->
<!-- Original: $(line_count "$main_file") lines -->
<!-- Target: ~$(($(line_count "$main_file") * 40 / 100)) lines (60% reduction) -->

See main version: cursor/skills/$skill_name/SKILL.md
EOF
            
            echo -e "${GREEN}Created${NC}: _optimized/skills/$skill_name/SKILL.md"
            created=$((created + 1))
        fi
    done
    
    echo ""
    echo -e "${GREEN}Created $created stub files${NC}"
    echo -e "${YELLOW}Remember to manually optimize each stub!${NC}"
}

# Generate detailed report
generate_report() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║           Cursor Config Sync Report                        ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "Generated: $(date)"
    echo -e "Repository: $REPO_DIR"
    echo ""
    
    # Size comparison
    echo -e "${CYAN}=== Size Comparison ===${NC}"
    echo ""
    
    local main_total=0
    local opt_total=0
    
    for component in agents commands rules; do
        local main_size=0
        local opt_size=0
        
        if [ -d "$MAIN_DIR/$component" ]; then
            for f in "$MAIN_DIR/$component"/*.md; do
                [ -f "$f" ] && main_size=$((main_size + $(line_count "$f")))
            done
        fi
        
        if [ -d "$OPT_DIR/$component" ]; then
            for f in "$OPT_DIR/$component"/*.md; do
                [ -f "$f" ] && opt_size=$((opt_size + $(line_count "$f")))
            done
        fi
        
        main_total=$((main_total + main_size))
        opt_total=$((opt_total + opt_size))
        
        local reduction=$(size_diff_pct "$main_size" "$opt_size")
        printf "  %-12s Main: %4d lines  Opt: %4d lines  (-%s%%)\n" "$component" "$main_size" "$opt_size" "$reduction"
    done
    
    # Skills
    local main_skills=0
    local opt_skills=0
    if [ -d "$MAIN_DIR/skills" ]; then
        for skill_dir in "$MAIN_DIR/skills"/*/; do
            [ -f "$skill_dir/SKILL.md" ] && main_skills=$((main_skills + $(line_count "$skill_dir/SKILL.md")))
        done
    fi
    if [ -d "$OPT_DIR/skills" ]; then
        for skill_dir in "$OPT_DIR/skills"/*/; do
            [ -f "$skill_dir/SKILL.md" ] && opt_skills=$((opt_skills + $(line_count "$skill_dir/SKILL.md")))
        done
    fi
    main_total=$((main_total + main_skills))
    opt_total=$((opt_total + opt_skills))
    
    local skills_reduction=$(size_diff_pct "$main_skills" "$opt_skills")
    printf "  %-12s Main: %4d lines  Opt: %4d lines  (-%s%%)\n" "skills" "$main_skills" "$opt_skills" "$skills_reduction"
    
    echo ""
    local total_reduction=$(size_diff_pct "$main_total" "$opt_total")
    echo -e "  ${MAGENTA}TOTAL        Main: $main_total lines  Opt: $opt_total lines  (-${total_reduction}%)${NC}"
    echo ""
    
    # Token estimate
    local main_tokens=$((main_total * 4))
    local opt_tokens=$((opt_total * 4))
    echo -e "${CYAN}=== Token Estimate ===${NC}"
    echo ""
    echo -e "  Main version:      ~${YELLOW}${main_tokens}${NC} tokens"
    echo -e "  Optimized version: ~${GREEN}${opt_tokens}${NC} tokens"
    echo -e "  Savings:           ~${MAGENTA}$((main_tokens - opt_tokens))${NC} tokens"
    echo ""
}

# Main
echo -e "${BLUE}Cursor Config Sync Tool${NC}"
echo ""

if [ "$LIST_MISSING" = true ]; then
    list_missing
elif [ "$CREATE_STUBS" = true ]; then
    create_stubs
elif [ "$REPORT" = true ]; then
    generate_report
    echo ""
    check_component "agents"
    check_component "commands"
    check_component "rules"
    check_skills
else
    # Default: check mode
    check_component "agents"
    check_component "commands"
    check_component "rules"
    check_skills
    
    echo -e "${BLUE}Run with --report for detailed analysis${NC}"
    echo -e "${BLUE}Run with --list-missing to see all missing files${NC}"
    echo -e "${BLUE}Run with --create to generate stubs for missing files${NC}"
fi

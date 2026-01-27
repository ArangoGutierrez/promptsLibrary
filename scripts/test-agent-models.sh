#!/bin/bash
# Test script to validate agent model configurations

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
AGENTS_DIR="$PROJECT_ROOT/cursor/agents"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Testing Agent Model Configurations ===${NC}\n"

# Valid model values (based on Cursor documentation)
# Short names
VALID_SHORT_MODELS=("sonnet" "opus" "haiku" "fast" "inherit")
# Regex for full model IDs: claude-{variant}-{major}-{minor}-{date}
FULL_MODEL_REGEX='^claude-(sonnet|opus|haiku)-[0-9]+-[0-9]+-[0-9]+$'
# Legacy format: claude-{major}-{minor}-{variant}
LEGACY_MODEL_REGEX='^claude-[0-9]+-[0-9]+-(sonnet|opus|haiku)$'

ERRORS=0
WARNINGS=0

# Function to check if model value is valid
is_valid_model() {
    local model=$1

    # Check short names
    for valid in "${VALID_SHORT_MODELS[@]}"; do
        if [ "$model" = "$valid" ]; then
            return 0
        fi
    done

    # Check full model ID format
    if echo "$model" | grep -qE "$FULL_MODEL_REGEX"; then
        return 0
    fi

    # Check legacy model ID format
    if echo "$model" | grep -qE "$LEGACY_MODEL_REGEX"; then
        return 0
    fi

    return 1
}

# Function to extract frontmatter field
extract_field() {
    local file=$1
    local field=$2
    # Extract content between first and second '---' delimiters
    awk '/^---$/{if(++count==2)exit;next}count==1' "$file" | grep "^${field}:" | sed "s/^${field}://" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//'
}

echo -e "${BLUE}Checking agent files in: $AGENTS_DIR${NC}\n"

# Check each agent file
for file in "$AGENTS_DIR"/*.md; do
    if [ ! -f "$file" ]; then
        continue
    fi
    
    filename=$(basename "$file")
    echo -e "${BLUE}Checking: ${filename}${NC}"
    
    # Check for frontmatter
    if ! head -1 "$file" | grep -q '^---$'; then
        echo -e "  ${RED}❌ Missing frontmatter${NC}"
        ERRORS=$((ERRORS + 1))
        continue
    fi
    
    # Extract model field
    model=$(extract_field "$file" "model")
    
    if [ -z "$model" ]; then
        echo -e "  ${YELLOW}⚠️  Missing model field${NC}"
        WARNINGS=$((WARNINGS + 1))
    else
        echo -e "  Model: ${GREEN}${model}${NC}"
        
        # Check if model value is valid
        if ! is_valid_model "$model"; then
            echo -e "  ${RED}❌ Invalid model value: '${model}'${NC}"
            echo -e "  ${YELLOW}   Valid values: ${VALID_MODELS[*]}${NC}"
            ERRORS=$((ERRORS + 1))
        else
            echo -e "  ${GREEN}✓ Valid model${NC}"
        fi
    fi
    
    # Check for required fields
    name=$(extract_field "$file" "name")
    description=$(extract_field "$file" "description")
    
    if [ -z "$name" ]; then
        echo -e "  ${RED}❌ Missing name field${NC}"
        ERRORS=$((ERRORS + 1))
    fi
    
    if [ -z "$description" ]; then
        echo -e "  ${RED}❌ Missing description field${NC}"
        ERRORS=$((ERRORS + 1))
    fi
    
    echo ""
done

# Summary
echo -e "${BLUE}=== Summary ===${NC}"
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✅ All agent configurations are valid!${NC}"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠️  Found $WARNINGS warnings (non-critical)${NC}"
    exit 0
else
    echo -e "${RED}❌ Found $ERRORS errors and $WARNINGS warnings${NC}"
    exit 1
fi

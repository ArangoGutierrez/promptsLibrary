#!/bin/bash
# test-context-monitor.sh - Test suite for context monitor hooks
#
# Tests the context monitor and file tracker hooks in isolation
# without requiring a full Claude Code session.

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTEXT_MONITOR="$SCRIPT_DIR/context-monitor.sh"
FILE_TRACKER="$SCRIPT_DIR/context-monitor-file-tracker.sh"
TEST_DIR="/tmp/claude-context-monitor-test-$$"
STATE_FILE="$TEST_DIR/.claude/context-state.json"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Setup test environment
setup() {
    mkdir -p "$TEST_DIR"
    cd "$TEST_DIR"
    export HOME="$TEST_DIR"  # Override HOME for testing
}

# Cleanup test environment
cleanup() {
    cd /
    rm -rf "$TEST_DIR"
}

# Test helper functions
test_start() {
    local name="$1"
    echo -e "${BLUE}TEST: $name${NC}"
    TESTS_RUN=$((TESTS_RUN + 1))
}

test_pass() {
    echo -e "${GREEN}  ✓ PASS${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo ""
}

test_fail() {
    local reason="$1"
    echo -e "${RED}  ✗ FAIL: $reason${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo ""
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Expected '$expected' but got '$actual'}"

    if [ "$expected" = "$actual" ]; then
        return 0
    else
        test_fail "$message"
        return 1
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-Expected to find '$needle' in output}"

    if echo "$haystack" | grep -q "$needle"; then
        return 0
    else
        test_fail "$message"
        return 1
    fi
}

assert_file_exists() {
    local file="$1"
    local message="${2:-Expected file '$file' to exist}"

    if [ -f "$file" ]; then
        return 0
    else
        test_fail "$message"
        return 1
    fi
}

# Test: Prerequisites check
test_prerequisites() {
    test_start "Prerequisites (jq installed)"

    if command -v jq &> /dev/null; then
        test_pass
    else
        test_fail "jq not installed"
    fi
}

# Test: File tracker creates state on first run
test_file_tracker_init() {
    test_start "File tracker initializes state"

    # Clean state
    rm -rf .claude

    # Run file tracker
    echo '{"file_path":"test.go"}' | "$FILE_TRACKER"

    # Check state file exists
    if ! assert_file_exists "$STATE_FILE"; then
        return
    fi

    # Check state contains file
    local files=$(jq -r '.files_touched | length' "$STATE_FILE")
    if assert_equals "1" "$files" "Expected 1 file tracked"; then
        test_pass
    fi
}

# Test: File tracker deduplicates files
test_file_tracker_dedup() {
    test_start "File tracker deduplicates files"

    # Clean state
    rm -rf .claude

    # Track same file twice
    echo '{"file_path":"test.go"}' | "$FILE_TRACKER"
    echo '{"file_path":"test.go"}' | "$FILE_TRACKER"

    # Should still be 1 file
    local files=$(jq -r '.files_touched | length' "$STATE_FILE")
    if assert_equals "1" "$files" "Expected 1 unique file"; then
        test_pass
    fi
}

# Test: File tracker tracks multiple files
test_file_tracker_multiple() {
    test_start "File tracker tracks multiple unique files"

    # Clean state
    rm -rf .claude

    # Track different files
    echo '{"file_path":"test1.go"}' | "$FILE_TRACKER"
    echo '{"file_path":"test2.go"}' | "$FILE_TRACKER"
    echo '{"file_path":"test3.go"}' | "$FILE_TRACKER"

    # Should have 3 files
    local files=$(jq -r '.files_touched | length' "$STATE_FILE")
    if assert_equals "3" "$files" "Expected 3 unique files"; then
        test_pass
    fi
}

# Test: Context monitor creates state on first run
test_context_monitor_init() {
    test_start "Context monitor initializes state"

    # Clean state
    rm -rf .claude

    # Run context monitor
    local output=$(echo '{"status":"completed","loop_count":1,"conversation_id":"test123"}' | "$CONTEXT_MONITOR")

    # Check state file exists
    if ! assert_file_exists "$STATE_FILE"; then
        return
    fi

    # Check conversation_id
    local conv_id=$(jq -r '.conversation_id' "$STATE_FILE")
    if assert_equals "test123" "$conv_id" "Expected conversation_id to match"; then
        test_pass
    fi
}

# Test: Context monitor tracks iterations
test_context_monitor_iterations() {
    test_start "Context monitor tracks iterations"

    # Clean state
    rm -rf .claude

    # Run multiple times
    echo '{"status":"completed","loop_count":1,"conversation_id":"test123"}' | "$CONTEXT_MONITOR" > /dev/null
    echo '{"status":"completed","loop_count":2,"conversation_id":"test123"}' | "$CONTEXT_MONITOR" > /dev/null
    echo '{"status":"completed","loop_count":3,"conversation_id":"test123"}' | "$CONTEXT_MONITOR" > /dev/null

    # Check iterations
    local iterations=$(jq -r '.iterations' "$STATE_FILE")
    if assert_equals "3" "$iterations" "Expected 3 iterations"; then
        test_pass
    fi
}

# Test: Context monitor detects healthy state
test_context_monitor_healthy() {
    test_start "Context monitor reports healthy state (no warning)"

    # Clean state
    rm -rf .claude

    # Run with low iteration count
    local output=$(echo '{"status":"completed","loop_count":1,"conversation_id":"test123"}' | "$CONTEXT_MONITOR")

    # Should return empty response (no warning)
    if assert_equals "{}" "$output" "Expected no warning for healthy state"; then
        test_pass
    fi
}

# Test: Context monitor detects filling state
test_context_monitor_filling() {
    test_start "Context monitor detects filling state"

    # Clean state
    rm -rf .claude

    # Add many files to reach filling state
    for i in {1..15}; do
        echo "{\"file_path\":\"test$i.go\"}" | "$FILE_TRACKER" > /dev/null
    done

    # Run with high iteration count to reach filling state
    for i in {1..10}; do
        echo '{"status":"completed","loop_count":'$i',"conversation_id":"test123"}' | "$CONTEXT_MONITOR" > /dev/null
    done

    # Final call should produce warning
    local output=$(echo '{"status":"completed","loop_count":11,"conversation_id":"test123"}' | "$CONTEXT_MONITOR")

    # Should contain followup_message
    if echo "$output" | jq -e '.followup_message' > /dev/null 2>&1; then
        local msg=$(echo "$output" | jq -r '.followup_message')
        if assert_contains "$msg" "Context" "Expected context warning message"; then
            test_pass
        fi
    else
        test_fail "Expected followup_message in output"
    fi
}

# Test: Context monitor detects stuck state
test_context_monitor_stuck() {
    test_start "Context monitor detects stuck state"

    # Clean state
    rm -rf .claude

    # Run many iterations without file edits
    for i in {1..7}; do
        echo '{"status":"completed","loop_count":'$i',"conversation_id":"test123"}' | "$CONTEXT_MONITOR" > /dev/null
    done

    # Should produce stuck warning
    local output=$(echo '{"status":"completed","loop_count":8,"conversation_id":"test123"}' | "$CONTEXT_MONITOR")
    local msg=$(echo "$output" | jq -r '.followup_message // empty')

    if [ -n "$msg" ] && assert_contains "$msg" "No recent file edits" "Expected stuck warning"; then
        test_pass
    else
        test_fail "Expected stuck warning after 5+ iterations without file edits"
    fi
}

# Test: Context monitor resets on new conversation
test_context_monitor_reset() {
    test_start "Context monitor resets on new conversation"

    # Clean state
    rm -rf .claude

    # Run with first conversation
    echo '{"status":"completed","loop_count":5,"conversation_id":"conv1"}' | "$CONTEXT_MONITOR" > /dev/null

    local iterations1=$(jq -r '.iterations' "$STATE_FILE")

    # Run with new conversation
    echo '{"status":"completed","loop_count":1,"conversation_id":"conv2"}' | "$CONTEXT_MONITOR" > /dev/null

    local iterations2=$(jq -r '.iterations' "$STATE_FILE")

    # Iterations should reset to 1
    if assert_equals "1" "$iterations2" "Expected iterations to reset for new conversation"; then
        test_pass
    fi
}

# Test: Security - path traversal blocked
test_security_path_traversal() {
    test_start "Security: Path traversal blocked"

    # Clean state
    rm -rf .claude

    # Try path traversal
    echo '{"file_path":"../../etc/passwd"}' | "$FILE_TRACKER" > /dev/null

    # State should not contain the malicious path
    if [ ! -f "$STATE_FILE" ]; then
        # State not created (good)
        test_pass
        return
    fi

    local files=$(jq -r '.files_touched | length' "$STATE_FILE" 2>/dev/null || echo "0")
    if assert_equals "0" "$files" "Expected path traversal to be blocked"; then
        test_pass
    fi
}

# Test: Config file override
test_config_override() {
    test_start "Config file overrides defaults"

    # Clean state
    rm -rf .claude

    # Create custom config
    mkdir -p "$TEST_DIR/.claude"
    cat > "$TEST_DIR/.claude/context-config.json" << 'EOF'
{
  "thresholds": {
    "healthy_max": 10,
    "filling_max": 20,
    "critical_max": 30
  }
}
EOF

    # Run with low iterations (would be healthy with defaults, but filling with custom)
    for i in {1..3}; do
        echo '{"status":"completed","loop_count":'$i',"conversation_id":"test123"}' | "$CONTEXT_MONITOR" > /dev/null
    done

    local output=$(echo '{"status":"completed","loop_count":4,"conversation_id":"test123"}' | "$CONTEXT_MONITOR")

    # Should produce warning due to lower threshold
    if echo "$output" | jq -e '.followup_message' > /dev/null 2>&1; then
        test_pass
    else
        test_fail "Expected warning with custom low thresholds"
    fi
}

# Test: Non-completed status ignored
test_ignore_non_completed() {
    test_start "Non-completed status ignored"

    # Clean state
    rm -rf .claude

    # Run with non-completed status
    local output=$(echo '{"status":"pending","loop_count":1,"conversation_id":"test123"}' | "$CONTEXT_MONITOR")

    # Should return empty response
    if assert_equals "{}" "$output" "Expected empty response for non-completed status"; then
        # State file should not be created
        if [ ! -f "$STATE_FILE" ]; then
            test_pass
        else
            test_fail "State file should not be created for non-completed status"
        fi
    fi
}

# Run all tests
run_tests() {
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Context Monitor Test Suite${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo ""

    # Check hooks exist
    if [ ! -f "$CONTEXT_MONITOR" ]; then
        echo -e "${RED}Error: $CONTEXT_MONITOR not found${NC}"
        exit 1
    fi

    if [ ! -f "$FILE_TRACKER" ]; then
        echo -e "${RED}Error: $FILE_TRACKER not found${NC}"
        exit 1
    fi

    # Run tests
    test_prerequisites
    test_file_tracker_init
    test_file_tracker_dedup
    test_file_tracker_multiple
    test_context_monitor_init
    test_context_monitor_iterations
    test_context_monitor_healthy
    test_context_monitor_filling
    test_context_monitor_stuck
    test_context_monitor_reset
    test_security_path_traversal
    test_config_override
    test_ignore_non_completed

    # Summary
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Test Summary${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  Tests run:    $TESTS_RUN"
    echo -e "  ${GREEN}Tests passed: $TESTS_PASSED${NC}"
    if [ "$TESTS_FAILED" -gt 0 ]; then
        echo -e "  ${RED}Tests failed: $TESTS_FAILED${NC}"
    else
        echo -e "  Tests failed: $TESTS_FAILED"
    fi
    echo ""

    if [ "$TESTS_FAILED" -eq 0 ]; then
        echo -e "${GREEN}✓ All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}✗ Some tests failed${NC}"
        return 1
    fi
}

# Main
main() {
    # Trap to ensure cleanup
    trap cleanup EXIT

    setup
    run_tests
}

main

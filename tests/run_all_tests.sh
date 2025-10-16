#!/usr/bin/env bash

# Master test runner for dotfiles project
# Executes all test suites and provides summary

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TOTAL_PASSED=0
TOTAL_FAILED=0

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Dotfiles Test Suite Runner          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

# Define test suites
TEST_SUITES=(
    "test_symlinks.sh:Symlink Management"
    "test_setup.sh:Setup Script"
    "test_gnome_session.sh:GNOME Session"
)

for test_spec in "${TEST_SUITES[@]}"; do
    IFS=':' read -r test_file test_name <<< "$test_spec"
    test_path="$SCRIPT_DIR/$test_file"
    
    if [[ -f "$test_path" ]]; then
        echo -e "${BLUE}Running: $test_name${NC}"
        echo "─────────────────────────────────────────"
        
        if bash "$test_path"; then
            echo -e "${GREEN}✓ $test_name passed${NC}"
        else
            echo -e "${RED}✗ $test_name failed${NC}"
        fi
        echo ""
    fi
done

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Test Suite Complete                 ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"

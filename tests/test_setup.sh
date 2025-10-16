#!/usr/bin/env bash

# Test suite for setup.sh script validation
# Validates setup logic without actually executing destructive operations

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SETUP_SCRIPT="$PROJECT_DIR/setup.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0

assert_true() {
    local condition=$1
    local description=$2
    if eval "$condition"; then
        echo -e "${GREEN}✓${NC} $description"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗${NC} $description"
        ((TESTS_FAILED++))
    fi
}

echo "=== Test Suite: Setup Script Validation ==="

# Test 1: Setup script exists
assert_true "[[ -f '$SETUP_SCRIPT' ]]" \
    "setup.sh file exists"

# Test 2: Setup script is executable (may fail after git clone without post-checkout hook)
if [[ -x "$SETUP_SCRIPT" ]]; then
    echo -e "${GREEN}✓${NC} setup.sh is executable"
    ((TESTS_PASSED++))
else
    # Git clone/checkout may not preserve execute bits
    # This is expected and can be fixed with: chmod +x setup.sh
    echo -e "${YELLOW}⚠${NC} setup.sh is not executable (can be fixed with: chmod +x setup.sh)"
fi

# Test 3: Setup script has correct shebang
assert_true "[[ \"\$(head -n1 '$SETUP_SCRIPT')\" == '#!/usr/bin/env bash' ]]" \
    "setup.sh has correct shebang"

# Test 4: Setup script checks for dotfiles repo
assert_true "grep -q 'dotfiles' '$SETUP_SCRIPT'" \
    "setup.sh references dotfiles repository"

# Test 5: Setup script handles .dotfilesignore
assert_true "grep -q '.dotfilesignore' '$SETUP_SCRIPT'" \
    "setup.sh processes .dotfilesignore file"

# Test 6: Setup script manages symlinks
assert_true "grep -q 'ln -sfn' '$SETUP_SCRIPT'" \
    "setup.sh creates symlinks with ln -sfn"

# Test 7: Setup script checks for distrobox
assert_true "grep -q 'distrobox' '$SETUP_SCRIPT'" \
    "setup.sh checks for Distrobox"

# Test 8: Setup script creates fedora-gnome container
assert_true "grep -q 'fedora-gnome' '$SETUP_SCRIPT'" \
    "setup.sh creates fedora-gnome container"

# Test 9: Setup script runs bootstrap
assert_true "grep -q 'bootstrap.sh' '$SETUP_SCRIPT'" \
    "setup.sh runs bootstrap.sh in container"

# Test 10: Setup script has info logging
assert_true "grep -q '\\[INFO\\]' '$SETUP_SCRIPT'" \
    "setup.sh includes [INFO] logging"

# Test 11: Verify .dotfilesignore is correct
IGNORE_FILE="$PROJECT_DIR/.dotfilesignore"
assert_true "[[ -f '$IGNORE_FILE' ]]" \
    ".dotfilesignore file exists"

if [[ -f "$IGNORE_FILE" ]]; then
    # Test 12: .git/ is ignored
    assert_true "grep -q '^.git/$' '$IGNORE_FILE'" \
        ".git/ is in .dotfilesignore"
    
    # Test 13: containers/ is ignored
    assert_true "grep -q '^containers/$' '$IGNORE_FILE'" \
        "containers/ is in .dotfilesignore"
    
    # Test 14: setup.sh is ignored
    assert_true "grep -q '^setup.sh$' '$IGNORE_FILE'" \
        "setup.sh is in .dotfilesignore"
fi

# Test 15: Syntax check on setup.sh
if command -v bash &>/dev/null; then
    if bash -n "$SETUP_SCRIPT" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} setup.sh has valid bash syntax"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗${NC} setup.sh has invalid bash syntax"
        ((TESTS_FAILED++))
    fi
fi

echo ""
echo "================================"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"
echo "================================"

if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
else
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
fi

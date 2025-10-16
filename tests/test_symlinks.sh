#!/usr/bin/env bash

# Test suite for dotfiles symlink management
# Tests the core symlink creation and validation

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TEST_TMPDIR="/tmp/dotfiles-test-$$"
DOTFILES_IGNORE="$PROJECT_DIR/.dotfilesignore"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

# Cleanup function
cleanup() {
    if [[ -d "$TEST_TMPDIR" ]]; then
        rm -rf "$TEST_TMPDIR"
    fi
}

trap cleanup EXIT

# Helper function for assertions
assert_file_exists() {
    local file=$1
    local description=$2
    if [[ -f "$file" ]]; then
        echo -e "${GREEN}✓${NC} $description"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗${NC} $description (file not found: $file)"
        ((TESTS_FAILED++))
    fi
}

assert_symlink_exists() {
    local symlink=$1
    local description=$2
    if [[ -L "$symlink" ]]; then
        echo -e "${GREEN}✓${NC} $description"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗${NC} $description (symlink not found: $symlink)"
        ((TESTS_FAILED++))
    fi
}

assert_symlink_target() {
    local symlink=$1
    local expected_target=$2
    local description=$3
    local actual_target=$(readlink "$symlink" 2>/dev/null || echo "")
    if [[ "$actual_target" == "$expected_target" ]]; then
        echo -e "${GREEN}✓${NC} $description"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗${NC} $description (expected: $expected_target, got: $actual_target)"
        ((TESTS_FAILED++))
    fi
}

# Test 1: Verify .dotfilesignore file exists
echo "=== Test Suite: Symlink Management ==="
assert_file_exists "$DOTFILES_IGNORE" ".dotfilesignore file exists"

# Test 2: Check that ignore patterns are not empty
if [[ -s "$DOTFILES_IGNORE" ]]; then
    echo -e "${GREEN}✓${NC} .dotfilesignore has content"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗${NC} .dotfilesignore is empty"
    ((TESTS_FAILED++))
fi

# Test 3: Verify critical files that should NOT be ignored
echo ""
echo "=== Test: Critical files should not be in .dotfilesignore ==="
CRITICAL_FILES=("etc/profile.d/fix_tmp.sh" "usr/local/bin/distrobox-gnome-session.sh")
for file in "${CRITICAL_FILES[@]}"; do
    if ! grep -Fxq "$file" "$DOTFILES_IGNORE"; then
        echo -e "${GREEN}✓${NC} $file is NOT ignored (correct)"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗${NC} $file is ignored (should not be)"
        ((TESTS_FAILED++))
    fi
done

# Test 4: Verify files that SHOULD be ignored
echo ""
echo "=== Test: Files should be in .dotfilesignore ==="
IGNORED_FILES=(".git/" "containers/" "setup.sh" "README.md")
for file in "${IGNORED_FILES[@]}"; do
    if grep -Fxq "$file" "$DOTFILES_IGNORE"; then
        echo -e "${GREEN}✓${NC} $file is ignored (correct)"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗${NC} $file is NOT ignored (should be)"
        ((TESTS_FAILED++))
    fi
done

# Test 5: Check file structure validity
echo ""
echo "=== Test: File structure validity ==="
REQUIRED_DIRS=("etc/profile.d" "usr/local/bin" "usr/share/wayland-sessions" "containers/gnome" "home/atzufuki")
for dir in "${REQUIRED_DIRS[@]}"; do
    if [[ -d "$PROJECT_DIR/$dir" ]]; then
        echo -e "${GREEN}✓${NC} Directory exists: $dir"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗${NC} Directory missing: $dir"
        ((TESTS_FAILED++))
    fi
done

# Test 6: Verify shell scripts have correct shebang
echo ""
echo "=== Test: Shell script shebangs ==="
SHELL_SCRIPTS=(
    "etc/profile.d/fix_tmp.sh"
    "containers/gnome/bootstrap.sh"
    "usr/local/bin/distrobox-gnome-session.sh"
)
for script in "${SHELL_SCRIPTS[@]}"; do
    if [[ -f "$PROJECT_DIR/$script" ]]; then
        first_line=$(head -n1 "$PROJECT_DIR/$script")
        if [[ "$first_line" == "#!/usr/bin/env bash" ]] || [[ "$first_line" == "#!/bin/bash" ]]; then
            echo -e "${GREEN}✓${NC} $script has correct shebang"
            ((TESTS_PASSED++))
        else
            echo -e "${RED}✗${NC} $script has invalid shebang: $first_line"
            ((TESTS_FAILED++))
        fi
    fi
done

# Test 7: Verify shell scripts are executable
echo ""
echo "=== Test: Shell script permissions ==="
for script in "${SHELL_SCRIPTS[@]}"; do
    if [[ -f "$PROJECT_DIR/$script" ]]; then
        if [[ -x "$PROJECT_DIR/$script" ]]; then
            echo -e "${GREEN}✓${NC} $script is executable"
            ((TESTS_PASSED++))
        else
            echo -e "${YELLOW}⚠${NC} $script is not executable (warning)"
        fi
    fi
done

# Test 8: Validate desktop file format
echo ""
echo "=== Test: Desktop file validation ==="
DESKTOP_FILE="$PROJECT_DIR/usr/share/wayland-sessions/distrobox-gnome.desktop"
if [[ -f "$DESKTOP_FILE" ]]; then
    REQUIRED_KEYS=("Name" "Comment" "Exec" "Type" "DesktopNames")
    for key in "${REQUIRED_KEYS[@]}"; do
        if grep -q "^$key=" "$DESKTOP_FILE"; then
            echo -e "${GREEN}✓${NC} Desktop file has '$key' entry"
            ((TESTS_PASSED++))
        else
            echo -e "${RED}✗${NC} Desktop file missing '$key' entry"
            ((TESTS_FAILED++))
        fi
    done
fi

# Final report
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

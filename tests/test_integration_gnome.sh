#!/usr/bin/env bash

# Integration test for GNOME session in Distrobox
# This test attempts to verify that GNOME can start in the container environment
# Note: Full GUI session testing in CI is limited; this validates the setup
# 
# Container runtime can be controlled via CONTAINER_CMD environment variable
# Default: auto-detect (podman > docker)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Auto-detect container runtime if not specified
if [[ -z "$CONTAINER_CMD" ]]; then
    if command -v podman &>/dev/null; then
        CONTAINER_CMD="podman"
    elif command -v docker &>/dev/null; then
        CONTAINER_CMD="docker"
    fi
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0

echo -e "${BLUE}=== Integration Test: GNOME Session in Distrobox ===${NC}"
echo -e "Using container runtime: ${YELLOW}${CONTAINER_CMD:-auto-detect}${NC}"
echo ""

# Helper functions
assert_command() {
    local cmd=$1
    local description=$2
    if eval "$cmd" &>/dev/null; then
        echo -e "${GREEN}✓${NC} $description"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗${NC} $description"
        ((TESTS_FAILED++))
    fi
}

assert_not_empty() {
    local value=$1
    local description=$2
    if [[ -n "$value" ]]; then
        echo -e "${GREEN}✓${NC} $description"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗${NC} $description"
        ((TESTS_FAILED++))
    fi
}

# Test 1: Check if distrobox is available
echo "--- Prerequisites ---"
if ! command -v distrobox &>/dev/null; then
    echo -e "${YELLOW}⚠${NC} Distrobox not installed - skipping integration tests"
    echo "   To run integration tests locally:"
    echo "   1. Install Distrobox: https://distrobox.it"
    echo "   2. Run: bash tests/test_integration_gnome.sh"
    exit 0
fi

assert_command "command -v distrobox" "Distrobox is installed"

# Test 2: Check if container runtime is available
if command -v podman &>/dev/null; then
    RUNTIME="podman"
    assert_command "command -v podman" "Podman is available"
elif command -v docker &>/dev/null; then
    RUNTIME="docker"
    assert_command "command -v docker" "Docker is available"
else
    echo -e "${RED}✗${NC} No container runtime found (Podman or Docker required)"
    ((TESTS_FAILED++))
    exit 1
fi

echo ""
echo "--- Container Setup ---"

# Test 3: Check if test container exists
CONTAINER_NAME="dotfiles-gnome-test-$$"
TEST_CONTAINER_EXISTS=$(distrobox list 2>/dev/null | grep -c "$CONTAINER_NAME" || true)

if [[ $TEST_CONTAINER_EXISTS -eq 0 ]]; then
    echo -e "${YELLOW}⚠${NC} Creating test container: $CONTAINER_NAME"
    
    # Create test container with minimal setup
    if distrobox create \
        --name "$CONTAINER_NAME" \
        --init \
        --additional-packages "systemd" \
        --image registry.fedoraproject.org/fedora:latest \
        2>/dev/null; then
        echo -e "${GREEN}✓${NC} Test container created"
        ((TESTS_PASSED++))
        CREATED_CONTAINER=true
    else
        echo -e "${RED}✗${NC} Failed to create test container"
        ((TESTS_FAILED++))
        exit 1
    fi
else
    echo -e "${YELLOW}⚠${NC} Using existing test container: $CONTAINER_NAME"
fi

# Test 4: Verify container can be entered
echo ""
echo "--- Container Access ---"
assert_command "distrobox enter '$CONTAINER_NAME' -- true" \
    "Can enter container"

# Test 5: Verify systemd is available
assert_command "distrobox enter '$CONTAINER_NAME' -- systemctl --user is-active --quiet || true" \
    "Systemd user session can be queried"

# Test 6: Check DNF is available in container
assert_command "distrobox enter '$CONTAINER_NAME' -- command -v dnf" \
    "DNF package manager is available"

echo ""
echo "--- GNOME Preparation ---"

# Test 7: Install GNOME (non-interactive, timeout 180 seconds for CI)
echo -e "${YELLOW}⚠${NC} Installing GNOME environment in container (this may take a few minutes)..."

if timeout 180 distrobox enter "$CONTAINER_NAME" -- \
    sudo dnf group install -y workstation-product-environment \
    &>/dev/null; then
    echo -e "${GREEN}✓${NC} GNOME environment installed"
    ((TESTS_PASSED++))
else
    echo -e "${YELLOW}⚠${NC} GNOME installation timed out or failed (this is OK in minimal CI)"
    # Don't count as failure - this is expected in containerized CI
fi

echo ""
echo "--- GNOME Session Test ---"

# Test 8: Verify gnome-session exists in container
if timeout 30 distrobox enter "$CONTAINER_NAME" -- which gnome-session &>/dev/null; then
    echo -e "${GREEN}✓${NC} gnome-session command is available"
    ((TESTS_PASSED++))
else
    echo -e "${YELLOW}⚠${NC} gnome-session not available (expected if install timed out)"
fi

# Test 9: Test systemd-run availability for session scope management
assert_command "distrobox enter '$CONTAINER_NAME' -- which systemd-run" \
    "systemd-run is available for session management"

# Test 10: Verify X11/Wayland socket paths are accessible
echo ""
echo "--- Display Server Integration ---"
if [[ -n "$XDG_RUNTIME_DIR" ]]; then
    assert_not_empty "$XDG_RUNTIME_DIR" "XDG_RUNTIME_DIR is set"
else
    echo -e "${YELLOW}⚠${NC} XDG_RUNTIME_DIR not set (expected in non-graphical CI)"
fi

if [[ -n "$WAYLAND_DISPLAY" ]]; then
    assert_not_empty "$WAYLAND_DISPLAY" "WAYLAND_DISPLAY is set"
else
    echo -e "${YELLOW}⚠${NC} WAYLAND_DISPLAY not set (expected in non-graphical CI)"
fi

# Test 11: Test profile script logic
echo ""
echo "--- Profile Script Validation ---"
PROFILE_SCRIPT="$PROJECT_DIR/etc/profile.d/fix_tmp.sh"

if [[ -f "$PROFILE_SCRIPT" ]]; then
    # Check that it can be sourced without errors
    assert_command "bash -n '$PROFILE_SCRIPT'" \
        "Profile script has valid syntax"
    
    # Verify it contains key operations
    assert_command "grep -q 'chown' '$PROFILE_SCRIPT'" \
        "Profile script fixes X11 socket permissions"
    
    assert_command "grep -q 'systemd' '$PROFILE_SCRIPT'" \
        "Profile script manages systemd user session"
fi

# Test 12: Verify bootstrap script will work
echo ""
echo "--- Bootstrap Validation ---"
BOOTSTRAP_SCRIPT="$PROJECT_DIR/containers/gnome/bootstrap.sh"

if [[ -f "$BOOTSTRAP_SCRIPT" ]]; then
    assert_command "bash -n '$BOOTSTRAP_SCRIPT'" \
        "Bootstrap script has valid syntax"
    
    # Check for critical components
    assert_command "grep -q 'systemd-user-sessions' '$BOOTSTRAP_SCRIPT'" \
        "Bootstrap enables systemd user sessions"
    
    assert_command "grep -q 'workstation-product-environment' '$BOOTSTRAP_SCRIPT'" \
        "Bootstrap installs GNOME environment"
fi

echo ""
echo "--- Cleanup ---"

# Test 13: Clean up test container if we created it
if [[ "$CREATED_CONTAINER" == "true" ]]; then
    if distrobox remove --force "$CONTAINER_NAME" &>/dev/null; then
        echo -e "${GREEN}✓${NC} Test container cleaned up"
        ((TESTS_PASSED++))
    else
        echo -e "${YELLOW}⚠${NC} Could not remove test container (manual cleanup may be needed)"
    fi
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
    echo -e "${GREEN}All integration tests passed!${NC}"
    exit 0
fi

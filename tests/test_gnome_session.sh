#!/usr/bin/env bash

# Test suite for GNOME session configuration in Distrobox
# Validates session launcher and bootstrap configuration

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

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

assert_command_exists() {
    local command=$1
    local description=$2
    if command -v "$command" &>/dev/null; then
        echo -e "${GREEN}✓${NC} Command exists: $description"
        ((TESTS_PASSED++))
    else
        echo -e "${YELLOW}⚠${NC} Command not available: $description (expected in container)"
    fi
}

echo "=== Test Suite: GNOME Session Configuration ==="

# Test 1: Session launcher exists
assert_true "[[ -f '$PROJECT_DIR/usr/local/bin/distrobox-gnome-session.sh' ]]" \
    "Session launcher script exists"

# Test 2: Desktop entry exists
assert_true "[[ -f '$PROJECT_DIR/usr/share/wayland-sessions/distrobox-gnome.desktop' ]]" \
    "Desktop entry file exists"

# Test 3: Bootstrap script exists
assert_true "[[ -f '$PROJECT_DIR/containers/gnome/bootstrap.sh' ]]" \
    "Bootstrap script exists"

# Test 4: Session launcher is executable
assert_true "[[ -x '$PROJECT_DIR/usr/local/bin/distrobox-gnome-session.sh' ]]" \
    "Session launcher is executable"

# Test 5: Session launcher uses distrobox-enter
assert_true "grep -q 'distrobox-enter' '$PROJECT_DIR/usr/local/bin/distrobox-gnome-session.sh'" \
    "Session launcher calls distrobox-enter"

# Test 6: Session launcher references fedora-gnome container
assert_true "grep -q 'fedora-gnome' '$PROJECT_DIR/usr/local/bin/distrobox-gnome-session.sh'" \
    "Session launcher references fedora-gnome container"

# Test 7: Session launcher uses gnome-session
assert_true "grep -q 'gnome-session' '$PROJECT_DIR/usr/local/bin/distrobox-gnome-session.sh'" \
    "Session launcher starts gnome-session"

# Test 8: Desktop file has X-GDM-SessionRegisters flag
assert_true "grep -q 'X-GDM-SessionRegisters=true' '$PROJECT_DIR/usr/share/wayland-sessions/distrobox-gnome.desktop'" \
    "Desktop file registers with GDM"

# Test 9: Desktop file is valid
assert_true "grep -q '^\\[Desktop Entry\\]' '$PROJECT_DIR/usr/share/wayland-sessions/distrobox-gnome.desktop'" \
    "Desktop file has valid format"

# Test 10: Bootstrap script updates system
assert_true "grep -q 'dnf update' '$PROJECT_DIR/containers/gnome/bootstrap.sh'" \
    "Bootstrap script updates packages"

# Test 11: Bootstrap script installs GNOME
assert_true "grep -q 'workstation-product-environment' '$PROJECT_DIR/containers/gnome/bootstrap.sh'" \
    "Bootstrap script installs GNOME environment"

# Test 12: Bootstrap script enables systemd user sessions
assert_true "grep -q 'systemd-user-sessions' '$PROJECT_DIR/containers/gnome/bootstrap.sh'" \
    "Bootstrap script enables systemd user sessions"

# Test 13: fix_tmp.sh fixes X11 socket permissions
assert_true "grep -q 'chown.*X11-unix' '$PROJECT_DIR/etc/profile.d/fix_tmp.sh'" \
    "Profile script fixes X11 socket permissions"

# Test 14: fix_tmp.sh starts systemd user session
assert_true "grep -q 'systemd.*user' '$PROJECT_DIR/etc/profile.d/fix_tmp.sh'" \
    "Profile script starts systemd user session"

# Test 15: Verify distrobox is available (warning if not)
if command -v distrobox &>/dev/null; then
    echo -e "${GREEN}✓${NC} Distrobox is installed"
    ((TESTS_PASSED++))
    
    # Test 16: Check if container exists
    if distrobox list | grep -q fedora-gnome; then
        echo -e "${GREEN}✓${NC} fedora-gnome container exists"
        ((TESTS_PASSED++))
        
        # Test 17: Container is running (check if we can enter it)
        if timeout 5 distrobox enter fedora-gnome -- true 2>/dev/null; then
            echo -e "${GREEN}✓${NC} Can enter fedora-gnome container"
            ((TESTS_PASSED++))
        else
            echo -e "${YELLOW}⚠${NC} Cannot enter container (may not be running)"
        fi
    else
        echo -e "${YELLOW}⚠${NC} fedora-gnome container not found (not created yet)"
    fi
else
    echo -e "${YELLOW}⚠${NC} Distrobox not installed (skip container tests)"
fi

echo ""
echo "================================"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"
echo "================================"

if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
else
    echo -e "${GREEN}All critical tests passed!${NC}"
    exit 0
fi

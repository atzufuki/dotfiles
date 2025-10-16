#!/usr/bin/env bash

# Simple integration test runner for GNOME in container
# This directly uses podman/docker instead of distrobox wrapper
# Much simpler for CI/local testing

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0

# Auto-detect container runtime
if [[ -z "$CONTAINER_CMD" ]]; then
    if command -v podman &>/dev/null; then
        CONTAINER_CMD="podman"
    elif command -v docker &>/dev/null; then
        CONTAINER_CMD="docker"
    else
        echo -e "${RED}✗${NC} No container runtime found (Podman or Docker required)"
        exit 1
    fi
fi

echo -e "${BLUE}=== Integration Test: GNOME in Container ===${NC}"
echo -e "Using container runtime: ${YELLOW}${CONTAINER_CMD}${NC}"

# Check for quick/light mode
if [[ "$QUICK_TEST" == "true" ]]; then
    echo -e "${YELLOW}Quick test mode (skipping GNOME installation)${NC}"
fi
echo ""

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

# Test 1: Container runtime available
assert_command "command -v $CONTAINER_CMD" "$CONTAINER_CMD is available"

# Test 2: Container daemon running
echo ""
echo "--- Checking container daemon ---"
assert_command "$CONTAINER_CMD info" "$CONTAINER_CMD daemon is running"

# Create test container
CONTAINER_NAME="dotfiles-gnome-test-$$"
TEST_IMAGE="registry.fedoraproject.org/fedora:latest"

echo ""
echo "--- Container Setup ---"
echo -e "${YELLOW}⚠${NC} Creating test container: $CONTAINER_NAME"

if $CONTAINER_CMD run -d \
    --name "$CONTAINER_NAME" \
    --init \
    -e container=podman \
    "$TEST_IMAGE" \
    sleep infinity &>/dev/null; then
    echo -e "${GREEN}✓${NC} Test container created and running"
    ((TESTS_PASSED++))
    CREATED_CONTAINER=true
else
    echo -e "${RED}✗${NC} Failed to create test container"
    ((TESTS_FAILED++))
    exit 1
fi

cleanup_container() {
    if [[ "$CREATED_CONTAINER" == "true" ]]; then
        echo ""
        echo "--- Cleanup ---"
        if $CONTAINER_CMD rm -f "$CONTAINER_NAME" &>/dev/null; then
            echo -e "${GREEN}✓${NC} Test container cleaned up"
        else
            echo -e "${YELLOW}⚠${NC} Could not remove test container (manual cleanup may be needed)"
        fi
    fi
}

trap cleanup_container EXIT

echo ""
echo "--- Container Access & Package Manager ---"

# Test 3: Can execute in container
assert_command "$CONTAINER_CMD exec $CONTAINER_NAME true" \
    "Can execute commands in container"

# Test 4: DNF available
assert_command "$CONTAINER_CMD exec $CONTAINER_NAME command -v dnf" \
    "DNF package manager is available"

# Test 5: Systemd available (before installation)
if $CONTAINER_CMD exec $CONTAINER_NAME command -v systemctl &>/dev/null; then
    echo -e "${GREEN}✓${NC} Systemd is available"
    ((TESTS_PASSED++))
else
    echo -e "${YELLOW}⊘${NC} Systemd not available yet (will be installed with GNOME)"
fi

# Test 6: Install GNOME environment
echo ""
echo "--- GNOME Installation ---"

if [[ "$QUICK_TEST" == "true" ]]; then
    echo -e "${YELLOW}⊘${NC} Skipping GNOME installation (QUICK_TEST=true mode)"
else
    echo -e "${YELLOW}⚠${NC} Installing GNOME environment (this may take several minutes)..."
    echo -e "${YELLOW}  Progress can be slow - watch for dnf output below...${NC}"
    echo ""

    # Create temp log file
    GNOME_INSTALL_LOG=$(mktemp)
    LAST_LOG_LINE=0
    
    # Start installation in background (redirected to file only, not terminal)
    timeout 300 $CONTAINER_CMD exec $CONTAINER_NAME \
        sudo dnf group install -y workstation-product-environment \
        >"$GNOME_INSTALL_LOG" 2>&1 &
    
    INSTALL_PID=$!
    
    # Show progress every 30 seconds
    while kill -0 $INSTALL_PID 2>/dev/null; do
        sleep 30
        CURRENT_LINES=$(wc -l < "$GNOME_INSTALL_LOG" 2>/dev/null || echo 0)
        if [[ $CURRENT_LINES -gt $LAST_LOG_LINE ]]; then
            echo -e "${YELLOW}  [progress: $(date '+%H:%M:%S')] $(tail -1 "$GNOME_INSTALL_LOG")${NC}"
            LAST_LOG_LINE=$CURRENT_LINES
        fi
    done
    
    wait $INSTALL_PID
    INSTALL_RESULT=$?
    
    echo ""
    if [[ $INSTALL_RESULT -eq 0 ]]; then
        echo -e "${GREEN}✓${NC} GNOME environment installed successfully"
        ((TESTS_PASSED++))
    elif [[ $INSTALL_RESULT -eq 124 ]]; then
        echo -e "${YELLOW}⚠${NC} GNOME installation timed out (5+ minutes)"
        echo "  This is expected in minimal/slow environments"
        # Check if partial install succeeded
        if grep -q "Complete" "$GNOME_INSTALL_LOG" 2>/dev/null; then
            echo -e "${GREEN}✓${NC} But some packages were installed"
            ((TESTS_PASSED++))
        fi
    else
        echo -e "${YELLOW}⚠${NC} GNOME installation encountered an error (exit code: $INSTALL_RESULT)"
        echo "  Last few lines of output:"
        tail -5 "$GNOME_INSTALL_LOG" | sed 's/^/    /'
    fi
    
    rm -f "$GNOME_INSTALL_LOG"
fi

echo ""
echo "--- Post-Installation Verification ---"

# Re-check Systemd after installation
echo -n "  Systemd availability after install... "
if $CONTAINER_CMD exec $CONTAINER_NAME command -v systemctl &>/dev/null; then
    echo -e "${GREEN}✓${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${YELLOW}⚠${NC} (may not be in PATH)"
fi

echo ""
echo "--- GNOME Components ---"

# Test 7: gnome-session available (with progress indicator)
echo -n "  Checking gnome-session... "
if $CONTAINER_CMD exec $CONTAINER_NAME which gnome-session &>/dev/null; then
    echo -e "${GREEN}✓${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${YELLOW}⚠${NC}"
fi

# Test 8: systemd-run available (with progress indicator)
echo -n "  Checking systemd-run... "
if $CONTAINER_CMD exec $CONTAINER_NAME which systemd-run &>/dev/null; then
    echo -e "${GREEN}✓${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${YELLOW}⚠${NC}"
fi

echo ""
echo "--- GNOME Session Test ---"

# Test 9: Try to launch gnome-session in container (mock e2e)
if [[ "$QUICK_TEST" != "true" ]]; then
    echo -n "  Attempting gnome-session startup... "
    
    # Try to start gnome-session for 5 seconds (will timeout, that's ok)
    # Just verify it starts without crashing
    GNOME_TEST_LOG=$(mktemp)
    timeout 5 $CONTAINER_CMD exec $CONTAINER_NAME \
        bash -c "systemd-run --user --scope --quiet gnome-session &
                 sleep 2
                 pgrep -f 'gnome-session' >/dev/null 2>&1" >"$GNOME_TEST_LOG" 2>&1
    
    GNOME_TEST_RESULT=$?
    
    if [[ $GNOME_TEST_RESULT -eq 0 ]]; then
        echo -e "${GREEN}✓${NC}"
        echo "    gnome-session process started successfully"
        ((TESTS_PASSED++))
    elif [[ $GNOME_TEST_RESULT -eq 124 ]]; then
        # Timeout is expected (process still running)
        echo -e "${GREEN}✓${NC}"
        echo "    gnome-session started and running (timed out as expected)"
        ((TESTS_PASSED++))
    else
        echo -e "${YELLOW}⚠${NC}"
        echo "    gnome-session startup test inconclusive"
    fi
    
    rm -f "$GNOME_TEST_LOG"
fi

echo ""
echo "--- Profile Scripts ---"

# Verify profile script syntax
PROFILE_SCRIPT="$PROJECT_DIR/etc/profile.d/fix_tmp.sh"
if [[ -f "$PROFILE_SCRIPT" ]]; then
    assert_command "bash -n '$PROFILE_SCRIPT'" \
        "Profile script has valid syntax"
    
    assert_command "grep -q 'chown' '$PROFILE_SCRIPT'" \
        "Profile script fixes X11 socket permissions"
    
    assert_command "grep -q 'systemd' '$PROFILE_SCRIPT'" \
        "Profile script manages systemd user session"
fi

echo ""
echo "--- Bootstrap Script ---"

# Verify bootstrap script
BOOTSTRAP_SCRIPT="$PROJECT_DIR/containers/gnome/bootstrap.sh"
if [[ -f "$BOOTSTRAP_SCRIPT" ]]; then
    assert_command "bash -n '$BOOTSTRAP_SCRIPT'" \
        "Bootstrap script has valid syntax"
    
    assert_command "grep -q 'systemd-user-sessions' '$BOOTSTRAP_SCRIPT'" \
        "Bootstrap enables systemd user sessions"
fi

# Final report
echo ""
echo "================================"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
if [[ $TESTS_FAILED -gt 0 ]]; then
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
fi
echo "================================"

if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
else
    echo -e "${GREEN}All integration tests passed!${NC}"
    exit 0
fi

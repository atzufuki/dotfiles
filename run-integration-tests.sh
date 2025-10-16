#!/usr/bin/env bash

# Podman Integration Test Wrapper
# This script automatically sets up Podman and runs GNOME session integration tests
# Works on Windows (with Podman Desktop) or Linux

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$PROJECT_DIR/tests"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Podman GNOME Integration Test Wrapper ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

# Step 1: Check Podman availability
echo -e "${YELLOW}[1/5]${NC} Checking Podman..."
if ! command -v podman &>/dev/null; then
    echo -e "${RED}✗ Podman not found${NC}"
    echo "   Please install Podman from: https://podman.io/docs/installation"
    exit 1
fi

PODMAN_VERSION=$(podman --version)
echo -e "${GREEN}✓${NC} $PODMAN_VERSION"

# Step 2: Check Podman socket/connection
echo ""
echo -e "${YELLOW}[2/5]${NC} Verifying Podman connection..."
if ! podman ps &>/dev/null; then
    echo -e "${RED}✗ Cannot connect to Podman${NC}"
    echo "   On Windows: Make sure Podman Desktop is running"
    echo "   On Linux: Make sure podman socket is active: systemctl --user start podman.socket"
    exit 1
fi

echo -e "${GREEN}✓${NC} Connected to Podman"

# Step 3: Check for distrobox
echo ""
echo -e "${YELLOW}[3/5]${NC} Checking Distrobox..."
if ! command -v distrobox &>/dev/null; then
    echo -e "${YELLOW}⚠${NC} Distrobox not found - installing..."
    
    # Install distrobox
    if bash -c "$(curl -fsSL https://raw.githubusercontent.com/89luca89/distrobox/main/install)" &>/dev/null; then
        echo -e "${GREEN}✓${NC} Distrobox installed"
    else
        echo -e "${YELLOW}⚠${NC} Distrobox installation had issues, continuing anyway..."
    fi
else
    DISTROBOX_VERSION=$(distrobox --version)
    echo -e "${GREEN}✓${NC} $DISTROBOX_VERSION"
fi

# Step 4: Prepare environment
echo ""
echo -e "${YELLOW}[4/5]${NC} Setting up environment..."

# Make test script executable
chmod +x "$SCRIPT_DIR/test_integration_gnome.sh" 2>/dev/null || true

echo -e "${GREEN}✓${NC} Environment ready"

# Step 5: Run integration test
echo ""
echo -e "${YELLOW}[5/5]${NC} Running integration tests..."
echo "────────────────────────────────────────"

# Export podman as container runtime
export CONTAINER_CMD="podman"

# Run the integration test
if bash "$SCRIPT_DIR/test_integration_gnome.sh"; then
    echo ""
    echo "────────────────────────────────────────"
    echo -e "${GREEN}✓ All integration tests passed!${NC}"
    exit 0
else
    exit_code=$?
    echo ""
    echo "────────────────────────────────────────"
    echo -e "${RED}✗ Integration tests failed${NC}"
    exit $exit_code
fi

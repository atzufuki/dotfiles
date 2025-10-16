#!/usr/bin/env bash

# Simple wrapper to run integration tests with Podman on Windows/macOS/Linux
# Usage: bash run_integration_test.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE}  Dotfiles Integration Test Runner${NC}"
echo -e "${BLUE}  (Podman-based)${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo ""
echo "Usage: bash run_integration_test.sh [OPTIONS]"
echo ""
echo "Options:"
echo "  QUICK_TEST=true      Skip GNOME installation (fast, ~30 seconds)"
echo "  CONTAINER_CMD=podman Use specific container runtime (default: auto-detect)"
echo ""
echo "Example (quick test):"
echo "  QUICK_TEST=true bash run_integration_test.sh"
echo ""
echo "═══════════════════════════════════════"
echo ""

# Check if podman is available
if ! command -v podman &>/dev/null; then
    echo -e "${YELLOW}✗ Podman not found in PATH${NC}"
    echo "  Please install Podman from: https://podman.io"
    exit 1
fi

PODMAN_VERSION=$(podman --version)
echo -e "${GREEN}✓ Using: $PODMAN_VERSION${NC}"
echo ""

# Try to start podman service (if needed on Windows/macOS)
if ! podman info &>/dev/null; then
    echo -e "${YELLOW}⚠ Podman daemon not running. Attempting to start...${NC}"
    
    # Try to start podman machine on macOS/Windows
    if podman machine ls &>/dev/null 2>&1; then
        echo "  Starting Podman machine..."
        podman machine start || true
    fi
    
    # Wait a moment for daemon to start
    sleep 2
    
    if ! podman info &>/dev/null; then
        echo -e "${YELLOW}✗ Could not start Podman daemon${NC}"
        echo "  Try starting Podman Desktop or run: podman machine start"
        exit 1
    fi
fi

echo -e "${GREEN}✓ Podman daemon is running${NC}"
echo ""

# Set container command to podman
export CONTAINER_CMD="podman"

echo -e "${BLUE}Running integration tests...${NC}"
echo ""

# Run the integration test
bash "$SCRIPT_DIR/test_integration_simple.sh"

TEST_RESULT=$?

echo ""
echo -e "${BLUE}═══════════════════════════════════════${NC}"

if [[ $TEST_RESULT -eq 0 ]]; then
    echo -e "${GREEN}Integration tests completed successfully!${NC}"
else
    echo -e "${YELLOW}⚠ Integration tests completed with warnings or failures${NC}"
fi

echo -e "${BLUE}═══════════════════════════════════════${NC}"

exit $TEST_RESULT

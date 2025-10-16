# Dotfiles Test Suite

This directory contains automated tests for the dotfiles project. The tests validate configuration, symlink management, setup procedures, and GNOME session integration.

## Test Structure

### Test Suites

1. **`test_symlinks.sh`** - Symlink Management Tests
   - Validates `.dotfilesignore` configuration
   - Checks critical files are not ignored
   - Verifies file structure and directories
   - Validates shell script shebangs and permissions
   - Validates desktop file format

2. **`test_setup.sh`** - Setup Script Tests
   - Validates `setup.sh` syntax and executability
   - Checks repository handling logic
   - Verifies Distrobox integration
   - Validates symlink creation procedures
   - Tests ignore file configuration

3. **`test_gnome_session.sh`** - GNOME Session Tests
   - Validates session launcher configuration
   - Checks desktop entry file format
   - Verifies bootstrap script configuration
   - Validates systemd user session setup
   - Checks container integration (if Distrobox is available)

4. **`test_integration_simple.sh`** - Integration Tests (Podman/Docker)
   - Direct container-based testing without Distrobox wrapper
   - Creates ephemeral test containers for clean environment
   - Validates Podman/Docker CLI and daemon availability
   - Tests GNOME environment installation in container
   - Validates systemd components
   - Automatic cleanup of test containers
   - **Requires**: Podman Desktop or Podman/Docker CLI
   - **Runtime**: ~30 seconds (quick mode) or 5-10 minutes (full)

5. **`run_integration_test.sh`** - Integration Test Wrapper
   - Convenient wrapper for running integration tests
   - Auto-detects Podman/Docker availability
   - Handles Podman machine startup (macOS/Windows)
   - Passes through environment variables and options

## Running Tests

### Run All Static Tests
```bash
bash tests/run_all_tests.sh
```

### Run Specific Test Suite
```bash
bash tests/test_symlinks.sh
bash tests/test_setup.sh
bash tests/test_gnome_session.sh
```

### Run Integration Tests (Container-based)

**Quick test** (no GNOME install, ~30 seconds):
```bash
QUICK_TEST=true bash tests/run_integration_test.sh
```

**Full test** (installs GNOME, 5-10 minutes):
```bash
bash tests/run_integration_test.sh
```

**Direct test** (without wrapper):
```bash
bash tests/test_integration_simple.sh
```

**Requirements:**
- Podman Desktop (Windows/macOS) or Podman/Docker (Linux)
- Container runtime CLI available in PATH

**Features:**
- ✓ Auto-detects Podman or Docker
- ✓ Real-time progress logging during GNOME installation
- ✓ Automatic cleanup of test containers
- ✓ Works on Windows (Podman Desktop), macOS, and Linux

## Test Output

Tests use colored output for clarity:
- **✓ Green** - Test passed
- **✗ Red** - Test failed (critical issue)
- **⚠ Yellow** - Warning or skipped test (non-critical)

## CI/CD Integration

The project has GitHub Actions workflows for automated testing:

### Static Tests Job
- Runs on every push/PR to validate configuration
- Tests symlink management, setup script, and session configuration
- Fast (~10 seconds)

### Integration Tests Job  
- Creates test containers to verify real-world scenarios
- Tests container setup, package manager availability
- Validates systemd components and gnome-session
- Runs simplified test (~2 minutes) without full GNOME install
- May be extended to full GNOME install in future

View workflow: `.github/workflows/test.yml`

## Test Requirements

### Required Commands (for static tests)
- `bash` - Bash shell interpreter
- `grep` - Text search utility
- `find` - File search utility

### Optional Commands (for integration tests)
- `distrobox` - Container management
- `podman` or `docker` - Container runtime
- `git` - Repository utilities

## What Tests Verify vs What They Cannot

### Static Tests Verify
✅ File structure and configuration
✅ Shell script syntax and shebang
✅ Desktop entry file format
✅ Systemd integration setup
✅ GDM session registration
✅ .dotfilesignore correctness

### Integration Tests Verify
✅ Distrobox container creation
✅ Container environment setup
✅ GNOME installation in container
✅ Systemd user session in container
✅ Package manager availability

### What Cannot Be Tested Automatically
❌ Actual symlink creation (requires root)
❌ Live GDM session login (requires display server)
❌ XWayland integration (requires running Wayland)
❌ Full GNOME desktop functionality
❌ Audio/graphics hardware passthrough
- Test X11 socket communication

For integration testing of these features, manual testing is recommended:

```bash
# Test setup script (creates symlinks and container)
bash setup.sh

# Test session launcher
bash /usr/local/bin/distrobox-gnome-session.sh

# Check container bootstrap
distrobox enter fedora-gnome -- gnome-session --version
```

## Troubleshooting Tests

### Test Fails: "distrobox-enter not found"
This is expected if Distrobox is not installed. Tests will show warnings but won't fail.

### Test Fails: "Script has invalid bash syntax"
Run individual scripts with `-n` flag to find syntax errors:
```bash
bash -n path/to/script.sh
```

### Test Fails: "File structure issues"
Check the `.dotfilesignore` file and ensure expected directories are present:
```bash
cat .dotfilesignore
find . -type d -name "etc" -o -name "usr" -o -name "containers"
```

## Contributing

When adding new features:
1. Add corresponding test cases
2. Ensure all tests pass: `bash tests/run_all_tests.sh`
3. Document test requirements in this README

## Notes

- Tests are non-destructive and safe to run multiple times
- Tests run with minimal dependencies
- Tests can run on any Linux distribution
- Test runner works with or without Distrobox installed

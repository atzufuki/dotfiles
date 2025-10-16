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

## Running Tests

### Run All Tests
```bash
bash tests/run_all_tests.sh
```

### Run Specific Test Suite
```bash
bash tests/test_symlinks.sh
bash tests/test_setup.sh
bash tests/test_gnome_session.sh
```

## Test Output

Tests use colored output for clarity:
- **✓ Green** - Test passed
- **✗ Red** - Test failed (critical issue)
- **⚠ Yellow** - Warning or skipped test (non-critical)

## CI/CD Integration

These tests can be integrated into CI/CD pipelines. Example GitHub Actions workflow:

```yaml
name: Test Dotfiles

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run test suite
        run: bash tests/run_all_tests.sh
```

## Test Requirements

### Required Commands
- `bash` - Bash shell interpreter
- `grep` - Text search utility
- `find` - File search utility

### Optional Commands
- `distrobox` - For container tests
- `git` - For repository tests

## What Tests Cannot Verify

These tests focus on static validation and do not:
- Test actual symlink creation (would require root/sudo)
- Test actual container creation/startup
- Test Wayland session integration
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

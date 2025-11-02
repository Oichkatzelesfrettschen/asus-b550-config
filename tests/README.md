# Test Suite

Comprehensive test suite for the asus-b550-config project.

## Quick Start

Run all tests:

```bash
./tests/run-tests.sh
```

Or using the Makefile:

```bash
make test
```

## Test Suites

The test suite includes:

### 1. Shell Script Syntax (5 tests)
- Validates syntax of all shell scripts
- Checks PKGBUILD and install script syntax
- Uses `bash -n` for syntax verification

### 2. ShellCheck Validation (3 tests)
- Runs ShellCheck with warnings as errors (`-S warning`)
- Validates all scripts in `scripts/` directory
- Ensures POSIX compliance and best practices

### 3. C Code Compilation (2 tests)
- Compiles `nct-id.c` with strict flags
- Verifies binary creation
- Uses: `gcc -std=c2x -O2 -Wall -Wextra -Werror`

### 4. Documentation Files (6 tests)
- Verifies existence of essential documentation
- Checks: README, CHANGELOG, CONTRIBUTING, SECURITY, SUPPORT, LICENSE

### 5. Configuration Files (4 tests)
- Validates existence of config files
- Checks: .editorconfig, .markdownlintrc, .pre-commit-config.yaml, PKGBUILD

### 6. Directory Structure (7 tests)
- Ensures proper directory organization
- Verifies: docs/, scripts/, systemd/, udev/, etc/, examples/, .github/

### 7. Systemd Units (3 tests)
- Checks systemd service and timer files
- Validates file existence in systemd/

### 8. Udev Rules (2 tests)
- Verifies udev rules files
- Checks hardware monitor and SATA rules

### 9. CI/CD Workflows (5 tests)
- Validates GitHub Actions workflow files
- Checks: lint, build, documentation, security, release

### 10. Markdown Linting (1 test)
- Runs markdownlint if available
- Validates all markdown files

## Test Output

Example output:

```
═══════════════════════════════════════════════════════════════
  ASUS B550 Config - Test Suite
═══════════════════════════════════════════════════════════════

[INFO] Test Suite 1: Shell Script Syntax
  Testing: max-fans.sh syntax... ✓
  Testing: max-fans-enhanced.sh syntax... ✓
  ...

═══════════════════════════════════════════════════════════════
  Test Results
═══════════════════════════════════════════════════════════════

Tests Run:    37
Tests Passed: 37
Tests Failed: 0

✓ All tests passed!
```

## Running Specific Tests

The test runner executes all test suites sequentially. To run specific tests, you can:

1. **Run specific validation**:
   ```bash
   # Just shell syntax
   make test-syntax
   
   # Just C compilation
   make test-build
   
   # Just linting
   make lint
   ```

2. **Run individual shellcheck**:
   ```bash
   shellcheck -S warning scripts/max-fans.sh
   ```

3. **Test C compilation manually**:
   ```bash
   gcc -std=c2x -O2 -Wall -Wextra -Werror \
       -o /tmp/nct-id scripts/nct-id.c
   ```

## CI/CD Integration

Tests run automatically on every push/PR via GitHub Actions:

- **Test Suite Workflow** (`.github/workflows/test.yml`)
  - Runs complete test suite
  - Tests Makefile targets
  - Multi-GCC version testing (11, 12, 13)
  - Bash version compatibility
  - Package build testing

## Dependencies

### Required
- `bash` - Shell script interpreter
- `gcc` - C compiler for nct-id
- Basic Unix utilities (test, grep, etc.)

### Optional (for complete testing)
- `shellcheck` - Shell script linting
- `markdownlint-cli` - Markdown linting
- `make` - For Makefile targets

### Installing Dependencies

**Arch Linux:**
```bash
sudo pacman -S shellcheck gcc make
npm install -g markdownlint-cli
```

**Ubuntu/Debian:**
```bash
sudo apt-get install shellcheck gcc make
npm install -g markdownlint-cli
```

## Exit Codes

- `0` - All tests passed
- `1` - One or more tests failed

## Adding New Tests

To add new tests to `run-tests.sh`:

1. Create a new test suite section
2. Use the `run_test` helper function:
   ```bash
   run_test "test name" "command to run"
   ```

3. The function handles:
   - Test counting
   - Pass/fail tracking
   - Colored output
   - Error collection

Example:
```bash
log_info "Test Suite 11: New Tests"
run_test "new feature exists" "test -f path/to/feature"
run_test "new config valid" "validate-config config.file"
```

## Troubleshooting

### Tests fail with "command not found"
- Install missing dependencies (shellcheck, markdownlint, etc.)
- Or run subset of tests that don't require those tools

### C compilation fails
- Ensure GCC is installed and supports C2x standard
- Check that `scripts/nct-id.c` exists

### Permission denied
- Ensure test script is executable: `chmod +x tests/run-tests.sh`

## Future Enhancements

Planned test additions:
- Integration tests with mock hardware
- Performance benchmarks
- Memory leak detection (valgrind)
- Code coverage metrics
- Regression test suite
- Multi-kernel compatibility tests

## Contributing

When adding new features:
1. Add corresponding tests
2. Ensure all existing tests still pass
3. Document new test suites in this README
4. Update CI/CD workflows if needed

See [CONTRIBUTING.md](../CONTRIBUTING.md) for general contribution guidelines.

---

**Last Updated**: 2025-11-02  
**Test Count**: 37 tests across 10 suites

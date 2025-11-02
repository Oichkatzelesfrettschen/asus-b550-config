#!/bin/bash
# Test runner for asus-b550-config
# Runs all test suites and reports results

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test result tracking
declare -a FAILED_TESTS

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $*"
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

run_test() {
    local test_name="$1"
    local test_command="$2"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    echo -n "  Testing: $test_name... "
    
    if eval "$test_command" &>/dev/null; then
        echo -e "${GREEN}✓${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        FAILED_TESTS+=("$test_name")
        return 1
    fi
}

# Banner
echo "═══════════════════════════════════════════════════════════════"
echo "  ASUS B550 Config - Test Suite"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Test 1: Shell Script Syntax
log_info "Test Suite 1: Shell Script Syntax"
run_test "max-fans.sh syntax" "bash -n scripts/max-fans.sh"
run_test "max-fans-enhanced.sh syntax" "bash -n scripts/max-fans-enhanced.sh"
run_test "max-fans-advanced.sh syntax" "bash -n scripts/max-fans-advanced.sh"
run_test "PKGBUILD syntax" "bash -n PKGBUILD"
run_test "Install script syntax" "bash -n eirikr-asus-b550-config.install"
echo ""

# Test 2: ShellCheck Validation
log_info "Test Suite 2: ShellCheck Validation"
if command -v shellcheck &>/dev/null; then
    run_test "ShellCheck max-fans.sh" "shellcheck -S warning scripts/max-fans.sh"
    run_test "ShellCheck max-fans-enhanced.sh" "shellcheck -S warning scripts/max-fans-enhanced.sh"
    run_test "ShellCheck max-fans-advanced.sh" "shellcheck -S warning scripts/max-fans-advanced.sh"
else
    log_warning "ShellCheck not installed, skipping..."
fi
echo ""

# Test 3: C Code Compilation
log_info "Test Suite 3: C Code Compilation"
run_test "nct-id.c compiles" "gcc -std=c2x -O2 -Wall -Wextra -Werror -o /tmp/test-nct-id scripts/nct-id.c"
if [ -f /tmp/test-nct-id ]; then
    run_test "nct-id binary created" "test -x /tmp/test-nct-id"
    rm -f /tmp/test-nct-id
fi
echo ""

# Test 4: Documentation Files
log_info "Test Suite 4: Documentation Files"
run_test "README.md exists" "test -f README.md"
run_test "CHANGELOG.md exists" "test -f CHANGELOG.md"
run_test "CONTRIBUTING.md exists" "test -f CONTRIBUTING.md"
run_test "SECURITY.md exists" "test -f SECURITY.md"
run_test "SUPPORT.md exists" "test -f SUPPORT.md"
run_test "LICENSE exists" "test -f LICENSE"
echo ""

# Test 5: Configuration Files
log_info "Test Suite 5: Configuration Files"
run_test ".editorconfig exists" "test -f .editorconfig"
run_test ".markdownlintrc exists" "test -f .markdownlintrc"
run_test ".pre-commit-config.yaml exists" "test -f .pre-commit-config.yaml"
run_test "PKGBUILD exists" "test -f PKGBUILD"
echo ""

# Test 6: Directory Structure
log_info "Test Suite 6: Directory Structure"
run_test "docs/ directory" "test -d docs"
run_test "scripts/ directory" "test -d scripts"
run_test "systemd/ directory" "test -d systemd"
run_test "udev/ directory" "test -d udev"
run_test "etc/ directory" "test -d etc"
run_test "examples/ directory" "test -d examples"
run_test ".github/ directory" "test -d .github"
echo ""

# Test 7: Systemd Units
log_info "Test Suite 7: Systemd Units"
run_test "max-fans.service exists" "test -f systemd/max-fans.service"
run_test "max-fans-restore.service exists" "test -f systemd/max-fans-restore.service"
run_test "max-fans-restore.timer exists" "test -f systemd/max-fans-restore.timer"
echo ""

# Test 8: Udev Rules
log_info "Test Suite 8: Udev Rules"
run_test "hwmon permissions rule exists" "test -f udev/50-asus-hwmon-permissions.rules"
run_test "SATA rule exists" "test -f udev/90-asus-sata.rules"
echo ""

# Test 9: CI/CD Workflows
log_info "Test Suite 9: CI/CD Workflows"
run_test "lint workflow exists" "test -f .github/workflows/lint.yml"
run_test "build workflow exists" "test -f .github/workflows/build.yml"
run_test "documentation workflow exists" "test -f .github/workflows/documentation.yml"
run_test "security workflow exists" "test -f .github/workflows/security.yml"
run_test "release workflow exists" "test -f .github/workflows/release.yml"
echo ""

# Test 10: Markdown Linting (if markdownlint available)
log_info "Test Suite 10: Markdown Linting"
if command -v markdownlint &>/dev/null; then
    run_test "Markdownlint validation" "markdownlint '**/*.md' --ignore node_modules"
else
    log_warning "Markdownlint not installed, skipping..."
fi
echo ""

# Summary
echo "═══════════════════════════════════════════════════════════════"
echo "  Test Results"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo -e "Tests Run:    ${BLUE}${TESTS_RUN}${NC}"
echo -e "Tests Passed: ${GREEN}${TESTS_PASSED}${NC}"
echo -e "Tests Failed: ${RED}${TESTS_FAILED}${NC}"
echo ""

if [ ${TESTS_FAILED} -gt 0 ]; then
    echo -e "${RED}Failed Tests:${NC}"
    for test in "${FAILED_TESTS[@]}"; do
        echo "  - $test"
    done
    echo ""
    exit 1
else
    echo -e "${GREEN}✓ All tests passed!${NC}"
    echo ""
    exit 0
fi

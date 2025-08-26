#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# gex/tests/test_sync.sh
#
# Basic tests for gex sync command
#
# Tests:
#   - Help output format
#   - Dry run functionality
#   - Strategy validation
#   - Basic sync operations
#   - Error conditions
#
# Usage:
#   ./test_sync.sh
#   bash test_sync.sh
#
# Requirements:
#   - Bash 4.0+
#   - Git repository with remote configured
#   - gex commands available in ../
# -----------------------------------------------------------------------------

set -euo pipefail

# Test framework variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GEX_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_NAME="test_sync"
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors for output
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  RED=$'\033[31m'
  GREEN=$'\033[32m'
  YELLOW=$'\033[33m'
  BLUE=$'\033[34m'
  BOLD=$'\033[1m'
  RESET=$'\033[0m'
else
  RED=""; GREEN=""; YELLOW=""; BLUE=""; BOLD=""; RESET=""
fi

# Test utilities
log_info() { echo "${BLUE}INFO${RESET}: $*" >&2; }
log_pass() { echo "${GREEN}PASS${RESET}: $*" >&2; }
log_fail() { echo "${RED}FAIL${RESET}: $*" >&2; }
log_warn() { echo "${YELLOW}WARN${RESET}: $*" >&2; }

setup_test() {
  log_info "Setting up test environment for $TEST_NAME"

  # Ensure we're in a git repository
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    log_fail "Must run tests from within a git repository"
    exit 1
  fi

  # Save current branch and state
  ORIGINAL_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")"
  ORIGINAL_COMMIT="$(git rev-parse HEAD 2>/dev/null)"

  # Ensure we start from a clean state
  if [ -n "$(git status --porcelain)" ]; then
    log_warn "Working directory not clean, stashing changes"
    git stash push -m "test_sync_stash_$(date +%s)" >/dev/null
    STASHED_CHANGES=1
  else
    STASHED_CHANGES=0
  fi

  log_info "Test setup complete"
  log_info "Original branch: $ORIGINAL_BRANCH"
}

cleanup_test() {
  log_info "Cleaning up test environment"

  # Switch back to original branch
  if [ -n "${ORIGINAL_BRANCH:-}" ]; then
    git checkout "$ORIGINAL_BRANCH" >/dev/null 2>&1 || true
  fi

  # Restore stashed changes if any
  if [ "${STASHED_CHANGES:-0}" = "1" ]; then
    git stash pop >/dev/null 2>&1 || log_warn "Could not restore stashed changes"
  fi

  log_info "Cleanup complete"
}

# Test framework
run_test() {
  local test_name="$1"
  local test_func="$2"
  TESTS_RUN=$((TESTS_RUN + 1))

  log_info "Running test: $test_name"

  if $test_func; then
    log_pass "$test_name"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    log_fail "$test_name"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  echo
}

# Helper function to run gex sync and capture output
run_sync() {
  local args=("$@")
  "$GEX_ROOT/gex" sync "${args[@]}" 2>&1
}

# Test Cases
test_help_output() {
  local output
  if output="$(run_sync --help 2>&1)"; then
    if [[ "$output" =~ "Usage: gex sync" ]] && [[ "$output" =~ "--strategy" ]] && [[ "$output" =~ "--all" ]]; then
      return 0
    fi
  fi
  return 1
}

test_dry_run_basic() {
  local output
  if output="$(run_sync --dry-run --no-fetch 2>&1)"; then
    if [[ "$output" =~ "DRY RUN" ]] && [[ "$output" =~ "Would execute" ]]; then
      return 0
    fi
  fi
  return 1
}

test_strategy_validation() {
  local output

  # Test valid strategies
  if ! output="$(run_sync --strategy=merge --dry-run --no-fetch 2>&1)"; then
    return 1
  fi

  if ! output="$(run_sync --strategy=rebase --dry-run --no-fetch 2>&1)"; then
    return 1
  fi

  # Test invalid strategy
  if output="$(run_sync --strategy=invalid --dry-run 2>&1)"; then
    return 1
  else
    if [[ "$output" =~ "Invalid strategy" ]]; then
      return 0
    fi
  fi

  return 1
}

test_all_option() {
  local output
  if output="$(run_sync --all --dry-run --no-fetch 2>&1)"; then
    # Should either show branches to sync or indicate no valid branches
    if [[ "$output" =~ "DRY RUN" ]] || [[ "$output" =~ "No valid branches" ]]; then
      return 0
    fi
  fi
  return 1
}

test_status_display() {
  local output
  if output="$(run_sync --dry-run --no-fetch 2>&1)"; then
    if [[ "$output" =~ "Sync Plan:" ]] && [[ "$output" =~ "Strategy:" ]] && [[ "$output" =~ "Branch Status:" ]]; then
      return 0
    fi
  fi
  return 1
}

test_invalid_options() {
  local output

  # Test unknown option
  if output="$(run_sync --invalid-option 2>&1)"; then
    return 1
  else
    if [[ "$output" =~ "Unknown option" ]]; then
      return 0
    fi
  fi

  return 1
}

test_no_upstream_handling() {
  # This test checks that branches without upstream are handled gracefully
  local output
  if output="$(run_sync nonexistent-branch --dry-run --no-fetch 2>&1)"; then
    # Should either warn about no upstream or branch not existing
    if [[ "$output" =~ "no upstream" ]] || [[ "$output" =~ "does not exist" ]]; then
      return 0
    fi
  fi
  return 1
}

test_protected_branch_handling() {
  # Test that protected branches are handled correctly in --all mode
  local output
  if output="$(run_sync --all --dry-run --no-fetch 2>&1)"; then
    # Should succeed (either sync branches or report no valid branches)
    # Protected branches should be skipped in --all mode
    return 0
  fi
  return 1
}

# Main test execution
main() {
  echo "${BOLD}=== Gex Sync Command Test Suite ===${RESET}"
  echo

  # Set up test environment
  setup_test

  # Ensure cleanup happens on exit
  trap cleanup_test EXIT

  # Run tests
  run_test "Help output format" test_help_output
  run_test "Dry run basic functionality" test_dry_run_basic
  run_test "Strategy validation" test_strategy_validation
  run_test "All option handling" test_all_option
  run_test "Status display format" test_status_display
  run_test "Invalid options handling" test_invalid_options
  run_test "No upstream branch handling" test_no_upstream_handling
  run_test "Protected branch handling" test_protected_branch_handling

  # Summary
  echo "${BOLD}=== Test Results ===${RESET}"
  echo "Tests run:    $TESTS_RUN"
  echo "Tests passed: ${GREEN}$TESTS_PASSED${RESET}"
  echo "Tests failed: ${RED}$TESTS_FAILED${RESET}"

  if [ $TESTS_FAILED -eq 0 ]; then
    echo
    echo "${GREEN}${BOLD}All tests passed!${RESET}"
    exit 0
  else
    echo
    echo "${RED}${BOLD}Some tests failed.${RESET}"
    exit 1
  fi
}

# Only run main if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main "$@"
fi

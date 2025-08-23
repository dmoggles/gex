#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# gex/tests/test_publish.sh
#
# Integration tests for gex publish command
#
# Tests:
#   - Basic publish functionality
#   - Dry run mode
#   - Remote and branch options
#   - Safety checks and warnings
#   - Integration with gex start workflow
#   - Configuration handling
#   - Error conditions
#
# Usage:
#   ./test_publish.sh
#   bash test_publish.sh
#
# Requirements:
#   - Bash 4.0+ (for associative arrays)
#   - Git repository with remote configured
#   - gex commands available in ../
# -----------------------------------------------------------------------------

set -euo pipefail

# Test framework variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GEX_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_NAME="test_publish"
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
  log_info "Setting up test environment"

  # Ensure we're in a git repository
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    log_fail "Must run tests from within a git repository"
    exit 1
  fi

  # Save current branch
  ORIGINAL_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")"

  # Ensure we start from a clean state
  if [ -n "$(git status --porcelain)" ]; then
    log_warn "Working directory not clean, stashing changes"
    git stash push -m "test_publish_stash_$(date +%s)"
  fi

  log_info "Original branch: $ORIGINAL_BRANCH"
}

cleanup_test() {
  log_info "Cleaning up test environment"

  # Switch back to original branch
  if [ -n "${ORIGINAL_BRANCH:-}" ]; then
    git checkout "$ORIGINAL_BRANCH" >/dev/null 2>&1 || true
  fi

  # Clean up any test branches
  local test_branches
  test_branches="$(git branch | grep -E "(test-publish|features/test-)" | sed 's/^[* ]*//' || true)"
  if [ -n "$test_branches" ]; then
    log_info "Cleaning up test branches: $test_branches"
    echo "$test_branches" | xargs -r git branch -D >/dev/null 2>&1 || true
  fi

  # Restore stashed changes if any
  if git stash list | grep -q "test_publish_stash_"; then
    log_info "Restoring stashed changes"
    git stash pop >/dev/null 2>&1 || true
  fi
}

# Test framework functions
run_test() {
  local test_name="$1"
  local test_func="$2"

  TESTS_RUN=$((TESTS_RUN + 1))
  log_info "Running test: $test_name"

  if "$test_func"; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    log_pass "$test_name"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    log_fail "$test_name"
  fi

  echo
}

assert_equals() {
  local expected="$1"
  local actual="$2"
  local message="${3:-}"

  if [ "$expected" = "$actual" ]; then
    return 0
  else
    log_fail "Assertion failed${message:+: $message}"
    log_fail "Expected: '$expected'"
    log_fail "Actual:   '$actual'"
    return 1
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local message="${3:-}"

  if [[ "$haystack" == *"$needle"* ]]; then
    return 0
  else
    log_fail "Assertion failed${message:+: $message}"
    log_fail "Expected '$haystack' to contain '$needle'"
    return 1
  fi
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  local message="${3:-}"

  if [[ "$haystack" != *"$needle"* ]]; then
    return 0
  else
    log_fail "Assertion failed${message:+: $message}"
    log_fail "Expected '$haystack' to NOT contain '$needle'"
    return 1
  fi
}

assert_command_success() {
  local cmd=("$@")
  local output

  if output=$("${cmd[@]}" 2>&1); then
    return 0
  else
    log_fail "Command failed: ${cmd[*]}"
    log_fail "Output: $output"
    return 1
  fi
}

assert_command_fails() {
  local cmd=("$@")
  local output

  if output=$("${cmd[@]}" 2>&1); then
    log_fail "Command unexpectedly succeeded: ${cmd[*]}"
    log_fail "Output: $output"
    return 1
  else
    return 0
  fi
}

# Test functions
test_help_output() {
  local output
  output="$("$GEX_ROOT/gex" publish --help)"

  assert_contains "$output" "Usage: gex publish" "Help should show usage"
  assert_contains "$output" "--remote=" "Help should show remote option"
  assert_contains "$output" "--dry-run" "Help should show dry-run option"
  assert_contains "$output" "Examples:" "Help should show examples"
}

test_dry_run_basic() {
  local output
  output="$("$GEX_ROOT/gex" publish --dry-run 2>&1)"

  assert_contains "$output" "DRY RUN" "Should indicate dry run mode"
  assert_contains "$output" "Would execute:" "Should show what would be executed"
  assert_contains "$output" "git" "Should show git command"
  assert_contains "$output" "push" "Should show push command"
}

test_detached_head_error() {
  # Create a detached HEAD state
  local commit
  commit="$(git rev-parse HEAD)"
  git checkout "$commit" >/dev/null 2>&1

  local output
  if output="$("$GEX_ROOT/gex" publish --dry-run 2>&1)"; then
    # Restore original branch before failing
    git checkout "$ORIGINAL_BRANCH" >/dev/null 2>&1
    log_fail "Command should fail in detached HEAD"
    return 1
  else
    # Restore original branch before asserting
    git checkout "$ORIGINAL_BRANCH" >/dev/null 2>&1
    assert_contains "$output" "detached HEAD" "Should mention detached HEAD"
    return 0
  fi
}

test_nonexistent_remote_error() {
  # Ensure we're on the original branch
  git checkout "$ORIGINAL_BRANCH" >/dev/null 2>&1

  local output
  if output="$("$GEX_ROOT/gex" publish --remote=nonexistent --dry-run 2>&1)"; then
    log_fail "Command should fail with nonexistent remote"
    return 1
  else
    assert_contains "$output" "does not exist" "Should mention remote doesn't exist"
    return 0
  fi
}

test_remote_branch_options() {
  # Ensure we're on the original branch
  git checkout "$ORIGINAL_BRANCH" >/dev/null 2>&1

  local output
  output="$("$GEX_ROOT/gex" publish --remote=origin --branch=test-branch --dry-run 2>&1)"

  assert_contains "$output" "Remote:         origin" "Should show specified remote"
  assert_contains "$output" "Target branch:  test-branch" "Should show specified branch"
  assert_contains "$output" "origin" "Should use correct push syntax"
}

test_to_option_parsing() {
  # Ensure we're on the original branch
  git checkout "$ORIGINAL_BRANCH" >/dev/null 2>&1

  local output
  output="$("$GEX_ROOT/gex" publish --to=origin/feature-branch --dry-run 2>&1)"

  assert_contains "$output" "Remote:         origin" "Should parse remote from --to"
  assert_contains "$output" "Target branch:  feature-branch" "Should parse branch from --to"
}

test_invalid_to_format() {
  local output
  if output="$("$GEX_ROOT/gex" publish --to=invalid-format --dry-run 2>&1)"; then
    log_fail "Command should fail with invalid --to format"
    return 1
  else
    assert_contains "$output" "Invalid --to format" "Should mention invalid format"
    return 0
  fi
}

test_protected_branch_warning() {
  # Ensure we're on the original branch
  git checkout "$ORIGINAL_BRANCH" >/dev/null 2>&1

  local output
  output="$("$GEX_ROOT/gex" publish --branch=main --dry-run 2>&1)"

  assert_contains "$output" "protected" "Should warn about protected branch"
}

test_force_options() {
  # Ensure we're on the original branch
  git checkout "$ORIGINAL_BRANCH" >/dev/null 2>&1

  local output1 output2

  # Test --force option
  output1="$("$GEX_ROOT/gex" publish --force --dry-run 2>&1)"
  assert_contains "$output1" "--force" "Should include force flag"

  # Test --force-with-lease option
  output2="$("$GEX_ROOT/gex" publish --force-with-lease --dry-run 2>&1)"
  assert_contains "$output2" "--force-with-lease" "Should include force-with-lease flag"
}

test_no_set_upstream_option() {
  # Ensure we're on the original branch
  git checkout "$ORIGINAL_BRANCH" >/dev/null 2>&1

  local output
  output="$("$GEX_ROOT/gex" publish --no-set-upstream --dry-run 2>&1)"

  assert_not_contains "$output" "--set-upstream" "Should not include set-upstream flag"
}

test_integration_with_gex_start() {
  # Create a test branch using gex start
  local branch_name="test-publish-integration"

  # First check what branch types are available
  local start_output
  start_output="$("$GEX_ROOT/gex" start --list-types 2>&1)"

  local branch_type
  if [[ "$start_output" == *"features"* ]]; then
    branch_type="features"
  elif [[ "$start_output" == *"feature"* ]]; then
    branch_type="feature"
  else
    log_warn "No suitable branch type found, using first available"
    branch_type="$(echo "$start_output" | grep -E "^  [a-z]" | head -n1 | sed 's/^  //' | awk '{print $1}')"
  fi

  if [ -z "$branch_type" ]; then
    log_warn "Could not determine branch type, skipping integration test"
    return 0
  fi

  # Create branch with gex start
  "$GEX_ROOT/gex" start "$branch_type" "$branch_name" >/dev/null 2>&1

  # Test publish from the created branch
  local publish_output
  publish_output="$("$GEX_ROOT/gex" publish --dry-run 2>&1)"

  assert_contains "$publish_output" "$branch_type/$branch_name" "Should show full branch name"
  assert_contains "$publish_output" "New branch" "Should indicate new branch"

  # Clean up
  git checkout "$ORIGINAL_BRANCH" >/dev/null 2>&1
  git branch -D "$branch_type/$branch_name" >/dev/null 2>&1
}

test_status_information() {
  # Ensure we're on the original branch
  git checkout "$ORIGINAL_BRANCH" >/dev/null 2>&1

  local output
  output="$("$GEX_ROOT/gex" publish --dry-run 2>&1)"

  assert_contains "$output" "Publishing Status:" "Should show status header"
  assert_contains "$output" "Local branch:" "Should show local branch"
  assert_contains "$output" "Remote:" "Should show remote"
  assert_contains "$output" "Target branch:" "Should show target branch"
  assert_contains "$output" "Status:" "Should show status"
}

test_command_availability() {
  # Test that gex recognizes publish command by trying to run it
  local help_output
  if help_output="$("$GEX_ROOT/gex" publish --help 2>&1)"; then
    assert_contains "$help_output" "Usage: gex publish" "Should be able to get publish help"
  else
    log_fail "gex publish command not found or failed"
    return 1
  fi
}

# Main test execution
main() {
  echo "${BOLD}Running gex publish tests${RESET}"
  echo "=========================================="
  echo

  # Setup
  setup_test
  trap cleanup_test EXIT

  # Run tests
  run_test "help_output" test_help_output
  run_test "dry_run_basic" test_dry_run_basic
  run_test "detached_head_error" test_detached_head_error
  run_test "nonexistent_remote_error" test_nonexistent_remote_error
  run_test "remote_branch_options" test_remote_branch_options
  run_test "to_option_parsing" test_to_option_parsing
  run_test "invalid_to_format" test_invalid_to_format
  run_test "protected_branch_warning" test_protected_branch_warning
  run_test "force_options" test_force_options
  run_test "no_set_upstream_option" test_no_set_upstream_option
  run_test "integration_with_gex_start" test_integration_with_gex_start
  run_test "status_information" test_status_information
  run_test "command_availability" test_command_availability

  # Summary
  echo "=========================================="
  echo "${BOLD}Test Summary${RESET}"
  echo "Tests run:    $TESTS_RUN"
  echo "Tests passed: ${GREEN}$TESTS_PASSED${RESET}"
  echo "Tests failed: ${RED}$TESTS_FAILED${RESET}"

  if [ $TESTS_FAILED -eq 0 ]; then
    echo
    echo "${GREEN}${BOLD}All tests passed!${RESET}"
    exit 0
  else
    echo
    echo "${RED}${BOLD}Some tests failed!${RESET}"
    exit 1
  fi
}

# Run main function if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main "$@"
fi

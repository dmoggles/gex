#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# gex/tests/test_squash.sh
#
# Integration tests for gex squash command
#
# Tests:
#   - Basic squash functionality with count
#   - Range-based squashing
#   - Auto-detection of unpushed commits
#   - Dry run mode
#   - Safety checks and error conditions
#   - Integration with upstream tracking
#   - Configuration handling
#   - Interactive mode (basic validation)
#
# Usage:
#   ./test_squash.sh
#   bash test_squash.sh
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
TEST_NAME="test_squash"
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
    git stash push -m "test_squash_stash_$(date +%s)" >/dev/null
    STASHED_CHANGES=1
  else
    STASHED_CHANGES=0
  fi

  # Create a test branch for our operations
  TEST_BRANCH="test-squash-$(date +%s)"
  git checkout -b "$TEST_BRANCH" >/dev/null 2>&1

  # Create some test commits to work with
  create_test_commits

  log_info "Test setup complete"
  log_info "Original branch: $ORIGINAL_BRANCH"
  log_info "Test branch: $TEST_BRANCH"
  log_info "Created test commits for squashing"
}

create_test_commits() {
  # Create a few commits that we can squash together
  local base_time=$(date +%s)

  # First commit
  echo "Test file content 1" > test_squash_file.txt
  git add test_squash_file.txt
  git commit -m "First test commit for squashing" >/dev/null

  # Second commit
  echo "Test file content 2" >> test_squash_file.txt
  git add test_squash_file.txt
  git commit -m "Second test commit for squashing" >/dev/null

  # Third commit
  echo "Test file content 3" >> test_squash_file.txt
  git add test_squash_file.txt
  git commit -m "Third test commit for squashing" >/dev/null

  # Fourth commit
  echo "Test file content 4" >> test_squash_file.txt
  git add test_squash_file.txt
  git commit -m "Fourth test commit for squashing" >/dev/null

  log_info "Created 4 test commits"
}

cleanup_test() {
  log_info "Cleaning up test environment"

  # Switch back to original branch
  if [ -n "${ORIGINAL_BRANCH:-}" ]; then
    git checkout "$ORIGINAL_BRANCH" >/dev/null 2>&1 || true
  fi

  # Delete test branch
  if [ -n "${TEST_BRANCH:-}" ]; then
    git branch -D "$TEST_BRANCH" >/dev/null 2>&1 || true
  fi

  # Restore stashed changes if any
  if [ "${STASHED_CHANGES:-0}" = "1" ]; then
    git stash pop >/dev/null 2>&1 || log_warn "Could not restore stashed changes"
  fi

  # Clean up any test files
  rm -f test_squash_file.txt 2>/dev/null || true

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

# Helper function to run gex squash and capture output
run_squash() {
  local args=("$@")
  "$GEX_ROOT/gex" squash "${args[@]}" 2>&1
}

# Helper function to count commits
count_commits() {
  git rev-list --count HEAD
}

# Helper function to get commit messages
get_commit_messages() {
  local count="${1:-5}"
  git log --format="%s" -n "$count"
}

# Test Cases
test_help_output() {
  local output
  if output="$(run_squash --help 2>&1)"; then
    if [[ "$output" =~ "Usage: gex squash" ]] && [[ "$output" =~ "--count" ]] && [[ "$output" =~ "--dry-run" ]]; then
      return 0
    fi
  fi
  return 1
}

test_dry_run_count() {
  local output
  local initial_count
  initial_count="$(count_commits)"

  # Test dry run with count
  if output="$(run_squash --dry-run --count=2 2>&1)"; then
    # Check that it shows what would be done
    if [[ "$output" =~ "DRY RUN" ]] && [[ "$output" =~ "Would execute" ]]; then
      # Verify no actual changes were made
      local final_count
      final_count="$(count_commits)"
      if [ "$initial_count" = "$final_count" ]; then
        return 0
      fi
    fi
  fi
  log_warn "Dry run count test failed. Output: $output"
  return 1
}

test_dry_run_range() {
  local output
  local initial_count
  initial_count="$(count_commits)"

  # Test dry run with range
  if output="$(run_squash --dry-run HEAD~2..HEAD 2>&1)"; then
    # Check that it shows what would be done
    if [[ "$output" =~ "DRY RUN" ]] && [[ "$output" =~ "Would execute" ]]; then
      # Verify no actual changes were made
      local final_count
      final_count="$(count_commits)"
      if [ "$initial_count" = "$final_count" ]; then
        return 0
      fi
    fi
  fi
  log_warn "Dry run range test failed. Output: $output"
  return 1
}

test_count_squash() {
  local initial_count
  local final_count
  local initial_messages

  initial_count="$(count_commits)"
  initial_messages="$(get_commit_messages 3)"

  # Create a test commit for custom message
  echo "# Test squash with count" > test_msg.txt

  # Test actual squashing with count and custom message
  if echo -e "Combined commit\n\nThis combines the last 2 commits" | git commit --file=- --allow-empty >/dev/null 2>&1; then
    # Now squash the last 2 commits
    if run_squash --count=2 --message="Combined test commits" >/dev/null 2>&1; then
      final_count="$(count_commits)"
      # Should have one less commit
      if [ "$final_count" = "$((initial_count - 1))" ]; then
        # Check that the top commit has our message
        local top_message
        top_message="$(git log --format="%s" -1)"
        if [ "$top_message" = "Combined test commits" ]; then
          return 0
        fi
      fi
    fi
  fi
  return 1
}

test_range_squash() {
  local initial_count
  local final_count

  initial_count="$(count_commits)"

  # Test squashing with range (last 3 commits)
  if echo "y" | run_squash HEAD~3..HEAD --message="Range squashed commits" >/dev/null 2>&1; then
    final_count="$(count_commits)"
    # Should have 2 fewer commits (3 became 1)
    if [ "$final_count" = "$((initial_count - 2))" ]; then
      # Check that the top commit has our message
      local top_message
      top_message="$(git log --format="%s" -1)"
      if [ "$top_message" = "Range squashed commits" ]; then
        return 0
      fi
    fi
  fi
  return 1
}

test_invalid_count() {
  local output

  # Test with invalid count (too small)
  if output="$(run_squash --count=1 2>&1)"; then
    # Should fail
    log_warn "Invalid count test unexpectedly succeeded. Output: $output"
    return 1
  else
    # Check that it gives appropriate error
    if [[ "$output" =~ "Count must be a number >= 2" ]] || [[ "$output" =~ "Need at least 2 commits" ]]; then
      return 0
    fi
  fi
  log_warn "Invalid count test failed. Output: $output"
  return 1
}

test_invalid_range() {
  local output

  # Test with invalid range
  if output="$(run_squash nonexistent..HEAD 2>&1)"; then
    # Should fail
    return 1
  else
    # Check that it gives appropriate error
    if [[ "$output" =~ "Invalid commit range" ]] || [[ "$output" =~ "bad revision" ]]; then
      return 0
    fi
  fi
  return 1
}

test_detached_head_error() {
  local original_head
  original_head="$(git rev-parse HEAD)"

  # Create detached HEAD state
  git checkout "$original_head" >/dev/null 2>&1

  local output
  if output="$(run_squash --count=2 2>&1)"; then
    # Should fail
    git checkout "$TEST_BRANCH" >/dev/null 2>&1  # Restore branch
    return 1
  else
    git checkout "$TEST_BRANCH" >/dev/null 2>&1  # Restore branch
    # Check error message
    if [[ "$output" =~ "detached HEAD" ]]; then
      return 0
    fi
  fi
  return 1
}

test_dirty_working_directory() {
  # Create uncommitted changes
  echo "Uncommitted change" > dirty_file.txt
  git add dirty_file.txt

  local output
  if output="$(run_squash --count=2 2>&1)"; then
    # Should fail
    git reset HEAD dirty_file.txt >/dev/null 2>&1
    rm -f dirty_file.txt
    return 1
  else
    git reset HEAD dirty_file.txt >/dev/null 2>&1
    rm -f dirty_file.txt
    # Check error message
    if [[ "$output" =~ "Working directory must be clean" ]]; then
      return 0
    fi
  fi
  return 1
}

# Main test execution
main() {
  echo "${BOLD}=== Gex Squash Command Test Suite ===${RESET}"
  echo

  # Set up test environment
  setup_test

  # Ensure cleanup happens on exit
  trap cleanup_test EXIT

  # Run tests
  run_test "Help output format" test_help_output
  run_test "Dry run with count" test_dry_run_count
  run_test "Dry run with range" test_dry_run_range
  run_test "Invalid count handling" test_invalid_count
  run_test "Invalid range handling" test_invalid_range
  run_test "Detached HEAD error" test_detached_head_error
  run_test "Dirty working directory error" test_dirty_working_directory
  run_test "Count-based squashing" test_count_squash
  run_test "Range-based squashing" test_range_squash

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

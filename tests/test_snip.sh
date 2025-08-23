#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# gex/tests/test_snip.sh
#
# Integration tests for gex snip command
#
# Tests:
#   - Basic snip functionality and dry run mode
#   - Target branch detection and validation
#   - Commit selection and validation
#   - Safety checks (lost commits, clean worktree, etc.)
#   - Keep original branch functionality
#   - Force move operations
#   - Configuration handling
#   - Error conditions and edge cases
#
# Usage:
#   ./test_snip.sh
#   bash test_snip.sh
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
TEST_NAME="test_snip"
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

  # Save current branch and commit
  ORIGINAL_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")"
  ORIGINAL_COMMIT="$(git rev-parse HEAD)"

  # Ensure we start from a clean state
  if [ -n "$(git status --porcelain)" ]; then
    log_warn "Working directory not clean, stashing changes"
    git stash push -m "test_snip_stash_$(date +%s)"
  fi

  log_info "Original branch: $ORIGINAL_BRANCH"
  log_info "Original commit: $(git rev-parse --short "$ORIGINAL_COMMIT")"
}

cleanup_test() {
  log_info "Cleaning up test environment"

  # Switch back to original branch
  if [ -n "${ORIGINAL_BRANCH:-}" ]; then
    git checkout "$ORIGINAL_BRANCH" >/dev/null 2>&1 || true
  fi

  # Clean up any test branches
  local test_branches
  test_branches="$(git branch | grep -E "(test-snip|snipped)" | sed 's/^[* ]*//' || true)"
  if [ -n "$test_branches" ]; then
    log_info "Cleaning up test branches: $test_branches"
    echo "$test_branches" | xargs -r git branch -D >/dev/null 2>&1 || true
  fi

  # Restore stashed changes if any
  if git stash list | grep -q "test_snip_stash_"; then
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

# Helper functions for test setup
create_test_branch_with_commits() {
  local branch_name="$1"
  local base_branch="${2:-main}"
  local num_commits="${3:-2}"

  # Create branch
  git checkout -b "$branch_name" "$base_branch" >/dev/null 2>&1

  # Add commits
  for i in $(seq 1 "$num_commits"); do
    echo "Test content $i" > "test-file-$i.txt"
    git add "test-file-$i.txt"
    git commit -m "Test commit $i on $branch_name" >/dev/null 2>&1
  done
}

# Test functions
test_help_output() {
  local output
  output="$("$GEX_ROOT/gex" snip --help)"

  assert_contains "$output" "Usage: gex snip" "Help should show usage"
  assert_contains "$output" "--onto=" "Help should show onto option"
  assert_contains "$output" "--commit=" "Help should show commit option"
  assert_contains "$output" "--dry-run" "Help should show dry-run option"
  assert_contains "$output" "Examples:" "Help should show examples"
  assert_contains "$output" "Cherry-pick" "Help should mention cherry-pick"
}

test_dry_run_basic() {
  # Switch to original branch to ensure clean state
  git checkout "$ORIGINAL_BRANCH" >/dev/null 2>&1

  # Create a test branch with a commit
  create_test_branch_with_commits "test-snip-dry-run" "$ORIGINAL_BRANCH" 1

  local output
  output="$("$GEX_ROOT/gex" snip --onto="$ORIGINAL_BRANCH" --dry-run 2>&1)"

  assert_contains "$output" "DRY RUN" "Should indicate dry run mode"
  assert_contains "$output" "Would execute:" "Should show what would be executed"
  assert_contains "$output" "git checkout" "Should show git checkout command"
  assert_contains "$output" "git cherry-pick" "Should show cherry-pick command"

  # Clean up
  git checkout "$ORIGINAL_BRANCH" >/dev/null 2>&1
  git branch -D "test-snip-dry-run" >/dev/null 2>&1
}

test_detached_head_error() {
  # Create a detached HEAD state
  local commit
  commit="$(git rev-parse HEAD)"
  git checkout "$commit" >/dev/null 2>&1

  local output
  if output="$("$GEX_ROOT/gex" snip --dry-run 2>&1)"; then
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

test_nonexistent_target_branch() {
  # Ensure we're on the original branch
  git checkout "$ORIGINAL_BRANCH" >/dev/null 2>&1

  local output
  if output="$("$GEX_ROOT/gex" snip --onto=nonexistent-branch --dry-run 2>&1)"; then
    log_fail "Command should fail with nonexistent target branch"
    return 1
  else
    assert_contains "$output" "does not exist" "Should mention branch doesn't exist"
    return 0
  fi
}

test_nonexistent_commit() {
  # Ensure we're on the original branch
  git checkout "$ORIGINAL_BRANCH" >/dev/null 2>&1

  local output
  if output="$("$GEX_ROOT/gex" snip --commit=abc123nonexistent --dry-run 2>&1)"; then
    log_fail "Command should fail with nonexistent commit"
    return 1
  else
    assert_contains "$output" "does not exist" "Should mention commit doesn't exist"
    return 0
  fi
}

test_target_branch_auto_detection() {
  # Switch to original branch
  git checkout "$ORIGINAL_BRANCH" >/dev/null 2>&1

  # Create test branch
  create_test_branch_with_commits "test-snip-auto-detect" "$ORIGINAL_BRANCH" 1

  local output
  output="$("$GEX_ROOT/gex" snip --dry-run 2>&1)"

  # Should auto-detect main or develop as target
  if git show-ref --verify --quiet refs/heads/main; then
    assert_contains "$output" "Target branch:     main" "Should auto-detect main"
  elif git show-ref --verify --quiet refs/heads/develop; then
    assert_contains "$output" "Target branch:     develop" "Should auto-detect develop"
  else
    # Should detect some branch
    assert_contains "$output" "Target branch:" "Should detect some target branch"
  fi

  # Clean up
  git checkout "$ORIGINAL_BRANCH" >/dev/null 2>&1
  git branch -D "test-snip-auto-detect" >/dev/null 2>&1
}

test_custom_target_branch() {
  # Switch to original branch
  git checkout "$ORIGINAL_BRANCH" >/dev/null 2>&1

  # Create test branch
  create_test_branch_with_commits "test-snip-custom-target" "$ORIGINAL_BRANCH" 1

  local output
  output="$("$GEX_ROOT/gex" snip --onto="$ORIGINAL_BRANCH" --dry-run 2>&1)"

  assert_contains "$output" "Target branch:     $ORIGINAL_BRANCH" "Should use specified target branch"

  # Clean up
  git checkout "$ORIGINAL_BRANCH" >/dev/null 2>&1
  git branch -D "test-snip-custom-target" >/dev/null 2>&1
}

test_custom_commit_selection() {
  # Switch to original branch
  git checkout "$ORIGINAL_BRANCH" >/dev/null 2>&1

  # Create test branch with multiple commits
  create_test_branch_with_commits "test-snip-custom-commit" "$ORIGINAL_BRANCH" 2

  # Get the first commit hash
  local first_commit
  first_commit="$(git rev-parse HEAD~1)"
  local first_commit_short
  first_commit_short="$(git rev-parse --short HEAD~1)"

  local output
  output="$("$GEX_ROOT/gex" snip --commit=HEAD~1 --onto="$ORIGINAL_BRANCH" --dry-run 2>&1)"

  assert_contains "$output" "Commit to snip:    $first_commit_short" "Should show specified commit"

  # Clean up
  git checkout "$ORIGINAL_BRANCH" >/dev/null 2>&1
  git branch -D "test-snip-custom-commit" >/dev/null 2>&1
}

test_lost_commits_warning() {
  # Switch to original branch
  git checkout "$ORIGINAL_BRANCH" >/dev/null 2>&1

  # Create test branch with multiple commits
  create_test_branch_with_commits "test-snip-lost-commits" "$ORIGINAL_BRANCH" 3

  # Try to snip an earlier commit (should warn about lost commits)
  local output
  if output="$("$GEX_ROOT/gex" snip --commit=HEAD~2 --onto="$ORIGINAL_BRANCH" --dry-run 2>&1)"; then
    log_fail "Command should fail due to lost commits"
    git checkout "$ORIGINAL_BRANCH" >/dev/null 2>&1
    git branch -D "test-snip-lost-commits" >/dev/null 2>&1
    return 1
  else
    assert_contains "$output" "would lose" "Should warn about lost commits"
    assert_contains "$output" "commit(s)" "Should mention commits"
    assert_contains "$output" "--force" "Should mention force option"

    # Clean up
    git checkout "$ORIGINAL_BRANCH" >/dev/null 2>&1
    git branch -D "test-snip-lost-commits" >/dev/null 2>&1
    return 0
  fi
}

test_force_with_lost_commits() {
  # Switch to original branch
  git checkout "$ORIGINAL_BRANCH" >/dev/null 2>&1

  # Create test branch with multiple commits
  create_test_branch_with_commits "test-snip-force" "$ORIGINAL_BRANCH" 3

  # Try to snip an earlier commit with --force
  local output
  output="$("$GEX_ROOT/gex" snip --commit=HEAD~2 --onto="$ORIGINAL_BRANCH" --force --dry-run 2>&1)"

  assert_contains "$output" "would lose" "Should still warn about lost commits"
  assert_contains "$output" "DRY RUN - Would execute:" "Should proceed with force"

  # Clean up
  git checkout "$ORIGINAL_BRANCH" >/dev/null 2>&1
  git branch -D "test-snip-force" >/dev/null 2>&1
}

test_keep_original_option() {
  # Switch to original branch
  git checkout "$ORIGINAL_BRANCH" >/dev/null 2>&1

  # Create test branch
  create_test_branch_with_commits "test-snip-keep-original" "$ORIGINAL_BRANCH" 1

  local output
  output="$("$GEX_ROOT/gex" snip --keep-original --onto="$ORIGINAL_BRANCH" --dry-run 2>&1)"

  assert_contains "$output" "original kept" "Should indicate original branch kept"
  assert_contains "$output" "snipped" "Should show new branch name"

  # Clean up
  git checkout "$ORIGINAL_BRANCH" >/dev/null 2>&1
  git branch -D "test-snip-keep-original" >/dev/null 2>&1
}

test_custom_new_branch_name() {
  # Switch to original branch
  git checkout "$ORIGINAL_BRANCH" >/dev/null 2>&1

  # Create test branch
  create_test_branch_with_commits "test-snip-custom-name" "$ORIGINAL_BRANCH" 1

  local output
  output="$("$GEX_ROOT/gex" snip --keep-original --branch=my-custom-branch --onto="$ORIGINAL_BRANCH" --dry-run 2>&1)"

  assert_contains "$output" "New branch:        my-custom-branch" "Should show custom branch name"

  # Clean up
  git checkout "$ORIGINAL_BRANCH" >/dev/null 2>&1
  git branch -D "test-snip-custom-name" >/dev/null 2>&1
}

test_snip_onto_same_branch_error() {
  # Try to snip onto the same branch we're on
  local output
  if output="$("$GEX_ROOT/gex" snip --onto="$ORIGINAL_BRANCH" --dry-run 2>&1)"; then
    log_fail "Command should fail when snipping onto same branch"
    return 1
  else
    assert_contains "$output" "onto itself" "Should mention can't snip onto same branch"
    return 0
  fi
}

test_uncommitted_changes_error() {
  # Create a file with uncommitted changes
  echo "uncommitted" > test-uncommitted.txt
  git add test-uncommitted.txt

  local output
  if output="$("$GEX_ROOT/gex" snip --dry-run 2>&1)"; then
    # Clean up
    git reset HEAD test-uncommitted.txt >/dev/null 2>&1
    rm -f test-uncommitted.txt
    log_fail "Command should fail with uncommitted changes"
    return 1
  else
    # Clean up
    git reset HEAD test-uncommitted.txt >/dev/null 2>&1
    rm -f test-uncommitted.txt
    assert_contains "$output" "not clean" "Should mention working directory not clean"
    return 0
  fi
}

test_status_information_display() {
  # Switch to original branch
  git checkout "$ORIGINAL_BRANCH" >/dev/null 2>&1

  # Create test branch
  create_test_branch_with_commits "test-snip-status" "$ORIGINAL_BRANCH" 1

  local output
  output="$("$GEX_ROOT/gex" snip --onto="$ORIGINAL_BRANCH" --dry-run 2>&1)"

  assert_contains "$output" "Snip Operation Summary:" "Should show operation summary"
  assert_contains "$output" "Current branch:" "Should show current branch"
  assert_contains "$output" "Target branch:" "Should show target branch"
  assert_contains "$output" "Commit to snip:" "Should show commit to snip"
  assert_contains "$output" "Commit message:" "Should show commit message"
  assert_contains "$output" "Author:" "Should show author"
  assert_contains "$output" "Date:" "Should show date"
  assert_contains "$output" "Commit contents:" "Should show commit contents"

  # Clean up
  git checkout "$ORIGINAL_BRANCH" >/dev/null 2>&1
  git branch -D "test-snip-status" >/dev/null 2>&1
}

test_command_availability() {
  # Test that gex recognizes snip command by trying to run it
  local help_output
  if help_output="$("$GEX_ROOT/gex" snip --help 2>&1)"; then
    assert_contains "$help_output" "Usage: gex snip" "Should be able to get snip help"
  else
    log_fail "gex snip command not found or failed"
    return 1
  fi
}

# Main test execution
main() {
  echo "${BOLD}Running gex snip tests${RESET}"
  echo "=========================================="
  echo

  # Setup
  setup_test
  trap cleanup_test EXIT

  # Run tests
  run_test "help_output" test_help_output
  run_test "dry_run_basic" test_dry_run_basic
  run_test "detached_head_error" test_detached_head_error
  run_test "nonexistent_target_branch" test_nonexistent_target_branch
  run_test "nonexistent_commit" test_nonexistent_commit
  run_test "target_branch_auto_detection" test_target_branch_auto_detection
  run_test "custom_target_branch" test_custom_target_branch
  run_test "custom_commit_selection" test_custom_commit_selection
  run_test "lost_commits_warning" test_lost_commits_warning
  run_test "force_with_lost_commits" test_force_with_lost_commits
  run_test "keep_original_option" test_keep_original_option
  run_test "custom_new_branch_name" test_custom_new_branch_name
  run_test "snip_onto_same_branch_error" test_snip_onto_same_branch_error
  run_test "uncommitted_changes_error" test_uncommitted_changes_error
  run_test "status_information_display" test_status_information_display
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

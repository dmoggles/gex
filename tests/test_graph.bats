#!/usr/bin/env bats
#
# test_graph.bats - Placeholder / initial tests for `gex graph`
#
# These tests exercise the basic flows of the graph command in a synthetic
# temporary repository. They intentionally avoid asserting on the exact ASCII
# graph structure (which can shift with git versions) and instead validate
# presence / absence of commit subjects as a proxy.
#
# To run:
#   bats gex/tests/test_graph.bats
#
# Prerequisites:
#   - bash
#   - git
#   - bats (https://github.com/bats-core/bats-core)
#
# Roadmap:
#   - Add tests for:
#       * --exclude patterns
#       * --highlight color presence (requires ANSI parsing)
#       * --style unicode substitution
#       * Detached HEAD inclusion
#       * Error handling for unknown options
#       * Large repo performance (maybe via fixture)
#

load 'test_helper' 2>/dev/null || true  # Optional future shared helpers

setup() {
  # Path to gex project root (parent of tests directory)
  GEX_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  GEX_BIN="$GEX_ROOT/gex"

  if [ ! -x "$GEX_BIN" ]; then
    echo "gex executable not found at $GEX_BIN" >&2
    return 1
  fi

  # Create isolated temp repo
  TMP_REPO="$(mktemp -d 2>/dev/null || mktemp -d -t gex-graph-spec)"
  cd "$TMP_REPO"

  git init -q
  git config user.name "Test User"
  git config user.email "test@example.com"

  # Base commit on main
  echo "root" > file.txt
  git add file.txt
  git commit -q -m "feat: root commit"

  # feature/one branch
  git checkout -q -b feature/one
  echo "one1" >> file.txt
  git commit -q -am "feat: feature one change 1"
  echo "one2" >> file.txt
  git commit -q -am "feat: feature one change 2"

  # feature/two branch from main
  git checkout -q main
  git checkout -q -b feature/two
  echo "two1" >> file.txt
  git commit -q -am "feat: feature two change 1"

  # Return to main
  git checkout -q main
}

teardown() {
  rm -rf "$TMP_REPO"
}

# Utility: run gex graph with consistent env
_run_graph() {
  # Always disable color for stable assertions
  NO_COLOR=1 "$GEX_BIN" graph --no-color "$@"
}

@test "graph --help outputs usage header" {
  run "$GEX_BIN" graph --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: gex graph"* ]]
  [[ "$output" == *"--branches"* ]]
}

@test "graph default shows commits from local branches" {
  run _run_graph
  [ "$status" -eq 0 ]
  # Root commit always present
  [[ "$output" == *"feat: root commit"* ]]
  # Since default includes local branches (main + feature/*), feature commits appear
  [[ "$output" == *"feat: feature one change 1"* ]]
  [[ "$output" == *"feat: feature two change 1"* ]]
}

@test "graph filters to specific branch via --branches" {
  run _run_graph --branches feature/one
  [ "$status" -eq 0 ]
  [[ "$output" == *"feat: feature one change 1"* ]]
  [[ "$output" == *"feat: feature one change 2"* ]]
  # Should not include feature two commit when filtering to feature/one only
  [[ "$output" != *"feat: feature two change 1"* ]]
}

@test "graph glob pattern matches multiple branches" {
  run _run_graph --branches 'feature/*'
  [ "$status" -eq 0 ]
  [[ "$output" == *"feat: feature one change 1"* ]]
  [[ "$output" == *"feat: feature two change 1"* ]]
}

@test "graph highlight option does not error (basic smoke)" {
  run _run_graph --branches 'feature/*' --highlight feature/one
  [ "$status" -eq 0 ]
  # Presence of at least one known commit ensures output generated
  [[ "$output" == *"feat: feature one change 1"* ]]
}

@test "graph --max limits number of commits (approximate sanity)" {
  # Request only 2 commits; ensure not all three feature commits appear.
  run _run_graph --branches 'feature/*' --max 2
  [ "$status" -eq 0 ]
  # We expect at most 2 feature commits; if we find all 3, the limit failed.
  local count_one count_two
  count_one=$(grep -c "feature one change" <<<"$output" || true)
  count_two=$(grep -c "feature two change" <<<"$output" || true)
  total=$((count_one + count_two))
  [ "$total" -le 2 ]
}

@test "graph --author filters results" {
  # Add a commit by a different author
  git checkout -q feature/two
  GIT_AUTHOR_NAME="Other User" GIT_AUTHOR_EMAIL="other@example.com" \
    git commit --allow-empty -q -m "chore: other user empty commit"

  run _run_graph --author "Other User" --branches feature/two
  [ "$status" -eq 0 ]
  [[ "$output" == *"chore: other user empty commit"* ]]
  # Should not include commits by Test User
  [[ "$output" != *"feat: feature two change 1"* ]]
}

@test "graph --merges-only produces no output before any merges" {
  run _run_graph --merges-only
  [ "$status" -eq 0 ]
  # In this repo there are no merge commits yet; expect empty or only graph lines
  # We allow whitespace / graph pipes; fail if a known subject appears.
  [[ "$output" != *"feat: root commit"* ]]
  [[ "$output" != *"feature one change"* ]]
}

@test "graph errors gracefully when pattern matches nothing" {
  run _run_graph --branches does-not-exist
  [ "$status" -ne 0 ]
  [[ "$output" == *"No branches matched selection"* ]]
}

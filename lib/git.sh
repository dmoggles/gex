#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# gex/lib/git.sh
#
# Git helper library for gex (Git eXtended)
#
# This library provides higher-level convenience functions that wrap
# common git plumbing operations, normalize outputs, and offer graceful
# fallbacks. It assumes it is sourced inside a bash shell and that
# gex/lib/core.sh may already be loaded (for logging utilities).
#
# None of the functions print extraneous text to stdout (only the
# requested data) so they can be safely composed in command pipelines.
# Errors are generally surfaced via non‑zero exit codes; callers decide
# whether to terminate.
#
# Conventions:
#  - Functions prefixed with gex_git_
#  - Return data on stdout; write diagnostics (if any) to stderr
#  - Avoid interactive prompts
#
# -----------------------------------------------------------------------------

# Safety (do not override if already set by parent script)
set -euo pipefail

# Ensure we are in bash
if [ -z "${BASH_VERSION:-}" ]; then
  echo "git.sh requires bash" >&2
  return 1 2>/dev/null || exit 1
fi

# -----------------------------------------------------------------------------
# Internal minimal fallbacks (if core.sh not loaded)
# -----------------------------------------------------------------------------
if ! declare -F gex_debug >/dev/null 2>&1; then
  gex_debug() { :; }
fi
if ! declare -F gex_warn >/dev/null 2>&1; then
  gex_warn() { echo "WARN: $*" >&2; }
fi
if ! declare -F gex_error >/dev/null 2>&1; then
  gex_error() { echo "ERROR: $*" >&2; }
fi
if ! declare -F gex_die >/dev/null 2>&1; then
  gex_die() { gex_error "$*"; exit 1; }
fi
if ! declare -F gex_match_glob >/dev/null 2>&1; then
  # Simple glob matcher supporting only * wildcard
  gex_match_glob() {
    local text="$1" glob="$2"
    local rx="^${glob//\*/.*}$"
    [[ "$text" =~ $rx ]]
  }
fi

# -----------------------------------------------------------------------------
# Basic repository / ref utilities
# -----------------------------------------------------------------------------

gex_git_is_repo() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1
}

gex_git_require_repo() {
  gex_git_is_repo || gex_die "Not inside a git repository."
}

gex_git_is_detached() {
  ! git symbolic-ref -q HEAD >/dev/null 2>&1
}

gex_git_current_branch() {
  if gex_git_is_detached; then
    return 1
  fi
  git symbolic-ref --short HEAD 2>/dev/null
}

gex_git_head_commit() {
  git rev-parse --verify HEAD 2>/dev/null
}

gex_git_short_hash() {
  local commit="${1:-}"
  [ -n "$commit" ] || return 1
  git rev-parse --short "$commit" 2>/dev/null
}

gex_git_commit_exists() {
  local rev="${1:-}"
  [ -n "$rev" ] || return 1
  git cat-file -e "${rev}^{commit}" 2>/dev/null
}

gex_git_resolve_ref() {
  local ref="${1:-}"
  [ -n "$ref" ] || return 1
  git rev-parse --verify "$ref" 2>/dev/null
}

gex_git_parent_commits() {
  local commit="${1:-}"
  [ -n "$commit" ] || return 1
  git show -s --format='%P' "$commit" 2>/dev/null
}

gex_git_is_ancestor() {
  local anc="${1:-}" desc="${2:-}"
  [ -n "$anc" ] && [ -n "$desc" ] || return 2
  git merge-base --is-ancestor "$anc" "$desc" 2>/dev/null
}

gex_git_merge_base() {
  local a="${1:-}" b="${2:-}"
  [ -n "$a" ] && [ -n "$b" ] || return 2
  git merge-base "$a" "$b" 2>/dev/null
}

gex_git_branch_contains() {
  local branch="${1:-}" commit="${2:-}"
  [ -n "$branch" ] && [ -n "$commit" ] || return 2
  git branch --contains "$commit" 2>/dev/null | sed 's/^[* ] *//;' | grep -Fx "$branch" >/dev/null 2>&1
}

# -----------------------------------------------------------------------------
# Branch listing
# -----------------------------------------------------------------------------

gex_git_local_branches() {
  git for-each-ref --format='%(refname:short)' refs/heads 2>/dev/null | sort
}

gex_git_remote_branches() {
  git for-each-ref --format='%(refname:short)' refs/remotes 2>/dev/null | sort
}

# Return all branches. Args:
#   $1 include_remotes (0/1)
gex_git_all_branches() {
  local include_remotes="${1:-0}"
  if [ "$include_remotes" = "1" ]; then
    { gex_git_local_branches; gex_git_remote_branches; } | awk '!seen[$0]++' | sort
  else
    gex_git_local_branches
  fi
}

# Determine default branch (heuristics):
# 1. origin/HEAD symbolic ref if exists
# 2. main
# 3. master
# 4. First local branch
gex_git_default_branch() {
  local ref
  ref="$(git symbolic-ref -q refs/remotes/origin/HEAD 2>/dev/null || true)"
  if [ -n "$ref" ]; then
    basename "${ref}"
    return 0
  fi
  if git show-ref --verify --quiet refs/heads/main; then
    echo "main"; return 0
  fi
  if git show-ref --verify --quiet refs/heads/master; then
    echo "master"; return 0
  fi
  gex_git_local_branches | head -n1
}

# -----------------------------------------------------------------------------
# Pattern resolution
# -----------------------------------------------------------------------------
# Resolve a set of glob patterns against existing branches.
# Args:
#   patterns... (at least one)  (globs; * only)
#   environment:
#     GEX_INCLUDE_REMOTES=0|1
#
# Deduplicated output.
gex_git_resolve_patterns() {
  local include_remotes="${GEX_INCLUDE_REMOTES:-0}"
  local patterns=("$@")
  [ ${#patterns[@]} -gt 0 ] || return 1
  local all
  mapfile -t all < <(gex_git_all_branches "$include_remotes")
  local matched=()
  local b p
  for b in "${all[@]}"; do
    for p in "${patterns[@]}"; do
      if gex_match_glob "$b" "$p"; then
        matched+=("$b")
        break
      fi
    done
  done
  if [ ${#matched[@]} -gt 0 ]; then
    printf '%s\n' "${matched[@]}" | awk '!seen[$0]++'
  fi
}

# Return explicit revision arguments representing inclusion + exclusions.
# Inputs:
#   inclusions: array of branch names (already resolved)
#   exclusions: array of glob patterns (NOT yet resolved)
# Environment:
#   GEX_INCLUDE_REMOTES=0|1 (for exclusion resolution)
gex_git_build_rev_args() {
  local -a inclusions=()
  local -a exclusions=()
  local mode=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --include) shift; inclusions+=("$1");;
      --exclude) shift; exclusions+=("$1");;
      *) echo "gex_git_build_rev_args: unknown token $1" >&2; return 2;;
    esac
    shift || true
  done

  local include_remotes="${GEX_INCLUDE_REMOTES:-0}"
  local all
  mapfile -t all < <(gex_git_all_branches "$include_remotes")

  local out=("${inclusions[@]}")

  # For each exclusion pattern, resolve to branches and prepend ^ref
  local pat br
  for pat in "${exclusions[@]}"; do
    for br in "${all[@]}"; do
      if gex_match_glob "$br" "$pat"; then
        out+=("^$br")
      fi
    done
  done

  printf '%s\n' "${out[@]}"
}

# -----------------------------------------------------------------------------
# Rev listing / graph data
# -----------------------------------------------------------------------------

# Wrapper around git rev-list with safe defaults. Accepts arbitrary trailing args.
# Examples:
#   gex_git_rev_list HEAD
#   gex_git_rev_list --max-count=100 main --not develop
gex_git_rev_list() {
  git rev-list "$@" 2>/dev/null
}

# Produce a simple adjacency list (parents) for commits reachable from given revs.
# Args: revs...
# Output lines: <commit> <parent1> <parent2> ...
gex_git_commit_parents_stream() {
  [ $# -gt 0 ] || return 1
  git rev-list --parents "$@" 2>/dev/null
}

# Enumerate commits reachable from branch A and not from branch B
# (i.e., unique to A). Args: A B
gex_git_unique_commits() {
  local a="${1:-}" b="${2:-}"
  [ -n "$a" ] && [ -n "$b" ] || return 2
  git rev-list "${a}" --not "${b}" 2>/dev/null
}

# -----------------------------------------------------------------------------
# Safety / maintenance helpers
# -----------------------------------------------------------------------------

# Detect large objects (top N by size) - lightweight heuristic.
# Args:
#   $1 N (default 10)
gex_git_large_objects() {
  local limit="${1:-10}"
  git verify-pack -v "$(git rev-parse --git-dir)/objects/pack/"*.idx 2>/dev/null \
    | grep -E ' blob ' \
    | sort -k3nr \
    | head -n "$limit" \
    | awk '{printf "%s %s\n",$1,$3}' \
    | while read -r oid size; do
        local path
        path="$(git rev-list --all --objects | grep "^$oid " | cut -d' ' -f2- || true)"
        echo "$size $oid $path"
      done
}

# Check divergence between local and its tracking remote branch.
# Args:
#   $1 branch (defaults to current)
# Output: "<ahead> <behind>"
gex_git_branch_divergence() {
  local branch="${1:-}"
  if [ -z "$branch" ]; then
    branch="$(gex_git_current_branch || true)"
  fi
  [ -n "$branch" ] || return 1
  local upstream
  upstream="$(git rev-parse --abbrev-ref "${branch}@{upstream}" 2>/dev/null || true)"
  if [ -z "$upstream" ]; then
    echo "0 0"
    return 0
  fi
  local ahead behind
  ahead=$(git rev-list --left-right --count "${upstream}...${branch}" 2>/dev/null | awk '{print $2}')
  behind=$(git rev-list --left-right --count "${upstream}...${branch}" 2>/dev/null | awk '{print $1}')
  echo "${ahead:-0} ${behind:-0}"
}

# Check if working directory is clean (no uncommitted changes)
gex_git_is_clean() {
  [ -z "$(git status --porcelain 2>/dev/null)" ]
}

# -----------------------------------------------------------------------------
# Misc / formatting helpers
# -----------------------------------------------------------------------------

# Pretty print short log line for a commit (hash subject)
gex_git_one_line() {
  local rev="${1:-HEAD}"
  git show -s --format='%h %s' "$rev" 2>/dev/null
}

# List tags pointing at a commit
gex_git_tags_pointing_at() {
  local rev="${1:-HEAD}"
  git tag --points-at "$rev" 2>/dev/null
}

# -----------------------------------------------------------------------------
# End of git.sh
# -----------------------------------------------------------------------------

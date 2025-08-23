#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# gex/lib/core.sh
#
# Core shared library for gex (Git eXtended)
#
# Responsibilities:
#  - Safe shell execution settings
#  - Color / formatting helpers
#  - Logging utilities
#  - Generic helper functions (arrays, globs, CSV parsing, temp dirs)
#  - Git repository validation helpers
#  - Lightweight configuration loading (global + repo)
#
# Environment Variables:
#  NO_COLOR=1      Disable colored output
#  GEX_DEBUG=1     Enable debug logging
#  GEX_TRACE=1     Shell trace (should be enabled before main dispatcher ideally)
#
# This file is sourced by subcommands; do not execute directly.
# -----------------------------------------------------------------------------

# shellcheck shell=bash
set -euo pipefail

# -----------------------------------------------------------------------------
# Internal state (prefixed to avoid collisions)
# -----------------------------------------------------------------------------
: "${GEX_CONFIG_DIR:=${XDG_CONFIG_HOME:-$HOME/.config}/gex}"
: "${GEX_REPO_CONFIG_FILE:=.gexrc}"
: "${GEX_GLOBAL_CONFIG_FILE:=$GEX_CONFIG_DIR/config}"

# Create config dir if absent (ignore errors in read-only scenarios)
mkdir -p "$GEX_CONFIG_DIR" 2>/dev/null || true

# -----------------------------------------------------------------------------
# Color Handling
# -----------------------------------------------------------------------------
gex_color_enabled() {
  # Enabled if stdout is a TTY, NO_COLOR not set, and not explicitly disabled
  [ -t 1 ] && [ -z "${NO_COLOR:-}" ]
}

gex__init_colors() {
  if gex_color_enabled; then
    GEX_CLR_RED=$'\033[31m'
    GEX_CLR_GRN=$'\033[32m'
    GEX_CLR_YEL=$'\033[33m'
    GEX_CLR_BLU=$'\033[34m'
    GEX_CLR_MAG=$'\033[35m'
    GEX_CLR_CYN=$'\033[36m'
    GEX_CLR_BOLD=$'\033[1m'
    GEX_CLR_DIM=$'\033[2m'
    GEX_CLR_RST=$'\033[0m'
  else
    GEX_CLR_RED=""; GEX_CLR_GRN=""; GEX_CLR_YEL=""; GEX_CLR_BLU=""
    GEX_CLR_MAG=""; GEX_CLR_CYN=""; GEX_CLR_BOLD=""; GEX_CLR_DIM=""; GEX_CLR_RST=""
  fi
}

gex__init_colors

gex_color_wrap() {
  local code="$1"; shift
  if gex_color_enabled; then
    printf '\033[%sm%s\033[0m' "$code" "$*"
  else
    printf '%s' "$*"
  fi
}

# -----------------------------------------------------------------------------
# Logging
# -----------------------------------------------------------------------------
gex_info()  { echo "${GEX_CLR_GRN}INFO${GEX_CLR_RST}: $*" >&2; }
gex_warn()  { echo "${GEX_CLR_YEL}WARN${GEX_CLR_RST}: $*" >&2; }
gex_error() { echo "${GEX_CLR_RED}ERROR${GEX_CLR_RST}: $*" >&2; }
gex_debug() {
  if [ "${GEX_DEBUG:-0}" = "1" ]; then
    echo "${GEX_CLR_BLU}DEBUG${GEX_CLR_RST}: $*" >&2
  fi
}

gex_die() {
  gex_error "$*"
  exit 1
}

# -----------------------------------------------------------------------------
# Command availability
# -----------------------------------------------------------------------------
gex_have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

# -----------------------------------------------------------------------------
# Git helpers
# -----------------------------------------------------------------------------
gex_require_git_repo() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || gex_die "Not inside a git repository."
}

gex_git_is_detached() {
  ! git symbolic-ref -q HEAD >/dev/null 2>&1
}

gex_ensure_clean_worktree() {
  # Returns failure if there are staged or unstaged changes (ignores untracked if param set)
  local ignore_untracked="${1:-0}"
  local status_args=("--porcelain")
  [ "$ignore_untracked" = "1" ] && status_args+=("--untracked-files=no")
  if [ -n "$(git status "${status_args[@]}")" ]; then
    gex_die "Working tree not clean. Commit/stash changes first."
  fi
}

# -----------------------------------------------------------------------------
# General helpers
# -----------------------------------------------------------------------------
gex_join_by() {
  local IFS="$1"; shift
  echo "$*"
}

gex_split_csv() {
  # Splits comma-separated list into lines (ignores empty segments)
  local raw="${1:-}"
  local IFS=','
  for part in $raw; do
    [ -n "$part" ] && printf '%s\n' "$part"
  done
}

gex_glob_to_regex() {
  # Convert a simple glob with * wildcard to a regex
  # Note: Only * is handled intentionally for simplicity.
  local glob="$1"
  local escaped
  escaped=$(printf '%s' "$glob" | sed -E 's/[][\.^$+?(){}|]/\\&/g')
  escaped="${escaped//\*/.*}"
  printf '^%s$' "$escaped"
}

gex_match_glob() {
  local text="$1" glob="$2"
  local rx
  rx=$(gex_glob_to_regex "$glob")
  [[ "$text" =~ $rx ]]
}

gex_array_contains() {
  local needle="$1"; shift
  local x
  for x in "$@"; do
    [ "$x" = "$needle" ] && return 0
  done
  return 1
}

gex_array_dedupe() {
  # Reads lines on stdin, outputs unique preserving first occurrence
  awk '!seen[$0]++'
}

gex_temp_dir() {
  local dir
  dir="$(mktemp -d 2>/dev/null || mktemp -d -t gex)" || gex_die "Failed to create temp dir"
  echo "$dir"
}

gex_assert_nonempty() {
  local val="$1" name="$2"
  [ -n "$val" ] || gex_die "Expected non-empty value for: $name"
}

# -----------------------------------------------------------------------------
# Configuration loading
# Format:
#   key = value
#   # comments allowed
# Lookup order (first hit wins):
#   1. Repo local .gexrc (if inside repo)
#   2. Global config (~/.config/gex/config)
#   3. Environment variable GEX_<UPPER_KEY>
# -----------------------------------------------------------------------------
gex__read_config_file_value() {
  local file="$1" key="$2"
  [ -f "$file" ] || return 1
  # Grep line starting with key (allow spaces), ignore comments
  # shellcheck disable=SC2162
  while IFS= read -r line; do
    # Trim leading/trailing spaces
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    # Skip comments / empty
    [ -z "$line" ] && continue
    [[ "$line" =~ ^# ]] && continue
    # Split on first '='
    if [[ "$line" =~ ^([^=[:space:]]+)[[:space:]]*=[[:space:]]*(.*)$ ]]; then
      local k="${BASH_REMATCH[1]}"
      local v="${BASH_REMATCH[2]}"
      if [ "$k" = "$key" ]; then
        # Trim trailing spaces in value
        v="${v%"${v##*[![:space:]]}"}"
        echo "$v"
        return 0
      fi
    fi
  done < "$file"
  return 1
}

gex_config_get() {
  local key="$1"
  [ -n "$key" ] || gex_die "config_get requires a key"
  local env_key="GEX_${key^^}"

  # 1. Repo local
  if git rev-parse --show-toplevel >/dev/null 2>&1; then
    local repo_root
    repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
    if [ -n "$repo_root" ]; then
      local local_file="$repo_root/$GEX_REPO_CONFIG_FILE"
      if val=$(gex__read_config_file_value "$local_file" "$key"); then
        printf '%s' "$val"
        return 0
      fi
    fi
  fi

  # 2. Global
  if val=$(gex__read_config_file_value "$GEX_GLOBAL_CONFIG_FILE" "$key"); then
    printf '%s' "$val"
    return 0
  fi

  # 3. Environment
  if [ -n "${!env_key:-}" ]; then
    printf '%s' "${!env_key}"
    return 0
  fi

  return 1
}

# -----------------------------------------------------------------------------
# Simple timing utility
# -----------------------------------------------------------------------------
gex_now_ns() {
  # Nanoseconds if available, fallback to seconds
  if gex_have_cmd date && date +%s%N >/dev/null 2>&1; then
    date +%s%N
  else
    date +%s
  fi
}

gex_time_block() {
  # Usage:
  #   gex_time_block "Description" command args...
  local label="$1"; shift
  local start end elapsed
  start=$(gex_now_ns)
  "$@"
  end=$(gex_now_ns)
  # Compute ms (approx if only seconds available)
  if [ ${#start} -ge 10 ] && [ ${#end} -ge 10 ]; then
    # Assume either seconds *or* nanoseconds
    local len=${#start}
    if [ "$len" -gt 12 ]; then
      # nanoseconds
      elapsed=$(( (end - start)/1000000 ))
      gex_debug "$label took ${elapsed}ms"
    else
      elapsed=$(( end - start ))
      gex_debug "$label took ${elapsed}s"
    fi
  fi
}

# -----------------------------------------------------------------------------
# Trap helpers
# -----------------------------------------------------------------------------
gex_add_trap() {
  # gex_add_trap EXIT 'echo done'
  local signal="$1"; shift
  local new_cmd="$*"
  local current
  current="$(trap -p "$signal" 2>/dev/null | sed -E "s/^trap -- '(.*)' $signal$/\1/")" || current=""
  if [ -z "$current" ]; then
    trap -- "$new_cmd" "$signal"
  else
    trap -- "$current; $new_cmd" "$signal"
  fi
}

# -----------------------------------------------------------------------------
# End of core.sh
# -----------------------------------------------------------------------------

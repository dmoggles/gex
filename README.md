# gex (Git eXtended)

A lightweight, extensible command-line tool that enhances Git workflows with intelligent automation and safety features.

**gex** provides high-level commands that wrap common Git operations, making complex workflows simple and safe while preserving the full power of Git underneath.

> **Status**: Production ready. Core commands: `graph`, `start`, `publish`, `snip`, `squash`, `sync`, `wip`, `config`

---

## Table of Contents

- [Why gex?](#why-gex)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Commands](#commands)
  - [graph - Visualize commit history](#graph)
  - [start - Create branches with smart naming](#start)
  - [publish - Push branches safely](#publish)
  - [snip - Cherry-pick to avoid conflicts](#snip)
  - [squash - Combine multiple commits](#squash)
  - [sync - Synchronize with upstream branches](#sync)
  - [wip - Quick work-in-progress commits](#wip)
  - [config - Manage configuration](#config)
- [Configuration](#configuration)
- [Workflows](#workflows)
- [Advanced Usage](#advanced-usage)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)

---

## Why gex?

Git is powerful but verbose. Common developer workflows involve repetitive command sequences that can be error-prone:

**Before gex:**
```bash
# Creating a feature branch
git checkout main
git pull
git checkout -b feature/user-auth
# ... make changes ...
git add .
git commit -m "Add user authentication"
git push -u origin feature/user-auth
```

**With gex:**
```bash
# Creating a feature branch
gex start feature user-auth
# ... make changes ...
git add .
git commit -m "Add user authentication"
gex publish
```

**Key benefits:**
- **Safety first**: Validates operations before execution, prevents common mistakes
- **Smart defaults**: Auto-detects branch names, remotes, and base branches
- **Workflow consistency**: Enforces naming conventions and best practices
- **Conflict avoidance**: Cherry-pick commits to avoid painful rebases
- **Powerful visualization**: Rich commit graph with filtering and highlighting
- **Configuration-driven**: Adapts to different team workflows and conventions

---

## Installation

### Method 1: Clone and Add to PATH

```bash
git clone https://github.com/dmoggles/gex.git ~/gex
cd ~/gex
chmod +x gex commands/*

# Add to your shell configuration
echo 'export PATH="$HOME/gex:$PATH"' >> ~/.bashrc  # or ~/.zshrc
source ~/.bashrc  # or restart your shell
```

### Method 2: Symlink to Existing PATH

```bash
git clone https://github.com/dmoggles/gex.git ~/gex
cd ~/gex
chmod +x gex commands/*
ln -s ~/gex/gex /usr/local/bin/gex
```

### Verification

```bash
gex --version
gex --help
```

---

## Quick Start

### 1. Basic Workflow

```bash
# Create a feature branch
gex start feature user-dashboard

# Make your changes
echo "new feature" > feature.txt
git add feature.txt
git commit -m "Add user dashboard"

# Publish to remote
gex publish

# View commit graph
gex graph --branches "feature/*,main" --highlight main
```

### 2. Work-in-Progress Pattern

```bash
# Quick checkpoint before risky changes
gex wip "before refactoring auth module"

# Make experimental changes...
# Something went wrong? Rollback instantly:
gex wip --undo

# Or list recent WIP commits
gex wip --list
```

### 3. Cleaning Up Commit History

```bash
# You made several small commits while developing
git log --oneline -5
# a1b2c3d Fix typo
# e4f5g6h Add validation  
# i7j8k9l Update tests
# m0n1o2p Add feature
# p3q4r5s Start work

# Squash the last 4 commits into one clean commit
gex squash --count=4 -m "Implement user validation feature"

# Now you have clean history ready to publish
gex publish --force-with-lease
```

### 4. Staying Up-to-Date with Upstream

```bash
# Keep your feature branch synchronized with main
gex sync --strategy=rebase           # Rebase local commits on latest main

# Update all your branches at once  
gex sync --all                       # Merge upstream changes into all branches

# Preview what would be updated
gex sync --all --dry-run             # See status without making changes
```

### 5. Avoiding Rebase Conflicts

```bash
# Your branch diverged from main with potential conflicts
gex snip --onto=main  # Cherry-pick your commit to latest main
# No merge conflicts to resolve!
```

---

## Commands

## graph

**Visualize commit history with powerful filtering and highlighting.**

The `graph` command provides a rich, filterable view of your Git history with branch highlighting, pattern matching, and interactive selection.

### Syntax
```bash
gex graph [options]
```

### Key Features
- **Branch filtering**: Show only branches matching patterns
- **Interactive selection**: Use fzf for dynamic branch picking
- **Highlighting**: Emphasize important branches
- **Time filtering**: Limit by date ranges
- **Author filtering**: Show commits by specific authors
- **Merge filtering**: Focus on merge commits only

### Options

| Option | Description | Example |
|--------|-------------|---------|
| `--branches <patterns>` | Comma-separated branch patterns | `--branches "main,feature/*"` |
| `--exclude <patterns>` | Exclude branch patterns | `--exclude "wip/*,temp/*"` |
| `--all` | Include all local and remote branches | `--all` |
| `--remotes` | Include remote branches | `--remotes` |
| `--since <date>` | Show commits after date | `--since "2 weeks ago"` |
| `--until <date>` | Show commits before date | `--until "2024-01-01"` |
| `--author <pattern>` | Filter by author | `--author "john@example.com"` |
| `--max <n>` | Limit number of commits | `--max 50` |
| `--merges-only` | Show only merge commits | `--merges-only` |
| `--highlight <branches>` | Highlight specific branches | `--highlight "main,develop"` |
| `--interactive` | Interactive branch selection (requires fzf) | `--interactive` |
| `--style <ascii\|unicode>` | Graph line style | `--style unicode` |
| `--decorate <short\|full\|no>` | Ref name decoration | `--decorate short` |
| `--no-color` | Disable colored output | `--no-color` |

### Examples

```bash
# Basic usage - show all local branches
gex graph

# Show only feature branches and main
gex graph --branches "feature/*,main"

# Interactive branch selection
gex graph --interactive

# Show last 2 weeks of work by team
gex graph --since "2 weeks ago" --author "team@company.com"

# Focus on release branches with highlighting
gex graph --branches "release/*,main" --highlight main

# Show merge commits only
gex graph --merges-only --max 20

# Export-friendly format
gex graph --no-color --style ascii > git-history.txt
```

### Pattern Matching
- `*` matches any characters: `feature/*` matches `feature/auth`, `feature/ui`, etc.
- Exact matches: `main` matches only the `main` branch
- Multiple patterns: `"main,develop,feature/*"` (comma-separated, no spaces)

---

## start

**Create branches with smart naming conventions and workflow automation.**

The `start` command automates branch creation with consistent naming, base branch detection, and optional remote publishing.

### Syntax
```bash
gex start <type> <name> [options]
```

### Key Features
- **Smart naming**: Enforces consistent branch naming patterns
- **Base branch detection**: Auto-detects main/develop/master
- **Issue integration**: Include issue numbers in branch names
- **Remote sync**: Optionally sync base branch before creating
- **Immediate publishing**: Create and push in one command

### Arguments

| Argument | Description | Example |
|----------|-------------|---------|
| `<type>` | Branch type (configurable) | `feature`, `bugfix`, `hotfix`, `chore` |
| `<name>` | Branch description (kebab-case) | `user-authentication`, `fix-login-bug` |

### Options

| Option | Description | Example |
|--------|-------------|---------|
| `--from=<branch>` | Base branch override | `--from=develop` |
| `--issue=<number>` | Include issue number | `--issue=123` |
| `--no-switch` | Create but don't check out | `--no-switch` |
| `--no-sync` | Skip syncing base branch | `--no-sync` |
| `--push` | Push and set upstream | `--push` |
| `--interactive` | Interactive mode | `--interactive` |
| `--list-types` | Show available types | `--list-types` |
| `--dry-run` | Preview without executing | `--dry-run` |

### Examples

```bash
# Basic feature branch
gex start feature user-dashboard
# Creates: feature/user-dashboard

# Bug fix with issue number
gex start bugfix login-timeout --issue=456
# Creates: bugfix/456-login-timeout

# Hotfix from specific branch
gex start hotfix security-patch --from=release/v1.2
# Creates: hotfix/security-patch (from release/v1.2)

# Create and immediately publish
gex start feature new-api --push
# Creates and pushes: feature/new-api

# Interactive mode
gex start --interactive
# Prompts for type, name, issue, etc.

# See available branch types
gex start --list-types
```

### Branch Types

Default types: `feature`, `bugfix`, `hotfix`, `chore`, `docs`

Customize via configuration:
```bash
gex config set branch_types "epic,story,task,bugfix"
```

### Issue Integration

Automatic issue number extraction:
```bash
gex start feature "#123-user-auth"     # → feature/123-user-auth
gex start bugfix "fix-login-#456"      # → bugfix/456-fix-login
```

---

## publish

**Publish branches to remote repositories with comprehensive safety checks.**

The `publish` command safely pushes branches with automatic upstream tracking, force-push protection, and status validation.

### Syntax
```bash
gex publish [options]
```

### Key Features
- **Smart defaults**: Auto-detects current branch and origin remote
- **Safety checks**: Validates remotes, warns about protected branches
- **Force push protection**: Safer alternatives to dangerous operations
- **Status awareness**: Shows ahead/behind information
- **Flexible targeting**: Custom remotes and branch names

### Options

| Option | Description | Example |
|--------|-------------|---------|
| `--remote=<name>` | Target remote | `--remote=upstream` |
| `--branch=<name>` | Remote branch name | `--branch=main` |
| `--to=<remote/branch>` | Shorthand syntax | `--to=origin/develop` |
| `--force` | Force push (dangerous) | `--force` |
| `--force-with-lease` | Safer force push | `--force-with-lease` |
| `--no-set-upstream` | Don't set tracking | `--no-set-upstream` |
| `--dry-run` | Preview actions | `--dry-run` |

### Examples

```bash
# Basic publish to origin
gex publish
# Pushes current branch to origin with upstream tracking

# Publish to different remote
gex publish --remote=upstream

# Publish with different name on remote
gex publish --branch=feature-v2

# Shorthand for remote/branch
gex publish --to=upstream/main

# Safe force push (recommended)
gex publish --force-with-lease

# Preview what would happen
gex publish --dry-run
```

### Safety Features

**Protected Branch Warnings:**
```bash
gex publish --branch=main
# WARNING: Target branch 'main' appears to be protected!
# Continue? [y/N]
```

**Force Push Detection:**
```bash
gex publish
# WARN: Remote branch has commits not in your local branch
# This requires a force push, which can be dangerous
# Force push with lease? [y/N]
```

**Status Information:**
```bash
gex publish --dry-run
# Publishing Status:
#   Local branch:   feature/auth
#   Remote:         origin
#   Target branch:  feature/auth
#   Ahead:          2 commits
#   Behind:         0 commits
#   Status:         Ready to push
```

---

## snip

**Cherry-pick commits onto the latest base branch to avoid rebase conflicts.**

The `snip` command solves the common problem of divergent branches by cherry-picking your commits onto the latest base branch, avoiding complex merge conflicts.

### Syntax
```bash
gex snip [options]
```

### Key Features
- **Conflict avoidance**: Cherry-pick instead of rebasing
- **Smart targeting**: Auto-detects appropriate base branch
- **Lost commit protection**: Warns before losing work
- **Branch preservation**: Option to keep original branch
- **Recovery guidance**: Clear instructions if conflicts occur

### The Problem Solved

```
Before:     main          your-branch
            |             |
            A---B---C-----D (your commit)
                 \
                  E---F (conflicts with B,C)

After:      main                  your-branch
            |                     |
            A---B---C---E---F-----D' (clean cherry-pick)
                 \
                  (original commits)
```

### Options

| Option | Description | Example |
|--------|-------------|---------|
| `--onto=<branch>` | Target base branch | `--onto=main` |
| `--commit=<ref>` | Specific commit to snip | `--commit=HEAD~1` |
| `--no-pull` | Skip syncing base branch | `--no-pull` |
| `--keep-original` | Keep original branch | `--keep-original` |
| `--branch=<name>` | New branch name | `--branch=feature-v2` |
| `--force` | Override safety warnings | `--force` |
| `--dry-run` | Preview operation | `--dry-run` |

### Examples

```bash
# Basic snip to latest main
gex snip
# Cherry-picks HEAD onto latest main, moves current branch

# Snip to different base
gex snip --onto=develop

# Snip specific commit
gex snip --commit=HEAD~2

# Keep original branch, create new one
gex snip --keep-original --branch=auth-v2

# Preview the operation
gex snip --dry-run
```

### Safety Features

**Lost Commit Warnings:**
```bash
gex snip --commit=HEAD~1
# WARN: This operation would lose 1 commit(s) after abc1234:
# WARN:   def5678 Fix typo in documentation
# Continue anyway? [y/N]
```

**Detailed Preview:**
```bash
gex snip --dry-run
# Snip Operation Summary:
#   Current branch:    feature/auth
#   Target branch:     main
#   Commit to snip:    abc1234
#   Commit message:    Add user authentication
#   Author:            John Doe <john@example.com>
#   Date:              2024-01-15
#   
# Would execute:
#   1. git checkout main
#   2. git pull --ff-only origin main
#   3. git cherry-pick abc1234
#   4. git branch -f feature/auth HEAD
#   5. git checkout feature/auth
```

### Conflict Resolution

If cherry-pick fails:
```bash
gex snip
# ERROR: Cherry-pick failed with conflicts!
# 
# To resolve:
#   1. Fix conflicts in the listed files
#   2. git add <resolved-files>
#   3. git cherry-pick --continue
#   4. gex snip --onto=main --commit=abc1234  # Re-run to complete
# 
# To abort:
#   git cherry-pick --abort
#   git checkout feature/auth
```

---

## squash

**Combine multiple commits into a single commit with smart defaults and safety checks.**

The `squash` command provides a safe and flexible way to clean up commit history by combining multiple commits into one, with automatic detection of unpushed commits and comprehensive safety features.

### Syntax
```bash
gex squash [options] [<commit-range>]
```

### Key Features
- **Smart detection**: Auto-detects unpushed commits to avoid rewriting shared history
- **Multiple modes**: Count-based, range-based, or interactive selection
- **Safety first**: Requires clean working directory and warns about force-push implications
- **Flexible messaging**: Custom commit messages or interactive editor
- **Comprehensive preview**: Shows exactly what will be squashed before execution

### The Problem Solved

```
Before:     feature-branch
            |
            A---B---C---D---E (5 small commits)

After:      feature-branch
            |
            A---F (1 clean commit combining B,C,D,E)
```

### Options

| Option | Description | Example |
|--------|-------------|---------|
| `--count=N`, `-n N` | Squash last N commits | `--count=3` |
| `--message=MSG`, `-m MSG` | New commit message | `-m "Combined work"` |
| `--interactive`, `-i` | Choose commits interactively | `--interactive` |
| `--onto=COMMIT` | Squash onto specific commit | `--onto=main` |
| `--force` | Allow squashing pushed commits | `--force` |
| `--dry-run` | Preview operation | `--dry-run` |

### Examples

```bash
# Squash all unpushed commits (default)
gex squash

# Squash last 3 commits
gex squash --count=3

# Squash with custom message
gex squash -n 5 -m "Implement user authentication feature"

# Squash specific range
gex squash HEAD~3..HEAD

# Interactive selection
gex squash --interactive

# Preview operation
gex squash --dry-run --count=2
```

### Interactive Mode

```bash
gex squash --interactive
# Select commits to squash (showing last 20 commits):
# 
# 0: a1b2c3d Fix typo in README
# 1: e4f5g6h Add user validation
# 2: i7j8k9l Update API documentation  
# 3: m0n1o2p Refactor auth module
# 4: p3q4r5s Initial user auth implementation
# 
# Enter commit numbers to squash (e.g., 0-2 or 0,1,2): 0-2
```

### Safety Features

**Clean Working Directory:**
```bash
gex squash --count=3
# ERROR: Working directory must be clean before squashing commits. 
# Commit or stash your changes first.
```

**Pushed Commit Protection:**
```bash
gex squash --count=5
# ERROR: Some commits in range have been pushed to upstream:
#   a1b2c3d Fix user authentication bug
#   e4f5g6h Update documentation
# 
# Squashing pushed commits will rewrite shared history!
# This requires force-push and may affect other developers.
# 
# Use --force to proceed anyway (dangerous) or adjust your range.
```

**Detailed Preview:**
```bash
gex squash --dry-run --count=3
# Squash Plan:
#   Branch:         feature/auth
#   Commit range:   HEAD~3..HEAD
#   Commits:        3
# 
# Commits to squash:
#   a1b2c3d Fix typo in validation
#   e4f5g6h Add password strength check
#   i7j8k9l Implement user registration
# 
# Target (squashing onto):
#   m0n1o2p Initial auth framework
# 
# Commit message will be:
#   Implement user registration (from first commit)
# 
# DRY RUN - Would execute:
#   git reset --soft m0n1o2p
#   git commit -m "Implement user registration"  # (from first commit)
# 
# This would squash 3 commits into 1 commit.
```

### Force-Push Integration

After squashing, you'll typically need to force-push:

```bash
gex squash --count=3
# Successfully squashed 3 commits!
# 
# Next steps:
#   # Push the squashed commit:
#   gex publish --force-with-lease
```

### Default Behavior

When no custom message is provided with `--message`, the squash command automatically uses the commit message from the first (oldest) commit in the squash range. This preserves the original intent while cleaning up intermediate commits.

### Configuration

Set defaults in `~/.config/gex/config` or `.gexrc`:

```ini
squash_unpushed_only = true     # Only squash unpushed commits
squash_preserve_merges = false  # Don't preserve merge commits
```

---

## sync

**Synchronize branches with their upstream tracking branches using smart defaults and safety checks.**

The `sync` command provides a comprehensive solution for keeping local branches up-to-date with upstream changes, supporting both single branch and bulk operations with intelligent conflict detection.

### Syntax
```bash
gex sync [options] [branch...]
```

### Key Features
- **Flexible strategies**: Choose between merge and rebase for different workflows
- **Bulk operations**: Update all branches with upstream tracking at once
- **Smart detection**: Auto-detects divergent branches and provides guidance
- **Interactive selection**: Choose specific branches to update from a list
- **Remote maintenance**: Prune stale remote references during sync
- **Safety first**: Requires clean working directory and shows detailed previews

### The Problem Solved

```
Before:    feature-branch      main (upstream)
           |                   |
           A---B---C           A---D---E---F (new commits)
           (out of date)

After:     feature-branch
           |
           A---D---E---F---B'---C' (rebased, up-to-date)
```

### Options

| Option | Description | Example |
|--------|-------------|---------|
| `--strategy=<merge\|rebase>` | Sync strategy | `--strategy=rebase` |
| `--all`, `-a` | Sync all branches with upstreams | `--all` |
| `--prune`, `-p` | Prune deleted remote branches | `--prune` |
| `--remote=<name>` | Specific remote to sync with | `--remote=upstream` |
| `--dry-run` | Preview operations | `--dry-run` |
| `--force` | Override safety checks | `--force` |
| `--no-fetch` | Skip fetching from remote | `--no-fetch` |
| `--interactive`, `-i` | Choose branches interactively | `--interactive` |

### Examples

```bash
# Update current branch with upstream
gex sync

# Update all branches with their upstreams
gex sync --all

# Use rebase strategy for linear history
gex sync --strategy=rebase

# Update specific branch
gex sync feature-branch

# Interactive selection of branches
gex sync --interactive

# Update all branches and clean up stale references
gex sync --all --prune

# Preview what would happen
gex sync --all --dry-run
```

### Strategies

**Merge Strategy (default):**
- Preserves branch history with merge commits
- Safer for shared branches
- Shows clear integration points

**Rebase Strategy:**
- Creates linear history
- Cleaner commit graph
- Rewrites local commits (use with caution on shared branches)

### Safety Features

**Clean Working Directory:**
```bash
gex sync
# ERROR: Working directory must be clean to sync current branch.
# Commit or stash changes first.
```

**Divergent Branch Detection:**
```bash
gex sync feature-branch
# WARN: Branch 'feature-branch' has diverged from 'origin/main' (ahead: 2, behind: 3)
# This may result in conflicts. Use --force to proceed anyway.
#   Consider:
#     gex sync feature-branch --strategy=rebase  # Rebase local commits
#     gex sync feature-branch --strategy=merge   # Merge upstream changes
```

**Detailed Preview:**
```bash
gex sync --all --dry-run
# Sync Plan:
#   Strategy:       merge
#   Branches:       3
#   Prune remotes:  yes
# 
# Branch Status:
#   main                : up-to-date with origin/main
#   feature-auth        : 2 commits behind origin/feature-auth
#   bugfix-login        : 1 ahead, 1 behind origin/main (diverged)
# 
# DRY RUN - Would execute:
#   git checkout feature-auth && git merge origin/feature-auth
#   git checkout bugfix-login && git merge origin/main
#   git remote prune origin
```

### Protected Branches

By default, protected branches (main, master, develop) are skipped in `--all` operations:

```bash
gex sync --all          # Skips main/master/develop
gex sync main           # Explicitly sync main (allowed)
```

### Integration Workflow

```bash
# Start feature work
gex start feature user-profile

# Work on feature...
git add . && git commit -m "Add user profile page"

# Keep up-to-date with main
gex sync --strategy=rebase

# Continue work...
git add . && git commit -m "Add profile validation"

# Final sync before publishing
gex sync
gex publish
```

### Configuration

Set defaults in `~/.config/gex/config` or `.gexrc`:

```ini
sync_strategy = rebase              # Default strategy (merge|rebase)
sync_auto_prune = true              # Auto-prune during sync operations
sync_fetch_all = false              # Fetch all remotes vs just current
protected_branches = main,develop   # Skip these in --all operations
```

---

## wip

**Create and manage work-in-progress commits with easy rollback.**

The `wip` command enables quick checkpointing of work with simple undo functionality, perfect for experimental changes or break points.

### Syntax
```bash
gex wip [message] [options]
```

### Key Features
- **Quick checkpointing**: Instant commits with WIP prefix
- **Easy rollback**: Undo last WIP commit perfectly
- **WIP history**: List recent WIP commits
- **Hook skipping**: Bypass pre-commit hooks for speed
- **Safe operations**: Only affects WIP commits

### Options

| Option | Description | Example |
|--------|-------------|---------|
| `--undo` | Rollback last WIP commit | `--undo` |
| `--list` | Show recent WIP commits | `--list` |
| `--push` | Push WIP (skip hooks) | `--push` |

### Examples

```bash
# Quick WIP commit
gex wip "checkpoint before refactor"
# Creates: "WIP: checkpoint before refactor"

# WIP without message
gex wip
# Creates: "WIP: [timestamp]"

# Undo last WIP
gex wip --undo
# Perfectly restores previous state

# List recent WIP commits
gex wip --list
# Shows: WIP commits with rollback info

# Push WIP commit (bypass hooks)
gex wip "broken but need to switch machines" --push
```

### WIP Commit Format

```bash
gex wip "testing new algorithm"
# Commit message: "WIP: testing new algorithm"
# 
# Includes metadata for safe undo:
# - Previous HEAD position
# - Working directory state
# - Staging area contents
```

### Safe Undo

```bash
gex wip --undo
# INFO: Rolling back WIP commit abc1234
# INFO: Restored to previous state def5678
# INFO: Working directory and staging area restored
```

**Undo Limitations:**
- Only works on WIP commits (prefixed with "WIP:")
- Must be the most recent commit
- Preserves uncommitted changes when possible

---

## config

**Manage gex configuration and workflow presets.**

The `config` command handles global and repository-specific settings, workflow presets, and customization options.

### Syntax
```bash
gex config <action> [arguments]
```

### Actions

| Action | Description | Example |
|--------|-------------|---------|
| `set <key> <value>` | Set configuration value | `set branch_types "epic,story,task"` |
| `get <key>` | Get configuration value | `get default_remote` |
| `use <preset>` | Apply workflow preset | `use features` |
| `list` | Show current configuration | `list` |
| `presets` | List available presets | `presets` |

### Examples

```bash
# Set custom branch types
gex config set branch_types "epic,story,task,bugfix"

# Set default base branch
gex config set default_base_branch develop

# Get current remote setting
gex config get default_remote

# Apply a workflow preset
gex config use features

# Show all configuration
gex config list

# See available presets
gex config presets
```

### Workflow Presets

**`features` preset:**
```bash
gex config use features
# Sets:
#   branch_types = feature,bugfix,hotfix,chore,docs
#   default_base_branch = main
```

**`patches` preset:**
```bash
gex config use patches
# Sets:
#   branch_types = features,patches,hotfix
#   default_base_branch = develop
```

---

## Configuration

### Configuration Files

**Global configuration:** `~/.config/gex/config`
```ini
# Global gex configuration
default_remote = origin
auto_set_upstream = true
protected_branches = main,master,develop,release/*
```

**Repository configuration:** `.gexrc` (in repo root)
```ini
# Repository-specific overrides
branch_types = epic,story,task,bugfix
default_base_branch = develop
auto_sync = false
```

### Configuration Keys

| Key | Description | Default | Example |
|-----|-------------|---------|---------|
| `branch_types` | Available branch types for `start` | `feature,bugfix,hotfix,chore,docs` | `epic,story,task` |
| `default_base_branch` | Default base for new branches | Auto-detect | `main`, `develop` |
| `default_remote` | Default remote for publishing | `origin` | `upstream`, `fork` |
| `auto_set_upstream` | Set upstream on publish | `true` | `false` |
| `auto_sync` | Sync base branch before operations | `true` | `false` |
| `protected_branches` | Branches to warn before force push | `main,master,develop` | `main,release/*` |

### Environment Variables

Override configuration with environment variables:

```bash
# Disable colors
export NO_COLOR=1

# Enable debug logging
export GEX_DEBUG=1

# Enable shell tracing
export GEX_TRACE=1

# Override config values
export GEX_DEFAULT_REMOTE=upstream
export GEX_BRANCH_TYPES=epic,story,task
```

---

## Workflows

### Feature Development Workflow

```bash
# 1. Start feature branch
gex start feature user-authentication

# 2. Develop and commit
git add .
git commit -m "Add login form"
git commit -m "Add authentication logic"

# 3. Checkpoint before risky changes
gex wip "before refactoring auth flow"

# 4. Continue development...
# Something went wrong? Quick rollback:
gex wip --undo

# 5. Publish feature
gex publish

# 6. Main moved forward? Avoid rebase conflicts:
gex snip --onto=main

# 7. Visualize your work
gex graph --branches "feature/*,main" --highlight main
```

### Hotfix Workflow

```bash
# 1. Create hotfix from production branch
gex start hotfix security-fix --from=main

# 2. Make critical fix
git add .
git commit -m "Fix security vulnerability"

# 3. Publish hotfix
gex publish

# 4. Cherry-pick to develop
gex snip --onto=develop --keep-original
```

### Team Collaboration Workflow

```bash
# 1. Configure team standards
gex config set branch_types "epic,story,task,bugfix"
gex config set protected_branches "main,develop,release/*"

# 2. Start work on story
gex start story user-dashboard --issue=123

# 3. Create checkpoint before team sync
gex wip "before standup demo"

# 4. Publish for review
gex publish --to=origin/story/123-user-dashboard

# 5. Visualize team progress
gex graph --since "1 week ago" --interactive
```

---

## Advanced Usage

### Integration with fzf

Enable interactive branch selection:
```bash
# Install fzf first
brew install fzf  # macOS
apt install fzf    # Ubuntu

# Use interactive mode
gex graph --interactive
```

### Custom Aliases

Add to your `.bashrc` or `.zshrc`:
```bash
alias gg='gex graph --interactive'
alias gs='gex start'
alias gp='gex publish'
alias gw='gex wip'
alias gwu='gex wip --undo'
```

### CI/CD Integration

```bash
# Disable color output in CI
gex graph --no-color > git-history.txt

# Check if branch follows naming convention
if gex start --list-types | grep -q "^${BRANCH_PREFIX}$"; then
  echo "Valid branch type: $BRANCH_PREFIX"
else
  echo "Invalid branch type: $BRANCH_PREFIX"
  exit 1
fi
```

### Scripting with gex

```bash
#!/bin/bash
# Script to create and publish feature branch

if [ $# -ne 1 ]; then
  echo "Usage: $0 <feature-name>"
  exit 1
fi

FEATURE_NAME="$1"

# Create feature branch
gex start feature "$FEATURE_NAME" --from=develop

# Make initial commit
touch "docs/${FEATURE_NAME}.md"
git add "docs/${FEATURE_NAME}.md"
git commit -m "Initial documentation for $FEATURE_NAME"

# Publish for collaboration
gex publish

echo "Feature branch created and published: feature/$FEATURE_NAME"
```

---

## Troubleshooting

### Common Issues

**Command not found:**
```bash
gex: command not found
```
- Ensure gex is in your PATH
- Check installation with `which gex`
- Reload shell: `source ~/.bashrc`

**Permission denied:**
```bash
permission denied: ./gex
```
- Make executable: `chmod +x gex commands/*`

**Branch patterns match nothing:**
```bash
gex graph --branches "feature/*"
# No output
```
- Check branches exist: `git branch --list "feature/*"`
- Try: `gex graph --all` to see all branches

**fzf not found:**
```bash
gex graph --interactive
# ERROR: fzf not installed
```
- Install fzf: `brew install fzf` or `apt install fzf`
- Or use without `--interactive`

### Debug Mode

Enable detailed logging:
```bash
export GEX_DEBUG=1
gex graph --branches "feature/*"
# DEBUG: Branch pattern: feature/*
# DEBUG: Found branches: feature/auth, feature/ui
# DEBUG: Executing: git log --graph --oneline...
```

Enable shell tracing:
```bash
export GEX_TRACE=1
gex start feature test
# Shows detailed shell execution
```

### Configuration Issues

**Config not loading:**
```bash
gex config list
# Shows default values only
```
- Check file exists: `ls ~/.config/gex/config`
- Check repo config: `ls .gexrc`
- Verify format: no spaces around `=`

**Branch types not working:**
```bash
gex start epic new-feature
# ERROR: Invalid branch type: epic
```
- Set branch types: `gex config set branch_types "epic,story,task"`
- Or check current: `gex config get branch_types`

---

## Contributing

We welcome contributions! Here's how to get started:

### Development Setup

```bash
git clone https://github.com/dmoggles/gex.git
cd gex
chmod +x gex commands/*

# Run tests
./tests/test_*.sh

# Check shell script quality
shellcheck gex commands/*
```

### Guidelines

1. **Compatibility**: Scripts should work on macOS and Linux
2. **Safety**: Validate inputs, provide dry-run modes
3. **Testing**: Add tests for new functionality
4. **Documentation**: Update README and help text
5. **Style**: Follow existing code patterns

### Adding New Commands

1. Create `commands/newcommand` (executable)
2. Follow existing command structure:
   - Usage function
   - Argument parsing
   - Validation
   - Dry-run support
   - Error handling
3. Add tests in `tests/test_newcommand.sh`
4. Update README documentation

### Running Tests

```bash
# Run all tests
for test in tests/test_*.sh; do
  echo "Running $test"
  "$test"
done

# Run specific test
./tests/test_graph.sh
```

---

## License

MIT License - see [LICENSE](LICENSE) file for details.

---

## Feedback

- **Issues**: [GitHub Issues](https://github.com/dmoggles/gex/issues)
- **Discussions**: [GitHub Discussions](https://github.com/dmoggles/gex/discussions)
- **Email**: Open an issue for feature requests

---

**gex** - Making Git workflows safer, faster, and more intuitive.
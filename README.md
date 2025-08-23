# gex (Git eXtended)

A lightweight, extensible command‑line tool that layers higher-level workflows on top of Git.
The initial focus is on a powerful `graph` command for quickly visualizing commit history across multiple branches with flexible filtering, highlighting, and interactive selection, plus essential workflow commands like `start`, `publish`, and `wip`.

> Status: Core functionality implemented. Commands available: `graph`, `start`, `publish`, `wip`, `config`.

---

## Why gex?

While `git` already provides rich plumbing, day‑to‑day workflows often repeat patterns:
- Viewing a meaningful multi-branch commit graph
- Creating branches with consistent naming conventions
- Publishing branches with proper upstream tracking
- Making quick work-in-progress commits
- Focusing on a subset of branches (e.g., feature branches related to an epic)
- Highlighting important branches (like `main`, `release/*`)
- Quickly limiting output by author, date, merges, etc.
- Interactively selecting branches with fuzzy search

`gex` provides commands that wrap and augment common git operations, making workflows faster and more discoverable.

---

## Features (Current)

### Graph Command
- Branch pattern selection: `--branches "feature/*,hotfix/*"`
- Exclusions by glob: `--exclude "wip/*"`
- Include remotes (`--remotes`) or everything (`--all`)
- Time and range filtering: `--since`, `--until`
- Limit commit count: `--max`
- Filter by author: `--author`
- Show only merges: `--merges-only`
- Highlight specific branches: `--highlight main,develop`
- Interactive mode (fzf): `--interactive`
- ASCII or basic Unicode graph lines: `--style ascii|unicode`
- Decoration control: `--decorate short|full|no`
- Disable color with `--no-color`
- Safe behavior when HEAD is detached (ensures it's shown)
- Clean failure messages if patterns match nothing

### Branch Management
- **start**: Create branches with smart naming conventions (`gex start feature my-feature`)
- **publish**: Push branches with upstream tracking and safety checks
- **wip**: Quick work-in-progress commits with easy rollback

### Configuration
- Global and per-repository configuration support
- Customizable branch types and naming patterns
- Workflow presets for different project styles

---

## Planned (Short Term Roadmap)

### Graph Enhancements
- Dimming (faint color) of non-highlighted branches
- JSON output mode for tooling (`--json`)
- Rich Unicode graph with persistent branch color assignment
- Intelligent subject line truncation (`--subject-width`)

### Additional Commands
- **sync**: Smart branch synchronization with remotes
- **prune**: Clean up stale branches
- **squash**: Interactive commit squashing

### Integrations
- Pull/merge request creation support
- Issue tracker integration (GitHub, GitLab, Jira)

Longer-term:
- Plugin system for user-defined commands
- Commit set diff utilities (e.g., "what's on branch X but not Y?")
- Release & changelog automation

---

## Installation

Clone the repository somewhere on your machine (example assumes `~/gex`):

    git clone <REPO_URL> ~/gex
    cd ~/gex
    chmod +x gex commands/*

Add to your shell PATH (choose one):

Bash / Zsh:

    echo 'export PATH="$HOME/gex:$PATH"' >> ~/.bashrc   # or ~/.zshrc
    # Then reload your shell
    exec $SHELL -l

Fish:

    set -Ux PATH $HOME/gex $PATH

(Alternatively, symlink `gex` into a directory already on PATH.)

### start

Create branches with smart naming conventions and workflow automation.

    gex start <type> <name> [options]

Option               | Description
--------------------|------------
--from=<branch>     | Base branch (default: auto-detect main/develop)
--issue=<number>    | Issue number to include in branch name
--no-switch         | Create branch but don't check it out
--no-sync           | Skip syncing base branch with remote
--push              | Push new branch and set upstream tracking
--interactive       | Interactive guided branch creation
--list-types        | Show available branch types
--dry-run           | Show what would be done without executing

Examples:

    gex start feature user-dashboard
    gex start bugfix login-timeout --issue=456
    gex start hotfix security-patch --from=release/v1.2 --push

### publish

Publish branches to remote repositories with safety checks and smart defaults.

    gex publish [options]

Option                  | Description
-----------------------|------------
--remote=<name>        | Remote to push to (default: origin)
--branch=<name>        | Remote branch name (default: current branch)
--to=<remote/branch>   | Shorthand for --remote=<remote> --branch=<branch>
--force                | Force push (dangerous)
--force-with-lease     | Force push with lease (safer)
--no-set-upstream      | Don't set upstream tracking
--dry-run              | Preview actions without executing

Examples:

    gex publish                              # Push current branch to origin
    gex publish --remote=upstream            # Push to upstream remote
    gex publish --to=origin/develop          # Push to origin/develop
    gex publish --force-with-lease           # Safe force push

### wip

Create and manage work-in-progress commits with easy rollback.

    gex wip [message] [options]

Option     | Description
-----------|------------
--undo     | Rollback the last WIP commit
--list     | List recent WIP commits
--push     | Push WIP commit (skips pre-commit hooks)

Examples:

    gex wip "checkpoint before refactor"
    gex wip --undo                          # Rollback last WIP
    gex wip --list                          # Show WIP history

### config

Manage gex configuration and workflow presets.

    gex config <action> [options]

Actions:
- `set <key> <value>` - Set configuration value
- `get <key>` - Get configuration value
- `use <preset>` - Apply workflow preset
- `list` - Show current configuration
- `presets` - List available presets

---

## Quick Start

### Basic Workflow

Create a new feature branch:

    gex start feature my-awesome-feature

Make your changes and commit:

    git add .
    git commit -m "Add awesome feature"

Publish your branch:

    gex publish

Quick work-in-progress commit:

    gex wip "checkpoint before lunch"

Rollback the WIP commit:

    gex wip --undo

### Graph Visualization

View commit history:

    gex graph

Filter to a subset of branches:

    gex graph --branches main,develop

Glob pattern:

    gex graph --branches "feature/*"

Highlight important branches:

    gex graph --branches "feature/*,main" --highlight main

Show only the last 100 commits affecting release branches:

    gex graph --branches "release/*" --max 100

Interactive branch picker (requires `fzf`):

    gex graph --interactive

View only merge commits from the last two weeks:

    gex graph --since 2.weeks --merges-only

Unicode graph glyphs:

    gex graph --style unicode

No colors (useful for logs):

    gex graph --no-color

### Configuration

Set up workflow presets:

    gex config use features    # Use feature/bugfix workflow
    gex config use patches     # Use features/patches workflow

Set custom branch types:

    gex config set branch_types "epic,story,task,bugfix"

---

## Command Reference

### graph

Visualize commit history with flexible filtering and highlighting.

Option (long)        | Description
---------------------|------------
--branches <list>    | Comma-separated branch names or globs (e.g. `main,feature/*`)
--exclude <list>     | Comma-separated glob patterns to exclude
--remotes            | Include remote branches (in addition to local)
--all                | Include all local + remote (overrides `--branches` if none provided)
--since <rev|date>   | Lower time/revision bound (e.g. `2024-01-01`, `2.weeks`, `tagname`)
--until <rev|date>   | Upper bound (default: HEAD)
--max <n>            | Limit number of commits shown
--author <pattern>   | Filter commits by author (passed to `git log --author`)
--merges-only        | Only merge commits (`--merges`)
--style ascii|unicode| Graph drawing style (initial unicode is minimal substitution)
--no-color           | Disable color output
--highlight <list>   | Comma list of branches whose labels should be emphasized
--decorate <mode>    | `short`, `full`, or `no` for ref decorations
--interactive        | Use `fzf` multi-select to choose branches
--show-remote-labels | Keep remote labels even if a matching local branch exists (future refinement)
-h, --help           | Show usage

Notes:
- If no `--branches`, `--all`, or `--remotes` are supplied, only local branches are considered.
- Patterns are simple globs; `*` matches any sequence.
- Exclusions both remove branches from positive selection and add explicit `^ref` rev exclusions.

---

## Configuration

Configuration files:
- Global: `~/.config/gex/config`
- Per repo: `.gexrc` at repo root

Common settings:

    # Branch types for gex start
    branch_types = feature,bugfix,hotfix,chore,docs
    
    # Default base branch
    default_base_branch = main
    
    # Default remote for publishing
    default_remote = origin
    
    # Protected branches (warnings on force push)
    protected_branches = main,master,develop,release/*
    
    # Auto-set upstream when publishing
    auto_set_upstream = true

Workflow presets:
- `features`: Uses feature/bugfix/hotfix/chore branch types
- `patches`: Uses features/patches/hotfix branch types

---

## Contributing

Until contribution guidelines are formalized:
1. Open an issue describing desired enhancement or bug.
2. For code contributions:
   - Keep scripts POSIX-friendly where practical (Bash features allowed but avoid unnecessary bashisms).
   - Run shellcheck.
   - Add or update tests (Bats) for non-trivial changes.
3. Submit a pull request referencing the issue.

---

## Testing

Tests will use [Bats](https://github.com/bats-core/bats-core).

Run all tests (once they are added):

    bats tests

Ensure `bats` is installed via your package manager or from source.

---

## Philosophy

- Leverage native `git` when possible before re-implementing logic.
- Provide ergonomic defaults while exposing underlying power.
- Favor transparency and explicit output over “magic.”
- Design for incremental adoption—each command should stand alone.

---

## Troubleshooting

Symptom                | Possible Cause / Fix
-----------------------|----------------------
No graph output        | Branch patterns matched nothing; verify with `git branch --list`
fzf error              | `fzf` not installed; remove `--interactive` or install it
Unicode glyphs odd     | Terminal font lacks symbols; switch to `--style ascii`
Colors off in CI       | CI non-TTY; use `--no-color` or set `NO_COLOR=1`

---

## License

Add a LICENSE file (e.g., MIT) to clarify usage rights.

---

## Feedback

Open issues for feature requests or problems. Early feedback strongly influences upcoming priorities.

Enjoy quicker, clearer Git history exploration with `gex graph`!
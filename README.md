# gex (Git eXtended)

A lightweight, extensible command‑line tool that layers higher-level workflows on top of Git.
The initial focus is on a powerful `graph` command for quickly visualizing commit history across multiple branches with flexible filtering, highlighting, and interactive selection.

> Status: Early scaffold (MVP). Currently only the `graph` command is implemented.

---

## Why gex?

While `git` already provides rich plumbing, day‑to‑day workflows often repeat patterns:
- Viewing a meaningful multi-branch commit graph
- Focusing on a subset of branches (e.g., feature branches related to an epic)
- Highlighting important branches (like `main`, `release/*`)
- Quickly limiting output by author, date, merges, etc.
- Interactively selecting branches with fuzzy search

`gex graph` wraps and augments `git log --graph`, making those tasks faster and more discoverable while leaving room to evolve into a fully custom renderer later.

---

## Features (Current)

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
- Safe behavior when HEAD is detached (ensures it’s shown)
- Clean failure messages if patterns match nothing

---

## Planned (Short Term Roadmap)

- Dimming (faint color) of non-highlighted branches
- JSON output mode for tooling (`--json`)
- Rich Unicode graph with persistent branch color assignment
- Intelligent subject line truncation (`--subject-width`)
- Config file support (global + per-repo)
- Additional commands: `start`, `sync`, `publish`, `prune`, etc.

Longer-term:
- Plugin system for user-defined commands
- Commit set diff utilities (e.g., “what’s on branch X but not Y?”)
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

---

## Quick Start

Inside any Git repository:

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

---

## Command Reference: graph

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

## Configuration (Future)

Planned file locations:
- Global: `~/.config/gex/config`
- Per repo: `.gexrc` at repo root

These will allow default branch patterns, highlighting sets, color preferences, etc.

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
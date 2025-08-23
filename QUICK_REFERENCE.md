# gex Quick Reference

**Git eXtended - Workflow automation with safety and smart defaults**

## Essential Commands

### Branch Management
```bash
gex start <type> <name>           # Create branch with naming conventions
gex publish                       # Push with upstream tracking & safety checks
gex snip                          # Cherry-pick to avoid rebase conflicts
```

### Work-in-Progress
```bash
gex wip "checkpoint"              # Quick WIP commit
gex wip --undo                    # Rollback last WIP commit
gex wip --list                    # Show WIP history
```

### Visualization
```bash
gex graph                         # Show commit graph
gex graph --interactive           # Interactive branch selection (fzf)
gex graph --branches "feature/*"  # Filter branches
```

### Configuration
```bash
gex config set <key> <value>      # Set configuration
gex config use <preset>           # Apply workflow preset
gex config list                   # Show current config
```

## Quick Workflows

### Feature Development
```bash
gex start feature user-auth       # Create: feature/user-auth
# ... develop ...
gex wip "checkpoint"              # Quick save
gex publish                       # Push with upstream
gex snip --onto=main              # Avoid rebase conflicts
```

### Hotfix
```bash
gex start hotfix security --from=main
# ... fix ...
gex publish
gex snip --onto=develop --keep-original
```

### Emergency Rollback
```bash
gex wip --undo                    # Undo last WIP commit
git reset --hard HEAD~1           # Undo last regular commit
```

## Command Options

### start
```bash
--from=<branch>          # Base branch (auto-detects main/develop)
--issue=<number>         # Include issue: feature/123-user-auth
--push                   # Create and publish immediately
--interactive            # Guided creation
--dry-run               # Preview without executing
```

### publish
```bash
--remote=<name>          # Target remote (default: origin)
--to=<remote/branch>     # Shorthand: --to=upstream/main
--force-with-lease       # Safe force push
--dry-run               # Preview status and actions
```

### snip
```bash
--onto=<branch>          # Target branch (auto-detects main)
--commit=<ref>           # Specific commit (default: HEAD)
--keep-original          # Create new branch, keep original
--force                  # Override lost commit warnings
```

### graph
```bash
--branches "pattern"     # Filter: "feature/*,main"
--exclude "pattern"      # Exclude: "wip/*"
--since "date"          # Time filter: "2 weeks ago"
--author "email"        # Author filter
--interactive           # fzf branch picker
--highlight "branches"   # Emphasize: "main,develop"
```

### wip
```bash
gex wip                  # WIP with timestamp
gex wip "message"        # WIP with custom message
--undo                   # Rollback last WIP
--list                   # Show WIP commits
```

## Configuration

### Files
- Global: `~/.config/gex/config`
- Repo: `.gexrc` (repository root)

### Common Settings
```ini
# Branch types for 'gex start'
branch_types = feature,bugfix,hotfix,chore,docs

# Default base branch
default_base_branch = main

# Default remote
default_remote = origin

# Protected branches (warnings)
protected_branches = main,master,develop,release/*

# Auto-set upstream on publish
auto_set_upstream = true
```

### Workflow Presets
```bash
gex config use features  # feature/bugfix/hotfix/chore
gex config use patches   # features/patches/hotfix
```

## Environment Variables
```bash
export NO_COLOR=1        # Disable colors
export GEX_DEBUG=1       # Debug logging
export GEX_TRACE=1       # Shell tracing
```

## Pattern Matching
- `*` matches any characters: `feature/*` → `feature/auth`, `feature/ui`
- Exact match: `main` → only `main` branch
- Multiple: `"main,develop,feature/*"` (comma-separated)

## Safety Features
- ✅ Working directory validation
- ✅ Force push warnings
- ✅ Protected branch detection
- ✅ Lost commit prevention
- ✅ Conflict resolution guidance
- ✅ Dry-run modes for all commands

## Integration

### With fzf (interactive mode)
```bash
brew install fzf         # macOS
apt install fzf          # Ubuntu
gex graph --interactive  # Interactive branch selection
```

### Shell Aliases
```bash
alias gg='gex graph --interactive'
alias gs='gex start'
alias gp='gex publish'
alias gw='gex wip'
alias gwu='gex wip --undo'
```

## Troubleshooting

### Common Issues
```bash
# Command not found
echo 'export PATH="$HOME/gex:$PATH"' >> ~/.bashrc

# Permission denied
chmod +x gex commands/*

# No branches match pattern
git branch --list "pattern"  # Verify branches exist

# Config not loading
ls ~/.config/gex/config .gexrc  # Check files exist
```

### Debug Mode
```bash
GEX_DEBUG=1 gex command      # Show debug info
GEX_TRACE=1 gex command      # Show shell execution
```

---

**Need help?** Run `gex <command> --help` for detailed options and examples.

**Full documentation:** https://github.com/dmoggles/gex
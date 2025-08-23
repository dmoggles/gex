# Changelog

All notable changes to the gex (Git eXtended) project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **`gex squash`** - Smart commit squashing with safety checks
  - Count-based squashing (`--count=N`)
  - Range-based squashing (`HEAD~3..HEAD`)
  - Interactive commit selection (`--interactive`)
  - Auto-detection of unpushed commits
  - Custom commit messages (`--message`)
  - Intelligent defaults: uses first commit's message when no custom message provided
  - Comprehensive safety checks (clean working directory, pushed commit protection)
  - Dry-run mode (`--dry-run`)
  - Force-push integration warnings
  - Configuration support for default behavior

## [1.0.0] - 2024-08-24

### Major Release - Production Ready

This marks the first stable release of gex with a comprehensive set of Git workflow automation commands.

### Added

#### Core Commands

- **`gex graph`** - Advanced commit history visualization
  - Branch pattern filtering with glob support (`--branches "feature/*"`)
  - Branch exclusion patterns (`--exclude "wip/*"`)
  - Interactive branch selection with fzf (`--interactive`)
  - Branch highlighting (`--highlight "main,develop"`)
  - Time-based filtering (`--since`, `--until`)
  - Author filtering (`--author`)
  - Merge commit filtering (`--merges-only`)
  - Commit count limiting (`--max`)
  - Multiple graph styles (`--style ascii|unicode`)
  - Decoration control (`--decorate short|full|no`)
  - Remote branch inclusion (`--remotes`, `--all`)
  - Color output control (`--no-color`)
  - Safe handling of detached HEAD state

- **`gex start`** - Smart branch creation with naming conventions
  - Configurable branch types (feature, bugfix, hotfix, chore, docs)
  - Automatic base branch detection (main/develop/master)
  - Custom base branch selection (`--from`)
  - Issue number integration (`--issue`)
  - Automatic base branch sync with remote
  - Optional immediate publishing (`--push`)
  - Interactive guided creation (`--interactive`)
  - Branch type listing (`--list-types`)
  - No-switch option for creation without checkout (`--no-switch`)
  - Sync control (`--no-sync`)
  - Comprehensive dry-run mode (`--dry-run`)
  - Smart issue number extraction from branch names

- **`gex publish`** - Safe branch publishing with comprehensive checks
  - Automatic upstream tracking setup
  - Smart remote detection (defaults to origin)
  - Custom remote and branch targeting (`--remote`, `--branch`, `--to`)
  - Force push protection with safer alternatives (`--force-with-lease`)
  - Protected branch warnings (main, master, develop)
  - Branch status information (ahead/behind commits)
  - Automatic force-push detection with user confirmation
  - Remote validation before publishing
  - Detached HEAD protection
  - Comprehensive dry-run preview
  - Integration with gex configuration system

- **`gex snip`** - Cherry-pick commits to avoid rebase conflicts
  - Smart target branch detection (main/develop/master)
  - Custom target branch specification (`--onto`)
  - Specific commit selection (`--commit`)
  - Base branch synchronization with remote
  - Lost commit detection and warnings
  - Force override for advanced users (`--force`)
  - Original branch preservation (`--keep-original`)
  - Custom new branch naming (`--branch`)
  - Comprehensive operation preview (`--dry-run`)
  - Conflict resolution guidance
  - Automatic error recovery with state restoration
  - Already-applied commit detection

- **`gex wip`** - Work-in-progress commit management
  - Quick WIP commits with timestamp
  - Custom WIP messages
  - Perfect rollback functionality (`--undo`)
  - WIP commit history (`--list`)
  - Pre-commit hook bypassing for speed
  - Safe WIP-only operations
  - Working directory state preservation
  - Push capability with hook skipping (`--push`)

- **`gex config`** - Configuration and workflow management
  - Key-value configuration setting (`set`, `get`)
  - Current configuration display (`list`)
  - Workflow preset system (`use`, `presets`)
  - Global and repository-specific configuration
  - Built-in workflow presets (features, patches)
  - Configuration validation and error handling

#### Configuration System

- **Global configuration**: `~/.config/gex/config`
- **Repository configuration**: `.gexrc` in repository root
- **Environment variable overrides**: `GEX_*` variables
- **Workflow presets**:
  - `features`: feature/bugfix/hotfix/chore/docs workflow
  - `patches`: features/patches/hotfix workflow
- **Configurable settings**:
  - `branch_types`: Customizable branch types for start command
  - `default_base_branch`: Default base branch for new branches
  - `default_remote`: Default remote for publishing
  - `protected_branches`: Branches requiring confirmation for force push
  - `auto_set_upstream`: Automatic upstream tracking
  - `auto_sync`: Automatic base branch synchronization

#### Safety Features

- Working directory cleanliness validation
- Force push warnings and safer alternatives
- Protected branch detection and warnings
- Lost commit prevention with override options
- Detached HEAD state protection
- Remote existence validation
- Comprehensive dry-run modes for all commands
- Automatic error recovery mechanisms
- Clear conflict resolution guidance

#### Developer Experience

- Comprehensive help system for all commands
- Rich status information and progress feedback
- Color-coded output with NO_COLOR support
- Debug logging system (`GEX_DEBUG=1`)
- Shell tracing for troubleshooting (`GEX_TRACE=1`)
- Detailed error messages with suggested solutions
- Interactive modes with fzf integration
- Command suggestions for typos

#### Testing Infrastructure

- Comprehensive test suites for all commands
- 16 test cases for snip command functionality
- 13 test cases for publish command functionality
- Edge case coverage and error condition testing
- Cross-platform compatibility testing (macOS/Linux)
- Shell compatibility testing (Bash 3.2+)

#### Documentation

- Complete README with all command documentation
- Quick reference guide for common workflows
- Comprehensive help text for each command
- Configuration examples and best practices
- Troubleshooting guide with common solutions
- Integration examples with other tools

### Changed

- **Version bumped to 1.0.0** indicating production readiness
- **Enhanced main help output** with comprehensive command overview
- **Updated command listing** to use portable find command (macOS compatibility)

### Fixed

- **macOS compatibility**: Replaced GNU-specific `find -printf` with portable alternative
- **Command line argument precedence**: Configuration no longer overrides explicit arguments
- **Variable scope issues**: Fixed `local` variable usage outside functions
- **Shell compatibility**: Improved Bash 3.2 compatibility throughout codebase
- **Error handling**: Enhanced error messages and recovery mechanisms

### Infrastructure

- **Modular command architecture** with shared library system
- **Extensible plugin system** foundation for external commands
- **Configuration hierarchy** with proper precedence rules
- **Cross-platform shell scripting** with compatibility layers
- **Comprehensive logging and debugging** infrastructure

### Performance

- **Optimized Git operations** with minimal repository access
- **Efficient branch filtering** with native Git commands
- **Lazy loading** of expensive operations
- **Smart caching** of configuration and Git metadata

## [0.1.0] - 2024-08-23

### Initial Development

- Project scaffolding and initial architecture
- Basic command dispatcher implementation
- Core library foundation (core.sh, git.sh)
- Initial graph command development
- Configuration system groundwork

---

## Future Releases

### Planned Features

- **sync command**: Smart branch synchronization with remotes
- **prune command**: Cleanup of stale and merged branches
- **squash command**: Interactive commit squashing
- **rebase command**: Safe interactive rebasing with conflict avoidance
- **pr/mr command**: Pull/merge request creation integration
- **issue command**: Issue tracker integration (GitHub, GitLab, Jira)

### Enhancements

- **JSON output modes** for tooling integration
- **Rich Unicode graphs** with persistent branch colors
- **Intelligent subject truncation** for better readability
- **Advanced conflict resolution** automation
- **Plugin system** for custom commands
- **Shell completion** for bash/zsh/fish
- **Git hooks integration** for workflow enforcement

---

**Note**: This project follows semantic versioning. Breaking changes will increment the major version, new features increment the minor version, and bug fixes increment the patch version.

For detailed information about any release, see the corresponding git tags and commit history.
# Makefile for gex (Git eXtended)
#
# Convenience developer tasks.
#
# Common targets:
#   make help         Show this help
#   make install      Install (append gex dir to PATH via shell snippet or symlink)
#   make uninstall    Attempt to remove prior PATH snippet / symlink
#   make test         Run Bats tests (requires bats)
#   make shellcheck   Run shellcheck on all scripts (requires shellcheck)
#   make shfmt        Format shell scripts with shfmt (if available)
#   make lint         shellcheck + (optional) shfmt --diff
#   make version      Show current gex version
#   make bump PATCH=1 Bump version (PATCH|MINOR|MAJOR) in ./gex script
#   make doctor       Quick environment diagnostics
#
# Environment overrides:
#   PREFIX=/usr/local            (for install-symlink)
#   INSTALL_MODE=path|symlink    (default: path)
#
# Notes:
#   - This Makefile avoids GNU-specific extensions when easy.
#   - Version bump is a simple in-place sed; review diffs before committing.

SHELL := /usr/bin/env bash

# Root directory (directory containing this Makefile)
ROOT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
BIN      := $(ROOT_DIR)/gex
COMMANDS := $(wildcard $(ROOT_DIR)/commands/*)
SHELL_SCRIPTS := $(BIN) $(COMMANDS) $(wildcard $(ROOT_DIR)/lib/*.sh) $(wildcard $(ROOT_DIR)/commands/*)

PREFIX ?= /usr/local
INSTALL_MODE ?= path

COLOR ?= 1
ifeq ($(NO_COLOR),1)
  COLOR=0
endif

ifeq ($(COLOR),1)
  BOLD := \033[1m
  DIM  := \033[2m
  GRN  := \033[32m
  YEL  := \033[33m
  RED  := \033[31m
  BLU  := \033[34m
  RST  := \033[0m
else
  BOLD :=
  DIM  :=
  GRN  :=
  YEL  :=
  RED  :=
  BLU  :=
  RST  :=
endif

.PHONY: help
help: ## Show this help
	@echo "$(BOLD)gex Makefile targets$(RST)"
	@echo
	@grep -E '^[a-zA-Z0-9_.-]+:.*?## ' $(MAKEFILE_LIST) | \
	  sed -E 's/:.*?## /:\t/' | \
	  awk -F'\t' '{printf "  $(BOLD)%-16s$(RST) %s\n", $$1, $$2}'
	@echo
	@echo "Variables:"
	@echo "  PREFIX=$(PREFIX)"
	@echo "  INSTALL_MODE=$(INSTALL_MODE) (path|symlink)"
	@echo

.PHONY: ensure-exec
ensure-exec: ## Ensure executable bits are set on main and command scripts
	@chmod +x $(BIN)
	@chmod -R u+rx $(ROOT_DIR)/commands

.PHONY: install
install: ensure-exec ## Install gex (append PATH export or symlink depending on INSTALL_MODE)
ifeq ($(INSTALL_MODE),path)
	@echo "$(BLU)[install]$(RST) Adding export line to $$HOME/.bashrc (if absent)"
	@grep -q 'export PATH="$$HOME/gex:$$PATH"' $$HOME/.bashrc 2>/dev/null || \
	  echo 'export PATH="$$HOME/gex:$$PATH"' >> $$HOME/.bashrc
	@echo "$(GRN)Path export appended (restart shell).$(RST)"
else ifeq ($(INSTALL_MODE),symlink)
	@echo "$(BLU)[install]$(RST) Creating symlink in $(PREFIX)/bin"
	@install -d $(PREFIX)/bin
	@ln -sf $(BIN) $(PREFIX)/bin/gex
	@echo "$(GRN)Symlink created: $(PREFIX)/bin/gex$(RST)"
else
	@echo "$(RED)Unknown INSTALL_MODE=$(INSTALL_MODE) (expected path|symlink)$(RST)"; exit 1
endif

.PHONY: uninstall
uninstall: ## Attempt to uninstall (remove PATH line or symlink)
	@echo "$(BLU)[uninstall]$(RST) Attempting cleanup"
	@if [ -L $(PREFIX)/bin/gex ]; then \
	  echo "Removing symlink $(PREFIX)/bin/gex"; rm -f $(PREFIX)/bin/gex; \
	fi
	@sed -i.bak '/export PATH="$$HOME\/gex:$$PATH"/d' $$HOME/.bashrc 2>/dev/null || true
	@echo "$(GRN)Uninstall attempt complete (manual review may still be needed).$(RST)"

.PHONY: test
test: ## Run Bats tests (requires bats)
	@if ! command -v bats >/dev/null 2>&1; then \
	  echo "$(YEL)bats not found; install from https://github.com/bats-core/bats-core$(RST)"; exit 1; \
	fi
	@echo "$(BLU)[test]$(RST) Running Bats"
	@bats $(ROOT_DIR)/tests

.PHONY: shellcheck
shellcheck: ## Run shellcheck on scripts
	@if ! command -v shellcheck >/dev/null 2>&1; then \
	  echo "$(YEL)shellcheck not installed$(RST)"; exit 1; \
	fi
	@echo "$(BLU)[lint]$(RST) shellcheck"
	@shellcheck $(SHELL_SCRIPTS)

.PHONY: shfmt
shfmt: ## Format shell scripts with shfmt (updates files)
	@if ! command -v shfmt >/dev/null 2>&1; then \
	  echo "$(YEL)shfmt not installed (skip)$(RST)"; exit 0; \
	fi
	@echo "$(BLU)[fmt]$(RST) shfmt -w"
	@shfmt -w -i 2 -sr -ci $(SHELL_SCRIPTS)

.PHONY: lint
lint: ## Run shellcheck and shfmt --diff (if shfmt present)
	$(MAKE) shellcheck
	@if command -v shfmt >/dev/null 2>&1; then \
	  echo "$(BLU)[lint]$(RST) shfmt --diff"; \
	  shfmt -d -i 2 -sr -ci $(SHELL_SCRIPTS) || (echo "$(YEL)Formatting differences detected. Run 'make shfmt'$(RST)"; exit 1); \
	else \
	  echo "$(YEL)shfmt not installed; skipping formatting diff$(RST)"; \
	fi

.PHONY: version
version: ## Print current gex version
	@grep -E '^GEX_VERSION=' $(BIN) | head -n1 | cut -d'"' -f2

# Usage:
#   make bump PATCH=1
#   make bump MINOR=1
#   make bump MAJOR=1
.PHONY: bump
bump: ## Bump version (set one of MAJOR=1 MINOR=1 PATCH=1)
	@current=$$(grep -E '^GEX_VERSION=' $(BIN) | head -n1 | sed -E 's/.*"([0-9]+\.[0-9]+\.[0-9]+)".*/\1/'); \
	part_major=$${current%%.*}; rest=$${current#*.}; part_minor=$${rest%%.*}; part_patch=$${rest#*.}; \
	if [ "$(MAJOR)" = "1" ]; then \
	  part_major=$$((part_major+1)); part_minor=0; part_patch=0; \
	elif [ "$(MINOR)" = "1" ]; then \
	  part_minor=$$((part_minor+1)); part_patch=0; \
	elif [ "$(PATCH)" = "1" ]; then \
	  part_patch=$$((part_patch+1)); \
	else \
	  echo "$(RED)Specify one of MAJOR=1 MINOR=1 PATCH=1$(RST)"; exit 1; \
	fi; \
	new_version="$$part_major.$$part_minor.$$part_patch"; \
	echo "$(BLU)[bump]$(RST) $$current -> $$new_version"; \
	sed -i.bak -E "s/^GEX_VERSION=.*/GEX_VERSION=\"$$new_version\"/" $(BIN); \
	rm -f $(BIN).bak; \
	echo "$(GRN)Version updated to $$new_version$(RST)"

.PHONY: doctor
doctor: ## Environment diagnostics
	@echo "$(BOLD)gex doctor$(RST)"
	@echo "Root:      $(ROOT_DIR)"
	@echo "Shell:     $$SHELL"
	@echo -n "Git:       "; git --version 2>/dev/null || echo "git not found"
	@echo -n "Bash:      "; bash --version | head -n1
	@echo -n "Bats:      "; (command -v bats >/dev/null && bats --version | head -n1) || echo "not installed"
	@echo -n "shellcheck:"; (command -v shellcheck >/dev/null && shellcheck --version | head -n1) || echo " not installed"
	@echo -n "shfmt:     "; (command -v shfmt >/dev/null && shfmt --version 2>/dev/null | head -n1) || echo "not installed"
	@echo -n "fzf:       "; (command -v fzf >/dev/null && fzf --version | head -n1) || echo "not installed"
	@echo "Scripts:"
	@for f in $(SHELL_SCRIPTS); do \
	  head -n1 "$$f" | grep -qE '^#!/usr/bin/env bash' || echo "  $(YEL)WARN$(RST): $$f missing bash shebang"; \
	done
	@echo "$(GRN)Doctor complete$(RST)"

.PHONY: clean
clean: ## Remove temporary artifacts (currently none)
	@echo "Nothing to clean yet."

# Default target
.DEFAULT_GOAL := help

# Makefile for asus-b550-config
# Common development and maintenance tasks

.PHONY: help lint test build clean install check validate format pre-commit setup

# Default target
.DEFAULT_GOAL := help

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
RED := \033[0;31m
YELLOW := \033[0;33m
NC := \033[0m # No Color

help: ## Show this help message
	@echo "$(BLUE)ASUS B550 Configuration - Development Tasks$(NC)"
	@echo ""
	@echo "$(GREEN)Available targets:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-20s$(NC) %s\n", $$1, $$2}'

setup: ## Install development dependencies
	@echo "$(BLUE)Installing development dependencies...$(NC)"
	@command -v shellcheck >/dev/null 2>&1 || (echo "$(RED)Installing shellcheck...$(NC)" && sudo pacman -S --noconfirm shellcheck)
	@command -v markdownlint >/dev/null 2>&1 || (echo "$(RED)Installing markdownlint...$(NC)" && npm install -g markdownlint-cli)
	@command -v pre-commit >/dev/null 2>&1 || (echo "$(RED)Installing pre-commit...$(NC)" && pip install pre-commit)
	@echo "$(GREEN)Setting up pre-commit hooks...$(NC)"
	@pre-commit install
	@echo "$(GREEN)✓ Setup complete!$(NC)"

lint: lint-shell lint-markdown lint-editorconfig ## Run all linters

lint-shell: ## Lint shell scripts with shellcheck
	@echo "$(BLUE)Running shellcheck...$(NC)"
	@shellcheck -S warning scripts/*.sh
	@echo "$(GREEN)✓ Shell scripts pass$(NC)"

lint-markdown: ## Lint markdown files
	@echo "$(BLUE)Running markdownlint...$(NC)"
	@markdownlint '**/*.md' --ignore node_modules
	@echo "$(GREEN)✓ Markdown files pass$(NC)"

lint-editorconfig: ## Check EditorConfig compliance
	@echo "$(BLUE)Checking EditorConfig compliance...$(NC)"
	@command -v editorconfig-checker >/dev/null 2>&1 || (echo "$(YELLOW)editorconfig-checker not installed, skipping...$(NC)" && exit 0)
	@editorconfig-checker
	@echo "$(GREEN)✓ EditorConfig compliance$(NC)"

test: test-syntax test-build ## Run all tests

test-syntax: ## Test shell script syntax
	@echo "$(BLUE)Testing shell script syntax...$(NC)"
	@for script in scripts/*.sh; do \
		echo "  Checking $$script..."; \
		bash -n "$$script" || exit 1; \
	done
	@bash -n PKGBUILD || exit 1
	@echo "$(GREEN)✓ All syntax checks pass$(NC)"

test-build: ## Test C code compilation
	@echo "$(BLUE)Testing C code compilation...$(NC)"
	@gcc -std=c2x -O2 -Wall -Wextra -Werror -o /tmp/nct-id scripts/nct-id.c
	@echo "$(GREEN)✓ C code compiles$(NC)"
	@rm -f /tmp/nct-id

build: ## Build the nct-id utility
	@echo "$(BLUE)Building nct-id utility...$(NC)"
	@gcc -std=c2x -O2 -Wall -Wextra -Werror -o nct-id scripts/nct-id.c
	@echo "$(GREEN)✓ Built: nct-id$(NC)"

build-package: ## Build Arch package
	@echo "$(BLUE)Building Arch package...$(NC)"
	@makepkg -f -C
	@echo "$(GREEN)✓ Package built$(NC)"

clean: ## Clean build artifacts
	@echo "$(BLUE)Cleaning build artifacts...$(NC)"
	@rm -f nct-id
	@rm -rf src/ pkg/
	@rm -f *.pkg.tar.*
	@rm -f *.tar.gz *.tar.bz2 *.tar.xz *.tar.zst
	@echo "$(GREEN)✓ Cleaned$(NC)"

validate: lint test ## Run all validation checks (lint + test)
	@echo "$(GREEN)✓ All validation checks pass!$(NC)"

check: validate ## Alias for validate

format: ## Auto-format files (where possible)
	@echo "$(BLUE)Auto-formatting markdown files...$(NC)"
	@markdownlint --fix '**/*.md' --ignore node_modules || true
	@echo "$(GREEN)✓ Files formatted$(NC)"

pre-commit: ## Run pre-commit hooks on all files
	@echo "$(BLUE)Running pre-commit hooks...$(NC)"
	@pre-commit run --all-files
	@echo "$(GREEN)✓ Pre-commit checks pass$(NC)"

install: build-package ## Install the package
	@echo "$(BLUE)Installing package...$(NC)"
	@sudo pacman -U --noconfirm *.pkg.tar.*
	@echo "$(GREEN)✓ Package installed$(NC)"

uninstall: ## Uninstall the package
	@echo "$(BLUE)Uninstalling package...$(NC)"
	@sudo pacman -R --noconfirm eirikr-asus-b550-config || echo "Package not installed"
	@echo "$(GREEN)✓ Package uninstalled$(NC)"

verify: ## Verify installation
	@echo "$(BLUE)Verifying installation...$(NC)"
	@test -f /usr/lib/eirikr/max-fans.sh && echo "  ✓ max-fans.sh installed" || echo "  ✗ max-fans.sh missing"
	@test -f /usr/lib/eirikr/max-fans-enhanced.sh && echo "  ✓ max-fans-enhanced.sh installed" || echo "  ✗ max-fans-enhanced.sh missing"
	@test -f /usr/lib/eirikr/max-fans-advanced.sh && echo "  ✓ max-fans-advanced.sh installed" || echo "  ✗ max-fans-advanced.sh missing"
	@test -f /usr/lib/eirikr/nct-id && echo "  ✓ nct-id installed" || echo "  ✗ nct-id missing"
	@test -f /usr/lib/systemd/system/max-fans.service && echo "  ✓ systemd units installed" || echo "  ✗ systemd units missing"
	@echo "$(GREEN)✓ Verification complete$(NC)"

ci: lint test ## Run CI checks locally
	@echo "$(GREEN)✓ All CI checks pass!$(NC)"

docs: ## Build documentation (if applicable)
	@echo "$(BLUE)Documentation is in markdown format$(NC)"
	@echo "  Main docs: docs/"
	@echo "  README: README.md"
	@echo "  CI/CD: .github/CI-CD.md"

stats: ## Show repository statistics
	@echo "$(BLUE)Repository Statistics$(NC)"
	@echo ""
	@echo "$(YELLOW)Code:$(NC)"
	@echo "  Shell scripts: $$(find scripts -name '*.sh' | wc -l)"
	@echo "  C files: $$(find scripts -name '*.c' | wc -l)"
	@echo "  Total LOC (scripts): $$(cat scripts/*.sh scripts/*.c 2>/dev/null | wc -l)"
	@echo ""
	@echo "$(YELLOW)Documentation:$(NC)"
	@echo "  Markdown files: $$(find . -name '*.md' ! -path './node_modules/*' | wc -l)"
	@echo "  Total LOC (docs): $$(find . -name '*.md' ! -path './node_modules/*' -exec cat {} \; | wc -l)"
	@echo ""
	@echo "$(YELLOW)Configuration:$(NC)"
	@echo "  Systemd units: $$(find systemd -name '*.service' -o -name '*.timer' | wc -l)"
	@echo "  Udev rules: $$(find udev -name '*.rules' | wc -l)"
	@echo ""
	@echo "$(YELLOW)CI/CD:$(NC)"
	@echo "  Workflows: $$(find .github/workflows -name '*.yml' | wc -l)"

# CI/CD Pipeline Documentation

This document describes the continuous integration and continuous deployment (CI/CD) pipelines for the asus-b550-config project.

## Overview

The project uses GitHub Actions for automated testing, linting, and validation. The pipelines run on every push and pull request to ensure code quality and prevent regressions.

## Workflows

### 1. Lint Workflow (`.github/workflows/lint.yml`)

**Purpose**: Enforce code quality and style standards

**Triggers**:
- Push to `main`, `develop`, or `copilot/**` branches
- Pull requests to `main` or `develop`

**Jobs**:

#### ShellCheck (Shell Script Linting)
- **What**: Analyzes all shell scripts in `scripts/` directory
- **Tool**: ShellCheck with severity level `warning` (warnings treated as errors)
- **Flags**: `-S warning` treats warnings as errors
- **Why**: Catches common shell scripting errors, portability issues, and bad practices

#### Markdownlint (Markdown Linting)
- **What**: Validates all `.md` files for style and formatting
- **Tool**: markdownlint-cli
- **Config**: Uses `.markdownlintrc` in repository root
- **Why**: Ensures consistent documentation formatting and readability

#### EditorConfig Check
- **What**: Validates files follow EditorConfig rules
- **Tool**: editorconfig-checker
- **Config**: Uses `.editorconfig` in repository root
- **Why**: Ensures consistent code formatting across different editors and contributors

### 2. Build & Test Workflow (`.github/workflows/build.yml`)

**Purpose**: Validate that all components build and compile correctly

**Triggers**:
- Push to `main`, `develop`, or `copilot/**` branches
- Pull requests to `main` or `develop`

**Jobs**:

#### Build C Code (nct-id utility)
- **What**: Compiles the `nct-id.c` utility
- **Compiler**: GCC with C2x standard (C23 equivalent)
- **Flags**: `-Wall -Wextra -Werror` (all warnings, treat warnings as errors)
- **Artifact**: Uploads compiled binary for inspection
- **Why**: Ensures C code compiles on clean systems without errors

#### Validate PKGBUILD (Arch Package)
- **What**: Validates Arch Linux package build script
- **Container**: Uses official `archlinux:latest` container
- **Tools**: 
  - `bash -n` for syntax checking
  - `namcap` for Arch packaging standards
  - `makepkg --nobuild` for dry run
- **Why**: Ensures package can be built on Arch Linux systems

#### Validate Shell Scripts (Syntax)
- **What**: Syntax checks all shell scripts
- **Tool**: `bash -n` (syntax check without execution)
- **Why**: Catches syntax errors before runtime

#### Validate Systemd Units
- **What**: Validates systemd service and timer files
- **Tool**: `systemd-analyze verify`
- **Why**: Ensures systemd units are properly formatted

### 3. Documentation Workflow (`.github/workflows/documentation.yml`)

**Purpose**: Ensure documentation is complete and links are valid

**Triggers**:
- Push to `main`, `develop`, or `copilot/**` branches
- Pull requests to `main` or `develop`

**Jobs**:

#### Check Markdown Links
- **What**: Validates all URLs in markdown files
- **Tool**: markdown-link-check
- **Config**: Uses `.github/markdown-link-check.json`
- **Why**: Prevents broken links in documentation

#### Validate Example Configurations
- **What**: Syntax checks example configuration files
- **Tool**: `bash -n` for shell script syntax
- **Why**: Ensures examples are valid and won't error when used

#### Check Documentation Completeness
- **What**: Verifies all essential documentation files exist
- **Checks**:
  - Essential files: README.md, CHANGELOG.md, CONTRIBUTING.md, SECURITY.md, SUPPORT.md, LICENSE
  - Documentation directory structure
  - Key technical documentation files
- **Why**: Ensures complete documentation for users and contributors

## Status Badges

Add these badges to README.md to show CI/CD status:

```markdown
[![Lint](https://github.com/Oichkatzelesfrettschen/asus-b550-config/actions/workflows/lint.yml/badge.svg)](https://github.com/Oichkatzelesfrettschen/asus-b550-config/actions/workflows/lint.yml)
[![Build & Test](https://github.com/Oichkatzelesfrettschen/asus-b550-config/actions/workflows/build.yml/badge.svg)](https://github.com/Oichkatzelesfrettschen/asus-b550-config/actions/workflows/build.yml)
[![Documentation](https://github.com/Oichkatzelesfrettschen/asus-b550-config/actions/workflows/documentation.yml/badge.svg)](https://github.com/Oichkatzelesfrettschen/asus-b550-config/actions/workflows/documentation.yml)
```

## Local Development

### Running Checks Locally

Before pushing code, run these checks locally:

```bash
# Shell script linting
shellcheck -S warning scripts/*.sh

# Markdown linting
markdownlint '**/*.md' --ignore node_modules

# EditorConfig check
editorconfig-checker

# C code compilation
gcc -std=c2x -O2 -Wall -Wextra -Werror -o nct-id scripts/nct-id.c

# PKGBUILD syntax
bash -n PKGBUILD

# Shell script syntax
bash -n scripts/*.sh

# Example configuration syntax
bash -n examples/max-fans-restore.conf.example
```

### Installing Tools Locally

```bash
# ShellCheck (Arch Linux)
sudo pacman -S shellcheck

# ShellCheck (Ubuntu/Debian)
sudo apt-get install shellcheck

# Markdownlint
npm install -g markdownlint-cli

# EditorConfig Checker
wget -O /tmp/ec.tar.gz https://github.com/editorconfig-checker/editorconfig-checker/releases/latest/download/ec-linux-amd64.tar.gz
tar -xzf /tmp/ec.tar.gz -C /tmp
sudo mv /tmp/bin/ec-linux-amd64 /usr/local/bin/editorconfig-checker
sudo chmod +x /usr/local/bin/editorconfig-checker

# Markdown Link Check
npm install -g markdown-link-check
```

## Future Enhancements

### Recommended Additions

1. **Security Scanning**
   - Add Dependabot for dependency updates
   - Add CodeQL for security analysis
   - Add secret scanning

2. **Release Automation**
   - Automated version bumping
   - Changelog generation
   - GitHub Releases creation
   - Package artifact uploads

3. **Code Coverage** (if tests are added)
   - Coverage reporting
   - Coverage badges
   - Trend tracking

4. **Performance Testing**
   - Script execution benchmarks
   - Binary size tracking

5. **Integration Testing**
   - Test on multiple Arch Linux versions
   - Test on different kernel versions
   - Mock hardware tests

### Security Best Practices

1. **Branch Protection**
   - Require status checks to pass before merging
   - Require pull request reviews
   - Require signed commits
   - Dismiss stale reviews

2. **Environment Secrets**
   - Store sensitive data in GitHub Secrets
   - Use environment-specific secrets
   - Rotate secrets regularly

3. **Dependency Management**
   - Keep GitHub Actions versions pinned
   - Use Dependabot for updates
   - Review dependency changes

## Troubleshooting

### Common Issues

**Issue**: ShellCheck fails with SC2034 (unused variable)
- **Solution**: Remove unused variables or add `# shellcheck disable=SC2034` comment

**Issue**: Markdownlint fails on long lines
- **Solution**: Adjust `.markdownlintrc` line length or break long lines

**Issue**: PKGBUILD validation fails
- **Solution**: Run `namcap PKGBUILD` locally and fix reported issues

**Issue**: Markdown link check fails
- **Solution**: Fix broken links or add exceptions to `.github/markdown-link-check.json`

### Getting Help

- Check workflow logs in GitHub Actions tab
- Review tool documentation (links in this file)
- Open an issue with `ci-cd` label

## Maintenance

### Updating Workflows

1. Test changes in a feature branch first
2. Review workflow runs before merging to main
3. Document any breaking changes in CHANGELOG.md
4. Update this documentation when adding new workflows

### Monitoring

- Review GitHub Actions usage monthly (check limits)
- Monitor workflow run times (optimize if slow)
- Check for failed workflows (fix or investigate)
- Update dependencies quarterly

## References

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [ShellCheck Wiki](https://github.com/koalaman/shellcheck/wiki)
- [Markdownlint Rules](https://github.com/DavidAnson/markdownlint/blob/main/doc/Rules.md)
- [EditorConfig](https://editorconfig.org/)
- [Arch Linux Packaging Standards](https://wiki.archlinux.org/title/Arch_package_guidelines)

---

**Last Updated**: 2025-11-02
**Maintained By**: Project maintainers

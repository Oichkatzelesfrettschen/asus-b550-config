# Contributing to asus-b550-config

Thank you for your interest in contributing to this project! This document provides guidelines for contributing to the ASUS B550 configuration package.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Coding Standards](#coding-standards)
- [Testing](#testing)
- [Submitting Changes](#submitting-changes)
- [Documentation](#documentation)

## Code of Conduct

This project follows standard open-source community guidelines:

- Be respectful and inclusive
- Focus on constructive feedback
- Accept differing viewpoints
- Prioritize the community's best interests

## Getting Started

### Prerequisites

- Arch Linux (or compatible distribution)
- ASUS B550 motherboard with NCT6798D Super I/O chip
- Development tools: `gcc`, `shellcheck`, `namcap`
- Testing tools: `lm_sensors`, `systemd`

### Repository Structure

```
asus-b550-config/
├── docs/               # Documentation files
├── scripts/            # Shell scripts and C utilities
├── systemd/            # Systemd service and timer units
├── udev/               # Udev rules
├── etc/                # Configuration files
├── examples/           # Example configurations
├── PKGBUILD            # Arch package build script
├── eirikr-asus-b550-config.install  # Package install script
└── README.md           # Main documentation
```

### Clone and Build

```bash
git clone https://github.com/Oichkatzelesfrettschen/asus-b550-config.git
cd asus-b550-config
makepkg -f -C
```

## Development Workflow

1. **Fork the repository** on GitHub
2. **Create a feature branch** from `main`:

   ```bash
   git checkout -b feature/my-feature
   ```

3. **Make your changes** following coding standards
4. **Test thoroughly** on real hardware (if possible)
5. **Commit with clear messages**:

   ```bash
   git commit -m "Add feature: brief description"
   ```

6. **Push to your fork**:

   ```bash
   git push origin feature/my-feature
   ```

7. **Submit a pull request** to the main repository

## Coding Standards

### Shell Scripts

All shell scripts must:

- Use `#!/bin/bash` shebang
- Set `set -u` and `set -o pipefail` for safety
- Pass `shellcheck -S error` with zero warnings
- Include comprehensive comments explaining WHY, not just WHAT
- Use readonly variables where appropriate
- Follow naming conventions:
  - Variables: `lowercase_with_underscores`
  - Constants: `UPPERCASE_WITH_UNDERSCORES`
  - Functions: `verb_noun` format

Example:

```bash
#!/bin/bash
set -u
set -o pipefail

readonly HWMON_PATH="/sys/class/hwmon"

log_info() {
  echo "[INFO] $*"
}

main() {
  log_info "Starting operation"
  # Implementation
}

main "$@"
```

### C Code

All C code must:

- Use C23 standard (`-std=c23`)
- Compile with `-Wall -Wextra -Werror`
- Include comprehensive header comments
- Document all functions with purpose, parameters, and return values
- Use meaningful variable names
- Follow Linux kernel coding style where applicable

### PKGBUILD

- Follow Arch Linux PKGBUILD standards
- Pass `namcap` validation
- Include detailed comments for all decisions
- Update `pkgver` and `pkgrel` appropriately
- Maintain checksums (or use `SKIP` for development)

## Testing

All pull requests are automatically tested via GitHub Actions CI/CD pipeline. See [.github/CI-CD.md](../.github/CI-CD.md) for details.

### Local Testing (Before Submitting PR)

Run these checks locally before submitting a pull request:

```bash
# Lint all shell scripts (warnings as errors)
shellcheck -S warning scripts/*.sh

# Lint all markdown files
markdownlint '**/*.md' --ignore node_modules

# Check EditorConfig compliance
editorconfig-checker

# Build C code
gcc -std=c2x -O2 -Wall -Wextra -Werror -o nct-id scripts/nct-id.c

# Validate PKGBUILD syntax
bash -n PKGBUILD

# Validate shell script syntax
bash -n scripts/*.sh

# Validate example configurations
bash -n examples/max-fans-restore.conf.example
```

### Shell Script Testing

```bash
# Lint all shell scripts
shellcheck -S error scripts/*.sh

# Test on real hardware (requires NCT6798D)
sudo scripts/max-fans.sh
sudo scripts/max-fans-advanced.sh --verify
```

### C Code Testing

```bash
# Build with all warnings
gcc -std=c23 -O2 -Wall -Wextra -Werror -o nct-id scripts/nct-id.c

# Test execution (requires root)
sudo ./nct-id
```

### Package Testing

```bash
# Build package
makepkg -f -C

# Test installation
sudo pacman -U eirikr-asus-b550-config-*.pkg.tar.*

# Verify services
systemctl status max-fans.service
sudo /usr/lib/eirikr/max-fans-advanced.sh --verify

# Test uninstallation
sudo pacman -R eirikr-asus-b550-config
```

## Submitting Changes

### Pull Request Guidelines

- **Title**: Clear, concise description of the change
- **Description**: Include:
  - Problem being solved
  - Solution approach
  - Testing performed
  - Breaking changes (if any)
  - Related issues (if any)

### Commit Message Format

```
<type>: <subject>

<body>

<footer>
```

Types:

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, no logic change)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Build process, tooling, dependencies

Example:

```
feat: Add support for Speed Cruise mode

Implement Speed Cruise (mode 3) which maintains target RPM
via hardware closed-loop control. Requires tachometry calibration.

Tested on ASUS ROG STRIX B550-F GAMING WIFI with NCT6798D.

Closes #42
```

## Documentation

### Documentation Standards

- Use Markdown format
- Include code examples
- Explain WHY, not just HOW
- Keep technical accuracy high
- Update all affected documentation

### Required Documentation Updates

When making changes, update:

1. **README.md** - If user-facing features change
2. **docs/** - Technical documentation for new features
3. **PKGBUILD** - Comments if build process changes
4. **examples/** - New example configurations
5. **CHANGELOG.md** - Version history (when created)

### Documentation Structure

```markdown
# Feature Name

## Overview
Brief description of what it does

## Usage
```bash
# Example command
sudo max-fans-advanced.sh --feature
```

## Technical Details

How it works under the hood

## Troubleshooting

Common issues and solutions

```

## Hardware Compatibility

When contributing features:

- **Test on real hardware** whenever possible
- **Document tested boards** in PR description
- **Note hardware requirements** clearly
- **Handle errors gracefully** for incompatible hardware

## Questions?

- **Issues**: Use GitHub Issues for bug reports and feature requests
- **Discussions**: Use GitHub Discussions for questions
- **Security**: Email security issues privately (see SECURITY.md if available)

## License

By contributing, you agree that your contributions will be licensed under the **GNU General Public License v3.0 (GPLv3)**, the same license as the project.

---

**Thank you for contributing!** Your efforts help make this project better for everyone.

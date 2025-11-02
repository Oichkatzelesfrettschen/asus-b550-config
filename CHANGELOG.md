# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- Reorganized repository structure for better maintainability
  - Moved documentation to `docs/` directory
  - Moved scripts to `scripts/` directory
  - Moved systemd units to `systemd/` directory
  - Moved udev rules to `udev/` directory
  - Moved configuration files to `etc/` directory
- Updated PKGBUILD to reflect new directory structure

### Added
- `CONTRIBUTING.md` with comprehensive contribution guidelines
- `CHANGELOG.md` for version tracking
- `examples/max-fans-restore.conf.example` with detailed usage examples
- `.editorconfig` for consistent code formatting across editors

## [1.3.0] - 2025-11-02

### Added
- Complete NCT6798D hardware monitoring and fan control
- 7-point SmartFan IV curves with configurable timing
- Thermal Cruise mode for constant temperature control
- Speed Cruise mode for RPM-based control (experimental)
- Dual-sensor blending (combine two temperature inputs per fan)
- Electrical mode switching (DC vs PWM)
- Tachometry calibration for accurate RPM readings
- Kernel debounce support for tach signal noise reduction
- Systemd persistence (settings survive firmware resets)
- Three script levels: simple, enhanced, advanced
- Comprehensive technical documentation

### Changed
- License changed from CC0 to GNU General Public License v3.0

### Fixed
- Hardware monitor permission issues via udev rules
- SATA resume compatibility improvements

## [1.0.0] - Initial Release

### Added
- Basic fan control functionality
- PKGBUILD for Arch Linux
- README with installation instructions
- LICENSE file

---

## Version Numbering

This project uses [Semantic Versioning](https://semver.org/):

- **MAJOR** version: Incompatible API changes or significant architectural changes
- **MINOR** version: New features in a backwards-compatible manner
- **PATCH** version: Backwards-compatible bug fixes

## Categories

- **Added**: New features
- **Changed**: Changes to existing functionality
- **Deprecated**: Soon-to-be removed features
- **Removed**: Removed features
- **Fixed**: Bug fixes
- **Security**: Security vulnerability fixes

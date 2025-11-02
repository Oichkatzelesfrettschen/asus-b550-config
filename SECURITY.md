# Security Policy

## Supported Versions

We actively support the following versions with security updates:

| Version | Supported          |
| ------- | ------------------ |
| 1.3.x   | :white_check_mark: |
| < 1.3   | :x:                |

## Reporting a Vulnerability

We take security seriously. If you discover a security vulnerability in this project, please report it responsibly.

### Reporting Process

1. **Do NOT** open a public GitHub issue for security vulnerabilities
2. Email security concerns privately to the maintainer (see GitHub profile)
3. Include the following information in your report:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if available)

### What to Expect

- **Acknowledgment**: We will acknowledge receipt within 48 hours
- **Assessment**: We will assess the vulnerability and its impact
- **Communication**: We will keep you informed of our progress
- **Resolution**: We will work to fix the issue promptly
- **Credit**: We will credit you in the fix (unless you prefer anonymity)

### Timeline

- **Critical**: Fix within 7 days
- **High**: Fix within 14 days
- **Medium**: Fix within 30 days
- **Low**: Fix within 60 days

## Security Considerations

This package interacts with hardware and requires root privileges. Users should be aware of:

### Hardware Access

- Scripts require root access to modify hardware monitoring settings
- Direct Super I/O port access (nct-id utility) can conflict with kernel drivers
- Incorrect fan settings could potentially damage hardware or reduce cooling effectiveness

### Best Practices

1. **Review scripts** before running them with root privileges
2. **Test changes** on non-critical systems first
3. **Monitor temperatures** after making fan control changes
4. **Keep firmware updated** to avoid BIOS/firmware conflicts
5. **Backup configurations** before making major changes

### Known Limitations

- Scripts assume trusted input (no input sanitization for performance)
- Direct hardware access requires elevated privileges
- Settings may be reset by firmware during power transitions
- Some features depend on specific hardware capabilities

## Vulnerability Categories

We consider the following security-relevant:

- **Critical**: Remote code execution, privilege escalation
- **High**: Local code execution, unauthorized hardware access
- **Medium**: Information disclosure, denial of service
- **Low**: Configuration issues, minor information leaks

Out of scope:
- Hardware failures due to overclocking or extreme settings (user responsibility)
- Firmware bugs (report to motherboard vendor)
- Kernel driver bugs (report to Linux kernel developers)

## Updates and Patches

Security updates will be:
- Released as patch versions (e.g., 1.3.1)
- Documented in [CHANGELOG.md](CHANGELOG.md)
- Announced via GitHub releases
- Tagged with `security` label

## External Dependencies

This project has minimal dependencies:
- `systemd` - System and service manager
- `lm_sensors` - Hardware monitoring utilities
- `gcc` - For building nct-id utility

We monitor security advisories for these dependencies and will update as needed.

## Questions?

For non-security questions, please use GitHub Issues or Discussions.

For security concerns, please follow the reporting process above.

---

**Last Updated**: 2025-11-02

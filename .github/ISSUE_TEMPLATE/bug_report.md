---
name: Bug report
about: Create a report to help us improve
title: '[BUG] '
labels: bug
assignees: ''
---

## Bug Description
A clear and concise description of the bug.

## Environment
- **Distribution**: [e.g., Arch Linux]
- **Kernel Version**: [e.g., 6.5.0]
- **Package Version**: [e.g., 1.3.0]
- **Motherboard**: [e.g., ASUS ROG STRIX B550-F GAMING WIFI]
- **Super I/O Chip**: [e.g., NCT6798D - check with `sensors` or `nct-id`]

## Steps to Reproduce
1. Go to '...'
2. Run command '...'
3. See error

## Expected Behavior
What you expected to happen.

## Actual Behavior
What actually happened.

## Logs and Output
```
Paste relevant logs, error messages, or command output here.

Examples:
- `journalctl -u max-fans.service`
- `sudo /usr/lib/eirikr/max-fans-advanced.sh --verify`
- `sensors` output
- `dmesg | grep -i nct6798`
```

## Configuration
If applicable, include your configuration files:
- `/usr/local/etc/max-fans-restore.conf`
- `/etc/modprobe.d/nct6798d.conf`

## Additional Context
Add any other context about the problem here (e.g., recent BIOS updates, hardware changes).

## Checklist
- [ ] I have read the documentation in `/usr/share/doc/eirikr-asus-b550-config/`
- [ ] I have checked existing issues for duplicates
- [ ] I have verified the chip is NCT6798D using `sensors` or `nct-id`
- [ ] I have included relevant logs and configuration

# Support

Looking for help with asus-b550-config? Here are your options.

## Documentation

Start with the comprehensive documentation included with the package:

### Main Documentation

- **[README.md](README.md)** - Overview, installation, quick start
- **[docs/ASUS-B550-TUNING.md](docs/ASUS-B550-TUNING.md)** - Getting started guide and troubleshooting
- **[docs/NCT6798D-PROGRAMMER-GUIDE.md](docs/NCT6798D-PROGRAMMER-GUIDE.md)** - Technical deep-dive
- **[docs/NCT6798D-ADVANCED-CONTROLS.md](docs/NCT6798D-ADVANCED-CONTROLS.md)** - All control modes and capabilities

### After Installation

View documentation on your system:

```bash
ls /usr/share/doc/eirikr-asus-b550-config/
```

### Examples

Check out example configurations:

```bash
cat /path/to/examples/max-fans-restore.conf.example
```

## Common Issues

### Fans Not Responding

1. Check that the service is running:

   ```bash
   sudo systemctl status max-fans.service
   ```

2. Verify hardware monitor permissions:

   ```bash
   ls -la /sys/class/hwmon/hwmon*/pwm*
   ```

3. Check chip detection:

   ```bash
   sensors | grep -i nct6798
   sudo /usr/lib/eirikr/nct-id
   ```

### Permission Denied Errors

The udev rules should grant proper permissions. If you see permission errors:

```bash
sudo udevadm control --reload-rules
sudo udevadm trigger --type=devices --action=change
```

### Settings Reset After Reboot

Use the persistence mechanism:

```bash
# Create restore configuration
sudo cp examples/max-fans-restore.conf.example /usr/local/etc/max-fans-restore.conf
sudo chmod +x /usr/local/etc/max-fans-restore.conf

# Enable and start timer
sudo systemctl enable max-fans-restore.timer
sudo systemctl start max-fans-restore.timer
```

### Hardware Not Detected

1. Confirm your board has NCT6798D:

   ```bash
   sensors | grep -i nct
   lspci | grep -i super
   ```

2. Check kernel module is loaded:

   ```bash
   lsmod | grep nct6775
   sudo modprobe nct6775
   ```

3. Check kernel logs:

   ```bash
   dmesg | grep -i nct6798
   journalctl -b | grep -i hwmon
   ```

## Getting Help

### Before Asking

1. **Search existing issues** - Your question may already be answered
2. **Read the documentation** - Most questions are covered in the docs
3. **Check the logs** - Error messages often point to the solution
4. **Verify your hardware** - Confirm you have compatible hardware

### GitHub Issues

For bugs and problems:

- **[Report a Bug](https://github.com/Oichkatzelesfrettschen/asus-b550-config/issues/new?template=bug_report.md)**
- **[Request a Feature](https://github.com/Oichkatzelesfrettschen/asus-b550-config/issues/new?template=feature_request.md)**
- **[Report Hardware Compatibility](https://github.com/Oichkatzelesfrettschen/asus-b550-config/issues/new?template=hardware_compatibility.md)**

When reporting issues, include:

- Motherboard model and BIOS version
- Distribution and kernel version
- Package version
- Full error messages and logs
- Output of `sensors` and `sudo nct-id`

### GitHub Discussions

For questions, ideas, and community support:

- **[Ask a Question](https://github.com/Oichkatzelesfrettschen/asus-b550-config/discussions)**
- **[Share Your Setup](https://github.com/Oichkatzelesfrettschen/asus-b550-config/discussions)**
- **[General Discussion](https://github.com/Oichkatzelesfrettschen/asus-b550-config/discussions)**

## Community Resources

### Related Projects

- [lm-sensors](https://github.com/lm-sensors/lm-sensors) - Hardware monitoring utilities
- [Linux kernel nct6775 driver](https://docs.kernel.org/hwmon/nct6775.html)

### External Documentation

- [Arch Linux Wiki - lm_sensors](https://wiki.archlinux.org/title/Lm_sensors)
- [Arch Linux Wiki - Fan speed control](https://wiki.archlinux.org/title/Fan_speed_control)

## Contributing

Want to help improve the project?

- **[Contributing Guidelines](CONTRIBUTING.md)**
- **[Code of Conduct](#)** (Be respectful and constructive)

## Security Issues

For security vulnerabilities, please follow our **[Security Policy](SECURITY.md)** for responsible disclosure.

## Professional Support

This is a community-driven open-source project. Professional support is not available, but the community is generally responsive and helpful.

## Useful Commands

### Diagnostic Commands

```bash
# Check hardware
sensors
sudo /usr/lib/eirikr/nct-id

# Check services
systemctl status max-fans.service
systemctl status max-fans-restore.service
journalctl -u max-fans.service

# Verify settings
sudo /usr/lib/eirikr/max-fans-advanced.sh --verify

# Check permissions
ls -la /sys/class/hwmon/hwmon*/pwm*
```

### Testing Commands

```bash
# Set all fans to max (simple)
sudo /usr/lib/eirikr/max-fans.sh

# Install SmartFan IV curves (advanced)
sudo /usr/lib/eirikr/max-fans-advanced.sh --smartfan-7pt

# Verify chip detection
sudo /usr/lib/eirikr/nct-id
```

## Still Need Help?

If you've:

1. Read the documentation
2. Checked existing issues
3. Tried the troubleshooting steps
4. Searched for similar problems

And still need help, please open a new issue with all the relevant information. We're here to help!

---

**Remember**: This project is maintained by volunteers in their spare time. Please be patient and respectful when asking for help.

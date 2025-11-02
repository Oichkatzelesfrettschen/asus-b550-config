# Examples Directory

This directory contains example configuration files for the asus-b550-config package.

## Files

### max-fans-restore.conf.example

Complete example configuration for the `max-fans-restore.service` persistence mechanism.

**Purpose**: Demonstrates all available fan control features and how to combine them for optimal system cooling.

**Usage**:

1. Review the example file and customize it for your needs:

   ```bash
   cat /path/to/examples/max-fans-restore.conf.example
   ```

2. Copy the customized version to the system location:

   ```bash
   sudo cp examples/max-fans-restore.conf.example /usr/local/etc/max-fans-restore.conf
   sudo chmod +x /usr/local/etc/max-fans-restore.conf
   ```

3. Enable and start the timer:

   ```bash
   sudo systemctl enable max-fans-restore.timer
   sudo systemctl start max-fans-restore.timer
   ```

4. Verify it works:

   ```bash
   sudo systemctl status max-fans-restore.service
   journalctl -u max-fans-restore.service
   ```

**Features Demonstrated**:

- 7-point SmartFan IV curves with configurable timing
- Dual-sensor temperature blending
- Thermal Cruise mode for constant temperature
- Electrical mode switching (DC vs PWM)
- Tachometry calibration
- Kernel debounce configuration
- Settings verification

## Contributing Examples

If you have a useful configuration that others might benefit from:

1. Create a new example file with a descriptive name
2. Include comprehensive comments explaining:
   - What hardware it's designed for
   - Why each setting was chosen
   - Expected behavior
3. Add a section to this README describing the example
4. Submit a pull request

See [CONTRIBUTING.md](../CONTRIBUTING.md) for details.

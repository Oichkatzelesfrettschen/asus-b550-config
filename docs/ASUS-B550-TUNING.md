# ASUS B550 Motherboard Tuning Guide

This package provides complete hardware monitoring and fan control configuration for ASUS ROG STRIX B550-F GAMING WIFI motherboards.

## Hardware Overview

**Chipset**: ASUS B550
**Super I/O**: Nuvoton NCT6798D
**Sensors**:

- 6x Temperature sensors
- 6x Voltage sensors
- 6x Fan/PWM channels (pwm1-pwm6)

## Issues Fixed

### 1. Max Fans Service Permission Denied

**Before**:

```
Oct 31 09:33:48 x570-5600X3D bash[764]: /bin/bash: line 1: /sys/class/hwmon/hwmon7/pwm5: Permission denied
```

**After**: Udev rules grant proper permissions, service starts successfully

### 2. Hardware Monitor Not Accessible

**Before**: `/sys/class/hwmon/` files owned by root:root with mode 644
**After**: Mode 664 (group/world readable), root writable

## Configuration Files

### Udev Rules: 50-asus-hwmon-permissions.rules

Grants read/write access to hwmon devices:

- `hwmon*` directories: mode 755
- `pwm*` files: mode 664
- Temperature/voltage sensors: mode 444/644

### Service: max-fans.service

- Type: oneshot
- Runs: `/usr/lib/eirikr/max-fans.sh`
- Sets all pwm[1-6] to 255 (maximum)
- Enables aggressive cooling

### Module Config: modprobe-nct6798d.conf

Default sensor configuration:

- `pwm_mode=0`: PWM mode (vs voltage mode)
- Optional: `disable_power_saving=1` if sensors become unreliable

## Usage

### Installation

```bash
sudo pacman -U eirikr-asus-b550-config-*.pkg.tar.*
```

### Enable Services

```bash
sudo systemctl daemon-reload
sudo systemctl enable max-fans.service
sudo systemctl start max-fans.service
```

### Monitor Sensors

```bash
# Quick view
sensors | grep -A 20 NCT6798

# Detailed info
sensors -A

# Watch in real-time
watch -n 1 sensors
```

### Test Fan Control

```bash
# Check current PWM value (0-255)
cat /sys/class/hwmon/hwmon7/pwm1

# Set to maximum (if max-fans.service fails)
echo 255 | sudo tee /sys/class/hwmon/hwmon*/pwm*
```

## Troubleshooting

### hwmon7 Device Not Found

Some systems may have different hwmon numbering. Find yours:

```bash
for hwmon in /sys/class/hwmon/hwmon*; do
  echo "$(cat "$hwmon/name"): $hwmon"
done
```

Expected output:

```
coretemp: /sys/class/hwmon/hwmon0
...
nct6798: /sys/class/hwmon/hwmon7   <-- This one
```

### PWM Files Don't Exist

NCT6798D driver may need enabling:

```bash
# Check if module is loaded
lsmod | grep nct6798
# Output: nct6798 16384 0

# If missing, probe manually
sudo modprobe nct6798
```

### Sensors Daemon Not Running

```bash
# Install if needed
sudo pacman -S lm_sensors

# Configure sensors
sudo sensors-detect

# Start daemon
sudo systemctl enable --now lm_sensors

# Verify
sensors
```

### Max Fans Service Fails

Check journal for errors:

```bash
sudo journalctl -u max-fans.service -n 20
```

Common issues:

1. Udev rules not applied: run `sudo udevadm control --reload-rules`
2. Wrong hwmon path: verify with `sensors`
3. Device permissions: check with `ls -la /sys/class/hwmon/hwmon7/`

## Advanced: Manual Fan Curve Control

For fine-grained control, install `fancontrol`:

```bash
sudo pacman -S lm_sensors
sudo pwmconfig     # Interactive setup
sudo systemctl enable --now fancontrol
```

This will create `/etc/fancontrol` with custom curves.

## SATA Resume Issues

**Known Problem**: ASUS B550 sometimes fails to resume SATA drives from suspend

```
Oct 31 09:33:47 kernel: ata5: failed to resume link (SControl 0)
Oct 31 09:33:47 kernel: ata6: failed to resume link (SControl 0)
```

**Root Cause**: ACPI firmware bug in some BIOS versions

**Workarounds**:

1. Update BIOS to latest version
2. Disable "Link Power Management" in BIOS
3. Use kernel parameter: `libata.force=noncq` (disables NCQ, slower)

**Monitor Resume**:

```bash
# Check if drives resume correctly
lsblk -d   # After resume, all drives should be present

# Monitor in real-time during suspend
sudo systemctl suspend &
sleep 5
dmesg | tail -20
```

## Verification Checklist

```bash
# All should succeed without errors

# 1. Service active
sudo systemctl is-active max-fans.service
# Output: active

# 2. PWM files writeable
test -w /sys/class/hwmon/hwmon7/pwm1 && echo "OK" || echo "FAIL"
# Output: OK

# 3. Sensors detected
sensors | grep -q NCT6798 && echo "OK" || echo "FAIL"
# Output: OK

# 4. Fan speed at maximum
cat /sys/class/hwmon/hwmon7/pwm1
# Output: 255 (or close)

# 5. No dmesg errors
dmesg | grep -i "hwmon\|nct6798"
# Should show only successful probe messages
```

## Performance Impact

- **CPU**: Negligible (sensors read ~100ms every 10sec = <0.01% overhead)
- **Fan Noise**: Increased due to maximum speed
- **Temperatures**: Better cooling, lower operating temps
- **Power**: Slightly higher (~5W) due to full fan speed

## See Also

- `/etc/modprobe.d/nct6798d.conf` - Kernel module config
- `/usr/lib/systemd/system/max-fans.service` - Systemd service
- `/usr/lib/udev/rules.d/50-asus-hwmon-permissions.rules` - Udev permissions
- `man lm_sensors` - Sensor utilities
- `man fancontrol` - Advanced fan control

## License

This configuration package is licensed under the Creative Commons 0 (Public Domain).

## Support

For issues specific to ASUS B550:

- Check ASUS support site for BIOS updates
- Review lm_sensors documentation
- Consult Linux Kernel hwmon documentation

For package issues:

- File issue with configuration details
- Provide output of: `sensors`, `lsmod`, `dmesg | grep -iE "nct6798|ata"`

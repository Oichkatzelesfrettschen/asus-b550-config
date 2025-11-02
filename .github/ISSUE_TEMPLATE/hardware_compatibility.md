---
name: Hardware compatibility report
about: Report success or issues with specific hardware
title: '[HARDWARE] '
labels: hardware
assignees: ''
---

## Hardware Information

### Motherboard
- **Manufacturer**: [e.g., ASUS]
- **Model**: [e.g., ROG STRIX B550-F GAMING WIFI]
- **BIOS Version**: [e.g., 2423]
- **Chipset**: [e.g., AMD B550]

### Super I/O Chip
- **Chip Model**: [e.g., NCT6798D]
- **Chip ID**: [Run `sudo nct-id` and paste output]

### System
- **Distribution**: [e.g., Arch Linux]
- **Kernel Version**: [e.g., 6.5.0]
- **Package Version**: [e.g., 1.3.0]

## Compatibility Status
- [ ] Fully working - all features functional
- [ ] Partially working - some features functional (specify below)
- [ ] Not working - package doesn't work with this hardware

## Working Features
List which features work:
- [ ] Basic fan control (max-fans.sh)
- [ ] SmartFan IV curves
- [ ] Thermal Cruise mode
- [ ] Speed Cruise mode
- [ ] Dual-sensor blending
- [ ] Electrical mode switching
- [ ] Tachometry calibration
- [ ] Kernel debounce
- [ ] Settings persistence

## Issues Encountered
Describe any issues, limitations, or quirks with this hardware.

## Sensor Output
```
Paste output of `sensors` command here
```

## Additional Notes
Any other relevant information about this hardware configuration.

## Testing Performed
Describe what testing you performed to verify compatibility.

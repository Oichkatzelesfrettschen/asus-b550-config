# Advanced On-Chip Fan Control for NCT6798D

**Version**: 2.0 (Advanced Features)
**Date**: November 1, 2025
**Script**: `max-fans-advanced.sh`
**Kernel Documentation**: https://docs.kernel.org/6.0/hwmon/nct6775.html

---

## Executive Summary

The NCT6798D Super I/O exposes **seven distinct control modes** via sysfs:

1. **Manual PWM** (mode=1) — Fixed duty cycle
2. **Thermal Cruise** (mode=2) — Hardware-regulated temperature
3. **Speed Cruise** (mode=3) — Hardware-regulated RPM (experimental)
4. **SmartFan IV** (mode=5) — Multi-point temperature curves (standard)
5. **Dual-sensor weighting** — Blend two temperature inputs per header
6. **Electrical mode** — Switch between DC and PWM output
7. **Tachometry calibration** — Set pulses-per-rev for accurate RPM

**Key insight**: The chip has an **on-chip PWM state machine** that executes all control logic in hardware. No firmware image to patch. No userspace daemon needed. Just sysfs writes to configure the state machine.

---

## Part 1: Control Modes Deep Dive

### 1.1 Manual PWM (mode=1)

**What**: Fixed fan speed (0-255)
**When**: Quick cooling boost, passive operation
**Register(s)**: pwmX (write directly)
**Latency**: Immediate

```bash
# Set fan to 180/255 (~70%)
echo 1 | sudo tee /sys/class/hwmon/hwmon2/pwm1_enable
echo 180 | sudo tee /sys/class/hwmon/hwmon2/pwm1
```

**Decision**: No timing control; fan speed changes instantly.

---

### 1.2 Thermal Cruise (mode=2)

**What**: Hardware maintains target temperature by adjusting PWM
**When**: Constant workload, minimal temperature oscillation
**Registers**: pwmX_target_temp, pwmX_temp_tolerance, pwmX_start, pwmX_floor, pwmX_step_{up,down}_time

**How It Works**:
```
Temperature sensor reading (input):
    ↓
    [Compare to target_temp ± temp_tolerance]
    ↓
    [PWM adjustment logic]
    ↓
PWM output (to fan)
    ↓
    [Sensor re-reads after step_up_time / step_down_time]
    ↓
    [Feedback loop repeats]
```

**Example** (maintain 55°C, ±5°C):

```bash
echo 2 | sudo tee /sys/class/hwmon/hwmon2/pwm1_enable     # Enable mode 2
echo 55000 | sudo tee /sys/class/hwmon/hwmon2/pwm1_target_temp       # 55°C target
echo 5000 | sudo tee /sys/class/hwmon/hwmon2/pwm1_temp_tolerance     # ±5°C tolerance
echo 64 | sudo tee /sys/class/hwmon/hwmon2/pwm1_start                # Min 64/255
echo 32 | sudo tee /sys/class/hwmon/hwmon2/pwm1_floor                # Floor 32/255
echo 500 | sudo tee /sys/class/hwmon/hwmon2/pwm1_step_up_time        # 500ms to increase
echo 1000 | sudo tee /sys/class/hwmon/hwmon2/pwm1_step_down_time     # 1000ms to decrease
```

**Decision**: Avoids oscillation; good for quiet operation. Less responsive to transient spikes.

---

### 1.3 SmartFan IV (mode=5) — Now 7 Points!

**What**: Multi-point temperature curve; hardware transitions between points
**When**: Variable workload, good balance of responsiveness + acoustic control
**Registers**: pwmX_auto_point[1-7]_{temp,pwm}, pwmX_step_{up,down}_time, pwmX_stop_time

**Original Design (5 points)**:
- 40°C → PWM 64
- 50°C → PWM 96
- 60°C → PWM 128
- 70°C → PWM 192
- 80°C → PWM 255

**Enhanced Design (7 points, finer granularity)**:
- 40°C → PWM 64 (25%, idle)
- 50°C → PWM 96 (38%)
- 60°C → PWM 128 (50%)
- 65°C → PWM 160 (63%) **[NEW]**
- 70°C → PWM 192 (75%)
- 75°C → PWM 224 (88%) **[NEW]**
- 80°C → PWM 255 (100%, thermal safe)

**How It Works**:

```
Temperature (input):
    ↓
    [Interpolate between setpoints]
    ↓
    [Calculate required PWM]
    ↓
    [Wait step_up_time before increasing / step_down_time before decreasing]
    ↓
PWM output (smooth ramps, not jumps)
    ↓
    [Fan responds, temperature changes]
    ↓
    [Loop continues, points interpolated in real-time]
```

**Install 7-point curve with smooth ramps**:

```bash
sudo ./max-fans-advanced.sh --smartfan-7pt --timing 800 1200 3000
```

**What those timing values mean**:
- `800` ms = wait 800ms before increasing PWM (ramps up gradually)
- `1200` ms = wait 1200ms before decreasing PWM (prevents oscillation)
- `3000` ms = wait 3000ms below lowest point before stopping fan

**Decision**: 7 points is the maximum the chip supports. Timing prevents fan cycling and acoustic noise.

---

### 1.4 Speed Cruise (mode=3) — Experimental

**What**: Hardware maintains target RPM
**When**: Specialized workloads; requires accurate tachometry
**Registers**: fanX_target, fanX_tolerance

**Caveat**: Labeled "use at your own risk" in upstream docs. Only works if:
1. Tachometry is correctly calibrated (fanX_pulses set to your fan's PPR)
2. Fan RPM is accurately reported
3. Control loop is stable on your specific hardware

**Example**:

```bash
echo 3 | sudo tee /sys/class/hwmon/hwmon2/pwm1_enable
echo 3000 | sudo tee /sys/class/hwmon/hwmon2/fan1_target          # 3000 RPM target
echo 500 | sudo tee /sys/class/hwmon/hwmon2/fan1_tolerance        # ±500 RPM tolerance
```

**Decision**: Skip unless you have tested tachometry calibration working first.

---

## Part 2: Advanced Capability #1 — Dual-Sensor Weighting

**Problem**: A single temperature input doesn't capture the full thermal picture.
- CPU fans should track CPU temp, but also "look at" VRM heat
- Case fans should track both chipset and case ambient
- No userspace daemon → no polling overhead

**Solution**: Hardware blends two temperature sensors into one PWM decision.

### How It Works

```
Primary temp (e.g., CPU)
    ↓
    [Weighted blend]  ← Secondary temp (e.g., VRM) feeds in here
    ↓
    [SmartFan curve applied to blended temperature]
    ↓
PWM output
```

**Registers**:
- `pwmX_weight_temp_sel` — Choose secondary sensor (1-13)
- `pwmX_weight_temp_step` — How much secondary influences the curve
- `pwmX_weight_temp_step_base` — Base temperature for secondary influence
- `pwmX_weight_duty_step` — PWM adjustment per influence unit
- `pwmX_weight_temp_step_tol` — Tolerance for secondary

### Example: Weight PWM2 by VRM Temperature

Scenario: CPU fan (pwm2) should respond to BOTH CPU temperature (temp2) and VRM temperature (temp5).

```bash
sudo ./max-fans-advanced.sh --dual-sensor 2 --primary 2 --secondary 5
```

This:
1. Selects temp5 (VRM) as secondary input
2. Sets influence parameters so if VRM heats up, pwm2 increases even if CPU temp is stable
3. Keeps primary temp (CPU) as the dominant signal

**Decision**: On-chip blending is instantaneous. No userspace calculation. No polling lag.

---

## Part 3: Advanced Capability #2 — Electrical Mode Selection

**Problem**: Some fan headers are wired for DC output; others for PWM.
- 3-pin (legacy) fans often need DC mode
- 4-pin (PWM) fans typically need PWM mode
- Mismatch = curve appears broken (fan doesn't respond to PWM changes)

**Solution**: sysfs attribute `pwmX_mode` switches output type.

### Values

- `0` = DC mode (variable voltage, 0-12V)
- `1` = PWM mode (fixed 12V, variable duty 0-100%)

### Example: Set Header 3 to DC Mode

```bash
sudo ./max-fans-advanced.sh --electrical-mode 3 --dc
```

**Decision**: Check your motherboard manual to determine which headers support which mode. Mismatch is a common cause of "SmartFan doesn't work."

---

## Part 4: Advanced Capability #3 — Tachometry Calibration

**Problem**: RPM reporting is wrong if the driver doesn't know fan's pulses-per-rev (PPR).
- Most fans: 2 PPR (two pulses per revolution)
- High-end gaming fans: 4 PPR
- Rare: 1, 3, 5, or 8 PPR

**Impact**: If PPR is wrong:
- RPM reads 2× or 0.5× actual
- Speed Cruise doesn't work
- RPM alarms trigger incorrectly
- SmartFan IV still works but RPM feedback is junk

**Solution**: Write correct PPR to `fanX_pulses`.

### Example: Calibrate Fan 1 to 4 PPR

```bash
sudo ./max-fans-advanced.sh --tachometry 1 --pulses 4
```

**Verify**: Check `/sys/class/hwmon/hwmon2/fan1_input` before and after.
- Should now report accurate RPM

**Decision**: Check your fan spec. Default to 2; adjust if RPM seems wrong by factor of 2.

---

## Part 5: Kernel Debounce

**Problem**: Tach signal may be noisy on some headers, causing spurious RPM spikes.

**Solution**: Enable `fan_debounce` module parameter.

### Persistent (Recommended)

```bash
echo "options nct6775 fan_debounce=1" | sudo tee /etc/modprobe.d/nct6775.conf
# Reload: sudo modprobe -r nct6775 && sudo modprobe nct6775
```

### Runtime Toggle (Temporary)

```bash
sudo ./max-fans-advanced.sh --debounce-enable
```

**Decision**: Enable if you see RPM jitter. Minimal performance impact.

---

## Part 6: Persistence Across Boot/Resume

**Problem**: Firmware/BIOS may reset hwmon settings on boot or resume.

**Solution**: systemd service + timer automatically reapply configuration.

### How to Enable

1. Create `/usr/local/etc/max-fans-restore.conf`:

```bash
#!/bin/bash
# Restore script executed after boot and resume

# 7-point SmartFan IV with smooth ramps
/usr/lib/eirikr/max-fans-advanced.sh --smartfan-7pt --timing 800 1200 3000

# Dual-sensor weighting on pwm2 (CPU + VRM)
/usr/lib/eirikr/max-fans-advanced.sh --dual-sensor 2 --primary 2 --secondary 5

# Electrical mode for 3-pin header
/usr/lib/eirikr/max-fans-advanced.sh --electrical-mode 3 --dc

# Tachometry calibration
/usr/lib/eirikr/max-fans-advanced.sh --tachometry 1 --pulses 4

# Kernel debounce
/usr/lib/eirikr/max-fans-advanced.sh --debounce-enable
```

2. Enable the systemd service:

```bash
sudo systemctl enable max-fans-restore.timer
sudo systemctl start max-fans-restore.timer
```

3. Verify:

```bash
systemctl status max-fans-restore.timer
journalctl -u max-fans-restore.service
```

**Decision**: Persistence ensures settings survive firmware resets and power transitions.

---

## Part 7: Full Workflow Example

Scenario: Gaming workstation with custom thermal control.

**Goals**:
1. Aggressive CPU cooling (7-point curve, tight tolerance)
2. VRM fan responds to both chipset and VRM temp
3. Case fans run in Thermal Cruise (quiet when idle)
4. All settings survive reboot

**Implementation**:

```bash
# 1. Install 7-point SmartFan IV with aggressive ramps
sudo /usr/lib/eirikr/max-fans-advanced.sh --smartfan-7pt --timing 500 1000 2000

# 2. Blend CPU (temp2) + VRM (temp5) on pwm2
sudo /usr/lib/eirikr/max-fans-advanced.sh --dual-sensor 2 --primary 2 --secondary 5

# 3. Thermal Cruise on case fans (pwm4, quiet unless temp rises)
sudo /usr/lib/eirikr/max-fans-advanced.sh --thermal-cruise 4 --target 50000 --tolerance 5000

# 4. Verify all settings
sudo /usr/lib/eirikr/max-fans-advanced.sh --verify

# 5. Make persistent
cat > /usr/local/etc/max-fans-restore.conf << 'EOF'
#!/bin/bash
/usr/lib/eirikr/max-fans-advanced.sh --smartfan-7pt --timing 500 1000 2000
/usr/lib/eirikr/max-fans-advanced.sh --dual-sensor 2 --primary 2 --secondary 5
/usr/lib/eirikr/max-fans-advanced.sh --thermal-cruise 4 --target 50000 --tolerance 5000
EOF
chmod +x /usr/local/etc/max-fans-restore.conf

# 6. Enable automatic restore
sudo systemctl enable max-fans-restore.timer
```

---

## Part 8: Kernel Access Paths (FYI)

The `nct6775` driver automatically selects the best access path:

1. **Direct ISA I/O** (port 0x0290) — If ACPI doesn't reserve the range
2. **ASUS WMI** (RSIO/WSIO/RHWM/WHWM) — If ACPI blocks ISA access

You don't need to do anything; the kernel handles it. This is why we use sysfs instead of poking registers directly—the kernel maintains the arbitration.

---

## Part 9: Troubleshooting

### Issue: "Permission denied" writing to sysfs

**Cause**: User is not root or doesn't have proper udev permissions

**Fix**: Use `sudo`, or ensure udev rules are installed:

```bash
pacman -Q eirikr-asus-b550-config
# Should include /usr/lib/udev/rules.d/50-asus-hwmon-permissions.rules
```

### Issue: SmartFan IV enabled but fans don't respond to temperature

**Common causes**:
1. **Electrical mode mismatch** — Check `pwmX_mode` (0=DC, 1=PWM) vs header type
2. **Wrong temperature sensor** — Verify `pwmX_temp_sel` points to live sensor
3. **Firmware reset** — Settings lost on boot (enable persistence layer)
4. **ACPI conflict** — Kernel reverted to WMI; same control, just different path

**Diagnose**:

```bash
sudo /usr/lib/eirikr/max-fans-advanced.sh --verify
```

### Issue: RPM reads wrong, Speed Cruise doesn't work

**Cause**: Incorrect tachometry (fanX_pulses)

**Fix**: Determine your fan's PPR from spec, then:

```bash
sudo /usr/lib/eirikr/max-fans-advanced.sh --tachometry 1 --pulses 4
```

### Issue: Thermal Cruise oscillates (fan speed jumps up/down)

**Cause**: Tolerance too tight, or step timing too short

**Fix**: Increase tolerance and timing:

```bash
# Instead of 55°C ±2°C, try ±5°C
sudo /usr/lib/eirikr/max-fans-advanced.sh --thermal-cruise 1 \
  --target 55000 --tolerance 5000
```

---

## Part 10: Reference Table — Control Modes at a Glance

| Mode | Name | Best For | Responsive | Quiet | Complex |
|------|------|----------|-----------|-------|---------|
| 1 | Manual PWM | Boost, testing | Instant | No | No |
| 2 | Thermal Cruise | Constant load | Medium | Yes | Low |
| 3 | Speed Cruise | RPM target | Medium | Maybe | Medium |
| 5 | SmartFan IV | Variable load | Good | Good | Medium |

---

## Part 11: Decision Matrix — Which Mode to Use?

```
Are you gaming?
├─ Yes → SmartFan IV (mode 5) with 7 points
└─ No → Thermal Cruise (mode 2) if workload is steady

Do you want minimal fan noise?
├─ Yes → Thermal Cruise (mode 2) or SmartFan IV with long step times
└─ No → SmartFan IV with short step times

Do you have a high-end fan with 4 PPR?
├─ Yes → Calibrate tachometry, can enable Speed Cruise (mode 3)
└─ No → Use 2 PPR (default), stick with modes 2 or 5

Do you need dual-sensor blending (CPU + VRM)?
├─ Yes → Enable weighting on that PWM
└─ No → Single temp per fan is fine

---

## Conclusion

With `max-fans-advanced.sh` and systemd persistence, you've accessed essentially **all** of the NCT6798D's on-chip control logic:

✓ 7-point curves (max granularity)
✓ Dual-sensor blending (no daemon)
✓ Thermal and Speed Cruise modes
✓ Electrical mode switching
✓ Tachometry calibration
✓ Kernel debounce
✓ Automatic persistence

The **next frontier** is mapping your board's actual sensor wiring:
- Which `tempN` is CPU (PECI)?
- Which is VRM?
- Which is chipset or case ambient?

You can then tailor weighting to maximize cooling precision without noise.

Reference your motherboard manual or run:

```bash
sudo /usr/lib/eirikr/max-fans-advanced.sh --verify
```

to see all available sensors.

---

**Document Version**: 2.0
**Last Updated**: November 1, 2025
**References**: [1] https://docs.kernel.org/6.0/hwmon/nct6775.html

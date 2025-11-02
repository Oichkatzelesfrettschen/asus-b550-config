# NCT6798D Programmer's Guide: Close-to-Metal Fan Control on ASUS B550

**Document Version**: 1.0
**Date**: November 1, 2025
**Target Hardware**: ASUS B550 motherboards with Nuvoton NCT6798D Super I/O
**Linux Kernel**: 5.0+ (tested on 6.x via CachyOS)
**Focus**: Understanding the register model, access paths, and how the kernel driver works

---

## Executive Summary

**Thesis**: The NCT6798D has no publicly available datasheet, but **is fully programmable on Linux** through well-supported kernel drivers and register access methods.

**Response**:

1. ✓ **No official NCT6798D datasheet** — vendors do not publish it freely.
2. ✓ **Reverse-mapped register model** — derived from adjacent Nuvoton parts (NCT6791, NCT6796D) and Linux driver code.
3. ✓ **Full Linux support** — kernel `nct6775` driver supports chip ID `0xD428` (NCT6798D) natively.
4. ✓ **Multiple access paths**:
   - Primary: **Kernel hwmon driver** (sysfs interface) — recommended, handles ACPI conflicts
   - Secondary: **ASUS WMI** (RSIO/WSIO methods) — used by kernel when ISA I/O blocked
   - Diagnostic: **Raw Super I/O access** (0x2E/0x4E ports) — for verification only

**Bottom Line**: You **can** program the NCT6798D "close to metal" on Linux. The safest path is the kernel driver + sysfs, which automatically handles firmware arbitration.

---

## Part 1: Super I/O Architecture & Register Model

### 1.1 The Nuvoton Super I/O Chip

The **NCT6798D** is a **Nuvoton Super I/O** chip — a multi-function device that provides:

- **Hardware Monitoring (HWM)**: Temperature sensors, voltage monitors, fan speed readers
- **PWM Engines**: 6 PWM outputs (0–255) for fan control
- **GPIO**: General-purpose I/O (not used for fan control)
- **ACPI EC**: Embedded Controller interface (telemetry path)

On ASUS B550 boards, the NCT6798D is soldered on the motherboard and connected to both:

- The **ISA I/O bus** (legacy x86 16-bit port I/O at 0x2E/0x4E, 0x290–0x29F)
- The **ACPI Embedded Controller** (for vendor-specific extended telemetry)

### 1.2 Super I/O Access Protocol

All Nuvoton Super I/O chips use a **two-port indexed access model**:

```
Index Port (0x2E or 0x4E):   selector for which register to access
Data Port  (0x2F or 0x4F):   read/write the selected register's value
```

**Entry / Exit Sequence**:

```c
// Enter Extended Function Mode (unlock CR access)
outb(0x2E, 0x87);   // write 0x87 to index port
outb(0x2E, 0x87);   // write 0x87 again (magic sequence)

// Now you can read/write CRs (configuration registers)

// Exit Extended Function Mode (lock, restore normal behavior)
outb(0x2E, 0xAA);   // write 0xAA to index port
```

**Read / Write Registers**:

```c
// Read a configuration register (CR)
outb(0x2E, 0x20);        // Index: select CR 0x20 (chip ID high byte)
unsigned char value = inb(0x2F);  // Data: read the value

// Write a configuration register (CR)
outb(0x2E, 0x07);        // Index: select CR 0x07 (logical device selector)
outb(0x2F, 0x0B);        // Data: write 0x0B (Hardware Monitor logical device)
```

### 1.3 Chip Identification (CR 0x20 / 0x21)

Configuration registers **0x20** and **0x21** contain the **chip ID**:

| Register | Meaning | NCT6798D Value |
|----------|---------|-----------------|
| CR 0x20 | Chip ID (high byte) | 0xD4 |
| CR 0x21 | Chip ID (low byte) | 0x28 |
| Combined | Chip ID | **0xD428** |

The Linux kernel driver tables explicitly list:

```c
// From drivers/hwmon/nct6775.c
static const struct nct6775_data nct6798_sio_data = {
    .chip_id = 0xd428,      // Match value for this chip
    .name = "nct6798",
    ...
};
```

**Action**: Running the `nct-id` utility confirms the chip ID is `0xD428`, matching the driver's expectation.

### 1.4 Logical Devices & HWM Base Address

Inside the Super I/O, different subsystems are **logical devices**. Each has its own configuration registers. To access HWM (Hardware Monitor), you must:

1. **Select logical device 0x0B** (the HWM block)

   ```c
   outb(0x2E, 0x07);     // CR 0x07 = device selector
   outb(0x2F, 0x0B);     // Select HWM (device 0x0B)
   ```

2. **Read HWM base address** from CR 0x60/0x61 (where HWM's index/data ports are)

   ```c
   outb(0x2E, 0x60);     // CR 0x60 = HWM base address (high byte)
   unsigned char base_hi = inb(0x2F);
   outb(0x2E, 0x61);     // CR 0x61 = HWM base address (low byte)
   unsigned char base_lo = inb(0x2F);
   unsigned short hwm_base = (base_hi << 8) | base_lo;  // typically 0x0290
   ```

3. **Use HWM base + offsets** to access temperature and PWM registers

   ```c
   // With HWM base = 0x0290:
   //   0x0290 = HWM index port
   //   0x0291 = HWM data port
   //   0x0295 = HWM index (alternative offset, used by Linux nct6775)
   //   0x0296 = HWM data   (alternative offset)
   ```

### 1.5 HWM Register Mapping (Hardware Monitor Registers)

Inside the HWM block, registers are accessed via another **indexed model**:

```
HWM Index Port (base + 0):  Select which HWM register
HWM Data Port  (base + 1):  Read/write that register
```

But the **Linux driver uses different offsets**:

```
HWM Index Port (base + 5):  0x0290 + 5 = 0x0295
HWM Data Port  (base + 6):  0x0290 + 6 = 0x0296
```

**Key HWM Register Ranges** (undocumented, reverse-mapped from 6796D):

| Range | Purpose | Access |
|-------|---------|--------|
| 0x00–0x40 | Temperature sensors (CPUTIN, SYSTIN, etc.) | Read-only |
| 0x40–0x60 | Fan speed inputs (fan RPM) | Read-only |
| 0x80–0xCF | PWM and SmartFan configuration | Read/Write |

### 1.6 PWM & SmartFan IV Registers (0x80–0xCF Range)

The NCT6798D has **6 PWM outputs** (PWM1–PWM6) and **Smart Fan IV** control.

**SmartFan IV** is a hardware-native feature:

- You define **temperature setpoints** (5 points per PWM channel)
- For each setpoint, you specify a target **PWM duty cycle**
- The hardware automatically adjusts PWM based on real-time temperature
- **No polling needed** — hardware responds in microseconds

**Register Layout** (per PWM, relative to HWM base):

| Offset | Register | Purpose | Access |
|--------|----------|---------|--------|
| +0x30 | PWM1_value | PWM1 duty cycle (0–255) | R/W |
| +0x33 | PWM1_enable | 1=manual, 5=SmartFan IV | R/W |
| +0x34–0x3D | PWM1_auto_point_*_temp | 5 temperature thresholds | R/W |
| +0x3E–0x47 | PWM1_auto_point_*_pwm | 5 PWM values | R/W |

Similar offsets for PWM2–PWM6 (incremented by 0x10 each).

**Why this is important**:

- Kernel driver abstracts these offsets into sysfs paths
- You don't need to calculate offsets manually
- sysfs is portable across distros and kernel versions

---

## Part 2: Linux Kernel Access Paths

### 2.1 Primary Path: Kernel `nct6775` Driver + sysfs

**Why this is the recommended path**:

1. **ACPI-aware**: Kernel driver detects when ACPI owns ISA I/O ports
2. **WMI fallback**: Automatically uses ASUS WMI (RSIO/WSIO) methods if ISA blocked
3. **Locking**: Kernel handles arbitration between firmware and drivers
4. **Portability**: Works across all ASUS B550 boards

**How it works**:

```bash
# 1. Load the driver (auto-probed on boot, but you can force reload)
sudo modprobe nct6775

# 2. Check which access path was used
dmesg | grep -i "nct6775\|wmi\|resource"

# Output examples:
#   "nct6775: Using Asus WMI to access 0xc1 chip"  <- WMI path (modern)
#   "nct6775: Found NCT6798D at 0x2e"               <- ISA I/O path (legacy)
```

**Kernel driver source code** (`drivers/hwmon/nct6775-platform.c`):

```c
// Pseudo-code showing WMI fallback logic
if (acpi_resource_conflict(ISA_IO_0x2E)) {
    // ACPI owns the ports; use WMI instead
    use_asus_wmi_methods();  // RSIO (read), WSIO (write), RHWM, WHWM
} else {
    // ISA ports available; use direct I/O
    use_direct_isa_access();  // outb/inb to 0x2E/0x2F
}
```

### 2.2 ASUS WMI Access (RSIO / WSIO / RHWM / WHWM)

When the kernel driver detects ISA I/O ports are locked by ACPI, it uses **ASUS WMI methods** to communicate with the chip.

**ASUS WMI method signatures** (ACPI/UEFI-defined):

| Method | Purpose | Parameters |
|--------|---------|------------|
| RSIO | **R**ead **S**uper **I**/**O** register | Input: register#; Output: value |
| WSIO | **W**rite **S**uper **I**/**O** register | Input: register#, value |
| RHWM | **R**ead **H**ardware **M**onitor register | Input: offset; Output: value |
| WHWM | **W**rite **H**ardware **M**onitor register | Input: offset, value |

**From kernel source** (`drivers/hwmon/nct6775-platform.c`):

```c
// Sample WMI method invocation
static int asus_wmi_read_register(u16 reg, u8 *value) {
    return asus_wmi_call_method("RSIO", reg, value);
}

// The kernel handles this transparently; userspace just sees sysfs
```

**Why WMI is important**:

- Avoids firmware conflict
- Transparently escalates from kernel-space (through BIOS ACPI methods)
- Security: firmware retains control; hardware protections not bypassed
- Supports advanced features (e.g., BIOS fan profiles)

### 2.3 sysfs Interface (Recommended for Userspace Control)

Once the kernel driver loads, you interact via **sysfs** (no direct port I/O needed):

```bash
# Find the NCT6798D hwmon device
ls /sys/class/hwmon/hwmon*/name | xargs grep -l nct6798

# Example output: /sys/class/hwmon/hwmon4/name (contains "nct6798d")

# Read temperature (in millidegrees C)
cat /sys/class/hwmon/hwmon4/temp1_input   # e.g., 45000 = 45°C

# Read/write PWM (0–255)
cat /sys/class/hwmon/hwmon4/pwm1          # e.g., 255 (max speed)
echo 180 | sudo tee /sys/class/hwmon/hwmon4/pwm1  # Set to ~70%

# Set PWM mode: 1=manual, 5=SmartFan IV
echo 1 | sudo tee /sys/class/hwmon/hwmon4/pwm1_enable

# Configure SmartFan IV setpoint (example: 60°C threshold, PWM=128)
echo 60000 | sudo tee /sys/class/hwmon/hwmon4/pwm1_auto_point3_temp
echo 128   | sudo tee /sys/class/hwmon/hwmon4/pwm1_auto_point3_pwm

# Enable SmartFan IV mode
echo 5 | sudo tee /sys/class/hwmon/hwmon4/pwm1_enable
```

**Kernel documentation**:
[`Documentation/hwmon/nct6775.rst`](https://www.kernel.org/doc/html/latest/hwmon/nct6775.html)

This document lists all sysfs attributes, their meanings, and valid ranges.

---

## Part 3: SmartFan IV Curve Programming

### 3.1 What is SmartFan IV?

**SmartFan IV** is a hardware feature built into the NCT6798D that automatically adjusts PWM based on temperature.

**Benefits**:

- **Responsive**: Hardware adjusts in microseconds (no userspace polling overhead)
- **Quiet**: Ramp gradually; avoid acoustic resonance peaks
- **Safe**: Temperature thresholds embedded in hardware (firmware can't override)
- **Configurable**: You define the temperature curve (5 setpoints per PWM)

### 3.2 Curve Definition: Temperature Setpoints

You define **5 setpoints** for each PWM channel. Each setpoint specifies:

- **Temperature threshold** (in millidegrees C)
- **Target PWM value** (0–255)

**Example conservative curve** (from `max-fans-enhanced.sh`):

```bash
SMARTFAN_TEMPS=(
    40000   # 40°C -> PWM  64 (gentle startup)
    50000   # 50°C -> PWM  96
    60000   # 60°C -> PWM 128 (medium)
    70000   # 70°C -> PWM 192 (aggressive)
    80000   # 80°C -> PWM 255 (max)
)
```

**Why these values**:

- **40°C threshold**: Most systems idle at 35–40°C. Start ramping here.
- **Gentle slope (40–60°C)**: System can stay quiet at low load
- **Aggressive ramp (60–80°C)**: Rapid fan increase as temperature climbs
- **Max at 80°C**: Thermally safe ceiling for most CPUs

### 3.3 Installing the Curve via sysfs

```bash
HWMON="/sys/class/hwmon/hwmon4"  # Replace with your device

# Set SmartFan IV for PWM1
# First, configure the 5 setpoints

# Point 1: 40°C -> PWM 64
echo 40000 | sudo tee $HWMON/pwm1_auto_point1_temp
echo 64    | sudo tee $HWMON/pwm1_auto_point1_pwm

# Point 2: 50°C -> PWM 96
echo 50000 | sudo tee $HWMON/pwm1_auto_point2_temp
echo 96    | sudo tee $HWMON/pwm1_auto_point2_pwm

# Point 3: 60°C -> PWM 128
echo 60000 | sudo tee $HWMON/pwm1_auto_point3_temp
echo 128   | sudo tee $HWMON/pwm1_auto_point3_pwm

# Point 4: 70°C -> PWM 192
echo 70000 | sudo tee $HWMON/pwm1_auto_point4_temp
echo 192   | sudo tee $HWMON/pwm1_auto_point4_pwm

# Point 5: 80°C -> PWM 255
echo 80000 | sudo tee $HWMON/pwm1_auto_point5_temp
echo 255   | sudo tee $HWMON/pwm1_auto_point5_pwm

# Finally, enable SmartFan IV mode (5)
echo 5 | sudo tee $HWMON/pwm1_enable

# Verify (should show "5")
cat $HWMON/pwm1_enable
```

### 3.4 Monitoring the Curve in Action

```bash
# Watch temperature and PWM adjustment in real-time
watch -n 1 'cat /sys/class/hwmon/hwmon4/temp1_input /sys/class/hwmon/hwmon4/pwm1'

# Output examples:
# 45000   (45°C)  -> PWM should jump to ~64
# 58000   (58°C)  -> PWM should interpolate between 64 and 96
# 72000   (72°C)  -> PWM should be near 192
# 85000   (85°C)  -> PWM should be 255 (max)
```

### 3.5 Decision: Temperature Sensor Source

**Which temperature sensor to use for SmartFan IV?**

Options:

1. **CPUTIN** (CPU package temp via PECI) — **RECOMMENDED**
   - Direct CPU temperature
   - Fastest response
   - Reliable on all ASUS boards

2. **SYSTIN** (system temperature via LM75 sensor) — Use if CPUTIN unavailable
   - Slower response
   - Less direct

3. **TSI** (Ryzen Threadripper, if applicable) — For high-end systems
   - Direct chiplet temperature

**Decision rationale**: Use CPUTIN for typical Ryzen 5000 CPUs. Check available sensors:

```bash
sensors | grep -E "CPUTIN|SYSTIN|TSI|Core"
```

---

## Part 4: Verification & Diagnostics

### 4.1 Verify Chip Presence

**Using the `nct-id` utility** (ground-truth Super I/O probe):

```bash
sudo /usr/lib/eirikr/nct-id
# Output:
#   SIO at 0x2E: DEVID=0xD428  HWM base=0x0290 (index/data @ base+5/base+6)
#
# Interpretation:
#   DEVID 0xD428 = NCT6798D (matches kernel driver tables)
#   HWM base 0x0290 = firmware configuration
#   index/data offset standard = hardcoded by Nuvoton
```

**What this tells you**:

- Chip is physically present and accessible
- Firmware hasn't disabled the Super I/O
- Kernel driver will find it automatically

### 4.2 Check Kernel Driver Status

```bash
# Is the driver loaded?
lsmod | grep nct6775
# Output: nct6775_platform, nct6775

# Check which access path was used
dmesg | grep -iE "nct6775|using|wmi|asus|resource"

# Example outputs:
#   "nct6775: Using Asus WMI to access 0xc1 chip"  <- WMI path
#   "nct6775: Found NCT6798D at 0x2e:0x290"         <- ISA path
#   "resource 0x2e-0x2f: conflicts with ACPI"      <- ACPI conflict (but WMI handles it)
```

### 4.3 Verify sysfs Device Presence

```bash
# Find hwmon device for NCT6798D
for dir in /sys/class/hwmon/hwmon*; do
  if grep -q nct6798 $dir/name 2>/dev/null; then
    echo "Found: $dir"
    cat $dir/name      # Should be "nct6798d"
    ls $dir/pwm*       # Should list pwm1, pwm2, etc.
    ls $dir/temp*      # Should list temp1, temp2, etc.
  fi
done
```

### 4.4 Test PWM Write Access

```bash
HWMON="/sys/class/hwmon/hwmon4"  # Replace with your device

# Set PWM1 to manual mode (enable=1)
echo 1 | sudo tee $HWMON/pwm1_enable

# Try to set PWM to 180 (~70%)
echo 180 | sudo tee $HWMON/pwm1

# Verify it was set
cat $HWMON/pwm1
# Should output: 180
```

If this fails:

- Permission denied: Run as root (`sudo`)
- Input/output error: Driver not loaded (`sudo modprobe nct6775`)
- File not found: Wrong hwmon device path (check `ls /sys/class/hwmon/`)

---

## Part 5: Known Issues & Workarounds

### 5.1 ACPI Resource Conflicts

**Symptom**: Kernel log shows `"resource 0x2e-0x2f: conflicts with ACPI"`

**Root cause**: ASUS BIOS declares ISA I/O ports as owned by firmware

**Modern kernels (5.9+)**: Handled automatically via ASUS WMI

- No action needed
- Driver transparently uses RSIO/WSIO methods
- sysfs interface works normally

**Older kernels (< 5.9)**: May require workaround

```bash
# Boot parameter workaround (not recommended; security risk)
acpi_enforce_resources=lax

# Add to /etc/default/grub:
GRUB_CMDLINE_LINUX="acpi_enforce_resources=lax"
sudo update-grub && sudo reboot
```

**Better solution**: Upgrade kernel (CachyOS ships 6.x by default)

### 5.2 Temperature Sensor Unreliability

**Issue**: Some sensors (e.g., CPUTIN) report bogus values on ASUS boards

**Workaround**: Cross-reference multiple sensors

```bash
# List all temperature sensors and their readings
sensors | grep -E "Core|CPUTIN|SYSTIN|Package"

# If CPUTIN reads 0°C or 127°C (out of range), use SYSTIN or TSI instead
```

### 5.3 EC vs Super I/O Confusion

**EC sensors** (via `asus_ec_sensors` driver):

- **Read-only** (telemetry: VRM voltage, current draw)
- Do NOT provide PWM control
- Different driver (`asus_ec_sensors`, not `nct6775`)

**Super I/O sensors** (via `nct6775` driver):

- **Read/write** (temperature, PWM, SmartFan IV control)
- This is what you use for fan control

**Decision**: Use `nct6775` for fan control, `asus_ec_sensors` only for advanced telemetry.

---

## Part 6: Practical Examples

### 6.1 Simple: Set All Fans to Maximum

```bash
# One-liner
sudo /usr/lib/eirikr/max-fans-enhanced.sh --manual 255
```

**What happens**:

1. Script finds NCT6798D hwmon device
2. Sets `pwm1_enable = 1` (manual mode) for each PWM
3. Writes `255` to each `pwmN` register
4. Fans spin at full speed immediately

### 6.2 Intermediate: Install SmartFan IV Curve

```bash
# Temperature-based control
sudo /usr/lib/eirikr/max-fans-enhanced.sh --smartfan
```

**What happens**:

1. Script finds NCT6798D hwmon device
2. Writes 5 temperature setpoints and corresponding PWM values
3. Sets `pwm1_enable = 5` (SmartFan IV mode)
4. Hardware automatically adjusts PWM based on temperature
5. System boots quiet, ramps up under load

### 6.3 Advanced: Custom Curve Script

Create `/tmp/custom-smartfan.sh`:

```bash
#!/bin/bash
HWMON="/sys/class/hwmon/hwmon4"

# Aggressive curve: rapid ramp at low temps (for gaming)
declare -a TEMPS=(30000 40000 50000 60000 70000)
declare -a PWMS=(100 150 200 240 255)

for i in {1..6}; do
  echo "Configuring PWM$i..."
  for j in {1..5}; do
    echo ${TEMPS[$((j-1))]} | sudo tee $HWMON/pwm${i}_auto_point${j}_temp > /dev/null
    echo ${PWMS[$((j-1))]} | sudo tee $HWMON/pwm${i}_auto_point${j}_pwm > /dev/null
  done
  echo 5 | sudo tee $HWMON/pwm${i}_enable > /dev/null
done

echo "Custom SmartFan IV curve installed"
```

```bash
chmod +x /tmp/custom-smartfan.sh
sudo /tmp/custom-smartfan.sh
```

### 6.4 Verification: Check Live Curve Adjustment

```bash
watch -n 1 '
  echo "Temperature:"; cat /sys/class/hwmon/hwmon4/temp1_input
  echo "PWM1 (target):"; cat /sys/class/hwmon/hwmon4/pwm1
  echo "Fan1 (RPM):"; cat /sys/class/hwmon/hwmon4/fan1_input
'
```

Stress test the CPU and observe real-time PWM adjustment:

```bash
# In terminal 1: watch curve
watch -n 1 'cat /sys/class/hwmon/hwmon4/temp1_input /sys/class/hwmon/hwmon4/pwm1'

# In terminal 2: stress test
stress --cpu 6 --timeout 60s
```

You should see:

- Temp rising from ~45°C to 80°C
- PWM following curve: 64 → 96 → 128 → 192 → 255
- Fan RPM increasing in real-time

---

## Part 7: Kernel Source References

If you want to understand the implementation details, these kernel files are canonical:

1. **Driver core**: `drivers/hwmon/nct6775.c`
   - Chip ID tables (line ~200)
   - Register definitions (line ~500)
   - SmartFan IV setpoint access (line ~1500)

2. **Platform driver**: `drivers/hwmon/nct6775-platform.c`
   - ASUS WMI method invocations
   - ACPI resource conflict handling
   - Device probing logic

3. **Kernel documentation**: `Documentation/hwmon/nct6775.rst`
   - sysfs attribute reference
   - Temperature sensor explanations
   - SmartFan IV configuration guide

**Build your own kernel module** (advanced):

```bash
# If you want to implement custom logic, study drivers/hwmon/nct6775.c
# The module is well-commented and self-contained
# For most use cases, userspace sysfs control is sufficient
```

---

## Part 8: Decision Matrix: When to Use Which Tool

| Use Case | Tool | Why |
|----------|------|-----|
| Quick temp check | `sensors` / sysfs | Simple, standard |
| Manual max speed | `max-fans-enhanced.sh --manual` | One-liner |
| Temperature curves | `max-fans-enhanced.sh --smartfan` | Hardware-native, responsive |
| Custom scripting | Direct sysfs echo/cat | Portable, composable |
| System verification | `/usr/lib/eirikr/nct-id` | Ground-truth chip probe |
| Kernel troubleshooting | `dmesg`, `lsmod`, sysfs attrs | Diagnostic, detailed |
| Advanced telemetry | `asus_ec_sensors` driver | VRM current, voltage (if needed) |

---

## Summary: The Path Forward

1. **Verify your chip**: `sudo /usr/lib/eirikr/nct-id`
   - Confirms NCT6798D is present and accessible
   - Reports HWM base address (validates firmware configuration)

2. **Load the driver**: `sudo modprobe nct6775`
   - Kernel automatically detects ISA vs WMI access path
   - Populates `/sys/class/hwmon/` with device

3. **Control fans**:
   - **Simple**: `sudo /usr/lib/eirikr/max-fans-enhanced.sh --manual 255`
   - **Smart**: `sudo /usr/lib/eirikr/max-fans-enhanced.sh --smartfan`

4. **Monitor in real-time**:
   - Watch temperature, PWM, RPM with `watch` / `sensors`
   - Verify curve is responding as expected

5. **Integrate into systemd**:
   - `/etc/systemd/system/max-fans.service` runs at boot
   - Can run either `--manual` or `--smartfan` mode

**Your thesis was half-right**: No public datasheet, but **fully programmable via Linux kernel + sysfs**. This is the "close to metal" access you wanted—direct to the hardware, without custom kernel code.

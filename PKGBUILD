pkgname=eirikr-asus-b550-config
pkgver=1.3.0
pkgrel=1
pkgdesc="ASUS B550 motherboard tuning: maximal on-chip NCT6798D fan control (7-point curves, thermal cruise, dual-sensor blending, electrical mode, tachometry)"
arch=('x86_64')
url="https://github.com/oaich/asus-b550-config"
license=('GPL3')
depends=('systemd' 'lm_sensors')
makedepends=('gcc')
optdepends=(
  'nct6798d-hwmon: hwmon driver for ASUS NCT6798D'
  'linux-headers: for kernel source reference'
)

# DECISION: Include three levels of fan control + persistence + comprehensive docs
# WHY: Backward compatibility (max-fans.sh) + standard features (max-fans-enhanced.sh)
#      + maximal on-chip capabilities (max-fans-advanced.sh) + nct-id diagnostic
#      + systemd persistence (max-fans-restore.service/timer)
source=(
  '50-asus-hwmon-permissions.rules'
  '90-asus-sata.rules'
  'max-fans.service'
  'max-fans-restore.service'
  'max-fans-restore.timer'
  'max-fans.sh'
  'max-fans-enhanced.sh'
  'max-fans-advanced.sh'
  'modprobe-nct6798d.conf'
  'ASUS-B550-TUNING.md'
  'NCT6798D-PROGRAMMER-GUIDE.md'
  'NCT6798D-ADVANCED-CONTROLS.md'
  'nct-id.c'
)

sha256sums=(
  'SKIP'
  'SKIP'
  'SKIP'
  'SKIP'
  'SKIP'
  'SKIP'
  'SKIP'
  'SKIP'
  'SKIP'
  'SKIP'
  'SKIP'
  'SKIP'
  'SKIP'
)

install='eirikr-asus-b550-config.install'

prepare() {
  # Ensure shell scripts are executable
  # WHY: makepkg doesn't automatically detect executable intent from source files
  # HOW: chmod +x marks scripts for sysfs shell execution
  chmod +x "${srcdir}/max-fans.sh"
  chmod +x "${srcdir}/max-fans-enhanced.sh"
  chmod +x "${srcdir}/max-fans-advanced.sh"
}

build() {
  # PURPOSE: Compile nct-id.c (Super I/O chip verification utility)
  # WHAT: Build C23 program that reads NCT6798D chip ID and HWM base address
  # WHY: Provides ground-truth verification independent of kernel driver
  # HOW: gcc with C23 standard, all warnings treated as errors
  # DECISION: C23 (not C99) for modern inline semantics and reduced macro boilerplate

  gcc -std=c23 -O2 -Wall -Wextra -Werror \
      -o "${srcdir}/nct-id" \
      "${srcdir}/nct-id.c"
}

package() {
  # PURPOSE: Install compiled binaries, scripts, config, and documentation
  # STRATEGY: Organize by destination type (udev, systemd, scripts, docs)
  # WHY separate comments: Document the purpose/rationale for each file

  # ============================================================================
  # UDEV RULES - Device permission configuration
  # ============================================================================
  # WHY: Grant user access to hwmon sysfs (PWM, temperature) without sudo
  # HOW: Mode 0664 = group-readable/writable (users in 'input' group)
  install -Dm644 "${srcdir}/50-asus-hwmon-permissions.rules" \
    "${pkgdir}/usr/lib/udev/rules.d/50-asus-hwmon-permissions.rules"

  # SATA device-specific rules for ASUS B550 SATA controllers
  # WHY: Prevent resume failures and link power management issues
  install -Dm644 "${srcdir}/90-asus-sata.rules" \
    "${pkgdir}/usr/lib/udev/rules.d/90-asus-sata.rules"

  # ============================================================================
  # SYSTEMD CONFIGURATION
  # ============================================================================
  # Service unit: runs max-fans.sh at boot (or manually via systemctl)
  install -Dm644 "${srcdir}/max-fans.service" \
    "${pkgdir}/usr/lib/systemd/system/max-fans.service"

  # Persistence service: reapplies advanced sysfs settings after boot/resume
  # WHY: Firmware/BIOS may reset hwmon settings on transitions
  # HOW: systemd service + timer automatically run /usr/local/etc/max-fans-restore.conf
  # DECISION: Persistence ensures custom settings survive power events
  install -Dm644 "${srcdir}/max-fans-restore.service" \
    "${pkgdir}/usr/lib/systemd/system/max-fans-restore.service"

  # Timer for persistence service: runs on boot and periodically
  # WHY: Ensures settings reapplied after suspend/resume, not just once
  install -Dm644 "${srcdir}/max-fans-restore.timer" \
    "${pkgdir}/usr/lib/systemd/system/max-fans-restore.timer"

  # ============================================================================
  # EXECUTABLE SCRIPTS - Fan control and verification tools
  # ============================================================================
  # Original max-fans.sh: simple, backward-compatible (sets all fans to max)
  # WHY keep: systemd unit references this; don't break existing configs
  install -Dm755 "${srcdir}/max-fans.sh" \
    "${pkgdir}/usr/lib/eirikr/max-fans.sh"

  # Enhanced max-fans-enhanced.sh: SmartFan IV curves, verification, flexibility
  # WHY new: Provides --smartfan, --verify, --manual flags for advanced control
  # WHY separate: Allows users to choose simple or advanced mode
  install -Dm755 "${srcdir}/max-fans-enhanced.sh" \
    "${pkgdir}/usr/lib/eirikr/max-fans-enhanced.sh"

  # Advanced max-fans-advanced.sh: Maximal on-chip control (7-point curves, thermal cruise, dual-sensor, electrical mode, tachometry)
  # WHAT: Expose full NCT6798D hardware capabilities via sysfs
  # WHY: On-chip state machine handles all logic; no daemon needed
  # HOW: Provides --smartfan-7pt, --thermal-cruise, --dual-sensor, --electrical-mode, --tachometry, --debounce-enable, --verify
  # DECISION: 7 points = maximum granularity; dual-sensor blending = precision control; persistent via systemd
  install -Dm755 "${srcdir}/max-fans-advanced.sh" \
    "${pkgdir}/usr/lib/eirikr/max-fans-advanced.sh"

  # nct-id utility: Ground-truth chip verification (compiled from C source)
  # WHAT: Directly probes Super I/O at 0x2E/0x4E, reads chip ID and HWM base
  # WHY: Independent diagnostic (doesn't rely on kernel driver being loaded)
  # HOW: Uses ioperm(2) to access ISA I/O ports; requires root
  install -Dm755 "${srcdir}/nct-id" \
    "${pkgdir}/usr/lib/eirikr/nct-id"

  # ============================================================================
  # KERNEL MODULE CONFIGURATION
  # ============================================================================
  # modprobe configuration for NCT6798D kernel driver
  # WHY: Sets driver parameters (e.g., PWM mode, ASPM behavior)
  # HOW: /etc/modprobe.d/nct6798d.conf is auto-loaded during module init
  install -Dm644 "${srcdir}/modprobe-nct6798d.conf" \
    "${pkgdir}/etc/modprobe.d/nct6798d.conf"

  # ============================================================================
  # DOCUMENTATION - User guides, technical reference, deployment info
  # ============================================================================
  # ASUS B550 TUNING: High-level guide to fan control and hwmon
  install -Dm644 "${srcdir}/ASUS-B550-TUNING.md" \
    "${pkgdir}/usr/share/doc/${pkgname}/ASUS-B550-TUNING.md"

  # NCT6798D PROGRAMMER'S GUIDE: Deep-dive technical reference
  # WHAT: Register model, access paths (ISA vs WMI), SmartFan IV curves,
  #       kernel driver implementation, known issues, verification procedures
  # WHY: Complete technical foundation for understanding and using the chip
  # WHO: System administrators, developers, power users
  install -Dm644 "${srcdir}/NCT6798D-PROGRAMMER-GUIDE.md" \
    "${pkgdir}/usr/share/doc/${pkgname}/NCT6798D-PROGRAMMER-GUIDE.md"

  # NCT6798D ADVANCED CONTROLS: Full on-chip capability guide
  # WHAT: All seven control modes (manual, thermal cruise, speed cruise, SmartFan IV)
  #       plus dual-sensor weighting, electrical mode, tachometry calibration,
  #       kernel debounce, and persistence via systemd
  # WHY: Exposes the full programmable logic in the hardware state machine
  # WHO: Power users, enthusiasts, system tuners seeking maximal control
  install -Dm644 "${srcdir}/NCT6798D-ADVANCED-CONTROLS.md" \
    "${pkgdir}/usr/share/doc/${pkgname}/NCT6798D-ADVANCED-CONTROLS.md"

  # License file (GNU GPLv3)
  # WHY: Proprietary project under GPL3 copyleft license
  install -Dm644 "${srcdir}/LICENSE" \
    "${pkgdir}/usr/share/licenses/${pkgname}/LICENSE"
}

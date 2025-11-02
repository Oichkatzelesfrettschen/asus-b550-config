#!/bin/bash

################################################################################
# max-fans-enhanced.sh - Advanced Fan Control for ASUS B550 + NCT6798D
#
# FUNCTIONALITY:
#   1. Manual control: Set fans to fixed PWM (default: maximum 255)
#   2. SmartFan IV: Temperature-based curves with multiple setpoints
#   3. Chip verification: Confirm NCT6798D is accessible and operational
#   4. Detailed logging: Document all register writes and temperatures
#
# TECHNICAL FOUNDATION:
#   The NCT6798D Super I/O exposes fan/PWM control via Linux hwmon sysfs:
#   - /sys/class/hwmon/hwmonX/pwmN          (0-255, PWM duty cycle)
#   - /sys/class/hwmon/hwmonX/pwmN_enable   (1=manual, 5=SmartFan IV, etc.)
#   - /sys/class/hwmon/hwmonX/tempN         (temperature in millidegrees C)
#   - /sys/class/hwmon/hwmonX/pwmN_auto_pointM_temp (threshold in mC)
#   - /sys/class/hwmon/hwmonX/pwmN_auto_pointM_pwm  (PWM value 0-255)
#
# WHY THIS APPROACH:
#   - sysfs is the stable, upstream-supported interface (not device-specific)
#   - Avoids direct Super I/O port access (which may conflict with ACPI/firmware)
#   - Kernel nct6775 driver handles WMI vs ISA I/O automatically
#   - SmartFan IV is hardware-native; responds in milliseconds (no userspace lag)
#
# REGISTER MODEL (reference):
#   NCT6798D / NCT6796D share similar register layout (undocumented but reverse-mapped):
#   - CR 0x20/0x21: Chip ID (0xD428 for NCT6798D)
#   - CR 0x60/0x61: HWM base address (typically 0x0290)
#   - HWM offset +0x00-0x80: Temperature/voltage/fan sensors (read-only)
#   - HWM offset +0x80-0xFF: PWM/SmartFan config (read/write)
#   Linux driver abstracts these as indexed registers and exposes via sysfs.
#
# DECISION: sysfs only (not raw register poking)
#   WHY: Respects kernel driver locking, firmware ownership, ACPI arbitration
#   WHY: Cross-distro portable (not tied to specific ISA I/O or WMI code)
#   HOW: kernel nct6775 driver translates sysfs writes to register updates
#
# USAGE:
#   max-fans-enhanced.sh [--manual [PWM]] [--smartfan] [--verify]
#
#   --manual [PWM]    Set all fans to fixed PWM (default 255 = max)
#   --smartfan        Install temperature-based SmartFan IV curves
#   --verify          Probe chip and report hwmon status (informational)
#   (no args)         Default: --manual 255 (backward compatible)
#
# EXAMPLES:
#   sudo max-fans-enhanced.sh                    # max speed, all fans
#   sudo max-fans-enhanced.sh --manual 180       # ~70% speed
#   sudo max-fans-enhanced.sh --smartfan         # temp-based curves
#   sudo max-fans-enhanced.sh --verify           # probe and report
#
# DEPLOYMENT:
#   Systemd unit (max-fans.service) typically runs with --manual 255
#   Interactive admin can use --smartfan to install curves dynamically
#
# REFERENCES (for decision justification):
#   - Linux kernel nct6775 driver: drivers/hwmon/nct6775.c
#   - Kernel sysfs interface: Documentation/hwmon/nct6775.rst
#   - Nuvoton NCT6796D datasheet: SmartFan IV register model (0xB0-0xB9)
#   - ASUS B550 community: WMI access, ACPI resource conflicts
#
################################################################################

set -u
set -o pipefail

################################################################################
# CONFIGURATION
################################################################################

readonly HWMON_PATH="/sys/class/hwmon"
readonly DEFAULT_PWM=255
SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_NAME

# SmartFan IV curve defaults (5 setpoints per Nuvoton 679x design)
# DECISION: Conservative curve (ramp gradually with temperature)
# WHY: Prevents thermal stress and acoustic issues from fan noise
# These can be overridden via command-line or config file
declare -a SMARTFAN_TEMPS=(
	40000   # Point 1: 40°C -> PWM 64 (gentle)
	50000   # Point 2: 50°C -> PWM 96
	60000   # Point 3: 60°C -> PWM 128 (medium)
	70000   # Point 4: 70°C -> PWM 192 (aggressive)
	80000   # Point 5: 80°C -> PWM 255 (max)
)

declare -a SMARTFAN_PWMS=(
	64
	96
	128
	192
	255
)

################################################################################
# LOGGING UTILITIES
################################################################################

log_info() {
	# PURPOSE: Log informational message
	# WHO: Called by all functions for diagnostics
	# WHEN: During normal operation, every action logged
	echo "[INFO] $*"
}

log_error() {
	# PURPOSE: Log error message to stderr
	# WHO: Called when operation fails
	# WHEN: On write failures, missing files, permission denials
	echo "[ERROR] $*" >&2
}

log_warn() {
	# PURPOSE: Log warning (non-fatal issue)
	# WHO: Called when setpoint/curve has unexpected behavior
	# WHEN: Non-critical conditions (e.g., temp sensor read-only)
	echo "[WARN] $*"
}

################################################################################
# CHIP VERIFICATION
################################################################################

verify_nct6798d() {
	# PURPOSE: Confirm NCT6798D is present and accessible via hwmon
	# WHAT: Scan /sys/class/hwmon for nct6798d or asus hwmon devices
	# WHY: Ensures we have the right chip before proceeding
	# HOW: Grep device name and report temperature sensors
	# RETURNS: 0 if found, 1 if not found

	log_info "Searching for NCT6798D or ASUS hwmon device..."

	local found_device=""
	for hwmon_dir in "$HWMON_PATH"/hwmon*; do
		if [[ ! -d "$hwmon_dir" ]]; then
			continue
		fi

		local device_name="unknown"
		if [[ -f "$hwmon_dir/name" ]]; then
			device_name=$(cat "$hwmon_dir/name")
		fi

		# DECISION: Match "nct6798d", "asus", "nct67" (case-insensitive)
		# WHY: Different board vendors expose different names
		#      "asus" = ASUS WMI sensors (also has NCT6798D underneath)
		#      "nct6798d" = direct kernel driver identification
		#      "nct67" = generic match for all 679x chips
		if [[ "$device_name" =~ ^(nct6798d|asus|nct67) ]]; then
			found_device="$hwmon_dir"
			log_info "  Found: $device_name at $hwmon_dir"

			# Report available temperature sensors
			local temp_count=0
			for temp_file in "$hwmon_dir"/temp*_input; do
				if [[ -f "$temp_file" ]]; then
					temp_count=$((temp_count + 1))
					local temp_label
					local temp_val
					temp_label=$(cat "$hwmon_dir/temp${temp_count}_label" 2>/dev/null || echo "Temp $temp_count")
					temp_val=$(cat "$temp_file" 2>/dev/null || echo "?")
					log_info "    $temp_label: $((temp_val / 1000))°C (raw: ${temp_val})"
				fi
			done

			# Report available PWM outputs
			local pwm_count=0
			for pwm_file in "$hwmon_dir"/pwm[0-9]; do
				if [[ -f "$pwm_file" ]]; then
					pwm_count=$((pwm_count + 1))
					local pwm_val
					local pwm_enable
					pwm_val=$(cat "$pwm_file" 2>/dev/null || echo "?")
					pwm_enable=$(cat "$hwmon_dir/pwm${pwm_count}_enable" 2>/dev/null || echo "?")
					# decode enable: 0=disabled, 1=manual, 2=pwm, 4=temp, 5=SmartFan IV
					log_info "    PWM$pwm_count: $pwm_val/255 (enable=$pwm_enable)"
				fi
			done

			log_info "Device verification successful"
			return 0
		fi
	done

	log_error "NCT6798D/ASUS hwmon device not found"
	return 1
}

################################################################################
# MANUAL PWM CONTROL
################################################################################

set_fan_manual() {
	# PURPOSE: Set fans to fixed PWM (simple mode)
	# WHAT: Write PWM value to all pwmN files
	# WHY: Fast, deterministic; no temperature-dependent variation
	# WHO: Called by main() when --manual flag used
	# PARAMS:
	#   $1 = hwmon_dir (e.g., /sys/class/hwmon/hwmon4)
	#   $2 = pwm_value (0-255)
	# RETURNS: 0 on success, 1 if any write failed

	local hwmon_dir="$1"
	local pwm_value="$2"

	# Validate PWM value range
	# WHY: Out-of-range values cause kernel write failure
	if ! [[ "$pwm_value" =~ ^[0-9]+$ ]] || ((pwm_value < 0 || pwm_value > 255)); then
		log_error "Invalid PWM value: $pwm_value (must be 0-255)"
		return 1
	fi

	log_info "Setting manual mode: PWM=$pwm_value ($(( (pwm_value * 100) / 255 ))%)"

	local pwm_count=0
	local success_count=0
	local failed_count=0

	# Iterate all pwmN files in the hwmon device
	for pwm_file in "$hwmon_dir"/pwm[0-9]; do
		[[ ! -f "$pwm_file" ]] && continue

		pwm_count=$((pwm_count + 1))

		# CRITICAL: Set pwmN_enable to 1 (manual mode) BEFORE writing PWM
		# WHY: Some modes are read-only; must switch to manual first
		# HOW: Echo 1 to the enable file
		local enable_file="${pwm_file}_enable"
		if [[ ! -w "$enable_file" ]]; then
			log_warn "Cannot write to $enable_file (may be read-only)"
			continue
		fi

		if ! echo 1 >"$enable_file" 2>/dev/null; then
			log_error "Failed to set $(basename "$pwm_file")_enable to manual mode"
			failed_count=$((failed_count + 1))
			continue
		fi

		# Now write the PWM value
		if ! echo "$pwm_value" >"$pwm_file" 2>/dev/null; then
			log_error "Failed to write $pwm_value to $pwm_file"
			failed_count=$((failed_count + 1))
			continue
		fi

		log_info "  $(basename "$pwm_file"): set to $pwm_value"
		success_count=$((success_count + 1))
	done

	log_info "Manual mode: $success_count PWM outputs set, $failed_count failed"
	[[ $success_count -gt 0 ]] && return 0 || return 1
}

################################################################################
# SMARTFAN IV CURVE SETUP
################################################################################

set_fan_smartfan_iv() {
	# PURPOSE: Install temperature-based SmartFan IV curves
	# WHAT: Write auto_point setpoints and enable SmartFan IV mode
	# WHY: Automatic fan speed follows CPU/board temperature (responsive, quiet)
	# WHO: Called when --smartfan flag used
	# PARAMS:
	#   $1 = hwmon_dir (e.g., /sys/class/hwmon/hwmon4)
	# DECISION: Use global SMARTFAN_TEMPS and SMARTFAN_PWMS arrays
	# WHY: Centralized configuration (easy to tweak at top of script)
	# RETURNS: 0 on success, 1 if any setpoint write failed

	local hwmon_dir="$1"

	log_info "Setting SmartFan IV mode (temperature-based control)"

	local pwm_count=0
	local success_count=0
	local failed_count=0

	# Iterate all pwmN files in the hwmon device
	for pwm_file in "$hwmon_dir"/pwm[0-9]; do
		[[ ! -f "$pwm_file" ]] && continue

		pwm_count=$((pwm_count + 1))
		local pwm_base
		pwm_base=$(basename "$pwm_file")

		log_info "Configuring $pwm_base with SmartFan IV curve..."

		# Write each auto_point setpoint
		# WHY: SmartFan IV requires multiple temp/PWM pairs to define curve
		# HOW: Write to pwmN_auto_pointM_temp and pwmN_auto_pointM_pwm
		local point=1
		local temp_idx=0
		local point_success=0

		while ((temp_idx < ${#SMARTFAN_TEMPS[@]})); do
			local temp_file="$hwmon_dir/${pwm_base}_auto_point${point}_temp"
			local pwm_point_file="$hwmon_dir/${pwm_base}_auto_point${point}_pwm"

			local target_temp="${SMARTFAN_TEMPS[$temp_idx]}"
			local target_pwm="${SMARTFAN_PWMS[$temp_idx]}"

			# WHY two separate writes:
			#   Some kernels require both temp and PWM in paired writes
			#   Atomic updates not guaranteed; order matters for validation
			if [[ -w "$temp_file" ]] && echo "$target_temp" >"$temp_file" 2>/dev/null; then
				if [[ -w "$pwm_point_file" ]] && echo "$target_pwm" >"$pwm_point_file" 2>/dev/null; then
					log_info "  Point $point: $((target_temp / 1000))°C -> PWM $target_pwm"
					point_success=$((point_success + 1))
				else
					log_error "Failed to write PWM for point $point"
				fi
			else
				log_warn "Setpoint $point not writable (may not be available)"
			fi

			point=$((point + 1))
			temp_idx=$((temp_idx + 1))
		done

		# CRITICAL: Enable SmartFan IV mode (pwmN_enable = 5)
		# WHY: Must switch from manual mode to SmartFan IV
		# HOW: Echo 5 to pwmN_enable
		local enable_file="${pwm_file}_enable"
		if [[ -w "$enable_file" ]]; then
			if echo 5 >"$enable_file" 2>/dev/null; then
				log_info "  $pwm_base: SmartFan IV enabled (mode 5)"
				success_count=$((success_count + 1))
			else
				log_error "Failed to enable SmartFan IV for $pwm_base"
				failed_count=$((failed_count + 1))
			fi
		else
			log_warn "$enable_file not writable"
			failed_count=$((failed_count + 1))
		fi
	done

	log_info "SmartFan IV: $success_count PWM outputs configured, $failed_count failed"
	[[ $success_count -gt 0 ]] && return 0 || return 1
}

################################################################################
# MAIN ENTRY POINT
################################################################################

main() {
	# PURPOSE: Parse arguments and dispatch to appropriate function
	# STRATEGY:
	#   1. Parse command-line flags
	#   2. Default to --manual 255 if no flags
	#   3. Verify hardware (optional --verify)
	#   4. Execute requested action
	# DECISION: Support multiple actions in single invocation
	# WHY: Allows composition (e.g., verify then set manual)

	local action="manual"
	local pwm_value="$DEFAULT_PWM"

	# Parse command-line arguments
	# WHY: Allow flexible invocation from systemd or shell
	while (($# > 0)); do
		case "$1" in
		--manual)
			action="manual"
			shift
			[[ $# -gt 0 ]] && [[ "$1" =~ ^[0-9]+$ ]] && { pwm_value="$1"; shift; }
			;;
		--smartfan)
			action="smartfan"
			shift
			;;
		--verify)
			verify_nct6798d
			return $?
			;;
		--help)
			cat <<-EOF
				Usage: $SCRIPT_NAME [OPTION]
				Set ASUS B550 NCT6798D fan speeds via kernel hwmon.

				Options:
				  --manual [PWM]    Set all fans to fixed PWM (default: 255)
				  --smartfan        Install temperature-based SmartFan IV curves
				  --verify          Verify chip presence and report status
				  --help            Show this message

				Examples:
				  sudo $SCRIPT_NAME                   # Max speed
				  sudo $SCRIPT_NAME --manual 180      # ~70% speed
				  sudo $SCRIPT_NAME --smartfan        # Temperature-based
				  sudo $SCRIPT_NAME --verify          # Diagnostics

				Configuration:
				  Edit SMARTFAN_TEMPS and SMARTFAN_PWMS arrays for custom curves.
			EOF
			return 0
			;;
		*)
			log_error "Unknown option: $1"
			return 1
			;;
		esac
	done

	# Find NCT6798D hwmon device
	# DECISION: Require explicit device match (not just any hwmon)
	# WHY: Safer; avoids affecting unrelated hwmon devices
	local found_device=""
	for hwmon_dir in "$HWMON_PATH"/hwmon*; do
		if [[ ! -d "$hwmon_dir" ]]; then
			continue
		fi

		local device_name="unknown"
		if [[ -f "$hwmon_dir/name" ]]; then
			device_name=$(cat "$hwmon_dir/name")
		fi

		# Match against known NCT6798D / ASUS identifiers
		if [[ "$device_name" =~ ^(nct6798d|asus|nct67) ]]; then
			found_device="$hwmon_dir"
			log_info "Found NCT6798D/ASUS device: $device_name at $hwmon_dir"
			break
		fi
	done

	if [[ -z "$found_device" ]]; then
		log_error "No NCT6798D/ASUS hwmon device found"
		log_error "Verify kernel nct6775 driver is loaded: sudo modprobe nct6775"
		return 1
	fi

	# Dispatch to requested action
	case "$action" in
	manual)
		set_fan_manual "$found_device" "$pwm_value"
		;;
	smartfan)
		set_fan_smartfan_iv "$found_device"
		;;
	*)
		log_error "Unknown action: $action"
		return 1
		;;
	esac
}

# Execution guard: ensure script is run as root
# WHY: sysfs PWM writes require root (security: only admin can change fans)
if [[ $EUID -ne 0 ]]; then
	log_error "This script must be run as root"
	exit 1
fi

main "$@"

#!/bin/bash
#
# max-fans.sh - Set all fans to maximum speed
# Target: ASUS B550 with NCT6798D hardware monitor
# Location: /usr/lib/eirikr/max-fans.sh
#

set -u

readonly HWMON_PATH="/sys/class/hwmon"
readonly MAX_PWM=255
readonly FANS=("pwm1" "pwm2" "pwm3" "pwm4" "pwm5" "pwm6")

log_info() {
  echo "[INFO] $*"
}

log_error() {
  echo "[ERROR] $*" >&2
}

set_fan_max() {
  local pwm_file="$1"

  if [[ ! -w "$pwm_file" ]]; then
    log_error "Cannot write to $pwm_file (permission denied)"
    return 1
  fi

  if ! echo "$MAX_PWM" > "$pwm_file" 2>/dev/null; then
    log_error "Failed to write $MAX_PWM to $pwm_file"
    return 1
  fi

  log_info "Set $(basename "$pwm_file") to maximum"
  return 0
}

main() {
  log_info "Setting all fans to maximum speed"

  local hwmon_count=0
  local fans_set=0
  local fans_failed=0

  # Find all hwmon devices
  for hwmon_dir in "$HWMON_PATH"/hwmon*; do
    if [[ ! -d "$hwmon_dir" ]]; then
      continue
    fi

    hwmon_count=$((hwmon_count + 1))
    local device_name="unknown"

    if [[ -f "$hwmon_dir/name" ]]; then
      device_name=$(cat "$hwmon_dir/name")
    fi

    log_info "Found hwmon device: $device_name at $hwmon_dir"

    # Try to set each pwm device
    for pwm in "${FANS[@]}"; do
      local pwm_file="$hwmon_dir/$pwm"

      if [[ ! -e "$pwm_file" ]]; then
        continue
      fi

      if set_fan_max "$pwm_file"; then
        fans_set=$((fans_set + 1))
      else
        fans_failed=$((fans_failed + 1))
      fi
    done
  done

  log_info "Total hwmon devices found: $hwmon_count"
  log_info "Fans set to maximum: $fans_set"
  log_info "Failed to set: $fans_failed"

  if [[ $fans_set -gt 0 ]]; then
    log_info "Fan speed adjustment completed successfully"
    return 0
  else
    log_error "Failed to set any fans to maximum"
    return 1
  fi
}

main "$@"

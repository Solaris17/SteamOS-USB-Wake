#!/usr/bin/env bash
set -euo pipefail

# Set service name and path
SERVICE_NAME="usb_wake.service"
# /usr is not writable on SteamOS and can be replaced during image update, so lets put the service in /etc/systemd/system instead since it persists
SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}"
TEMP_PASSWORD_DEFAULT="USBWake!"

log() { echo "[usb-wake-setup] $*"; }
stage() {
  echo
  echo "============================================================"
  log "$*"
  echo "============================================================"
  echo
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: missing required command: $1" >&2
    exit 1
  }
}

# Lets check for root and see if we can make it easier on the user.
ensure_root() {
  if [[ "${EUID}" -eq 0 ]]; then
    return
  fi

  need_cmd sudo
  need_cmd passwd

  local target_user=""
  local pass_status=""
  local pass_status_code=""
  local temp_password="${USB_WAKE_TEMP_PASSWORD:-${TEMP_PASSWORD_DEFAULT}}"
  local temp_password_was_set="false"

  target_user="$(id -un)"
  pass_status="$(passwd -S "${target_user}" 2>/dev/null || true)"
  pass_status_code="$(awk '{print $2}' <<< "${pass_status}")"

  if sudo -n true >/dev/null 2>&1; then
    stage "Sudo is already authorized for this session."
  elif [[ "${pass_status_code}" == "NP" ]]; then
    stage "No sudo password is set for '${target_user}'. Setting temporary password..."
    printf '%s\n%s\n' "${temp_password}" "${temp_password}" | passwd "${target_user}" >/dev/null
    temp_password_was_set="true"
  fi

  stage "Re-running as root..."
  set +e
  if [[ "${temp_password_was_set}" == "true" ]]; then
    printf '%s\n' "${temp_password}" | \
      sudo -S -k bash "$0" --internal-temp-user "${target_user}" -- "$@"
  else
    sudo -k bash "$0" -- "$@"
  fi
  local run_rc=$?
  set -e

  if [[ "${temp_password_was_set}" == "true" ]]; then
    local pass_status_after=""
    local pass_status_after_code=""
    pass_status_after="$(passwd -S "${target_user}" 2>/dev/null || true)"
    pass_status_after_code="$(awk '{print $2}' <<< "${pass_status_after}")"
    if [[ "${pass_status_after_code}" == "NP" ]]; then
      log "Temporary password cleanup verified for '${target_user}' (status: NP)."
    else
      log "WARNING: password status for '${target_user}' is '${pass_status_after_code:-unknown}' after run."
    fi
  fi

  exit "${run_rc}"
}

cleanup_temp_password() {
  if [[ "${EUID}" -ne 0 ]]; then
    return
  fi

  if [[ "${USB_WAKE_TEMP_PASSWORD_SET:-0}" != "1" ]]; then
    return
  fi

  if [[ -z "${USB_WAKE_TARGET_USER:-}" ]]; then
    log "WARNING: missing target user for temporary password cleanup."
    return
  fi

  stage "Removing temporary password for '${USB_WAKE_TARGET_USER}'..."
  passwd -d "${USB_WAKE_TARGET_USER}" >/dev/null 2>&1 || \
    log "WARNING: failed to remove temporary password. Run: sudo passwd -d ${USB_WAKE_TARGET_USER}"
}

on_exit() {
  cleanup_temp_password
  echo
}

with_readonly_disabled() {
  # Detect SteamOS readonly mode (if the command exists)
  local readonly_tool=""
  local readonly_was_enabled="false"

  if command -v steamos-readonly >/dev/null 2>&1; then
    readonly_tool="steamos-readonly"
  fi

  if [[ -n "${readonly_tool}" ]]; then
    if "${readonly_tool}" status 2>/dev/null | grep -qi 'enabled'; then
      readonly_was_enabled="true"
    fi
  fi

  if [[ "${readonly_was_enabled}" == "true" && -n "${readonly_tool}" ]]; then
    stage "SteamOS readonly is ENABLED; disabling temporarily..."
    "${readonly_tool}" disable
  else
    stage "SteamOS readonly appears disabled (or steamos-readonly not present)."
  fi

  "$@"

  # If we disabled readonly, put it back
  if [[ "${readonly_was_enabled}" == "true" && -n "${readonly_tool}" ]]; then
    stage "Re-enabling SteamOS readonly..."
    "${readonly_tool}" enable || true
  fi
}

# Install the service.
install_service() {
  # We enable all root hubs to do it because some USB devices like controllers
  # have different id values based on state (like sleep) so udevs are ineffective.
  stage "Writing ${SERVICE_PATH}..."
  cat > "${SERVICE_PATH}" <<'EOF'
[Unit]
Description=Enables wakeup for all USB root hubs

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'for device in /sys/bus/usb/devices/usb*; do echo enabled > "$device"/power/wakeup; done'

[Install]
WantedBy=multi-user.target
EOF

  chmod 0644 "${SERVICE_PATH}"
  chown root:root "${SERVICE_PATH}"

  stage "Reloading systemd..."
  systemctl daemon-reload

  stage "Enabling and starting ${SERVICE_NAME}..."
  systemctl enable --now "${SERVICE_NAME}"

  stage "Status:"
  systemctl --no-pager --full status "${SERVICE_NAME}" || true

  stage "Quick check (showing current wakeup flags):"
  grep -H . /sys/bus/usb/devices/usb*/power/wakeup 2>/dev/null || true

  stage "Install complete."
}

# Uninstall the service.
uninstall_service() {
  stage "Stopping and disabling ${SERVICE_NAME} if present..."
  systemctl disable --now "${SERVICE_NAME}" 2>/dev/null || true

  stage "Removing ${SERVICE_PATH} if present..."
  rm -f "${SERVICE_PATH}"

  stage "Disabling USB wakeup flags..."
  for device in /sys/bus/usb/devices/usb*; do
    if [[ -w "${device}/power/wakeup" ]]; then
      echo disabled > "${device}/power/wakeup" || true
    fi
  done

  stage "Reloading systemd..."
  systemctl daemon-reload

  stage "Quick check (showing current wakeup flags):"
  grep -H . /sys/bus/usb/devices/usb*/power/wakeup 2>/dev/null || true

  stage "Uninstall complete."
}

show_status() {
  stage "Service status:"
  systemctl --no-pager --full status "${SERVICE_NAME}" || true

  stage "Current wakeup flags:"
  grep -H . /sys/bus/usb/devices/usb*/power/wakeup 2>/dev/null || true
}

select_action() {
  if [[ $# -gt 0 ]]; then
    case "${1}" in
      install|uninstall|status) SELECTED_ACTION="${1}" ;;
      *) SELECTED_ACTION="unknown" ;;
    esac
    return
  fi

  echo
  echo "USB Wake Setup"
  echo "1) Install"
  echo "2) Uninstall"
  echo "3) Status"
  echo "4) Exit"
  read -r -p "Choose an option [1-4]: " menu_choice
  echo

  case "${menu_choice}" in
    1) SELECTED_ACTION="install" ;;
    2) SELECTED_ACTION="uninstall" ;;
    3) SELECTED_ACTION="status" ;;
    4) SELECTED_ACTION="exit" ;;
    *) SELECTED_ACTION="unknown" ;;
  esac
}

main() {
  echo

  local -a script_args=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --internal-temp-user)
        if [[ $# -lt 2 ]]; then
          echo "ERROR: --internal-temp-user requires a username." >&2
          exit 1
        fi
        USB_WAKE_TEMP_PASSWORD_SET="1"
        USB_WAKE_TARGET_USER="$2"
        shift 2
        ;;
      --)
        shift
        while [[ $# -gt 0 ]]; do
          script_args+=("$1")
          shift
        done
        ;;
      *)
        script_args+=("$1")
        shift
        ;;
    esac
  done

  ensure_root "${script_args[@]}"
  trap on_exit EXIT

  need_cmd systemctl
  need_cmd sh
  need_cmd grep

  local action=""
  SELECTED_ACTION=""
  select_action "${script_args[@]}"
  action="${SELECTED_ACTION}"

  case "${action}" in
    install)
      with_readonly_disabled install_service
      ;;
    uninstall)
      with_readonly_disabled uninstall_service
      ;;
    status)
      show_status
      ;;
    exit)
      log "No changes made."
      ;;
    *)
      echo "Usage: $0 [install|uninstall|status]"
      echo "Or run without arguments for a menu."
      exit 1
      ;;
  esac
}

main "$@"

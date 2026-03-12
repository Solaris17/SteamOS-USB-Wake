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

  local target_user="${USER}"
  local pass_status=""
  local temp_password="${USB_WAKE_TEMP_PASSWORD:-${TEMP_PASSWORD_DEFAULT}}"
  local temp_password_was_set="false"

  pass_status="$(passwd -S "${target_user}" 2>/dev/null || true)"

  if [[ -n "${pass_status}" && "${pass_status}" == *" NP "* ]]; then
    stage "No sudo password is set for '${target_user}'. Setting temporary password..."
    printf '%s\n%s\n' "${temp_password}" "${temp_password}" | passwd "${target_user}" >/dev/null
    temp_password_was_set="true"
  fi

  stage "Re-running as root..."
  if [[ "${temp_password_was_set}" == "true" ]]; then
    echo "${temp_password}" | sudo -S -k bash "$0" "$@"
  else
    sudo -k bash "$0" "$@"
  fi
  local run_rc=$?

  if [[ "${temp_password_was_set}" == "true" ]]; then
    stage "Removing temporary password for '${target_user}'..."
    echo "${temp_password}" | sudo -S -k passwd -d "${target_user}" >/dev/null 2>&1 || \
      log "WARNING: failed to remove temporary password. Run: sudo passwd -d ${target_user}"
  fi

  exit "${run_rc}"
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

  stage "Reloading systemd..."
  systemctl daemon-reload

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
      install|uninstall|status) echo "${1}" ;;
      *) echo "unknown" ;;
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

  case "${menu_choice}" in
    1) echo "install" ;;
    2) echo "uninstall" ;;
    3) echo "status" ;;
    4) echo "exit" ;;
    *) echo "unknown" ;;
  esac
}

main() {
  ensure_root "$@"

  need_cmd systemctl
  need_cmd sh
  need_cmd grep

  local action
  action="$(select_action "$@")"

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

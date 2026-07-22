#!/usr/bin/env bash
set -euo pipefail

# Variables
# Set service name and path
SERVICE_NAME="usb_wake.service"
# /usr is not writable on SteamOS and can be replaced during image update, so lets put the service in /etc/systemd/system instead since it persists
SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}"
# Lets backup the currently connected USB devices wakeup settings before we change them, so we can restore them if needed
BACKUP_PATH="/etc/systemd/system/usb_wake-$(date +%Y%m%d-%H%M%S).backup"

# Simple logging function with consistent prefix and color
log() { printf '\033[1;34m[USB Wake Setup]\033[0m %s\n' "$*"; }

# Check for required commands and exit with error if not found
need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo
    echo "ERROR: missing required command: $1" >&2
    echo
    exit 1
  }
}

need_cmd systemctl
need_cmd sh
need_cmd grep
need_cmd rm

# Begin Functions
# Capture flags passed to the script
usage() {
  cat <<EOF
Usage:
  $0
  $0 --restore
  $0 --uninstall
EOF
}

# Handle command line arguments
MODE="install"
RESTORE_PATH=""
if [[ $# -gt 0 ]]; then
  case "$1" in
    --restore)
      if [[ $# -ne 1 ]]; then
        usage
        exit 1
      fi
      MODE="restore"
      RESTORE_PATH="__SELECT__"
      ;;
    --uninstall)
      if [[ $# -ne 1 ]]; then
        usage
        exit 1
      fi
      MODE="uninstall"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 1
      ;;
  esac
fi

# Function to prompt user to select a backup file to restore from
select_restore_file() {
  local backup_files=()
  local selection=""
  local index=1
  local file=""

  mapfile -t backup_files < <(compgen -G "/etc/systemd/system/usb_wake-*.backup" || true)
# Check if any backup files were found
  if [[ ${#backup_files[@]} -eq 0 ]]; then
    echo
    log "No backup files found in /etc/systemd/system."
    echo
    exit 1
  fi
# Display available backup files
  echo
  log "Available backup files:"
  echo
  for file in "${backup_files[@]}"; do
    printf '  %d. %s\n' "${index}" "${file}"
    index=$((index + 1))
  done
  echo
# Prompt user to select a backup file
  while true; do
    printf 'Select backup to restore [1-%d, q to quit]: ' "${#backup_files[@]}"
    read -r selection

    case "${selection}" in
      [qQ])
        echo
        log "Aborted by user."
        echo
        exit 0
        ;;
    esac
# Validate selection
    if [[ "${selection}" =~ ^[0-9]+$ ]] && (( selection >= 1 && selection <= ${#backup_files[@]} )); then
      RESTORE_PATH="${backup_files[selection - 1]}"
      echo
      return
    fi

    echo
    log "Invalid selection."
    echo
  done
}

if [[ "${RESTORE_PATH}" == "__SELECT__" ]]; then
  select_restore_file
fi

# Prompt user for confirmation before proceeding, since this script will make system changes
echo
if [[ -n "${RESTORE_PATH}" ]]; then
  echo "Running this flag will restore USB wakeup settings from: ${RESTORE_PATH}"
  echo
  printf '\033[1;31mThis will be overwritten at next reboot if the service is still installed!\033[0m'
  echo
elif [[ "${MODE}" == "uninstall" ]]; then
  echo "Running this flag will uninstall the USB wake service."
else
  echo "Running this script will install a system service that modifies USB wakeup settings."
  echo
  echo "Use --help for more information."
fi
echo
# I should honestly just switch everything to echo -e for color
printf 'Continue? [\033[1;32mY\033[0m/n] '
read -r reply
echo
# Handle user input (default to yes if they just press enter)
case "$reply" in
  ""|[yY]|[yY][eE][sS])
    ;;
  [nN]|[nN][oO])
    log "Aborted by user."
    echo
    exit 0
    ;;
  *)
    log "Invalid input. Aborted."
    echo
    exit 1
    ;;
esac

# Detect SteamOS readonly mode (if the command exists)
READONLY_TOOL=""
if command -v steamos-readonly >/dev/null 2>&1; then
  READONLY_TOOL="steamos-readonly"
fi

readonly_was_enabled="false"
if [[ -n "${READONLY_TOOL}" ]]; then
  if "${READONLY_TOOL}" status 2>/dev/null | grep -qi 'enabled'; then
    readonly_was_enabled="true"
  fi
fi

cleanup() {
  # If we disabled readonly, put it back on exit
  if [[ "${readonly_was_enabled}" == "true" && -n "${READONLY_TOOL}" ]]; then
    echo
    log "Re-enabling SteamOS read-only file system..."
    echo
    "${READONLY_TOOL}" enable || true
  fi
}
trap cleanup EXIT

if [[ "${readonly_was_enabled}" == "true" && -n "${READONLY_TOOL}" ]]; then
  echo
  log $'SteamOS read-only file system is \033[1;33mENABLED\033[0m; disabling temporarily...'
  echo
  "${READONLY_TOOL}" disable
else
  echo
  log $'SteamOS read-only file system appears \033[1;33mDISABLED\033[0m.'
  echo
fi

# If the user passed the --restore flag, we skip the installation steps and just restore the settings from the selected backup file
if [[ -n "${RESTORE_PATH}" ]]; then
  echo
  log "Restoring USB wakeup settings from: ${RESTORE_PATH}..."
  while IFS=: read -r path state; do
    [[ -n "${path}" && -n "${state}" ]] || continue
    # USB topology can change after installation, so skip backup entries
    # whose sysfs paths are no longer present or writable.
    [[ -w "${path}" ]] || continue
    printf '%s' "${state}" > "${path}"
  done < "${RESTORE_PATH}"
  echo
  echo
  log "Quick check (showing restored wakeup flags):"
  echo
  grep -H . /sys/bus/usb/devices/*/power/wakeup 2>/dev/null || true
  echo
  log "Restore complete!"
  echo
  exit 0
fi

# If the user passed the --uninstall flag, we prompt them to optionally restore from a backup before uninstalling, then we remove the service file and disable the service
if [[ "${MODE}" == "uninstall" ]]; then
  echo
  printf 'Restore USB wakeup settings from a backup before uninstalling? [\033[1;32mY\033[0m/n] '
  read -r restore_reply
  echo

  case "$restore_reply" in
    ""|[yY]|[yY][eE][sS])
      RESTORE_PATH="__SELECT__"
      select_restore_file
      echo
      log "Restoring USB wakeup settings from: ${RESTORE_PATH}..."
      while IFS=: read -r path state; do
        [[ -n "${path}" && -n "${state}" ]] || continue
        # USB topology can change after installation, so skip backup entries
        # whose sysfs paths are no longer present or writable.
        [[ -w "${path}" ]] || continue
        printf '%s' "${state}" > "${path}"
      done < "${RESTORE_PATH}"
      echo
      echo
      log "Quick check (showing restored wakeup flags):"
      echo
      echo
      grep -H . /sys/bus/usb/devices/*/power/wakeup 2>/dev/null || true
      echo
      ;;
    [nN]|[nN][oO])
      ;;
    *)
      log "Invalid input. Aborted."
      echo
      exit 1
      ;;
  esac

  echo
  log "Stopping and disabling ${SERVICE_NAME}..."
  echo
  echo
  systemctl disable --now "${SERVICE_NAME}" || true

  echo
  echo
  log "Removing service file: ${SERVICE_PATH}..."
  echo
  rm -f "${SERVICE_PATH}"

  # Reload systemd to apply changes
  echo
  log "Refreshing system service config..."
  echo
  systemctl daemon-reload

  echo
  log "Uninstall complete!"
  echo
  exit 0
fi

# Enable wake for every currently exposed USB device with a writable
# power/wakeup setting. This includes downstream USB hubs, which may be
# required to propagate wake events from connected controllers or receivers.
# Wake authorization is not directional, so some disconnects, shutdowns,
# timeouts, or re-enumeration events may also wake the system.
echo
log "Writing USB service to: ${SERVICE_PATH}..."
echo
cat > "${SERVICE_PATH}" <<'EOF'
[Unit]
Description=Enables wakeup for USB devices with writable wake controls
Documentation=https://github.com/Solaris17/SteamOS-USB-Wake

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'for wake in /sys/bus/usb/devices/*/power/wakeup; do if [ -w "$wake" ]; then echo enabled > "$wake"; fi; done'

[Install]
WantedBy=multi-user.target
EOF

chmod 0644 "${SERVICE_PATH}"
chown root:root "${SERVICE_PATH}"

# Reload systemd to recognize the new service, then enable and start it
echo
log "Refreshing system service config..."
echo
systemctl daemon-reload

# Back up all currently exposed USB wakeup settings before the service changes them
echo
log "Backing up current USB wakeup settings to: ${BACKUP_PATH}..."
grep -H . /sys/bus/usb/devices/*/power/wakeup > "${BACKUP_PATH}" 2>/dev/null || true
echo

echo
log "Enabling and starting ${SERVICE_NAME}..."
echo
systemctl enable --now "${SERVICE_NAME}"

echo
log "Service Status:"
echo
systemctl --no-pager --full status "${SERVICE_NAME}" || true

echo
log "Quick check (showing new/current wakeup flags):"
echo
grep -H . /sys/bus/usb/devices/*/power/wakeup 2>/dev/null || true

echo
log "All Done!"
echo
echo

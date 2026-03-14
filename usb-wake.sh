#!/usr/bin/env bash
set -euo pipefail

# Set service name and path
SERVICE_NAME="usb_wake.service"
# /usr is not writable on SteamOS and can be replaced during image update, so lets put the service in /etc/systemd/system instead since it persists
SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}"

log() { printf '\033[1;34m[USB Wake Setup]\033[0m %s\n' "$*"; }

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

# Prompt user for confirmation before proceeding, since this script will make system changes
echo
echo "Running this script will install a system service that modifies USB wakeup settings."
echo
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
  # If we disabled readonly, put it back
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

# We enable all root hubs to do it because some USB devices like controllers have different id values based on state (like sleep) so udevs are ineffective
echo
log "Writing USB service to: ${SERVICE_PATH}..."
echo
cat > "${SERVICE_PATH}" <<'EOF'
[Unit]
Description=Enables wakeup for all USB root hubs
Documentation=https://github.com/Solaris17/SteamOS-USB-Wake

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'for device in /sys/bus/usb/devices/usb*; do echo enabled > "$device"/power/wakeup; done'

[Install]
WantedBy=multi-user.target
EOF

chmod 0644 "${SERVICE_PATH}"
chown root:root "${SERVICE_PATH}"

# reload systemd to recognize the new service, then enable and start it
echo
log "Refreshing system service config..."
echo
systemctl daemon-reload

echo
log "Enabling and starting ${SERVICE_NAME}..."
echo
systemctl enable --now "${SERVICE_NAME}"

echo
log "Service Status:"
echo
systemctl --no-pager --full status "${SERVICE_NAME}" || true

echo
log "Quick check (showing current wakeup flags):"
echo
grep -H . /sys/bus/usb/devices/usb*/power/wakeup 2>/dev/null || true

echo
log "All Done!"
echo
echo

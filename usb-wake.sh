#!/usr/bin/env bash
set -euo pipefail

# Set service name and path
SERVICE_NAME="usb_wake.service"
# /usr is not writable on SteamOS and can be replaced during image update, so lets put the service in /etc/systemd/system instead since it persists
SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}"

echo
log() { echo "[usb-wake-setup] $*"; }
echo

echo
need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: missing required command: $1" >&2
    exit 1
  }
}
echo

need_cmd systemctl
need_cmd sh
need_cmd grep

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

echo
cleanup() {
  # If we disabled readonly, put it back
  if [[ "${readonly_was_enabled}" == "true" && -n "${READONLY_TOOL}" ]]; then
    log "Re-enabling SteamOS readonly..."
    "${READONLY_TOOL}" enable || true
  fi
}
trap cleanup EXIT
echo

echo
if [[ "${readonly_was_enabled}" == "true" && -n "${READONLY_TOOL}" ]]; then
  log "SteamOS readonly is ENABLED; disabling temporarily..."
  "${READONLY_TOOL}" disable
else
echo
  log "SteamOS readonly appears disabled (or steamos-readonly not present)."
fi
echo

# We enable all root hubs to do it because some USB devices like controllers have different id values based on state (like sleep) so udevs are ineffective
log "Writing ${SERVICE_PATH}..."
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

echo
log "Reloading systemd..."
echo
systemctl daemon-reload

echo
log "Enabling and starting ${SERVICE_NAME}..."
echo
systemctl enable --now "${SERVICE_NAME}"

echo
log "Status:"
echo
systemctl --no-pager --full status "${SERVICE_NAME}" || true

echo
log "Quick check (showing current wakeup flags):"
echo
grep -H . /sys/bus/usb/devices/usb*/power/wakeup 2>/dev/null || true

echo
log "Done."
echo

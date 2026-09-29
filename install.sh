#!/bin/bash
# Install msi-power-linux.  Usage:  sudo ./install.sh [--lid-rule]
#   --lid-rule  also install the polkit rule that makes closing the lid always suspend
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "Run with sudo: sudo ./install.sh" >&2; exit 1; }
USER_NAME=${SUDO_USER:-}
if [ -z "$USER_NAME" ] || [ "$USER_NAME" = root ]; then
    echo "Run it via sudo from your normal user account (the Power Mode picker needs to know who you are)." >&2
    exit 1
fi
cd "$(dirname "$0")"

[ -d /sys/devices/platform/msi-ec ] || echo "WARNING: msi-ec driver not loaded - see README. Only the Linux power profile will switch until it is."
command -v powerprofilesctl >/dev/null || echo "WARNING: powerprofilesctl not found - install power-profiles-daemon."
command -v zenity >/dev/null || echo "WARNING: zenity not found - the Power Mode picker needs it."

install -m 755 bin/msi-power-auto bin/msi-power-set bin/power-mode /usr/local/bin/
install -m 644 udev/99-msi-power-auto.rules /etc/udev/rules.d/
install -m 644 systemd/msi-power-auto.service /etc/systemd/system/
install -m 755 systemd/system-sleep/msi-power-auto /usr/lib/systemd/system-sleep/msi-power-auto
install -m 644 desktop/power-mode.desktop desktop/power-mode-automatic.desktop /usr/share/applications/

# Passwordless sudo for exactly one command (it only accepts the fixed preset names)
tmp=$(mktemp)
echo "$USER_NAME ALL=(root) NOPASSWD: /usr/local/bin/msi-power-set" > "$tmp"
visudo -cf "$tmp" >/dev/null
install -m 440 "$tmp" /etc/sudoers.d/msi-power
rm -f "$tmp"

if [ "${1:-}" = --lid-rule ]; then
    install -m 644 polkit/60-lid-close-always-suspend.rules /etc/polkit-1/rules.d/
    echo "Installed lid rule."
fi

systemctl daemon-reload
systemctl enable --now msi-power-auto.service
udevadm control --reload
echo "Done. Open 'Power Mode' from the app menu, or run: power-mode"

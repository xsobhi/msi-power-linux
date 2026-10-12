#!/bin/bash
# Remove msi-power-linux.  Usage:  sudo ./uninstall.sh
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "Run with sudo: sudo ./uninstall.sh" >&2; exit 1; }
systemctl disable --now msi-power-auto.service 2>/dev/null || true
rm -f /usr/local/bin/msi-power-auto /usr/local/bin/msi-power-set /usr/local/bin/power-mode \
      /etc/udev/rules.d/99-msi-power-auto.rules /etc/systemd/system/msi-power-auto.service \
      /usr/lib/systemd/system-sleep/msi-power-auto /etc/sudoers.d/msi-power \
      /usr/share/applications/power-mode.desktop /usr/share/applications/power-mode-automatic.desktop \
      /etc/xdg/autostart/battery-calibration-restore.desktop \
      /etc/polkit-1/rules.d/60-lid-close-always-suspend.rules /run/msi-power-manual
systemctl daemon-reload
udevadm control --reload
echo "Removed. The EC keeps its last mode until changed (or use MSI Center / the msi-ec sysfs files)."

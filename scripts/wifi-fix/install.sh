#!/usr/bin/env bash
# sudo bash scripts/wifi-fix/install.sh   (then reboot)
set -euo pipefail
cd "$(dirname "$0")"
install -m 644 rtl8723be.conf /etc/modprobe.d/rtl8723be.conf
install -d /etc/systemd/network/10-netplan-wlo1.network.d
install -m 644 keep-ip.conf /etc/systemd/network/10-netplan-wlo1.network.d/keep-ip.conf
install -m 755 wifi-watchdog.sh /usr/local/sbin/wifi-watchdog.sh
install -m 644 wifi-watchdog.service wifi-watchdog.timer /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now wifi-watchdog.timer
echo "Installed. Reboot to apply the driver settings: sudo reboot"

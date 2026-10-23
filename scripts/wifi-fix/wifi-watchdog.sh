#!/usr/bin/env bash
# Runs every minute. If the router can't be reached, escalate:
# 3 min: reconnect Wi-Fi, 6 min: reload the Wi-Fi driver, 15 min: reboot (at most once an hour).
IF=wlo1
GW=192.168.0.1
STATE=/run/wifi-watchdog.fails

if ping -c2 -W3 -I "$IF" "$GW" >/dev/null 2>&1; then
  [ -s "$STATE" ] && logger -t wifi-watchdog "network back after $(cat "$STATE") failed checks"
  rm -f "$STATE"; exit 0
fi

fails=$(( $(cat "$STATE" 2>/dev/null || echo 0) + 1 ))
echo $fails > "$STATE"
logger -t wifi-watchdog "router unreachable ($fails)"

case $fails in
  3) logger -t wifi-watchdog "reconnecting Wi-Fi"
     systemctl restart wpa_supplicant; networkctl reconfigure "$IF" ;;
  6) logger -t wifi-watchdog "reloading rtl8723be driver"
     modprobe -r rtl8723be && sleep 2 && modprobe rtl8723be
     sleep 5; systemctl restart wpa_supplicant; networkctl reconfigure "$IF" ;;
  15) up=$(cut -d. -f1 /proc/uptime)
      if [ "$up" -gt 3600 ]; then logger -t wifi-watchdog "still offline, rebooting"; systemctl reboot
      else logger -t wifi-watchdog "still offline, but booted <1h ago, not rebooting"; fi ;;
esac

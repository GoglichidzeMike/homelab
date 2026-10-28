#!/usr/bin/env bash
# Usage: scripts/vpn.sh on|off|status
#   on     - qBittorrent through Mullvad (stops downloading if the VPN is down)
#   off    - qBittorrent direct on the home IP (e.g. Mullvad subscription lapsed)
#   status - show mode and the IP torrents are using
set -euo pipefail
cd "$(dirname "$0")/.."
VPN_FILES=docker-compose.yml:docker-compose.vpn.yml

set_mode() {
  sed -i '/^COMPOSE_FILE=/d' .env
  [ "$1" = on ] && echo "COMPOSE_FILE=$VPN_FILES" >> .env
  docker compose up -d --remove-orphans
  # VPN mode: bind torrents to the tunnel (tun0) so they survive VPN reconnects; direct mode: any interface
  if [ "$1" = on ]; then qbit_interface tun0; else qbit_interface ""; fi
}

qbit_interface() {
  local pass
  pass=$(grep '^HOMEPAGE_VAR_QBIT_PASS=' .env | cut -d= -f2-)
  for _ in $(seq 30); do
    docker exec -e P="$pass" -e IF="$1" qbittorrent sh -c '
      curl -sf -c /tmp/vpn.c --data-urlencode username=admin --data-urlencode "password=$P" http://localhost:8090/api/v2/auth/login >/dev/null &&
      curl -sf -b /tmp/vpn.c --data-urlencode "json={\"current_network_interface\":\"$IF\"}" http://localhost:8090/api/v2/app/setPreferences
      s=$?; rm -f /tmp/vpn.c; exit $s' 2>/dev/null && { echo "qBittorrent interface: ${1:-any}"; return; }
    sleep 2
  done
  echo "Could not set the qBittorrent interface (web UI not reachable)"
}

case "${1:-status}" in
  on)
    grep -qE '^MULLVAD_WG_PRIVATE_KEY=.+' .env || { echo "Add MULLVAD_WG_PRIVATE_KEY and MULLVAD_WG_ADDRESS to .env first"; exit 1; }
    set_mode on ;;
  off) set_mode off ;;
  status)
    if grep -q "^COMPOSE_FILE=$VPN_FILES" .env; then echo "mode: VPN (Mullvad)"; else echo "mode: direct (home IP)"; fi
    echo -n "torrent IP: "
    docker exec qbittorrent curl -s -m 10 https://am.i.mullvad.net/connected || echo "no internet (VPN down?)" ;;
  *) echo "usage: $0 on|off|status"; exit 1 ;;
esac

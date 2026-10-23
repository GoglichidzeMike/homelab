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

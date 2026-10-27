# homelab

Docker Compose stack on the `homelab` laptop (Ubuntu, user `mikegogl`, LAN `192.168.0.102`,
Tailscale `homelab.tailb183e9.ts.net`). Media + recordings live on the HDD at `/mnt/media`.

## Services

| Service | What | Port | Access |
|---|---|---|---|
| Homarr | Dashboard (home page) | 7575 | https://saxli.app (Cloudflare Access) |
| Jellyfin | Movies / TV player | 8096 | https://jellyfin.saxli.app |
| Seerr | Search + request movies/shows | 5055 | https://request.saxli.app (Cloudflare Access) |
| Home Assistant | Smart home | 8123 | https://ha.saxli.app |
| Frigate | Cameras / NVR | 8971 | https://cam.saxli.app (Frigate login) |
| Dozzle | Container logs | 8888 | https://logs.saxli.app (Cloudflare Access) |
| Radarr / Sonarr | Movie / TV automation | 7878 / 8989 | LAN or Tailscale only |
| Prowlarr | Torrent indexers | 9696 | LAN or Tailscale only |
| qBittorrent | Downloads | 8090 | LAN or Tailscale only |
| Portainer | Docker UI | 9443 | LAN or Tailscale only |
| Glances | CPU/RAM/disk for Homarr | – | internal only |
| Mosquitto | MQTT (Frigate → HA) | 1883 | localhost only |
| cloudflared | Tunnel for `*.saxli.app` | – | routes managed in Cloudflare Zero Trust |
| gluetun | Mullvad VPN for qBittorrent | – | only in VPN mode |

## How movies work

Seerr request → Radarr/Sonarr → Prowlarr finds a torrent → qBittorrent downloads to
`/mnt/media/downloads` → imported (hardlink) to `/mnt/media/movies` or `/mnt/media/tv` →
Jellyfin library refresh. Torrents are removed after import (no seeding). Quality profile:
HD-1080p, no remux, size-capped.

## Remote access

- **Public sites**: Cloudflare Tunnel (`TUNNEL_TOKEN`); public hostnames + Access policies are set
  in the Cloudflare dashboard, not in this repo.
- **Everything else**: Tailscale (installed on the host, auto-starts, key expiry disabled).
  `ssh homelab` from the Mac.

## Setup from scratch

1. Install Docker + Tailscale (`sudo tailscale up --hostname=homelab`).
2. Mount the HDD at `/mnt/media`.
3. `cp .env.example .env` and fill it in — or restore a backup (below), which includes `.env`.
4. `docker compose up -d`

## Backups

`scripts/backup.sh` runs nightly at 04:00 (user crontab) and writes
`/mnt/media/backups/homelab-<date>.tar.gz` — all app data + `.env`, minus logs/caches. Keeps 14.
Apps are stopped for ~20 s during the backup. Log: `/mnt/media/backups/backup.log`.

Restore (e.g. on the Raspberry Pi):

```bash
git clone git@github.com:GoglichidzeMike/homelab.git && cd homelab
sudo tar xzf /mnt/media/backups/homelab-<date>.tar.gz -C .
docker compose up -d
```

Backups are on the same HDD as the media — copy one elsewhere now and then.

## Torrent VPN (Mullvad)

```bash
scripts/vpn.sh status   # mode + the IP torrents use
scripts/vpn.sh on       # qBittorrent through Mullvad (needs MULLVAD_* in .env)
scripts/vpn.sh off      # back to the home IP, e.g. if the Mullvad subscription lapsed
```

VPN mode adds `docker-compose.vpn.yml` via `COMPOSE_FILE` in `.env`. It has a kill switch:
if Mullvad is down, downloads stop rather than leak the home IP. Everything else keeps working.
`MULLVAD_COUNTRY` picks the server country.

## Home Assistant extras

Stored in HA's own data (covered by backups, not tracked in git):

- Custom integrations in `homeassistant/custom_components/`: `frigate`, `xiaomi_home`
  (official Xiaomi, from github.com/XiaoMi/ha_xiaomi_home — update by replacing the folder, restart HA).
- Xiaomi Home: cloud region Singapore; 3× S20+ vacuums, humidifier, rice cooker. Most raw vacuum
  entities are hidden; the useful ones are renamed.
- Dashboard **Vacuums** (`/robot-vacuums`): one card per vacuum — controls, mode/suction/water,
  battery, maintenance.
- Automation "Bedroom camera: record 09:00-21:00".

## Known issues / todo

- Wi-Fi (rtl8723be) drops from power saving and sometimes loses its DHCP lease.
  `sudo bash scripts/wifi-fix/install.sh && sudo reboot` installs: driver power-save off,
  keep-IP-on-missed-renewal, and a watchdog timer (reconnect → reload driver → reboot after 15 min
  offline). Watchdog log: `journalctl -t wifi-watchdog`. Ethernet makes all of this unnecessary.
- Bedroom camera records motion 09:00–21:00 only (see HA extras). All 4 cameras have ONVIF pan/tilt in Frigate.
- Plan: move to a Raspberry Pi with a 4 TB NAS HDD (CMR, e.g. WD Red Plus / IronWolf).

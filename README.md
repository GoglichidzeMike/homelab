# homelab

Docker Compose stack on the `homelab` laptop: Jellyfin, Home Assistant, Frigate + Mosquitto,
Seerr / Radarr / Sonarr / Prowlarr / qBittorrent, Homarr + Glances, Dozzle, Portainer,
and a Cloudflare Tunnel for `saxli.app`.

## Setup

1. `cp .env.example .env` and fill in the values.
2. Media HDD mounted at `/mnt/media` (movies, tv, downloads, frigate).
3. `docker compose up -d`

App data directories (API keys, databases, sessions) are not tracked — see `.gitignore`.
Frigate credentials come from `FRIGATE_*` env vars; the Mosquitto `passwd` file is not tracked.

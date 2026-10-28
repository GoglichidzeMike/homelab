#!/usr/bin/env bash
# Nightly backup of all app data + .env to the HDD.
# Briefly stops apps with databases so the copies are consistent (~1 min).
# Restore: see README.
set -uo pipefail

SRC=/home/mikegogl/homelab
DST=/mnt/media/backups
KEEP=14
APPS="jellyfin homeassistant portainer qbittorrent prowlarr radarr sonarr seerr homarr audiobookshelf bazarr paperless"
STAMP=$(date +%F_%H%M)

mkdir -p "$DST"
echo "[$(date)] backup start"

running=$(docker ps --format '{{.Names}}' | grep -xE "$(echo $APPS | tr ' ' '|')" | tr '\n' ' ')
docker stop $running >/dev/null
trap 'docker start $running >/dev/null' EXIT

docker run --rm -v "$SRC":/src:ro -v /mnt/media/paperless/media:/extra/paperless-media:ro -v "$DST":/dst debian:12-slim sh -c "
  tar czf /dst/homelab-$STAMP.tar.gz -C /src \
    --exclude='jellyfin/cache' --exclude='*/logs' --exclude='*/log' --exclude='*.log' \
    --exclude='*/MediaCover' --exclude='frigate/config/model_cache' --exclude='homarr/appdata/redis' --exclude='audiobookshelf/metadata/cache' --exclude='paperless/redis' \
    --exclude='docker-compose.yml.bak*' . \
    -C /extra paperless-media &&
  chown 1000:1000 /dst/homelab-$STAMP.tar.gz && chmod 600 /dst/homelab-$STAMP.tar.gz"
status=$?

# off-site copy while apps are still stopped (consistent databases); capped so apps never stay down long
offsite=skipped
if grep -qE '^R2_BUCKET=.+' "$SRC/.env"; then
  timeout 20m "$SRC/scripts/offsite.sh" backup >/dev/null 2>&1 && offsite=ok || offsite=FAILED
fi

docker start $running >/dev/null; trap - EXIT
[ "$offsite" = ok ] && { "$SRC/scripts/offsite.sh" prune >/dev/null 2>&1 || offsite="ok (prune failed)"; }
echo "[$(date)] off-site (R2): $offsite"

ls -1t "$DST"/homelab-*.tar.gz 2>/dev/null | tail -n +$((KEEP+1)) | xargs -r rm -f
if [ $status -eq 0 ]; then
  echo "[$(date)] backup ok: homelab-$STAMP.tar.gz ($(du -h "$DST/homelab-$STAMP.tar.gz" | cut -f1))"
else
  echo "[$(date)] backup FAILED (tar exit $status)"; exit 1
fi

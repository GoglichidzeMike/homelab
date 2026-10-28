#!/usr/bin/env bash
# Off-site backup: encrypted, incremental restic snapshots in Cloudflare R2.
# Covers app data + .env + Paperless documents (not media or camera recordings).
# Usage: scripts/offsite.sh backup|prune|snapshots|check|restore-test|<any restic command>
# Needs R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_BUCKET, RESTIC_PASSWORD in .env.
# Lose RESTIC_PASSWORD and the backup can't be opened, so keep a copy off this machine.
set -euo pipefail
HOMELAB=/home/mikegogl/homelab
CACHE=/mnt/media/backups/restic-cache
RESTIC_IMAGE=restic/restic:0.17.3

get() { grep "^$1=" "$HOMELAB/.env" | cut -d= -f2-; }

restic() {
  docker run --rm -i \
    -e RESTIC_REPOSITORY="s3:https://$(get R2_ACCOUNT_ID).r2.cloudflarestorage.com/$(get R2_BUCKET)" \
    -e RESTIC_PASSWORD="$(get RESTIC_PASSWORD)" \
    -e AWS_ACCESS_KEY_ID="$(get R2_ACCESS_KEY_ID)" \
    -e AWS_SECRET_ACCESS_KEY="$(get R2_SECRET_ACCESS_KEY)" \
    -e AWS_DEFAULT_REGION=auto \
    -v "$HOMELAB":/data/homelab:ro \
    -v /mnt/media/paperless/media:/data/paperless-media:ro \
    -v "$CACHE":/root/.cache/restic \
    -v "${RESTORE_DIR:-/tmp}":/restore \
    "$RESTIC_IMAGE" "$@"
}

case "${1:-}" in
  backup)
    mkdir -p "$CACHE"
    restic cat config >/dev/null 2>&1 || restic init
    restic backup --host homelab --tag nightly \
      --exclude='/data/homelab/jellyfin/cache' --exclude='/data/homelab/*/logs' --exclude='/data/homelab/*/log' \
      --exclude='*.log' --exclude='/data/homelab/*/MediaCover' --exclude='/data/homelab/frigate/config/model_cache' \
      --exclude='/data/homelab/homarr/appdata/redis' --exclude='/data/homelab/audiobookshelf/metadata/cache' \
      --exclude='/data/homelab/paperless/redis' --exclude='/data/homelab/docker-compose.yml.bak*' \
      /data/homelab /data/paperless-media ;;
  prune)
    restic forget --host homelab --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune ;;
  restore-test)
    # restore .env + one Paperless file into a temp dir and compare with the originals
    RESTORE_DIR=$(mktemp -d); export RESTORE_DIR
    restic restore latest --target /restore --include /data/homelab/.env --include /data/homelab/docker-compose.yml >/dev/null
    cmp "$HOMELAB/.env" "$RESTORE_DIR/data/homelab/.env" && cmp "$HOMELAB/docker-compose.yml" "$RESTORE_DIR/data/homelab/docker-compose.yml" \
      && echo "restore test OK" || echo "restore test FAILED (files differ — normal only if they changed since the last backup)"
    docker run --rm -v "$RESTORE_DIR":/r alpine:3.20 rm -rf /r/data; rmdir "$RESTORE_DIR" ;;
  "") echo "usage: $0 backup|prune|snapshots|check|restore-test"; exit 1 ;;
  *) restic "$@" ;;
esac

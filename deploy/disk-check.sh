#!/usr/bin/env bash
# Logs a warning to syslog (journalctl -t afriva-disk) when the root disk is over 85% full.
# Installed as /usr/local/bin/afriva-disk-check, run by cron every 30 minutes.
set -euo pipefail

THRESHOLD=85
USED="$(df --output=pcent / | tail -1 | tr -dc '0-9')"
VIDEOS="$(du -sh /var/www/afriva/backend/storage/app/private/videos 2>/dev/null | cut -f1 || echo 0)"

if [ "$USED" -ge "$THRESHOLD" ]; then
  logger -t afriva-disk -p user.warning "Disk ${USED}% full (videos: ${VIDEOS}). Add a Hetzner Volume or move videos to Object Storage."
fi

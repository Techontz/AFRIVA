#!/usr/bin/env bash
# Nightly MySQL backup (installed as /usr/local/bin/afriva-backup, run by cron as the deploy user).
# Keeps 14 days of compressed dumps in /var/backups/afriva. Credentials come from the app's .env.
set -euo pipefail

ENV_FILE=/var/www/afriva/backend/.env
DEST=/var/backups/afriva
KEEP_DAYS=14

get() { grep -E "^$1=" "$ENV_FILE" | tail -1 | cut -d= -f2- | sed -e 's/^"//' -e 's/"$//'; }

CNF="$(mktemp)"
trap 'rm -f "$CNF"' EXIT
chmod 600 "$CNF"
printf '[client]\nuser=%s\npassword=%s\n' "$(get DB_USERNAME)" "$(get DB_PASSWORD)" > "$CNF"

FILE="$DEST/afriva-$(date +%F-%H%M).sql.gz"
mysqldump --defaults-extra-file="$CNF" --single-transaction --routines --no-tablespaces "$(get DB_DATABASE)" | gzip > "$FILE"
chmod 640 "$FILE"
find "$DEST" -name 'afriva-*.sql.gz' -mtime +$KEEP_DAYS -delete

echo "$(date -Is) backup ok: $FILE ($(du -h "$FILE" | cut -f1))"

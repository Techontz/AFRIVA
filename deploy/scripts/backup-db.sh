#!/usr/bin/env bash
# Encrypted MySQL backup of the Afriva database, uploaded to the private R2 backup bucket.
# Run as the deploy user (systemd timer afriva-backup.timer runs it nightly).
#
#   deploy/scripts/backup-db.sh                       nightly backup (daily/, plus weekly/ on Sundays)
#   deploy/scripts/backup-db.sh --label pre-migrate   one-off backup (manual/), used by deploy.sh
#   deploy/scripts/backup-db.sh --local-only          do not upload
#
# Pipeline: mysqldump --single-transaction | gzip | age (public key) > file, then verify, upload, prune.
# Retention: R2 keeps 14 daily, 8 weekly and 20 manual backups; the server keeps 3 days locally.
#
# Secrets (never in git, never in the Laravel .env):
#   /srv/afriva/secrets/backup.env        R2_ENDPOINT, R2_BACKUP_BUCKET, R2_BACKUP_ACCESS_KEY_ID,
#                                         R2_BACKUP_SECRET_ACCESS_KEY (token scoped to the backup bucket)
#   /srv/afriva/secrets/backup-age.pub    age public key (encrypts)
#   /srv/afriva/secrets/backup-age.key    age private key (decrypts; also store a copy OFF the server)

set -euo pipefail

main() {
    # shellcheck source=deploy/scripts/lib.sh
    . "$(dirname "$(readlink -f "$0")")/lib.sh"

    local label="nightly" local_only=0
    while [ $# -gt 0 ]; do
        case "$1" in
            --label) label="${2:-}"; shift 2 ;;
            --local-only) local_only=1; shift ;;
            -h|--help) sed -n '2,20p' "$0"; return 0 ;;
            *) die "unknown option: $1" ;;
        esac
    done
    [[ "$label" =~ ^[A-Za-z0-9._-]+$ ]] || die "invalid label: $label"

    local recipients="$SECRETS_DIR/backup-age.pub" identity="$SECRETS_DIR/backup-age.key"
    [ -s "$recipients" ] || die "missing $recipients (see docs/ops/backup-recovery.md)"
    command -v age > /dev/null || die "age is not installed (apt install age)"
    mkdir -p "$BACKUP_DIR" "$STATE_DIR"
    chmod 750 "$BACKUP_DIR"
    umask 077

    local stamp file tmp
    stamp="$(date -u '+%Y%m%d-%H%M%S')"
    file="$BACKUP_DIR/afriva-db-$stamp-$label.sql.gz.age"
    tmp="$file.partial"
    trap 'rm -f "${tmp:-}"' EXIT

    log "dumping database to $file"
    # The root password and database name are read inside the mysql container from its own environment.
    dc exec -T mysql sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" exec mysqldump -uroot \
            --single-transaction --quick --routines --triggers --events --hex-blob \
            --no-tablespaces --default-character-set=utf8mb4 "$MYSQL_DATABASE"' \
        | gzip -6 \
        | age -R "$recipients" -o "$tmp"
    mv "$tmp" "$file"

    # Verify: decrypt, decompress and look for mysqldump's completion marker (needs the private key).
    if [ -r "$identity" ]; then
        if age -d -i "$identity" "$file" | gunzip -c | tail -n 1 | grep -q 'Dump completed'; then
            log "verified (decrypts, decompresses, dump complete)"
        else
            die "verification failed for $file"
        fi
    else
        warn "no private key on this server; skipped decrypt verification"
    fi

    local size
    size="$(stat -c %s "$file")"
    log "backup size: $size bytes"

    if [ "$local_only" = "1" ]; then
        log "local only: not uploading"
    elif upload_and_prune "$file" "$label"; then
        :
    else
        warn "upload to R2 failed or is not configured; the local copy is kept"
    fi

    # Local copies: 3 days.
    find "$BACKUP_DIR" -maxdepth 1 -type f -name 'afriva-db-*.sql.gz.age' -mtime +2 -delete

    printf '%s %s %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$(basename "$file")" "$size" > "$STATE_DIR/last_backup"
    log "backup finished: $file"
}

# Uploads to R2 and applies retention. Returns 1 when R2 is not configured.
upload_and_prune() {
    local file="$1" label="$2" conf="$SECRETS_DIR/backup.env"
    [ -r "$conf" ] || { warn "missing $conf"; return 1; }
    command -v aws > /dev/null || { warn "aws CLI not installed"; return 1; }

    local R2_ENDPOINT R2_BACKUP_BUCKET R2_BACKUP_ACCESS_KEY_ID R2_BACKUP_SECRET_ACCESS_KEY
    R2_ENDPOINT="$(conf_value "$conf" R2_ENDPOINT)"
    R2_BACKUP_BUCKET="$(conf_value "$conf" R2_BACKUP_BUCKET)"
    R2_BACKUP_ACCESS_KEY_ID="$(conf_value "$conf" R2_BACKUP_ACCESS_KEY_ID)"
    R2_BACKUP_SECRET_ACCESS_KEY="$(conf_value "$conf" R2_BACKUP_SECRET_ACCESS_KEY)"
    if [ -z "$R2_ENDPOINT" ] || [ -z "$R2_BACKUP_BUCKET" ] || [ -z "$R2_BACKUP_ACCESS_KEY_ID" ] || [ -z "$R2_BACKUP_SECRET_ACCESS_KEY" ]; then
        warn "R2 backup settings incomplete in $conf"
        return 1
    fi

    r2() {
        AWS_ACCESS_KEY_ID="$R2_BACKUP_ACCESS_KEY_ID" AWS_SECRET_ACCESS_KEY="$R2_BACKUP_SECRET_ACCESS_KEY" \
        AWS_DEFAULT_REGION=auto AWS_REQUEST_CHECKSUM_CALCULATION=when_required \
        AWS_RESPONSE_CHECKSUM_VALIDATION=when_required \
            aws --endpoint-url "$R2_ENDPOINT" --only-show-errors "$@"
    }

    local name bucket="s3://$R2_BACKUP_BUCKET"
    name="$(basename "$file")"
    if [ "$label" = "nightly" ]; then
        r2 s3 cp "$file" "$bucket/daily/$name"
        log "uploaded daily/$name"
        if [ "$(date '+%u')" = "7" ]; then
            r2 s3 cp "$bucket/daily/$name" "$bucket/weekly/$name"
            log "copied to weekly/$name"
        fi
        prune_prefix daily 14
        prune_prefix weekly 8
    else
        r2 s3 cp "$file" "$bucket/manual/$name"
        log "uploaded manual/$name"
        prune_prefix manual 20
    fi
    return 0
}

# Keeps the newest $2 objects under prefix $1 (names start with a sortable UTC timestamp).
prune_prefix() {
    local prefix="$1" keep="$2" old
    old="$(r2 s3 ls "s3://$R2_BACKUP_BUCKET/$prefix/" | awk '{print $4}' | grep '^afriva-db-' | sort -r | tail -n +"$((keep + 1))" || true)"
    local obj
    for obj in $old; do
        r2 s3 rm "s3://$R2_BACKUP_BUCKET/$prefix/$obj"
        log "pruned $prefix/$obj"
    done
}

conf_value() {
    local line
    line="$(grep -E "^$2=" "$1" | tail -n 1)" || true
    line="${line#*=}"; line="${line%\"}"; line="${line#\"}"
    printf '%s' "$line"
}

main "$@"; exit $?

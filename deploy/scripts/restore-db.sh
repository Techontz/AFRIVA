#!/usr/bin/env bash
# Restores an encrypted Afriva database backup. Run as the deploy user.
#
# SAFE BY DEFAULT: restores into a NEW scratch database (afriva_restore_<timestamp>) and leaves
# production untouched. Production is only replaced with --into-production plus a typed confirmation.
#
#   deploy/scripts/restore-db.sh latest                       newest local backup into a scratch DB
#   deploy/scripts/restore-db.sh /srv/afriva/backups/<file>   a local file
#   deploy/scripts/restore-db.sh r2:daily/<file>              download from the R2 backup bucket
#   deploy/scripts/restore-db.sh r2:latest                    newest daily backup in R2
#   deploy/scripts/restore-db.sh <source> --database name     choose the scratch database name
#   deploy/scripts/restore-db.sh <source> --into-production   replace the live database (asks first)
#
# Needs the age private key at /srv/afriva/secrets/backup-age.key (or AGE_IDENTITY_FILE=path).

set -euo pipefail

main() {
    local script_dir
    script_dir="$(dirname "$(readlink -f "$0")")"
    # shellcheck source=deploy/scripts/lib.sh
    . "$script_dir/lib.sh"

    local source="" target="" production=0
    while [ $# -gt 0 ]; do
        case "$1" in
            --into-production) production=1; shift ;;
            --database) target="${2:-}"; shift 2 ;;
            -h|--help) sed -n '2,16p' "$0"; return 0 ;;
            -*) die "unknown option: $1" ;;
            *) source="$1"; shift ;;
        esac
    done
    [ -n "$source" ] || die "usage: restore-db.sh <latest|file|r2:key|r2:latest> [--database name] [--into-production]"

    local identity="${AGE_IDENTITY_FILE:-$SECRETS_DIR/backup-age.key}"
    [ -r "$identity" ] || die "age private key not readable: $identity"
    command -v age > /dev/null || die "age is not installed"
    umask 077

    local file
    file="$(resolve_source "$source")"
    [ -s "$file" ] || die "backup file not found or empty: $file"
    log "backup: $file"

    # Check the file decrypts and is a complete dump before touching any database.
    age -d -i "$identity" "$file" | gunzip -c | tail -n 1 | grep -q 'Dump completed' \
        || die "backup does not decrypt to a complete dump; nothing was changed"

    local prod_db
    prod_db="$(env_value DB_DATABASE)"
    [ -n "$prod_db" ] || die "DB_DATABASE missing in $ENV_FILE"

    if [ "$production" = "1" ]; then
        target="$prod_db"
        warn "This REPLACES the production database '$prod_db' with $(basename "$file")."
        warn "A safety backup is taken first and the API is put in maintenance mode during the restore."
        local answer
        read -r -p "Type RESTORE PRODUCTION to continue: " answer
        [ "$answer" = "RESTORE PRODUCTION" ] || die "not confirmed; nothing was changed"

        "$script_dir/backup-db.sh" --label pre-restore || die "safety backup failed; nothing was changed"
        dc exec -T app php artisan down --retry=60 || warn "could not enable maintenance mode"
        dc stop worker scheduler || true
        mysql_root -e "DROP DATABASE \`$target\`; CREATE DATABASE \`$target\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
        import_into "$identity" "$file" "$target"
        dc start worker scheduler || warn "worker/scheduler not started (not deployed yet?)"
        dc exec -T app php artisan up || warn "could not leave maintenance mode; run: compose.sh exec app php artisan up"
        dc exec -T app php artisan cache:clear || true
        log "production database restored from $(basename "$file")"
        return 0
    fi

    [ -n "$target" ] || target="afriva_restore_$(date -u '+%Y%m%d%H%M%S')"
    [[ "$target" =~ ^[A-Za-z0-9_]+$ ]] || die "invalid database name: $target"
    [ "$target" != "$prod_db" ] || die "refusing to use the production name without --into-production"

    mysql_root -e "CREATE DATABASE \`$target\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" \
        || die "could not create $target (does it exist already?)"
    import_into "$identity" "$file" "$target"

    log "restored into scratch database '$target'. Row counts:"
    mysql_root -e "SELECT table_name, table_rows FROM information_schema.tables WHERE table_schema='$target' ORDER BY table_name;"
    log "inspect: compose.sh exec mysql sh -c 'MYSQL_PWD=\"\$MYSQL_ROOT_PASSWORD\" mysql -uroot $target'"
    log "drop when done: compose.sh exec mysql sh -c 'MYSQL_PWD=\"\$MYSQL_ROOT_PASSWORD\" mysql -uroot -e \"DROP DATABASE $target\"'"
}

mysql_root() {
    dc exec -T mysql sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" exec mysql -uroot "$@"' sh "$@"
}

import_into() {
    local identity="$1" file="$2" db="$3"
    log "importing into '$db'"
    age -d -i "$identity" "$file" | gunzip -c | mysql_root --default-character-set=utf8mb4 "$db"
}

# Prints a local path for the requested backup (downloading from R2 when needed).
resolve_source() {
    local src="$1"
    case "$src" in
        latest)
            find "$BACKUP_DIR" -maxdepth 1 -type f -name 'afriva-db-*.sql.gz.age' -printf '%f\n' \
                | sort | tail -n 1 | sed "s#^#$BACKUP_DIR/#"
            ;;
        r2:*)
            local key="${src#r2:}" conf="$SECRETS_DIR/backup.env" endpoint bucket id secret
            endpoint="$(grep -E '^R2_ENDPOINT=' "$conf" | cut -d= -f2-)"
            bucket="$(grep -E '^R2_BACKUP_BUCKET=' "$conf" | cut -d= -f2-)"
            id="$(grep -E '^R2_BACKUP_ACCESS_KEY_ID=' "$conf" | cut -d= -f2-)"
            secret="$(grep -E '^R2_BACKUP_SECRET_ACCESS_KEY=' "$conf" | cut -d= -f2-)"
            r2dl() {
                AWS_ACCESS_KEY_ID="$id" AWS_SECRET_ACCESS_KEY="$secret" AWS_DEFAULT_REGION=auto \
                AWS_REQUEST_CHECKSUM_CALCULATION=when_required AWS_RESPONSE_CHECKSUM_VALIDATION=when_required \
                    aws --endpoint-url "$endpoint" --only-show-errors "$@"
            }
            if [ "$key" = "latest" ]; then
                key="daily/$(r2dl s3 ls "s3://$bucket/daily/" | awk '{print $4}' | grep '^afriva-db-' | sort | tail -n 1)"
            fi
            [[ "$key" =~ ^(daily|weekly|manual)/afriva-db-[A-Za-z0-9._-]+$ ]] || die "invalid R2 key: $key"
            mkdir -p "$BACKUP_DIR/restore"
            r2dl s3 cp "s3://$bucket/$key" "$BACKUP_DIR/restore/$(basename "$key")" >&2
            printf '%s' "$BACKUP_DIR/restore/$(basename "$key")"
            ;;
        *)
            printf '%s' "$src"
            ;;
    esac
}

main "$@"; exit $?

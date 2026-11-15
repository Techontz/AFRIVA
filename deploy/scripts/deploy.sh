#!/usr/bin/env bash
# Deploys a git ref of the Afriva API on this server. Run as the deploy user.
#
#   deploy/scripts/deploy.sh [ref]          ref = branch, tag or commit (default: main)
#
# Environment:
#   ALLOW_DESTRUCTIVE_MIGRATIONS=1   run migrations whose SQL contains DROP, RENAME or TRUNCATE
#   SKIP_BACKUP=1                    skip the pre-migration database backup (not recommended)
#   HEALTH_VIA_PUBLIC=1              health check through public DNS instead of 127.0.0.1
#
# Steps: fetch and check out the ref, build afriva-api:<sha>, start MySQL and Redis, inspect pending
# migrations (php artisan migrate --pretend) and refuse destructive SQL, back up the database, migrate,
# switch app/worker/scheduler to the new image (each container runs "php artisan optimize" on start),
# health check /up and /api/v1/health, and roll back to the previous image on failure.
#
# Migrations run while the previous release is still serving, so they must be backward compatible
# (add columns and tables first, remove old ones in a later release). A rollback switches the image
# back but does NOT undo migrations; restore the pre-migration backup with restore-db.sh if needed.
#
# The whole script is wrapped in main() so that "git checkout" replacing this file mid-run is harmless.

set -euo pipefail

main() {
    local script_dir
    script_dir="$(dirname "$(readlink -f "$0")")"
    # shellcheck source=deploy/scripts/lib.sh
    . "$script_dir/lib.sh"

    local ref="${1:-main}"
    [[ "$ref" =~ ^[A-Za-z0-9._/-]+$ ]] || die "invalid ref: $ref"
    [ "$(id -u)" -ne 0 ] || die "run as the deploy user, not root"
    [ -f "$ENV_FILE" ] || die "missing $ENV_FILE (copy deploy/.env.production.example and fill it in)"
    mkdir -p "$STATE_DIR"

    exec 9>"$STATE_DIR/deploy.lock"
    flock -n 9 || die "another deploy or rollback is running"
    exec > >(tee -a "$STATE_DIR/deploy.log") 2>&1

    log "==== deploy of '$ref' started by $(whoami)"
    cd "$REPO_DIR"
    if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
        die "$REPO_DIR has local changes; the server checkout must stay clean"
    fi
    git fetch --prune --tags --force origin
    local sha
    sha="$(git rev-parse --verify --quiet "origin/$ref^{commit}" || git rev-parse --verify --quiet "$ref^{commit}")" \
        || die "ref not found: $ref"
    git checkout --quiet --detach "$sha"
    local tag="${sha:0:12}"
    local prev
    prev="$(current_tag)"
    log "commit $sha, image $IMAGE_REPO:$tag, current ${prev:-none}"

    # ---- Build ----------------------------------------------------------------
    if docker image inspect "$IMAGE_REPO:$tag" > /dev/null 2>&1; then
        log "image $IMAGE_REPO:$tag already built"
    else
        log "building $IMAGE_REPO:$tag"
        docker build \
            --build-context phpconf="$REPO_DIR/deploy/docker/php" \
            --build-arg APP_UID="$(id -u)" --build-arg APP_GID="$(id -g)" \
            --build-arg GIT_SHA="$sha" \
            -f "$REPO_DIR/deploy/docker/php/Dockerfile" \
            -t "$IMAGE_REPO:$tag" \
            "$REPO_DIR/backend"
    fi

    # ---- Data services --------------------------------------------------------
    AFRIVA_IMAGE_TAG="$tag" dc up -d mysql redis
    wait_healthy mysql 180 || die "MySQL is not healthy"
    wait_healthy redis 60 || die "Redis is not healthy"

    # ---- Migration safety check -------------------------------------------------
    local pretend
    pretend="$(artisan_run "$tag" migrate --pretend --force --no-ansi 2>&1)" || {
        printf '%s\n' "$pretend"
        die "php artisan migrate --pretend failed; nothing was changed"
    }
    local migrate=0
    if printf '%s' "$pretend" | grep -qi 'nothing to migrate'; then
        log "no pending migrations"
    else
        migrate=1
        log "pending migrations (pretend):"
        printf '%s\n' "$pretend"
        local destructive
        destructive="$(printf '%s\n' "$pretend" | grep -Ei '\b(drop|rename|truncate)\b' || true)"
        if [ -n "$destructive" ]; then
            printf '%s\n' "$destructive"
            if [ "${ALLOW_DESTRUCTIVE_MIGRATIONS:-0}" = "1" ]; then
                warn "destructive SQL found; continuing because ALLOW_DESTRUCTIVE_MIGRATIONS=1"
            else
                die "destructive SQL (DROP/RENAME/TRUNCATE) found in pending migrations. Review it, then rerun with ALLOW_DESTRUCTIVE_MIGRATIONS=1. Nothing was changed."
            fi
        fi
    fi

    # ---- Backup and migrate -------------------------------------------------------
    if [ "$migrate" = "1" ]; then
        if [ "${SKIP_BACKUP:-0}" = "1" ]; then
            warn "SKIP_BACKUP=1: migrating without a fresh backup"
        else
            log "backing up the database before migrating"
            "$script_dir/backup-db.sh" --label "pre-migrate-$tag" || die "backup failed; not migrating. Nothing was changed."
        fi
        log "running migrations"
        artisan_run "$tag" migrate --force --no-ansi || die "migration failed. Containers still run ${prev:-nothing}. Check the database; the pre-migration backup is in $BACKUP_DIR."
    fi

    # ---- Switch -------------------------------------------------------------------
    log "switching app, worker and scheduler to $tag"
    AFRIVA_IMAGE_TAG="$tag" dc up -d --no-deps --remove-orphans app worker scheduler

    if wait_healthy app 120 && health_check 10; then
        if [ -n "$prev" ] && [ "$prev" != "$tag" ]; then
            printf '%s\n' "$prev" > "$STATE_DIR/previous_tag"
        fi
        printf '%s\n' "$tag" > "$STATE_DIR/current_tag"
        printf '%s %s %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$tag" "$ref" >> "$STATE_DIR/releases.log"
        prune_images "$tag" "$prev"
        log "==== deploy of $tag succeeded"
        return 0
    fi

    # ---- Automatic rollback ---------------------------------------------------------
    warn "new release $tag failed its health check"
    AFRIVA_IMAGE_TAG="$tag" dc logs --tail 80 app || true
    if [ -z "$prev" ] || [ "$prev" = "$tag" ]; then
        die "no previous image to roll back to. Investigate with: deploy/scripts/compose.sh logs app"
    fi
    log "rolling back to $prev"
    AFRIVA_IMAGE_TAG="$prev" dc up -d --no-deps app worker scheduler
    if wait_healthy app 120 && health_check 10; then
        warn "rolled back to $prev. Migrations of $tag (if any) were NOT undone."
    else
        warn "rollback to $prev is also unhealthy. Manual action needed (see docs/ops/troubleshooting.md)."
    fi
    log "==== deploy of $tag FAILED"
    return 1
}

# Keeps the current, previous and 3 most recent other images; removes older build cache.
prune_images() {
    local keep_a="$1" keep_b="${2:-}" n=0 t
    while read -r t; do
        [ -n "$t" ] || continue
        if [ "$t" = "$keep_a" ] || [ "$t" = "$keep_b" ]; then continue; fi
        n=$((n + 1))
        if [ "$n" -gt 3 ]; then
            docker image rm "$IMAGE_REPO:$t" > /dev/null 2>&1 || true
        fi
    done < <(docker image ls "$IMAGE_REPO" --format '{{.Tag}}')
    docker builder prune -f --filter until=168h > /dev/null 2>&1 || true
}

main "$@"; exit $?

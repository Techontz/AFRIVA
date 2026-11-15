#!/usr/bin/env bash
# Shared helpers for the Afriva deploy scripts. Sourced, not executed.
# shellcheck disable=SC2034

AFRIVA_ROOT="${AFRIVA_ROOT:-/srv/afriva}"
REPO_DIR="${REPO_DIR:-$AFRIVA_ROOT/repo}"
SHARED_DIR="$AFRIVA_ROOT/shared"
STATE_DIR="$AFRIVA_ROOT/state"
BACKUP_DIR="$AFRIVA_ROOT/backups"
SECRETS_DIR="$AFRIVA_ROOT/secrets"
ENV_FILE="$SHARED_DIR/.env"
COMPOSE_FILE="$REPO_DIR/deploy/docker-compose.prod.yml"
API_HOST="${API_HOST:-api.afriva.co.tz}"
IMAGE_REPO="afriva-api"

log()  { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }
warn() { printf '[%s] WARNING: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2; }
die()  { printf '[%s] ERROR: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2; exit 1; }

# Reads one KEY=value from the shared .env without sourcing it (values are never executed).
env_value() {
    local key="$1" line
    line="$(grep -E "^${key}=" "$ENV_FILE" 2>/dev/null | tail -n 1)" || true
    line="${line#*=}"
    line="${line%\"}"; line="${line#\"}"
    line="${line%\'}"; line="${line#\'}"
    printf '%s' "$line"
}

current_tag()  { cat "$STATE_DIR/current_tag" 2>/dev/null || true; }
previous_tag() { cat "$STATE_DIR/previous_tag" 2>/dev/null || true; }

# docker compose with the production file, env file and an image tag (default: the current one).
dc() {
    local tag="${AFRIVA_IMAGE_TAG:-$(current_tag)}"
    [ -n "$tag" ] || tag="none"
    AFRIVA_IMAGE_TAG="$tag" AFRIVA_ROOT="$AFRIVA_ROOT" \
        docker compose --project-directory "$REPO_DIR/deploy" -f "$COMPOSE_FILE" --env-file "$ENV_FILE" "$@"
}

# One-off artisan command in a throwaway container of the given tag (no config caching).
artisan_run() {
    local tag="$1"; shift
    AFRIVA_IMAGE_TAG="$tag" dc run --rm --no-deps -T -e AFRIVA_OPTIMIZE=0 app php artisan "$@"
}

# Waits until a compose service reports healthy (or fails after $2 seconds).
wait_healthy() {
    local service="$1" timeout="${2:-120}" waited=0 cid status
    while [ "$waited" -lt "$timeout" ]; do
        cid="$(dc ps -q "$service" 2>/dev/null | head -n 1)"
        if [ -n "$cid" ]; then
            status="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$cid" 2>/dev/null || true)"
            case "$status" in
                healthy) return 0 ;;
                unhealthy|exited|dead) warn "$service is $status"; return 1 ;;
            esac
        fi
        sleep 3; waited=$((waited + 3))
    done
    warn "$service not healthy after ${timeout}s"
    return 1
}

# HTTP status of an API path. By default it connects to this server (127.0.0.1) with the real host
# name and TLS, so it tests this origin even before DNS points here. HEALTH_VIA_PUBLIC=1 goes
# through public DNS (Cloudflare) instead.
http_status() {
    local path="$1"
    local args=(-sS -o /dev/null -w '%{http_code}' --max-time 15)
    if [ "${HEALTH_VIA_PUBLIC:-0}" != "1" ]; then
        args+=(--resolve "$API_HOST:443:127.0.0.1")
    fi
    curl "${args[@]}" "https://$API_HOST$path" 2>/dev/null || echo "000"
}

# /up must answer 200. /api/v1/health should answer 200; 404 (not deployed yet) is only a warning.
health_check() {
    local tries="${1:-10}" i code deep
    for ((i = 1; i <= tries; i++)); do
        code="$(http_status /up)"
        if [ "$code" = "200" ]; then
            break
        fi
        log "health: /up answered $code (attempt $i/$tries)"
        sleep 3
    done
    [ "$code" = "200" ] || { warn "/up failed with $code"; return 1; }
    log "health: /up 200"

    deep="$(http_status /api/v1/health)"
    case "$deep" in
        200) log "health: /api/v1/health 200" ;;
        404) warn "/api/v1/health returned 404 (endpoint not deployed yet); continuing" ;;
        *)   warn "/api/v1/health failed with $deep"; return 1 ;;
    esac
    return 0
}

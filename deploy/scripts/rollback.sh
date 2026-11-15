#!/usr/bin/env bash
# Switches the Afriva API back to an earlier image. Run as the deploy user.
#
#   deploy/scripts/rollback.sh            back to the previous image (state/previous_tag)
#   deploy/scripts/rollback.sh <tag>      to a specific image tag (see: docker image ls afriva-api)
#
# Only the code changes. Database migrations are NOT undone; if the newer release changed the schema
# in a way the old code cannot handle, restore the pre-migration backup (docs/ops/backup-recovery.md).

set -euo pipefail

main() {
    # shellcheck source=deploy/scripts/lib.sh
    . "$(dirname "$(readlink -f "$0")")/lib.sh"

    local target="${1:-}"
    [ "$(id -u)" -ne 0 ] || die "run as the deploy user, not root"
    exec 9>"$STATE_DIR/deploy.lock"
    flock -n 9 || die "another deploy or rollback is running"
    exec > >(tee -a "$STATE_DIR/deploy.log") 2>&1

    local current
    current="$(current_tag)"
    [ -n "$target" ] || target="$(previous_tag)"
    [ -n "$target" ] || die "no previous tag recorded; pass a tag (docker image ls $IMAGE_REPO)"
    [[ "$target" =~ ^[A-Za-z0-9._-]+$ ]] || die "invalid tag: $target"
    docker image inspect "$IMAGE_REPO:$target" > /dev/null 2>&1 || die "image $IMAGE_REPO:$target not found on this server"
    [ "$target" != "$current" ] || die "$target is already running"

    log "==== rollback from ${current:-none} to $target"
    AFRIVA_IMAGE_TAG="$target" dc up -d --no-deps app worker scheduler
    if wait_healthy app 120 && health_check 10; then
        printf '%s\n' "$target" > "$STATE_DIR/current_tag"
        [ -z "$current" ] || printf '%s\n' "$current" > "$STATE_DIR/previous_tag"
        printf '%s %s rollback\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$target" >> "$STATE_DIR/releases.log"
        log "==== rollback to $target succeeded (run rollback.sh again to return to $current)"
        return 0
    fi
    warn "$target is unhealthy too. Containers are left on $target for inspection."
    die "rollback failed; see docs/ops/troubleshooting.md"
}

main "$@"; exit $?

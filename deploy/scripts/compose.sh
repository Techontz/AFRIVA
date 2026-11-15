#!/usr/bin/env bash
# docker compose for the Afriva production stack, pinned to the currently deployed image tag.
# Usage: deploy/scripts/compose.sh ps | logs -f worker | exec app php artisan about | ...
set -euo pipefail
# shellcheck source=deploy/scripts/lib.sh
. "$(dirname "$(readlink -f "$0")")/lib.sh"
dc "$@"

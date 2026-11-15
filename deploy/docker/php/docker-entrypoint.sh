#!/bin/sh
# Afriva container entrypoint (runs as the non-root "afriva" user).
#  1. Makes sure the bind-mounted storage/ tree exists with safe permissions.
#  2. Caches config, routes, events and views (php artisan optimize) for long-running roles.
#  3. Execs the command (php-fpm, queue:work, schedule:work, or a one-off artisan command).
#
# Set AFRIVA_OPTIMIZE=0 for one-off commands (deploy.sh does this for migrate and pretend runs).
set -eu

cd /var/www/html

for d in app/public app/private framework/cache/data framework/sessions framework/views logs; do
    mkdir -p "storage/$d"
done
# Creator ID documents live on the private disk: owner only. Public images must stay readable
# by the host Nginx (which serves /storage/ directly), so directories there are 755.
chmod 700 storage/app/private 2>/dev/null || true
chmod 755 storage storage/app storage/app/public 2>/dev/null || true

if [ ! -f .env ]; then
    echo "afriva-entrypoint: /var/www/html/.env is missing (mount /srv/afriva/shared/.env)." >&2
    exit 1
fi

if [ "${AFRIVA_OPTIMIZE:-1}" = "1" ]; then
    # Fails loudly on a broken config so the container never starts with a half cached state.
    php artisan optimize --no-ansi -q
fi

exec "$@"

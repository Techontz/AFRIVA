#!/bin/bash
# One-time production setup, run on the server after filling in .env:
#   DB_DATABASE / DB_USERNAME / DB_PASSWORD and ADMIN_EMAIL / ADMIN_PASSWORD
# Usage: bash deploy-finish.sh
set -e
cd "$(dirname "$0")"

need() { grep -q "^$1=.\+" .env || { echo "Fill in $1 in .env first."; exit 1; }; }
need DB_DATABASE
need DB_USERNAME
need DB_PASSWORD
need ADMIN_EMAIL
need ADMIN_PASSWORD

php artisan config:clear
php artisan migrate --force
php artisan db:seed --force   # production: reference data + the ADMIN_EMAIL super admin only

# The admin now exists; don't keep its password in a file.
sed -i 's/^ADMIN_PASSWORD=.*/ADMIN_PASSWORD=/' .env

php artisan optimize   # config, route, event and view caches

# Scheduler: daily earnings distribution + hourly subscription expiry.
CRON="* * * * * cd $PWD && php artisan schedule:run >> /dev/null 2>&1"
(crontab -l 2>/dev/null | grep -v 'artisan schedule:run' || true; echo "$CRON") | crontab -

echo "Afriva API is set up."

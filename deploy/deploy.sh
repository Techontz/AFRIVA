#!/usr/bin/env bash
# Ship the backend and website from this machine to the server. Run from the project root:
#   deploy/deploy.sh <server-ip-or-host>
# Never touches the server's .env, uploaded files (storage/app) or database contents;
# migrations run with --force, and the base data seeder runs only on the very first deploy.
set -euo pipefail

HOST="${1:?usage: deploy/deploy.sh <server-ip-or-host>}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/afriva_hetzner}"
REMOTE="afriva@$HOST"
APP_DIR=/var/www/afriva
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SSH=(ssh -i "$SSH_KEY" -o IdentitiesOnly=yes)

echo "==> Uploading backend"
rsync -az --delete -e "${SSH[*]}" \
  --exclude .env --exclude '.env.*' --exclude vendor/ --exclude node_modules/ \
  --exclude 'storage/app/*' --exclude 'storage/logs/*' --exclude 'storage/framework/cache/*' \
  --exclude 'storage/framework/sessions/*' --exclude 'storage/framework/views/*' \
  --exclude 'bootstrap/cache/*.php' --exclude public/storage --exclude database/database.sqlite \
  --exclude .DS_Store --exclude CLAUDE.md --exclude AGENTS.md \
  "$ROOT/backend/" "$REMOTE:$APP_DIR/backend/"

echo "==> Uploading website"
rsync -az --delete -e "${SSH[*]}" \
  --exclude node_modules/ --exclude .next/ --exclude '.env*' --exclude .DS_Store --exclude AGENTS.md \
  "$ROOT/afriva_web/" "$REMOTE:$APP_DIR/web/"

echo "==> Building on the server"
"${SSH[@]}" "$REMOTE" bash -s <<'REMOTE_SCRIPT'
set -euo pipefail
cd /var/www/afriva/backend

composer install --no-dev --optimize-autoloader --no-interaction --quiet
grep -q '^APP_KEY=base64' .env || php artisan key:generate --force
mkdir -p storage/app/public storage/app/private/videos storage/logs \
  storage/framework/{cache,sessions,views} bootstrap/cache
[ -L public/storage ] || php artisan storage:link

php artisan migrate --force
if [ ! -f storage/app/.base-data-seeded ]; then
  # Settings, categories, plans, payment methods. Demo accounts/dramas are NOT loaded in production.
  php artisan db:seed --class=CoreSeeder --force
  touch storage/app/.base-data-seeded
fi

php artisan optimize
sudo systemctl reload php8.3-fpm
sudo systemctl restart afriva-queue

cd /var/www/afriva/web
npm ci --no-audit --no-fund --loglevel=error
npm run build
sudo systemctl restart afriva-web
REMOTE_SCRIPT

echo "==> Health checks"
"${SSH[@]}" "$REMOTE" 'curl -fsS -o /dev/null -w "API  /up            %{http_code}\n" http://127.0.0.1/up -H "Host: $(grep ^APP_URL= /var/www/afriva/backend/.env | cut -d/ -f3)";
  curl -fsS -o /dev/null -w "Web  /              %{http_code}\n" http://127.0.0.1:3000/'
echo "Deploy finished."

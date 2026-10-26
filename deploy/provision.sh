#!/usr/bin/env bash
# One-time setup of a fresh Ubuntu 24.04 server for Afriva. Run as root:
#   WEB_DOMAIN=afriva.example API_DOMAIN=api.afriva.example LE_EMAIL=you@example.com bash provision.sh
# Safe to re-run: every step checks before changing anything.
set -euo pipefail

: "${WEB_DOMAIN:?set WEB_DOMAIN}"
: "${API_DOMAIN:?set API_DOMAIN}"
: "${LE_EMAIL:?set LE_EMAIL to the email for HTTPS certificate expiry notices}"
DEPLOY_USER=afriva
APP_DIR=/var/www/afriva
HERE="$(cd "$(dirname "$0")" && pwd)"
export DEBIAN_FRONTEND=noninteractive

echo "==> System packages"
apt-get update -q
apt-get upgrade -yq
apt-get install -yq software-properties-common curl unzip git ufw fail2ban unattended-upgrades \
  nginx mysql-server certbot python3-certbot-nginx ffmpeg \
  php8.3-fpm php8.3-cli php8.3-mysql php8.3-mbstring php8.3-xml php8.3-curl php8.3-zip \
  php8.3-intl php8.3-bcmath php8.3-gd php8.3-opcache
dpkg-reconfigure -f noninteractive unattended-upgrades

if ! command -v node >/dev/null || [[ "$(node -v)" != v22* ]]; then
  echo "==> Node.js 22"
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
  apt-get install -yq nodejs
fi

if ! command -v composer >/dev/null; then
  echo "==> Composer"
  curl -fsSL https://getcomposer.org/installer -o /tmp/composer-setup.php
  php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer
  rm /tmp/composer-setup.php
fi

echo "==> Swap (2 GB) so builds don't run out of memory"
if ! swapon --show | grep -q /swapfile; then
  fallocate -l 2G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

echo "==> Deploy user '$DEPLOY_USER' (same SSH keys as root)"
if ! id "$DEPLOY_USER" >/dev/null 2>&1; then
  adduser --disabled-password --gecos "" "$DEPLOY_USER"
fi
usermod -aG www-data "$DEPLOY_USER"
install -d -m 700 -o "$DEPLOY_USER" -g "$DEPLOY_USER" /home/$DEPLOY_USER/.ssh
install -m 600 -o "$DEPLOY_USER" -g "$DEPLOY_USER" /root/.ssh/authorized_keys /home/$DEPLOY_USER/.ssh/authorized_keys
# The deploy user may restart only the app services.
cat > /etc/sudoers.d/afriva <<EOF
$DEPLOY_USER ALL=(root) NOPASSWD: /usr/bin/systemctl reload php8.3-fpm, /usr/bin/systemctl restart afriva-web, /usr/bin/systemctl restart afriva-queue, /usr/bin/systemctl reload nginx
EOF
chmod 440 /etc/sudoers.d/afriva

echo "==> App directories"
install -d -o "$DEPLOY_USER" -g www-data -m 2775 $APP_DIR $APP_DIR/backend $APP_DIR/web
install -d -o "$DEPLOY_USER" -g www-data -m 2770 /var/backups/afriva

echo "==> SSH hardening (keys only)"
cat > /etc/ssh/sshd_config.d/10-afriva.conf <<'EOF'
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin prohibit-password
MaxAuthTries 4
EOF
systemctl reload ssh

echo "==> Firewall: SSH, HTTP, HTTPS only"
ufw default deny incoming
ufw default allow outgoing
ufw allow OpenSSH
ufw allow 'Nginx Full'
ufw --force enable
systemctl enable --now fail2ban

echo "==> MySQL: database + app user (local connections only)"
if [ ! -f /root/afriva-db.env ]; then
  DB_PASS="$(openssl rand -base64 33 | tr -d '/+=' | cut -c1-32)"
  mysql <<SQL
CREATE DATABASE IF NOT EXISTS afriva CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'afriva'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON afriva.* TO 'afriva'@'localhost';
FLUSH PRIVILEGES;
SQL
  printf 'DB_USERNAME=afriva\nDB_PASSWORD=%s\n' "$DB_PASS" > /root/afriva-db.env
  chmod 600 /root/afriva-db.env
fi
# MySQL listens on localhost only (Ubuntu default bind-address=127.0.0.1); the firewall blocks 3306 anyway.

echo "==> Backend .env (created once; never overwritten)"
if [ ! -f $APP_DIR/backend/.env ]; then
  DB_PASS="$(grep '^DB_PASSWORD=' /root/afriva-db.env | cut -d= -f2-)"
  sed -e "s/__API_DOMAIN__/$API_DOMAIN/g" -e "s/__WEB_DOMAIN__/$WEB_DOMAIN/g" -e "s/__DB_PASSWORD__/$DB_PASS/" \
    "$HERE/env/backend.env.production" > $APP_DIR/backend/.env
  chown $DEPLOY_USER:$DEPLOY_USER $APP_DIR/backend/.env
  chmod 600 $APP_DIR/backend/.env
fi
echo "NEXT_PUBLIC_API_URL=https://$API_DOMAIN/api/v1" > $APP_DIR/web/.env.production
chown $DEPLOY_USER:$DEPLOY_USER $APP_DIR/web/.env.production

echo "==> PHP limits for video uploads (500 MB)"
cat > /etc/php/8.3/fpm/conf.d/99-afriva.ini <<'EOF'
upload_max_filesize = 512M
post_max_size = 520M
max_execution_time = 300
max_input_time = 300
memory_limit = 512M
expose_php = Off
opcache.enable = 1
opcache.memory_consumption = 192
opcache.validate_timestamps = 0
EOF
cp /etc/php/8.3/fpm/conf.d/99-afriva.ini /etc/php/8.3/cli/conf.d/99-afriva.ini
sed -i 's/^opcache.validate_timestamps.*/opcache.validate_timestamps = 1/' /etc/php/8.3/cli/conf.d/99-afriva.ini
# PHP runs as the deploy user, so uploads, logs and cron (also the deploy user) never fight over ownership.
# The socket stays owned by www-data so Nginx can connect.
sed -i -e "s/^user = www-data/user = $DEPLOY_USER/" /etc/php/8.3/fpm/pool.d/www.conf
systemctl restart php8.3-fpm

echo "==> Nginx sites"
rm -f /etc/nginx/sites-enabled/default
for site in afriva-api afriva-web; do
  sed -e "s/__API_DOMAIN__/$API_DOMAIN/g" -e "s/__WEB_DOMAIN__/$WEB_DOMAIN/g" \
    "$HERE/nginx/$site.conf" > /etc/nginx/sites-available/$site.conf
  ln -sf /etc/nginx/sites-available/$site.conf /etc/nginx/sites-enabled/$site.conf
done
cp "$HERE/nginx/afriva-limits.conf" /etc/nginx/conf.d/afriva-limits.conf
nginx -t
systemctl reload nginx

echo "==> Services: Next.js website + Laravel queue worker"
cp "$HERE/systemd/afriva-web.service" "$HERE/systemd/afriva-queue.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable afriva-web afriva-queue

echo "==> Cron: Laravel scheduler, nightly DB backup, disk check"
install -m 755 "$HERE/backup.sh" /usr/local/bin/afriva-backup
install -m 755 "$HERE/disk-check.sh" /usr/local/bin/afriva-disk-check
cat > /etc/cron.d/afriva <<EOF
* * * * * $DEPLOY_USER cd $APP_DIR/backend && php artisan schedule:run >> /dev/null 2>&1
15 2 * * * $DEPLOY_USER /usr/local/bin/afriva-backup >> /var/log/afriva-backup.log 2>&1
*/30 * * * * root /usr/local/bin/afriva-disk-check
EOF
touch /var/log/afriva-backup.log && chown $DEPLOY_USER /var/log/afriva-backup.log

echo "==> HTTPS certificates (DNS for both domains must already point here)"
if ! certbot certificates 2>/dev/null | grep -q "$API_DOMAIN"; then
  certbot --nginx --non-interactive --agree-tos --redirect -m "$LE_EMAIL" \
    -d "$WEB_DOMAIN" -d "www.$WEB_DOMAIN" -d "$API_DOMAIN"
fi

echo
echo "Done. DB credentials are in /root/afriva-db.env (root-only). Next: run deploy/deploy.sh from your Mac."

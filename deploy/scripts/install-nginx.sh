#!/usr/bin/env bash
# Installs the Afriva Nginx config and obtains the Let's Encrypt certificate. Run as root, after
# bootstrap-server.sh and after api.afriva.co.tz resolves to this server (DNS only / grey cloud is the
# most reliable for the first issuance; proxied also works because Let's Encrypt follows redirects).
#
#   deploy/scripts/install-nginx.sh admin@afriva.co.tz
#
# Idempotent: rerun after changing files in deploy/nginx/ to install and reload them.
set -euo pipefail

EMAIL="${1:-}"
DOMAIN="${DOMAIN:-api.afriva.co.tz}"
SRC="$(cd "$(dirname "$(readlink -f "$0")")/../nginx" && pwd)"

[ "$(id -u)" -eq 0 ] || { echo "run as root (sudo)" >&2; exit 1; }

install -d -m 0755 /var/www/certbot /etc/nginx/snippets /etc/nginx/certs
install -m 0644 "$SRC/conf.d/afriva-http.conf" /etc/nginx/conf.d/afriva-http.conf
install -m 0644 "$SRC/snippets/afriva-security-headers.conf" /etc/nginx/snippets/
install -m 0644 "$SRC/snippets/afriva-fastcgi.conf" /etc/nginx/snippets/
# Keep a refreshed Cloudflare list if one exists; otherwise start from the seed copy.
[ -f /etc/nginx/snippets/cloudflare-realip.conf ] || install -m 0644 "$SRC/snippets/cloudflare-realip.conf" /etc/nginx/snippets/
rm -f /etc/nginx/sites-enabled/default

if [ ! -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
    [ -n "$EMAIL" ] || { echo "first run needs an email for Let's Encrypt: install-nginx.sh you@example.com" >&2; exit 1; }
    install -m 0644 "$SRC/sites/acme-only.conf" /etc/nginx/sites-available/acme-only.conf
    ln -sfn /etc/nginx/sites-available/acme-only.conf /etc/nginx/sites-enabled/acme-only.conf
    nginx -t && systemctl reload nginx
    certbot certonly --webroot -w /var/www/certbot -d "$DOMAIN" \
        --email "$EMAIL" --agree-tos --no-eff-email --non-interactive
    rm -f /etc/nginx/sites-enabled/acme-only.conf
fi

# Reload Nginx after every renewal (certbot's systemd timer runs "certbot renew" twice a day).
install -d -m 0755 /etc/letsencrypt/renewal-hooks/deploy
cat > /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh <<'HOOK'
#!/bin/sh
nginx -t && systemctl reload nginx
HOOK
chmod 0755 /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh

install -m 0644 "$SRC/sites/api.afriva.co.tz.conf" /etc/nginx/sites-available/api.afriva.co.tz.conf
ln -sfn /etc/nginx/sites-available/api.afriva.co.tz.conf /etc/nginx/sites-enabled/api.afriva.co.tz.conf
nginx -t
systemctl reload nginx
echo "Nginx installed for $DOMAIN. Test renewal with: certbot renew --dry-run"

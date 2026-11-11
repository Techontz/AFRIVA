# Afriva

Short-drama streaming platform.

| Folder | Stack | What it is |
|---|---|---|
| [`afriva_web/`](afriva_web/) | Next.js | Viewer website, Super Admin (`/admin`), company Studio (`/studio`) |
| [`backend/`](backend/) | Laravel + MySQL | REST API (`/api/v1`), payments, earnings |
| [`afriva_app/`](afriva_app/) | Flutter | Android / iOS app |

See [`SPEC.md`](SPEC.md) for the API contract and data model, and each folder's README for local setup.

## Production hosting (Tanzania Servers, DirectAdmin + CloudLinux)

| Site | Server folder | How it runs |
|---|---|---|
| `https://api.afriva.co.tz` | `~/domains/api.afriva.co.tz/afriva_api` (docroot `…/afriva_api/public`) | Laravel on PHP 8.3 |
| `https://afriva.co.tz` | `~/afriva_web` | Node.js App (Node 22, startup file `server.js`) |
| `https://admin.afriva.co.tz`, `https://studio.afriva.co.tz` | same app: `admin` uses `~/domains/afriva.co.tz/public_html` as docroot, `studio` has a copy of its `.htaccess` | the app redirects `/admin` and `/studio` to these hosts |
| Android / iOS app | — | release builds call `https://api.afriva.co.tz/api/v1` by default |

The backend's `composer.json` pins `config.platform.php` to 8.3 because the host only offers PHP ≤ 8.3 (Laravel 13 then uses Symfony 7.4).

**Updating the website:** build locally with the production URLs baked in, then replace `~/afriva_web` with the contents of `.next/standalone` and restart the app (`cloudlinux-selector restart --json --interpreter nodejs --app-root afriva_web`, or "Restart" under Setup Node.js App). A restart can leave the previous `next-server` processes running; they pile up until the account hits its process limit ("fork: Resource temporarily unavailable", API 503). After each restart run `pkill -u afrivaco -f next-server` so only fresh processes remain (they start again on the next visit). When Next.js itself was not upgraded, uploading `.next`, `server.js` and `package.json` is enough (`node_modules` stays the same).

```bash
cd afriva_web
NEXT_PUBLIC_API_URL=https://api.afriva.co.tz/api/v1 NEXT_PUBLIC_SITE_URL=https://afriva.co.tz \
  NEXT_PUBLIC_ADMIN_URL=https://admin.afriva.co.tz NEXT_PUBLIC_STUDIO_URL=https://studio.afriva.co.tz npm run build
cp -r .next/static .next/standalone/.next/   # required, or the site loads without CSS/JS
[ -d public ] && cp -r public .next/standalone/
```

**Updating the API:** upload the changed files (or a fresh `composer install --no-dev` bundle, keeping the server's `.env` and `storage/`), then run `composer dump-autoload --no-dev --classmap-authoritative && php artisan migrate --force && php artisan optimize && pkill -u afrivaco lsphp` in `~/domains/api.afriva.co.tz/afriva_api`. The last command restarts PHP so OPcache picks up the new code (OPcache is enabled for the account with `selectorctl --interpreter=php --version=8.3 --enable-user-extensions=opcache`, and `public/.user.ini` turns off timestamp checks).

**CDN (Bunny pull zones):** `https://afrivamedia.b-cdn.net` mirrors `https://api.afriva.co.tz` (posters, uploads; set `MEDIA_CDN_URL=https://afrivamedia.b-cdn.net` in the API `.env`), and `https://afrivaweb.b-cdn.net` mirrors `https://afriva.co.tz` (build the website with `NEXT_PUBLIC_ASSET_PREFIX=https://afrivaweb.b-cdn.net` so `/_next/static` and `/brand` load from it). Files are cached at the edge (Johannesburg for East Africa); purge a zone in the Bunny dashboard after replacing a file under the same name. A cron job pings the site and API every 2 minutes (`# afriva-keepwarm`) so Passenger and PHP never go cold.

Server `.env` speed settings: `CACHE_STORE=file`, `SESSION_DRIVER=array`, `QUEUE_CONNECTION=sync`, `DB_HOST=localhost`.

## Deploying the website to Vercel (alternative)

1. Import this repo in Vercel and set **Root Directory** to `afriva_web`.
2. Add the environment variable `NEXT_PUBLIC_API_URL` = `https://<your-backend-domain>/api/v1`.
3. The Laravel backend must be hosted separately (VPS, Laravel Forge/Cloud, Railway, etc.) with MySQL. Add the Vercel domain to `CORS_ALLOWED_ORIGINS` in the backend `.env`.

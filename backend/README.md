# Afriva API (Laravel)

The backend for **Afriva**, a short-drama streaming platform. It implements `../SPEC.md` (§4 data model, §5 payments, §6 REST API, §7 seed data).
The web app (`afriva_web`) and the Flutter app (`afriva_app`) both use it.

- Laravel 13 · PHP 8.3+ · Sanctum bearer tokens · MySQL (SQLite works too)
- Base URL: `http://localhost:8000/api/v1`
- Envelope: `{ "data": ..., "meta": {...}? }` · Errors: `{ "message", "code", "errors"? }`

## Setup (MySQL)

```bash
cd backend
composer install
cp .env.example .env          # skip if .env already exists
php artisan key:generate      # skip if APP_KEY is already set

# create the database (root / empty password, as configured in .env)
mysql -u root -e "CREATE DATABASE afriva CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

php artisan migrate --seed    # or: php artisan migrate:fresh --seed
php artisan storage:link      # public URLs for uploaded posters and videos
php artisan serve             # http://localhost:8000
```

Seeding takes about 5–10 seconds. It creates 32 dramas, about 1,600 episodes, about 30k episode views, and 60 days of payments, subscriptions, earnings and payouts.

### Running without MySQL (SQLite)

```bash
touch database/database.sqlite
DB_CONNECTION=sqlite DB_DATABASE=$PWD/database/database.sqlite php artisan migrate:fresh --seed
DB_CONNECTION=sqlite DB_DATABASE=$PWD/database/database.sqlite php artisan serve
```

All migrations work on both MySQL and SQLite.

### Tests

```bash
php artisan test        # PHPUnit, in-memory SQLite (.env.testing / phpunit.xml)
```

### Scheduler

```bash
php artisan schedule:work               # local; in production, cron: * * * * * php artisan schedule:run
php artisan earnings:distribute         # distribute yesterday's subscription pool
php artisan earnings:distribute --date=2026-10-01
php artisan bunny:sync                  # every 5 min: re-check Bunny uploads still uploading/processing
```

## Production deployment

```bash
composer install --no-dev --optimize-autoloader --classmap-authoritative
php artisan key:generate            # first deploy only
php artisan migrate --force
php artisan db:seed --force          # first deploy only (see below)
php artisan storage:link
php artisan optimize                 # caches config, routes, events and views in one step
```

Run `php artisan optimize` again after every deploy or `.env` change (`php artisan optimize:clear` undoes it). Run artisan as the same system user as the web server (the DirectAdmin account user) so the file cache stays writable for both.

Set these in the production `.env`:

```dotenv
APP_ENV=production
APP_DEBUG=false
APP_URL=https://api.example.com
APP_LOCALE=en
APP_FALLBACK_LOCALE=en

LOG_CHANNEL=stack
LOG_STACK=single
LOG_LEVEL=warning

DB_CONNECTION=mysql
DB_HOST=localhost
DB_PORT=3306

SESSION_DRIVER=array
CACHE_STORE=file
QUEUE_CONNECTION=sync
BROADCAST_CONNECTION=log
FILESYSTEM_DISK=public

PAYMENTS_SANDBOX_AUTO_APPROVE=false
```

| Key | Value |
|---|---|
| `APP_ENV` / `APP_DEBUG` | `production` / `false` |
| `APP_URL` | public https URL of the API (used for uploaded file URLs) |
| `CORS_ALLOWED_ORIGINS` | the web app's domain(s), e.g. `https://afriva.vercel.app` |
| `TRUSTED_PROXIES` | your load balancer / proxy IPs, or `*` behind a managed platform (Forge, Railway, Cloudflare) |
| `ADMIN_EMAIL` / `ADMIN_PASSWORD` | the first super admin (password 12+ characters) |
| `PAYMENTS_SANDBOX_AUTO_APPROVE` | `false` (`true` gives every plan away for free) |
| `LOG_LEVEL` | `warning` or `error` |
| `CACHE_STORE` | `file` (or `redis` if available). Never `database`: the rate limiter alone costs about 6 queries per request on it |
| `SESSION_DRIVER` | `array`. The API uses bearer tokens only and `/` skips the session middleware. Use `file` if server rendered pages are ever added |
| `QUEUE_CONNECTION` | `sync` (nothing is queued yet, so no worker is needed) |
| `DB_HOST` | `localhost` lets PHP use the MySQL unix socket, which is faster than TCP to `127.0.0.1` |

Performance notes:

- Public catalogue responses (`/home`, `/dramas/rankings`, `/dramas/{slug}`, `/categories`, `/plans`, `/payment-methods`) are cached for 5 minutes. Saving or deleting a drama, episode, category, tag, plan, payment method or company invalidates them immediately. View counters can lag by up to 5 minutes on these pages.
- Make sure OPcache is enabled for the PHP 8.3 handler (DirectAdmin: PHP selector or `php.ini`, `opcache.enable=1`, `opcache.validate_timestamps=0` with a PHP reload after each deploy).
- The API honours `Accept-Language` (`en`, `sw`; anything else falls back to English) and sends `Vary: Accept-Language`. Machine readable `code` values are the same in every language.

Other notes:

- In production, `db:seed` creates only the reference data (settings, categories, plans, payment methods) and the `ADMIN_EMAIL` super admin. It never creates the demo accounts below, and it refuses to run without `ADMIN_EMAIL` and `ADMIN_PASSWORD`.
- Add the scheduler to cron: `* * * * * cd /path/to/backend && php artisan schedule:run >> /dev/null 2>&1`. It distributes subscription earnings daily and expires subscriptions hourly.
- Every `/api` route is rate limited to 240 requests per minute per user (or per IP for guests). Login and register have stricter limits.
- Raise `upload_max_filesize` and `post_max_size` in `php.ini` (and `client_max_body_size` in nginx) if studios upload videos directly.
- Uploaded videos are served from `public/storage` and are not access controlled. For paid content at scale, move them to private storage or a CDN with signed URLs.

## Seeded demo accounts (local only, password for all: `password`)

| Role | Login |
|---|---|
| Super admin | `admin@afriva.com` |
| Company: Kilima Studios (TZ, 70%) | `kilima-studios@afriva.com` |
| Company: Savannah Pictures (KE, 65%) | `savannah-pictures@afriva.com` |
| Company: Lagos Reel House (NG, 70%) | `lagos-reel-house@afriva.com` |
| Company: Zanzibar Tales (TZ, 75%) | `zanzibar-tales@afriva.com` |
| Viewer (200 coins) | `viewer@afriva.com` (phone `+255712000001`) |
| VIP viewer (active Monthly VIP) | `vip@afriva.com` (phone `+255754000002`) |
| 180 synthetic viewers | `viewer1@demo.afriva.com` … `viewer180@demo.afriva.com` |

Login accepts an email or a phone number: `POST /auth/login {"login": "...", "password": "..."}`.

## Payments

- `app/Payments/Contracts/PaymentGateway.php` defines the interface: `initiate`, `verify` and `handleCallback`.
- `app/Payments/GatewayResponse.php` is the result object (`success` / `pending` / `failed`, `nextAction`, `redirectUrl`).
- `app/Payments/PaymentManager.php` picks the driver for a method code, using `config/payments.php`.
- Drivers live in `app/Payments/Gateways/`: `MpesaGateway`, `TigoPesaGateway`, `AirtelMoneyGateway`, `HaloPesaGateway`, `CardGateway`, `BankGateway` and `SandboxGateway`. None of the real providers is connected yet, so their drivers return `pending('Provider not yet connected')`.
- `app/Services/PaymentService.php` handles `checkout()` and `fulfill()`. `fulfill()` creates a time subscription or an episode pack, or adds coins (plus bonus coins). It is safe to call more than once.
- `PAYMENTS_SANDBOX_AUTO_APPROVE=true` (the default in `.env`) sends every method not flagged `is_integrated` to the sandbox. The sandbox approves at once, so checkout completes immediately.
- With `PAYMENTS_SANDBOX_AUTO_APPROVE=false`, payments go to the real driver and stay `pending` until that provider is connected.
- `POST /api/v1/payments/callback/sandbox {"reference":"AFV-…","status":"success"}` settles a pending payment by hand, but only one that was routed through the sandbox driver. It is disabled when `APP_ENV=production` unless `PAYMENTS_SANDBOX_CALLBACKS=true`.
- A provider callback can only settle payments that were routed through that same provider.
- Provider credentials are `.env` keys: `MPESA_*`, `TIGOPESA_*`, `AIRTEL_*`, `HALOPESA_*`, `CARD_*` and `BANK_*`.
- Provider webhooks go to `POST /api/v1/payments/callback/{provider}`.

## Revenue attribution

- **Coin unlock:** creates a `company_earnings` row (`source=coins`) right away. Amount = `coins_spent × coin_value_tzs (setting, default 10) × company share %`.
- **Episode-pack unlock:** creates a row (`source=episode_pack`) right away. Amount = `plan.price / episode_quota × share %`.
- **Weekly, monthly and yearly subscriptions:** `earnings:distribute` runs daily at 00:30. It adds up each active subscription's daily value (`price / duration_days`) into a pool. Each drama gets a slice of the pool based on its share of subscriber views that day, and the drama's company keeps its share % of that slice. Re-running for the same date replaces that date's rows.

## Uploads

Studio and admin endpoints for dramas and episodes accept `multipart/form-data`. Dramas take `poster` and `backdrop` images; episodes take a `video` (mp4/mov/webm, max 500 MB) and a `thumbnail`. You can send `poster_url` or `video_url` strings instead. Files are stored on the `public` disk (`storage/app/public/{posters,videos,...}`) and returned as `APP_URL/storage/...`.
PHP does not parse multipart bodies on PUT, so send updates as `POST` with `_method=PUT`. In multipart requests, `tags` and `category_ids` may be comma-separated strings.

For large video uploads, raise `upload_max_filesize` and `post_max_size` in `php.ini`.

## Bunny Stream (episode videos)

Episode videos are uploaded straight from the browser or app to [Bunny Stream](https://bunny.net/docs/stream) over TUS. The API only creates the video and signs the upload, so the Bunny API key never leaves the server.

**Environment (`.env`):**

| Variable | Value |
| - | - |
| `BUNNY_STREAM_LIBRARY_ID` | Stream > your library > API > Library ID |
| `BUNNY_STREAM_API_KEY` | Same page, API key (server only) |
| `BUNNY_STREAM_CDN_HOSTNAME` | Same page, CDN hostname without `https://`, e.g. `vz-xxxx.b-cdn.net` |
| `BUNNY_STREAM_TOKEN_KEY` | Security > CDN token authentication key. Empty = unsigned playback URLs |
| `BUNNY_STREAM_TOKEN_TTL` | Signed playback URL lifetime in seconds (default `14400`) |
| `BUNNY_STREAM_WEBHOOK_SECRET` | Optional: the library's Read-Only API key. When set, webhooks without a valid `X-BunnyStream-Signature` are ignored |

Uploads are enabled only when the library id, API key and CDN hostname are all set; otherwise `video-upload` answers 503 `video_storage_not_configured` and pasted `video_url`s keep working.

**Bunny library settings:**
- **Webhook URL:** `https://api.afriva.co.tz/api/v1/webhooks/bunny`. The payload is never trusted on its own: the API looks up the episode by video id and reads the real status with Get Video. `php artisan bunny:sync` (scheduled every 5 minutes) catches missed webhooks.
- **Security > Token Authentication (CDN):** enable it and copy its key into `BUNNY_STREAM_TOKEN_KEY`. HLS URLs are then signed per request with a directory token (`/bcdn_token=...&token_path=/{guid}/&expires=.../{guid}/playlist.m3u8`) that covers every segment. Thumbnails and any other file on the CDN hostname are signed with a long lived token that changes once a week.
- **Block direct URL file access / allowed domains:** keep "Block direct URL file access" off. The app plays the HLS URL directly and the Flutter app sends no `Referer`, so access control relies on the signed tokens, not on referrers. Leave "Allowed domains" empty or list every web domain that plays video.
- **CORS:** the web player loads `playlist.m3u8` and segments from the CDN hostname with JavaScript, so the CDN must answer with CORS headers (check the library's pull zone settings if the browser reports a CORS error).

**Upload flow (studio `studio/...` or admin `admin/...`):**
1. `POST dramas/{drama}/episodes/{episode}/video-upload` returns `{video_id, library_id, tus_endpoint, signature, expires, title}` (valid 6 hours). Episode `video_status` becomes `uploading`.
2. The client uploads with tus-js-client (or any TUS client) to `tus_endpoint` with headers `AuthorizationSignature`, `AuthorizationExpire`, `VideoId`, `LibraryId` and metadata `filetype`, `title`.
3. `POST .../video-upload/complete` (optional body `video_id`) sets `processing`.
4. The webhook (or `bunny:sync`) sets `ready`, `video_url`, `duration_seconds` and, if the episode has no own thumbnail, `thumbnail_url`; or `failed`.

`video_status` is one of `none`, `uploading`, `processing`, `ready`, `failed`. When an episode is re-uploaded the old video keeps playing until the new one is ready, then the old one is deleted at Bunny. Deleting an episode or drama deletes its Bunny videos (best effort). Viewers get `video_url: null` ("coming soon") for episodes without a playable video, and never get a URL for a locked episode.

## Route overview (`/api/v1`)

**Public, auth optional.** If a bearer token is sent, `is_favorite` and `is_unlocked` reflect that user.
- `POST auth/register`, `POST auth/login`
- `GET home`, `GET categories`
- `GET dramas?category=&q=&sort=popular|newest&page=&per_page=`
- `GET dramas/rankings?type=trending|new|popular`, `GET dramas/{slug}`
- `GET feed`, `GET plans`, `GET payment-methods`
- `GET episodes/{id}/play`: returns 402 with `episode_locked` when the user cannot watch it; `video_url` is null while the episode has no video yet
- `POST payments/callback/{provider}`
- `POST webhooks/bunny` (Bunny Stream video status)

**Viewer (auth):**
- `POST auth/logout`, `GET auth/me`
- `POST episodes/{id}/unlock {method: coins|episode_pack}`, `POST episodes/{id}/progress`
- `POST checkout`, `GET payments/{reference}`
- `GET me/subscription`, `GET me/payments`, `GET me/history`, `GET me/favorites`, `POST me/favorites/{drama_id}` (toggles)

**Admin (`role:super_admin`), prefix `admin/`:**
- `GET dashboard`
- `companies` CRUD and `companies/{id}/stats`. Creating a company also creates its login from `owner_name`, `owner_email`, `owner_password`.
- `plans` and `categories` CRUD
- `dramas` CRUD and `dramas/{id}/episodes` CRUD, `POST dramas/{id}/episodes/{id}/video-upload[/complete]`
- `GET` and `PUT payment-methods/{id}`
- `GET users`, `GET users/{id}`, `PUT users/{id}` (`status`, `role`, `coins`, `coins_adjust`)
- `GET payments`
- `GET payouts`, `POST payouts`, `PUT payouts/{id}`
- `GET settings`, `PUT settings`

**Studio (`role:company`), prefix `studio/`.** Everything is limited to the user's own company; another company's drama returns 404.
- `GET dashboard`
- `dramas` CRUD and `dramas/{id}/episodes` CRUD, `POST dramas/{id}/episodes/{id}/video-upload[/complete]`
- `GET earnings`, `GET payouts`
- `GET profile`, `PUT profile`

CORS allows `http://localhost:3000` and any `localhost` / `127.0.0.1` / `10.0.2.2` port (Flutter web and the Android emulator). Add more origins with `CORS_ALLOWED_ORIGINS`.

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
```

## Seeded accounts (password for all: `password`)

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
- With `PAYMENTS_SANDBOX_AUTO_APPROVE=false`, payments stay `pending`. To finish a sandbox payment by hand, call `POST /api/v1/payments/callback/sandbox {"reference":"AFV-…","status":"success"}`.
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

## Route overview (`/api/v1`)

**Public, auth optional.** If a bearer token is sent, `is_favorite` and `is_unlocked` reflect that user.
- `POST auth/register`, `POST auth/login`
- `GET home`, `GET categories`
- `GET dramas?category=&q=&sort=popular|newest&page=&per_page=`
- `GET dramas/rankings?type=trending|new|popular`, `GET dramas/{slug}`
- `GET feed`, `GET plans`, `GET payment-methods`
- `GET episodes/{id}/play`: returns 402 with `episode_locked` when the user cannot watch it
- `POST payments/callback/{provider}`

**Viewer (auth):**
- `POST auth/logout`, `GET auth/me`
- `POST episodes/{id}/unlock {method: coins|episode_pack}`, `POST episodes/{id}/progress`
- `POST checkout`, `GET payments/{reference}`
- `GET me/subscription`, `GET me/payments`, `GET me/history`, `GET me/favorites`, `POST me/favorites/{drama_id}` (toggles)

**Admin (`role:super_admin`), prefix `admin/`:**
- `GET dashboard`
- `companies` CRUD and `companies/{id}/stats`. Creating a company also creates its login from `owner_name`, `owner_email`, `owner_password`.
- `plans` and `categories` CRUD
- `dramas` CRUD and `dramas/{id}/episodes` CRUD
- `GET` and `PUT payment-methods/{id}`
- `GET users`, `GET users/{id}`, `PUT users/{id}` (`status`, `role`, `coins`, `coins_adjust`)
- `GET payments`
- `GET payouts`, `POST payouts`, `PUT payouts/{id}`
- `GET settings`, `PUT settings`

**Studio (`role:company`), prefix `studio/`.** Everything is limited to the user's own company; another company's drama returns 404.
- `GET dashboard`
- `dramas` CRUD and `dramas/{id}/episodes` CRUD
- `GET earnings`, `GET payouts`
- `GET profile`, `PUT profile`

CORS allows `http://localhost:3000` and any `localhost` / `127.0.0.1` / `10.0.2.2` port (Flutter web and the Android emulator). Add more origins with `CORS_ALLOWED_ORIGINS`.

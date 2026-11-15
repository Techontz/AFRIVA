# Environment variables

## Where settings live

| Place | File or screen | Who reads it |
|---|---|---|
| API server | `/srv/afriva/shared/.env` (template: `deploy/.env.production.example`) | Laravel in the app, worker and scheduler containers; Docker Compose for DB and Redis passwords |
| Backup credentials | `/srv/afriva/secrets/backup.env` (template: `deploy/backup.env.example`) | `backup-db.sh`, `restore-db.sh` only |
| Backup key | `/srv/afriva/secrets/backup-age.key` and `.pub` | Backup and restore scripts. Copy of the private key in the owner's password manager. |
| Website | Vercel > Project > Settings > Environment Variables | Next.js build |
| Deploy workflow | GitHub > Settings > Environments > production > secrets | `deploy-api.yml` |
| Flutter app | `--dart-define=API_URL=...` at build time | App binary (default `https://api.afriva.co.tz/api/v1`) |

All values in templates are empty on purpose. Generate passwords with `openssl rand -hex 32` (hex only, so no quoting problems with `$` or `#`).

## Applying a change on the server

```bash
nano /srv/afriva/shared/.env
/srv/afriva/repo/deploy/scripts/compose.sh up -d --force-recreate app worker scheduler
```

Config is cached when each container starts, so a restart is required. `DB_*`, `REDIS_PASSWORD` and `MYSQL_ROOT_PASSWORD` are special: MySQL only reads them when its volume is first created. To change the database password later, change it in MySQL first (`ALTER USER`), then in `.env`. To change `REDIS_PASSWORD`, edit `.env` and recreate redis too: `compose.sh up -d --force-recreate redis app worker scheduler`.

## API server variables (main groups)

The template lists every variable the app reads, with comments. Key ones:

| Variable | Production value | Notes |
|---|---|---|
| `APP_ENV` / `APP_DEBUG` | `production` / `false` | Never `true` in production: it leaks stack traces. |
| `APP_KEY` | copy from the old host | Changing it makes encrypted data unreadable. Rotate only with `APP_PREVIOUS_KEYS`. |
| `APP_URL` | `https://api.afriva.co.tz` | |
| `APP_COMMIT` | leave empty | Compose sets it to the deployed image tag; shown by `/api/v1/health`. |
| `DB_HOST` / `DB_DATABASE` / `DB_USERNAME` / `DB_PASSWORD` | `mysql` / `afriva` / `afriva` / generated | `DB_HOST` is the compose service name. |
| `MYSQL_ROOT_PASSWORD` | generated | Compose only. Used by backups and restores. |
| `REDIS_HOST` / `REDIS_PASSWORD` | `redis` / generated | Redis will not start without a password. |
| `CACHE_STORE` / `QUEUE_CONNECTION` | `redis` / `redis` | |
| `SESSION_DRIVER` | `array` | Token API, no sessions. |
| `TRUSTED_PROXIES` | empty | Nginx already passes the real client IP. A value here would let clients spoof IPs. |
| `CORS_ALLOWED_ORIGINS` | the four site origins | Comma separated. |
| `LOG_STACK` / `LOG_DAILY_DAYS` | `daily` / `14` | Files in `/srv/afriva/shared/storage/logs`. |
| `MEDIA_DISK` / `PRIVATE_DOCUMENTS_DISK` | `public` / `local` before migration, `r2_public` / `r2_private` after | |
| `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY` | app token | Scoped to the media and private buckets. |
| `R2_ENDPOINT` | `https://<ACCOUNT_ID>.r2.cloudflarestorage.com` | |
| `R2_PUBLIC_BUCKET`, `R2_PRIVATE_BUCKET`, `R2_BACKUP_BUCKET` | `afriva-media`, `afriva-private`, `afriva-backups` | Backup bucket name is informational here; its credentials are in `backup.env`. |
| `R2_PUBLIC_URL` | `https://media.afriva.co.tz` | |
| `BUNNY_STREAM_*` | from Bunny | See [video-management.md](video-management.md). Set `BUNNY_STREAM_TOKEN_KEY` and `BUNNY_STREAM_WEBHOOK_SECRET` in production. |
| `PAYMENTS_SANDBOX_AUTO_APPROVE`, `PAYMENTS_SANDBOX_CALLBACKS` | `false`, `false` | No gateway is connected yet; checkout shows "Coming soon". |
| `MAIL_*` | your mail provider | `MAIL_FROM_ADDRESS=support@afriva.co.tz`. |
| `INFRA_MONTHLY_BUDGET_USD`, `INFRA_ALERT_EMAIL` | your budget, your email | Budget alerts at 50, 75, 90, 100%. |
| `HETZNER_API_TOKEN`, `HETZNER_SERVER_ID` | read-only token | For the admin Infrastructure page. |
| `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID` | read-only token | Analytics read and R2 read only. |
| `BUNNY_ACCOUNT_API_KEY` | Bunny account key | Full account access: server only, never in Vercel or the app. |
| `AFRIVA_UID`, `AFRIVA_GID`, `AFRIVA_ROOT` | `id -u`, `id -g` of deploy, `/srv/afriva` | Compose and image build only. |

## Website (Vercel)

| Variable | Value |
|---|---|
| `NEXT_PUBLIC_API_URL` | `https://api.afriva.co.tz/api/v1` |
| `NEXT_PUBLIC_SITE_URL` | `https://afriva.co.tz` |
| `NEXT_PUBLIC_ADMIN_URL` | `https://admin.afriva.co.tz` |
| `NEXT_PUBLIC_STUDIO_URL` | `https://studio.afriva.co.tz` |
| `NEXT_PUBLIC_ASSET_PREFIX` | leave unset on Vercel |

`NEXT_PUBLIC_*` values are compiled into the browser bundle: never put a secret in one. Changing them needs a redeploy in Vercel.

## GitHub (environment "production")

`DEPLOY_HOST`, `DEPLOY_USER`, `DEPLOY_SSH_KEY`, `DEPLOY_KNOWN_HOSTS`. See [deployment.md](deployment.md#github-setup-for-the-deploy-workflow-owner-once).

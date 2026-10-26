# Deploying Afriva to Hetzner Cloud

One Ubuntu 24.04 server runs everything:

| Part | How it runs |
|---|---|
| Laravel API (`backend/`) | Nginx + PHP 8.3-FPM at `https://API_DOMAIN` |
| Website (`afriva_web/`) | Next.js (`afriva-web` service) behind Nginx at `https://WEB_DOMAIN` |
| Database | MySQL 8, local connections only |
| Scheduler / queue | cron `schedule:run` every minute, `afriva-queue` service |
| Videos | `backend/storage/app/private/videos`, served by Nginx only via signed, expiring URLs |
| Posters/thumbnails | `backend/storage/app/public`, public at `/storage/...` |

## First-time setup

1. **DNS** (at your domain registrar): `A` records for `WEB_DOMAIN`, `www.WEB_DOMAIN` and `API_DOMAIN` pointing at the server's IPv4.
2. **Provision** (once, as root):
   ```bash
   rsync -az -e "ssh -i ~/.ssh/afriva_hetzner" deploy/ root@SERVER_IP:/root/afriva-deploy/
   ssh -i ~/.ssh/afriva_hetzner root@SERVER_IP \
     'WEB_DOMAIN=example.com API_DOMAIN=api.example.com LE_EMAIL=you@example.com bash /root/afriva-deploy/provision.sh'
   ```
3. **Deploy** the code: `deploy/deploy.sh SERVER_IP`
4. **Create your admin login** (prompts for the password on the server):
   ```bash
   ssh -t -i ~/.ssh/afriva_hetzner afriva@SERVER_IP 'cd /var/www/afriva/backend && php artisan afriva:create-admin you@example.com'
   ```

## Every later release

```bash
deploy/deploy.sh SERVER_IP
```

It uploads the code, runs `composer install`, migrations and caches, builds the website and restarts the services. It never overwrites the server's `.env`, uploaded files or data.

## Flutter app

Build against the live API:

```bash
flutter build apk --dart-define=API_URL=https://API_DOMAIN/api/v1
```

## Operations

| Task | Command (as `afriva@SERVER_IP`) |
|---|---|
| App logs | `tail -f /var/www/afriva/backend/storage/logs/laravel-$(date +%F).log` |
| Website logs | `journalctl -u afriva-web -f` |
| Nginx errors | `sudo tail -f /var/log/nginx/error.log` (needs root) |
| Backups | `ls /var/backups/afriva` (nightly at 02:15, 14 days kept) |
| Restore a backup | `gunzip -c FILE.sql.gz \| mysql -u afriva -p afriva` |
| Disk warnings | `journalctl -t afriva-disk` |

Edit production settings in `/var/www/afriva/backend/.env`, then run `php artisan optimize && sudo systemctl reload php8.3-fpm`.

## Notes

- `PAYMENTS_SANDBOX_AUTO_APPROVE=false` and `PAYMENTS_SANDBOX_ENABLED=false` in production. If either were `true`, payments could be approved without being paid. Real payments need a provider's credentials in `.env`; then, after a successful live test, switch the method to "integrated" in Admin → Njia za malipo. Until then the apps show it as "Inakuja hivi karibuni" and refuse it at checkout.
- Uploaded videos are transcoded to HLS (480p/720p/1080p) by the `afriva-queue` worker with ffmpeg (`MEDIA_TRANSCODE=true`). Watch failures in Admin → Video Library (`video_status = failed`, with the ffmpeg error) and use "Reprocess".
- Cost alerts: set `cost_alert_monthly_tzs` in Admin → Mipangilio; `costs:check` runs daily at 07:00 and logs a warning (and an audit entry) at 80% of the limit.
- First admin: `afriva:create-admin` creates an **owner**. Add editors, reviewers and finance staff in Admin → Wafanyakazi.
- Database dumps stay on the same server. Turn on **Hetzner Backups** for the server so videos and dumps also exist off the disk.
- When videos outgrow the disk, attach a Hetzner Volume and move `storage/app/private/videos` onto it; the Nginx `alias` path must follow.

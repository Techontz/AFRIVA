# Architecture

```
                    Viewers (web, Android, iOS)
                              |
                 Cloudflare DNS + proxy (free plan)
      +-----------------------+-------------------------+-----------------------------+
      |                                                 |                             |
afriva.co.tz, www., admin., studio.            api.afriva.co.tz (proxied)       media.afriva.co.tz
      |                                                 |                             |
   Vercel (Next.js)                        Hetzner Cloud server, Ubuntu 24.04     Cloudflare R2
                                           Host Nginx + Let's Encrypt             public bucket: posters,
                                             | FastCGI 127.0.0.1:9000             banners, logos, avatars
                                           Docker Compose                         private bucket: ID documents
                                             app        php-fpm (Laravel API)       (signed, expiring URLs)
                                             worker     queue:work redis          backup bucket: encrypted
                                             scheduler  schedule:work               database dumps
                                             mysql      MySQL 8.4 (no port)
                                             redis      Redis 7 (no port, password)
                                                         |
                                                   Bunny Stream (video upload, encoding, HLS delivery)
```

## Components

| Part | Runs on | Notes |
|---|---|---|
| Website, admin, studio | Vercel | One Next.js app. `admin.` and `studio.` are routed by host name inside the app. Deployed automatically by Vercel's GitHub integration on every push to `main`. |
| API | Hetzner server, `app` container | Laravel 13 on PHP 8.3 FPM with OPcache. Sanctum bearer tokens, no server sessions. |
| Queue worker | `worker` container | `php artisan queue:work redis`. Horizon is not installed; the container restart policy keeps the worker alive and it exits every hour by design to stay fresh. |
| Scheduler | `scheduler` container | `php artisan schedule:work`: `earnings:distribute` daily 00:30 UTC (03:30 Dar es Salaam), `subscriptions:expire` hourly, `bunny:sync` every 5 minutes. Exactly one scheduler must run. |
| Database | `mysql` container | MySQL 8.4 LTS, data in the `afriva_mysql-data` Docker volume. Not reachable from outside the server. |
| Cache, rate limits, queue | `redis` container | Redis 7 with password, append-only persistence, 512 MB cap. Evicts only cache keys (with TTL), never queued jobs. |
| TLS and HTTP | Host Nginx | Let's Encrypt certificate (certbot webroot), security headers, rate limits, real client IP from Cloudflare, serves `/storage/` files directly. |
| Video | Bunny Stream | Browsers upload video straight to Bunny with TUS; the API never handles video bytes. See [video-management.md](video-management.md). |
| Images and documents | Local disk now, Cloudflare R2 after migration | Public images on `r2_public`, ID documents on `r2_private`. |
| DNS, CDN, WAF | Cloudflare | `api.` is proxied (orange cloud). SSL mode "Full (strict)". |

## Why host Nginx (not an Nginx container)

* Certbot on the host is the simplest reliable Let's Encrypt setup: `apt install certbot`, webroot challenge, a systemd timer for renewal, and a reload hook. No shared certificate volumes.
* Nginx and its logs survive container rebuilds, so a broken image never takes TLS or the maintenance page down.
* Only one port is published by Docker (`127.0.0.1:9000`). Docker bypasses UFW for published ports, so binding to 127.0.0.1 keeps PHP-FPM private.
* The host does not need the code: Nginx sends every request to `/var/www/html/public/index.php` inside the container.

## Request path

1. Client resolves `api.afriva.co.tz` to Cloudflare. Cloudflare terminates TLS, applies its WAF, then connects to the server over HTTPS (Full strict).
2. Nginx restores the real client IP from `CF-Connecting-IP` (trusted only from Cloudflare ranges), applies rate limits, adds security headers and passes the request to PHP-FPM.
3. Laravel answers. Video playback responses contain signed, expiring Bunny HLS URLs; the player then streams directly from Bunny's CDN.

## Releases

* Each API release is a Docker image `afriva-api:<12 char commit sha>` built on the server.
* `/srv/afriva/state/current_tag` and `previous_tag` record what runs and what to roll back to.
* The last 5 images stay on the server for instant rollback.

## Server layout

```
/srv/afriva/
  repo/                 git checkout (detached at the deployed commit)
  shared/.env           production settings (600)
  shared/storage/       Laravel storage/ (bind mounted into the containers)
  secrets/              backup.env, backup-age.key, backup-age.pub (700)
  backups/              local encrypted dumps, 3 days
  state/                current_tag, previous_tag, releases.log, deploy.log, last_backup
```

## Monitoring

* Netdata on `127.0.0.1:19999` (SSH tunnel only). Chosen over a Prometheus stack because it needs no second server and is one package; it costs about 100 to 150 MB of RAM, fine on 8 GB.
* Compose healthchecks on every container; `restart: unless-stopped` restarts crashed ones.
* The admin Infrastructure page (built by the app) shows server, database, Redis, R2 and Bunny figures and sends budget alerts.
* Recommended external uptime check (free tier of any uptime service) on `https://api.afriva.co.tz/up`.

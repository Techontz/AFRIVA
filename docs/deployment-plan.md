# Afriva: production deployment assessment and plan

Status: Phase 1 (inspect) and Phase 2 (plan) only. Nothing has been purchased, created or changed for this plan. Prices are estimates from public price lists and must be confirmed on each provider's pricing page before approval.

## 1. What exists today (inspected 2026-11-15)

| Part | Today |
|---|---|
| Backend | Laravel 13 (PHP 8.3 pinned), Sanctum bearer API at `/api/v1`, 13 migrations, MySQL. Health route `/up`. Scheduler defines `earnings:distribute` (daily 00:30) and `bunny:sync` (every 5 min). No queued jobs yet (`QUEUE_CONNECTION=sync`). Cache `file`, sessions `array`. |
| Web | Next.js 16.4 (React 19, cacheComponents/PPR, `output: standalone`). One app serves the viewer site, `/admin` and `/studio`; `src/proxy.ts` routes `admin.` and `studio.` hosts. Images are already WebP and served unoptimized. Uses `tus-js-client` for direct video uploads. |
| App | Flutter (Dart ^3.13), API URL from `--dart-define=API_URL`, default `https://api.afriva.co.tz/api/v1`. HLS playback with quality picker. |
| Video | Bunny Stream is already integrated through `app/Services/BunnyStream.php`: video creation, direct TUS upload credentials from Laravel (admin and studio upload straight to Bunny, Laravel never proxies video), signed webhook endpoint `POST /api/v1/webhooks/bunny`, status sync command, expiring signed HLS playback URLs, protected videos, deletion and cleanup. |
| Images and documents | Stored on the server's local `public` disk (posters, banners, avatars) and a private disk (creator ID documents), served through the Bunny pull zone `afrivamedia.b-cdn.net`. No S3/R2 driver installed. |
| Hosting | Shared DirectAdmin account at Tanzania Servers (CloudLinux, LiteSpeed, Passenger). Server load ~12 on 8 cores, process limits, cold starts. This is the main cause of slowness. |
| DNS | `afriva.co.tz` (plus `api.`, `admin.`, `studio.`) on the Tanzania Servers DNS. |
| Payments | Mobile money and card checkout built, but no gateway connected (see `afriva-payments-status`). Unrelated to this plan. |
| Code | Private GitHub repo `Conradbubex/afriva`, branch `main`. |

### Gaps against the brief

1. No Redis, no queue worker, and the scheduler may not be running on the shared host (only a keep-warm cron was added). `bunny:sync` and `earnings:distribute` need a real scheduler.
2. Images live on the server disk, not object storage. Moving them to R2 needs the S3 Flysystem package, two buckets (public media, private documents) and a one-time copy of existing files.
3. No container or server configuration, no backups beyond manual tarballs, no monitoring, no CI.
4. No infrastructure or cost dashboard in the admin panel.
5. Email (`support@afriva.co.tz`) depends on the current DNS; moving DNS to Cloudflare must copy any MX records first.

## 2. Two decisions before anything is built

**A. Where the website runs.** Vercel's free Hobby plan does not allow commercial use, so a paying streaming site needs Vercel Pro, about **US$20 per month per team member**. The alternative is to run Next.js in Docker on the same Hetzner server for no extra cost. Vercel gives a global edge and zero-ops deploys; the Hetzner option is cheaper. The brief asks for Vercel, so the plan below assumes Vercel Pro unless you choose otherwise.

**B. Server location.** Hetzner has no African region (Germany, Finland, USA, Singapore). From Tanzania the API round trip to Germany is roughly 150 to 200 ms. Video is unaffected (Bunny serves it from Johannesburg and other edges) and Cloudflare caches images at the edge, but every API call crosses to Europe. A dedicated, unloaded server in Germany is still expected to be much faster than today's overloaded shared host, but this should be measured after setup.

## 3. Target architecture

```
                 Viewers (web, Android, iOS)
                          |
                    Cloudflare DNS + proxy (free plan)
        +-----------------+------------------+-----------------------------+
        |                                    |                             |
 afriva.co.tz, www, admin., studio.     api.afriva.co.tz            media.afriva.co.tz
        |                                    |                             |
     Vercel (Next.js)              Hetzner Cloud server (Ubuntu LTS)   Cloudflare R2 (public bucket)
                                   Nginx + Let's Encrypt               posters, banners, avatars
                                   Docker Compose:                     R2 private bucket: ID documents
                                     php-fpm (Laravel API)               (signed, expiring URLs only)
                                     queue worker (supervised)
                                     scheduler
                                     MySQL 8 (not exposed)
                                     Redis 7 (not exposed, password)
                                          |
                                   Bunny Stream (upload via TUS direct from browser,
                                   HLS playback with expiring signed tokens, webhooks to API)
```

One server is enough for the current audience. A second server is only worth adding later for high availability or if the database outgrows it; the plan does not create one.

## 4. Estimated monthly cost (confirm before approval)

| Item | Estimate | Notes |
|---|---|---|
| Hetzner Cloud, shared vCPU, 4 vCPU / 8 GB / 80 GB (CX32 class) | about EUR 7 to 9 | Billed hourly with a monthly cap. A stopped server is still billed; only deleting it stops billing. |
| Hetzner automatic backups | +20% of server, about EUR 1.5 to 2 | 7 daily snapshots of the whole server. Database dumps to R2 are added on top at no extra cost. |
| Primary IPv4 | about EUR 0.5 | |
| Vercel Pro | US$20 per member | Or US$0 if Next.js runs on the Hetzner server. |
| Cloudflare DNS, SSL, proxy, basic WAF | US$0 | Free plan. |
| Cloudflare R2 | US$0 up to 10 GB, then about US$0.015 per GB-month | No egress fees. Needs a payment method on the Cloudflare account even for the free tier. |
| Bunny Stream | usage based | Storage per GB per region, CDN per GB delivered (Africa is priced higher than Europe), encoding included. Today's usage is small; the dashboard below will show the real figure. |
| **Total (excluding Bunny)** | **about US$30 to 35 with Vercel Pro, about US$10 to 13 without** | |

What can be capped: Hetzner server size (fixed), R2 (alerts only), Vercel Pro spend management (can pause projects at a limit). What cannot be hard-capped automatically: Bunny bandwidth (Bunny has balance-based billing with low-balance alerts; streaming stops if the balance runs out, so top-ups or auto-recharge must be managed). The dashboard and alerts report spend; they do not control it.

## 5. Implementation (Phase 3, no charges)

All of this can be prepared and tested locally and committed to GitHub before any account is touched:

1. `deploy/` folder: `docker-compose.prod.yml` (php-fpm, worker, scheduler, mysql, redis), PHP image with required extensions and OPcache, Nginx site config with security headers and rate limits, Certbot renewal, `.env.production.example` (no secrets).
2. Server bootstrap script for a fresh Ubuntu LTS: non-root deploy user, SSH keys only, password login and root login off, UFW (22, 80, 443 only), fail2ban, unattended security upgrades, Docker, swap, log rotation, node-exporter style monitoring or Netdata.
3. Laravel changes: Redis for cache, queue and rate limiting; queue worker and scheduler services; `league/flysystem-aws-s3-v3` with `r2_public` and `r2_private` disks; ID documents served by short-lived signed URLs; a deeper health endpoint (DB, Redis, storage, Bunny reachability); structured production logging.
4. Backups: nightly `mysqldump` compressed and encrypted, uploaded to a private R2 bucket, 14 daily + 8 weekly retention, plus a documented and tested restore script.
5. Admin "Infrastructure" page: server health (CPU, RAM, disk from the server itself), Bunny storage, video count, monthly bandwidth and processing failures (Bunny API), R2 storage (Cloudflare API), database size, Redis memory, Hetzner server price (Hetzner API), with every figure labelled as live usage, estimate, or billed amount. Budget alerts by email at 50, 75, 90 and 100% of a monthly budget you set.
6. CI: GitHub Actions that run backend tests and web lint/build on every push; a manual "Deploy API" workflow that SSHes to the server, pulls, builds, runs `migrate --force` only for non-destructive migrations (destructive ones need a manual flag), runs health checks, and rolls back to the previous image on failure. Vercel deploys the web app from GitHub automatically.
7. Flutter: release flavours for production and staging API URLs (already supported through `--dart-define`), Android signing config template (keystore stays off GitHub), iOS bundle settings check.

## 6. Deployment (Phase 4, needs your approval and access)

| Step | What I need from you |
|---|---|
| Create the Hetzner server | Your approval of the size and cost; a Hetzner Cloud account with a payment method. Either you create the server in the Hetzner console with my SSH public key, or you create an API token and set it in your terminal yourself (I never type tokens). |
| Move DNS to Cloudflare | A Cloudflare account; you add `afriva.co.tz` and change the nameservers at the `.co.tz` registrar (through Tanzania Servers). I first copy every existing record, including email MX records. |
| R2 | Enable R2 in Cloudflare (payment method required), create the access key, and enter it in the server `.env` yourself. |
| Vercel | Approve Vercel Pro (or choose Hetzner hosting). The Vercel connector in this session can create the project and set non-secret environment variables; you link the GitHub repo and add the domains. |
| Data migration | A maintenance window of about 30 minutes: final database dump from the shared host, restore on Hetzner, copy uploaded images to R2, switch DNS. The old host stays untouched as a fallback until you confirm. |
| Bunny | Point the Bunny webhook to the same `api.afriva.co.tz` URL (unchanged if the domain stays the same) and set the webhook secret on the new server. |

## 7. Verification (Phase 5)

Every item in the brief's checklist is tested on the real production environment and reported as pass or fail with evidence: website, API, database, Redis, login, admin video upload to Bunny, processing webhook, playback on web and in the app with signed URLs, images from R2, a backup taken and restored into a scratch database, HTTPS and redirects.

## 8. Security review items already known

- Rate limits exist on login, register, studio application, webhooks and saved payment methods; the rest of the API relies on the default `api` limiter. To review per route.
- Creator ID documents must stay private (planned: private R2 bucket plus expiring URLs).
- The Bunny API key, token key and webhook secret live only in the server `.env`.
- Card numbers and CVCs never reach the API (enforced by validation); mobile money PINs are never collected.
- DRM: signed expiring HLS URLs stop casual link sharing but are not DRM. If any content licence requires DRM (Widevine/FairPlay), Bunny offers MediaCage DRM at extra cost; to decide per licence.

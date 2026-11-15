# Afriva operations

Runbooks for running Afriva in production. Start with the architecture, then follow the deployment guide once.

| Document | Read it when |
|---|---|
| [architecture.md](architecture.md) | You want the big picture: what runs where and why. |
| [deployment.md](deployment.md) | First setup of the server, Cloudflare, R2, Vercel and the data migration; and every later API deploy. |
| [environment-variables.md](environment-variables.md) | You add or change a setting on the server or in Vercel. |
| [server-management.md](server-management.md) | Day to day: logs, restarts, updates, disk, monitoring, SSH access. |
| [backup-recovery.md](backup-recovery.md) | Backups, restores, and disaster recovery. |
| [video-management.md](video-management.md) | Anything about episode videos and Bunny Stream. |
| [costs.md](costs.md) | Monthly cost estimates and what can be capped. |
| [troubleshooting.md](troubleshooting.md) | Something is broken. |

The plan these documents implement is [../deployment-plan.md](../deployment-plan.md).

## Where things live in the repo

| Path | What |
|---|---|
| `deploy/docker/php/Dockerfile` | Production PHP-FPM image (PHP 8.3, OPcache, non-root). |
| `deploy/docker-compose.prod.yml` | app, worker, scheduler, mysql, redis. |
| `deploy/.env.production.example` | Every server setting, empty. Copy to `/srv/afriva/shared/.env`. |
| `deploy/backup.env.example` | Backup bucket credentials template. Copy to `/srv/afriva/secrets/backup.env`. |
| `deploy/nginx/` | Host Nginx config for `api.afriva.co.tz`. |
| `deploy/scripts/` | `bootstrap-server.sh`, `install-nginx.sh`, `deploy.sh`, `rollback.sh`, `backup-db.sh`, `restore-db.sh`, `compose.sh`, `update-cloudflare-ips.sh`. |
| `deploy/systemd/` | Timers for nightly backups and the weekly Cloudflare IP refresh. |
| `.github/workflows/` | `ci.yml` (tests and builds), `deploy-kit.yml` (checks of deploy/), `deploy-api.yml` (manual production deploy). |

## Golden rules

1. Secrets live only on the server (`/srv/afriva/shared/.env`, `/srv/afriva/secrets/`) and in Vercel or GitHub secret stores. Never in git, chat or email.
2. Every API deploy goes through `deploy.sh` (directly or via the "Deploy API" workflow). It backs up the database before migrating and rolls back on failure.
3. Keep a copy of the backup private key (`backup-age.key`) somewhere off the server. Without it the backups cannot be opened.

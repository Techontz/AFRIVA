# Troubleshooting

Shortcut: `c=/srv/afriva/repo/deploy/scripts/compose.sh` (as deploy on the server).

## First look, whatever the problem

```bash
$c ps                                   # all healthy?
curl -s https://api.afriva.co.tz/up     # 200?
curl -s https://api.afriva.co.tz/api/v1/health   # which check fails?
$c logs --tail 100 app
tail -n 50 /srv/afriva/shared/storage/logs/laravel-$(date +%F).log
sudo tail -n 50 /var/log/nginx/api.afriva.error.log
df -h / ; free -h
```

## Symptoms

| Symptom | Likely cause | Fix |
|---|---|---|
| Cloudflare page "521 Web server is down" | Nginx stopped or port 443 blocked | `sudo systemctl status nginx`, `sudo nginx -t`, `sudo ufw status`. |
| Cloudflare "525/526 SSL handshake failed / invalid certificate" | Certificate missing or expired, SSL mode mismatch | `sudo certbot certificates`; renew with `sudo certbot renew`; Cloudflare SSL mode must be Full (strict). |
| "502 Bad Gateway" from Nginx | `app` container down or restarting | `$c ps`, `$c logs app`; then `$c up -d app`. A config error in `.env` makes `php artisan optimize` fail at start: the log says which. |
| "504 Gateway Timeout" | Slow request over 70 s, or PHP-FPM saturated | `$c logs app` (slowlog shows slow scripts), Netdata CPU/RAM, MySQL slow log (below). |
| 500 errors with "server_error" | Application exception | Laravel log file for the stack trace. |
| 503 "service_unavailable" everywhere | Maintenance mode left on | `$c exec app php artisan up`. |
| 429 "too many requests" for many users | Nginx or Laravel rate limit; many users share one carrier NAT IP | Check `api.afriva.error.log` for "limiting requests". Raise `rate`/`burst` in `deploy/nginx/conf.d/afriva-http.conf` or the site file, then `install-nginx.sh`. |
| Logins fail for everyone | Redis down (rate limiter and cache) or DB down | `$c ps`; `$c logs redis`; `$c logs mysql`. |
| Uploads fail with 413 | Image bigger than 25 MB body limit | Expected; app validation is 4 to 8 MB per image. |
| Images 404 after R2 migration | `MEDIA_DISK`, `R2_PUBLIC_URL` or the bucket's custom domain | `curl -I https://media.afriva.co.tz/<path>`; check `.env` and recreate containers. |
| Scheduled tasks not running | Scheduler container down | `$c ps scheduler`, `$c logs scheduler`, `$c exec scheduler php artisan schedule:list`. |
| Queue jobs pile up | Worker down or failing | `$c logs worker`, `$c exec app php artisan queue:failed`. |
| Videos stuck processing | Webhook or Bunny issue | [video-management.md](video-management.md#common-problems). |
| Real client IPs show as Cloudflare IPs in logs | Cloudflare list outdated or snippet missing | `sudo systemctl start afriva-cloudflare-ips.service`. |
| Disk full | Docker images, logs, backups | [server-management.md](server-management.md#disk-space). |
| MySQL "Out of memory" or killed | Too many PHP children plus buffer pool | Lower `pm.max_children` or `innodb_buffer_pool_size`; check `dmesg -T \| grep -i oom`. |

## Deploy problems

| Message from deploy.sh | Meaning and fix |
|---|---|
| `destructive SQL (DROP/RENAME/TRUNCATE) found` | A pending migration drops or renames something. Read the printed SQL. If intended, make sure a backup exists and rerun with `ALLOW_DESTRUCTIVE_MIGRATIONS=1` (or tick the box in the workflow). Note that index drops and SQLite-style table rebuilds also match: the check is cautious on purpose. |
| `has local changes` | Someone edited files in `/srv/afriva/repo`. Show with `git -C /srv/afriva/repo status`; discard with `git -C /srv/afriva/repo checkout -- .` |
| `another deploy or rollback is running` | Wait, or if a previous run crashed: check `ps aux \| grep deploy.sh`; the lock frees itself when that process ends. |
| `migration failed` | Containers still run the old release. Read the error. Fix forward with a new migration, or restore the pre-migration backup (`manual/...pre-migrate-<tag>`) with `restore-db.sh --into-production`. |
| `failed its health check` then `rolled back` | The new code did not answer `/up` or `/api/v1/health` with 200. The old image runs again. Logs were printed above. |
| `/api/v1/health failed with 503` | One dependency check failed (database, cache, storage or Bunny config). The JSON body says which: `curl -s --resolve api.afriva.co.tz:443:127.0.0.1 https://api.afriva.co.tz/api/v1/health`. |
| Build fails at `composer install` | `composer.lock` out of sync with `composer.json`, or a package needs a PHP extension missing from the Dockerfile. |
| GitHub workflow: `Host key verification failed` | `DEPLOY_KNOWN_HOSTS` is outdated (server rebuilt). Update it with `ssh-keyscan -t ed25519 SERVER_IP`. |

## Useful diagnostics

```bash
# MySQL slow queries (over 1 s)
$c exec mysql tail -n 50 /var/lib/mysql/slow.log
# Running queries
$c exec mysql sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot -e "SHOW FULL PROCESSLIST"'
# Redis memory and keys
$c exec redis sh -c 'REDISCLI_AUTH="$REDIS_PASSWORD" redis-cli info memory | head -n 20'
# PHP-FPM pool status
$c exec app sh -c 'SCRIPT_NAME=/fpm-status SCRIPT_FILENAME=/fpm-status REQUEST_METHOD=GET cgi-fcgi -bind -connect 127.0.0.1:9000'
# Container resource use
docker stats --no-stream
# Test the origin directly (bypasses Cloudflare)
curl -sI --resolve api.afriva.co.tz:443:127.0.0.1 https://api.afriva.co.tz/up
```

## Post-migration checklist

- [ ] `https://afriva.co.tz`, `www`, `admin.`, `studio.` load over HTTPS (Vercel).
- [ ] `https://api.afriva.co.tz/up` is 200; `/api/v1/health` is 200 with all checks ok.
- [ ] Register, log in, log out on web and in the app.
- [ ] Posters and banners load (from `media.afriva.co.tz` after R2 migration).
- [ ] Admin: upload a poster (becomes WebP), upload a short test video, it reaches "ready".
- [ ] Episode plays on web and in the app; the playlist URL has a token.
- [ ] Creator ID document opens from admin through a short-lived link.
- [ ] Email: a password or contact email arrives; mail to `support@afriva.co.tz` still arrives.
- [ ] `sudo systemctl start afriva-backup.service` succeeds; `restore-db.sh r2:latest` restores into a scratch DB.
- [ ] `http://api.afriva.co.tz` redirects to HTTPS; security headers present (`curl -sI`).
- [ ] Netdata reachable through the SSH tunnel only; `nmap` from outside shows only 22, 80, 443.

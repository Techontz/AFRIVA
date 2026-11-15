# Server management

Log in as `ssh deploy@SERVER_IP`. Shortcut used below: `c=/srv/afriva/repo/deploy/scripts/compose.sh`.

## Status and logs

| Task | Command |
|---|---|
| Container status and health | `$c ps` |
| Follow API (PHP) logs | `$c logs -f --tail 100 app` |
| Worker or scheduler logs | `$c logs -f worker` / `$c logs -f scheduler` |
| Laravel log files | `ls /srv/afriva/shared/storage/logs/` then `tail -f .../laravel-YYYY-MM-DD.log` |
| Nginx access and errors | `sudo tail -f /var/log/nginx/api.afriva.access.log` / `api.afriva.error.log` |
| Slowest recent requests | `awk '{for(i=1;i<=NF;i++) if($i ~ /^rt=/) print substr($i,4), $7}' /var/log/nginx/api.afriva.access.log \| sort -rn \| head` |
| Deploy history | `cat /srv/afriva/state/releases.log`, full output in `/srv/afriva/state/deploy.log` |
| Running release | `cat /srv/afriva/state/current_tag` |
| Last backup | `cat /srv/afriva/state/last_backup` |
| Scheduled tasks | `$c exec scheduler php artisan schedule:list` |
| Failed queue jobs | `$c exec app php artisan queue:failed` (retry: `queue:retry all`) |
| Laravel overview | `$c exec app php artisan about` |

## Monitoring

* Netdata: `ssh -L 19999:127.0.0.1:19999 deploy@SERVER_IP`, then open `http://localhost:19999`. CPU, RAM, disk, network, per-container usage, Nginx and MySQL charts. It is not reachable from the internet.
* Quick check without Netdata: `htop`, `df -h`, `free -h`, `docker stats --no-stream`.
* The admin panel's Infrastructure page shows usage and spend; budget alerts go to `INFRA_ALERT_EMAIL`.
* Recommended: an external uptime monitor (any free tier) on `https://api.afriva.co.tz/up` every 1 to 5 minutes, alerting your email or phone.

## Restarting

| What | Command |
|---|---|
| Everything of the API | `$c restart app worker scheduler` |
| After editing `.env` | `$c up -d --force-recreate app worker scheduler` |
| Stop accepting requests (maintenance page, 503) | `$c exec app php artisan down` / back: `$c exec app php artisan up` |
| MySQL or Redis | `$c restart mysql` (brief API errors while it restarts) |
| Nginx | `sudo nginx -t && sudo systemctl reload nginx` |
| Whole server | `sudo reboot` (needs a sudo password) or the Hetzner console. Containers come back by themselves. |

Never run `docker compose down -v`: `-v` deletes the database volume.

## Database access

```bash
$c exec mysql sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot "$MYSQL_DATABASE"'
```

For a GUI from your computer, use an SSH tunnel to the container (MySQL has no public port):

```bash
ssh -L 3307:$(ssh deploy@SERVER_IP "docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' afriva-mysql-1"):3306 deploy@SERVER_IP
```

then connect the GUI to `127.0.0.1:3307` with the app user.

## Updates

* **Ubuntu security updates** install automatically every night (unattended-upgrades). Some need a reboot: if `/var/run/reboot-required` exists, reboot in a quiet hour (about 1 minute of downtime).
* **Docker Engine** is updated by hand, monthly: `sudo apt update && sudo apt install --only-upgrade docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin`. Containers restart.
* **MySQL and Redis images**: patch updates with `$c pull mysql redis && $c up -d mysql redis` in a quiet hour, after a fresh backup. Major versions (for example MySQL 9) need a planned upgrade.
* **PHP base image**: rebuilt with each deploy when the Dockerfile changes; to pick up PHP security patches, deploy with `docker builder prune -af` first so the base image is pulled fresh.
* **Cloudflare IP list**: refreshed weekly by `afriva-cloudflare-ips.timer`.
* **TLS certificate**: renewed automatically by certbot's timer; check with `sudo certbot renew --dry-run`.

## Disk space

80 GB disk. Main users: Docker images (about 500 MB each, 5 kept), MySQL data, local backups (3 days), logs.

```bash
df -h /
docker system df
sudo du -sh /srv/afriva/* /var/lib/docker
```

Free space: `docker image prune -f` (dangling only), `docker builder prune -f`. Do not delete the volumes.

## SSH access

* Add a person: append their public key to `/home/deploy/.ssh/authorized_keys`. Remove the line to revoke.
* Password and root logins are disabled; fail2ban bans IPs after 5 failed SSH attempts for 1 hour (`sudo fail2ban-client status sshd`).
* Locked out: Hetzner console > server > Console (web terminal), or Rescue mode.

## Scaling notes

* More API capacity on the same box: raise `pm.max_children` in `deploy/docker/php/www.conf` (watch RAM).
* Bigger server: Hetzner console > Rescale (a few minutes of downtime; "CPU and RAM only" keeps the disk size so you can scale back down).
* Never run two schedulers. More workers are fine: `$c up -d --scale worker=2 --no-recreate`.

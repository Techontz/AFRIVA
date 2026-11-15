# Backup and recovery

## What is backed up, and how

| Data | Backup | Retention | Where |
|---|---|---|---|
| MySQL database | Nightly `mysqldump --single-transaction`, gzip, encrypted with age | 14 daily + 8 weekly in R2, 3 days on the server | `afriva-backups` bucket: `daily/`, `weekly/` |
| MySQL before every migration and before a production restore | Same, triggered by `deploy.sh` / `restore-db.sh` | Last 20 | `manual/` |
| Whole server (OS, config, Docker volumes) | Hetzner automatic backups | 7 daily snapshots | Hetzner |
| Images and ID documents | Cloudflare R2 (durable, replicated by Cloudflare) | n/a | `afriva-media`, `afriva-private` |
| Videos | Bunny Stream storage | n/a | Bunny |
| Code | GitHub | n/a | `Conradbubex/afriva` |
| Secrets (`.env`, backup key) | **Owner's password manager** | n/a | Off-site, by hand |

Hetzner snapshots are crash-consistent: fine for the OS, but the database dump is the reliable copy of MySQL.

### Images (R2)

R2 stores objects redundantly, so a disk failure is not a concern. What R2 does not protect against is deletion (by a bug, by a stolen token, or by a person). Options, in order of effort:

1. Keep the app token scoped to the media buckets only (no backup bucket), as set up.
2. Optional: a weekly bucket-to-bucket copy into a separate bucket, for example with rclone on the server: `rclone sync r2:afriva-media r2:afriva-media-copy` (costs storage for the second copy; images are small).
3. Until migration, local files under `/srv/afriva/shared/storage/app/` are covered by Hetzner snapshots.

## Encryption key

* `/srv/afriva/secrets/backup-age.pub` encrypts. `/srv/afriva/secrets/backup-age.key` decrypts.
* **The private key must also live off the server** (password manager). If the server is lost and the key was only there, every backup is unreadable.
* For stronger separation, you can delete `backup-age.key` from the server: backups keep working (they only need the `.pub`), the post-backup verification is skipped, and you copy the key back only when restoring.

## Schedule

`afriva-backup.timer` runs `backup-db.sh` daily at 02:15 Dar es Salaam time. Check:

```bash
systemctl list-timers afriva-backup.timer
journalctl -u afriva-backup.service --since yesterday
cat /srv/afriva/state/last_backup
```

Run one now: `sudo systemctl start afriva-backup.service` (or `/srv/afriva/repo/deploy/scripts/backup-db.sh --label manual`).
Cron alternative: `deploy/systemd/crontab.example`.

## Restore

`restore-db.sh` never touches production unless asked. Default: restore into a new scratch database and print row counts.

```bash
cd /srv/afriva/repo
deploy/scripts/restore-db.sh latest                    # newest local file
deploy/scripts/restore-db.sh r2:latest                 # newest daily in R2
deploy/scripts/restore-db.sh r2:weekly/afriva-db-20261115-021500-nightly.sql.gz.age
deploy/scripts/restore-db.sh /srv/afriva/backups/afriva-db-....sql.gz.age --database afriva_check
```

List R2 backups:

```bash
set -a; . /srv/afriva/secrets/backup.env; set +a
AWS_ACCESS_KEY_ID=$R2_BACKUP_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY=$R2_BACKUP_SECRET_ACCESS_KEY AWS_DEFAULT_REGION=auto \
  aws --endpoint-url "$R2_ENDPOINT" s3 ls "s3://$R2_BACKUP_BUCKET/daily/"
```

### Restore into production

```bash
deploy/scripts/restore-db.sh r2:daily/<file> --into-production
```

It asks you to type `RESTORE PRODUCTION`, then: takes a safety backup of the current database (`manual/...pre-restore`), puts the API in maintenance mode, stops worker and scheduler, drops and recreates the database, imports, starts everything and leaves maintenance mode.

Everything written after the backup time is lost. Payments made in that window must be reconciled with the provider's records.

### Test restores

Once a month: `deploy/scripts/restore-db.sh r2:latest`, check the counts look right, drop the scratch database (the script prints the command). This proves backups are readable and the key works.

## Disaster recovery (server lost)

1. Create a new server (see [deployment.md](deployment.md) steps 1 to 3), or restore a Hetzner snapshot (fastest: Hetzner console > server > Backups > Rebuild from backup).
2. On a new server: put `.env`, `backup.env` and `backup-age.key` back from the password manager.
3. `deploy/scripts/compose.sh up -d mysql redis`, then `deploy/scripts/restore-db.sh r2:latest --into-production` (the `app` maintenance steps are skipped with a warning if the app is not running yet).
4. `deploy/scripts/deploy.sh main`, `install-nginx.sh`, point the `api` DNS record at the new IP.

Target: back online within 1 to 2 hours, losing at most one day of data (less if the failure is not total and binlogs survive).

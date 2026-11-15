# Deployment

Part 1 is done once to move Afriva from the shared host to the new setup. Part 2 is every later API release.
Steps marked **Owner** need your accounts or payment details; nobody else should type those credentials.

Order of work: server (1 to 3), Cloudflare DNS (4), R2 (5), Vercel (6), first API deploy (7), migration window (8).
The old Tanzania Servers host keeps serving everything until step 8 switches DNS.

---

## Part 1: first setup

### 1. Create the Hetzner server (Owner)

1. Hetzner Cloud console: create a project "Afriva" and add a payment method.
2. Security > SSH keys: add your own public key (from `~/.ssh/id_ed25519.pub`; create one with `ssh-keygen -t ed25519` if needed).
3. Add Server:
   * Location: Falkenstein or Nuremberg (Germany) or Helsinki. Pick one and measure the API latency from Tanzania after setup.
   * Image: Ubuntu 24.04.
   * Type: shared vCPU, 4 vCPU / 8 GB RAM / 80 GB disk (CX33 in the current Hetzner list, formerly CX32). About EUR 7 to 9 per month, see [costs.md](costs.md).
   * Networking: public IPv4 and IPv6.
   * SSH key: the one from step 2.
   * Backups: enable (+20%, daily server snapshots).
   * Name: `afriva-api-1`.
4. Optional but recommended: Firewalls > create one allowing inbound TCP 22, 80, 443 only and apply it to the server (free, in addition to UFW on the server).
5. Note the server's IPv4 address.

### 2. Bootstrap the server

From your computer:

```bash
scp deploy/scripts/bootstrap-server.sh root@SERVER_IP:/root/
ssh root@SERVER_IP 'bash /root/bootstrap-server.sh "$(cat ~/.ssh/authorized_keys | head -n 1)"'
```

The command reuses the key Hetzner installed for root; you can also pass your public key text directly as the first argument. The script prints the next steps. Then:

1. In a **new** terminal, check `ssh deploy@SERVER_IP` works. Root login and passwords are now off.
2. Optional, in the still open root session: `passwd deploy` gives the deploy user a password for full `sudo`. Without it, deploy can only run the few commands the scripts need (reload Nginx, start a backup). Root work can always be done from the Hetzner web console.
3. GitHub > repo `Conradbubex/afriva` > Settings > Deploy keys > Add: paste the key printed by the script, **read access only**.
4. As deploy:
   ```bash
   git clone git@github.com:Conradbubex/afriva.git /srv/afriva/repo
   ```
5. As root (from the root session):
   ```bash
   cp /srv/afriva/repo/deploy/systemd/*.service /srv/afriva/repo/deploy/systemd/*.timer /etc/systemd/system/
   systemctl daemon-reload
   systemctl enable --now afriva-cloudflare-ips.timer
   # enable afriva-backup.timer after step 5 (R2) and the backup key exist
   ```

### 3. Settings and secrets on the server

As deploy:

```bash
cp /srv/afriva/repo/deploy/.env.production.example /srv/afriva/shared/.env
chmod 600 /srv/afriva/shared/.env
nano /srv/afriva/shared/.env
```

Fill at least: `DB_PASSWORD`, `MYSQL_ROOT_PASSWORD`, `REDIS_PASSWORD` (each `openssl rand -hex 32`), Bunny values (copy from the old host's `.env`), mail settings, `AFRIVA_UID` and `AFRIVA_GID` (output of `id -u` and `id -g`). `APP_KEY` must be the **same key as on the old host** (copy it), otherwise encrypted values in the database cannot be read. See [environment-variables.md](environment-variables.md).

Backup key (age):

```bash
age-keygen -o /srv/afriva/secrets/backup-age.key
grep 'public key' /srv/afriva/secrets/backup-age.key | awk '{print $4}' > /srv/afriva/secrets/backup-age.pub
chmod 600 /srv/afriva/secrets/backup-age.key
cat /srv/afriva/secrets/backup-age.key
```

**Owner:** copy the printed `AGE-SECRET-KEY-...` line into your password manager now. Without it, backups cannot be decrypted if the server is lost.

### 4. Move DNS to Cloudflare (Owner, then check together)

1. **Before anything else**, copy every DNS record from the current DNS at Tanzania Servers (DirectAdmin > DNS Management for `afriva.co.tz`): A, AAAA, CNAME, **MX**, **TXT** (SPF `v=spf1...`, DKIM `default._domainkey`, DMARC `_dmarc`), SRV, and any verification records (Google, Apple, Bunny). Save a screenshot or text copy.
2. Cloudflare: create a free account, Add a site `afriva.co.tz`, Free plan. Cloudflare imports records it can find. Compare against your copy and add anything missing.
3. Proxy status (cloud icon):
   * `MX` targets and `mail.`, `webmail.`, `smtp.`, `pop.`, `imap.`, `ftp.`: **DNS only (grey)**. Mail cannot pass through the proxy.
   * `afriva.co.tz`, `www`, `admin`, `studio`, `api`: keep them pointing at the **old host** for now. Proxy can stay off until the switch.
4. Set TTL of `api` and the website records to "Auto" (300 s while unproxied) so the later switch is quick.
5. SSL/TLS > Overview: **Full (strict)**. Edge Certificates: Always Use HTTPS on, Minimum TLS 1.2. Do not enable "Automatic HTTPS Rewrites" changes to API JSON (it only touches HTML, harmless either way).
6. Change nameservers: Tanzania Servers client area > Domains > `afriva.co.tz` > Nameservers > use custom, enter the two Cloudflare nameservers. `.co.tz` changes can take several hours.
7. Check: `dig NS afriva.co.tz +short` shows Cloudflare; the website and email still work (send and receive a test email to `support@afriva.co.tz`).

### 5. Cloudflare R2 (Owner)

1. Cloudflare dashboard > R2: enable (needs a payment method, free tier covers 10 GB).
2. Create buckets (location hint: Europe or automatic):
   * `afriva-media`: public images. Settings > Custom domain: `media.afriva.co.tz` (Cloudflare adds the DNS record).
   * `afriva-private`: creator ID documents. No public access.
   * `afriva-backups`: database backups. No public access.
3. R2 > Manage API tokens > Create two tokens (type: Object Read & Write, "Apply to specific buckets only"):
   * App token: `afriva-media` and `afriva-private`. Put its key id and secret in `/srv/afriva/shared/.env` as `R2_ACCESS_KEY_ID` and `R2_SECRET_ACCESS_KEY`.
   * Backup token: `afriva-backups` only. Put it in `/srv/afriva/secrets/backup.env` (template `deploy/backup.env.example`, mode 600).
4. Endpoint `https://<ACCOUNT_ID>.r2.cloudflarestorage.com` goes into both files as `R2_ENDPOINT`. `R2_PUBLIC_URL=https://media.afriva.co.tz`.
5. Enable nightly backups (root): `systemctl enable --now afriva-backup.timer`.

### 6. Vercel (Owner approves Vercel Pro)

1. vercel.com > Add New > Project > Import `Conradbubex/afriva` (install the Vercel GitHub app for this repo only).
2. Root Directory: `afriva_web`. Framework: Next.js (auto). Build and output settings: defaults.
3. Environment variables (Production):
   | Name | Value |
   |---|---|
   | `NEXT_PUBLIC_API_URL` | `https://api.afriva.co.tz/api/v1` |
   | `NEXT_PUBLIC_SITE_URL` | `https://afriva.co.tz` |
   | `NEXT_PUBLIC_ADMIN_URL` | `https://admin.afriva.co.tz` |
   | `NEXT_PUBLIC_STUDIO_URL` | `https://studio.afriva.co.tz` |
4. Deploy, then open the `*.vercel.app` URL to check pages load (they call the API on the old host until the switch, which is fine).
5. Settings > Domains: add `afriva.co.tz`, `www.afriva.co.tz` (redirect to apex or the reverse, your choice), `admin.afriva.co.tz`, `studio.afriva.co.tz`. Vercel shows the DNS records it needs (usually `A 76.76.21.21` for the apex and `CNAME cname.vercel-dns.com` for subdomains). Add them in Cloudflare as **DNS only (grey)**; Vercel issues its own certificates and runs its own edge, and proxying through Cloudflare in front of Vercel is not recommended by Vercel.
6. From now on every push to `main` deploys the website automatically; pull requests get preview URLs. No GitHub workflow is needed.

### 7. First API start on the new server (no traffic yet)

As deploy (requires DNS from step 4 for `api` to point at this server only when issuing the certificate; see note):

```bash
cd /srv/afriva/repo
deploy/scripts/compose.sh up -d mysql redis    # uses image tag "none" for app; fine for these two
```

TLS certificate: the HTTP-01 challenge needs `api.afriva.co.tz` to reach this server. Two options:

* Issue it during the migration window right after switching `api` DNS (simplest), or
* Before the window, create a temporary record such as `api-new.afriva.co.tz` pointing here, and run `DOMAIN=api-new.afriva.co.tz` for testing only.

Then (as root): `bash /srv/afriva/repo/deploy/scripts/install-nginx.sh you@afriva.co.tz`.

### 8. Data migration window (about 30 minutes)

Announce a short maintenance window. Lower risk: do it at night Tanzania time.

1. **Old host:** put the API in maintenance so no writes are lost: in DirectAdmin's terminal (or SSH) in the Laravel folder run `php artisan down`.
2. **Old host:** dump the database:
   ```bash
   mysqldump --single-transaction --quick --routines --triggers --no-tablespaces -u USER -p DBNAME | gzip > afriva-final.sql.gz
   ```
   (phpMyAdmin > Export > Custom > gzip also works.) Also archive uploads: `tar czf afriva-storage.tgz -C storage/app public private`.
3. Copy both files to the new server: `scp afriva-final.sql.gz afriva-storage.tgz deploy@SERVER_IP:/srv/afriva/backups/`.
4. **New server**, as deploy:
   ```bash
   cd /srv/afriva/repo
   gunzip -c /srv/afriva/backups/afriva-final.sql.gz \
     | deploy/scripts/compose.sh exec -T mysql sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot "$MYSQL_DATABASE"'
   tar xzf /srv/afriva/backups/afriva-storage.tgz -C /srv/afriva/shared/storage/app
   chmod 700 /srv/afriva/shared/storage/app/private
   deploy/scripts/deploy.sh main      # builds, runs pending migrations (with a backup), starts the API
   ```
5. Copy images and documents to R2 (command provided by the app):
   ```bash
   deploy/scripts/compose.sh exec app php artisan media:migrate-to-r2 --dry-run
   deploy/scripts/compose.sh exec app php artisan media:migrate-to-r2
   ```
   Then set `MEDIA_DISK=r2_public` and `PRIVATE_DOCUMENTS_DISK=r2_private` in `/srv/afriva/shared/.env` and run `deploy/scripts/compose.sh up -d --force-recreate app worker scheduler`. Local files are never deleted by the command.
6. Switch DNS in Cloudflare: `api` A record to the new server IP (AAAA to its IPv6), **proxied (orange)**. If the certificate was not issued yet, run `install-nginx.sh` now (Let's Encrypt follows Cloudflare's redirect to HTTPS, and the challenge path is served on both ports).
7. Check: `curl -s https://api.afriva.co.tz/up`, `curl -s https://api.afriva.co.tz/api/v1/health`, log in on the website and the app, play an episode, upload a poster in admin, upload a short test video in studio and watch it reach "ready" (webhook). See the checklist in [troubleshooting.md](troubleshooting.md).
8. Bunny: the webhook URL stays `https://api.afriva.co.tz/api/v1/webhooks/bunny`. Make sure `BUNNY_STREAM_WEBHOOK_SECRET` is set (the library's Read-Only API key).
9. Take a first backup: `sudo systemctl start afriva-backup.service`, then `journalctl -u afriva-backup.service`.
10. **Fallback:** leave the old host untouched (still in maintenance) for at least 7 days. To fall back, point `api` back to the old host IP and run `php artisan up` there. Data written on the new server after the switch would then be missing on the old one, so decide quickly.

---

## Part 2: every API release

Normal path, from GitHub:

1. Merge to `main`; wait for CI to pass.
2. GitHub > Actions > "Deploy API" > Run workflow. Ref: `main` (or a tag or commit). Leave "Allow destructive migrations" off.
3. Approve the run (the `production` environment requires your review).
4. The job SSHes to the server and runs `deploy.sh`, then checks `https://api.afriva.co.tz/up` through Cloudflare.

Manual path, on the server as deploy: `/srv/afriva/repo/deploy/scripts/deploy.sh main`.

What `deploy.sh` does:

1. Fetches and checks out the ref (the server checkout must have no local edits).
2. Builds `afriva-api:<sha>` (cached layers make this quick when only app code changed).
3. Starts MySQL and Redis if needed.
4. Runs `php artisan migrate --pretend` with the new code. If the SQL contains `DROP`, `RENAME` or `TRUNCATE`, it stops without changing anything. Rerun with `ALLOW_DESTRUCTIVE_MIGRATIONS=1` (or the workflow checkbox) only after reading the SQL.
5. If there are pending migrations: encrypted backup (`manual/` in R2), then `migrate --force`. The old release keeps serving during this, so write migrations that old code tolerates (add first, remove later).
6. Recreates `app`, `worker` and `scheduler` on the new image. Each runs `php artisan optimize` on start.
7. Health checks `/up` (must be 200) and `/api/v1/health` (200; 404 only warns).
8. On failure: switches back to the previous image automatically. Migrations are **not** undone.

Rollback by hand: `deploy/scripts/rollback.sh` (previous image) or `deploy/scripts/rollback.sh <tag>`. List images: `docker image ls afriva-api`.

Website releases: automatic in Vercel. Roll back in Vercel > Deployments > pick an earlier one > Promote to Production.

## GitHub setup for the deploy workflow (Owner, once)

1. Create a key pair just for GitHub Actions on your computer: `ssh-keygen -t ed25519 -f afriva-gh-deploy -N ""`.
2. Add `afriva-gh-deploy.pub` to `/home/deploy/.ssh/authorized_keys` on the server.
3. GitHub > Settings > Environments > New environment `production`: Required reviewers = you; Deployment branches = `main`.
4. Environment secrets: `DEPLOY_HOST` (server IP), `DEPLOY_USER` (`deploy`), `DEPLOY_SSH_KEY` (contents of `afriva-gh-deploy`), `DEPLOY_KNOWN_HOSTS` (output of `ssh-keyscan -t ed25519 SERVER_IP`).
5. Delete the local private key file after saving it as a secret.

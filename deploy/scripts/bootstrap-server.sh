#!/usr/bin/env bash
# One-time (idempotent) setup of a fresh Ubuntu 24.04 LTS server for the Afriva API. Run as root:
#
#   curl -fsSLO <raw url of this file>   (or scp it)   then:
#   bash bootstrap-server.sh "ssh-ed25519 AAAA... owner@laptop" [--user deploy] [--swap 4G] [--nopasswd-sudo]
#
# What it does: deploy user with your SSH key, SSH hardening (keys only, no root login), UFW (22, 80, 443),
# fail2ban, unattended security upgrades, swap, timezone Africa/Dar_es_Salaam, Docker Engine + compose
# plugin (Docker's apt repo), Nginx + certbot, age + aws CLI for backups, Netdata bound to localhost,
# /srv/afriva layout, log rotation, systemd timers for backups and Cloudflare IP refresh.
#
# Safe to rerun. KEEP your current root SSH session open until you have logged in as the deploy user
# in a second terminal: root login is switched off at the end.

set -euo pipefail

SSH_KEY="${1:-}"
shift || true
DEPLOY_USER="deploy"
SWAP_SIZE="4G"
NOPASSWD_SUDO=0
while [ $# -gt 0 ]; do
    case "$1" in
        --user) DEPLOY_USER="$2"; shift 2 ;;
        --swap) SWAP_SIZE="$2"; shift 2 ;;
        --nopasswd-sudo) NOPASSWD_SUDO=1; shift ;;
        *) echo "unknown option: $1" >&2; exit 1 ;;
    esac
done

AFRIVA_ROOT=/srv/afriva
export DEBIAN_FRONTEND=noninteractive

say() { printf '\n==> %s\n' "$*"; }

[ "$(id -u)" -eq 0 ] || { echo "run as root" >&2; exit 1; }
[[ "$SSH_KEY" =~ ^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp256|sk-ssh-ed25519@openssh.com)\  ]] \
    || { echo "first argument must be an SSH public key (ssh-ed25519 AAAA...)" >&2; exit 1; }
. /etc/os-release
[ "${VERSION_ID:-}" = "24.04" ] || echo "WARNING: written for Ubuntu 24.04, found ${PRETTY_NAME:-unknown}" >&2

say "Base packages and updates"
apt-get update -q
apt-get -y -q upgrade
apt-get install -y -q ca-certificates curl gnupg git ufw fail2ban unattended-upgrades \
    apt-listchanges nginx certbot age unzip jq htop logrotate

say "Timezone Africa/Dar_es_Salaam"
timedatectl set-timezone Africa/Dar_es_Salaam

say "Deploy user '$DEPLOY_USER'"
if ! id "$DEPLOY_USER" > /dev/null 2>&1; then
    adduser --disabled-password --gecos "" "$DEPLOY_USER"
fi
usermod -aG sudo "$DEPLOY_USER"
install -d -m 0700 -o "$DEPLOY_USER" -g "$DEPLOY_USER" "/home/$DEPLOY_USER/.ssh"
AUTH="/home/$DEPLOY_USER/.ssh/authorized_keys"
touch "$AUTH"
grep -qxF "$SSH_KEY" "$AUTH" || echo "$SSH_KEY" >> "$AUTH"
chown "$DEPLOY_USER:$DEPLOY_USER" "$AUTH"
chmod 0600 "$AUTH"
# Commands the scripts need without a password. Full sudo needs a password the owner sets with
# "passwd deploy" (or rerun with --nopasswd-sudo to allow everything without one).
if [ "$NOPASSWD_SUDO" = "1" ]; then
    echo "$DEPLOY_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-afriva-deploy
else
    cat > /etc/sudoers.d/90-afriva-deploy <<EOF
$DEPLOY_USER ALL=(root) NOPASSWD: /usr/sbin/nginx -t, /usr/bin/systemctl reload nginx, /usr/bin/systemctl start afriva-backup.service, /usr/bin/systemctl status *
EOF
fi
chmod 0440 /etc/sudoers.d/90-afriva-deploy
visudo -cf /etc/sudoers.d/90-afriva-deploy

# Read-only GitHub deploy key for the private repo (owner adds the public half in GitHub).
GH_KEY="/home/$DEPLOY_USER/.ssh/afriva_github"
if [ ! -f "$GH_KEY" ]; then
    sudo -u "$DEPLOY_USER" ssh-keygen -t ed25519 -N "" -C "afriva-server-deploy-key" -f "$GH_KEY" -q
fi
cat > "/home/$DEPLOY_USER/.ssh/config" <<EOF
Host github.com
    IdentityFile $GH_KEY
    IdentitiesOnly yes
EOF
chown "$DEPLOY_USER:$DEPLOY_USER" "/home/$DEPLOY_USER/.ssh/config"
chmod 0600 "/home/$DEPLOY_USER/.ssh/config"
sudo -u "$DEPLOY_USER" sh -c 'ssh-keygen -F github.com > /dev/null || ssh-keyscan -t ed25519 github.com >> ~/.ssh/known_hosts 2> /dev/null'

say "Firewall (UFW): 22, 80, 443 only"
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

say "fail2ban (SSH)"
cat > /etc/fail2ban/jail.d/afriva.local <<'EOF'
# Only SSH. No Nginx jails: behind Cloudflare the connecting IP is Cloudflare's, so banning it at the
# firewall would block many real users. Abuse on the API is handled by Nginx rate limits and Cloudflare.
[sshd]
enabled = true
backend = systemd
maxretry = 5
findtime = 10m
bantime = 1h
EOF
systemctl enable --now fail2ban
systemctl restart fail2ban

say "Unattended security upgrades"
cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF
cat > /etc/apt/apt.conf.d/52afriva-unattended <<'EOF'
// Security updates only (Ubuntu default origins). Docker's repo is not included on purpose:
// Docker upgrades restart containers and are done by hand in a maintenance window.
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
// No automatic reboots; /var/run/reboot-required is checked in server-management.md.
Unattended-Upgrade::Automatic-Reboot "false";
EOF
systemctl enable --now unattended-upgrades

say "Swap ($SWAP_SIZE)"
if ! swapon --show | grep -q '/swapfile'; then
    fallocate -l "$SWAP_SIZE" /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
fi
grep -q '^/swapfile ' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
cat > /etc/sysctl.d/90-afriva.conf <<'EOF'
vm.swappiness = 10
vm.overcommit_memory = 1
net.core.somaxconn = 1024
EOF
sysctl --system > /dev/null

say "Docker Engine + compose plugin (Docker's official apt repo)"
if ! command -v docker > /dev/null; then
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" \
        > /etc/apt/sources.list.d/docker.list
    apt-get update -q
    apt-get install -y -q docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi
install -d -m 0755 /etc/docker
cat > /etc/docker/daemon.json <<'EOF'
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "5" },
  "live-restore": true
}
EOF
systemctl enable --now docker
systemctl restart docker
# Note: membership of the docker group is equivalent to root on this host.
usermod -aG docker "$DEPLOY_USER"

say "aws CLI v2 (backups to R2)"
if ! command -v aws > /dev/null; then
    tmpd="$(mktemp -d)"
    curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip" -o "$tmpd/awscliv2.zip"
    unzip -q "$tmpd/awscliv2.zip" -d "$tmpd"
    "$tmpd/aws/install"
    rm -rf "$tmpd"
fi

say "Netdata monitoring (localhost only)"
# Netdata from Ubuntu's repo: per-second CPU, RAM, disk, network, Nginx, MySQL and Docker charts for
# about 100 to 150 MB of RAM. It listens on 127.0.0.1:19999 only; open it through an SSH tunnel:
#   ssh -L 19999:127.0.0.1:19999 deploy@<server>   then browse http://localhost:19999
apt-get install -y -q netdata
install -d /etc/netdata
cat > /etc/netdata/netdata.conf <<'EOF'
[db]
    mode = dbengine
    dbengine multihost disk space MB = 512
[web]
    bind to = 127.0.0.1
EOF
touch /etc/netdata/.opt-out-from-anonymous-statistics
install -d /var/lib/netdata/cloud.d
printf '[global]\n    enabled = no\n' > /var/lib/netdata/cloud.d/cloud.conf
systemctl enable netdata
systemctl restart netdata

say "/srv/afriva layout"
install -d -m 0755 -o "$DEPLOY_USER" -g "$DEPLOY_USER" "$AFRIVA_ROOT"
install -d -m 0755 -o "$DEPLOY_USER" -g "$DEPLOY_USER" "$AFRIVA_ROOT/shared"
install -d -m 0755 -o "$DEPLOY_USER" -g "$DEPLOY_USER" "$AFRIVA_ROOT/shared/storage"
install -d -m 0755 -o "$DEPLOY_USER" -g "$DEPLOY_USER" "$AFRIVA_ROOT/shared/storage/app"
install -d -m 0755 -o "$DEPLOY_USER" -g "$DEPLOY_USER" "$AFRIVA_ROOT/shared/storage/app/public"
install -d -m 0700 -o "$DEPLOY_USER" -g "$DEPLOY_USER" "$AFRIVA_ROOT/shared/storage/app/private"
install -d -m 0775 -o "$DEPLOY_USER" -g "$DEPLOY_USER" "$AFRIVA_ROOT/shared/storage/framework"
install -d -m 0775 -o "$DEPLOY_USER" -g "$DEPLOY_USER" "$AFRIVA_ROOT/shared/storage/logs"
install -d -m 0700 -o "$DEPLOY_USER" -g "$DEPLOY_USER" "$AFRIVA_ROOT/secrets"
install -d -m 0750 -o "$DEPLOY_USER" -g "$DEPLOY_USER" "$AFRIVA_ROOT/backups"
install -d -m 0755 -o "$DEPLOY_USER" -g "$DEPLOY_USER" "$AFRIVA_ROOT/state"
install -d -m 0755 /var/www/certbot
if [ -f "$AFRIVA_ROOT/shared/.env" ]; then
    chown "$DEPLOY_USER:$DEPLOY_USER" "$AFRIVA_ROOT/shared/.env"
    chmod 0600 "$AFRIVA_ROOT/shared/.env"
fi

say "Log rotation for Laravel logs"
cat > /etc/logrotate.d/afriva <<EOF
# Laravel's daily channel already rotates by date; this compresses and caps anything else in logs/.
$AFRIVA_ROOT/shared/storage/logs/*.log {
    weekly
    rotate 8
    maxsize 100M
    missingok
    notifempty
    compress
    delaycompress
    copytruncate
    su $DEPLOY_USER $DEPLOY_USER
}
$AFRIVA_ROOT/state/deploy.log {
    monthly
    rotate 12
    missingok
    notifempty
    compress
    copytruncate
    su $DEPLOY_USER $DEPLOY_USER
}
EOF

say "systemd units (installed later from the repo checkout)"
cat > /etc/motd <<'EOF'

  Afriva API server. Runbooks: /srv/afriva/repo/docs/ops/
  Stack:   /srv/afriva/repo/deploy/scripts/compose.sh ps
  Monitor: ssh -L 19999:127.0.0.1:19999 then http://localhost:19999

EOF

say "SSH hardening (keys only, no root login)"
if [ -s "$AUTH" ]; then
    cat > /etc/ssh/sshd_config.d/99-afriva.conf <<EOF
PasswordAuthentication no
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no
PermitRootLogin no
PubkeyAuthentication yes
PermitEmptyPasswords no
X11Forwarding no
MaxAuthTries 4
AllowUsers $DEPLOY_USER
EOF
    sshd -t
    systemctl reload ssh || systemctl restart ssh
else
    echo "WARNING: $AUTH is empty; SSH hardening skipped so you are not locked out" >&2
fi

say "Done"
cat <<EOF

Next steps (docs/ops/deployment.md, section "Server"):
  1. In a NEW terminal, confirm you can log in:  ssh $DEPLOY_USER@<server-ip>
     (root login and passwords are now disabled; keep this root session open until that works)
  2. Optional: give $DEPLOY_USER a sudo password:  passwd $DEPLOY_USER
  3. Add this read-only deploy key in GitHub (repo Settings > Deploy keys, no write access):
$(cat "$GH_KEY.pub")
  4. As $DEPLOY_USER: git clone git@github.com:Conradbubex/afriva.git $AFRIVA_ROOT/repo
  5. As root: install the timers and Nginx:
       cp $AFRIVA_ROOT/repo/deploy/systemd/*.service $AFRIVA_ROOT/repo/deploy/systemd/*.timer /etc/systemd/system/
       systemctl daemon-reload && systemctl enable --now afriva-backup.timer afriva-cloudflare-ips.timer
       bash $AFRIVA_ROOT/repo/deploy/scripts/install-nginx.sh you@example.com
EOF

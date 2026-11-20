#!/usr/bin/env bash
# चौतारी — set up the server (run as root on the Azure machine; deploy/azure/provision.sh calls it).
# Needs: REF (git ref of this repo), KV (Key Vault name), ST (backup storage account), DOMAIN.
# Safe to run again: it updates the code, keeps the database and the secrets.
#
#   /srv/chautari/repo        this repository at REF
#   /srv/chautari/supabase    the database and its API (self-hosted Supabase: db, auth, rest, gateway only)
#   /srv/chautari/www         the app, built for this server
#   /srv/chautari/documents   photos of bills and work, under their SHA-256
#   Caddy                     https://$DOMAIN : the app, /rest and /auth to Supabase, /reader to the reader
# The database holds TEST data only until the lawyer's review; the app shows a TEST badge.
set -euo pipefail
: "${REF:?}" "${KV:?}" "${ST:?}" "${DOMAIN:?}"
export DEBIAN_FRONTEND=noninteractive
S=/srv/chautari; mkdir -p $S/documents $S/www; cd $S
say() { printf '\n== %s\n' "$*"; }

say "system: updates, swap, firewall"
apt-get update -qq
apt-get install -y -qq git jq curl gnupg ufw caddy unattended-upgrades >/dev/null
systemctl enable --now unattended-upgrades >/dev/null 2>&1 || true
if [ ! -f /swapfile ]; then fallocate -l 2G /swapfile && chmod 600 /swapfile && mkswap /swapfile >/dev/null && swapon /swapfile && echo '/swapfile none swap sw 0 0' >> /etc/fstab; fi
ufw --force reset >/dev/null; ufw default deny incoming >/dev/null; ufw allow 80/tcp >/dev/null; ufw allow 443/tcp >/dev/null; ufw --force enable >/dev/null

say "code: chautari @ $REF"
if [ -d $S/repo/.git ]; then git -C $S/repo fetch -q --depth 1 origin "$REF" && git -C $S/repo checkout -q -f FETCH_HEAD
else git clone -q --depth 1 --branch "$REF" https://github.com/zentrust-inc/chautari $S/repo 2>/dev/null || { git clone -q https://github.com/zentrust-inc/chautari $S/repo && git -C $S/repo checkout -q "$REF"; }; fi
install -m 755 $S/repo/deploy/server/kv.sh /usr/local/bin/chautari-kv
git -C $S/repo log -1 --format='%h %s'

say "database: self-hosted Supabase"
if [ ! -f $S/supabase/.env ]; then
  if chautari-kv get supabase-env > /tmp/env.b64 2>/dev/null && [ -s /tmp/env.b64 ]; then
    echo "restoring the Supabase secrets kept in the Key Vault"
    curl -fsSL https://raw.githubusercontent.com/supabase/supabase/master/docker/setup.sh -o /root/supabase-setup.sh
    sh /root/supabase-setup.sh -y --project-dir supabase
    base64 -d /tmp/env.b64 > $S/supabase/.env
  else
    curl -fsSL https://raw.githubusercontent.com/supabase/supabase/master/docker/setup.sh -o /root/supabase-setup.sh
    sh /root/supabase-setup.sh -y --project-dir supabase
  fi
  rm -f /tmp/env.b64
fi
cd $S/supabase
setenv() { if grep -q "^$1=" .env; then sed -i "s|^$1=.*|$1=$2|" .env; else echo "$1=$2" >> .env; fi; }
setenv SUPABASE_PUBLIC_URL "https://$DOMAIN"
setenv API_EXTERNAL_URL "https://$DOMAIN"
setenv SITE_URL "https://$DOMAIN"
setenv DISABLE_SIGNUP true          # nobody can make their own account; officers add people
setenv ENABLE_PHONE_SIGNUP false    # until the SMS provider (Aakash SMS) is set up
setenv ENABLE_ANONYMOUS_USERS false
setenv API_GW_HTTP_PORT 127.0.0.1:8000   # the gateway is reached only through Caddy
chmod 600 .env
# keep the secrets off this machine too, so a lost machine does not lose the keys
base64 -w0 .env | chautari-kv put supabase-env
docker compose pull -q db auth rest api-gw
docker compose up -d --no-deps db
for i in $(seq 1 60); do docker inspect -f '{{.State.Health.Status}}' supabase-db 2>/dev/null | grep -q healthy && break; sleep 5; done
docker compose up -d --no-deps auth rest api-gw
set -a; . ./.env; set +a

say "database: our migrations"
psqldb() { docker exec -i supabase-db psql -X -q -v ON_ERROR_STOP=1 -U supabase_admin -d postgres "$@"; }
psqldb -c "create schema if not exists ops; create table if not exists ops.applied (file text primary key, at timestamptz default now());"
for f in $S/repo/supabase/migrations/*.sql; do
  n=$(basename "$f")
  if [ -z "$(psqldb -At -c "select 1 from ops.applied where file = '$n'")" ]; then
    echo "  applying $n"; psqldb < "$f"; psqldb -c "insert into ops.applied (file) values ('$n')"
  fi
done
docker compose restart rest >/dev/null   # PostgREST reloads the new functions and views

say "photos and the reader"
docker build -q -t chautari-reader $S/repo/reader >/dev/null
install -m 755 $S/repo/deploy/server/start-reader.sh /usr/local/bin/chautari-start-reader
DOMAIN=$DOMAIN chautari-start-reader

say "the app, built for this server (TEST badge until real use is approved)"
docker run --rm -v $S/repo/app:/app -w /app \
  -e VITE_SUPABASE_URL="https://$DOMAIN" -e VITE_SUPABASE_ANON_KEY="$ANON_KEY" \
  -e VITE_READER_URL="https://$DOMAIN/reader" -e VITE_SERVER_BADGE="परीक्षण · TEST" \
  node:22-bookworm-slim sh -c "npm ci --silent && npm run build --silent" >/dev/null
rm -rf $S/www && cp -r $S/repo/app/dist $S/www

say "web: Caddy with HTTPS for $DOMAIN"
sed "s|{DOMAIN}|$DOMAIN|g" $S/repo/deploy/server/Caddyfile > /etc/caddy/Caddyfile
systemctl reload caddy || systemctl restart caddy

say "nightly encrypted backup to $ST (South India), kept 90 days"
if ! chautari-kv get backup-passphrase >/dev/null 2>&1; then openssl rand -base64 48 | tr -d '\n' | chautari-kv put backup-passphrase; fi
install -m 755 $S/repo/deploy/server/backup.sh /usr/local/bin/chautari-backup
echo "ST=$ST" > /etc/chautari-backup.env
echo "45 20 * * * root . /etc/chautari-backup.env; ST=\$ST /usr/local/bin/chautari-backup >> /var/log/chautari-backup.log 2>&1" > /etc/cron.d/chautari-backup

say "health check"
sleep 5
curl -fsS -o /dev/null -w "gateway /rest: %{http_code}\n" -H "apikey: $ANON_KEY" "http://127.0.0.1:8000/rest/v1/bodies?select=id" || echo "gateway: not answering yet"
curl -fsS http://127.0.0.1:8787/health && echo " reader ok" || echo "reader: not answering"
curl -fsS -o /dev/null -w "https://$DOMAIN: %{http_code}\n" "https://$DOMAIN/" || echo "https: certificate may take a minute"
docker ps --format '{{.Names}}\t{{.Status}}'
echo "setup finished $(date -u +%FT%TZ)"

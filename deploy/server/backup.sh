#!/usr/bin/env bash
# Nightly: the whole database and the photos, encrypted (AES-256, passphrase in the Key Vault), to blob storage in South India.
set -euo pipefail
: "${ST:?}"
t=$(date -u +%Y%m%dT%H%MZ); d=$(mktemp -d); trap 'rm -rf $d' EXIT
pass=$(chautari-kv get backup-passphrase)
docker exec supabase-db pg_dumpall -U supabase_admin | gzip | gpg --batch --symmetric --cipher-algo AES256 --passphrase "$pass" -o $d/db.sql.gz.gpg
tar -C /srv/chautari -czf - documents | gpg --batch --symmetric --cipher-algo AES256 --passphrase "$pass" -o $d/documents.tgz.gpg
tok=$(curl -fsS -H Metadata:true "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fstorage.azure.com%2F" | jq -r .access_token)
for f in db.sql.gz.gpg documents.tgz.gpg; do
  curl -fsS -X PUT -H "Authorization: Bearer $tok" -H "x-ms-version: 2021-08-06" -H "x-ms-blob-type: BlockBlob" \
    --data-binary @$d/$f "https://$ST.blob.core.windows.net/backups/$t/$f" >/dev/null
done
echo "$t backup ok: $(du -ch $d/*.gpg | tail -1 | cut -f1)"

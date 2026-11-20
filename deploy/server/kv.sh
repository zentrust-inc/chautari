#!/usr/bin/env bash
# chautari-kv get|put <secret-name>  — read or write a Key Vault secret with this machine's own identity.
# KV (the vault name) comes from the environment or /etc/chautari-kv. put reads the value from stdin.
set -euo pipefail
KV="${KV:-$(cat /etc/chautari-kv 2>/dev/null || true)}"; [ -n "$KV" ] || { echo "KV not set" >&2; exit 2; }
[ -f /etc/chautari-kv ] || echo "$KV" > /etc/chautari-kv
tok=$(curl -fsS -H Metadata:true "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fvault.azure.net" | jq -r .access_token)
url="https://$KV.vault.azure.net/secrets/$2?api-version=7.4"
case "$1" in
  get) curl -fsS -H "Authorization: Bearer $tok" "$url" | jq -er .value ;;
  put) v=$(cat); jq -n --arg v "$v" '{value:$v}' | curl -fsS -X PUT -H "Authorization: Bearer $tok" -H 'Content-Type: application/json' --data @- "$url" >/dev/null ;;
  *) echo "usage: chautari-kv get|put <name>" >&2; exit 2 ;;
esac

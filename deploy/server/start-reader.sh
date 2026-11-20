#!/usr/bin/env bash
# (Re)start the reader with the keys from the Key Vault. Run again after a key is added or changed:
#   sudo chautari-start-reader   (the domain comes from /srv/chautari/domain unless DOMAIN is set)
# Keys stay in the vault and in a root-only file; never in the repository or a log.
set -euo pipefail
S=/srv/chautari
DOMAIN="${DOMAIN:-$(cat $S/domain 2>/dev/null || true)}"; : "${DOMAIN:?no domain: set DOMAIN or write $S/domain}"
SERVICE_ROLE_KEY=$(grep -m1 "^SERVICE_ROLE_KEY=" $S/supabase/.env | cut -d= -f2- | sed 's/^"//; s/"$//')
f=/root/.chautari-reader.env; umask 077
{
  echo "SUPABASE_URL=http://127.0.0.1:8000"; echo "SUPABASE_SERVICE_KEY=$SERVICE_ROLE_KEY"
  echo "DOCS_DIR=/data/documents"; echo "ALLOW_ORIGIN=https://$DOMAIN"; echo "PORT=8787"
  mode=tesseract
  a=$(chautari-kv get anthropic-api-key 2>/dev/null || echo not-set); v=$(chautari-kv get vision-api-key 2>/dev/null || echo not-set)
  s=$(chautari-kv get sarvam-api-key 2>/dev/null || echo not-set)
  [ "$a" != not-set ] && echo "ANTHROPIC_API_KEY=$a"
  [ "$v" != not-set ] && echo "VISION_API_KEY=$v"
  [ "$s" != not-set ] && echo "SARVAM_API_KEY=$s"
  # the decided reader: Claude Opus + Google Vision must agree; Tesseract on this machine until both keys are in
  if [ "$a" != not-set ] && [ "$v" != not-set ]; then mode=mix; fi
  echo "CHAUTARI_READER=$mode"
} > $f
docker rm -f chautari-reader >/dev/null 2>&1 || true
docker run -d --name chautari-reader --restart unless-stopped --network host --env-file $f \
  -v $S/documents:/data/documents chautari-reader >/dev/null
echo "reader started ($(grep CHAUTARI_READER $f))"

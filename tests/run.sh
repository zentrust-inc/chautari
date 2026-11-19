#!/usr/bin/env bash
# Rebuilds a scratch database from the migrations and runs the test suite.
set -euo pipefail
cd "$(dirname "$0")/.."
PSQL="psql -X -q -v ON_ERROR_STOP=1 -h ${PGHOST:-/var/tmp/wwpg} -p ${PGPORT:-5433} -U ${PGUSER:-postgres}"
$PSQL -d postgres -c "drop database if exists wwos_test" -c "create database wwos_test"
$PSQL -d wwos_test -f tests/00_supabase_stub.sql
for f in supabase/migrations/*.sql; do $PSQL -d wwos_test -f "$f"; done
for f in tests/[1-9]*.sql; do echo "== $f"; $PSQL -d wwos_test -o /dev/null -f "$f"; done
$PSQL -d wwos_test -At -c "select count(*) || ' checks passed, ' || count(*) filter (where not ok) || ' failed' from t.results"

# the independent verifier must agree with the database
EXPORT=$(mktemp)
$PSQL -d wwos_test -At -c "select coalesce(json_agg(c order by seq), '[]') from public.chain_export c" > "$EXPORT"
HEAD=$($PSQL -d wwos_test -At -c "select head_hash from public.chain_heads")
node scripts/verify-chain.mjs "$EXPORT" --head "$HEAD"
rm -f "$EXPORT"

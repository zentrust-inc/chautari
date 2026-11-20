#!/usr/bin/env bash
# End-to-end test on the TEST server, through https like a phone: sign in, record work hours with photos (sent twice,
# recorded once), a spring reading, read a sample bill, confirm it, and check the chain. Run as root on the server:
#   sudo bash /srv/chautari/repo/deploy/server/test-live.sh
# It loads the SAMPLE people (seed/demo.sql) if the database is empty. Only on a server marked TEST.
set -uo pipefail
S=/srv/chautari; D=$(cat $S/domain); U="https://$D"
[ -f $S/TEST_SERVER ] || { echo "not a TEST server: refusing"; exit 2; }
ev() { grep -m1 "^$1=" $S/supabase/.env | cut -d= -f2- | sed 's/^"//; s/"$//'; }
ANON=$(ev ANON_KEY); SERVICE=$(ev SERVICE_ROLE_KEY)
psqldb() { docker exec -i supabase-db psql -X -q -At -v ON_ERROR_STOP=1 -U supabase_admin -d postgres "$@"; }
pass=0; fail=0
ok() { if [ "$2" = "true" ]; then echo "PASS  $1"; pass=$((pass+1)); else echo "FAIL  $1 ${3:-}"; fail=$((fail+1)); fi; }

if [ "$(psqldb -c 'select count(*) from ww.entities')" = "0" ]; then
  echo "loading the SAMPLE people and activity (seed/demo.sql)"; psqldb < $S/repo/seed/demo.sql >/dev/null
  docker restart supabase-rest >/dev/null; sleep 4
fi

# a test sign-in for गीता (ledger keeper, sample person 4): an auth user with a random password, linked to her
PW=$(openssl rand -hex 16); EMAIL="gita.test@chautari.invalid"
uid=$(curl -s "$U/auth/v1/admin/users?per_page=200" -H "apikey: $SERVICE" -H "Authorization: Bearer $SERVICE" | jq -r --arg e "$EMAIL" '.users[] | select(.email==$e) | .id')
if [ -n "$uid" ]; then
  curl -s -X PUT "$U/auth/v1/admin/users/$uid" -H "apikey: $SERVICE" -H "Authorization: Bearer $SERVICE" -H 'Content-Type: application/json' -d "{\"password\":\"$PW\"}" >/dev/null
else
  uid=$(curl -s -X POST "$U/auth/v1/admin/users" -H "apikey: $SERVICE" -H "Authorization: Bearer $SERVICE" -H 'Content-Type: application/json' \
        -d "{\"email\":\"$EMAIL\",\"password\":\"$PW\",\"email_confirm\":true}" | jq -r .id)
fi
psqldb -c "update ww.persons set auth_user_id = null where auth_user_id = '$uid'; update ww.persons set auth_user_id = '$uid' where display_name = 'गीता'" >/dev/null
TOK=$(curl -s -X POST "$U/auth/v1/token?grant_type=password" -H "apikey: $ANON" -H 'Content-Type: application/json' -d "{\"email\":\"$EMAIL\",\"password\":\"$PW\"}" | jq -r .access_token)
ok "sign-in gives a session" "$([ ${#TOK} -gt 100 ] && echo true || echo false)"
rpc() { curl -s -X POST "$U/rest/v1/rpc/$1" -H "apikey: $ANON" -H "Authorization: Bearer $TOK" -H 'Content-Type: application/json' -d "$2"; }
anon() { curl -s "$U/rest/v1/$1" -H "apikey: $ANON"; }

me=$(rpc my_record '{}'); ok "my_record is गीता's own record" "$(echo "$me" | jq '.person.name == "गीता"')" "$me"
w=$(rpc officer_workers '{"p_entity":"thumki-cfug"}'); ok "officer_workers lists the ward's people" "$(echo "$w" | jq 'length >= 10')"
dil=$(echo "$w" | jq -r '.[] | select(.name=="दिल") | .person_id')
code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$U/rest/v1/rpc/officer_workers" -H "apikey: $ANON" -H 'Content-Type: application/json' -d '{"p_entity":"thumki-cfug"}')
ok "the public cannot read the worker list (HTTP $code)" "$([ "$code" != 200 ] && echo true || echo false)"

# two photos through the reader service (/reader/photo), as the phone sends them
convert -size 320x240 xc:'#7a6' /tmp/before.jpg 2>/dev/null || docker run --rm -v /tmp:/t chautari-reader convert -size 320x240 xc:'#7a6' /t/before.jpg
docker run --rm -v /tmp:/t chautari-reader convert -size 320x240 xc:'#46a' /t/after.jpg
eb=$(curl -s -X POST "$U/reader/photo?entity=thumki-cfug&kind=before" -H "Authorization: Bearer $TOK" -H 'Content-Type: image/jpeg' --data-binary @/tmp/before.jpg)
ea=$(curl -s -X POST "$U/reader/photo?entity=thumki-cfug&kind=after" -H "Authorization: Bearer $TOK" -H 'Content-Type: image/jpeg' --data-binary @/tmp/after.jpg)
ok "the before photo is kept under its SHA-256" "$(echo "$eb" | jq --arg s "$(sha256sum /tmp/before.jpg | cut -c1-64)" '.sha256 == $s')" "$eb"
ok "it is on the server's disk" "$([ -f $S/documents/thumki-cfug/$(echo "$eb" | jq -r .sha256).jpg ] && echo true || echo false)"
ok "photos only for signed-in people" "$([ "$(curl -s -o /dev/null -w '%{http_code}' $U/reader/documents/thumki-cfug/$(echo "$eb" | jq -r .sha256).jpg)" = 401 ] && echo true || echo false)"

ref=$(cat /proc/sys/kernel/random/uuid); wid=$(cat /proc/sys/kernel/random/uuid); today=$(TZ=Asia/Kathmandu date +%F)
body=$(jq -n --arg r "$ref" --arg w "$wid" --arg p "$dil" --arg d "$today" --argjson b "$eb" --argjson a "$ea" \
  '{p_client_ref:$r, p_entity:"thumki-cfug", p_type:"work.logged", p_payload:{work_id:$w, project:"परीक्षण", task_np:"परीक्षण काम", hours:2, paid:false},
    p_private:{person_id:$p}, p_occurred_on:$d, p_fiscal_year:"2083/84", p_evidence:[$b,$a]}')
r1=$(rpc record_event_once "$body"); r2=$(rpc record_event_once "$body")
ok "work hours with both photos are recorded in गीता's name" "$(echo "$r1" | jq '.seq > 0 and .already == false')" "$r1"
ok "sending the same entry again returns the same entry, not a second one" "$(jq -n --argjson a "$r1" --argjson b "$r2" '$a.seq == $b.seq and $b.already == true')" "$r2"
ok "the work waits for a supervisor" "$([ "$(psqldb -c "select status from ww.work_logs where id = '$wid'")" = pending ] && echo true || echo false)"

rd=$(jq -n --arg r "$(cat /proc/sys/kernel/random/uuid)" --arg d "$today" '{p_client_ref:$r, p_entity:"thumki-cfug", p_type:"reading.spring", p_payload:{spring_id:"कालो धारा", litres_per_minute:3.5, method:"बाल्टी र घडी"}, p_private:{}, p_occurred_on:$d, p_fiscal_year:"2083/84", p_evidence:[]}')
r3=$(rpc record_event_once "$rd"); ok "a spring reading is recorded" "$(echo "$r3" | jq '.seq > 0')" "$r3"

# a SAMPLE bill through the reader, then confirmed by गीता
rb=$(curl -s -X POST "$U/reader/read?entity=thumki-cfug&kind=bill" -H "Authorization: Bearer $TOK" -H 'Content-Type: image/jpeg' --data-binary @$S/repo/samples/bills/hw01.jpg)
sid=$(echo "$rb" | jq -r .suggestion_id); ok "the reader reads a sample bill and hands in a suggestion" "$([ -n "$sid" ] && [ "$sid" != null ] && echo true || echo false)" "$(echo "$rb" | head -c 300)"
ws=$(rpc officer_suggestions '{"p_entity":"thumki-cfug"}'); ok "the bill waits for गीता, with its checks" "$(echo "$ws" | jq --arg s "$sid" 'any(.[]; .suggestion_id == $s and (.checks | type) == "array")')"
payee=$(psqldb -c "select id from ww.payees where entity_id = 'thumki-cfug' and kind = 'shop' order by id limit 1")
line=$(psqldb -c "select id from ww.budget_lines where entity_id = 'thumki-cfug' and cancelled_seq is null order by id limit 1")
acct=$(psqldb -c "select account_code from ww.budget_lines where id = '$line'")
cb=$(jq -n --arg s "$sid" --arg e "$(cat /proc/sys/kernel/random/uuid)" --arg p "$payee" --arg l "$line" --arg a "$acct" --arg d "$today" \
  '{p_suggestion:$s, p_type:"expense.recorded", p_occurred_on:$d, p_fiscal_year:"2083/84",
    p_payload:{expense_id:$e, amount:500, account_code:$a, payee_id:$p, method:"cash", budget_line_id:$l, memo_np:"परीक्षण: नमूना बिल", bill_no:"0417"}}')
rc=$(rpc confirm_suggestion "$cb"); ok "गीता confirms the bill in her own name" "$(echo "$rc" | jq '.seq > 0')" "$(echo "$rc" | head -c 300)"
ok "the public entry says the reader read it and what she changed" "$([ "$(psqldb -c "select payload ? 'ai_read' from ww.events where seq = $(echo "$rc" | jq -r '.seq // 0')")" = t ] && echo true || echo false)"
rc2=$(rpc confirm_suggestion "$cb"); ok "the same bill cannot be confirmed twice" "$(echo "$rc2" | jq 'has("message")')"

ok "the chain verifies on the server" "$([ "$(psqldb -c "select bool_and(ok) from ww.verify_chain('kakani-3')")" = t ] && echo true || echo false)"
heads=$(anon 'chain_heads?select=*'); ok "the public sees the chain head" "$(echo "$heads" | jq 'length > 0')"
echo; echo "$pass passed, $fail failed"

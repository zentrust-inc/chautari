#!/usr/bin/env node
// Chautari — export a demo snapshot for the app's sample mode.
//
// Reads a database built from the migrations + seed/demo.sql and writes every
// public view (read as the `anon` role, exactly what the world sees) plus each
// demo person's own record and officer queues (through the same public.*
// functions the app calls). The app's sample mode then shows the database's own
// output, not hand-made data.
//
//   node scripts/export-snapshot.mjs > app/src/data/sample-snapshot.json
//
// Never point this at the real database: it exports every person's own record.

import { execFileSync } from 'node:child_process';

const db = process.env.PGDATABASE || 'wwos_demo';
const args = ['-X', '-q', '-At', '-v', 'ON_ERROR_STOP=1',
  '-h', process.env.PGHOST || '/var/tmp/wwpg', '-p', process.env.PGPORT || '5433',
  '-U', process.env.PGUSER || 'postgres', '-d', db];
const sql = (q) => JSON.parse(execFileSync('psql', [...args, '-c', q], { encoding: 'utf8', maxBuffer: 64 << 20 }).trim() || 'null');

// refuse anything that is not the demo data
const demo = sql(`select to_json(exists (select 1 from pg_namespace where nspname = 'demo'))`);
if (!demo) { console.error('this database has no demo schema: refusing to export'); process.exit(1); }

const VIEWS = ['bodies', 'money_status', 'income_and_spending', 'budget_status', 'spending_shares', 'payments',
  'fair_turns', 'project_hours', 'office_holders', 'nature_readings', 'questions', 'rules',
  'mpc_summary', 'loan_register', 'grant_register', 'enterprise_results', 'surplus_allocations',
  'chain_export', 'chain_heads'];

// the world: read as anon, so anything anon cannot see is not exported
const pub = {};
for (const v of VIEWS) {
  const order = v === 'chain_export' ? 'order by seq' : '';
  pub[v] = JSON.parse(execFileSync('psql', [...args, '-c', 'set role anon', '-c',
    `select coalesce(json_agg(t ${order}), '[]') from public.${v} t`],
    { encoding: 'utf8', maxBuffer: 64 << 20 }));
}

// demo people (server side, demo only) and what each one sees through the API
const people = sql(`select json_agg(json_build_object(
    'auth', p.auth_user_id, 'name', p.display_name, 'gender', p.gender,
    'house_no', h.house_no,
    'roles', coalesce((select json_agg(json_build_object('entity', r.entity_id, 'role', r.role))
                         from ww.role_terms r where r.person_id = p.id and r.to_seq is null), '[]'))
    order by h.house_no)
  from ww.persons p left join ww.households h on h.id = p.household_id`);

const asPerson = (auth, call) => {
  try {
    const out = execFileSync('psql', [...args, '-c', 'set role authenticated',
      '-c', `set request.jwt.claim.sub = '${auth}'`, '-c', `select ${call}`],
      { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });
    return JSON.parse(out || 'null');
  } catch { return null; }   // not allowed for this person: the app shows nothing
};
const rows = (fn) => `coalesce((select json_agg(t) from ${fn} t), '[]')`;

const OFFICER_ROLES = ['chair', 'secretary', 'treasurer', 'accounts_committee', 'supervisor', 'ledger_keeper'];
for (const p of people) {
  p.my_record = asPerson(p.auth, 'public.my_record()');
  p.my_account = asPerson(p.auth, `public.my_account('kakani-mpc')`);
  p.officer = {};
  for (const { entity, role } of p.roles) {
    if (!OFFICER_ROLES.includes(role)) continue;
    const o = (p.officer[entity] ??= {});
    if (role === 'supervisor' || role === 'ledger_keeper') {
      o.workers ??= asPerson(p.auth, rows(`public.officer_workers('${entity}')`));
    }
    if (role === 'ledger_keeper') continue;
    if (role !== 'supervisor') {
      o.payments_waiting ??= asPerson(p.auth, rows(`public.officer_payments_waiting('${entity}')`));
    }
    if (role === 'supervisor' || role === 'accounts_committee') {
      o.work_waiting ??= asPerson(p.auth, rows(`public.officer_work_waiting('${entity}')`));
    }
    if (role === 'accounts_committee') {
      o.questions ??= asPerson(p.auth, rows(`public.officer_questions('${entity}')`));
    }
  }
}

process.stdout.write(JSON.stringify({
  kind: 'wu-wei-os-demo-snapshot',
  note: 'Fictional people and sample activity from seed/demo.sql. Not real records.',
  exported_at: new Date().toISOString(),
  public: pub,
  people,
}));

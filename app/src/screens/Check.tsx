import { useState } from 'preact/hooks';
import { lang, t } from '../lib/i18n';
import { num } from '../lib/format';
import { chainReport, checkChain, pub } from '../state';
import { source } from '../data/source';
import { verify, type WardReport } from '../lib/chain';
import { Screen, Section, Pill } from '../ui';

// Anyone can check the record on their own phone: no login, no trust in the server.
export function Check() {
  const rep = chainReport.value;
  const heads = pub.value?.chain_heads ?? [];
  const [tampered, setTampered] = useState<{ rep: WardReport[]; seq: number } | null>(null);

  const tamper = async () => {
    const rows = (await source.chain()).map((r) => ({ ...r }));
    // change the amount of one paid voucher, in this phone's copy only
    const target = rows.find((r) => r.type === 'payment.released');
    if (!target) return;
    const p = JSON.parse(target.payload_text);
    p.amount = Number(p.amount) + 1000;
    target.payload_text = JSON.stringify(p);
    setTampered({ rep: await verify(rows), seq: Number(target.seq) });
  };

  return (
    <Screen title={t('check_title')} back={false}>
      <p class="lede">{t('check_what')}</p>
      {!rep && <p class="empty">{t('chain_checking')}</p>}
      {rep?.map((r) => {
        const pubHead = heads.find((h) => h.ward_id === r.ward)?.head_hash;
        return (
          <div class={`verdict ${r.ok ? 'ok' : 'bad'}`} key={r.ward}>
            <p class="verdict-title"><span class="seal" aria-hidden="true" />{r.ok ? t('chain_ok') : t('chain_bad')}</p>
            <p>{num(r.entries)} {t('entries')}{!r.ok && r.problem ? ` · ${t('problem_at')} ${num(r.problem.seq)}` : ''}</p>
            <p class="hash"><span class="item-meta">{t('head')}</span><code>{r.head}</code></p>
            {pubHead && <p class="item-meta">{t('published_head')}: {pubHead === r.head ? <Pill tone="good">{t('match')}</Pill> : <Pill tone="bad">✗</Pill>}</p>}
          </div>
        );
      })}
      <button class="btn btn-quiet" onClick={() => checkChain()}>{lang.value === 'np' ? 'फेरि जाँच्नुहोस्' : 'Check again'}</button>

      <Section title={t('tamper')} note={t('tamper_what')}>
        {!tampered ? <button class="btn" onClick={tamper}>{t('tamper')}</button> : (
          <>
            {tampered.rep.map((r) => (
              <div class={`verdict ${r.ok ? 'ok' : 'bad'}`} key={r.ward}>
                <p class="verdict-title"><span class="seal" aria-hidden="true" />{r.ok ? t('chain_ok') : t('chain_bad')}</p>
                <p>{lang.value === 'np' ? `इन्ट्री नं. ${num(tampered.seq)} को रकम रु १,००० बढाइयो।` : `Entry ${tampered.seq}: amount raised by Rs 1,000.`}</p>
                {r.problem && <p>{t('problem_at')} {num(r.problem.seq)}: {lang.value === 'np' ? 'औंठाछाप मिलेन' : 'fingerprint does not match'}</p>}
              </div>
            ))}
            <button class="btn btn-quiet" onClick={() => setTampered(null)}>{t('restore')}</button>
          </>
        )}
      </Section>

      <Section title={lang.value === 'np' ? 'कम्प्युटरमा जाँच्न' : 'To check on a computer'}>
        <pre class="code">node scripts/verify-chain.mjs export.json --head {rep?.[0]?.head.slice(0, 12) ?? '…'}…</pre>
      </Section>
    </Screen>
  );
}

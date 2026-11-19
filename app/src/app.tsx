import { useEffect } from 'preact/hooks';
import { lang, setLang, t } from './lib/i18n';
import { todayBS } from './lib/format';
import { pub, loadError, route, loadAll, checkChain, officerRoles, go, me } from './state';
import { offline, source } from './data/source';
import { Home } from './screens/Home';
import { Money } from './screens/Money';
import { Work } from './screens/Work';
import { Nature } from './screens/Nature';
import { Decisions } from './screens/Decisions';
import { Coop } from './screens/Coop';
import { Mine } from './screens/Mine';
import { Tasks } from './screens/Tasks';
import { Check } from './screens/Check';
import { Capture } from './screens/Capture';
import { Readings } from './screens/Readings';
import { WorkLog } from './screens/WorkLog';
import { useState } from 'preact/hooks';

// The how-to guide is loaded only when opened, so it never adds to the first load on 3G.
function Guide() {
  const [G, setG] = useState<null | (() => preact.JSX.Element)>(null);
  useEffect(() => { import('./screens/Guide').then((m) => setG(() => m.Guide)); }, []);
  return G ? <G /> : <main class="screen"><p class="empty">{t('loading')}</p></main>;
}

const SCREENS: Record<string, (p: any) => preact.JSX.Element> = {
  home: Home, money: Money, work: Work, nature: Nature, decisions: Decisions, coop: Coop, mine: Mine, tasks: Tasks, check: Check, help: Guide, capture: Capture, readings: Readings, worklog: WorkLog,
};

export function App() {
  useEffect(() => { loadAll().then(() => checkChain().catch(() => {})); }, []);
  const r = route.value in SCREENS ? route.value : 'home';
  const Screen = SCREENS[r];
  const showTasks = officerRoles.value.length > 0;
  const tab = (id: string) => (['money', 'work', 'nature', 'decisions', 'coop'].includes(r) ? 'home' : ['capture', 'readings', 'worklog'].includes(r) ? 'tasks' : r) === id;

  return (
    <div class="app" lang={lang.value === 'np' ? 'ne' : 'en'}>
      <header class="topbar">
        <button class="brand" onClick={() => go('home')} aria-label={t('home')}>
          <span class="brand-mark" aria-hidden="true" />{t('app')}
        </button>
        <span class="today">{todayBS()}</span>
        {source.mode === 'sample' && <span class="sample-badge">{t('sample')}</span>}
        <button class="lang" onClick={() => setLang(lang.value === 'np' ? 'en' : 'np')}>{t('language')}</button>
      </header>
      {offline.value && <p class="offline">{t('offline')}</p>}
      {loadError.value && !pub.value ? (
        <main class="screen"><p class="error">{t('error')}</p><button class="btn" onClick={loadAll}>{t('retry')}</button></main>
      ) : !pub.value ? (
        <main class="screen"><p class="empty">{t('loading')}</p></main>
      ) : <Screen />}
      <nav class="tabbar" aria-label="main">
        <button class={tab('home') ? 'on' : ''} onClick={() => go('home')}><Icon d="M4 11l8-7 8 7v9h-5v-6H9v6H4z" />{t('home')}</button>
        <button class={tab('mine') ? 'on' : ''} onClick={() => go('mine')}><Icon d="M12 12a4 4 0 1 0 0-8a4 4 0 1 0 0 8 M4 21c0-4 3.6-7 8-7s8 3 8 7" />{me.value ? me.value.name : t('mine')}</button>
        {showTasks && <button class={tab('tasks') ? 'on' : ''} onClick={() => go('tasks')}><Icon d="M9 6h11 M9 12h11 M9 18h11 M4 6l1 1 2-2 M4 12l1 1 2-2 M4 18l1 1 2-2" />{t('tasks')}</button>}
        <button class={tab('check') ? 'on' : ''} onClick={() => go('check')}><Icon d="M12 3l7 3v5c0 5-3 8-7 10c-4-2-7-5-7-10V6z M9 12l2 2 4-4" />{t('check')}</button>
        <button class={tab('help') ? 'on' : ''} onClick={() => go('help')}><Icon d="M12 21a9 9 0 1 0 0-18a9 9 0 1 0 0 18 M9.5 9a2.5 2.5 0 1 1 3.5 2.3c-.6.3-1 .9-1 1.6v.6 M12 17h.01" />{t('help')}</button>
      </nav>
    </div>
  );
}
const Icon = ({ d }: { d: string }) => <svg viewBox="0 0 24 24" aria-hidden="true"><path d={d} /></svg>;

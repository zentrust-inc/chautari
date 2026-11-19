import { render } from 'preact';
import { App } from './app';
import './styles.css';

if (!__PREVIEW__) {
  // self-hosted Mukta (Devanagari + Latin), so text renders the same offline
  import('./fonts');
  if ('serviceWorker' in navigator && import.meta.env.PROD) {
    window.addEventListener('load', () => navigator.serviceWorker.register('./sw.js').catch(() => {}));
  }
}
render(<App />, document.getElementById('app')!);

import { defineConfig } from 'vite';
import preact from '@preact/preset-vite';
import { viteSingleFile } from 'vite-plugin-singlefile';
import { readFileSync, writeFileSync, readdirSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';
import { createHash } from 'node:crypto';

// After the installable build, list every file into sw.js so the phone saves the whole app on first visit.
function precache() {
  return {
    name: 'chautari-precache',
    apply: 'build' as const,
    closeBundle() {
      const out = 'dist';
      const files: string[] = [];
      const walk = (d: string) => readdirSync(d).forEach((f) => {
        const p = join(d, f);
        statSync(p).isDirectory() ? walk(p) : files.push(relative(out, p).split('\\').join('/'));
      });
      walk(out);
      const list = ['./', ...files.filter((f) => f !== 'sw.js' && !f.endsWith('.woff')).sort().map((f) => './' + f)];
      const hash = createHash('sha256');
      files.filter((f) => f !== 'sw.js').sort().forEach((f) => hash.update(f).update(readFileSync(join(out, f))));
      const sw = readFileSync(join(out, 'sw.js'), 'utf8')
        .replace('__BUILD_ID__', hash.digest('hex').slice(0, 12))
        .replace('__PRECACHE__', JSON.stringify(list));
      writeFileSync(join(out, 'sw.js'), sw);
    },
  };
}

const pkg = JSON.parse(readFileSync(new URL('./package.json', import.meta.url), 'utf8'));

// `vite build`                -> the installable PWA (dist/), live when VITE_SUPABASE_* are set
// `vite build --mode preview` -> one self-contained page in sample mode (dist-preview/), for sharing
export default defineConfig(({ mode }) => {
  const preview = mode === 'preview';
  return {
    base: './',
    plugins: [preact(), ...(preview ? [viteSingleFile()] : [precache()])],
    define: {
      __PREVIEW__: JSON.stringify(preview),
      __VERSION__: JSON.stringify(pkg.version),
      __BUILD_DATE__: JSON.stringify(new Date().toISOString().slice(0, 10)),
    },
    build: {
      outDir: preview ? 'dist-preview' : 'dist',
      target: 'es2019',
      ...(preview ? { copyPublicDir: false } : {}),
    },
  };
});

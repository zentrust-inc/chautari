import { defineConfig } from 'vite';
import preact from '@preact/preset-vite';
import { viteSingleFile } from 'vite-plugin-singlefile';
import { readFileSync } from 'node:fs';

const pkg = JSON.parse(readFileSync(new URL('./package.json', import.meta.url), 'utf8'));

// `vite build`                -> the installable PWA (dist/), live when VITE_SUPABASE_* are set
// `vite build --mode preview` -> one self-contained page in sample mode (dist-preview/), for sharing
export default defineConfig(({ mode }) => {
  const preview = mode === 'preview';
  return {
    base: './',
    plugins: [preact(), ...(preview ? [viteSingleFile()] : [])],
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

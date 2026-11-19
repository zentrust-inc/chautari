// Builds the two shareable forms of the sample-mode app from `vite build --mode preview`:
//   demo/index.html               a standalone page anyone can open in a browser (the repo's one demo)
//   app/dist-preview/chautari.html the same page without <html>/<head>/<body>, for a claude.ai artifact
//   demo/chautari-offline.html    one file with the Mukta font inside, to send on WhatsApp and open with no internet
// The first two load fonts from Google Fonts; offline they fall back to the phone's own Devanagari font.
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
const src = readFileSync('dist-preview/index.html', 'utf8');
const fonts = '<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>\n' +
  '<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Mukta:wght@400;600&display=swap">';

const standalone = src.replace(/\s*<link rel="(manifest|icon|apple-touch-icon)"[^>]*>/g, '').replace('</title>', '</title>\n' + fonts);
mkdirSync('../demo', { recursive: true });
writeFileSync('../demo/index.html', standalone);

// Offline file: same page, fonts embedded (Devanagari + Latin, 400 and 600), nothing fetched from the internet.
const face = (sub, w) => {
  const b64 = readFileSync(`node_modules/@fontsource/mukta/files/mukta-${sub}-${w}-normal.woff2`).toString('base64');
  return `@font-face{font-family:'Mukta';font-style:normal;font-weight:${w};font-display:swap;src:url(data:font/woff2;base64,${b64}) format('woff2')}`;
};
const embedded = '<style>' + ['devanagari', 'latin'].flatMap((sub) => [400, 600].map((w) => face(sub, w))).join('') + '</style>';
const offline = standalone.replace(fonts, embedded);
writeFileSync('../demo/chautari-offline.html', offline);

const pick = (re) => [...src.matchAll(re)].map((m) => m[0]).join('\n');
const page = ['<title>चौतारी</title>', '<meta name="claude:viewport-fit-sides" content="cover">', fonts,
  pick(/<style[\s\S]*?<\/style>/g), '<div id="app"></div>', pick(/<script[\s\S]*?<\/script>/g)].join('\n');
writeFileSync('dist-preview/chautari.html', page);
console.log('demo/index.html', (standalone.length / 1024).toFixed(0), 'KB; demo/chautari-offline.html', (offline.length / 1024).toFixed(0), 'KB; app/dist-preview/chautari.html', (page.length / 1024).toFixed(0), 'KB');

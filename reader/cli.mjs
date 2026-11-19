#!/usr/bin/env node
// node reader/cli.mjs [--cashbook] photo.jpg [...]   prints each suggestion as JSON
import { readDocument } from './read.mjs';
const args = process.argv.slice(2);
const kind = args.includes('--cashbook') ? 'cashbook' : 'bill';
const files = args.filter((a) => !a.startsWith('--'));
if (!files.length) { console.error('usage: node reader/cli.mjs [--cashbook] photo.jpg ...'); process.exit(2); }
for (const f of files) console.log(JSON.stringify({ file: f, ...(await readDocument(f, { kind })) }, null, 2));

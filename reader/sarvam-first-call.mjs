// First call to Sarvam Vision (Document AI, parse): one photo in, the text it reads out.
// Run: node --env-file=.env sarvam-first-call.mjs [photo] [printed|handwritten|mixed]
// The key comes from SARVAM_API_KEY (reader/.env, never committed). This sends the photo to Sarvam (India).
import fs from 'node:fs';
import { SarvamAIClient } from 'sarvamai';

const file = process.argv[2] ?? '../samples/hard/hcb01.jpg';
const contentType = process.argv[3] ?? 'handwritten';
const client = new SarvamAIClient({ apiSubscriptionKey: process.env.SARVAM_API_KEY });

const job = await client.docAi.parse({ file: [fs.createReadStream(file)], language: 'ne-IN', content_type: contentType });
console.log('job', job.job_id, job.status);

const DONE = new Set(['completed', 'partially_completed', 'failed', 'rejected']);
let st;
do {
  await new Promise((r) => setTimeout(r, 3000));
  st = await client.docAi.getStatus(job.job_id);
} while (!DONE.has(String(st.status).toLowerCase()));
console.log('status', st.status, JSON.stringify(st.usage ?? {}));

if (['completed', 'partially_completed'].includes(String(st.status).toLowerCase())) {
  const res = await client.docAi.getResults(job.job_id);
  console.log(JSON.stringify(res, null, 2));
} else {
  console.log(JSON.stringify(st, null, 2));
}

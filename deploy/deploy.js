#!/usr/bin/env node
/**
 * Uploads the release AAB to Google Play via the androidpublisher API.
 *
 * Usage (from repo root, after `cd deploy && npm install`):
 *   node deploy/deploy.js --track=production --priority=3 --fraction=0.1
 *
 * Flags:
 *   --track=production|sharing|internal   default: internal
 *   --priority=0..5    sets inAppUpdatePriority on the release (default 0)
 *   --force            100% rollout (production only; default is --fraction)
 *   --fraction=0.1     staged rollout fraction for production (default 0.1)
 *   --dry-run          upload + validate the edit, then discard it (no publish)
 *   --yes              skip confirmation prompts (CI)
 *
 * Needs deploy/service-account.json (never commit it).
 */
const fs = require('fs');
const path = require('path');
const readline = require('readline');
const { google } = require('googleapis');

const PACKAGE_NAME = 'com.vengurlatech.qless';
const AAB_PATH = path.resolve(
  __dirname,
  '../frontend/build/app/outputs/bundle/release/app-release.aab'
);
const KEY_PATH = path.resolve(__dirname, 'service-account.json');
const TRACKS = ['production', 'sharing', 'internal'];

function parseArgs(argv) {
  const opts = {
    track: 'internal',
    priority: 0,
    force: false,
    fraction: 0.1,
    dryRun: false,
    yes: false,
  };
  for (const arg of argv) {
    const [k, v] = arg.replace(/^--/, '').split('=');
    switch (k) {
      case 'track': opts.track = v; break;
      case 'priority': opts.priority = Number(v); break;
      case 'force': opts.force = true; break;
      case 'fraction': opts.fraction = Number(v); break;
      case 'dry-run': opts.dryRun = true; break;
      case 'yes': opts.yes = true; break;
      default: fail(`Unknown flag: ${arg}`);
    }
  }
  if (!TRACKS.includes(opts.track)) fail(`--track must be one of ${TRACKS.join('|')}`);
  if (!Number.isInteger(opts.priority) || opts.priority < 0 || opts.priority > 5)
    fail('--priority must be an integer 0..5');
  if (!(opts.fraction > 0 && opts.fraction < 1))
    fail('--fraction must be between 0 and 1 (exclusive); use --force for 100%');
  return opts;
}

function fail(msg) {
  console.error(`Error: ${msg}`);
  process.exit(1);
}

function confirm(question, yes) {
  if (yes) return Promise.resolve(true);
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  return new Promise((resolve) =>
    rl.question(`${question} [y/N] `, (a) => {
      rl.close();
      resolve(/^y(es)?$/i.test(a.trim()));
    })
  );
}

async function main() {
  const opts = parseArgs(process.argv.slice(2));

  if (!fs.existsSync(AAB_PATH)) fail(`AAB not found: ${AAB_PATH}\nRun: flutter build appbundle --release`);
  if (!fs.existsSync(KEY_PATH)) fail(`Service account key not found: ${KEY_PATH}`);

  const sizeMb = (fs.statSync(AAB_PATH).size / 1048576).toFixed(1);
  const rollout =
    opts.track === 'production'
      ? opts.force ? '100%' : `${opts.fraction * 100}% (staged)`
      : '100%';
  console.log(`Package:  ${PACKAGE_NAME}`);
  console.log(`AAB:      ${AAB_PATH} (${sizeMb} MB)`);
  console.log(`Track:    ${opts.track}`);
  console.log(`Rollout:  ${rollout}`);
  console.log(`Priority: ${opts.priority}`);
  console.log(`Dry run:  ${opts.dryRun}`);

  if (!(await confirm('Proceed?', opts.yes))) return console.log('Aborted.');

  const auth = new google.auth.GoogleAuth({
    keyFile: KEY_PATH,
    scopes: ['https://www.googleapis.com/auth/androidpublisher'],
  });
  const publisher = google.androidpublisher({ version: 'v3', auth });

  // Internal app sharing: no edit/track, returns a shareable download URL.
  if (opts.track === 'sharing') {
    if (opts.dryRun) return console.log('Dry run: nothing uploaded for internal app sharing.');
    const res = await publisher.internalappsharingartifacts.uploadbundle({
      packageName: PACKAGE_NAME,
      media: { mimeType: 'application/octet-stream', body: fs.createReadStream(AAB_PATH) },
    });
    console.log('Uploaded. Share link:', res.data.downloadUrl);
    return;
  }

  if (opts.track === 'production' && opts.force && !opts.dryRun) {
    if (!(await confirm('--force releases to 100% of production users. Really continue?', opts.yes)))
      return console.log('Aborted.');
  }

  const { data: edit } = await publisher.edits.insert({ packageName: PACKAGE_NAME });
  const editId = edit.id;
  try {
    console.log('Uploading bundle...');
    const { data: bundle } = await publisher.edits.bundles.upload({
      packageName: PACKAGE_NAME,
      editId,
      media: { mimeType: 'application/octet-stream', body: fs.createReadStream(AAB_PATH) },
    });
    console.log(`Uploaded versionCode ${bundle.versionCode}`);

    const full = opts.track !== 'production' || opts.force;
    const release = {
      versionCodes: [String(bundle.versionCode)],
      status: full ? 'completed' : 'inProgress',
      inAppUpdatePriority: opts.priority,
    };
    if (!full) release.userFraction = opts.fraction;

    await publisher.edits.tracks.update({
      packageName: PACKAGE_NAME,
      editId,
      track: opts.track,
      requestBody: { track: opts.track, releases: [release] },
    });

    if (opts.dryRun) {
      await publisher.edits.validate({ packageName: PACKAGE_NAME, editId });
      console.log('Dry run: edit validated OK. Discarding (nothing published).');
      await publisher.edits.delete({ packageName: PACKAGE_NAME, editId });
      return;
    }

    await publisher.edits.commit({ packageName: PACKAGE_NAME, editId });
    console.log(`Published versionCode ${bundle.versionCode} to "${opts.track}" (${rollout}).`);
  } catch (err) {
    try { await publisher.edits.delete({ packageName: PACKAGE_NAME, editId }); } catch (_) {}
    throw err;
  }
}

main().catch((err) => {
  console.error('Deploy failed:', err.errors ? JSON.stringify(err.errors) : err.message);
  process.exit(1);
});

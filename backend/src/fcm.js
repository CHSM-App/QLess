// Firebase Admin, initialised once for every route that sends a push.
//
// Credentials: GOOGLE_APPLICATION_CREDENTIALS (path to the service-account
// JSON), else the legacy routes/ServiceAccountKey.json the server still has.
// With neither, the app still boots and each send() rejects with a clear error
// instead of the whole backend crashing at require time.
//
// Modular API (firebase-admin/app, /messaging): present in v13 and the only
// one in v14, so upgrading is a version bump. Routes keep calling
// `admin.messaging().send(...)` through the object exported below.
const fs = require('fs');
const path = require('path');
const { initializeApp, getApps, cert, applicationDefault } = require('firebase-admin/app');
const { getMessaging } = require('firebase-admin/messaging');
const log = require('./middleware/logger');

if (!getApps().length) {
  const legacyKey = path.join(__dirname, '..', 'routes', 'ServiceAccountKey.json');
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    initializeApp({ credential: applicationDefault() });
  } else if (fs.existsSync(legacyKey)) {
    initializeApp({ credential: cert(require(legacyKey)) });
  } else {
    log.warn('Firebase credentials not found; push notifications will fail');
    initializeApp();
  }
}

module.exports = { messaging: () => getMessaging() };

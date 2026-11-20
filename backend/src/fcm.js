// Firebase Admin, initialised once for every route that sends a push.
//
// Credentials: GOOGLE_APPLICATION_CREDENTIALS (path to the service-account
// JSON), else the legacy routes/ServiceAccountKey.json the server still has.
// With neither, the app still boots and each send() rejects with a clear error
// instead of the whole backend crashing at require time.
const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');
const log = require('./middleware/logger');

if (!admin.apps.length) {
  const legacyKey = path.join(__dirname, '..', 'routes', 'ServiceAccountKey.json');
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    admin.initializeApp({ credential: admin.credential.applicationDefault() });
  } else if (fs.existsSync(legacyKey)) {
    admin.initializeApp({ credential: admin.credential.cert(require(legacyKey)) });
  } else {
    log.warn('Firebase credentials not found; push notifications will fail');
    admin.initializeApp();
  }
}

module.exports = admin;

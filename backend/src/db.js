const sql = require('mssql');
require('dotenv').config({ path: require('path').join(__dirname, '..', '.env'), quiet: true });
const log = require('./middleware/logger');

const required = ['DB_USER', 'DB_PASSWORD', 'DB_SERVER', 'DB_NAME'];
for (const k of required) {
  if (!process.env[k]) {
    throw new Error(`Missing required env var: ${k}. Copy .env.example to .env and fill in values.`);
  }
}

const sqlConfig = {
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  server: process.env.DB_SERVER,
  database: process.env.DB_NAME,
  port: parseInt(process.env.DB_PORT, 10) || 1433,
  options: {
    encrypt: true,
    // Self-signed certs only acceptable outside production.
    trustServerCertificate: true,
  },
  pool: {
    max: parseInt(process.env.DB_POOL_MAX, 10) || 20,
    min: parseInt(process.env.DB_POOL_MIN, 10) || 0,
    idleTimeoutMillis: 30000,
  },
};

const pool = new sql.ConnectionPool(sqlConfig);

// Fires once per failed acquire, so an outage would log every request. Log the
// first, then one line per minute with how many were swallowed.
let poolErrorAt = 0;
let poolErrorsSuppressed = 0;
pool.on('error', (err) => {
  const now = Date.now();
  if (now - poolErrorAt < 60000) { poolErrorsSuppressed++; return; }
  log.error(`MSSQL pool error: ${err.message} (suppressed ${poolErrorsSuppressed})`);
  poolErrorAt = now;
  poolErrorsSuppressed = 0;
});

// Connect on demand (same approach as the billing backend). A failed connect
// leaves the pool retryable, so whoever finds it disconnected starts a fresh
// attempt; concurrent callers share the in-flight one. Failures are logged
// here and never left as unhandled rejections.
let connecting = null;
function ensureConnected() {
  if (pool.connected) return Promise.resolve(pool);
  if (!connecting) {
    connecting = pool.connect()
      .then(() => {
        log.info('MSSQL connected');
        return pool;
      }, (err) => {
        log.error('MSSQL connection failed: ' + err.message);
        throw err;
      })
      .finally(() => { connecting = null; });
  }
  return connecting;
}

ensureConnected().catch(() => {}); // eager first attempt; already logged

// Routes call db.request() directly. If the pool dropped, kick off a reconnect
// so the next request finds it open.
const originalRequest = pool.request.bind(pool);
pool.request = function () {
  if (!pool.connected) ensureConnected().catch(() => {});
  return originalRequest();
};

module.exports = pool;
module.exports.ensureConnected = ensureConnected;

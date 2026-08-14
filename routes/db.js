const sql = require('mssql');
require('dotenv').config();
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

// Eagerly start connecting; routes that call pool.request() before the
// connection resolves will queue, not crash. bin/www awaits ready() before
// binding the HTTP port so the first request always finds a live pool.
 let readyPromise = pool.connect()
  .then(() => {
    log.info('MSSQL connected');
    return pool;
  })
  .catch((err) => {
    log.error('MSSQL connection failed: ' + err.message);
    throw err;
  });

const originalRequest = pool.request.bind(pool);
pool.request = function () {
  if (!pool.connected && !pool.connecting) {
    readyPromise = pool.connect()
      .then(() => {
        log.info('MSSQL reconnected');
        return pool;
      })
      .catch((err) => {
        log.error('MSSQL reconnect failed: ' + err.message);
        throw err;
      });
  }
  return originalRequest();
};

pool.on('error', (err) => {
  log.error('MSSQL pool error: ' + err.message);
  if (pool.closed) {
    readyPromise = pool.connect()
      .then(() => {
        log.info('MSSQL reconnected after pool error');
        return pool;
      })
      .catch((error) => {
        log.error('MSSQL reconnect after pool error failed: ' + error.message);
        throw error;
      });
  }
});

module.exports = pool;
module.exports.ready = () => readyPromise;

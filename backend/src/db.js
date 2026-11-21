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
        checkTimezone();
        return pool;
      }, (err) => {
        log.error('MSSQL connection failed: ' + err.message);
        throw err;
      })
      .finally(() => { connecting = null; });
  }
  return connecting;
}

// The SQL uses GETDATE() for "today" and slot times, all meant as IST. A
// database server on another zone shifts every queue and booking silently.
let timezoneChecked = false;
function checkTimezone() {
  if (timezoneChecked) return;
  timezoneChecked = true;
  pool.request().query('SELECT DATEPART(TZOFFSET, SYSDATETIMEOFFSET()) AS tz')
    .then((r) => {
      const tz = r.recordset?.[0]?.tz;
      if (tz !== 330) log.error(`Database server time is UTC${tz >= 0 ? '+' : ''}${tz / 60}, not IST (UTC+5:30): dates and queue times will be wrong.`);
    })
    .catch((err) => log.error('timezone check failed: ' + err.message));
}

ensureConnected().catch(() => {}); // eager first attempt; already logged

// Routes call db.request() directly. If the pool dropped, kick off a reconnect
// so the next request finds it open.
const originalRequest = pool.request.bind(pool);
pool.request = function () {
  if (!pool.connected) ensureConnected().catch(() => {});
  const request = originalRequest();
  request.run = (queries) => run(request, queries);
  return request;
};

// ── Former stored procedures ────────────────────────────────────────────────
// src/queries/*.js hold the SQL that used to live in stored procedures, one
// batch per @operation. `db.request().input(...).run(queries)` runs the batch
// for the 'operation' input with the procedure's parameters declared as typed
// locals, so values convert, truncate and default exactly as they did, and the
// same errors come back for a missing or unknown parameter.
function run(request, queries) {
  const given = request.parameters;
  const byName = new Map(queries.params.map((p) => [p.name.toLowerCase(), p]));
  for (const name of Object.keys(given)) {
    if (!byName.has(name.toLowerCase())) {
      return Promise.reject(new Error(`@${name} is not a parameter for procedure ${queries.procedure}.`));
    }
  }
  const lines = [];
  for (const p of queries.params) {
    const key = Object.keys(given).find((n) => n.toLowerCase() === p.name.toLowerCase());
    if (key !== undefined) {
      const param = given[key];
      delete given[key];
      given[`__${p.name}`] = { ...param, name: `__${p.name}` };
      lines.push(`DECLARE @${p.name} ${p.type} = @__${p.name};`);
    } else if (p.default !== null) {
      lines.push(`DECLARE @${p.name} ${p.type} = ${p.default};`);
    } else {
      return Promise.reject(new Error(
        `Procedure or function '${queries.procedure}' expects parameter '@${p.name}', which was not supplied.`));
    }
  }
  const opParam = given.__operation;
  const op = opParam ? String(opParam.value).toLowerCase() : null;
  const key = op === null ? null : Object.keys(queries.ops).find((k) => k.toLowerCase() === op);
  const body = key ? queries.ops[key] : queries.other;
  const text = `/* ${queries.procedure}:${key || '-'} */\n${lines.join('\n')}\n${body}`;
  // wait for the pool (a request sent while it is still opening fails)
  return ensureConnected().then(() => request.query(text));
}

module.exports = pool;
module.exports.ensureConnected = ensureConnected;
module.exports.run = run; // for requests not created by db.request() (e.g. inside a transaction)

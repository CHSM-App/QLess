#!/usr/bin/env node
// One-off runner for the .sql scripts in backend/scripts/.
// Reuses the exact same connection config as routes/db.js (same backend/.env),
// so it works wherever that file already works — your machine or the server.
//
// Usage (run from the backend/ directory):
//   node scripts/run-sql.js scripts/add-manoj-swant-kudal.sql
//   node scripts/run-sql.js scripts/add-demo-receptionist.sql
//   node scripts/run-sql.js scripts/add-demo-patient.sql
//
// Or via the npm script added to package.json:
//   npm run db -- scripts/add-demo-patient.sql
//
// Uses pool.request().batch() (not .query()) because these scripts rely on
// T-SQL batch-level statements (DECLARE, BEGIN TRAN, IF EXISTS, RAISERROR,
// RETURN) that .query() does not reliably support.

require('dotenv').config();
const fs = require('fs');
const path = require('path');
const sql = require('mssql');

const file = process.argv[2];
if (!file) {
  console.error('Usage: node scripts/run-sql.js <path-to-sql-file>');
  process.exit(1);
}

const resolved = path.resolve(file);
if (!fs.existsSync(resolved)) {
  console.error(`File not found: ${resolved}`);
  process.exit(1);
}

const required = ['DB_USER', 'DB_PASSWORD', 'DB_SERVER', 'DB_NAME'];
for (const k of required) {
  if (!process.env[k]) {
    console.error(`Missing required env var: ${k}. Copy .env.example to .env and fill in values.`);
    process.exit(1);
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
    trustServerCertificate: true,
  },
};

// GO is an sqlcmd/SSMS batch separator, not real T-SQL — the engine itself
// rejects it ("Incorrect syntax near 'GO'") if sent as part of a batch. Split
// on lines that are only "GO" (optionally with a repeat count, which we
// ignore) and run each piece as its own .batch() call, same as sqlcmd would.
function splitBatches(sqlText) {
  return sqlText
    .split(/^\s*GO\s*(?:\d+)?\s*$/im)
    .map((b) => b.trim())
    .filter(Boolean);
}

(async () => {
  const sqlText = fs.readFileSync(resolved, 'utf8');
  const batches = splitBatches(sqlText);
  console.log(`Connecting to ${sqlConfig.server}/${sqlConfig.database} as ${sqlConfig.user}...`);
  const pool = await sql.connect(sqlConfig);
  try {
    console.log(`Running ${path.basename(resolved)} (${batches.length} batch${batches.length === 1 ? '' : 'es'}) ...`);
    let anyResults = false;

    for (let i = 0; i < batches.length; i++) {
      const result = await pool.request().batch(batches[i]);

      const recordsets = result.recordsets && result.recordsets.length
        ? result.recordsets
        : (result.recordset ? [result.recordset] : []);

      if (recordsets.length) {
        anyResults = true;
        recordsets.forEach((rs, j) => {
          console.log(`-- batch ${i + 1}/${batches.length}, recordset ${j} --`);
          console.table(rs);
        });
      }
    }

    if (!anyResults) console.log('Done — no rows returned.');
  } finally {
    await pool.close();
  }
})().catch((err) => {
  // RAISERROR from the scripts' own guard clauses (e.g. "mobile already
  // exists") surfaces here as a normal failure — that is expected, not a bug.
  console.error('FAILED:', err.message);
  process.exit(1);
});

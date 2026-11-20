# QLess Backend

Express + MSSQL API for the QLess app (doctors, receptionists, patients):
OTP login, live clinic queue over Socket.IO, appointments, prescriptions,
push notifications (Firebase).

## Layout

```
src/
  server.js          Express app + startup (iisnode entry point)
  realtime.js        Socket.IO: queue updates, doctor online/offline
  db.js              MSSQL pool (reconnects on demand)
  fcm.js             Firebase Admin, initialised once
  migrate.js         Migration runner
  migrations/        000_baseline.sql, 001_…, each with an optional _rollback.sql
  middleware/        auth, protect, authorize, roles, rate limits, uploads, logger
  routes/
    auth.js          /login           OTP, sessions, sign-up, clinics, receptionists
    admin.js         /admin           doctor approval panel
    account.js       /delete-account  OTP-verified account deletion
    doctor/          /doctor/*        (insert/ is split by feature)
    patient/         /patient/*
  static/            privacy, terms, delete-account, admin panel pages
scripts/             one-off data scripts (demo users etc.) + run-sql.js
tests/               Jest + supertest (DB, Firebase and cron are mocked)
uploads/             user images (served at /uploads, JWT-gated)
```

Business logic for most endpoints lives in stored procedures (`sp_*`). Their
definitions are versioned in `src/migrations/` — never edit them directly on
the server.

## Setup

```bash
npm install
cp .env.example .env     # fill in DB_*, JWT_SECRET_KEY, CORS_ORIGINS, PUBLIC_BASE_URL
npm run dev              # nodemon, or: npm start
```

Startup refuses to run with `NODE_ENV=production` when a required variable is
missing or `JWT_SECRET_KEY` is shorter than 32 characters.

Push notifications need a Firebase service account: set
`GOOGLE_APPLICATION_CREDENTIALS` to its JSON path (the legacy
`routes/ServiceAccountKey.json` is still picked up). Without one the app runs
and only the pushes fail.

## Database migrations

```bash
npm run migrate:status                  # what is applied / pending
npm run migrate:up                      # apply everything pending
npm run migrate:down                    # roll back the last one
npm run migrate -- create add_something # new 00N_add_something.sql + _rollback.sql
```

Rules (same as the billing backend):
- `GO` between batches, no `BEGIN TRANSACTION` at the top level.
- Procedures and views: `CREATE OR ALTER`.
- No `USE [db]` — the database comes from `.env`.

**New empty database:** `npm run migrate:up` builds everything from `000`.

**Existing database that predates migrations:** run once
`npm run db -- scripts/bootstrap-migrations.sql` (marks `000` applied), then
`npm run migrate:up`.

One-off data scripts: `npm run db -- scripts/<file>.sql`.

## Tests

```bash
npm test
```

Route tests run against a scripted DB mock (`tests/helpers/db.js`): a suite
answers by stored procedure + `@operation` instead of by call order.

## Deployment (IIS / iisnode)

`web.config` points iisnode at `src/server.js`. Deploy `src/`, `web.config`,
`package.json` and `package-lock.json` together, run `npm ci --omit=dev`, then
`npm run migrate:up` if there are pending migrations. Keep `.env` and the
Firebase key on the server; they are not in git.

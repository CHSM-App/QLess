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
  queries/           SQL that used to be stored procedures, one batch per operation
  familyMembers.js   family-member insert/update (patient app + walk-in)
  middleware/        auth, protect, authorize, roles, ownPatient, rate limits, uploads, logger
  routes/
    auth/            /login           index.js mounts: session, lookups, signup, otp,
                                      pages, clinics, receptionist; helpers in shared.js
    admin.js         /admin           doctor approval panel
    account.js       /delete-account  OTP-verified account deletion
    doctor/          /doctor/*        (insert/ is split by feature)
    patient/         /patient/*
  static/            privacy, terms, delete-account, admin panel pages
scripts/             one-off data scripts (demo users etc.) + run-sql.js
tests/               Jest + supertest (DB, Firebase and cron are mocked)
uploads/             user images (served at /uploads, JWT-gated)
```

There are no stored procedures any more: all SQL lives in this repo. Most of it
is inline in the routes; the large former procedures (appointments, doctors,
patients, …) are in `src/queries/*.js` as one SQL batch per operation:

```js
const appointmentsSql = require('../queries/appointments');
await db.request()
  .input('operation', 'NEXT_SESSION')
  .input('doctor_id', doctor_id)
  .run(appointmentsSql);   // see run() in src/db.js
```

`run()` declares the old procedure parameters as typed locals, so values
convert and default exactly as they did. Change a batch like any other code
(with its test); schema changes still go through `src/migrations/`.

Access rules: `/doctor/insert/*` is for doctor and receptionist tokens; on
`/patient/*` a patient token may only use its own ids (and its family members'
where the app books for family) — `src/middleware/ownPatient.js`.

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
npm run test:coverage   # fails if coverage drops below the threshold in package.json
```

When a change raises coverage, raise `jest.coverageThreshold` to the new floor
(rounded down) in the same commit — it only ever goes up.

Route tests run against a scripted DB mock (`tests/helpers/db.js`): a suite
answers by stored procedure + `@operation` instead of by call order.

`npm run lint` (ESLint errors only, as CI runs it); `npm run lint:all` also lists
the style warnings in older code. CI (`.github/workflows/main.yml`, job
`test-backend`) runs lint, tests with coverage and `npm audit --omit=dev
--audit-level=high`, and only then syncs the `backend` branch Plesk deploys.

## Response shapes

Existing routes answer in the shapes the app already parses: `{ success,
message }`, `{ error }` on auth failures, or a raw array for lists. Don't change
an existing route's shape without changing the app at the same time; its tests
pin the current one. **New** endpoints use `{ success, message, data }`.
Every 5xx answer is replaced by `{ success: false, message, correlation_id }`
(`hideServerErrors`); the full error is in the log under that id.
`GET /health` → `{ status, db, uptime }` (503 when the database is down).

## Deployment (IIS / iisnode)

`web.config` points iisnode at `src/server.js`. Deploy `src/`, `web.config`,
`package.json` and `package-lock.json` together, run `npm ci --omit=dev`, then
`npm run migrate:up` if there are pending migrations. Keep `.env` and the
Firebase key on the server; they are not in git.

# Deploying the QLess backend

Hosting: Plesk (Windows/IIS + iisnode), deployed with **Plesk Git (pull)**.
Database: SQL Server. `QLess_test_db` doubles as **staging**.

## 1. Server `.env` (production)

| Variable | Value |
|---|---|
| `NODE_ENV` | `production` (startup refuses weak/missing secrets in this mode) |
| `JWT_SECRET_KEY` | 64+ random chars: `node -e "console.log(require('crypto').randomBytes(64).toString('hex'))"` |
| `DB_SERVER`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD` | production database |
| `CORS_ORIGINS` | `https://qless.vengurlatech.com` (no `localhost` in production) |
| `PUBLIC_BASE_URL` | `https://qless.vengurlatech.com` |
| `GOOGLE_APPLICATION_CREDENTIALS` | path to the Firebase service-account JSON, **outside the repo** (e.g. `C:\Inetpub\vhosts\vengurlatech.com\secrets\firebase-admin.json`) |
| `WHATSAPP_API_TOKEN` | SMSala token |
| `DEMO_ENABLED` / `DEMO_OTP` | store-review accounts only: `DEMO_ENABLED=true` with a non-default `DEMO_OTP`, otherwise `false` |
| `SIGNUP_REQUIRES_OTP` / `MOBILE_CHANGE_REQUIRES_OTP` | `false` until the app version with the OTP step (Wave 7) is on most phones, then `true`. While `false`, a missing proof is only logged. |
| `UPLOADS_DIR` | user images folder **outside the repo** (see §4) |
| `ADMIN_USERNAME`, `ADMIN_PASSWORD` | admin panel credential (long, unique) |

`.env` never goes to git. After changing it, restart the app (Plesk → Node.js → Restart).

## 2. Database — first time on an existing database

```bash
npm run db -- scripts/bootstrap-migrations.sql   # once: marks 000 (baseline) as applied
npm run migrate:status                           # 000 applied, the rest pending
npm run migrate:up
```

A **new empty** database: just `npm run migrate:up` (builds everything from 000).

The database login's default schema must be **dbo**: Plesk → Databases → user, or
`ALTER USER [<login>] WITH DEFAULT_SCHEMA = dbo;` (a different default schema made
an older baseline create objects in the wrong schema).

Notes on later migrations:
- **011** adds a CHECK on `appointments.status`. If it stops with "unknown appointment
  status values: …", map those rows to a listed value, then rerun `migrate:up`.
- The database server's clock must be **IST**: the app logs an error at startup
  ("Database server time is UTC…") if it isn't.

**D4 — after a month in production**, look at which `appointments` indexes are used
before merging the four `(doctor_id, appointment_date, …)` ones:
```sql
SELECT i.name, s.user_seeks, s.user_scans, s.user_lookups, s.user_updates
FROM sys.indexes i
LEFT JOIN sys.dm_db_index_usage_stats s
  ON s.object_id = i.object_id AND s.index_id = i.index_id AND s.database_id = DB_ID()
WHERE i.object_id = OBJECT_ID('dbo.appointments');
```
(The counters reset when SQL Server restarts.)

## 3. Each release (checklist)

1. CI green on the branch (backend tests + coverage + `npm audit`, Flutter tests).
2. Deploy to **staging** (the app/env on `QLess_test_db`): pull, `npm ci --omit=dev`,
   `npm run migrate:status` → `npm run migrate:up`.
3. Smoke-test the app against staging: login (doctor, receptionist, patient), token
   refresh after 15 min, booking, queue start → next → skip → recall → stop, registration.
4. Production: Plesk Git pull → additional deployment actions (below) run → check
   `GET /health` and the iisnode log.
5. Rollback: `git revert` the release commit and pull; if it shipped a migration,
   `npm run migrate:down` (one step per run) **before** reverting the code.

**Plesk Git → Additional deployment actions:**
```
cd backend && npm ci --omit=dev && npm run migrate:up
```
If Plesk pulls the CI-built **`backend` branch** (CI copies `backend/` to that branch's
root, only after the backend tests pass), the repo root *is* the backend: use
`npm ci --omit=dev && npm run migrate:up` without `cd backend`.

### First production deploy (once)

1. Back up the production database (§6) and the server's `uploads/` folder.
2. Server `.env` complete (§1): no `localhost` in `CORS_ORIGINS`, `DEMO_ENABLED=false`
   unless store review needs it, both `*_REQUIRES_OTP=false` for now.
3. Database login default schema = `dbo` (§2).
4. Existing database: `npm run db -- scripts/bootstrap-migrations.sql` once, then
   `npm run migrate:status` → only 000 applied → `npm run migrate:up`.
   Read §2's note on 011 if it stops.
5. Move uploads out of the repo **before** the pull that untracks them (§4).
6. IIS settings (§5), scheduled backup (§6), uptime monitor on `/health` (§7).
7. After the pull: `GET /health` → `db: up`; iisnode log has "MSSQL connected" and
   no "not IST" error; log in once as doctor, receptionist and patient.

## 4. User uploads (`uploads/`) — move out of git first

Images are written at runtime and must not live in the repo, but **untracking them
while Plesk pulls would delete them on the server**. Order matters:

1. On the server, copy `backend\uploads\` to a folder outside the repo, e.g.
   `C:\Inetpub\vhosts\vengurlatech.com\qless-uploads\`.
2. Set `UPLOADS_DIR` to that folder in the server `.env`; restart; check an image loads.
3. Only then, in the repo: `git rm -r --cached backend/uploads` + `uploads/` in
   `.gitignore`, commit, pull on the server.

## 5. IIS / Plesk settings

- One node process (`nodeProcessCountPerApplication="1"` in `web.config`): socket
  rooms and doctor online/offline status live in process memory. Scaling out needs
  the socket.io Redis adapter first.
- App pool **idle time-out = 0** and **start mode = AlwaysRunning**, so the daily
  reminder/cleanup cron jobs are not skipped while idle. The startup catch-up
  (`closeStaleSessions`) still covers recycles.
- Server time zone: IST (the SQL uses server-local `GETDATE()` for "today").

## 6. Backups

- Plesk → Backup Manager → scheduled **daily** backup of the database **and**
  `UPLOADS_DIR`, keep 14.
- Restore drill once per quarter onto `QLess_test_db`; note the date here.

## 7. Monitoring

- `GET /health` → `{ status, db, uptime }` for an uptime monitor (every 5 min).
- iisnode logs: `backend\iisnode_logs\` (rotated, 20 × 10 MB).

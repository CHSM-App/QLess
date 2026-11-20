# QLess: Improvement and Optimization Plan

A backlog to implement later. Every item was checked against the code on 2026-11-20. File references are to `backend/src/` unless stated otherwise. Each item follows the project rules: tests first, one change per commit, and schema changes as numbered migrations (`npm run migrate -- create <name>`).

- **Priority:** P0 = fix soon (security or data), P1 = high value, P2 = worthwhile, P3 = nice to have
- **Effort:** S = under half a day, M = 1–2 days, L = 3+ days

## 1. Security

| # | P | Effort | Finding | Fix |
|---|---|---|---|---|
| S1 | P0 | S | `GET /login/getDoctorProfileByClinic` is **unauthenticated** and returns `SELECT *` from `doctor_login_vw` (`routes/auth.js`, around lines 407–437). That gives anyone the doctor's **mobile, email, license_no and FCM token**. | Select only the public columns the app shows: name, clinic, qualification, specialization, experience, image, fee. Test that the response has no `mobile`, `email`, `token` or `license_no`. |
| S2 | P0 | S | ~~`/doctor/insert/*` has no role check, so a patient token can drive a doctor's queue.~~ **Done (Change 1):** `authorize(ROLE.DOCTOR, ROLE.RECEPTIONIST)` on the mount; tested in `tests/routes/protect.test.js`. | — |
| S3 | P0 | M | Patient routes (`routes/patient/*.js`) never compare the `patient_id` in the URL or body with `req.user.uid`. Any patient can read or change another patient's favorites, reviews, family members and appointments (IDOR). | A small `ownPatient` middleware: the token's `uid` must equal the `patient_id`, or own the `family_id`. Apply per route, with a 403 test for each. Do the same audit for doctor routes (`doctor_id` vs `req.user.uid`; receptionists via their doctor). |
| S4 | P1 | S | Refresh tokens are stored in plain text (`RefreshTokens.refresh_token nvarchar(max)`). A database leak would let anyone hijack every session. | Store `SHA-256(token)` in a new `token_hash char(64)` column and compare hashes. This also fixes D1. Needs a migration and one forced re-login. |
| S5 | P1 | S | `helmet({ contentSecurityPolicy: false })` in `server.js`. | Move the inline scripts in `static/*.html` and the landing page into files, then enable a CSP. |
| S6 | P2 | S | `uploads/` (61 user images) and the old `routes/BusinessImages/` are tracked in git. | Confirm how you deploy. If it isn't `git pull`, run `git rm -r --cached uploads` and add it to `.gitignore`. Back up `uploads/` with the database instead. |
| S8 | P0 | S | `/delete-account/request` returns the OTP itself (`dev_otp`) whenever `NODE_ENV !== 'production'` (`routes/account.js`, `sendWhatsAppOtp`). On any non-production server, anyone can schedule deletion of anyone's account. Login OTP (`/login/send-otp`) does not do this. Pinned by `tests/routes/account.test.js`. | Remove `dev_otp` entirely (demo numbers already cover testing), and flip that test to assert it's absent. Confirm the live server's `NODE_ENV=production`. |
| S7 | P2 | S | Many 500 responses return the raw `err.message`, which leaks SQL and driver details. | Return a generic message plus the `correlation_id` that `requestId` already generates; log the detail. |

## 2. Database performance

| # | P | Effort | Finding | Fix |
|---|---|---|---|---|
| D1 | P1 | S | The refresh-token lookup `WHERE refresh_token = @refresh_token` runs on an `nvarchar(max)` column, which **can't be indexed**. Every token refresh is a full table scan: 1,860 rows today, growing between cleanups. | An indexed `token_hash char(64)` (same change as S4), plus an index on `user_mobile` for revoke. |
| D2 | P1 | S | `fetchCurrentServing` (`routes/doctor/insert/shared.js`) and `joinClinic` (`realtime.js`) filter `appointments` by `queue_id` on **every queue action and every patient socket join**, and there's no index on `queue_id`. | `CREATE INDEX IX_appointments_queue ON appointments (queue_id, status) INCLUDE (queue_number, booking_type)`. |
| D3 | P1 | S | The inbox lookup `SELECT patient_id FROM patients WHERE token = @token` (`insertNotificationForToken` in `shared.js`) also runs on `nvarchar(max)`. That's one scan per notification, often inside loops. | Pass `patient_id` from the procedure result instead of re-deriving it from the token, or add an indexed `token_hash`. |
| D4 | P2 | S | `appointments` has 4 overlapping indexes, all starting with `(doctor_id, appointment_date)`: `IDX_APPOINTMENT_MAIN`, `IDX_SLOT`, `IDX_QUEUE`, `IDX_BOOKING_TYPE`. Each one adds write cost to every booking. | Check usage with `sys.dm_db_index_usage_stats`. Keep one with `INCLUDE` columns and drop the rest. |
| D5 | P2 | S | `hasNotificationBeenSent` queries `notifications (patient_id, type, ref_id)`, but only `(patient_id, created_at)` is indexed. | Add a `(patient_id, type, ref_id)` index, or a unique filtered index, which gives real idempotency instead of check-then-insert. |
| D6 | P2 | M | Status values include the typo `'cancled'` alongside `'cancelled'` (12 places, e.g. `shared.js` lines 39 and 45). | Migration: `UPDATE … SET status = 'cancelled' WHERE status = 'cancled'`, and find the procedure branch that writes it. Then drop the typo from all filters and add a CHECK constraint on allowed statuses. |
| D7 | P3 | S | `RefreshTokens` ids come from `MAX(id)+1` under `UPDLOCK, HOLDLOCK` (`ManageRefreshToken`), which serialises every login. | Make `id` an `IDENTITY` column (a migration with a table rebuild). |
| D8 | P3 | S | `GETDATE()`, which is server-local time, decides "today" in 4 inline SQL places and in the procedures. The server's timezone is an assumption. | Standardise on IST explicitly (`SYSDATETIMEOFFSET() AT TIME ZONE 'India Standard Time'`), or on UTC with a conversion. |

## 3. API and Node performance

| # | P | Effort | Finding | Fix |
|---|---|---|---|---|
| A1 | P1 | M | Queue start, pause and emergency pause notify patients **one at a time** in `for … of` loops: `await insertNotificationForToken` plus one FCM call per token (`routes/doctor/insert/appointments.js`, around lines 158, 245 and 746). A queue of 40 patients means 40+ sequential database round trips and FCM calls before the doctor's request returns. | One `sendEachForMulticast` (already used elsewhere in the same file) and one batched inbox `INSERT … SELECT`. Respond to the doctor **before** the fan-out and let it run in the background with logged errors, as `sendPositionNotifications` already does. |
| A2 | P2 | S | `realtime.js` and several routes make 50 `console.log` calls. They bypass the redacting logger (`middleware/logger.js`), can print mobiles and tokens, and clutter the iisnode logs. | Replace them with `log.debug` / `log.info`; the logger already redacts. |
| A3 | P2 | S | Two places log whole recordsets with `JSON.stringify` (e.g. the walk-in family insert). | Log ids only. |
| A4 | P3 | S | `getDoctorProfileByClinic` and similar public lookups return full rows, so payloads are larger than needed. | Explicit column lists (same fix as S1). |

## 4. Reliability

| # | P | Effort | Finding | Fix |
|---|---|---|---|---|
| R1 | P1 | S | There's no health endpoint for monitoring or uptime checks. | `GET /health` returning `{ db: ok }` (via `ensureConnected()`), with a small rate limit. |
| R2 | P2 | M | Doctor online/offline status and socket rooms live in process memory (`realtime.js`, five `new Map()`s). An IIS recycle wipes them, and running more than one process would split them. | Keep `nodeProcessCountPerApplication="1"` and document why; the app already re-joins on reconnect. If you ever scale out, use the socket.io Redis adapter. |
| R3 | P2 | S | Cron jobs (reminders, the stale-session sweep) run inside the web process, so an app-pool idle shutdown skips them. | Disable the IIS idle timeout for the app pool, or run `node src/jobs.js` as a scheduled task. Keep the startup catch-up. |
| R4 | P2 | S | No automated database backup procedure is documented. | A Plesk scheduled backup of the database and `uploads/`, plus one restore drill. |

## 5. Code quality and maintainability

| # | P | Effort | Finding | Fix |
|---|---|---|---|---|
| Q1 | P1 | L | Business logic sits in 16 stored procedures; `sp_appointment` alone is 3,483 lines. | Move them to inline SQL one procedure at a time, tests first (already planned: favorites first, `sp_appointment` last). |
| Q2 | P1 | L | Tests cover about 9 of 95 routes. | Test track T1–T17 (planned), with a coverage threshold that only goes up. |
| Q3 | P2 | M | `routes/auth.js` (1,300 lines) mixes OTP, sessions, doctor/patient sign-up, clinics and receptionists. | Split it like `doctor/insert/`: `auth/{otp,session,signup,clinics,receptionist}.js`, with the same URLs. |
| Q4 | P2 | S | Responses come in several shapes: `{success, message}`, `{error}`, raw arrays. | Document each route's shape in its tests. Unify only for new endpoints, because changing old ones breaks the app. |
| Q5 | P3 | S | Mixed `var`/`const` in older code and unused imports (like the `multer`, `path` and `fs-extra` imports already removed from `insert.js`). | ESLint with `no-unused-vars` and an `npm run lint` script; fix incrementally. |

## 6. DevOps

| # | P | Effort | Finding | Fix |
|---|---|---|---|---|
| O1 | P1 | S | There's no CI, so tests only run when someone remembers. | GitHub Actions: `npm ci && npm test` in `backend/` on every push and PR. |
| O2 | P1 | S | There's no staging: changes go from `QLess_test_db` straight to users. | A separate production database and `.env`. Run `npm run migrate:status` before every deploy, and keep a deploy checklist in `backend/README.md`. |
| O3 | P2 | S | Deploys are manual file uploads. | A scripted deploy (Plesk Git or a `deploy.ps1`): pull, `npm ci --omit=dev`, `migrate:up`, recycle the app pool. |

## 7. Frontend (Flutter): first look only

| # | P | Effort | Finding | Fix |
|---|---|---|---|---|
| F1 | P2 | L | Some screen files are very large: `doctor/screens/home_screen.dart` (4,834 lines), `patient/screens/patient_home_screen.dart` (4,466), `doctor/screens/doctor_registration.dart` (3,771). They're slow to change and rebuild the whole screen. | Extract a widget per section, use `const` constructors, and use Riverpod `select` to narrow rebuilds. Needs its own review before planning. |
| F2 | P2 | M | After S2 and S3, the API returns 403 for a wrong role or owner. | Make the Dio interceptor show a clear message on 403, and never treat it as "session expired". |

## 8. Bugs pinned while moving procedures to inline SQL

The moves keep behaviour identical (quirks included). Each bug below is pinned by a test, so the fix is a deliberate, visible change.

| # | P | Found in | Bug | Fix | Pinned by |
|---|---|---|---|---|---|
| B1 | P2 | `sp_favorite_doctors` → `routes/patient/insert.js` `/favoriteDoctor/add` | Answers `success: true` even when the doctor was already a favorite (no `favorite_id` in that case). | Return `success: false` (or `already: true`) on the "Already added" row; check what the app expects first. | `tests/routes/favorites.test.js` "already a favorite" |
| B2 | P2 | same | `clinic_id = @clinic_id` never matches NULL, so a second add without `clinic_id` skips the existence check and hits the `UQ_fav` unique key → 500. | Compare with `(clinic_id = @clinic_id OR (clinic_id IS NULL AND @clinic_id IS NULL))`, or require `clinic_id`. | `tests/routes/favorites.test.js` "DB failure → 500" (UQ_fav message) |
| B3 | P3 | same → `routes/patient/index.js` DELETE `/favoriteDoctor/...` | Answers "Deleted successfully" even when nothing matched. | Use `@@ROWCOUNT` and return 404 when 0. | `tests/routes/favorites.test.js` |

## Suggested order
1. S1, S8, S2 and S3 (security, small), then D1 together with S4, then D2 and D3 (quick wins on the hottest paths).
2. R1, O1 and O2 (operability), then A1 (doctor-side latency), then A2 and A3.
3. Q2 continuously, Q1 one procedure at a time, and Q3 the next time auth is touched.
4. D4–D8, S5–S7, R2–R4, O3, Q4–Q5 and F1–F2 as time allows.

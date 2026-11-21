# QLess: Improvement and Optimization Plan

A backlog to implement later. Every item was checked against the code on 2026-11-20. File references are to `backend/src/` unless stated otherwise. Each item follows the project rules: tests first, one change per commit, and schema changes as numbered migrations (`npm run migrate -- create <name>`).

- **Priority:** P0 = fix soon (security or data), P1 = high value, P2 = worthwhile, P3 = nice to have
- **Effort:** S = under half a day, M = 1–2 days, L = 3+ days

## 1. Security

| # | P | Effort | Finding | Fix |
|---|---|---|---|---|
| S11 | P0 | S | ~~Patient account takeover via an unauthenticated `POST /login/patient` Update (mobile included).~~ **Done:** `requireOwnProfile()` in `routes/auth.js` guards both the patient and doctor Update paths (own token, matching `uid`; a token without `uid` is refused). Tested in `tests/routes/account-security.test.js`. | — |
| S12 | P0 | S | ~~Push-notification hijack via an unauthenticated `saveFirebaseToken`.~~ **Done:** requires a token; mobile and role come from the token, never the body. Tested in `account-security.test.js`. | — |
| S13 | P0 | S | ~~Unlimited OTP sending / guessing.~~ **Done:** `otpSendLimiter` (3 per number per 15 min + 10 per IP per hour) and `otpVerifyLimiter` (10 per number per 15 min) on the login and account-deletion OTP routes. Tested with the real limiter in `tests/routes/otp-limits.test.js`. | — |
| S14 | P1 | S | ~~Sign-up needed no OTP proof, and doctor registration even minted a login ticket for any unused number.~~ **Done:** server checks the `/verify-otp` ticket on registration (`checkSignupProof`, never mints one); app 1.0.8 verifies the mobile with `shared/widgets/otp_verify_sheet.dart` before submitting doctor and patient registration and sends `loginTicket` (the doctor's auto sign-in reuses the echoed ticket). | **Your step:** once most users run app ≥ 1.0.8, set `SIGNUP_REQUIRES_OTP=true` on the server. |
| S15 | P1 | S | ~~Demo logins accepted `123456` in every environment.~~ **Done:** `src/demo.js` (one list): off unless `DEMO_ENABLED=true`; production refuses to start with demo on and the default/short `DEMO_OTP`. Tested in `account-security.test.js`. | — |
| O4 | P0 | S | ~~29 known vulnerabilities (2 critical, 14 high).~~ **Done:** 0 critical / 0 high. 8 moderate remain (`uuid` via firebase-admin 13's Firestore/Storage). `src/fcm.js` now uses the modular API, which works on 13 and 14; 14 was tried and reports 0 vulnerabilities. | **Your step:** firebase-admin 14 needs **Node ≥ 22** on the server. Once confirmed: `npm i firebase-admin@^14`, then send one real push on staging. |
| S10 | P0 | S | ~~`/login/send-otp` returned the OTP itself in every response, in every environment (`otp: otp // remove in production`), so anyone could sign in as any mobile number.~~ **Done:** the code is no longer in the response; the app never read it. Tested in `tests/routes/notifications-otp.test.js`. | — |
| S9 | P0 | S | ~~`doctor_mobile_exist` also returns receptionist mobiles (`doctor_id` NULL), and the login treated any row as "doctor found": a receptionist posting `role: 'doctor'` got a doctor session (`role_id 1`, no `uid`) with doctor-only rights. The current app sends `role: 'receptionist'`, but older apps or direct API calls didn't.~~ **Done:** only a real `doctor_id` counts (`resolveAccountRole` in `routes/auth.js`). Tested in `tests/routes/auth.test.js`. | — |
| S1 | P0 | S | ~~`GET /login/getDoctorProfileByClinic` was **unauthenticated** and returned the doctor's mobile, email, licence no. and FCM token to anyone.~~ **Done:** it now requires a doctor or receptionist token. Its only caller is the receptionist login, which needs those fields and already sends its token, so the response is unchanged. Tested in `tests/routes/doctor-profile.test.js`. | Optional later: a receptionist may only read *their own* doctor. |
| S2 | P0 | S | ~~`/doctor/insert/*` has no role check, so a patient token can drive a doctor's queue.~~ **Done (Change 1):** `authorize(ROLE.DOCTOR, ROLE.RECEPTIONIST)` on the mount; tested in `tests/routes/protect.test.js`. | — |
| S3 | P0 | M | ~~Patient and staff routes trusted ids from the URL/body (IDOR).~~ **Done:** patient tokens via `middleware/ownPatient.js`; doctor/receptionist tokens via `middleware/ownStaff.js` (every doctor/clinic/queue/appointment/slot/availability/leave/receptionist/patient id must belong to the token's doctor; walk-in exempt for patient ids). Patients keep only clinic photos + their own appointment's prescription on `/doctor/users`. SQL verified on the real DB; tested in `ownership.test.js` and `staff-ownership.test.js`. | — |
| S4 | P1 | S | ~~Refresh tokens stored in plain text.~~ **Done:** migration `007` hashes every stored token in place (SHA-256, computed in SQL on both sides) and drops the plain column, so **no one is signed out** and no plain-text window remains. Verified on the real DB: a pre-migration session still refreshes; rotated and logged-out tokens are refused. | — |
| S5 | P1 | S | ~~No Content-Security-Policy.~~ **Done:** the two inline page scripts moved to `src/static/*.js` (served at `/static`); CSP `script-src 'self'`, inline styles + Google Fonts allowed, `data:` images, `frame-ancestors 'none'`. Tested in `staff-ownership.test.js`. | — |
| S6 | P2 | S | ~~Uploads lived in the repo.~~ **Done (code):** one `UPLOADS_DIR` setting (`src/uploads.js`) used by every upload path. | **Your step on the server:** move the files and set `UPLOADS_DIR` first, then untrack them — order in `backend/DEPLOY.md` §4. |
| S8 | P0 | S | ~~`/delete-account/request` returned the OTP (`dev_otp`) whenever `NODE_ENV !== 'production'`.~~ **Done:** removed in every environment. Tested in `tests/routes/account.test.js`. | — |
| S7 | P2 | S | ~~500 responses leaked SQL/driver error text.~~ **Done:** `hideServerErrors` (`middleware/errors.js`) logs any 5xx body with the request id and answers a generic message + `correlation_id`; 4xx untouched. | — |

## 2. Database performance

| # | P | Effort | Finding | Fix |
|---|---|---|---|---|
| D1 | P1 | S | ~~Token lookup scanned an unindexable NVARCHAR(MAX).~~ **Done with S4:** unique index on `token_hash`, index on `user_mobile` (revoke). | — |
| D2 | P1 | S | ~~No index on `appointments.queue_id`; every queue action and socket join scanned.~~ **Done:** migration `008` `IX_appointments_queue (queue_id, status)` with the columns the queue reads included. | — |
| D3 | P1 | S | ~~Inbox owner looked up by `token = @token` on NVARCHAR(MAX), one scan per notification.~~ **Done:** migration `009` persisted `Patients.token_hash` + index; `insertNotificationForToken` looks up by hash (and still compares the token). Checked on the real DB. | — |
| D4 | P2 | S | `appointments` has 4 overlapping indexes, all starting with `(doctor_id, appointment_date)`. | **Waiting for data:** the usage query is in `DEPLOY.md` §2; merge them after a month of production stats. |
| D5 | P2 | S | ~~Once-per-stage pushes were check-then-insert with no index (two queue moves together could both send).~~ **Done (redefined):** atomic `INSERT_ONCE` (`insertNotificationOnce` in `shared.js`) + migration `010` index `(patient_id, type, ref_id)`. Not a unique index: `'queue'` notifications reuse `ref_id = doctor_id` every day. 5 concurrent sends → 1 row on the real DB. | — |
| D6 | P2 | M | ~~Free-text `appointments.status`.~~ **Done (redefined):** migration `011` CHECK over the values the code uses; `CancleD`/`cancled` kept as "cancelled by doctor" (the app matches that spelling). It stops with a list if any row holds another value. | — |
| D7 | P3 | S | ~~`RefreshTokens` ids from `MAX(id)+1` under a table lock.~~ **Done:** migration `012` sequence default on `id` (no table rebuild); the insert uses `OUTPUT inserted.id`. | — |
| D8 | P3 | S | ~~The server's timezone is an assumption.~~ **Done:** on first connect `db.js` logs an error unless the database server is on IST (UTC+5:30). The SQL keeps `GETDATE()`. | — |

## 3. API and Node performance

| # | P | Effort | Finding | Fix |
|---|---|---|---|---|
| A1 | P1 | M | ~~Queue start / pause / emergency pause notified patients one at a time before answering the doctor.~~ **Done:** the doctor is answered right after the database change; `notifyTokensInBackground` (`shared.js`) then writes one batched inbox insert (`OPENJSON`, distinct owners, via the D3 hash index) and sends one multicast. Errors are logged, never thrown. Tested in `queue-flow.test.js`; batch checked on the real DB. | — |
| A2 | P2 | S | ~~`console.log` bypassed the redacting logger.~~ **Done:** routes and `realtime.js` use `log.debug/info/error` (debug is silent in production). | — |
| A3 | P2 | S | ~~Whole recordsets in logs.~~ **Done:** ids only. | — |
| A4 | P3 | S | ~~Trim `getDoctorProfileByClinic` columns.~~ **Not needed:** the app's `DoctorDetails` reads ~30 of those fields (receptionist login), and the leak itself was closed by S1 (staff token required). | — |

## 4. Reliability

| # | P | Effort | Finding | Fix |
|---|---|---|---|---|
| R1 | P1 | S | ~~No health endpoint.~~ **Done:** `GET /health` → `{ status, db, uptime }`, 503 when the database is down, own rate limit (30/min). Tested in `health.test.js`. | Point an uptime monitor at it (`DEPLOY.md` §7). |
| R2 | P2 | M | ~~Socket rooms and online status live in process memory.~~ **Done:** documented in `web.config` (one process on purpose) and `DEPLOY.md` §5; the app re-joins on reconnect. Also fixed: `watchedFiles` missed `src\queries`, `src\routes\doctor\insert` and `src\routes\auth`, so a pull touching only those didn't restart the app. | Socket.io Redis adapter only if you ever scale out. |
| R3 | P2 | S | Cron jobs run inside the web process; an idle shutdown skips them. | **Your step:** Plesk/IIS idle timeout 0 + AlwaysRunning (`DEPLOY.md` §5). The startup catch-up stays. |
| R4 | P2 | S | No automated database backup. | **Your step:** Plesk scheduled backup + one restore drill (`DEPLOY.md` §6). |

## 5. Code quality and maintainability

| # | P | Effort | Finding | Fix |
|---|---|---|---|---|
| Q1 | P1 | L | ~~Business logic sat in 16 stored procedures.~~ **Done:** none are left. 3 were moved by hand into their routes; the other 12 were split mechanically into `src/queries/*.js` (one batch per operation, run with `db.request().run()`) and compared with the procedures on the real database (185 cases, results plus all table contents). | Next step, as each area changes: rewrite a query module's batches by hand into plain route SQL / JS, using the existing tests. |
| Q2 | P1 | L | Route coverage is partial: 308 backend tests, line coverage 61% (threshold in `package.json`, only goes up; target 70% **not reached yet**). Every route the apps use is also exercised end to end on `QLess_test_db` by the route smoke run. | Keep adding route tests with each change (biggest gaps: `realtime.js` 0%, `routes/doctor/insert/reminders.js` 10%, `routes/auth/receptionist.js` 10%, `routes/auth/clinics.js` 12%); raise the threshold as it grows. |
| Q3 | P2 | M | ~~`routes/auth.js` (1,340 lines) mixed OTP, sessions, sign-up, clinics and receptionists.~~ **Done:** `routes/auth/` — `index.js` mounts `session`, `lookups`, `signup`, `otp`, `pages`, `clinics`, `receptionist` (same URLs, same order); helpers in `shared.js`. Moved verbatim by script: route table identical (23 routes, same middleware), every original line present, all tests + route-smoke pass. | — |
| Q4 | P2 | S | ~~Responses come in several shapes.~~ **Done:** documented in `README.md` ("Response shapes"); old routes keep theirs (pinned by tests), new ones use `{ success, message, data }`. | — |
| Q5 | P3 | S | ~~No linter.~~ **Done:** ESLint (`eslint.config.js`), `npm run lint` = errors only (0 now; runs in CI), `npm run lint:all` shows the 39 style warnings in older code to fix as files are touched. | — |

## 6. DevOps

| # | P | Effort | Finding | Fix |
|---|---|---|---|---|
| O1 | P1 | S | ~~No CI for the backend.~~ **Done:** job `test-backend` in `.github/workflows/main.yml`: Node 22, `npm ci`, lint, tests with the coverage threshold, `npm audit --omit=dev --audit-level=high`. `sync-backend` (the branch Plesk deploys) now waits for it. | — |
| O2 | P1 | S | ~~No staging.~~ **Done (decision):** `QLess_test_db` is staging; the release checklist is `DEPLOY.md` §3. | — |
| O3 | P2 | S | ~~Deploys were manual uploads.~~ **Done:** Plesk Git deploy with additional actions (`npm ci --omit=dev && npm run migrate:up`) plus a first-deploy checklist, `DEPLOY.md` §3. | — |

## 7. Frontend (Flutter): first look only

| # | P | Effort | Finding | Fix |
|---|---|---|---|---|
| F1 | P2 | L | ~~Very large screen files.~~ **Done:** split with `part` files (same library, code moved verbatim; verified: every original line present, identical analyzer issue set before the lint pass): `doctor/screens/home_screen.dart` 4,834 → 1,812 + `home_screen/` (5 parts); `patient/screens/patient_home_screen.dart` 4,466 → 775 + 6 parts; `doctor/screens/doctor_registration.dart` 3,771 → 1,448 + 4 parts. Builders that don't call `setState` live in private extensions on the State. Smoke tests (`test/big_screens_smoke_test.dart`, written first) build and dispose each screen. Found and fixed on the way: `HomeScreen` and `AppointmentScreen` used `ref` inside `dispose()`, which always throws in flutter_riverpod 2.6 — so their dispose never finished (animation controller and clinic socket watch leaked). | — |
| F2 | P2 | M | ~~403 handling.~~ **Done (already in place):** `core/network/interceptor.dart` shows "Your account does not have access to this action." on 403 and never logs out on it (only a 401, or a 403 from the refresh call). | — |
| F3 | P3 | M | ~~`flutter analyze`: 494 issues.~~ **Done: 0.** 337 `withOpacity` → `withValues(alpha:)`, `dart fix`, 62 unreferenced private declarations + dead locals/fields removed, never-passed constructor parameters turned into constant getters (same values), 2 missing `mounted` checks, geolocator/Switch API updates, `addMedicine_page.dart` / `viewModel_provider.dart` renamed to snake_case, `DoctorLoginState.clinic_id/clinic_name` → `clinicId/clinicName`. JSON-named model fields (`Token`, `DOB`) keep their names (file-level ignore with the reason). App version 1.0.8+11. | — |

## 8. Bugs pinned while moving procedures to inline SQL

The moves keep behaviour identical (quirks included). Each bug below is pinned by a test, so the fix is a deliberate, visible change.

| # | P | Found in | Bug | Fix | Pinned by |
|---|---|---|---|---|---|
| B1 | P2 | `routes/patient/insert.js` `/favoriteDoctor/add` | ~~Answered a plain success even when the doctor was already a favorite.~~ **Done:** `{ success: true, already: true, message: 'Doctor is already in your favorites' }` (the app still treats it as success). | — | `favorites.test.js`, route-smoke |
| B2 | P2 | favorites add / delete / check | ~~`clinic_id = @clinic_id` never matched NULL, so a second add without a clinic hit `UQ_fav` → 500.~~ **Done:** NULL-safe compare everywhere; `"null"` in a URL means NULL. | — | `favorites.test.js`, route-smoke (add twice + delete on the real DB) |
| B3 | P3 | `routes/patient/index.js` DELETE `/favoriteDoctor/...` | ~~Answered "Deleted successfully" when nothing matched.~~ **Done:** `@@ROWCOUNT` → 404 "This doctor is not in your favorites". | — | `favorites.test.js`, route-smoke |
| B4 | P1 | `routes/patient/users.js` `/review/doctor/:doctor_id/:clinic_id` | ~~Self vs family review decided by comparing ids from two sequences.~~ **Done:** decided by the appointment's `user_type`. | — | `reviews.test.js`, route-smoke |
| B5 | P3 | `routes/patient/insert.js` `/review/add` | ~~Review insert and `is_reviewed` update not atomic.~~ **Done:** `SET XACT_ABORT ON` + one transaction. | — | `reviews.test.js`, route-smoke (is_reviewed checked on the real DB) |
| B6 | P3 | same | ~~Comments over 500 characters cut silently.~~ **Done:** 400 "Comment can be at most 500 characters." | — | `reviews.test.js`, route-smoke |
| B7 | P1 | `routes/patient/index.js` DELETE `/deleteFamilyMember/:member_id` | ~~Read `.Message` → always 400; and no foreign key existed, so a member with appointments was deleted (orphaned appointments, found on the real DB).~~ **Done:** explicit check of `appointments` / `patient_records` (`user_type = 2`) → 409 "Member is used in other records"; otherwise 200. | — | `family.test.js`, route-smoke |
| B8 | P2 | `src/familyMembers.js` / `/insertFamilyMember` | ~~`family_id` optional; Update of a missing member answered success.~~ **Done:** `family_id` required → 400; Update returns `updated` → 404 when 0 (ownPatient already answers 403 for a member that isn't yours). | — | `family.test.js`, route-smoke |
| B9 | P3 | same (+ walk-in booking) | ~~Names over 100 characters cut silently.~~ **Done:** 400 in `/insertFamilyMember` and `/walkInBook`. | — | `family.test.js` |

### Found while moving the last 12 procedures (behaviour kept; fix each separately with its test)

| # | P | Where | Bug | Fix | Pinned by |
|---|---|---|---|---|---|
| B13 | P0 | `/appointment/queueRecall` | ~~Recall never sent `doctor_id`, so every queue recall failed.~~ **Done:** `doctor_id` is passed; verified on the real database (recall now reaches its real rules). | — | `tests/routes/queue-flow.test.js` |
| B10 | P1 | `routes/patient/insert.js` `/appointment/cancel` | ~~Called a non-existent operation `CANCEL`.~~ **Done:** runs `CANCEL_APPOINTMENT` like `/cancelAppointment/:id`. | — | `appointments-cancel.test.js`, route-smoke (status checked on the real DB) |
| B11 | P1 | `routes/doctor/insert/leave.js`, `schedule.js` | ~~`MARK_APPT_DOCTOR_CANCELLED` did not exist, so leave/slot cancels showed as patient self-cancels.~~ **Done:** operation added to `queries/appointments.js` (`'cancelled'` → `'CancleD'`). | — | `appointments-cancel.test.js`, route-smoke |
| B12 | P1 | `appointments.js` `queueStart`, `queuePause`, `queuePauseEmergency` | ~~A Firebase failure after the change answered 500.~~ **Done:** `multicast()` logs and reports 0 delivered; the doctor gets success. | — | `queue-flow.test.js` |
| B14 | P2 | `routes/doctor/insert/prescriptions.js` `/insertMedicine` | ~~Duplicate never returned 409.~~ **Done:** matches "already in your list" → 409. | — | `medicines-prescriptions.test.js`, route-smoke |
| B16 | P1 | doctor profile Update (`routes/auth/signup.js`); app `doctor_edit_screen.dart` | ~~The app's change-mobile OTP was fake (code made on the phone).~~ **Done:** the edit screen sends and verifies a real OTP for the new number and sends `loginTicket` with the update; the server checks it (`checkMobileChangeProof`). The patient mobile field is read-only, so it never needs proof. | **Your step:** with app ≥ 1.0.8 out, set `MOBILE_CHANGE_REQUIRES_OTP=true`. | `account-security.test.js`, `otp_verify_sheet_test.dart` |
| B17 | P1 | `sendPositionNotifications` (`routes/doctor/insert/shared.js`) | ~~The "You're next / Get ready / 3rd in queue" pushes never went out: the query filtered on status `'waiting'` (never written; waiting is `'booked'`) and joined a non-existent `doctors` table; the error was swallowed.~~ **Done:** `'booked'` + `doctor_login`. 3 pushes on the real DB, none on a repeat. | — | `notifications-once.test.js` |
| B18 | P0 | `middleware/ownStaff.js`, `queries/doctors.js`, `queries/patients.js` | ~~A newly registered doctor got 403 DOCTOR_PENDING on walk-in, queue, prescriptions and patient data: the verification gate read `is_verified = 1` as verified, while the database uses 0 = verified (and new doctors never reached the admin pending list).~~ **Done:** verification is reviewed in the background and restricts nothing: new doctors are saved as pending (`is_verified = 1`) so they appear in `/admin/doctors/pending`; login and the patients' doctor list no longer filter on it. Only an admin block (Reject → `active_status = 1`) restricts: every staff route answers 403 `DOCTOR_BLOCKED` for that doctor and their receptionists, session refresh is refused, login and the patient list exclude them. App shows "Your account has been blocked". Checked on the real DB. | — | `protect.test.js`, `auth.test.js` |
| B15 | P3 | database user | After the Plesk reset, the DB login's default schema is `QLessTest`, not `dbo`. Fixed for the migrations (baseline fully `[dbo]`-qualified, `dbo.schema_migrations`), but unqualified SQL resolves against that schema first. | Set the login's default schema to `dbo` in Plesk / `ALTER USER … WITH DEFAULT_SCHEMA = dbo`. | — |

## Suggested order
0. ~~Before production: S11, S12, S13, O4, B13~~ **done** — see `backend/DEPLOY.md` for the launch checklist.
1. **B13** (queue recall, one line), then the doctor/receptionist half of S3, then D1 together with S4, then D2 and D3 (quick wins on the hottest paths). S1, S2, S8, S9, S10 and patient-side S3 are done.
2. R1, O1 and O2 (operability), then A1 (doctor-side latency), then A2 and A3.
3. Q2 continuously, Q1 one procedure at a time, and Q3 the next time auth is touched.
4. D4–D8, S5–S7, R2–R4, O3, Q4–Q5 and F1–F2 as time allows.

# Rollback: offline sync changes

This doc covers two changes. Each can be rolled back on its own:
- **Part 1:** starting a queue offline from the schedule (below).
- **Part 2:** fixes to how offline work syncs (further down).

# Part 1: start a queue offline from the schedule

**Change:** the doctor can see today's sessions and start the queue offline, even if the app never downloaded today's sessions or nobody has booked yet.

**How it works:**
- The app builds a stand-in session from the cached schedule, with `queue_id = -slot_id`.
- The backend turns any negative `queue_id` back into the real `doctor_queue` row, creating it if needed, when the doctor's offline actions sync.

**Commits:** backend `<backend-sha>` · frontend `<frontend-sha>` (fill in once committed)

---

## What was changed

### Backend
| File | Change |
|---|---|
| `backend/src/routes/doctor/insert/shared.js` | Added `RESOLVE_TEMP_QUEUE_SQL`, `TempQueueError`, `resolveTempQueueId()`, `resolveTempQueue()` middleware, and their exports. Added the `doctorLeaveSql` and `ownStaff` imports. |
| `backend/src/routes/doctor/insert/index.js` | `router.use(require('./shared').resolveTempQueue);` placed before `ownStaff(router)` |
| `backend/tests/routes/queue.test.js` | `describe('offline-started sessions (queue_id = -slot_id)')` block |

### Frontend
| File | Change |
|---|---|
| `frontend/lib/core/database/offline_queue_store.dart` | `ensureScheduledSessions()` and `_weekdays`, plus the `doctor_leave_model` / `doctor_schedule_model` imports |
| `frontend/lib/core/database/local_database.dart` | Inside `upsertQueues`: the `batch.delete(... 'queue_id < 0 AND slot_id = ?' ...)` block |
| `frontend/lib/presentation/doctor/view_models/appointment_list_viewmodel.dart` | Inside `_loadFromCache`: the `ensureScheduledSessions(...)` try/catch |
| `frontend/test/core/offline_sync_test.dart` | `group('sessions from the schedule (offline start)')` and the `today_queue_model` import |

---

## Why rolling back is low risk
- **Backend:** the middleware only acts on a **negative** `queue_id`. Real ids pass through unchanged, so leaving it deployed costs nothing.
- **Frontend:** it only adds rows to the phone's **local** cache.
- **Database:** the only server data it creates is empty `doctor_queue` rows for today's scheduled slots.

## Order: frontend first, backend later
Phones can still hold unsynced actions with a negative `queue_id`.
- If the backend is rolled back first, those actions get **403** from `ownStaff` and show up under **Profile → Sync** as failed items, where the doctor can retry or discard them.
- So roll back the app first, and keep the backend change until doctors' Sync screens show 0 pending, or for at least a day.

---

## Steps

### 1. Frontend (stops new stand-in sessions)
- **Quick switch-off:** delete the `ensureScheduledSessions(...)` try/catch in `_loadFromCache` in `appointment_list_viewmodel.dart`. That alone disables the feature.
- **Full rollback:** `git revert <frontend-sha>`, or remove the frontend changes listed in the table above.
- **Optional, to clear stand-ins already cached on phones:** in the same release, add this at the top of `_loadFromCache`:
  ```dart
  await (await LocalDatabase.instance.database).delete('queues', where: 'queue_id < 0');
  ```
  Without it they're harmless. They stop being shown the next day, and the queues table prunes anything older than 7 days.
- Release the app build.

### 2. Backend, once phones have synced
- `git revert <backend-sha>`, or remove the backend changes listed in the table above.
- Deploy. Then run `npm test` in `backend/`. The test block for this feature goes away with the revert.

### 3. Database cleanup (optional)
- **How to tell the rows apart:** the resolver creates rows with `total_queue = 0`, while the booking SP always creates rows with `total_queue = 1`. An empty row the resolver made and nobody used looks like this:
  ```sql
  -- review first
  SELECT dq.queue_id, dq.doctor_id, dq.slot_id, dq.queue_date, dq.queue_status
  FROM doctor_queue dq
  WHERE dq.total_queue = 0
    AND NOT EXISTS (SELECT 1 FROM appointments a WHERE a.queue_id = dq.queue_id);

  -- then delete only the ones not running/paused
  DELETE dq FROM doctor_queue dq
  WHERE dq.total_queue = 0 AND dq.queue_status IN (0, 3)
    AND NOT EXISTS (SELECT 1 FROM appointments a WHERE a.queue_id = dq.queue_id);
  ```
- **Don't delete** rows with `queue_status` 1 (running) or 2 (paused). A doctor is using them, and the nightly `closeStaleSessions` closes them.
- **Rows left behind for today** show online as a session card with no patients, which is harmless.

---

## Checking the rollback
- **Online:** a session with no bookings shows "awaiting bookings" again, with no stand-in card.
- **Offline, no cache:** opening the app shows the "today's data not downloaded" message instead of schedule sessions.
- **Server logs:** no new `[resolveTempQueue]` lines once the backend is reverted, and no 409 "earlier day" or "not in today's schedule" answers.
- **Tests:** `npm test` (backend) and `flutter test` (frontend) both pass.

---

# Part 2: offline sync fixes

**Commits:** backend `<backend-sha-2>` · frontend `<frontend-sha-2>` (fill in once committed)

Each piece below can be undone on its own.

| # | Piece | What it fixes |
|---|---|---|
| 2a | **The backend skips replays that already took effect** | A replayed "Next" no longer advances the queue a second time. A replayed "Start queue" no longer resets `current_serving`. Replayed skip, start session and end session no longer show up as false failed items. |
| 2b | **The add-medicine endpoint returns `medicine_id`** | Medicines added offline can sync |
| 2c | **The health-check limit is raised to 120 per minute** | The app's online check can poll `/health` |
| 2d | **The app's online check calls `/health` instead of DNS** | "Online" now means the backend is reachable, not just that google.com resolves |
| 2e | **Sync runs straight away and takes several passes** | Work syncs about 1 second after it's saved |
| 2f | **Outbox rules** | Actions linked to an unsynced walk-in wait instead of failing. A 401 no longer counts toward the retry limit. |
| 2g | **Pending work is re-applied after a fetch, and offline actions follow the server's rules** | A patient completed offline no longer comes back after reconnecting |
| 2h | **Medicines can be added offline** | |
| 2i | **The day's data is downloaded, and the doctor's presence rejoined, after sync** | |

## What was changed, and how to undo each piece

### Backend
- **2a:**
  - In `backend/src/routes/doctor/insert/shared.js`, remove `APPT_DONE`, `QUEUE_DONE`, `alreadyApplied()` and its export.
  - In `appointments.js`, remove the import and the seven `if (await alreadyApplied(req, '…')) return …` lines in queueNext, queueStart, queuePause, queueStop, queueSkip, startSession and endSession.
  - Effect: replays go straight to the SPs again, as before.
- **2b:**
  - In `backend/src/queries/medicines.js`, remove `, @medId AS medicine_id` from the three `SELECT '…' AS Message` lines.
  - In `routes/doctor/insert/prescriptions.js` `/insertMedicine`, remove `medicine_id` and the `&& !req.body.offline_queued_at` part.
  - **Roll back 2h first.** Without it, a medicine added offline syncs but never gets its real id.
- **2c:** in `backend/src/middleware/rateLimit.js` `healthLimiter`, set `max` back to `30`. **Do this only after rolling back 2d**, or devices behind one clinic connection get 429 responses.
- **Tests:** in `backend/tests/routes/queue.test.js`, remove `describe('offline replay of an action that already took effect')`. In `medicines-prescriptions.test.js`, remove `describe('medicines added offline')`.

### Frontend
- **2d:** in `lib/presentation/shared/providers/connectivity_notifier.dart`, put back the `InternetAddress.lookup('google.com')` version of `_lookupOnce` (plus the `dart:io` import), and remove `_probe` and the `dio` and `constant.dart` imports.
- **2e:** in `lib/presentation/shared/controllers/sync_controller.dart`:
  - Remove the `store.changes` listener (`onQueued`, `debounce`).
  - Remove the `for (var pass …)` loop, leaving one pass of the four sync calls.
  - Remove the `prefetch` parameter and `_downloadTheDay`.
  - Remove the closing `joinClinic` call.
  - In `offline_queue_store.dart`, the `changes` / `_changed()` notifier can stay (nothing listens to it any more) or be removed.
- **2f:** in `lib/core/database/offline_queue_store.dart`:
  - Remove `_withoutUnsyncedWalkIns()` and its two call sites (`flushPendingOps`, `flushPendingPrescriptions`).
  - Remove the `statusCode == 401` branch in `_flush`.
  - In `discardFailed`, remove the `deletePendingForAppointment` / `deleteMedicine` lines.
  - Remove `LocalDatabase.deletePendingForAppointment`.
- **2g:**
  - In `appointment_list_viewmodel.dart`:
    - Remove the `pendingCount > 0 → reapplyPendingOps → _loadFromCache → return` block in `fetchPatientAppointments`.
    - Remove the same block in `getTodayQueue`.
    - Remove `_needsRunningQueue`, `_queueNotRunningOffline()` and its call in `_onlineOrOffline`.
    - Put back `doctorId ?? queueId` in `queuePauseEmergency`. This is optional; the fallback was a bug.
  - In `offline_queue_store.dart`, remove `reapplyPendingOps()` and the "someone is already in progress" early return in `_autoAdvance`.
  - In `doctor_precriptionentry_screen.dart` `_completeAndBack`, go back to the plain fire-and-forget `endSession(...)`.
- **2h:**
  - In `offline_queue_store.dart`, remove `OfflineOperation.addMedicine` (enum, `name`, `fromString`, its `applyOfflineQueueOp` case), `_tempMedKey`, `enqueueAddMedicine()` and `flushPendingMedicines()`, plus the `addMedicine` filter in `flushPendingOps` / `reapplyPendingOps`.
  - In `appointment_list_viewmodel.dart` `_executeOp`, remove the `addMedicine` case.
  - In `local_database.dart`, remove `remapMedicine()`, `insertMedicine()` and `deleteMedicine()`, and put `upsertMedicines` back to `where: 'doctor_id = ?'`.
  - In `doctor_login_viewmodel.dart`:
    - Remove the offline branch in `addMedicine` and `syncPendingMedicines()`.
    - Remove the `medicineTypes` cache in `fetchMedicineTypes`.
    - Remove the "unsynced" merge in `fetchAllMedicines`.
    - Remove the `network_errors` import.
  - In `add_medicine_page.dart`, put back the `isOffline → connectivityErrorMessage` early return.
  - **Before shipping this rollback**, make sure no phone still has `addMedicine` rows pending. Otherwise `PendingOperation.fromRow` throws "Unknown offline operation" and the row is marked failed as corrupt; the medicine itself is lost, but nothing else breaks.
- **2i:** covered by 2e (`_downloadTheDay`, `joinClinic`).
- **Tests:** in `frontend/test/core/offline_sync_test.dart`, remove `group('sync fixes')` and the `appointment_list`, `medicine` and `prescription` imports.

## Order
1. **Frontend first** (2d–2i), and wait until phones' Profile → Sync shows 0 pending.
2. **Then the backend:** 2a, 2b, then 2c last.

Rolling back **2a alone** is safe at any time, but replays can then double-apply "Next" again.

## Check after rollback
- `npm test` (backend) and `flutter test` (frontend) both pass.
- Adding a medicine offline shows "No internet connection" again.
- The connectivity banner follows DNS again.

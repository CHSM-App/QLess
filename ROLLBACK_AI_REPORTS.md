# Rollback: AI medical report summaries

**What the feature does:** a doctor, receptionist or patient photographs a lab report (up to 6 pages) or uploads one PDF (up to 10 pages). Claude Haiku 4.5 writes a short summary. A doctor can keep the report in **Unassigned reports**, or attach it to a patient and, optionally, one of that patient's prescriptions. Patients see reports attached to them. A report a patient attaches to a prescription is shared with the doctor who wrote that prescription.

**Commits:** backend `<backend-sha>` · frontend `<frontend-sha>` (fill in once committed)

There are three levels of undo. Start with the smallest one that solves the problem.

| Level | Effect | Deploy needed | Time |
|---|---|---|---|
| 1. Kill switch | Stops all Claude spend. Saved reports stay readable. | No (edit `.env` + restart) | 1 min |
| 2. Hide in app | Removes the menu items and buttons | App release | 1 release |
| 3. Full removal | Removes the code, the table and the files | Backend + app | about 1 hour |

---

## What was changed

### Backend
| File | Change |
|---|---|
| `backend/src/ai.js` | **New.** Claude call (`claude-haiku-4-5`), JSON schema, prompt, daily limits, `enabled()` kill switch |
| `backend/src/routes/reports.js` | **New.** `/reports/*` routes: summarize, unassigned, patient, prescription, assign, delete, file |
| `backend/src/migrations/016_medical_reports.sql` (+ `_rollback.sql`) | **New.** `dbo.medical_reports` table and its indexes |
| `backend/src/middleware/upload.js` | PDF magic bytes in `detectImageMagic`; `verifyImageFiles` rejects PDFs; new `reportUpload`, `verifyReportFiles`, `countPdfPages`; the 413 message mentions 10 MB for reports |
| `backend/src/server.js` | `app.use('/reports', …)` mount and the `/uploads/reports` → 404 guard |
| `backend/tests/routes/reports.test.js` | **New** |
| `backend/package.json` / `package-lock.json` | `@anthropic-ai/sdk` dependency |
| `backend/.env.example`, `backend/DEPLOY.md` | `ANTHROPIC_API_KEY`, `AI_REPORTS_ENABLED` |
| `backend/src/static/privacy.html` | Anthropic row in the processor table, plus one sentence under "Data Location" |

### Frontend
| File | Change |
|---|---|
| `frontend/lib/data/api/reports_api.dart` | **New.** `MedicalReport` model, `ReportsApi` (plain Dio), `reportErrorText` |
| `frontend/lib/presentation/shared/reports/report_screens.dart` | **New.** Capture, detail, assign sheet, lists, `PrescriptionReportsTile` |
| `frontend/lib/core/feature_flags.dart` | `kAiReportsEnabled` |
| `frontend/lib/presentation/doctor/screens/profile_screen.dart` | Two menu items: **AI Report Summary** and **Unassigned Reports**, plus 2 imports |
| `frontend/lib/presentation/doctor/screens/home_screen.dart` | Small **Scan report** button above the walk-in button, plus 2 imports |
| `frontend/test/report_match_test.dart` | **New.** Phone/name matching for the assign sheet |
| `frontend/lib/presentation/doctor/screens/doctor_prescription_history.dart` | `_reportsTile` inserted in the mobile and desktop layouts, plus 2 imports |
| `frontend/lib/presentation/patient/screens/patient_prescription_list.dart` | **My reports** app-bar button and `PrescriptionReportsTile` on the prescription view, plus 2 imports |

---

## Level 1: kill switch (no deploy, stops spend immediately)
1. In the server `backend/.env`, set `AI_REPORTS_ENABLED=false`.
2. Restart the app (Plesk → Node.js → Restart).
3. Result:
   - `POST /reports/summarize` answers 503 before any upload work. The app shows "AI summary is unavailable right now".
   - Listing, viewing, assigning and deleting saved reports keep working.
   - Claude is never called.
4. Optional: also revoke the API key at console.anthropic.com → API keys. With the key revoked or unset, the feature answers 503 the same way.

To undo Level 1, set it back to `true` and restart.

## Level 2: hide it in the app
1. Set `const bool kAiReportsEnabled = false;` in `frontend/lib/core/feature_flags.dart`.
2. Release a new build. Every entry point is hidden.
3. Older app versions still show the buttons. Combine this with Level 1 so they get the 503 message.

## Level 3: full removal
**Order: app first, then backend.** If the backend goes first, older apps calling the removed `/reports` routes just get 404 errors. No data can be corrupted either way.

1. **Back up (optional, recommended).** Dropping the table loses every summary and attachment.
   ```sql
   SELECT * INTO dbo.medical_reports_backup_20261127 FROM dbo.medical_reports;
   ```
   Also copy `<UPLOADS_DIR>/reports/` somewhere safe.
2. **Frontend:** run `git revert <frontend-sha>`, or undo the frontend files in the table above. No codegen is involved, because `reports_api.dart` uses plain Dio. Release the app.
3. **Backend:**
   ```bash
   cd backend
   npm run migrate:down        # runs 016_medical_reports_rollback.sql → DROP TABLE medical_reports
   git revert <backend-sha>    # or undo the backend files listed above
   npm uninstall @anthropic-ai/sdk   # only if the revert didn't already restore package.json
   ```
   Deploy, then restart.
4. **Files:** delete `<UPLOADS_DIR>/reports/` on the server. That folder is outside the repo, so `git revert` does not touch it.
5. **Secrets:** remove `ANTHROPIC_API_KEY` and `AI_REPORTS_ENABLED` from `.env`, then revoke the key in the Anthropic console.
6. **Privacy policy:** the revert removes the Anthropic row and sentence from `privacy.html`. Check that it is gone from the live `/privacy` page.

### Verify the rollback
- `npm run migrate:status` shows 016 as pending (not applied).
- `POST /reports/summarize` returns 404.
- The doctor profile has no report items, and prescription screens show no "Reports" tile.
- Existing prescription screens load as before. `npm test` passes.

---

## Why rolling back is low risk
- **Additive only.** The feature adds a new table, new routes and new screens. No existing table, stored query or route changes behaviour.
- **Two small shared changes:**
  - `verifyImageFiles` now rejects PDFs. It never accepted them before, because PDF wasn't a known magic number.
  - The `/uploads/reports` 404 guard. It is harmless once the folder is gone.
- **Deleting a report keeps an empty row.** The row has its files and summary cleared, so it stays out of every list. It keeps counting towards the daily cap and the spend figures, so delete-and-retry can't run up credits. Level 3 drops these rows with the table.

---

## Credit usage: what keeps it low (for reference)
- Model `claude-haiku-4-5` ($1 / $5 per million tokens), no thinking, `max_tokens` 1500, `maxRetries` 1.
- About 5k input tokens and 0.6k output for a typical 3-page report, which is about **$0.008 (₹0.7) per report**.
- Claude is called once per report. Viewing, listing and assigning read the saved summary.
- Identical files uploaded again by the same doctor or patient reuse the earlier summary (sha256 match). Token columns are NULL for those rows.
- Photos are resized on the phone to at most 1568 px at quality 70. Limits: 6 photos, or a 10-page PDF of at most 15 MB.
- Daily limit per person: staff 30 and patients 5 (`DAILY_LIMIT` in `backend/src/ai.js`).
- To check spend:
  ```sql
  SELECT COUNT(*) AS reports,
         SUM(input_tokens) AS in_tok, SUM(output_tokens) AS out_tok,
         SUM(input_tokens) / 1e6 * 1 + SUM(output_tokens) / 1e6 * 5 AS usd
  FROM dbo.medical_reports
  WHERE created_at >= '2026-12-01';
  ```

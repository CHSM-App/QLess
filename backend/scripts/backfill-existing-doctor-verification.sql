/*
  QLess — backfill is_verified for doctors that predate the approval gate
  ---------------------------------------------------------------------------
  WHY:
  migrate-doctor-verification.sql assumed existing doctor rows already had
  is_verified = 1 (matching the schema dump's old Insert default), so the
  corrected login_screen.dart check ("block when != 1") wouldn't affect them.

  That assumption was wrong: checking the live DB after the migration shows
  all 41 existing doctor rows (active_status = 0) actually have is_verified
  = 0 — the schema dump was stale relative to what's really deployed. Under
  the OLD (inverted) frontend check, 0 passed through fine; under the FIXED
  check, 0 now reads as "pending" and would lock every one of them out,
  including real production accounts, the next time the updated app ships.

  This is a one-time catch-up: mark everyone who already has a working
  account as approved. Only brand-new registrations made AFTER this ran will
  start out pending for real admin review.
*/

USE [QLess];
GO

SELECT doctor_id, name, mobile, is_verified, active_status
FROM dbo.doctor_login
WHERE active_status = 0 AND is_verified = 0;
GO

UPDATE dbo.doctor_login
SET is_verified = 1
WHERE active_status = 0 AND is_verified = 0;
GO

SELECT COUNT(*) AS still_pending
FROM dbo.doctor_login
WHERE active_status = 0 AND is_verified = 0;
GO

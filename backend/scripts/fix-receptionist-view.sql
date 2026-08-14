/*
  QLess — receptionist_vw join fix
  ---------------------------------------------------------------------------
  WHY:
  The view joined clinics, Gender and role with INNER JOINs, so a receptionist
  whose clinic_id, gender_id or role_id was NULL (or pointed at a deleted row)
  vanished from the view entirely — even though the receptionist record itself
  was perfectly fine.

  That is how the login role went missing: ManageRefreshToken used to read
  role_id from this view, found no row, and wrote a session with role_id = NULL.
  Fifteen minutes later the token refresh handed the app a role of nothing, the
  receptionist's screen turned into the doctor's, and the next launch dropped
  the session at the login page.

  The token path no longer depends on this view (see
  migrate-refresh-token-role.sql), but every other reader — the receptionist
  list, checkPhoneReceptionist, the profile screen — still hides those people.
  A lookup that is missing should blank one column, not delete the person.

  LEFT JOIN only ever ADDS rows, so nothing that works today stops working;
  callers must simply tolerate a NULL clinic_name / gender / role, which is the
  honest representation of "not set yet".
*/

USE [QLess];
GO

ALTER VIEW dbo.receptionist_vw
AS
SELECT r.recep_id,
       r.name,
       r.mobile_no,
       r.email,
       r.Address,
       r.active_status,
       c.clinic_name,
       r.gender_id,
       g.gender,
       r.clinic_id,
       r.img_url,
       r.created_at,
       r.token,
       ro.role,
       r.role_id,
       r.doctor_id
FROM   dbo.receptionist AS r
       LEFT JOIN dbo.clinics AS c ON r.clinic_id = c.clinic_id
       LEFT JOIN dbo.Gender  AS g ON r.gender_id = g.gender_id
       LEFT JOIN dbo.role    AS ro ON r.role_id  = ro.role_id;
GO

-- Who was hidden until now:
-- SELECT r.recep_id, r.name, r.mobile_no, r.clinic_id, r.gender_id, r.role_id
-- FROM   dbo.receptionist AS r
-- WHERE  r.clinic_id IS NULL OR r.gender_id IS NULL OR r.role_id IS NULL;

-- Receptionists still carrying no role_id (worth back-filling to 3):
-- UPDATE dbo.receptionist SET role_id = 3 WHERE role_id IS NULL;

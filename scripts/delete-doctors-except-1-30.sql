-- PERMANENTLY deletes every doctor except doctor_id 1..30 (so doctor 58, which
-- holds the demo mobile 9876000001, IS deleted too), together with their
-- clinics and ALL related rows
-- (appointments, queue, prescriptions + medicines, reviews, favourites,
-- schedule/slots/leave, receptionists, tokens, OTPs, deletion requests...).
-- THIS CANNOT BE UNDONE.  Take a database backup first.
--
-- Two-pass use:
--   1) Run as-is (@apply = 0). It only COUNTS what would be deleted.
--   2) Check the counts, then set @apply = 1 and run again to delete.
-- The transaction is always committed or rolled back inside this script, so
-- it never leaves a lock behind.


DECLARE @apply BIT = 0;   -- <<< change to 1 to really delete

SET XACT_ABORT ON;

IF OBJECT_ID('tempdb..#del_doc') IS NOT NULL DROP TABLE #del_doc;
IF OBJECT_ID('tempdb..#del_clinic') IS NOT NULL DROP TABLE #del_clinic;
IF OBJECT_ID('tempdb..#del_presc') IS NOT NULL DROP TABLE #del_presc;
IF OBJECT_ID('tempdb..#del_avail') IS NOT NULL DROP TABLE #del_avail;

SELECT doctor_id, mobile INTO #del_doc
FROM dbo.doctor_login
WHERE doctor_id NOT BETWEEN 1 AND 30;

-- Clinics owned by those doctors (via clinics.doctor_id or doctor_login.clinic_id)
SELECT clinic_id INTO #del_clinic
FROM dbo.clinics
WHERE doctor_id IN (SELECT doctor_id FROM #del_doc)
   OR clinic_id IN (SELECT clinic_id FROM dbo.doctor_login
                    WHERE doctor_id IN (SELECT doctor_id FROM #del_doc));

-- Prescriptions written by those doctors or at those clinics
SELECT prescription_id INTO #del_presc
FROM dbo.patient_records
WHERE doctor_id IN (SELECT doctor_id FROM #del_doc)
   OR clinic_id IN (SELECT clinic_id FROM #del_clinic);

-- Availability rows (and through them time slots)
SELECT availability_id INTO #del_avail
FROM dbo.doctor_availability
WHERE doctor_id IN (SELECT doctor_id FROM #del_doc)
   OR clinic_id IN (SELECT clinic_id FROM #del_clinic);

-- What will go
SELECT 'doctors'                 AS what, COUNT(*) AS n FROM #del_doc
UNION ALL SELECT 'clinics',               COUNT(*) FROM #del_clinic
UNION ALL SELECT 'clinic_images',         COUNT(*) FROM dbo.clinic_images WHERE clinic_id IN (SELECT clinic_id FROM #del_clinic)
UNION ALL SELECT 'appointments',          COUNT(*) FROM dbo.appointments WHERE doctor_id IN (SELECT doctor_id FROM #del_doc) OR clinic_id IN (SELECT clinic_id FROM #del_clinic)
UNION ALL SELECT 'doctor_queue',          COUNT(*) FROM dbo.doctor_queue WHERE doctor_id IN (SELECT doctor_id FROM #del_doc) OR clinic_id IN (SELECT clinic_id FROM #del_clinic)
UNION ALL SELECT 'patient_records',       COUNT(*) FROM #del_presc
UNION ALL SELECT 'PrescriptionMedicine',  COUNT(*) FROM dbo.PrescriptionMedicine WHERE prescription_id IN (SELECT prescription_id FROM #del_presc)
UNION ALL SELECT 'reviews',               COUNT(*) FROM dbo.reviews WHERE doctor_id IN (SELECT doctor_id FROM #del_doc) OR clinic_id IN (SELECT clinic_id FROM #del_clinic)
UNION ALL SELECT 'favorite_doctors',      COUNT(*) FROM dbo.favorite_doctors WHERE doctor_id IN (SELECT doctor_id FROM #del_doc) OR clinic_id IN (SELECT clinic_id FROM #del_clinic)
UNION ALL SELECT 'doctor_availability',   COUNT(*) FROM #del_avail
UNION ALL SELECT 'doctor_time_slots',     COUNT(*) FROM dbo.doctor_time_slots WHERE availability_id IN (SELECT availability_id FROM #del_avail)
UNION ALL SELECT 'doctor_leave',          COUNT(*) FROM dbo.doctor_leave WHERE doctor_id IN (SELECT doctor_id FROM #del_doc) OR clinic_id IN (SELECT clinic_id FROM #del_clinic)
UNION ALL SELECT 'doctor_timing',         COUNT(*) FROM dbo.doctor_timing WHERE doctor_id IN (SELECT doctor_id FROM #del_doc) OR clinic_id IN (SELECT clinic_id FROM #del_clinic)
UNION ALL SELECT 'doctor_unavailability', COUNT(*) FROM dbo.doctor_unavailability WHERE doctor_id IN (SELECT doctor_id FROM #del_doc)
UNION ALL SELECT 'Doctor_Medicine',       COUNT(*) FROM dbo.Doctor_Medicine WHERE doctor_id IN (SELECT doctor_id FROM #del_doc)
UNION ALL SELECT 'Medicine_Master_Backup',COUNT(*) FROM dbo.Medicine_Master_Backup WHERE doctor_id IN (SELECT doctor_id FROM #del_doc)
UNION ALL SELECT 'receptionists',         COUNT(*) FROM dbo.receptionist WHERE doctor_id IN (SELECT doctor_id FROM #del_doc) OR clinic_id IN (SELECT clinic_id FROM #del_clinic)
UNION ALL SELECT 'RefreshTokens',         COUNT(*) FROM dbo.RefreshTokens WHERE user_mobile IN (SELECT mobile FROM #del_doc)
UNION ALL SELECT 'otp_verification',      COUNT(*) FROM dbo.otp_verification WHERE mobile_no IN (SELECT mobile FROM #del_doc)
UNION ALL SELECT 'AccountDeletionRequests', COUNT(*) FROM dbo.AccountDeletionRequests WHERE phone IN (SELECT mobile FROM #del_doc) AND role_id = 1;

SELECT doctor_id, mobile FROM #del_doc ORDER BY doctor_id;

IF @apply = 0
BEGIN
    PRINT 'DRY RUN - nothing deleted. Set @apply = 1 to delete.';
    RETURN;
END

BEGIN TRY
    BEGIN TRAN;

    DELETE FROM dbo.PrescriptionMedicine WHERE prescription_id IN (SELECT prescription_id FROM #del_presc);
    DELETE FROM dbo.patient_records      WHERE prescription_id IN (SELECT prescription_id FROM #del_presc);

    DELETE FROM dbo.doctor_time_slots    WHERE availability_id IN (SELECT availability_id FROM #del_avail);
    DELETE FROM dbo.doctor_availability  WHERE availability_id IN (SELECT availability_id FROM #del_avail);

    DELETE FROM dbo.appointments         WHERE doctor_id IN (SELECT doctor_id FROM #del_doc) OR clinic_id IN (SELECT clinic_id FROM #del_clinic);
    DELETE FROM dbo.doctor_queue         WHERE doctor_id IN (SELECT doctor_id FROM #del_doc) OR clinic_id IN (SELECT clinic_id FROM #del_clinic);
    DELETE FROM dbo.reviews              WHERE doctor_id IN (SELECT doctor_id FROM #del_doc) OR clinic_id IN (SELECT clinic_id FROM #del_clinic);
    DELETE FROM dbo.favorite_doctors     WHERE doctor_id IN (SELECT doctor_id FROM #del_doc) OR clinic_id IN (SELECT clinic_id FROM #del_clinic);
    DELETE FROM dbo.doctor_leave         WHERE doctor_id IN (SELECT doctor_id FROM #del_doc) OR clinic_id IN (SELECT clinic_id FROM #del_clinic);
    DELETE FROM dbo.doctor_timing        WHERE doctor_id IN (SELECT doctor_id FROM #del_doc) OR clinic_id IN (SELECT clinic_id FROM #del_clinic);
    DELETE FROM dbo.doctor_unavailability WHERE doctor_id IN (SELECT doctor_id FROM #del_doc);
    DELETE FROM dbo.Doctor_Medicine      WHERE doctor_id IN (SELECT doctor_id FROM #del_doc);
    DELETE FROM dbo.Medicine_Master_Backup WHERE doctor_id IN (SELECT doctor_id FROM #del_doc);
    DELETE FROM dbo.receptionist         WHERE doctor_id IN (SELECT doctor_id FROM #del_doc) OR clinic_id IN (SELECT clinic_id FROM #del_clinic);

    DELETE FROM dbo.clinic_images        WHERE clinic_id IN (SELECT clinic_id FROM #del_clinic);
    DELETE FROM dbo.clinics              WHERE clinic_id IN (SELECT clinic_id FROM #del_clinic);

    DELETE FROM dbo.RefreshTokens        WHERE user_mobile IN (SELECT mobile FROM #del_doc);
    DELETE FROM dbo.otp_verification     WHERE mobile_no IN (SELECT mobile FROM #del_doc);
    DELETE FROM dbo.AccountDeletionRequests WHERE phone IN (SELECT mobile FROM #del_doc) AND role_id = 1;
    DELETE FROM dbo.doctor_login         WHERE doctor_id IN (SELECT doctor_id FROM #del_doc);

    COMMIT TRAN;
    PRINT 'Deleted.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRAN;
    SELECT ERROR_MESSAGE() AS error, ERROR_LINE() AS line;
END CATCH;

SELECT doctor_id, name, mobile, active_status FROM dbo.doctor_login ORDER BY doctor_id;

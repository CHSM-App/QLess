-- =============================================================================
-- Rollback 002: drop_unused_procedures
-- =============================================================================
-- Recreates the three procedures exactly as in 000_baseline.sql.
-- =============================================================================

CREATE OR ALTER PROCEDURE [dbo].[sp_doc]
AS
BEGIN
SET NOCOUNT ON;

/*
============================================================
APPOINTMENT SYSTEM - FINAL DOCUMENTATION (QUEUE + SLOT ENGINE)
============================================================

OVERVIEW
------------------------------------------------------------
System supports TWO booking types:

1. QUEUE BASED (booking_type = 1)
2. SLOT BASED  (booking_type = 2)

Both flows are STRICTLY separated internally but handled
through SAME stored procedure using @operation.

All operations are:
✔ appointment_id driven
✔ state-machine based
✔ production-safe

------------------------------------------------------------


============================================================
TABLES
============================================================

TABLE: appointments
------------------------------------------------------------
appointment_id
doctor_id
patient_id        → can store patient OR family member id
user_type         → 1 = patient, 2 = family member
appointment_date
start_time
end_time
booking_type      → 1 = Queue, 2 = Slot
queue_number
status
created_at

STATUS FLOW:
------------------------------------------------------------
booked → in_progress → completed
       → skipped → in_progress → completed
       → cancelled


TABLE: doctor_queue
------------------------------------------------------------
queue_id
doctor_id
queue_date
current_serving        → queue_number
current_queue_no       → patient_id
total_queue
completed_count
avg_consultation_time
queue_status           → 1=Active, 2=Paused, 3=Stopped
started_at
stopped_at


============================================================
CORE DESIGN RULES
============================================================

1. appointment_id is SINGLE SOURCE OF TRUTH
2. NEVER rely on queue_number for updates
3. Only ONE active (in_progress) per doctor per day
4. Queue and Slot NEVER run together
5. doctor_queue is ONLY for queue tracking

------------------------------------------------------------


============================================================
BOOKING LOGIC
============================================================

SLOT BOOKING:
------------------------------------------------------------
- Fixed time slots
- start_time & end_time predefined
- No runtime modification

QUEUE BOOKING:
------------------------------------------------------------
- Only allowed for TODAY
- queue_number auto increment
- doctor_queue auto maintained


============================================================
SESSION MANAGEMENT (IMPORTANT)
============================================================

START_SESSION
------------------------------------------------------------
booked/skipped → in_progress

QUEUE:
- sets start_time
- updates doctor_queue pointer

SLOT:
- only updates status


END_SESSION
------------------------------------------------------------
in_progress → completed

QUEUE:
- sets end_time
- increments completed_count
- auto stops queue if no patients

SLOT:
- only status update


NEXT_SESSION
------------------------------------------------------------
COMPLETE current + START next

QUEUE:
- completes current
- finds next by queue_number
- starts next
- updates doctor_queue

SLOT:
- completes current
- starts next slot (by start_time)


SKIP_SESSION
------------------------------------------------------------
booked/in_progress → skipped

QUEUE:
- skips current
- moves to next
- updates pointer

SLOT:
- skips slot
- activates next


RECALL_SESSION
------------------------------------------------------------
skipped → in_progress

QUEUE:
- updates pointer
- resumes skipped patient

SLOT:
- directly in_progress


============================================================
QUEUE MANAGEMENT
============================================================

QUEUE_START
------------------------------------------------------------
- Initializes queue
- No patient auto assigned

QUEUE_PAUSE
------------------------------------------------------------
- queue_status = 2

QUEUE_STOP
------------------------------------------------------------
- queue_status = 3

QUEUE_STATUS
------------------------------------------------------------
- total_queue
- current_serving
- waiting_count


============================================================
QUEUE ESTIMATION
============================================================

Formula:
------------------------------------------------------------
patients_ahead = my_queue - current_serving - 1

estimated_wait =
    patients_ahead * avg_consultation_time

default avg = 7 minutes


============================================================
AVG CONSULTATION TIME
============================================================

DOCTOR_AVG_TIME:
------------------------------------------------------------
Priority:
1. Today’s completed appointments
2. Last 7 days
3. Default value


============================================================
PATIENT HANDLING
============================================================

patient_id column stores:
------------------------------------------------------------
- patient id (user_type = 1)
- family member id (user_type = 2)

No separate column used.


============================================================
IMPORTANT EDGE CASES HANDLED
============================================================

✔ Skip patient and recall later
✔ Queue stops only when no booked/skipped left
✔ Only one active session allowed
✔ Appointment_id validation everywhere
✔ Safe updates using @@ROWCOUNT
✔ Slot integrity preserved (no time overwrite)


============================================================
FINAL ARCHITECTURE
============================================================

QUEUE:
------------------------------------------------------------
Stateful system (uses doctor_queue)

SLOT:
------------------------------------------------------------
Stateless system (status driven)

------------------------------------------------------------

FINAL RULE:
------------------------------------------------------------
"QUEUE = state machine"
"SLOT  = schedule system"

============================================================
*/


END
GO

CREATE OR ALTER PROCEDURE [dbo].[sp_users_manage]
(
    @operation          NVARCHAR(50),
    @role_id            INT = NULL,
	@gender_id INT =NULL,
	@blood_group_id INT=NULL
)
AS
BEGIN
SET NOCOUNT ON;

IF @operation = 'getGenders'
BEGIN
	select * from dbo.Gender
END

IF @operation = 'getRelations'
BEGIN
	select * from dbo.Relations
END

IF @operation = 'getBloodGroups'
BEGIN
	select * from dbo.blood_groups
END

END
GO

CREATE OR ALTER PROCEDURE [dbo].[sp_Medicin_Type]
    @operation NVARCHAR(20) = NULL,
    @Medi_Type_Id INT = 0,
    @Medi_Type_Name NVARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @operation = 'Update'
    BEGIN
        IF @Medi_Type_Id = 0
        BEGIN
            DECLARE @new_id INT;
            SELECT TOP 1 @new_id = Medi_Type_Id FROM dbo.Medicin_Type ORDER BY Medi_Type_Id DESC;

            IF @new_id IS NULL OR @new_id = 0
                SET @new_id = 1;
            ELSE
                SET @new_id = @new_id + 1;

            INSERT INTO dbo.Medicin_Type (
                Medi_Type_Id, Medi_Type_Name
            )
            VALUES (
                @new_id, @Medi_Type_Name
            );
        END
        ELSE
        BEGIN
            UPDATE dbo.Medicin_Type
            SET Medi_Type_Name = @Medi_Type_Name
            WHERE Medi_Type_Id = @Medi_Type_Id;
        END
    END

    IF @operation = 'Select'
    BEGIN
        SELECT *
        FROM dbo.Medicin_Type
        WHERE Medi_Type_Id = @Medi_Type_Id;
    END

    IF @operation = 'Delete'
    BEGIN
        DELETE FROM dbo.Medicin_Type
        WHERE Medi_Type_Id = @Medi_Type_Id;
    END
END
GO


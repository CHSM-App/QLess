-- =============================================================================
-- Migration 000: baseline
-- =============================================================================
-- Full QLess schema generated from the live catalog of QLess_test_db on 2026-11-20
-- (tables, keys, indexes, checks, foreign keys, views, procedures) plus the
-- lookup rows the app cannot run without (Gender, role, blood_groups, Medicine_Type, Relations).
--
-- On an EMPTY database: npm run migrate:up builds everything from here.
-- On an EXISTING database: run scripts/bootstrap-migrations.sql once instead,
-- which marks 000 as applied without executing it.
-- =============================================================================

-- ── Tables ─────────────────────────────────────────────────────────────────

CREATE TABLE [dbo].[AccountDeletionRequests] (
    [id] int IDENTITY(1, 1) NOT NULL,
    [phone] varchar(15) NOT NULL,
    [role_id] tinyint NOT NULL,
    [reason] nvarchar(255) NULL,
    [status] varchar(20) NOT NULL CONSTRAINT [DF__AccountDe__statu__1387E197] DEFAULT ('pending'),
    [requested_at] datetime NOT NULL CONSTRAINT [DF__AccountDe__reque__147C05D0] DEFAULT (getdate()),
    [completed_at] datetime NULL,
    [otp_verified_at] datetime2(7) NULL,
    [scheduled_for] datetime2(7) NULL,
    [created_at] datetime2(7) NOT NULL CONSTRAINT [DF__AccountDe__creat__24B26D99] DEFAULT (getutcdate()),
    CONSTRAINT [PK__AccountD__3213E83F92760F4A] PRIMARY KEY CLUSTERED ([id])
)
GO

CREATE TABLE [dbo].[appointments] (
    [appointment_id] int IDENTITY(1, 1) NOT NULL,
    [doctor_id] int NOT NULL,
    [patient_id] int NOT NULL,
    [appointment_date] date NOT NULL,
    [start_time] time(7) NULL,
    [end_time] time(7) NULL,
    [booking_type] int NOT NULL,
    [queue_number] int NULL,
    [status] nvarchar(20) NULL CONSTRAINT [DF__appointme__statu__4865BE2A] DEFAULT ('booked'),
    [created_at] datetime NULL CONSTRAINT [DF__appointme__creat__4959E263] DEFAULT (getdate()),
    [user_type] int NULL,
    [slot_id] int NULL,
    [queue_id] int NULL,
    [symptoms] nvarchar(max) NULL,
    [is_reviewed] bit NULL CONSTRAINT [DF_is_reviewed] DEFAULT ((0)),
    [clinic_id] nvarchar(20) NULL,
    [is_arrived] bit NOT NULL CONSTRAINT [DF__appointme__is_ar__2882FE7D] DEFAULT ((0)),
    [arrived_at] datetime NULL,
    CONSTRAINT [PK__appointm__A50828FCD7D7F5D5] PRIMARY KEY CLUSTERED ([appointment_id]),
    CONSTRAINT [CHK_booking_rules] CHECK ([booking_type]=(1) AND [queue_number] IS NOT NULL AND [queue_id] IS NOT NULL OR [booking_type]=(2) AND [start_time] IS NOT NULL AND [end_time] IS NOT NULL AND [queue_number] IS NULL AND [queue_id] IS NULL),
    CONSTRAINT [CHK_booking_type] CHECK ([booking_type]=(2) OR [booking_type]=(1))
)
GO

CREATE TABLE [dbo].[blood_groups] (
    [blood_group_id] int IDENTITY(1, 1) NOT NULL,
    [blood_group_name] varchar(5) NOT NULL,
    CONSTRAINT [PK__blood_gr__63C4B9427FF41242] PRIMARY KEY CLUSTERED ([blood_group_id]),
    CONSTRAINT [UQ__blood_gr__4B73B8DCCF0ABFA6] UNIQUE NONCLUSTERED ([blood_group_name])
)
GO

CREATE TABLE [dbo].[booking_status] (
    [id] int NULL,
    [status] nvarchar(50) NULL,
    CONSTRAINT [uq_booking_status_status] UNIQUE NONCLUSTERED ([status])
)
GO

CREATE TABLE [dbo].[Category] (
    [c_id] int IDENTITY(1, 1) NOT NULL,
    [category] nvarchar(50) NULL,
    CONSTRAINT [PK_Category] PRIMARY KEY CLUSTERED ([c_id])
)
GO

CREATE TABLE [dbo].[clinic_images] (
    [clinic_image_id] int IDENTITY(1, 1) NOT NULL,
    [clinic_id] nvarchar(50) NOT NULL,
    [image_url] nvarchar(max) NOT NULL,
    [sort_order] int NULL,
    [active_status] bit NULL CONSTRAINT [DF__clinic_im__activ__27C3E46E] DEFAULT ((0)),
    [created_at] datetime NULL CONSTRAINT [DF__clinic_im__creat__28B808A7] DEFAULT (getdate()),
    CONSTRAINT [PK__clinic_i__F923E5B547D7F8DC] PRIMARY KEY CLUSTERED ([clinic_image_id])
)
GO

CREATE TABLE [dbo].[clinics] (
    [clinic_id] nvarchar(50) NOT NULL,
    [clinic_name] nvarchar(50) NULL,
    [clinic_address] nvarchar(50) NULL,
    [latitude] decimal(10, 7) NULL,
    [longitude] decimal(10, 7) NULL,
    [consultation_fee] decimal(10, 2) NULL,
    [created_at] datetime NULL CONSTRAINT [DF__clinics__created__56E8E7AB] DEFAULT (getdate()),
    [website_name] nvarchar(50) NULL,
    [clinic_email] nvarchar(50) NULL,
    [clinic_contact] nvarchar(20) NULL,
    [image_url] nvarchar(max) NULL,
    [active_status] int NULL,
    [is_verified] int NULL,
    [doctor_id] int NULL,
    CONSTRAINT [PK__clinics__A0C8D19B1997DC17] PRIMARY KEY CLUSTERED ([clinic_id])
)
GO

CREATE TABLE [dbo].[doctor_availability] (
    [availability_id] int IDENTITY(1, 1) NOT NULL,
    [doctor_id] int NOT NULL,
    [day_of_week] varchar(10) NOT NULL,
    [is_enabled] bit NULL CONSTRAINT [DF__doctor_av__is_en__1E6F845E] DEFAULT ((0)),
    [created_at] datetime NULL CONSTRAINT [DF__doctor_av__creat__1F63A897] DEFAULT (getdate()),
    [clinic_id] nvarchar(20) NULL,
    CONSTRAINT [PK__doctor_a__86E3A80158C745CF] PRIMARY KEY CLUSTERED ([availability_id])
)
GO

CREATE TABLE [dbo].[doctor_leave] (
    [leave_id] int IDENTITY(1, 1) NOT NULL,
    [doctor_id] int NOT NULL,
    [from_date] date NOT NULL,
    [to_date] date NOT NULL,
    [reason] nvarchar(200) NULL,
    [is_active] bit NOT NULL CONSTRAINT [DF_doctor_leave_active] DEFAULT ((1)),
    [created_at] datetime NOT NULL CONSTRAINT [DF_doctor_leave_created] DEFAULT (getdate()),
    [clinic_id] varchar(20) NULL,
    CONSTRAINT [PK__doctor_l__743350BC50A6E9B3] PRIMARY KEY CLUSTERED ([leave_id])
)
GO

CREATE TABLE [dbo].[doctor_login] (
    [doctor_id] int IDENTITY(1, 1) NOT NULL,
    [name] nvarchar(50) NULL,
    [email] nvarchar(50) NULL,
    [mobile] nvarchar(20) NULL,
    [qualification] nvarchar(max) NULL,
    [license_no] nvarchar(50) NULL,
    [image] nvarchar(max) NULL,
    [experience] int NULL,
    [specialization] nvarchar(50) NULL,
    [created_at] datetime NULL,
    [role_id] int NULL,
    [active_status] int NULL,
    [is_verified] int NULL,
    [clinic_id] nvarchar(50) NULL,
    [token] nvarchar(max) NULL,
    [gender_id] int NULL,
    [q_start_before] int NULL,
    [avg_consultation_time] decimal(10, 2) NULL,
    [last_heartbeat] datetime NULL,
    [is_online] int NULL CONSTRAINT [DF__doctor_lo__is_on__7E8CC4B1] DEFAULT ((0)),
    CONSTRAINT [UQ_doctor_mobile] UNIQUE NONCLUSTERED ([mobile])
)
GO

CREATE TABLE [dbo].[Doctor_Medicine] (
    [link_id] int IDENTITY(1, 1) NOT NULL,
    [doctor_id] int NOT NULL,
    [medicine_id] int NOT NULL,
    [is_active] bit NOT NULL CONSTRAINT [DF__Doctor_Me__is_ac__77DFC722] DEFAULT ((1)),
    [created_at] datetime NOT NULL CONSTRAINT [DF__Doctor_Me__creat__78D3EB5B] DEFAULT (getdate()),
    CONSTRAINT [PK__Doctor_M__93B0078C77645622] PRIMARY KEY CLUSTERED ([link_id]),
    CONSTRAINT [UQ_Doctor_Medicine] UNIQUE NONCLUSTERED ([doctor_id], [medicine_id])
)
GO

CREATE TABLE [dbo].[doctor_queue] (
    [queue_id] int IDENTITY(1, 1) NOT NULL,
    [doctor_id] int NULL,
    [queue_date] date NULL,
    [current_serving] int NULL CONSTRAINT [DF__doctor_qu__curre__5A846E65] DEFAULT ((0)),
    [total_queue] int NULL CONSTRAINT [DF__doctor_qu__total__5B78929E] DEFAULT ((0)),
    [avg_consultation_time] float NULL,
    [queue_status] int NULL CONSTRAINT [DF__doctor_qu__queue__5C6CB6D7] DEFAULT ((1)),
    [started_at] datetime NULL,
    [stopped_at] datetime NULL,
    [created_at] datetime NULL CONSTRAINT [DF__doctor_qu__creat__5D60DB10] DEFAULT (getdate()),
    [completed_count] int NULL CONSTRAINT [DF__doctor_qu__compl__5E54FF49] DEFAULT ((0)),
    [current_patient_id] int NULL CONSTRAINT [DF__doctor_qu__curre__640DD89F] DEFAULT ((0)),
    [slot_id] int NULL CONSTRAINT [DF__doctor_qu__slot___15A53433] DEFAULT ((0)),
    [max_queue] int NULL,
    [clinic_id] nvarchar(20) NULL,
    [booking_closed] bit NOT NULL CONSTRAINT [DF__doctor_qu__booki__278EDA44] DEFAULT ((0)),
    CONSTRAINT [PK__doctor_q__2294FA6ECAC7D513] PRIMARY KEY CLUSTERED ([queue_id])
)
GO

CREATE TABLE [dbo].[doctor_time_slots] (
    [slot_id] int IDENTITY(1, 1) NOT NULL,
    [availability_id] int NOT NULL,
    [start_time] time(7) NOT NULL,
    [end_time] time(7) NOT NULL,
    [booking_mode] int NOT NULL,
    [slot_duration] int NULL,
    [max_queue_length] int NULL,
    [slot_key] varchar(50) NULL,
    [is_deleted] bit NULL CONSTRAINT [DF__doctor_ti__is_de__2AA05119] DEFAULT ((0)),
    [is_active] bit NOT NULL CONSTRAINT [DF__doctor_ti__is_ac__45544755] DEFAULT ((1)),
    CONSTRAINT [PK__doctor_t__971A01BB2F2284B5] PRIMARY KEY CLUSTERED ([slot_id])
)
GO

CREATE TABLE [dbo].[doctor_timing] (
    [doctor_id] int NOT NULL,
    [avg_consultation_time] float NULL,
    [morning_avg] float NULL,
    [afternoon_avg] float NULL,
    [evening_avg] float NULL,
    [total_completed] int NULL,
    [last_updated] datetime NULL,
    [clinic_id] varchar(50) NOT NULL,
    CONSTRAINT [PK_doctor_timing] PRIMARY KEY CLUSTERED ([doctor_id], [clinic_id])
)
GO

CREATE TABLE [dbo].[doctor_unavailability] (
    [id] int IDENTITY(1, 1) NOT NULL,
    [doctor_id] int NOT NULL,
    [unavailable_date] date NOT NULL,
    [reason] nvarchar(255) NULL,
    CONSTRAINT [PK__doctor_u__3213E83FD6F55302] PRIMARY KEY CLUSTERED ([id]),
    CONSTRAINT [UQ_doctor_unavailable] UNIQUE NONCLUSTERED ([doctor_id], [unavailable_date])
)
GO

CREATE TABLE [dbo].[family_members] (
    [member_id] int IDENTITY(1, 1) NOT NULL,
    [family_id] int NULL,
    [name] nvarchar(100) NULL,
    [Gender_id] int NULL,
    [relation_id] int NULL,
    [DOB] smalldatetime NULL,
    [mobile_no] nvarchar(50) NULL,
    CONSTRAINT [PK_family_members] PRIMARY KEY CLUSTERED ([member_id])
)
GO

CREATE TABLE [dbo].[favorite_doctors] (
    [favorite_id] int IDENTITY(1, 1) NOT NULL,
    [patient_id] int NOT NULL,
    [doctor_id] int NOT NULL,
    [is_favorite] bit NOT NULL CONSTRAINT [DF__favorite___is_fa__0A338187] DEFAULT ((1)),
    [created_at] datetime NOT NULL CONSTRAINT [DF__favorite___creat__0B27A5C0] DEFAULT (getdate()),
    [updated_at] datetime NULL,
    [clinic_id] nvarchar(20) NULL,
    CONSTRAINT [PK__favorite__46ACF4CB6D3DBE88] PRIMARY KEY CLUSTERED ([favorite_id]),
    CONSTRAINT [UQ_fav] UNIQUE NONCLUSTERED ([patient_id], [doctor_id], [clinic_id])
)
GO

CREATE TABLE [dbo].[Gender] (
    [gender_id] int NOT NULL,
    [gender] nvarchar(20) NOT NULL
)
GO

CREATE TABLE [dbo].[Medicine_Master] (
    [medicine_id] int IDENTITY(1, 1) NOT NULL,
    [medicine_name] nvarchar(500) NULL,
    [medicine_type_id] int NULL,
    CONSTRAINT [PK_Medicine_Master] PRIMARY KEY CLUSTERED ([medicine_id]),
    CONSTRAINT [UQ_Medicine_Name_Type] UNIQUE NONCLUSTERED ([medicine_name], [medicine_type_id])
)
GO

CREATE TABLE [dbo].[Medicine_Master_Backup] (
    [medicine_id] int IDENTITY(1, 1) NOT NULL,
    [doctor_id] int NULL,
    [medicine_name] nvarchar(500) NULL,
    [medicine_type_id] int NULL,
    [is_active] bit NOT NULL
)
GO

CREATE TABLE [dbo].[Medicine_Type] (
    [medicine_type_id] int IDENTITY(1, 1) NOT NULL,
    [Medi_Type_Name] nvarchar(100) NULL,
    CONSTRAINT [PK_Medicine_Type] PRIMARY KEY CLUSTERED ([medicine_type_id])
)
GO

CREATE TABLE [dbo].[notifications] (
    [notification_id] int IDENTITY(1, 1) NOT NULL,
    [patient_id] int NOT NULL,
    [title] nvarchar(200) NOT NULL,
    [body] nvarchar(1000) NOT NULL,
    [type] varchar(40) NOT NULL,
    [ref_id] varchar(40) NULL,
    [is_read] bit NOT NULL CONSTRAINT [DF__notificat__is_re__5B438874] DEFAULT ((0)),
    [created_at] datetime NOT NULL CONSTRAINT [DF__notificat__creat__5C37ACAD] DEFAULT (getdate()),
    CONSTRAINT [PK__notifica__E059842F2C963741] PRIMARY KEY CLUSTERED ([notification_id])
)
GO

CREATE TABLE [dbo].[otp_verification] (
    [id] int IDENTITY(1, 1) NOT NULL,
    [mobile_no] varchar(15) NULL,
    [otp_hash] varchar(255) NULL,
    [expires_at] datetime NULL,
    [attempts] int NULL CONSTRAINT [DF__otp_verif__attem__0A688BB1] DEFAULT ((0)),
    [is_verified] bit NULL CONSTRAINT [DF__otp_verif__is_ve__0B5CAFEA] DEFAULT ((0)),
    [created_at] datetime NULL CONSTRAINT [DF__otp_verif__creat__0C50D423] DEFAULT (getdate()),
    CONSTRAINT [PK__otp_veri__3213E83F9513BEDF] PRIMARY KEY CLUSTERED ([id])
)
GO

CREATE TABLE [dbo].[patient_records] (
    [prescription_id] int IDENTITY(1, 1) NOT NULL,
    [patient_id] int NOT NULL,
    [doctor_id] int NULL,
    [prescription_date] datetime NULL CONSTRAINT [DF__prescript__presc__2610A626] DEFAULT (getdate()),
    [symptoms] nvarchar(max) NULL,
    [diagnosis] nvarchar(max) NULL,
    [clinical_notes] nvarchar(max) NULL,
    [follow_up_date] date NULL,
    [advice] nvarchar(max) NULL,
    [created_at] datetime NULL CONSTRAINT [DF__prescript__creat__2704CA5F] DEFAULT (getdate()),
    [user_type] int NULL,
    [appointment_id] int NULL,
    [clinic_id] nvarchar(20) NULL,
    [investigation] nvarchar(max) NULL,
    CONSTRAINT [PK__prescrip__3EE444F8660E38C6] PRIMARY KEY CLUSTERED ([prescription_id])
)
GO

CREATE TABLE [dbo].[Patients] (
    [patient_id] int IDENTITY(1, 1) NOT NULL,
    [name] nvarchar(100) NULL,
    [mobile_no] nvarchar(50) NULL,
    [email] nvarchar(100) NULL,
    [Address] nvarchar(100) NULL,
    [gender_id] int NULL,
    [DOB] smalldatetime NULL,
    [blood_group_id] int NULL,
    [weight] nvarchar(50) NULL,
    [role_id] int NULL,
    [active_status] int NULL,
    [token] nvarchar(max) NULL,
    [img_url] nvarchar(max) NULL,
    CONSTRAINT [PK_userProfile] PRIMARY KEY CLUSTERED ([patient_id]),
    CONSTRAINT [UQ_patient_mobile] UNIQUE NONCLUSTERED ([mobile_no])
)
GO

CREATE TABLE [dbo].[PrescriptionMedicine] (
    [presc_med_id] int IDENTITY(1, 1) NOT NULL,
    [prescription_id] int NOT NULL,
    [medicine_id] int NOT NULL,
    [medicine_type_id] int NOT NULL,
    [frequency] varchar(50) NULL,
    [duration] varchar(50) NULL,
    [timing] varchar(50) NULL,
    [tablet_dosage] varchar(20) NULL,
    [syrup_dosage_ml] varchar(20) NULL,
    [inj_dosage] varchar(20) NULL,
    [inj_route] varchar(20) NULL,
    [drops_count] varchar(10) NULL,
    [drops_application] varchar(20) NULL,
    [lotion_apply_area] varchar(50) NULL,
    [lotion_usage] varchar(50) NULL,
    [spray_puffs] varchar(20) NULL,
    [spray_usage] varchar(20) NULL,
    [powder_dosage] varchar(20) NULL,
    [powder_form] varchar(50) NULL,
    [inhaler_puffs] varchar(20) NULL,
    [inhaler_type] varchar(30) NULL,
    [inhaler_technique] varchar(50) NULL,
    [inhaler_usage] varchar(50) NULL,
    CONSTRAINT [PK__Prescrip__80008E0F9924DF3F] PRIMARY KEY CLUSTERED ([presc_med_id])
)
GO

CREATE TABLE [dbo].[receptionist] (
    [recep_id] int IDENTITY(1, 1) NOT NULL,
    [name] nvarchar(100) NULL,
    [mobile_no] nvarchar(50) NULL,
    [email] nvarchar(100) NULL,
    [Address] nvarchar(100) NULL,
    [gender_id] int NULL,
    [active_status] int NULL,
    [token] nvarchar(max) NULL,
    [img_url] nvarchar(max) NULL,
    [clinic_id] nvarchar(50) NULL,
    [created_at] datetime NULL,
    [role_id] int NULL,
    [doctor_id] int NULL
)
GO

CREATE TABLE [dbo].[RefreshTokens] (
    [id] int NOT NULL,
    [user_mobile] nvarchar(50) NOT NULL,
    [refresh_token] nvarchar(max) NOT NULL,
    [device_info] nvarchar(500) NULL,
    [created_at] datetime2(7) NULL,
    [expires_at] datetime2(7) NOT NULL,
    [revoked] bit NULL,
    [role_id] int NULL,
    CONSTRAINT [PK__RefreshT__3213E83FC9D556E1] PRIMARY KEY CLUSTERED ([id])
)
GO

CREATE TABLE [dbo].[Relations] (
    [relation_id] int NOT NULL,
    [relation] nvarchar(50) NULL
)
GO

CREATE TABLE [dbo].[reviews] (
    [review_id] int IDENTITY(1, 1) NOT NULL,
    [appointment_id] int NOT NULL,
    [doctor_id] int NOT NULL,
    [patient_id] int NOT NULL,
    [rating] decimal(2, 1) NOT NULL,
    [comment] nvarchar(500) NULL,
    [created_at] datetime NOT NULL CONSTRAINT [DF__reviews__created__10E07F16] DEFAULT (getdate()),
    [reviewed_by_user_id] int NULL,
    [clinic_id] nvarchar(20) NULL,
    CONSTRAINT [PK__reviews__60883D906E445617] PRIMARY KEY CLUSTERED ([review_id]),
    CONSTRAINT [CK_reviews_rating] CHECK ([rating]>=(0.5) AND [rating]<=(5.0) AND floor([rating]*(2))=[rating]*(2))
)
GO

CREATE TABLE [dbo].[role] (
    [role_id] int IDENTITY(1, 1) NOT NULL,
    [role] nvarchar(15) NULL
)
GO

CREATE TABLE [dbo].[State] (
    [state_id] int NOT NULL,
    [state] nvarchar(50) NULL,
    CONSTRAINT [PK__State__81A474176D65139C] PRIMARY KEY CLUSTERED ([state_id])
)
GO

-- ── Indexes ────────────────────────────────────────────────────────────────

CREATE UNIQUE NONCLUSTERED INDEX [UX_reviews_appointment] ON [dbo].[reviews] ([appointment_id])
GO

CREATE NONCLUSTERED INDEX [IX_reviews_doctor] ON [dbo].[reviews] ([doctor_id])
GO

CREATE NONCLUSTERED INDEX [IX_reviews_patient] ON [dbo].[reviews] ([patient_id])
GO

CREATE UNIQUE NONCLUSTERED INDEX [UX_ADR_phone_role_pending] ON [dbo].[AccountDeletionRequests] ([phone], [role_id]) WHERE ([status]='pending')
GO

CREATE NONCLUSTERED INDEX [IX_ADR_scheduled] ON [dbo].[AccountDeletionRequests] ([status], [scheduled_for])
GO

CREATE UNIQUE NONCLUSTERED INDEX [idx_slot_key] ON [dbo].[doctor_time_slots] ([availability_id], [start_time])
GO

CREATE UNIQUE NONCLUSTERED INDEX [UQ_queue] ON [dbo].[appointments] ([doctor_id], [appointment_date], [slot_id], [queue_number]) WHERE ([queue_number] IS NOT NULL)
GO

CREATE NONCLUSTERED INDEX [IDX_APPOINTMENT_MAIN] ON [dbo].[appointments] ([doctor_id], [appointment_date])
GO

CREATE NONCLUSTERED INDEX [IDX_SLOT] ON [dbo].[appointments] ([doctor_id], [appointment_date], [start_time])
GO

CREATE NONCLUSTERED INDEX [IDX_QUEUE] ON [dbo].[appointments] ([doctor_id], [appointment_date], [queue_number])
GO

CREATE NONCLUSTERED INDEX [IDX_BOOKING_TYPE] ON [dbo].[appointments] ([doctor_id], [appointment_date], [booking_type])
GO

CREATE NONCLUSTERED INDEX [IX_doctor_leave_lookup] ON [dbo].[doctor_leave] ([doctor_id], [is_active], [from_date], [to_date])
GO

CREATE UNIQUE NONCLUSTERED INDEX [UQ__doctor_q__355A60F078E22094] ON [dbo].[doctor_queue] ([doctor_id], [queue_date], [slot_id])
GO

CREATE NONCLUSTERED INDEX [IX_notifications_patient_created] ON [dbo].[notifications] ([patient_id], [created_at] DESC)
GO

-- ── Foreign keys ───────────────────────────────────────────────────────────

ALTER TABLE [dbo].[doctor_time_slots] WITH CHECK ADD CONSTRAINT [FK__doctor_ti__avail__22401542] FOREIGN KEY ([availability_id]) REFERENCES [dbo].[doctor_availability] ([availability_id])
GO

ALTER TABLE [dbo].[clinic_images] WITH CHECK ADD CONSTRAINT [FK__clinic_im__clini__29AC2CE0] FOREIGN KEY ([clinic_id]) REFERENCES [dbo].[clinics] ([clinic_id])
GO

ALTER TABLE [dbo].[PrescriptionMedicine] WITH CHECK ADD CONSTRAINT [FK__Prescript__presc__2CBDA3B5] FOREIGN KEY ([prescription_id]) REFERENCES [dbo].[patient_records] ([prescription_id])
GO

ALTER TABLE [dbo].[PrescriptionMedicine] WITH CHECK ADD CONSTRAINT [FK__Prescript__medic__2EA5EC27] FOREIGN KEY ([medicine_type_id]) REFERENCES [dbo].[Medicine_Type] ([medicine_type_id])
GO

ALTER TABLE [dbo].[Doctor_Medicine] WITH CHECK ADD CONSTRAINT [FK_DoctorMedicine_Medicine] FOREIGN KEY ([medicine_id]) REFERENCES [dbo].[Medicine_Master] ([medicine_id])
GO

ALTER TABLE [dbo].[PrescriptionMedicine] WITH CHECK ADD CONSTRAINT [FK_PrescriptionMedicine_Medicine] FOREIGN KEY ([medicine_id]) REFERENCES [dbo].[Medicine_Master] ([medicine_id])
GO

-- ── Views, procedures ──────────────────────────────────────────────────────

CREATE VIEW dbo.appointment_booking_vw AS

SELECT 
    a.appointment_id, a.doctor_id, a.patient_id,
    a.patient_id AS family_id,
    d.name AS doctor_name, d.specialization, d.experience,
    COALESCE(a.clinic_id, d.clinic_id) AS clinic_id,
    c.clinic_name, c.clinic_address, c.clinic_contact, c.latitude, c.longitude,
    p.name AS patient_name,
    g.gender, p.DOB,
    a.appointment_date, a.start_time, a.end_time,
    a.queue_number, a.status, a.booking_type, a.user_type,
    'SELF' AS booking_for,
    a.slot_id, a.queue_id, a.symptoms, a.is_reviewed, d.mobile
FROM dbo.appointments AS a
INNER JOIN dbo.Patients AS p ON a.patient_id = p.patient_id
LEFT OUTER JOIN dbo.Gender AS g ON p.gender_id = g.gender_id
LEFT OUTER JOIN (
    SELECT doctor_id, name, specialization, experience, mobile, clinic_id,
           ROW_NUMBER() OVER (PARTITION BY doctor_id ORDER BY doctor_id) AS rn
    FROM dbo.doctor_login
) AS d ON a.doctor_id = d.doctor_id AND d.rn = 1
LEFT OUTER JOIN dbo.clinics AS c 
    ON c.clinic_id = COALESCE(a.clinic_id, d.clinic_id)
WHERE (a.user_type = 1)

UNION ALL

SELECT 
    a.appointment_id, a.doctor_id, a.patient_id,
    fm.family_id,
    d.name AS doctor_name, d.specialization, d.experience,
    COALESCE(a.clinic_id, d.clinic_id) AS clinic_id,
    c.clinic_name, c.clinic_address, c.clinic_contact, c.latitude, c.longitude,
    fm.name AS patient_name,
    g.gender, fm.DOB,
    a.appointment_date, a.start_time, a.end_time,
    a.queue_number, a.status, a.booking_type, a.user_type,
    'FAMILY' AS booking_for,
    a.slot_id, a.queue_id, a.symptoms, a.is_reviewed, d.mobile
FROM dbo.appointments AS a
INNER JOIN dbo.family_members AS fm ON a.patient_id = fm.member_id
LEFT OUTER JOIN dbo.Gender AS g ON fm.Gender_id = g.gender_id
LEFT OUTER JOIN (
    SELECT doctor_id, name, specialization, experience, mobile, clinic_id,
           ROW_NUMBER() OVER (PARTITION BY doctor_id ORDER BY doctor_id) AS rn
    FROM dbo.doctor_login
) AS d ON a.doctor_id = d.doctor_id AND d.rn = 1
LEFT OUTER JOIN dbo.clinics AS c 
    ON c.clinic_id = COALESCE(a.clinic_id, d.clinic_id)
WHERE (a.user_type = 2)
GO

CREATE VIEW dbo.doctor_availability_vw AS
SELECT 
    dbo.doctor_availability.doctor_id,
    dbo.doctor_availability.clinic_id,        -- ← ADD THIS
    dbo.doctor_availability.day_of_week,
    dbo.doctor_availability.is_enabled,
    dbo.doctor_availability.created_at,
    dbo.doctor_time_slots.slot_id,
    dbo.doctor_time_slots.availability_id,
    dbo.doctor_time_slots.start_time,
    dbo.doctor_time_slots.end_time,
    dbo.doctor_time_slots.booking_mode,
    dbo.doctor_time_slots.slot_duration,
    dbo.doctor_time_slots.is_active
FROM dbo.doctor_availability 
INNER JOIN dbo.doctor_time_slots 
    ON dbo.doctor_availability.availability_id = dbo.doctor_time_slots.availability_id
WHERE dbo.doctor_time_slots.is_active = 1;
GO

CREATE VIEW dbo.doctor_login_vw
AS
SELECT c.clinic_id, c.clinic_name, c.clinic_address, c.latitude, c.longitude, c.consultation_fee, c.created_at, c.website_name, c.clinic_email, c.clinic_contact, c.image_url, c.active_status, c.is_verified, dl.doctor_id, dl.name, dl.email, dl.mobile, 
                  dl.qualification, dl.license_no, dl.image, dl.experience, dl.specialization, dl.created_at AS doc_created_at, dl.active_status AS doc_active_status, dl.is_verified AS doc_is_verified, dl.role_id, r.role, dl.token, g.gender, dl.gender_id, 
                  dl.q_start_before
FROM     dbo.doctor_login AS dl INNER JOIN
                  dbo.clinics AS c ON c.doctor_id = dl.doctor_id INNER JOIN
                  dbo.role AS r ON dl.role_id = r.role_id INNER JOIN
                  dbo.Gender AS g ON dl.gender_id = g.gender_id
GO

CREATE VIEW dbo.patient_login_vw
AS
SELECT p.patient_id, p.name, p.mobile_no, p.email, p.Address, p.DOB, p.weight, p.role_id, p.active_status, p.token, r.role, p.gender_id, g.gender, p.blood_group_id, bg.blood_group_name, p.img_url
FROM     dbo.Patients AS p LEFT OUTER JOIN
                  dbo.role AS r ON p.role_id = r.role_id LEFT OUTER JOIN
                  dbo.Gender AS g ON p.gender_id = g.gender_id LEFT OUTER JOIN
                  dbo.blood_groups AS bg ON p.blood_group_id = bg.blood_group_id
GO

-- 2) Expose it through prescription_vw (used by PrescriptionDetail,
--    AppointmentWisePrescription and the patient/doctor prescription screens).
CREATE VIEW [dbo].[prescription_vw]
AS
SELECT d.name AS doctor_name, d.qualification, d.experience, d.specialization, p.doctor_id, p.patient_id, CASE WHEN p.user_type = 1 THEN 'Self' WHEN p.user_type = 2 THEN 'Family' END AS user_type_name,
                  CASE WHEN p.user_type = 1 THEN pt.name WHEN p.user_type = 2 THEN fm.name END AS patient_name, p.prescription_id, p.prescription_date, p.symptoms, p.diagnosis, p.clinical_notes, p.follow_up_date, p.advice, p.created_at,
                  pm.presc_med_id, pm.medicine_id, mm.medicine_name, mm.medicine_type_id, mt.Medi_Type_Name, pm.frequency, pm.duration, pm.timing, pm.tablet_dosage, pm.syrup_dosage_ml, pm.inj_dosage, pm.inj_route, pm.drops_count,
                  pm.drops_application, pm.lotion_apply_area, pm.spray_puffs, pm.spray_usage, pm.lotion_usage, c.clinic_name, c.clinic_address, c.clinic_contact, p.user_type, p.appointment_id, pm.powder_dosage, pm.powder_form, pm.inhaler_puffs,
                  pm.inhaler_type, pm.inhaler_technique, pm.inhaler_usage, p.investigation
FROM     dbo.patient_records AS p INNER JOIN
                  dbo.appointments AS ap ON ap.appointment_id = p.appointment_id INNER JOIN
                  dbo.doctor_login AS d ON d.doctor_id = p.doctor_id LEFT OUTER JOIN
                  dbo.Patients AS pt ON p.patient_id = pt.patient_id AND p.user_type = 1 LEFT OUTER JOIN
                  dbo.family_members AS fm ON p.patient_id = fm.member_id AND p.user_type = 2 LEFT OUTER JOIN
                  dbo.PrescriptionMedicine AS pm ON p.prescription_id = pm.prescription_id LEFT OUTER JOIN
                  dbo.Medicine_Master AS mm ON mm.medicine_id = pm.medicine_id LEFT OUTER JOIN
                  dbo.Medicine_Type AS mt ON mm.medicine_type_id = mt.medicine_type_id INNER JOIN
                  dbo.clinics AS c ON c.clinic_id = ap.clinic_id
GO

CREATE VIEW dbo.receptionist_vw
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

-- 3) Procedure ---------------------------------------------------------------
CREATE PROCEDURE [dbo].[ManageRefreshToken]
    @operation       NVARCHAR(20),       -- 'insert' | 'get' | 'revoke' | 'AutoTask'

    -- Insert fields
    @user_mobile     NVARCHAR(50) = NULL,
    @refresh_token   NVARCHAR(MAX) = NULL,
    @device_info     NVARCHAR(500) = NULL,
    @ip_address      NVARCHAR(100) = NULL,
    @expires_at      DATETIME2 = NULL,
    @role            NVARCHAR(20) = NULL -- 'doctor' | 'patient' | 'receptionist'
AS
BEGIN
    SET NOCOUNT ON;

    -- Insert Operation --------------------------------------------
    IF @operation = 'insert'
    BEGIN
        DECLARE @role_id TINYINT =
            CASE LOWER(LTRIM(RTRIM(ISNULL(@role, ''))))
                WHEN 'doctor'       THEN 1
                WHEN 'patient'      THEN 2
                WHEN 'receptionist' THEN 3
            END;

        -- Refuse to create a session whose role we cannot name. A NULL role_id
        -- here is exactly what produced the receptionist→doctor bug.
        IF @role_id IS NULL
        BEGIN
            RAISERROR('ManageRefreshToken: @role must be doctor, patient or receptionist.', 16, 1);
            RETURN;
        END

        DECLARE @new INT;

        BEGIN TRANSACTION;

            -- UPDLOCK + HOLDLOCK: two logins landing together must not read the
            -- same MAX(id) and collide on the primary key.
            SELECT @new = ISNULL(MAX(id), 0) + 1
            FROM dbo.RefreshTokens WITH (UPDLOCK, HOLDLOCK);

            INSERT INTO dbo.RefreshTokens
                (id, user_mobile, refresh_token, device_info, created_at, expires_at, role_id, revoked)
            VALUES
                (@new, @user_mobile, @refresh_token, @device_info, SYSUTCDATETIME(), @expires_at, @role_id, 0);

        COMMIT TRANSACTION;

        SELECT @new AS id, @role_id AS role_id;
        RETURN;
    END


    -- Get Operation ------------------------------------------------
    IF @operation = 'get'
    BEGIN
        -- SELECT * carries role_id, which is what refreshAccessToken reads.
        SELECT TOP 1 *
        FROM dbo.RefreshTokens
        WHERE refresh_token = @refresh_token
          AND revoked = 0
          AND expires_at > SYSUTCDATETIME();
        RETURN;
    END


    -- Revoke Operation ---------------------------------------------
    IF @operation = 'revoke'
    BEGIN
        -- Callers revoke every live token of one mobile (login + refresh), or a
        -- single token when they have it.
        UPDATE dbo.RefreshTokens
        SET revoked = 1
        WHERE revoked != 1
          AND (
                (@refresh_token IS NOT NULL AND refresh_token = @refresh_token)
             OR (@refresh_token IS NULL AND @user_mobile IS NOT NULL AND user_mobile = @user_mobile)
              );

        SELECT @@ROWCOUNT AS revoked_count;
        RETURN;
    END


    -- Housekeeping --------------------------------------------------
    IF @operation = 'AutoTask'
    BEGIN
        DELETE FROM dbo.RefreshTokens
        WHERE expires_at < SYSUTCDATETIME();

        DELETE FROM dbo.RefreshTokens
        WHERE id IN (
            SELECT id FROM (
                SELECT id,
                       ROW_NUMBER() OVER (
                         PARTITION BY user_mobile ORDER BY created_at DESC
                       ) AS rn
                FROM dbo.RefreshTokens
            ) t
            WHERE t.rn > 5
        );
        RETURN;
    END

    -- Invalid Operation --------------------------------------------
    SELECT 'Invalid operation. Use insert, get, revoke or AutoTask.' AS error_message;
END
GO

CREATE PROCEDURE [dbo].[sp_appointment]
    @operation NVARCHAR(50) = NULL,
    @doctor_id INT = NULL,
    @patient_id INT = NULL,
    @family_id INT = NULL,
    @appointment_id INT = NULL,
    @appointment_date DATE = NULL,
    @user_type INT = NULL,
    @start_time TIME = NULL,
    @default_avg INT = 7,
    @slot_id int = 0,
    @patient_id_local INT = NULL,
    @queue_id INT = NULL,
    @token NVARCHAR(MAX) = NULL,
    @is_next INT = NULL,
    @symptoms NVARCHAR(MAX) = NULL,
    @clinic_id NVARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    --------------------------------------------------
    -- ALL VARIABLE DECLARATIONS
    --------------------------------------------------

    -- BOOK
    DECLARE @booking_mode INT,
            @slot_duration INT,
            @slot_start TIME,
            @slot_end TIME,
            @minutes INT,
            @next_queue INT,
            @temp_slot int,
            @total_queue int,
            @max_queue_length int;

    -- GET_AVAILABILITY
    DECLARE @day NVARCHAR(20);

    -- GET_MONTH_SLOTS
    DECLARE @start_date DATE;
    DECLARE @end_date DATE;

    -- QUEUE_NEXT / QUEUE_SKIP / SHARED
    DECLARE @booking_type INT;
    DECLARE @current_queue INT;
    DECLARE @next_patient_id INT;
    DECLARE @next_appointment_id INT;

    -- QUEUE_NEXT
    DECLARE @current_serving INT;
    DECLARE @qn_next_queue INT;
    DECLARE @qn_next_patient_id INT;

    -- QUEUE_SKIP
    DECLARE @skip_current_serving INT;
    DECLARE @skip_next_queue INT;
    DECLARE @skip_next_patient_id INT;

    -- QUEUE_RECALL
    DECLARE @recall_queue_number INT;

    -- QUEUE_ESTIMATE
    DECLARE @my_queue INT;
    DECLARE @patients_ahead INT;
    DECLARE @estimated_wait INT;

    -- RESCHEDULE
    DECLARE @old_booking_type INT;
    DECLARE @old_status NVARCHAR(50);

    -- START_SESSION
    DECLARE @ss_queue_number INT;
    DECLARE @ss_patient_id INT;

    -- END_SESSION
    DECLARE @es_current_serving INT;
    DECLARE @consult_time INT;
    DECLARE @hour INT;

    -- DOCTOR_AVG_TIME
    DECLARE @avg_time INT;

    -- QUEUE_ESTIMATE_SMART / QUEUE_PREVIEW_ESTIMATE
    DECLARE @base_avg FLOAT;
    DECLARE @adaptive_avg FLOAT;
    DECLARE @queue_size INT;
    DECLARE @estimated_time FLOAT;
    DECLARE @started_at DATETIME;
    DECLARE @time_passed INT;
    DECLARE @expected_completed FLOAT;
    DECLARE @actual_completed INT;
    DECLARE @delay_count FLOAT;
    DECLARE @adjustment FLOAT;
    DECLARE @arrival_time DATETIME;
    DECLARE @multiplier FLOAT;
    DECLARE @queue_started_time DATETIME;
    DECLARE @slot_start_dt DATETIME;
    DECLARE @mins_from_mid INT;

    BEGIN TRY

        --------------------------------------------------
        -- BOOK APPOINTMENT
        --------------------------------------------------
        IF @operation = 'BOOK'
        BEGIN
            BEGIN TRY
                BEGIN TRANSACTION;

                IF EXISTS
                (
                    SELECT 1
                    FROM doctor_unavailability
                    WHERE doctor_id = @doctor_id
                          AND unavailable_date = @appointment_date
                )
                    RAISERROR('Doctor Unavailable', 16, 1);

                IF EXISTS
                (
                    SELECT 1
                    FROM appointments
                    WHERE doctor_id = @doctor_id
                          AND patient_id = @patient_id
                          AND user_type = @user_type
                          AND appointment_date = @appointment_date
                          AND slot_id = @slot_id
                          AND status = 'booked'
                )
                    RAISERROR('Already booked', 16, 1);

                --------------------------------------------------
                -- GET SLOT / MODE
                --------------------------------------------------

                IF (@start_time IS NULL)
                BEGIN
                    SET @booking_mode = 1;
                END
                ELSE
                BEGIN
                    SET @booking_mode = 2;
                END;

                IF @booking_mode IS NULL
                    RAISERROR('No valid slot found', 16, 1);

                --------------------------------------------------
                -- SLOT BOOKING
                --------------------------------------------------
                IF @booking_mode = 2
                BEGIN
                    --------------------------------------------------
                    -- 🔥 FETCH SLOT DATA
                    --------------------------------------------------
                    SELECT @slot_start = start_time,
                           @slot_end = end_time,
                           @slot_duration = slot_duration
                    FROM doctor_time_slots
                    WHERE slot_id = @slot_id;

                    --------------------------------------------------
                    -- VALIDATIONS
                    --------------------------------------------------
                    IF @slot_duration IS NULL
                        RAISERROR('Slot duration not defined', 16, 1);

                    IF @start_time < @slot_start
                       OR @start_time >= @slot_end
                        RAISERROR('Invalid slot time range', 16, 1);

                    SET @minutes = DATEDIFF(MINUTE, @slot_start, @start_time);

                    IF @minutes % @slot_duration <> 0
                        RAISERROR('Invalid slot interval', 16, 1);

                    --------------------------------------------------
                    -- INSERT
                    --------------------------------------------------
                    INSERT INTO appointments
                    (
                        doctor_id,
                        patient_id,
                        user_type,
                        appointment_date,
                        start_time,
                        end_time,
                        booking_type,
                        slot_id,
                        queue_number,
                        queue_id,
                        symptoms,
						clinic_id
                    )
                    VALUES
                    (   @doctor_id,
                        @patient_id,
                        @user_type,
                        @appointment_date,
                        @start_time,
                        DATEADD(MINUTE, @slot_duration, @start_time), -- ✅ FIXED
                        2,
                        @slot_id,
                        NULL,
                        NULL,
                        @symptoms,
						@clinic_id
                    );
                END

                --------------------------------------------------
                -- QUEUE BOOKING
                --------------------------------------------------
                ELSE IF @booking_mode = 1
                BEGIN
                    IF @appointment_date <> CAST(GETDATE() AS DATE)
                        RAISERROR('Queue only for today', 16, 1);

                    --------------------------------------------------
                    -- GET NEXT QUEUE NUMBER
                    --------------------------------------------------
                    SELECT @next_queue = ISNULL(MAX(queue_number), 0) + 1
                    FROM appointments WITH (UPDLOCK, HOLDLOCK)
                    WHERE doctor_id = @doctor_id
                          AND appointment_date = @appointment_date
                          AND slot_id = @slot_id;

                    --------------------------------------------------
                    -- UPSERT doctor_queue + GET queue_id
                    --------------------------------------------------
                    SELECT @temp_slot = queue_id,
                           @max_queue_length = max_queue,
                           @total_queue = total_queue
                    FROM doctor_queue
                    WHERE doctor_id = @doctor_id
                          AND slot_id = @slot_id
                          AND queue_date = @appointment_date
						   AND (@clinic_id IS NULL OR clinic_id = @clinic_id OR clinic_id IS NULL);


                    if (isnull(@temp_slot, 0) > 0)
                    BEGIN
                        IF (ISNULL(@total_queue, 0) + 1 > @max_queue_length)
                            RAISERROR('Queue Full', 16, 1);

                        UPDATE doctor_queue
                        SET total_queue = ISNULL(total_queue, 0) + 1,
                            clinic_id   = COALESCE(clinic_id, @clinic_id)
                        where queue_id = @temp_slot;

                    END
                    else
                    BEGIN
                        INSERT INTO doctor_queue
                        (
                            slot_id,
                            doctor_id,
                            queue_date,
                            total_queue,
                            current_serving,
                            current_patient_id,
                            queue_status,
                            completed_count,
                            max_queue,
							   clinic_id  
                        )
                        SELECT @slot_id,
                               @doctor_id,
                               @appointment_date,
                               1,
                               0,
                               @patient_id,
                               0,
                               0,
                               ts.max_queue_length,
							    @clinic_id  
                        FROM doctor_time_slots ts
                        WHERE ts.slot_id = @slot_id;
                    END;



                    --------------------------------------------------
                    -- GET queue_id
                    --------------------------------------------------
                    SELECT @queue_id = queue_id
                    FROM doctor_queue
                    WHERE doctor_id = @doctor_id
                          AND queue_date = @appointment_date
                          AND slot_id = @slot_id
						   AND (@clinic_id IS NULL OR clinic_id = @clinic_id OR clinic_id IS NULL);

                    --------------------------------------------------
                    -- INSERT APPOINTMENT
                    --------------------------------------------------
                    INSERT INTO appointments
                    (
                        doctor_id,
                        patient_id,
                        user_type,
                        appointment_date,
                        booking_type,
                        queue_number,
                        queue_id,
                        slot_id,
                        symptoms,
						clinic_id
                    )
                    VALUES
                    (@doctor_id,
                     @patient_id,
                     @user_type,
                     @appointment_date,
                     1  ,
                     @next_queue,
                     @queue_id,
                     @slot_id,
                     @symptoms,
					 @clinic_id
                    );
                END

                COMMIT;

                SELECT 1 AS success,
                       'Booked Successfully' AS message;
            END TRY
            BEGIN CATCH
                ROLLBACK;

                SELECT 0 AS success,
                       ERROR_MESSAGE() AS message,
                       ERROR_MESSAGE() AS error;
            END CATCH
        END

        --------------------------------------------------
        -- GET AVAILABILITY
        --------------------------------------------------
        IF @operation = 'GET_AVAILABILITY'
        BEGIN
            SET @day = DATENAME(WEEKDAY, @appointment_date);

            SELECT ts.slot_id,
                   ts.start_time,
                   ts.end_time,
                   ts.booking_mode,
                   ts.slot_duration,
                   (
                       SELECT COUNT(*)
                       FROM appointments a
                       WHERE a.doctor_id = @doctor_id
                             AND a.appointment_date = @appointment_date
                             AND a.start_time = ts.start_time
                             AND a.status = 'booked'
                   ) AS booked_count
            FROM doctor_availability da
                JOIN doctor_time_slots ts
                    ON da.availability_id = ts.availability_id
            WHERE da.doctor_id = @doctor_id
                  AND da.day_of_week = @day
                  AND da.is_enabled = 1
				   AND (da.clinic_id = @clinic_id OR da.clinic_id IS NULL OR @clinic_id IS NULL); -- ← ADD;
        END

        --------------------------------------------------
        -- CANCEL
        --------------------------------------------------
        IF @operation = 'CANCEL_APPOINTMENT'
        BEGIN


            --------------------------------------------------
            -- GET QUEUE ID FROM APPOINTMENT
            --------------------------------------------------
            SELECT @queue_id = queue_id
            FROM appointments
            WHERE appointment_id = @appointment_id;

            --------------------------------------------------
            -- UPDATE APPOINTMENT STATUS
            --------------------------------------------------
            UPDATE appointments
            SET status = 'cancelled'
            WHERE appointment_id = @appointment_id;

            --------------------------------------------------
            -- REDUCE QUEUE COUNT
            --------------------------------------------------
            IF @queue_id IS NOT NULL
            BEGIN
                UPDATE doctor_queue
                SET total_queue = CASE
                                      WHEN total_queue > 0 THEN
                                          total_queue - 1
                                      ELSE
                                          0
                                  END
                WHERE queue_id = @queue_id;
            END

            SELECT 1 AS success,
                   'Cancelled Successfully' AS message;
        END

        ----------------------------------------------------
        ---- GET MONTH SLOTS
        ----------------------------------------------------
        --IF @operation = 'GET_MONTH_SLOTS'
        --BEGIN
        --    SET @start_date = CAST(GETDATE() AS DATE);
        --    SET @end_date = EOMONTH(@start_date);

        --    ;WITH DateCTE
        --    AS (SELECT @start_date AS booking_date
        --        UNION ALL
        --        SELECT DATEADD(DAY, 1, booking_date)
        --        FROM DateCTE
        --        WHERE booking_date < @end_date
        --       ),
        --          AvailableDays
        --    AS (SELECT d.booking_date,
        --               da.availability_id
        --        FROM DateCTE d
        --            JOIN doctor_availability da
        --                ON LOWER(LTRIM(RTRIM(da.day_of_week))) = LOWER(DATENAME(WEEKDAY, d.booking_date))
        --                   AND da.doctor_id = @doctor_id
        --                   AND da.is_enabled = 1
        --       ),
        --          Slots
        --    AS (SELECT ad.booking_date,
        --               ts.start_time,
        --               ts.end_time,
        --               ts.slot_duration
        --        FROM AvailableDays ad
        --            JOIN doctor_time_slots ts
        --                ON ts.availability_id = ad.availability_id
        --        WHERE ts.booking_mode = 2
        --       ),
        --          SlotCTE
        --    AS (SELECT booking_date,
        --               start_time,
        --               end_time,
        --               slot_duration,
        --               start_time AS slot_time
        --        FROM Slots
        --        UNION ALL
        --        SELECT booking_date,
        --               start_time,
        --               end_time,
        --               slot_duration,
        --               DATEADD(MINUTE, slot_duration, slot_time)
        --        FROM SlotCTE
        --        WHERE DATEADD(MINUTE, slot_duration, slot_time) < end_time
        --       )
        --    SELECT s.booking_date,
        --           s.slot_time AS start_time,
        --           DATEADD(MINUTE, s.slot_duration, s.slot_time) AS end_time,
        --           1 AS is_booked
        --    FROM SlotCTE s
        --        INNER JOIN appointments a
        --            ON a.doctor_id = @doctor_id
        --               AND a.appointment_date = s.booking_date
        --               AND a.start_time = s.slot_time
        --               AND a.status = 'booked'
        --    ORDER BY s.booking_date,
        --             s.slot_time
        --    OPTION (MAXRECURSION 1000);
        --END
		IF @operation = 'GET_MONTH_SLOTS'
BEGIN
    SET @start_date = CAST(GETDATE() AS DATE);
    --SET @end_date = EOMONTH(@start_date);
	SET @end_date = EOMONTH(DATEADD(MONTH, 1, @start_date));


    ;WITH DateCTE AS (
        SELECT @start_date AS booking_date
        UNION ALL
        SELECT DATEADD(DAY, 1, booking_date)
        FROM DateCTE
        WHERE booking_date < @end_date
    ),
    AvailableDays AS (
        SELECT d.booking_date, da.availability_id
        FROM DateCTE d
        JOIN doctor_availability da
            ON LOWER(LTRIM(RTRIM(da.day_of_week))) = LOWER(DATENAME(WEEKDAY, d.booking_date))
           AND da.doctor_id = @doctor_id
           AND da.clinic_id = @clinic_id
           AND da.is_enabled = 1
    ),
    --Slots AS (
    --    SELECT ad.booking_date, ts.start_time, ts.end_time, ts.slot_duration
    --    FROM AvailableDays ad
    --    JOIN doctor_time_slots ts ON ts.availability_id = ad.availability_id
    --    WHERE ts.booking_mode = 2
	  Slots AS (
        SELECT ad.booking_date, ts.start_time, ts.end_time, ts.slot_duration
        FROM AvailableDays ad
        JOIN doctor_time_slots ts ON ts.availability_id = ad.availability_id
        WHERE ts.booking_mode IN (2, 3)   -- ← 2 la IN (2,3) kar
   
    ),
    SlotCTE AS (
        SELECT booking_date, start_time, end_time, slot_duration, start_time AS slot_time
        FROM Slots
        UNION ALL
        SELECT booking_date, start_time, end_time, slot_duration,
               DATEADD(MINUTE, slot_duration, slot_time)
        FROM SlotCTE
        WHERE DATEADD(MINUTE, slot_duration, slot_time) < end_time
    )
    SELECT s.booking_date,
           s.slot_time AS start_time,
           DATEADD(MINUTE, s.slot_duration, s.slot_time) AS end_time,
           1 AS is_booked
    FROM SlotCTE s
    INNER JOIN appointments a
        ON a.doctor_id        = @doctor_id
       AND a.clinic_id        = @clinic_id
       AND a.appointment_date = s.booking_date
       AND a.start_time       = s.slot_time
       AND a.status           = 'booked'
    ORDER BY s.booking_date, s.slot_time
    OPTION (MAXRECURSION 1000);
END


        --------------------------------------------------
        -- QUEUE STATUS
        --------------------------------------------------
        IF @operation = 'QUEUE_STATUS'
        BEGIN
            SELECT ISNULL(total_queue, 0) AS total_queue,
                   ISNULL(current_serving, 0) AS current_serving,
                   ISNULL(total_queue, 0) - ISNULL(current_serving, 0) AS waiting_count
            FROM doctor_queue
            WHERE doctor_id = @doctor_id
                  AND queue_date = @appointment_date;
        END

        --------------------------------------------------
        -- CANCEL APPOINTMENT BY DOCTOR (ONLY SLOT)
        --------------------------------------------------
        IF @operation = 'CANCEL_BY_DOCTOR'
        BEGIN
            BEGIN TRY
                BEGIN TRANSACTION;

                --------------------------------------------------
                -- VALIDATE APPOINTMENT
                --------------------------------------------------
                SELECT @booking_type = booking_type
                FROM appointments
                WHERE appointment_id = @appointment_id
                      AND doctor_id = @doctor_id;

                IF @booking_type IS NULL
                    RAISERROR('Invalid appointment', 16, 1);

                --------------------------------------------------
                -- 🔥 ONLY SLOT ALLOWED
                --------------------------------------------------
                IF @booking_type <> 2
                    RAISERROR('Doctor can cancel only slot appointments', 16, 1);

                --------------------------------------------------
                -- UPDATE STATUS
                --------------------------------------------------
                UPDATE appointments
                SET status = 'CancleD'
                WHERE appointment_id = @appointment_id;

                COMMIT;

                SELECT 1 AS success,
                       'Slot appointment cancelled successfully' AS message;

            END TRY
            BEGIN CATCH
                ROLLBACK;

                SELECT 0 AS success,
                       ERROR_MESSAGE() AS message,
                       ERROR_MESSAGE() AS error;
            END CATCH
        END

        --------------------------------------------------
        -- QUEUE START
        --------------------------------------------------
        IF @operation = 'QUEUE_START'
        BEGIN
            --------------------------------------------------
            -- START / CREATE QUEUE
            --------------------------------------------------

            UPDATE doctor_queue
            SET queue_status = 1,
                started_at = GETDATE(),
                current_serving = 0
            --current_queue_no = NULL
            WHERE doctor_id = @doctor_id
                  AND queue_id = @queue_id
                  AND queue_date = CAST(GETDATE() AS DATE);

            --MERGE doctor_queue AS dq
            --USING
            --(
            --    SELECT @doctor_id AS doctor_id,
            --           CAST(GETDATE() AS DATE) AS queue_date
            --) src
            --ON dq.doctor_id = src.doctor_id
            --   AND dq.queue_date = src.queue_date
            --WHEN MATCHED THEN
            --    UPDATE SET queue_status = 1,
            --               started_at = GETDATE(),
            --               current_serving = 0,
            --               current_queue_no = NULL
            --WHEN NOT MATCHED THEN
            --    INSERT
            --    (
            --        doctor_id,
            --        queue_date,
            --        queue_status,
            --        current_serving,
            --        total_queue,
            --        current_queue_no,
            --        completed_count,
            --        started_at
            --    )
            --    VALUES
            --    (@doctor_id, CAST(GETDATE() AS DATE), 1, 0, 0, NULL, 0, GETDATE());

            --------------------------------------------------
            -- 🔥 RETURN TOKENS (CORRECT LOGIC)
            --------------------------------------------------
            SELECT a.appointment_id,
                   a.queue_number,

                   --------------------------------------------------
                   -- 🔥 TOKEN RESOLUTION
                   --------------------------------------------------
                   CASE
                       WHEN a.user_type = 1 THEN
                           p.token
                       WHEN a.user_type = 2 THEN
                           p2.token
                   END AS token
            FROM appointments a

                --------------------------------------------------
                -- DIRECT PATIENT
                --------------------------------------------------
                LEFT JOIN patients p
                    ON a.user_type = 1
                       AND p.patient_id = a.patient_id

                --------------------------------------------------
                -- FAMILY MEMBER → MAP TO PATIENT
                --------------------------------------------------
                LEFT JOIN family_members fm
                    ON a.user_type = 2
                       AND fm.member_id = a.patient_id
                LEFT JOIN patients p2
                    ON fm.family_id = p2.patient_id
            WHERE a.doctor_id = @doctor_id
                  AND queue_id = @queue_id
                  AND a.appointment_date = CAST(GETDATE() AS DATE)
                  AND a.booking_type = 1
                  AND a.status IN ( 'booked', 'in_progress' )
            ORDER BY a.queue_number;

        END

        --------------------------------------------------
        -- GET TODAY QUEUE BY DOCTOR (WITH SLOT TIMES)
        --------------------------------------------------
        IF @operation = 'GET_TODAY_QUEUE'
        BEGIN
            BEGIN TRY

                --------------------------------------------------
                -- FETCH QUEUES WITH SESSION TIME (slot )
                --------------------------------------------------
                SELECT dq.queue_id,
                       dq.doctor_id,
                       dq.queue_date,
                       dq.slot_id,

                       --------------------------------------------------
                       -- 🔥 CORRECT SLOT TIME (DIRECT FROM SLOT_ID)
                       --------------------------------------------------
                       ts.start_time,
                       ts.end_time,
                       dq.queue_status,
                       dq.current_serving,
                       dq.current_patient_id,
                       dq.total_queue,
                       dq.completed_count,
                       dq.started_at,
                       dq.stopped_at
                FROM doctor_queue dq

                    --------------------------------------------------
                    -- 🔥 DIRECT SLOT JOIN (IMPORTANT)
                    --------------------------------------------------
                    LEFT JOIN doctor_time_slots ts
                        ON dq.slot_id = ts.slot_id
                    LEFT JOIN doctor_availability da
                        ON da.availability_id = ts.availability_id

                --------------------------------------------------
                -- FILTER
                --------------------------------------------------
                WHERE dq.doctor_id = @doctor_id
                      AND dq.queue_date = CAST(GETDATE() AS DATE)
                      AND (@clinic_id IS NULL OR dq.clinic_id = @clinic_id OR dq.clinic_id IS NULL)
                ORDER BY ts.start_time;

                --------------------------------------------------
                -- STATUS
                --------------------------------------------------
                SELECT 1 AS success,
                       'Today queue fetched' AS message;

            END TRY
            BEGIN CATCH
                SELECT 0 AS success,
                       ERROR_MESSAGE() AS message,
                       ERROR_MESSAGE() AS error;
            END CATCH
        END

        IF @operation = 'QUEUE_PAUSE'
        BEGIN
            --------------------------------------------------
            -- PAUSE QUEUE (YOUR ORIGINAL LOGIC)
            --------------------------------------------------
            UPDATE doctor_queue
            SET queue_status = 2 -- 2 = paused
            WHERE doctor_id = @doctor_id
                  AND queue_id = @queue_id
                  AND queue_date = CAST(GETDATE() AS DATE);

            --------------------------------------------------
            -- CHECK SUCCESS
            --------------------------------------------------
            IF @@ROWCOUNT = 0
            BEGIN
                SELECT 0 AS success,
                       'Queue not found or already paused' AS message;
                RETURN;
            END

            --------------------------------------------------
            -- SUCCESS RESPONSE (RESULT SET 1)
            --------------------------------------------------
            SELECT 1 AS success,
                   'Queue paused' AS message;

            --------------------------------------------------
            -- 🔥 RETURN TOKENS (RESULT SET 2)
            --------------------------------------------------
            SELECT a.appointment_id,
                   a.queue_number,
                   CASE
                       WHEN a.user_type = 1 THEN
                           p.token
                       WHEN a.user_type = 2 THEN
                           p2.token
                   END AS token
            FROM appointments a
                LEFT JOIN patients p
                    ON a.user_type = 1
                       AND p.patient_id = a.patient_id
                LEFT JOIN family_members fm
                    ON a.user_type = 2
                       AND fm.member_id = a.patient_id
                LEFT JOIN patients p2
                    ON fm.family_id = p2.patient_id
            WHERE a.doctor_id = @doctor_id
                  AND a.appointment_date = CAST(GETDATE() AS DATE)
                  AND a.booking_type = 1
                  AND queue_id = @queue_id
                  AND a.status IN ( 'booked', 'in_progress' )
            ORDER BY a.queue_number;

        END

    --------------------------------------------------
-- EMERGENCY QUEUE PAUSE
--------------------------------------------------
IF @operation = 'QUEUE_PAUSE_EMERGENCY'
BEGIN
    BEGIN TRY

        IF @queue_id IS NULL
        BEGIN
            SELECT 0 AS success, 'queue_id required' AS message;
            RETURN;
        END

        DECLARE @q_doctor_id  INT;
        DECLARE @current_stat INT;

        SELECT @q_doctor_id  = doctor_id,
               @current_stat = queue_status
        FROM doctor_queue
        WHERE queue_id = @queue_id;

        IF @q_doctor_id IS NULL
        BEGIN
            SELECT 0 AS success, 'Invalid queue' AS message;
            RETURN;
        END

        --------------------------------------------------
        -- IDEMPOTENCY CHECK
        -- queue_status: 0=not started, 1=active, 2=paused, 3=stopped, 4=emergency
        --------------------------------------------------
        IF @current_stat = 4
        BEGIN
            SELECT 0 AS success,
                   'Queue is already in emergency pause' AS message;
            RETURN;
        END

        IF @current_stat = 3
        BEGIN
            SELECT 0 AS success,
                   'Queue is already stopped' AS message;
            RETURN;
        END

        --------------------------------------------------
        -- UPDATE STATUS → 4 (EMERGENCY PAUSED)
        --------------------------------------------------
        UPDATE doctor_queue
        SET queue_status = 4
        WHERE queue_id = @queue_id;

        --------------------------------------------------
        -- SUCCESS RESPONSE (RESULT SET 1)
        --------------------------------------------------
        SELECT 1 AS success,
               'Queue paused successfully' AS message;

        --------------------------------------------------
        -- TOKENS (RESULT SET 2)
        --------------------------------------------------
        SELECT a.appointment_id,
               a.queue_number,
               CASE
                   WHEN a.user_type = 1 THEN p.token
                   WHEN a.user_type = 2 THEN p2.token
               END AS token
        FROM appointments a
            LEFT JOIN patients p
                ON a.user_type = 1
                   AND p.patient_id = a.patient_id
            LEFT JOIN family_members fm
                ON a.user_type = 2
                   AND fm.member_id = a.patient_id
            LEFT JOIN patients p2
                ON fm.family_id = p2.patient_id
        WHERE a.doctor_id = @q_doctor_id
              AND a.appointment_date = CAST(GETDATE() AS DATE)
              AND a.booking_type = 1
              AND a.queue_id = @queue_id
              AND a.status IN ('booked', 'in_progress')
        ORDER BY a.queue_number;

    END TRY
    BEGIN CATCH
        SELECT 0 AS success,
               ERROR_MESSAGE() AS message,
               ERROR_MESSAGE() AS error;
    END CATCH
END

   
           ---------------------------------------------------------
        -- QUEUE STOP
        IF @operation = 'QUEUE_STOP'
        BEGIN
            DECLARE @qstop_start_time TIME;

            -- Get start_time of the queue being stopped (from its slot)
            SELECT TOP 1 @qstop_start_time = ts.start_time
            FROM doctor_queue dq
                INNER JOIN doctor_time_slots ts ON dq.slot_id = ts.slot_id
            WHERE dq.doctor_id  = @doctor_id
              AND dq.queue_id   = @queue_id
              AND dq.queue_date = CAST(GETDATE() AS DATE);

            -- Close this queue only
            UPDATE doctor_queue
            SET queue_status = 3,
                stopped_at   = GETDATE()
            WHERE doctor_id  = @doctor_id
              AND queue_id   = @queue_id
              AND queue_date = CAST(GETDATE() AS DATE);

            -- THIS queue's pending (booked + skipped) → cancelled
            UPDATE appointments
            SET status = 'CancleD'
            WHERE queue_id = @queue_id
              AND status IN ('skipped', 'booked');

            -- Earlier-time slot bookings (booking_type=2) before this queue's time → cancelled
            UPDATE appointments
            SET status = 'CancleD'
            WHERE doctor_id        = @doctor_id
              AND booking_type     = 2
              AND appointment_date = CAST(GETDATE() AS DATE)
              AND status IN ('booked', 'skipped')
              AND start_time       < @qstop_start_time;

            SELECT 1 success,
                   'Queue stopped' message;
        END
		-------------------------------------------------------------------------------------------------------------
-- QUEUE_PROXIMITY_LIST (NEW - for proximity notifications)
--------------------------------------------------
IF @operation = 'QUEUE_PROXIMITY_LIST'
BEGIN
    DECLARE @prox_hour INT = DATEPART(HOUR, GETDATE());
    DECLARE @prox_avg  INT;

    SELECT @prox_avg = COALESCE(
        CASE
            WHEN @prox_hour < 12 THEN morning_avg
            WHEN @prox_hour < 17 THEN afternoon_avg
            ELSE evening_avg
        END,
        avg_consultation_time,
        @default_avg
    )
    FROM doctor_timing
    WHERE doctor_id = @doctor_id AND (@clinic_id IS NULL OR clinic_id = @clinic_id);

    IF @prox_avg IS NULL SET @prox_avg = @default_avg;
    IF @prox_avg < 3     SET @prox_avg = 3;
    IF @prox_avg > 30    SET @prox_avg = 30;

    SELECT
        a.appointment_id,
        CASE
            WHEN a.user_type = 1 THEN a.patient_id
            WHEN a.user_type = 2 THEN fm.family_id
        END AS owner_id,
        CASE
            WHEN a.user_type = 1 THEN p.token
            WHEN a.user_type = 2 THEN p2.token
        END AS owner_token,
        ISNULL(d.name, 'your doctor') AS doctor_name,
        (a.queue_number - dq.current_serving - 1) * @prox_avg AS est_minutes_to_turn
    FROM appointments a
        INNER JOIN doctor_queue dq
            ON dq.queue_id = a.queue_id
        LEFT JOIN patients p
            ON a.user_type = 1 AND p.patient_id = a.patient_id
        LEFT JOIN family_members fm
            ON a.user_type = 2 AND fm.member_id = a.patient_id
        LEFT JOIN patients p2
            ON fm.family_id = p2.patient_id
        LEFT JOIN doctor_login d
            ON d.doctor_id = a.doctor_id
    WHERE a.doctor_id        = @doctor_id
      AND a.appointment_date = CAST(GETDATE() AS DATE)
      AND a.booking_type     = 1
      AND a.status           = 'booked'
      AND dq.queue_status    = 1
      AND (a.queue_number - dq.current_serving) > 1
    ORDER BY est_minutes_to_turn;
END


        --------------------------------------------------
        ---- NEXT SESSION (FINAL - SLOT_ID BASED)
        ----------------------------------------------------
        --IF @operation = 'NEXT_SESSION'
        --BEGIN
        --    --------------------------------------------------
        --    -- GET CURRENT APPOINTMENT DETAILS
        --    --------------------------------------------------
        --    SELECT @booking_type = booking_type,
        --           @slot_id = slot_id,
        --           @current_queue = queue_number
        --    FROM appointments
        --    WHERE appointment_id = @appointment_id
        --          AND doctor_id = @doctor_id;

        --    IF @booking_type IS NULL
        --    BEGIN
        --        SELECT 0 AS success,
        --               'Invalid appointment' AS message;
        --        RETURN;
        --    END

        --    --------------------------------------------------
        --    -- QUEUE FLOW (SESSION SAFE)
        --    --------------------------------------------------
        --    IF @booking_type = 1
        --    BEGIN
        --        --------------------------------------------------
        --        -- CHECK QUEUE STARTED
        --        --------------------------------------------------
        --        IF NOT EXISTS
        --        (
        --            SELECT 1
        --            FROM doctor_queue
        --            WHERE slot_id = @slot_id
        --                  AND queue_status = 1
        --        )
        --        BEGIN
        --            SELECT 0 AS success,
        --                   'Queue not started' AS message;
        --            RETURN;
        --        END

        --        --------------------------------------------------
        --        -- COMPLETE CURRENT
        --        --------------------------------------------------
        --        UPDATE appointments
        --        SET end_time = GETDATE(),
        --            status = 'completed'
        --        WHERE appointment_id = @appointment_id
        --              AND booking_type = 1
        --              AND status = 'in_progress';

        --        IF @@ROWCOUNT = 0
        --        BEGIN
        --            SELECT 0 AS success,
        --                   'Invalid active appointment' AS message;
        --            RETURN;
        --        END

        --        --------------------------------------------------
        --        -- UPDATE COMPLETED COUNT
        --        --------------------------------------------------
        --        UPDATE doctor_queue
        --        SET completed_count = ISNULL(completed_count, 0) + 1
        --        WHERE slot_id = @slot_id;

        --        --------------------------------------------------
        --        -- FIND NEXT IN SAME SESSION
        --        --------------------------------------------------
        --        SELECT TOP 1
        --            @next_queue = queue_number,
        --            @qn_next_patient_id = patient_id,
        --            @next_appointment_id = appointment_id
        --        FROM appointments
        --        WHERE slot_id = @slot_id
        --              AND booking_type = 1
        --              AND status = 'booked'
        --              AND queue_number > @current_queue
        --        ORDER BY queue_number;

        --        --------------------------------------------------
        --        -- NO NEXT IN THIS SESSION
        --        --------------------------------------------------
        --        IF @next_queue IS NULL
        --        BEGIN
        --            --------------------------------------------------
        --            -- CHECK SKIPPED IN SAME SESSION
        --            --------------------------------------------------
        --            IF EXISTS
        --            (
        --                SELECT 1
        --                FROM appointments
        --                WHERE slot_id = @slot_id
        --                      AND booking_type = 1
        --                      AND status = 'skipped'
        --            )
        --            BEGIN
        --                UPDATE doctor_queue
        --                SET current_patient_id = NULL
        --                WHERE slot_id = @slot_id;

        --                SELECT 1 AS success,
        --                       'Booked done. Skipped pending.' AS message;
        --                RETURN;
        --            END

        --            --------------------------------------------------
        --            -- CLOSE ONLY THIS SESSION
        --            --------------------------------------------------
        --            UPDATE doctor_queue
        --            SET
        --                --queue_status = 3,
        --                --             stopped_at = GETDATE(),
        --                current_patient_id = NULL
        --            WHERE slot_id = @slot_id;

        --            SELECT 1 AS success,
        --                   'No Patient Left' AS message;
        --            RETURN;
        --        END

        --        --------------------------------------------------
        --        -- START NEXT IN SAME SESSION
        --        --------------------------------------------------
        --        UPDATE appointments
        --        SET start_time = GETDATE(),
        --            status = 'in_progress'
        --        WHERE appointment_id = @next_appointment_id
        --              and slot_id = @slot_id;

        --        --------------------------------------------------
        --        -- UPDATE POINTER
        --        --------------------------------------------------
        --        UPDATE doctor_queue
        --        SET current_serving = @next_queue,
        --            current_patient_id = @qn_next_patient_id
        --        WHERE slot_id = @slot_id;

        --        --------------------------------------------------
        --        -- CONSULTATION TIME TRACKING
        --        --------------------------------------------------
        --        SELECT @consult_time = DATEDIFF(MINUTE, start_time, end_time)
        --        FROM appointments
        --        WHERE appointment_id = @appointment_id;

        --        IF @consult_time IS NOT NULL
        --        BEGIN
        --            SET @hour = DATEPART(HOUR, GETDATE());

        --            IF NOT EXISTS (SELECT 1 FROM doctor_timing WHERE doctor_id = @doctor_id)
        --            BEGIN
        --                INSERT INTO doctor_timing
        --                (
        --                    doctor_id,
        --                    avg_consultation_time,
        --                    morning_avg,
        --                    afternoon_avg,
        --                    evening_avg,
        --                    total_completed,
        --                    last_updated
        --                )
        --                VALUES
        --                (@doctor_id, @consult_time, NULL, NULL, NULL, 1, GETDATE());
        --            END
        --            ELSE
        --            BEGIN
        --                UPDATE doctor_timing
        --                SET avg_consultation_time = (avg_consultation_time * total_completed + @consult_time)
        --                                            / (total_completed + 1),
        --                    total_completed = total_completed + 1,
        --                    last_updated = GETDATE()
        --                WHERE doctor_id = @doctor_id;

        --                IF @hour < 12
        --                    UPDATE doctor_timing
        --                    SET morning_avg = ISNULL((morning_avg + @consult_time) / 2, @consult_time)
        --                    WHERE doctor_id = @doctor_id;
        --                ELSE IF @hour < 17
        --                    UPDATE doctor_timing
        --                    SET afternoon_avg = ISNULL((afternoon_avg + @consult_time) / 2, @consult_time)
        --                    WHERE doctor_id = @doctor_id;
        --                ELSE
        --                    UPDATE doctor_timing
        --                    SET evening_avg = ISNULL((evening_avg + @consult_time) / 2, @consult_time)
        --                    WHERE doctor_id = @doctor_id;
        --            END
        --        END

        --        SELECT 1 AS success,
        --               'Next queue patient started' AS message;
        --        RETURN;
        --    END

        --    --------------------------------------------------
        --    -- SLOT FLOW (SESSION SAFE)
        --    --------------------------------------------------
        --    IF @booking_type = 2
        --    BEGIN
        --        --------------------------------------------------
        --        -- COMPLETE CURRENT SLOT
        --        --------------------------------------------------
        --        UPDATE appointments
        --        SET status = 'completed'
        --        WHERE appointment_id = @appointment_id
        --              AND booking_type = 2
        --              AND status = 'in_progress';

        --        IF @@ROWCOUNT = 0
        --        BEGIN
        --            SELECT 0 AS success,
        --                   'Invalid active slot' AS message;
        --            RETURN;
        --        END

        --        --------------------------------------------------
        --        -- FIND NEXT SLOT IN SAME SESSION
        --        --------------------------------------------------
        --        SELECT TOP 1
        --            @next_appointment_id = appointment_id
        --        FROM appointments
        --        WHERE slot_id = @slot_id
        --              AND booking_type = 2
        --              AND status = 'booked'
        --        ORDER BY start_time;

        --        --------------------------------------------------
        --        -- NO NEXT SLOT
        --        --------------------------------------------------
        --        IF @next_appointment_id IS NULL
        --        BEGIN
        --            SELECT 1 AS success,
        --                   'No Patient Left' AS message;
        --            RETURN;
        --        END

        --        --------------------------------------------------
        --        -- START NEXT SLOT
        --        --------------------------------------------------
        --        UPDATE appointments
        --        SET status = 'in_progress'
        --        WHERE appointment_id = @next_appointment_id;

        --        SELECT 1 AS success,
        --               'Next slot started' AS message;
        --        RETURN;
        --    END
        --END
        --------------------------------------------------
        -- NEXT SESSION (FINAL - SESSION SAFE)
        --------------------------------------------------
        IF @operation = 'NEXT_SESSION'
        BEGIN
            --------------------------------------------------
            -- GET CURRENT APPOINTMENT DETAILS
            --------------------------------------------------
            SELECT @booking_type = booking_type,
                   @slot_id = slot_id,
                   @queue_id = queue_id,                 -- ✅ ADD
                   @current_queue = queue_number
            FROM appointments
            WHERE appointment_id = @appointment_id
                  AND doctor_id = @doctor_id;

            IF @booking_type IS NULL
            BEGIN
                SELECT 0 AS success,
                       'Invalid appointment' AS message;
                RETURN;
            END

            --------------------------------------------------
            -- QUEUE FLOW (SESSION SAFE)
            --------------------------------------------------
            IF @booking_type = 1
            BEGIN
                --------------------------------------------------
                -- CHECK QUEUE STARTED (✅ queue_id scoped)
                --------------------------------------------------
                IF NOT EXISTS
                (
                    SELECT 1
                    FROM doctor_queue
                    WHERE queue_id = @queue_id        -- ✅ specific session
                          AND queue_status = 1
                )
                BEGIN
                    SELECT 0 AS success,
                           'Queue not started' AS message;
                    RETURN;
                END

                --------------------------------------------------
                -- COMPLETE CURRENT
                --------------------------------------------------
                --UPDATE appointments
                --SET end_time = GETDATE(),
                --    status = 'completed'
                --WHERE appointment_id = @appointment_id
                --      AND booking_type = 1
                --      AND status = 'in_progress';

                --IF @@ROWCOUNT = 0
                --BEGIN
                --    SELECT 0 AS success,
                --           'Invalid active appointment' AS message;
                --    RETURN;
                --END

				                --------------------------------------------------
                -- COMPLETE CURRENT (in_progress किंवा booked)
                --------------------------------------------------
                UPDATE appointments
                SET end_time = GETDATE(),
                    status = 'completed'
                WHERE appointment_id = @appointment_id
                      AND booking_type = 1
                      AND status IN ('in_progress', 'booked');


                --------------------------------------------------
                -- UPDATE COMPLETED COUNT (✅ this queue only)
                --------------------------------------------------
                UPDATE doctor_queue
                SET completed_count = ISNULL(completed_count, 0) + 1
                WHERE queue_id = @queue_id;           -- ✅

                --------------------------------------------------
                -- FIND NEXT IN SAME SESSION (✅ queue_id scoped)
                --------------------------------------------------
                SELECT TOP 1
                    @next_queue = queue_number,
                    @qn_next_patient_id = patient_id,
                    @next_appointment_id = appointment_id
                FROM appointments
                WHERE queue_id = @queue_id            -- ✅
                      AND booking_type = 1
                      AND status = 'booked'
                      AND queue_number > @current_queue
                ORDER BY queue_number;

                --------------------------------------------------
                -- NO NEXT IN THIS SESSION
                --------------------------------------------------
                IF @next_queue IS NULL
                BEGIN
                    --------------------------------------------------
                    -- CHECK SKIPPED IN SAME SESSION (✅ queue_id scoped)
                    --------------------------------------------------
                    IF EXISTS
                    (
                        SELECT 1
                        FROM appointments
                        WHERE queue_id = @queue_id    -- ✅
                              AND booking_type = 1
                              AND status = 'skipped'
                    )
                    BEGIN
                        UPDATE doctor_queue
                        SET current_patient_id = NULL
                        WHERE queue_id = @queue_id;   -- ✅

                        SELECT 1 AS success,
                               'Booked done. Skipped pending.' AS message;
                        RETURN;
                    END

                    --------------------------------------------------
                    -- CLOSE ONLY THIS SESSION (✅ queue_id scoped)
                    --------------------------------------------------
                    UPDATE doctor_queue
                    SET current_patient_id = NULL
                    WHERE queue_id = @queue_id;       -- ✅

                    SELECT 1 AS success,
                           'No Patient Left' AS message;
                    RETURN;
                END

                --------------------------------------------------
                -- START NEXT IN SAME SESSION
                --------------------------------------------------
                UPDATE appointments
                SET start_time = GETDATE(),
                    status = 'in_progress'
                WHERE appointment_id = @next_appointment_id;

                --------------------------------------------------
                -- UPDATE POINTER (✅ queue_id scoped)
                --------------------------------------------------
                UPDATE doctor_queue
                SET current_serving = @next_queue,
                    current_patient_id = @qn_next_patient_id
                WHERE queue_id = @queue_id;           -- ✅

                --------------------------------------------------
                -- CONSULTATION TIME TRACKING (unchanged)
                --------------------------------------------------
                SELECT @consult_time = DATEDIFF(MINUTE, start_time, end_time)
                FROM appointments
                WHERE appointment_id = @appointment_id;
				IF @consult_time IS NOT NULL
BEGIN
    SET @hour = DATEPART(HOUR, GETDATE());
    DECLARE @effective_clinic VARCHAR(50) = ISNULL(@clinic_id, 'DEFAULT');

    IF NOT EXISTS (
        SELECT 1 FROM doctor_timing 
        WHERE doctor_id = @doctor_id AND clinic_id = @effective_clinic
    )
    BEGIN
        INSERT INTO doctor_timing
            (doctor_id, clinic_id, avg_consultation_time,
             morning_avg, afternoon_avg, evening_avg,
             total_completed, last_updated)
        VALUES
            (@doctor_id, @effective_clinic, @consult_time,
             NULL, NULL, NULL, 1, GETDATE());
    END
    ELSE
    BEGIN
        UPDATE doctor_timing
        SET avg_consultation_time = (avg_consultation_time * total_completed + @consult_time)
                                    / (total_completed + 1),
            total_completed = total_completed + 1,
            last_updated = GETDATE()
        WHERE doctor_id = @doctor_id AND clinic_id = @effective_clinic;

        IF @hour < 12
            UPDATE doctor_timing
            SET morning_avg = ISNULL((morning_avg + @consult_time) / 2, @consult_time)
            WHERE doctor_id = @doctor_id AND clinic_id = @effective_clinic;
        ELSE IF @hour < 17
            UPDATE doctor_timing
            SET afternoon_avg = ISNULL((afternoon_avg + @consult_time) / 2, @consult_time)
            WHERE doctor_id = @doctor_id AND clinic_id = @effective_clinic;
        ELSE
            UPDATE doctor_timing
            SET evening_avg = ISNULL((evening_avg + @consult_time) / 2, @consult_time)
            WHERE doctor_id = @doctor_id AND clinic_id = @effective_clinic;
    END
END


                SELECT 1 AS success,
                       'Next queue patient started' AS message;
                RETURN;
            END

            --------------------------------------------------
            -- SLOT FLOW (SESSION SAFE)
            --------------------------------------------------
            IF @booking_type = 2
            BEGIN
                --------------------------------------------------
                -- COMPLETE CURRENT SLOT
                --------------------------------------------------
                UPDATE appointments
                SET status = 'completed'
                WHERE appointment_id = @appointment_id
                      AND booking_type = 2
                      AND status = 'in_progress';

                IF @@ROWCOUNT = 0
                BEGIN
                    SELECT 0 AS success,
                           'Invalid active slot' AS message;
                    RETURN;
                END

                --------------------------------------------------
                -- FIND NEXT SLOT IN SAME SESSION (✅ DATE + DOCTOR filter)
                --------------------------------------------------
                SELECT TOP 1
                    @next_appointment_id = appointment_id
                FROM appointments
                WHERE slot_id = @slot_id
                      AND doctor_id = @doctor_id                      -- ✅
                      AND appointment_date = CAST(GETDATE() AS DATE)  -- ✅ TODAY only
                      AND booking_type = 2
                      AND status = 'booked'
                ORDER BY start_time;

                --------------------------------------------------
                -- NO NEXT SLOT
                --------------------------------------------------
                IF @next_appointment_id IS NULL
                BEGIN
                    SELECT 1 AS success,
                           'No Patient Left' AS message;
                    RETURN;
                END

                --------------------------------------------------
                -- START NEXT SLOT
                --------------------------------------------------
                UPDATE appointments
                SET status = 'in_progress',
                    start_time = GETDATE()
                WHERE appointment_id = @next_appointment_id;

                SELECT 1 AS success,
                       'Next slot started' AS message;
                RETURN;
            END
        END

        ----------------------------------------------------
        -- SKIP SESSION (FINAL - SLOT_ID BASED + is_next)
        --------------------------------------------------
        IF @operation = 'SKIP_SESSION'
        BEGIN
            --------------------------------------------------
            -- GET APPOINTMENT DETAILS
            --------------------------------------------------
            SELECT @booking_type = booking_type,
                   @slot_id = slot_id,
                   @current_queue = queue_number,
                   @user_type = user_type,
                   @patient_id_local = patient_id
            FROM appointments
            WHERE appointment_id = @appointment_id
                  AND doctor_id = @doctor_id;

            IF @booking_type IS NULL
            BEGIN
                SELECT 0 AS success,
                       'Invalid appointment' AS message,
                       NULL AS token;
                RETURN;
            END

            --------------------------------------------------
            -- GET TOKEN
            --------------------------------------------------
            IF @user_type = 1
            BEGIN
                SELECT @token = token
                FROM patients
                WHERE patient_id = @patient_id_local;
            END
            ELSE IF @user_type = 2
            BEGIN
                SELECT @token = p.token
                FROM family_members fm
                    JOIN patients p
                        ON fm.family_id = p.patient_id
                WHERE fm.member_id = @patient_id_local;
            END

            --------------------------------------------------
            -- QUEUE FLOW (SESSION SAFE)
            --------------------------------------------------
            IF @booking_type = 1
            BEGIN
                --------------------------------------------------
                -- CHECK QUEUE STARTED
                --------------------------------------------------
                IF NOT EXISTS
                (
                    SELECT 1
                    FROM doctor_queue
                    WHERE slot_id = @slot_id
                          AND queue_status = 1
                )
                BEGIN
                    SELECT 0 AS success,
                           'Queue not started or already stopped' AS message,
                           NULL AS token;
                    RETURN;
                END

                --------------------------------------------------
                -- SKIP CURRENT
                --------------------------------------------------
                UPDATE appointments
                SET status = 'skipped'
                WHERE appointment_id = @appointment_id
                      AND booking_type = 1
                      AND status IN ( 'booked', 'in_progress' );

                IF @@ROWCOUNT = 0
                BEGIN
                    SELECT 0 AS success,
                           'Invalid active queue appointment' AS message,
                           NULL AS token;
                    RETURN;
                END

                --------------------------------------------------
                -- IF NOT MOVE NEXT
                --------------------------------------------------
                IF @is_next = 0
                BEGIN
                    UPDATE doctor_queue
                    SET current_patient_id = NULL,
                        current_serving = NULL
                    WHERE slot_id = @slot_id;

                    SELECT 1 AS success,
                           'Patient skipped.' AS message,
                           @token AS token;
                    RETURN;
                END

                --------------------------------------------------
                -- FIND NEXT IN SAME SESSION
                --------------------------------------------------
                SELECT TOP 1
                    @next_queue = queue_number,
                    @next_patient_id = patient_id,
                    @next_appointment_id = appointment_id
                FROM appointments
                WHERE slot_id = @slot_id
                      AND booking_type = 1
                      AND status = 'booked'
                      AND queue_number > @current_queue
                ORDER BY queue_number;

                --------------------------------------------------
                -- NO NEXT
                --------------------------------------------------
                IF @next_queue IS NULL
                BEGIN
                    --IF EXISTS
                    --(
                    --    SELECT 1
                    --    FROM appointments
                    --    WHERE slot_id = @slot_id
                    --          AND booking_type = 1
                    --          AND status = 'skipped'
                    --)
                    --BEGIN
                    --    UPDATE doctor_queue
                    --    SET current_patient_id = NULL
                    --    WHERE slot_id = @slot_id;

                    --    SELECT 1 AS success,
                    --           'Patient skipped. Skipped pending.' AS message,
                    --           @token AS token;
                    --    RETURN;
                    --END

                    UPDATE doctor_queue
                    SET
                        --queue_status = 3,
                        --             stopped_at = GETDATE(),
                        current_patient_id = NULL
                    WHERE slot_id = @slot_id;

                    SELECT 1 AS success,
                           'Last Patient Skipped' AS message,
                           @token AS token;
                    RETURN;
                END

                --------------------------------------------------
                -- START NEXT
                --------------------------------------------------
                UPDATE appointments
                SET start_time = GETDATE(),
                    status = 'in_progress'
                WHERE appointment_id = @next_appointment_id
                      and slot_id = @slot_id;

                --------------------------------------------------
                -- UPDATE POINTER
                --------------------------------------------------
                UPDATE doctor_queue
                SET current_serving = @next_queue,
                    current_patient_id = @next_patient_id
                WHERE slot_id = @slot_id;

                SELECT 1 AS success,
                       'Queue patient skipped and next started' AS message,
                       @token AS token;
                RETURN;
            END

            --------------------------------------------------
            -- SLOT FLOW (SESSION SAFE)
            --------------------------------------------------
            IF @booking_type = 2
            BEGIN
                --------------------------------------------------
                -- SKIP SLOT
                --------------------------------------------------
                UPDATE appointments
                SET status = 'skipped'
                WHERE appointment_id = @appointment_id
                      AND booking_type = 2
                      AND status IN ( 'booked', 'in_progress' );

                IF @@ROWCOUNT = 0
                BEGIN
                    SELECT 0 AS success,
                           'Invalid active slot' AS message,
                           NULL AS token;
                    RETURN;
                END

                --------------------------------------------------
                -- IF NOT MOVE NEXT
                --------------------------------------------------
                IF @is_next = 0
                BEGIN
                    SELECT 1 AS success,
                           'Slot skipped.' AS message,
                           @token AS token;
                    RETURN;
                END

                --------------------------------------------------
                -- FIND NEXT SLOT (SAME SESSION)
                --------------------------------------------------
                SELECT TOP 1
                    @next_appointment_id = appointment_id
                FROM appointments
                WHERE slot_id = @slot_id
                      AND booking_type = 2
                      AND status = 'booked'
                ORDER BY start_time;

                IF @next_appointment_id IS NULL
                BEGIN
                    SELECT 1 AS success,
                           'Last Patient Skipped' AS message,
                           @token AS token;
                    RETURN;
                END

                --------------------------------------------------
                -- START NEXT SLOT
                --------------------------------------------------
                UPDATE appointments
                SET status = 'in_progress'
                WHERE appointment_id = @next_appointment_id;

                SELECT 1 AS success,
                       'Slot skipped and next started' AS message,
                       @token AS token;
                RETURN;
            END
        END --------------------------------------------------
        -- RECALL SESSION
        ----------------------------------------------------
        --IF @operation = 'RECALL_SESSION'
        --BEGIN
        --    --------------------------------------------------
        --    -- GET BOOKING TYPE
        --    --------------------------------------------------
        --    SELECT @booking_type = booking_type
        --    FROM appointments
        --    WHERE appointment_id = @appointment_id;

        --    IF @booking_type IS NULL
        --    BEGIN
        --        SELECT 0 AS success,
        --               'Invalid appointment' AS message;
        --        RETURN;
        --    END

        --    --------------------------------------------------
        --    -- QUEUE FLOW
        --    --------------------------------------------------
        --    IF @booking_type = 1
        --    BEGIN
        --        --------------------------------------------------
        --        -- CHECK QUEUE STARTED
        --        --------------------------------------------------
        --        IF NOT EXISTS
        --        (
        --            SELECT 1
        --            FROM doctor_queue
        --            WHERE doctor_id = @doctor_id
        --                  AND queue_date = CAST(GETDATE() AS DATE)
        --                  AND queue_status = 1
        --        )
        --        BEGIN
        --            SELECT 0 AS success,
        --                   'Queue not started or already stopped' AS message;
        --            RETURN;
        --        END

        --        --------------------------------------------------
        --        -- VALIDATION
        --        --------------------------------------------------
        --        IF NOT EXISTS
        --        (
        --            SELECT 1
        --            FROM appointments
        --            WHERE appointment_id = @appointment_id
        --                  AND booking_type = 1
        --                  AND status = 'skipped'
        --        )
        --        BEGIN
        --            SELECT 0 AS success,
        --                   'Only skipped queue patient can be recalled' AS message;
        --            RETURN;
        --        END

        --        --------------------------------------------------
        --        -- RECALL (START SESSION AGAIN)
        --        --------------------------------------------------
        --        UPDATE appointments
        --        SET start_time = GETDATE(),
        --            status = 'in_progress'
        --        WHERE appointment_id = @appointment_id;

        --        --------------------------------------------------
        --        -- UPDATE POINTER
        --        --------------------------------------------------
        --        UPDATE doctor_queue
        --        SET current_serving =
        --            (
        --                SELECT queue_number
        --                FROM appointments
        --                WHERE appointment_id = @appointment_id
        --            ),
        --            current_patient_id =
        --            (
        --                SELECT patient_id FROM appointments WHERE appointment_id = @appointment_id
        --            )
        --        WHERE doctor_id = @doctor_id
        --              AND queue_date = CAST(GETDATE() AS DATE);

        --        SELECT 1 AS success,
        --               'Queue patient recalled and started' AS message;
        --        RETURN;
        --    END

        --    --------------------------------------------------
        --    -- SLOT FLOW
        --    --------------------------------------------------
        --    IF @booking_type = 2
        --    BEGIN
        --        --------------------------------------------------
        --        -- VALIDATION
        --        --------------------------------------------------
        --        IF NOT EXISTS
        --        (
        --            SELECT 1
        --            FROM appointments
        --            WHERE appointment_id = @appointment_id
        --                  AND booking_type = 2
        --                  AND status = 'skipped'
        --        )
        --        BEGIN
        --            SELECT 0 AS success,
        --                   'Only skipped slot can be recalled' AS message;
        --            RETURN;
        --        END

        --        --------------------------------------------------
        --        -- RECALL SLOT
        --        --------------------------------------------------
        --        UPDATE appointments
        --        SET status = 'in_progress'
        --        WHERE appointment_id = @appointment_id;

        --        SELECT 1 AS success,
        --               'Slot recalled and started' AS message;
        --        RETURN;
        --    END
        --END

        ----------------------------------------------------
        ---- START SESSION
        ----------------------------------------------------
        --IF @operation = 'START_SESSION'
        --BEGIN
        --    --------------------------------------------------
        --    -- GET APPOINTMENT
        --    --------------------------------------------------
        --    SELECT @ss_queue_number = queue_number,
        --           @ss_patient_id = patient_id,
        --           @booking_mode = booking_type,
        --           @queue_id = queue_id
        --    FROM appointments
        --    WHERE appointment_id = @appointment_id;

        --    IF @booking_mode IS NULL
        --    BEGIN
        --        SELECT 0 AS success,
        --               'Invalid appointment' AS message;
        --        RETURN;
        --    END

        --    --------------------------------------------------
        --    -- QUEUE FLOW
        --    --------------------------------------------------
        --    IF @booking_mode = 1
        --    BEGIN
        --        --------------------------------------------------
        --        -- CHECK QUEUE STARTED
        --        --------------------------------------------------
        --        IF NOT EXISTS
        --        (
        --            SELECT 1
        --            FROM doctor_queue
        --            WHERE doctor_id = @doctor_id
        --                  AND queue_date = CAST(GETDATE() AS DATE)
        --                  AND queue_status = 1
        --        )
        --        BEGIN
        --            SELECT 0 AS success,
        --                   'Queue not started or already stopped' AS message;
        --            RETURN;
        --        END

        --        --------------------------------------------------
        --        -- VALIDATION
        --        --------------------------------------------------
        --        IF NOT EXISTS
        --        (
        --            SELECT 1
        --            FROM appointments
        --            WHERE appointment_id = @appointment_id
        --                  AND booking_type = 1
        --                  AND status IN ( 'booked', 'skipped' )
        --        )
        --        BEGIN
        --            SELECT 0 AS success,
        --                   'Only booked/skipped queue can be started' AS message;
        --            RETURN;
        --        END

        --        --------------------------------------------------
        --        -- RESET ANY ACTIVE SESSION
        --        --------------------------------------------------
        --        UPDATE appointments
        --        SET status = 'booked'
        --        WHERE doctor_id = @doctor_id
        --              AND appointment_date = CAST(GETDATE() AS DATE)
        --              AND booking_type = 1
        --              AND status = 'in_progress';

        --        --------------------------------------------------
        --        -- START CURRENT (BY ID)
        --        --------------------------------------------------
        --        UPDATE appointments
        --        SET start_time = GETDATE(),
        --            status = 'in_progress'
        --        WHERE appointment_id = @appointment_id;

        --        --------------------------------------------------
        --        -- UPDATE POINTER
        --        --------------------------------------------------
        --        UPDATE doctor_queue
        --        SET current_serving = @ss_queue_number,
        --            current_patient_id = @ss_patient_id
        --        WHERE doctor_id = @doctor_id
        --              and queue_id = @queue_id
        --              AND queue_date = CAST(GETDATE() AS DATE);

        --        SELECT 1 AS success,
        --               'Queue session started' AS message;
        --        RETURN;
        --    END

        --    --------------------------------------------------
        --    -- SLOT FLOW
        --    --------------------------------------------------
        --    IF @booking_mode = 2
        --    BEGIN
        --        --------------------------------------------------
        --        -- VALIDATION
        --        --------------------------------------------------
        --        IF NOT EXISTS
        --        (
        --            SELECT 1
        --            FROM appointments
        --            WHERE appointment_id = @appointment_id
        --                  AND booking_type = 2
        --                  AND status IN ( 'booked', 'skipped' )
        --        )
        --        BEGIN
        --            SELECT 0 AS success,
        --                   'Only booked/skipped slot can be started' AS message;
        --            RETURN;
        --        END

        --        --------------------------------------------------
        --        -- RESET CURRENT ACTIVE SLOT
        --        --------------------------------------------------
        --        UPDATE appointments
        --        SET status = 'booked'
        --        WHERE doctor_id = @doctor_id
        --              AND appointment_date = CAST(GETDATE() AS DATE)
        --              AND booking_type = 2
        --              AND status = 'in_progress';

        --        --------------------------------------------------
        --        -- START SLOT (BY ID)
        --        --------------------------------------------------
        --        UPDATE appointments
        --        SET status = 'in_progress'
        --        WHERE appointment_id = @appointment_id;

        --        SELECT 1 AS success,
        --               'Slot session started' AS message;
        --        RETURN;
        --    END
        --END

		        --------------------------------------------------
        -- RECALL SESSION
        --------------------------------------------------
        IF @operation = 'RECALL_SESSION'
        BEGIN
            --------------------------------------------------
            -- GET BOOKING TYPE
            --------------------------------------------------
            SELECT @booking_type = booking_type
            FROM appointments
            WHERE appointment_id = @appointment_id;

            IF @booking_type IS NULL
            BEGIN
                SELECT 0 AS success,
                       'Invalid appointment' AS message;
                RETURN;
            END

            --------------------------------------------------
            -- QUEUE FLOW
            --------------------------------------------------
            IF @booking_type = 1
            BEGIN
                --------------------------------------------------
                -- CHECK QUEUE STARTED
                --------------------------------------------------
                IF NOT EXISTS
                (
                    SELECT 1
                    FROM doctor_queue
                    WHERE doctor_id = @doctor_id
                          AND queue_date = CAST(GETDATE() AS DATE)
                          AND queue_status = 1
                )
                BEGIN
                    SELECT 0 AS success,
                           'Queue not started or already stopped' AS message;
                    RETURN;
                END

                --------------------------------------------------
                -- VALIDATION
                --------------------------------------------------
                IF NOT EXISTS
                (
                    SELECT 1
                    FROM appointments
                    WHERE appointment_id = @appointment_id
                          AND booking_type = 1
                          AND status = 'skipped'
                )
                BEGIN
                    SELECT 0 AS success,
                           'Only skipped queue patient can be recalled' AS message;
                    RETURN;
                END

                --------------------------------------------------
                -- 🔥 BLOCK: secound patient  in_progress 
                --    in_progress.  current complete .
                --------------------------------------------------
                IF EXISTS
                (
                    SELECT 1
                    FROM appointments
                    WHERE queue_id =
                          (SELECT queue_id FROM appointments
                           WHERE appointment_id = @appointment_id)
                          AND booking_type = 1
                          AND status = 'in_progress'
                )
                BEGIN
                    SELECT 0 AS success,
                           'Please complete the current in-progress patient first' AS message;
                    RETURN;
                END

                --------------------------------------------------
                -- RECALL (START SESSION AGAIN)
                --------------------------------------------------
                UPDATE appointments
                SET start_time = GETDATE(),
                    status = 'in_progress'
                WHERE appointment_id = @appointment_id;

                --------------------------------------------------
                -- UPDATE POINTER
                --------------------------------------------------
                UPDATE doctor_queue
                SET current_serving =
                    (
                        SELECT queue_number
                        FROM appointments
                        WHERE appointment_id = @appointment_id
                    ),
                    current_patient_id =
                    (
                        SELECT patient_id FROM appointments WHERE appointment_id = @appointment_id
                    )
                WHERE doctor_id = @doctor_id
                      AND queue_date = CAST(GETDATE() AS DATE);

                SELECT 1 AS success,
                       'Queue patient recalled and started' AS message;
                RETURN;
            END

            --------------------------------------------------
            -- SLOT FLOW
            --------------------------------------------------
            IF @booking_type = 2
            BEGIN
                --------------------------------------------------
                -- VALIDATION
                --------------------------------------------------
                IF NOT EXISTS
                (
                    SELECT 1
                    FROM appointments
                    WHERE appointment_id = @appointment_id
                          AND booking_type = 2
                          AND status = 'skipped'
                )
                BEGIN
                    SELECT 0 AS success,
                           'Only skipped slot can be recalled' AS message;
                    RETURN;
                END

                --------------------------------------------------
                -- 🔥 BLOCK: secound slot patient  in_progress 
                --------------------------------------------------
                IF EXISTS
                (
                    SELECT 1
                    FROM appointments
                    WHERE doctor_id =
                          (SELECT doctor_id FROM appointments
                           WHERE appointment_id = @appointment_id)
                          AND appointment_date = CAST(GETDATE() AS DATE)
                          AND booking_type = 2
                          AND status = 'in_progress'
                )
                BEGIN
                    SELECT 0 AS success,
                           'Please complete the current in-progress patient first' AS message;
                    RETURN;
                END

                --------------------------------------------------
                -- RECALL SLOT
                --------------------------------------------------
                UPDATE appointments
                SET status = 'in_progress'
                WHERE appointment_id = @appointment_id;

                SELECT 1 AS success,
                       'Slot recalled and started' AS message;
                RETURN;
            END
        END

		        --------------------------------------------------
        -- START SESSION
        --------------------------------------------------
        IF @operation = 'START_SESSION'
        BEGIN
            --------------------------------------------------
            -- GET APPOINTMENT
            --------------------------------------------------
            SELECT @ss_queue_number = queue_number,
                   @ss_patient_id = patient_id,
                   @booking_mode = booking_type,
                   @queue_id = queue_id
            FROM appointments
            WHERE appointment_id = @appointment_id;

            IF @booking_mode IS NULL
            BEGIN
                SELECT 0 AS success,
                       'Invalid appointment' AS message;
                RETURN;
            END

            --------------------------------------------------
            -- QUEUE FLOW
            --------------------------------------------------
            IF @booking_mode = 1
            BEGIN
                --------------------------------------------------
                -- CHECK QUEUE STARTED
                --------------------------------------------------
                IF NOT EXISTS
                (
                    SELECT 1
                    FROM doctor_queue
                    WHERE doctor_id = @doctor_id
                          AND queue_date = CAST(GETDATE() AS DATE)
                          AND queue_status = 1
                )
                BEGIN
                    SELECT 0 AS success,
                           'Queue not started or already stopped' AS message;
                    RETURN;
                END

                --------------------------------------------------
                -- VALIDATION
                --------------------------------------------------
                IF NOT EXISTS
                (
                    SELECT 1
                    FROM appointments
                    WHERE appointment_id = @appointment_id
                          AND booking_type = 1
                          AND status IN ( 'booked', 'skipped' )
                )
                BEGIN
                    SELECT 0 AS success,
                           'Only booked/skipped queue can be started' AS message;
                    RETURN;
                END

                --------------------------------------------------
                -- 🔥 BLOCK: secound patient  in_progress 
                --   ( 'RESET ANY ACTIVE SESSION' auto-bump )
                --------------------------------------------------
                IF EXISTS
                (
                    SELECT 1
                    FROM appointments
                    WHERE queue_id = @queue_id
                          AND booking_type = 1
                          AND status = 'in_progress'
                )
                BEGIN
                    SELECT 0 AS success,
                           'Please complete the current in-progress patient first' AS message;
                    RETURN;
                END

                --------------------------------------------------
                -- START CURRENT (BY ID)
                --------------------------------------------------
                UPDATE appointments
                SET start_time = GETDATE(),
                    status = 'in_progress'
                WHERE appointment_id = @appointment_id;

                --------------------------------------------------
                -- UPDATE POINTER
                --------------------------------------------------
                UPDATE doctor_queue
                SET current_serving = @ss_queue_number,
                    current_patient_id = @ss_patient_id
                WHERE doctor_id = @doctor_id
                      AND queue_id = @queue_id
                      AND queue_date = CAST(GETDATE() AS DATE);

                SELECT 1 AS success,
                       'Queue session started' AS message;
                RETURN;
            END

            --------------------------------------------------
            -- SLOT FLOW
            --------------------------------------------------
            IF @booking_mode = 2
            BEGIN
                --------------------------------------------------
                -- VALIDATION
                --------------------------------------------------
                IF NOT EXISTS
                (
                    SELECT 1
                    FROM appointments
                    WHERE appointment_id = @appointment_id
                          AND booking_type = 2
                          AND status IN ( 'booked', 'skipped' )
                )
                BEGIN
                    SELECT 0 AS success,
                           'Only booked/skipped slot can be started' AS message;
                    RETURN;
                END

                --------------------------------------------------
                -- 🔥 BLOCK: secound slot patient  in_progress 
                --   ( 'RESET CURRENT ACTIVE SLOT' auto-bump )
                --------------------------------------------------
                IF EXISTS
                (
                    SELECT 1
                    FROM appointments
                    WHERE doctor_id = @doctor_id
                          AND appointment_date = CAST(GETDATE() AS DATE)
                          AND booking_type = 2
                          AND status = 'in_progress'
                )
                BEGIN
                    SELECT 0 AS success,
                           'Please complete the current in-progress patient first' AS message;
                    RETURN;
                END

                --------------------------------------------------
                -- START SLOT (BY ID)
                --------------------------------------------------
                UPDATE appointments
                SET status = 'in_progress'
                WHERE appointment_id = @appointment_id;

                SELECT 1 AS success,
                       'Slot session started' AS message;
                RETURN;
            END
        END


        --------------------------------------------------
        -- END SESSION
        --------------------------------------------------
        IF @operation = 'END_SESSION'
        BEGIN
            --------------------------------------------------
            -- GET BOOKING TYPE
            --------------------------------------------------
            SELECT @booking_type = booking_type,
                   @queue_id = queue_id
            FROM appointments
            WHERE appointment_id = @appointment_id;

            IF @booking_type IS NULL
            BEGIN
                SELECT 0 AS success,
                       'Invalid appointment' AS message;
                RETURN;
            END

            --------------------------------------------------
            -- QUEUE FLOW
            --------------------------------------------------
            IF @booking_type = 1
            BEGIN
                --------------------------------------------------
                -- CHECK QUEUE STARTED
                --------------------------------------------------
                IF NOT EXISTS
                (
                    SELECT 1
                    FROM doctor_queue
                    WHERE doctor_id = @doctor_id
                          AND queue_date = CAST(GETDATE() AS DATE)
                          AND queue_status = 1
                          and queue_id = @queue_id
                )
                BEGIN
                    SELECT 0 AS success,
                           'Queue not started or already stopped' AS message,
                           NULL AS token;
                    RETURN;
                END

                --------------------------------------------------
                -- VALIDATION
                --------------------------------------------------
                IF NOT EXISTS
                (
                    SELECT 1
                    FROM appointments
                    WHERE appointment_id = @appointment_id
                          AND status = 'in_progress'
                )
                BEGIN
                    SELECT 0 AS success,
                           'Only active queue session can be ended' AS message,
                           NULL AS token;
                    RETURN;
                END

                --------------------------------------------------
                -- END CURRENT SESSION
                --------------------------------------------------
                UPDATE appointments
                SET end_time = GETDATE(),
                    status = 'completed'
                WHERE appointment_id = @appointment_id;

                --------------------------------------------------
                -- UPDATE COMPLETED COUNT
                --------------------------------------------------
                UPDATE doctor_queue
                SET completed_count = ISNULL(completed_count, 0) + 1
                WHERE doctor_id = @doctor_id
                      and queue_id = @queue_id
                      AND queue_date = CAST(GETDATE() AS DATE);

                --------------------------------------------------
                -- AUTO STOP CHECK
                --------------------------------------------------
                IF NOT EXISTS
                (
                    SELECT 1
                    FROM appointments
                    WHERE doctor_id = @doctor_id
                          AND appointment_date = CAST(GETDATE() AS DATE)
                          AND booking_type = 1
                          AND status IN ( 'booked', 'skipped' )
                )
                BEGIN
                    --UPDATE doctor_queue
                    --SET queue_status = 3,
                    --    stopped_at = GETDATE(),
                    --    current_patient_id = NULL
                    --WHERE doctor_id = @doctor_id
                    --      AND queue_date = CAST(GETDATE() AS DATE);
					   UPDATE doctor_queue
    SET current_patient_id = NULL   -- ✅  pointer clear
    WHERE doctor_id = @doctor_id
          AND queue_id = @queue_id  -- ✅ specific session
          AND queue_date = CAST(GETDATE() AS DATE);

                    SELECT 1 AS success,
                           'Queue completed' AS message,
                           NULL AS token;
                    RETURN;
                END

                --------------------------------------------------
                -- 🔥 RETURN ONLY 3rd NEXT PATIENT TOKEN
                --------------------------------------------------
                SELECT 1 AS success,
                       'Queue session ended' AS message,
                       NULL AS token,
                       NULL AS appointment_id,
                       NULL AS queue_number
                UNION ALL
                SELECT NULL,
                       NULL,
                       CASE
                           WHEN a.user_type = 1 THEN
                               p.token
                           WHEN a.user_type = 2 THEN
                               p2.token
                       END AS token,
                       a.appointment_id,
                       a.queue_number
                FROM
                (
                    SELECT *,
                           ROW_NUMBER() OVER (ORDER BY queue_number) AS rn
                    FROM appointments
                    WHERE doctor_id = @doctor_id
                          AND appointment_date = CAST(GETDATE() AS DATE)
                          AND booking_type = 1
                          AND status = 'booked'
                ) a
                    LEFT JOIN patients p
                        ON a.user_type = 1
                           AND p.patient_id = a.patient_id
                    LEFT JOIN family_members fm
                        ON a.user_type = 2
                           AND fm.member_id = a.patient_id
                    LEFT JOIN patients p2
                        ON fm.family_id = p2.patient_id
                WHERE a.rn = 3;

                RETURN;
            END

            --------------------------------------------------
            -- SLOT FLOW
            --------------------------------------------------
            IF @booking_type = 2
            BEGIN
                --------------------------------------------------
                -- VALIDATION
                --------------------------------------------------
                IF NOT EXISTS
                (
                    SELECT 1
                    FROM appointments
                    WHERE appointment_id = @appointment_id
                          AND booking_type = 2
                          AND status = 'in_progress'
                )
                BEGIN
                    SELECT 0 AS success,
                           'Only active slot can be ended' AS message;
                    RETURN;
                END

                --------------------------------------------------
                -- END SLOT (BY ID)
                --------------------------------------------------
                UPDATE appointments
                SET status = 'completed'
                WHERE appointment_id = @appointment_id;

                --------------------------------------------------
                -- GET CURRENT CONSULTATION TIME
                --------------------------------------------------
                SELECT @consult_time = DATEDIFF(MINUTE, start_time, end_time)
                FROM appointments
                WHERE appointment_id = @appointment_id;

                IF @consult_time IS NOT NULL
                BEGIN
                    SET @hour = DATEPART(HOUR, GETDATE());

                    --------------------------------------------------
                    -- UPSERT PROFILE
                    --------------------------------------------------
                    IF NOT EXISTS (SELECT 1 FROM doctor_timing WHERE doctor_id = @doctor_id AND (@clinic_id IS NULL OR clinic_id = @clinic_id))
                    BEGIN
                        INSERT INTO doctor_timing
                        (
                            doctor_id,
                            avg_consultation_time,
                            morning_avg,
                            afternoon_avg,
                            evening_avg,
                            total_completed,
                            last_updated,
                            clinic_id
                        )
                        VALUES
                        (@doctor_id, @consult_time, NULL, NULL, NULL, 1, GETDATE(), @clinic_id);
                    END
                    ELSE
                    BEGIN
                        --------------------------------------------------
                        -- UPDATE GLOBAL AVG
                        --------------------------------------------------
                        UPDATE doctor_timing
                        SET avg_consultation_time = (avg_consultation_time * total_completed + @consult_time)
                                                    / (total_completed + 1),
                            total_completed = total_completed + 1,
                            last_updated = GETDATE()
                        WHERE doctor_id = @doctor_id AND (@clinic_id IS NULL OR clinic_id = @clinic_id);

                        --------------------------------------------------
                        -- UPDATE TIME SEGMENT AVG
                        --------------------------------------------------
                        IF @hour < 12
                        BEGIN
                            UPDATE doctor_timing
                            SET morning_avg = ISNULL((morning_avg + @consult_time) / 2, @consult_time)
                            WHERE doctor_id = @doctor_id  AND (@clinic_id IS NULL OR clinic_id = @clinic_id);
                        END
                        ELSE IF @hour < 17
                        BEGIN
                            UPDATE doctor_timing
                            SET afternoon_avg = ISNULL((afternoon_avg + @consult_time) / 2, @consult_time)
                            WHERE doctor_id = @doctor_id  AND (@clinic_id IS NULL OR clinic_id = @clinic_id);
                        END
                        ELSE
                        BEGIN
                            UPDATE doctor_timing
                            SET evening_avg = ISNULL((evening_avg + @consult_time) / 2, @consult_time)
                            WHERE doctor_id = @doctor_id  AND (@clinic_id IS NULL OR clinic_id = @clinic_id);
                        END
                    END
                END

                SELECT 1 AS success,
                       'Slot completed' AS message;
                RETURN;
            END
        END

        --------------------------------------------------
        -- RESCHEDULE APPOINTMENT
        --------------------------------------------------
        IF @operation = 'RESCHEDULE_APPOINTMENT'
        BEGIN
            --------------------------------------------------
            -- VALIDATE APPOINTMENT
            --------------------------------------------------
            SELECT @old_booking_type = booking_type,
                   @old_status = status
            FROM appointments
            WHERE appointment_id = @appointment_id;

            IF @old_booking_type IS NULL
            BEGIN
                SELECT 0 AS success,
                       'Invalid appointment' AS message;
                RETURN;
            END

            --------------------------------------------------
            -- BLOCK QUEUE RESCHEDULE
            --------------------------------------------------
            IF @old_booking_type = 1
            BEGIN
                SELECT 0 AS success,
                       'Queue appointments cannot be rescheduled' AS message;
                RETURN;
            END

            --------------------------------------------------
            -- BLOCK INVALID STATUS
            --------------------------------------------------
            IF @old_status IN ( 'completed', 'cancelled' )
            BEGIN
                SELECT 0 AS success,
                       'Cannot reschedule completed/cancelled appointment' AS message;
                RETURN;
            END

            --------------------------------------------------
            -- VALIDATE SLOT AVAILABILITY
            --------------------------------------------------
            SELECT @slot_duration = ts.slot_duration,
                   @slot_start = ts.start_time,
                   @slot_end = ts.end_time
            FROM doctor_time_slots ts
                JOIN doctor_availability da
                    ON ts.availability_id = da.availability_id
            WHERE da.doctor_id = @doctor_id
                  AND da.is_enabled = 1
                  AND da.day_of_week = DATENAME(WEEKDAY, @appointment_date)
                  AND ts.booking_mode = 2
                  AND @start_time >= ts.start_time
                  AND @start_time < ts.end_time;

            IF @slot_duration IS NULL
            BEGIN
                SELECT 0 AS success,
                       'Invalid slot' AS message;
                RETURN;
            END

            --------------------------------------------------
            -- VALIDATE SLOT INTERVAL
            --------------------------------------------------
            SET @minutes = DATEDIFF(MINUTE, @slot_start, @start_time);

            IF @minutes % @slot_duration <> 0
            BEGIN
                SELECT 0 AS success,
                       'Invalid slot interval' AS message;
                RETURN;
            END

            --------------------------------------------------
            -- PREVENT DOUBLE BOOKING
            --------------------------------------------------
            IF EXISTS
            (
                SELECT 1
                FROM appointments
                WHERE doctor_id = @doctor_id
                      AND appointment_date = @appointment_date
                      AND start_time = @start_time
                      AND appointment_id <> @appointment_id
                      AND status = 'booked'
            )
            BEGIN
                SELECT 0 AS success,
                       'Slot already booked' AS message;
                RETURN;
            END

            --------------------------------------------------
            -- UPDATE APPOINTMENT
            --------------------------------------------------
            UPDATE appointments
            SET appointment_date = @appointment_date,
                symptoms = @symptoms,
                start_time = @start_time,
                end_time = DATEADD(MINUTE, @slot_duration, @start_time),
                status = 'booked'
            WHERE appointment_id = @appointment_id;

            SELECT 1 AS success,
                   'Appointment rescheduled successfully' AS message;
        END

        --------------------------------------------------
        -- PATIENT LIST
        --------------------------------------------------
--------------------------------------------------
-- PATIENT APPOINTMENT LIST (WITH SESSION START TIME)
--------------------------------------------------
IF @operation = 'patientAppointmentList'
BEGIN
    SELECT 
        vw.*,
        dq.queue_status,

        --------------------------------------------------
        -- 🔥 SESSION START TIME (FROM SLOT)
        --------------------------------------------------
        FORMAT(ts.start_time, 'hh:mm tt') AS session_start_time

    FROM dbo.appointment_booking_vw vw

    --------------------------------------------------
    -- 🔥 QUEUE JOIN (SESSION BASED)
    --------------------------------------------------
    --LEFT JOIN doctor_queue dq
    --    ON dq.doctor_id = vw.doctor_id
    --    AND dq.queue_date = CAST(GETDATE() AS DATE)
    --    AND dq.slot_id = vw.slot_id
	LEFT JOIN doctor_queue dq
    ON dq.doctor_id = vw.doctor_id
    AND dq.queue_date = CAST(GETDATE() AS DATE)
    AND dq.slot_id = vw.slot_id
    AND (@clinic_id IS NULL OR dq.clinic_id = @clinic_id)  -- ADD


    --------------------------------------------------
    -- 🔥 SESSION TIME JOIN (USING slot_id)
    --------------------------------------------------
    LEFT JOIN doctor_time_slots ts
        ON ts.slot_id = vw.slot_id
    LEFT JOIN doctor_availability da
        ON da.availability_id = ts.availability_id

    WHERE vw.doctor_id = @doctor_id
          AND (@clinic_id IS NULL OR vw.clinic_id = @clinic_id)

    --------------------------------------------------
    -- ORDERING
    --------------------------------------------------
    ORDER BY 
        vw.appointment_date,
        CASE 
            WHEN vw.queue_number IS NULL THEN vw.start_time
        END,
        CASE 
            WHEN vw.queue_number IS NOT NULL THEN vw.queue_number
        END;
END
        --------------------------------------------------
        -- PATIENT'S APPOINTMENTS
        --------------------------------------------------
        IF @operation = 'patient_Appointments'
        BEGIN
            SELECT *
            FROM dbo.appointment_booking_vw
            WHERE family_id = @family_id
            order by queue_number asc;
        END


        -- QUEUE ESTIMATE SMART (FINAL WITH total_queue + current_serving)
        --------------------------------------------------
        IF @operation = 'QUEUE_ESTIMATE_SMART'
        BEGIN
            DECLARE @base_time DATETIME;
            DECLARE @is_queue_started BIT = 0;
            DECLARE @is_my_turn BIT = 0;
            DECLARE @queue_status INT;
            DECLARE @current_slot_start TIME;
  
DECLARE @my_status VARCHAR(30);  


            --------------------------------------------------
            -- VALIDATE APPOINTMENT + GET queue_id + slot_id
            --------------------------------------------------
            --SELECT @my_queue = queue_number,
            --       @queue_id = queue_id,
            --       @slot_id = slot_id
            --FROM appointments
            --WHERE appointment_id = @appointment_id
            --      AND booking_type = 1;


			-- VALIDATE APPOINTMENT + GET queue_id + slot_id
SELECT @my_queue = queue_number,
       @queue_id = queue_id,
       @slot_id = slot_id,
       @my_status = status         
FROM appointments
WHERE appointment_id = @appointment_id
      AND booking_type = 1;


            IF @my_queue IS NULL
               OR @queue_id IS NULL
               OR @slot_id IS NULL
            BEGIN
                SELECT 0 AS success,
                       'Invalid queue appointment' AS message;
                RETURN;
            END

            --------------------------------------------------
            -- GET CURRENT SESSION START TIME
            --------------------------------------------------
            SELECT @current_slot_start = start_time
            FROM doctor_time_slots
            WHERE slot_id = @slot_id;

            --------------------------------------------------
            -- 🔥 GET QUEUE INFO
            ----------------------------------------------------
            --SELECT @queue_status = queue_status,
            --       @current_serving = ISNULL(current_serving, 0),
            --       @total_queue = ISNULL(total_queue, 0),
            --       @is_queue_started = CASE
            --                               WHEN queue_status = 1 THEN
            --                                   1
            --                               ELSE
            --                                   0
            --                           END
            --FROM doctor_queue
            --WHERE queue_id = @queue_id;
			SELECT @queue_status = queue_status,
       @is_queue_started = CASE
                               WHEN queue_status = 1 THEN 1
                               ELSE 0
                           END
FROM doctor_queue
WHERE queue_id = @queue_id;
SELECT @current_serving = ISNULL(MAX(a.queue_number), 0)
FROM appointments a
WHERE a.queue_id = @queue_id
  AND a.booking_type = 1
  AND a.status IN ('completed', 'in_progress', 'cancelled', 'cancled', 'skipped')
  AND NOT EXISTS (
        SELECT 1 FROM appointments b
        WHERE b.queue_id = a.queue_id
          AND b.booking_type = 1
          AND b.queue_number < a.queue_number
          AND b.status NOT IN ('completed', 'cancelled', 'cancled', 'skipped')
      );


SELECT @total_queue = COUNT(*)
FROM appointments
WHERE queue_id = @queue_id
  AND booking_type = 1;


--SELECT @current_serving = ISNULL(MAX(queue_number), 0)
--FROM appointments
--WHERE queue_id = @queue_id
--  AND booking_type = 1
--  AND status IN ('completed', 'in_progress');

--SELECT @total_queue = COUNT(*)
--FROM appointments
--WHERE queue_id = @queue_id
--  AND booking_type = 1
--  AND LOWER(status) NOT IN ('cancelled', 'cancled');


            IF @is_queue_started IS NULL
                SET @is_queue_started = 0;

            --------------------------------------------------
            -- TIME-BASED AVG
            --------------------------------------------------
            SET @hour = DATEPART(HOUR, GETDATE());

            SELECT @base_avg = CASE
                                   WHEN @hour < 12 THEN
                                       morning_avg
                                   WHEN @hour < 17 THEN
                                       afternoon_avg
                                   ELSE
                                       evening_avg
                               END
            FROM doctor_timing
            WHERE doctor_id = @doctor_id AND (@clinic_id IS NULL OR clinic_id = @clinic_id);

            IF @base_avg IS NULL
            BEGIN
                SELECT @base_avg = avg_consultation_time
                FROM doctor_queue
                WHERE queue_id = @queue_id;
            END

            IF @base_avg IS NULL
                SET @base_avg = 7;

            --------------------------------------------------
            -- QUEUE SIZE (CURRENT SESSION)
            --------------------------------------------------
            SELECT @queue_size = COUNT(*)
            FROM appointments
            WHERE queue_id = @queue_id
                  AND booking_type = 1
                  AND status IN ( 'booked', 'in_progress' );

            --------------------------------------------------
            -- AVG CONSULT TIME (Practo-style)
            --   measured avg, clamped to a sane 3–30 min band.
            --   NO artificial queue-size scaling.
            --------------------------------------------------
            IF @base_avg < 3  SET @base_avg = 3;
            IF @base_avg > 30 SET @base_avg = 30;

            SET @adaptive_avg = @base_avg;

            --------------------------------------------------
            -- PATIENTS AHEAD (CURRENT SESSION)
            --------------------------------------------------
            SELECT @patients_ahead = COUNT(*)
            FROM appointments
            WHERE queue_id = @queue_id
                  AND booking_type = 1
                  AND status IN ( 'booked', 'in_progress' )
                  AND queue_number < @my_queue;

            --------------------------------------------------
            -- 🔥 PREVIOUS SESSIONS LOAD
            --------------------------------------------------
            DECLARE @previous_load INT = 0;

            --SELECT @previous_load = COUNT(*)
            --FROM appointments a
            --    JOIN doctor_queue dq2
            --        ON a.queue_id = dq2.queue_id
            --    JOIN doctor_time_slots ts2
            --        ON dq2.slot_id = ts2.slot_id
            --WHERE dq2.doctor_id = @doctor_id
            --      AND dq2.queue_date = CAST(GETDATE() AS DATE)
            --      AND a.status IN ( 'booked', 'in_progress' )
            --      AND ts2.start_time < @current_slot_start;
			SELECT @previous_load = COUNT(*)
FROM appointments a
    JOIN doctor_queue dq2 ON a.queue_id = dq2.queue_id
    JOIN doctor_time_slots ts2 ON dq2.slot_id = ts2.slot_id
WHERE dq2.doctor_id = @doctor_id
      AND dq2.clinic_id = @clinic_id        -- ← ADD THIS
      AND dq2.queue_date = CAST(GETDATE() AS DATE)
      AND a.status IN ('booked', 'in_progress')
      AND ts2.start_time < @current_slot_start;


            --------------------------------------------------
            -- WAITING (NOT-YET-STARTED) PATIENTS AHEAD IN THIS SESSION
            --------------------------------------------------
            DECLARE @waiting_ahead     INT = 0;
            DECLARE @inprogress_start  DATETIME;
            DECLARE @remaining_current FLOAT = 0;

            SELECT @waiting_ahead = COUNT(*)
            FROM appointments
            WHERE queue_id = @queue_id
                  AND booking_type = 1
                  AND status = 'booked'
                  AND queue_number < @my_queue;

            --------------------------------------------------
            -- 🔥 CURRENT IN-PROGRESS PATIENT → only the REMAINING time counts
            --   (Practo/Qminder style: don't charge a full slot for someone
            --    the doctor is already partway through consulting.)
            --------------------------------------------------
            SELECT TOP 1 @inprogress_start = start_time
            FROM appointments
            WHERE queue_id = @queue_id
                  AND booking_type = 1
                  AND status = 'in_progress'
                  AND queue_number < @my_queue
            ORDER BY queue_number DESC;

            IF @inprogress_start IS NOT NULL
            BEGIN
                DECLARE @elapsed_current INT =
                    DATEDIFF(MINUTE, @inprogress_start, GETDATE());

                SET @remaining_current = @adaptive_avg - @elapsed_current;

                -- clamp: never more than a full slot, never below 1 min
                IF @remaining_current > @adaptive_avg
                    SET @remaining_current = @adaptive_avg;
                IF @remaining_current < 1
                    SET @remaining_current = 1;
            END

            --------------------------------------------------
            -- FINAL ESTIMATION
            --   earlier sessions + waiting-ahead → full avg each
            --   current in-progress patient      → remaining time only
            --------------------------------------------------
            SET @estimated_time =
                ((@previous_load + @waiting_ahead) * @adaptive_avg)
                + @remaining_current;

            --------------------------------------------------
            -- START TIME (REAL OR SCHEDULE)
            --------------------------------------------------
            SELECT TOP 1
                @started_at = start_time
            FROM appointments
            WHERE queue_id = @queue_id
                  AND booking_type = 1
                  AND start_time IS NOT NULL
            ORDER BY start_time;

            IF @started_at IS NULL
            BEGIN
                SET @started_at
                    = DATETIMEFROMPARTS(
                                           YEAR(GETDATE()),
                                           MONTH(GETDATE()),
                                           DAY(GETDATE()),
                                           DATEPART(HOUR, @current_slot_start),
                                           DATEPART(MINUTE, @current_slot_start),
                                           0,
                                           0
                                       );
            END

            IF @started_at IS NULL
            BEGIN
                SELECT 0 AS success,
                       'Doctor not available today' AS message;
                RETURN;
            END

            --------------------------------------------------
            -- IMMEDIATE TURN LOGIC
            --------------------------------------------------
            --IF @patients_ahead = 0
            --   AND @previous_load = 0
            --   AND @is_queue_started = 1
            --BEGIN
            --    SET @estimated_time = 0;
            --    SET @arrival_time = GETDATE();
            --    SET @is_my_turn = 1;
            --END

IF (
        @current_serving = @my_queue                          
        OR (@patients_ahead = 0 AND @previous_load = 0)        
   )
   AND @is_queue_started = 1
   AND @my_status IN ('booked', 'in_progress')               
BEGIN
    SET @estimated_time = 0;
    SET @arrival_time = GETDATE();
    SET @is_my_turn = 1;
END


            ELSE
            BEGIN
                -- Scheduled session start as today's datetime
                SET @slot_start_dt =
                    DATETIMEFROMPARTS(
                        YEAR(GETDATE()), MONTH(GETDATE()), DAY(GETDATE()),
                        DATEPART(HOUR, @current_slot_start),
                        DATEPART(MINUTE, @current_slot_start), 0, 0);

                -- Queue NOT started → nothing happens before the scheduled
                --   start, so measure from start time, never from 'now'.
                -- Queue running / doctor late → measure from now.
                IF @is_queue_started = 0 AND @slot_start_dt > GETDATE()
                    SET @base_time = @slot_start_dt;
                ELSE
                    SET @base_time = GETDATE();

                SET @arrival_time = DATEADD(MINUTE, CEILING(@estimated_time), @base_time);

                -- Never in the past
                IF @arrival_time < GETDATE()
                    SET @arrival_time = GETDATE();

                -- 🔥 Never before the scheduled start while queue not started
                IF @is_queue_started = 0 AND @arrival_time < @slot_start_dt
                    SET @arrival_time = @slot_start_dt;

                -- Round UP to next 5-min mark (clean display, like Practo)
                -- NOTE: use a midnight DATETIME (not DATE) — DATEADD(MINUTE,..)
                --       is not allowed on the DATE type.
                SET @mins_from_mid = DATEDIFF(MINUTE,
                                              DATEADD(DAY, DATEDIFF(DAY, 0, @arrival_time), 0),
                                              @arrival_time);
                SET @arrival_time  = DATEADD(MINUTE,
                                             ((@mins_from_mid + 4) / 5) * 5,
                                             DATEADD(DAY, DATEDIFF(DAY, 0, @arrival_time), 0));
            END

            --------------------------------------------------
            -- RESPONSE
            --------------------------------------------------
            SELECT 1 AS success,
                   @my_queue AS my_queue_number,
                   @patients_ahead AS patients_ahead,
                   @queue_size AS queue_size,
                   @total_queue AS total_queue,         -- 🔥 NEW
                   @current_serving AS current_serving, -- 🔥 NEW
                   CAST(@adaptive_avg AS DECIMAL(5, 2)) AS avg_time,
                   CASE
                       WHEN DATEDIFF(MINUTE, GETDATE(), @arrival_time) < 0 THEN 0
                       ELSE DATEDIFF(MINUTE, GETDATE(), @arrival_time)
                   END AS estimated_minutes,
                   FORMAT(@arrival_time, 'hh:mm tt') AS estimated_arrival_time,
                   @is_queue_started AS queue_started,
                   @is_my_turn AS is_my_turn,
                   CASE
                       --WHEN @queue_status = 0 THEN
                       --    'Not Started Yet'
                       --WHEN @queue_status = 1
                       --     AND @is_my_turn = 1 THEN
                       --    'Your Turn'
					    WHEN @my_status = 'skipped' THEN        
        'Skipped'
    WHEN @queue_status = 0 THEN
        'Not Started Yet'
    WHEN @queue_status = 1
         AND @is_my_turn = 1 THEN
        'Your Turn'
                       WHEN @queue_status = 1 THEN
                           'Waiting'
                       WHEN @queue_status = 2 THEN
                           'Paused'
                       WHEN @queue_status = 3 THEN
                           'Queue Closed'
                       WHEN @queue_status = 4 THEN
                           'Emergency Paused'
                       ELSE
                           'Unknown'
                   END AS status;
        END
        --------------------------------------------------
        -- QUEUE PREVIEW ESTIMATE (FINAL CORRECT VERSION)
        --------------------------------------------------
        IF @operation = 'QUEUE_PREVIEW_ESTIMATE'
        BEGIN


            --------------------------------------------------
            -- 🔥 GET NEXT QUEUE NUMBER (NEW BOOKING)
            --------------------------------------------------
            SELECT @my_queue = ISNULL(MAX(queue_number), 0) + 1
            FROM appointments
            WHERE doctor_id = @doctor_id
                  AND appointment_date = CAST(GETDATE() AS DATE)
                  AND booking_type = 1
                  AND slot_id = @slot_id;

            --------------------------------------------------
            -- 🔥 GET CURRENT QUEUE INFO
            --------------------------------------------------
            SELECT @current_serving = ISNULL(current_patient_id, 0),
                   @queue_started_time = started_at,
                   @base_avg = avg_consultation_time
            FROM doctor_queue
            WHERE doctor_id = @doctor_id
                  AND queue_date = CAST(GETDATE() AS DATE)
                  AND slot_id = @slot_id;

            SET @current_serving = ISNULL(@current_serving, 0);

            --------------------------------------------------
            -- 🔥 PATIENTS AHEAD (REAL COUNT BASED)
            --------------------------------------------------
            SELECT @patients_ahead = COUNT(*)
            FROM appointments
            WHERE doctor_id = @doctor_id
                  AND appointment_date = CAST(GETDATE() AS DATE)
                  AND booking_type = 1
                  AND slot_id = @slot_id
                  AND status IN ( 'booked', 'in_progress' );

            SET @queue_size = @patients_ahead;

            --------------------------------------------------
            -- TIME-BASED AVG (FALLBACK)
            --------------------------------------------------
            IF @base_avg IS NULL
            BEGIN
                SET @hour = DATEPART(HOUR, GETDATE());

                SELECT @base_avg = CASE
                                       WHEN @hour < 12 THEN
                                           morning_avg
                                       WHEN @hour < 17 THEN
                                           afternoon_avg
                                       ELSE
                                           evening_avg
                                   END
                FROM doctor_timing
                WHERE doctor_id = @doctor_id AND (@clinic_id IS NULL OR clinic_id = @clinic_id);
            END

            IF @base_avg IS NULL
                SET @base_avg = 7;

            --------------------------------------------------
            -- AVG CONSULT TIME (Practo-style)
            --   measured avg, clamped to a sane 3–30 min band.
            --   NO artificial queue-size scaling.
            --------------------------------------------------
            IF @base_avg < 3  SET @base_avg = 3;
            IF @base_avg > 30 SET @base_avg = 30;

            SET @adaptive_avg = @base_avg;

            --------------------------------------------------
            -- INITIAL ESTIMATION
            --------------------------------------------------
            SET @estimated_time = @patients_ahead * @adaptive_avg;

            --------------------------------------------------
            -- START TIME (REAL OR SCHEDULE)
            --------------------------------------------------

            -- REAL START
            SET @started_at = @queue_started_time;

            -- FALLBACK → SLOT TIME
            IF @started_at IS NULL
            BEGIN
                SELECT TOP 1
                    @started_at
                        = DATETIMEFROMPARTS(
                                               YEAR(GETDATE()),
                                               MONTH(GETDATE()),
                                               DAY(GETDATE()),
                                               DATEPART(HOUR, ts.start_time),
                                               DATEPART(MINUTE, ts.start_time),
                                               0,
                                               0
                                           )
                FROM doctor_time_slots ts
                WHERE ts.slot_id = @slot_id;
            END

            IF @started_at IS NULL
            BEGIN
                SELECT 0 AS success,
                       'Doctor not available today' AS message;
                RETURN;
            END

            --------------------------------------------------
            -- QUEUE STARTED CHECK
            --------------------------------------------------
            IF @started_at <= GETDATE()
                SET @is_queue_started = 1;
            ELSE
                SET @is_queue_started = 0;

            --------------------------------------------------
            -- FINAL ARRIVAL TIME
            --------------------------------------------------
            IF @patients_ahead = 0
               AND @is_queue_started = 1
            BEGIN
                SET @estimated_time = 0;
                SET @arrival_time = GETDATE();
                SET @is_my_turn = 1;
            END
            ELSE
            BEGIN
                -- Scheduled session start as today's datetime
                SELECT @slot_start_dt =
                    DATETIMEFROMPARTS(
                        YEAR(GETDATE()), MONTH(GETDATE()), DAY(GETDATE()),
                        DATEPART(HOUR, ts.start_time),
                        DATEPART(MINUTE, ts.start_time), 0, 0)
                FROM doctor_time_slots ts
                WHERE ts.slot_id = @slot_id;

                -- Queue NOT started → measure from scheduled start, not 'now'.
                IF @is_queue_started = 0
                   AND @slot_start_dt IS NOT NULL
                   AND @slot_start_dt > GETDATE()
                    SET @base_time = @slot_start_dt;
                ELSE
                    SET @base_time = GETDATE();

                SET @arrival_time = DATEADD(MINUTE, CEILING(@estimated_time), @base_time);

                -- Never in the past
                IF @arrival_time < GETDATE()
                    SET @arrival_time = GETDATE();

                -- 🔥 Never before the scheduled start while queue not started
                IF @is_queue_started = 0
                   AND @slot_start_dt IS NOT NULL
                   AND @arrival_time < @slot_start_dt
                    SET @arrival_time = @slot_start_dt;

                -- Round UP to next 5-min mark (clean display, like Practo)
                -- NOTE: use a midnight DATETIME (not DATE) — DATEADD(MINUTE,..)
                --       is not allowed on the DATE type.
                SET @mins_from_mid = DATEDIFF(MINUTE,
                                              DATEADD(DAY, DATEDIFF(DAY, 0, @arrival_time), 0),
                                              @arrival_time);
                SET @arrival_time  = DATEADD(MINUTE,
                                             ((@mins_from_mid + 4) / 5) * 5,
                                             DATEADD(DAY, DATEDIFF(DAY, 0, @arrival_time), 0));
            END

            --------------------------------------------------
            -- RESPONSE
            --------------------------------------------------
            SELECT 1 AS success,
                   @my_queue AS predicted_queue_number,
                   @patients_ahead AS patients_ahead,
                   @queue_size AS current_queue_size,
                   CAST(@adaptive_avg AS DECIMAL(5, 2)) AS avg_time,
                   CASE
                       WHEN DATEDIFF(MINUTE, GETDATE(), @arrival_time) < 0 THEN 0
                       ELSE DATEDIFF(MINUTE, GETDATE(), @arrival_time)
                   END AS estimated_minutes,
                   FORMAT(@arrival_time, 'hh:mm tt') AS estimated_arrival_time,
                   @is_queue_started AS queue_started,
                   @is_my_turn AS is_my_turn,
                   CASE
                       WHEN @is_queue_started = 0 THEN
                           'Not Started Yet'
                       WHEN @is_my_turn = 1 THEN
                           'Your Turn'
                       ELSE
                           'Waiting'
                   END AS status;
        END


        IF @operation = 'CHECK_QUEUE_BOOKING'
        BEGIN
            DECLARE @is_queue_available BIT = 0;
            DECLARE @is_booking_started BIT = 0;
            DECLARE @queue_length INT = 0;
            DECLARE @queue_start_time DATETIME;
            DECLARE @current_time DATETIME = GETDATE();
            DECLARE @q_start_before INT;

            --------------------------------------------------
            -- 🔥 CHECK QUEUE SLOT EXISTS TODAY
            --------------------------------------------------
            IF EXISTS
            (
                SELECT 1
                FROM doctor_availability da
                    JOIN doctor_time_slots ts
                        ON da.availability_id = ts.availability_id
                WHERE da.doctor_id = @doctor_id
                      AND da.is_enabled = 1
                      AND da.day_of_week = DATENAME(WEEKDAY, GETDATE())
                      AND ts.booking_mode IN ( 1, 3 )
            )
            BEGIN
                SET @is_queue_available = 1;
            END

            --------------------------------------------------
            -- ❌ IF NO QUEUE AVAILABLE
            --------------------------------------------------
            IF @is_queue_available = 0
            BEGIN
                SELECT 0 AS success,
                       'Queue booking not available for today' AS message;
                RETURN;
            END

            --------------------------------------------------
            -- 🔥 GET QUEUE SLOT START TIME + MAX LENGTH
            --------------------------------------------------
            SELECT TOP 1
                @queue_start_time
                    = DATETIMEFROMPARTS(
                                           YEAR(GETDATE()),
                                           MONTH(GETDATE()),
                                           DAY(GETDATE()),
                                           DATEPART(HOUR, ts.start_time),
                                           DATEPART(MINUTE, ts.start_time),
                                           0,
                                           0
                                       ),
                @max_queue_length = ts.max_queue_length
            FROM doctor_availability da
                JOIN doctor_time_slots ts
                    ON da.availability_id = ts.availability_id
            WHERE da.doctor_id = @doctor_id
                  AND da.is_enabled = 1
                  AND da.day_of_week = DATENAME(WEEKDAY, GETDATE())
                  AND ts.booking_mode IN ( 1, 3 )
            ORDER BY ts.start_time;

            --------------------------------------------------
            -- 🔥 GET q_start_before FROM doctor_login
            --------------------------------------------------
            SELECT @q_start_before = q_start_before
            FROM doctor_login
            WHERE doctor_id = @doctor_id;

            --------------------------------------------------
            -- 🔥 CALCULATE BOOKING START TIME
            --------------------------------------------------
            IF @q_start_before IS NOT NULL
            BEGIN
                SET @queue_start_time = DATEADD(MINUTE, -@q_start_before, @queue_start_time);
            END

            --------------------------------------------------
            -- 🔥 CHECK BOOKING STARTED OR NOT
            --------------------------------------------------
            IF @current_time >= @queue_start_time
                SET @is_booking_started = 1;

            --------------------------------------------------
            -- 🔥 GET CURRENT QUEUE LENGTH
            --------------------------------------------------
            SELECT @queue_length = ISNULL(total_queue, 0)
            FROM doctor_queue
            WHERE doctor_id = @doctor_id
                  AND queue_date = CAST(GETDATE() AS DATE);

            --------------------------------------------------
            -- 🔥 CHECK MAX QUEUE LIMIT
            --------------------------------------------------
            DECLARE @is_full BIT = 0;

            IF @max_queue_length IS NOT NULL
               AND @queue_length >= @max_queue_length
                SET @is_full = 1;

            --------------------------------------------------
            -- RESPONSE
            --------------------------------------------------
            SELECT 1 AS success,
                   @is_queue_available AS is_queue_available,
                   @is_booking_started AS is_booking_started,
                   @queue_length AS current_queue_length,
                   @max_queue_length AS max_queue_length,
                   @is_full AS is_queue_full,
                   FORMAT(@queue_start_time, 'hh:mm tt') AS booking_start_time;
        END



        IF @operation = 'TOMORROW_PATIENT_APPOINTMENTS'
        BEGIN
            SELECT a.appointment_id,
                   a.appointment_date,
                   d.name AS doctor_name,
                   p.token AS patient_token
            FROM appointments a
                INNER JOIN doctor_login d
                    ON d.doctor_id = a.doctor_id
                INNER JOIN patients p
                    ON p.patient_id = a.patient_id
            WHERE CAST(a.appointment_date AS DATE) = CAST(DATEADD(DAY, 1, GETDATE()) AS DATE)
            ORDER BY a.queue_number;
        END


        IF @operation = 'YESTERDAY_COMPLETED_PATIENTS'
        BEGIN
            SELECT a.appointment_id,
                   a.appointment_date,
                   a.queue_number,
                   d.name AS doctor_name,
                   CASE
                       WHEN a.user_type = 2 THEN
                           p_main.token
                       ELSE
                           p.token
                   END AS patient_token
            FROM appointments a
                INNER JOIN doctor_login d
                    ON d.doctor_id = a.doctor_id

                -- Direct patient (user_type = 1)
                LEFT JOIN patients p
                    ON p.patient_id = a.patient_id
                       AND a.user_type <> 2

                -- For family member (user_type = 2)
                LEFT JOIN family_members fm
                    ON fm.member_id = a.patient_id
                       AND a.user_type = 2

                -- Get token using family_id (main member)
                LEFT JOIN patients p_main
                    ON p_main.patient_id = fm.family_id
                       AND a.user_type = 2
            WHERE CAST(a.appointment_date AS DATE) = CAST(DATEADD(DAY, -1, GETDATE()) AS DATE)
                  AND a.status = 'completed'
            ORDER BY a.queue_number;
        END


    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK;
        SELECT 0 AS success,
               ERROR_MESSAGE() AS message;
    END CATCH
END
GO

CREATE PROCEDURE [dbo].[sp_doc]
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

--USE [QLess]
--GO
--/****** Object:  StoredProcedure [dbo].[sp_doctor_leave]    Script Date: 27-06-2026 12:26:08 ******/
--SET ANSI_NULLS ON
--GO
--SET QUOTED_IDENTIFIER ON
--GO

--ALTER   PROCEDURE [dbo].[sp_doctor_leave]
--    @operation  VARCHAR(30),
--    @leave_id   INT           = NULL,
--    @doctor_id  INT           = NULL,
--    @from_date  DATE          = NULL,
--    @to_date    DATE          = NULL,
--    @reason     NVARCHAR(200) = NULL
--AS
--BEGIN
--    SET NOCOUNT ON;

--    -- range madhle kiti future booked/in_progress appts (confirm dialog sathi)
--    IF @operation = 'COUNT_AFFECTED'
--    BEGIN
--        SELECT COUNT(*) AS cnt
--        FROM appointments a
--        JOIN doctor_time_slots  dts ON dts.slot_id        = a.slot_id
--        JOIN doctor_availability da  ON da.availability_id = dts.availability_id
--        WHERE da.doctor_id = @doctor_id
--          AND a.appointment_date BETWEEN @from_date AND @to_date
--          AND a.appointment_date >= CAST(GETDATE() AS DATE)
--          AND LOWER(a.status) IN ('booked', 'in_progress');
--        RETURN;
--    END

--    -- validate + insert, navin leave_id return
--    IF @operation = 'ADD_LEAVE'
--    BEGIN
--        IF @from_date IS NULL OR @to_date IS NULL OR @from_date > @to_date
--        BEGIN
--            SELECT CAST(NULL AS INT) AS leave_id, 'INVALID_RANGE' AS error;
--            RETURN;
--        END
--        IF @from_date < CAST(GETDATE() AS DATE)
--        BEGIN
--            SELECT CAST(NULL AS INT) AS leave_id, 'PAST_DATE' AS error;
--            RETURN;
--        END

--        INSERT INTO dbo.doctor_leave (doctor_id, from_date, to_date, reason)
--        VALUES (@doctor_id, @from_date, @to_date, @reason);

--        SELECT CAST(SCOPE_IDENTITY() AS INT) AS leave_id,
--               CAST(NULL AS VARCHAR(20))     AS error;
--        RETURN;
--    END

--    -- range madhle sagle future appts cancel + patient FCM tokens return
--    -- (token AS fcm_token alias kela -> Node madhe r.fcm_token barobar)
--    IF @operation = 'APPLY_LEAVE_CANCEL'
--    BEGIN
--        DECLARE @affected TABLE (appointment_id INT, patient_id INT);

--        INSERT INTO @affected (appointment_id, patient_id)
--        SELECT a.appointment_id, a.patient_id
--        FROM appointments a
--        JOIN doctor_time_slots  dts ON dts.slot_id        = a.slot_id
--        JOIN doctor_availability da  ON da.availability_id = dts.availability_id
--        WHERE da.doctor_id = @doctor_id
--          AND a.appointment_date BETWEEN @from_date AND @to_date
--          AND a.appointment_date >= CAST(GETDATE() AS DATE)
--          AND LOWER(a.status) IN ('booked', 'in_progress');

--        UPDATE appointments
--        SET status = 'CancleD'
--        WHERE appointment_id IN (SELECT appointment_id FROM @affected);

--        SELECT p.token AS fcm_token
--        FROM @affected af
--        JOIN patients p ON p.patient_id = af.patient_id
--        WHERE p.token IS NOT NULL
--          AND LTRIM(RTRIM(p.token)) <> '';
--        RETURN;
--    END

--    -- doctor chya "My Leaves" list sathi upcoming active leaves
--    IF @operation = 'LIST_LEAVE'
--    BEGIN
--        SELECT leave_id,
--               doctor_id,
--               CONVERT(VARCHAR(10), from_date, 23) AS from_date,
--               CONVERT(VARCHAR(10), to_date,   23) AS to_date,
--               reason
--        FROM dbo.doctor_leave
--        WHERE doctor_id = @doctor_id
--          AND is_active = 1
--          AND to_date  >= CAST(GETDATE() AS DATE)
--        ORDER BY from_date;
--        RETURN;
--    END

--    -- planned leave soft-delete (already-cancelled appts restore hot NAHIT)
--    IF @operation = 'CANCEL_LEAVE'
--    BEGIN
--        UPDATE dbo.doctor_leave
--        SET is_active = 0
--        WHERE leave_id  = @leave_id
--          AND doctor_id = @doctor_id;

--        SELECT @leave_id AS leave_id;
--        RETURN;
--    END

--    -- patient app calendar madhe greyed-out dates
--    IF @operation = 'GET_LEAVE_DATES'
--    BEGIN
--        SELECT CONVERT(VARCHAR(10), from_date, 23) AS from_date,
--               CONVERT(VARCHAR(10), to_date,   23) AS to_date
--        FROM dbo.doctor_leave
--        WHERE doctor_id = @doctor_id
--          AND is_active = 1
--          AND to_date  >= CAST(GETDATE() AS DATE)
--        ORDER BY from_date;
--        RETURN;
--    END

--    -- @from_date kontya active leave madhe yeto ka — booking hard-guard
--    IF @operation = 'IS_BLOCKED'
--    BEGIN
--        SELECT CASE WHEN EXISTS (
--            SELECT 1
--            FROM dbo.doctor_leave
--            WHERE doctor_id = @doctor_id
--              AND is_active  = 1
--              AND @from_date BETWEEN from_date AND to_date
--        ) THEN 1 ELSE 0 END AS blocked;
--        RETURN;
--    END
--END




-- 2. SP update with @clinic_id parameter
CREATE PROCEDURE [dbo].[sp_doctor_leave]
    @operation  VARCHAR(30),
    @leave_id   INT           = NULL,
    @doctor_id  INT           = NULL,
    @from_date  DATE          = NULL,
    @to_date    DATE          = NULL,
    @reason     NVARCHAR(200) = NULL,
    @clinic_id  VARCHAR(20)   = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @operation = 'COUNT_AFFECTED'
    BEGIN
        SELECT COUNT(*) AS cnt
        FROM appointments a
        JOIN doctor_time_slots  dts ON dts.slot_id        = a.slot_id
        JOIN doctor_availability da  ON da.availability_id = dts.availability_id
        WHERE da.doctor_id = @doctor_id
          AND (@clinic_id IS NULL OR da.clinic_id = @clinic_id)
          AND a.appointment_date BETWEEN @from_date AND @to_date
          AND a.appointment_date >= CAST(GETDATE() AS DATE)
          AND LOWER(a.status) IN ('booked', 'in_progress');
        RETURN;
    END

    IF @operation = 'ADD_LEAVE'
    BEGIN
        IF @from_date IS NULL OR @to_date IS NULL OR @from_date > @to_date
        BEGIN
            SELECT CAST(NULL AS INT) AS leave_id, 'INVALID_RANGE' AS error;
            RETURN;
        END
        IF @from_date < CAST(GETDATE() AS DATE)
        BEGIN
            SELECT CAST(NULL AS INT) AS leave_id, 'PAST_DATE' AS error;
            RETURN;
        END

        INSERT INTO dbo.doctor_leave (doctor_id, clinic_id, from_date, to_date, reason)
        VALUES (@doctor_id, @clinic_id, @from_date, @to_date, @reason);

        SELECT CAST(SCOPE_IDENTITY() AS INT) AS leave_id,
               CAST(NULL AS VARCHAR(20))     AS error;
        RETURN;
    END

    IF @operation = 'APPLY_LEAVE_CANCEL'
    BEGIN
        DECLARE @affected TABLE (appointment_id INT, patient_id INT);

        INSERT INTO @affected (appointment_id, patient_id)
        SELECT a.appointment_id, a.patient_id
        FROM appointments a
        JOIN doctor_time_slots  dts ON dts.slot_id        = a.slot_id
        JOIN doctor_availability da  ON da.availability_id = dts.availability_id
        WHERE da.doctor_id = @doctor_id
          AND (@clinic_id IS NULL OR da.clinic_id = @clinic_id)
          AND a.appointment_date BETWEEN @from_date AND @to_date
          AND a.appointment_date >= CAST(GETDATE() AS DATE)
          AND LOWER(a.status) IN ('booked', 'in_progress');

        UPDATE appointments
        SET status = 'CancleD'
        WHERE appointment_id IN (SELECT appointment_id FROM @affected);

        SELECT p.token AS fcm_token
        FROM @affected af
        JOIN patients p ON p.patient_id = af.patient_id
        WHERE p.token IS NOT NULL
          AND LTRIM(RTRIM(p.token)) <> '';
        RETURN;
    END

    IF @operation = 'LIST_LEAVE'
    BEGIN
        SELECT leave_id,
               doctor_id,
               clinic_id,
               CONVERT(VARCHAR(10), from_date, 23) AS from_date,
               CONVERT(VARCHAR(10), to_date,   23) AS to_date,
               reason
        FROM dbo.doctor_leave
        WHERE doctor_id = @doctor_id
          AND (@clinic_id IS NULL OR clinic_id = @clinic_id)
          AND is_active = 1
          AND to_date  >= CAST(GETDATE() AS DATE)
        ORDER BY from_date;
        RETURN;
    END

    IF @operation = 'CANCEL_LEAVE'
    BEGIN
        UPDATE dbo.doctor_leave
        SET is_active = 0
        WHERE leave_id  = @leave_id
          AND doctor_id = @doctor_id
          AND (@clinic_id IS NULL OR clinic_id = @clinic_id);

        SELECT @leave_id AS leave_id;
        RETURN;
    END

   IF @operation = 'GET_LEAVE_DATES'
BEGIN
    SELECT CONVERT(VARCHAR(10), from_date, 23) AS from_date,
           CONVERT(VARCHAR(10), to_date,   23) AS to_date
    FROM dbo.doctor_leave
    WHERE doctor_id = @doctor_id
      AND (clinic_id IS NULL OR clinic_id = @clinic_id)  -- ← हे बदल
      AND is_active = 1
      AND to_date  >= CAST(GETDATE() AS DATE)
    ORDER BY from_date;
    RETURN;
END


    IF @operation = 'IS_BLOCKED'
    BEGIN
        SELECT CASE WHEN EXISTS (
            SELECT 1
            FROM dbo.doctor_leave
            WHERE doctor_id = @doctor_id
              AND (@clinic_id IS NULL OR clinic_id = @clinic_id)
              AND is_active  = 1
              AND @from_date BETWEEN from_date AND to_date
        ) THEN 1 ELSE 0 END AS blocked;
        RETURN;
    END
END
GO

CREATE PROCEDURE [dbo].[sp_doctor_login]
(
    @operation          NVARCHAR(50),
    @doctor_id          INT = NULL,
    @name               NVARCHAR(50) = NULL,
    @email              NVARCHAR(MAX) = NULL,
    @mobile             NVARCHAR(20) = NULL,
    @qualification      NVARCHAR(MAX) = NULL,
    @license_no         NVARCHAR(50) = NULL,
    @experience         INT = NULL,
    @specialization     NVARCHAR(50) = NULL,
    @role_id            INT = NULL,
    @gender_id          INT = NULL,
    @q_start_before     INT = NULL,
    @role               NVARCHAR(20) = NULL,
    @token              NVARCHAR(MAX) = NULL,
    @image              NVARCHAR(MAX) = NULL,
    @clinic_id          NVARCHAR(50) = NULL,
    @clinic_name        NVARCHAR(50) = NULL,
    @clinic_address     NVARCHAR(100) = NULL,
    @latitude           DECIMAL(10,7) = NULL,
    @longitude          DECIMAL(10,7) = NULL,
    @consultation_fee   DECIMAL(10,2) = NULL,
    @website_name       NVARCHAR(50) = NULL,
    @clinic_email       NVARCHAR(MAX) = NULL,
    @clinic_contact     NVARCHAR(20) = NULL,
    @image_url          NVARCHAR(MAX) = NULL,
    @sort_order         INT = NULL
)
AS
BEGIN
SET NOCOUNT ON;

---------------------------------------------------------
-- INSERT
---------------------------------------------------------
IF @operation = 'Insert'
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        IF EXISTS (
            SELECT 1 FROM dbo.doctor_login
            WHERE mobile = @mobile AND active_status = 0
        )
        BEGIN
            SELECT 0 AS success, 'Mobile number already exists' AS message;
            ROLLBACK TRANSACTION;
            RETURN;
        END
		IF EXISTS (
    SELECT 1 FROM dbo.receptionist
    WHERE mobile_no = @mobile AND active_status = 1
)
BEGIN
    SELECT 0 AS success, 'This mobile is already registered as a Receptionist' AS message;
    ROLLBACK TRANSACTION;
    RETURN;
END


        DECLARE @next_no INT;
        SELECT @next_no = ISNULL(MAX(CAST(SUBSTRING(clinic_id,3,10) AS INT)),0) + 1
        FROM dbo.clinics WHERE clinic_id LIKE 'CL%';
        SET @clinic_id = 'CL' + RIGHT('000' + CAST(@next_no AS NVARCHAR), 3);

        INSERT INTO dbo.clinics
            (clinic_id, clinic_name, clinic_address, latitude, longitude,
             consultation_fee, website_name, clinic_email, clinic_contact,
             image_url, active_status, is_verified)
        VALUES
            (@clinic_id, @clinic_name, @clinic_address, @latitude, @longitude,
             @consultation_fee, @website_name, @clinic_email, @clinic_contact,
             @image_url, 0, 1);

        -- is_verified = 0: a freshly-registered doctor is PENDING admin
        -- review until someone approves them via /admin (VerifyDoctor below).
        INSERT INTO dbo.doctor_login
            (name, email, mobile, qualification, license_no, experience,
             specialization, created_at, role_id, clinic_id,
             active_status, is_verified, gender_id, image)
        VALUES
            (@name, @email, @mobile, @qualification, @license_no, @experience,
             @specialization, GETDATE(), @role_id, @clinic_id,
             0, 0, @gender_id, @image);

        SET @doctor_id = SCOPE_IDENTITY();

        UPDATE dbo.clinics
        SET doctor_id = @doctor_id
        WHERE clinic_id = @clinic_id;

        COMMIT TRANSACTION;
        SELECT @doctor_id AS doctor_id, @clinic_id AS clinic_id;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        SELECT ERROR_MESSAGE() AS ErrorMessage, ERROR_LINE() AS ErrorLine;
    END CATCH
    RETURN;
END

---------------------------------------------------------
-- saveFirebaseToken
---------------------------------------------------------
IF @operation = 'saveFirebaseToken'
BEGIN
    IF @role = 'doctor'
        UPDATE doctor_login SET token = @token WHERE mobile = @mobile;
    ELSE IF @role = 'patient'
        UPDATE Patients SET token = @token WHERE mobile_no = @mobile;
    RETURN;
END

---------------------------------------------------------
-- UPDATE
---------------------------------------------------------
IF @operation = 'Update'
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.doctor_login
        SET name = @name, email = @email, mobile = @mobile,
            qualification = @qualification, license_no = @license_no,
            experience = @experience, specialization = @specialization,
            role_id = @role_id, gender_id = @gender_id
        WHERE doctor_id = @doctor_id;

        UPDATE dbo.clinics
        SET clinic_name = @clinic_name, clinic_address = @clinic_address,
            latitude = @latitude, longitude = @longitude,
            consultation_fee = @consultation_fee, website_name = @website_name,
            clinic_email = @clinic_email, clinic_contact = @clinic_contact,
            image_url = @image_url
        WHERE clinic_id = (SELECT clinic_id FROM dbo.doctor_login WHERE doctor_id = @doctor_id);

        COMMIT TRANSACTION;

        DECLARE @returned_clinic_id NVARCHAR(50);
        SELECT @returned_clinic_id = clinic_id FROM dbo.doctor_login WHERE doctor_id = @doctor_id;
        SELECT @doctor_id AS doctor_id, @returned_clinic_id AS clinic_id;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        SELECT ERROR_MESSAGE() AS ErrorMessage, ERROR_LINE() AS ErrorLine;
    END CATCH
    RETURN;
END

---------------------------------------------------------
-- FetchDoctor
---------------------------------------------------------
IF @operation = 'FetchDoctor'
BEGIN
    SELECT d.doctor_id, d.name, d.email, d.mobile, d.qualification,
           d.license_no, d.experience, d.specialization, d.clinic_id,
           c.clinic_name, c.clinic_address, c.consultation_fee,
           c.clinic_contact, c.clinic_email
    FROM dbo.doctor_login d
    LEFT JOIN dbo.clinics c ON d.clinic_id = c.clinic_id
    WHERE d.mobile = @mobile;
    RETURN;
END

---------------------------------------------------------
-- FetchDoctors
---------------------------------------------------------
IF @operation = 'FetchDoctors'
BEGIN
    SELECT * FROM dbo.doctor_login
    WHERE clinic_id = @clinic_id AND active_status = 0;
    RETURN;
END

---------------------------------------------------------
-- DeleteDoctor
---------------------------------------------------------
IF @operation = 'DeleteDoctor'
BEGIN
    UPDATE dbo.doctor_login SET active_status = 1 WHERE doctor_id = @doctor_id;
    SELECT 1 AS success, 'Doctor deleted successfully' AS message;
    RETURN;
END

---------------------------------------------------------
-- ListPendingDoctors — admin approval queue
---------------------------------------------------------
IF @operation = 'ListPendingDoctors'
BEGIN
    SELECT doctor_id, name, email, mobile, qualification, license_no,
           experience, specialization, clinic_id, clinic_name,
           clinic_address, clinic_contact, clinic_email, doc_created_at
    FROM dbo.doctor_login_vw
    WHERE doc_active_status = 0 AND doc_is_verified = 1
    ORDER BY doc_created_at ASC;
    RETURN;
END

---------------------------------------------------------
-- VerifyDoctor — admin approval
---------------------------------------------------------
IF @operation = 'VerifyDoctor'
BEGIN
    UPDATE dbo.doctor_login SET is_verified = 0 WHERE doctor_id = @doctor_id;
    SELECT 1 AS success, 'Doctor verified' AS message;
    RETURN;
END

---------------------------------------------------------
-- check_phone_doctor
---------------------------------------------------------
IF @operation = 'check_phone_doctor'
BEGIN
    SELECT * FROM dbo.doctor_login_vw
    WHERE mobile = @mobile AND doc_active_status = 0 AND doc_is_verified = 0;
    RETURN;
END

---------------------------------------------------------
-- doctor_mobile_exist
---------------------------------------------------------
IF @operation = 'doctor_mobile_exist'
BEGIN
    SELECT doctor_id, mobile, doc_active_status, doc_is_verified
    FROM dbo.doctor_login_vw
    WHERE mobile = @mobile AND doc_active_status = 0

    UNION ALL

    SELECT NULL AS doctor_id, mobile_no AS mobile, 1 AS doc_active_status, 1 AS doc_is_verified
    FROM dbo.receptionist
    WHERE mobile_no = @mobile AND active_status = 1;
    RETURN;
END

---------------------------------------------------------
-- uploadDoctorImg
---------------------------------------------------------
IF @operation = 'uploadDoctorImg'
BEGIN
    UPDATE doctor_login SET image = @image WHERE doctor_id = @doctor_id;
    RETURN;
END

---------------------------------------------------------
-- uploadClinicImg
---------------------------------------------------------
IF @operation = 'uploadClinicImg'
BEGIN
    UPDATE clinics SET image_url = @image_url WHERE clinic_id = @clinic_id;
    RETURN;
END

---------------------------------------------------------
-- uploadClinicGallery
---------------------------------------------------------
IF @operation = 'uploadClinicGallery'
BEGIN
    INSERT INTO dbo.clinic_images
        (clinic_id, image_url, sort_order, active_status, created_at)
    VALUES (@clinic_id, @image_url, @sort_order, 0, GETDATE());
    RETURN;
END

---------------------------------------------------------
-- Insert_Q_StartTime
---------------------------------------------------------
IF @operation = 'Insert_Q_StartTime'
BEGIN
    UPDATE doctor_login SET q_start_before = @q_start_before WHERE doctor_id = @doctor_id;
    RETURN;
END

---------------------------------------------------------
-- fetchClinicGallery
---------------------------------------------------------
IF @operation = 'fetchClinicGallery'
BEGIN
    SELECT clinic_image_id, clinic_id, image_url, sort_order
    FROM dbo.clinic_images
    WHERE clinic_id = @clinic_id AND active_status = 0
    ORDER BY sort_order;
    RETURN;
END

---------------------------------------------------------
-- deleteClinicGallery
---------------------------------------------------------
IF @operation = 'deleteClinicGallery'
BEGIN
    DELETE FROM dbo.clinic_images
    WHERE clinic_id = @clinic_id
      AND image_url IN (SELECT value FROM STRING_SPLIT(@image_url, ','));
    SELECT @@ROWCOUNT AS deleted_count, 'Images deleted' AS message;
    RETURN;
END

---------------------------------------------------------
-- AddClinic
---------------------------------------------------------
IF @operation = 'AddClinic'
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @next_no2 INT;
        SELECT @next_no2 = ISNULL(MAX(CAST(SUBSTRING(clinic_id,3,10) AS INT)),0) + 1
        FROM dbo.clinics WHERE clinic_id LIKE 'CL%';
        SET @clinic_id = 'CL' + RIGHT('000' + CAST(@next_no2 AS NVARCHAR), 3);

        INSERT INTO dbo.clinics
            (clinic_id, clinic_name, clinic_address, latitude, longitude,
             consultation_fee, website_name, clinic_email, clinic_contact,
             image_url, active_status, is_verified, doctor_id)
        VALUES
            (@clinic_id, @clinic_name, @clinic_address, @latitude, @longitude,
             @consultation_fee, @website_name, @clinic_email, @clinic_contact,
             @image_url, 0, 1, @doctor_id);

        COMMIT TRANSACTION;
        SELECT 1 AS success, @clinic_id AS clinic_id, 'Clinic added' AS message;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        SELECT ERROR_MESSAGE() AS ErrorMessage;
    END CATCH
    RETURN;
END

---------------------------------------------------------
-- GetDoctorClinics
---------------------------------------------------------
IF @operation = 'GetDoctorClinics'
BEGIN
    SELECT
        clinic_id, clinic_name, clinic_address,
        latitude, longitude, consultation_fee,
        clinic_email, clinic_contact,
        website_name, image_url,
        CASE WHEN clinic_id = (
            SELECT clinic_id FROM dbo.doctor_login WHERE doctor_id = @doctor_id
        ) THEN 1 ELSE 0 END AS is_primary
    FROM dbo.clinics
    WHERE doctor_id = @doctor_id
      AND active_status = 0
    ORDER BY is_primary DESC;
    RETURN;
END

---------------------------------------------------------
-- UpdateClinic
---------------------------------------------------------
IF @operation = 'UpdateClinic'
BEGIN
    UPDATE dbo.clinics
    SET clinic_name      = @clinic_name,
        clinic_address   = @clinic_address,
        latitude         = ISNULL(@latitude, latitude),
        longitude        = ISNULL(@longitude, longitude),
        consultation_fee = @consultation_fee,
        website_name     = @website_name,
        clinic_email     = @clinic_email,
        clinic_contact   = @clinic_contact
    WHERE clinic_id = @clinic_id
      AND doctor_id = @doctor_id;
    SELECT 1 AS success, @clinic_id AS clinic_id;
    RETURN;
END

---------------------------------------------------------
-- DeleteClinic
---------------------------------------------------------
IF @operation = 'DeleteClinic'
BEGIN
    -- Primary clinic (doctor_login.clinic_id shi match) delete nahi hoto
    IF EXISTS (
        SELECT 1 FROM dbo.doctor_login
        WHERE doctor_id = @doctor_id AND clinic_id = @clinic_id
    )
    BEGIN
        SELECT 0 AS success, 'Cannot delete primary clinic' AS message;
        RETURN;
    END

    UPDATE dbo.clinics
    SET active_status = 1
    WHERE clinic_id = @clinic_id
      AND doctor_id = @doctor_id;

    SELECT 1 AS success, 'Clinic deleted' AS message;
    RETURN;
END

END
GO

--USE [QLess]
--GO
--/****** Object:  StoredProcedure [dbo].[sp_doctor_schedule]    Script Date: 23-06-2026 13:21:01 ******/
--SET ANSI_NULLS ON
--GO
--SET QUOTED_IDENTIFIER ON
--GO
--ALTER PROCEDURE [dbo].[sp_doctor_schedule]
--    @operation        VARCHAR(40),
--    @doctor_id        INT  = NULL,
--    @day_of_week      VARCHAR(10) = NULL,
--    @is_enabled       BIT  = NULL,
--    @availability_id  INT  = NULL,
--    @slot_id          INT  = NULL,
--    @start_time       TIME = NULL,
--    @end_time         TIME = NULL,
--    @booking_mode     INT  = NULL,
--    @slot_duration    INT  = NULL,
--    @max_queue_length INT  = NULL
--AS
--BEGIN
--    SET NOCOUNT ON;

--    ----------------------------------------------------------------------
--    -- DELETE_ALL  (unchanged behavior, but only touches active slots)
--    ----------------------------------------------------------------------
--    IF @operation = 'DELETE_ALL'
--    BEGIN
--        UPDATE doctor_time_slots
--        SET is_active = 0
--        WHERE availability_id IN (
--            SELECT availability_id FROM doctor_availability WHERE doctor_id = @doctor_id
--        );

--        DELETE FROM doctor_availability
--        WHERE doctor_id = @doctor_id;
--    END

--    ----------------------------------------------------------------------
--    -- INSERT_DAY  (unchanged)
--    ----------------------------------------------------------------------
--    IF @operation = 'INSERT_DAY'
--    BEGIN
--        INSERT INTO doctor_availability (doctor_id, day_of_week, is_enabled)
--        VALUES (@doctor_id, @day_of_week, @is_enabled);

--        SELECT SCOPE_IDENTITY() AS availability_id;
--    END

--    ----------------------------------------------------------------------
--    -- INSERT_SLOT  (unchanged)
--    ----------------------------------------------------------------------
--    IF @operation = 'INSERT_SLOT'
--    BEGIN
--        INSERT INTO doctor_time_slots (
--            availability_id, start_time, end_time,
--            booking_mode, slot_duration, max_queue_length
--        )
--        VALUES (
--            @availability_id, @start_time, @end_time,
--            @booking_mode, @slot_duration, @max_queue_length
--        );
--    END

--    ----------------------------------------------------------------------
--    -- UPSERT_DAY
--    ----------------------------------------------------------------------
--    IF @operation = 'UPSERT_DAY'
--    BEGIN
--        DECLARE @existing_avail_id INT;

--        SELECT @existing_avail_id = availability_id
--        FROM doctor_availability
--        WHERE doctor_id = @doctor_id
--          AND day_of_week = @day_of_week;

--        IF @existing_avail_id IS NULL
--        BEGIN
--            INSERT INTO doctor_availability (doctor_id, day_of_week, is_enabled)
--            VALUES (@doctor_id, @day_of_week, @is_enabled);

--            SELECT CAST(SCOPE_IDENTITY() AS INT) AS availability_id;
--        END
--        ELSE
--        BEGIN
--            UPDATE doctor_availability
--            SET is_enabled = @is_enabled
--            WHERE availability_id = @existing_avail_id;

--            SELECT @existing_avail_id AS availability_id;
--        END
--    END

--    ----------------------------------------------------------------------
--    -- UPSERT_SLOT
--    --   - @slot_id NULL  → INSERT
--    --   - @slot_id given → UPDATE that row
--    ----------------------------------------------------------------------
--   IF @operation = 'UPSERT_SLOT'
--BEGIN
--    IF @slot_id IS NULL
--    BEGIN
--        -- Same key cha soft-deleted row aahe ka? Tar to reactivate kar
--        DECLARE @dead_slot_id INT;

--        SELECT @dead_slot_id = slot_id
--        FROM doctor_time_slots
--        WHERE availability_id = @availability_id
--          AND start_time      = @start_time
--          AND is_active        = 0;

--        IF @dead_slot_id IS NOT NULL
--        BEGIN
--            UPDATE doctor_time_slots
--            SET end_time         = @end_time,
--                booking_mode     = @booking_mode,
--                slot_duration    = @slot_duration,
--                max_queue_length = @max_queue_length,
--                is_active        = 1
--            WHERE slot_id = @dead_slot_id;

--            SELECT @dead_slot_id AS slot_id;
--        END
--        ELSE
--        BEGIN
--            INSERT INTO doctor_time_slots (
--                availability_id, start_time, end_time,
--                booking_mode, slot_duration, max_queue_length
--            )
--            VALUES (
--                @availability_id, @start_time, @end_time,
--                @booking_mode, @slot_duration, @max_queue_length
--            );

--            SELECT CAST(SCOPE_IDENTITY() AS INT) AS slot_id;
--        END
--    END
--    ELSE
--    BEGIN
--        UPDATE doctor_time_slots
--        SET start_time       = @start_time,
--            end_time         = @end_time,
--            booking_mode     = @booking_mode,
--            slot_duration    = @slot_duration,
--            max_queue_length = @max_queue_length,
--            is_active        = 1
--        WHERE slot_id = @slot_id
--          AND availability_id = @availability_id;

--        SELECT @slot_id AS slot_id;
--    END
--END

--    ----------------------------------------------------------------------
--    -- GET_DAY_SLOT_IDS   (only active slots)
--    ----------------------------------------------------------------------
--    IF @operation = 'GET_DAY_SLOT_IDS'
--    BEGIN
--        SELECT dts.slot_id
--        FROM doctor_time_slots dts
--        JOIN doctor_availability da ON da.availability_id = dts.availability_id
--        WHERE da.doctor_id   = @doctor_id
--          AND da.day_of_week = @day_of_week
--          AND dts.is_active  = 1;
--    END

--    ----------------------------------------------------------------------
--    -- COUNT_FUTURE_APPTS_FOR_SLOT
--    ----------------------------------------------------------------------
--      IF @operation = 'COUNT_FUTURE_APPTS_FOR_SLOT'
--    BEGIN
--        SELECT COUNT(*) AS cnt
--        FROM appointments
--        WHERE slot_id = @slot_id
--          AND appointment_date > CAST(GETDATE() AS DATE)   -- ★ >= → >  (today exclude)
--          AND LOWER(status) IN ('booked', 'in_progress');
--    END


--    ----------------------------------------------------------------------
--    -- CANCEL_FUTURE_APPTS_FOR_SLOT   ★ was MISSING in your paste
--    --   - Marks future booked/in_progress appointments on this slot as cancelled
--    --   - Returns patient FCM tokens for Node to multicast
--    --   ⚠ assumes patients.fcm_token column. Tell me if different.
--    ----------------------------------------------------------------------
--    IF @operation = 'CANCEL_FUTURE_APPTS_FOR_SLOT'
--    BEGIN
--        DECLARE @affected TABLE (appointment_id INT, patient_id INT);

--             INSERT INTO @affected (appointment_id, patient_id)
--        SELECT appointment_id, patient_id
--        FROM appointments
--        WHERE slot_id = @slot_id
--          AND appointment_date > CAST(GETDATE() AS DATE)   -- ★ >= → >
--          AND LOWER(status) IN ('booked', 'in_progress');


--        UPDATE appointments
--        SET status = 'CancleD'
--        WHERE appointment_id IN (SELECT appointment_id FROM @affected);

--        --SELECT p.token
--        --FROM @affected a
--        --JOIN patients p ON p.patient_id = a.patient_id
--        --WHERE p.token IS NOT NULL
--        --  AND LTRIM(RTRIM(p.token)) <> '';
--		SELECT
--    CASE
--        WHEN ap.user_type = 1 THEN p.token
--        WHEN ap.user_type = 2 THEN p2.token
--    END AS fcm_token
--FROM @affected a
--JOIN appointments ap
--    ON ap.appointment_id = a.appointment_id
--LEFT JOIN patients p
--    ON ap.user_type = 1 AND p.patient_id = ap.patient_id
--LEFT JOIN family_members fm
--    ON ap.user_type = 2 AND fm.member_id = ap.patient_id
--LEFT JOIN patients p2
--    ON fm.family_id = p2.patient_id
--WHERE COALESCE(
--    CASE WHEN ap.user_type = 1 THEN p.token
--         WHEN ap.user_type = 2 THEN p2.token END, '') <> '';

--    END

--    ----------------------------------------------------------------------
--    -- DELETE_SLOT   ★ soft delete (preserves completed-appointment history)
--    --   - Instead of removing the row, mark inactive
--    --   - Past appointments keep their slot_id reference intact
--    ----------------------------------------------------------------------
--    IF @operation = 'DELETE_SLOT'
--    BEGIN
--        UPDATE doctor_time_slots
--        SET is_active = 0
--        WHERE slot_id = @slot_id;
--    END

--    ----------------------------------------------------------------------
--    -- GET   (only active slots returned to UI)
--    ----------------------------------------------------------------------
--    IF @operation = 'GET'
--    BEGIN
--        SELECT 
--            da.availability_id,
--            da.day_of_week,
--            da.is_enabled,
--            dts.slot_id,
--            CONVERT(VARCHAR(5), dts.start_time, 108) AS start_time,
--            CONVERT(VARCHAR(5), dts.end_time,   108) AS end_time,
--            dts.booking_mode,
--            dts.slot_duration,
--            dts.max_queue_length
--        FROM doctor_availability da
--        LEFT JOIN doctor_time_slots dts 
--            ON da.availability_id = dts.availability_id
--           AND dts.is_active = 1                       -- ★ hide soft-deleted
--        WHERE da.doctor_id = @doctor_id
--        ORDER BY 
--            CASE da.day_of_week
--                WHEN 'Monday' THEN 1
--                WHEN 'Tuesday' THEN 2
--                WHEN 'Wednesday' THEN 3
--                WHEN 'Thursday' THEN 4
--                WHEN 'Friday' THEN 5
--                WHEN 'Saturday' THEN 6
--                WHEN 'Sunday' THEN 7
--            END,
--            dts.start_time;
--    END


--	    ----------------------------------------------------------------------
--    -- RESCHEDULE_FUTURE_APPTS_FOR_SLOT  ★ NEW
--    ----------------------------------------------------------------------
--    IF @operation = 'RESCHEDULE_FUTURE_APPTS_FOR_SLOT'
--    BEGIN
--        DECLARE @affectedR TABLE (appointment_id INT, patient_id INT);

--             INSERT INTO @affectedR (appointment_id, patient_id)
--        SELECT appointment_id, patient_id
--        FROM appointments
--        WHERE slot_id = @slot_id
--          AND appointment_date > CAST(GETDATE() AS DATE)   -- ★ >= → >
--          AND LOWER(status) IN ('booked', 'in_progress');


--        UPDATE appointments
--        SET status = 'reschedule'
--        WHERE appointment_id IN (SELECT appointment_id FROM @affectedR);

--        SELECT p.token
--        FROM @affectedR a
--        JOIN patients p ON p.patient_id = a.patient_id
--        WHERE p.token IS NOT NULL
--          AND LTRIM(RTRIM(p.token)) <> '';
--    END

--END




-- Step 2: updated SP
CREATE PROCEDURE [dbo].[sp_doctor_schedule]
    @operation        VARCHAR(40),
    @doctor_id        INT            = NULL,
    @clinic_id        NVARCHAR(20)   = NULL,   -- ← NEW
    @day_of_week      VARCHAR(10)    = NULL,
    @is_enabled       BIT            = NULL,
    @availability_id  INT            = NULL,
    @slot_id          INT            = NULL,
    @start_time       TIME           = NULL,
    @end_time         TIME           = NULL,
    @booking_mode     INT            = NULL,
    @slot_duration    INT            = NULL,
    @max_queue_length INT            = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @operation = 'DELETE_ALL'
    BEGIN
        UPDATE doctor_time_slots SET is_active = 0
        WHERE availability_id IN (
            SELECT availability_id FROM doctor_availability
            WHERE doctor_id = @doctor_id
              AND (clinic_id = @clinic_id OR @clinic_id IS NULL)
        );
        DELETE FROM doctor_availability
        WHERE doctor_id = @doctor_id
          AND (clinic_id = @clinic_id OR @clinic_id IS NULL);
    END

    IF @operation = 'INSERT_DAY'
    BEGIN
        INSERT INTO doctor_availability (doctor_id, clinic_id, day_of_week, is_enabled)
        VALUES (@doctor_id, @clinic_id, @day_of_week, @is_enabled);
        SELECT SCOPE_IDENTITY() AS availability_id;
    END

    IF @operation = 'INSERT_SLOT'
    BEGIN
        INSERT INTO doctor_time_slots (
            availability_id, start_time, end_time,
            booking_mode, slot_duration, max_queue_length)
        VALUES (@availability_id, @start_time, @end_time,
                @booking_mode, @slot_duration, @max_queue_length);
    END

    IF @operation = 'UPSERT_DAY'
    BEGIN
        DECLARE @existing_avail_id INT;
        SELECT @existing_avail_id = availability_id
        FROM doctor_availability
        WHERE doctor_id  = @doctor_id
          AND day_of_week = @day_of_week
          AND (clinic_id = @clinic_id OR (@clinic_id IS NULL AND clinic_id IS NULL));

        IF @existing_avail_id IS NULL
        BEGIN
            INSERT INTO doctor_availability (doctor_id, clinic_id, day_of_week, is_enabled)
            VALUES (@doctor_id, @clinic_id, @day_of_week, @is_enabled);
            SELECT CAST(SCOPE_IDENTITY() AS INT) AS availability_id;
        END
        ELSE
        BEGIN
            UPDATE doctor_availability SET is_enabled = @is_enabled
            WHERE availability_id = @existing_avail_id;
            SELECT @existing_avail_id AS availability_id;
        END
    END

    -- (UPSERT_SLOT, DELETE_SLOT, COUNT_FUTURE_APPTS_FOR_SLOT,
    --  CANCEL_FUTURE_APPTS_FOR_SLOT, RESCHEDULE_FUTURE_APPTS_FOR_SLOT
    --  — no change needed, they work by availability_id/slot_id directly)

    IF @operation = 'UPSERT_SLOT'
    BEGIN
        IF @slot_id IS NULL
        BEGIN
            DECLARE @dead_slot_id INT;
            SELECT @dead_slot_id = slot_id FROM doctor_time_slots
            WHERE availability_id = @availability_id AND start_time = @start_time AND is_active = 0;

            IF @dead_slot_id IS NOT NULL
            BEGIN
                UPDATE doctor_time_slots
                SET end_time=@end_time, booking_mode=@booking_mode,
                    slot_duration=@slot_duration, max_queue_length=@max_queue_length, is_active=1
                WHERE slot_id = @dead_slot_id;
                SELECT @dead_slot_id AS slot_id;
            END
            ELSE
            BEGIN
                INSERT INTO doctor_time_slots (availability_id, start_time, end_time, booking_mode, slot_duration, max_queue_length)
                VALUES (@availability_id, @start_time, @end_time, @booking_mode, @slot_duration, @max_queue_length);
                SELECT CAST(SCOPE_IDENTITY() AS INT) AS slot_id;
            END
        END
        ELSE
        BEGIN
            UPDATE doctor_time_slots
            SET start_time=@start_time, end_time=@end_time, booking_mode=@booking_mode,
                slot_duration=@slot_duration, max_queue_length=@max_queue_length, is_active=1
            WHERE slot_id = @slot_id AND availability_id = @availability_id;
            SELECT @slot_id AS slot_id;
        END
    END

    IF @operation = 'GET_DAY_SLOT_IDS'
    BEGIN
        SELECT dts.slot_id
        FROM doctor_time_slots dts
        JOIN doctor_availability da ON da.availability_id = dts.availability_id
        WHERE da.doctor_id   = @doctor_id
          AND da.day_of_week = @day_of_week
          AND (da.clinic_id  = @clinic_id OR (@clinic_id IS NULL AND da.clinic_id IS NULL))
          AND dts.is_active  = 1;
    END

    IF @operation = 'COUNT_FUTURE_APPTS_FOR_SLOT'
    BEGIN
        SELECT COUNT(*) AS cnt FROM appointments
        WHERE slot_id = @slot_id AND appointment_date > CAST(GETDATE() AS DATE)
          AND LOWER(status) IN ('booked','in_progress');
    END

    IF @operation = 'CANCEL_FUTURE_APPTS_FOR_SLOT'
    BEGIN
        DECLARE @affected TABLE (appointment_id INT, patient_id INT);
        INSERT INTO @affected SELECT appointment_id, patient_id FROM appointments
        WHERE slot_id = @slot_id AND appointment_date > CAST(GETDATE() AS DATE)
          AND LOWER(status) IN ('booked','in_progress');

        UPDATE appointments SET status='CancleD'
        WHERE appointment_id IN (SELECT appointment_id FROM @affected);

        SELECT CASE WHEN ap.user_type=1 THEN p.token WHEN ap.user_type=2 THEN p2.token END AS fcm_token
        FROM @affected a
        JOIN appointments ap ON ap.appointment_id = a.appointment_id
        LEFT JOIN patients p ON ap.user_type=1 AND p.patient_id=ap.patient_id
        LEFT JOIN family_members fm ON ap.user_type=2 AND fm.member_id=ap.patient_id
        LEFT JOIN patients p2 ON fm.family_id=p2.patient_id
        WHERE COALESCE(CASE WHEN ap.user_type=1 THEN p.token WHEN ap.user_type=2 THEN p2.token END,'') <> '';
    END

    IF @operation = 'DELETE_SLOT'
    BEGIN
        UPDATE doctor_time_slots SET is_active=0 WHERE slot_id=@slot_id;
    END

    IF @operation = 'GET'
    BEGIN
        SELECT da.availability_id, da.day_of_week, da.is_enabled,
               dts.slot_id,
               CONVERT(VARCHAR(5), dts.start_time, 108) AS start_time,
               CONVERT(VARCHAR(5), dts.end_time,   108) AS end_time,
               dts.booking_mode, dts.slot_duration, dts.max_queue_length
        FROM doctor_availability da
        LEFT JOIN doctor_time_slots dts
            ON da.availability_id = dts.availability_id AND dts.is_active = 1
        WHERE da.doctor_id = @doctor_id
          AND (da.clinic_id = @clinic_id OR (@clinic_id IS NULL AND da.clinic_id IS NULL))
        ORDER BY CASE da.day_of_week
            WHEN 'Monday' THEN 1 WHEN 'Tuesday' THEN 2 WHEN 'Wednesday' THEN 3
            WHEN 'Thursday' THEN 4 WHEN 'Friday' THEN 5 WHEN 'Saturday' THEN 6
            WHEN 'Sunday' THEN 7 END, dts.start_time;
    END

    IF @operation = 'RESCHEDULE_FUTURE_APPTS_FOR_SLOT'
    BEGIN
        DECLARE @affectedR TABLE (appointment_id INT, patient_id INT);
        INSERT INTO @affectedR SELECT appointment_id, patient_id FROM appointments
        WHERE slot_id = @slot_id AND appointment_date > CAST(GETDATE() AS DATE)
          AND LOWER(status) IN ('booked','in_progress');

        UPDATE appointments SET status='reschedule'
        WHERE appointment_id IN (SELECT appointment_id FROM @affectedR);

        SELECT p.token FROM @affectedR a
        JOIN patients p ON p.patient_id=a.patient_id
        WHERE p.token IS NOT NULL AND LTRIM(RTRIM(p.token)) <> '';
    END
END
GO

CREATE PROCEDURE [dbo].[sp_family_members]
(
    @operation NVARCHAR(20),

    @member_id INT = NULL,
    @family_id INT = NULL,
    @name NVARCHAR(100) = NULL,
    @Gender_id INT = NULL,
    @relation_id INT = NULL,
    @DOB SMALLDATETIME = NULL,
    @mobile_no NVARCHAR(50) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

---------------------------------------------------------
-- INSERT MEMBER
---------------------------------------------------------
IF @operation = 'Insert'
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.family_members
        (
            family_id,
            name,
            Gender_id,
            relation_id,
            DOB,
            mobile_no
        )
        VALUES
        (
            @family_id,
            @name,
            @Gender_id,
            @relation_id,
            @DOB,
            @mobile_no
        );

        SET @member_id = SCOPE_IDENTITY();

        COMMIT TRANSACTION;

        SELECT @member_id AS member_id;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;

        SELECT 
            ERROR_MESSAGE() AS ErrorMessage,
            ERROR_LINE() AS ErrorLine;
    END CATCH

RETURN;
END

---------------------------------------------------------
-- UPDATE MEMBER
---------------------------------------------------------
IF @operation = 'Update'
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.family_members
        SET
            family_id = @family_id,
            name = @name,
            Gender_id = @Gender_id,
            relation_id = @relation_id,
            DOB = @DOB,
            mobile_no = @mobile_no
        WHERE member_id = @member_id;

        COMMIT TRANSACTION;

        SELECT @member_id AS member_id;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;

        SELECT 
            ERROR_MESSAGE() AS ErrorMessage,
            ERROR_LINE() AS ErrorLine;
    END CATCH

RETURN;
END

---------------------------------------------------------
-- FETCH SINGLE MEMBER
---------------------------------------------------------
IF @operation = 'FetchMember'
BEGIN
    SELECT *
    FROM dbo.family_members
    WHERE member_id = @member_id;

RETURN;
END

---------------------------------------------------------
-- FETCH ALL MEMBERS BY FAMILY
---------------------------------------------------------
IF @operation = 'AllFamilyMembers'
BEGIN
 SELECT 
    fm.member_id,
    fm.family_id,
    fm.name,
    fm.Gender_id,
    g.Gender,          -- ✅ ADD THIS
    fm.relation_id,
    r.relation, -- ✅ ADD THIS
    fm.DOB,
    fm.mobile_no
FROM dbo.family_members fm
LEFT JOIN Gender g ON fm.Gender_id = g.gender_id
LEFT JOIN Relations r ON fm.relation_id = r.relation_id
    WHERE family_id = @family_id;
END
IF @operation = 'DeleteMember'
BEGIN
    BEGIN TRY
        DELETE FROM dbo.family_members
        WHERE member_id = @member_id;

        SELECT 1 AS success, 'Member deleted successfully' AS message;
    END TRY
    BEGIN CATCH
        SELECT 0 AS success, 
               'Member is used in other records, cannot delete.' AS message;
    END CATCH
END

END
GO

CREATE PROCEDURE [dbo].[sp_favorite_doctors]
(
    @operation NVARCHAR(10),
    @patient_id INT,
    @doctor_id INT = NULL,
	 @clinic_id  NVARCHAR(50) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    -- ✅ Insert favorite (avoid duplicate)
    --IF @operation = 'Insert'
    --BEGIN
    --    IF NOT EXISTS (
    --        SELECT 1 FROM favorite_doctors 
    --        WHERE patient_id = @patient_id 
    --          AND doctor_id = @doctor_id
    --    )
    --    BEGIN
    --        INSERT INTO favorite_doctors (patient_id, doctor_id, is_favorite, created_at)
    --        VALUES (@patient_id, @doctor_id, 1, GETDATE());

    --        SELECT 1 AS success, SCOPE_IDENTITY() AS favorite_id, 'Added successfully' AS message;
    --    END
    --    ELSE
    --    BEGIN
    --        SELECT 0 AS success, 'Already added to favorites' AS message;
    --    END
    --END
	 IF @operation = 'Insert'
    BEGIN
        IF NOT EXISTS (
            SELECT 1 FROM favorite_doctors 
            WHERE patient_id = @patient_id 
              AND doctor_id  = @doctor_id
			  AND clinic_id=@clinic_id
        )
        BEGIN
            INSERT INTO favorite_doctors (patient_id, doctor_id, clinic_id, is_favorite, created_at)
            VALUES (@patient_id, @doctor_id, @clinic_id, 1, GETDATE());

            SELECT 1 AS success, SCOPE_IDENTITY() AS favorite_id, 'Added successfully' AS message;
        END
        ELSE
        BEGIN
            ---- Update clinic_id if it was missing
            --UPDATE favorite_doctors
            --SET clinic_id = COALESCE(@clinic_id, clinic_id)
            --WHERE patient_id = @patient_id AND doctor_id = @doctor_id;

            SELECT 0 AS success, 'Already added to favorites' AS message;
        END
    END

    -- ✅ Delete favorite
    ELSE IF @operation = 'Delete'
    BEGIN
        DELETE FROM favorite_doctors
        WHERE patient_id = @patient_id
          AND doctor_id = @doctor_id
		  AND clinic_id=@clinic_id;


        SELECT 1 AS success, 'Deleted successfully' AS message;
    END

    -- ✅ Fetch (2 cases handled)
    ELSE IF @operation = 'Fetch'
    BEGIN
        -- 👉 Case 1: Check single doctor (for heart icon)
        IF @doctor_id IS NOT NULL
        BEGIN
            SELECT 
                CASE 
                    WHEN EXISTS (
                        SELECT 1 FROM favorite_doctors 
                        WHERE patient_id = @patient_id 
                          AND doctor_id = @doctor_id
						  AND clinic_id=@clinic_id
                          AND is_favorite = 1
                    )
                    THEN 1 ELSE 0 
                END AS is_favorite;
        END
        ELSE
        BEGIN
            -- 👉 Case 2: Get all favorite doctors of patient
            SELECT *
            FROM favorite_doctors
            WHERE patient_id = @patient_id
              AND is_favorite = 1
            ORDER BY created_at DESC;
        END
    END
END
GO

CREATE PROCEDURE [dbo].[sp_Medicin_Type]
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

CREATE PROCEDURE [dbo].[sp_Medicine_Master]
    @operation        NVARCHAR(20)  = NULL,
    @medicine_id      INT           = 0,
    @doctor_id        INT           = 0,
    @medicine_name    NVARCHAR(100) = NULL,
    @medicine_type_id INT           = NULL,
    @search_query     NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- ─────────────────────────────────────────────────────────
    -- INSERT: global library + per-doctor link
    -- ─────────────────────────────────────────────────────────
    IF @operation = 'Insert'
    BEGIN
        DECLARE @medId INT;

        -- 1. Medicine_Master madhe (name+type) ahe ka check
        SELECT @medId = medicine_id 
        FROM dbo.Medicine_Master
        WHERE medicine_name    = @medicine_name 
          AND medicine_type_id = @medicine_type_id;

        -- 2. Naselich tar global library madhe insert
        IF @medId IS NULL
        BEGIN
            INSERT INTO dbo.Medicine_Master (medicine_name, medicine_type_id)
            VALUES (@medicine_name, @medicine_type_id);
            SET @medId = SCOPE_IDENTITY();
        END

        -- 3. Already active link asla → duplicate prevent
        IF EXISTS (
            SELECT 1 FROM dbo.Doctor_Medicine
            WHERE doctor_id   = @doctor_id 
              AND medicine_id = @medId 
              AND is_active   = 1
        )
        BEGIN
            SELECT 'Medicine already in your list.' AS Message;
            RETURN;
        END

        -- 4. Soft-deleted link asla → reactivate
        IF EXISTS (
            SELECT 1 FROM dbo.Doctor_Medicine
            WHERE doctor_id   = @doctor_id 
              AND medicine_id = @medId 
              AND is_active   = 0
        )
        BEGIN
            UPDATE dbo.Doctor_Medicine
            SET    is_active = 1
            WHERE  doctor_id   = @doctor_id 
              AND  medicine_id = @medId;

            SELECT 'Medicine reactivated.' AS Message;
            RETURN;
        END

        -- 5. Navin link insert
        INSERT INTO dbo.Doctor_Medicine (doctor_id, medicine_id, is_active)
        VALUES (@doctor_id, @medId, 1);

        SELECT 'Medicine added successfully.' AS Message;
    END

    -- ─────────────────────────────────────────────────────────
    -- GET MEDICINE TYPES
    -- ─────────────────────────────────────────────────────────
    IF @operation = 'getMedicineTypes'
    BEGIN
        SELECT * FROM dbo.Medicine_Type;
    END

    -- ─────────────────────────────────────────────────────────
    -- FETCH ALL MEDICINES (per doctor list)
    -- ─────────────────────────────────────────────────────────
    IF @operation = 'fetchAllMedicines'
    BEGIN
        SELECT
            m.medicine_id,
            dm.doctor_id,
            m.medicine_name,
            m.medicine_type_id,
            t.Medi_Type_Name
        FROM   dbo.Doctor_Medicine dm
        INNER JOIN dbo.Medicine_Master m ON dm.medicine_id    = m.medicine_id
        INNER JOIN dbo.Medicine_Type   t ON m.medicine_type_id = t.medicine_type_id
        WHERE  dm.doctor_id = @doctor_id
          AND  dm.is_active = 1
        ORDER BY m.medicine_name;
    END

    -- ─────────────────────────────────────────────────────────
    -- GET SUGGESTIONS (NEW — global library madhun typing veli)
    -- ─────────────────────────────────────────────────────────
    IF @operation = 'getSuggestions'
    BEGIN
        SELECT TOP 20
            m.medicine_id,
            m.medicine_name,
            m.medicine_type_id,
            t.Medi_Type_Name
        FROM   dbo.Medicine_Master m
        INNER JOIN dbo.Medicine_Type t ON m.medicine_type_id = t.medicine_type_id
        WHERE  m.medicine_name LIKE @search_query + '%'
        ORDER BY m.medicine_name;
    END

    -- ─────────────────────────────────────────────────────────
    -- DELETE (per-doctor soft delete; library la touch nahi)
    -- ─────────────────────────────────────────────────────────
    IF @operation = 'Delete'
    BEGIN
        UPDATE dbo.Doctor_Medicine
        SET    is_active = 0
        WHERE  medicine_id = @medicine_id
          AND  doctor_id   = @doctor_id
          AND  is_active   = 1;

        IF @@ROWCOUNT > 0
            SELECT 'Medicine removed from your list.' AS Message;
        ELSE
            SELECT 'No medicine found to delete.' AS Message;
    END
END
GO

CREATE PROCEDURE [dbo].[sp_notification]
    @operation       VARCHAR(40),
    @notification_id INT            = NULL,
    @patient_id      INT            = NULL,
    @title           NVARCHAR(200)  = NULL,
    @body            NVARCHAR(1000) = NULL,
    @type            VARCHAR(40)    = NULL,
    @ref_id          VARCHAR(40)    = NULL,
    -- Appointment-context lookup params
    @slot_id         INT            = NULL,
    @doctor_id       INT            = NULL,
    @queue_id        INT            = NULL,
    @from_date       DATE           = NULL,
    @to_date         DATE           = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @operation = 'INSERT'
    BEGIN
        IF @patient_id IS NULL OR @title IS NULL OR @body IS NULL OR @type IS NULL
        BEGIN
            SELECT 0 AS success, 'patient_id, title, body and type are required' AS message;
            RETURN;
        END

        INSERT INTO notifications (patient_id, title, body, type, ref_id)
        VALUES (@patient_id, @title, @body, @type, @ref_id);

        SELECT 1 AS success,
               SCOPE_IDENTITY() AS notification_id,
               'Notification stored' AS message;
        RETURN;
    END

    IF @operation = 'LIST'
    BEGIN
        SELECT  notification_id, patient_id, title, body, type, ref_id, is_read, created_at
        FROM    notifications
        WHERE   patient_id = @patient_id
        ORDER BY created_at DESC;
        RETURN;
    END

    IF @operation = 'MARK_READ'
    BEGIN
        UPDATE notifications
        SET    is_read = 1
        WHERE  notification_id = @notification_id AND patient_id = @patient_id;
        SELECT 1 AS success, 'Marked as read' AS message;
        RETURN;
    END

    IF @operation = 'MARK_ALL_READ'
    BEGIN
        UPDATE notifications
        SET    is_read = 1
        WHERE  patient_id = @patient_id AND is_read = 0;
        SELECT 1 AS success, 'All marked as read' AS message;
        RETURN;
    END

    -- ── Appointment context lookups for personalized cancellation notifications ──

    IF @operation = 'APPT_CONTEXT_SLOT'
    BEGIN
        SELECT a.appointment_id,
               a.appointment_date,
               a.start_time,
               CASE WHEN a.user_type = 1 THEN p.patient_id ELSE p2.patient_id END AS owner_id,
               CASE WHEN a.user_type = 1 THEN p.token      ELSE p2.token      END AS owner_token,
               d.name AS doctor_name
        FROM appointments a
        LEFT JOIN patients p        ON a.user_type = 1 AND p.patient_id = a.patient_id
        LEFT JOIN family_members fm ON a.user_type = 2 AND fm.member_id = a.patient_id
        LEFT JOIN patients p2       ON fm.family_id = p2.patient_id
        LEFT JOIN doctor_login d    ON d.doctor_id  = a.doctor_id
        WHERE a.slot_id = @slot_id
          AND a.appointment_date >= CAST(GETDATE() AS DATE)
          AND a.status IN ('booked', 'in_progress');
        RETURN;
    END

    IF @operation = 'APPT_CONTEXT_DOCTOR_RANGE'
    BEGIN
        SELECT a.appointment_id,
               a.appointment_date,
               a.start_time,
               CASE WHEN a.user_type = 1 THEN p.patient_id ELSE p2.patient_id END AS owner_id,
               CASE WHEN a.user_type = 1 THEN p.token      ELSE p2.token      END AS owner_token,
               d.name AS doctor_name
        FROM appointments a
        LEFT JOIN patients p        ON a.user_type = 1 AND p.patient_id = a.patient_id
        LEFT JOIN family_members fm ON a.user_type = 2 AND fm.member_id = a.patient_id
        LEFT JOIN patients p2       ON fm.family_id = p2.patient_id
        LEFT JOIN doctor_login d    ON d.doctor_id  = a.doctor_id
        WHERE a.doctor_id = @doctor_id
          AND a.appointment_date BETWEEN @from_date AND @to_date
          AND a.status IN ('booked', 'in_progress');
        RETURN;
    END

    IF @operation = 'APPT_CONTEXT_QUEUE'
    BEGIN
        DECLARE @qstop_time TIME;
        SELECT  @qstop_time = ts.start_time
        FROM    doctor_queue dq
        INNER JOIN doctor_time_slots ts ON dq.slot_id = ts.slot_id
        WHERE   dq.queue_id = @queue_id;

        SELECT a.appointment_id,
               a.appointment_date,
               a.start_time,
               CASE WHEN a.user_type = 1 THEN p.patient_id ELSE p2.patient_id END AS owner_id,
               CASE WHEN a.user_type = 1 THEN p.token      ELSE p2.token      END AS owner_token,
               d.name AS doctor_name
        FROM appointments a
        LEFT JOIN patients p        ON a.user_type = 1 AND p.patient_id = a.patient_id
        LEFT JOIN family_members fm ON a.user_type = 2 AND fm.member_id = a.patient_id
        LEFT JOIN patients p2       ON fm.family_id = p2.patient_id
        LEFT JOIN doctor_login d    ON d.doctor_id  = a.doctor_id
        WHERE a.doctor_id = @doctor_id
          AND a.appointment_date = CAST(GETDATE() AS DATE)
          AND a.status IN ('booked', 'skipped')
          AND (
                a.queue_id = @queue_id
                OR (a.booking_type = 2 AND a.start_time < @qstop_time)
              );
        RETURN;
    END

    SELECT 0 AS success, 'Unknown operation' AS message;
END
GO

CREATE   PROCEDURE [dbo].[sp_otp]
    @operation VARCHAR(20),
    @mobile_no VARCHAR(15),
    @otp_hash VARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -----------------------------------------
    -- SEND OTP
    -----------------------------------------
    IF @operation = 'send_otp'
    BEGIN
        -- Rate limit: max 3 OTP in last 10 min
        IF (
            SELECT COUNT(*) 
            FROM otp_verification
            WHERE mobile_no = @mobile_no
            AND created_at > DATEADD(MINUTE, -10, GETDATE())
        ) >= 3
        BEGIN
            SELECT 0 AS status, 'Too many OTP requests. Try later.' AS message;
            RETURN;
        END

        -- Delete old OTPs (optional cleanup)
        DELETE FROM otp_verification 
        WHERE mobile_no = @mobile_no;

        -- Insert new OTP
        INSERT INTO otp_verification (
            mobile_no, otp_hash, expires_at
        )
        VALUES (
            @mobile_no,
            @otp_hash,
            DATEADD(MINUTE, 5, GETDATE()) -- 5 min expiry
        );

        SELECT 1 AS status, 'OTP sent successfully' AS message;
    END

    -----------------------------------------
    -- VERIFY OTP
    -----------------------------------------
    ELSE IF @operation = 'verify_otp'
    BEGIN
        DECLARE @id INT,
                @db_otp_hash VARCHAR(255),
                @expires_at DATETIME,
                @attempts INT,
                @is_verified BIT;

        -- Get latest OTP
        SELECT TOP 1
            @id = id,
            @db_otp_hash = otp_hash,
            @expires_at = expires_at,
            @attempts = attempts,
            @is_verified = is_verified
        FROM otp_verification
        WHERE mobile_no = @mobile_no
        ORDER BY created_at DESC;

        IF @id IS NULL
        BEGIN
            SELECT 0 AS status, 'OTP not found' AS message;
            RETURN;
        END

        IF @is_verified = 1
        BEGIN
            SELECT 0 AS status, 'OTP already used' AS message;
            RETURN;
        END

        IF @expires_at < GETDATE()
        BEGIN
            SELECT 0 AS status, 'OTP expired' AS message;
            RETURN;
        END

        IF @attempts >= 5
        BEGIN
            SELECT 0 AS status, 'Too many attempts. Try again later.' AS message;
            RETURN;
        END

        -- Return hash to Node.js for comparison
        SELECT 
            1 AS status,
            @id AS otp_id,
            @db_otp_hash AS otp_hash,
            @attempts AS attempts;
    END

    -----------------------------------------
    -- UPDATE ATTEMPTS
    -----------------------------------------
    ELSE IF @operation = 'update_attempt'
    BEGIN
        UPDATE otp_verification
        SET attempts = attempts + 1
        WHERE mobile_no = @mobile_no;

        SELECT 1 AS status;
    END

    -----------------------------------------
    -- MARK VERIFIED
    -----------------------------------------
    ELSE IF @operation = 'mark_verified'
    BEGIN
        UPDATE otp_verification
        SET is_verified = 1
        WHERE mobile_no = @mobile_no;

        SELECT 1 AS status;
    END
END
GO

CREATE PROCEDURE [dbo].[sp_patients]
(
    @operation NVARCHAR(50),
    @patient_id INT = NULL,
    @mobile_no NVARCHAR(50) = NULL,
    @name NVARCHAR(100) = NULL,
    @Address NVARCHAR(100) = NULL,
    @email NVARCHAR(100) = NULL,
    @gender_id INT = NULL,
    @DOB SMALLDATETIME = NULL,
    @blood_group_id INT = NULL,
    @height NVARCHAR(50) = NULL,
    @weight DECIMAL(6, 2) = NULL,
    @doctor_id int = Null,
	@img_url  NVARCHAR(MAX) = NULL,
	@clinic_id   NVARCHAR(20) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    ---------------------------------------------------------
    -- INSERT PATIENT
    ---------------------------------------------------------
    IF @operation = 'Insert'
    BEGIN
        BEGIN TRY
            BEGIN TRANSACTION;
			--------------------------------------------------
        -- CHECK MOBILE ALREADY EXISTS
        --------------------------------------------------
        IF EXISTS (
            SELECT 1
            FROM dbo.Patients
            WHERE mobile_no = @mobile_no
            AND active_status = 1
        )
        BEGIN
            SELECT
                0 AS success,
                'Mobile number already exists' AS message;

            ROLLBACK TRANSACTION;
            RETURN;
        END


            INSERT INTO dbo.Patients
            (
                name,
                mobile_no,
                email,
                Address,
                gender_id,
                DOB,
                blood_group_id,
                weight,
                role_id,
                active_status
            )
            VALUES
            (   @name,
                @mobile_no,
                @email,
                @Address,
                @gender_id,
                @DOB,
                @blood_group_id,
                @weight,
                2, -- patient role
                1  -- active
            );

            SET @patient_id = SCOPE_IDENTITY();

            COMMIT TRANSACTION;

            SELECT @patient_id AS patient_id;

        END TRY
        BEGIN CATCH
            ROLLBACK TRANSACTION;

            SELECT ERROR_MESSAGE() AS ErrorMessage,
                   ERROR_LINE() AS ErrorLine;
        END CATCH

        RETURN;
    END

    ---------------------------------------------------------
    -- UPDATE PATIENT
    ---------------------------------------------------------
    IF @operation = 'Update'
    BEGIN
        BEGIN TRY
            BEGIN TRANSACTION;

            UPDATE dbo.Patients
            SET name = @name,
                mobile_no = @mobile_no,
                email = @email,
                Address = @Address,
                gender_id = @gender_id,
                DOB = @DOB,
                blood_group_id = @blood_group_id,
                weight = @weight
            WHERE patient_id = @patient_id;

            COMMIT TRANSACTION;

            SELECT @patient_id AS patient_id;

        END TRY
        BEGIN CATCH
            ROLLBACK TRANSACTION;

            SELECT ERROR_MESSAGE() AS ErrorMessage,
                   ERROR_LINE() AS ErrorLine;
        END CATCH

        RETURN;
    END

    ---------------------------------------------------------
    -- FETCH PATIENT
    ---------------------------------------------------------
    IF @operation = 'FetchPatient'
    BEGIN
        SELECT *
        FROM dbo.Patients
        WHERE mobile_no = @mobile_no
              AND active_status = 1;

        RETURN;
    END

    ---------------------------------------------------------
    -- FETCH ALL PATIENTS
    ---------------------------------------------------------
    IF @operation = 'FetchPatients'
    BEGIN
        SELECT *
        FROM dbo.Patients
        WHERE active_status = 1;
    END

    ---------------------------------------------------------
    -- DELETE (Soft Delete)
    ---------------------------------------------------------
    IF @operation = 'DeletePatient'
    BEGIN
        UPDATE dbo.Patients
        SET active_status = 0
        WHERE patient_id = @patient_id;

        SELECT 1 AS success,
               'Patient deleted successfully' AS message;
    END

    ---------------------------------------------------------
    -- CHECK PHONE
    ---------------------------------------------------------
    IF @operation = 'check_phone_patient'
    BEGIN
        SELECT *
        FROM dbo.patient_login_vw
        WHERE mobile_no = @mobile_no;
    END

IF @operation = 'getDoctors'
BEGIN
    SELECT
        d.*,

        --------------------------------------------------
        -- CURRENT QUEUE LENGTH (appointments based)
        --------------------------------------------------
        (
            SELECT COUNT(*)
            FROM appointments a
            WHERE a.doctor_id = d.doctor_id
                  AND a.booking_type = 1
                  AND a.status = 'booked'
                  AND a.appointment_date = CAST(GETDATE() AS DATE)
        ) AS queue_length,

        qb.is_queue_available,
        qb.is_booking_started,
        qb.current_queue_length,
        qb.max_queue_length,
        qb.is_queue_full,
        qb.booking_start_time,

        --------------------------------------------------
        -- SLOT AVAILABILITY
        --------------------------------------------------
        sa.is_slot_available,

        --------------------------------------------------
        -- RECENTLY VISITED
        --------------------------------------------------
        CASE
            WHEN EXISTS
            (
                SELECT 1
                FROM appointments a2
                WHERE a2.doctor_id = d.doctor_id
                      AND a2.patient_id = @patient_id
                      AND a2.status = 'completed'
                      AND a2.appointment_date >= DATEADD(MONTH, -1, CAST(GETDATE() AS DATE))
            )
            THEN 1 ELSE 0
        END AS is_recently_visited,
	        --------------------------------------------------
        -- RATING + REVIEW COUNT (clinic-wise)
        --------------------------------------------------
        (
            SELECT AVG(CAST(rv.rating AS FLOAT))
            FROM reviews rv
            WHERE rv.doctor_id = d.doctor_id
              AND (rv.clinic_id = d.clinic_id OR rv.clinic_id IS NULL)
        ) AS rating,
        (
            SELECT COUNT(*)
            FROM reviews rv
            WHERE rv.doctor_id = d.doctor_id
              AND (rv.clinic_id = d.clinic_id OR rv.clinic_id IS NULL)
        ) AS review_count


    FROM doctor_login_vw d

    --------------------------------------------------
    -- ONLY VERIFIED DOCTORS
    --------------------------------------------------
    INNER JOIN doctor_login dl_main
        ON dl_main.doctor_id = d.doctor_id
        AND dl_main.is_verified = 0

    --------------------------------------------------
    -- QUEUE LOGIC (WITH END TIME CHECK)
    --------------------------------------------------
    OUTER APPLY
    (
        SELECT TOP 1

            --------------------------------------------------
            -- QUEUE AVAILABLE (WITH START + END WINDOW)
            --------------------------------------------------
            CASE
                WHEN GETDATE() BETWEEN
                    DATETIMEFROMPARTS(
                        YEAR(GETDATE()),
                        MONTH(GETDATE()),
                        DAY(GETDATE()),
                        DATEPART(HOUR, ts.start_time),
                        DATEPART(MINUTE, ts.start_time),
                        0,0
                    )
                    AND
                    DATETIMEFROMPARTS(
                        YEAR(GETDATE()),
                        MONTH(GETDATE()),
                        DAY(GETDATE()),
                        DATEPART(HOUR, ts.end_time),
                        DATEPART(MINUTE, ts.end_time),
                        0,0
                    )
                THEN 1
                ELSE 0
            END AS is_queue_available,

            --------------------------------------------------
            -- BOOKING START TIME
            --------------------------------------------------
            FORMAT(
                DATEADD(MINUTE,
                    -ISNULL(dl.q_start_before,0),
                    DATETIMEFROMPARTS(
                        YEAR(GETDATE()),
                        MONTH(GETDATE()),
                        DAY(GETDATE()),
                        DATEPART(HOUR, ts.start_time),
                        DATEPART(MINUTE, ts.start_time),
                        0,0
                    )
                ),
                'hh:mm tt'
            ) AS booking_start_time,

            --------------------------------------------------
            -- BOOKING STARTED
            --------------------------------------------------
            CASE
                WHEN GETDATE() >= DATEADD(MINUTE,
                    -ISNULL(dl.q_start_before,0),
                    DATETIMEFROMPARTS(
                        YEAR(GETDATE()),
                        MONTH(GETDATE()),
                        DAY(GETDATE()),
                        DATEPART(HOUR, ts.start_time),
                        DATEPART(MINUTE, ts.start_time),
                        0,0
                    )
                )
                THEN 1 ELSE 0
            END AS is_booking_started,

            --------------------------------------------------
            -- PENDING QUEUE (excludes completed/cancelled/skipped)
            --------------------------------------------------
            --(
            --    SELECT COUNT(*)
            --    FROM appointments a3
            --    JOIN doctor_time_slots ts3b
            --        ON ts3b.slot_id = a3.slot_id
            --    JOIN doctor_availability da3b
            --        ON da3b.availability_id = ts3b.availability_id
            --    WHERE a3.doctor_id = d.doctor_id
            --          AND a3.booking_type = 1
            --          AND a3.appointment_date = CAST(GETDATE() AS DATE)
            --          AND a3.status NOT IN ('completed', 'cancelled', 'cancled', 'skipped')
            --          AND (da3b.clinic_id = d.clinic_id OR da3b.clinic_id IS NULL)
            --) AS current_queue_length,

--			(
--    SELECT COUNT(*)
--    FROM appointments a3
--    JOIN doctor_time_slots ts3b
--        ON ts3b.slot_id = a3.slot_id
--    JOIN doctor_availability da3b
--        ON da3b.availability_id = ts3b.availability_id
--    LEFT JOIN doctor_queue dq3b
--        ON dq3b.queue_id = a3.queue_id
--    WHERE a3.doctor_id = d.doctor_id
--          AND a3.booking_type = 1
--          AND a3.appointment_date = CAST(GETDATE() AS DATE)
--          AND a3.status NOT IN ('completed', 'cancelled', 'cancled', 'skipped')
--          AND (da3b.clinic_id = d.clinic_id OR da3b.clinic_id IS NULL)
--          AND (dq3b.queue_status IS NULL OR dq3b.queue_status <> 3)
--) AS current_queue_length,

            --------------------------------------------------
            -- PENDING QUEUE (excludes completed/cancelled/skipped,
            -- and excludes queues the doctor has stopped or closed booking on)
            --------------------------------------------------
            (
                SELECT COUNT(*)
                FROM appointments a3
                JOIN doctor_time_slots ts3b
                    ON ts3b.slot_id = a3.slot_id
                JOIN doctor_availability da3b
                    ON da3b.availability_id = ts3b.availability_id
                LEFT JOIN doctor_queue dq3b
                    ON dq3b.queue_id = a3.queue_id
                WHERE a3.doctor_id = d.doctor_id
                      AND a3.booking_type = 1
                      AND a3.appointment_date = CAST(GETDATE() AS DATE)
                      AND a3.status NOT IN ('completed', 'cancelled', 'cancled', 'skipped')
                      AND (da3b.clinic_id = d.clinic_id OR da3b.clinic_id IS NULL)
                      AND (dq3b.queue_status IS NULL OR dq3b.queue_status <> 3)
                      AND ISNULL(dq3b.booking_closed, 0) = 0
            ) AS current_queue_length,


            --------------------------------------------------
            -- MAX QUEUE
            --------------------------------------------------
            (
                SELECT SUM(ISNULL(ts2.max_queue_length,0))
                FROM doctor_availability da2
                JOIN doctor_time_slots ts2
                    ON da2.availability_id = ts2.availability_id
				WHERE da2.doctor_id = d.doctor_id
      AND (da2.clinic_id = d.clinic_id OR da2.clinic_id IS NULL)
      AND da2.is_enabled = 1
      AND ts2.is_active = 1
      AND ts2.is_deleted = 0
      AND da2.day_of_week = DATENAME(WEEKDAY, GETDATE())
      AND ts2.booking_mode IN (1,3)
            ) AS max_queue_length,

	 CASE
    WHEN
    (
        SELECT COUNT(*)
        FROM doctor_time_slots ts3
        JOIN doctor_availability da3 ON ts3.availability_id = da3.availability_id
        WHERE da3.doctor_id = d.doctor_id
          AND (da3.clinic_id = d.clinic_id OR da3.clinic_id IS NULL)
          AND da3.is_enabled = 1
          AND ts3.is_active = 1
          AND ts3.is_deleted = 0
          AND da3.day_of_week = DATENAME(WEEKDAY, GETDATE())
          AND ts3.booking_mode IN (1,3)
    ) > 0
    AND
    (
        SELECT COUNT(*)
        FROM doctor_time_slots ts3
        JOIN doctor_availability da3 ON ts3.availability_id = da3.availability_id
        LEFT JOIN doctor_queue dq3
            ON dq3.doctor_id = d.doctor_id
            AND dq3.queue_date = CAST(GETDATE() AS DATE)
            AND dq3.slot_id = ts3.slot_id
        WHERE da3.doctor_id = d.doctor_id
          AND (da3.clinic_id = d.clinic_id OR da3.clinic_id IS NULL)
          AND da3.is_enabled = 1
          AND ts3.is_active = 1
          AND ts3.is_deleted = 0
          AND da3.day_of_week = DATENAME(WEEKDAY, GETDATE())
          AND ts3.booking_mode IN (1,3)
				  AND (ts3.max_queue_length IS NULL OR ISNULL(dq3.total_queue,0) < ts3.max_queue_length)

    ) = 0
    THEN 1 ELSE 0
END AS is_queue_full


        FROM doctor_availability da
        JOIN doctor_time_slots ts
            ON da.availability_id = ts.availability_id

        LEFT JOIN doctor_login dl
            ON dl.doctor_id = d.doctor_id

		WHERE da.doctor_id = d.doctor_id
  AND (da.clinic_id = d.clinic_id OR da.clinic_id IS NULL)
  AND da.is_enabled = 1
  AND ts.is_active = 1
  AND ts.is_deleted = 0
  AND da.day_of_week = DATENAME(WEEKDAY, GETDATE())
  AND ts.booking_mode IN (1,3)

        ORDER BY
            CASE WHEN GETDATE() BETWEEN
                DATETIMEFROMPARTS(YEAR(GETDATE()),MONTH(GETDATE()),DAY(GETDATE()),
                    DATEPART(HOUR, ts.start_time),DATEPART(MINUTE, ts.start_time),0,0)
                AND
                DATETIMEFROMPARTS(YEAR(GETDATE()),MONTH(GETDATE()),DAY(GETDATE()),
                    DATEPART(HOUR, ts.end_time),DATEPART(MINUTE, ts.end_time),0,0)
            THEN 0 ELSE 1 END,
            ts.start_time
    ) qb

    --------------------------------------------------
    -- SLOT AVAILABILITY (ANY DAY)
    --------------------------------------------------
    OUTER APPLY
    (
        SELECT TOP 1
            CASE
                WHEN EXISTS
                (
                    SELECT 1
                    FROM doctor_availability da2
                    JOIN doctor_time_slots ts2
                        ON da2.availability_id = ts2.availability_id
                    WHERE da2.doctor_id = d.doctor_id
                          AND da2.is_enabled = 1
                          AND ts2.booking_mode IN (2,3)
                )
                THEN 1 ELSE 0
            END AS is_slot_available
    ) sa
	  WHERE d.active_status = 0;
END
IF @operation = 'doctor_availability'
BEGIN
    SELECT *
    FROM doctor_availability_vw
    WHERE doctor_id = @doctor_id
      AND clinic_id = @clinic_id ;
END




---------------------------------------------------------
-- CHECK PHONE
---------------------------------------------------------
IF @operation = 'patient_mobile_exist'

BEGIN
    SELECT
        patient_id,
        mobile_no
      FROM dbo.patients
      WHERE mobile_no = @mobile_no;
    RETURN;
END


-- DOCTOR IMAGE
IF @operation = 'uploadPatientImg'
BEGIN
    UPDATE Patients
    SET img_url = @img_url
    WHERE patient_id = @patient_id;

    RETURN;
END



END
GO

-- Step 2: Create fresh
CREATE PROCEDURE [dbo].[sp_prescription]
(
    @operation          NVARCHAR(50)  = NULL,
    @prescription_id    INT           = 0,
    @patient_id         INT           = 0,
    @doctor_id          INT           = NULL,
    @prescription_date  DATETIME      = NULL,
    @symptoms           NVARCHAR(MAX) = NULL,
    @diagnosis          NVARCHAR(MAX) = NULL,
    @clinical_notes     NVARCHAR(MAX) = NULL,
    @follow_up_date     DATE          = NULL,
    @advice             NVARCHAR(MAX) = NULL,
    @created_at         DATETIME      = NULL,
	 @user_type    INT           = 0,
    @presc_med_id       INT           = 0,
    @medicine_id        INT           = NULL,
    @medicine_type_id   INT           = NULL,
    @frequency          VARCHAR(50)   = NULL,
    @duration           VARCHAR(50)   = NULL,
    @timing             VARCHAR(50)   = NULL,
    @tablet_dosage      VARCHAR(20)   = NULL,
    @syrup_dosage_ml    VARCHAR(20)   = NULL,
    @inj_dosage         VARCHAR(20)   = NULL,
    @inj_route          VARCHAR(20)   = NULL,
    @drops_count        VARCHAR(10)   = NULL,
    @drops_application  VARCHAR(20)   = NULL,
    @lotion_apply_area  VARCHAR(50)   = NULL,
    @spray_puffs        VARCHAR(20)   = NULL,
    @spray_usage        VARCHAR(20)   = NULL,
	@lotion_usage      VARCHAR(50)   = NULL,
    @powder_dosage      VARCHAR(20)   = NULL,
    @powder_form        VARCHAR(50)   = NULL,
    @inhaler_puffs      VARCHAR(20)   = NULL,
    @inhaler_type       VARCHAR(30)   = NULL,
    @inhaler_technique  VARCHAR(50)   = NULL,
    @inhaler_usage      VARCHAR(50)   = NULL,
	@appointment_id INT=0,
	@clinic_id NVARCHAR(20) = NULL

)
AS
BEGIN
    SET NOCOUNT ON;
	

 IF @operation = 'Insert'
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        IF @prescription_id = 0
        BEGIN
            INSERT INTO dbo.patient_records
            (patient_id, doctor_id, prescription_date, symptoms, diagnosis,
             clinical_notes, follow_up_date, advice, created_at, user_type, appointment_id,clinic_id)
            VALUES
            (@patient_id, @doctor_id, ISNULL(@prescription_date, GETDATE()),
             @symptoms, @diagnosis, @clinical_notes, @follow_up_date,
             @advice, ISNULL(@created_at, GETDATE()), @user_type, @appointment_id,@clinic_id);

            SET @prescription_id = SCOPE_IDENTITY();
        END

        IF @medicine_id IS NOT NULL
        BEGIN
            INSERT INTO dbo.PrescriptionMedicine
                (prescription_id, medicine_id, medicine_type_id, frequency, duration,
                 timing, tablet_dosage, syrup_dosage_ml, inj_dosage, inj_route,
                 drops_count, drops_application, lotion_apply_area, spray_puffs,
                 spray_usage, lotion_usage,
                 powder_dosage, powder_form,
                 inhaler_puffs, inhaler_type, inhaler_technique, inhaler_usage)
                VALUES
                (@prescription_id, @medicine_id, @medicine_type_id, @frequency, @duration,
                 @timing, @tablet_dosage, @syrup_dosage_ml, @inj_dosage, @inj_route,
                 @drops_count, @drops_application, @lotion_apply_area, @spray_puffs,
                 @spray_usage, @lotion_usage,
                 @powder_dosage, @powder_form,
                 @inhaler_puffs, @inhaler_type, @inhaler_technique, @inhaler_usage);
        END

        --------------------------------------------------
        -- 🔥 GET TOKEN (PATIENT / FAMILY)
        --------------------------------------------------
        DECLARE @token NVARCHAR(MAX) = NULL;

        IF @user_type = 1
        BEGIN
            SELECT @token = token
            FROM patients
            WHERE patient_id = @patient_id;
        END
        ELSE IF @user_type = 2
        BEGIN
            SELECT @token = p.token
            FROM family_members fm
            JOIN patients p ON fm.family_id = p.patient_id
            WHERE fm.member_id = @patient_id;
        END

        COMMIT TRANSACTION;

        --------------------------------------------------
        -- ✅ FINAL RESPONSE
        --------------------------------------------------
        SELECT 
            1 AS success,
            'Prescription created' AS message,
            @prescription_id AS prescription_id,
            @token AS token;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;

        SELECT 
            0 AS success,
            ERROR_MESSAGE() AS message,
            NULL AS prescription_id,
            NULL AS token;
    END CATCH
END

    IF @operation = 'Update'
    BEGIN
        BEGIN TRY
            BEGIN TRANSACTION;
            UPDATE dbo.patient_records
            SET patient_id=@patient_id, doctor_id=@doctor_id,
                prescription_date=@prescription_date, symptoms=@symptoms,
                diagnosis=@diagnosis, clinical_notes=@clinical_notes,
                follow_up_date=@follow_up_date, advice=@advice, created_at=@created_at,user_type=@user_type,appointment_id=@appointment_id
            WHERE prescription_id = @prescription_id;
            UPDATE dbo.PrescriptionMedicine
           SET medicine_id=@medicine_id, medicine_type_id=@medicine_type_id,
                frequency=@frequency, duration=@duration, timing=@timing,
                tablet_dosage=@tablet_dosage, syrup_dosage_ml=@syrup_dosage_ml,
                inj_dosage=@inj_dosage, inj_route=@inj_route,
                drops_count=@drops_count, drops_application=@drops_application,
                lotion_apply_area=@lotion_apply_area, spray_puffs=@spray_puffs,
                spray_usage=@spray_usage, lotion_usage=@lotion_usage,
                powder_dosage=@powder_dosage, powder_form=@powder_form,
                inhaler_puffs=@inhaler_puffs, inhaler_type=@inhaler_type,
                inhaler_technique=@inhaler_technique, inhaler_usage=@inhaler_usage
            WHERE presc_med_id = @presc_med_id;
            COMMIT TRANSACTION;
            SELECT @prescription_id AS prescription_id;
        END TRY
        BEGIN CATCH
            ROLLBACK TRANSACTION;
            SELECT ERROR_MESSAGE() AS ErrorMessage, ERROR_LINE() AS ErrorLine;
        END CATCH
    END

    IF @operation = 'Fetch'
    BEGIN
        SELECT * FROM dbo.patient_records 
        WHERE prescription_id = @prescription_id;
        
        SELECT * FROM dbo.PrescriptionMedicine 
        WHERE prescription_id = @prescription_id;
    END

    IF @operation = 'Delete'
    BEGIN
        BEGIN TRY
            BEGIN TRANSACTION;
            DELETE FROM dbo.PrescriptionMedicine 
            WHERE prescription_id = @prescription_id;
            DELETE FROM dbo.patient_records 
            WHERE prescription_id = @prescription_id;
            COMMIT TRANSACTION;
            SELECT 1 AS success, 'Prescription deleted successfully' AS message;
        END TRY
        BEGIN CATCH
            ROLLBACK TRANSACTION;
            SELECT ERROR_MESSAGE() AS ErrorMessage, ERROR_LINE() AS ErrorLine;
        END CATCH
    END


	IF @operation = 'FollowUpReminders'
BEGIN
    SELECT
        pr.prescription_id,
        pr.appointment_id,
        pr.doctor_id,
        pr.follow_up_date,
        CASE
            WHEN pr.follow_up_date = CAST(GETDATE() AS DATE)
                THEN 'day_of'
            WHEN pr.follow_up_date = CAST(DATEADD(DAY, 1, GETDATE()) AS DATE)
                THEN 'day_before'
        END AS reminder_kind,
        (SELECT TOP 1 v.doctor_name
           FROM dbo.prescription_vw v
          WHERE v.prescription_id = pr.prescription_id) AS doctor_name,
        CASE
            WHEN pr.user_type = 1 THEN p1.token
            WHEN pr.user_type = 2 THEN p2.token
        END AS patient_token
    FROM dbo.patient_records pr
    LEFT JOIN patients p1
           ON pr.user_type = 1 AND p1.patient_id = pr.patient_id
    LEFT JOIN family_members fm
           ON pr.user_type = 2 AND fm.member_id = pr.patient_id
    LEFT JOIN patients p2
           ON pr.user_type = 2 AND p2.patient_id = fm.family_id
    WHERE pr.follow_up_date IN (
              CAST(GETDATE() AS DATE),
              CAST(DATEADD(DAY, 1, GETDATE()) AS DATE)
          );
END


-- Prescription List (1 per prescription)
IF @operation = 'PatientPrescriptionList'
BEGIN
    SELECT DISTINCT
        prescription_id,
        patient_id,
        patient_name,
        user_type,
        user_type_name,

        doctor_id,
        doctor_name as name,
        qualification,
        specialization,

        prescription_date,
        symptoms,
        diagnosis,
        clinical_notes,
        follow_up_date,
        advice,
        created_at,

        clinic_name,
        clinic_address,
        clinic_contact

    FROM dbo.prescription_vw

    WHERE 
        -- 👤 Self
        patient_id = @patient_id
        
        OR 
        
        -- 👨‍👩‍👧 Family Members
        patient_id IN (
            SELECT member_id 
            FROM family_members 
            WHERE family_id = @patient_id
        )

    ORDER BY prescription_date DESC
END


-- Prescription Detail
ELSE IF @operation = 'PrescriptionDetail'
BEGIN
    SELECT *
    FROM dbo.prescription_vw
    WHERE prescription_id = @prescription_id
END

-- Appointment Wise
ELSE IF @operation = 'AppointmentWisePrescription'
BEGIN
    SELECT *
    FROM dbo.prescription_vw
    WHERE appointment_id = @appointment_id
END

-- Optional: Invalid operation
ELSE
BEGIN
    SELECT 'Invalid Operation' AS message
END
END
GO

CREATE PROCEDURE [dbo].[sp_receptionist]
(
    @operation NVARCHAR(50),
    @recep_id INT = NULL,
    @mobile_no NVARCHAR(50) = NULL,
    @name NVARCHAR(100) = NULL,
    @Address NVARCHAR(100) = NULL,
    @email NVARCHAR(100) = NULL,
    @gender_id INT = NULL,
    @clinic_id  NVARCHAR(50) = NULL,
    @img_url NVARCHAR(MAX) = NULL,
	    @doctor_id INT = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    ---------------------------------------------------------
    -- INSERT RECEPTIONIST
    ---------------------------------------------------------
    IF @operation = 'Insert'
    BEGIN
        BEGIN TRY
            BEGIN TRANSACTION;

            IF EXISTS
            (
                SELECT 1
                FROM receptionist
                WHERE mobile_no = @mobile_no
                AND active_status = 1
            )
            BEGIN
                SELECT
                    0 AS success,
                    'Mobile number already exists' AS message;

                ROLLBACK TRANSACTION;
                RETURN;
            END
			 IF EXISTS
        (
            SELECT 1
            FROM doctor_login
            WHERE mobile = @mobile_no
            AND active_status = 1
        )
        BEGIN
            SELECT 0 AS success, 'This mobile is already registered as a Doctor' AS message;
            ROLLBACK TRANSACTION;
            RETURN;
        END

            INSERT INTO receptionist
            (
                name,
                mobile_no,
                email,
                Address,
                gender_id,
                clinic_id,
                active_status,
                created_at,
				role_id,
				doctor_id
            )
            VALUES
            (
                @name,
                @mobile_no,
                @email,
                @Address,
                @gender_id,
                @clinic_id,
                1,
                GETDATE(),
				3,
				@doctor_id
            );

            SET @recep_id = SCOPE_IDENTITY();

            COMMIT TRANSACTION;

            SELECT
                1 AS success,
                @recep_id AS recep_id,
                'Receptionist created successfully' AS message;

        END TRY
        BEGIN CATCH
            ROLLBACK TRANSACTION;

            SELECT
                0 AS success,
                ERROR_MESSAGE() AS message;
        END CATCH

        RETURN;
    END

    ---------------------------------------------------------
    -- UPDATE RECEPTIONIST
    ---------------------------------------------------------
  IF @operation = 'Update'
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE receptionist
        SET
            name      = ISNULL(@name,      name),
            mobile_no = ISNULL(@mobile_no, mobile_no),
            email     = ISNULL(@email,     email),
            Address   = ISNULL(@Address,   Address),
            gender_id = ISNULL(@gender_id, gender_id),
            clinic_id = ISNULL(@clinic_id, clinic_id),
            doctor_id = ISNULL(@doctor_id, doctor_id)
        WHERE recep_id = @recep_id;

        COMMIT TRANSACTION;

        SELECT
            1 AS success,
            @recep_id AS recep_id,
            'Receptionist updated successfully' AS message;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        SELECT 0 AS success, ERROR_MESSAGE() AS message;
    END CATCH

    RETURN;
END


    ---------------------------------------------------------
    -- FETCH BY MOBILE
    ---------------------------------------------------------
    IF @operation = 'FetchReceptionist'
    BEGIN
        SELECT *
        FROM receptionist
        WHERE mobile_no = @mobile_no
        AND active_status = 1;

        RETURN;
    END

    ---------------------------------------------------------
    -- FETCH ALL
    ---------------------------------------------------------
    IF @operation = 'FetchReceptionistList'
    BEGIN
        SELECT *
        FROM receptionist
        WHERE active_status = 1 and doctor_id=@doctor_id
        ORDER BY recep_id DESC;

        RETURN;
    END

    ---------------------------------------------------------
    -- FETCH BY ID
    ---------------------------------------------------------
    IF @operation = 'FetchById'
    BEGIN
        SELECT *
        FROM receptionist
        WHERE recep_id = @recep_id
        AND active_status = 1;

        RETURN;
    END

    ---------------------------------------------------------
    -- SOFT DELETE
    ---------------------------------------------------------
    IF @operation = 'DeleteReceptionist'
    BEGIN
        UPDATE receptionist
        SET active_status = 0
        WHERE recep_id = @recep_id;

        SELECT
            1 AS success,
            'Receptionist deleted successfully' AS message;

        RETURN;
    END

  

    ---------------------------------------------------------
    -- UPLOAD IMAGE
    ---------------------------------------------------------
    IF @operation = 'uploadReceptionistImg'
    BEGIN
        UPDATE receptionist
        SET img_url = @img_url
        WHERE recep_id = @recep_id;

        SELECT
            1 AS success,
            'Image uploaded successfully' AS message;

        RETURN;
    END
	IF @operation = 'check_phone_receptionist'
    BEGIN
        SELECT
            recep_id,
            name,
            mobile_no,
            email,
            Address,
            gender_id,
            clinic_id,
            doctor_id,
            img_url,
            active_status,
            created_at,
            role_id,
            token
        FROM receptionist
        WHERE mobile_no = @mobile_no
        AND active_status = 1;
        RETURN;
    END

END
GO

CREATE PROCEDURE [dbo].[sp_review]
(
    @operation NVARCHAR(10),
    @appointment_id INT = NULL,
    @doctor_id INT = NULL,
    @patient_id INT = NULL,
    -- Half-star precision: 0.5, 1.0, 1.5, ... 5.0. INT would truncate
    -- 3.5 → 3 silently at the parameter boundary, before INSERT even
    -- reaches the DECIMAL column.
    @rating DECIMAL(2,1) = NULL,
    @comment NVARCHAR(500) = NULL,
    @reviewed_by_user_id INT = NULL,
	  @clinic_id           NVARCHAR(50)  = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    -- ✅ Insert review (appointment-based, avoid duplicate)
  IF @operation = 'Insert'
    BEGIN
        IF NOT EXISTS (
            SELECT 1 FROM appointments
            WHERE appointment_id = @appointment_id
              AND doctor_id      = @doctor_id
              AND patient_id     = @patient_id
              AND status         = 'completed'
        )
        BEGIN
            SELECT 0 AS success, 'Appointment not completed or invalid' AS message;
            RETURN;
        END

        IF EXISTS (
            SELECT 1 FROM reviews
            WHERE appointment_id = @appointment_id
        )
        BEGIN
            SELECT 0 AS success, 'Review already submitted' AS message;
            RETURN;
        END

        INSERT INTO reviews (appointment_id, doctor_id, patient_id, rating, comment, created_at, reviewed_by_user_id, clinic_id)
        VALUES (@appointment_id, @doctor_id, @patient_id, @rating, @comment, GETDATE(), @reviewed_by_user_id, @clinic_id);

        UPDATE appointments
        SET is_reviewed = 1
        WHERE appointment_id = @appointment_id;

        SELECT 1 AS success, SCOPE_IDENTITY() AS review_id, 'Review added' AS message;
    END

    -- ✅ Delete review (by appointment + patient)
    ELSE IF @operation = 'Delete'
    BEGIN
        DELETE FROM reviews
        WHERE appointment_id = @appointment_id
          AND patient_id = @patient_id;

        SELECT 1 AS success, 'Review deleted' AS message;
    END

    -- ✅ Fetch reviews
    ELSE IF @operation = 'Fetch'
    BEGIN
        -- Case 1: Single appointment review
        IF @appointment_id IS NOT NULL
        BEGIN
            SELECT * FROM reviews
            WHERE appointment_id = @appointment_id;
        END
        ELSE
        BEGIN
            -- Case 2: All reviews of a doctor
            SELECT
                r.review_id,
                r.appointment_id,
                r.doctor_id,
                r.patient_id,

                -- whose account submitted review
                p.name AS reviewed_by_name,

                -- actual appointment for whom
                CASE
                   WHEN r.patient_id = r.reviewed_by_user_id
                        THEN p.name
                   ELSE fm.name
                END AS patient_name,

                r.rating,
                r.comment,
                r.created_at

            FROM reviews r

            LEFT JOIN Patients p
               ON p.patient_id = r.reviewed_by_user_id

            LEFT JOIN family_members fm
               ON fm.member_id = r.patient_id


			   WHERE r.doctor_id = @doctor_id
  AND (@clinic_id IS NULL OR r.clinic_id = @clinic_id OR r.clinic_id IS NULL)
ORDER BY r.created_at DESC;


            --WHERE r.doctor_id = @doctor_id
            --ORDER BY r.created_at DESC;
        END
    END
END
GO

CREATE   PROCEDURE [dbo].[sp_slot_today_count]
    @slot_id INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT COUNT(*) AS cnt
    FROM appointments
    WHERE slot_id = @slot_id
      AND appointment_date = CAST(GETDATE() AS DATE)
      AND LOWER(status) IN ('booked', 'in_progress');
END
GO

CREATE PROCEDURE [dbo].[sp_users_manage]
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

-- ── Lookup data ────────────────────────────────────────────────────────────

INSERT INTO [dbo].[Gender] ([gender_id], [gender]) VALUES
    (1, N'Male'),
    (2, N'Female'),
    (3, N'Other')
GO

SET IDENTITY_INSERT [dbo].[role] ON
INSERT INTO [dbo].[role] ([role_id], [role]) VALUES
    (1, N'doctor'),
    (2, N'patient'),
    (3, N'receptionist')
SET IDENTITY_INSERT [dbo].[role] OFF
GO

SET IDENTITY_INSERT [dbo].[blood_groups] ON
INSERT INTO [dbo].[blood_groups] ([blood_group_id], [blood_group_name]) VALUES
    (1, N'A+'),
    (2, N'A-'),
    (3, N'B+'),
    (4, N'B-'),
    (5, N'AB+'),
    (6, N'AB-'),
    (7, N'O+'),
    (8, N'O-')
SET IDENTITY_INSERT [dbo].[blood_groups] OFF
GO

SET IDENTITY_INSERT [dbo].[Medicine_Type] ON
INSERT INTO [dbo].[Medicine_Type] ([medicine_type_id], [Medi_Type_Name]) VALUES
    (1, N'Tablet'),
    (2, N'Syrups'),
    (3, N'Drops'),
    (4, N'Injections'),
    (5, N'Lotions'),
    (6, N'Inhalers'),
    (7, N'Sprays'),
    (8, N'Powders')
SET IDENTITY_INSERT [dbo].[Medicine_Type] OFF
GO

INSERT INTO [dbo].[Relations] ([relation_id], [relation]) VALUES
    (1, N'Self'),
    (2, N'Father'),
    (3, N'Mother'),
    (4, N'Spouse'),
    (5, N'Son'),
    (6, N'Daughter'),
    (7, N'Brother'),
    (8, N'Sister'),
    (9, N'Other')
GO

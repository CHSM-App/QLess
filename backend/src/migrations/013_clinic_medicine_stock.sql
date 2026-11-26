-- =============================================================================
-- Migration 013: clinic_medicine_stock
-- =============================================================================
-- Doctors either hand medicines over / inject them from the clinic's own stock,
-- or prescribe them to be bought at a medical shop. Stock belongs to the CLINIC
-- (doctors at one clinic share it) and is kept as an append-only ledger:
-- balance = SUM(qty). Offline devices only ever add rows, so syncs never
-- overwrite each other; client_uuid makes a re-sent row a no-op.
--
--   Clinic_Medicine        per-clinic settings: unit, reorder level, sale price
--   Clinic_Stock_Movement  every +/- change (purchase, dispense, adjust, ...)
--   PrescriptionMedicine   + source / given-at-clinic / qty / price per line
--   Medicine_Type          + 'Consumables' (syringes, IV sets, cannula, NS)
--
-- Negative stock is allowed on purpose: the medicine was already given.
-- batch_no / expiry_date are stored but not used yet.
-- Quantities are DECIMAL so ml of a multi-dose vial can be tracked later.
-- =============================================================================

CREATE TABLE dbo.Clinic_Medicine (
    clinic_id     NVARCHAR(50)  NOT NULL,
    medicine_id   INT           NOT NULL,
    unit          NVARCHAR(20)  NULL,          -- tablet, bottle, vial, piece ...
    reorder_level DECIMAL(10,2) NULL,          -- low-stock warning at or below
    sale_price    DECIMAL(10,2) NULL,          -- default price per unit to patient
    created_at    DATETIME      NOT NULL CONSTRAINT DF_Clinic_Medicine_created_at DEFAULT (GETDATE()),
    CONSTRAINT PK_Clinic_Medicine PRIMARY KEY (clinic_id, medicine_id),
    CONSTRAINT FK_Clinic_Medicine_clinic   FOREIGN KEY (clinic_id)   REFERENCES dbo.clinics (clinic_id),
    CONSTRAINT FK_Clinic_Medicine_medicine FOREIGN KEY (medicine_id) REFERENCES dbo.Medicine_Master (medicine_id)
)
GO

CREATE TABLE dbo.Clinic_Stock_Movement (
    movement_id     INT IDENTITY(1,1) NOT NULL,
    client_uuid     UNIQUEIDENTIFIER NULL,     -- set by the app; dedupes offline re-sends
    clinic_id       NVARCHAR(50)  NOT NULL,
    medicine_id     INT           NOT NULL,
    qty             DECIMAL(10,2) NOT NULL,    -- + in, - out
    reason          VARCHAR(20)   NOT NULL,
    presc_med_id    INT           NULL,        -- set for dispense / administer
    unit_cost       DECIMAL(10,2) NULL,        -- purchase price per unit
    batch_no        NVARCHAR(50)  NULL,        -- not used yet
    expiry_date     DATE          NULL,        -- not used yet
    note            NVARCHAR(200) NULL,
    created_by_id   INT           NOT NULL,    -- doctor_id or recep_id
    created_by_role TINYINT       NOT NULL,    -- role table: 1 doctor, 3 receptionist
    created_at      DATETIME      NOT NULL CONSTRAINT DF_Clinic_Stock_Movement_created_at DEFAULT (GETDATE()),
    CONSTRAINT PK_Clinic_Stock_Movement PRIMARY KEY (movement_id),
    CONSTRAINT FK_Clinic_Stock_Movement_item
        FOREIGN KEY (clinic_id, medicine_id) REFERENCES dbo.Clinic_Medicine (clinic_id, medicine_id),
    CONSTRAINT FK_Clinic_Stock_Movement_presc
        FOREIGN KEY (presc_med_id) REFERENCES dbo.PrescriptionMedicine (presc_med_id),
    CONSTRAINT CK_Clinic_Stock_Movement_qty    CHECK (qty <> 0),
    CONSTRAINT CK_Clinic_Stock_Movement_reason
        CHECK (reason IN ('purchase', 'dispense', 'administer', 'adjust', 'return')),
    CONSTRAINT CK_Clinic_Stock_Movement_role   CHECK (created_by_role IN (1, 3))
)
GO

CREATE UNIQUE INDEX UX_Clinic_Stock_Movement_client_uuid
    ON dbo.Clinic_Stock_Movement (client_uuid) WHERE client_uuid IS NOT NULL
GO

CREATE INDEX IX_Clinic_Stock_Movement_item
    ON dbo.Clinic_Stock_Movement (clinic_id, medicine_id) INCLUDE (qty)
GO

-- NULL source on old rows means "outside" (nothing was taken from stock).
ALTER TABLE dbo.PrescriptionMedicine ADD
    source                 VARCHAR(10)   NULL,
    administered_at_clinic BIT           NOT NULL CONSTRAINT DF_PrescriptionMedicine_administered DEFAULT (0),
    qty_given              DECIMAL(10,2) NULL,
    unit_price             DECIMAL(10,2) NULL,    -- price charged, copied at save time
    CONSTRAINT CK_PrescriptionMedicine_source CHECK (source IN ('clinic', 'outside'))
GO

-- id 9: the app maps type ids by position (MedicineType enum, 1..9)
IF NOT EXISTS (SELECT 1 FROM dbo.Medicine_Type WHERE Medi_Type_Name = N'Consumables')
BEGIN
    SET IDENTITY_INSERT dbo.Medicine_Type ON;
    INSERT INTO dbo.Medicine_Type (medicine_type_id, Medi_Type_Name) VALUES (9, N'Consumables');
    SET IDENTITY_INSERT dbo.Medicine_Type OFF;
END
GO

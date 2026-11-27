// /doctor/stock — the clinic's medicine stock (migration 013). Doctors and
// receptionists of the clinic manage it together; ownStaff checks clinic_id.
//
// Stock is a ledger: balance = SUM(qty) of Clinic_Stock_Movement. Prescriptions
// write the dispense / administer rows (src/queries/prescriptions.js); this
// router lists stock, edits per-clinic settings and records purchases,
// adjustments and returns. Negative balances are allowed on purpose.
const express = require('express');
const sql = require('mssql');
const db = require('../../db');
const log = require('../../middleware/logger');

const router = express.Router();
require('../../middleware/ownStaff')(router);

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const MANUAL_REASONS = ['purchase', 'adjust', 'return']; // dispense/administer come from prescriptions

const num = (v) => (v === undefined || v === null || v === '' ? null : Number(v));
const text = (v, max) => (typeof v === 'string' && v.trim() ? v.trim().slice(0, max) : null);
const fail = (res, where, err) => {
  log.error(`[stock] ${where}: ${err.message}`);
  return res.status(500).json({ success: false, message: 'Failed to update stock' });
};

// GET /doctor/stock/:clinic_id — every medicine the clinic keeps, with balance
router.get('/:clinic_id', async (req, res) => {
  try {
    const r = await db.request()
      .input('clinic_id', sql.NVarChar(50), req.params.clinic_id)
      .query(`
        SELECT cm.medicine_id, mm.medicine_name, mm.brand_name, mm.strength,
               mm.medicine_type_id, mt.Medi_Type_Name,
               cm.unit, cm.reorder_level, cm.sale_price,
               ISNULL(s.balance, 0) AS balance,
               CASE WHEN cm.reorder_level IS NOT NULL AND ISNULL(s.balance, 0) <= cm.reorder_level
                    THEN 1 ELSE 0 END AS is_low
        FROM dbo.Clinic_Medicine cm
        JOIN dbo.Medicine_Master mm ON mm.medicine_id = cm.medicine_id
        LEFT JOIN dbo.Medicine_Type mt ON mt.medicine_type_id = mm.medicine_type_id
        OUTER APPLY (SELECT SUM(m.qty) AS balance FROM dbo.Clinic_Stock_Movement m
                     WHERE m.clinic_id = cm.clinic_id AND m.medicine_id = cm.medicine_id) s
        WHERE cm.clinic_id = @clinic_id
        ORDER BY mm.medicine_name`);
    return res.json({ success: true, data: r.recordset });
  } catch (err) { return fail(res, 'list', err); }
});

// GET /doctor/stock/:clinic_id/movements?medicine_id= — latest 200 changes
router.get('/:clinic_id/movements', async (req, res) => {
  const medicineId = num(req.query.medicine_id);
  if (medicineId !== null && !Number.isInteger(medicineId)) {
    return res.status(400).json({ success: false, message: 'medicine_id must be a number' });
  }
  try {
    const r = await db.request()
      .input('clinic_id', sql.NVarChar(50), req.params.clinic_id)
      .input('medicine_id', sql.Int, medicineId)
      .query(`
        SELECT TOP 200 m.movement_id, m.medicine_id, mm.medicine_name, m.qty, m.reason,
               m.presc_med_id, pm.prescription_id, m.unit_cost, m.batch_no, m.expiry_date,
               m.note, m.created_by_role, m.created_at,
               CASE m.created_by_role WHEN 1 THEN d.name ELSE r.name END AS created_by_name
        FROM dbo.Clinic_Stock_Movement m
        JOIN dbo.Medicine_Master mm ON mm.medicine_id = m.medicine_id
        LEFT JOIN dbo.PrescriptionMedicine pm ON pm.presc_med_id = m.presc_med_id
        LEFT JOIN dbo.doctor_login d ON m.created_by_role = 1 AND d.doctor_id = m.created_by_id
        LEFT JOIN dbo.receptionist r ON m.created_by_role = 3 AND r.recep_id = m.created_by_id
        WHERE m.clinic_id = @clinic_id
          AND (@medicine_id IS NULL OR m.medicine_id = @medicine_id)
        ORDER BY m.movement_id DESC`);
    return res.json({ success: true, data: r.recordset });
  } catch (err) { return fail(res, 'movements', err); }
});

// PUT /doctor/stock/item — set unit, reorder level and sale price (all three
// are replaced; send the current value to keep one)
router.put('/item', async (req, res) => {
  const { clinic_id } = req.body;
  const medicineId = num(req.body.medicine_id);
  const reorder = num(req.body.reorder_level);
  const price = num(req.body.sale_price);
  if (!clinic_id || !Number.isInteger(medicineId)) {
    return res.status(400).json({ success: false, message: 'clinic_id and medicine_id are required' });
  }
  if ((reorder !== null && !(reorder >= 0)) || (price !== null && !(price >= 0))) {
    return res.status(400).json({ success: false, message: 'reorder_level and sale_price must be 0 or more' });
  }
  try {
    const r = await db.request()
      .input('clinic_id', sql.NVarChar(50), clinic_id)
      .input('medicine_id', sql.Int, medicineId)
      .input('unit', sql.NVarChar(20), text(req.body.unit, 20))
      .input('reorder_level', sql.Decimal(10, 2), reorder)
      .input('sale_price', sql.Decimal(10, 2), price)
      .query(`
        DECLARE @n INT;
        UPDATE dbo.Clinic_Medicine WITH (UPDLOCK, SERIALIZABLE)
        SET unit = @unit, reorder_level = @reorder_level, sale_price = @sale_price
        WHERE clinic_id = @clinic_id AND medicine_id = @medicine_id;
        SET @n = @@ROWCOUNT;
        IF @n = 0
        BEGIN
            INSERT INTO dbo.Clinic_Medicine (clinic_id, medicine_id, unit, reorder_level, sale_price)
            SELECT @clinic_id, medicine_id, @unit, @reorder_level, @sale_price
            FROM dbo.Medicine_Master WHERE medicine_id = @medicine_id;
            SET @n = @@ROWCOUNT;
        END
        SELECT @n AS n;`);
    if (!r.recordset?.[0]?.n) return res.status(404).json({ success: false, message: 'Medicine not found' });
    return res.json({ success: true, message: 'Stock settings saved' });
  } catch (err) { return fail(res, 'item', err); }
});

// POST /doctor/stock/movement — purchase (+), adjust (+/-), return (+/-).
// client_uuid (optional) makes an offline re-send a no-op.
router.post('/movement', async (req, res) => {
  const { clinic_id, reason, client_uuid } = req.body;
  const medicineId = num(req.body.medicine_id);
  const qty = num(req.body.qty);
  const unitCost = num(req.body.unit_cost);
  const expiry = req.body.expiry_date ? new Date(req.body.expiry_date) : null;

  if (!clinic_id || !Number.isInteger(medicineId)) {
    return res.status(400).json({ success: false, message: 'clinic_id and medicine_id are required' });
  }
  if (!MANUAL_REASONS.includes(reason)) {
    return res.status(400).json({ success: false, message: `reason must be one of: ${MANUAL_REASONS.join(', ')}` });
  }
  if (!Number.isFinite(qty) || qty === 0 || Math.abs(qty) >= 1e8 || (reason === 'purchase' && qty < 0)) {
    return res.status(400).json({ success: false, message: 'qty must be a non-zero number (more than 0 for a purchase)' });
  }
  if (unitCost !== null && !(unitCost >= 0)) {
    return res.status(400).json({ success: false, message: 'unit_cost must be 0 or more' });
  }
  if (expiry && Number.isNaN(expiry.getTime())) {
    return res.status(400).json({ success: false, message: 'expiry_date is not a valid date' });
  }
  if (client_uuid && !UUID.test(client_uuid)) {
    return res.status(400).json({ success: false, message: 'client_uuid must be a UUID' });
  }

  try {
    const r = await db.request()
      .input('client_uuid', sql.UniqueIdentifier, client_uuid || null)
      .input('clinic_id', sql.NVarChar(50), clinic_id)
      .input('medicine_id', sql.Int, medicineId)
      .input('qty', sql.Decimal(10, 2), qty)
      .input('reason', sql.VarChar(20), reason)
      .input('unit_cost', sql.Decimal(10, 2), unitCost)
      .input('batch_no', sql.NVarChar(50), text(req.body.batch_no, 50))
      .input('expiry_date', sql.Date, expiry)
      .input('note', sql.NVarChar(200), text(req.body.note, 200))
      .input('created_by_id', sql.Int, Number(req.user.uid))
      .input('created_by_role', sql.TinyInt, Number(req.user.role_id))
      .query(`
        INSERT INTO dbo.Clinic_Medicine (clinic_id, medicine_id)
        SELECT @clinic_id, medicine_id FROM dbo.Medicine_Master
        WHERE medicine_id = @medicine_id
          AND NOT EXISTS (SELECT 1 FROM dbo.Clinic_Medicine WITH (UPDLOCK, HOLDLOCK)
                          WHERE clinic_id = @clinic_id AND medicine_id = @medicine_id);

        IF NOT EXISTS (SELECT 1 FROM dbo.Clinic_Medicine WHERE clinic_id = @clinic_id AND medicine_id = @medicine_id)
        BEGIN
            SELECT CAST(NULL AS INT) AS movement_id;
            RETURN;
        END

        INSERT INTO dbo.Clinic_Stock_Movement
            (client_uuid, clinic_id, medicine_id, qty, reason, unit_cost, batch_no, expiry_date,
             note, created_by_id, created_by_role)
        VALUES
            (@client_uuid, @clinic_id, @medicine_id, @qty, @reason, @unit_cost, @batch_no, @expiry_date,
             @note, @created_by_id, @created_by_role);

        SELECT SCOPE_IDENTITY() AS movement_id,
               (SELECT SUM(qty) FROM dbo.Clinic_Stock_Movement
                WHERE clinic_id = @clinic_id AND medicine_id = @medicine_id) AS balance;`);
    const row = r.recordset?.[0];
    if (!row?.movement_id) return res.status(404).json({ success: false, message: 'Medicine not found' });
    return res.json({ success: true, movement_id: row.movement_id, balance: row.balance });
  } catch (err) {
    // the same offline change sent twice: it is already recorded
    if ([2601, 2627].includes(err.number) && /client_uuid/i.test(err.message)) {
      return res.json({ success: true, duplicate: true, message: 'Already recorded' });
    }
    return fail(res, 'movement', err);
  }
});

module.exports = router;

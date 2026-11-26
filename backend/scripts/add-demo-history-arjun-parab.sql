-- Demo data for showing the app to a doctor: one complete patient with three
-- past visits under Dr. Arjun Parab (doctor_id 1, clinic CL001 Smart Clinic),
-- plus a medicine list with clinic stock (purchases + dispensed items).
--
-- Patient login: 9878000001 (demo range, OTP 123456, no SMS sent).
-- Dates are relative to today, so the history always looks recent.
--
-- Safe to re-run: stops if the demo patient already exists.
-- Undo: scripts/remove-demo-history-arjun-parab.sql

SET XACT_ABORT ON;
BEGIN TRAN;

DECLARE @doctor INT = 1, @clinic NVARCHAR(50) = 'CL001', @mobile NVARCHAR(20) = '9878000001';
DECLARE @today DATE = CAST(GETDATE() AS DATE);

IF NOT EXISTS (SELECT 1 FROM doctor_login WHERE doctor_id = @doctor AND clinic_id = @clinic)
BEGIN RAISERROR('Doctor 1 / clinic CL001 not found', 16, 1); ROLLBACK TRAN; RETURN; END

IF EXISTS (SELECT 1 FROM Patients WHERE mobile_no = @mobile)
BEGIN RAISERROR('Demo patient 9878000001 already exists', 16, 1); ROLLBACK TRAN; RETURN; END

-- ── Medicines (global library) + doctor's list + clinic stock settings ──────
DECLARE @meds TABLE (k VARCHAR(10), name NVARCHAR(100), type_id INT, brand NVARCHAR(200),
                     strength NVARCHAR(50), components NVARCHAR(500), unit NVARCHAR(20),
                     reorder DECIMAL(10,2), price DECIMAL(10,2), cost DECIMAL(10,2), opening DECIMAL(10,2));
INSERT INTO @meds VALUES
 ('PCM',  N'Paracetamol',  1, N'Dolo 650',    N'650mg',     N'Paracetamol 650mg',                 N'tablet', 50, 2,    1.2,  300),
 ('CTZ',  N'Cetirizine',   1, N'Cetzine',     N'10mg',      N'Cetirizine 10mg',                   N'tablet', 30, 2,    1,    200),
 ('PAN',  N'Pantoprazole', 1, N'Pan 40',      N'40mg',      N'Pantoprazole 40mg',                 N'tablet', 30, 8,    5,    150),
 ('AML',  N'Amlodipine',   1, N'Amlong',      N'5mg',       N'Amlodipine 5mg',                    N'tablet', 30, 3,    1.8,  100),
 ('AZI',  N'Azithromycin', 1, N'Azithral',    N'500mg',     N'Azithromycin 500mg',                N'tablet', 15, 25,   18,   45),
 ('MET',  N'Metformin',    1, N'Glycomet',    N'500mg',     N'Metformin 500mg',                   N'tablet', 30, 2,    1.2,  120),
 ('AMB',  N'Ambroxol',     2, N'Ambrodil',    N'15mg/5ml',  N'Ambroxol 15mg/5ml',                 N'bottle', 5,  95,   70,   12),
 ('DIC',  N'Diclofenac',   4, N'Voveran',     N'75mg/3ml',  N'Diclofenac sodium 75mg',            N'vial',   10, 30,   18,   40),
 ('OND',  N'Ondansetron',  4, N'Emeset',      N'4mg/2ml',   N'Ondansetron 4mg',                   N'vial',   10, 25,   14,   30),
 ('MOX',  N'Moxifloxacin', 3, N'Vigamox',     N'0.5%',      N'Moxifloxacin 0.5%',                 N'bottle', 3,  180,  140,  6),
 ('ORS',  N'ORS',          8, N'Electral',    N'21.8g',     N'Oral rehydration salts',            N'sachet', 20, 22,   16,   60),
 ('SAL',  N'Salbutamol',   6, N'Asthalin',    N'100mcg',    N'Salbutamol 100mcg/puff',            N'piece',  2,  160,  125,  4),
 ('CAL',  N'Calamine',     5, N'Lacto Calamine', N'120ml',  N'Calamine + Zinc oxide',             N'bottle', 3,  110,  85,   8),
 ('SYR',  N'Syringe',      9, N'Dispovan',    N'3ml',       NULL,                                 N'piece',  50, 5,    2.5,  200);

INSERT INTO Medicine_Master (medicine_name, medicine_type_id, brand_name, strength, components)
SELECT m.name, m.type_id, m.brand, m.strength, m.components FROM @meds m
WHERE NOT EXISTS (SELECT 1 FROM Medicine_Master x WHERE x.medicine_name = m.name AND x.medicine_type_id = m.type_id
                  AND x.brand_name = m.brand AND x.strength = m.strength);

DECLARE @mid TABLE (k VARCHAR(10) PRIMARY KEY, id INT, type_id INT, price DECIMAL(10,2));
INSERT INTO @mid SELECT m.k, x.medicine_id, m.type_id, m.price FROM @meds m
JOIN Medicine_Master x ON x.medicine_name = m.name AND x.medicine_type_id = m.type_id AND x.brand_name = m.brand AND x.strength = m.strength;

INSERT INTO Doctor_Medicine (doctor_id, medicine_id, is_active, created_at)
SELECT @doctor, id, 1, DATEADD(DAY, -75, @today) FROM @mid i
WHERE NOT EXISTS (SELECT 1 FROM Doctor_Medicine d WHERE d.doctor_id = @doctor AND d.medicine_id = i.id);

INSERT INTO Clinic_Medicine (clinic_id, medicine_id, unit, reorder_level, sale_price, created_at)
SELECT @clinic, i.id, m.unit, m.reorder, m.price, DATEADD(DAY, -75, @today) FROM @mid i JOIN @meds m ON m.k = i.k
WHERE NOT EXISTS (SELECT 1 FROM Clinic_Medicine c WHERE c.clinic_id = @clinic AND c.medicine_id = i.id);

-- Opening purchase 75 days ago, a top-up of Paracetamol 20 days ago.
INSERT INTO Clinic_Stock_Movement (clinic_id, medicine_id, qty, reason, unit_cost, note, created_by_id, created_by_role, created_at)
SELECT @clinic, i.id, m.opening, 'purchase', m.cost, N'Opening stock (demo)', @doctor, 1, DATEADD(DAY, -75, @today)
FROM @mid i JOIN @meds m ON m.k = i.k;
INSERT INTO Clinic_Stock_Movement (clinic_id, medicine_id, qty, reason, unit_cost, note, created_by_id, created_by_role, created_at)
SELECT @clinic, id, 200, 'purchase', 1.2, N'Restock (demo)', @doctor, 1, DATEADD(DAY, -20, @today) FROM @mid WHERE k = 'PCM';

-- ── Patient ──────────────────────────────────────────────────────────────────
INSERT INTO Patients (name, mobile_no, email, Address, gender_id, DOB, blood_group_id, weight, role_id, active_status)
VALUES (N'Rohan Desai', @mobile, N'rohan.desai@example.com', N'Near Bus Stand, Vengurla, Sindhudurg 416516',
        1, '1988-04-12', 3 /* B+ */, N'72', 2, 1);
DECLARE @patient INT = SCOPE_IDENTITY();

-- ── Visits: (days ago, time, symptoms, diagnosis, notes, investigation, advice, follow-up in days) ──
DECLARE @visits TABLE (n INT, days_ago INT, t TIME, symptoms NVARCHAR(500), diagnosis NVARCHAR(500),
                       notes NVARCHAR(500), investigation NVARCHAR(500), advice NVARCHAR(500), follow_up INT);
INSERT INTO @visits VALUES
 (1, 60, '10:15', N'Fever since 2 days, body ache, dry cough', N'Viral fever',
     N'Temp 101.4°F, BP 130/86, SpO2 98%. Throat mildly congested.', N'CBC, Dengue NS1',
     N'Plenty of fluids, rest for 3 days, steam inhalation twice a day.', 5),
 (2, 30, '11:00', N'Acidity, headache, occasional dizziness', N'Gastritis; Stage 1 hypertension',
     N'BP 148/94 (repeat 144/92). CBC normal. Weight 72 kg.', N'Lipid profile, HbA1c',
     N'Avoid spicy and oily food, reduce salt, 30 min walk daily. Check BP weekly.', 30),
 (3, 7,  '17:30', N'Sore throat, pain while swallowing, mild fever', N'Acute pharyngitis',
     N'Temp 99.8°F, BP 136/88. Tonsils enlarged with exudate. HbA1c 5.9 (pre-diabetic).', NULL,
     N'Warm salt-water gargles, complete the antibiotic course. Continue BP medicine.', 14);

DECLARE @appt TABLE (n INT, appointment_id INT, prescription_id INT);
DECLARE @n INT = 1;
WHILE @n <= 3
BEGIN
  DECLARE @date DATE, @t TIME, @aid INT;
  SELECT @date = DATEADD(DAY, -days_ago, @today), @t = t FROM @visits WHERE n = @n;

  INSERT INTO appointments (doctor_id, patient_id, appointment_date, start_time, end_time, booking_type, queue_number,
                            status, created_at, user_type, symptoms, is_reviewed, clinic_id, is_arrived, arrived_at)
  -- booking_type 2 = time slot (CHK_booking_rules: no queue row needed)
  SELECT @doctor, @patient, @date, @t, DATEADD(MINUTE, 10, @t), 2, NULL, 'completed',
         DATEADD(HOUR, -2, CAST(@date AS DATETIME) + CAST(@t AS DATETIME)), 1, symptoms, IIF(@n = 1, 1, 0),
         @clinic, 1, CAST(@date AS DATETIME) + CAST(DATEADD(MINUTE, -15, @t) AS DATETIME)
  FROM @visits WHERE n = @n;
  SET @aid = SCOPE_IDENTITY();

  INSERT INTO patient_records (patient_id, doctor_id, prescription_date, symptoms, diagnosis, clinical_notes,
                               follow_up_date, follow_up_time, advice, created_at, user_type, appointment_id, clinic_id, investigation)
  SELECT @patient, @doctor, CAST(@date AS DATETIME) + CAST(DATEADD(MINUTE, 10, @t) AS DATETIME), symptoms, diagnosis, notes,
         DATEADD(DAY, follow_up, @date), '10:30', advice,
         CAST(@date AS DATETIME) + CAST(DATEADD(MINUTE, 10, @t) AS DATETIME), 1, @aid, @clinic, investigation
  FROM @visits WHERE n = @n;

  INSERT INTO @appt VALUES (@n, @aid, SCOPE_IDENTITY());
  SET @n += 1;
END

-- ── Prescription lines ───────────────────────────────────────────────────────
-- source 'clinic' = given from clinic stock (qty + price, stock goes down);
-- 'outside' = to buy at a medical shop.
DECLARE @lines TABLE (visit INT, k VARCHAR(10), frequency VARCHAR(20), duration VARCHAR(20), timing VARCHAR(30),
                      dosage VARCHAR(20), inj_route VARCHAR(20), source VARCHAR(10), administered BIT, qty DECIMAL(10,2));
INSERT INTO @lines VALUES
 (1, 'PCM', '1-1-1', '3 days', 'After Food',  '1-1-1', NULL, 'clinic',  0, 9),
 (1, 'CTZ', '0-0-1', '5 days', 'At Bedtime',  '0-0-1', NULL, 'outside', 0, NULL),
 (1, 'AMB', '1-1-1', '5 days', 'After Food',  '5',     NULL, 'outside', 0, NULL),
 (1, 'DIC', NULL,    NULL,     NULL,          '75mg',  'IM', 'clinic',  1, 1),
 (1, 'SYR', NULL,    NULL,     NULL,          NULL,    NULL, 'clinic',  0, 1),
 (2, 'PAN', '1-0-0', '14 days','Before Food', '1-0-0', NULL, 'clinic',  0, 14),
 (2, 'AML', '1-0-0', '30 days','After Food',  '1-0-0', NULL, 'outside', 0, NULL),
 (3, 'AZI', '1-0-0', '3 days', 'After Food',  '1-0-0', NULL, 'clinic',  0, 3),
 (3, 'PCM', '1-0-1', '3 days', 'After Food',  '1-0-1', NULL, 'clinic',  0, 6),
 (3, 'AML', '1-0-0', '30 days','After Food',  '1-0-0', NULL, 'outside', 0, NULL);

INSERT INTO PrescriptionMedicine (prescription_id, medicine_id, medicine_type_id, frequency, duration, timing,
                                  tablet_dosage, syrup_dosage_ml, inj_dosage, inj_route,
                                  source, administered_at_clinic, qty_given, unit_price)
SELECT a.prescription_id, i.id, i.type_id, l.frequency, l.duration, l.timing,
       IIF(i.type_id = 1, l.dosage, NULL), IIF(i.type_id = 2, l.dosage, NULL),
       IIF(i.type_id = 4, l.dosage, NULL), l.inj_route,
       l.source, l.administered, l.qty, IIF(l.source = 'clinic', i.price, NULL)
FROM @lines l JOIN @appt a ON a.n = l.visit JOIN @mid i ON i.k = l.k;

-- Stock out for every clinic-given line, dated at that visit.
INSERT INTO Clinic_Stock_Movement (clinic_id, medicine_id, qty, reason, presc_med_id, note, created_by_id, created_by_role, created_at)
SELECT @clinic, p.medicine_id, -p.qty_given, IIF(p.administered_at_clinic = 1, 'administer', 'dispense'),
       p.presc_med_id, N'Rohan Desai', @doctor, 1, r.prescription_date
FROM PrescriptionMedicine p JOIN patient_records r ON r.prescription_id = p.prescription_id
WHERE r.patient_id = @patient AND p.source = 'clinic';

-- ── Review for the first visit ───────────────────────────────────────────────
INSERT INTO reviews (appointment_id, doctor_id, patient_id, rating, comment, created_at, reviewed_by_user_id, clinic_id)
SELECT appointment_id, @doctor, @patient, 5, N'Very good doctor, explained everything clearly. Fever was gone in 2 days.',
       DATEADD(DAY, -58, @today), @patient, @clinic
FROM @appt WHERE n = 1;

COMMIT TRAN;

SELECT p.patient_id, p.name, p.mobile_no,
       (SELECT COUNT(*) FROM appointments WHERE patient_id = p.patient_id) visits,
       (SELECT COUNT(*) FROM PrescriptionMedicine pm JOIN patient_records r ON r.prescription_id = pm.prescription_id
         WHERE r.patient_id = p.patient_id) medicine_lines
FROM Patients p WHERE p.mobile_no = @mobile;

SELECT m.brand_name, m.strength, cm.unit, cm.sale_price, SUM(s.qty) AS stock, cm.reorder_level
FROM Clinic_Medicine cm JOIN Medicine_Master m ON m.medicine_id = cm.medicine_id
JOIN Clinic_Stock_Movement s ON s.clinic_id = cm.clinic_id AND s.medicine_id = cm.medicine_id
WHERE cm.clinic_id = @clinic GROUP BY m.brand_name, m.strength, cm.unit, cm.sale_price, cm.reorder_level
ORDER BY m.brand_name;

-- Demo data: last month of patients for Dr. Arjun Parab (doctor_id 1, mobile
-- 8888888888, clinic CL001). 40 patients, 9878000002..9878000041 (demo range,
-- OTP 123456): the first 10 are repeat patients (2-4 visits each), the other
-- 30 came once. Every visit is completed with a prescription; clinic-given
-- medicines take stock out, covered by a demo restock 31 days ago.
--
-- Needs the medicines from scripts/add-demo-history-arjun-parab.sql.
-- Dates are relative to today. Safe to re-run: stops if the patients exist.
-- Undo: scripts/remove-demo-month-arjun-parab.sql

SET XACT_ABORT ON;
BEGIN TRAN;

DECLARE @doctor INT = 1, @clinic NVARCHAR(50) = 'CL001';
DECLARE @today DATE = CAST(GETDATE() AS DATE);

IF EXISTS (SELECT 1 FROM Patients WHERE mobile_no BETWEEN '9878000002' AND '9878000041')
BEGIN RAISERROR('Demo month patients already exist', 16, 1); ROLLBACK TRAN; RETURN; END

DECLARE @mid TABLE (k VARCHAR(10) PRIMARY KEY, id INT, type_id INT, price DECIMAL(10,2));
INSERT INTO @mid
SELECT v.k, m.medicine_id, m.medicine_type_id, cm.sale_price
FROM (VALUES ('PCM',N'Dolo 650'),('CTZ',N'Cetzine'),('PAN',N'Pan 40'),('AML',N'Amlong'),('AZI',N'Azithral'),
             ('MET',N'Glycomet'),('AMB',N'Ambrodil'),('DIC',N'Voveran'),('OND',N'Emeset'),('MOX',N'Vigamox'),
             ('ORS',N'Electral'),('SAL',N'Asthalin'),('CAL',N'Lacto Calamine'),('SYR',N'Dispovan')) v(k, brand)
JOIN Medicine_Master m ON m.brand_name = v.brand
JOIN Clinic_Medicine cm ON cm.medicine_id = m.medicine_id AND cm.clinic_id = @clinic;

IF (SELECT COUNT(*) FROM @mid) <> 14
BEGIN RAISERROR('Clinic medicines missing: run add-demo-history-arjun-parab.sql first', 16, 1); ROLLBACK TRAN; RETURN; END

-- Restock so the month of dispensing never takes stock below zero.
INSERT INTO Clinic_Stock_Movement (clinic_id, medicine_id, qty, reason, unit_cost, note, created_by_id, created_by_role, created_at)
SELECT @clinic, i.id, r.qty, 'purchase', r.cost, N'Restock (demo month)', @doctor, 1, DATEADD(DAY, -31, @today)
FROM (VALUES ('PCM',400,1.2),('PAN',200,5),('AZI',60,18),('MET',200,1.2),('DIC',30,18),('OND',30,14),
             ('ORS',60,16),('SYR',60,2.5),('CTZ',100,1)) r(k, qty, cost)
JOIN @mid i ON i.k = r.k;

-- ── Patients: n 1-10 repeat (visits = 2 + n % 3), 11-40 once ─────────────────
DECLARE @people TABLE (n INT PRIMARY KEY, name NVARCHAR(100), gender_id INT, address NVARCHAR(200));
INSERT INTO @people VALUES
 (1,N'Suresh Naik',1,N'Camp, Vengurla'),            (2,N'Vasanti Kadam',2,N'Ubhadanda, Vengurla'),
 (3,N'Prakash Sawant',1,N'Mochemad, Vengurla'),     (4,N'Shubhangi Parulekar',2,N'Hospital Naka, Vengurla'),
 (5,N'Ganesh Gawade',1,N'Tulas, Vengurla'),         (6,N'Meena Prabhu',2,N'Market Road, Vengurla'),
 (7,N'Dattaram Kubal',1,N'Parabwada, Vengurla'),    (8,N'Sunita Mhapsekar',2,N'Bhendmala, Vengurla'),
 (9,N'Vijay Redkar',1,N'Redi, Vengurla'),           (10,N'Anjali Tendolkar',2,N'Shiroda, Vengurla'),
 (11,N'Aniket Dhuri',1,N'Mathond, Vengurla'),       (12,N'Pooja Malvankar',2,N'Sagareshwar, Vengurla'),
 (13,N'Rahul Chavan',1,N'Ubhadanda, Vengurla'),     (14,N'Sneha Gaonkar',2,N'Camp, Vengurla'),
 (15,N'Mahesh Shirodkar',1,N'Shiroda, Vengurla'),   (16,N'Kavita Raut',2,N'Mochemad, Vengurla'),
 (17,N'Sachin Marathe',1,N'Market Road, Vengurla'), (18,N'Priya Bandekar',2,N'Tulas, Vengurla'),
 (19,N'Nitin Khanolkar',1,N'Hospital Naka, Vengurla'),(20,N'Rupali Pednekar',2,N'Parabwada, Vengurla'),
 (21,N'Omkar Velip',1,N'Aravali, Vengurla'),        (22,N'Swati Joshi',2,N'Camp, Vengurla'),
 (23,N'Tushar Patkar',1,N'Mhapan, Vengurla'),       (24,N'Neha Salgaonkar',2,N'Bhendmala, Vengurla'),
 (25,N'Rajesh Hodawadekar',1,N'Hodawade, Vengurla'),(26,N'Manisha Lad',2,N'Ubhadanda, Vengurla'),
 (27,N'Amol Kerkar',1,N'Redi, Vengurla'),           (28,N'Deepa Kamat',2,N'Market Road, Vengurla'),
 (29,N'Sandeep Sawant',1,N'Tank, Vengurla'),        (30,N'Rekha Dalvi',2,N'Mochemad, Vengurla'),
 (31,N'Yogesh Morje',1,N'Matond, Vengurla'),        (32,N'Ashwini Govekar',2,N'Shiroda, Vengurla'),
 (33,N'Kiran Parab',1,N'Parabwada, Vengurla'),      (34,N'Smita Wagh',2,N'Camp, Vengurla'),
 (35,N'Pravin Gawas',1,N'Tulas, Vengurla'),         (36,N'Archana Nerurkar',2,N'Sagareshwar, Vengurla'),
 (37,N'Sagar Mestry',1,N'Hospital Naka, Vengurla'), (38,N'Varsha Kudalkar',2,N'Ubhadanda, Vengurla'),
 (39,N'Hemant Desai',1,N'Aravali, Vengurla'),       (40,N'Jyoti Pawaskar',2,N'Bhendmala, Vengurla');

DECLARE @pid TABLE (n INT PRIMARY KEY, patient_id INT);
INSERT INTO Patients (name, mobile_no, email, Address, gender_id, DOB, blood_group_id, weight, role_id, active_status)
OUTPUT CAST(RIGHT(inserted.mobile_no, 2) AS INT) - 1, inserted.patient_id INTO @pid
SELECT name, '98780000' + RIGHT('0' + CAST(n + 1 AS VARCHAR), 2), NULL, address + N', Sindhudurg 416516', gender_id,
       DATEFROMPARTS(IIF(n <= 10, 1950 + n * 2, 1970 + (n * 7) % 35), 1 + n % 12, 1 + (n * 3) % 28),
       1 + n % 8, CAST(50 + (n * 11) % 35 AS NVARCHAR), 2, 1
FROM @people;

-- ── Diagnoses: 1-3 chronic (repeat patients' follow-ups), 4-10 acute ────────
DECLARE @dx TABLE (d INT PRIMARY KEY, symptoms NVARCHAR(500), diagnosis NVARCHAR(500), notes NVARCHAR(500),
                   investigation NVARCHAR(500), advice NVARCHAR(500), follow_up INT);
INSERT INTO @dx VALUES
 (1, N'Headache, BP follow-up', N'Essential hypertension', N'BP 146/92. No chest pain. Pulse 82 regular.', N'Lipid profile, Serum creatinine',
     N'Low salt diet, 30 min walk daily, check BP weekly.', 14),
 (2, N'Increased thirst, sugar follow-up', N'Type 2 diabetes mellitus', N'FBS 148, PPBS 212. Weight stable.', N'HbA1c, Urine routine',
     N'Avoid sweets and rice at night, regular walk, foot care.', 14),
 (3, N'Burning in chest after meals, bloating', N'Gastritis / GERD', N'Epigastric tenderness. No vomiting.', NULL,
     N'Small frequent meals, avoid tea on empty stomach and spicy food.', 10),
 (4, N'Fever with body ache since 2 days', N'Viral fever', N'Temp 101°F, SpO2 98%. Throat congested.', N'CBC, Dengue NS1',
     N'Plenty of fluids, rest, tepid sponging if fever above 101°F.', 5),
 (5, N'Sore throat, pain while swallowing', N'Acute pharyngitis', N'Temp 99.6°F. Tonsils enlarged.', NULL,
     N'Warm salt-water gargles, complete the antibiotic course.', 7),
 (6, N'Loose motions 5-6 times since morning, weakness', N'Acute gastroenteritis', N'Mild dehydration. BP 108/70.', N'Stool routine',
     N'ORS after every loose motion, light diet, avoid outside food.', 3),
 (7, N'Sneezing, running nose, itchy eyes', N'Allergic rhinitis', N'Nasal mucosa pale and boggy.', NULL,
     N'Avoid dust, steam inhalation at night.', 10),
 (8, N'Productive cough since 1 week', N'Acute bronchitis', N'Scattered wheeze both sides. SpO2 97%.', N'Chest X-ray',
     N'Steam inhalation, warm water, avoid cold drinks.', 7),
 (9, N'Low back pain after lifting, difficulty bending', N'Lumbar muscle strain', N'Paraspinal tenderness, SLR negative.', NULL,
     N'Hot fomentation, avoid lifting weights for a week.', 7),
 (10, N'Itchy rash on arms and neck', N'Contact dermatitis', N'Erythematous papules, no blisters.', NULL,
     N'Avoid new soaps or detergents, keep area dry.', 7);

DECLARE @dxmeds TABLE (d INT, k VARCHAR(10), frequency VARCHAR(20), duration VARCHAR(20), timing VARCHAR(30),
                       dosage VARCHAR(20), inj_route VARCHAR(20), source VARCHAR(10), administered BIT, qty DECIMAL(10,2));
INSERT INTO @dxmeds VALUES
 (1, 'AML', '1-0-0', '14 days', 'After Food',  '1-0-0', NULL, 'outside', 0, NULL),
 (2, 'MET', '1-0-1', '14 days', 'After Food',  '1-0-1', NULL, 'clinic',  0, 28),
 (3, 'PAN', '1-0-0', '10 days', 'Before Food', '1-0-0', NULL, 'clinic',  0, 10),
 (4, 'PCM', '1-1-1', '3 days',  'After Food',  '1-1-1', NULL, 'clinic',  0, 9),
 (4, 'CTZ', '0-0-1', '3 days',  'At Bedtime',  '0-0-1', NULL, 'outside', 0, NULL),
 (5, 'AZI', '1-0-0', '3 days',  'After Food',  '1-0-0', NULL, 'clinic',  0, 3),
 (5, 'PCM', '1-0-1', '3 days',  'After Food',  '1-0-1', NULL, 'clinic',  0, 6),
 (6, 'ORS', '1-1-1', '2 days',  'After Food',  NULL,    NULL, 'clinic',  0, 4),
 (6, 'OND', NULL,    NULL,      NULL,          '4mg',   'IV', 'clinic',  1, 1),
 (6, 'SYR', NULL,    NULL,      NULL,          NULL,    NULL, 'clinic',  0, 1),
 (7, 'CTZ', '0-0-1', '10 days', 'At Bedtime',  '0-0-1', NULL, 'clinic',  0, 10),
 (8, 'AMB', '1-1-1', '7 days',  'After Food',  '5',     NULL, 'outside', 0, NULL),
 (8, 'SAL', 'SOS',   '7 days',  NULL,          NULL,    NULL, 'outside', 0, NULL),
 (9, 'DIC', NULL,    NULL,      NULL,          '75mg',  'IM', 'clinic',  1, 1),
 (9, 'SYR', NULL,    NULL,      NULL,          NULL,    NULL, 'clinic',  0, 1),
 (9, 'PAN', '1-0-0', '5 days',  'Before Food', '1-0-0', NULL, 'clinic',  0, 5),
 (10,'CAL', '1-0-1', '7 days',  NULL,          NULL,    NULL, 'outside', 0, NULL),
 (10,'CTZ', '0-0-1', '7 days',  'At Bedtime',  '0-0-1', NULL, 'outside', 0, NULL);

-- ── Visits: repeat patients alternate chronic follow-up / acute, spread over
-- the month; one-time patients get a date and illness from their number. ────
DECLARE @visits TABLE (v INT IDENTITY PRIMARY KEY, n INT, days_ago INT, t TIME, d INT);
INSERT INTO @visits (n, days_ago, t, d)
SELECT p.n,
       IIF(p.n <= 10, (26 + p.n % 4) - (s.i - 1) * ((26 + p.n % 4) / (2 + p.n % 3)), 1 + (p.n * 7) % 29),
       DATEADD(MINUTE, ((p.n * 3 + s.i * 5) % 9) * 15, IIF((p.n + s.i) % 2 = 0, CAST('10:00' AS TIME), CAST('17:00' AS TIME))),
       CASE WHEN p.n <= 10 AND s.i % 2 = 1 THEN 1 + p.n % 3
            WHEN p.n <= 10 THEN 4 + (p.n + s.i) % 7
            WHEN p.n % 6 = 0 THEN 1 + p.n % 3
            ELSE 4 + p.n % 7 END
FROM @people p
JOIN (VALUES (1),(2),(3),(4)) s(i) ON s.i <= IIF(p.n <= 10, 2 + p.n % 3, 1);

DECLARE @appt TABLE (v INT, appointment_id INT, prescription_id INT);
DECLARE @v INT = 1, @last INT = (SELECT MAX(v) FROM @visits);
WHILE @v <= @last
BEGIN
  DECLARE @date DATE, @t TIME, @patient INT, @aid INT;
  SELECT @date = DATEADD(DAY, -x.days_ago, @today), @t = x.t, @patient = p.patient_id
  FROM @visits x JOIN @pid p ON p.n = x.n WHERE x.v = @v;

  INSERT INTO appointments (doctor_id, patient_id, appointment_date, start_time, end_time, booking_type, queue_number,
                            status, created_at, user_type, symptoms, is_reviewed, clinic_id, is_arrived, arrived_at)
  SELECT @doctor, @patient, @date, @t, DATEADD(MINUTE, 10, @t), 2, NULL, 'completed',
         DATEADD(HOUR, -2, CAST(@date AS DATETIME) + CAST(@t AS DATETIME)), 1, d.symptoms, IIF(@v % 7 = 0, 1, 0),
         @clinic, 1, CAST(@date AS DATETIME) + CAST(DATEADD(MINUTE, -15, @t) AS DATETIME)
  FROM @visits x JOIN @dx d ON d.d = x.d WHERE x.v = @v;
  SET @aid = SCOPE_IDENTITY();

  INSERT INTO patient_records (patient_id, doctor_id, prescription_date, symptoms, diagnosis, clinical_notes,
                               follow_up_date, follow_up_time, advice, created_at, user_type, appointment_id, clinic_id, investigation)
  SELECT @patient, @doctor, CAST(@date AS DATETIME) + CAST(DATEADD(MINUTE, 10, @t) AS DATETIME), d.symptoms, d.diagnosis, d.notes,
         DATEADD(DAY, d.follow_up, @date), '10:30', d.advice,
         CAST(@date AS DATETIME) + CAST(DATEADD(MINUTE, 10, @t) AS DATETIME), 1, @aid, @clinic, d.investigation
  FROM @visits x JOIN @dx d ON d.d = x.d WHERE x.v = @v;

  INSERT INTO @appt VALUES (@v, @aid, SCOPE_IDENTITY());
  SET @v += 1;
END

INSERT INTO PrescriptionMedicine (prescription_id, medicine_id, medicine_type_id, frequency, duration, timing,
                                  tablet_dosage, syrup_dosage_ml, inj_dosage, inj_route,
                                  source, administered_at_clinic, qty_given, unit_price)
SELECT a.prescription_id, i.id, i.type_id, l.frequency, l.duration, l.timing,
       IIF(i.type_id = 1, l.dosage, NULL), IIF(i.type_id = 2, l.dosage, NULL),
       IIF(i.type_id = 4, l.dosage, NULL), l.inj_route,
       l.source, l.administered, l.qty, IIF(l.source = 'clinic', i.price, NULL)
FROM @appt a JOIN @visits x ON x.v = a.v JOIN @dxmeds l ON l.d = x.d JOIN @mid i ON i.k = l.k;

INSERT INTO Clinic_Stock_Movement (clinic_id, medicine_id, qty, reason, presc_med_id, note, created_by_id, created_by_role, created_at)
SELECT @clinic, pm.medicine_id, -pm.qty_given, IIF(pm.administered_at_clinic = 1, 'administer', 'dispense'),
       pm.presc_med_id, pt.name, @doctor, 1, r.prescription_date
FROM @appt a JOIN patient_records r ON r.prescription_id = a.prescription_id
JOIN PrescriptionMedicine pm ON pm.prescription_id = r.prescription_id
JOIN Patients pt ON pt.patient_id = r.patient_id
WHERE pm.source = 'clinic';

-- Reviews on the visits flagged is_reviewed.
INSERT INTO reviews (appointment_id, doctor_id, patient_id, rating, comment, created_at, reviewed_by_user_id, clinic_id)
SELECT ap.appointment_id, @doctor, ap.patient_id, IIF(a.v % 3 = 0, 4, 5),
       CHOOSE(1 + a.v % 4, N'Very good doctor, listens patiently.', N'Felt better in two days. Thank you doctor.',
              N'Clear explanation and medicines given at the clinic itself.', N'Short wait, good treatment.'),
       DATEADD(DAY, 1, ap.appointment_date), ap.patient_id, @clinic
FROM @appt a JOIN appointments ap ON ap.appointment_id = a.appointment_id WHERE ap.is_reviewed = 1;

COMMIT TRAN;

SELECT IIF(p.mobile_no <= '9878000011', 'repeat', 'one-time') kind, COUNT(DISTINCT p.patient_id) patients, COUNT(*) visits,
       MIN(a.appointment_date) first_visit, MAX(a.appointment_date) last_visit
FROM Patients p JOIN appointments a ON a.patient_id = p.patient_id
WHERE p.mobile_no BETWEEN '9878000002' AND '9878000041'
GROUP BY IIF(p.mobile_no <= '9878000011', 'repeat', 'one-time');

SELECT m.brand_name, SUM(s.qty) AS stock
FROM Clinic_Stock_Movement s JOIN Medicine_Master m ON m.medicine_id = s.medicine_id
WHERE s.clinic_id = @clinic GROUP BY m.brand_name ORDER BY stock;

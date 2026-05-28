// Book N patients into Dr. Manoj's (doctor_id=1) currently active or next
// upcoming queue slot today. CLI arg: N (default 20).
//
// Slot pick rule: queue (booking_mode=1) slot today whose [start,end] contains
// GETDATE(); falls back to next upcoming slot.
//
// Patient pool: Sindhudurg-local first (Vengurla/Sawantwadi/Kudal/Malvan/
// Kankavli/Devgad), then any seeded patient if pool runs short.
//
// Run from backend/:  node scripts/bookManojActiveQueue.js 30

const db = require('../routes/db');

const DOCTOR_ID = 1;
const N = parseInt(process.argv[2], 10) || 20;
const SYMPTOMS = ['Fever','Cold','Headache','Cough','BP check','Acidity','Joint pain','Skin rash','Stomach upset','Allergy'];

function todayStr() {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;
}

async function main() {
  await db.ready();

  const slotR = await db.request().input('doctor_id', DOCTOR_ID).query(`
    SELECT TOP 1 ts.slot_id,
                 CONVERT(VARCHAR, ts.start_time, 108) AS start_t,
                 CONVERT(VARCHAR, ts.end_time, 108)   AS end_t,
                 ts.max_queue_length
    FROM doctor_availability da
    INNER JOIN doctor_time_slots ts ON ts.availability_id = da.availability_id
    WHERE da.doctor_id = @doctor_id
      AND da.day_of_week = DATENAME(WEEKDAY, GETDATE())
      AND da.is_enabled  = 1
      AND ts.booking_mode = 1
      AND CAST(GETDATE() AS TIME) < ts.end_time
    ORDER BY
      CASE WHEN CAST(GETDATE() AS TIME) BETWEEN ts.start_time AND ts.end_time THEN 0 ELSE 1 END,
      ts.start_time;
  `);
  const slot = slotR.recordset[0];
  if (!slot) throw new Error('No active or upcoming queue slot today');
  console.log(`[slot] slot_id=${slot.slot_id}  ${slot.start_t} – ${slot.end_t}  max=${slot.max_queue_length}`);

  const bookedR = await db.request()
    .input('doctor_id', DOCTOR_ID).input('slot_id', slot.slot_id)
    .query(`SELECT patient_id, user_type FROM appointments
            WHERE doctor_id=@doctor_id AND slot_id=@slot_id
              AND appointment_date=CAST(GETDATE() AS DATE);`);
  const taken = new Set(bookedR.recordset.map(r => `${r.user_type}:${r.patient_id}`));
  console.log(`[existing] ${bookedR.recordset.length} already in this slot today`);

  // Sindhudurg first
  const sdR = await db.request().query(`
    SELECT patient_id, name FROM patients
    WHERE mobile_no LIKE '987800%'
      AND (Address LIKE '%Vengurla%'
        OR Address LIKE '%Sawantwadi%'
        OR Address LIKE '%Kudal%'
        OR Address LIKE '%Malvan%'
        OR Address LIKE '%Kankavli%'
        OR Address LIKE '%Devgad%')
    ORDER BY patient_id;
  `);
  const subjects = sdR.recordset.filter(p => !taken.has(`1:${p.patient_id}`)).slice(0, N);
  if (subjects.length < N) {
    const fbR = await db.request().query(`
      SELECT patient_id, name FROM patients
      WHERE mobile_no LIKE '987800%' ORDER BY patient_id;
    `);
    for (const p of fbR.recordset) {
      if (subjects.length >= N) break;
      if (taken.has(`1:${p.patient_id}`)) continue;
      if (subjects.find(s => s.patient_id === p.patient_id)) continue;
      subjects.push(p);
    }
    if (subjects.length < N) throw new Error(`Only ${subjects.length} patients available (need ${N})`);
  }
  console.log(`[pool] ${subjects.length} subjects ready`);

  const date = todayStr();
  let ok = 0;
  for (let i = 0; i < subjects.length; i++) {
    const s = subjects[i];
    const r = await db.request()
      .input('operation','BOOK').input('user_type', 1)
      .input('doctor_id', DOCTOR_ID).input('patient_id', s.patient_id)
      .input('appointment_date', date).input('start_time', null)
      .input('slot_id', slot.slot_id)
      .input('symptoms', SYMPTOMS[i % SYMPTOMS.length])
      .execute('sp_appointment');
    const row = r.recordset?.[0];
    if (row?.success !== 1) { console.warn(`  [skip] ${s.name}: ${row?.message}`); continue; }
    ok++;
  }
  console.log(`[book] booked ${ok}/${subjects.length}`);

  const snap = await db.request()
    .input('doctor_id', DOCTOR_ID).input('slot_id', slot.slot_id)
    .query(`
      SELECT a.queue_number, a.status, p.name, a.symptoms
      FROM appointments a
      LEFT JOIN patients p ON a.user_type=1 AND p.patient_id=a.patient_id
      WHERE a.doctor_id=@doctor_id AND a.slot_id=@slot_id
        AND a.appointment_date=CAST(GETDATE() AS DATE)
      ORDER BY a.queue_number;
    `);
  console.log(`\nQueue (slot=${slot.slot_id}) snapshot:`); console.table(snap.recordset);

  const dq = await db.request()
    .input('doctor_id', DOCTOR_ID).input('slot_id', slot.slot_id)
    .query(`SELECT queue_id, queue_status, current_serving, completed_count, total_queue, current_patient_id
            FROM doctor_queue
            WHERE doctor_id=@doctor_id AND slot_id=@slot_id
              AND queue_date=CAST(GETDATE() AS DATE);`);
  console.log('\ndoctor_queue:'); console.table(dq.recordset);

  process.exit(0);
}

main().catch(err => { console.error('Fatal:', err.message); process.exit(1); });

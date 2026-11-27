// AI summaries of medical reports (routes/reports.js), via the Claude API.
//
// Kept cheap on purpose (ROLLBACK_AI_REPORTS.md has the full list): Haiku, no
// thinking, small max_tokens, terse JSON schema, one call per report (the
// summary is stored and never regenerated). Env:
//   ANTHROPIC_API_KEY   — unset = summaries answer 503
//   AI_REPORTS_ENABLED  — 'false' = kill switch, no further spend
const fs = require('fs-extra');
const Anthropic = require('@anthropic-ai/sdk');

const MODEL = 'claude-haiku-4-5';
const MAX_TOKENS = 1500;
// Uploads per person per day (counted from medical_reports, so restarts don't reset it).
const DAILY_LIMIT = { staff: 30, patient: 5 };

const enabled = () => process.env.AI_REPORTS_ENABLED !== 'false' && !!process.env.ANTHROPIC_API_KEY;

let client;
// maxRetries 1: a retried request is billed again.
const getClient = () => (client ||= new Anthropic({ maxRetries: 1, timeout: 90 * 1000 }));

const str = { type: 'string' };
// Patient / report details as printed — shown in the app and used to suggest
// which patient a doctor's unassigned report belongs to (phone, then name).
const DETAILS = ['patient_name', 'patient_age', 'patient_gender', 'patient_phone', 'patient_address',
  'patient_id_on_report', 'referred_by', 'lab_name'];
const SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: [...DETAILS, 'report_type', 'report_date', 'overview', 'key_findings', 'notes'],
  properties: {
    ...Object.fromEntries(DETAILS.map((k) => [k, str])),
    report_type: str,
    report_date: str,
    overview: str,
    key_findings: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['test', 'value', 'unit', 'reference_range', 'flag'],
        properties: {
          test: str, value: str, unit: str, reference_range: str,
          flag: { type: 'string', enum: ['normal', 'high', 'low', 'abnormal'] },
        },
      },
    },
    notes: { type: 'array', items: str },
  },
};

const SYSTEM = `You summarise medical/lab reports from photos or PDFs.
Rules: copy names, values, units and reference ranges exactly as printed; never guess or invent. Use "" for anything not on the report. report_date as YYYY-MM-DD if printed.
Patient details: name, age, gender, phone/mobile (digits only), address, patient/registration/UHID number, referring doctor and lab/hospital name, exactly as printed.
key_findings: every test result on the report, flag from its reference range (abnormal = outside range with no direction, or a positive/abnormal remark).
overview: at most 80 words. notes: at most 3 short points.
If the pages are not a medical report, set report_type to "Not a medical report" and leave the rest empty.`;

const AUDIENCE = {
  doctor: 'Reader: the treating doctor. Be clinical and concise; highlight abnormal values.',
  patient: 'Reader: the patient. Use plain, calm language, no diagnosis; add a note to discuss the results with their doctor.',
};

class AiError extends Error {
  constructor(status, message) { super(message); this.status = status; }
}

/**
 * files: [{ path, realType }] — images, or one PDF (verified by upload.js).
 * Returns { summary, usage: { input_tokens, output_tokens } }; throws AiError.
 */
async function summarizeReport(files, audience) {
  const blocks = await Promise.all(files.map(async (f) => {
    const data = (await fs.readFile(f.path)).toString('base64');
    return f.realType === 'application/pdf'
      ? { type: 'document', source: { type: 'base64', media_type: 'application/pdf', data } }
      : { type: 'image', source: { type: 'base64', media_type: f.realType, data } };
  }));

  let msg;
  try {
    msg = await getClient().messages.create({
      model: MODEL,
      max_tokens: MAX_TOKENS,
      system: SYSTEM,
      messages: [{ role: 'user', content: [...blocks, { type: 'text', text: AUDIENCE[audience] }] }],
      output_config: { format: { type: 'json_schema', schema: SCHEMA } },
    });
  } catch (err) {
    if (err instanceof Anthropic.RateLimitError) throw new AiError(503, 'AI summary is busy. Please try again in a minute.');
    if (err instanceof Anthropic.BadRequestError) throw new AiError(422, 'Could not read this report. Try clearer photos.');
    throw new AiError(502, 'AI summary failed. Please try again.');
  }

  const text = msg.content.find((b) => b.type === 'text');
  if (msg.stop_reason !== 'end_turn' || !text) throw new AiError(422, 'Could not summarise this report.');
  let summary;
  try { summary = JSON.parse(text.text); } catch { throw new AiError(422, 'Could not summarise this report.'); }
  return { summary, usage: { input_tokens: msg.usage.input_tokens, output_tokens: msg.usage.output_tokens } };
}

module.exports = { summarizeReport, enabled, AiError, DAILY_LIMIT, MODEL };

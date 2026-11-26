// WhatsApp template messages to patients (prescription, follow-up) through
// SMSala, the same provider and token as the login OTP (routes/auth/otp.js).
// Meta only delivers pre-approved templates, so each kind has its own template
// id in .env; the params fill that template's {{1}}, {{2}}, … in order.
//
//   WHATSAPP_TEMPLATE_URL           SMSala's template-message endpoint
//   WHATSAPP_RX_TEMPLATE_ID         prescription template
//   WHATSAPP_FOLLOWUP_TEMPLATE_ID   follow-up template
const axios = require('axios');
const log = require('./middleware/logger');

/** 10-digit Indian mobile from whatever was stored ("+91 98…", "098…"), or null. */
function indianMobile(raw) {
  const digits = String(raw ?? '').replace(/\D/g, '').replace(/^0+/, '');
  const ten = digits.length === 12 && digits.startsWith('91') ? digits.slice(2) : digits;
  return /^[6-9]\d{9}$/.test(ten) ? ten : null;
}

/** Throws when the provider is not set up or refuses; resolves when sent. */
async function sendWhatsAppTemplate(mobile10, templateId, params) {
  // Dev: OTP_TO_CONSOLE=1 prints instead of sending, like the OTP route.
  if (process.env.OTP_TO_CONSOLE === '1' && process.env.NODE_ENV !== 'production') {
    console.log(`\n[WhatsApp] ${mobile10} template ${templateId} → ${JSON.stringify(params)}\n`);
    return;
  }
  const url = process.env.WHATSAPP_TEMPLATE_URL;
  if (!url || !templateId || !process.env.WHATSAPP_API_TOKEN) {
    throw new Error('WhatsApp messaging is not configured');
  }
  // ponytail: field names follow the SendOtp call; match them to SMSala's
  // template-message docs once the templates are approved.
  const { data } = await axios.post(url, {
    PhoneNumber: `91${mobile10}`,
    ApiToken: process.env.WHATSAPP_API_TOKEN,
    TemplateId: Number(templateId),
    Parameters: params.map((p) => String(p ?? '-').replace(/\s+/g, ' ').trim() || '-'),
  });
  if (!data || data.IsSuccess !== true) {
    log.error('whatsapp: provider refused: ' + JSON.stringify(data).slice(0, 500));
    throw new Error('WhatsApp provider refused the message');
  }
}

module.exports = { sendWhatsAppTemplate, indianMobile };

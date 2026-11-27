// Minimal structured logger. Goal: stop sensitive data (FCM tokens, JWTs,
// raw mobile numbers, full SP payloads) from landing in stdout/log files.
//
// API mirrors pino/winston so we can swap in a real logger later without
// touching call sites: log.debug / log.info / log.warn / log.error.
//
//   log.info('event', { mobile: '9876543210' })  →  redacts to 98******10
//   log.debug(...)                                →  no-op in production
//
// Drop a real logger in here when needs grow (rotation, JSON shipping, etc.)

const SENSITIVE_KEYS = new Set([
  'token', 'accesstoken', 'refreshtoken', 'firebasetoken', 'fcmtoken',
  'fcm_token', 'patient_token', 'doctor_token', 'owner_token',
  'authorization', 'password', 'jwt', 'secret',
]);

const PHONE_KEYS = new Set(['mobile', 'mobile_no', 'mobileno', 'phone']);

const isProd = process.env.NODE_ENV === 'production';

function maskPhone(v) {
  const s = String(v);
  if (s.length < 4) return '***';
  return `${s.slice(0, 2)}${'*'.repeat(Math.max(s.length - 4, 0))}${s.slice(-2)}`;
}

// Recursively redact known-sensitive keys. Doesn't mutate input.
function redact(value, depth = 0) {
  if (value == null || depth > 4) return value;
  if (Array.isArray(value)) return value.map((v) => redact(v, depth + 1));
  if (typeof value !== 'object') return value;
  const out = {};
  for (const [k, v] of Object.entries(value)) {
    const lk = k.toLowerCase();
    if (SENSITIVE_KEYS.has(lk)) out[k] = '[REDACTED]';
    else if (PHONE_KEYS.has(lk)) out[k] = maskPhone(v);
    else out[k] = redact(v, depth + 1);
  }
  return out;
}

function emit(level, msg, meta) {
  const line = meta !== undefined
    ? `[${level}] ${msg} ${JSON.stringify(redact(meta))}`
    : `[${level}] ${msg}`;
  if (level === 'error') console.error(line);
  else if (level === 'warn') console.warn(line);
  else console.log(line);
}

module.exports = {
  debug: (msg, meta) => { if (!isProd) emit('debug', msg, meta); },
  info:  (msg, meta) => emit('info',  msg, meta),
  warn:  (msg, meta) => emit('warn',  msg, meta),
  error: (msg, meta) => emit('error', msg, meta),
  // Exposed for use cases that need explicit redaction outside a log call.
  redact,
};

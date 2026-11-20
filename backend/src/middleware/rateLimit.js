const rateLimit = require('express-rate-limit');

// Shared 429 handler so every limiter returns the same shape clients can
// parse, rather than the default plain-text body.
function rateLimitHandler(req, res /* next, options */) {
  res.status(429).json({
    error: 'Too many requests. Please try again later.',
  });
}

const commonOptions = {
  standardHeaders: 'draft-7', // RateLimit-* headers (RFC draft)
  legacyHeaders: false,       // strip X-RateLimit-* (legacy)
  handler: rateLimitHandler,
};

// ── Global baseline. Pure DDoS/scraping backstop — NOT a per-user throttle.
// Real per-action limits live on the sensitive routes below. This must sit far
// above legitimate traffic because (a) the app re-fetches the appointment list
// (2 API calls each) after every queue action, and (b) a whole clinic behind
// one WiFi/NAT shares a single public IP (trust proxy: 1), so all their users
// bucket together. 300/15min was exhausting mid-session and 429-ing every page.
const globalLimiter = rateLimit({
  ...commonOptions,
  windowMs: 15 * 60 * 1000,
  max: 2000,
});

// ── Auth issuance + refresh. Brute-force / credential-stuffing target. Real
// users hit these <10x in a session.
const authLimiter = rateLimit({
  ...commonOptions,
  windowMs: 15 * 60 * 1000,
  max: 10,
});

// ── Phone-existence lookups. Account-enumeration target (an attacker can
// otherwise iterate phone numbers to harvest registered users). Loose enough
// to let a real user retype a number, strict enough to make enumeration slow.
const lookupLimiter = rateLimit({
  ...commonOptions,
  windowMs: 15 * 60 * 1000,
  max: 30,
});

// ── Account deletion endpoints. OTP-gated, low-volume. Stricter than auth to
// slow down scraping of who has accounts (request endpoint) while still being
// generous enough that a real user can retry once or twice.
const deletionLimiter = rateLimit({
  ...commonOptions,
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 10,
});

module.exports = {
  globalLimiter,
  authLimiter,
  lookupLimiter,
  deletionLimiter,
};

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

// ── Global baseline. Catches scraping/DDoS noise across every route without
// blocking realistic user traffic. Mobile clients chatting with the API may
// burst 50–100 reqs while a screen loads; 300/15min is comfortably above that.
const globalLimiter = rateLimit({
  ...commonOptions,
  windowMs: 15 * 60 * 1000,
  max: 300,
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

module.exports = {
  globalLimiter,
  authLimiter,
  lookupLimiter,
};

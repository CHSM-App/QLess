require('dotenv').config();

const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const path = require('path');

const protect = require('./routes/middleware/protect');
const uploadAuth = require('./routes/middleware/uploadAuth');
const requestId = require('./routes/middleware/requestId');
const { globalLimiter } = require('./routes/middleware/rateLimit');

const app = express();

// Behind IIS/nginx/Cloudflare. Without this, every request looks like it came
// from 127.0.0.1 and the rate limiter buckets everyone together.
app.set('trust proxy', 1);

// ── Security headers. Defaults cover HSTS, X-Frame-Options: SAMEORIGIN,
// X-Content-Type-Options: nosniff, Referrer-Policy, X-DNS-Prefetch-Control,
// and others. Two tunings:
//   - contentSecurityPolicy: disabled. CSP needs per-route tuning (the
//     bundled privacy.html / pug views would otherwise break on inline
//     styles). Re-enable with a tailored policy once the HTML surface is
//     finalised.
//   - crossOriginResourcePolicy: 'cross-origin'. /uploads serves images to
//     the Flutter app from a different origin; the default 'same-origin'
//     would block those <img> loads.
app.use(
  helmet({
    contentSecurityPolicy: false,
    crossOriginResourcePolicy: { policy: 'cross-origin' },
  }),
);

// ── CORS — restrict to an env-driven allowlist. Comma-separate origins in
// CORS_ORIGINS. If unset, all cross-origin requests are rejected.
const allowed = (process.env.CORS_ORIGINS || '')
  .split(',')
  .map((s) => s.trim())
  .filter(Boolean);

// Flutter web / desktop dev binds to a random localhost port on each run, so
// hardcoding a port in CORS_ORIGINS doesn't work. In non-production allow any
// localhost / 127.0.0.1 origin regardless of port. Never enabled in prod.
const LOCALHOST_RE = /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/;
const isDev = process.env.NODE_ENV !== 'production';

app.use(
  cors({
    origin: (origin, cb) => {
      // Same-origin / native mobile requests have no Origin header.
      if (!origin) return cb(null, true);
      if (allowed.includes(origin)) return cb(null, true);
      if (isDev && LOCALHOST_RE.test(origin)) return cb(null, true);
      return cb(new Error(`CORS: origin ${origin} not allowed`));
    },
    credentials: true,
  }),
);

// Request-ID first so it's available to the logger and every error handler.
app.use(requestId);
app.use(morgan(process.env.NODE_ENV === 'production' ? 'combined' : 'dev'));
app.use(express.json({ limit: '1mb' }));
app.use(express.urlencoded({ extended: true, limit: '1mb' }));

// Baseline rate limit on every route. Stricter per-endpoint limits are
// applied inside /login (see routes/login.js).
app.use(globalLimiter);

// ── Routers. Folder names are capitalised on disk; use the exact case so the
// app boots on case-sensitive filesystems (Linux/IIS-on-Azure-Linux).
const loginRouter = require('./routes/login');
const doctorUsersRouter = require('./routes/Doctor/users');
const doctorInsertRouter = require('./routes/Doctor/insert');
const doctorIndexRouter = require('./routes/Doctor/index');
const patientUsersRouter = require('./routes/Patient/users');
const patientInsertRouter = require('./routes/Patient/insert');
const patientIndexRouter = require('./routes/Patient/index');

// Public — login + token refresh must be reachable without a valid token.
app.use('/login', loginRouter);

// Authenticated — every doctor/patient endpoint now requires a valid JWT.
app.use('/doctor/users', protect, doctorUsersRouter);
app.use('/doctor/insert', protect, doctorInsertRouter);
app.use('/doctor/index', protect, doctorIndexRouter);
app.use('/patient/users', protect, patientUsersRouter);
app.use('/patient/insert', protect, patientInsertRouter);
app.use('/patient/index', protect, patientIndexRouter);

// Uploaded images — JWT-gated. Accepts Authorization header or ?token=
// query string (Image.network/<img> can't set headers). See
// routes/middleware/uploadAuth.js. The Flutter client must wrap any URL
// pointing at /uploads/ with the current access token before rendering.
app.use('/uploads', uploadAuth, express.static(path.join(__dirname, 'uploads')));

app.get('/', (req, res) => res.send('OK'));

// 404 fallthrough
app.use((req, res) => res.status(404).json({ error: 'Not Found' }));

// Global error handler. Catches anything a route forwards via next(err) or
// throws from synchronous middleware. Per-route async handlers should call
// the `serverError(req, res, err)` helper from routes/middleware/errors.js
// instead — same shape, doesn't require `next` to be in scope.
app.use((err, req, res, next) => {
  const status = err.status || 500;
  console.error(`[${req.id}] [UNHANDLED ${status}] ${req.method} ${req.originalUrl || req.path}:`, err);
  res.status(status).json({
    success: false,
    error: status >= 500 ? 'Internal Server Error' : err.message,
    correlation_id: req.id,
  });
});

module.exports = app;

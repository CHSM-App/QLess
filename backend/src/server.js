const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

// Validate required environment variables at startup
const REQUIRED_ENV = ['DB_SERVER', 'DB_USER', 'DB_PASSWORD', 'DB_NAME', 'JWT_SECRET_KEY', 'CORS_ORIGINS'];
const missing = REQUIRED_ENV.filter((key) => !process.env[key]);
if (missing.length > 0) {
  console.error(`[startup] Missing required environment variables: ${missing.join(', ')}`);
  console.error('[startup] Copy backend/.env.example to backend/.env and fill in the values.');
}

const WEAK_DEFAULTS = ['changeme', 'secret', 'jwt_secret', 'your_secret'];
const jwtSecret = process.env.JWT_SECRET_KEY || '';
const weakSecret = !!jwtSecret && (WEAK_DEFAULTS.includes(jwtSecret.toLowerCase()) || jwtSecret.length < 32);
if (weakSecret) {
  console.error('[startup] JWT_SECRET_KEY is weak — use at least 32 random characters.');
}
// Demo (store-review) logins accept a fixed OTP; with the well-known default
// anyone could sign in to the demo accounts.
const { demoEnabled, demoOtp, DEFAULT_OTP } = require('./demo');
const weakDemo = demoEnabled() && (demoOtp() === DEFAULT_OTP || demoOtp().length < 6);
if (weakDemo) {
  console.error('[startup] DEMO_ENABLED=true needs a non-default DEMO_OTP of 6+ digits.');
}
// In production a missing or weak secret is fatal: booting anyway would sign
// every session with a guessable key. Dev and test only warn.
if (process.env.NODE_ENV === 'production' && (missing.length > 0 || weakSecret || weakDemo)) {
  console.error('[startup] Refusing to start in production with the configuration errors above.');
  process.exit(1);
}

const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const http = require('http');
const log = require('./middleware/logger');

const protect = require('./middleware/protect');
const authorize = require('./middleware/authorize');
const { ROLE } = require('./middleware/roles');
const uploadAuth = require('./middleware/uploadAuth');
const requestId = require('./middleware/requestId');
const { globalLimiter, healthLimiter } = require('./middleware/rateLimit');
const db = require('./db');

const app = express();

// Behind IIS/nginx/Cloudflare. Without this, every request looks like it came
// from 127.0.0.1 and the rate limiter buckets everyone together.
app.set('trust proxy', 1);

// Security headers + Content-Security-Policy. No inline scripts anywhere (the
// admin / delete-account page scripts live in src/static/*.js); styles may be
// inline; pages embed data: images and use Google Fonts.
app.use(
  helmet({
    contentSecurityPolicy: {
      useDefaults: false,
      directives: {
        defaultSrc: ["'self'"],
        scriptSrc: ["'self'"],
        styleSrc: ["'self'", "'unsafe-inline'", 'https://fonts.googleapis.com'],
        fontSrc: ["'self'", 'https://fonts.gstatic.com', 'data:'],
        imgSrc: ["'self'", 'data:', 'https:'],
        connectSrc: ["'self'"],
        objectSrc: ["'none'"],
        baseUri: ["'self'"],
        formAction: ["'self'"],
        frameAncestors: ["'none'"],
      },
    },
    crossOriginResourcePolicy: { policy: 'cross-origin' },
  }),
);

// CORS — restrict to an env-driven allowlist.
const allowed = (process.env.CORS_ORIGINS || '')
  .split(',')
  .map((s) => s.trim())
  .filter(Boolean);

app.use(
  cors({
    origin: (origin, cb) => {
      if (!origin) return cb(null, true);
      if (allowed.includes(origin)) return cb(null, true);
      return cb(new Error(`CORS: origin ${origin} not allowed`));
    },
    credentials: true,
  }),
);

// Request-ID first so it's available to the logger and every error handler.
app.use(requestId);

// Uptime monitor (R1). Before hideServerErrors so a 503 keeps its body.
app.get('/health', healthLimiter, async (req, res) => {
  const uptime = Math.round(process.uptime());
  try {
    await db.ensureConnected();
    await db.request().query('SELECT 1 AS ok');
    res.json({ status: 'ok', db: 'up', uptime });
  } catch (err) {
    log.error('health: database down: ' + err.message);
    res.status(503).json({ status: 'degraded', db: 'down', uptime });
  }
});
// 5xx bodies never carry internal error text (logged with the request id instead).
app.use(require('./middleware/errors').hideServerErrors);
// /uploads?token=<jwt> — keep access tokens out of the request log.
morgan.token('url', (req) => (req.originalUrl || req.url).replace(/([?&]token=)[^&]*/g, '$1[REDACTED]'));
if (process.env.NODE_ENV !== 'test') {
  app.use(morgan(process.env.NODE_ENV === 'production' ? 'combined' : 'dev'));
}
app.use(express.json({ limit: '1mb' }));
app.use(express.urlencoded({ extended: true, limit: '1mb' }));

// Baseline rate limit on every route.
app.use(globalLimiter);

// ── Routers.
const authRouter = require('./routes/auth');
const doctorUsersRouter = require('./routes/doctor/users');
const doctorInsertRouter = require('./routes/doctor/insert');
const doctorIndexRouter = require('./routes/doctor/index');
const patientUsersRouter = require('./routes/patient/users');
const patientInsertRouter = require('./routes/patient/insert');
const patientIndexRouter = require('./routes/patient/index');

const accountRouter = require('./routes/account');
const adminRouter = require('./routes/admin');

// Public — login + token refresh must be reachable without a valid token.
app.use('/login', authRouter);

// Admin panel — auth happens inside the router itself (its own /login route
// issues the token; everything else there requires it).
app.use('/admin', adminRouter);

// Account deletion — OTP-verified, no JWT required.
app.use('/delete-account', accountRouter);

// Authenticated — every doctor/patient endpoint requires a valid JWT.
app.use('/doctor/users', protect, doctorUsersRouter);
// Queue, leave, schedule, prescriptions, walk-in: clinic staff only.
app.use('/doctor/insert', protect, authorize(ROLE.DOCTOR, ROLE.RECEPTIONIST), doctorInsertRouter);
app.use('/doctor/index', protect, doctorIndexRouter);
app.use('/patient/users', protect, patientUsersRouter);
// Booking, cancelling, family and favorites: patient tokens only. (patient/users
// lets staff into the few read routes the clinic app needs — see its guard.)
app.use('/patient/insert', protect, authorize(ROLE.PATIENT), patientInsertRouter);
app.use('/patient/index', protect, authorize(ROLE.PATIENT), patientIndexRouter);

// Uploaded images — JWT-gated. Folder: UPLOADS_DIR (src/uploads.js).
const UPLOADS_DIR = require('./uploads');
const PUBLIC_DIR = path.join(__dirname, '..', 'public');
app.use('/uploads', uploadAuth, express.static(UPLOADS_DIR));

// Landing page static assets (CSS, JS, images).
app.use(express.static(PUBLIC_DIR));
// Scripts of the server-rendered pages (admin panel, delete-account).
app.use('/static', express.static(path.join(__dirname, 'static'), { index: false }));

// Keep old Play Store privacy/logo links working.
app.get('/privacy', (req, res) => res.sendFile(path.join(__dirname, 'static', 'privacy.html')));
app.get('/privacy/logo', (req, res) => res.sendFile(path.join(__dirname, '..', '..', 'frontend', 'assets', 'icon', 'qless_logo.png')));

// React landing page — serve index.html for all non-API routes.
app.get('*', (req, res) => {
  const indexFile = path.join(PUBLIC_DIR, 'index.html');
  if (require('fs').existsSync(indexFile)) {
    return res.sendFile(indexFile);
  }
  res.status(404).json({ error: 'Not Found' });
});

// Global error handler.
app.use((err, req, res, next) => {
  const status = err.status || 500;
  log.error(`[${req.id}] [UNHANDLED ${status}] ${req.method} ${req.originalUrl || req.path}: ${err.stack || err.message}`);
  res.status(status).json({
    success: false,
    error: status >= 500 ? 'Internal Server Error' : err.message,
    correlation_id: req.id,
  });
});

// iisnode runs src/server.js directly — bind immediately so iisnode gets a
// live process. The DB pool connects eagerly in db.js and requests queue until
// it is ready. Tests require() this file with NODE_ENV=test and get only the app.
if (process.env.NODE_ENV !== 'test') {
  // Log instead of crashing: an iisnode restart mid-outage just lands the new
  // process in the same outage.
  process.on('unhandledRejection', (reason) => {
    log.error('Unhandled promise rejection: ' + ((reason && reason.stack) || String(reason)));
  });
  // Still exit (state is unknown after a throw), but record why first.
  process.on('uncaughtException', (err) => {
    log.error('Uncaught exception: ' + (err.stack || err.message));
    process.exit(1);
  });

  const port = process.env.PORT || 3000;
  const server = http.createServer(app);
  app.set('io', require('./realtime').attach(server, allowed));

  server.listen(port, () => {
    log.info('Listening on port ' + port);
  });

  server.on('error', (err) => {
    log.error('Server error: ' + err.message);
    process.exit(1);
  });
}

module.exports = app;

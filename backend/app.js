// ── TEMPORARY: write crash to a file so it's readable after process exits ───
const fs = require('fs');
const _crashLog = require('path').join(__dirname, 'startup-error.txt');
process.on('uncaughtException', (err) => {
  const msg = 'UNCAUGHT EXCEPTION: ' + err.stack + '\n';
  process.stderr.write(msg);
  fs.writeFileSync(_crashLog, msg);
  process.exit(1);
});
process.on('unhandledRejection', (reason) => {
  const msg = 'UNHANDLED REJECTION: ' + ((reason && reason.stack) ? reason.stack : String(reason)) + '\n';
  process.stderr.write(msg);
  fs.writeFileSync(_crashLog, msg);
  process.exit(1);
});

require('dotenv').config();

const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const path = require('path');
const log = require('./routes/middleware/logger');

const protect = require('./routes/middleware/protect');
const uploadAuth = require('./routes/middleware/uploadAuth');
const requestId = require('./routes/middleware/requestId');
const { globalLimiter } = require('./routes/middleware/rateLimit');

const app = express();

// Behind IIS/nginx/Cloudflare. Without this, every request looks like it came
// from 127.0.0.1 and the rate limiter buckets everyone together.
app.set('trust proxy', 1);

// ── TEMPORARILY DISABLED FOR DEBUGGING ──────────────────────────────────────
// app.use(helmet({ contentSecurityPolicy: false, crossOriginResourcePolicy: { policy: 'cross-origin' } }));
// app.use(cors({ origin: (origin, cb) => { ... }, credentials: true }));
// app.use(globalLimiter);
// ────────────────────────────────────────────────────────────────────────────

// Allow all origins (temporary)
app.use(cors());

// Request-ID first so it's available to the logger and every error handler.
app.use(requestId);
app.use(morgan(process.env.NODE_ENV === 'production' ? 'combined' : 'dev'));
app.use(express.json({ limit: '1mb' }));
app.use(express.urlencoded({ extended: true, limit: '1mb' }));

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

// ── TEMPORARILY: JWT auth disabled for debugging ────────────────────────────
app.use('/doctor/users', doctorUsersRouter);
app.use('/doctor/insert', doctorInsertRouter);
app.use('/doctor/index', doctorIndexRouter);
app.use('/patient/users', patientUsersRouter);
app.use('/patient/insert', patientInsertRouter);
app.use('/patient/index', patientIndexRouter);

// ── TEMPORARILY: upload auth disabled
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

app.get('/', (req, res) => res.send('OK'));


// 404 fallthrough
app.use((req, res) => res.status(404).json({ error: 'Not Found' }));

// Global error handler. Catches anything a route forwards via next(err) or
// throws from synchronous middleware. Per-route async handlers should call
// the `serverError(req, res, err)` helper from routes/middleware/errors.js
// instead — same shape, doesn't require `next` to be in scope.
app.use((err, req, res, next) => {
  const status = err.status || 500;
  log.error(`[${req.id}] [UNHANDLED ${status}] ${req.method} ${req.originalUrl || req.path}: ${err.stack || err.message}`);
  res.status(status).json({
    success: false,
    error: status >= 500 ? 'Internal Server Error' : err.message,
    correlation_id: req.id,
  });
});

module.exports = app;

// iisnode runs app.js directly (it does not use `npm start` or bin/www).
// Bind the HTTP port immediately so iisnode gets a live server; the DB pool
// connects eagerly in routes/db.js and routes will queue until it is ready.
const http = require('http');
const db = require('./routes/db');
const port = process.env.PORT || '3000';
app.set('port', port);
const server = http.createServer(app);
server.listen(port, () => log.info('Listening on port ' + port));
server.on('error', (err) => {
  log.error('Server error: ' + err.message);
  process.exit(1);
});
db.ready()
  .then(() => log.info('DB pool ready'))
  .catch((err) => log.error('DB connection failed at startup: ' + err.message));

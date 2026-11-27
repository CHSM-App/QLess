# QLess — old backend (backup)

Snapshot of the backend **before** the restructure, taken from git commit
`762a128d` ("feat: Enhance offline sync functionality and error handling"): the Express app
(`app.js`, `bin/www`, `routes/**`), its config, the one-off SQL scripts, and the
production schema dump with all 18 stored procedures (`scripts/schema/full-schema.sql`).

The code that replaced it lives in `backend/src/` (routes, `src/queries/` for the former
stored procedures) and `backend/src/migrations/`. **Reference only — nothing here is run.**

- Files: 46 (18,696 lines)
- Not included (binary / unchanged / generated): 85 files — images
  (`routes/BusinessImages/*`, `uploads/*`), the `public/` landing-page build, the HTML pages
  (moved unchanged to `src/static/`), `logo_b64.txt`, `startup-error.txt`, `.user.ini`, `package-lock.json`.
- Any file, including those, can be restored exactly from git:
  `git show 762a128d:backend/<path> > <file>`

## Contents

- [`backend/app.js`](#backend-app-js)
- [`backend/bin/www`](#backend-bin-www)
- [`backend/routes/admin.js`](#backend-routes-admin-js)
- [`backend/routes/db.js`](#backend-routes-db-js)
- [`backend/routes/delete-account.js`](#backend-routes-delete-account-js)
- [`backend/routes/Doctor/index.js`](#backend-routes-doctor-index-js)
- [`backend/routes/Doctor/insert.js`](#backend-routes-doctor-insert-js)
- [`backend/routes/Doctor/users.js`](#backend-routes-doctor-users-js)
- [`backend/routes/login.js`](#backend-routes-login-js)
- [`backend/routes/middleware/auth.js`](#backend-routes-middleware-auth-js)
- [`backend/routes/middleware/authorize.js`](#backend-routes-middleware-authorize-js)
- [`backend/routes/middleware/errors.js`](#backend-routes-middleware-errors-js)
- [`backend/routes/middleware/logger.js`](#backend-routes-middleware-logger-js)
- [`backend/routes/middleware/protect.js`](#backend-routes-middleware-protect-js)
- [`backend/routes/middleware/rateLimit.js`](#backend-routes-middleware-ratelimit-js)
- [`backend/routes/middleware/requestId.js`](#backend-routes-middleware-requestid-js)
- [`backend/routes/middleware/roles.js`](#backend-routes-middleware-roles-js)
- [`backend/routes/middleware/upload.js`](#backend-routes-middleware-upload-js)
- [`backend/routes/middleware/uploadAuth.js`](#backend-routes-middleware-uploadauth-js)
- [`backend/routes/Patient/index.js`](#backend-routes-patient-index-js)
- [`backend/routes/Patient/insert.js`](#backend-routes-patient-insert-js)
- [`backend/routes/Patient/users.js`](#backend-routes-patient-users-js)
- [`backend/scripts/add-demo-patient.sql`](#backend-scripts-add-demo-patient-sql)
- [`backend/scripts/add-demo-receptionist.sql`](#backend-scripts-add-demo-receptionist-sql)
- [`backend/scripts/add-manoj-swant-kudal.sql`](#backend-scripts-add-manoj-swant-kudal-sql)
- [`backend/scripts/backfill-existing-doctor-verification.sql`](#backend-scripts-backfill-existing-doctor-verification-sql)
- [`backend/scripts/bookManojActiveQueue.js`](#backend-scripts-bookmanojactivequeue-js)
- [`backend/scripts/change-manoj-swant-mobile.sql`](#backend-scripts-change-manoj-swant-mobile-sql)
- [`backend/scripts/delete-doctors-except-1-30.sql`](#backend-scripts-delete-doctors-except-1-30-sql)
- [`backend/scripts/fix-receptionist-view.sql`](#backend-scripts-fix-receptionist-view-sql)
- [`backend/scripts/migrate-500-errors.js`](#backend-scripts-migrate-500-errors-js)
- [`backend/scripts/migrate-account-deletion.sql`](#backend-scripts-migrate-account-deletion-sql)
- [`backend/scripts/migrate-doctor-verification.sql`](#backend-scripts-migrate-doctor-verification-sql)
- [`backend/scripts/migrate-medicine-brand-components.sql`](#backend-scripts-migrate-medicine-brand-components-sql)
- [`backend/scripts/migrate-refresh-token-role.sql`](#backend-scripts-migrate-refresh-token-role-sql)
- [`backend/scripts/remove-demo-patient.sql`](#backend-scripts-remove-demo-patient-sql)
- [`backend/scripts/remove-demo-receptionist.sql`](#backend-scripts-remove-demo-receptionist-sql)
- [`backend/scripts/remove-manoj-swant-kudal.sql`](#backend-scripts-remove-manoj-swant-kudal-sql)
- [`backend/scripts/restore-first-original-doctor-sp.sql`](#backend-scripts-restore-first-original-doctor-sp-sql)
- [`backend/scripts/run-sql.js`](#backend-scripts-run-sql-js)
- [`backend/scripts/set-manoj-swant-kudal-location.sql`](#backend-scripts-set-manoj-swant-kudal-location-sql)
- [`backend/scripts/schema/full-schema.sql`](#backend-scripts-schema-full-schema-sql)
- [`backend/.env.example`](#backend-env-example)
- [`backend/.gitignore`](#backend-gitignore)
- [`backend/package.json`](#backend-package-json)
- [`backend/web.config`](#backend-web-config)

## `backend/app.js`

`````js
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


const http = require('http');
const { Server } = require('socket.io');

const app = express();

// Behind IIS/nginx/Cloudflare. Without this, every request looks like it came
// from 127.0.0.1 and the rate limiter buckets everyone together.
app.set('trust proxy', 1);

// Security headers.
app.use(
  helmet({
    contentSecurityPolicy: false,
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
app.use(morgan(process.env.NODE_ENV === 'production' ? 'combined' : 'dev'));
app.use(express.json({ limit: '1mb' }));
app.use(express.urlencoded({ extended: true, limit: '1mb' }));

// Baseline rate limit on every route.
app.use(globalLimiter);

// ── Routers.
const loginRouter = require('./routes/login');
const doctorUsersRouter = require('./routes/Doctor/users');
const doctorInsertRouter = require('./routes/Doctor/insert');
const doctorIndexRouter = require('./routes/Doctor/index');
const patientUsersRouter = require('./routes/Patient/users');
const patientInsertRouter = require('./routes/Patient/insert');
const patientIndexRouter = require('./routes/Patient/index');

const deleteAccountRouter = require('./routes/delete-account');
const adminRouter = require('./routes/admin');

// Public — login + token refresh must be reachable without a valid token.
app.use('/login', loginRouter);

// Admin panel — auth happens inside the router itself (its own /login route
// issues the token; everything else there requires it).
app.use('/admin', adminRouter);

// Account deletion — OTP-verified, no JWT required.
app.use('/delete-account', deleteAccountRouter);

// Authenticated — every doctor/patient endpoint requires a valid JWT.
app.use('/doctor/users', protect, doctorUsersRouter);
app.use('/doctor/insert', protect, doctorInsertRouter);
app.use('/doctor/index', protect, doctorIndexRouter);
app.use('/patient/users', protect, patientUsersRouter);
app.use('/patient/insert', protect, patientInsertRouter);
app.use('/patient/index', protect, patientIndexRouter);

// Uploaded images — JWT-gated.
app.use('/uploads', uploadAuth, express.static(path.join(__dirname, 'uploads')));

// Landing page static assets (CSS, JS, images).
app.use(express.static(path.join(__dirname, 'public')));

// Keep old Play Store privacy/logo links working.
app.get('/privacy', (req, res) => res.sendFile(path.join(__dirname, 'routes', 'privacy.html')));
app.get('/privacy/logo', (req, res) => res.sendFile(path.join(__dirname, '..', 'frontend', 'assets', 'icon', 'qless_logo.png')));


// React landing page — serve index.html for all non-API routes.
app.get('*', (req, res) => {
  const indexFile = path.join(__dirname, 'public', 'index.html');
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

module.exports = app;

// ── SERVER + SOCKET SETUP ───────────────────────────────────────
const db = require('./routes/db');
const port = process.env.PORT || 3000;

const server = http.createServer(app);

// SOCKET.IO INIT
const io = new Server(server, {
  cors: {
    origin: (origin, cb) => {
      if (!origin) return cb(null, true);
      if (allowed.includes(origin)) return cb(null, true);
      return cb(new Error(`CORS: origin ${origin} not allowed`));
    },
    methods: ['GET', 'POST'],
    credentials: true,
  },
});

app.set('io', io);

// doctorSockets: doctorId → Set<socketId>  (active connections)
// doctorStatus:  doctorId → true/false       (last known online state)
// doctorStatusAt: doctorId → timestamp of the last doctorStatus change
const doctorSockets = new Map();
const doctorStatus  = new Map();
const doctorStatusAt = new Map();
// doctorStatusReason: doctorId → 'disconnect' | 'logout'  (why the last offline happened,
// so patients can tell a real network problem apart from an intentional logout)
const doctorStatusReason = new Map();
// doctorOfflineTimers: doctorId → Timeout  (pending offline broadcast, cancelled on reconnect)
const doctorOfflineTimers = new Map();
// Grace period before telling patients a doctor is offline. Covers brief
// app-background/screen-lock/network-blip disconnects that Socket.IO
// normally reconnects from within a couple seconds.
const DOCTOR_OFFLINE_GRACE_MS = 8000;
// How long a stale "offline" reading stays worth telling a freshly-opened
// patient app about. Past this, it's not a live network issue anymore —
// the doctor just hasn't started today's session yet — so stop replaying it.
const DOCTOR_OFFLINE_STALE_MS = 30 * 60 * 1000;

// SOCKET EVENTS
io.on('connection', (socket) => {
  console.log('Socket connected:', socket.id);

  // Patient/general join.
  // Sends two immediate replies so the patient's screen is correct even if
  // they open the app after queue actions already happened:
  //   1. doctor_status  — avoids a stuck offline banner on reconnect
  //   2. queue_update   — seeds current_serving so the NOW circle shows the
  //                       real value instead of the SP's stale/buggy value
  socket.on('joinClinic', async (clinicId) => {
    socket.join(`clinic_${clinicId}`);
    if (doctorStatus.has(clinicId)) {
      const isOnline = doctorStatus.get(clinicId);
      const age = Date.now() - (doctorStatusAt.get(clinicId) || 0);
      if (isOnline || age < DOCTOR_OFFLINE_STALE_MS) {
        socket.emit('doctor_status', {
          doctor_id: clinicId,
          online: isOnline,
          reason: isOnline ? undefined : doctorStatusReason.get(clinicId),
        });
      }
    }
    // Fetch today's furthest-served token for this doctor and push it so the
    // Flutter app's doctorCurrentServing map is populated on cold start.
    try {
      const res = await db.request()
        .input('doctor_id', parseInt(clinicId))
        .query(`
          SELECT MAX(a.queue_number) AS current_serving
          FROM   appointments a
          JOIN   doctor_queue dq ON dq.queue_id = a.queue_id
          WHERE  dq.doctor_id = @doctor_id
            AND  CAST(dq.queue_date AS DATE) = CAST(GETDATE() AS DATE)
            AND  a.status IN ('in_progress', 'completed', 'cancelled', 'cancled', 'skipped')
            AND  NOT EXISTS (
                   SELECT 1 FROM appointments b
                   WHERE  b.queue_id = a.queue_id
                     AND  b.booking_type = 1
                     AND  b.queue_number < a.queue_number
                     AND  b.status NOT IN ('completed', 'cancelled', 'cancled', 'skipped')
                 )
        `);
      const cs = res.recordset[0]?.current_serving;
      if (cs != null && cs > 0) {
        socket.emit('queue_update', { event: 'initial', doctor_id: clinicId, current_serving: cs });
      }
    } catch (_) {}
  });

  // Doctor join — tracked for offline detection
  socket.on('doctorJoinClinic', (doctorId) => {
    console.log(`[DOCTOR] doctorJoinClinic doctorId=${doctorId} socket=${socket.id}`);
    socket.join(`clinic_${doctorId}`);
    if (!doctorSockets.has(doctorId)) doctorSockets.set(doctorId, new Set());
    doctorSockets.get(doctorId).add(socket.id);
    socket._doctorRooms = socket._doctorRooms || new Set();
    socket._doctorRooms.add(doctorId);

    // Reconnected before the grace period elapsed — cancel the pending offline broadcast.
    const pendingTimer = doctorOfflineTimers.get(doctorId);
    if (pendingTimer) {
      clearTimeout(pendingTimer);
      doctorOfflineTimers.delete(doctorId);
    }

    doctorStatus.set(doctorId, true);
    doctorStatusAt.set(doctorId, Date.now());
    doctorStatusReason.delete(doctorId);
    io.to(`clinic_${doctorId}`).emit('doctor_status', { doctor_id: doctorId, online: true });
    console.log(`[DOCTOR] emitted online=true to clinic_${doctorId}`);
  });

  socket.on('leaveClinic', (clinicId) => {
    socket.leave(`clinic_${clinicId}`);
  });

  // Explicit doctor logout — skip the reconnect grace period and tell
  // patients immediately, since this isn't a network blip.
  socket.on('doctorLogout', (doctorId) => {
    console.log(`[DOCTOR] doctorLogout doctorId=${doctorId} socket=${socket.id}`);
    const pendingTimer = doctorOfflineTimers.get(doctorId);
    if (pendingTimer) {
      clearTimeout(pendingTimer);
      doctorOfflineTimers.delete(doctorId);
    }
    const sockets = doctorSockets.get(doctorId);
    if (sockets) {
      sockets.delete(socket.id);
      if (sockets.size === 0) doctorSockets.delete(doctorId);
    }
    doctorStatus.set(doctorId, false);
    doctorStatusAt.set(doctorId, Date.now());
    doctorStatusReason.set(doctorId, 'logout');
    io.to(`clinic_${doctorId}`).emit('doctor_status', { doctor_id: doctorId, online: false, reason: 'logout' });
    console.log(`[DOCTOR] emitted online=false to clinic_${doctorId} (explicit logout)`);
  });

  socket.on('disconnect', () => {
    console.log('Socket disconnected:', socket.id, '| doctorRooms:', socket._doctorRooms ? [...socket._doctorRooms] : 'none');
    if (socket._doctorRooms) {
      for (const doctorId of socket._doctorRooms) {
        const sockets = doctorSockets.get(doctorId);
        if (sockets) {
          sockets.delete(socket.id);
          if (sockets.size === 0) {
            doctorSockets.delete(doctorId);
            // Don't broadcast offline immediately — give the doctor's app a
            // grace period to reconnect (background/lock/network blip).
            const existingTimer = doctorOfflineTimers.get(doctorId);
            if (existingTimer) clearTimeout(existingTimer);
            const timer = setTimeout(() => {
              doctorOfflineTimers.delete(doctorId);
              const stillConnected = doctorSockets.get(doctorId);
              if (stillConnected && stillConnected.size > 0) return; // reconnected in the meantime
              doctorStatus.set(doctorId, false); // remember offline state
              doctorStatusAt.set(doctorId, Date.now());
              doctorStatusReason.set(doctorId, 'disconnect');
              io.to(`clinic_${doctorId}`).emit('doctor_status', { doctor_id: doctorId, online: false, reason: 'disconnect' });
              console.log(`[DOCTOR] emitted online=false to clinic_${doctorId} (after grace period)`);
            }, DOCTOR_OFFLINE_GRACE_MS);
            doctorOfflineTimers.set(doctorId, timer);
          }
        }
      }
    }
  });
});

// START SERVER
server.listen(port, () => {
  log.info('Listening on port ' + port);
});

server.on('error', (err) => {
  log.error('Server error: ' + err.message);
  process.exit(1);
});

// DB READY
db.ready()
  .then(() => log.info('DB pool ready'))
  .catch((err) =>
    log.error('DB connection failed at startup: ' + err.message)
  );
`````

## `backend/bin/www`

`````js
#!/usr/bin/env node

/**
 * Module dependencies.
 */

require('dotenv').config();
var app = require('../app');
var debug = require('debug')('donotwait:server');
var http = require('http');
var db = require('../routes/db');

/**
 * Get port from environment and store in Express.
 */

var port = normalizePort(process.env.PORT || '3000');
app.set('port', port);

/**
 * Create HTTP server.
 */

var server = http.createServer(app);

/**
 * Wait for the DB pool to be ready before accepting requests, otherwise the
 * first N requests after cold start race the pool and 500.
 */

db.ready()
  .then(function () {
    server.listen(port);
    server.on('error', onError);
    server.on('listening', onListening);
  })
  .catch(function (err) {
    console.error('Startup failed: DB not reachable', err.message);
    process.exit(1);
  });

/**
 * Last-resort process-level handlers. An unhandled rejection won't crash the
 * worker silently; an uncaught exception logs and exits so a supervisor
 * (IIS/PM2/systemd) can restart cleanly.
 */
process.on('unhandledRejection', function (reason) {
  console.error('UNHANDLED REJECTION:', reason);
});
process.on('uncaughtException', function (err) {
  console.error('UNCAUGHT EXCEPTION:', err);
  process.exit(1);
});

/**
 * Normalize a port into a number, string, or false.
 */

function normalizePort(val) {
  var port = parseInt(val, 10);

  if (isNaN(port)) {
    // named pipe
    return val;
  }

  if (port >= 0) {
    // port number
    return port;
  }

  return false;
}

/**
 * Event listener for HTTP server "error" event.
 */

function onError(error) {
  if (error.syscall !== 'listen') {
    throw error;
  }

  var bind = typeof port === 'string'
    ? 'Pipe ' + port
    : 'Port ' + port;

  // handle specific listen errors with friendly messages
  switch (error.code) {
    case 'EACCES':
      console.error(bind + ' requires elevated privileges');
      process.exit(1);
      break;
    case 'EADDRINUSE':
      console.error(bind + ' is already in use');
      process.exit(1);
      break;
    default:
      throw error;
  }
}

/**
 * Event listener for HTTP server "listening" event.
 */

function onListening() {
  var addr = server.address();
  var bind = typeof addr === 'string'
    ? 'pipe ' + addr
    : 'port ' + addr.port;
  debug('Listening on ' + bind);
  console.log('Listening on ' + bind);
}
`````

## `backend/routes/admin.js`

`````js
const express = require('express');
const router = express.Router();
const jwt = require('jsonwebtoken');
const path = require('path');
const crypto = require('crypto');
require('dotenv').config();

const auth = require('./middleware/auth');
const authorize = require('./middleware/authorize');
const { ROLE } = require('./middleware/roles');
const { authLimiter } = require('./middleware/rateLimit');
const db = require('./db');
const log = require('./middleware/logger');

// There is no admin table — a single shared staff credential (env vars)
// mints a token carrying ROLE.ADMIN. Good enough for one support team;
// revisit with a real admin table if more than one person needs their own
// login.
function constantTimeEqual(a, b) {
	const bufA = Buffer.from(String(a));
	const bufB = Buffer.from(String(b));
	if (bufA.length !== bufB.length) return false;
	return crypto.timingSafeEqual(bufA, bufB);
}

// Unauthenticated static page — it handles its own login form and only
// calls the protected routes below once it has a token.
router.get('/', (req, res) => {
	res.sendFile(path.join(__dirname, 'admin-panel.html'));
});

router.post('/login', authLimiter, (req, res) => {
	const { username, password } = req.body || {};
	const envUser = process.env.ADMIN_USERNAME;
	const envPass = process.env.ADMIN_PASSWORD;

	if (!envUser || !envPass) {
		log.error('admin login attempted but ADMIN_USERNAME/ADMIN_PASSWORD are not set');
		return res.status(500).json({ error: 'Admin panel is not configured.' });
	}

	if (!username || !password ||
		!constantTimeEqual(username, envUser) ||
		!constantTimeEqual(password, envPass)) {
		return res.status(401).json({ error: 'Invalid credentials' });
	}

	const accessToken = jwt.sign(
		{ role_id: ROLE.ADMIN, uid: 'admin' },
		process.env.JWT_SECRET_KEY,
		{ expiresIn: '4h' }
	);

	return res.json({ accessToken });
});

// Everything below requires a valid admin token.
router.use(auth, authorize(ROLE.ADMIN));

router.get('/doctors/pending', async (req, res) => {
	try {
		const result = await db.request()
			.input('operation', 'ListPendingDoctors')
			.execute('sp_doctor_login');
		res.json(result.recordset);
	} catch (err) {
		log.error('admin ListPendingDoctors error: ' + err.message);
		res.status(500).json({ error: err.message });
	}
});

router.post('/doctors/:id/verify', async (req, res) => {
	const doctorId = parseInt(req.params.id, 10);
	if (!doctorId) return res.status(400).json({ error: 'Invalid doctor id' });

	try {
		const result = await db.request()
			.input('operation', 'VerifyDoctor')
			.input('doctor_id', doctorId)
			.execute('sp_doctor_login');
		res.json(result.recordset?.[0] || { success: true });
	} catch (err) {
		log.error('admin VerifyDoctor error: ' + err.message);
		res.status(500).json({ error: err.message });
	}
});

router.post('/doctors/:id/reject', async (req, res) => {
	const doctorId = parseInt(req.params.id, 10);
	if (!doctorId) return res.status(400).json({ error: 'Invalid doctor id' });

	try {
		// Reuses the existing soft-delete operation — a rejected doctor should
		// disappear from the pending queue and be unable to log in, exactly
		// like a deleted one.
		const result = await db.request()
			.input('operation', 'DeleteDoctor')
			.input('doctor_id', doctorId)
			.execute('sp_doctor_login');
		res.json(result.recordset?.[0] || { success: true });
	} catch (err) {
		log.error('admin reject doctor error: ' + err.message);
		res.status(500).json({ error: err.message });
	}
});

module.exports = router;
`````

## `backend/routes/db.js`

`````js
const sql = require('mssql');
require('dotenv').config();
const log = require('./middleware/logger');

const required = ['DB_USER', 'DB_PASSWORD', 'DB_SERVER', 'DB_NAME'];
for (const k of required) {
  if (!process.env[k]) {
    throw new Error(`Missing required env var: ${k}. Copy .env.example to .env and fill in values.`);
  }
}

const sqlConfig = {
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  server: process.env.DB_SERVER,
  database: process.env.DB_NAME,
  port: parseInt(process.env.DB_PORT, 10) || 1433,
  options: {
    encrypt: true,
    // Self-signed certs only acceptable outside production.
    trustServerCertificate: true,
  },
  pool: {
    max: parseInt(process.env.DB_POOL_MAX, 10) || 20,
    min: parseInt(process.env.DB_POOL_MIN, 10) || 0,
    idleTimeoutMillis: 30000,
  },
};

const pool = new sql.ConnectionPool(sqlConfig);

// Eagerly start connecting; routes that call pool.request() before the
// connection resolves will queue, not crash. bin/www awaits ready() before
// binding the HTTP port so the first request always finds a live pool.
 let readyPromise = pool.connect()
  .then(() => {
    log.info('MSSQL connected');
    return pool;
  })
  .catch((err) => {
    log.error('MSSQL connection failed: ' + err.message);
    throw err;
  });

const originalRequest = pool.request.bind(pool);
pool.request = function () {
  if (!pool.connected && !pool.connecting) {
    readyPromise = pool.connect()
      .then(() => {
        log.info('MSSQL reconnected');
        return pool;
      })
      .catch((err) => {
        log.error('MSSQL reconnect failed: ' + err.message);
        throw err;
      });
  }
  return originalRequest();
};

pool.on('error', (err) => {
  log.error('MSSQL pool error: ' + err.message);
  if (pool.closed) {
    readyPromise = pool.connect()
      .then(() => {
        log.info('MSSQL reconnected after pool error');
        return pool;
      })
      .catch((error) => {
        log.error('MSSQL reconnect after pool error failed: ' + error.message);
        throw error;
      });
  }
});

module.exports = pool;
module.exports.ready = () => readyPromise;
`````

## `backend/routes/delete-account.js`

`````js
'use strict';

/**
 * Account deletion endpoints — called by the public landing page form.
 * No JWT required. Identity is proven via WhatsApp OTP (reuses /login/send-otp
 * and /login/verify-otp flow already in place).
 *
 * Flow:
 *   1. POST /delete-account/request
 *        • Accepts { phone, role_id }
 *        • Sends WhatsApp OTP via existing /login/send-otp logic
 *        • Always returns 200 (no user enumeration)
 *
 *   2. POST /delete-account/confirm
 *        • Accepts { phone, role_id, otp, reason? }
 *        • Verifies OTP via existing sp_otp / bcrypt flow
 *        • Upserts AccountDeletionRequests row
 *          (scheduled_for = now + 30 days, status = 'pending')
 *        • Returns scheduled_for date
 *
 *   3. POST /delete-account/cancel
 *        • Accepts { phone, role_id, otp }
 *        • Verifies fresh OTP
 *        • Marks pending request as cancelled
 */

const express = require('express');
const bcrypt  = require('bcryptjs');
const axios   = require('axios');
const db      = require('./db');
const log     = require('./middleware/logger');
const { deletionLimiter } = require('./middleware/rateLimit');

const router = express.Router();

const DELETION_DELAY_DAYS = 30;

const VALID_ROLE_IDS = [1, 2, 3]; // 1=Doctor, 2=Patient, 3=Receptionist

// Review/QA demo accounts (mirrors DEMO_RANGES in routes/login.js — keep in
// sync). They have no real phone, so no OTP is sent: the fixed demo OTP is
// accepted instead, and confirming deletion is a harmless no-op so the account
// stays usable for the next reviewer.
const DEMO_OTP = process.env.DEMO_OTP || '123456';
const DEMO_RANGES = [
  [9000000001, 9000000001],
  [9876000001, 9876000030],
  [9877000001, 9877000030],
  [9878000001, 9878000050],
];
function isDemoPhone(phone) {
  const n = Number(phone);
  return !!n && DEMO_RANGES.some(([from, to]) => n >= from && n <= to);
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

function normalizePhone(raw) {
  if (!raw) return null;
  let n = raw.toString().trim().replace(/\D/g, '');
  if (n.startsWith('91') && n.length > 10) n = n.slice(n.length - 10);
  if (n.startsWith('0')) n = n.replace(/^0+/, '');
  return /^[6-9]\d{9}$/.test(n) ? n : null;
}

async function sendWhatsAppOtp(phone) {
  const otp = Math.floor(100000 + Math.random() * 900000).toString();

  if (!process.env.WHATSAPP_API_TOKEN) {
    throw new Error('WhatsApp API token not configured');
  }

  const waRes = await axios.post('https://api2.smsala.com/whatsapp/SendOtp', {
    PhoneNumber: `91${phone}`,
    OtpCode: otp,
    ApiToken: process.env.WHATSAPP_API_TOKEN,
    TemplateId: 463,
  });

  if (!waRes.data || waRes.data.IsSuccess !== true) {
    throw new Error('Failed to send OTP via WhatsApp');
  }

  const otp_hash = await bcrypt.hash(otp, 10);

  const dbResult = await db.request()
    .input('operation', 'send_otp')
    .input('mobile_no', phone)
    .input('otp_hash', otp_hash)
    .execute('sp_otp');

  if (dbResult.recordset[0].status === 0) {
    throw new Error(dbResult.recordset[0].message || 'Failed to save OTP');
  }

  // Return otp in non-production for dev convenience (mirrors /login/send-otp)
  return process.env.NODE_ENV !== 'production' ? otp : null;
}

async function verifyOtp(phone, otp) {
  const result = await db.request()
    .input('operation', 'verify_otp')
    .input('mobile_no', phone)
    .execute('sp_otp');

  const data = result.recordset[0];
  if (!data || data.status === 0) return false;

  const isMatch = await bcrypt.compare(otp, data.otp_hash);
  if (!isMatch) {
    await db.request()
      .input('operation', 'update_attempt')
      .input('mobile_no', phone)
      .execute('sp_otp');
    return false;
  }

  await db.request()
    .input('operation', 'mark_verified')
    .input('mobile_no', phone)
    .execute('sp_otp');

  return true;
}

// ─────────────────────────────────────────────────────────────────────────────
// POST /delete-account/request
// Sends a WhatsApp OTP to the given phone. Always 200 — prevents enumeration.
// ─────────────────────────────────────────────────────────────────────────────

router.post('/request', deletionLimiter, async (req, res) => {
  const phone  = normalizePhone(req.body.phone);
  const roleId = parseInt(req.body.role_id);

  if (!phone) {
    return res.status(400).json({ success: false, message: 'Invalid phone number.' });
  }
  if (!VALID_ROLE_IDS.includes(roleId)) {
    return res.status(400).json({ success: false, message: 'Invalid role_id.' });
  }

  if (isDemoPhone(phone)) {
    return res.json({
      success: true,
      message: 'If an account exists for this number, an OTP has been sent via WhatsApp.',
    });
  }

  try {
    const devOtp = await sendWhatsAppOtp(phone);
    log.info(`[DELETE-ACCOUNT] OTP sent phone=${phone} role_id=${roleId}`);
    return res.json({
      success: true,
      message: 'If an account exists for this number, an OTP has been sent via WhatsApp.',
      ...(devOtp ? { dev_otp: devOtp } : {}),
    });
  } catch (err) {
    log.error('[DELETE-ACCOUNT] request error: ' + err.message);
    // Return 200 even on OTP send failure — no enumeration
    return res.json({
      success: true,
      message: 'If an account exists for this number, an OTP has been sent via WhatsApp.',
    });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /delete-account/confirm
// Verifies OTP and schedules the account for deletion in 30 days.
// ─────────────────────────────────────────────────────────────────────────────

router.post('/confirm', deletionLimiter, async (req, res) => {
  const phone  = normalizePhone(req.body.phone);
  const roleId = parseInt(req.body.role_id);
  const otp    = (req.body.otp || '').toString().trim();
  const reason = req.body.reason || null;

  if (!phone) {
    return res.status(400).json({ success: false, message: 'Invalid phone number.' });
  }
  if (!VALID_ROLE_IDS.includes(roleId)) {
    return res.status(400).json({ success: false, message: 'Invalid role_id.' });
  }
  if (!/^\d{6}$/.test(otp)) {
    return res.status(400).json({ success: false, message: 'OTP must be a 6-digit number.' });
  }

  if (isDemoPhone(phone)) {
    if (otp !== DEMO_OTP) {
      return res.status(400).json({ success: false, message: 'Invalid or expired OTP.' });
    }
    const demoDate = new Date(Date.now() + DELETION_DELAY_DAYS * 24 * 60 * 60 * 1000);
    log.info(`[DELETE-ACCOUNT] demo account confirm (no-op) phone=${phone} role_id=${roleId}`);
    return res.json({
      success: true,
      message: `Your account is scheduled for deletion on ${demoDate.toDateString()}. You can cancel before that date.`,
      scheduled_for: demoDate,
    });
  }

  try {
    const otpValid = await verifyOtp(phone, otp);
    if (!otpValid) {
      return res.status(400).json({ success: false, message: 'Invalid or expired OTP.' });
    }

    const now         = new Date();
    const scheduledFor = new Date(now.getTime() + DELETION_DELAY_DAYS * 24 * 60 * 60 * 1000);

    // Check for existing pending request
    const existing = await db.request()
      .input('phone',   phone)
      .input('role_id', roleId)
      .query(`
        SELECT id, scheduled_for
        FROM AccountDeletionRequests
        WHERE phone = @phone AND role_id = @role_id AND status = 'pending'
      `);

    if (existing.recordset.length > 0) {
      return res.status(409).json({
        success: false,
        message: 'A deletion request already exists for this account.',
        scheduled_for: existing.recordset[0].scheduled_for,
      });
    }

    await db.request()
      .input('phone',           phone)
      .input('role_id',         roleId)
      .input('reason',          reason ? reason.toString().slice(0, 500) : null)
      .input('otp_verified_at', now)
      .input('scheduled_for',   scheduledFor)
      .query(`
        INSERT INTO AccountDeletionRequests
          (phone, role_id, reason, otp_verified_at, scheduled_for, status)
        VALUES
          (@phone, @role_id, @reason, @otp_verified_at, @scheduled_for, 'pending')
      `);

    log.info(`[DELETE-ACCOUNT] request created phone=${phone} role_id=${roleId} scheduled_for=${scheduledFor.toISOString()}`);

    return res.json({
      success: true,
      message: `Your account is scheduled for deletion on ${scheduledFor.toDateString()}. You can cancel before that date.`,
      scheduled_for: scheduledFor,
    });
  } catch (err) {
    log.error('[DELETE-ACCOUNT] confirm error: ' + err.message);
    return res.status(500).json({ success: false, message: 'Server error. Please try again.' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /delete-account/cancel
// Cancels a pending deletion request after verifying a fresh OTP.
// ─────────────────────────────────────────────────────────────────────────────

router.post('/cancel', deletionLimiter, async (req, res) => {
  const phone  = normalizePhone(req.body.phone);
  const roleId = parseInt(req.body.role_id);
  const otp    = (req.body.otp || '').toString().trim();

  if (!phone) {
    return res.status(400).json({ success: false, message: 'Invalid phone number.' });
  }
  if (!VALID_ROLE_IDS.includes(roleId)) {
    return res.status(400).json({ success: false, message: 'Invalid role_id.' });
  }
  if (!/^\d{6}$/.test(otp)) {
    return res.status(400).json({ success: false, message: 'OTP must be a 6-digit number.' });
  }

  if (isDemoPhone(phone)) {
    if (otp !== DEMO_OTP) {
      return res.status(400).json({ success: false, message: 'Invalid or expired OTP.' });
    }
    return res.json({
      success: true,
      message: 'Your account deletion request has been cancelled. Your account is safe.',
    });
  }

  try {
    const otpValid = await verifyOtp(phone, otp);
    if (!otpValid) {
      return res.status(400).json({ success: false, message: 'Invalid or expired OTP.' });
    }

    const requestResult = await db.request()
      .input('phone',   phone)
      .input('role_id', roleId)
      .query(`
        SELECT id FROM AccountDeletionRequests
        WHERE phone = @phone AND role_id = @role_id AND status = 'pending'
      `);

    if (requestResult.recordset.length === 0) {
      return res.status(404).json({ success: false, message: 'No pending deletion request found for this account.' });
    }

    const requestId = requestResult.recordset[0].id;

    await db.request()
      .input('id', requestId)
      .query(`UPDATE AccountDeletionRequests SET status = 'cancelled' WHERE id = @id`);

    log.info(`[DELETE-ACCOUNT] request cancelled phone=${phone} role_id=${roleId} id=${requestId}`);

    return res.json({
      success: true,
      message: 'Your account deletion request has been cancelled. Your account is safe.',
    });
  } catch (err) {
    log.error('[DELETE-ACCOUNT] cancel error: ' + err.message);
    return res.status(500).json({ success: false, message: 'Server error. Please try again.' });
  }
});

module.exports = router;
`````

## `backend/routes/Doctor/index.js`

`````js
var express = require('express');
var router = express.Router();
var db = require('../db');
var sql = require('mssql');
const log = require('../middleware/logger');
const authorize = require('../middleware/authorize');
const { ROLE } = require('../middleware/roles');

// DELETE Medicine (per-doctor link unlink)
router.delete("/deleteMedicine/:doctor_id/:medicine_id", authorize(ROLE.DOCTOR), async (req, res) => {
  try {
    const { doctor_id, medicine_id } = req.params;

    if (!medicine_id || !doctor_id) {
      return res.status(400).json({
        success: false,
        message: "doctor_id and medicine_id are required"
      });
    }

    const request = db.request();
    request.input("operation", "Delete");
    request.input("doctor_id", sql.Int, parseInt(doctor_id));
    request.input("medicine_id", sql.Int, parseInt(medicine_id));

    const result = await request.execute("sp_Medicine_Master");

    // SP returns 'Medicine removed from your list.' on success
    // OR 'No medicine found to delete.' on failure
    const message = result.recordset?.[0]?.Message || "Operation completed";
    const lower = message.toLowerCase();
    const success = lower.includes("removed") || lower.includes("successfully");

    return res.status(success ? 200 : 400).json({
      success,
      message
    });

  } catch (err) {
    log.error('Error in deleteMedicine API: ' + err.message);

    return res.status(500).json({
      success: false,
      message: err.message || "Failed to delete medicine"
    });
  }
});




// Clinic gallery — soft-remove selected gallery images for a clinic.
// Mounted at /doctor/index → DELETE /doctor/index/delete/clinicGallery
// Body: { clinic_id, image_urls: [..] }. SP splits @image_url on ','.
router.delete("/delete/clinicGallery", authorize(ROLE.DOCTOR), async (req, res) => {
  try {
    const { clinic_id, image_urls } = req.body;
    const urls = Array.isArray(image_urls)
      ? image_urls.map((u) => (u || "").toString().trim()).filter(Boolean)
      : [];

    if (!clinic_id || urls.length === 0) {
      return res.status(400).json({
        success: false,
        message: "clinic_id and a non-empty image_urls array are required",
      });
    }

    const result = await db.request()
      .input("operation", "deleteClinicGallery")
      .input("clinic_id", clinic_id)
      .input("image_url", urls.join(","))
      .execute("sp_doctor_login");

    const deletedCount = result.recordset?.[0]?.deleted_count ?? 0;
    return res.status(200).json({
      success: true,
      deleted_count: deletedCount,
      message: result.recordset?.[0]?.message || "Images deleted",
    });
  } catch (err) {
    log.error("Error in deleteClinicGallery API: " + err.message);
    return res.status(500).json({
      success: false,
      message: err.message || "Failed to delete clinic gallery images",
    });
  }
});



// DELETE Receptionist
router.delete("/deletereceptionist/:recep_id", authorize(ROLE.DOCTOR), async (req, res) => {
  try {
    const { recep_id } = req.params;

    if (!recep_id) {
      return res.status(400).json({
        success: false,
        message: "recep_id is required"
      });
    }

    const request = db.request();
    request.input("operation", "DeleteReceptionist");
    request.input("recep_id", sql.Int, parseInt(recep_id));

    const result = await request.execute("sp_receptionist");

    // SP returns 'Medicine removed from your list.' on success
    // OR 'No medicine found to delete.' on failure
    const message = result.recordset?.[0]?.Message || "Operation completed";
    const lower = message.toLowerCase();
    const success = lower.includes("removed") || lower.includes("successfully");

    return res.status(success ? 200 : 400).json({
      success,
      message
    });

  } catch (err) {
    log.error('Error in deleteReceptionist API: ' + err.message);

    return res.status(500).json({
      success: false,
      message: err.message || "Failed to delete receptionist"
    });
  }
});


module.exports = router;
`````

## `backend/routes/Doctor/insert.js`

`````js
var express = require('express');
var router = express.Router();
var db = require('../db'); // go from admin/ to routes/
const sql = require("mssql");
const multer = require("multer");
const path = require("path");
const fs = require("fs-extra");
const admin = require("firebase-admin");
const cron = require('node-cron');
const log = require('../middleware/logger');

// Helper — emits a queue_update event to all sockets in clinic_<doctor_id> room.
// req.app.get('io') is available because app.set('io', io) is called in app.js.
function emitQueueUpdate(req, event, doctor_id, extra = {}) {
  const io = req.app.get('io');
  if (io && doctor_id) io.to('clinic_' + doctor_id).emit('queue_update', { event, doctor_id, ...extra });
}

// Actions the doctor took offline are replayed on reconnect carrying
// offline_queued_at (UTC ISO, set on the device when queued). Live pushes like
// "Your Turn Now" for an action older than this are stale — that patient was
// already seen — so routes skip them; socket updates still go out.
// ponytail: trusts the device clock; use server receive time if clocks drift.
const STALE_REPLAY_MS = 10 * 60 * 1000;
function isStaleReplay(req) {
  const t = Date.parse(req.body?.offline_queued_at);
  return Number.isFinite(t) && Date.now() - t > STALE_REPLAY_MS;
}

// Returns the furthest queue_number the active queue has reached — MAX among
// in_progress and completed only. Skipped patients are handled outside the
// main queue and must not affect this value. When a skipped patient is
// recalled (skipped → in_progress), completed tokens still dominate the MAX
// (e.g. recalled token 2 after token 4 was completed → MAX = 4 ✓).
async function fetchCurrentServing(appointment_id) {
  try {
    const res = await db.request()
      .input('appointment_id', sql.Int, parseInt(appointment_id))
      .query(`
        SELECT MAX(a.queue_number) AS current_serving
        FROM   appointments a
        WHERE  a.queue_id = (SELECT queue_id FROM appointments WHERE appointment_id = @appointment_id)
          AND  a.status   IN ('in_progress', 'completed', 'cancelled', 'cancled', 'skipped')
          AND  NOT EXISTS (
                 SELECT 1 FROM appointments b
                 WHERE  b.queue_id = a.queue_id
                   AND  b.booking_type = 1
                   AND  b.queue_number < a.queue_number
                   AND  b.status NOT IN ('completed', 'cancelled', 'cancled', 'skipped')
               )
      `);
    return res.recordset[0]?.current_serving ?? null;
  } catch (_) {
    return null;
  }
}

if (!admin.apps.length) {
  const serviceAccount = require("../ServiceAccountKey.json");
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

// ── Notifications inbox helpers ─────────────────────────────────────────────
// Every FCM push is mirrored as a row in `notifications` via sp_notification
// so the patient's in-app Notifications screen has a persistent history.
// FCM alone is fire-and-forget — closed-app messages otherwise vanish.
async function insertNotification(patient_id, title, body, type, ref_id = null) {
  if (!patient_id || !title || !body || !type) return { success: 0 };
  try {
    const r = await db.request()
      .input('operation', 'INSERT')
      .input('patient_id', patient_id)
      .input('title', title)
      .input('body', body)
      .input('type', type)
      .input('ref_id', ref_id != null ? String(ref_id) : null)
      .execute('sp_notification');
    return r.recordset?.[0] ?? { success: 1 };
  } catch (err) {
    log.error('insertNotification failed: ' + err.message);
    return { success: 0, message: err.message };
  }
}

// Family-member appointments share the family head's FCM token, so the head's
// `patients.patient_id` is the right inbox owner in both cases.
async function insertNotificationForToken(token, title, body, type, ref_id = null) {
  if (!token) return;
  try {
    const r = await db.request()
      .input('token', token)
      .query('SELECT TOP 1 patient_id FROM patients WHERE token = @token');
    const patient_id = r.recordset?.[0]?.patient_id;
    if (!patient_id) return;
    await insertNotification(patient_id, title, body, type, ref_id);
  } catch (err) {
    log.error('insertNotificationForToken failed: ' + err.message);
  }
}

// Idempotency check for proximity notifications. As the queue moves, the same
// patient would cross the same threshold across multiple endSession events —
// we send the "30 min" / "10 min" notification ONCE per stage per appointment.
// ref_id is namespaced as "<appointment_id>:<stage>" to allow one row per stage
// without conflicting with single-stage notifications used elsewhere.
async function hasNotificationBeenSent(patient_id, type, ref_id) {
  if (!patient_id || !type || !ref_id) return false;
  try {
    const r = await db.request()
      .input('patient_id', patient_id)
      .input('type', type)
      .input('ref_id', String(ref_id))
      .query(`SELECT TOP 1 1 AS hit FROM notifications
              WHERE patient_id = @patient_id
                AND type = @type
                AND ref_id = @ref_id`);
    return (r.recordset?.[0]?.hit === 1);
  } catch (err) {
    log.error('hasNotificationBeenSent failed: ' + err.message);
    return false;
  }
}

// Position-based notifications — Practo style. Every time the queue moves,
// the top-3 waiting patients get a position milestone push (once per milestone
// per appointment, idempotency via hasNotificationBeenSent):
//   Position 1 → "You're Next!"
//   Position 2 → "Get Ready! — 2nd in line"
//   Position 3 → "3rd in Queue"
// appointment_id → queue_id subquery used to scope to exact clinic's queue;
// avoids assuming dq.clinic_id column exists.
async function sendPositionNotifications(doctor_id, appointment_id) {
  if (!doctor_id || !appointment_id) return;
  try {
    const r = await db.request()
      .input('ref_apt_id', sql.Int, parseInt(appointment_id))
      .query(`
        SELECT TOP 3
          a.appointment_id,
          ROW_NUMBER() OVER (ORDER BY a.queue_number) AS position,
          CASE WHEN a.user_type = 1 THEN p.token  ELSE ph.token       END AS token,
          CASE WHEN a.user_type = 1 THEN p.patient_id ELSE ph.patient_id END AS patient_id,
          d.name AS doctor_name
        FROM appointments a
        JOIN doctor_queue   dq ON dq.queue_id   = a.queue_id
        JOIN doctors        d  ON d.doctor_id   = dq.doctor_id
        LEFT JOIN patients  p  ON a.user_type = 1 AND p.patient_id  = a.patient_id
        LEFT JOIN family_members fm ON a.user_type = 2 AND fm.member_id = a.patient_id
        LEFT JOIN patients  ph ON a.user_type = 2 AND ph.patient_id = fm.family_id
        WHERE a.queue_id = (SELECT TOP 1 queue_id FROM appointments WHERE appointment_id = @ref_apt_id)
          AND a.status = 'waiting'
        ORDER BY a.queue_number ASC
      `);

    const rows = r.recordset || [];
    if (rows.length === 0) return;

    for (const row of rows) {
      const pos = Number(row.position);
      const doctor = row.doctor_name || 'your doctor';
      const patient_id = row.patient_id;
      const aptId = row.appointment_id;
      const token = row.token;
      if (!patient_id || !aptId) continue;

      let stage, title, body;
      if (pos === 1) {
        stage = 'queue_next'; title = "You're Next!";
        body = `Dr. ${doctor} is ready for you. Please come in.`;
      } else if (pos === 2) {
        stage = 'queue_ready'; title = 'Get Ready!';
        body = `You're 2nd in line for Dr. ${doctor}. Please be at the clinic.`;
      } else if (pos === 3) {
        stage = 'queue_soon'; title = '3rd in Queue';
        body = `You're 3rd in line for Dr. ${doctor}. Get ready.`;
      } else { continue; }

      const refId = `${aptId}:${stage}`;
      if (await hasNotificationBeenSent(patient_id, 'queue', refId)) continue;

      await insertNotification(patient_id, title, body, 'queue', refId);

      if (token && String(token).trim()) {
        await admin.messaging().send({
          token,
          notification: { title, body },
          data: { type: 'queue', stage, doctor_id: String(doctor_id), appointment_id: String(aptId) },
        }).catch(err => log.error(`FCM err (pos${pos}): ` + (err.code || err.message)));
      }
    }
  } catch (err) {
    log.error('sendPositionNotifications failed: ' + err.message);
  }
}

// Proximity notifications — fired on every queue movement (queueStart,
// endSession, queueSkip, cancelByDoctor). For each waiting patient, the SP
// returns estimated minutes-to-turn based on (position-1) * avg consultation
// time. We send:
//   Stage 2 ("queue_far",  25–35 min away) — "Head to the clinic now"
//   Stage 3 ("queue_near",  5–15 min away) — "Almost your turn"
// Stage 4 ("Be Ready", 3rd in queue) and Stage 5 ("Your Turn Now") are already
// covered by endSession's existing rows[1] token and queueNext respectively.
//
// REQUIRED SP OPERATION — sp_appointment @operation = 'QUEUE_PROXIMITY_LIST':
//   IN : @doctor_id
//   OUT (one row per still-waiting appt today for this doctor, EXCLUDING
//        positions 1–3 since those are covered by existing notifications):
//     appointment_id        INT
//     owner_id              INT     -- family head's patients.patient_id
//     owner_token           NVARCHAR(MAX)
//     doctor_name           NVARCHAR
//     est_minutes_to_turn   INT     -- (position - 1) * avg_consultation_minutes
//
// Fire-and-forget — failures here must not break the calling endpoint.
async function sendProximityNotifications(doctor_id, clinic_id = null) {
  if (!doctor_id) return;
  try {
    const r = await db.request()
      .input('operation', 'QUEUE_PROXIMITY_LIST')
      .input('doctor_id', doctor_id)
      .input('clinic_id', clinic_id || null)
      .execute('sp_appointment');

    const rows = r.recordset || [];
    if (rows.length === 0) return;

    await Promise.all(rows.map(async (row) => {
      const minutes = row.est_minutes_to_turn;
      const patient_id = row.owner_id;
      const token = row.owner_token;
      const aptId = row.appointment_id;
      const doctor = row.doctor_name || 'your doctor';
      if (!patient_id || !aptId || minutes == null) return;

      let stage = null, title = null, body = null;
      if (minutes >= 25 && minutes <= 35) {
        stage = 'queue_far';
        title = 'Your turn is approaching';
        body = `Your turn with Dr. ${doctor} is in about ${minutes} minutes. Please head to the clinic now.`;
      } else if (minutes >= 5 && minutes <= 15) {
        stage = 'queue_near';
        title = 'Almost your turn';
        body = `Your turn with Dr. ${doctor} is in about ${minutes} minutes. Please be at the clinic.`;
      } else {
        return;
      }

      const refId = `${aptId}:${stage}`;
      if (await hasNotificationBeenSent(patient_id, 'queue', refId)) return;

      await insertNotification(patient_id, title, body, 'queue', refId);

      if (token && token.trim() !== '') {
        await admin.messaging().send({
          token,
          notification: { title, body },
          data: {
            type: 'queue',
            stage,
            doctor_id: String(doctor_id),
            appointment_id: String(aptId),
          },
        }).catch(err =>
          log.error('FCM err (proximity): ' + (err.code || err.message)),
        );
      }
    }));
  } catch (err) {
    log.error('sendProximityNotifications failed: ' + err.message);
  }
}

// Format helpers for human-readable notification bodies. mssql returns TIME
// as a Date pinned to 1970-01-01, so we extract just the time portion.
function formatApptDate(d) {
  if (!d) return '';
  const dt = new Date(d);
  if (isNaN(dt.getTime())) return '';
  return dt.toLocaleDateString('en-IN', {
    day: 'numeric', month: 'short', year: 'numeric',
  });
}

function formatApptTime(t) {
  if (!t) return '';
  let h, m;
  if (t instanceof Date) {
    // node-mssql returns a TIME column as a Date pinned to 1970-01-01 whose
    // LOCAL wall-clock equals the stored value (tedious builds it from the
    // server TZ), so read it back with getHours/getMinutes — NOT getUTC* and
    // NOT String()+split('T') (a Date's toString has no 'T', yielding NaN).
    if (isNaN(t.getTime())) return '';
    h = t.getHours();
    m = t.getMinutes();
  } else {
    let s = String(t);
    if (s.includes('T')) s = s.split('T')[1].split('.')[0];
    const parts = s.split(':');
    h = parseInt(parts[0], 10);
    m = parseInt(parts[1], 10);
  }
  if (isNaN(h)) return '';
  const mm = String(isNaN(m) ? 0 : m).padStart(2, '0');
  const ampm = h >= 12 ? 'PM' : 'AM';
  h = h % 12 || 12;
  return `${h}:${mm} ${ampm}`;
}

// Public endpoint — same logic, exposed for any caller wanting to drop a row
// into the inbox directly (manual testing / future services).
router.post('/insertNotification', async (req, res) => {
  const { patient_id, title, body, type, ref_id } = req.body;
  if (!patient_id || !title || !body || !type) {
    return res.status(400).json({
      success: false,
      message: 'patient_id, title, body and type are required',
    });
  }
  const row = await insertNotification(patient_id, title, body, type, ref_id ?? null);
  return res.status(row.success === 1 ? 200 : 500).json({
    success: row.success === 1,
    notification_id: row.notification_id,
    message: row.message || 'Notification stored',
  });
});

router.post('/insertMedicine', async (req, res) => {
  const {
    doctor_id,
    medicine_name,
    medicine_type_id,
    brand_name,
    strength,
    components
  } = req.body;

  // Optional fields: trim, empty -> null
  const opt = (v) => (typeof v === 'string' && v.trim() ? v.trim() : null);

  try {
    const request = db.request();

    request.input('operation', 'Insert');
    request.input('doctor_id', doctor_id);
    request.input('medicine_name', medicine_name);
    request.input('medicine_type_id', medicine_type_id);
    request.input('brand_name', opt(brand_name));
    request.input('strength', opt(strength));
    request.input('components', opt(components));

    const result = await request.execute('sp_Medicine_Master');

    const message = result.recordset?.[0]?.Message || 'Medicine inserted successfully';
    const isDuplicate = message.toLowerCase().includes('already exists');

    res.status(isDuplicate ? 409 : 200).json({
      success: isDuplicate ? 0 : 1,
      message,
      data: result.recordset,
    });

  } catch (error) {
    res.status(500).json({
      success: 0,
      message: `Failed to insert medicine. ${error}`,
    });
  }
});


router.post('/addQueueStartTime/', async (req, res) => {
  const {
    doctor_id,
    q_start_before
  } = req.body;

  try {
    const request = db.request();

    request.input('operation', 'Insert_Q_StartTime'); // SP operation
    request.input('doctor_id', doctor_id);
    request.input('q_start_before', q_start_before);

    // Execute stored procedure
    const result = await request.execute('sp_doctor_login');

    res.status(200).json({
      success: 1,
      message: 'Time inserted successfully',
      data: result.recordset,
    });

  } catch (error) {
    res.status(500).json({
      success: 0,
      message: `Failed to insert Time ${error}`,
    });
  }
});


router.post('/saveDoctorSchedule', async (req, res) => {
  const { doctor_id, clinic_id, schedule, force } = req.body;
  const action = req.body.action === 'reschedule' ? 'reschedule' : 'cancel';
  const addClinic = (r) => { if (clinic_id) r.input('clinic_id', clinic_id); return r; };

  if (!doctor_id || !Array.isArray(schedule)) {
    return res.status(400).json({
      success: false,
      message: 'doctor_id and schedule (array) required'
    });
  }
  log.debug('saveDoctorSchedule payload: ' + JSON.stringify({
    doctor_id,
    force: !!force,
    days: schedule.map(d => ({
      day: d.day,
      is_enabled: d.is_enabled,
      slot_ids: (d.slots || []).map(s => s.slot_id),
    })),
  }));

  try {

    const toMin = (t) => {
      const [h, m] = String(t || '').split(':');
      return (parseInt(h, 10) || 0) * 60 + (parseInt(m, 10) || 0);
    };
    for (const day of schedule) {
      if (day.is_enabled !== 1) continue;
      const slots = (day.slots || [])
        .map(s => ({ s: toMin(s.start_time), e: toMin(s.end_time) }))
        .sort((a, b) => a.s - b.s);
      for (let i = 0; i < slots.length; i++) {
        if (slots[i].e <= slots[i].s) {
          return res.status(400).json({
            success: false,
            message: `${day.day}: a slot's end time must be after its start time.`,
          });
        }
        if (i > 0 && slots[i].s < slots[i - 1].e) {
          return res.status(400).json({
            success: false,
            message: `${day.day}: time slots overlap. Please fix the timings.`,
          });
        }
      }
    }

    const conflicts = [];     // FUTURE appts (cancel/reschedule gate)
    const todayBlocked = [];  // TODAY's live bookings on a slot being removed/retimed
    // Current schedule (slot_id -> timing) to detect timing changes.
    const cur = await addClinic(db.request()
      .input('operation', 'GET')
      .input('doctor_id', doctor_id))
      .execute('sp_doctor_schedule');
    const curTiming = {};
    for (const r of (cur.recordset || [])) {
      if (r.slot_id != null) {
        curTiming[r.slot_id] = {
          start: String(r.start_time || '').slice(0, 5),
          end: String(r.end_time || '').slice(0, 5),
        };
      }
    }
    const norm = (t) => String(t || '').slice(0, 5);
    const todayCount = async (slot_id) => {
      const r = await db.request()
        .input('slot_id', slot_id)
        .execute('sp_slot_today_count');
      return r.recordset?.[0]?.cnt ?? 0;
    };

    for (const day of schedule) {
      const existing = await addClinic(db.request()
        .input('operation', 'GET_DAY_SLOT_IDS')
        .input('doctor_id', doctor_id)
        .input('day_of_week', day.day))
        .execute('sp_doctor_schedule');

      const existingIds = (existing.recordset || []).map(r => r.slot_id);
      const incomingIds = (day.slots || [])
        .map(s => s.slot_id)
        .filter(id => id != null);

      const toDelete = existingIds.filter(id => !incomingIds.includes(id));

      // also: if day is being disabled entirely, every existing slot is gone
      const disablingDay = day.is_enabled !== 1;
      const removedSlotIds = disablingDay ? existingIds : toDelete;

      // (a) Removed slots: future -> cancel/reschedule gate;
      //     TODAY's live bookings -> hard block (would be orphaned).
      for (const slot_id of removedSlotIds) {
        if ((await todayCount(slot_id)) > 0) todayBlocked.push(day.day);

        const r = await db.request()
          .input('operation', 'COUNT_FUTURE_APPTS_FOR_SLOT')
          .input('slot_id', slot_id)
          .execute('sp_doctor_schedule');

        const count = r.recordset?.[0]?.cnt ?? 0;
        if (count > 0) {
          conflicts.push({ day: day.day, slot_id, future_appointments: count });
        }
      }

      // (b) Kept-but-retimed slots with TODAY's live bookings -> hard block
      //     (today's patient would silently shift to a new time).
      if (!disablingDay) {
        for (const s of (day.slots || [])) {
          if (s.slot_id == null) continue;
          const prev = curTiming[s.slot_id];
          if (!prev) continue;
          const changed = norm(s.start_time) !== prev.start ||
            norm(s.end_time) !== prev.end;
          if (changed && (await todayCount(s.slot_id)) > 0) {
            todayBlocked.push(day.day);
          }
        }
      }
    }
    if (todayBlocked.length > 0) {
      const days = [...new Set(todayBlocked)];
      return res.status(409).json({
        success: false,
        today_blocked: true,
        days,
        message:
          `You have bookings today (${days.join(', ')}). Today's schedule ` +
          `can't be changed here. Use "Leave" to block the whole day, or ` +
          `reschedule those patients individually from the queue.`,
      });
    }

    if (conflicts.length > 0 && !force) {
      return res.status(409).json({
        success: false,
        message: 'Some slots have future appointments. Confirm before deleting.',
        conflicts
      });
    }

    // ── PASS 2: actually apply the changes
    // Per-patient context for personalized notifications — patient needs to
    // know WHICH appointment was cancelled so they can rebook the right one.
    const affectedAppts = []; // [{patient_id, token, doctor_name, date, time, appointment_id}]

    for (const day of schedule) {
      // UPSERT DAY
      const dayResult = await addClinic(db.request()
        .input('operation', 'UPSERT_DAY')
        .input('doctor_id', doctor_id)
        .input('day_of_week', day.day)
        .input('is_enabled', day.is_enabled))
        .execute('sp_doctor_schedule');

      const availability_id = dayResult.recordset?.[0]?.availability_id;
      if (!availability_id) {
        throw new Error(`UPSERT_DAY did not return availability_id for ${day.day}`);
      }

      // Re-read existing slot ids for diff
      const existing = await addClinic(db.request()
        .input('operation', 'GET_DAY_SLOT_IDS')
        .input('doctor_id', doctor_id)
        .input('day_of_week', day.day))
        .execute('sp_doctor_schedule');
      const existingIds = (existing.recordset || []).map(r => r.slot_id);

      const incomingIds = (day.slots || [])
        .map(s => s.slot_id)
        .filter(id => id != null);

      // DELETE removed slots (safe: pass2 only runs after conflict pass)
      // If day is disabled, drop everything for it.
      const disablingDay = day.is_enabled !== 1;
      const removedSlotIds = disablingDay
        ? existingIds
        : existingIds.filter(id => !incomingIds.includes(id));

      // 'reschedule' keeps the appointment alive (status='reschedule') so the
      // patient still sees it and can rebook; 'cancel' marks it 'cancelled'.
      const releaseOp = action === 'reschedule'
        ? 'RESCHEDULE_FUTURE_APPTS_FOR_SLOT'
        : 'CANCEL_FUTURE_APPTS_FOR_SLOT';

      for (const slot_id of removedSlotIds) {
        // Pre-fetch context before the SP changes statuses, so we can build
        // personalized "Dr. X on 15 Jun at 10:30 AM" notifications.
        const details = await db.request()
          .input('operation', 'APPT_CONTEXT_SLOT')
          .input('slot_id', slot_id)
          .execute('sp_notification');

        for (const row of (details.recordset || [])) {
          if (!row.owner_id) continue;
          affectedAppts.push({
            patient_id: row.owner_id,
            token: row.owner_token,
            doctor_name: row.doctor_name || 'your doctor',
            date: formatApptDate(row.appointment_date),
            time: formatApptTime(row.start_time),
            appointment_id: row.appointment_id,
          });
        }

        // Release future appointments on this slot
        await db.request()
          .input('operation', releaseOp)
          .input('slot_id', slot_id)
          .execute('sp_doctor_schedule');

        // For 'cancel' mode, normalize status to 'CancleD' so the patient app
        // shows "Cancelled by Doctor" (the release SP otherwise sets generic
        // 'cancelled' which looks identical to a patient self-cancel).
        // Reschedule mode leaves status='reschedule' — that's its own state.
        if (action === 'cancel') {
          const slotApptIds = (details.recordset || []).map(r => r.appointment_id);
          await Promise.all(slotApptIds.map(aid =>
            db.request()
              .input('operation', 'MARK_APPT_DOCTOR_CANCELLED')
              .input('appointment_id', aid)
              .execute('sp_appointment')
              .catch(err =>
                log.error('status normalize err: ' + aid + ' ' + err.message),
              ),
          ));
        }

        // Now safe to delete the slot row
        await db.request()
          .input('operation', 'DELETE_SLOT')
          .input('slot_id', slot_id)
          .execute('sp_doctor_schedule');
      }

      // UPSERT each slot, only if day enabled
      if (day.is_enabled === 1 && Array.isArray(day.slots)) {
        for (const slot of day.slots) {
          await db.request()
            .input('operation', 'UPSERT_SLOT')
            .input('availability_id', availability_id)
            .input('slot_id', slot.slot_id ?? null)
            .input('start_time', slot.start_time)
            .input('end_time', slot.end_time)
            .input('booking_mode', slot.booking_mode)
            .input('slot_duration', slot.slot_duration ?? null)
            .input('max_queue_length', slot.max_queue_length ?? null)
            .execute('sp_doctor_schedule');
        }
      }
    }

    if (affectedAppts.length > 0) {
      const isReschedule = action === 'reschedule';
      const title = isReschedule ? 'Please Reschedule' : 'Appointment Cancelled';

      const tasks = affectedAppts.map((a) => {
        const when = a.date && a.time ? `${a.date} at ${a.time}`
          : a.date ? a.date
            : a.time ? `at ${a.time}`
              : '';
        const body = isReschedule
          ? `Dr. ${a.doctor_name}'s schedule changed. Your appointment${when ? ' on ' + when : ''} needs to be rebooked. Tap to book again.`
          : `Your appointment with Dr. ${a.doctor_name}${when ? ' on ' + when : ''} has been cancelled. Tap to book again.`;
        return { ...a, title, body };
      });

      // Inbox rows first so a device that refetches on push arrival sees them.
      await Promise.all(tasks.map(t =>
        insertNotification(t.patient_id, t.title, t.body, 'appointment', t.appointment_id),
      ));

      // Per-patient FCM (parallel). Generic multicast can't carry per-patient
      // bodies, so we fan out one send per token.
      await Promise.all(tasks
        .filter(t => t.token && t.token.trim() !== '')
        .map(t =>
          admin.messaging().send({
            token: t.token,
            notification: { title: t.title, body: t.body },
            data: {
              type: 'appointment',
              action: isReschedule ? 'rebook' : 'cancelled',
              doctor_id: String(doctor_id),
              appointment_id: String(t.appointment_id),
            },
          }).catch(err => log.error('FCM err (saveDoctorSchedule): ' + err.message)),
        ),
      );
    }

    return res.status(200).json({
      success: true,
      message: 'Schedule saved successfully',
      cancelled_notifications: affectedAppts.length,
      error: null
    });

  } catch (error) {
    log.error('saveDoctorSchedule error: ' + error.message);
    return res.status(500).json({
      success: false,
      message: 'Error saving schedule',
      error: error.message
    });
  }
});

// ──────────────────────────────────────────────────────────────────────────
//  DOCTOR LEAVE / SUTTI  (date-range unavailability — industry "Mark
//  Unavailable" pattern). Cancels every future booked/in_progress
//  appointment in the range and FCM-notifies the affected patients.
// ──────────────────────────────────────────────────────────────────────────
router.post('/addDoctorLeave', async (req, res) => {
  const { doctor_id, from_date, to_date, reason, force, clinic_id } = req.body;

  if (!doctor_id || !from_date || !to_date) {
    return res.status(400).json({
      success: false,
      message: 'doctor_id, from_date and to_date are required',
    });
  }
  if (from_date > to_date) {
    return res.status(400).json({
      success: false,
      message: 'from_date cannot be after to_date',
    });
  }

  try {
    // PASS 1 — how many future appts will be cancelled? Gate behind `force`
    // (same UX as saveDoctorSchedule conflict gate).
    const countRes = await db.request()
      .input('operation', 'COUNT_AFFECTED')
      .input('doctor_id', doctor_id)
      .input('from_date', from_date)
      .input('to_date', to_date)
      .input('clinic_id', clinic_id || null)
      .execute('sp_doctor_leave');

    const affected = countRes.recordset?.[0]?.cnt ?? 0;

    if (affected > 0 && !force) {
      return res.status(409).json({
        success: false,
        message: 'Appointments exist in this date range. Confirm before applying leave.',
        affected_appointments: affected,
      });
    }

    // PASS 2 — record the leave
    const addRes = await db.request()
      .input('operation', 'ADD_LEAVE')
      .input('doctor_id', doctor_id)
      .input('from_date', from_date)
      .input('to_date', to_date)
      .input('reason', reason ?? null)
      .input('clinic_id', clinic_id || null)
      .execute('sp_doctor_leave');

    const row = addRes.recordset?.[0] ?? {};
    if (row.error) {
      return res.status(400).json({
        success: false,
        message: row.error === 'PAST_DATE'
          ? 'Leave start date is in the past'
          : 'Invalid leave date range',
      });
    }
    const leave_id = row.leave_id;

    // Pre-fetch personalized context BEFORE the SP changes statuses, so each
    // patient sees their own doctor + date in the notification.
    const detailsRes = await db.request()
      .input('operation', 'APPT_CONTEXT_DOCTOR_RANGE')
      .input('doctor_id', doctor_id)
      .input('from_date', from_date)
      .input('to_date', to_date)
      .execute('sp_notification');

    const affectedAppts = [];
    for (const row of (detailsRes.recordset || [])) {
      if (!row.owner_id) continue;
      affectedAppts.push({
        patient_id: row.owner_id,
        token: row.owner_token,
        doctor_name: row.doctor_name || 'your doctor',
        date: formatApptDate(row.appointment_date),
        time: formatApptTime(row.start_time),
        appointment_id: row.appointment_id,
      });
    }

    // PASS 3 — cancel future appts in range
    await db.request()
      .input('operation', 'APPLY_LEAVE_CANCEL')
      .input('doctor_id', doctor_id)
      .input('from_date', from_date)
      .input('to_date', to_date)
      .execute('sp_doctor_leave');

    // PASS 3.5 — normalize status to 'CancleD' so the patient app shows
    // "Cancelled by Doctor" (the leave SP otherwise sets generic 'cancelled'
    // which looks the same as a patient self-cancel).
    if (affectedAppts.length > 0) {
      await Promise.all(affectedAppts.map(a =>
        db.request()
          .input('operation', 'MARK_APPT_DOCTOR_CANCELLED')
          .input('appointment_id', a.appointment_id)
          .execute('sp_appointment')
          .catch(err =>
            log.error('status normalize err: ' + a.appointment_id + ' ' + err.message),
          ),
      ));
    }

    if (affectedAppts.length > 0) {
      const title = 'Appointment Cancelled';
      const tasks = affectedAppts.map((a) => {
        const when = a.date && a.time ? `${a.date} at ${a.time}`
          : a.date ? a.date
            : a.time ? `at ${a.time}`
              : '';
        const body =
          `Dr. ${a.doctor_name} is unavailable${when ? ' on ' + when : ''}. ` +
          `Your appointment has been cancelled. Tap to book again.`;
        return { ...a, title, body };
      });

      await Promise.all(tasks.map(t =>
        insertNotification(t.patient_id, t.title, t.body, 'appointment', t.appointment_id),
      ));

      await Promise.all(tasks
        .filter(t => t.token && t.token.trim() !== '')
        .map(t =>
          admin.messaging().send({
            token: t.token,
            notification: { title: t.title, body: t.body },
            data: {
              type: 'appointment',
              action: 'cancelled',
              doctor_id: String(doctor_id),
              appointment_id: String(t.appointment_id),
            },
          }).catch(err => log.error('FCM err (addDoctorLeave): ' + err.message)),
        ),
      );
    }

    return res.status(200).json({
      success: true,
      message: 'Leave applied successfully',
      leave_id,
      cancelled_appointments: affectedAppts.length,
    });

  } catch (error) {
    log.error('addDoctorLeave error: ' + error.message);
    return res.status(500).json({
      success: false,
      message: 'Error applying leave',
      error: error.message,
    });
  }
});

router.get('/doctorLeaves/:doctor_id/:clinic_id?', async (req, res) => {
  const { doctor_id, clinic_id } = req.params;
  try {
    const result = await db.request()
      .input('operation', 'LIST_LEAVE')
      .input('doctor_id', doctor_id)
      .input('clinic_id', clinic_id || null)
      .execute('sp_doctor_leave');

    res.status(200).json(result.recordset || []);
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error fetching leaves',
      error: error.message,
    });
  }
});

router.post('/cancelDoctorLeave', async (req, res) => {
  const { doctor_id, leave_id, clinic_id } = req.body;

  if (!doctor_id || !leave_id) {
    return res.status(400).json({
      success: false,
      message: 'doctor_id and leave_id are required',
    });
  }

  try {
    await db.request()
      .input('operation', 'CANCEL_LEAVE')
      .input('doctor_id', doctor_id)
      .input('leave_id', leave_id)
      .input('clinic_id', clinic_id || null)
      .execute('sp_doctor_leave');

    return res.status(200).json({
      success: true,
      message: 'Leave cancelled. Note: appointments already cancelled are not auto-restored.',
    });
  } catch (error) {
    log.error('cancelDoctorLeave error: ' + error.message);
    return res.status(500).json({
      success: false,
      message: 'Error cancelling leave',
      error: error.message,
    });
  }
});


router.post('/insertPrescription', async (req, res) => {
  const {
    patient_id,
    doctor_id,
    prescription_date,
    symptoms,
    diagnosis,
    user_type,
    appointment_id,
    clinical_notes,
    follow_up_date,
    advice,
    medicines = [],
    clinic_id,
  } = req.body;

  if (!patient_id) {
    return res.status(400).json({ success: false, message: 'patient_id is required' });
  }

  if (!doctor_id) {
    return res.status(400).json({ success: false, message: 'doctor_id is required' });
  }

  if (!Array.isArray(medicines)) {
    return res.status(400).json({ success: false, message: 'medicines must be an array' });
  }

  const clean = (v) => (v === '' || v === undefined ? null : v);

  try {
    // One prescription per appointment. A retry (offline replay, or a resend
    // after a timeout whose first attempt actually landed) must not create a
    // duplicate or re-notify the patient — return the existing one.
    if (parseInt(appointment_id) > 0) {
      const existing = await db.request()
        .input('appointment_id', sql.Int, parseInt(appointment_id))
        .query('SELECT TOP 1 prescription_id FROM patient_records WHERE appointment_id = @appointment_id');
      const existingId = existing.recordset?.[0]?.prescription_id;
      if (existingId) {
        log.info(`[insertPrescription] appointment ${appointment_id} already has prescription ${existingId} — skipped duplicate`);
        return res.json({ success: true, prescription_id: existingId, message: 'Prescription already saved' });
      }
    }

    let prescription_id = null;
    let patientToken = null;
    let doctorName = null;

    const rows = medicines.length > 0 ? medicines : [null];

    for (let i = 0; i < rows.length; i++) {
      const med = rows[i];

      const request = db.request();

      request.input('operation', 'Insert');
      request.input('prescription_id', prescription_id ?? 0);
      request.input('patient_id', patient_id);
      request.input('doctor_id', doctor_id);
      request.input('prescription_date', clean(prescription_date) ?? new Date());
      request.input('symptoms', clean(symptoms));
      request.input('diagnosis', clean(diagnosis));
      request.input('clinical_notes', clean(clinical_notes));
      request.input('follow_up_date', clean(follow_up_date));
      request.input('advice', clean(advice));
      request.input('created_at', new Date());
      request.input('user_type', user_type);
      request.input('appointment_id', appointment_id);
      request.input('clinic_id', clinic_id || null);

      request.input('medicine_id', med?.medicine_id ?? null);
      request.input('medicine_type_id', med?.medicine_type_id ?? null);
      request.input('frequency', clean(med?.frequency));
      request.input('duration', clean(med?.duration));
      request.input('timing', clean(med?.timing));
      request.input('tablet_dosage', clean(med?.tablet_dosage));
      request.input('syrup_dosage_ml', clean(med?.syrup_dosage_ml));
      request.input('inj_dosage', clean(med?.inj_dosage));
      request.input('inj_route', clean(med?.inj_route));
      request.input('drops_count', clean(med?.drops_count));
      request.input('drops_application', clean(med?.drops_application));
      request.input('lotion_apply_area', clean(med?.lotion_apply_area));
      request.input('spray_puffs', clean(med?.spray_puffs));
      request.input('spray_usage', clean(med?.spray_usage));
      request.input('lotion_usage', clean(med?.lotion_usage));

      // ── Powders ───────────────────────────────────────────────
      request.input('powder_dosage', clean(med?.powder_dosage));
      request.input('powder_form', clean(med?.powder_form));

      // ── Inhalers ──────────────────────────────────────────────
      request.input('inhaler_puffs', clean(med?.inhaler_puffs));
      request.input('inhaler_type', clean(med?.inhaler_type));
      request.input('inhaler_technique', clean(med?.inhaler_technique));
      request.input('inhaler_usage', clean(med?.inhaler_usage));

      const result = await request.execute('sp_prescription');

      const row = result.recordset?.[0];

      if (!row || row.success === 0) {
        return res.status(500).json({
          success: false,
          message: row?.message || 'Prescription failed'
        });
      }

      // ✅ FIRST CALL → GET ID + TOKEN
      if (i === 0) {
        prescription_id = row.prescription_id;
        // SP may return the FCM token under either alias; accept both.
        patientToken = row.token || row.fcm_token;
        // Doctor name is optional — used to personalise the "Appointment
        // Complete — review it" body. Falls back below if the SP doesn't
        // return it.
        doctorName = row.doctor_name || row.doctorName || null;
        log.debug('[insertPrescription] SP row keys: ' + Object.keys(row).join(', '));
        log.debug('[insertPrescription] patientToken: ' + (patientToken ? '[REDACTED]' : 'null'));

        if (!prescription_id) {
          return res.status(500).json({
            success: false,
            message: 'Failed to create prescription'
          });
        }
      }
    }

    // sp_prescription doesn't always echo the patient's FCM token. Fallback is a
    // direct read from patients.token (same column populated by sp_doctor_login's
    // 'saveFirebaseToken' op for role='patient', and used in the reverse lookup
    // at the top of this file).
    if (!patientToken) {
      try {
        const tokenLookup = await db.request()
          .input('patient_id', patient_id)
          .query('SELECT TOP 1 token FROM patients WHERE patient_id = @patient_id');
        patientToken = tokenLookup.recordset?.[0]?.token || null;
        log.debug('[insertPrescription] token fetched via patients fallback: ' + (patientToken ? '[REDACTED]' : 'null'));
      } catch (lookupErr) {
        log.error('[insertPrescription] token lookup failed: ' + lookupErr.message);
      }
    }

    // 🔔 SEND TWO NOTIFICATIONS — completing a consultation triggers both:
    //   1) "Appointment Complete — review it"  → opens the review dialog
    //   2) "Prescription Assigned — tap to view" → opens the prescription
    // The review one fires only when we have an appointment_id to attach
    // to (the dialog needs it). Both share the cached patientToken so we
    // don't double-lookup.
    const drLabel = doctorName ? `Dr. ${doctorName}` : 'the doctor';

    if (appointment_id) {
      const reviewTitle = 'Appointment Complete';
      const reviewBody =
        `Your appointment with ${drLabel} is complete. Tap to leave a review.`;

      await insertNotification(
        patient_id, reviewTitle, reviewBody, 'rating', appointment_id,
      );

      if (patientToken) {
        try {
          await admin.messaging().send({
            token: patientToken,
            notification: { title: reviewTitle, body: reviewBody },
            // appointment_id lets the frontend look up the row and pop the
            // review dialog with doctor/patient context already populated.
            data: {
              type: 'rating',
              appointment_id: String(appointment_id),
            },
          });
        } catch (err) {
          log.error('[insertPrescription] review FCM FAILED: ' + (err.code || '') + ' ' + err.message);
        }
      }
    } else {
      log.warn('[insertPrescription] appointment_id missing — review notification skipped');
    }

    const presTitle = 'Prescription Assigned';
    const presBody = 'Doctor has assigned prescription to you. Please review it.';

    // Inbox row first — patient_id is already known here, no token lookup needed.
    await insertNotification(patient_id, presTitle, presBody, 'prescription', prescription_id);

    if (patientToken) {
      try {
        const fcmResp = await admin.messaging().send({
          token: patientToken,
          notification: { title: presTitle, body: presBody },
          data: {
            type: 'prescription',
            prescription_id: String(prescription_id),
          },
        });
        log.info('[insertPrescription] FCM send OK: ' + fcmResp);
      } catch (err) {
        log.error('[insertPrescription] FCM send FAILED: ' + (err.code || '') + ' ' + err.message);
      }
    } else {
      log.warn('[insertPrescription] no patientToken — push skipped (inbox row saved)');
    }

    return res.status(200).json({
      success: true,
      prescription_id,
      message: 'Prescription created successfully'
    });

  } catch (err) {
    log.error('Error in /insertPrescription: ' + err.message);
    return res.status(500).json({
      success: false,
      message: err.message
    });
  }
});

router.post('/appointment/queueNext', async (req, res) => {
  const { doctor_id, appointment_id, clinic_id } = req.body;

  if (!doctor_id) {
    return res.status(400).json({ success: false, message: 'doctor_id is required' });
  }
  if (!appointment_id) {
    return res.status(400).json({ success: false, message: 'appointment_id is required' });
  }

  try {
    const result = await db.request()
      .input('operation', 'NEXT_SESSION')
      .input('doctor_id', doctor_id)
      .input('appointment_id', appointment_id)
      .input('clinic_id', clinic_id || null)
      .execute('sp_appointment');

    const row = result.recordset?.[0] ?? {};

    if (row.success !== 1) {
      return res.json({
        success: false,
        message: row.message || 'Queue next failed'
      });
    }

    const token = row.token;
    const stale = isStaleReplay(req);

    log.debug('queueNext: next patient token present: ' + !!token);

    // 🔔 SEND NOTIFICATION TO NEXT PATIENT
    if (token && !stale) {
      const nextTitle = 'Your Turn Now';
      const nextBody = 'Doctor is ready to see you. Please proceed.';

      await insertNotificationForToken(token, nextTitle, nextBody, 'appointment', appointment_id);

      try {
        await admin.messaging().send({
          token: token,
          notification: { title: nextTitle, body: nextBody },
          data: { type: 'appointment', appointment_id: String(appointment_id) },
        });
      } catch (fcmErr) {
        log.error('FCM send failed for queueNext notification: ' + (fcmErr.code || fcmErr.message));
      }
    }

    if (!stale) {
      sendProximityNotifications(doctor_id, clinic_id);
      sendPositionNotifications(doctor_id, appointment_id);
    }
    const nextServing = await fetchCurrentServing(appointment_id);
    emitQueueUpdate(req, 'next', doctor_id, { current_serving: nextServing, clinic_id });

    return res.json({
      success: true,
      message: row.message ?? 'Queue next done'
    });

  } catch (error) {
    log.error('queueNext error: ' + error.message);
    return res.status(500).json({
      success: false,
      message: 'Queue next failed',
      error: error.message
    });
  }
});


// QUEUE START
router.post('/appointment/queueStart', async (req, res) => {
  const { doctor_id, queue_id } = req.body;

  if (!doctor_id) {
    return res.status(400).json({
      success: false,
      message: 'doctor_id required'
    });
  }

  try {
    const result = await db.request()
      .input('operation', 'QUEUE_START')
      .input('queue_id', queue_id)
      .input('doctor_id', doctor_id)
      .execute('sp_appointment');

    // QUEUE_START's SP returns the status row and the waiting-patient token
    // rows. Depending on the SP it may put them in ONE recordset (status first,
    // tokens after) or in TWO separate recordsets — exactly the gotcha
    // documented in queuePause below. node-mssql only exposes the first
    // recordset on `.recordset`, so the old `rows.slice(1)` silently found ZERO
    // tokens whenever the SP used the separate-recordset shape and no
    // "Doctor Arrived" push ever went out. Flatten every recordset and take all
    // token-bearing rows (the status row carries `success`, not a token).
    const allRows = (result.recordsets || [result.recordset || []]).flat();
    const statusRow = allRows.find(r => r && r.success != null) || {};

    /* if (statusRow.success !== 1) {
         return res.json({
           success: false,
           message: statusRow|| 'Queue start failed'
         });
       }*/


    const tokens = allRows
      .filter(r => r && r !== statusRow && r.token && String(r.token).trim() !== '')
      .map(r => r.token);

    if (tokens.length === 0 || isStaleReplay(req)) {
      emitQueueUpdate(req, 'queue_started', doctor_id, { queue_id });
      return res.json({
        success: true,
        message: 'Queue started, no patients to notify'
      });
    }

    let doctorName = 'your doctor';
    try {
      const ctx = await db.request()
        .input('operation', 'APPT_CONTEXT_QUEUE')
        .input('doctor_id', doctor_id)
        .input('queue_id', queue_id)
        .execute('sp_notification');
      doctorName = ctx.recordset?.[0]?.doctor_name || 'your doctor';
    } catch (e) { log.error('[queueStart] name lookup failed: ' + e.message); }
    const startTitle = 'Doctor Arrived';
    const startBody = `Dr. ${doctorName} has started the queue. Please be ready.`;

    for (const tk of tokens) {
      await insertNotificationForToken(tk, startTitle, startBody, 'queue', doctor_id);
    }


    // 🔥 SEND NOTIFICATION
    const message = {
      notification: { title: startTitle, body: startBody },
      data: { type: 'queue' },
      tokens: tokens,
    };

    const response = await admin.messaging().sendEachForMulticast(message);

    sendProximityNotifications(doctor_id);
    emitQueueUpdate(req, 'queue_started', doctor_id, { queue_id });

    return res.json({
      success: true,
      message: 'Queue started and notifications sent',
      total_tokens: tokens.length,
      success_count: response.successCount,
      failure_count: response.failureCount
    });

  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Queue start failed',
      error: error.message
    });
  }
});


// QUEUE PAUSE
router.post('/appointment/queuePause', async (req, res) => {
  const { doctor_id, queue_id } = req.body;
  if (!doctor_id) {
    return res.status(400).json({
      success: false,
      message: 'doctor_id required'
    });
  }

  try {
    const result = await db.request()
      .input('operation', 'QUEUE_PAUSE')
      .input('queue_id', queue_id)
      .input('doctor_id', doctor_id)
      .execute('sp_appointment');

    // SP returns 2 separate result sets: [0] = status, [1] = token rows.
    // node-mssql's `result.recordset` is only the FIRST recordset, so tokens
    // live in `result.recordsets[1]`.
    const recordsets = result.recordsets || [];
    const statusRow = recordsets[0]?.[0] || {};
    const tokenRows = recordsets[1] || [];

    // ✅ CHECK SUCCESS
    if (statusRow.success !== 1) {
      return res.json({
        success: false,
        message: statusRow.message || 'Queue pause failed'
      });
    }

    const tokens = tokenRows
      .map(r => r.token)
      .filter(t => t && t.trim() !== '');

    log.debug('queuePause: tokens count: ' + tokens.length);

    // 🔔 SEND NOTIFICATION
    if (tokens.length > 0 && !isStaleReplay(req)) {
      let doctorName = 'your doctor';
      try {
        const ctx = await db.request()
          .input('operation', 'APPT_CONTEXT_QUEUE')
          .input('doctor_id', doctor_id)
          .input('queue_id', queue_id)
          .execute('sp_notification');
        doctorName = ctx.recordset?.[0]?.doctor_name || 'your doctor';
      } catch (e) { log.error('[queuePause] name lookup failed: ' + e.message); }
      const pauseTitle = 'Queue Paused';
      const pauseBody = `Dr. ${doctorName} has paused the queue. Please wait.`;

      for (const tk of tokens) {
        await insertNotificationForToken(tk, pauseTitle, pauseBody, 'queue', doctor_id);
      }

      const message = {
        notification: { title: pauseTitle, body: pauseBody },
        data: { type: 'queue' },
        tokens: tokens,
      };

      const response = await admin.messaging().sendEachForMulticast(message);

      emitQueueUpdate(req, 'queue_paused', doctor_id, { queue_id });
      return res.json({
        success: true,
        message: 'Queue paused and notifications sent',
        total_tokens: tokens.length,
        success_count: response.successCount,
        failure_count: response.failureCount
      });
    }

    // ✅ NO TOKENS CASE
    emitQueueUpdate(req, 'queue_paused', doctor_id, { queue_id });
    return res.json({
      success: true,
      message: 'Queue paused, no patients to notify'
    });

  } catch (error) {
    log.error('queuePause error: ' + error.message);
    return res.status(500).json({
      success: false,
      message: 'Queue pause failed',
      error: error.message
    });
  }
});



// QUEUE STOP
router.post('/appointment/queueStop', async (req, res) => {
  const { doctor_id, queue_id } = req.body;

  if (!doctor_id) {
    return res.status(400).json({ success: false, message: 'doctor_id required' });
  }

  try {
    // Pre-fetch personalized context BEFORE the SP cancels everything.
    const detailsRes = await db.request()
      .input('operation', 'APPT_CONTEXT_QUEUE')
      .input('doctor_id', doctor_id)
      .input('queue_id', queue_id)
      .execute('sp_notification');

    const affectedAppts = [];
    for (const row of (detailsRes.recordset || [])) {
      if (!row.owner_id) continue;
      affectedAppts.push({
        patient_id: row.owner_id,
        token: row.owner_token,
        doctor_name: row.doctor_name || 'your doctor',
        date: formatApptDate(row.appointment_date),
        time: formatApptTime(row.start_time),
        appointment_id: row.appointment_id,
      });
    }

    // Skipped patients aren't part of the cancel context above, but they're
    // still left waiting when the queue closes — capture them (before the SP
    // mutates their status) so we can notify them too.
    const affectedIds = new Set(affectedAppts.map(a => a.patient_id));
    let skippedAppts = [];
    try {
      const skippedRes = await db.request()
        .input('queue_id', queue_id)
        .query(`
          SELECT a.patient_id, p.token AS owner_token, a.appointment_id
          FROM appointments a
          LEFT JOIN patients p ON a.user_type = 1 AND p.patient_id = a.patient_id
          WHERE a.queue_id = @queue_id AND LOWER(a.status) = 'skipped'
        `);
      skippedAppts = (skippedRes.recordset || [])
        .filter(r => r.patient_id && !affectedIds.has(r.patient_id));
    } catch (e) {
      log.error('[queueStop] skipped lookup failed: ' + e.message);
    }

    const result = await db.request()
      .input('operation', 'QUEUE_STOP')
      .input('queue_id', queue_id)
      .input('doctor_id', doctor_id)
      .execute('sp_appointment');

    const rows = result.recordset || [];
    const statusRow = rows[0] || {};

    if (statusRow.success !== 1) {
      return res.json({
        success: false,
        message: statusRow.message || 'Queue stop failed'
      });
    }

    if (affectedAppts.length > 0) {
      const title = 'Appointment Cancelled';
      const tasks = affectedAppts.map((a) => {
        const when = a.time ? `your ${a.time} appointment` : 'your appointment';
        const body =
          `Dr. ${a.doctor_name} has stopped today's queue. ${when} has been cancelled. ` +
          `Tap to book again.`;
        return { ...a, title, body };
      });

      await Promise.all(tasks.map(t =>
        insertNotification(t.patient_id, t.title, t.body, 'appointment', t.appointment_id),
      ));

      await Promise.all(tasks
        .filter(t => t.token && t.token.trim() !== '')
        .map(t =>
          admin.messaging().send({
            token: t.token,
            notification: { title: t.title, body: t.body },
            data: {
              type: 'appointment',
              action: 'cancelled',
              doctor_id: String(doctor_id),
              appointment_id: String(t.appointment_id),
            },
          }).catch(err => log.error('FCM err (queueStop): ' + err.message)),
        ),
      );
    }

    if (skippedAppts.length > 0) {
      const doctorName = affectedAppts[0]?.doctor_name || 'your doctor';
      const title = 'Queue Closed';
      const body =
        `Dr. ${doctorName} has closed today's queue. You were skipped earlier — ` +
        `please contact the clinic or book again.`;

      await Promise.all(skippedAppts.map(s =>
        insertNotification(s.patient_id, title, body, 'appointment', s.appointment_id),
      ));

      await Promise.all(skippedAppts
        .filter(s => s.owner_token && s.owner_token.trim() !== '')
        .map(s =>
          admin.messaging().send({
            token: s.owner_token,
            notification: { title, body },
            data: {
              type: 'appointment',
              action: 'cancelled',
              doctor_id: String(doctor_id),
              appointment_id: String(s.appointment_id),
            },
          }).catch(err => log.error('FCM err (queueStop skipped): ' + err.message)),
        ),
      );
      log.info('[queueStop] notified ' + skippedAppts.length + ' skipped patient(s)');
    }

    emitQueueUpdate(req, 'queue_stopped', doctor_id, { queue_id });
    return res.json({
      success: true,
      message: statusRow.message || 'Queue stopped',
      cancelled_notifications: affectedAppts.length,
      skipped_notifications: skippedAppts.length
    });

  } catch (error) {
    log.error('queueStop error: ' + error.message);
    return res.status(500).json({ success: false, message: 'Queue stop failed', error: error.message });
  }
});

// STOP/RESUME BOOKING — toggles new-booking acceptance for today's queue
// WITHOUT touching the queue itself. Existing waiting patients are left
// exactly as-is (no cancellation, no forced completion); use queueStop for
// that. Distinct from queue_status so a doctor can pause new patients from
// joining while still serving whoever is already in line.
router.post('/appointment/stopBooking', async (req, res) => {
  const { doctor_id, queue_id, booking_closed } = req.body;

  if (!doctor_id || !queue_id) {
    return res.status(400).json({ success: false, message: 'doctor_id and queue_id are required' });
  }

  try {
    const result = await db.request()
      .input('queue_id', queue_id)
      .input('doctor_id', doctor_id)
      .input('booking_closed', booking_closed ? 1 : 0)
      .query(`
        UPDATE doctor_queue
        SET booking_closed = @booking_closed
        WHERE queue_id = @queue_id AND doctor_id = @doctor_id
      `);

    if (result.rowsAffected?.[0] === 0) {
      return res.json({ success: false, message: 'Queue not found' });
    }

    emitQueueUpdate(req, 'booking_status_changed', doctor_id, { queue_id, booking_closed: !!booking_closed });

    return res.json({
      success: true,
      message: booking_closed ? 'New bookings stopped' : 'New bookings resumed',
      booking_closed: !!booking_closed,
    });

  } catch (error) {
    log.error('stopBooking error: ' + error.message);
    return res.status(500).json({ success: false, message: 'Stop booking failed', error: error.message });
  }
});

//QUEUE SKIP
router.post('/appointment/queueSkip', async (req, res) => {
  const { doctor_id, appointment_id, is_next } = req.body;

  if (!doctor_id) {
    return res.status(400).json({ success: false, message: 'doctor_id is required' });
  }

  if (!appointment_id) {
    return res.status(400).json({ success: false, message: 'appointment_id is required' });
  }

  try {
    const result = await db.request()
      .input('operation', 'SKIP_SESSION')
      .input('doctor_id', doctor_id)
      .input('appointment_id', appointment_id)
      .input('is_next', is_next)
      .execute('sp_appointment');

    const row = result.recordset?.[0] ?? {};

    // ✅ CHECK SUCCESS
    if (row.success !== 1) {
      return res.json({
        success: false,
        message: row.message || 'Queue skip failed'
      });
    }

    const token = row.token;
    const stale = isStaleReplay(req);

    log.debug('queueSkip: skipped patient token present: ' + !!token);

    // 🔔 SEND ONLY TO SKIPPED PATIENT
    if (token && !stale) {
      const skipTitle = 'You were skipped';
      const skipBody = 'Doctor skipped your turn due to absence. Please contact clinic.';

      try {
        await insertNotificationForToken(token, skipTitle, skipBody, 'appointment', appointment_id);
      } catch (notifErr) {
        log.error('insertNotificationForToken failed: ' + notifErr.message);
      }

      try {
        await admin.messaging().send({
          token: token,
          notification: { title: skipTitle, body: skipBody },
          // appointment_id lets the killed-app FCM tap auto-open the detail
          // sheet for the skipped appointment so the patient can act on it.
          data: { type: 'appointment', appointment_id: String(appointment_id) },
        });
      } catch (fcmErr) {
        // Stale/unregistered tokens must not fail the skip operation
        log.error('FCM send failed for skip notification: ' + (fcmErr.code || fcmErr.message));
      }
    }

    if (!stale) {
      sendProximityNotifications(doctor_id);
      sendPositionNotifications(doctor_id, appointment_id);
    }
    const skipServing = await fetchCurrentServing(appointment_id);
    emitQueueUpdate(req, 'skip', doctor_id, { current_serving: skipServing });

    return res.json({
      success: true,
      message: row.message || 'Patient skipped and notified'
    });

  } catch (error) {
    log.error('queueSkip error: ' + error.message);
    return res.status(500).json({
      success: false,
      message: 'Queue skip failed',
      error: error.message
    });
  }
});


//QUEUE RECALL
router.post('/appointment/queueRecall', async (req, res) => {
  const { appointment_id, doctor_id } = req.body;

  // ✅ validation
  if (!appointment_id) {
    return res.status(400).json({
      success: false,
      message: 'appointment_id required'
    });
  }

  try {
    const result = await db.request()
      .input('operation', 'RECALL_SESSION')
      .input('appointment_id', appointment_id)
      .execute('sp_appointment');

    const row = result.recordset?.[0] ?? {};

    if (row.success === 1) {
      const recallServing = await fetchCurrentServing(appointment_id);
      emitQueueUpdate(req, 'recall', doctor_id, { current_serving: recallServing });
    }

    return res.json({
      success: row.success === 1,
      message: row.message ?? 'Patient recalled'
    });

  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Queue recall failed',
      error: error.message
    });
  }
});


router.post('/appointment/startSession', async (req, res) => {
  const { doctor_id, appointment_id } = req.body;

  // ✅ validation
  if (!doctor_id || !appointment_id) {
    return res.status(400).json({
      success: false,
      message: 'doctor_id and appointment_id are required'
    });
  }

  try {
    const result = await db.request()
      .input('operation', 'START_SESSION')
      .input('doctor_id', doctor_id)
      .input('appointment_id', appointment_id)
      .execute('sp_appointment');

    const row = result.recordset?.[0] ?? {};

    if (row.success === 1) {
      const startServing = await fetchCurrentServing(appointment_id);
      emitQueueUpdate(req, 'session_started', doctor_id, { current_serving: startServing });
    }
    return res.json({
      success: row.success === 1,
      message: row.message ?? 'Session started'
    });

  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Start session failed',
      error: error.message
    });
  }
});



//END SESSION 
router.post('/appointment/endSession', async (req, res) => {
  const { doctor_id, appointment_id, clinic_id } = req.body;

  if (!doctor_id || !appointment_id) {
    return res.status(400).json({
      success: false,
      message: 'doctor_id and appointment_id are required'
    });
  }

  try {
    const result = await db.request()
      .input('operation', 'END_SESSION')
      .input('doctor_id', doctor_id)
      .input('appointment_id', appointment_id)
      .input('clinic_id', clinic_id || null)
      .execute('sp_appointment');

    const allRows = (result.recordsets || [result.recordset || []]).flat();
    const statusRow = allRows.find(r => r && r.success != null) || {};

    if (statusRow.success !== 1) {
      return res.json({
        success: false,
        message: statusRow.message || 'End session failed'
      });
    }

    // Practo-style queue notifications are purely position/ETA driven. The
    // patient who just moved up gets a single "Almost your turn" from
    // sendProximityNotifications — we deliberately DON'T send a separate fixed
    // "Be Ready (3rd in queue)" push, which only duplicated the proximity
    // 'near' stage for the same patient. Every ended consultation shifts each
    // waiting patient one slot closer, so re-scan proximity here.
    if (!isStaleReplay(req)) {
      sendProximityNotifications(doctor_id, clinic_id);
      sendPositionNotifications(doctor_id, appointment_id);
    }
    emitQueueUpdate(req, 'session_ended', doctor_id);

    return res.json({
      success: true,
      message: statusRow.message || 'Session ended'
    });

  } catch (error) {
    log.error('endSession error: ' + error.message);
    return res.status(500).json({
      success: false,
      message: 'End session failed',
      error: error.message
    });
  }
});


// QUEUE PAUSE (EMERGENCY)
// Mirrors QUEUE_PAUSE convention: SP returns row[0] = status, rows[1..] = { token }
// for every still-waiting patient on this queue. Each remaining patient gets an
// "emergency pause" notification so they don't keep waiting in the dark.
router.post('/appointment/queuePauseEmergency/:queue_id', async (req, res) => {
  const { queue_id } = req.params;

  if (!queue_id) {
    return res.status(400).json({
      success: false,
      message: 'queue_id required'
    });
  }

  try {
    const result = await db.request()
      .input('operation', 'QUEUE_PAUSE_EMERGENCY')
      .input('queue_id', queue_id)
      .execute('sp_appointment');

    // SP returns 2 separate result sets: [0] = status, [1] = token rows.
    // node-mssql's `result.recordset` is only the FIRST recordset, so tokens
    // live in `result.recordsets[1]`.
    const recordsets = result.recordsets || [];
    const statusRow = recordsets[0]?.[0] || {};
    const tokenRows = recordsets[1] || [];

    log.debug('[queuePauseEmergency] recordsets count: ' + recordsets.length);
    log.debug('[queuePauseEmergency] status row: ' + JSON.stringify(statusRow));
    log.debug('[queuePauseEmergency] token rows count: ' + tokenRows.length);

    if (statusRow.success !== 1) {
      return res.json({
        success: false,
        message: statusRow.message || 'Queue pause failed'
      });
    }

    const tokens = tokenRows
      .map(r => r.token)
      .filter(t => t && t.trim() !== '');

    log.debug('[queuePauseEmergency] tokens extracted: ' + tokens.length);

    let emergencyDoctorId = null;
    let doctorName = 'your doctor';
    try {
      const dn = await db.request()
        .input('queue_id', queue_id)
        .query(`SELECT dq.doctor_id, d.name FROM doctor_queue dq
                JOIN doctor_login d ON d.doctor_id = dq.doctor_id
                WHERE dq.queue_id = @queue_id`);
      emergencyDoctorId = dn.recordset?.[0]?.doctor_id ?? null;
      doctorName = dn.recordset?.[0]?.name || 'your doctor';
    } catch (e) { log.error('[queuePauseEmergency] name lookup failed: ' + e.message); }

    if (tokens.length > 0) {
      const pauseTitle = 'Queue Paused (Emergency)';
      const pauseBody = `Dr. ${doctorName} has paused the queue due to an emergency. Please wait — we will notify you when it resumes.`;

      for (const tk of tokens) {
        await insertNotificationForToken(tk, pauseTitle, pauseBody, 'queue', queue_id);
      }

      const message = {
        notification: { title: pauseTitle, body: pauseBody },
        data: { type: 'queue' },
        tokens: tokens,
      };

      const response = await admin.messaging().sendEachForMulticast(message);
      log.info('[queuePauseEmergency] FCM result: ' + response.successCount + '/' + tokens.length);

      emitQueueUpdate(req, 'queue_paused_emergency', emergencyDoctorId, { queue_id });
      return res.json({
        success: true,
        message: statusRow.message || 'Queue paused successfully',
        total_tokens: tokens.length,
        success_count: response.successCount,
        failure_count: response.failureCount
      });
    }

    emitQueueUpdate(req, 'queue_paused_emergency', emergencyDoctorId, { queue_id });
    return res.json({
      success: true,
      message: statusRow.message || 'Queue paused, no patients to notify'
    });

  } catch (error) {
    log.error('[queuePauseEmergency] error: ' + error.message);
    return res.status(500).json({
      success: false,
      message: 'Queue pause failed',
      error: error.message
    });
  }
});


//cron job ---------------------------------------------------------------------------------------------------------------------------------
cron.schedule('0 14 * * *', async () => {
  try {
    const result = await db.request()
      .input('operation', 'TOMORROW_PATIENT_APPOINTMENTS')
      .execute('sp_appointment');

    const rows = result.recordset || [];

    if (rows.length === 0) {
      log.info('[cron 14:00] No appointments for tomorrow');
      return;
    }

    let successCount = 0;
    let failureCount = 0;

    for (const row of rows) {
      const token = row.patient_token;
      const doctorName = row.doctor_name;
      if (!token) continue;

      // Date from the DATE column, time from the TIME column. Formatting the
      // date's own time always yields midnight → 05:30 am in IST; start_time
      // holds the real booked slot time.
      const formattedDate = formatApptDate(row.appointment_date);
      const formattedTime = formatApptTime(row.start_time);
      const remTitle = 'Appointment Reminder';
      const remBody = `Your appointment with Dr. ${doctorName} is scheduled on ${formattedDate} at ${formattedTime}.`;

      await insertNotificationForToken(token, remTitle, remBody, 'appointment', row.appointment_id);

      const message = {
        token: token,
        notification: { title: remTitle, body: remBody },
        // appointment_id lets the killed-app FCM tap auto-open the detail
        // sheet for the reminded appointment.
        data: { type: 'appointment', appointment_id: String(row.appointment_id) },
      };

      try {
        await admin.messaging().send(message);
        successCount++;
      } catch (err) {
        log.error('FCM Error: ' + err.message);
        failureCount++;
      }
    }

    log.info(`[cron 14:00] Tomorrow reminders sent: ${successCount} ok, ${failureCount} failed / ${rows.length} total`);

  } catch (error) {
    log.error('[cron 14:00] Failed to send reminders: ' + error.message);
  }
}, { timezone: 'Asia/Kolkata' });


cron.schedule('0 15 * * *', async () => {
  try {
    const result = await db.request()
      .input('operation', 'TOMORROW_PATIENT_APPOINTMENTS')
      .execute('sp_appointment');

    const rows = result.recordset || [];

    if (rows.length === 0) {
      log.info('[cron 15:00] No appointments for tomorrow');
      return;
    }

    for (const row of rows) {
      const token = row.patient_token;
      const doctorName = row.doctor_name;
      if (!token) continue;

      // Date from the DATE column, time from the TIME column (see 14:00 cron).
      const formattedDate = formatApptDate(row.appointment_date);
      const formattedTime = formatApptTime(row.start_time);

      const remTitle = 'Appointment Reminder';
      const remBody = `Your appointment with Dr. ${doctorName} is scheduled on ${formattedDate} at ${formattedTime}.`;

      await insertNotificationForToken(token, remTitle, remBody, 'appointment', row.appointment_id);

      const message = {
        token: token,
        notification: { title: remTitle, body: remBody },
        // appointment_id lets the killed-app FCM tap auto-open the detail
        // sheet for the reminded appointment.
        data: { type: 'appointment', appointment_id: String(row.appointment_id) },
      };

      try {
        await admin.messaging().send(message);
      } catch (err) {
        log.error('FCM Error: ' + err.message);
      }
    }

    log.info(`[cron 15:00] Tomorrow reminders sent: ${rows.length} total`);

  } catch (error) {
    log.error('[cron 15:00] Failed to send reminders: ' + error.message);
  }
}, { timezone: 'Asia/Kolkata' });


cron.schedule('0 16 * * *', async () => {
  try {
    const result = await db.request()
      .input('operation', 'YESTERDAY_COMPLETED_PATIENTS')
      .execute('sp_appointment');

    const rows = result.recordset || [];

    if (rows.length === 0) {
      log.info('[cron 16:00] No patients to send rating request');
      return;
    }

    let successCount = 0;
    let failureCount = 0;

    for (const row of rows) {
      const token = row.patient_token;
      const doctorName = row.doctor_name;
      const appointmentId = row.appointment_id;

      if (!token) continue;

      const rateTitle = 'Rate Your Experience';
      const rateBody = `How was your consultation with Dr. ${doctorName}? Tap to rate.`;

      await insertNotificationForToken(token, rateTitle, rateBody, 'rating', appointmentId);

      const message = {
        token: token,
        notification: { title: rateTitle, body: rateBody },
        data: {
          appointment_id: appointmentId.toString(),
          type: 'rating',
        },
      };

      try {
        await admin.messaging().send(message);
        successCount++;
      } catch (err) {
        log.error('FCM Error: ' + err.message);
        failureCount++;
      }
    }

    log.info(`[cron 16:00] Rating notifications sent: ${successCount} ok, ${failureCount} failed / ${rows.length} total`);

  } catch (error) {
    log.error('[cron 16:00] Failed to send rating notifications: ' + error.message);
  }

}, { timezone: 'Asia/Kolkata' });


// Follow-up reminders (Practo pattern). When a doctor sets a follow_up_date on a
// prescription, the patient is reminded the day BEFORE and again the DAY OF so
// they book the review visit. sp_prescription 'FollowUpReminders' returns one row
// per prescription whose follow_up_date is today or tomorrow, each carrying the
// patient's FCM token (patient or family-head), the doctor name and a
// reminder_kind flag ('day_before' | 'day_of').
//
// Extracted from the cron so the /test/followup-reminders debug route can fire it
// on demand without waiting for 09:00. `tag` only labels the log line.
async function runFollowUpReminders(tag = 'cron 09:00') {
  const result = await db.request()
    .input('operation', 'FollowUpReminders')
    .execute('sp_prescription');

  const rows = result.recordset || [];

  if (rows.length === 0) {
    log.info(`[${tag}] No follow-up reminders due`);
    return { total: 0, sent: 0, failed: 0, skipped: 0 };
  }

  let successCount = 0;
  let failureCount = 0;
  let skippedCount = 0;

  for (const row of rows) {
    const token = row.patient_token;
    const doctorName = row.doctor_name || 'your doctor';
    const kind = row.reminder_kind; // 'day_before' | 'day_of'

    if (!token || !kind) { skippedCount++; continue; }

    const title = kind === 'day_of' ? 'Follow-up Today' : 'Follow-up Tomorrow';
    const body = kind === 'day_of'
      ? `Your follow-up with Dr. ${doctorName} is today. Tap to book your visit.`
      : `Your follow-up with Dr. ${doctorName} is tomorrow. Tap to book your visit.`;

    // type 'appointment' with no appointment_id → the tap lands on the
    // appointments tab where the patient can book the follow-up. doctor_id is
    // carried for any future "pre-select this doctor" booking deep link.
    await insertNotificationForToken(token, title, body, 'appointment', null);

    const message = {
      token,
      notification: { title, body },
      data: {
        type: 'appointment',
        action: 'followup',
        doctor_id: String(row.doctor_id ?? ''),
        prescription_id: String(row.prescription_id ?? ''),
      },
    };

    try {
      await admin.messaging().send(message);
      successCount++;
    } catch (err) {
      log.error('FCM Error: ' + err.message);
      failureCount++;
    }
  }

  log.info(`[${tag}] Follow-up reminders sent: ${successCount} ok, ${failureCount} failed, ${skippedCount} skipped / ${rows.length} total`);
  return { total: rows.length, sent: successCount, failed: failureCount, skipped: skippedCount };
}

cron.schedule('0 9 * * *', async () => {
  try {
    await runFollowUpReminders('cron 09:00');
  } catch (error) {
    log.error('[cron 09:00] Failed to send follow-up reminders: ' + error.message);
  }
}, { timezone: 'Asia/Kolkata' });


// CANCEL SLOT APPOINTMENT BY DOCTOR
router.post('/appointment/cancelByDoctor', async (req, res) => {
  const { appointment_id, doctor_id } = req.body;

  if (!appointment_id || !doctor_id) {
    return res.status(400).json({
      success: false,
      message: 'appointment_id and doctor_id required'
    });
  }

  try {
    const result = await db.request()
      .input('operation', 'CANCEL_BY_DOCTOR')
      .input('appointment_id', appointment_id)
      .input('doctor_id', doctor_id)
      .execute('sp_appointment');

    const row = result.recordset?.[0] || {};

    if (row.success !== 1) {
      return res.json({
        success: false,
        message: row.message || 'Cancel failed'
      });
    }

    // Cancelling a patient shifts everyone behind them up — re-scan proximity.
    sendProximityNotifications(doctor_id);
    emitQueueUpdate(req, 'cancel', doctor_id);

    return res.json({
      success: true,
      message: row.message || 'Slot appointment cancelled successfully'
    });

  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Cancel failed',
      error: error.message
    });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// WALK-IN PATIENT BOOK (Receptionist)
// Finds or creates a patient by mobile, then books the appointment.
// ─────────────────────────────────────────────────────────────────────────────
router.post('/walkInBook', async (req, res) => {
  const { name, mobile_no, doctor_id, clinic_id, appointment_date, start_time, slot_id, user_type, symptoms, gender_id, family_id, patient_id: existingPatientId } = req.body;

  if (!name || !mobile_no || !doctor_id || !appointment_date) {
    return res.status(400).json({ success: false, message: 'name, mobile_no, doctor_id, appointment_date required' });
  }

  try {
    // Offline replay (offline_queued_at set by the app): the original send may
    // have landed before its response was lost, so first check whether this
    // walk-in already exists — same doctor, date, name and mobile, not
    // cancelled — and return it instead of creating a second patient + booking.
    // Online walk-ins skip this check and behave exactly as before.
    if (req.body.offline_queued_at) {
      const dup = await db.request()
        .input('doctor_id', sql.Int, parseInt(doctor_id))
        .input('appointment_date', appointment_date)
        .input('name', String(name).trim())
        .input('mobile_no', String(mobile_no))
        .query(`
          SELECT TOP 1 a.appointment_id, a.patient_id
          FROM appointments a
          LEFT JOIN patients p ON a.user_type = 1 AND p.patient_id = a.patient_id
          LEFT JOIN family_members fm ON a.user_type = 2 AND fm.member_id = a.patient_id
          WHERE a.doctor_id = @doctor_id
            AND a.appointment_date = @appointment_date
            AND LOWER(ISNULL(a.status, '')) <> 'cancelled'
            AND LTRIM(RTRIM(COALESCE(p.name, fm.name))) = @name
            AND COALESCE(p.mobile_no, fm.mobile_no) = @mobile_no
        `);
      const row = dup.recordset?.[0];
      if (row) {
        log.info(`walkInBook: replay matched existing appointment ${row.appointment_id} — skipped duplicate`);
        return res.json({ success: true, message: 'Walk-in already booked', patient_id: row.patient_id });
      }
    }

    let patient_id;

    if (family_id) {
      // Family member booking: insert into family_members, then book appointment under the
      // primary patient's id (family_id) with user_type=2.
      const famRes = await db.request()
        .input('operation', 'Insert')
        .input('member_id', null)
        .input('family_id', parseInt(family_id))
        .input('name', String(name).trim())
        .input('Gender_id', gender_id ? parseInt(gender_id) : null)
        .input('relation_id', null)
        .input('DOB', null)
        .input('mobile_no', mobile_no)
        .execute('sp_family_members');
      patient_id = famRes.recordset[0]?.member_id;
      log.info(`walkInBook family: family_id=${family_id} member_id=${patient_id} recordset=${JSON.stringify(famRes.recordset)}`);
      if (!patient_id) throw new Error('Failed to create family member record');
    } else if (existingPatientId) {
      // Existing patient returning — use their patient_id directly.
      patient_id = parseInt(existingPatientId);
    } else {
      // New first-time walk-in — create a shadow profile in patients table.
      const insertRes = await db.request()
        .input('operation', 'Insert')
        .input('patient_id', null)
        .input('name', String(name).trim())
        .input('mobile_no', mobile_no)
        .input('email', null)
        .input('Address', null)
        .input('gender_id', gender_id ? parseInt(gender_id) : null)
        .input('DOB', null)
        .input('blood_group_id', null)
        .input('weight', null)
        .execute('sp_patients');
      patient_id = insertRes.recordset[0]?.patient_id;
      if (!patient_id) throw new Error('Failed to create patient profile');
    }

    // Step 2: Check doctor leave
    const blockRes = await db.request()
      .input('operation', 'IS_BLOCKED')
      .input('doctor_id', doctor_id)
      .input('from_date', appointment_date)
      .execute('sp_doctor_leave');

    if (blockRes.recordset?.[0]?.blocked === 1) {
      return res.json({ success: false, message: 'Doctor is on leave on this date. Please pick another date.' });
    }

    // Step 3: Book appointment
    const bookRes = await db.request()
      .input('operation', 'BOOK')
      .input('user_type', user_type || 1)
      .input('doctor_id', doctor_id)
      .input('patient_id', patient_id)
      .input('appointment_date', appointment_date)
      .input('start_time', start_time || null)
      .input('slot_id', slot_id || null)
      .input('symptoms', symptoms || '')
      .input('clinic_id', clinic_id || null)
      .execute('sp_appointment');

    const booked = bookRes.recordset[0].success === 1;
    log.info(`walkInBook: patient_id=${patient_id} user_type=${user_type} family_id=${family_id || null} booked=${booked} msg=${bookRes.recordset[0].message}`);
    if (booked) emitQueueUpdate(req, 'booked', doctor_id);

    return res.json({
      success: booked,
      message: bookRes.recordset[0].message,
      patient_id,
    });

  } catch (error) {
    return res.status(500).json({ success: false, message: 'Walk-in booking failed', error: error.message });
  }
});





// ─────────────────────────────────────────────────────────────────────────────
// AUTO-CLOSE STALE SESSIONS
// A queue/slot session a doctor forgets to close at end of day stays "open"
// (doctor_queue.queue_status <> 3 with queue_date < today). GET_TODAY_QUEUE then
// keeps returning it, so it lingers on the doctor's Home / Patient List the next
// day, and its booked/skipped patients are never told their visit lapsed.
//
// This sweep, for every stale session:
//   1. closes each stale queue by reusing the proven QUEUE_STOP flow (same as the
//      manual Close button at /appointment/queueStop), and
//   2. cancels any remaining past-dated pending appointment (slot bookings +
//      stragglers) via CANCEL_BY_DOCTOR,
// then notifies each affected patient that they missed their appointment.
//
// Idempotent: only still-pending rows are selected, so a second run is a no-op —
// safe to fire from the nightly cron, on startup, AND lazily on getTodayQueue.
// ─────────────────────────────────────────────────────────────────────────────

// Only notify about a no-show that lapsed recently. The nightly cron always sees
// yesterday's data (so this is always true there), but a first-run / startup
// catch-up can hit a backlog of weeks-old sessions — we still cancel+close those
// for cleanup, but pushing "you missed your 15 May visit" today would be spam.
const NOTIFY_MAX_AGE_DAYS = 2;
function isWithinNotifyWindow(rawDate) {
  if (!rawDate) return false;
  const d = new Date(rawDate);
  if (isNaN(d.getTime())) return false;
  const ageMs = Date.now() - d.getTime();
  return ageMs <= NOTIFY_MAX_AGE_DAYS * 24 * 60 * 60 * 1000;
}

// Shared "you missed your visit" notification (inbox row + FCM). Mirrors the
// data payload shape used by queueStop so the killed-app tap behaves the same.
// Silently skips stale backlog (see NOTIFY_MAX_AGE_DAYS) — cancellation already
// happened at the call site regardless.
async function notifyMissedAppointment(doctor_id, a) {
  if (!isWithinNotifyWindow(a.rawDate)) return;

  const title = 'Appointment Closed';
  const when = a.date ? ` on ${a.date}` : '';
  const body =
    `You missed your appointment with Dr. ${a.doctor_name}${when}. ` +
    `It has been closed. Tap to book again.`;

  await insertNotification(a.patient_id, title, body, 'appointment', a.appointment_id);

  if (a.token && a.token.trim() !== '') {
    await admin.messaging().send({
      token: a.token,
      notification: { title, body },
      data: {
        type: 'appointment',
        action: 'cancelled',
        doctor_id: String(doctor_id),
        appointment_id: String(a.appointment_id),
      },
    }).catch(err => log.error('FCM err (staleSweep): ' + (err.code || err.message)));
  }
}

// Close one stale queue — mirrors the /appointment/queueStop handler: capture
// affected (pending + skipped) patients BEFORE the SP mutates them, run QUEUE_STOP,
// then notify with no-show wording.
async function closeOneStaleQueue(doctor_id, queue_id) {
  const detailsRes = await db.request()
    .input('operation', 'APPT_CONTEXT_QUEUE')
    .input('doctor_id', doctor_id)
    .input('queue_id', queue_id)
    .execute('sp_notification');

  const affected = [];
  for (const row of (detailsRes.recordset || [])) {
    if (!row.owner_id) continue;
    affected.push({
      patient_id: row.owner_id,
      token: row.owner_token,
      doctor_name: row.doctor_name || 'your doctor',
      date: formatApptDate(row.appointment_date),
      rawDate: row.appointment_date,
      appointment_id: row.appointment_id,
    });
  }

  // Skipped patients aren't in the cancel context but are still left waiting —
  // capture them before QUEUE_STOP flips their status.
  const affectedIds = new Set(affected.map(a => a.patient_id));
  const doctorName = affected[0]?.doctor_name || 'your doctor';
  try {
    const skippedRes = await db.request()
      .input('queue_id', queue_id)
      .query(`
        SELECT a.patient_id, p.token AS owner_token, a.appointment_id,
               a.appointment_date
        FROM appointments a
        LEFT JOIN patients p ON a.user_type = 1 AND p.patient_id = a.patient_id
        WHERE a.queue_id = @queue_id AND LOWER(a.status) = 'skipped'
      `);
    for (const r of (skippedRes.recordset || [])) {
      if (!r.patient_id || affectedIds.has(r.patient_id)) continue;
      affected.push({
        patient_id: r.patient_id,
        token: r.owner_token,
        doctor_name: doctorName,
        date: formatApptDate(r.appointment_date),
        rawDate: r.appointment_date,
        appointment_id: r.appointment_id,
      });
    }
  } catch (e) {
    log.error('[staleSweep] skipped lookup failed: ' + e.message);
  }

  const result = await db.request()
    .input('operation', 'QUEUE_STOP')
    .input('queue_id', queue_id)
    .input('doctor_id', doctor_id)
    .execute('sp_appointment');
  const statusRow = (result.recordset || [])[0] || {};
  if (statusRow.success !== 1) {
    throw new Error(statusRow.message || 'QUEUE_STOP failed');
  }

  await Promise.all(affected.map(a => notifyMissedAppointment(doctor_id, a)));
  return affected.length;
}

// Cancel any past-dated appointment still pending (slot bookings + stragglers not
// tied to a queue closed above). Queue rows are already 'cancelled' by QUEUE_STOP,
// so this picks up only what's left — keeping the sweep idempotent.
async function cancelStalePendingAppointments() {
  const res = await db.request().query(`
    SELECT a.appointment_id, a.doctor_id, a.patient_id, a.appointment_date,
           p.token AS owner_token, d.name AS doctor_name
    FROM appointments a
    LEFT JOIN patients p     ON a.user_type = 1 AND p.patient_id = a.patient_id
    LEFT JOIN doctor_login d ON d.doctor_id = a.doctor_id
    WHERE a.appointment_date < CAST(GETDATE() AS DATE)
      AND LOWER(a.status) IN ('booked', 'in_progress', 'skipped')
  `);

  let count = 0;
  for (const row of (res.recordset || [])) {
    try {
      const r = await db.request()
        .input('operation', 'CANCEL_BY_DOCTOR')
        .input('appointment_id', row.appointment_id)
        .input('doctor_id', row.doctor_id)
        .execute('sp_appointment');
      if ((r.recordset?.[0]?.success) !== 1) continue;
      count++;
      await notifyMissedAppointment(row.doctor_id, {
        patient_id: row.patient_id,
        token: row.owner_token,
        doctor_name: row.doctor_name || 'your doctor',
        date: formatApptDate(row.appointment_date),
        rawDate: row.appointment_date,
        appointment_id: row.appointment_id,
      });
    } catch (e) {
      log.error(`[staleSweep] cancel appt ${row.appointment_id} failed: ${e.message}`);
    }
  }
  return count;
}

// In-process guard so the nightly cron and a lazy getTodayQueue call can't run the
// sweep concurrently (would double-notify on a race).
let _staleSweepRunning = false;
async function closeStaleSessions() {
  if (_staleSweepRunning) return { skipped: true };
  _staleSweepRunning = true;
  let queuesClosed = 0;
  let slotsCancelled = 0;
  try {
    const staleQ = await db.request().query(`
      SELECT queue_id, doctor_id FROM doctor_queue
      WHERE queue_date < CAST(GETDATE() AS DATE) AND queue_status <> 3
    `);

    for (const q of (staleQ.recordset || [])) {
      try {
        await closeOneStaleQueue(q.doctor_id, q.queue_id);
        queuesClosed++;
      } catch (e) {
        log.error(`[staleSweep] queue ${q.queue_id} failed: ${e.message}`);
      }
    }

    slotsCancelled = await cancelStalePendingAppointments();

    if (queuesClosed > 0 || slotsCancelled > 0) {
      log.info(`[staleSweep] closed ${queuesClosed} stale queue(s), cancelled ${slotsCancelled} stale appt(s)`);
    }
    return { queuesClosed, slotsCancelled };
  } catch (e) {
    log.error('[staleSweep] failed: ' + e.message);
    return { error: e.message };
  } finally {
    _staleSweepRunning = false;
  }
}

// Nightly at 00:05 IST → a previous-day session is auto-closed as the new day starts.
cron.schedule('5 0 * * *', () => { closeStaleSessions(); },
  { timezone: 'Asia/Kolkata' });

// Catch up once on startup — covers a server/IIS recycle that straddled midnight
// and missed the cron. Deferred so it never blocks the listen() call.
setTimeout(() => { closeStaleSessions(); }, 5000);

module.exports = router;
module.exports.closeStaleSessions = closeStaleSessions; 
`````

## `backend/routes/Doctor/users.js`

`````js
var express = require('express');
var router = express.Router();
var db = require('../db'); // go from admin/ to routes/
const sql = require("mssql");
const multer = require("multer");
const path = require("path");

const fs = require("fs-extra");
// Auto-close sweep for previous-day sessions (cancel + notify). Shared from the
// insert router so getTodayQueue can self-heal stale data on demand.
const { closeStaleSessions } = require('./insert');


router.get('/getMedicineTypes', async (req, res) => {
  try {
    const request = db.request();

    request.input('operation', 'getMedicineTypes');

    const result = await request.execute('sp_Medicine_Master'); // change if needed

    res.status(200).json(
      result.recordset
    );

  } catch (error) {
    res.status(500).json({
      success: 0,
      message: `Failed to fetch medicine types ${error}`
    });
  }
});


router.get('/getMedicineSuggestions', async (req, res) => {
  const { q } = req.query;

  if (!q || q.toString().trim().length === 0) {
    return res.status(200).json([]);
  }

  try {
    const request = db.request();
    request.input('operation', 'getSuggestions');
    request.input('search_query', q.toString().trim());

    const result = await request.execute('sp_Medicine_Master');
    res.status(200).json(result.recordset);
  } catch (error) {
    res.status(500).json({
      success: 0,
      message: `Failed to fetch suggestions ${error}`
    });
  }
});


router.get('/getAllMedicines/:doctor_id', async (req, res) => {
  const { doctor_id } = req.params;

  try {
    const request = db.request();

    request.input('operation', 'fetchAllMedicines');
    request.input('doctor_id', doctor_id);

    const result = await request.execute('sp_Medicine_Master');

    res.status(200).json(
      result.recordset
    );

  } catch (error) {
    res.status(500).json({
      success: 0,
      message: `Failed to fetch medicines ${error}`
    });
  }
});

router.get('/getDoctorSchedule/:doctor_id', async (req, res) => {
  const { doctor_id } = req.params;
  const { clinic_id } = req.query;

  try {

    const req2 = db.request()
      .input('operation', 'GET')
      .input('doctor_id', doctor_id);
    if (clinic_id) req2.input('clinic_id', clinic_id);
    const result = await req2.execute('sp_doctor_schedule');

    const rows = result.recordset;

    const grouped = {};

    for (const row of rows) {

      if (!grouped[row.day_of_week]) {
        grouped[row.day_of_week] = {
          day: row.day_of_week,
          is_enabled: row.is_enabled ? 1 : 0,
          slots: []
        };
      }



      if (row.slot_id) {
        grouped[row.day_of_week].slots.push({
          slot_id: row.slot_id,
          start_time: row.start_time,   // already HH:mm
          end_time: row.end_time,
          booking_mode: row.booking_mode,
          slot_duration: row.slot_duration,
          max_queue_length: row.max_queue_length
        });
      }
    }

    const schedule = Object.values(grouped);

    res.status(200).json({
      doctor_id: parseInt(doctor_id),
      schedule: schedule
    });

  } catch (error) {

    res.status(500).json({
      success: false,
      message: 'Error fetching schedule',
      error: error.message
    });

  }
});



router.get('/patientAppointmentList/:doctor_id', async (req, res) => {
  const { doctor_id } = req.params;
  const { clinic_id } = req.query;

  try {
    const request = db.request();

    request.input('operation', 'patientAppointmentList');
    request.input('doctor_id', doctor_id);
    if (clinic_id) request.input('clinic_id', clinic_id);

    const result = await request.execute('sp_appointment');
    const rows = result.recordset || [];

    // sp_appointment predates is_arrived — patch it in with a lookup instead
    // of touching the stored procedure.
    const skippedIds = rows
      .filter(r => (r.status || '').toLowerCase() === 'skipped')
      .map(r => r.appointment_id);
    if (skippedIds.length > 0) {
      const arrivedRes = await db.request()
        .query(`
          SELECT appointment_id, is_arrived, arrived_at
          FROM appointments
          WHERE appointment_id IN (${skippedIds.map(id => Number(id)).join(',')})
        `);
      const arrivedMap = new Map(
        (arrivedRes.recordset || []).map(r => [r.appointment_id, r])
      );
      for (const r of rows) {
        const a = arrivedMap.get(r.appointment_id);
        r.is_arrived = a?.is_arrived ?? false;
        r.arrived_at = a?.arrived_at ?? null;
      }
    }

    res.status(200).json(rows);

  } catch (error) {
    res.status(500).json({
      success: 0,
      message: `Failed to fetch Appointment List ${error}`
    });
  }
});
router.get('/appointmentWisePrescription/:appointment_id', async (req, res) => {
  const { appointment_id } = req.params;

  try {

    const result = await db.request()
      .input('appointment_id', appointment_id)
      .input('operation', 'AppointmentWisePrescription')
      .execute('sp_prescription');

    res.status(200).json(result.recordset);

  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error fetching prescription details',
      error: error.message
    });
  }
});


// GET TODAY QUEUE
router.get('/appointment/getTodayQueue/:doctor_id', async (req, res) => {
  const { doctor_id } = req.params;
  const { clinic_id } = req.query;

  if (!doctor_id) {
    return res.status(400).json({
      success: false,
      message: 'doctor_id required'
    });
  }

  try {
    // Self-heal: close any previous-day session (cancel its lapsed patients +
    // notify) before reading, so a doctor opening the app never sees stale data
    // even if the nightly cron / startup catch-up was missed. No-op on normal days.
    try { await closeStaleSessions(); } catch (e) { /* never block the read */ }

    const req2 = db.request()
      .input('operation', 'GET_TODAY_QUEUE')
      .input('doctor_id', doctor_id);
    if (clinic_id) req2.input('clinic_id', clinic_id);
    const result = await req2.execute('sp_appointment');

    const rows = result.recordsets?.[0] || [];
    const statusRow = result.recordsets?.[1]?.[0] || {};

    if (statusRow.success !== 1) {
      return res.json({
        success: false,
        message: statusRow || 'Failed to fetch queue'
      });
    }

    // Enrich with booking_closed (the "stop new bookings" toggle) — sp_appointment's
    // GET_TODAY_QUEUE doesn't return it, so fetch it directly rather than touch the SP.
    const queueIds = rows.map(r => r.queue_id).filter(id => id != null);
    if (queueIds.length > 0) {
      const bcRes = await db.request().query(`
        SELECT queue_id, booking_closed FROM doctor_queue
        WHERE queue_id IN (${queueIds.map(id => Number(id)).join(',')})
      `);
      const bcMap = new Map((bcRes.recordset || []).map(r => [r.queue_id, r.booking_closed]));
      for (const r of rows) r.booking_closed = bcMap.get(r.queue_id) === true;
    }

    return res.json(rows);

  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Failed to fetch queue',
      error: error.message
    });
  }
});





// Clinic gallery — list active gallery images for a clinic.
// Mounted at /doctor/users → GET /doctor/users/clinicGallery/:clinic_id
router.get('/clinicGallery/:clinic_id', async (req, res) => {
  try {
    const { clinic_id } = req.params;
    if (!clinic_id) {
      return res.status(400).json({ success: false, message: 'clinic_id is required' });
    }
    const result = await db.request()
      .input('operation', 'fetchClinicGallery')
      .input('clinic_id', clinic_id)
      .execute('sp_doctor_login');
    return res.status(200).json(result.recordset);
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Failed to fetch clinic gallery',
      error: error.message,
    });
  }
});



router.get('/getDoctorsByClinic/:clinic_id', async (req, res) => {
  const { clinic_id } = req.params;
  try {
    const result = await db.request()
      .input('operation', 'FetchDoctors')
      .input('clinic_id', clinic_id)
      .execute('sp_doctor_login');
    res.status(200).json(result.recordset);
  } catch (error) {
    res.status(500).json({ success: 0, message: `Failed to fetch clinic doctors: ${error.message}` });
  }
});



router.get('/fetchReceptionistList/:doctor_id', async (req, res) => {
  const { doctor_id } = req.params;
  console.log('[ReceptionistDebug] fetchReceptionistList doctor_id:', doctor_id);

  try {
    const request = db.request();

    request.input('operation', 'FetchReceptionistList');
    request.input('doctor_id', doctor_id);

    const result = await request.execute('sp_receptionist');
    console.log(
      '[ReceptionistDebug] fetchReceptionistList count:',
      result.recordset?.length || 0
    );

    res.status(200).json(result.recordset);

  } catch (error) {
    console.error('[ReceptionistDebug] fetchReceptionistList error:', error);
    res.status(500).json({
      success: 0,
      message: `Failed to fetch receptionist list: ${error.message}`
    });
  }
});



module.exports = router; 
`````

## `backend/routes/login.js`

`````js
const express = require('express');
const router = express.Router();
const jwt = require('jsonwebtoken');
require('dotenv').config();
const auth = require('./middleware/auth');
const authorize = require('./middleware/authorize');
const { ROLE, ROLE_ID_BY_NAME, ROLE_NAME_BY_ID, resolveRoleId } = require('./middleware/roles');
const db = require('./db'); // your mssql pool wrapper
const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const axios = require('axios');
const path = require('path');
const fs = require("fs-extra");
const { authLimiter, lookupLimiter } = require('./middleware/rateLimit');
const { upload, uploadHandler, verifyImageFiles, cleanupFiles } = require('./middleware/upload');
const log = require('./middleware/logger');

// Public base URL is required for returned image URLs to be reachable by
// clients. Fail fast at startup rather than silently building broken links.
const PUBLIC_BASE_URL = (process.env.PUBLIC_BASE_URL || '').replace(/\/+$/, '');
if (!PUBLIC_BASE_URL) {
	throw new Error('Missing required env var: PUBLIC_BASE_URL');
}

// Refresh-token lifetime. Access tokens are short (15m); the refresh token is
// what keeps the user signed in across days, so give it a long, Practo-style
// window. Override via REFRESH_TOKEN_TTL_DAYS env without a code change.
const REFRESH_TOKEN_TTL_DAYS = parseInt(process.env.REFRESH_TOKEN_TTL_DAYS, 10) || 30;
const REFRESH_TOKEN_TTL_MS = REFRESH_TOKEN_TTL_DAYS * 24 * 3600 * 1000;

// Login tickets prove "this mobile just passed OTP". Short-lived on purpose:
// long enough to finish the login call, too short to be worth stealing.
const LOGIN_TICKET_TTL = process.env.LOGIN_TICKET_TTL || '5m';

// Review/QA accounts skip the SMS OTP (mirrors frontend/lib/core/demo_accounts.dart).
// They still have to present the fixed demo OTP — the ranges alone are not a
// password. Keep both lists in sync when either side changes.
const DEMO_OTP = process.env.DEMO_OTP || '123456';
const DEMO_RANGES = [
	[9000000001, 9000000001], // Dr. Manoj Swant (doctor)
	[9876000001, 9876000030], // doctors
	[9877000001, 9877000030], // receptionists
	[9878000001, 9878000050], // patients
];

function isDemoMobile(mobile) {
	const n = Number(String(mobile || '').replace(/\D/g, ''));
	if (!n) return false;
	return DEMO_RANGES.some(([from, to]) => n >= from && n <= to);
}

/** Digits only, last 10 — so "+91 98…", "098…" and "98…" compare equal. */
function normalizeMobile(value) {
	const digits = String(value || '').replace(/\D/g, '');
	return digits.length > 10 ? digits.slice(-10) : digits;
}

function generateRefreshToken() {
	return crypto.randomBytes(64).toString('hex');
}

// Create tokens helper
function createAccessToken(payload) {
	return jwt.sign(payload, process.env.JWT_SECRET_KEY, {
		expiresIn: process.env.JWT_ACCESS_TTL || '15m',
	});
}

/**
 * Looks the mobile up in the doctor / patient / receptionist tables and returns
 * { roleId, uid } — or null when the number holds no account at all.
 *
 * The client's `requestedRole` is only a preference, never the answer: one
 * mobile can legitimately be both a doctor and a patient, so the caller picks
 * which of their OWN roles to use, but can never claim one they do not hold.
 * Previously the role arrived in the request body and was written to the
 * session as-is, so posting role:"doctor" with a receptionist's number was
 * enough to get a doctor session.
 */
async function resolveAccountRole(mobile, requestedRole) {
	const wanted = ROLE_ID_BY_NAME[String(requestedRole || '').trim().toLowerCase()] || null;

	const firstRow = (result) => (result.recordset && result.recordset[0]) || null;
	const idOf = (row, ...keys) => {
		for (const key of keys) {
			const value = row && row[key];
			if (value !== undefined && value !== null && Number(value) > 0) return Number(value);
		}
		return null;
	};

	const lookups = {
		[ROLE.DOCTOR]: async () => {
			const row = firstRow(await db.request()
				.input('operation', 'doctor_mobile_exist')
				.input('mobile', mobile)
				.execute('sp_doctor_login'));
			return row ? { roleId: ROLE.DOCTOR, uid: idOf(row, 'doctor_id', 'id') } : null;
		},
		[ROLE.PATIENT]: async () => {
			const row = firstRow(await db.request()
				.input('operation', 'patient_mobile_exist')
				.input('mobile_no', mobile)
				.execute('sp_patients'));
			return row ? { roleId: ROLE.PATIENT, uid: idOf(row, 'patient_id', 'id') } : null;
		},
		[ROLE.RECEPTIONIST]: async () => {
			const row = firstRow(await db.request()
				.input('operation', 'check_phone_receptionist')
				.input('mobile_no', mobile)
				.execute('sp_receptionist'));
			return row ? { roleId: ROLE.RECEPTIONIST, uid: idOf(row, 'recep_id', 'id') } : null;
		},
	};

	// "Doctor" on the role picker covers clinic staff too, so a doctor login
	// that finds no doctor falls through to receptionist — that is how a
	// receptionist signs in today. Patient never falls through to staff.
	const order = wanted === ROLE.PATIENT
		? [ROLE.PATIENT]
		: wanted === ROLE.RECEPTIONIST
			? [ROLE.RECEPTIONIST, ROLE.DOCTOR]
			: [ROLE.DOCTOR, ROLE.RECEPTIONIST];

	for (const roleId of order) {
		const found = await lookups[roleId]();
		if (found) return found;
	}
	return null;
}

function createRefreshTokenPayload(mobile) {
	const token = generateRefreshToken();
	return token;
}

router.post('/Createlogin', authLimiter, async (req, res) => {
	try {
		const {
			mobile,
			deviceDetails,
			role,
			loginTicket,
			otp
		} = req.body;

		if (!mobile) return res.status(400).json({
			error: 'Mobile number required'
		});
		if (!role) return res.status(400).json({
			error: 'Role required'
		});

		const normalizedMobile = normalizeMobile(mobile);

		// ── Proof of OTP ────────────────────────────────────────────────
		// Issuing tokens for any mobile that was merely POSTed here meant a
		// phone number was the only thing standing between an attacker and a
		// full session. /verify-otp now hands out a signed, short-lived ticket
		// and this route refuses to mint a session without one.
		if (isDemoMobile(normalizedMobile)) {
			if (String(otp || '') !== DEMO_OTP) {
				return res.status(401).json({ error: 'Invalid OTP' });
			}
		} else {
			if (!loginTicket) {
				return res.status(401).json({ error: 'OTP verification required' });
			}
			try {
				const ticket = jwt.verify(loginTicket, process.env.JWT_SECRET_KEY);
				if (ticket.purpose !== 'login' || normalizeMobile(ticket.mobile) !== normalizedMobile) {
					return res.status(401).json({ error: 'OTP verification required' });
				}
			} catch (err) {
				log.error('Createlogin: bad login ticket for ' + normalizedMobile + ' (' + err.message + ')');
				return res.status(401).json({ error: 'OTP verification expired. Please try again.' });
			}
		}

		// ── Role comes from the database, not from the request body ──────
		const account = await resolveAccountRole(normalizedMobile, role);
		if (!account) {
			return res.status(404).json({
				error: 'No account found for this mobile number'
			});
		}
		const roleId = account.roleId;
		const roleName = ROLE_NAME_BY_ID[roleId];

		await db.request()
			.input('operation', 'revoke')
			.input('user_mobile', mobile)
			.execute('ManageRefreshToken');

		const refreshToken = createRefreshTokenPayload(mobile);
		const expiresAt = new Date(Date.now() + REFRESH_TOKEN_TTL_MS);

		await db.request()
			.input('operation', 'insert')
			.input('user_mobile', mobile)
			.input('refresh_token', refreshToken)
			.input('device_info', deviceDetails)
			.input('expires_at', expiresAt)
			.input('role', roleName)
			.execute('ManageRefreshToken');

		// role_id travels inside the token so every route can authorize on it
		// instead of trusting whatever the caller sends.
		const accessToken = createAccessToken({
			mobile,
			role_id: roleId,
			uid: account.uid,
		});

		return res.json({
			accessToken,
			refreshToken,
			roleId,
			mobile
		});
	} catch (err) {
		log.error('Createlogin error: ' + err.message);
		return res.status(500).json({
			error: err.message
		});
	}
});


router.post('/refreshAccessToken', authLimiter, async (req, res) => {
	log.debug('inside the refreshAccessToken route');
	try {
		const {
			refreshToken
		} = req.body;

		if (!refreshToken)
			return res.status(400).json({
				error: 'Refresh token required'
			});

		const result = await db.request()
			.input('operation', 'get')
			.input('refresh_token', refreshToken)
			.execute('ManageRefreshToken');

		const rows = result.recordset || [];


		if (!rows.length)
			return res.status(403).json({
				error: 'Invalid refresh token'
			});

		const row = rows[0];
		const mobile = row.user_mobile;

		// Columns only (never the token values) — tells us at a glance whether
		// ManageRefreshToken's `get` actually projects role_id.
		log.debug('refreshAccessToken row columns: ' + Object.keys(row).join(','));

		// The SP does not always project role_id on `get` — that is why
		// /Createlogin already needed a fallback. Returning that raw value
		// handed the client roleId null → the app stored 0, which turned a
		// receptionist session into a doctor-looking one and wiped the session
		// on the next launch. Resolve it defensively instead, and refuse to
		// answer rather than reply with an unknown role.
		const roleId = resolveRoleId(row.role_id, row.role);
		if (!roleId) {
			log.error(
				'refreshAccessToken: cannot resolve role for ' + mobile +
				' (role_id=' + row.role_id + ' role=' + row.role + ')'
			);
			return res.status(500).json({
				error: 'Could not resolve account role. Please try again.'
			});
		}

		// revoke old
		await db.request()
			.input('operation', 'revoke')
			.input('user_mobile', mobile)
			.execute('ManageRefreshToken');

		// create new — same role as the stored session, re-resolving only the
		// account id so the token keeps carrying who this is.
		const account = await resolveAccountRole(normalizeMobile(mobile), ROLE_NAME_BY_ID[roleId]);
		const newAccessToken = createAccessToken({
			mobile,
			role_id: roleId,
			uid: account && account.roleId === roleId ? account.uid : null,
		});

		const newRefreshToken = createRefreshTokenPayload(mobile);

		const newExpiresAt = new Date(Date.now() + REFRESH_TOKEN_TTL_MS);
		await db.request()
			.input('operation', 'insert')
			.input('user_mobile', mobile)
			.input('refresh_token', newRefreshToken)
			.input('device_info', row.device_info)
			.input('expires_at', newExpiresAt)
			.input('role', ROLE_NAME_BY_ID[roleId])

			.execute('ManageRefreshToken');



		return res.json({
			accessToken: newAccessToken,
			refreshToken: newRefreshToken,
			roleId,
			mobile
		});

	} catch (err) {
		return res.status(500).json({
			error: err.message
		});
	}
});


router.post('/saveFirebaseToken', async (req, res) => {
	log.debug('inside the saveFirebaseToken route');
	try {
		const {
			role,
			firebaseToken,
			mobile
		} = req.body;

		// Validate required fields
		if (!role || !firebaseToken || !mobile) {
			return res.status(400).json({
				error: 'role, mobile and firebaseToken are required'
			});
		}


		// Save firebase token via SP
		await db.request()
			.input('operation', 'saveFirebaseToken')
			.input('mobile', mobile)
			.input('token', firebaseToken)
			.input('role', role)
			.execute('sp_doctor_login');

		return res.status(200).json({
			success: true,
			message: `Firebase token saved for ${role}`,
			mobile,
			role,
		});

	} catch (err) {
		log.error('saveFirebaseToken error: ' + err.message);
		return res.status(500).json({
			error: err.message
		});
	}
});

router.post('/logout', async (req, res) => {
	try {
		const {
			refreshToken
		} = req.body;

		if (!refreshToken) {
			return res.status(400).json({
				success: false,
				message: 'Refresh token required'
			});
		}

		const result = await db.request()
			.input('operation', 'revoke')
			.input('refresh_token', refreshToken)
			.execute('ManageRefreshToken');

		const revokedCount = result.recordset[0]?.revoked_count || 0;

		if (revokedCount > 0) {
			return res.json({
				success: true,
				message: 'Logout successful'
			});
		} else {
			return res.status(400).json({
				success: false,
				message: 'Invalid refresh token or already revoked'
			});
		}

	} catch (err) {
		log.error('logout error: ' + err.message);
		return res.status(500).json({
			success: false,
			message: 'Logout failed'
		});
	}
});


// Used by receptionist login to load the linked doctor's full profile
router.get('/getDoctorProfileByClinic', lookupLimiter, async (req, res) => {
	try {
		const { clinic_id, doctor_id } = req.query;

		if (doctor_id && parseInt(doctor_id) > 0 && clinic_id) {
			const r = await db.request()
				.input('doctor_id', parseInt(doctor_id))
				.input('clinic_id', clinic_id)
				.query('SELECT * FROM dbo.doctor_login_vw WHERE doctor_id = @doctor_id AND clinic_id = @clinic_id AND doc_active_status = 0');
			return res.json(r.recordset);
		}

		if (doctor_id && parseInt(doctor_id) > 0) {
			const r = await db.request()
				.input('doctor_id', parseInt(doctor_id))
				.query('SELECT * FROM dbo.doctor_login_vw WHERE doctor_id = @doctor_id AND doc_active_status = 0');
			return res.json(r.recordset);
		}

		if (clinic_id) {
			const r = await db.request()
				.input('clinic_id', clinic_id)
				.query('SELECT * FROM dbo.doctor_login_vw WHERE clinic_id = @clinic_id AND doc_active_status = 0');
			return res.json(r.recordset);
		}

		res.json([]);
	} catch (err) {
		res.status(500).json({ error: err.message });
	}
});

router.get('/checkPhoneDoctor', lookupLimiter, async (req, res) => {
	try {
		const {
			mobile
		} = req.query;

		const result = await db.request()
			.input('operation', 'check_phone_doctor')
			.input('mobile', mobile)
			.execute('sp_doctor_login');

		res.json(result.recordset);
	} catch (err) {
		res.status(500).json({
			error: err.message
		});
	}
});

router.get('/checkPhonePatient', lookupLimiter, async (req, res) => {
	try {
		const mobile_no = req.query.mobile_no ?? req.query.mobileNo;

		const result = await db.request()
			.input('operation', 'check_phone_patient')
			.input('mobile_no', mobile_no)
			.execute('sp_patients');

		res.json(result.recordset);
	} catch (err) {
		res.status(500).json({
			error: err.message
		});
	}
});


router.get('/mobileExistDoctor', lookupLimiter, async (req, res) => {
	try {
		const {
			mobile
		} = req.query;
		const result = await db.request()
			.input('operation', 'doctor_mobile_exist')
			.input('mobile', mobile)
			.execute('sp_doctor_login');
		res.json(result.recordset);
	} catch (err) {
		res.status(500).json({
			error: err.message
		});
	}
});

router.get('/mobileExistPatient', lookupLimiter, async (req, res) => {
	try {
		let mobile_no = req.query.mobile_no ?? req.query.mobileNo;
		if (!mobile_no) {
			return res.status(400).json({
				error: 'mobile_no is required'
			});
		}

		mobile_no = mobile_no.toString().trim().replace(/\D/g, '');
		if (mobile_no.startsWith('91') && mobile_no.length === 12) {
			mobile_no = mobile_no.slice(2);
		}

		if (!/^[6-9]\d{9}$/.test(mobile_no)) {
			return res.status(400).json({
				error: 'Invalid mobile number'
			});
		}

		const result = await db.request()
			.input('operation', 'patient_mobile_exist')
			.input('mobile_no', mobile_no)
			.execute('sp_patients');
		res.json(result.recordset);
	} catch (err) {
		res.status(500).json({
			error: err.message
		});
	}
});


router.get('/checkPhoneReceptionist', lookupLimiter, async (req, res) => {
	try {
		let mobile_no = req.query.mobile_no ?? req.query.mobileNo;
		if (!mobile_no) return res.status(400).json({ error: 'mobile_no is required' });
		mobile_no = mobile_no.toString().trim().replace(/\D/g, '');
		if (mobile_no.startsWith('91') && mobile_no.length === 12) mobile_no = mobile_no.slice(2);

		const result = await db.request()
			.input('operation', 'check_phone_receptionist')
			.input('mobile_no', mobile_no)
			.execute('sp_receptionist');

		console.log('[ReceptionistDebug] checkPhoneReceptionist result:', JSON.stringify(result.recordset?.[0]));
		res.json(result.recordset);
	} catch (err) {
		res.status(500).json({ error: err.message });
	}
});

router.get('/mobileExistReceptionist', lookupLimiter, async (req, res) => {
	try {
		let mobile_no = req.query.mobile_no ?? req.query.mobileNo;
		if (!mobile_no) {
			return res.status(400).json({ error: 'mobile_no is required' });
		}

		mobile_no = mobile_no.toString().trim().replace(/\D/g, '');
		if (mobile_no.startsWith('91') && mobile_no.length === 12) {
			mobile_no = mobile_no.slice(2);
		}

		if (!/^[6-9]\d{9}$/.test(mobile_no)) {
			return res.status(400).json({ error: 'Invalid mobile number' });
		}

		const result = await db.request()
			.input('operation', 'check_phone_receptionist')
			.input('mobile_no', mobile_no)
			.execute('sp_receptionist');
		res.json(result.recordset);
	} catch (err) {
		res.status(500).json({ error: err.message });
	}
});


router.post('/doctor', uploadHandler(upload.fields([{
	name: "doctor_image",
	maxCount: 1
},
{
	// Flutter sends the gallery under "clinic_images" (plural, up to 5).
	// Must match the field name the client uses or multer rejects the whole
	// upload with LIMIT_UNEXPECTED_FILE before the handler ever runs.
	name: "clinic_images",
	maxCount: 5
}
])), async (req, res) => {
	try {

		// Magic-byte check: confirm the bytes really are JPEG/PNG/WebP, not a
		// polyglot file with a spoofed mime. 415 + temp cleanup on mismatch.
		if (!(await verifyImageFiles(req, res))) return;

		const {
			doctor_id,
			name,
			email,
			mobile,
			qualification,
			license_no,
			experience,
			specialization,
			role_id,
			clinic_name,
			clinic_address,
			latitude,
			longitude,
			consultation_fee,
			website_name,
			clinic_email,
			clinic_contact,
			gender_id
		} = req.body;

		const operation = doctor_id && doctor_id > 0 ? "Update" : "Insert";

		// Registration must stay open — a new doctor has no token yet. Editing
		// an existing record must not: without this, any signed-in user (a
		// receptionist, a patient) could POST a doctor_id and rewrite that
		// doctor's profile. Updates therefore require a doctor's own token.
		if (operation === "Update") {
			// auth() is synchronous: it either calls next() or answers 401 itself.
			let authenticated = false;
			auth(req, res, () => { authenticated = true; });
			if (!authenticated) return;

			if (Number(req.user.role_id) !== ROLE.DOCTOR) {
				return res.status(403).json({
					error: 'Only the doctor can update this profile.'
				});
			}
			if (req.user.uid && Number(req.user.uid) !== Number(doctor_id)) {
				return res.status(403).json({
					error: 'You can only update your own profile.'
				});
			}
		}

		// =========================
		// 1️⃣ INSERT / UPDATE
		// =========================
		const request = db.request();

		request.input("operation", operation);

		request.input("doctor_id", doctor_id || null);
		request.input("name", name);
		request.input("email", email);
		request.input("mobile", mobile);
		request.input("qualification", qualification);
		request.input("license_no", license_no);
		request.input("experience", experience);
		request.input("specialization", specialization);
		request.input("role_id", role_id);
		request.input("gender_id", gender_id);

		request.input("clinic_name", clinic_name);
		request.input("clinic_address", clinic_address);
		request.input("latitude", latitude);
		request.input("longitude", longitude);
		request.input("consultation_fee", consultation_fee);
		request.input("website_name", website_name);
		request.input("clinic_email", clinic_email);
		request.input("clinic_contact", clinic_contact);

		const result = await request.execute("sp_doctor_login");

		const row = result.recordset?.[0];
		const returnedDoctorId = row?.doctor_id;
		const returnedClinicId = row?.clinic_id;

		if (!returnedDoctorId) {
			// row.success === 0 means the SP rejected it (duplicate mobile, etc.)
			// — surface its message as a 400 so the app can show it to the user.
			const isRejection = row?.success === 0;
			return res.status(isRejection ? 400 : 500).json({
				success: false,
				message: row?.message || 'Failed to save doctor'
			});
		}

		let doctorImageUrl = null;
		let clinicImageUrls = [];

		// =========================
		// 2️⃣ DOCTOR IMAGE
		// =========================
		if (req.files?.doctor_image) {

			const file = req.files.doctor_image[0];

			const dir = path.join(__dirname, "..", "uploads", "doctor_images", returnedDoctorId.toString());
			await fs.ensureDir(dir);

			const dest = path.join(dir, file.filename);
			await fs.move(file.path, dest, {
				overwrite: true
			});


			doctorImageUrl = `${PUBLIC_BASE_URL}/uploads/doctor_images/${returnedDoctorId}/${file.filename}`;

			await db.request()
				.input("operation", "uploadDoctorImg")
				.input("doctor_id", returnedDoctorId)
				.input("image", doctorImageUrl)
				.execute("sp_doctor_login");
		}

		// =========================
		// 3️⃣ CLINIC IMAGE
		// =========================
		if (req.files?.clinic_images?.length) {

			const dir = path.join(__dirname, "..", "uploads", "clinic_images", returnedClinicId.toString());
			await fs.ensureDir(dir);

			// Continue sort_order after the gallery images that already exist for
			// this clinic, so newly added photos append rather than collide.
			const existingGallery = await db.request()
				.input("operation", "fetchClinicGallery")
				.input("clinic_id", returnedClinicId)
				.execute("sp_doctor_login");
			let sortOrder = existingGallery.recordset?.length || 0;

			for (const file of req.files.clinic_images) {
				const dest = path.join(dir, file.filename);
				await fs.move(file.path, dest, {
					overwrite: true
				});

				const url = `${PUBLIC_BASE_URL}/uploads/clinic_images/${returnedClinicId}/${file.filename}`;
				clinicImageUrls.push(url);

				// uploadClinicGallery INSERTs into dbo.clinic_images (the gallery the
				// app reads). uploadClinicImg only overwrote clinics.image_url (single).
				await db.request()
					.input("operation", "uploadClinicGallery")
					.input("clinic_id", returnedClinicId)
					.input("image_url", url)
					.input("sort_order", sortOrder)
					.execute("sp_doctor_login");
				sortOrder++;
			}
		}

		// A freshly-registered doctor has never been through /send-otp +
		// /verify-otp, so /Createlogin would 401 them for lacking a loginTicket.
		// This request itself is the proof of ownership here (new row, caller's
		// own mobile) — mint the same ticket /verify-otp would, so the app can
		// sign the doctor in immediately after registration without a second
		// OTP round trip.
		let loginTicket;
		if (operation === "Insert" && mobile) {
			loginTicket = jwt.sign(
				{ mobile: normalizeMobile(mobile), purpose: 'login' },
				process.env.JWT_SECRET_KEY,
				{ expiresIn: LOGIN_TICKET_TTL }
			);
		}

		return res.json({
			success: true,
			doctor_id: returnedDoctorId,
			clinic_id: returnedClinicId,
			doctor_image: doctorImageUrl,
			clinic_images: clinicImageUrls,
			clinic_image: clinicImageUrls[0] || null,
			message: operation === "Update" ? "Updated" : "Created",
			...(loginTicket ? { loginTicket } : {})
		});

	} catch (err) {
		log.error('doctor upsert error: ' + err.message);
		// Drop any orphaned temp file the upload left behind so /uploads/temp
		// doesn't grow forever when the SP / move step fails mid-request.
		await cleanupFiles(req).catch(() => { });
		res.status(500).json({
			success: false,
			error: err.message
		});
	}
});

router.post('/patient', uploadHandler(upload.single("image")), async (req, res) => {
	try {

		// Magic-byte check: confirm bytes match the claimed image format.
		if (!(await verifyImageFiles(req, res))) return;

		const {
			patient_id,
			name,
			mobile_no,
			email,
			address,
			gender_id,
			DOB,
			blood_group_id,
			weight
		} = req.body;

		const operation = patient_id && patient_id > 0 ? "Update" : "Insert";

		// Optional fields arrive as "" over multipart/form-data when left blank —
		// SQL Server can't implicitly convert "" to decimal/int, so null them out.
		const clean = (v) => (v === "" || v === undefined ? null : v);

		const request = db.request();

		request.input("operation", operation);
		request.input("patient_id", patient_id || null);
		request.input("name", name);
		request.input("mobile_no", mobile_no);
		request.input("email", clean(email));
		request.input("Address", clean(address));
		request.input("gender_id", gender_id);
		request.input("DOB", DOB);
		request.input("blood_group_id", clean(blood_group_id));
		request.input("weight", clean(weight));

		const result = await request.execute("sp_patients");

		const returnedPatientId = result.recordset?.[0]?.patient_id;

		if (!returnedPatientId) {
			return res.status(500).json({
				success: false,
				message: "Patient failed"
			});
		}

		let imageUrl = null;

		// =========================
		// IMAGE
		// =========================
		if (req.file) {

			const dir = path.join(__dirname, "..", "uploads", "patient_images", returnedPatientId.toString());
			await fs.ensureDir(dir);

			const dest = path.join(dir, req.file.filename);
			await fs.move(req.file.path, dest, {
				overwrite: true
			});

			imageUrl = `${PUBLIC_BASE_URL}/uploads/patient_images/${returnedPatientId}/${req.file.filename}`;

			await db.request()
				.input("operation", "uploadPatientImg")
				.input("patient_id", returnedPatientId)
				.input("img_url", imageUrl)
				.execute("sp_patients");
		}

		return res.json({
			success: true,
			patient_id: returnedPatientId,
			image_url: imageUrl,
			message: operation === "Update" ? "Updated" : "Created"
		});

	} catch (err) {
		await cleanupFiles(req).catch(() => { });
		res.status(500).json({
			success: false,
			error: err.message
		});
	}
});


router.post('/send-otp', async (req, res) => {
	try {
		const body = req.body || {};
		let mobile_no = body.mobile_no ?? body.mobileNo ?? body.mobile;

		if (!mobile_no) {
			return res.status(400).json({
				status: 0,
				message: 'Mobile number required'
			});
		}

		if (typeof mobile_no !== 'string') {
			mobile_no = mobile_no.toString();
		}

		let normalized = mobile_no.trim().replace(/\D/g, '');

		if (normalized.startsWith('91') && normalized.length > 10) {
			normalized = normalized.slice(normalized.length - 10);
		}

		if (normalized.startsWith('0')) {
			normalized = normalized.replace(/^0+/, '');
		}

		if (!/^[6-9]\d{9}$/.test(normalized)) {
			return res.status(400).json({
				status: 0,
				message: 'Invalid mobile number'
			});
		}

		const mobile_no_cc = `91${normalized}`;

		if (!process.env.WHATSAPP_API_TOKEN) {
			return res.status(500).json({
				status: 0,
				message: 'WhatsApp API token not configured'
			});
		}

		// ✅ Generate OTP
		const otp = Math.floor(100000 + Math.random() * 900000).toString();

		// ✅ Send WhatsApp OTP
		const waResponse = await axios.post(
			"https://api2.smsala.com/whatsapp/SendOtp",
			{
				PhoneNumber: mobile_no_cc,
				OtpCode: otp,
				ApiToken: process.env.WHATSAPP_API_TOKEN,
				TemplateId: 463
			}
		);

		if (!waResponse.data || waResponse.data.IsSuccess !== true) {
			return res.status(400).json({
				status: 0,
				message: 'Failed to send OTP via WhatsApp',
				response: waResponse.data
			});
		}

		// ✅ Hash OTP
		const otp_hash = await bcrypt.hash(otp, 10);

		// ✅ Save in DB using normalized local number
		const dbResult = await db.request()
			.input('operation', 'send_otp')
			.input('mobile_no', normalized)
			.input('otp_hash', otp_hash)
			.execute('sp_otp');

		if (dbResult.recordset[0].status === 0) {
			return res.status(400).json(dbResult.recordset[0]);
		}

		res.json({
			status: 1,
			message: 'OTP sent successfully',
			otp: otp // ⚠️ remove in production
		});

	} catch (err) {
		res.status(500).json({
			status: 0,
			message: 'Server error',
			error: err?.response?.data || err.message
		});
	}
});
router.post('/verify-otp', async (req, res) => {
	const { mobile_no, otp } = req.body;

	try {
		const result = await db.request()
			.input('operation', 'verify_otp')
			.input('mobile_no', mobile_no)
			.execute('sp_otp');

		const data = result.recordset[0];

		if (data.status === 0) {
			return res.status(400).json(data);
		}

		const isMatch = await bcrypt.compare(otp, data.otp_hash);

		if (!isMatch) {
			// increase attempt
			await db.request()
				.input('operation', 'update_attempt')
				.input('mobile_no', mobile_no)
				.execute('sp_otp');

			return res.status(400).json({
				status: 0,
				message: 'Invalid OTP'
			});
		}

		// mark verified
		await db.request()
			.input('operation', 'mark_verified')
			.input('mobile_no', mobile_no)
			.execute('sp_otp');

		// Proof that this mobile passed OTP, to be handed straight back to
		// /Createlogin. Without it that route would keep issuing sessions to
		// anyone who knows a phone number.
		const loginTicket = jwt.sign(
			{ mobile: normalizeMobile(mobile_no), purpose: 'login' },
			process.env.JWT_SECRET_KEY,
			{ expiresIn: LOGIN_TICKET_TTL }
		);

		res.json({
			status: 1,
			message: 'OTP verified successfully',
			loginTicket
		});

	} catch (err) {
		console.error(err);
		res.status(500).json({ error: 'Server error' });
	}
});


router.get('/privacy', (req, res) => {
	res.sendFile(path.join(__dirname, 'privacy.html'));
});


router.get('/terms', (req, res) => {
	res.sendFile(path.join(__dirname, 'terms.html'));
});


router.get('/delete-account', (req, res) => {
	res.sendFile(path.join(__dirname, 'delete-account.html'));
});



// ════════════════════════════════════════════════════════════════════
//  DOCTOR CLINICS
// ════════════════════════════════════════════════════════════════════

router.get('/getClinicsForDoctor/:doctor_id', async (req, res) => {
	try {
		const { doctor_id } = req.params;
		if (!doctor_id) return res.status(400).json({ error: 'doctor_id required' });
		const result = await db.request()
			.input('operation', 'GetDoctorClinics')
			.input('doctor_id', parseInt(doctor_id))
			.execute('sp_doctor_login');
		return res.json(result.recordset);
	} catch (err) {
		log.error('getClinicsForDoctor error: ' + err.message);
		return res.status(500).json({ error: err.message });
	}
});

router.post('/addClinic', auth, authorize(ROLE.DOCTOR), uploadHandler(upload.fields([{ name: 'clinic_images', maxCount: 5 }])), async (req, res) => {
	try {
		if (!(await verifyImageFiles(req, res))) return;

		const {
			doctor_id, clinic_name, clinic_address,
			latitude, longitude, consultation_fee,
			website_name, clinic_email, clinic_contact,
		} = req.body;

		if (!doctor_id) return res.status(400).json({ success: false, error: 'doctor_id required' });

		const result = await db.request()
			.input('operation', 'AddClinic')
			.input('doctor_id', parseInt(doctor_id))
			.input('clinic_name', clinic_name || null)
			.input('clinic_address', clinic_address || null)
			.input('latitude', latitude ? parseFloat(latitude) : null)
			.input('longitude', longitude ? parseFloat(longitude) : null)
			.input('consultation_fee', consultation_fee ? parseFloat(consultation_fee) : null)
			.input('website_name', website_name || null)
			.input('clinic_email', clinic_email || null)
			.input('clinic_contact', clinic_contact || null)
			.execute('sp_doctor_login');

		const row = result.recordset?.[0];
		if (!row?.success) {
			return res.status(400).json({ success: false, error: row?.ErrorMessage || 'Failed to add clinic' });
		}

		const returnedClinicId = row.clinic_id;
		const clinicImageUrls = [];

		if (req.files?.clinic_images?.length) {
			const dir = require('path').join(__dirname, '..', 'uploads', 'clinic_images', returnedClinicId);
			await require('fs-extra').ensureDir(dir);

			let sortOrder = 0;
			for (const file of req.files.clinic_images) {
				const dest = require('path').join(dir, file.filename);
				await require('fs-extra').move(file.path, dest, { overwrite: true });
				const url = `${PUBLIC_BASE_URL}/uploads/clinic_images/${returnedClinicId}/${file.filename}`;
				clinicImageUrls.push(url);
				await db.request()
					.input('operation', 'uploadClinicGallery')
					.input('clinic_id', returnedClinicId)
					.input('image_url', url)
					.input('sort_order', sortOrder)
					.execute('sp_doctor_login');
				sortOrder++;
			}
		}

		return res.json({ success: true, clinic_id: returnedClinicId, clinic_images: clinicImageUrls });
	} catch (err) {
		log.error('addClinic error: ' + err.message);
		await cleanupFiles(req).catch(() => { });
		return res.status(500).json({ success: false, error: err.message });
	}
});

router.put('/updateClinic', auth, authorize(ROLE.DOCTOR), uploadHandler(upload.fields([{ name: 'clinic_images', maxCount: 5 }])), async (req, res) => {
	try {
		if (!(await verifyImageFiles(req, res))) return;

		const {
			clinic_id, doctor_id, clinic_name, clinic_address,
			latitude, longitude, consultation_fee,
			website_name, clinic_email, clinic_contact,
		} = req.body;

		if (!clinic_id || !doctor_id) return res.status(400).json({ success: false, error: 'clinic_id and doctor_id required' });

		await db.request()
			.input('operation', 'UpdateClinic')
			.input('clinic_id', clinic_id)
			.input('doctor_id', parseInt(doctor_id))
			.input('clinic_name', clinic_name || null)
			.input('clinic_address', clinic_address || null)
			.input('latitude', latitude ? parseFloat(latitude) : null)
			.input('longitude', longitude ? parseFloat(longitude) : null)
			.input('consultation_fee', consultation_fee ? parseFloat(consultation_fee) : null)
			.input('website_name', website_name || null)
			.input('clinic_email', clinic_email || null)
			.input('clinic_contact', clinic_contact || null)
			.execute('sp_doctor_login');

		if (req.files?.clinic_images?.length) {
			const dir = require('path').join(__dirname, '..', 'uploads', 'clinic_images', clinic_id);
			await require('fs-extra').ensureDir(dir);
			let sortOrder = 0;
			for (const file of req.files.clinic_images) {
				const dest = require('path').join(dir, file.filename);
				await require('fs-extra').move(file.path, dest, { overwrite: true });
				const url = `${PUBLIC_BASE_URL}/uploads/clinic_images/${clinic_id}/${file.filename}`;
				await db.request()
					.input('operation', 'uploadClinicGallery')
					.input('clinic_id', clinic_id)
					.input('image_url', url)
					.input('sort_order', sortOrder)
					.execute('sp_doctor_login');
				sortOrder++;
			}
		}

		return res.json({ success: true, clinic_id });
	} catch (err) {
		log.error('updateClinic error: ' + err.message);
		await cleanupFiles(req).catch(() => { });
		return res.status(500).json({ success: false, error: err.message });
	}
});

router.delete('/deleteClinic/:clinic_id/:doctor_id', auth, authorize(ROLE.DOCTOR), async (req, res) => {
	try {
		const { clinic_id, doctor_id } = req.params;
		if (!clinic_id || !doctor_id) return res.status(400).json({ success: false, error: 'clinic_id and doctor_id required' });

		const result = await db.request()
			.input('operation', 'DeleteClinic')
			.input('clinic_id', clinic_id)
			.input('doctor_id', parseInt(doctor_id))
			.execute('sp_doctor_login');

		const row = result.recordset?.[0];
		if (!row?.success) {
			return res.status(400).json({ success: false, error: row?.message || 'Cannot delete clinic' });
		}
		return res.json({ success: true });
	} catch (err) {
		log.error('deleteClinic error: ' + err.message);
		return res.status(500).json({ success: false, error: err.message });
	}
});

// ════════════════════════════════════════════════════════════════════

//  RECEPTIONIST — CREATE / UPDATE  (same pattern as /patient)
// ════════════════════════════════════════════════════════════════════
router.post('/receptionist', auth, authorize(ROLE.DOCTOR, ROLE.RECEPTIONIST), uploadHandler(upload.single("image")), async (req, res) => {
	try {
		if (!(await verifyImageFiles(req, res))) return;

		// Doctors manage their staff; a receptionist may only edit their own
		// record (the app shows them this screen as "Personal Information").
		if (Number(req.user.role_id) === ROLE.RECEPTIONIST) {
			const ownId = Number(req.user.uid);
			const targetId = Number(req.body.recep_id);
			if (!ownId || !targetId || ownId !== targetId) {
				return res.status(403).json({
					success: false,
					message: 'You can only edit your own profile.'
				});
			}
		}

		const {
			recep_id,
			name,
			mobile_no,
			email,
			address,
			gender_id,
			clinic_id,
			doctor_id,
		} = req.body;
		console.log('[ReceptionistDebug] save receptionist body:', {
			recep_id,
			name,
			mobile_no,
			email,
			gender_id,
			clinic_id,
			doctor_id,
			hasImage: !!req.file,
		});

		const parsedRecepId = recep_id ? parseInt(recep_id) : null;
		const parsedGenderId = gender_id ? parseInt(gender_id) : null;
		const parsedDoctorId = doctor_id ? parseInt(doctor_id) : null;
		const operation = parsedRecepId && parsedRecepId > 0 ? 'Update' : 'Insert';

		const request = db.request();
		request.input('operation', operation);
		request.input('recep_id', parsedRecepId);
		request.input('name', name);
		request.input('mobile_no', mobile_no);
		request.input('email', email || null);
		request.input('Address', address || null);
		request.input('gender_id', parsedGenderId);
		request.input('clinic_id', (clinic_id != null && clinic_id !== undefined && String(clinic_id) !== '0') ? clinic_id : null);
		request.input('doctor_id', parsedDoctorId);

		const result = await request.execute('sp_receptionist');

		const row = result.recordset?.[0];
		console.log('[ReceptionistDebug] save receptionist result:', row);

		if (!row?.success) {
			return res.status(400).json({
				success: false,
				message: row?.message || 'Receptionist operation failed',
			});
		}

		const returnedRecepId = row.recep_id || recep_id;
		let imageUrl = null;

		if (req.file) {
			const dir = path.join(__dirname, '..', 'uploads', 'receptionist_images', returnedRecepId.toString());
			await fs.ensureDir(dir);

			const dest = path.join(dir, req.file.filename);
			await fs.move(req.file.path, dest, { overwrite: true });

			imageUrl = `${PUBLIC_BASE_URL}/uploads/receptionist_images/${returnedRecepId}/${req.file.filename}`;

			await db.request()
				.input('operation', 'uploadReceptionistImg')
				.input('recep_id', returnedRecepId)
				.input('img_url', imageUrl)
				.execute('sp_receptionist');
		}

		return res.json({
			success: true,
			recep_id: returnedRecepId,
			image_url: imageUrl,
			message: operation === 'Update' ? 'Updated' : 'Created',
		});

	} catch (err) {
		console.error('[ReceptionistDebug] save receptionist CATCH full:', {
			message: err?.message,
			code: err?.code,
			number: err?.number,
			state: err?.state,
			class: err?.class,
			lineNumber: err?.lineNumber,
			procName: err?.procName,
			originalMessage: err?.originalError?.message,
			preceding: err?.precedingErrors?.map(e => e.message),
		});
		const errMsg = err?.originalError?.message || err?.message || err?.toString() || 'Unknown error';
		await cleanupFiles(req).catch(() => { });
		res.status(500).json({ success: false, error: errMsg });
	}
});


module.exports = router;
`````

## `backend/routes/middleware/auth.js`

`````js
// middleware/auth.js
const jwt = require('jsonwebtoken');
const dotenv = require('dotenv');
dotenv.config();
const log = require('./logger');

module.exports = function (req, res, next) {
  const authHeader = req.header('Authorization');

  if (!authHeader) {
    return res.status(401).json({ msg: 'No token, access denied' });
  }

  const token = authHeader.split(' ')[1]; // Get only the token part

  if (!token) {
    return res.status(401).json({ msg: 'Invalid token format' });
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET_KEY);
    req.user = decoded; // Attach decoded token data (like user_id)
    next();
  } catch (err) {
    log.error('JWT verification failed: ' + err.message);
    res.status(401).json({ msg: 'Token is not valid' });
  }
};

`````

## `backend/routes/middleware/authorize.js`

`````js
const log = require('./logger');

/**
 * Route guard: allows only the listed role ids. Must run after auth/protect,
 * which puts the decoded token on req.user.
 *
 * Until this existed, role was enforced only by hiding buttons in the app —
 * anyone who could call the API could act as any role. The access token now
 * carries role_id, so the server can decide.
 *
 * Answers 403 (forbidden), never 401: 401 means "your token expired, refresh
 * it", and the app acts on that difference. A role that is simply not allowed
 * must not look like an expired session.
 */
function authorize(...allowedRoleIds) {
	const allowed = allowedRoleIds.flat().map(Number);

	return function authorizeMiddleware(req, res, next) {
		const roleId = Number(req.user && req.user.role_id);

		if (!roleId) {
			// Token predates role_id (issued before this change) — treat as
			// unauthenticated so the client signs in again rather than being
			// told it lacks permission it may actually have.
			log.error('authorize: token without role_id on ' + req.originalUrl);
			return res.status(401).json({ msg: 'Session is out of date. Please sign in again.' });
		}

		if (!allowed.includes(roleId)) {
			log.error('authorize: role ' + roleId + ' blocked on ' + req.originalUrl);
			return res.status(403).json({ msg: 'Your account does not have access to this action.' });
		}

		return next();
	};
}

module.exports = authorize;
`````

## `backend/routes/middleware/errors.js`

`````js
const crypto = require('crypto');
const log = require('./logger');

// Centralised 500 response. Use from every route catch block so internal
// errors (SP names, table names, foreign-key violations, stack traces) never
// reach the client. The full error is logged server-side with a correlation
// ID; the client gets the same ID so a support ticket can be matched to the
// exact log line.
//
//   } catch (err) {
//     return serverError(req, res, err);
//   }
//
// Response shape: { success: false, error: 'Internal Server Error',
//                   correlation_id: '<hex>' }
function serverError(req, res, err, context) {
  const id = req.id || crypto.randomBytes(6).toString('hex');
  const where = context ? ` (${context})` : '';
  log.error(`[${id}] [500] ${req.method} ${req.originalUrl || req.path}${where}: ${err.stack || err.message}`);
  return res.status(500).json({
    success: false,
    error: 'Internal Server Error',
    correlation_id: id,
  });
}

module.exports = { serverError };
`````

## `backend/routes/middleware/logger.js`

`````js
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
`````

## `backend/routes/middleware/protect.js`

`````js
const auth = require('./auth');

module.exports = function protect(req, res, next) {
  auth(req, res, function () {
    if (!req.user) {
      return;  // stop route execution if token invalid/expired
    }
    next();     // continue to Router
  });
};
`````

## `backend/routes/middleware/rateLimit.js`

`````js
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
`````

## `backend/routes/middleware/requestId.js`

`````js
const crypto = require('crypto');

// Tag every request with a short correlation ID. The ID is logged alongside
// any error and returned to the client in the 500 response so support can
// match a user's report back to the exact log line.
module.exports = function requestId(req, res, next) {
  // Honor an upstream correlation header if one is already set (e.g. by
  // an API gateway / load balancer) so traces stitch across hops.
  const fromHeader = req.headers['x-request-id'];
  req.id = (typeof fromHeader === 'string' && fromHeader.length > 0 && fromHeader.length <= 128)
    ? fromHeader
    : crypto.randomBytes(6).toString('hex');
  res.setHeader('X-Request-Id', req.id);
  next();
};
`````

## `backend/routes/middleware/roles.js`

`````js
// Single source of truth for role ids. Both the login routes (which issue
// sessions) and authorize() (which gates routes) read from here, so a role can
// never mean one thing at login and another at request time.
const ROLE = {
	DOCTOR: 1,
	PATIENT: 2,
	RECEPTIONIST: 3,
	// Not a DB row — there's no multi-admin table, just a single shared
	// credential (backend/.env ADMIN_USERNAME/ADMIN_PASSWORD) that mints a
	// token carrying this role_id. See backend/routes/admin.js.
	ADMIN: 4,
};

const ROLE_ID_BY_NAME = {
	doctor: ROLE.DOCTOR,
	patient: ROLE.PATIENT,
	receptionist: ROLE.RECEPTIONIST,
	admin: ROLE.ADMIN,
};

const ROLE_NAME_BY_ID = {
	[ROLE.DOCTOR]: 'doctor',
	[ROLE.PATIENT]: 'patient',
	[ROLE.RECEPTIONIST]: 'receptionist',
	[ROLE.ADMIN]: 'admin',
};

/**
 * Returns 1/2/3, or null when the role cannot be determined.
 * Takes the numeric id first and falls back to the role name, because
 * ManageRefreshToken does not project role_id on every operation.
 */
function resolveRoleId(roleId, roleName) {
	const asNumber = Number(roleId);
	if (ROLE_NAME_BY_ID[asNumber]) return asNumber;
	if (typeof roleName === 'string') {
		const mapped = ROLE_ID_BY_NAME[roleName.trim().toLowerCase()];
		if (mapped) return mapped;
	}
	return null;
}

module.exports = { ROLE, ROLE_ID_BY_NAME, ROLE_NAME_BY_ID, resolveRoleId };
`````

## `backend/routes/middleware/upload.js`

`````js
const path = require('path');
const fs = require('fs-extra');
const fsp = require('fs').promises; // FileHandle API — fs-extra's fs.open returns a numeric fd
const multer = require('multer');

const TEMP_DIR = path.join(__dirname, '..', '..', 'uploads', 'temp');
const MAX_FILE_BYTES = 5 * 1024 * 1024; // 5 MB per file

// Mime allowlist. SVG is intentionally excluded — it's XML and can carry
// inline <script>, which becomes XSS the moment it's served same-origin.
const ALLOWED_MIMES = new Set(['image/jpeg', 'image/png', 'image/webp']);

// Distinguishable from multer's own LIMIT_* errors so the error handler can
// return a 415 instead of a generic 400.
class MulterRejection extends Error {
  constructor(message) {
    super(message);
    this.name = 'MulterRejection';
  }
}

const storage = multer.diskStorage({
  destination: async (req, file, cb) => {
    try {
      await fs.ensureDir(TEMP_DIR);
      cb(null, TEMP_DIR);
    } catch (err) {
      cb(err);
    }
  },
  filename: (req, file, cb) => {
    // Strip anything that isn't a word char, dot, or hyphen — defends against
    // path traversal (../) and shell metacharacters in the saved filename.
    const safe = file.originalname.replace(/[^\w.\-]/g, '_');
    cb(null, `${Date.now()}-${safe}`);
  },
});

function fileFilter(req, file, cb) {
  if (!ALLOWED_MIMES.has(file.mimetype)) {
    return cb(new MulterRejection(`Unsupported file type: ${file.mimetype}`));
  }
  cb(null, true);
}

const upload = multer({
  storage,
  fileFilter,
  limits: {
    fileSize: MAX_FILE_BYTES,
    files: 6, // sanity bound: 1 doctor photo + up to 5 clinic photos
  },
});

// Magic-byte verification. The client-sent mime can lie; reading the first
// bytes off disk is the only way to confirm the file really is what it claims.
// Defends against polyglot files (e.g. PNG header + PHP payload).
async function detectImageMagic(filePath) {
  const fd = await fsp.open(filePath, 'r');
  try {
    const buf = Buffer.alloc(12);
    const { bytesRead } = await fd.read(buf, 0, 12, 0);
    if (bytesRead < 12) return null;

    // JPEG: FF D8 FF
    if (buf[0] === 0xff && buf[1] === 0xd8 && buf[2] === 0xff) return 'image/jpeg';
    // PNG: 89 50 4E 47 0D 0A 1A 0A
    if (
      buf[0] === 0x89 && buf[1] === 0x50 && buf[2] === 0x4e && buf[3] === 0x47 &&
      buf[4] === 0x0d && buf[5] === 0x0a && buf[6] === 0x1a && buf[7] === 0x0a
    ) return 'image/png';
    // WebP: "RIFF" .. .. .. .. "WEBP"
    if (
      buf[0] === 0x52 && buf[1] === 0x49 && buf[2] === 0x46 && buf[3] === 0x46 &&
      buf[8] === 0x57 && buf[9] === 0x45 && buf[10] === 0x42 && buf[11] === 0x50
    ) return 'image/webp';

    return null;
  } finally {
    await fd.close();
  }
}

function collectFiles(req) {
  const out = [];
  if (req.file) out.push(req.file);
  if (req.files) {
    for (const v of Object.values(req.files)) {
      if (Array.isArray(v)) out.push(...v);
      else out.push(v);
    }
  }
  return out;
}

// Delete whatever multer wrote to disk for this request. Called whenever the
// upload is rejected so /uploads/temp doesn't grow unbounded with rejects.
async function cleanupFiles(req) {
  const files = collectFiles(req);
  await Promise.allSettled(files.map((f) => fs.remove(f.path)));
}

// Wraps a multer middleware so its errors come back as clean JSON instead of
// surfacing in the global 500 handler.
function uploadHandler(multerMiddleware) {
  return (req, res, next) => {
    multerMiddleware(req, res, async (err) => {
      if (!err) return next();
      await cleanupFiles(req).catch(() => {});

      if (err.code === 'LIMIT_FILE_SIZE') {
        return res.status(413).json({
          success: false,
          error: 'File too large. Max 5 MB per file.',
        });
      }
      if (err.code === 'LIMIT_FILE_COUNT' || err.code === 'LIMIT_UNEXPECTED_FILE') {
        return res.status(400).json({
          success: false,
          error: 'Too many files or unexpected field.',
        });
      }
      if (err.name === 'MulterRejection') {
        return res.status(415).json({
          success: false,
          error: err.message,
        });
      }
      return next(err);
    });
  };
}

// Post-upload validator. Confirms each accepted file's bytes match an image
// format we trust. On mismatch, deletes the temp file(s) and 415s; route
// handler must check the return value and stop processing on `false`.
async function verifyImageFiles(req, res) {
  const files = collectFiles(req);
  for (const f of files) {
    const realType = await detectImageMagic(f.path);
    if (!realType) {
      await cleanupFiles(req).catch(() => {});
      res.status(415).json({
        success: false,
        error: `Uploaded file is not a valid image: ${f.originalname}`,
      });
      return false;
    }
  }
  return true;
}

module.exports = {
  upload,
  uploadHandler,
  verifyImageFiles,
  cleanupFiles,
};
`````

## `backend/routes/middleware/uploadAuth.js`

`````js
const jwt = require('jsonwebtoken');

// Same JWT validation as the API protect middleware, but with one key
// difference: the token is accepted via the `?token=` query string in
// addition to the Authorization header. <img src> / Image.network can't
// set headers, so query-string fallback is required for any browser /
// webview that renders /uploads/ assets directly.
//
// Failure mode is deliberately a 401 *image* response: clients see a
// broken image, not an HTML 401 page injected mid-render.
module.exports = function uploadAuth(req, res, next) {
  const headerToken = (req.headers.authorization || '').split(' ')[1];
  const queryToken =
    typeof req.query.token === 'string' ? req.query.token : undefined;
  const token = headerToken || queryToken;

  if (!token) {
    return res.status(401).json({ error: 'Auth required for /uploads' });
  }

  try {
    req.user = jwt.verify(token, process.env.JWT_SECRET_KEY);
    return next();
  } catch (err) {
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
};
`````

## `backend/routes/Patient/index.js`

`````js
var express = require('express');
var router = express.Router();
var db = require('../db');
var sql = require('mssql');
const log = require('../middleware/logger');

// DELETE Medicine
router.delete("/deleteFamilyMember/:member_id", async (req, res) => {
  try {
    const { member_id } = req.params;

    if (!member_id) {
      return res.status(400).json({
        success: false,
        message: "member_id is required"
      });
    }

    const request = db.request();
    request.input("operation", "DeleteMember");
    request.input("member_id", sql.Int, parseInt(member_id));

    const result = await request.execute("sp_family_members");

    // The SP returns a message like 'Family Member deleted successfully.' or error message
    const message = result.recordset?.[0]?.Message || "Operation completed";

    // Determine success based on message
    const success = message.toLowerCase().includes("successfully");

    return res.status(success ? 200 : 400).json({
      success,
      message
    });

  } catch (err) {
    log.error('Error in deleteFamily Members API: ' + err.message);

    return res.status(500).json({
      success: false,
      message: err.message || "Failed to delete family Member"
    });
  }
});


// DELETE Favorite Doctor
router.delete("/favoriteDoctor/:patient_id/:doctor_id/:clinic_id", async (req, res) => {
  try {
    const { patient_id, doctor_id, clinic_id } = req.params;

    if (!patient_id || !doctor_id || !clinic_id) {
      return res.status(400).json({
        success: false,
        message: "patient_id, doctor_id, and clinic_id are required"
      });
    }

    const request = db.request();
    request.input("operation", "Delete");
    request.input("patient_id", sql.Int, parseInt(patient_id));
    request.input("doctor_id", sql.Int, parseInt(doctor_id));
    request.input("clinic_id", sql.NVarChar(50), clinic_id);

    const result = await request.execute("sp_favorite_doctors");

    // The SP returns a message like 'Deleted successfully' or error
    const message = result.recordset?.[0]?.message || "Operation completed";

    // Determine success based on message
    const success = message.toLowerCase().includes("successfully");

    return res.status(success ? 200 : 400).json({
      success,
      message
    });

  } catch (err) {
    log.error('Error in deleteFavoriteDoctor API: ' + err.message);

    return res.status(500).json({
      success: false,
      message: err.message || "Failed to delete favorite doctor"
    });
  }
});



// DELETE review
router.delete('/review/:appointment_id/:patient_id', async (req, res) => {
  try {
    const { appointment_id, patient_id } = req.params;

    if (!appointment_id || !patient_id) {
      return res.status(400).json({
        success: false,
        message: "appointment_id and patient_id are required"
      });
    }

    const request = db.request();
    request.input("operation", "Delete");
    request.input("appointment_id", sql.Int, parseInt(appointment_id));
    request.input("patient_id", sql.Int, parseInt(patient_id));

    const result = await request.execute("sp_review");

    const message = result.recordset?.[0]?.message || "Operation completed";
    const success = message.toLowerCase().includes("deleted") || message.toLowerCase().includes("success");

    return res.status(success ? 200 : 400).json({
      success,
      message
    });

  } catch (err) {
    log.error('Error in deleteReview API: ' + err.message);

    return res.status(500).json({
      success: false,
      message: err.message || "Failed to delete review"
    });
  }
});


module.exports = router; 
`````

## `backend/routes/Patient/insert.js`

`````js
var express = require('express');
var router = express.Router();
var db = require('../db'); // go from admin/ to routes/
const sql = require("mssql");
const multer = require("multer");
const log = require('../middleware/logger');
const path = require("path");
const fs = require("fs-extra");

function emitQueueUpdate(req, event, doctor_id, extra = {}) {
  const io = req.app.get('io');
  if (io && doctor_id) io.to('clinic_' + doctor_id).emit('queue_update', { event, doctor_id, ...extra });
}


router.post('/insertFamilyMember', async (req, res) => {
  try {
    const {
      member_id,
      family_id,
      name,
      Gender_id,
      relation_id,
      DOB,
      mobile_no
    } = req.body;

    const clean = (v) => (v === "" ? null : v);

    const operation = member_id && member_id > 0 ? "Update" : "Insert";

    const result = await db.request()
      .input('operation', operation)
      .input('member_id', member_id || null)
      .input('family_id', family_id)
      .input('name', clean(name))
      .input('Gender_id', Gender_id || null)
      .input('relation_id', relation_id || null)
      .input('DOB', DOB || null)
      .input('mobile_no', clean(mobile_no))
      .execute('sp_family_members');

    // ✅ Handle SQL error
    if (result.recordset?.[0]?.ErrorMessage) {
      return res.status(500).json({
        success: false,
        error: result.recordset[0].ErrorMessage
      });
    }

    return res.status(200).json({
      success: true,
      member_id: result.recordset?.[0]?.member_id,
      message:
        operation === "Update"
          ? "Family member updated successfully"
          : "Family member added successfully"
    });

  } catch (error) {
    log.error('Error in /addFamilyMember: ' + error.message);

    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});



router.post('/appointment/book', async (req, res) => {
  const { doctor_id, patient_id, appointment_date, start_time, user_type, slot_id, symptoms, clinic_id } = req.body;

  try {
    // Hard-guard: reject booking if the doctor is on leave that date
    // (defense in depth — patient UI also greys these dates out).
    const blockRes = await db.request()
      .input('operation', 'IS_BLOCKED')
      .input('doctor_id', doctor_id)
      .input('from_date', appointment_date)
      .execute('sp_doctor_leave');

    if (blockRes.recordset?.[0]?.blocked === 1) {
      return res.json({
        success: false,
        message: 'Doctor is on leave on this date. Please pick another date.',
      });
    }

    // Hard-guard: reject booking if the doctor has manually closed today's
    // queue (queueStop → doctor_queue.queue_status = 3). The patient's booking
    // screen only checks the scheduled time window, so closing early (e.g. a
    // 9-12 session stopped at 11:30) wouldn't otherwise block new bookings.
    const queueRes = await db.request()
      .input('doctor_id', doctor_id)
      .input('appointment_date', appointment_date)
      .input('slot_id', slot_id)
      .query(`
        SELECT TOP 1 queue_status, booking_closed FROM doctor_queue
        WHERE doctor_id = @doctor_id AND queue_date = @appointment_date
          AND (@slot_id IS NULL OR slot_id = @slot_id)
        ORDER BY queue_id DESC
      `);

    const queueRow = queueRes.recordset?.[0];
    if (queueRow?.queue_status === 3) {
      return res.json({
        success: false,
        message: 'Doctor has closed the queue for today. Please try again later or pick another date.',
      });
    }
    if (queueRow?.booking_closed === true) {
      return res.json({
        success: false,
        message: 'Doctor has stopped accepting new bookings for today. Please try again later or pick another date.',
      });
    }

    const result = await db.request()
      .input('operation', 'BOOK')
      .input('user_type', user_type)
      .input('doctor_id', doctor_id)
      .input('patient_id', patient_id)
      .input('appointment_date', appointment_date)
      .input('start_time', start_time)
      .input('slot_id', slot_id)
      .input('symptoms', symptoms)
      .input('clinic_id', clinic_id || null)
      .execute('sp_appointment');

    const booked = result.recordset[0].success === 1;
    if (booked) emitQueueUpdate(req, 'booked', doctor_id);
    res.json({ success: booked, message: result.recordset[0].message });

  } catch (error) {
    res.json({
      success: false,
      message: 'Booking failed',
      error: error.message
    });
  }
});

router.post('/appointment/cancel', async (req, res) => {
  const { appointment_id } = req.body;

  try {
    const result = await db.request()
      .input('operation', 'CANCEL')
      .input('appointment_id', appointment_id)
      .execute('sp_appointment');

    res.json({
      success: true,
      message: result.recordset[0].message
    });

  } catch (error) {
    res.json({
      success: false,
      message: 'Cancel failed',
      error: error.message
    });
  }
});

router.post('/appointment/queueStatus', async (req, res) => {
  const { doctor_id, appointment_date } = req.body;

  try {
    const result = await db.request()
      .input('operation', 'QUEUE_STATUS')
      .input('doctor_id', doctor_id)
      .input('appointment_date', appointment_date)
      .execute('sp_appointment');

    res.json({
      success: true,
      message: 'Queue status fetched',
      data: result.recordset
    });

  } catch (error) {
    res.json({
      success: false,
      message: 'Error fetching queue',
      error: error.message
    });
  }
});




router.post('/favoriteDoctor/add', async (req, res) => {
  const { patient_id, doctor_id, clinic_id } = req.body;

  if (!patient_id || !doctor_id) {
    return res.status(400).json({ success: false, message: 'patient_id and doctor_id are required' });
  }

  try {
    const result = await db.request()
      .input('operation', 'Insert')
      .input('patient_id', patient_id)
      .input('doctor_id', doctor_id)
      .input('clinic_id', clinic_id || null)
      .execute('sp_favorite_doctors');

    res.status(200).json({
      success: true,
      message: 'Doctor added to favorites',
      favorite_id: result.recordset?.[0]?.favorite_id
    });

  } catch (error) {
    log.error('Error in /favoriteDoctor/add: ' + error.message);
    res.status(500).json({ success: false, message: error.message });
  }
});




// ADD review
router.post('/review/add', async (req, res) => {
  const { appointment_id, doctor_id, patient_id, rating, comment, reviewed_by_user_id, clinic_id } = req.body;

  if (!appointment_id || !doctor_id || !patient_id || !rating || !reviewed_by_user_id) {
    return res.status(400).json({
      success: false,
      message: 'appointment_id, doctor_id, patient_id, rating, reviewed_by_user_id required'
    });
  }

  try {
    const result = await db.request()
      .input('operation', 'Insert')
      .input('appointment_id', appointment_id)
      .input('doctor_id', doctor_id)
      .input('patient_id', patient_id)
      .input('rating', rating)
      .input('comment', comment || '')
      .input('reviewed_by_user_id', reviewed_by_user_id)
      .input('clinic_id', clinic_id || null)
      .execute('sp_review');

    res.status(200).json({
      success: result.recordset?.[0]?.success ?? true,
      message: result.recordset?.[0]?.message || 'Review added',
      review_id: result.recordset?.[0]?.review_id
    });

  } catch (error) {
    log.error('Error in /review/add: ' + error.message);
    res.status(500).json({ success: false, message: error.message });
  }
});



router.post('/rescheduleAppointment', async (req, res) => {
  const {
    appointment_id,
    doctor_id,
    appointment_date,
    start_time,
    slot_id,
    symptoms
  } = req.body;

  try {
    const result = await db.request()
      .input('operation', 'RESCHEDULE_APPOINTMENT')
      .input('appointment_id', appointment_id)
      .input('doctor_id', doctor_id)
      .input('appointment_date', appointment_date)
      .input('start_time', start_time)
      .input('slot_id', slot_id)
      .input('symptoms', symptoms)

      .execute('sp_appointment');

    emitQueueUpdate(req, 'rescheduled', doctor_id);
    res.status(200).json({
      success: true,
      message: result.recordset[0]?.message || 'Operation completed'
    });

  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error while rescheduling appointment',
      error: error.message
    });
  }
});

router.post('/cancelAppointment/:appointment_id', async (req, res) => {
  const { appointment_id } = req.params;

  try {
    // Look up doctor_id before cancelling so we can notify the room.
    let doctor_id = null;
    try {
      const dr = await db.request()
        .input('appointment_id', appointment_id)
        .query('SELECT TOP 1 doctor_id FROM appointments WHERE appointment_id = @appointment_id');
      doctor_id = dr.recordset?.[0]?.doctor_id ?? null;
    } catch (_) { }

    const result = await db.request()
      .input('operation', 'CANCEL_APPOINTMENT')
      .input('appointment_id', appointment_id)
      .execute('sp_appointment');

    emitQueueUpdate(req, 'patient_cancelled', doctor_id);
    res.status(200).json({
      success: result.recordset[0]?.success || true,
      message: result.recordset[0]?.message || 'Appointment cancelled successfully'
    });

  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error while cancelling appointment',
      error: error.message
    });
  }
});


// PATIENT MARKS THEMSELVES ARRIVED AT CLINIC AFTER BEING SKIPPED —
// doctor's queue screen highlights this patient so they get recalled first.
router.post('/appointment/markArrived', async (req, res) => {
  const { appointment_id, patient_id } = req.body;

  if (!appointment_id || !patient_id) {
    return res.status(400).json({
      success: false,
      message: 'appointment_id and patient_id are required'
    });
  }

  try {
    const result = await db.request()
      .input('appointment_id', appointment_id)
      .input('patient_id', patient_id)
      .query(`
        UPDATE appointments
        SET is_arrived = 1, arrived_at = GETDATE()
        OUTPUT INSERTED.doctor_id
        WHERE appointment_id = @appointment_id
          AND patient_id = @patient_id
          AND LOWER(status) = 'skipped'
      `);

    const doctorId = result.recordset?.[0]?.doctor_id;
    if (!doctorId) {
      return res.status(400).json({
        success: false,
        message: 'Appointment not found or not currently skipped'
      });
    }

    emitQueueUpdate(req, 'patient_arrived', doctorId, { appointment_id });

    res.status(200).json({
      success: true,
      message: 'Doctor has been notified that you are at the clinic'
    });

  } catch (error) {
    log.error('markArrived error: ' + error.message);
    res.status(500).json({
      success: false,
      message: 'Failed to notify the clinic',
      error: error.message
    });
  }
});

router.post('/queueEstimate', async (req, res) => {
  const {
    appointment_id,
    doctor_id,
    clinic_id
  } = req.body;

  try {
    const result = await db.request()
      .input('operation', 'QUEUE_ESTIMATE_SMART')
      .input('appointment_id', appointment_id)
      .input('doctor_id', doctor_id)
      .input('clinic_id', clinic_id || null)
      .execute('sp_appointment');

    res.status(200).json(result.recordset[0]);

  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error while fetching queue estimate',
      error: error.message
    });
  }
});

router.post('/queuePreviewEstimate', async (req, res) => {
  const {
    doctor_id,
    slot_id,
    clinic_id
  } = req.body;

  try {
    const result = await db.request()
      .input('operation', 'QUEUE_PREVIEW_ESTIMATE')
      .input('doctor_id', doctor_id)
      .input('slot_id', slot_id)
      .input('clinic_id', clinic_id || null)
      .execute('sp_appointment');

    const preview = result.recordset[0] || {};

    // Reflect today's manual "stop new bookings" toggle so the patient sees it
    // live on the booking screen, not just as a rejection after tapping Book.
    try {
      const bcRes = await db.request()
        .input('doctor_id', doctor_id)
        .input('slot_id', slot_id)
        .query(`
          SELECT TOP 1 queue_status, booking_closed FROM doctor_queue
          WHERE doctor_id = @doctor_id AND queue_date = CAST(GETDATE() AS DATE)
            AND (@slot_id IS NULL OR slot_id = @slot_id)
          ORDER BY queue_id DESC
        `);
      const row = bcRes.recordset?.[0];
      preview.booking_closed = row ? (row.booking_closed === true || row.queue_status === 3) : false;
    } catch (e) {
      preview.booking_closed = false;
    }

    res.status(200).json(preview);

  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error while fetching queue preview estimate',
      error: error.message
    });
  }
});


router.get('/getPatientAppointments/:family_id', async (req, res) => {
  const { family_id } = req.params;

  try {
    const request = db.request();

    request.input('operation', 'patient_Appointments');
    request.input('family_id', family_id);

    const result = await request.execute('sp_appointment');

    const today = new Date().toISOString().split('T')[0];

    const enrichedAppointments = [];

    for (const item of result.recordset) {
      let queueData = {
        my_queue_number: null,
        patients_ahead: null,
        estimated_arrival_time: null,
        queue_started: null,
        is_my_turn: null
      };

      const appointmentDate = new Date(item.appointment_date).toISOString().split('T')[0];

      if (appointmentDate === today) {
        try {
          const queueResult = await db.request()
            .input('operation', 'QUEUE_ESTIMATE_SMART')
            .input('appointment_id', item.appointment_id)
            .input('doctor_id', item.doctor_id)
            .execute('sp_appointment');

          if (queueResult.recordset.length > 0) {
            const q = queueResult.recordset[0];

            queueData = {
              my_queue_number: q.my_queue_number,
              patients_ahead: q.patients_ahead,
              estimated_arrival_time: q.estimated_arrival_time,
              queue_started: q.queue_started,
              is_my_turn: q.is_my_turn,
              total_queue: q.total_queue,
              current_serving: q.current_serving,
            };
          }
        } catch (err) {
          // ignore queue error per item
        }
      }

      enrichedAppointments.push({
        ...item,
        ...queueData
      });
    }

    res.status(200).json(
      enrichedAppointments
    );

  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Failed to fetch Appointment List',
      error: error.message
    });
  }
});


module.exports = router; 
`````

## `backend/routes/Patient/users.js`

`````js
var express = require('express');
var router = express.Router();
var db = require('../db'); // go from admin/ to routes/
const sql = require("mssql");
const multer = require("multer");
const log = require('../middleware/logger');
const path = require("path");
const fs = require("fs-extra");

// The furthest token the queue has actually reached — the largest
// queue_number N such that every token from 1..N-1 is fully resolved
// (completed, cancelled, or skipped) and token N itself is in_progress,
// completed, cancelled, or skipped. An in_progress token is NOT yet
// resolved, so nothing after it (even a cancelled token) can count as
// "reached" until it finishes. Cancelled/skipped tokens are bypassed as
// soon as they're marked; a skipped patient who is later recalled and
// served does not pull current_serving back to their number.
// This is the SAME rule the doctor's GET_TODAY_QUEUE and the socket
// `fetchCurrentServing` use, so every surface shows one value.
// We compute it here to override sp_appointment's QUEUE_ESTIMATE_SMART, whose
// current_serving lags/miscounts for the patient list.
async function correctCurrentServing(appointment_id) {
  try {
    const res = await db.request()
      .input('appointment_id', sql.Int, parseInt(appointment_id))
      .query(`
        SELECT MAX(a.queue_number) AS current_serving
        FROM   appointments a
        WHERE  a.queue_id = (SELECT queue_id FROM appointments WHERE appointment_id = @appointment_id)
          AND  a.status   IN ('in_progress', 'completed', 'cancelled', 'cancled', 'skipped')
          AND  NOT EXISTS (
                 -- any strictly-earlier token still not resolved (booked or
                 -- itself in_progress) blocks this one from counting
                 SELECT 1 FROM appointments b
                 WHERE  b.queue_id = a.queue_id
                   AND  b.booking_type = 1
                   AND  b.queue_number < a.queue_number
                   AND  b.status NOT IN ('completed', 'cancelled', 'cancled', 'skipped')
               )
      `);
    return res.recordset[0]?.current_serving ?? null;
  } catch (_) {
    return null;
  }
}


router.get('/fetchFamilyMembers/:family_id', async (req, res) => {
  const { family_id } = req.params;

  try {
    const request = db.request();

    request.input('operation', 'AllFamilyMembers');
    request.input('family_id', family_id);

    const result = await request.execute('sp_family_members');

    // ✅ SEND DIRECT LIST
    res.status(200).json(result.recordset);

  } catch (error) {
    res.status(500).json({
      success: 0,
      message: `Failed to fetch Family Members ${error}`
    });
  }
});

router.get('/getDoctorAvailability/:doctor_id/:clinic_id', async (req, res) => {
  const { doctor_id, clinic_id } = req.params;

  try {

    const result = await db.request()
      .input('doctor_id', doctor_id)
      .input('clinic_id', clinic_id || null)
      .input('operation', 'doctor_availability')
      .execute('sp_patients');

    res.status(200).json(result.recordset);

  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error fetching doctor availability',
      error: error.message
    });
  }
});

// Active future leave ranges for a doctor — patient app greys these
// out in the appointment-date calendar.
router.get('/getDoctorLeaveDates/:doctor_id/:clinic_id', async (req, res) => {
  const { doctor_id, clinic_id } = req.params;

  try {
    const result = await db.request()
      .input('operation', 'GET_LEAVE_DATES')
      .input('doctor_id', doctor_id)
      .input('clinic_id', clinic_id)
      .execute('sp_doctor_leave');

    res.status(200).json(result.recordset || []);


  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error fetching doctor leave dates',
      error: error.message,
    });
  }
});

router.get('/getDoctors/:patient_id', async (req, res) => {
  const { patient_id } = req.params;
  try {
    const result = await db.request()
      .input('operation', 'getDoctors')
      .input('patient_id', patient_id)
      .execute('sp_patients');

    const doctors = result.recordset;
    const today = new Date().toISOString().split('T')[0];

    // Parallel leave-check for each doctor (IS_BLOCKED covers today's date)
    const leaveResults = await Promise.all(
      doctors.map(async (d) => {
        if (!d.doctor_id) return { doctor_id: d.doctor_id, blocked: 0 };
        try {
          const r = await db.request()
            .input('operation', 'IS_BLOCKED')
            .input('doctor_id', d.doctor_id)
            .input('from_date', today)
            .execute('sp_doctor_leave');
          return { doctor_id: d.doctor_id, blocked: r.recordset?.[0]?.blocked ?? 0 };
        } catch { return { doctor_id: d.doctor_id, blocked: 0 }; }
      })
    );

    const leaveMap = {};
    leaveResults.forEach(l => { leaveMap[l.doctor_id] = l.blocked; });

    res.status(200).json(
      doctors.map(d => ({ ...d, is_on_leave: leaveMap[d.doctor_id] ?? 0 }))
    );
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error fetching doctor data',
      error: error.message
    });
  }
});

router.get('/patientPrescriptionList/:patient_id', async (req, res) => {
  const { patient_id } = req.params;

  try {

    const result = await db.request()
      .input('patient_id', patient_id)
      .input('operation', 'PatientPrescriptionList')
      .execute('sp_prescription');

    res.status(200).json(result.recordset);

  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error fetching prescription',
      error: error.message
    });
  }
});



router.get('/patientPrescriptionDetails/:prescription_id', async (req, res) => {
  const { prescription_id } = req.params;

  try {

    const result = await db.request()
      .input('prescription_id', prescription_id)
      .input('operation', 'PrescriptionDetail')
      .execute('sp_prescription');

    res.status(200).json(result.recordset);

  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error fetching prescription details',
      error: error.message
    });
  }
});

router.get('/appointment/getBookedSlots/:doctor_id/:clinic_id', async (req, res) => {
  const { doctor_id, clinic_id } = req.params;

  try {
    const result = await db.request()
      .input('operation', 'GET_MONTH_SLOTS')
      .input('doctor_id', doctor_id)
      .input('clinic_id', clinic_id || null)
      .execute('sp_appointment');

    res.status(200).json(result.recordset);

  } catch (error) {
    res.json({
      success: false,
      message: 'Error fetching slots',
      error: error.message
    });
  }
});


router.get('/appointment/getAvailability', async (req, res) => {
  const { doctor_id, appointment_date } = req.body;

  try {
    const result = await db.request()
      .input('operation', 'GET_AVAILABILITY')
      .input('doctor_id', doctor_id)
      .input('appointment_date', appointment_date)
      .execute('sp_appointment');

    res.json({
      success: true,
      message: 'Availability fetched',
      data: result.recordset
    });

  } catch (error) {
    res.json({
      success: false,
      message: 'Error fetching availability',
      error: error.message
    });
  }
});


// GET PATIENT APPOINTMENTS (OPTIMIZED + ADDED NEW QUEUE FIELDS)
router.get('/getPatientAppointments/:family_id', async (req, res) => {
  const { family_id } = req.params;

  try {
    const request = db.request();

    request.input('operation', 'patient_Appointments');
    request.input('family_id', family_id);

    const result = await request.execute('sp_appointment');

    const today = new Date().toISOString().split('T')[0];

    const enrichedAppointments = [];

    for (const item of result.recordset) {
      let queueData = {
        my_queue_number: null,
        patients_ahead: null,
        estimated_arrival_time: null,
        queue_started: null,
        is_my_turn: null
      };

      const appointmentDate = new Date(item.appointment_date).toISOString().split('T')[0];

      if (appointmentDate === today) {
        try {
          const queueResult = await db.request()
            .input('operation', 'QUEUE_ESTIMATE_SMART')
            .input('appointment_id', item.appointment_id)
            .input('doctor_id', item.doctor_id)
            .input('clinic_id', item.clinic_id)
            .execute('sp_appointment');

          if (queueResult.recordset.length > 0) {
            const q = queueResult.recordset[0];

            // Override the SP's current_serving with the correct MAX-token value
            // so the patient's NOW circle matches the doctor screen and never
            // lags after a complete/skip/recall. Fall back to the SP value only
            // if our query returns null.
            const serving = await correctCurrentServing(item.appointment_id);

            queueData = {
              my_queue_number: q.my_queue_number,
              patients_ahead: q.patients_ahead,
              estimated_arrival_time: q.estimated_arrival_time,
              queue_started: q.queue_started,
              is_my_turn: q.is_my_turn,
              total_queue: q?.total_queue ?? null,
              current_serving: serving ?? q?.current_serving ?? null,
              queue_state: q?.status ?? null
            };
          }
        } catch (err) {
          // ignore queue error per item
        }
      }

      if ((item.status || '').toLowerCase() === 'skipped') {
        try {
          const arrivedRes = await db.request()
            .input('appointment_id', item.appointment_id)
            .query('SELECT is_arrived, arrived_at FROM appointments WHERE appointment_id = @appointment_id');
          const a = arrivedRes.recordset?.[0];
          queueData.is_arrived = a?.is_arrived ?? false;
          queueData.arrived_at = a?.arrived_at ?? null;
        } catch (err) {
          // ignore — not critical to the appointment list rendering
        }
      }

      enrichedAppointments.push({
        ...item,
        ...queueData
      });
    }

    res.status(200).json(enrichedAppointments);

  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Failed to fetch Appointment List',
      error: error.message
    });
  }
});



// SP Case 2: all favorites for a patient (doctor_id omitted → SP returns all rows)
router.get('/favoriteDoctors/:patient_id', async (req, res) => {
  try {
    const result = await db.request()
      .input('operation', 'Fetch')
      .input('patient_id', req.params.patient_id)
      .execute('sp_favorite_doctors');
    res.status(200).json(result.recordset || []);
  } catch (error) {
    log.error('Error in get all favorites: ' + error.message);
    res.status(500).json({ success: false, message: error.message });
  }
});

router.get('/favoriteDoctor/:patient_id/:doctor_id/:clinic_id', async (req, res) => {
  try {
    const { patient_id, doctor_id, clinic_id } = req.params;

    const result = await db.request()
      .input('operation', 'Fetch')
      .input('patient_id', patient_id)
      .input('doctor_id', doctor_id)
      .input('clinic_id', clinic_id)
      .execute('sp_favorite_doctors');

    res.status(200).json({
      is_favorite: result.recordset?.[0]?.is_favorite || 0
    });

  } catch (error) {
    log.error('Error in check favorite: ' + error.message);
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});


router.get('/review/appointment/:appointment_id', async (req, res) => {
  try {
    const { appointment_id } = req.params;

    const result = await db.request()
      .input('operation', 'Fetch')
      .input('appointment_id', appointment_id)
      .execute('sp_review');

    res.status(200).json(result.recordset || []);

  } catch (error) {
    log.error('Error in get review by appointment: ' + error.message);
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});

// ── In-app notifications inbox ─────────────────────────────────────────────
// Backed by sp_notification (INSERT/LIST/MARK_READ/MARK_ALL_READ). Doctor-side
// FCM routes call insertNotification(...) to drop rows; the patient app reads
// them here on screen open and on every FCM refresh.
router.get('/getNotifications/:patient_id', async (req, res) => {
  const { patient_id } = req.params;
  try {
    const result = await db.request()
      .input('operation', 'LIST')
      .input('patient_id', patient_id)
      .execute('sp_notification');
    res.status(200).json(result.recordset || []);
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error fetching notifications',
      error: error.message,
    });
  }
});

router.post('/markNotificationRead', async (req, res) => {
  const { notification_id, patient_id } = req.body;
  if (!notification_id || !patient_id) {
    return res.status(400).json({
      success: false,
      message: 'notification_id and patient_id are required',
    });
  }
  try {
    await db.request()
      .input('operation', 'MARK_READ')
      .input('notification_id', notification_id)
      .input('patient_id', patient_id)
      .execute('sp_notification');
    res.status(200).json({ success: true, message: 'Marked as read' });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error marking notification',
      error: error.message,
    });
  }
});

router.post('/markAllNotificationsRead/:patient_id', async (req, res) => {
  const { patient_id } = req.params;
  try {
    await db.request()
      .input('operation', 'MARK_ALL_READ')
      .input('patient_id', patient_id)
      .execute('sp_notification');
    res.status(200).json({ success: true, message: 'All marked as read' });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error marking notifications',
      error: error.message,
    });
  }
});

// GET all reviews for doctor (optional clinic_id param)
router.get('/review/doctor/:doctor_id/:clinic_id', async (req, res) => {
  try {
    const { doctor_id, clinic_id } = req.params;

    const result = await db.request()
      .input('operation', 'Fetch')
      .input('doctor_id', doctor_id)
      .input('clinic_id', clinic_id)
      .execute('sp_review');

    res.status(200).json(result.recordset || []);

  } catch (error) {
    log.error('Error in get doctor reviews: ' + error.message);
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});


module.exports = router; 
`````

## `backend/scripts/add-demo-patient.sql`

`````sql
-- Adds a demo Patient account for App Store / Play Store review.
-- Mobile sits inside the patient demo range used by the OTP bypass
-- (see DEMO_RANGES in routes/login.js and isDemoNumber() in
-- frontend/lib/core/demo_accounts.dart): 9878000001-9878000050.
--
-- Login: 9878000001 + demo OTP 123456 — no SMS is sent for this number.
--
-- Review before running. Safe to re-run: it checks for an existing row
-- with this mobile and rolls back instead of inserting a duplicate.

SET XACT_ABORT ON;
BEGIN TRAN;

DECLARE @mobile NVARCHAR(20) = '9878000001';
DECLARE @name   NVARCHAR(100) = 'Demo Patient';

IF EXISTS (SELECT 1 FROM Patients WHERE mobile_no = @mobile)
BEGIN
  RAISERROR('Mobile already exists in Patients', 16, 1);
  ROLLBACK TRAN;
  RETURN;
END

INSERT INTO Patients
  (name, mobile_no, email, Address, gender_id, DOB, blood_group_id, weight,
   role_id, active_status, token, img_url)
VALUES
  (@name, @mobile, NULL, NULL, NULL, NULL, NULL, NULL,
   2 /* ROLE.PATIENT, see routes/middleware/roles.js */, 1, NULL, NULL);

COMMIT TRAN;

SELECT patient_id, name, mobile_no FROM Patients WHERE mobile_no = @mobile;
`````

## `backend/scripts/add-demo-receptionist.sql`

`````sql
-- Adds a demo Receptionist account for App Store / Play Store review,
-- attached to Dr. Manoj Swant's clinic (see add-manoj-swant-kudal.sql) so a
-- reviewer logging in as this receptionist sees a real clinic queue.
--
-- Mobile sits inside the receptionist demo range used by the OTP bypass
-- (see DEMO_RANGES in routes/login.js and isDemoNumber() in
-- frontend/lib/core/demo_accounts.dart): 9877000001-9877000030.
--
-- Login: 9877000001 + demo OTP 123456 — no SMS is sent for this number.
--
-- Run add-manoj-swant-kudal.sql FIRST — this script looks up his doctor_id
-- by mobile 9000000001 and fails loudly if that row doesn't exist yet.
--
-- Review before running. Safe to re-run: it checks for an existing row
-- with this mobile and rolls back instead of inserting a duplicate.

SET XACT_ABORT ON;
BEGIN TRAN;

DECLARE @mobile       NVARCHAR(20) = '9877000001';
DECLARE @name         NVARCHAR(100) = 'Demo Receptionist';
DECLARE @doctor_mobile NVARCHAR(20) = '9000000001';
DECLARE @clinic_id    NVARCHAR(50) = 'CL060';
DECLARE @doctor_id    INT;

SELECT @doctor_id = doctor_id FROM doctor_login WHERE mobile = @doctor_mobile;

IF @doctor_id IS NULL
BEGIN
  RAISERROR('Dr. Manoj Swant (mobile 9000000001) not found — run add-manoj-swant-kudal.sql first', 16, 1);
  ROLLBACK TRAN;
  RETURN;
END

IF EXISTS (SELECT 1 FROM receptionist WHERE mobile_no = @mobile)
BEGIN
  RAISERROR('Mobile already exists in receptionist', 16, 1);
  ROLLBACK TRAN;
  RETURN;
END

INSERT INTO receptionist
  (name, mobile_no, email, Address, gender_id, active_status, token, img_url,
   clinic_id, created_at, role_id, doctor_id)
VALUES
  (@name, @mobile, NULL, NULL, NULL, 1, NULL, NULL,
   @clinic_id, GETDATE(), 3 /* ROLE.RECEPTIONIST, see routes/middleware/roles.js */, @doctor_id);

COMMIT TRAN;

SELECT recep_id, name, mobile_no, clinic_id, doctor_id FROM receptionist WHERE mobile_no = @mobile;
`````

## `backend/scripts/add-manoj-swant-kudal.sql`

`````sql
-- Adds Dr. Manoj Swant as a separate doctor login (mobile 9000000001) with a
-- clinic in Kudal. Copies role/gender/timing defaults from the existing
-- Dr. Manoj (doctor_id = 1) so the new row behaves the same way.
-- doctor_login.mobile is UNIQUE, so this must be a new row, not a second
-- number on doctor_id = 1.
--
-- Review before running. Set @clinic_name / @address / @fee as needed.
-- Login: 9000000001 + demo OTP 123456 (see DEMO_RANGES in routes/login.js).

SET XACT_ABORT ON;
BEGIN TRAN;

DECLARE @mobile      NVARCHAR(20) = '9000000001';
DECLARE @clinic_id   NVARCHAR(50) = 'CL060';
DECLARE @clinic_name NVARCHAR(50) = 'Dr. Manoj Swant Clinic';
DECLARE @address     NVARCHAR(50) = 'Kudal, Sindhudurg';
DECLARE @fee         DECIMAL(10,2) = 300;

IF EXISTS (SELECT 1 FROM clinics WHERE clinic_id = @clinic_id)
BEGIN
  RAISERROR('clinic_id already exists in clinics', 16, 1);
  ROLLBACK TRAN;
  RETURN;
END

IF EXISTS (SELECT 1 FROM doctor_login WHERE mobile = @mobile)
BEGIN
  RAISERROR('Mobile already exists in doctor_login', 16, 1);
  ROLLBACK TRAN;
  RETURN;
END

INSERT INTO doctor_login
  (name, email, mobile, qualification, license_no, image, experience, specialization,
   created_at, role_id, active_status, is_verified, clinic_id, gender_id,
   q_start_before, avg_consultation_time)
SELECT
  'Dr. Manoj Swant', email, @mobile, qualification, license_no, image, experience, specialization,
  GETDATE(), role_id, 1, 1, @clinic_id, gender_id,
  q_start_before, avg_consultation_time
FROM doctor_login
WHERE doctor_id = 1;

DECLARE @new_doctor_id INT = SCOPE_IDENTITY();

INSERT INTO clinics
  (clinic_id, clinic_name, clinic_address, latitude, longitude, consultation_fee,
   created_at, clinic_contact, active_status, is_verified, doctor_id)
VALUES
  (@clinic_id, @clinic_name, @address, 16.0136000, 73.6853000, @fee,
   GETDATE(), @mobile, 1, 1, @new_doctor_id);

COMMIT TRAN;

SELECT doctor_id, name, mobile, clinic_id FROM doctor_login WHERE mobile = @mobile;
`````

## `backend/scripts/backfill-existing-doctor-verification.sql`

`````sql
/*
  QLess — backfill is_verified for doctors that predate the approval gate
  ---------------------------------------------------------------------------
  WHY:
  migrate-doctor-verification.sql assumed existing doctor rows already had
  is_verified = 1 (matching the schema dump's old Insert default), so the
  corrected login_screen.dart check ("block when != 1") wouldn't affect them.

  That assumption was wrong: checking the live DB after the migration shows
  all 41 existing doctor rows (active_status = 0) actually have is_verified
  = 0 — the schema dump was stale relative to what's really deployed. Under
  the OLD (inverted) frontend check, 0 passed through fine; under the FIXED
  check, 0 now reads as "pending" and would lock every one of them out,
  including real production accounts, the next time the updated app ships.

  This is a one-time catch-up: mark everyone who already has a working
  account as approved. Only brand-new registrations made AFTER this ran will
  start out pending for real admin review.
*/

USE [QLess];
GO

SELECT doctor_id, name, mobile, is_verified, active_status
FROM dbo.doctor_login
WHERE active_status = 0 AND is_verified = 0;
GO

UPDATE dbo.doctor_login
SET is_verified = 1
WHERE active_status = 0 AND is_verified = 0;
GO

SELECT COUNT(*) AS still_pending
FROM dbo.doctor_login
WHERE active_status = 0 AND is_verified = 0;
GO
`````

## `backend/scripts/bookManojActiveQueue.js`

`````js
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
const CLINIC_ID = 'CL001';
const N = parseInt(process.argv[2], 10) || 20;
const SLOT_START = process.argv[3] || null; // optional HH:MM filter, e.g. "11:30"
const SYMPTOMS = ['Fever','Cold','Headache','Cough','BP check','Acidity','Joint pain','Skin rash','Stomach upset','Allergy'];

function todayStr() {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;
}

async function main() {
  await db.ready();

  const slotR = await db.request()
    .input('doctor_id', DOCTOR_ID)
    .input('slot_start', SLOT_START)
    .query(`
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
      AND (@slot_start IS NULL OR CONVERT(VARCHAR(5), ts.start_time, 108) = @slot_start)
      AND (@slot_start IS NOT NULL OR CAST(GETDATE() AS TIME) < ts.end_time)
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
      .input('clinic_id', CLINIC_ID)
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
`````

## `backend/scripts/change-manoj-swant-mobile.sql`

`````sql
-- Changes Dr. Manoj Swant's login number from 9876000001 to 9000000001.
-- doctor_login.mobile is UNIQUE, so 9000000001 must not already exist
-- (run remove-manoj-swant-kudal.sql first if add-manoj-swant-kudal.sql was run).

SET XACT_ABORT ON;

DECLARE @old_mobile NVARCHAR(20) = '9876000001';
DECLARE @new_mobile NVARCHAR(20) = '9000000001';

-- Preview
SELECT doctor_id, name, mobile, clinic_id FROM doctor_login WHERE mobile IN (@old_mobile, @new_mobile);

IF NOT EXISTS (SELECT 1 FROM doctor_login WHERE mobile = @old_mobile)
BEGIN
  RAISERROR('Old mobile not found - nothing changed', 16, 1);
  RETURN;
END

IF EXISTS (SELECT 1 FROM doctor_login WHERE mobile = @new_mobile)
BEGIN
  RAISERROR('New mobile already exists in doctor_login - nothing changed', 16, 1);
  RETURN;
END

BEGIN TRAN;

UPDATE doctor_login SET mobile = @new_mobile WHERE mobile = @old_mobile;

-- Keep the clinic contact in sync if it held the old number
UPDATE clinics SET clinic_contact = @new_mobile
WHERE clinic_contact = @old_mobile
  AND doctor_id = (SELECT doctor_id FROM doctor_login WHERE mobile = @new_mobile);

COMMIT TRAN;

SELECT doctor_id, name, mobile, clinic_id FROM doctor_login WHERE mobile = @new_mobile;
`````

## `backend/scripts/delete-doctors-except-1-30.sql`

`````sql
-- PERMANENTLY deletes every doctor except doctor_id 1..30 (so doctor 58, which
-- holds the demo mobile 9876000001, IS deleted too), together with their
-- clinics and ALL related rows
-- (appointments, queue, prescriptions + medicines, reviews, favourites,
-- schedule/slots/leave, receptionists, tokens, OTPs, deletion requests...).
-- THIS CANNOT BE UNDONE.  Take a database backup first.
--
-- Two-pass use:
--   1) Run as-is (@apply = 0). It only COUNTS what would be deleted.
--   2) Check the counts, then set @apply = 1 and run again to delete.
-- The transaction is always committed or rolled back inside this script, so
-- it never leaves a lock behind.

USE [QLess];
GO

DECLARE @apply BIT = 0;   -- <<< change to 1 to really delete

SET XACT_ABORT ON;

IF OBJECT_ID('tempdb..#del_doc') IS NOT NULL DROP TABLE #del_doc;
IF OBJECT_ID('tempdb..#del_clinic') IS NOT NULL DROP TABLE #del_clinic;
IF OBJECT_ID('tempdb..#del_presc') IS NOT NULL DROP TABLE #del_presc;
IF OBJECT_ID('tempdb..#del_avail') IS NOT NULL DROP TABLE #del_avail;

SELECT doctor_id, mobile INTO #del_doc
FROM dbo.doctor_login
WHERE doctor_id NOT BETWEEN 1 AND 30;

-- Clinics owned by those doctors (via clinics.doctor_id or doctor_login.clinic_id)
SELECT clinic_id INTO #del_clinic
FROM dbo.clinics
WHERE doctor_id IN (SELECT doctor_id FROM #del_doc)
   OR clinic_id IN (SELECT clinic_id FROM dbo.doctor_login
                    WHERE doctor_id IN (SELECT doctor_id FROM #del_doc));

-- Prescriptions written by those doctors or at those clinics
SELECT prescription_id INTO #del_presc
FROM dbo.patient_records
WHERE doctor_id IN (SELECT doctor_id FROM #del_doc)
   OR clinic_id IN (SELECT clinic_id FROM #del_clinic);

-- Availability rows (and through them time slots)
SELECT availability_id INTO #del_avail
FROM dbo.doctor_availability
WHERE doctor_id IN (SELECT doctor_id FROM #del_doc)
   OR clinic_id IN (SELECT clinic_id FROM #del_clinic);

-- What will go
SELECT 'doctors'                 AS what, COUNT(*) AS n FROM #del_doc
UNION ALL SELECT 'clinics',               COUNT(*) FROM #del_clinic
UNION ALL SELECT 'clinic_images',         COUNT(*) FROM dbo.clinic_images WHERE clinic_id IN (SELECT clinic_id FROM #del_clinic)
UNION ALL SELECT 'appointments',          COUNT(*) FROM dbo.appointments WHERE doctor_id IN (SELECT doctor_id FROM #del_doc) OR clinic_id IN (SELECT clinic_id FROM #del_clinic)
UNION ALL SELECT 'doctor_queue',          COUNT(*) FROM dbo.doctor_queue WHERE doctor_id IN (SELECT doctor_id FROM #del_doc) OR clinic_id IN (SELECT clinic_id FROM #del_clinic)
UNION ALL SELECT 'patient_records',       COUNT(*) FROM #del_presc
UNION ALL SELECT 'PrescriptionMedicine',  COUNT(*) FROM dbo.PrescriptionMedicine WHERE prescription_id IN (SELECT prescription_id FROM #del_presc)
UNION ALL SELECT 'reviews',               COUNT(*) FROM dbo.reviews WHERE doctor_id IN (SELECT doctor_id FROM #del_doc) OR clinic_id IN (SELECT clinic_id FROM #del_clinic)
UNION ALL SELECT 'favorite_doctors',      COUNT(*) FROM dbo.favorite_doctors WHERE doctor_id IN (SELECT doctor_id FROM #del_doc) OR clinic_id IN (SELECT clinic_id FROM #del_clinic)
UNION ALL SELECT 'doctor_availability',   COUNT(*) FROM #del_avail
UNION ALL SELECT 'doctor_time_slots',     COUNT(*) FROM dbo.doctor_time_slots WHERE availability_id IN (SELECT availability_id FROM #del_avail)
UNION ALL SELECT 'doctor_leave',          COUNT(*) FROM dbo.doctor_leave WHERE doctor_id IN (SELECT doctor_id FROM #del_doc) OR clinic_id IN (SELECT clinic_id FROM #del_clinic)
UNION ALL SELECT 'doctor_timing',         COUNT(*) FROM dbo.doctor_timing WHERE doctor_id IN (SELECT doctor_id FROM #del_doc) OR clinic_id IN (SELECT clinic_id FROM #del_clinic)
UNION ALL SELECT 'doctor_unavailability', COUNT(*) FROM dbo.doctor_unavailability WHERE doctor_id IN (SELECT doctor_id FROM #del_doc)
UNION ALL SELECT 'Doctor_Medicine',       COUNT(*) FROM dbo.Doctor_Medicine WHERE doctor_id IN (SELECT doctor_id FROM #del_doc)
UNION ALL SELECT 'Medicine_Master_Backup',COUNT(*) FROM dbo.Medicine_Master_Backup WHERE doctor_id IN (SELECT doctor_id FROM #del_doc)
UNION ALL SELECT 'receptionists',         COUNT(*) FROM dbo.receptionist WHERE doctor_id IN (SELECT doctor_id FROM #del_doc) OR clinic_id IN (SELECT clinic_id FROM #del_clinic)
UNION ALL SELECT 'RefreshTokens',         COUNT(*) FROM dbo.RefreshTokens WHERE user_mobile IN (SELECT mobile FROM #del_doc)
UNION ALL SELECT 'otp_verification',      COUNT(*) FROM dbo.otp_verification WHERE mobile_no IN (SELECT mobile FROM #del_doc)
UNION ALL SELECT 'AccountDeletionRequests', COUNT(*) FROM dbo.AccountDeletionRequests WHERE phone IN (SELECT mobile FROM #del_doc) AND role_id = 1;

SELECT doctor_id, mobile FROM #del_doc ORDER BY doctor_id;

IF @apply = 0
BEGIN
    PRINT 'DRY RUN - nothing deleted. Set @apply = 1 to delete.';
    RETURN;
END

BEGIN TRY
    BEGIN TRAN;

    DELETE FROM dbo.PrescriptionMedicine WHERE prescription_id IN (SELECT prescription_id FROM #del_presc);
    DELETE FROM dbo.patient_records      WHERE prescription_id IN (SELECT prescription_id FROM #del_presc);

    DELETE FROM dbo.doctor_time_slots    WHERE availability_id IN (SELECT availability_id FROM #del_avail);
    DELETE FROM dbo.doctor_availability  WHERE availability_id IN (SELECT availability_id FROM #del_avail);

    DELETE FROM dbo.appointments         WHERE doctor_id IN (SELECT doctor_id FROM #del_doc) OR clinic_id IN (SELECT clinic_id FROM #del_clinic);
    DELETE FROM dbo.doctor_queue         WHERE doctor_id IN (SELECT doctor_id FROM #del_doc) OR clinic_id IN (SELECT clinic_id FROM #del_clinic);
    DELETE FROM dbo.reviews              WHERE doctor_id IN (SELECT doctor_id FROM #del_doc) OR clinic_id IN (SELECT clinic_id FROM #del_clinic);
    DELETE FROM dbo.favorite_doctors     WHERE doctor_id IN (SELECT doctor_id FROM #del_doc) OR clinic_id IN (SELECT clinic_id FROM #del_clinic);
    DELETE FROM dbo.doctor_leave         WHERE doctor_id IN (SELECT doctor_id FROM #del_doc) OR clinic_id IN (SELECT clinic_id FROM #del_clinic);
    DELETE FROM dbo.doctor_timing        WHERE doctor_id IN (SELECT doctor_id FROM #del_doc) OR clinic_id IN (SELECT clinic_id FROM #del_clinic);
    DELETE FROM dbo.doctor_unavailability WHERE doctor_id IN (SELECT doctor_id FROM #del_doc);
    DELETE FROM dbo.Doctor_Medicine      WHERE doctor_id IN (SELECT doctor_id FROM #del_doc);
    DELETE FROM dbo.Medicine_Master_Backup WHERE doctor_id IN (SELECT doctor_id FROM #del_doc);
    DELETE FROM dbo.receptionist         WHERE doctor_id IN (SELECT doctor_id FROM #del_doc) OR clinic_id IN (SELECT clinic_id FROM #del_clinic);

    DELETE FROM dbo.clinic_images        WHERE clinic_id IN (SELECT clinic_id FROM #del_clinic);
    DELETE FROM dbo.clinics              WHERE clinic_id IN (SELECT clinic_id FROM #del_clinic);

    DELETE FROM dbo.RefreshTokens        WHERE user_mobile IN (SELECT mobile FROM #del_doc);
    DELETE FROM dbo.otp_verification     WHERE mobile_no IN (SELECT mobile FROM #del_doc);
    DELETE FROM dbo.AccountDeletionRequests WHERE phone IN (SELECT mobile FROM #del_doc) AND role_id = 1;
    DELETE FROM dbo.doctor_login         WHERE doctor_id IN (SELECT doctor_id FROM #del_doc);

    COMMIT TRAN;
    PRINT 'Deleted.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRAN;
    SELECT ERROR_MESSAGE() AS error, ERROR_LINE() AS line;
END CATCH;

SELECT doctor_id, name, mobile, active_status FROM dbo.doctor_login ORDER BY doctor_id;
`````

## `backend/scripts/fix-receptionist-view.sql`

`````sql
/*
  QLess — receptionist_vw join fix
  ---------------------------------------------------------------------------
  WHY:
  The view joined clinics, Gender and role with INNER JOINs, so a receptionist
  whose clinic_id, gender_id or role_id was NULL (or pointed at a deleted row)
  vanished from the view entirely — even though the receptionist record itself
  was perfectly fine.

  That is how the login role went missing: ManageRefreshToken used to read
  role_id from this view, found no row, and wrote a session with role_id = NULL.
  Fifteen minutes later the token refresh handed the app a role of nothing, the
  receptionist's screen turned into the doctor's, and the next launch dropped
  the session at the login page.

  The token path no longer depends on this view (see
  migrate-refresh-token-role.sql), but every other reader — the receptionist
  list, checkPhoneReceptionist, the profile screen — still hides those people.
  A lookup that is missing should blank one column, not delete the person.

  LEFT JOIN only ever ADDS rows, so nothing that works today stops working;
  callers must simply tolerate a NULL clinic_name / gender / role, which is the
  honest representation of "not set yet".
*/

USE [QLess];
GO

ALTER VIEW dbo.receptionist_vw
AS
SELECT r.recep_id,
       r.name,
       r.mobile_no,
       r.email,
       r.Address,
       r.active_status,
       c.clinic_name,
       r.gender_id,
       g.gender,
       r.clinic_id,
       r.img_url,
       r.created_at,
       r.token,
       ro.role,
       r.role_id,
       r.doctor_id
FROM   dbo.receptionist AS r
       LEFT JOIN dbo.clinics AS c ON r.clinic_id = c.clinic_id
       LEFT JOIN dbo.Gender  AS g ON r.gender_id = g.gender_id
       LEFT JOIN dbo.role    AS ro ON r.role_id  = ro.role_id;
GO

-- Who was hidden until now:
-- SELECT r.recep_id, r.name, r.mobile_no, r.clinic_id, r.gender_id, r.role_id
-- FROM   dbo.receptionist AS r
-- WHERE  r.clinic_id IS NULL OR r.gender_id IS NULL OR r.role_id IS NULL;

-- Receptionists still carrying no role_id (worth back-filling to 3):
-- UPDATE dbo.receptionist SET role_id = 3 WHERE role_id IS NULL;
`````

## `backend/scripts/migrate-500-errors.js`

`````js

`````

## `backend/scripts/migrate-account-deletion.sql`

`````sql
-- ============================================================================
-- Migration: Upgrade AccountDeletionRequests for OTP-verified deletion flow
--
-- SAFE TO RUN MULTIPLE TIMES — all changes are guarded by existence checks.
-- Run against the QLess database before deploying the new backend.
-- ============================================================================

-- ── 1. Create table fresh if it does not exist ───────────────────────────────
IF NOT EXISTS (
    SELECT 1 FROM sys.objects WHERE name = 'AccountDeletionRequests' AND type = 'U'
)
BEGIN
    CREATE TABLE AccountDeletionRequests (
        id              INT              NOT NULL IDENTITY(1,1),
        phone           NVARCHAR(15)     NOT NULL,
        role_id         INT              NOT NULL,   -- 1=Doctor, 2=Patient, 3=Receptionist
        reason          NVARCHAR(500)    NULL,
        status          NVARCHAR(20)     NOT NULL DEFAULT 'pending',
        otp_verified_at DATETIME2        NULL,
        scheduled_for   DATETIME2        NULL,
        completed_at    DATETIME2        NULL,
        created_at      DATETIME2        NOT NULL DEFAULT GETUTCDATE(),

        CONSTRAINT PK_AccountDeletionRequests PRIMARY KEY (id),
        CONSTRAINT CK_ADR_status  CHECK (status IN ('pending', 'cancelled', 'completed')),
        CONSTRAINT CK_ADR_role_id CHECK (role_id IN (1, 2, 3))
    )

    CREATE UNIQUE INDEX UX_ADR_phone_role_pending
        ON AccountDeletionRequests (phone, role_id)
        WHERE status = 'pending'

    CREATE INDEX IX_ADR_scheduled
        ON AccountDeletionRequests (status, scheduled_for)

    PRINT 'AccountDeletionRequests created from scratch.'
END
GO

-- ── 2. Add missing columns to existing table ─────────────────────────────────
-- Each column is added in its own batch so DDL is committed before the next
-- check runs. This avoids "column not found" parse errors.

IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID('AccountDeletionRequests') AND name = 'status'
)
BEGIN
    ALTER TABLE AccountDeletionRequests
        ADD status NVARCHAR(20) NOT NULL DEFAULT 'pending'
    ALTER TABLE AccountDeletionRequests
        ADD CONSTRAINT CK_ADR_status CHECK (status IN ('pending', 'cancelled', 'completed'))
    PRINT 'Added column: status'
END
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID('AccountDeletionRequests') AND name = 'otp_verified_at'
)
BEGIN
    ALTER TABLE AccountDeletionRequests ADD otp_verified_at DATETIME2 NULL
    PRINT 'Added column: otp_verified_at'
END
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID('AccountDeletionRequests') AND name = 'scheduled_for'
)
BEGIN
    ALTER TABLE AccountDeletionRequests ADD scheduled_for DATETIME2 NULL
    PRINT 'Added column: scheduled_for'
END
GO

-- Backfill scheduled_for for any pre-existing rows (runs after the column exists)
IF EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID('AccountDeletionRequests') AND name = 'scheduled_for'
)
BEGIN
    IF EXISTS (
        SELECT 1 FROM sys.columns
        WHERE object_id = OBJECT_ID('AccountDeletionRequests') AND name = 'created_at'
    )
        EXEC sp_executesql N'
            UPDATE AccountDeletionRequests
            SET scheduled_for = DATEADD(DAY, 30, created_at)
            WHERE scheduled_for IS NULL'
    ELSE
        EXEC sp_executesql N'
            UPDATE AccountDeletionRequests
            SET scheduled_for = DATEADD(DAY, 30, GETUTCDATE())
            WHERE scheduled_for IS NULL'
END
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID('AccountDeletionRequests') AND name = 'completed_at'
)
BEGIN
    ALTER TABLE AccountDeletionRequests ADD completed_at DATETIME2 NULL
    PRINT 'Added column: completed_at'
END
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID('AccountDeletionRequests') AND name = 'created_at'
)
BEGIN
    ALTER TABLE AccountDeletionRequests
        ADD created_at DATETIME2 NOT NULL DEFAULT GETUTCDATE()
    PRINT 'Added column: created_at'
END
GO

-- ── 3. Add missing indexes ────────────────────────────────────────────────────

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('AccountDeletionRequests') AND name = 'UX_ADR_phone_role_pending'
)
BEGIN
    CREATE UNIQUE INDEX UX_ADR_phone_role_pending
        ON AccountDeletionRequests (phone, role_id)
        WHERE status = 'pending'
    PRINT 'Added index: UX_ADR_phone_role_pending'
END
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('AccountDeletionRequests') AND name = 'IX_ADR_scheduled'
)
BEGIN
    CREATE INDEX IX_ADR_scheduled
        ON AccountDeletionRequests (status, scheduled_for)
    PRINT 'Added index: IX_ADR_scheduled'
END
GO

-- ── 4. Verify final schema ────────────────────────────────────────────────────
SELECT
    c.name      AS column_name,
    t.name      AS data_type,
    c.max_length,
    c.is_nullable,
    c.is_identity,
    c.column_id
FROM sys.columns c
JOIN sys.types   t ON t.user_type_id = c.user_type_id
WHERE c.object_id = OBJECT_ID('AccountDeletionRequests')
ORDER BY c.column_id
GO
`````

## `backend/scripts/migrate-doctor-verification.sql`

`````sql
/*
  QLess — doctor verification gate fix + admin approval operations
  ---------------------------------------------------------------------------
  WHY:
  sp_doctor_login's Insert branch hardcoded is_verified = 1 for every newly
  registered doctor. The app's login screen blocks sign-in precisely when
  is_verified = 1 (frontend/lib/presentation/shared/screens/login_screen.dart,
  "Under Verification" dialog) — so every doctor who ever registered was
  blocked forever, with no code path anywhere that ever flipped the flag back.

  This migration:
    1. Changes the Insert default to is_verified = 0 (pending review).
    2. Adds 'ListPendingDoctors' and 'VerifyDoctor' operations so the new
       /admin approval endpoints (backend/routes/admin.js) have something to
       call. 'DeleteDoctor' (already existed) doubles as "reject".

  After this runs, existing doctor rows that were inserted under the old
  default (is_verified = 1, meaning "blocked forever") need a one-time
  backfill — see the commented UPDATE at the bottom.
*/

USE [QLess];
GO

ALTER PROCEDURE [dbo].[sp_doctor_login]
(
    @operation          NVARCHAR(50),
    @doctor_id          INT = NULL,
    @name               NVARCHAR(50) = NULL,
    @email              NVARCHAR(MAX) = NULL,
    @mobile             NVARCHAR(20) = NULL,
    @qualification      NVARCHAR(MAX) = NULL,
    @license_no         NVARCHAR(50) = NULL,
    @experience         INT = NULL,
    @specialization     NVARCHAR(50) = NULL,
    @role_id            INT = NULL,
    @gender_id          INT = NULL,
    @q_start_before     INT = NULL,
    @role               NVARCHAR(20) = NULL,
    @token              NVARCHAR(MAX) = NULL,
    @image              NVARCHAR(MAX) = NULL,
    @clinic_id          NVARCHAR(50) = NULL,
    @clinic_name        NVARCHAR(50) = NULL,
    @clinic_address     NVARCHAR(100) = NULL,
    @latitude           DECIMAL(10,7) = NULL,
    @longitude          DECIMAL(10,7) = NULL,
    @consultation_fee   DECIMAL(10,2) = NULL,
    @website_name       NVARCHAR(50) = NULL,
    @clinic_email       NVARCHAR(MAX) = NULL,
    @clinic_contact     NVARCHAR(20) = NULL,
    @image_url          NVARCHAR(MAX) = NULL,
    @sort_order         INT = NULL
)
AS
BEGIN
SET NOCOUNT ON;

---------------------------------------------------------
-- INSERT
---------------------------------------------------------
IF @operation = 'Insert'
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        IF EXISTS (
            SELECT 1 FROM dbo.doctor_login
            WHERE mobile = @mobile AND active_status = 0
        )
        BEGIN
            SELECT 0 AS success, 'Mobile number already exists' AS message;
            ROLLBACK TRANSACTION;
            RETURN;
        END
		IF EXISTS (
    SELECT 1 FROM dbo.receptionist
    WHERE mobile_no = @mobile AND active_status = 1
)
BEGIN
    SELECT 0 AS success, 'This mobile is already registered as a Receptionist' AS message;
    ROLLBACK TRANSACTION;
    RETURN;
END


        DECLARE @next_no INT;
        SELECT @next_no = ISNULL(MAX(CAST(SUBSTRING(clinic_id,3,10) AS INT)),0) + 1
        FROM dbo.clinics WHERE clinic_id LIKE 'CL%';
        SET @clinic_id = 'CL' + RIGHT('000' + CAST(@next_no AS NVARCHAR), 3);

        INSERT INTO dbo.clinics
            (clinic_id, clinic_name, clinic_address, latitude, longitude,
             consultation_fee, website_name, clinic_email, clinic_contact,
             image_url, active_status, is_verified)
        VALUES
            (@clinic_id, @clinic_name, @clinic_address, @latitude, @longitude,
             @consultation_fee, @website_name, @clinic_email, @clinic_contact,
             @image_url, 0, 1);

        -- is_verified = 0: a freshly-registered doctor is PENDING admin
        -- review until someone approves them via /admin (VerifyDoctor below).
        INSERT INTO dbo.doctor_login
            (name, email, mobile, qualification, license_no, experience,
             specialization, created_at, role_id, clinic_id,
             active_status, is_verified, gender_id, image)
        VALUES
            (@name, @email, @mobile, @qualification, @license_no, @experience,
             @specialization, GETDATE(), @role_id, @clinic_id,
             0, 0, @gender_id, @image);

        SET @doctor_id = SCOPE_IDENTITY();

        UPDATE dbo.clinics
        SET doctor_id = @doctor_id
        WHERE clinic_id = @clinic_id;

        COMMIT TRANSACTION;
        SELECT @doctor_id AS doctor_id, @clinic_id AS clinic_id;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        SELECT ERROR_MESSAGE() AS ErrorMessage, ERROR_LINE() AS ErrorLine;
    END CATCH
    RETURN;
END

---------------------------------------------------------
-- saveFirebaseToken
---------------------------------------------------------
IF @operation = 'saveFirebaseToken'
BEGIN
    IF @role = 'doctor'
        UPDATE doctor_login SET token = @token WHERE mobile = @mobile;
    ELSE IF @role = 'patient'
        UPDATE Patients SET token = @token WHERE mobile_no = @mobile;
    RETURN;
END

---------------------------------------------------------
-- UPDATE
---------------------------------------------------------
IF @operation = 'Update'
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.doctor_login
        SET name = @name, email = @email, mobile = @mobile,
            qualification = @qualification, license_no = @license_no,
            experience = @experience, specialization = @specialization,
            role_id = @role_id, gender_id = @gender_id
        WHERE doctor_id = @doctor_id;

        UPDATE dbo.clinics
        SET clinic_name = @clinic_name, clinic_address = @clinic_address,
            latitude = @latitude, longitude = @longitude,
            consultation_fee = @consultation_fee, website_name = @website_name,
            clinic_email = @clinic_email, clinic_contact = @clinic_contact,
            image_url = @image_url
        WHERE clinic_id = (SELECT clinic_id FROM dbo.doctor_login WHERE doctor_id = @doctor_id);

        COMMIT TRANSACTION;

        DECLARE @returned_clinic_id NVARCHAR(50);
        SELECT @returned_clinic_id = clinic_id FROM dbo.doctor_login WHERE doctor_id = @doctor_id;
        SELECT @doctor_id AS doctor_id, @returned_clinic_id AS clinic_id;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        SELECT ERROR_MESSAGE() AS ErrorMessage, ERROR_LINE() AS ErrorLine;
    END CATCH
    RETURN;
END

---------------------------------------------------------
-- FetchDoctor
---------------------------------------------------------
IF @operation = 'FetchDoctor'
BEGIN
    SELECT d.doctor_id, d.name, d.email, d.mobile, d.qualification,
           d.license_no, d.experience, d.specialization, d.clinic_id,
           c.clinic_name, c.clinic_address, c.consultation_fee,
           c.clinic_contact, c.clinic_email
    FROM dbo.doctor_login d
    LEFT JOIN dbo.clinics c ON d.clinic_id = c.clinic_id
    WHERE d.mobile = @mobile;
    RETURN;
END

---------------------------------------------------------
-- FetchDoctors
---------------------------------------------------------
IF @operation = 'FetchDoctors'
BEGIN
    SELECT * FROM dbo.doctor_login
    WHERE clinic_id = @clinic_id AND active_status = 0;
    RETURN;
END

---------------------------------------------------------
-- DeleteDoctor
---------------------------------------------------------
IF @operation = 'DeleteDoctor'
BEGIN
    UPDATE dbo.doctor_login SET active_status = 1 WHERE doctor_id = @doctor_id;
    SELECT 1 AS success, 'Doctor deleted successfully' AS message;
    RETURN;
END

---------------------------------------------------------
-- ListPendingDoctors — admin approval queue
---------------------------------------------------------
IF @operation = 'ListPendingDoctors'
BEGIN
    SELECT doctor_id, name, email, mobile, qualification, license_no,
           experience, specialization, clinic_id, clinic_name,
           clinic_address, clinic_contact, clinic_email, doc_created_at
    FROM dbo.doctor_login_vw
    WHERE doc_active_status = 0 AND doc_is_verified = 0
    ORDER BY doc_created_at ASC;
    RETURN;
END

---------------------------------------------------------
-- VerifyDoctor — admin approval
---------------------------------------------------------
IF @operation = 'VerifyDoctor'
BEGIN
    UPDATE dbo.doctor_login SET is_verified = 1 WHERE doctor_id = @doctor_id;
    SELECT 1 AS success, 'Doctor verified' AS message;
    RETURN;
END

---------------------------------------------------------
-- check_phone_doctor
---------------------------------------------------------
IF @operation = 'check_phone_doctor'
BEGIN
    SELECT * FROM dbo.doctor_login_vw
    WHERE mobile = @mobile AND doc_active_status = 0 AND doc_is_verified = 0;
    RETURN;
END

---------------------------------------------------------
-- doctor_mobile_exist
---------------------------------------------------------
IF @operation = 'doctor_mobile_exist'
BEGIN
    SELECT doctor_id, mobile, doc_active_status, doc_is_verified
    FROM dbo.doctor_login_vw
    WHERE mobile = @mobile AND doc_active_status = 0

    UNION ALL

    SELECT NULL AS doctor_id, mobile_no AS mobile, 1 AS doc_active_status, 1 AS doc_is_verified
    FROM dbo.receptionist
    WHERE mobile_no = @mobile AND active_status = 1;
    RETURN;
END

---------------------------------------------------------
-- uploadDoctorImg
---------------------------------------------------------
IF @operation = 'uploadDoctorImg'
BEGIN
    UPDATE doctor_login SET image = @image WHERE doctor_id = @doctor_id;
    RETURN;
END

---------------------------------------------------------
-- uploadClinicImg
---------------------------------------------------------
IF @operation = 'uploadClinicImg'
BEGIN
    UPDATE clinics SET image_url = @image_url WHERE clinic_id = @clinic_id;
    RETURN;
END

---------------------------------------------------------
-- uploadClinicGallery
---------------------------------------------------------
IF @operation = 'uploadClinicGallery'
BEGIN
    INSERT INTO dbo.clinic_images
        (clinic_id, image_url, sort_order, active_status, created_at)
    VALUES (@clinic_id, @image_url, @sort_order, 0, GETDATE());
    RETURN;
END

---------------------------------------------------------
-- Insert_Q_StartTime
---------------------------------------------------------
IF @operation = 'Insert_Q_StartTime'
BEGIN
    UPDATE doctor_login SET q_start_before = @q_start_before WHERE doctor_id = @doctor_id;
    RETURN;
END

---------------------------------------------------------
-- fetchClinicGallery
---------------------------------------------------------
IF @operation = 'fetchClinicGallery'
BEGIN
    SELECT clinic_image_id, clinic_id, image_url, sort_order
    FROM dbo.clinic_images
    WHERE clinic_id = @clinic_id AND active_status = 0
    ORDER BY sort_order;
    RETURN;
END

---------------------------------------------------------
-- deleteClinicGallery
---------------------------------------------------------
IF @operation = 'deleteClinicGallery'
BEGIN
    DELETE FROM dbo.clinic_images
    WHERE clinic_id = @clinic_id
      AND image_url IN (SELECT value FROM STRING_SPLIT(@image_url, ','));
    SELECT @@ROWCOUNT AS deleted_count, 'Images deleted' AS message;
    RETURN;
END

---------------------------------------------------------
-- AddClinic
---------------------------------------------------------
IF @operation = 'AddClinic'
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @next_no2 INT;
        SELECT @next_no2 = ISNULL(MAX(CAST(SUBSTRING(clinic_id,3,10) AS INT)),0) + 1
        FROM dbo.clinics WHERE clinic_id LIKE 'CL%';
        SET @clinic_id = 'CL' + RIGHT('000' + CAST(@next_no2 AS NVARCHAR), 3);

        INSERT INTO dbo.clinics
            (clinic_id, clinic_name, clinic_address, latitude, longitude,
             consultation_fee, website_name, clinic_email, clinic_contact,
             image_url, active_status, is_verified, doctor_id)
        VALUES
            (@clinic_id, @clinic_name, @clinic_address, @latitude, @longitude,
             @consultation_fee, @website_name, @clinic_email, @clinic_contact,
             @image_url, 0, 1, @doctor_id);

        COMMIT TRANSACTION;
        SELECT 1 AS success, @clinic_id AS clinic_id, 'Clinic added' AS message;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        SELECT ERROR_MESSAGE() AS ErrorMessage;
    END CATCH
    RETURN;
END

---------------------------------------------------------
-- GetDoctorClinics
---------------------------------------------------------
IF @operation = 'GetDoctorClinics'
BEGIN
    SELECT
        clinic_id, clinic_name, clinic_address,
        latitude, longitude, consultation_fee,
        clinic_email, clinic_contact,
        website_name, image_url,
        CASE WHEN clinic_id = (
            SELECT clinic_id FROM dbo.doctor_login WHERE doctor_id = @doctor_id
        ) THEN 1 ELSE 0 END AS is_primary
    FROM dbo.clinics
    WHERE doctor_id = @doctor_id
      AND active_status = 0
    ORDER BY is_primary DESC;
    RETURN;
END

---------------------------------------------------------
-- UpdateClinic
---------------------------------------------------------
IF @operation = 'UpdateClinic'
BEGIN
    UPDATE dbo.clinics
    SET clinic_name      = @clinic_name,
        clinic_address   = @clinic_address,
        latitude         = ISNULL(@latitude, latitude),
        longitude        = ISNULL(@longitude, longitude),
        consultation_fee = @consultation_fee,
        website_name     = @website_name,
        clinic_email     = @clinic_email,
        clinic_contact   = @clinic_contact
    WHERE clinic_id = @clinic_id
      AND doctor_id = @doctor_id;
    SELECT 1 AS success, @clinic_id AS clinic_id;
    RETURN;
END

---------------------------------------------------------
-- DeleteClinic
---------------------------------------------------------
IF @operation = 'DeleteClinic'
BEGIN
    -- Primary clinic (doctor_login.clinic_id shi match) delete nahi hoto
    IF EXISTS (
        SELECT 1 FROM dbo.doctor_login
        WHERE doctor_id = @doctor_id AND clinic_id = @clinic_id
    )
    BEGIN
        SELECT 0 AS success, 'Cannot delete primary clinic' AS message;
        RETURN;
    END

    UPDATE dbo.clinics
    SET active_status = 1
    WHERE clinic_id = @clinic_id
      AND doctor_id = @doctor_id;

    SELECT 1 AS success, 'Clinic deleted' AS message;
    RETURN;
END

END
GO

-- No backfill needed for doctors who registered before this migration: they
-- were inserted with is_verified = 1 under the old (inverted) convention,
-- and that value now means "approved" under the corrected convention below
-- — so existing doctors keep working without any data change.
`````

## `backend/scripts/migrate-medicine-brand-components.sql`

`````sql
/*
  QLess — optional brand name / strength / components on medicines
  ---------------------------------------------------------------------------
  WHY:
  Doctors could only save a medicine name + type. They need to record the
  brand (e.g. Crocin), strength (e.g. 500mg) and components
  (e.g. Paracetamol 500mg + Caffeine 30mg). All three are optional.

  This migration:
    1. Adds brand_name, strength, components to Medicine_Master (all NULL).
    2. Widens the unique key to (name, type, brand, strength) so the same
       medicine can exist under different brands/strengths in the shared
       global library.
    3. Updates sp_Medicine_Master to accept/return the new columns and to
       match brand in suggestions.
*/

USE [QLess];
GO

IF COL_LENGTH('dbo.Medicine_Master', 'brand_name') IS NULL
    ALTER TABLE dbo.Medicine_Master ADD
        brand_name NVARCHAR(200) NULL,
        strength   NVARCHAR(50)  NULL,
        components NVARCHAR(500) NULL;
GO

IF EXISTS (SELECT 1 FROM sys.key_constraints WHERE name = 'UQ_Medicine_Name_Type')
    ALTER TABLE dbo.Medicine_Master DROP CONSTRAINT UQ_Medicine_Name_Type;
GO

IF NOT EXISTS (SELECT 1 FROM sys.key_constraints WHERE name = 'UQ_Medicine_Name_Type_Brand_Strength')
    ALTER TABLE dbo.Medicine_Master ADD CONSTRAINT UQ_Medicine_Name_Type_Brand_Strength
        UNIQUE (medicine_name, medicine_type_id, brand_name, strength);
GO

ALTER PROCEDURE [dbo].[sp_Medicine_Master]
    @operation        NVARCHAR(20)  = NULL,
    @medicine_id      INT           = 0,
    @doctor_id        INT           = 0,
    @medicine_name    NVARCHAR(100) = NULL,
    @medicine_type_id INT           = NULL,
    @search_query     NVARCHAR(100) = NULL,
    @brand_name       NVARCHAR(200) = NULL,
    @strength         NVARCHAR(50)  = NULL,
    @components       NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- ---------------------------------------------------------
    -- INSERT: global library + per-doctor link
    -- ---------------------------------------------------------
    IF @operation = 'Insert'
    BEGIN
        DECLARE @medId INT;

        -- 1. Medicine_Master madhe (name+type+brand+strength) ahe ka check
        SELECT @medId = medicine_id
        FROM dbo.Medicine_Master
        WHERE medicine_name    = @medicine_name
          AND medicine_type_id = @medicine_type_id
          AND ISNULL(brand_name, '') = ISNULL(@brand_name, '')
          AND ISNULL(strength, '')   = ISNULL(@strength, '');

        -- 2. Naselich tar global library madhe insert
        IF @medId IS NULL
        BEGIN
            INSERT INTO dbo.Medicine_Master (medicine_name, medicine_type_id, brand_name, strength, components)
            VALUES (@medicine_name, @medicine_type_id, @brand_name, @strength, @components);
            SET @medId = SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            -- Existing row la components nasel tar bharun ghya
            UPDATE dbo.Medicine_Master
            SET    components = @components
            WHERE  medicine_id = @medId
              AND  components IS NULL
              AND  @components IS NOT NULL;
        END

        -- 3. Already active link asla ? duplicate prevent
        IF EXISTS (
            SELECT 1 FROM dbo.Doctor_Medicine
            WHERE doctor_id   = @doctor_id
              AND medicine_id = @medId
              AND is_active   = 1
        )
        BEGIN
            SELECT 'Medicine already in your list.' AS Message;
            RETURN;
        END

        -- 4. Soft-deleted link asla ? reactivate
        IF EXISTS (
            SELECT 1 FROM dbo.Doctor_Medicine
            WHERE doctor_id   = @doctor_id
              AND medicine_id = @medId
              AND is_active   = 0
        )
        BEGIN
            UPDATE dbo.Doctor_Medicine
            SET    is_active = 1
            WHERE  doctor_id   = @doctor_id
              AND  medicine_id = @medId;

            SELECT 'Medicine reactivated.' AS Message;
            RETURN;
        END

        -- 5. Navin link insert
        INSERT INTO dbo.Doctor_Medicine (doctor_id, medicine_id, is_active)
        VALUES (@doctor_id, @medId, 1);

        SELECT 'Medicine added successfully.' AS Message;
    END

    -- ---------------------------------------------------------
    -- GET MEDICINE TYPES
    -- ---------------------------------------------------------
    IF @operation = 'getMedicineTypes'
    BEGIN
        SELECT * FROM dbo.Medicine_Type;
    END

    -- ---------------------------------------------------------
    -- FETCH ALL MEDICINES (per doctor list)
    -- ---------------------------------------------------------
    IF @operation = 'fetchAllMedicines'
    BEGIN
        SELECT
            m.medicine_id,
            dm.doctor_id,
            m.medicine_name,
            m.medicine_type_id,
            t.Medi_Type_Name,
            m.brand_name,
            m.strength,
            m.components
        FROM   dbo.Doctor_Medicine dm
        INNER JOIN dbo.Medicine_Master m ON dm.medicine_id    = m.medicine_id
        INNER JOIN dbo.Medicine_Type   t ON m.medicine_type_id = t.medicine_type_id
        WHERE  dm.doctor_id = @doctor_id
          AND  dm.is_active = 1
        ORDER BY m.medicine_name;
    END

    -- ---------------------------------------------------------
    -- GET SUGGESTIONS (global library madhun typing veli)
    -- ---------------------------------------------------------
    IF @operation = 'getSuggestions'
    BEGIN
        SELECT TOP 20
            m.medicine_id,
            m.medicine_name,
            m.medicine_type_id,
            t.Medi_Type_Name,
            m.brand_name,
            m.strength,
            m.components
        FROM   dbo.Medicine_Master m
        INNER JOIN dbo.Medicine_Type t ON m.medicine_type_id = t.medicine_type_id
        WHERE  m.medicine_name LIKE @search_query + '%'
           OR  m.brand_name    LIKE @search_query + '%'
        ORDER BY m.medicine_name;
    END

    -- ---------------------------------------------------------
    -- DELETE (per-doctor soft delete; library la touch nahi)
    -- ---------------------------------------------------------
    IF @operation = 'Delete'
    BEGIN
        UPDATE dbo.Doctor_Medicine
        SET    is_active = 0
        WHERE  medicine_id = @medicine_id
          AND  doctor_id   = @doctor_id
          AND  is_active   = 1;

        IF @@ROWCOUNT > 0
            SELECT 'Medicine removed from your list.' AS Message;
        ELSE
            SELECT 'No medicine found to delete.' AS Message;
    END
END
GO
`````

## `backend/scripts/migrate-refresh-token-role.sql`

`````sql
/*
  QLess — RefreshTokens role migration
  ---------------------------------------------------------------------------
  WHY:
  The 'insert' branch looked the role id up in doctor_login_vw / patient_login_vw
  / receptionist_vw by mobile. When that lookup found nothing — a receptionist
  whose view row carries no role_id, or a mobile stored in a different format —
  @role_id stayed NULL and the session row was written with role_id = NULL.

  /Createlogin survived that (it had its own fallback), but /refreshAccessToken
  reads the role straight off the row: it answered the app with roleId null, the
  app stored 0, and ~15 minutes after login every `roleId == 3` receptionist
  check turned false — the receptionist's screen became the doctor's, and the
  next app launch saw roleId 0 and wiped the session back to the login screen.

  FIX: the role name now maps directly to its id. The API resolves which role
  the account actually holds (see resolveAccountRole in routes/login.js) and
  passes the verified name here, so this procedure no longer depends on view
  contents or on how a mobile number happens to be formatted.

  ALSO: the id is assigned under UPDLOCK/HOLDLOCK. MAX(id)+1 read outside a lock
  hands the same id to two simultaneous logins and one of them dies on the
  primary key.

  Run against the database in backend/.env → DB_NAME.
*/

USE [QLess];
GO

-- 1) Column (already present on QLess; guarded so the script is re-runnable) --
IF COL_LENGTH('dbo.RefreshTokens', 'role_id') IS NULL
BEGIN
    ALTER TABLE dbo.RefreshTokens ADD role_id TINYINT NULL;
END
GO

-- 2) Sessions with no role cannot be refreshed correctly and cannot be
--    back-filled reliably. Dropping them costs each signed-in user one
--    re-login, which beats guessing a role and mis-typing their session.
DELETE FROM dbo.RefreshTokens WHERE role_id IS NULL;
GO

-- 3) Procedure ---------------------------------------------------------------
ALTER PROCEDURE [dbo].[ManageRefreshToken]
    @operation       NVARCHAR(20),       -- 'insert' | 'get' | 'revoke' | 'AutoTask'

    -- Insert fields
    @user_mobile     NVARCHAR(50) = NULL,
    @refresh_token   NVARCHAR(MAX) = NULL,
    @device_info     NVARCHAR(500) = NULL,
    @ip_address      NVARCHAR(100) = NULL,
    @expires_at      DATETIME2 = NULL,
    @role            NVARCHAR(20) = NULL -- 'doctor' | 'patient' | 'receptionist'
AS
BEGIN
    SET NOCOUNT ON;

    -- Insert Operation --------------------------------------------
    IF @operation = 'insert'
    BEGIN
        DECLARE @role_id TINYINT =
            CASE LOWER(LTRIM(RTRIM(ISNULL(@role, ''))))
                WHEN 'doctor'       THEN 1
                WHEN 'patient'      THEN 2
                WHEN 'receptionist' THEN 3
            END;

        -- Refuse to create a session whose role we cannot name. A NULL role_id
        -- here is exactly what produced the receptionist→doctor bug.
        IF @role_id IS NULL
        BEGIN
            RAISERROR('ManageRefreshToken: @role must be doctor, patient or receptionist.', 16, 1);
            RETURN;
        END

        DECLARE @new INT;

        BEGIN TRANSACTION;

            -- UPDLOCK + HOLDLOCK: two logins landing together must not read the
            -- same MAX(id) and collide on the primary key.
            SELECT @new = ISNULL(MAX(id), 0) + 1
            FROM dbo.RefreshTokens WITH (UPDLOCK, HOLDLOCK);

            INSERT INTO dbo.RefreshTokens
                (id, user_mobile, refresh_token, device_info, created_at, expires_at, role_id, revoked)
            VALUES
                (@new, @user_mobile, @refresh_token, @device_info, SYSUTCDATETIME(), @expires_at, @role_id, 0);

        COMMIT TRANSACTION;

        SELECT @new AS id, @role_id AS role_id;
        RETURN;
    END


    -- Get Operation ------------------------------------------------
    IF @operation = 'get'
    BEGIN
        -- SELECT * carries role_id, which is what refreshAccessToken reads.
        SELECT TOP 1 *
        FROM dbo.RefreshTokens
        WHERE refresh_token = @refresh_token
          AND revoked = 0
          AND expires_at > SYSUTCDATETIME();
        RETURN;
    END


    -- Revoke Operation ---------------------------------------------
    IF @operation = 'revoke'
    BEGIN
        -- Callers revoke every live token of one mobile (login + refresh), or a
        -- single token when they have it.
        UPDATE dbo.RefreshTokens
        SET revoked = 1
        WHERE revoked != 1
          AND (
                (@refresh_token IS NOT NULL AND refresh_token = @refresh_token)
             OR (@refresh_token IS NULL AND @user_mobile IS NOT NULL AND user_mobile = @user_mobile)
              );

        SELECT @@ROWCOUNT AS revoked_count;
        RETURN;
    END


    -- Housekeeping --------------------------------------------------
    IF @operation = 'AutoTask'
    BEGIN
        DELETE FROM dbo.RefreshTokens
        WHERE expires_at < SYSUTCDATETIME();

        DELETE FROM dbo.RefreshTokens
        WHERE id IN (
            SELECT id FROM (
                SELECT id,
                       ROW_NUMBER() OVER (
                         PARTITION BY user_mobile ORDER BY created_at DESC
                       ) AS rn
                FROM dbo.RefreshTokens
            ) t
            WHERE t.rn > 5
        );
        RETURN;
    END

    -- Invalid Operation --------------------------------------------
    SELECT 'Invalid operation. Use insert, get, revoke or AutoTask.' AS error_message;
END
GO

-- 4) Verify ------------------------------------------------------------------
-- After one receptionist login the newest row must read role_id = 3:
-- SELECT TOP 5 id, user_mobile, role_id, revoked, created_at
-- FROM dbo.RefreshTokens ORDER BY id DESC;
`````

## `backend/scripts/remove-demo-patient.sql`

`````sql
-- Rolls back add-demo-patient.sql: removes the patient with mobile
-- 9878000001. Run the SELECT first to see what will be deleted.

SET XACT_ABORT ON;

DECLARE @mobile NVARCHAR(20) = '9878000001';

DECLARE @patient_id INT = (SELECT patient_id FROM Patients WHERE mobile_no = @mobile);

-- Preview
SELECT 'Patients' AS tbl, patient_id, name, mobile_no FROM Patients WHERE patient_id = @patient_id;

IF @patient_id IS NULL
BEGIN
  RAISERROR('No patient with this mobile - nothing deleted', 16, 1);
  RETURN;
END

BEGIN TRAN;

DELETE FROM Patients WHERE patient_id = @patient_id;

COMMIT TRAN;
`````

## `backend/scripts/remove-demo-receptionist.sql`

`````sql
-- Rolls back add-demo-receptionist.sql: removes the receptionist with
-- mobile 9877000001. Run the SELECT first to see what will be deleted.

SET XACT_ABORT ON;

DECLARE @mobile NVARCHAR(20) = '9877000001';

DECLARE @recep_id INT = (SELECT recep_id FROM receptionist WHERE mobile_no = @mobile);

-- Preview
SELECT 'receptionist' AS tbl, recep_id, name, mobile_no, clinic_id, doctor_id
  FROM receptionist WHERE recep_id = @recep_id;

IF @recep_id IS NULL
BEGIN
  RAISERROR('No receptionist with this mobile - nothing deleted', 16, 1);
  RETURN;
END

BEGIN TRAN;

DELETE FROM receptionist WHERE recep_id = @recep_id;

COMMIT TRAN;
`````

## `backend/scripts/remove-manoj-swant-kudal.sql`

`````sql
-- Rolls back add-manoj-swant-kudal.sql: removes the doctor with mobile
-- 9000000001 and clinic CL060 (only if CL060 belongs to that doctor).
-- Run the SELECTs first (below) to see what will be deleted.

SET XACT_ABORT ON;

DECLARE @mobile    NVARCHAR(20) = '9000000001';
DECLARE @clinic_id NVARCHAR(50) = 'CL060';

DECLARE @doctor_id INT = (SELECT doctor_id FROM doctor_login WHERE mobile = @mobile);

-- Preview
SELECT 'doctor_login' AS tbl, doctor_id, name, mobile, clinic_id FROM doctor_login WHERE doctor_id = @doctor_id;
SELECT 'clinics' AS tbl, clinic_id, clinic_name, doctor_id FROM clinics WHERE clinic_id = @clinic_id;

IF @doctor_id IS NULL OR @doctor_id = 1
BEGIN
  RAISERROR('No doctor with this mobile (or it is doctor_id 1) - nothing deleted', 16, 1);
  RETURN;
END

IF NOT EXISTS (SELECT 1 FROM clinics WHERE clinic_id = @clinic_id AND doctor_id = @doctor_id)
BEGIN
  RAISERROR('CL060 does not belong to this doctor - nothing deleted', 16, 1);
  RETURN;
END

BEGIN TRAN;

-- Rows the doctor may have created after login (safe if empty)
DELETE FROM doctor_time_slots
  WHERE availability_id IN (SELECT availability_id FROM doctor_availability WHERE doctor_id = @doctor_id);
DELETE FROM doctor_availability WHERE doctor_id = @doctor_id;
DELETE FROM doctor_leave WHERE doctor_id = @doctor_id;
DELETE FROM doctor_queue WHERE doctor_id = @doctor_id;

DELETE FROM clinics WHERE clinic_id = @clinic_id AND doctor_id = @doctor_id;
DELETE FROM doctor_login WHERE doctor_id = @doctor_id;

COMMIT TRAN;
`````

## `backend/scripts/restore-first-original-doctor-sp.sql`

`````sql
-- Restores the ORIGINAL (pre 4-Nov) doctor login behaviour:
--   is_verified = 0  -> APPROVED  (doctor can log in)
--   is_verified = 1  -> PENDING   (app shows "Under Verification")
-- A newly registered doctor gets is_verified = 1 (pending). To let them in,
-- set it to 0 by hand: UPDATE dbo.doctor_login SET is_verified = 0 WHERE doctor_id = <id>;
-- check_phone_doctor requires doc_is_verified = 0 (unchanged from the original).
-- The ListPendingDoctors / VerifyDoctor operations are kept (so backend
-- /admin routes do not break) but use the original meaning (1 = pending).
--
-- Requires the app's login_screen.dart check to be `isverified == 1` => block.
--
-- STEP 1: run this whole file (Execute).
-- STEP 2: run the data fix at the bottom (read it first).

USE [QLess]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[sp_doctor_login]
(
    @operation          NVARCHAR(50),
    @doctor_id          INT = NULL,
    @name               NVARCHAR(50) = NULL,
    @email              NVARCHAR(MAX) = NULL,
    @mobile             NVARCHAR(20) = NULL,
    @qualification      NVARCHAR(MAX) = NULL,
    @license_no         NVARCHAR(50) = NULL,
    @experience         INT = NULL,
    @specialization     NVARCHAR(50) = NULL,
    @role_id            INT = NULL,
    @gender_id          INT = NULL,
    @q_start_before     INT = NULL,
    @role               NVARCHAR(20) = NULL,
    @token              NVARCHAR(MAX) = NULL,
    @image              NVARCHAR(MAX) = NULL,
    @clinic_id          NVARCHAR(50) = NULL,
    @clinic_name        NVARCHAR(50) = NULL,
    @clinic_address     NVARCHAR(100) = NULL,
    @latitude           DECIMAL(10,7) = NULL,
    @longitude          DECIMAL(10,7) = NULL,
    @consultation_fee   DECIMAL(10,2) = NULL,
    @website_name       NVARCHAR(50) = NULL,
    @clinic_email       NVARCHAR(MAX) = NULL,
    @clinic_contact     NVARCHAR(20) = NULL,
    @image_url          NVARCHAR(MAX) = NULL,
    @sort_order         INT = NULL
)
AS
BEGIN
SET NOCOUNT ON;

---------------------------------------------------------
-- INSERT
---------------------------------------------------------
IF @operation = 'Insert'
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        IF EXISTS (
            SELECT 1 FROM dbo.doctor_login
            WHERE mobile = @mobile AND active_status = 0
        )
        BEGIN
            SELECT 0 AS success, 'Mobile number already exists' AS message;
            ROLLBACK TRANSACTION;
            RETURN;
        END
        IF EXISTS (
            SELECT 1 FROM dbo.receptionist
            WHERE mobile_no = @mobile AND active_status = 1
        )
        BEGIN
            SELECT 0 AS success, 'This mobile is already registered as a Receptionist' AS message;
            ROLLBACK TRANSACTION;
            RETURN;
        END


        DECLARE @next_no INT;
        SELECT @next_no = ISNULL(MAX(CAST(SUBSTRING(clinic_id,3,10) AS INT)),0) + 1
        FROM dbo.clinics WHERE clinic_id LIKE 'CL%';
        SET @clinic_id = 'CL' + RIGHT('000' + CAST(@next_no AS NVARCHAR), 3);

        INSERT INTO dbo.clinics
            (clinic_id, clinic_name, clinic_address, latitude, longitude,
             consultation_fee, website_name, clinic_email, clinic_contact,
             image_url, active_status, is_verified)
        VALUES
            (@clinic_id, @clinic_name, @clinic_address, @latitude, @longitude,
             @consultation_fee, @website_name, @clinic_email, @clinic_contact,
             @image_url, 0, 1);

        -- is_verified = 1: a freshly-registered doctor starts as pending
        -- ("Under Verification" at login) until it is set to 0 by hand
        -- (original behaviour).
        INSERT INTO dbo.doctor_login
            (name, email, mobile, qualification, license_no, experience,
             specialization, created_at, role_id, clinic_id,
             active_status, is_verified, gender_id, image)
        VALUES
            (@name, @email, @mobile, @qualification, @license_no, @experience,
             @specialization, GETDATE(), @role_id, @clinic_id,
             0, 1, @gender_id, @image);

        SET @doctor_id = SCOPE_IDENTITY();

        UPDATE dbo.clinics
        SET doctor_id = @doctor_id
        WHERE clinic_id = @clinic_id;

        COMMIT TRANSACTION;
        SELECT @doctor_id AS doctor_id, @clinic_id AS clinic_id;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        SELECT ERROR_MESSAGE() AS ErrorMessage, ERROR_LINE() AS ErrorLine;
    END CATCH
    RETURN;
END

---------------------------------------------------------
-- saveFirebaseToken
---------------------------------------------------------
IF @operation = 'saveFirebaseToken'
BEGIN
    IF @role = 'doctor'
        UPDATE doctor_login SET token = @token WHERE mobile = @mobile;
    ELSE IF @role = 'patient'
        UPDATE Patients SET token = @token WHERE mobile_no = @mobile;
    RETURN;
END

---------------------------------------------------------
-- UPDATE
---------------------------------------------------------
IF @operation = 'Update'
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.doctor_login
        SET name = @name, email = @email, mobile = @mobile,
            qualification = @qualification, license_no = @license_no,
            experience = @experience, specialization = @specialization,
            role_id = @role_id, gender_id = @gender_id
        WHERE doctor_id = @doctor_id;

        UPDATE dbo.clinics
        SET clinic_name = @clinic_name, clinic_address = @clinic_address,
            latitude = @latitude, longitude = @longitude,
            consultation_fee = @consultation_fee, website_name = @website_name,
            clinic_email = @clinic_email, clinic_contact = @clinic_contact,
            image_url = @image_url
        WHERE clinic_id = (SELECT clinic_id FROM dbo.doctor_login WHERE doctor_id = @doctor_id);

        COMMIT TRANSACTION;

        DECLARE @returned_clinic_id NVARCHAR(50);
        SELECT @returned_clinic_id = clinic_id FROM dbo.doctor_login WHERE doctor_id = @doctor_id;
        SELECT @doctor_id AS doctor_id, @returned_clinic_id AS clinic_id;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        SELECT ERROR_MESSAGE() AS ErrorMessage, ERROR_LINE() AS ErrorLine;
    END CATCH
    RETURN;
END

---------------------------------------------------------
-- FetchDoctor
---------------------------------------------------------
IF @operation = 'FetchDoctor'
BEGIN
    SELECT d.doctor_id, d.name, d.email, d.mobile, d.qualification,
           d.license_no, d.experience, d.specialization, d.clinic_id,
           c.clinic_name, c.clinic_address, c.consultation_fee,
           c.clinic_contact, c.clinic_email
    FROM dbo.doctor_login d
    LEFT JOIN dbo.clinics c ON d.clinic_id = c.clinic_id
    WHERE d.mobile = @mobile;
    RETURN;
END

---------------------------------------------------------
-- FetchDoctors
---------------------------------------------------------
IF @operation = 'FetchDoctors'
BEGIN
    SELECT * FROM dbo.doctor_login
    WHERE clinic_id = @clinic_id AND active_status = 0;
    RETURN;
END

---------------------------------------------------------
-- DeleteDoctor
---------------------------------------------------------
IF @operation = 'DeleteDoctor'
BEGIN
    UPDATE dbo.doctor_login SET active_status = 1 WHERE doctor_id = @doctor_id;
    SELECT 1 AS success, 'Doctor deleted successfully' AS message;
    RETURN;
END

---------------------------------------------------------
-- ListPendingDoctors - blocked/pending doctors (1 = pending)
---------------------------------------------------------
IF @operation = 'ListPendingDoctors'
BEGIN
    SELECT doctor_id, name, email, mobile, qualification, license_no,
           experience, specialization, clinic_id, clinic_name,
           clinic_address, clinic_contact, clinic_email, doc_created_at
    FROM dbo.doctor_login_vw
    WHERE doc_active_status = 0 AND doc_is_verified = 1
    ORDER BY doc_created_at ASC;
    RETURN;
END

---------------------------------------------------------
-- VerifyDoctor - approval (0 = approved)
---------------------------------------------------------
IF @operation = 'VerifyDoctor'
BEGIN
    UPDATE dbo.doctor_login SET is_verified = 0 WHERE doctor_id = @doctor_id;
    SELECT 1 AS success, 'Doctor verified' AS message;
    RETURN;
END

---------------------------------------------------------
-- check_phone_doctor (approved doctors only: 0 = approved) - original
---------------------------------------------------------
IF @operation = 'check_phone_doctor'
BEGIN
    SELECT * FROM dbo.doctor_login_vw
    WHERE mobile = @mobile AND doc_active_status = 0 AND doc_is_verified = 0;
    RETURN;
END

---------------------------------------------------------
-- doctor_mobile_exist
---------------------------------------------------------
IF @operation = 'doctor_mobile_exist'
BEGIN
    SELECT doctor_id, mobile, doc_active_status, doc_is_verified
    FROM dbo.doctor_login_vw
    WHERE mobile = @mobile AND doc_active_status = 0

    UNION ALL

    SELECT NULL AS doctor_id, mobile_no AS mobile, 1 AS doc_active_status, 1 AS doc_is_verified
    FROM dbo.receptionist
    WHERE mobile_no = @mobile AND active_status = 1;
    RETURN;
END

---------------------------------------------------------
-- uploadDoctorImg
---------------------------------------------------------
IF @operation = 'uploadDoctorImg'
BEGIN
    UPDATE doctor_login SET image = @image WHERE doctor_id = @doctor_id;
    RETURN;
END

---------------------------------------------------------
-- uploadClinicImg
---------------------------------------------------------
IF @operation = 'uploadClinicImg'
BEGIN
    UPDATE clinics SET image_url = @image_url WHERE clinic_id = @clinic_id;
    RETURN;
END

---------------------------------------------------------
-- uploadClinicGallery
---------------------------------------------------------
IF @operation = 'uploadClinicGallery'
BEGIN
    INSERT INTO dbo.clinic_images
        (clinic_id, image_url, sort_order, active_status, created_at)
    VALUES (@clinic_id, @image_url, @sort_order, 0, GETDATE());
    RETURN;
END

---------------------------------------------------------
-- Insert_Q_StartTime
---------------------------------------------------------
IF @operation = 'Insert_Q_StartTime'
BEGIN
    UPDATE doctor_login SET q_start_before = @q_start_before WHERE doctor_id = @doctor_id;
    RETURN;
END

---------------------------------------------------------
-- fetchClinicGallery
---------------------------------------------------------
IF @operation = 'fetchClinicGallery'
BEGIN
    SELECT clinic_image_id, clinic_id, image_url, sort_order
    FROM dbo.clinic_images
    WHERE clinic_id = @clinic_id AND active_status = 0
    ORDER BY sort_order;
    RETURN;
END

---------------------------------------------------------
-- deleteClinicGallery
---------------------------------------------------------
IF @operation = 'deleteClinicGallery'
BEGIN
    DELETE FROM dbo.clinic_images
    WHERE clinic_id = @clinic_id
      AND image_url IN (SELECT value FROM STRING_SPLIT(@image_url, ','));
    SELECT @@ROWCOUNT AS deleted_count, 'Images deleted' AS message;
    RETURN;
END

---------------------------------------------------------
-- AddClinic
---------------------------------------------------------
IF @operation = 'AddClinic'
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @next_no2 INT;
        SELECT @next_no2 = ISNULL(MAX(CAST(SUBSTRING(clinic_id,3,10) AS INT)),0) + 1
        FROM dbo.clinics WHERE clinic_id LIKE 'CL%';
        SET @clinic_id = 'CL' + RIGHT('000' + CAST(@next_no2 AS NVARCHAR), 3);

        INSERT INTO dbo.clinics
            (clinic_id, clinic_name, clinic_address, latitude, longitude,
             consultation_fee, website_name, clinic_email, clinic_contact,
             image_url, active_status, is_verified, doctor_id)
        VALUES
            (@clinic_id, @clinic_name, @clinic_address, @latitude, @longitude,
             @consultation_fee, @website_name, @clinic_email, @clinic_contact,
             @image_url, 0, 1, @doctor_id);

        COMMIT TRANSACTION;
        SELECT 1 AS success, @clinic_id AS clinic_id, 'Clinic added' AS message;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        SELECT ERROR_MESSAGE() AS ErrorMessage;
    END CATCH
    RETURN;
END

---------------------------------------------------------
-- GetDoctorClinics
---------------------------------------------------------
IF @operation = 'GetDoctorClinics'
BEGIN
    SELECT
        clinic_id, clinic_name, clinic_address,
        latitude, longitude, consultation_fee,
        clinic_email, clinic_contact,
        website_name, image_url,
        CASE WHEN clinic_id = (
            SELECT clinic_id FROM dbo.doctor_login WHERE doctor_id = @doctor_id
        ) THEN 1 ELSE 0 END AS is_primary
    FROM dbo.clinics
    WHERE doctor_id = @doctor_id
      AND active_status = 0
    ORDER BY is_primary DESC;
    RETURN;
END

---------------------------------------------------------
-- UpdateClinic
---------------------------------------------------------
IF @operation = 'UpdateClinic'
BEGIN
    UPDATE dbo.clinics
    SET clinic_name      = @clinic_name,
        clinic_address   = @clinic_address,
        latitude         = ISNULL(@latitude, latitude),
        longitude        = ISNULL(@longitude, longitude),
        consultation_fee = @consultation_fee,
        website_name     = @website_name,
        clinic_email     = @clinic_email,
        clinic_contact   = @clinic_contact
    WHERE clinic_id = @clinic_id
      AND doctor_id = @doctor_id;
    SELECT 1 AS success, @clinic_id AS clinic_id;
    RETURN;
END

---------------------------------------------------------
-- DeleteClinic
---------------------------------------------------------
IF @operation = 'DeleteClinic'
BEGIN
    -- Primary clinic (doctor_login.clinic_id shi match) delete nahi hoto
    IF EXISTS (
        SELECT 1 FROM dbo.doctor_login
        WHERE doctor_id = @doctor_id AND clinic_id = @clinic_id
    )
    BEGIN
        SELECT 0 AS success, 'Cannot delete primary clinic' AS message;
        RETURN;
    END

    UPDATE dbo.clinics
    SET active_status = 1
    WHERE clinic_id = @clinic_id
      AND doctor_id = @doctor_id;

    SELECT 1 AS success, 'Clinic deleted' AS message;
    RETURN;
END

END
GO

-- =====================================================================
-- STEP 2 (data fix) - run SEPARATELY, after step 1.
-- Originally ALL doctor rows had is_verified = 0. Today doctors 31-49,
-- 51-57 and 59 are 1 (the 4-Nov backfill set them) and would be blocked.
-- See who is 1, then set the ones that should log in back to 0:
--
--   SELECT doctor_id, name, mobile, is_verified FROM dbo.doctor_login
--   WHERE is_verified = 1 AND active_status = 0;
--
-- Everyone (as originally):
--   UPDATE dbo.doctor_login SET is_verified = 0 WHERE active_status = 0;
-- Only some:
--   UPDATE dbo.doctor_login SET is_verified = 0 WHERE doctor_id IN (31, 49, 55, 59);
-- =====================================================================
`````

## `backend/scripts/run-sql.js`

`````js
#!/usr/bin/env node
// One-off runner for the .sql scripts in backend/scripts/.
// Reuses the exact same connection config as routes/db.js (same backend/.env),
// so it works wherever that file already works — your machine or the server.
//
// Usage (run from the backend/ directory):
//   node scripts/run-sql.js scripts/add-manoj-swant-kudal.sql
//   node scripts/run-sql.js scripts/add-demo-receptionist.sql
//   node scripts/run-sql.js scripts/add-demo-patient.sql
//
// Or via the npm script added to package.json:
//   npm run db -- scripts/add-demo-patient.sql
//
// Uses pool.request().batch() (not .query()) because these scripts rely on
// T-SQL batch-level statements (DECLARE, BEGIN TRAN, IF EXISTS, RAISERROR,
// RETURN) that .query() does not reliably support.

require('dotenv').config();
const fs = require('fs');
const path = require('path');
const sql = require('mssql');

const file = process.argv[2];
if (!file) {
  console.error('Usage: node scripts/run-sql.js <path-to-sql-file>');
  process.exit(1);
}

const resolved = path.resolve(file);
if (!fs.existsSync(resolved)) {
  console.error(`File not found: ${resolved}`);
  process.exit(1);
}

const required = ['DB_USER', 'DB_PASSWORD', 'DB_SERVER', 'DB_NAME'];
for (const k of required) {
  if (!process.env[k]) {
    console.error(`Missing required env var: ${k}. Copy .env.example to .env and fill in values.`);
    process.exit(1);
  }
}

const sqlConfig = {
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  server: process.env.DB_SERVER,
  database: process.env.DB_NAME,
  port: parseInt(process.env.DB_PORT, 10) || 1433,
  options: {
    encrypt: true,
    trustServerCertificate: true,
  },
};

// GO is an sqlcmd/SSMS batch separator, not real T-SQL — the engine itself
// rejects it ("Incorrect syntax near 'GO'") if sent as part of a batch. Split
// on lines that are only "GO" (optionally with a repeat count, which we
// ignore) and run each piece as its own .batch() call, same as sqlcmd would.
function splitBatches(sqlText) {
  return sqlText
    .split(/^\s*GO\s*(?:\d+)?\s*$/im)
    .map((b) => b.trim())
    .filter(Boolean);
}

(async () => {
  const sqlText = fs.readFileSync(resolved, 'utf8');
  const batches = splitBatches(sqlText);
  console.log(`Connecting to ${sqlConfig.server}/${sqlConfig.database} as ${sqlConfig.user}...`);
  const pool = await sql.connect(sqlConfig);
  try {
    console.log(`Running ${path.basename(resolved)} (${batches.length} batch${batches.length === 1 ? '' : 'es'}) ...`);
    let anyResults = false;

    for (let i = 0; i < batches.length; i++) {
      const result = await pool.request().batch(batches[i]);

      const recordsets = result.recordsets && result.recordsets.length
        ? result.recordsets
        : (result.recordset ? [result.recordset] : []);

      if (recordsets.length) {
        anyResults = true;
        recordsets.forEach((rs, j) => {
          console.log(`-- batch ${i + 1}/${batches.length}, recordset ${j} --`);
          console.table(rs);
        });
      }
    }

    if (!anyResults) console.log('Done — no rows returned.');
  } finally {
    await pool.close();
  }
})().catch((err) => {
  // RAISERROR from the scripts' own guard clauses (e.g. "mobile already
  // exists") surfaces here as a normal failure — that is expected, not a bug.
  console.error('FAILED:', err.message);
  process.exit(1);
});
`````

## `backend/scripts/set-manoj-swant-kudal-location.sql`

`````sql
-- Sets Dr. Manoj Swant's clinic address and map location to Kudal, Sindhudurg.
-- Works whether his login is still 9876000001 or already 9000000001.
-- Coordinates are Kudal town centre; fine-tune later with the map pin in the app.

SET XACT_ABORT ON;

DECLARE @address   NVARCHAR(50)  = 'Kudal, Sindhudurg';
DECLARE @latitude  DECIMAL(10,7) = 16.0121000;
DECLARE @longitude DECIMAL(10,7) = 73.6889000;

-- Preview
SELECT d.doctor_id, d.name, d.mobile, c.clinic_id, c.clinic_address, c.latitude, c.longitude
FROM doctor_login d
JOIN clinics c ON c.doctor_id = d.doctor_id
WHERE d.mobile IN ('9876000001', '9000000001');

BEGIN TRAN;

UPDATE c
SET c.clinic_address = @address,
    c.latitude       = @latitude,
    c.longitude      = @longitude
FROM clinics c
JOIN doctor_login d ON d.doctor_id = c.doctor_id
WHERE d.mobile IN ('9876000001', '9000000001');

COMMIT TRAN;

SELECT d.doctor_id, d.name, d.mobile, c.clinic_id, c.clinic_address, c.latitude, c.longitude
FROM doctor_login d
JOIN clinics c ON c.doctor_id = d.doctor_id
WHERE d.mobile IN ('9876000001', '9000000001');
`````

## `backend/scripts/schema/full-schema.sql`

`````sql
/****** Object:  Database [QLess_Prod_db]    Script Date: 15-10-2026 12:09:42 ******/
CREATE DATABASE [QLess_Prod_db]
 CONTAINMENT = NONE
 ON  PRIMARY 
( NAME = N'DoNotWait', FILENAME = N'C:\Program Files (x86)\Plesk\Databases\MSSQL\MSSQL15.MSSQLSERVER2019\MSSQL\DATA\QLess_Prod_db_b7e40e08c1bb4ffa853aeeac66cf3870.mdf' , SIZE = 10240KB , MAXSIZE = 5242880KB , FILEGROWTH = 1024KB )
 LOG ON 
( NAME = N'DoNotWait_log', FILENAME = N'C:\Program Files (x86)\Plesk\Databases\MSSQL\MSSQL15.MSSQLSERVER2019\MSSQL\DATA\QLess_Prod_db_ba86973b632c47a49f0189e131988ec1.ldf' , SIZE = 8192KB , MAXSIZE = 5242880KB , FILEGROWTH = 10%)
 WITH CATALOG_COLLATION = DATABASE_DEFAULT
GO
ALTER DATABASE [QLess_Prod_db] SET COMPATIBILITY_LEVEL = 150
GO
IF (1 = FULLTEXTSERVICEPROPERTY('IsFullTextInstalled'))
begin
EXEC [QLess_Prod_db].[dbo].[sp_fulltext_database] @action = 'enable'
end
GO
ALTER DATABASE [QLess_Prod_db] SET ANSI_NULL_DEFAULT OFF 
GO
ALTER DATABASE [QLess_Prod_db] SET ANSI_NULLS OFF 
GO
ALTER DATABASE [QLess_Prod_db] SET ANSI_PADDING OFF 
GO
ALTER DATABASE [QLess_Prod_db] SET ANSI_WARNINGS OFF 
GO
ALTER DATABASE [QLess_Prod_db] SET ARITHABORT OFF 
GO
ALTER DATABASE [QLess_Prod_db] SET AUTO_CLOSE OFF 
GO
ALTER DATABASE [QLess_Prod_db] SET AUTO_SHRINK OFF 
GO
ALTER DATABASE [QLess_Prod_db] SET AUTO_UPDATE_STATISTICS ON 
GO
ALTER DATABASE [QLess_Prod_db] SET CURSOR_CLOSE_ON_COMMIT OFF 
GO
ALTER DATABASE [QLess_Prod_db] SET CURSOR_DEFAULT  GLOBAL 
GO
ALTER DATABASE [QLess_Prod_db] SET CONCAT_NULL_YIELDS_NULL OFF 
GO
ALTER DATABASE [QLess_Prod_db] SET NUMERIC_ROUNDABORT OFF 
GO
ALTER DATABASE [QLess_Prod_db] SET QUOTED_IDENTIFIER OFF 
GO
ALTER DATABASE [QLess_Prod_db] SET RECURSIVE_TRIGGERS OFF 
GO
ALTER DATABASE [QLess_Prod_db] SET  DISABLE_BROKER 
GO
ALTER DATABASE [QLess_Prod_db] SET AUTO_UPDATE_STATISTICS_ASYNC OFF 
GO
ALTER DATABASE [QLess_Prod_db] SET DATE_CORRELATION_OPTIMIZATION OFF 
GO
ALTER DATABASE [QLess_Prod_db] SET TRUSTWORTHY OFF 
GO
ALTER DATABASE [QLess_Prod_db] SET ALLOW_SNAPSHOT_ISOLATION OFF 
GO
ALTER DATABASE [QLess_Prod_db] SET PARAMETERIZATION SIMPLE 
GO
ALTER DATABASE [QLess_Prod_db] SET READ_COMMITTED_SNAPSHOT OFF 
GO
ALTER DATABASE [QLess_Prod_db] SET HONOR_BROKER_PRIORITY OFF 
GO
ALTER DATABASE [QLess_Prod_db] SET RECOVERY SIMPLE 
GO
ALTER DATABASE [QLess_Prod_db] SET  MULTI_USER 
GO
ALTER DATABASE [QLess_Prod_db] SET PAGE_VERIFY CHECKSUM  
GO
ALTER DATABASE [QLess_Prod_db] SET DB_CHAINING OFF 
GO
ALTER DATABASE [QLess_Prod_db] SET FILESTREAM( NON_TRANSACTED_ACCESS = OFF ) 
GO
ALTER DATABASE [QLess_Prod_db] SET TARGET_RECOVERY_TIME = 60 SECONDS 
GO
ALTER DATABASE [QLess_Prod_db] SET DELAYED_DURABILITY = DISABLED 
GO
ALTER DATABASE [QLess_Prod_db] SET ACCELERATED_DATABASE_RECOVERY = OFF  
GO
ALTER DATABASE [QLess_Prod_db] SET QUERY_STORE = OFF
GO
/****** Object:  User [QlessProd]    Script Date: 15-10-2026 12:09:43 ******/
CREATE USER [QlessProd] FOR LOGIN [QlessProd] WITH DEFAULT_SCHEMA=[QlessProd]
GO
ALTER ROLE [db_ddladmin] ADD MEMBER [QlessProd]
GO
ALTER ROLE [db_datareader] ADD MEMBER [QlessProd]
GO
ALTER ROLE [db_datawriter] ADD MEMBER [QlessProd]
GO
/****** Object:  Schema [QlessAdmin]    Script Date: 15-10-2026 12:09:43 ******/
CREATE SCHEMA [QlessAdmin]
GO
/****** Object:  Schema [QlessProd]    Script Date: 15-10-2026 12:09:43 ******/
CREATE SCHEMA [QlessProd]
GO
/****** Object:  View [dbo].[appointment_booking_vw]    Script Date: 15-10-2026 12:09:43 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[appointment_booking_vw] AS

SELECT 
    a.appointment_id, a.doctor_id, a.patient_id,
    a.patient_id AS family_id,
    d.name AS doctor_name, d.specialization, d.experience,
    COALESCE(a.clinic_id, d.clinic_id) AS clinic_id,
    c.clinic_name, c.clinic_address, c.clinic_contact, c.latitude, c.longitude,
    p.name AS patient_name,
    g.gender, p.DOB,
    a.appointment_date, a.start_time, a.end_time,
    a.queue_number, a.status, a.booking_type, a.user_type,
    'SELF' AS booking_for,
    a.slot_id, a.queue_id, a.symptoms, a.is_reviewed, d.mobile
FROM dbo.appointments AS a
INNER JOIN dbo.Patients AS p ON a.patient_id = p.patient_id
LEFT OUTER JOIN dbo.Gender AS g ON p.gender_id = g.gender_id
LEFT OUTER JOIN (
    SELECT doctor_id, name, specialization, experience, mobile, clinic_id,
           ROW_NUMBER() OVER (PARTITION BY doctor_id ORDER BY doctor_id) AS rn
    FROM dbo.doctor_login
) AS d ON a.doctor_id = d.doctor_id AND d.rn = 1
LEFT OUTER JOIN dbo.clinics AS c 
    ON c.clinic_id = COALESCE(a.clinic_id, d.clinic_id)
WHERE (a.user_type = 1)

UNION ALL

SELECT 
    a.appointment_id, a.doctor_id, a.patient_id,
    fm.family_id,
    d.name AS doctor_name, d.specialization, d.experience,
    COALESCE(a.clinic_id, d.clinic_id) AS clinic_id,
    c.clinic_name, c.clinic_address, c.clinic_contact, c.latitude, c.longitude,
    fm.name AS patient_name,
    g.gender, fm.DOB,
    a.appointment_date, a.start_time, a.end_time,
    a.queue_number, a.status, a.booking_type, a.user_type,
    'FAMILY' AS booking_for,
    a.slot_id, a.queue_id, a.symptoms, a.is_reviewed, d.mobile
FROM dbo.appointments AS a
INNER JOIN dbo.family_members AS fm ON a.patient_id = fm.member_id
LEFT OUTER JOIN dbo.Gender AS g ON fm.Gender_id = g.gender_id
LEFT OUTER JOIN (
    SELECT doctor_id, name, specialization, experience, mobile, clinic_id,
           ROW_NUMBER() OVER (PARTITION BY doctor_id ORDER BY doctor_id) AS rn
    FROM dbo.doctor_login
) AS d ON a.doctor_id = d.doctor_id AND d.rn = 1
LEFT OUTER JOIN dbo.clinics AS c 
    ON c.clinic_id = COALESCE(a.clinic_id, d.clinic_id)
WHERE (a.user_type = 2)
GO
/****** Object:  View [dbo].[doctor_availability_vw]    Script Date: 15-10-2026 12:09:43 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[doctor_availability_vw] AS
SELECT 
    dbo.doctor_availability.doctor_id,
    dbo.doctor_availability.clinic_id,        -- ? ADD THIS
    dbo.doctor_availability.day_of_week,
    dbo.doctor_availability.is_enabled,
    dbo.doctor_availability.created_at,
    dbo.doctor_time_slots.slot_id,
    dbo.doctor_time_slots.availability_id,
    dbo.doctor_time_slots.start_time,
    dbo.doctor_time_slots.end_time,
    dbo.doctor_time_slots.booking_mode,
    dbo.doctor_time_slots.slot_duration,
    dbo.doctor_time_slots.is_active
FROM dbo.doctor_availability 
INNER JOIN dbo.doctor_time_slots 
    ON dbo.doctor_availability.availability_id = dbo.doctor_time_slots.availability_id
WHERE dbo.doctor_time_slots.is_active = 1;
GO
/****** Object:  View [dbo].[doctor_login_vw]    Script Date: 15-10-2026 12:09:43 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[doctor_login_vw]
AS
SELECT c.clinic_id, c.clinic_name, c.clinic_address, c.latitude, c.longitude, c.consultation_fee, c.created_at, c.website_name, c.clinic_email, c.clinic_contact, c.image_url, c.active_status, c.is_verified, dl.doctor_id, dl.name, dl.email, dl.mobile, 
                  dl.qualification, dl.license_no, dl.image, dl.experience, dl.specialization, dl.created_at AS doc_created_at, dl.active_status AS doc_active_status, dl.is_verified AS doc_is_verified, dl.role_id, r.role, dl.token, g.gender, dl.gender_id, 
                  dl.q_start_before
FROM     dbo.doctor_login AS dl INNER JOIN
                  dbo.clinics AS c ON c.doctor_id = dl.doctor_id INNER JOIN
                  dbo.role AS r ON dl.role_id = r.role_id INNER JOIN
                  dbo.Gender AS g ON dl.gender_id = g.gender_id
GO
/****** Object:  View [dbo].[patient_login_vw]    Script Date: 15-10-2026 12:09:43 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[patient_login_vw]
AS
SELECT p.patient_id, p.name, p.mobile_no, p.email, p.Address, p.DOB, p.weight, p.role_id, p.active_status, p.token, r.role, p.gender_id, g.gender, p.blood_group_id, bg.blood_group_name, p.img_url
FROM     dbo.Patients AS p LEFT OUTER JOIN
                  dbo.role AS r ON p.role_id = r.role_id LEFT OUTER JOIN
                  dbo.Gender AS g ON p.gender_id = g.gender_id LEFT OUTER JOIN
                  dbo.blood_groups AS bg ON p.blood_group_id = bg.blood_group_id
GO
/****** Object:  View [dbo].[prescription_vw]    Script Date: 15-10-2026 12:09:43 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[prescription_vw]
AS
SELECT d.name AS doctor_name, d.qualification, d.experience, d.specialization, p.doctor_id, p.patient_id, CASE WHEN p.user_type = 1 THEN 'Self' WHEN p.user_type = 2 THEN 'Family' END AS user_type_name, 
                  CASE WHEN p.user_type = 1 THEN pt.name WHEN p.user_type = 2 THEN fm.name END AS patient_name, p.prescription_id, p.prescription_date, p.symptoms, p.diagnosis, p.clinical_notes, p.follow_up_date, p.advice, p.created_at, 
                  pm.presc_med_id, pm.medicine_id, mm.medicine_name, mm.medicine_type_id, mt.Medi_Type_Name, pm.frequency, pm.duration, pm.timing, pm.tablet_dosage, pm.syrup_dosage_ml, pm.inj_dosage, pm.inj_route, pm.drops_count, 
                  pm.drops_application, pm.lotion_apply_area, pm.spray_puffs, pm.spray_usage, pm.lotion_usage, c.clinic_name, c.clinic_address, c.clinic_contact, p.user_type, p.appointment_id, pm.powder_dosage, pm.powder_form, pm.inhaler_puffs, 
                  pm.inhaler_type, pm.inhaler_technique, pm.inhaler_usage
FROM     dbo.patient_records AS p INNER JOIN
                  dbo.appointments AS ap ON ap.appointment_id = p.appointment_id INNER JOIN
                  dbo.doctor_login AS d ON d.doctor_id = p.doctor_id LEFT OUTER JOIN
                  dbo.Patients AS pt ON p.patient_id = pt.patient_id AND p.user_type = 1 LEFT OUTER JOIN
                  dbo.family_members AS fm ON p.patient_id = fm.member_id AND p.user_type = 2 LEFT OUTER JOIN
                  dbo.PrescriptionMedicine AS pm ON p.prescription_id = pm.prescription_id LEFT OUTER JOIN
                  dbo.Medicine_Master AS mm ON mm.medicine_id = pm.medicine_id LEFT OUTER JOIN
                  dbo.Medicine_Type AS mt ON mm.medicine_type_id = mt.medicine_type_id INNER JOIN
                  dbo.clinics AS c ON c.clinic_id = ap.clinic_id
GO
/****** Object:  View [dbo].[receptionist_vw]    Script Date: 15-10-2026 12:09:43 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[receptionist_vw]
AS
SELECT r.recep_id,
       r.name,
       r.mobile_no,
       r.email,
       r.Address,
       r.active_status,
       c.clinic_name,
       r.gender_id,
       g.gender,
       r.clinic_id,
       r.img_url,
       r.created_at,
       r.token,
       ro.role,
       r.role_id,
       r.doctor_id
FROM   dbo.receptionist AS r
       LEFT JOIN dbo.clinics AS c ON r.clinic_id = c.clinic_id
       LEFT JOIN dbo.Gender  AS g ON r.gender_id = g.gender_id
       LEFT JOIN dbo.role    AS ro ON r.role_id  = ro.role_id;

GO
/****** Object:  Table [dbo].[AccountDeletionRequests]    Script Date: 15-10-2026 12:09:43 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[AccountDeletionRequests](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[phone] [varchar](15) NOT NULL,
	[role_id] [tinyint] NOT NULL,
	[reason] [nvarchar](255) NULL,
	[status] [varchar](20) NOT NULL,
	[requested_at] [datetime] NOT NULL,
	[completed_at] [datetime] NULL,
	[otp_verified_at] [datetime2](7) NULL,
	[scheduled_for] [datetime2](7) NULL,
	[created_at] [datetime2](7) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[appointments]    Script Date: 15-10-2026 12:09:44 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[appointments](
	[appointment_id] [int] IDENTITY(1,1) NOT NULL,
	[doctor_id] [int] NOT NULL,
	[patient_id] [int] NOT NULL,
	[appointment_date] [date] NOT NULL,
	[start_time] [time](7) NULL,
	[end_time] [time](7) NULL,
	[booking_type] [int] NOT NULL,
	[queue_number] [int] NULL,
	[status] [nvarchar](20) NULL,
	[created_at] [datetime] NULL,
	[user_type] [int] NULL,
	[slot_id] [int] NULL,
	[queue_id] [int] NULL,
	[symptoms] [nvarchar](max) NULL,
	[is_reviewed] [bit] NULL,
	[clinic_id] [nvarchar](20) NULL,
	[is_arrived] [bit] NOT NULL,
	[arrived_at] [datetime] NULL,
PRIMARY KEY CLUSTERED 
(
	[appointment_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[blood_groups]    Script Date: 15-10-2026 12:09:44 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[blood_groups](
	[blood_group_id] [int] IDENTITY(1,1) NOT NULL,
	[blood_group_name] [varchar](5) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[blood_group_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
UNIQUE NONCLUSTERED 
(
	[blood_group_name] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[booking_status]    Script Date: 15-10-2026 12:09:44 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[booking_status](
	[id] [int] NULL,
	[status] [nvarchar](50) NULL,
 CONSTRAINT [uq_booking_status_status] UNIQUE NONCLUSTERED 
(
	[status] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Category]    Script Date: 15-10-2026 12:09:44 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Category](
	[c_id] [int] IDENTITY(1,1) NOT NULL,
	[category] [nvarchar](50) NULL,
 CONSTRAINT [PK_Category] PRIMARY KEY CLUSTERED 
(
	[c_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[clinic_images]    Script Date: 15-10-2026 12:09:44 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[clinic_images](
	[clinic_image_id] [int] IDENTITY(1,1) NOT NULL,
	[clinic_id] [nvarchar](50) NOT NULL,
	[image_url] [nvarchar](max) NOT NULL,
	[sort_order] [int] NULL,
	[active_status] [bit] NULL,
	[created_at] [datetime] NULL,
PRIMARY KEY CLUSTERED 
(
	[clinic_image_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[clinics]    Script Date: 15-10-2026 12:09:44 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[clinics](
	[clinic_id] [nvarchar](50) NOT NULL,
	[clinic_name] [nvarchar](50) NULL,
	[clinic_address] [nvarchar](50) NULL,
	[latitude] [decimal](10, 7) NULL,
	[longitude] [decimal](10, 7) NULL,
	[consultation_fee] [decimal](10, 2) NULL,
	[created_at] [datetime] NULL,
	[website_name] [nvarchar](50) NULL,
	[clinic_email] [nvarchar](50) NULL,
	[clinic_contact] [nvarchar](20) NULL,
	[image_url] [nvarchar](max) NULL,
	[active_status] [int] NULL,
	[is_verified] [int] NULL,
	[doctor_id] [int] NULL,
 CONSTRAINT [PK__clinics__A0C8D19B1997DC17] PRIMARY KEY CLUSTERED 
(
	[clinic_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[doctor_availability]    Script Date: 15-10-2026 12:09:44 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[doctor_availability](
	[availability_id] [int] IDENTITY(1,1) NOT NULL,
	[doctor_id] [int] NOT NULL,
	[day_of_week] [varchar](10) NOT NULL,
	[is_enabled] [bit] NULL,
	[created_at] [datetime] NULL,
	[clinic_id] [nvarchar](20) NULL,
PRIMARY KEY CLUSTERED 
(
	[availability_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[doctor_leave]    Script Date: 15-10-2026 12:09:44 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[doctor_leave](
	[leave_id] [int] IDENTITY(1,1) NOT NULL,
	[doctor_id] [int] NOT NULL,
	[from_date] [date] NOT NULL,
	[to_date] [date] NOT NULL,
	[reason] [nvarchar](200) NULL,
	[is_active] [bit] NOT NULL,
	[created_at] [datetime] NOT NULL,
	[clinic_id] [varchar](20) NULL,
PRIMARY KEY CLUSTERED 
(
	[leave_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[doctor_login]    Script Date: 15-10-2026 12:09:44 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[doctor_login](
	[doctor_id] [int] IDENTITY(1,1) NOT NULL,
	[name] [nvarchar](50) NULL,
	[email] [nvarchar](50) NULL,
	[mobile] [nvarchar](20) NULL,
	[qualification] [nvarchar](max) NULL,
	[license_no] [nvarchar](50) NULL,
	[image] [nvarchar](max) NULL,
	[experience] [int] NULL,
	[specialization] [nvarchar](50) NULL,
	[created_at] [datetime] NULL,
	[role_id] [int] NULL,
	[active_status] [int] NULL,
	[is_verified] [int] NULL,
	[clinic_id] [nvarchar](50) NULL,
	[token] [nvarchar](max) NULL,
	[gender_id] [int] NULL,
	[q_start_before] [int] NULL,
	[avg_consultation_time] [decimal](10, 2) NULL,
	[last_heartbeat] [datetime] NULL,
	[is_online] [int] NULL,
 CONSTRAINT [UQ_doctor_mobile] UNIQUE NONCLUSTERED 
(
	[mobile] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Doctor_Medicine]    Script Date: 15-10-2026 12:09:44 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Doctor_Medicine](
	[link_id] [int] IDENTITY(1,1) NOT NULL,
	[doctor_id] [int] NOT NULL,
	[medicine_id] [int] NOT NULL,
	[is_active] [bit] NOT NULL,
	[created_at] [datetime] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[link_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_Doctor_Medicine] UNIQUE NONCLUSTERED 
(
	[doctor_id] ASC,
	[medicine_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[doctor_queue]    Script Date: 15-10-2026 12:09:44 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[doctor_queue](
	[queue_id] [int] IDENTITY(1,1) NOT NULL,
	[doctor_id] [int] NULL,
	[queue_date] [date] NULL,
	[current_serving] [int] NULL,
	[total_queue] [int] NULL,
	[avg_consultation_time] [float] NULL,
	[queue_status] [int] NULL,
	[started_at] [datetime] NULL,
	[stopped_at] [datetime] NULL,
	[created_at] [datetime] NULL,
	[completed_count] [int] NULL,
	[current_patient_id] [int] NULL,
	[slot_id] [int] NULL,
	[max_queue] [int] NULL,
	[clinic_id] [nvarchar](20) NULL,
	[booking_closed] [bit] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[queue_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[doctor_time_slots]    Script Date: 15-10-2026 12:09:44 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[doctor_time_slots](
	[slot_id] [int] IDENTITY(1,1) NOT NULL,
	[availability_id] [int] NOT NULL,
	[start_time] [time](7) NOT NULL,
	[end_time] [time](7) NOT NULL,
	[booking_mode] [int] NOT NULL,
	[slot_duration] [int] NULL,
	[max_queue_length] [int] NULL,
	[slot_key] [varchar](50) NULL,
	[is_deleted] [bit] NULL,
	[is_active] [bit] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[slot_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[doctor_timing]    Script Date: 15-10-2026 12:09:44 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[doctor_timing](
	[doctor_id] [int] NOT NULL,
	[avg_consultation_time] [float] NULL,
	[morning_avg] [float] NULL,
	[afternoon_avg] [float] NULL,
	[evening_avg] [float] NULL,
	[total_completed] [int] NULL,
	[last_updated] [datetime] NULL,
	[clinic_id] [varchar](50) NOT NULL,
 CONSTRAINT [PK_doctor_timing] PRIMARY KEY CLUSTERED 
(
	[doctor_id] ASC,
	[clinic_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[doctor_unavailability]    Script Date: 15-10-2026 12:09:44 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[doctor_unavailability](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[doctor_id] [int] NOT NULL,
	[unavailable_date] [date] NOT NULL,
	[reason] [nvarchar](255) NULL,
PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_doctor_unavailable] UNIQUE NONCLUSTERED 
(
	[doctor_id] ASC,
	[unavailable_date] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[family_members]    Script Date: 15-10-2026 12:09:44 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[family_members](
	[member_id] [int] IDENTITY(1,1) NOT NULL,
	[family_id] [int] NULL,
	[name] [nvarchar](100) NULL,
	[Gender_id] [int] NULL,
	[relation_id] [int] NULL,
	[DOB] [smalldatetime] NULL,
	[mobile_no] [nvarchar](50) NULL,
 CONSTRAINT [PK_family_members] PRIMARY KEY CLUSTERED 
(
	[member_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[favorite_doctors]    Script Date: 15-10-2026 12:09:44 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[favorite_doctors](
	[favorite_id] [int] IDENTITY(1,1) NOT NULL,
	[patient_id] [int] NOT NULL,
	[doctor_id] [int] NOT NULL,
	[is_favorite] [bit] NOT NULL,
	[created_at] [datetime] NOT NULL,
	[updated_at] [datetime] NULL,
	[clinic_id] [nvarchar](20) NULL,
PRIMARY KEY CLUSTERED 
(
	[favorite_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_fav] UNIQUE NONCLUSTERED 
(
	[patient_id] ASC,
	[doctor_id] ASC,
	[clinic_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Gender]    Script Date: 15-10-2026 12:09:44 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Gender](
	[gender_id] [int] NOT NULL,
	[gender] [nvarchar](20) NOT NULL
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Medicine_Master]    Script Date: 15-10-2026 12:09:44 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Medicine_Master](
	[medicine_id] [int] IDENTITY(1,1) NOT NULL,
	[medicine_name] [nvarchar](500) NULL,
	[medicine_type_id] [int] NULL,
 CONSTRAINT [PK_Medicine_Master] PRIMARY KEY CLUSTERED 
(
	[medicine_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_Medicine_Name_Type] UNIQUE NONCLUSTERED 
(
	[medicine_name] ASC,
	[medicine_type_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Medicine_Master_Backup]    Script Date: 15-10-2026 12:09:44 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Medicine_Master_Backup](
	[medicine_id] [int] IDENTITY(1,1) NOT NULL,
	[doctor_id] [int] NULL,
	[medicine_name] [nvarchar](500) NULL,
	[medicine_type_id] [int] NULL,
	[is_active] [bit] NOT NULL
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Medicine_Type]    Script Date: 15-10-2026 12:09:44 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Medicine_Type](
	[medicine_type_id] [int] IDENTITY(1,1) NOT NULL,
	[Medi_Type_Name] [nvarchar](100) NULL,
 CONSTRAINT [PK_Medicine_Type] PRIMARY KEY CLUSTERED 
(
	[medicine_type_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[notifications]    Script Date: 15-10-2026 12:09:44 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[notifications](
	[notification_id] [int] IDENTITY(1,1) NOT NULL,
	[patient_id] [int] NOT NULL,
	[title] [nvarchar](200) NOT NULL,
	[body] [nvarchar](1000) NOT NULL,
	[type] [varchar](40) NOT NULL,
	[ref_id] [varchar](40) NULL,
	[is_read] [bit] NOT NULL,
	[created_at] [datetime] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[notification_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[otp_verification]    Script Date: 15-10-2026 12:09:44 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[otp_verification](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[mobile_no] [varchar](15) NULL,
	[otp_hash] [varchar](255) NULL,
	[expires_at] [datetime] NULL,
	[attempts] [int] NULL,
	[is_verified] [bit] NULL,
	[created_at] [datetime] NULL,
PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[patient_records]    Script Date: 15-10-2026 12:09:44 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[patient_records](
	[prescription_id] [int] IDENTITY(1,1) NOT NULL,
	[patient_id] [int] NOT NULL,
	[doctor_id] [int] NULL,
	[prescription_date] [datetime] NULL,
	[symptoms] [nvarchar](max) NULL,
	[diagnosis] [nvarchar](max) NULL,
	[clinical_notes] [nvarchar](max) NULL,
	[follow_up_date] [date] NULL,
	[advice] [nvarchar](max) NULL,
	[created_at] [datetime] NULL,
	[user_type] [int] NULL,
	[appointment_id] [int] NULL,
	[clinic_id] [nvarchar](20) NULL,
PRIMARY KEY CLUSTERED 
(
	[prescription_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Patients]    Script Date: 15-10-2026 12:09:44 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Patients](
	[patient_id] [int] IDENTITY(1,1) NOT NULL,
	[name] [nvarchar](100) NULL,
	[mobile_no] [nvarchar](50) NULL,
	[email] [nvarchar](100) NULL,
	[Address] [nvarchar](100) NULL,
	[gender_id] [int] NULL,
	[DOB] [smalldatetime] NULL,
	[blood_group_id] [int] NULL,
	[weight] [nvarchar](50) NULL,
	[role_id] [int] NULL,
	[active_status] [int] NULL,
	[token] [nvarchar](max) NULL,
	[img_url] [nvarchar](max) NULL,
 CONSTRAINT [PK_userProfile] PRIMARY KEY CLUSTERED 
(
	[patient_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_patient_mobile] UNIQUE NONCLUSTERED 
(
	[mobile_no] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[PrescriptionMedicine]    Script Date: 15-10-2026 12:09:44 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[PrescriptionMedicine](
	[presc_med_id] [int] IDENTITY(1,1) NOT NULL,
	[prescription_id] [int] NOT NULL,
	[medicine_id] [int] NOT NULL,
	[medicine_type_id] [int] NOT NULL,
	[frequency] [varchar](50) NULL,
	[duration] [varchar](50) NULL,
	[timing] [varchar](50) NULL,
	[tablet_dosage] [varchar](20) NULL,
	[syrup_dosage_ml] [varchar](20) NULL,
	[inj_dosage] [varchar](20) NULL,
	[inj_route] [varchar](20) NULL,
	[drops_count] [varchar](10) NULL,
	[drops_application] [varchar](20) NULL,
	[lotion_apply_area] [varchar](50) NULL,
	[lotion_usage] [varchar](50) NULL,
	[spray_puffs] [varchar](20) NULL,
	[spray_usage] [varchar](20) NULL,
	[powder_dosage] [varchar](20) NULL,
	[powder_form] [varchar](50) NULL,
	[inhaler_puffs] [varchar](20) NULL,
	[inhaler_type] [varchar](30) NULL,
	[inhaler_technique] [varchar](50) NULL,
	[inhaler_usage] [varchar](50) NULL,
 CONSTRAINT [PK__Prescrip__80008E0F9924DF3F] PRIMARY KEY CLUSTERED 
(
	[presc_med_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[receptionist]    Script Date: 15-10-2026 12:09:44 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[receptionist](
	[recep_id] [int] IDENTITY(1,1) NOT NULL,
	[name] [nvarchar](100) NULL,
	[mobile_no] [nvarchar](50) NULL,
	[email] [nvarchar](100) NULL,
	[Address] [nvarchar](100) NULL,
	[gender_id] [int] NULL,
	[active_status] [int] NULL,
	[token] [nvarchar](max) NULL,
	[img_url] [nvarchar](max) NULL,
	[clinic_id] [nvarchar](50) NULL,
	[created_at] [datetime] NULL,
	[role_id] [int] NULL,
	[doctor_id] [int] NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[RefreshTokens]    Script Date: 15-10-2026 12:09:44 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[RefreshTokens](
	[id] [int] NOT NULL,
	[user_mobile] [nvarchar](50) NOT NULL,
	[refresh_token] [nvarchar](max) NOT NULL,
	[device_info] [nvarchar](500) NULL,
	[created_at] [datetime2](7) NULL,
	[expires_at] [datetime2](7) NOT NULL,
	[revoked] [bit] NULL,
	[role_id] [int] NULL,
 CONSTRAINT [PK__RefreshT__3213E83FC9D556E1] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Relations]    Script Date: 15-10-2026 12:09:44 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Relations](
	[relation_id] [int] NOT NULL,
	[relation] [nvarchar](50) NULL
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[reviews]    Script Date: 15-10-2026 12:09:44 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[reviews](
	[review_id] [int] IDENTITY(1,1) NOT NULL,
	[appointment_id] [int] NOT NULL,
	[doctor_id] [int] NOT NULL,
	[patient_id] [int] NOT NULL,
	[rating] [decimal](2, 1) NOT NULL,
	[comment] [nvarchar](500) NULL,
	[created_at] [datetime] NOT NULL,
	[reviewed_by_user_id] [int] NULL,
	[clinic_id] [nvarchar](20) NULL,
PRIMARY KEY CLUSTERED 
(
	[review_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[role]    Script Date: 15-10-2026 12:09:44 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[role](
	[role_id] [int] IDENTITY(1,1) NOT NULL,
	[role] [nvarchar](15) NULL
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[State]    Script Date: 15-10-2026 12:09:44 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[State](
	[state_id] [int] NOT NULL,
	[state] [nvarchar](50) NULL,
PRIMARY KEY CLUSTERED 
(
	[state_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_ADR_scheduled]    Script Date: 15-10-2026 12:09:44 ******/
CREATE NONCLUSTERED INDEX [IX_ADR_scheduled] ON [dbo].[AccountDeletionRequests]
(
	[status] ASC,
	[scheduled_for] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [UX_ADR_phone_role_pending]    Script Date: 15-10-2026 12:09:44 ******/
CREATE UNIQUE NONCLUSTERED INDEX [UX_ADR_phone_role_pending] ON [dbo].[AccountDeletionRequests]
(
	[phone] ASC,
	[role_id] ASC
)
WHERE ([status]='pending')
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IDX_APPOINTMENT_MAIN]    Script Date: 15-10-2026 12:09:44 ******/
CREATE NONCLUSTERED INDEX [IDX_APPOINTMENT_MAIN] ON [dbo].[appointments]
(
	[doctor_id] ASC,
	[appointment_date] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IDX_BOOKING_TYPE]    Script Date: 15-10-2026 12:09:44 ******/
CREATE NONCLUSTERED INDEX [IDX_BOOKING_TYPE] ON [dbo].[appointments]
(
	[doctor_id] ASC,
	[appointment_date] ASC,
	[booking_type] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IDX_QUEUE]    Script Date: 15-10-2026 12:09:44 ******/
CREATE NONCLUSTERED INDEX [IDX_QUEUE] ON [dbo].[appointments]
(
	[doctor_id] ASC,
	[appointment_date] ASC,
	[queue_number] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IDX_SLOT]    Script Date: 15-10-2026 12:09:44 ******/
CREATE NONCLUSTERED INDEX [IDX_SLOT] ON [dbo].[appointments]
(
	[doctor_id] ASC,
	[appointment_date] ASC,
	[start_time] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [UQ_queue]    Script Date: 15-10-2026 12:09:44 ******/
CREATE UNIQUE NONCLUSTERED INDEX [UQ_queue] ON [dbo].[appointments]
(
	[doctor_id] ASC,
	[appointment_date] ASC,
	[slot_id] ASC,
	[queue_number] ASC
)
WHERE ([queue_number] IS NOT NULL)
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_doctor_leave_lookup]    Script Date: 15-10-2026 12:09:44 ******/
CREATE NONCLUSTERED INDEX [IX_doctor_leave_lookup] ON [dbo].[doctor_leave]
(
	[doctor_id] ASC,
	[is_active] ASC,
	[from_date] ASC,
	[to_date] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [UQ__doctor_q__355A60F078E22094]    Script Date: 15-10-2026 12:09:44 ******/
CREATE UNIQUE NONCLUSTERED INDEX [UQ__doctor_q__355A60F078E22094] ON [dbo].[doctor_queue]
(
	[doctor_id] ASC,
	[queue_date] ASC,
	[slot_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [idx_slot_key]    Script Date: 15-10-2026 12:09:44 ******/
CREATE UNIQUE NONCLUSTERED INDEX [idx_slot_key] ON [dbo].[doctor_time_slots]
(
	[availability_id] ASC,
	[start_time] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_notifications_patient_created]    Script Date: 15-10-2026 12:09:44 ******/
CREATE NONCLUSTERED INDEX [IX_notifications_patient_created] ON [dbo].[notifications]
(
	[patient_id] ASC,
	[created_at] DESC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_reviews_doctor]    Script Date: 15-10-2026 12:09:44 ******/
CREATE NONCLUSTERED INDEX [IX_reviews_doctor] ON [dbo].[reviews]
(
	[doctor_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_reviews_patient]    Script Date: 15-10-2026 12:09:44 ******/
CREATE NONCLUSTERED INDEX [IX_reviews_patient] ON [dbo].[reviews]
(
	[patient_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [UX_reviews_appointment]    Script Date: 15-10-2026 12:09:44 ******/
CREATE UNIQUE NONCLUSTERED INDEX [UX_reviews_appointment] ON [dbo].[reviews]
(
	[appointment_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
ALTER TABLE [dbo].[AccountDeletionRequests] ADD  DEFAULT ('pending') FOR [status]
GO
ALTER TABLE [dbo].[AccountDeletionRequests] ADD  DEFAULT (getdate()) FOR [requested_at]
GO
ALTER TABLE [dbo].[AccountDeletionRequests] ADD  DEFAULT (getutcdate()) FOR [created_at]
GO
ALTER TABLE [dbo].[appointments] ADD  DEFAULT ('booked') FOR [status]
GO
ALTER TABLE [dbo].[appointments] ADD  DEFAULT (getdate()) FOR [created_at]
GO
ALTER TABLE [dbo].[appointments] ADD  CONSTRAINT [DF_is_reviewed]  DEFAULT ((0)) FOR [is_reviewed]
GO
ALTER TABLE [dbo].[appointments] ADD  DEFAULT ((0)) FOR [is_arrived]
GO
ALTER TABLE [dbo].[clinic_images] ADD  DEFAULT ((0)) FOR [active_status]
GO
ALTER TABLE [dbo].[clinic_images] ADD  DEFAULT (getdate()) FOR [created_at]
GO
ALTER TABLE [dbo].[clinics] ADD  CONSTRAINT [DF__clinics__created__56E8E7AB]  DEFAULT (getdate()) FOR [created_at]
GO
ALTER TABLE [dbo].[doctor_availability] ADD  DEFAULT ((0)) FOR [is_enabled]
GO
ALTER TABLE [dbo].[doctor_availability] ADD  DEFAULT (getdate()) FOR [created_at]
GO
ALTER TABLE [dbo].[doctor_leave] ADD  CONSTRAINT [DF_doctor_leave_active]  DEFAULT ((1)) FOR [is_active]
GO
ALTER TABLE [dbo].[doctor_leave] ADD  CONSTRAINT [DF_doctor_leave_created]  DEFAULT (getdate()) FOR [created_at]
GO
ALTER TABLE [dbo].[doctor_login] ADD  DEFAULT ((0)) FOR [is_online]
GO
ALTER TABLE [dbo].[Doctor_Medicine] ADD  DEFAULT ((1)) FOR [is_active]
GO
ALTER TABLE [dbo].[Doctor_Medicine] ADD  DEFAULT (getdate()) FOR [created_at]
GO
ALTER TABLE [dbo].[doctor_queue] ADD  DEFAULT ((0)) FOR [current_serving]
GO
ALTER TABLE [dbo].[doctor_queue] ADD  DEFAULT ((0)) FOR [total_queue]
GO
ALTER TABLE [dbo].[doctor_queue] ADD  DEFAULT ((1)) FOR [queue_status]
GO
ALTER TABLE [dbo].[doctor_queue] ADD  DEFAULT (getdate()) FOR [created_at]
GO
ALTER TABLE [dbo].[doctor_queue] ADD  DEFAULT ((0)) FOR [completed_count]
GO
ALTER TABLE [dbo].[doctor_queue] ADD  DEFAULT ((0)) FOR [current_patient_id]
GO
ALTER TABLE [dbo].[doctor_queue] ADD  DEFAULT ((0)) FOR [slot_id]
GO
ALTER TABLE [dbo].[doctor_queue] ADD  DEFAULT ((0)) FOR [booking_closed]
GO
ALTER TABLE [dbo].[doctor_time_slots] ADD  DEFAULT ((0)) FOR [is_deleted]
GO
ALTER TABLE [dbo].[doctor_time_slots] ADD  DEFAULT ((1)) FOR [is_active]
GO
ALTER TABLE [dbo].[favorite_doctors] ADD  DEFAULT ((1)) FOR [is_favorite]
GO
ALTER TABLE [dbo].[favorite_doctors] ADD  DEFAULT (getdate()) FOR [created_at]
GO
ALTER TABLE [dbo].[notifications] ADD  DEFAULT ((0)) FOR [is_read]
GO
ALTER TABLE [dbo].[notifications] ADD  DEFAULT (getdate()) FOR [created_at]
GO
ALTER TABLE [dbo].[otp_verification] ADD  DEFAULT ((0)) FOR [attempts]
GO
ALTER TABLE [dbo].[otp_verification] ADD  DEFAULT ((0)) FOR [is_verified]
GO
ALTER TABLE [dbo].[otp_verification] ADD  DEFAULT (getdate()) FOR [created_at]
GO
ALTER TABLE [dbo].[patient_records] ADD  DEFAULT (getdate()) FOR [prescription_date]
GO
ALTER TABLE [dbo].[patient_records] ADD  DEFAULT (getdate()) FOR [created_at]
GO
ALTER TABLE [dbo].[reviews] ADD  DEFAULT (getdate()) FOR [created_at]
GO
ALTER TABLE [dbo].[clinic_images]  WITH CHECK ADD FOREIGN KEY([clinic_id])
REFERENCES [dbo].[clinics] ([clinic_id])
GO
ALTER TABLE [dbo].[Doctor_Medicine]  WITH CHECK ADD  CONSTRAINT [FK_DoctorMedicine_Medicine] FOREIGN KEY([medicine_id])
REFERENCES [dbo].[Medicine_Master] ([medicine_id])
GO
ALTER TABLE [dbo].[Doctor_Medicine] CHECK CONSTRAINT [FK_DoctorMedicine_Medicine]
GO
ALTER TABLE [dbo].[doctor_time_slots]  WITH CHECK ADD FOREIGN KEY([availability_id])
REFERENCES [dbo].[doctor_availability] ([availability_id])
GO
ALTER TABLE [dbo].[PrescriptionMedicine]  WITH CHECK ADD  CONSTRAINT [FK__Prescript__medic__2EA5EC27] FOREIGN KEY([medicine_type_id])
REFERENCES [dbo].[Medicine_Type] ([medicine_type_id])
GO
ALTER TABLE [dbo].[PrescriptionMedicine] CHECK CONSTRAINT [FK__Prescript__medic__2EA5EC27]
GO
ALTER TABLE [dbo].[PrescriptionMedicine]  WITH CHECK ADD  CONSTRAINT [FK__Prescript__presc__2CBDA3B5] FOREIGN KEY([prescription_id])
REFERENCES [dbo].[patient_records] ([prescription_id])
GO
ALTER TABLE [dbo].[PrescriptionMedicine] CHECK CONSTRAINT [FK__Prescript__presc__2CBDA3B5]
GO
ALTER TABLE [dbo].[PrescriptionMedicine]  WITH CHECK ADD  CONSTRAINT [FK_PrescriptionMedicine_Medicine] FOREIGN KEY([medicine_id])
REFERENCES [dbo].[Medicine_Master] ([medicine_id])
GO
ALTER TABLE [dbo].[PrescriptionMedicine] CHECK CONSTRAINT [FK_PrescriptionMedicine_Medicine]
GO
ALTER TABLE [dbo].[appointments]  WITH CHECK ADD  CONSTRAINT [CHK_booking_rules] CHECK  (([booking_type]=(1) AND [queue_number] IS NOT NULL AND [queue_id] IS NOT NULL OR [booking_type]=(2) AND [start_time] IS NOT NULL AND [end_time] IS NOT NULL AND [queue_number] IS NULL AND [queue_id] IS NULL))
GO
ALTER TABLE [dbo].[appointments] CHECK CONSTRAINT [CHK_booking_rules]
GO
ALTER TABLE [dbo].[appointments]  WITH CHECK ADD  CONSTRAINT [CHK_booking_type] CHECK  (([booking_type]=(2) OR [booking_type]=(1)))
GO
ALTER TABLE [dbo].[appointments] CHECK CONSTRAINT [CHK_booking_type]
GO
ALTER TABLE [dbo].[reviews]  WITH CHECK ADD  CONSTRAINT [CK_reviews_rating] CHECK  (([rating]>=(0.5) AND [rating]<=(5.0) AND floor([rating]*(2))=[rating]*(2)))
GO
ALTER TABLE [dbo].[reviews] CHECK CONSTRAINT [CK_reviews_rating]
GO
/****** Object:  StoredProcedure [dbo].[ManageRefreshToken]    Script Date: 15-10-2026 12:09:44 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- 3) Procedure ---------------------------------------------------------------
CREATE PROCEDURE [dbo].[ManageRefreshToken]
    @operation       NVARCHAR(20),       -- 'insert' | 'get' | 'revoke' | 'AutoTask'

    -- Insert fields
    @user_mobile     NVARCHAR(50) = NULL,
    @refresh_token   NVARCHAR(MAX) = NULL,
    @device_info     NVARCHAR(500) = NULL,
    @ip_address      NVARCHAR(100) = NULL,
    @expires_at      DATETIME2 = NULL,
    @role            NVARCHAR(20) = NULL -- 'doctor' | 'patient' | 'receptionist'
AS
BEGIN
    SET NOCOUNT ON;

    -- Insert Operation --------------------------------------------
    IF @operation = 'insert'
    BEGIN
        DECLARE @role_id TINYINT =
            CASE LOWER(LTRIM(RTRIM(ISNULL(@role, ''))))
                WHEN 'doctor'       THEN 1
                WHEN 'patient'      THEN 2
                WHEN 'receptionist' THEN 3
            END;

        -- Refuse to create a session whose role we cannot name. A NULL role_id
        -- here is exactly what produced the receptionist?doctor bug.
        IF @role_id IS NULL
        BEGIN
            RAISERROR('ManageRefreshToken: @role must be doctor, patient or receptionist.', 16, 1);
            RETURN;
        END

        DECLARE @new INT;

        BEGIN TRANSACTION;

            -- UPDLOCK + HOLDLOCK: two logins landing together must not read the
            -- same MAX(id) and collide on the primary key.
            SELECT @new = ISNULL(MAX(id), 0) + 1
            FROM dbo.RefreshTokens WITH (UPDLOCK, HOLDLOCK);

            INSERT INTO dbo.RefreshTokens
                (id, user_mobile, refresh_token, device_info, created_at, expires_at, role_id, revoked)
            VALUES
                (@new, @user_mobile, @refresh_token, @device_info, SYSUTCDATETIME(), @expires_at, @role_id, 0);

        COMMIT TRANSACTION;

        SELECT @new AS id, @role_id AS role_id;
        RETURN;
    END


    -- Get Operation ------------------------------------------------
    IF @operation = 'get'
    BEGIN
        -- SELECT * carries role_id, which is what refreshAccessToken reads.
        SELECT TOP 1 *
        FROM dbo.RefreshTokens
        WHERE refresh_token = @refresh_token
          AND revoked = 0
          AND expires_at > SYSUTCDATETIME();
        RETURN;
    END


    -- Revoke Operation ---------------------------------------------
    IF @operation = 'revoke'
    BEGIN
        -- Callers revoke every live token of one mobile (login + refresh), or a
        -- single token when they have it.
        UPDATE dbo.RefreshTokens
        SET revoked = 1
        WHERE revoked != 1
          AND (
                (@refresh_token IS NOT NULL AND refresh_token = @refresh_token)
             OR (@refresh_token IS NULL AND @user_mobile IS NOT NULL AND user_mobile = @user_mobile)
              );

        SELECT @@ROWCOUNT AS revoked_count;
        RETURN;
    END


    -- Housekeeping --------------------------------------------------
    IF @operation = 'AutoTask'
    BEGIN
        DELETE FROM dbo.RefreshTokens
        WHERE expires_at < SYSUTCDATETIME();

        DELETE FROM dbo.RefreshTokens
        WHERE id IN (
            SELECT id FROM (
                SELECT id,
                       ROW_NUMBER() OVER (
                         PARTITION BY user_mobile ORDER BY created_at DESC
                       ) AS rn
                FROM dbo.RefreshTokens
            ) t
            WHERE t.rn > 5
        );
        RETURN;
    END

    -- Invalid Operation --------------------------------------------
    SELECT 'Invalid operation. Use insert, get, revoke or AutoTask.' AS error_message;
END

GO
/****** Object:  StoredProcedure [dbo].[sp_appointment]    Script Date: 15-10-2026 12:09:44 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[sp_appointment]
    @operation NVARCHAR(50) = NULL,
    @doctor_id INT = NULL,
    @patient_id INT = NULL,
    @family_id INT = NULL,
    @appointment_id INT = NULL,
    @appointment_date DATE = NULL,
    @user_type INT = NULL,
    @start_time TIME = NULL,
    @default_avg INT = 7,
    @slot_id int = 0,
    @patient_id_local INT = NULL,
    @queue_id INT = NULL,
    @token NVARCHAR(MAX) = NULL,
    @is_next INT = NULL,
    @symptoms NVARCHAR(MAX) = NULL,
    @clinic_id NVARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    --------------------------------------------------
    -- ALL VARIABLE DECLARATIONS
    --------------------------------------------------

    -- BOOK
    DECLARE @booking_mode INT,
            @slot_duration INT,
            @slot_start TIME,
            @slot_end TIME,
            @minutes INT,
            @next_queue INT,
            @temp_slot int,
            @total_queue int,
            @max_queue_length int;

    -- GET_AVAILABILITY
    DECLARE @day NVARCHAR(20);

    -- GET_MONTH_SLOTS
    DECLARE @start_date DATE;
    DECLARE @end_date DATE;

    -- QUEUE_NEXT / QUEUE_SKIP / SHARED
    DECLARE @booking_type INT;
    DECLARE @current_queue INT;
    DECLARE @next_patient_id INT;
    DECLARE @next_appointment_id INT;

    -- QUEUE_NEXT
    DECLARE @current_serving INT;
    DECLARE @qn_next_queue INT;
    DECLARE @qn_next_patient_id INT;

    -- QUEUE_SKIP
    DECLARE @skip_current_serving INT;
    DECLARE @skip_next_queue INT;
    DECLARE @skip_next_patient_id INT;

    -- QUEUE_RECALL
    DECLARE @recall_queue_number INT;

    -- QUEUE_ESTIMATE
    DECLARE @my_queue INT;
    DECLARE @patients_ahead INT;
    DECLARE @estimated_wait INT;

    -- RESCHEDULE
    DECLARE @old_booking_type INT;
    DECLARE @old_status NVARCHAR(50);

    -- START_SESSION
    DECLARE @ss_queue_number INT;
    DECLARE @ss_patient_id INT;

    -- END_SESSION
    DECLARE @es_current_serving INT;
    DECLARE @consult_time INT;
    DECLARE @hour INT;

    -- DOCTOR_AVG_TIME
    DECLARE @avg_time INT;

    -- QUEUE_ESTIMATE_SMART / QUEUE_PREVIEW_ESTIMATE
    DECLARE @base_avg FLOAT;
    DECLARE @adaptive_avg FLOAT;
    DECLARE @queue_size INT;
    DECLARE @estimated_time FLOAT;
    DECLARE @started_at DATETIME;
    DECLARE @time_passed INT;
    DECLARE @expected_completed FLOAT;
    DECLARE @actual_completed INT;
    DECLARE @delay_count FLOAT;
    DECLARE @adjustment FLOAT;
    DECLARE @arrival_time DATETIME;
    DECLARE @multiplier FLOAT;
    DECLARE @queue_started_time DATETIME;
    DECLARE @slot_start_dt DATETIME;
    DECLARE @mins_from_mid INT;

    BEGIN TRY

        --------------------------------------------------
        -- BOOK APPOINTMENT
        --------------------------------------------------
        IF @operation = 'BOOK'
        BEGIN
            BEGIN TRY
                BEGIN TRANSACTION;

                IF EXISTS
                (
                    SELECT 1
                    FROM doctor_unavailability
                    WHERE doctor_id = @doctor_id
                          AND unavailable_date = @appointment_date
                )
                    RAISERROR('Doctor Unavailable', 16, 1);

                IF EXISTS
                (
                    SELECT 1
                    FROM appointments
                    WHERE doctor_id = @doctor_id
                          AND patient_id = @patient_id
                          AND user_type = @user_type
                          AND appointment_date = @appointment_date
                          AND slot_id = @slot_id
                          AND status = 'booked'
                )
                    RAISERROR('Already booked', 16, 1);

                --------------------------------------------------
                -- GET SLOT / MODE
                --------------------------------------------------

                IF (@start_time IS NULL)
                BEGIN
                    SET @booking_mode = 1;
                END
                ELSE
                BEGIN
                    SET @booking_mode = 2;
                END;

                IF @booking_mode IS NULL
                    RAISERROR('No valid slot found', 16, 1);

                --------------------------------------------------
                -- SLOT BOOKING
                --------------------------------------------------
                IF @booking_mode = 2
                BEGIN
                    --------------------------------------------------
                    -- ?? FETCH SLOT DATA
                    --------------------------------------------------
                    SELECT @slot_start = start_time,
                           @slot_end = end_time,
                           @slot_duration = slot_duration
                    FROM doctor_time_slots
                    WHERE slot_id = @slot_id;

                    --------------------------------------------------
                    -- VALIDATIONS
                    --------------------------------------------------
                    IF @slot_duration IS NULL
                        RAISERROR('Slot duration not defined', 16, 1);

                    IF @start_time < @slot_start
                       OR @start_time >= @slot_end
                        RAISERROR('Invalid slot time range', 16, 1);

                    SET @minutes = DATEDIFF(MINUTE, @slot_start, @start_time);

                    IF @minutes % @slot_duration <> 0
                        RAISERROR('Invalid slot interval', 16, 1);

                    --------------------------------------------------
                    -- INSERT
                    --------------------------------------------------
                    INSERT INTO appointments
                    (
                        doctor_id,
                        patient_id,
                        user_type,
                        appointment_date,
                        start_time,
                        end_time,
                        booking_type,
                        slot_id,
                        queue_number,
                        queue_id,
                        symptoms,
						clinic_id
                    )
                    VALUES
                    (   @doctor_id,
                        @patient_id,
                        @user_type,
                        @appointment_date,
                        @start_time,
                        DATEADD(MINUTE, @slot_duration, @start_time), -- ? FIXED
                        2,
                        @slot_id,
                        NULL,
                        NULL,
                        @symptoms,
						@clinic_id
                    );
                END

                --------------------------------------------------
                -- QUEUE BOOKING
                --------------------------------------------------
                ELSE IF @booking_mode = 1
                BEGIN
                    IF @appointment_date <> CAST(GETDATE() AS DATE)
                        RAISERROR('Queue only for today', 16, 1);

                    --------------------------------------------------
                    -- GET NEXT QUEUE NUMBER
                    --------------------------------------------------
                    SELECT @next_queue = ISNULL(MAX(queue_number), 0) + 1
                    FROM appointments WITH (UPDLOCK, HOLDLOCK)
                    WHERE doctor_id = @doctor_id
                          AND appointment_date = @appointment_date
                          AND slot_id = @slot_id;

                    --------------------------------------------------
                    -- UPSERT doctor_queue + GET queue_id
                    --------------------------------------------------
                    SELECT @temp_slot = queue_id,
                           @max_queue_length = max_queue,
                           @total_queue = total_queue
                    FROM doctor_queue
                    WHERE doctor_id = @doctor_id
                          AND slot_id = @slot_id
                          AND queue_date = @appointment_date
						   AND (@clinic_id IS NULL OR clinic_id = @clinic_id OR clinic_id IS NULL);


                    if (isnull(@temp_slot, 0) > 0)
                    BEGIN
                        IF (ISNULL(@total_queue, 0) + 1 > @max_queue_length)
                            RAISERROR('Queue Full', 16, 1);

                        UPDATE doctor_queue
                        SET total_queue = ISNULL(total_queue, 0) + 1,
                            clinic_id   = COALESCE(clinic_id, @clinic_id)
                        where queue_id = @temp_slot;

                    END
                    else
                    BEGIN
                        INSERT INTO doctor_queue
                        (
                            slot_id,
                            doctor_id,
                            queue_date,
                            total_queue,
                            current_serving,
                            current_patient_id,
                            queue_status,
                            completed_count,
                            max_queue,
							   clinic_id  
                        )
                        SELECT @slot_id,
                               @doctor_id,
                               @appointment_date,
                               1,
                               0,
                               @patient_id,
                               0,
                               0,
                               ts.max_queue_length,
							    @clinic_id  
                        FROM doctor_time_slots ts
                        WHERE ts.slot_id = @slot_id;
                    END;



                    --------------------------------------------------
                    -- GET queue_id
                    --------------------------------------------------
                    SELECT @queue_id = queue_id
                    FROM doctor_queue
                    WHERE doctor_id = @doctor_id
                          AND queue_date = @appointment_date
                          AND slot_id = @slot_id
						   AND (@clinic_id IS NULL OR clinic_id = @clinic_id OR clinic_id IS NULL);

                    --------------------------------------------------
                    -- INSERT APPOINTMENT
                    --------------------------------------------------
                    INSERT INTO appointments
                    (
                        doctor_id,
                        patient_id,
                        user_type,
                        appointment_date,
                        booking_type,
                        queue_number,
                        queue_id,
                        slot_id,
                        symptoms,
						clinic_id
                    )
                    VALUES
                    (@doctor_id,
                     @patient_id,
                     @user_type,
                     @appointment_date,
                     1  ,
                     @next_queue,
                     @queue_id,
                     @slot_id,
                     @symptoms,
					 @clinic_id
                    );
                END

                COMMIT;

                SELECT 1 AS success,
                       'Booked Successfully' AS message;
            END TRY
            BEGIN CATCH
                ROLLBACK;

                SELECT 0 AS success,
                       ERROR_MESSAGE() AS message,
                       ERROR_MESSAGE() AS error;
            END CATCH
        END

        --------------------------------------------------
        -- GET AVAILABILITY
        --------------------------------------------------
        IF @operation = 'GET_AVAILABILITY'
        BEGIN
            SET @day = DATENAME(WEEKDAY, @appointment_date);

            SELECT ts.slot_id,
                   ts.start_time,
                   ts.end_time,
                   ts.booking_mode,
                   ts.slot_duration,
                   (
                       SELECT COUNT(*)
                       FROM appointments a
                       WHERE a.doctor_id = @doctor_id
                             AND a.appointment_date = @appointment_date
                             AND a.start_time = ts.start_time
                             AND a.status = 'booked'
                   ) AS booked_count
            FROM doctor_availability da
                JOIN doctor_time_slots ts
                    ON da.availability_id = ts.availability_id
            WHERE da.doctor_id = @doctor_id
                  AND da.day_of_week = @day
                  AND da.is_enabled = 1
				   AND (da.clinic_id = @clinic_id OR da.clinic_id IS NULL OR @clinic_id IS NULL); -- ? ADD;
        END

        --------------------------------------------------
        -- CANCEL
        --------------------------------------------------
        IF @operation = 'CANCEL_APPOINTMENT'
        BEGIN


            --------------------------------------------------
            -- GET QUEUE ID FROM APPOINTMENT
            --------------------------------------------------
            SELECT @queue_id = queue_id
            FROM appointments
            WHERE appointment_id = @appointment_id;

            --------------------------------------------------
            -- UPDATE APPOINTMENT STATUS
            --------------------------------------------------
            UPDATE appointments
            SET status = 'cancelled'
            WHERE appointment_id = @appointment_id;

            --------------------------------------------------
            -- REDUCE QUEUE COUNT
            --------------------------------------------------
            IF @queue_id IS NOT NULL
            BEGIN
                UPDATE doctor_queue
                SET total_queue = CASE
                                      WHEN total_queue > 0 THEN
                                          total_queue - 1
                                      ELSE
                                          0
                                  END
                WHERE queue_id = @queue_id;
            END

            SELECT 1 AS success,
                   'Cancelled Successfully' AS message;
        END

        ----------------------------------------------------
        ---- GET MONTH SLOTS
        ----------------------------------------------------
        --IF @operation = 'GET_MONTH_SLOTS'
        --BEGIN
        --    SET @start_date = CAST(GETDATE() AS DATE);
        --    SET @end_date = EOMONTH(@start_date);

        --    ;WITH DateCTE
        --    AS (SELECT @start_date AS booking_date
        --        UNION ALL
        --        SELECT DATEADD(DAY, 1, booking_date)
        --        FROM DateCTE
        --        WHERE booking_date < @end_date
        --       ),
        --          AvailableDays
        --    AS (SELECT d.booking_date,
        --               da.availability_id
        --        FROM DateCTE d
        --            JOIN doctor_availability da
        --                ON LOWER(LTRIM(RTRIM(da.day_of_week))) = LOWER(DATENAME(WEEKDAY, d.booking_date))
        --                   AND da.doctor_id = @doctor_id
        --                   AND da.is_enabled = 1
        --       ),
        --          Slots
        --    AS (SELECT ad.booking_date,
        --               ts.start_time,
        --               ts.end_time,
        --               ts.slot_duration
        --        FROM AvailableDays ad
        --            JOIN doctor_time_slots ts
        --                ON ts.availability_id = ad.availability_id
        --        WHERE ts.booking_mode = 2
        --       ),
        --          SlotCTE
        --    AS (SELECT booking_date,
        --               start_time,
        --               end_time,
        --               slot_duration,
        --               start_time AS slot_time
        --        FROM Slots
        --        UNION ALL
        --        SELECT booking_date,
        --               start_time,
        --               end_time,
        --               slot_duration,
        --               DATEADD(MINUTE, slot_duration, slot_time)
        --        FROM SlotCTE
        --        WHERE DATEADD(MINUTE, slot_duration, slot_time) < end_time
        --       )
        --    SELECT s.booking_date,
        --           s.slot_time AS start_time,
        --           DATEADD(MINUTE, s.slot_duration, s.slot_time) AS end_time,
        --           1 AS is_booked
        --    FROM SlotCTE s
        --        INNER JOIN appointments a
        --            ON a.doctor_id = @doctor_id
        --               AND a.appointment_date = s.booking_date
        --               AND a.start_time = s.slot_time
        --               AND a.status = 'booked'
        --    ORDER BY s.booking_date,
        --             s.slot_time
        --    OPTION (MAXRECURSION 1000);
        --END
		IF @operation = 'GET_MONTH_SLOTS'
BEGIN
    SET @start_date = CAST(GETDATE() AS DATE);
    --SET @end_date = EOMONTH(@start_date);
	SET @end_date = EOMONTH(DATEADD(MONTH, 1, @start_date));


    ;WITH DateCTE AS (
        SELECT @start_date AS booking_date
        UNION ALL
        SELECT DATEADD(DAY, 1, booking_date)
        FROM DateCTE
        WHERE booking_date < @end_date
    ),
    AvailableDays AS (
        SELECT d.booking_date, da.availability_id
        FROM DateCTE d
        JOIN doctor_availability da
            ON LOWER(LTRIM(RTRIM(da.day_of_week))) = LOWER(DATENAME(WEEKDAY, d.booking_date))
           AND da.doctor_id = @doctor_id
           AND da.clinic_id = @clinic_id
           AND da.is_enabled = 1
    ),
    --Slots AS (
    --    SELECT ad.booking_date, ts.start_time, ts.end_time, ts.slot_duration
    --    FROM AvailableDays ad
    --    JOIN doctor_time_slots ts ON ts.availability_id = ad.availability_id
    --    WHERE ts.booking_mode = 2
	  Slots AS (
        SELECT ad.booking_date, ts.start_time, ts.end_time, ts.slot_duration
        FROM AvailableDays ad
        JOIN doctor_time_slots ts ON ts.availability_id = ad.availability_id
        WHERE ts.booking_mode IN (2, 3)   -- ? 2 la IN (2,3) kar
   
    ),
    SlotCTE AS (
        SELECT booking_date, start_time, end_time, slot_duration, start_time AS slot_time
        FROM Slots
        UNION ALL
        SELECT booking_date, start_time, end_time, slot_duration,
               DATEADD(MINUTE, slot_duration, slot_time)
        FROM SlotCTE
        WHERE DATEADD(MINUTE, slot_duration, slot_time) < end_time
    )
    SELECT s.booking_date,
           s.slot_time AS start_time,
           DATEADD(MINUTE, s.slot_duration, s.slot_time) AS end_time,
           1 AS is_booked
    FROM SlotCTE s
    INNER JOIN appointments a
        ON a.doctor_id        = @doctor_id
       AND a.clinic_id        = @clinic_id
       AND a.appointment_date = s.booking_date
       AND a.start_time       = s.slot_time
       AND a.status           = 'booked'
    ORDER BY s.booking_date, s.slot_time
    OPTION (MAXRECURSION 1000);
END


        --------------------------------------------------
        -- QUEUE STATUS
        --------------------------------------------------
        IF @operation = 'QUEUE_STATUS'
        BEGIN
            SELECT ISNULL(total_queue, 0) AS total_queue,
                   ISNULL(current_serving, 0) AS current_serving,
                   ISNULL(total_queue, 0) - ISNULL(current_serving, 0) AS waiting_count
            FROM doctor_queue
            WHERE doctor_id = @doctor_id
                  AND queue_date = @appointment_date;
        END

        --------------------------------------------------
        -- CANCEL APPOINTMENT BY DOCTOR (ONLY SLOT)
        --------------------------------------------------
        IF @operation = 'CANCEL_BY_DOCTOR'
        BEGIN
            BEGIN TRY
                BEGIN TRANSACTION;

                --------------------------------------------------
                -- VALIDATE APPOINTMENT
                --------------------------------------------------
                SELECT @booking_type = booking_type
                FROM appointments
                WHERE appointment_id = @appointment_id
                      AND doctor_id = @doctor_id;

                IF @booking_type IS NULL
                    RAISERROR('Invalid appointment', 16, 1);

                --------------------------------------------------
                -- ?? ONLY SLOT ALLOWED
                --------------------------------------------------
                IF @booking_type <> 2
                    RAISERROR('Doctor can cancel only slot appointments', 16, 1);

                --------------------------------------------------
                -- UPDATE STATUS
                --------------------------------------------------
                UPDATE appointments
                SET status = 'CancleD'
                WHERE appointment_id = @appointment_id;

                COMMIT;

                SELECT 1 AS success,
                       'Slot appointment cancelled successfully' AS message;

            END TRY
            BEGIN CATCH
                ROLLBACK;

                SELECT 0 AS success,
                       ERROR_MESSAGE() AS message,
                       ERROR_MESSAGE() AS error;
            END CATCH
        END

        --------------------------------------------------
        -- QUEUE START
        --------------------------------------------------
        IF @operation = 'QUEUE_START'
        BEGIN
            --------------------------------------------------
            -- START / CREATE QUEUE
            --------------------------------------------------

            UPDATE doctor_queue
            SET queue_status = 1,
                started_at = GETDATE(),
                current_serving = 0
            --current_queue_no = NULL
            WHERE doctor_id = @doctor_id
                  AND queue_id = @queue_id
                  AND queue_date = CAST(GETDATE() AS DATE);

            --MERGE doctor_queue AS dq
            --USING
            --(
            --    SELECT @doctor_id AS doctor_id,
            --           CAST(GETDATE() AS DATE) AS queue_date
            --) src
            --ON dq.doctor_id = src.doctor_id
            --   AND dq.queue_date = src.queue_date
            --WHEN MATCHED THEN
            --    UPDATE SET queue_status = 1,
            --               started_at = GETDATE(),
            --               current_serving = 0,
            --               current_queue_no = NULL
            --WHEN NOT MATCHED THEN
            --    INSERT
            --    (
            --        doctor_id,
            --        queue_date,
            --        queue_status,
            --        current_serving,
            --        total_queue,
            --        current_queue_no,
            --        completed_count,
            --        started_at
            --    )
            --    VALUES
            --    (@doctor_id, CAST(GETDATE() AS DATE), 1, 0, 0, NULL, 0, GETDATE());

            --------------------------------------------------
            -- ?? RETURN TOKENS (CORRECT LOGIC)
            --------------------------------------------------
            SELECT a.appointment_id,
                   a.queue_number,

                   --------------------------------------------------
                   -- ?? TOKEN RESOLUTION
                   --------------------------------------------------
                   CASE
                       WHEN a.user_type = 1 THEN
                           p.token
                       WHEN a.user_type = 2 THEN
                           p2.token
                   END AS token
            FROM appointments a

                --------------------------------------------------
                -- DIRECT PATIENT
                --------------------------------------------------
                LEFT JOIN patients p
                    ON a.user_type = 1
                       AND p.patient_id = a.patient_id

                --------------------------------------------------
                -- FAMILY MEMBER ? MAP TO PATIENT
                --------------------------------------------------
                LEFT JOIN family_members fm
                    ON a.user_type = 2
                       AND fm.member_id = a.patient_id
                LEFT JOIN patients p2
                    ON fm.family_id = p2.patient_id
            WHERE a.doctor_id = @doctor_id
                  AND queue_id = @queue_id
                  AND a.appointment_date = CAST(GETDATE() AS DATE)
                  AND a.booking_type = 1
                  AND a.status IN ( 'booked', 'in_progress' )
            ORDER BY a.queue_number;

        END

        --------------------------------------------------
        -- GET TODAY QUEUE BY DOCTOR (WITH SLOT TIMES)
        --------------------------------------------------
        IF @operation = 'GET_TODAY_QUEUE'
        BEGIN
            BEGIN TRY

                --------------------------------------------------
                -- FETCH QUEUES WITH SESSION TIME (slot )
                --------------------------------------------------
                SELECT dq.queue_id,
                       dq.doctor_id,
                       dq.queue_date,
                       dq.slot_id,

                       --------------------------------------------------
                       -- ?? CORRECT SLOT TIME (DIRECT FROM SLOT_ID)
                       --------------------------------------------------
                       ts.start_time,
                       ts.end_time,
                       dq.queue_status,
                       dq.current_serving,
                       dq.current_patient_id,
                       dq.total_queue,
                       dq.completed_count,
                       dq.started_at,
                       dq.stopped_at
                FROM doctor_queue dq

                    --------------------------------------------------
                    -- ?? DIRECT SLOT JOIN (IMPORTANT)
                    --------------------------------------------------
                    LEFT JOIN doctor_time_slots ts
                        ON dq.slot_id = ts.slot_id
                    LEFT JOIN doctor_availability da
                        ON da.availability_id = ts.availability_id

                --------------------------------------------------
                -- FILTER
                --------------------------------------------------
                WHERE dq.doctor_id = @doctor_id
                      AND dq.queue_date = CAST(GETDATE() AS DATE)
                      AND (@clinic_id IS NULL OR dq.clinic_id = @clinic_id OR dq.clinic_id IS NULL)
                ORDER BY ts.start_time;

                --------------------------------------------------
                -- STATUS
                --------------------------------------------------
                SELECT 1 AS success,
                       'Today queue fetched' AS message;

            END TRY
            BEGIN CATCH
                SELECT 0 AS success,
                       ERROR_MESSAGE() AS message,
                       ERROR_MESSAGE() AS error;
            END CATCH
        END

        IF @operation = 'QUEUE_PAUSE'
        BEGIN
            --------------------------------------------------
            -- PAUSE QUEUE (YOUR ORIGINAL LOGIC)
            --------------------------------------------------
            UPDATE doctor_queue
            SET queue_status = 2 -- 2 = paused
            WHERE doctor_id = @doctor_id
                  AND queue_id = @queue_id
                  AND queue_date = CAST(GETDATE() AS DATE);

            --------------------------------------------------
            -- CHECK SUCCESS
            --------------------------------------------------
            IF @@ROWCOUNT = 0
            BEGIN
                SELECT 0 AS success,
                       'Queue not found or already paused' AS message;
                RETURN;
            END

            --------------------------------------------------
            -- SUCCESS RESPONSE (RESULT SET 1)
            --------------------------------------------------
            SELECT 1 AS success,
                   'Queue paused' AS message;

            --------------------------------------------------
            -- ?? RETURN TOKENS (RESULT SET 2)
            --------------------------------------------------
            SELECT a.appointment_id,
                   a.queue_number,
                   CASE
                       WHEN a.user_type = 1 THEN
                           p.token
                       WHEN a.user_type = 2 THEN
                           p2.token
                   END AS token
            FROM appointments a
                LEFT JOIN patients p
                    ON a.user_type = 1
                       AND p.patient_id = a.patient_id
                LEFT JOIN family_members fm
                    ON a.user_type = 2
                       AND fm.member_id = a.patient_id
                LEFT JOIN patients p2
                    ON fm.family_id = p2.patient_id
            WHERE a.doctor_id = @doctor_id
                  AND a.appointment_date = CAST(GETDATE() AS DATE)
                  AND a.booking_type = 1
                  AND queue_id = @queue_id
                  AND a.status IN ( 'booked', 'in_progress' )
            ORDER BY a.queue_number;

        END

    --------------------------------------------------
-- EMERGENCY QUEUE PAUSE
--------------------------------------------------
IF @operation = 'QUEUE_PAUSE_EMERGENCY'
BEGIN
    BEGIN TRY

        IF @queue_id IS NULL
        BEGIN
            SELECT 0 AS success, 'queue_id required' AS message;
            RETURN;
        END

        DECLARE @q_doctor_id  INT;
        DECLARE @current_stat INT;

        SELECT @q_doctor_id  = doctor_id,
               @current_stat = queue_status
        FROM doctor_queue
        WHERE queue_id = @queue_id;

        IF @q_doctor_id IS NULL
        BEGIN
            SELECT 0 AS success, 'Invalid queue' AS message;
            RETURN;
        END

        --------------------------------------------------
        -- IDEMPOTENCY CHECK
        -- queue_status: 0=not started, 1=active, 2=paused, 3=stopped, 4=emergency
        --------------------------------------------------
        IF @current_stat = 4
        BEGIN
            SELECT 0 AS success,
                   'Queue is already in emergency pause' AS message;
            RETURN;
        END

        IF @current_stat = 3
        BEGIN
            SELECT 0 AS success,
                   'Queue is already stopped' AS message;
            RETURN;
        END

        --------------------------------------------------
        -- UPDATE STATUS ? 4 (EMERGENCY PAUSED)
        --------------------------------------------------
        UPDATE doctor_queue
        SET queue_status = 4
        WHERE queue_id = @queue_id;

        --------------------------------------------------
        -- SUCCESS RESPONSE (RESULT SET 1)
        --------------------------------------------------
        SELECT 1 AS success,
               'Queue paused successfully' AS message;

        --------------------------------------------------
        -- TOKENS (RESULT SET 2)
        --------------------------------------------------
        SELECT a.appointment_id,
               a.queue_number,
               CASE
                   WHEN a.user_type = 1 THEN p.token
                   WHEN a.user_type = 2 THEN p2.token
               END AS token
        FROM appointments a
            LEFT JOIN patients p
                ON a.user_type = 1
                   AND p.patient_id = a.patient_id
            LEFT JOIN family_members fm
                ON a.user_type = 2
                   AND fm.member_id = a.patient_id
            LEFT JOIN patients p2
                ON fm.family_id = p2.patient_id
        WHERE a.doctor_id = @q_doctor_id
              AND a.appointment_date = CAST(GETDATE() AS DATE)
              AND a.booking_type = 1
              AND a.queue_id = @queue_id
              AND a.status IN ('booked', 'in_progress')
        ORDER BY a.queue_number;

    END TRY
    BEGIN CATCH
        SELECT 0 AS success,
               ERROR_MESSAGE() AS message,
               ERROR_MESSAGE() AS error;
    END CATCH
END

   
           ---------------------------------------------------------
        -- QUEUE STOP
        IF @operation = 'QUEUE_STOP'
        BEGIN
            DECLARE @qstop_start_time TIME;

            -- Get start_time of the queue being stopped (from its slot)
            SELECT TOP 1 @qstop_start_time = ts.start_time
            FROM doctor_queue dq
                INNER JOIN doctor_time_slots ts ON dq.slot_id = ts.slot_id
            WHERE dq.doctor_id  = @doctor_id
              AND dq.queue_id   = @queue_id
              AND dq.queue_date = CAST(GETDATE() AS DATE);

            -- Close this queue only
            UPDATE doctor_queue
            SET queue_status = 3,
                stopped_at   = GETDATE()
            WHERE doctor_id  = @doctor_id
              AND queue_id   = @queue_id
              AND queue_date = CAST(GETDATE() AS DATE);

            -- THIS queue's pending (booked + skipped) ? cancelled
            UPDATE appointments
            SET status = 'CancleD'
            WHERE queue_id = @queue_id
              AND status IN ('skipped', 'booked');

            -- Earlier-time slot bookings (booking_type=2) before this queue's time ? cancelled
            UPDATE appointments
            SET status = 'CancleD'
            WHERE doctor_id        = @doctor_id
              AND booking_type     = 2
              AND appointment_date = CAST(GETDATE() AS DATE)
              AND status IN ('booked', 'skipped')
              AND start_time       < @qstop_start_time;

            SELECT 1 success,
                   'Queue stopped' message;
        END
		-------------------------------------------------------------------------------------------------------------
-- QUEUE_PROXIMITY_LIST (NEW - for proximity notifications)
--------------------------------------------------
IF @operation = 'QUEUE_PROXIMITY_LIST'
BEGIN
    DECLARE @prox_hour INT = DATEPART(HOUR, GETDATE());
    DECLARE @prox_avg  INT;

    SELECT @prox_avg = COALESCE(
        CASE
            WHEN @prox_hour < 12 THEN morning_avg
            WHEN @prox_hour < 17 THEN afternoon_avg
            ELSE evening_avg
        END,
        avg_consultation_time,
        @default_avg
    )
    FROM doctor_timing
    WHERE doctor_id = @doctor_id AND (@clinic_id IS NULL OR clinic_id = @clinic_id);

    IF @prox_avg IS NULL SET @prox_avg = @default_avg;
    IF @prox_avg < 3     SET @prox_avg = 3;
    IF @prox_avg > 30    SET @prox_avg = 30;

    SELECT
        a.appointment_id,
        CASE
            WHEN a.user_type = 1 THEN a.patient_id
            WHEN a.user_type = 2 THEN fm.family_id
        END AS owner_id,
        CASE
            WHEN a.user_type = 1 THEN p.token
            WHEN a.user_type = 2 THEN p2.token
        END AS owner_token,
        ISNULL(d.name, 'your doctor') AS doctor_name,
        (a.queue_number - dq.current_serving - 1) * @prox_avg AS est_minutes_to_turn
    FROM appointments a
        INNER JOIN doctor_queue dq
            ON dq.queue_id = a.queue_id
        LEFT JOIN patients p
            ON a.user_type = 1 AND p.patient_id = a.patient_id
        LEFT JOIN family_members fm
            ON a.user_type = 2 AND fm.member_id = a.patient_id
        LEFT JOIN patients p2
            ON fm.family_id = p2.patient_id
        LEFT JOIN doctor_login d
            ON d.doctor_id = a.doctor_id
    WHERE a.doctor_id        = @doctor_id
      AND a.appointment_date = CAST(GETDATE() AS DATE)
      AND a.booking_type     = 1
      AND a.status           = 'booked'
      AND dq.queue_status    = 1
      AND (a.queue_number - dq.current_serving) > 1
    ORDER BY est_minutes_to_turn;
END


        --------------------------------------------------
        ---- NEXT SESSION (FINAL - SLOT_ID BASED)
        ----------------------------------------------------
        --IF @operation = 'NEXT_SESSION'
        --BEGIN
        --    --------------------------------------------------
        --    -- GET CURRENT APPOINTMENT DETAILS
        --    --------------------------------------------------
        --    SELECT @booking_type = booking_type,
        --           @slot_id = slot_id,
        --           @current_queue = queue_number
        --    FROM appointments
        --    WHERE appointment_id = @appointment_id
        --          AND doctor_id = @doctor_id;

        --    IF @booking_type IS NULL
        --    BEGIN
        --        SELECT 0 AS success,
        --               'Invalid appointment' AS message;
        --        RETURN;
        --    END

        --    --------------------------------------------------
        --    -- QUEUE FLOW (SESSION SAFE)
        --    --------------------------------------------------
        --    IF @booking_type = 1
        --    BEGIN
        --        --------------------------------------------------
        --        -- CHECK QUEUE STARTED
        --        --------------------------------------------------
        --        IF NOT EXISTS
        --        (
        --            SELECT 1
        --            FROM doctor_queue
        --            WHERE slot_id = @slot_id
        --                  AND queue_status = 1
        --        )
        --        BEGIN
        --            SELECT 0 AS success,
        --                   'Queue not started' AS message;
        --            RETURN;
        --        END

        --        --------------------------------------------------
        --        -- COMPLETE CURRENT
        --        --------------------------------------------------
        --        UPDATE appointments
        --        SET end_time = GETDATE(),
        --            status = 'completed'
        --        WHERE appointment_id = @appointment_id
        --              AND booking_type = 1
        --              AND status = 'in_progress';

        --        IF @@ROWCOUNT = 0
        --        BEGIN
        --            SELECT 0 AS success,
        --                   'Invalid active appointment' AS message;
        --            RETURN;
        --        END

        --        --------------------------------------------------
        --        -- UPDATE COMPLETED COUNT
        --        --------------------------------------------------
        --        UPDATE doctor_queue
        --        SET completed_count = ISNULL(completed_count, 0) + 1
        --        WHERE slot_id = @slot_id;

        --        --------------------------------------------------
        --        -- FIND NEXT IN SAME SESSION
        --        --------------------------------------------------
        --        SELECT TOP 1
        --            @next_queue = queue_number,
        --            @qn_next_patient_id = patient_id,
        --            @next_appointment_id = appointment_id
        --        FROM appointments
        --        WHERE slot_id = @slot_id
        --              AND booking_type = 1
        --              AND status = 'booked'
        --              AND queue_number > @current_queue
        --        ORDER BY queue_number;

        --        --------------------------------------------------
        --        -- NO NEXT IN THIS SESSION
        --        --------------------------------------------------
        --        IF @next_queue IS NULL
        --        BEGIN
        --            --------------------------------------------------
        --            -- CHECK SKIPPED IN SAME SESSION
        --            --------------------------------------------------
        --            IF EXISTS
        --            (
        --                SELECT 1
        --                FROM appointments
        --                WHERE slot_id = @slot_id
        --                      AND booking_type = 1
        --                      AND status = 'skipped'
        --            )
        --            BEGIN
        --                UPDATE doctor_queue
        --                SET current_patient_id = NULL
        --                WHERE slot_id = @slot_id;

        --                SELECT 1 AS success,
        --                       'Booked done. Skipped pending.' AS message;
        --                RETURN;
        --            END

        --            --------------------------------------------------
        --            -- CLOSE ONLY THIS SESSION
        --            --------------------------------------------------
        --            UPDATE doctor_queue
        --            SET
        --                --queue_status = 3,
        --                --             stopped_at = GETDATE(),
        --                current_patient_id = NULL
        --            WHERE slot_id = @slot_id;

        --            SELECT 1 AS success,
        --                   'No Patient Left' AS message;
        --            RETURN;
        --        END

        --        --------------------------------------------------
        --        -- START NEXT IN SAME SESSION
        --        --------------------------------------------------
        --        UPDATE appointments
        --        SET start_time = GETDATE(),
        --            status = 'in_progress'
        --        WHERE appointment_id = @next_appointment_id
        --              and slot_id = @slot_id;

        --        --------------------------------------------------
        --        -- UPDATE POINTER
        --        --------------------------------------------------
        --        UPDATE doctor_queue
        --        SET current_serving = @next_queue,
        --            current_patient_id = @qn_next_patient_id
        --        WHERE slot_id = @slot_id;

        --        --------------------------------------------------
        --        -- CONSULTATION TIME TRACKING
        --        --------------------------------------------------
        --        SELECT @consult_time = DATEDIFF(MINUTE, start_time, end_time)
        --        FROM appointments
        --        WHERE appointment_id = @appointment_id;

        --        IF @consult_time IS NOT NULL
        --        BEGIN
        --            SET @hour = DATEPART(HOUR, GETDATE());

        --            IF NOT EXISTS (SELECT 1 FROM doctor_timing WHERE doctor_id = @doctor_id)
        --            BEGIN
        --                INSERT INTO doctor_timing
        --                (
        --                    doctor_id,
        --                    avg_consultation_time,
        --                    morning_avg,
        --                    afternoon_avg,
        --                    evening_avg,
        --                    total_completed,
        --                    last_updated
        --                )
        --                VALUES
        --                (@doctor_id, @consult_time, NULL, NULL, NULL, 1, GETDATE());
        --            END
        --            ELSE
        --            BEGIN
        --                UPDATE doctor_timing
        --                SET avg_consultation_time = (avg_consultation_time * total_completed + @consult_time)
        --                                            / (total_completed + 1),
        --                    total_completed = total_completed + 1,
        --                    last_updated = GETDATE()
        --                WHERE doctor_id = @doctor_id;

        --                IF @hour < 12
        --                    UPDATE doctor_timing
        --                    SET morning_avg = ISNULL((morning_avg + @consult_time) / 2, @consult_time)
        --                    WHERE doctor_id = @doctor_id;
        --                ELSE IF @hour < 17
        --                    UPDATE doctor_timing
        --                    SET afternoon_avg = ISNULL((afternoon_avg + @consult_time) / 2, @consult_time)
        --                    WHERE doctor_id = @doctor_id;
        --                ELSE
        --                    UPDATE doctor_timing
        --                    SET evening_avg = ISNULL((evening_avg + @consult_time) / 2, @consult_time)
        --                    WHERE doctor_id = @doctor_id;
        --            END
        --        END

        --        SELECT 1 AS success,
        --               'Next queue patient started' AS message;
        --        RETURN;
        --    END

        --    --------------------------------------------------
        --    -- SLOT FLOW (SESSION SAFE)
        --    --------------------------------------------------
        --    IF @booking_type = 2
        --    BEGIN
        --        --------------------------------------------------
        --        -- COMPLETE CURRENT SLOT
        --        --------------------------------------------------
        --        UPDATE appointments
        --        SET status = 'completed'
        --        WHERE appointment_id = @appointment_id
        --              AND booking_type = 2
        --              AND status = 'in_progress';

        --        IF @@ROWCOUNT = 0
        --        BEGIN
        --            SELECT 0 AS success,
        --                   'Invalid active slot' AS message;
        --            RETURN;
        --        END

        --        --------------------------------------------------
        --        -- FIND NEXT SLOT IN SAME SESSION
        --        --------------------------------------------------
        --        SELECT TOP 1
        --            @next_appointment_id = appointment_id
        --        FROM appointments
        --        WHERE slot_id = @slot_id
        --              AND booking_type = 2
        --              AND status = 'booked'
        --        ORDER BY start_time;

        --        --------------------------------------------------
        --        -- NO NEXT SLOT
        --        --------------------------------------------------
        --        IF @next_appointment_id IS NULL
        --        BEGIN
        --            SELECT 1 AS success,
        --                   'No Patient Left' AS message;
        --            RETURN;
        --        END

        --        --------------------------------------------------
        --        -- START NEXT SLOT
        --        --------------------------------------------------
        --        UPDATE appointments
        --        SET status = 'in_progress'
        --        WHERE appointment_id = @next_appointment_id;

        --        SELECT 1 AS success,
        --               'Next slot started' AS message;
        --        RETURN;
        --    END
        --END
        --------------------------------------------------
        -- NEXT SESSION (FINAL - SESSION SAFE)
        --------------------------------------------------
        IF @operation = 'NEXT_SESSION'
        BEGIN
            --------------------------------------------------
            -- GET CURRENT APPOINTMENT DETAILS
            --------------------------------------------------
            SELECT @booking_type = booking_type,
                   @slot_id = slot_id,
                   @queue_id = queue_id,                 -- ? ADD
                   @current_queue = queue_number
            FROM appointments
            WHERE appointment_id = @appointment_id
                  AND doctor_id = @doctor_id;

            IF @booking_type IS NULL
            BEGIN
                SELECT 0 AS success,
                       'Invalid appointment' AS message;
                RETURN;
            END

            --------------------------------------------------
            -- QUEUE FLOW (SESSION SAFE)
            --------------------------------------------------
            IF @booking_type = 1
            BEGIN
                --------------------------------------------------
                -- CHECK QUEUE STARTED (? queue_id scoped)
                --------------------------------------------------
                IF NOT EXISTS
                (
                    SELECT 1
                    FROM doctor_queue
                    WHERE queue_id = @queue_id        -- ? specific session
                          AND queue_status = 1
                )
                BEGIN
                    SELECT 0 AS success,
                           'Queue not started' AS message;
                    RETURN;
                END

                --------------------------------------------------
                -- COMPLETE CURRENT
                --------------------------------------------------
                --UPDATE appointments
                --SET end_time = GETDATE(),
                --    status = 'completed'
                --WHERE appointment_id = @appointment_id
                --      AND booking_type = 1
                --      AND status = 'in_progress';

                --IF @@ROWCOUNT = 0
                --BEGIN
                --    SELECT 0 AS success,
                --           'Invalid active appointment' AS message;
                --    RETURN;
                --END

				                --------------------------------------------------
                -- COMPLETE CURRENT (in_progress ????? booked)
                --------------------------------------------------
                UPDATE appointments
                SET end_time = GETDATE(),
                    status = 'completed'
                WHERE appointment_id = @appointment_id
                      AND booking_type = 1
                      AND status IN ('in_progress', 'booked');


                --------------------------------------------------
                -- UPDATE COMPLETED COUNT (? this queue only)
                --------------------------------------------------
                UPDATE doctor_queue
                SET completed_count = ISNULL(completed_count, 0) + 1
                WHERE queue_id = @queue_id;           -- ?

                --------------------------------------------------
                -- FIND NEXT IN SAME SESSION (? queue_id scoped)
                --------------------------------------------------
                SELECT TOP 1
                    @next_queue = queue_number,
                    @qn_next_patient_id = patient_id,
                    @next_appointment_id = appointment_id
                FROM appointments
                WHERE queue_id = @queue_id            -- ?
                      AND booking_type = 1
                      AND status = 'booked'
                      AND queue_number > @current_queue
                ORDER BY queue_number;

                --------------------------------------------------
                -- NO NEXT IN THIS SESSION
                --------------------------------------------------
                IF @next_queue IS NULL
                BEGIN
                    --------------------------------------------------
                    -- CHECK SKIPPED IN SAME SESSION (? queue_id scoped)
                    --------------------------------------------------
                    IF EXISTS
                    (
                        SELECT 1
                        FROM appointments
                        WHERE queue_id = @queue_id    -- ?
                              AND booking_type = 1
                              AND status = 'skipped'
                    )
                    BEGIN
                        UPDATE doctor_queue
                        SET current_patient_id = NULL
                        WHERE queue_id = @queue_id;   -- ?

                        SELECT 1 AS success,
                               'Booked done. Skipped pending.' AS message;
                        RETURN;
                    END

                    --------------------------------------------------
                    -- CLOSE ONLY THIS SESSION (? queue_id scoped)
                    --------------------------------------------------
                    UPDATE doctor_queue
                    SET current_patient_id = NULL
                    WHERE queue_id = @queue_id;       -- ?

                    SELECT 1 AS success,
                           'No Patient Left' AS message;
                    RETURN;
                END

                --------------------------------------------------
                -- START NEXT IN SAME SESSION
                --------------------------------------------------
                UPDATE appointments
                SET start_time = GETDATE(),
                    status = 'in_progress'
                WHERE appointment_id = @next_appointment_id;

                --------------------------------------------------
                -- UPDATE POINTER (? queue_id scoped)
                --------------------------------------------------
                UPDATE doctor_queue
                SET current_serving = @next_queue,
                    current_patient_id = @qn_next_patient_id
                WHERE queue_id = @queue_id;           -- ?

                --------------------------------------------------
                -- CONSULTATION TIME TRACKING (unchanged)
                --------------------------------------------------
                SELECT @consult_time = DATEDIFF(MINUTE, start_time, end_time)
                FROM appointments
                WHERE appointment_id = @appointment_id;
				IF @consult_time IS NOT NULL
BEGIN
    SET @hour = DATEPART(HOUR, GETDATE());
    DECLARE @effective_clinic VARCHAR(50) = ISNULL(@clinic_id, 'DEFAULT');

    IF NOT EXISTS (
        SELECT 1 FROM doctor_timing 
        WHERE doctor_id = @doctor_id AND clinic_id = @effective_clinic
    )
    BEGIN
        INSERT INTO doctor_timing
            (doctor_id, clinic_id, avg_consultation_time,
             morning_avg, afternoon_avg, evening_avg,
             total_completed, last_updated)
        VALUES
            (@doctor_id, @effective_clinic, @consult_time,
             NULL, NULL, NULL, 1, GETDATE());
    END
    ELSE
    BEGIN
        UPDATE doctor_timing
        SET avg_consultation_time = (avg_consultation_time * total_completed + @consult_time)
                                    / (total_completed + 1),
            total_completed = total_completed + 1,
            last_updated = GETDATE()
        WHERE doctor_id = @doctor_id AND clinic_id = @effective_clinic;

        IF @hour < 12
            UPDATE doctor_timing
            SET morning_avg = ISNULL((morning_avg + @consult_time) / 2, @consult_time)
            WHERE doctor_id = @doctor_id AND clinic_id = @effective_clinic;
        ELSE IF @hour < 17
            UPDATE doctor_timing
            SET afternoon_avg = ISNULL((afternoon_avg + @consult_time) / 2, @consult_time)
            WHERE doctor_id = @doctor_id AND clinic_id = @effective_clinic;
        ELSE
            UPDATE doctor_timing
            SET evening_avg = ISNULL((evening_avg + @consult_time) / 2, @consult_time)
            WHERE doctor_id = @doctor_id AND clinic_id = @effective_clinic;
    END
END


                SELECT 1 AS success,
                       'Next queue patient started' AS message;
                RETURN;
            END

            --------------------------------------------------
            -- SLOT FLOW (SESSION SAFE)
            --------------------------------------------------
            IF @booking_type = 2
            BEGIN
                --------------------------------------------------
                -- COMPLETE CURRENT SLOT
                --------------------------------------------------
                UPDATE appointments
                SET status = 'completed'
                WHERE appointment_id = @appointment_id
                      AND booking_type = 2
                      AND status = 'in_progress';

                IF @@ROWCOUNT = 0
                BEGIN
                    SELECT 0 AS success,
                           'Invalid active slot' AS message;
                    RETURN;
                END

                --------------------------------------------------
                -- FIND NEXT SLOT IN SAME SESSION (? DATE + DOCTOR filter)
                --------------------------------------------------
                SELECT TOP 1
                    @next_appointment_id = appointment_id
                FROM appointments
                WHERE slot_id = @slot_id
                      AND doctor_id = @doctor_id                      -- ?
                      AND appointment_date = CAST(GETDATE() AS DATE)  -- ? TODAY only
                      AND booking_type = 2
                      AND status = 'booked'
                ORDER BY start_time;

                --------------------------------------------------
                -- NO NEXT SLOT
                --------------------------------------------------
                IF @next_appointment_id IS NULL
                BEGIN
                    SELECT 1 AS success,
                           'No Patient Left' AS message;
                    RETURN;
                END

                --------------------------------------------------
                -- START NEXT SLOT
                --------------------------------------------------
                UPDATE appointments
                SET status = 'in_progress',
                    start_time = GETDATE()
                WHERE appointment_id = @next_appointment_id;

                SELECT 1 AS success,
                       'Next slot started' AS message;
                RETURN;
            END
        END

        ----------------------------------------------------
        -- SKIP SESSION (FINAL - SLOT_ID BASED + is_next)
        --------------------------------------------------
        IF @operation = 'SKIP_SESSION'
        BEGIN
            --------------------------------------------------
            -- GET APPOINTMENT DETAILS
            --------------------------------------------------
            SELECT @booking_type = booking_type,
                   @slot_id = slot_id,
                   @current_queue = queue_number,
                   @user_type = user_type,
                   @patient_id_local = patient_id
            FROM appointments
            WHERE appointment_id = @appointment_id
                  AND doctor_id = @doctor_id;

            IF @booking_type IS NULL
            BEGIN
                SELECT 0 AS success,
                       'Invalid appointment' AS message,
                       NULL AS token;
                RETURN;
            END

            --------------------------------------------------
            -- GET TOKEN
            --------------------------------------------------
            IF @user_type = 1
            BEGIN
                SELECT @token = token
                FROM patients
                WHERE patient_id = @patient_id_local;
            END
            ELSE IF @user_type = 2
            BEGIN
                SELECT @token = p.token
                FROM family_members fm
                    JOIN patients p
                        ON fm.family_id = p.patient_id
                WHERE fm.member_id = @patient_id_local;
            END

            --------------------------------------------------
            -- QUEUE FLOW (SESSION SAFE)
            --------------------------------------------------
            IF @booking_type = 1
            BEGIN
                --------------------------------------------------
                -- CHECK QUEUE STARTED
                --------------------------------------------------
                IF NOT EXISTS
                (
                    SELECT 1
                    FROM doctor_queue
                    WHERE slot_id = @slot_id
                          AND queue_status = 1
                )
                BEGIN
                    SELECT 0 AS success,
                           'Queue not started or already stopped' AS message,
                           NULL AS token;
                    RETURN;
                END

                --------------------------------------------------
                -- SKIP CURRENT
                --------------------------------------------------
                UPDATE appointments
                SET status = 'skipped'
                WHERE appointment_id = @appointment_id
                      AND booking_type = 1
                      AND status IN ( 'booked', 'in_progress' );

                IF @@ROWCOUNT = 0
                BEGIN
                    SELECT 0 AS success,
                           'Invalid active queue appointment' AS message,
                           NULL AS token;
                    RETURN;
                END

                --------------------------------------------------
                -- IF NOT MOVE NEXT
                --------------------------------------------------
                IF @is_next = 0
                BEGIN
                    UPDATE doctor_queue
                    SET current_patient_id = NULL,
                        current_serving = NULL
                    WHERE slot_id = @slot_id;

                    SELECT 1 AS success,
                           'Patient skipped.' AS message,
                           @token AS token;
                    RETURN;
                END

                --------------------------------------------------
                -- FIND NEXT IN SAME SESSION
                --------------------------------------------------
                SELECT TOP 1
                    @next_queue = queue_number,
                    @next_patient_id = patient_id,
                    @next_appointment_id = appointment_id
                FROM appointments
                WHERE slot_id = @slot_id
                      AND booking_type = 1
                      AND status = 'booked'
                      AND queue_number > @current_queue
                ORDER BY queue_number;

                --------------------------------------------------
                -- NO NEXT
                --------------------------------------------------
                IF @next_queue IS NULL
                BEGIN
                    --IF EXISTS
                    --(
                    --    SELECT 1
                    --    FROM appointments
                    --    WHERE slot_id = @slot_id
                    --          AND booking_type = 1
                    --          AND status = 'skipped'
                    --)
                    --BEGIN
                    --    UPDATE doctor_queue
                    --    SET current_patient_id = NULL
                    --    WHERE slot_id = @slot_id;

                    --    SELECT 1 AS success,
                    --           'Patient skipped. Skipped pending.' AS message,
                    --           @token AS token;
                    --    RETURN;
                    --END

                    UPDATE doctor_queue
                    SET
                        --queue_status = 3,
                        --             stopped_at = GETDATE(),
                        current_patient_id = NULL
                    WHERE slot_id = @slot_id;

                    SELECT 1 AS success,
                           'Last Patient Skipped' AS message,
                           @token AS token;
                    RETURN;
                END

                --------------------------------------------------
                -- START NEXT
                --------------------------------------------------
                UPDATE appointments
                SET start_time = GETDATE(),
                    status = 'in_progress'
                WHERE appointment_id = @next_appointment_id
                      and slot_id = @slot_id;

                --------------------------------------------------
                -- UPDATE POINTER
                --------------------------------------------------
                UPDATE doctor_queue
                SET current_serving = @next_queue,
                    current_patient_id = @next_patient_id
                WHERE slot_id = @slot_id;

                SELECT 1 AS success,
                       'Queue patient skipped and next started' AS message,
                       @token AS token;
                RETURN;
            END

            --------------------------------------------------
            -- SLOT FLOW (SESSION SAFE)
            --------------------------------------------------
            IF @booking_type = 2
            BEGIN
                --------------------------------------------------
                -- SKIP SLOT
                --------------------------------------------------
                UPDATE appointments
                SET status = 'skipped'
                WHERE appointment_id = @appointment_id
                      AND booking_type = 2
                      AND status IN ( 'booked', 'in_progress' );

                IF @@ROWCOUNT = 0
                BEGIN
                    SELECT 0 AS success,
                           'Invalid active slot' AS message,
                           NULL AS token;
                    RETURN;
                END

                --------------------------------------------------
                -- IF NOT MOVE NEXT
                --------------------------------------------------
                IF @is_next = 0
                BEGIN
                    SELECT 1 AS success,
                           'Slot skipped.' AS message,
                           @token AS token;
                    RETURN;
                END

                --------------------------------------------------
                -- FIND NEXT SLOT (SAME SESSION)
                --------------------------------------------------
                SELECT TOP 1
                    @next_appointment_id = appointment_id
                FROM appointments
                WHERE slot_id = @slot_id
                      AND booking_type = 2
                      AND status = 'booked'
                ORDER BY start_time;

                IF @next_appointment_id IS NULL
                BEGIN
                    SELECT 1 AS success,
                           'Last Patient Skipped' AS message,
                           @token AS token;
                    RETURN;
                END

                --------------------------------------------------
                -- START NEXT SLOT
                --------------------------------------------------
                UPDATE appointments
                SET status = 'in_progress'
                WHERE appointment_id = @next_appointment_id;

                SELECT 1 AS success,
                       'Slot skipped and next started' AS message,
                       @token AS token;
                RETURN;
            END
        END --------------------------------------------------
        -- RECALL SESSION
        ----------------------------------------------------
        --IF @operation = 'RECALL_SESSION'
        --BEGIN
        --    --------------------------------------------------
        --    -- GET BOOKING TYPE
        --    --------------------------------------------------
        --    SELECT @booking_type = booking_type
        --    FROM appointments
        --    WHERE appointment_id = @appointment_id;

        --    IF @booking_type IS NULL
        --    BEGIN
        --        SELECT 0 AS success,
        --               'Invalid appointment' AS message;
        --        RETURN;
        --    END

        --    --------------------------------------------------
        --    -- QUEUE FLOW
        --    --------------------------------------------------
        --    IF @booking_type = 1
        --    BEGIN
        --        --------------------------------------------------
        --        -- CHECK QUEUE STARTED
        --        --------------------------------------------------
        --        IF NOT EXISTS
        --        (
        --            SELECT 1
        --            FROM doctor_queue
        --            WHERE doctor_id = @doctor_id
        --                  AND queue_date = CAST(GETDATE() AS DATE)
        --                  AND queue_status = 1
        --        )
        --        BEGIN
        --            SELECT 0 AS success,
        --                   'Queue not started or already stopped' AS message;
        --            RETURN;
        --        END

        --        --------------------------------------------------
        --        -- VALIDATION
        --        --------------------------------------------------
        --        IF NOT EXISTS
        --        (
        --            SELECT 1
        --            FROM appointments
        --            WHERE appointment_id = @appointment_id
        --                  AND booking_type = 1
        --                  AND status = 'skipped'
        --        )
        --        BEGIN
        --            SELECT 0 AS success,
        --                   'Only skipped queue patient can be recalled' AS message;
        --            RETURN;
        --        END

        --        --------------------------------------------------
        --        -- RECALL (START SESSION AGAIN)
        --        --------------------------------------------------
        --        UPDATE appointments
        --        SET start_time = GETDATE(),
        --            status = 'in_progress'
        --        WHERE appointment_id = @appointment_id;

        --        --------------------------------------------------
        --        -- UPDATE POINTER
        --        --------------------------------------------------
        --        UPDATE doctor_queue
        --        SET current_serving =
        --            (
        --                SELECT queue_number
        --                FROM appointments
        --                WHERE appointment_id = @appointment_id
        --            ),
        --            current_patient_id =
        --            (
        --                SELECT patient_id FROM appointments WHERE appointment_id = @appointment_id
        --            )
        --        WHERE doctor_id = @doctor_id
        --              AND queue_date = CAST(GETDATE() AS DATE);

        --        SELECT 1 AS success,
        --               'Queue patient recalled and started' AS message;
        --        RETURN;
        --    END

        --    --------------------------------------------------
        --    -- SLOT FLOW
        --    --------------------------------------------------
        --    IF @booking_type = 2
        --    BEGIN
        --        --------------------------------------------------
        --        -- VALIDATION
        --        --------------------------------------------------
        --        IF NOT EXISTS
        --        (
        --            SELECT 1
        --            FROM appointments
        --            WHERE appointment_id = @appointment_id
        --                  AND booking_type = 2
        --                  AND status = 'skipped'
        --        )
        --        BEGIN
        --            SELECT 0 AS success,
        --                   'Only skipped slot can be recalled' AS message;
        --            RETURN;
        --        END

        --        --------------------------------------------------
        --        -- RECALL SLOT
        --        --------------------------------------------------
        --        UPDATE appointments
        --        SET status = 'in_progress'
        --        WHERE appointment_id = @appointment_id;

        --        SELECT 1 AS success,
        --               'Slot recalled and started' AS message;
        --        RETURN;
        --    END
        --END

        ----------------------------------------------------
        ---- START SESSION
        ----------------------------------------------------
        --IF @operation = 'START_SESSION'
        --BEGIN
        --    --------------------------------------------------
        --    -- GET APPOINTMENT
        --    --------------------------------------------------
        --    SELECT @ss_queue_number = queue_number,
        --           @ss_patient_id = patient_id,
        --           @booking_mode = booking_type,
        --           @queue_id = queue_id
        --    FROM appointments
        --    WHERE appointment_id = @appointment_id;

        --    IF @booking_mode IS NULL
        --    BEGIN
        --        SELECT 0 AS success,
        --               'Invalid appointment' AS message;
        --        RETURN;
        --    END

        --    --------------------------------------------------
        --    -- QUEUE FLOW
        --    --------------------------------------------------
        --    IF @booking_mode = 1
        --    BEGIN
        --        --------------------------------------------------
        --        -- CHECK QUEUE STARTED
        --        --------------------------------------------------
        --        IF NOT EXISTS
        --        (
        --            SELECT 1
        --            FROM doctor_queue
        --            WHERE doctor_id = @doctor_id
        --                  AND queue_date = CAST(GETDATE() AS DATE)
        --                  AND queue_status = 1
        --        )
        --        BEGIN
        --            SELECT 0 AS success,
        --                   'Queue not started or already stopped' AS message;
        --            RETURN;
        --        END

        --        --------------------------------------------------
        --        -- VALIDATION
        --        --------------------------------------------------
        --        IF NOT EXISTS
        --        (
        --            SELECT 1
        --            FROM appointments
        --            WHERE appointment_id = @appointment_id
        --                  AND booking_type = 1
        --                  AND status IN ( 'booked', 'skipped' )
        --        )
        --        BEGIN
        --            SELECT 0 AS success,
        --                   'Only booked/skipped queue can be started' AS message;
        --            RETURN;
        --        END

        --        --------------------------------------------------
        --        -- RESET ANY ACTIVE SESSION
        --        --------------------------------------------------
        --        UPDATE appointments
        --        SET status = 'booked'
        --        WHERE doctor_id = @doctor_id
        --              AND appointment_date = CAST(GETDATE() AS DATE)
        --              AND booking_type = 1
        --              AND status = 'in_progress';

        --        --------------------------------------------------
        --        -- START CURRENT (BY ID)
        --        --------------------------------------------------
        --        UPDATE appointments
        --        SET start_time = GETDATE(),
        --            status = 'in_progress'
        --        WHERE appointment_id = @appointment_id;

        --        --------------------------------------------------
        --        -- UPDATE POINTER
        --        --------------------------------------------------
        --        UPDATE doctor_queue
        --        SET current_serving = @ss_queue_number,
        --            current_patient_id = @ss_patient_id
        --        WHERE doctor_id = @doctor_id
        --              and queue_id = @queue_id
        --              AND queue_date = CAST(GETDATE() AS DATE);

        --        SELECT 1 AS success,
        --               'Queue session started' AS message;
        --        RETURN;
        --    END

        --    --------------------------------------------------
        --    -- SLOT FLOW
        --    --------------------------------------------------
        --    IF @booking_mode = 2
        --    BEGIN
        --        --------------------------------------------------
        --        -- VALIDATION
        --        --------------------------------------------------
        --        IF NOT EXISTS
        --        (
        --            SELECT 1
        --            FROM appointments
        --            WHERE appointment_id = @appointment_id
        --                  AND booking_type = 2
        --                  AND status IN ( 'booked', 'skipped' )
        --        )
        --        BEGIN
        --            SELECT 0 AS success,
        --                   'Only booked/skipped slot can be started' AS message;
        --            RETURN;
        --        END

        --        --------------------------------------------------
        --        -- RESET CURRENT ACTIVE SLOT
        --        --------------------------------------------------
        --        UPDATE appointments
        --        SET status = 'booked'
        --        WHERE doctor_id = @doctor_id
        --              AND appointment_date = CAST(GETDATE() AS DATE)
        --              AND booking_type = 2
        --              AND status = 'in_progress';

        --        --------------------------------------------------
        --        -- START SLOT (BY ID)
        --        --------------------------------------------------
        --        UPDATE appointments
        --        SET status = 'in_progress'
        --        WHERE appointment_id = @appointment_id;

        --        SELECT 1 AS success,
        --               'Slot session started' AS message;
        --        RETURN;
        --    END
        --END

		        --------------------------------------------------
        -- RECALL SESSION
        --------------------------------------------------
        IF @operation = 'RECALL_SESSION'
        BEGIN
            --------------------------------------------------
            -- GET BOOKING TYPE
            --------------------------------------------------
            SELECT @booking_type = booking_type
            FROM appointments
            WHERE appointment_id = @appointment_id;

            IF @booking_type IS NULL
            BEGIN
                SELECT 0 AS success,
                       'Invalid appointment' AS message;
                RETURN;
            END

            --------------------------------------------------
            -- QUEUE FLOW
            --------------------------------------------------
            IF @booking_type = 1
            BEGIN
                --------------------------------------------------
                -- CHECK QUEUE STARTED
                --------------------------------------------------
                IF NOT EXISTS
                (
                    SELECT 1
                    FROM doctor_queue
                    WHERE doctor_id = @doctor_id
                          AND queue_date = CAST(GETDATE() AS DATE)
                          AND queue_status = 1
                )
                BEGIN
                    SELECT 0 AS success,
                           'Queue not started or already stopped' AS message;
                    RETURN;
                END

                --------------------------------------------------
                -- VALIDATION
                --------------------------------------------------
                IF NOT EXISTS
                (
                    SELECT 1
                    FROM appointments
                    WHERE appointment_id = @appointment_id
                          AND booking_type = 1
                          AND status = 'skipped'
                )
                BEGIN
                    SELECT 0 AS success,
                           'Only skipped queue patient can be recalled' AS message;
                    RETURN;
                END

                --------------------------------------------------
                -- ?? BLOCK: secound patient  in_progress 
                --    in_progress.  current complete .
                --------------------------------------------------
                IF EXISTS
                (
                    SELECT 1
                    FROM appointments
                    WHERE queue_id =
                          (SELECT queue_id FROM appointments
                           WHERE appointment_id = @appointment_id)
                          AND booking_type = 1
                          AND status = 'in_progress'
                )
                BEGIN
                    SELECT 0 AS success,
                           'Please complete the current in-progress patient first' AS message;
                    RETURN;
                END

                --------------------------------------------------
                -- RECALL (START SESSION AGAIN)
                --------------------------------------------------
                UPDATE appointments
                SET start_time = GETDATE(),
                    status = 'in_progress'
                WHERE appointment_id = @appointment_id;

                --------------------------------------------------
                -- UPDATE POINTER
                --------------------------------------------------
                UPDATE doctor_queue
                SET current_serving =
                    (
                        SELECT queue_number
                        FROM appointments
                        WHERE appointment_id = @appointment_id
                    ),
                    current_patient_id =
                    (
                        SELECT patient_id FROM appointments WHERE appointment_id = @appointment_id
                    )
                WHERE doctor_id = @doctor_id
                      AND queue_date = CAST(GETDATE() AS DATE);

                SELECT 1 AS success,
                       'Queue patient recalled and started' AS message;
                RETURN;
            END

            --------------------------------------------------
            -- SLOT FLOW
            --------------------------------------------------
            IF @booking_type = 2
            BEGIN
                --------------------------------------------------
                -- VALIDATION
                --------------------------------------------------
                IF NOT EXISTS
                (
                    SELECT 1
                    FROM appointments
                    WHERE appointment_id = @appointment_id
                          AND booking_type = 2
                          AND status = 'skipped'
                )
                BEGIN
                    SELECT 0 AS success,
                           'Only skipped slot can be recalled' AS message;
                    RETURN;
                END

                --------------------------------------------------
                -- ?? BLOCK: secound slot patient  in_progress 
                --------------------------------------------------
                IF EXISTS
                (
                    SELECT 1
                    FROM appointments
                    WHERE doctor_id =
                          (SELECT doctor_id FROM appointments
                           WHERE appointment_id = @appointment_id)
                          AND appointment_date = CAST(GETDATE() AS DATE)
                          AND booking_type = 2
                          AND status = 'in_progress'
                )
                BEGIN
                    SELECT 0 AS success,
                           'Please complete the current in-progress patient first' AS message;
                    RETURN;
                END

                --------------------------------------------------
                -- RECALL SLOT
                --------------------------------------------------
                UPDATE appointments
                SET status = 'in_progress'
                WHERE appointment_id = @appointment_id;

                SELECT 1 AS success,
                       'Slot recalled and started' AS message;
                RETURN;
            END
        END

		        --------------------------------------------------
        -- START SESSION
        --------------------------------------------------
        IF @operation = 'START_SESSION'
        BEGIN
            --------------------------------------------------
            -- GET APPOINTMENT
            --------------------------------------------------
            SELECT @ss_queue_number = queue_number,
                   @ss_patient_id = patient_id,
                   @booking_mode = booking_type,
                   @queue_id = queue_id
            FROM appointments
            WHERE appointment_id = @appointment_id;

            IF @booking_mode IS NULL
            BEGIN
                SELECT 0 AS success,
                       'Invalid appointment' AS message;
                RETURN;
            END

            --------------------------------------------------
            -- QUEUE FLOW
            --------------------------------------------------
            IF @booking_mode = 1
            BEGIN
                --------------------------------------------------
                -- CHECK QUEUE STARTED
                --------------------------------------------------
                IF NOT EXISTS
                (
                    SELECT 1
                    FROM doctor_queue
                    WHERE doctor_id = @doctor_id
                          AND queue_date = CAST(GETDATE() AS DATE)
                          AND queue_status = 1
                )
                BEGIN
                    SELECT 0 AS success,
                           'Queue not started or already stopped' AS message;
                    RETURN;
                END

                --------------------------------------------------
                -- VALIDATION
                --------------------------------------------------
                IF NOT EXISTS
                (
                    SELECT 1
                    FROM appointments
                    WHERE appointment_id = @appointment_id
                          AND booking_type = 1
                          AND status IN ( 'booked', 'skipped' )
                )
                BEGIN
                    SELECT 0 AS success,
                           'Only booked/skipped queue can be started' AS message;
                    RETURN;
                END

                --------------------------------------------------
                -- ?? BLOCK: secound patient  in_progress 
                --   ( 'RESET ANY ACTIVE SESSION' auto-bump )
                --------------------------------------------------
                IF EXISTS
                (
                    SELECT 1
                    FROM appointments
                    WHERE queue_id = @queue_id
                          AND booking_type = 1
                          AND status = 'in_progress'
                )
                BEGIN
                    SELECT 0 AS success,
                           'Please complete the current in-progress patient first' AS message;
                    RETURN;
                END

                --------------------------------------------------
                -- START CURRENT (BY ID)
                --------------------------------------------------
                UPDATE appointments
                SET start_time = GETDATE(),
                    status = 'in_progress'
                WHERE appointment_id = @appointment_id;

                --------------------------------------------------
                -- UPDATE POINTER
                --------------------------------------------------
                UPDATE doctor_queue
                SET current_serving = @ss_queue_number,
                    current_patient_id = @ss_patient_id
                WHERE doctor_id = @doctor_id
                      AND queue_id = @queue_id
                      AND queue_date = CAST(GETDATE() AS DATE);

                SELECT 1 AS success,
                       'Queue session started' AS message;
                RETURN;
            END

            --------------------------------------------------
            -- SLOT FLOW
            --------------------------------------------------
            IF @booking_mode = 2
            BEGIN
                --------------------------------------------------
                -- VALIDATION
                --------------------------------------------------
                IF NOT EXISTS
                (
                    SELECT 1
                    FROM appointments
                    WHERE appointment_id = @appointment_id
                          AND booking_type = 2
                          AND status IN ( 'booked', 'skipped' )
                )
                BEGIN
                    SELECT 0 AS success,
                           'Only booked/skipped slot can be started' AS message;
                    RETURN;
                END

                --------------------------------------------------
                -- ?? BLOCK: secound slot patient  in_progress 
                --   ( 'RESET CURRENT ACTIVE SLOT' auto-bump )
                --------------------------------------------------
                IF EXISTS
                (
                    SELECT 1
                    FROM appointments
                    WHERE doctor_id = @doctor_id
                          AND appointment_date = CAST(GETDATE() AS DATE)
                          AND booking_type = 2
                          AND status = 'in_progress'
                )
                BEGIN
                    SELECT 0 AS success,
                           'Please complete the current in-progress patient first' AS message;
                    RETURN;
                END

                --------------------------------------------------
                -- START SLOT (BY ID)
                --------------------------------------------------
                UPDATE appointments
                SET status = 'in_progress'
                WHERE appointment_id = @appointment_id;

                SELECT 1 AS success,
                       'Slot session started' AS message;
                RETURN;
            END
        END


        --------------------------------------------------
        -- END SESSION
        --------------------------------------------------
        IF @operation = 'END_SESSION'
        BEGIN
            --------------------------------------------------
            -- GET BOOKING TYPE
            --------------------------------------------------
            SELECT @booking_type = booking_type,
                   @queue_id = queue_id
            FROM appointments
            WHERE appointment_id = @appointment_id;

            IF @booking_type IS NULL
            BEGIN
                SELECT 0 AS success,
                       'Invalid appointment' AS message;
                RETURN;
            END

            --------------------------------------------------
            -- QUEUE FLOW
            --------------------------------------------------
            IF @booking_type = 1
            BEGIN
                --------------------------------------------------
                -- CHECK QUEUE STARTED
                --------------------------------------------------
                IF NOT EXISTS
                (
                    SELECT 1
                    FROM doctor_queue
                    WHERE doctor_id = @doctor_id
                          AND queue_date = CAST(GETDATE() AS DATE)
                          AND queue_status = 1
                          and queue_id = @queue_id
                )
                BEGIN
                    SELECT 0 AS success,
                           'Queue not started or already stopped' AS message,
                           NULL AS token;
                    RETURN;
                END

                --------------------------------------------------
                -- VALIDATION
                --------------------------------------------------
                IF NOT EXISTS
                (
                    SELECT 1
                    FROM appointments
                    WHERE appointment_id = @appointment_id
                          AND status = 'in_progress'
                )
                BEGIN
                    SELECT 0 AS success,
                           'Only active queue session can be ended' AS message,
                           NULL AS token;
                    RETURN;
                END

                --------------------------------------------------
                -- END CURRENT SESSION
                --------------------------------------------------
                UPDATE appointments
                SET end_time = GETDATE(),
                    status = 'completed'
                WHERE appointment_id = @appointment_id;

                --------------------------------------------------
                -- UPDATE COMPLETED COUNT
                --------------------------------------------------
                UPDATE doctor_queue
                SET completed_count = ISNULL(completed_count, 0) + 1
                WHERE doctor_id = @doctor_id
                      and queue_id = @queue_id
                      AND queue_date = CAST(GETDATE() AS DATE);

                --------------------------------------------------
                -- AUTO STOP CHECK
                --------------------------------------------------
                IF NOT EXISTS
                (
                    SELECT 1
                    FROM appointments
                    WHERE doctor_id = @doctor_id
                          AND appointment_date = CAST(GETDATE() AS DATE)
                          AND booking_type = 1
                          AND status IN ( 'booked', 'skipped' )
                )
                BEGIN
                    --UPDATE doctor_queue
                    --SET queue_status = 3,
                    --    stopped_at = GETDATE(),
                    --    current_patient_id = NULL
                    --WHERE doctor_id = @doctor_id
                    --      AND queue_date = CAST(GETDATE() AS DATE);
					   UPDATE doctor_queue
    SET current_patient_id = NULL   -- ?  pointer clear
    WHERE doctor_id = @doctor_id
          AND queue_id = @queue_id  -- ? specific session
          AND queue_date = CAST(GETDATE() AS DATE);

                    SELECT 1 AS success,
                           'Queue completed' AS message,
                           NULL AS token;
                    RETURN;
                END

                --------------------------------------------------
                -- ?? RETURN ONLY 3rd NEXT PATIENT TOKEN
                --------------------------------------------------
                SELECT 1 AS success,
                       'Queue session ended' AS message,
                       NULL AS token,
                       NULL AS appointment_id,
                       NULL AS queue_number
                UNION ALL
                SELECT NULL,
                       NULL,
                       CASE
                           WHEN a.user_type = 1 THEN
                               p.token
                           WHEN a.user_type = 2 THEN
                               p2.token
                       END AS token,
                       a.appointment_id,
                       a.queue_number
                FROM
                (
                    SELECT *,
                           ROW_NUMBER() OVER (ORDER BY queue_number) AS rn
                    FROM appointments
                    WHERE doctor_id = @doctor_id
                          AND appointment_date = CAST(GETDATE() AS DATE)
                          AND booking_type = 1
                          AND status = 'booked'
                ) a
                    LEFT JOIN patients p
                        ON a.user_type = 1
                           AND p.patient_id = a.patient_id
                    LEFT JOIN family_members fm
                        ON a.user_type = 2
                           AND fm.member_id = a.patient_id
                    LEFT JOIN patients p2
                        ON fm.family_id = p2.patient_id
                WHERE a.rn = 3;

                RETURN;
            END

            --------------------------------------------------
            -- SLOT FLOW
            --------------------------------------------------
            IF @booking_type = 2
            BEGIN
                --------------------------------------------------
                -- VALIDATION
                --------------------------------------------------
                IF NOT EXISTS
                (
                    SELECT 1
                    FROM appointments
                    WHERE appointment_id = @appointment_id
                          AND booking_type = 2
                          AND status = 'in_progress'
                )
                BEGIN
                    SELECT 0 AS success,
                           'Only active slot can be ended' AS message;
                    RETURN;
                END

                --------------------------------------------------
                -- END SLOT (BY ID)
                --------------------------------------------------
                UPDATE appointments
                SET status = 'completed'
                WHERE appointment_id = @appointment_id;

                --------------------------------------------------
                -- GET CURRENT CONSULTATION TIME
                --------------------------------------------------
                SELECT @consult_time = DATEDIFF(MINUTE, start_time, end_time)
                FROM appointments
                WHERE appointment_id = @appointment_id;

                IF @consult_time IS NOT NULL
                BEGIN
                    SET @hour = DATEPART(HOUR, GETDATE());

                    --------------------------------------------------
                    -- UPSERT PROFILE
                    --------------------------------------------------
                    IF NOT EXISTS (SELECT 1 FROM doctor_timing WHERE doctor_id = @doctor_id AND (@clinic_id IS NULL OR clinic_id = @clinic_id))
                    BEGIN
                        INSERT INTO doctor_timing
                        (
                            doctor_id,
                            avg_consultation_time,
                            morning_avg,
                            afternoon_avg,
                            evening_avg,
                            total_completed,
                            last_updated,
                            clinic_id
                        )
                        VALUES
                        (@doctor_id, @consult_time, NULL, NULL, NULL, 1, GETDATE(), @clinic_id);
                    END
                    ELSE
                    BEGIN
                        --------------------------------------------------
                        -- UPDATE GLOBAL AVG
                        --------------------------------------------------
                        UPDATE doctor_timing
                        SET avg_consultation_time = (avg_consultation_time * total_completed + @consult_time)
                                                    / (total_completed + 1),
                            total_completed = total_completed + 1,
                            last_updated = GETDATE()
                        WHERE doctor_id = @doctor_id AND (@clinic_id IS NULL OR clinic_id = @clinic_id);

                        --------------------------------------------------
                        -- UPDATE TIME SEGMENT AVG
                        --------------------------------------------------
                        IF @hour < 12
                        BEGIN
                            UPDATE doctor_timing
                            SET morning_avg = ISNULL((morning_avg + @consult_time) / 2, @consult_time)
                            WHERE doctor_id = @doctor_id  AND (@clinic_id IS NULL OR clinic_id = @clinic_id);
                        END
                        ELSE IF @hour < 17
                        BEGIN
                            UPDATE doctor_timing
                            SET afternoon_avg = ISNULL((afternoon_avg + @consult_time) / 2, @consult_time)
                            WHERE doctor_id = @doctor_id  AND (@clinic_id IS NULL OR clinic_id = @clinic_id);
                        END
                        ELSE
                        BEGIN
                            UPDATE doctor_timing
                            SET evening_avg = ISNULL((evening_avg + @consult_time) / 2, @consult_time)
                            WHERE doctor_id = @doctor_id  AND (@clinic_id IS NULL OR clinic_id = @clinic_id);
                        END
                    END
                END

                SELECT 1 AS success,
                       'Slot completed' AS message;
                RETURN;
            END
        END

        --------------------------------------------------
        -- RESCHEDULE APPOINTMENT
        --------------------------------------------------
        IF @operation = 'RESCHEDULE_APPOINTMENT'
        BEGIN
            --------------------------------------------------
            -- VALIDATE APPOINTMENT
            --------------------------------------------------
            SELECT @old_booking_type = booking_type,
                   @old_status = status
            FROM appointments
            WHERE appointment_id = @appointment_id;

            IF @old_booking_type IS NULL
            BEGIN
                SELECT 0 AS success,
                       'Invalid appointment' AS message;
                RETURN;
            END

            --------------------------------------------------
            -- BLOCK QUEUE RESCHEDULE
            --------------------------------------------------
            IF @old_booking_type = 1
            BEGIN
                SELECT 0 AS success,
                       'Queue appointments cannot be rescheduled' AS message;
                RETURN;
            END

            --------------------------------------------------
            -- BLOCK INVALID STATUS
            --------------------------------------------------
            IF @old_status IN ( 'completed', 'cancelled' )
            BEGIN
                SELECT 0 AS success,
                       'Cannot reschedule completed/cancelled appointment' AS message;
                RETURN;
            END

            --------------------------------------------------
            -- VALIDATE SLOT AVAILABILITY
            --------------------------------------------------
            SELECT @slot_duration = ts.slot_duration,
                   @slot_start = ts.start_time,
                   @slot_end = ts.end_time
            FROM doctor_time_slots ts
                JOIN doctor_availability da
                    ON ts.availability_id = da.availability_id
            WHERE da.doctor_id = @doctor_id
                  AND da.is_enabled = 1
                  AND da.day_of_week = DATENAME(WEEKDAY, @appointment_date)
                  AND ts.booking_mode = 2
                  AND @start_time >= ts.start_time
                  AND @start_time < ts.end_time;

            IF @slot_duration IS NULL
            BEGIN
                SELECT 0 AS success,
                       'Invalid slot' AS message;
                RETURN;
            END

            --------------------------------------------------
            -- VALIDATE SLOT INTERVAL
            --------------------------------------------------
            SET @minutes = DATEDIFF(MINUTE, @slot_start, @start_time);

            IF @minutes % @slot_duration <> 0
            BEGIN
                SELECT 0 AS success,
                       'Invalid slot interval' AS message;
                RETURN;
            END

            --------------------------------------------------
            -- PREVENT DOUBLE BOOKING
            --------------------------------------------------
            IF EXISTS
            (
                SELECT 1
                FROM appointments
                WHERE doctor_id = @doctor_id
                      AND appointment_date = @appointment_date
                      AND start_time = @start_time
                      AND appointment_id <> @appointment_id
                      AND status = 'booked'
            )
            BEGIN
                SELECT 0 AS success,
                       'Slot already booked' AS message;
                RETURN;
            END

            --------------------------------------------------
            -- UPDATE APPOINTMENT
            --------------------------------------------------
            UPDATE appointments
            SET appointment_date = @appointment_date,
                symptoms = @symptoms,
                start_time = @start_time,
                end_time = DATEADD(MINUTE, @slot_duration, @start_time),
                status = 'booked'
            WHERE appointment_id = @appointment_id;

            SELECT 1 AS success,
                   'Appointment rescheduled successfully' AS message;
        END

        --------------------------------------------------
        -- PATIENT LIST
        --------------------------------------------------
--------------------------------------------------
-- PATIENT APPOINTMENT LIST (WITH SESSION START TIME)
--------------------------------------------------
IF @operation = 'patientAppointmentList'
BEGIN
    SELECT 
        vw.*,
        dq.queue_status,

        --------------------------------------------------
        -- ?? SESSION START TIME (FROM SLOT)
        --------------------------------------------------
        FORMAT(ts.start_time, 'hh:mm tt') AS session_start_time

    FROM dbo.appointment_booking_vw vw

    --------------------------------------------------
    -- ?? QUEUE JOIN (SESSION BASED)
    --------------------------------------------------
    --LEFT JOIN doctor_queue dq
    --    ON dq.doctor_id = vw.doctor_id
    --    AND dq.queue_date = CAST(GETDATE() AS DATE)
    --    AND dq.slot_id = vw.slot_id
	LEFT JOIN doctor_queue dq
    ON dq.doctor_id = vw.doctor_id
    AND dq.queue_date = CAST(GETDATE() AS DATE)
    AND dq.slot_id = vw.slot_id
    AND (@clinic_id IS NULL OR dq.clinic_id = @clinic_id)  -- ADD


    --------------------------------------------------
    -- ?? SESSION TIME JOIN (USING slot_id)
    --------------------------------------------------
    LEFT JOIN doctor_time_slots ts
        ON ts.slot_id = vw.slot_id
    LEFT JOIN doctor_availability da
        ON da.availability_id = ts.availability_id

    WHERE vw.doctor_id = @doctor_id
          AND (@clinic_id IS NULL OR vw.clinic_id = @clinic_id)

    --------------------------------------------------
    -- ORDERING
    --------------------------------------------------
    ORDER BY 
        vw.appointment_date,
        CASE 
            WHEN vw.queue_number IS NULL THEN vw.start_time
        END,
        CASE 
            WHEN vw.queue_number IS NOT NULL THEN vw.queue_number
        END;
END
        --------------------------------------------------
        -- PATIENT'S APPOINTMENTS
        --------------------------------------------------
        IF @operation = 'patient_Appointments'
        BEGIN
            SELECT *
            FROM dbo.appointment_booking_vw
            WHERE family_id = @family_id
            order by queue_number asc;
        END


        -- QUEUE ESTIMATE SMART (FINAL WITH total_queue + current_serving)
        --------------------------------------------------
        IF @operation = 'QUEUE_ESTIMATE_SMART'
        BEGIN
            DECLARE @base_time DATETIME;
            DECLARE @is_queue_started BIT = 0;
            DECLARE @is_my_turn BIT = 0;
            DECLARE @queue_status INT;
            DECLARE @current_slot_start TIME;
  
DECLARE @my_status VARCHAR(30);  


            --------------------------------------------------
            -- VALIDATE APPOINTMENT + GET queue_id + slot_id
            --------------------------------------------------
            --SELECT @my_queue = queue_number,
            --       @queue_id = queue_id,
            --       @slot_id = slot_id
            --FROM appointments
            --WHERE appointment_id = @appointment_id
            --      AND booking_type = 1;


			-- VALIDATE APPOINTMENT + GET queue_id + slot_id
SELECT @my_queue = queue_number,
       @queue_id = queue_id,
       @slot_id = slot_id,
       @my_status = status         
FROM appointments
WHERE appointment_id = @appointment_id
      AND booking_type = 1;


            IF @my_queue IS NULL
               OR @queue_id IS NULL
               OR @slot_id IS NULL
            BEGIN
                SELECT 0 AS success,
                       'Invalid queue appointment' AS message;
                RETURN;
            END

            --------------------------------------------------
            -- GET CURRENT SESSION START TIME
            --------------------------------------------------
            SELECT @current_slot_start = start_time
            FROM doctor_time_slots
            WHERE slot_id = @slot_id;

            --------------------------------------------------
            -- ?? GET QUEUE INFO
            ----------------------------------------------------
            --SELECT @queue_status = queue_status,
            --       @current_serving = ISNULL(current_serving, 0),
            --       @total_queue = ISNULL(total_queue, 0),
            --       @is_queue_started = CASE
            --                               WHEN queue_status = 1 THEN
            --                                   1
            --                               ELSE
            --                                   0
            --                           END
            --FROM doctor_queue
            --WHERE queue_id = @queue_id;
			SELECT @queue_status = queue_status,
       @is_queue_started = CASE
                               WHEN queue_status = 1 THEN 1
                               ELSE 0
                           END
FROM doctor_queue
WHERE queue_id = @queue_id;
SELECT @current_serving = ISNULL(MAX(a.queue_number), 0)
FROM appointments a
WHERE a.queue_id = @queue_id
  AND a.booking_type = 1
  AND a.status IN ('completed', 'in_progress', 'cancelled', 'cancled', 'skipped')
  AND NOT EXISTS (
        SELECT 1 FROM appointments b
        WHERE b.queue_id = a.queue_id
          AND b.booking_type = 1
          AND b.queue_number < a.queue_number
          AND b.status NOT IN ('completed', 'cancelled', 'cancled', 'skipped')
      );


SELECT @total_queue = COUNT(*)
FROM appointments
WHERE queue_id = @queue_id
  AND booking_type = 1;


--SELECT @current_serving = ISNULL(MAX(queue_number), 0)
--FROM appointments
--WHERE queue_id = @queue_id
--  AND booking_type = 1
--  AND status IN ('completed', 'in_progress');

--SELECT @total_queue = COUNT(*)
--FROM appointments
--WHERE queue_id = @queue_id
--  AND booking_type = 1
--  AND LOWER(status) NOT IN ('cancelled', 'cancled');


            IF @is_queue_started IS NULL
                SET @is_queue_started = 0;

            --------------------------------------------------
            -- TIME-BASED AVG
            --------------------------------------------------
            SET @hour = DATEPART(HOUR, GETDATE());

            SELECT @base_avg = CASE
                                   WHEN @hour < 12 THEN
                                       morning_avg
                                   WHEN @hour < 17 THEN
                                       afternoon_avg
                                   ELSE
                                       evening_avg
                               END
            FROM doctor_timing
            WHERE doctor_id = @doctor_id AND (@clinic_id IS NULL OR clinic_id = @clinic_id);

            IF @base_avg IS NULL
            BEGIN
                SELECT @base_avg = avg_consultation_time
                FROM doctor_queue
                WHERE queue_id = @queue_id;
            END

            IF @base_avg IS NULL
                SET @base_avg = 7;

            --------------------------------------------------
            -- QUEUE SIZE (CURRENT SESSION)
            --------------------------------------------------
            SELECT @queue_size = COUNT(*)
            FROM appointments
            WHERE queue_id = @queue_id
                  AND booking_type = 1
                  AND status IN ( 'booked', 'in_progress' );

            --------------------------------------------------
            -- AVG CONSULT TIME (Practo-style)
            --   measured avg, clamped to a sane 3�30 min band.
            --   NO artificial queue-size scaling.
            --------------------------------------------------
            IF @base_avg < 3  SET @base_avg = 3;
            IF @base_avg > 30 SET @base_avg = 30;

            SET @adaptive_avg = @base_avg;

            --------------------------------------------------
            -- PATIENTS AHEAD (CURRENT SESSION)
            --------------------------------------------------
            SELECT @patients_ahead = COUNT(*)
            FROM appointments
            WHERE queue_id = @queue_id
                  AND booking_type = 1
                  AND status IN ( 'booked', 'in_progress' )
                  AND queue_number < @my_queue;

            --------------------------------------------------
            -- ?? PREVIOUS SESSIONS LOAD
            --------------------------------------------------
            DECLARE @previous_load INT = 0;

            --SELECT @previous_load = COUNT(*)
            --FROM appointments a
            --    JOIN doctor_queue dq2
            --        ON a.queue_id = dq2.queue_id
            --    JOIN doctor_time_slots ts2
            --        ON dq2.slot_id = ts2.slot_id
            --WHERE dq2.doctor_id = @doctor_id
            --      AND dq2.queue_date = CAST(GETDATE() AS DATE)
            --      AND a.status IN ( 'booked', 'in_progress' )
            --      AND ts2.start_time < @current_slot_start;
			SELECT @previous_load = COUNT(*)
FROM appointments a
    JOIN doctor_queue dq2 ON a.queue_id = dq2.queue_id
    JOIN doctor_time_slots ts2 ON dq2.slot_id = ts2.slot_id
WHERE dq2.doctor_id = @doctor_id
      AND dq2.clinic_id = @clinic_id        -- ? ADD THIS
      AND dq2.queue_date = CAST(GETDATE() AS DATE)
      AND a.status IN ('booked', 'in_progress')
      AND ts2.start_time < @current_slot_start;


            --------------------------------------------------
            -- WAITING (NOT-YET-STARTED) PATIENTS AHEAD IN THIS SESSION
            --------------------------------------------------
            DECLARE @waiting_ahead     INT = 0;
            DECLARE @inprogress_start  DATETIME;
            DECLARE @remaining_current FLOAT = 0;

            SELECT @waiting_ahead = COUNT(*)
            FROM appointments
            WHERE queue_id = @queue_id
                  AND booking_type = 1
                  AND status = 'booked'
                  AND queue_number < @my_queue;

            --------------------------------------------------
            -- ?? CURRENT IN-PROGRESS PATIENT ? only the REMAINING time counts
            --   (Practo/Qminder style: don't charge a full slot for someone
            --    the doctor is already partway through consulting.)
            --------------------------------------------------
            SELECT TOP 1 @inprogress_start = start_time
            FROM appointments
            WHERE queue_id = @queue_id
                  AND booking_type = 1
                  AND status = 'in_progress'
                  AND queue_number < @my_queue
            ORDER BY queue_number DESC;

            IF @inprogress_start IS NOT NULL
            BEGIN
                DECLARE @elapsed_current INT =
                    DATEDIFF(MINUTE, @inprogress_start, GETDATE());

                SET @remaining_current = @adaptive_avg - @elapsed_current;

                -- clamp: never more than a full slot, never below 1 min
                IF @remaining_current > @adaptive_avg
                    SET @remaining_current = @adaptive_avg;
                IF @remaining_current < 1
                    SET @remaining_current = 1;
            END

            --------------------------------------------------
            -- FINAL ESTIMATION
            --   earlier sessions + waiting-ahead ? full avg each
            --   current in-progress patient      ? remaining time only
            --------------------------------------------------
            SET @estimated_time =
                ((@previous_load + @waiting_ahead) * @adaptive_avg)
                + @remaining_current;

            --------------------------------------------------
            -- START TIME (REAL OR SCHEDULE)
            --------------------------------------------------
            SELECT TOP 1
                @started_at = start_time
            FROM appointments
            WHERE queue_id = @queue_id
                  AND booking_type = 1
                  AND start_time IS NOT NULL
            ORDER BY start_time;

            IF @started_at IS NULL
            BEGIN
                SET @started_at
                    = DATETIMEFROMPARTS(
                                           YEAR(GETDATE()),
                                           MONTH(GETDATE()),
                                           DAY(GETDATE()),
                                           DATEPART(HOUR, @current_slot_start),
                                           DATEPART(MINUTE, @current_slot_start),
                                           0,
                                           0
                                       );
            END

            IF @started_at IS NULL
            BEGIN
                SELECT 0 AS success,
                       'Doctor not available today' AS message;
                RETURN;
            END

            --------------------------------------------------
            -- IMMEDIATE TURN LOGIC
            --------------------------------------------------
            --IF @patients_ahead = 0
            --   AND @previous_load = 0
            --   AND @is_queue_started = 1
            --BEGIN
            --    SET @estimated_time = 0;
            --    SET @arrival_time = GETDATE();
            --    SET @is_my_turn = 1;
            --END

IF (
        @current_serving = @my_queue                          
        OR (@patients_ahead = 0 AND @previous_load = 0)        
   )
   AND @is_queue_started = 1
   AND @my_status IN ('booked', 'in_progress')               
BEGIN
    SET @estimated_time = 0;
    SET @arrival_time = GETDATE();
    SET @is_my_turn = 1;
END


            ELSE
            BEGIN
                -- Scheduled session start as today's datetime
                SET @slot_start_dt =
                    DATETIMEFROMPARTS(
                        YEAR(GETDATE()), MONTH(GETDATE()), DAY(GETDATE()),
                        DATEPART(HOUR, @current_slot_start),
                        DATEPART(MINUTE, @current_slot_start), 0, 0);

                -- Queue NOT started ? nothing happens before the scheduled
                --   start, so measure from start time, never from 'now'.
                -- Queue running / doctor late ? measure from now.
                IF @is_queue_started = 0 AND @slot_start_dt > GETDATE()
                    SET @base_time = @slot_start_dt;
                ELSE
                    SET @base_time = GETDATE();

                SET @arrival_time = DATEADD(MINUTE, CEILING(@estimated_time), @base_time);

                -- Never in the past
                IF @arrival_time < GETDATE()
                    SET @arrival_time = GETDATE();

                -- ?? Never before the scheduled start while queue not started
                IF @is_queue_started = 0 AND @arrival_time < @slot_start_dt
                    SET @arrival_time = @slot_start_dt;

                -- Round UP to next 5-min mark (clean display, like Practo)
                -- NOTE: use a midnight DATETIME (not DATE) � DATEADD(MINUTE,..)
                --       is not allowed on the DATE type.
                SET @mins_from_mid = DATEDIFF(MINUTE,
                                              DATEADD(DAY, DATEDIFF(DAY, 0, @arrival_time), 0),
                                              @arrival_time);
                SET @arrival_time  = DATEADD(MINUTE,
                                             ((@mins_from_mid + 4) / 5) * 5,
                                             DATEADD(DAY, DATEDIFF(DAY, 0, @arrival_time), 0));
            END

            --------------------------------------------------
            -- RESPONSE
            --------------------------------------------------
            SELECT 1 AS success,
                   @my_queue AS my_queue_number,
                   @patients_ahead AS patients_ahead,
                   @queue_size AS queue_size,
                   @total_queue AS total_queue,         -- ?? NEW
                   @current_serving AS current_serving, -- ?? NEW
                   CAST(@adaptive_avg AS DECIMAL(5, 2)) AS avg_time,
                   CASE
                       WHEN DATEDIFF(MINUTE, GETDATE(), @arrival_time) < 0 THEN 0
                       ELSE DATEDIFF(MINUTE, GETDATE(), @arrival_time)
                   END AS estimated_minutes,
                   FORMAT(@arrival_time, 'hh:mm tt') AS estimated_arrival_time,
                   @is_queue_started AS queue_started,
                   @is_my_turn AS is_my_turn,
                   CASE
                       --WHEN @queue_status = 0 THEN
                       --    'Not Started Yet'
                       --WHEN @queue_status = 1
                       --     AND @is_my_turn = 1 THEN
                       --    'Your Turn'
					    WHEN @my_status = 'skipped' THEN        
        'Skipped'
    WHEN @queue_status = 0 THEN
        'Not Started Yet'
    WHEN @queue_status = 1
         AND @is_my_turn = 1 THEN
        'Your Turn'
                       WHEN @queue_status = 1 THEN
                           'Waiting'
                       WHEN @queue_status = 2 THEN
                           'Paused'
                       WHEN @queue_status = 3 THEN
                           'Queue Closed'
                       WHEN @queue_status = 4 THEN
                           'Emergency Paused'
                       ELSE
                           'Unknown'
                   END AS status;
        END
        --------------------------------------------------
        -- QUEUE PREVIEW ESTIMATE (FINAL CORRECT VERSION)
        --------------------------------------------------
        IF @operation = 'QUEUE_PREVIEW_ESTIMATE'
        BEGIN


            --------------------------------------------------
            -- ?? GET NEXT QUEUE NUMBER (NEW BOOKING)
            --------------------------------------------------
            SELECT @my_queue = ISNULL(MAX(queue_number), 0) + 1
            FROM appointments
            WHERE doctor_id = @doctor_id
                  AND appointment_date = CAST(GETDATE() AS DATE)
                  AND booking_type = 1
                  AND slot_id = @slot_id;

            --------------------------------------------------
            -- ?? GET CURRENT QUEUE INFO
            --------------------------------------------------
            SELECT @current_serving = ISNULL(current_patient_id, 0),
                   @queue_started_time = started_at,
                   @base_avg = avg_consultation_time
            FROM doctor_queue
            WHERE doctor_id = @doctor_id
                  AND queue_date = CAST(GETDATE() AS DATE)
                  AND slot_id = @slot_id;

            SET @current_serving = ISNULL(@current_serving, 0);

            --------------------------------------------------
            -- ?? PATIENTS AHEAD (REAL COUNT BASED)
            --------------------------------------------------
            SELECT @patients_ahead = COUNT(*)
            FROM appointments
            WHERE doctor_id = @doctor_id
                  AND appointment_date = CAST(GETDATE() AS DATE)
                  AND booking_type = 1
                  AND slot_id = @slot_id
                  AND status IN ( 'booked', 'in_progress' );

            SET @queue_size = @patients_ahead;

            --------------------------------------------------
            -- TIME-BASED AVG (FALLBACK)
            --------------------------------------------------
            IF @base_avg IS NULL
            BEGIN
                SET @hour = DATEPART(HOUR, GETDATE());

                SELECT @base_avg = CASE
                                       WHEN @hour < 12 THEN
                                           morning_avg
                                       WHEN @hour < 17 THEN
                                           afternoon_avg
                                       ELSE
                                           evening_avg
                                   END
                FROM doctor_timing
                WHERE doctor_id = @doctor_id AND (@clinic_id IS NULL OR clinic_id = @clinic_id);
            END

            IF @base_avg IS NULL
                SET @base_avg = 7;

            --------------------------------------------------
            -- AVG CONSULT TIME (Practo-style)
            --   measured avg, clamped to a sane 3�30 min band.
            --   NO artificial queue-size scaling.
            --------------------------------------------------
            IF @base_avg < 3  SET @base_avg = 3;
            IF @base_avg > 30 SET @base_avg = 30;

            SET @adaptive_avg = @base_avg;

            --------------------------------------------------
            -- INITIAL ESTIMATION
            --------------------------------------------------
            SET @estimated_time = @patients_ahead * @adaptive_avg;

            --------------------------------------------------
            -- START TIME (REAL OR SCHEDULE)
            --------------------------------------------------

            -- REAL START
            SET @started_at = @queue_started_time;

            -- FALLBACK ? SLOT TIME
            IF @started_at IS NULL
            BEGIN
                SELECT TOP 1
                    @started_at
                        = DATETIMEFROMPARTS(
                                               YEAR(GETDATE()),
                                               MONTH(GETDATE()),
                                               DAY(GETDATE()),
                                               DATEPART(HOUR, ts.start_time),
                                               DATEPART(MINUTE, ts.start_time),
                                               0,
                                               0
                                           )
                FROM doctor_time_slots ts
                WHERE ts.slot_id = @slot_id;
            END

            IF @started_at IS NULL
            BEGIN
                SELECT 0 AS success,
                       'Doctor not available today' AS message;
                RETURN;
            END

            --------------------------------------------------
            -- QUEUE STARTED CHECK
            --------------------------------------------------
            IF @started_at <= GETDATE()
                SET @is_queue_started = 1;
            ELSE
                SET @is_queue_started = 0;

            --------------------------------------------------
            -- FINAL ARRIVAL TIME
            --------------------------------------------------
            IF @patients_ahead = 0
               AND @is_queue_started = 1
            BEGIN
                SET @estimated_time = 0;
                SET @arrival_time = GETDATE();
                SET @is_my_turn = 1;
            END
            ELSE
            BEGIN
                -- Scheduled session start as today's datetime
                SELECT @slot_start_dt =
                    DATETIMEFROMPARTS(
                        YEAR(GETDATE()), MONTH(GETDATE()), DAY(GETDATE()),
                        DATEPART(HOUR, ts.start_time),
                        DATEPART(MINUTE, ts.start_time), 0, 0)
                FROM doctor_time_slots ts
                WHERE ts.slot_id = @slot_id;

                -- Queue NOT started ? measure from scheduled start, not 'now'.
                IF @is_queue_started = 0
                   AND @slot_start_dt IS NOT NULL
                   AND @slot_start_dt > GETDATE()
                    SET @base_time = @slot_start_dt;
                ELSE
                    SET @base_time = GETDATE();

                SET @arrival_time = DATEADD(MINUTE, CEILING(@estimated_time), @base_time);

                -- Never in the past
                IF @arrival_time < GETDATE()
                    SET @arrival_time = GETDATE();

                -- ?? Never before the scheduled start while queue not started
                IF @is_queue_started = 0
                   AND @slot_start_dt IS NOT NULL
                   AND @arrival_time < @slot_start_dt
                    SET @arrival_time = @slot_start_dt;

                -- Round UP to next 5-min mark (clean display, like Practo)
                -- NOTE: use a midnight DATETIME (not DATE) � DATEADD(MINUTE,..)
                --       is not allowed on the DATE type.
                SET @mins_from_mid = DATEDIFF(MINUTE,
                                              DATEADD(DAY, DATEDIFF(DAY, 0, @arrival_time), 0),
                                              @arrival_time);
                SET @arrival_time  = DATEADD(MINUTE,
                                             ((@mins_from_mid + 4) / 5) * 5,
                                             DATEADD(DAY, DATEDIFF(DAY, 0, @arrival_time), 0));
            END

            --------------------------------------------------
            -- RESPONSE
            --------------------------------------------------
            SELECT 1 AS success,
                   @my_queue AS predicted_queue_number,
                   @patients_ahead AS patients_ahead,
                   @queue_size AS current_queue_size,
                   CAST(@adaptive_avg AS DECIMAL(5, 2)) AS avg_time,
                   CASE
                       WHEN DATEDIFF(MINUTE, GETDATE(), @arrival_time) < 0 THEN 0
                       ELSE DATEDIFF(MINUTE, GETDATE(), @arrival_time)
                   END AS estimated_minutes,
                   FORMAT(@arrival_time, 'hh:mm tt') AS estimated_arrival_time,
                   @is_queue_started AS queue_started,
                   @is_my_turn AS is_my_turn,
                   CASE
                       WHEN @is_queue_started = 0 THEN
                           'Not Started Yet'
                       WHEN @is_my_turn = 1 THEN
                           'Your Turn'
                       ELSE
                           'Waiting'
                   END AS status;
        END


        IF @operation = 'CHECK_QUEUE_BOOKING'
        BEGIN
            DECLARE @is_queue_available BIT = 0;
            DECLARE @is_booking_started BIT = 0;
            DECLARE @queue_length INT = 0;
            DECLARE @queue_start_time DATETIME;
            DECLARE @current_time DATETIME = GETDATE();
            DECLARE @q_start_before INT;

            --------------------------------------------------
            -- ?? CHECK QUEUE SLOT EXISTS TODAY
            --------------------------------------------------
            IF EXISTS
            (
                SELECT 1
                FROM doctor_availability da
                    JOIN doctor_time_slots ts
                        ON da.availability_id = ts.availability_id
                WHERE da.doctor_id = @doctor_id
                      AND da.is_enabled = 1
                      AND da.day_of_week = DATENAME(WEEKDAY, GETDATE())
                      AND ts.booking_mode IN ( 1, 3 )
            )
            BEGIN
                SET @is_queue_available = 1;
            END

            --------------------------------------------------
            -- ? IF NO QUEUE AVAILABLE
            --------------------------------------------------
            IF @is_queue_available = 0
            BEGIN
                SELECT 0 AS success,
                       'Queue booking not available for today' AS message;
                RETURN;
            END

            --------------------------------------------------
            -- ?? GET QUEUE SLOT START TIME + MAX LENGTH
            --------------------------------------------------
            SELECT TOP 1
                @queue_start_time
                    = DATETIMEFROMPARTS(
                                           YEAR(GETDATE()),
                                           MONTH(GETDATE()),
                                           DAY(GETDATE()),
                                           DATEPART(HOUR, ts.start_time),
                                           DATEPART(MINUTE, ts.start_time),
                                           0,
                                           0
                                       ),
                @max_queue_length = ts.max_queue_length
            FROM doctor_availability da
                JOIN doctor_time_slots ts
                    ON da.availability_id = ts.availability_id
            WHERE da.doctor_id = @doctor_id
                  AND da.is_enabled = 1
                  AND da.day_of_week = DATENAME(WEEKDAY, GETDATE())
                  AND ts.booking_mode IN ( 1, 3 )
            ORDER BY ts.start_time;

            --------------------------------------------------
            -- ?? GET q_start_before FROM doctor_login
            --------------------------------------------------
            SELECT @q_start_before = q_start_before
            FROM doctor_login
            WHERE doctor_id = @doctor_id;

            --------------------------------------------------
            -- ?? CALCULATE BOOKING START TIME
            --------------------------------------------------
            IF @q_start_before IS NOT NULL
            BEGIN
                SET @queue_start_time = DATEADD(MINUTE, -@q_start_before, @queue_start_time);
            END

            --------------------------------------------------
            -- ?? CHECK BOOKING STARTED OR NOT
            --------------------------------------------------
            IF @current_time >= @queue_start_time
                SET @is_booking_started = 1;

            --------------------------------------------------
            -- ?? GET CURRENT QUEUE LENGTH
            --------------------------------------------------
            SELECT @queue_length = ISNULL(total_queue, 0)
            FROM doctor_queue
            WHERE doctor_id = @doctor_id
                  AND queue_date = CAST(GETDATE() AS DATE);

            --------------------------------------------------
            -- ?? CHECK MAX QUEUE LIMIT
            --------------------------------------------------
            DECLARE @is_full BIT = 0;

            IF @max_queue_length IS NOT NULL
               AND @queue_length >= @max_queue_length
                SET @is_full = 1;

            --------------------------------------------------
            -- RESPONSE
            --------------------------------------------------
            SELECT 1 AS success,
                   @is_queue_available AS is_queue_available,
                   @is_booking_started AS is_booking_started,
                   @queue_length AS current_queue_length,
                   @max_queue_length AS max_queue_length,
                   @is_full AS is_queue_full,
                   FORMAT(@queue_start_time, 'hh:mm tt') AS booking_start_time;
        END



        IF @operation = 'TOMORROW_PATIENT_APPOINTMENTS'
        BEGIN
            SELECT a.appointment_id,
                   a.appointment_date,
                   d.name AS doctor_name,
                   p.token AS patient_token
            FROM appointments a
                INNER JOIN doctor_login d
                    ON d.doctor_id = a.doctor_id
                INNER JOIN patients p
                    ON p.patient_id = a.patient_id
            WHERE CAST(a.appointment_date AS DATE) = CAST(DATEADD(DAY, 1, GETDATE()) AS DATE)
            ORDER BY a.queue_number;
        END


        IF @operation = 'YESTERDAY_COMPLETED_PATIENTS'
        BEGIN
            SELECT a.appointment_id,
                   a.appointment_date,
                   a.queue_number,
                   d.name AS doctor_name,
                   CASE
                       WHEN a.user_type = 2 THEN
                           p_main.token
                       ELSE
                           p.token
                   END AS patient_token
            FROM appointments a
                INNER JOIN doctor_login d
                    ON d.doctor_id = a.doctor_id

                -- Direct patient (user_type = 1)
                LEFT JOIN patients p
                    ON p.patient_id = a.patient_id
                       AND a.user_type <> 2

                -- For family member (user_type = 2)
                LEFT JOIN family_members fm
                    ON fm.member_id = a.patient_id
                       AND a.user_type = 2

                -- Get token using family_id (main member)
                LEFT JOIN patients p_main
                    ON p_main.patient_id = fm.family_id
                       AND a.user_type = 2
            WHERE CAST(a.appointment_date AS DATE) = CAST(DATEADD(DAY, -1, GETDATE()) AS DATE)
                  AND a.status = 'completed'
            ORDER BY a.queue_number;
        END


    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK;
        SELECT 0 AS success,
               ERROR_MESSAGE() AS message;
    END CATCH
END



GO
/****** Object:  StoredProcedure [dbo].[sp_doc]    Script Date: 15-10-2026 12:09:44 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[sp_doc]
AS
BEGIN
SET NOCOUNT ON;

/*
============================================================
APPOINTMENT SYSTEM - FINAL DOCUMENTATION (QUEUE + SLOT ENGINE)
============================================================

OVERVIEW
------------------------------------------------------------
System supports TWO booking types:

1. QUEUE BASED (booking_type = 1)
2. SLOT BASED  (booking_type = 2)

Both flows are STRICTLY separated internally but handled
through SAME stored procedure using @operation.

All operations are:
? appointment_id driven
? state-machine based
? production-safe

------------------------------------------------------------


============================================================
TABLES
============================================================

TABLE: appointments
------------------------------------------------------------
appointment_id
doctor_id
patient_id        ? can store patient OR family member id
user_type         ? 1 = patient, 2 = family member
appointment_date
start_time
end_time
booking_type      ? 1 = Queue, 2 = Slot
queue_number
status
created_at

STATUS FLOW:
------------------------------------------------------------
booked ? in_progress ? completed
       ? skipped ? in_progress ? completed
       ? cancelled


TABLE: doctor_queue
------------------------------------------------------------
queue_id
doctor_id
queue_date
current_serving        ? queue_number
current_queue_no       ? patient_id
total_queue
completed_count
avg_consultation_time
queue_status           ? 1=Active, 2=Paused, 3=Stopped
started_at
stopped_at


============================================================
CORE DESIGN RULES
============================================================

1. appointment_id is SINGLE SOURCE OF TRUTH
2. NEVER rely on queue_number for updates
3. Only ONE active (in_progress) per doctor per day
4. Queue and Slot NEVER run together
5. doctor_queue is ONLY for queue tracking

------------------------------------------------------------


============================================================
BOOKING LOGIC
============================================================

SLOT BOOKING:
------------------------------------------------------------
- Fixed time slots
- start_time & end_time predefined
- No runtime modification

QUEUE BOOKING:
------------------------------------------------------------
- Only allowed for TODAY
- queue_number auto increment
- doctor_queue auto maintained


============================================================
SESSION MANAGEMENT (IMPORTANT)
============================================================

START_SESSION
------------------------------------------------------------
booked/skipped ? in_progress

QUEUE:
- sets start_time
- updates doctor_queue pointer

SLOT:
- only updates status


END_SESSION
------------------------------------------------------------
in_progress ? completed

QUEUE:
- sets end_time
- increments completed_count
- auto stops queue if no patients

SLOT:
- only status update


NEXT_SESSION
------------------------------------------------------------
COMPLETE current + START next

QUEUE:
- completes current
- finds next by queue_number
- starts next
- updates doctor_queue

SLOT:
- completes current
- starts next slot (by start_time)


SKIP_SESSION
------------------------------------------------------------
booked/in_progress ? skipped

QUEUE:
- skips current
- moves to next
- updates pointer

SLOT:
- skips slot
- activates next


RECALL_SESSION
------------------------------------------------------------
skipped ? in_progress

QUEUE:
- updates pointer
- resumes skipped patient

SLOT:
- directly in_progress


============================================================
QUEUE MANAGEMENT
============================================================

QUEUE_START
------------------------------------------------------------
- Initializes queue
- No patient auto assigned

QUEUE_PAUSE
------------------------------------------------------------
- queue_status = 2

QUEUE_STOP
------------------------------------------------------------
- queue_status = 3

QUEUE_STATUS
------------------------------------------------------------
- total_queue
- current_serving
- waiting_count


============================================================
QUEUE ESTIMATION
============================================================

Formula:
------------------------------------------------------------
patients_ahead = my_queue - current_serving - 1

estimated_wait =
    patients_ahead * avg_consultation_time

default avg = 7 minutes


============================================================
AVG CONSULTATION TIME
============================================================

DOCTOR_AVG_TIME:
------------------------------------------------------------
Priority:
1. Today�s completed appointments
2. Last 7 days
3. Default value


============================================================
PATIENT HANDLING
============================================================

patient_id column stores:
------------------------------------------------------------
- patient id (user_type = 1)
- family member id (user_type = 2)

No separate column used.


============================================================
IMPORTANT EDGE CASES HANDLED
============================================================

? Skip patient and recall later
? Queue stops only when no booked/skipped left
? Only one active session allowed
? Appointment_id validation everywhere
? Safe updates using @@ROWCOUNT
? Slot integrity preserved (no time overwrite)


============================================================
FINAL ARCHITECTURE
============================================================

QUEUE:
------------------------------------------------------------
Stateful system (uses doctor_queue)

SLOT:
------------------------------------------------------------
Stateless system (status driven)

------------------------------------------------------------

FINAL RULE:
------------------------------------------------------------
"QUEUE = state machine"
"SLOT  = schedule system"

============================================================
*/


END
GO
/****** Object:  StoredProcedure [dbo].[sp_doctor_leave]    Script Date: 15-10-2026 12:09:44 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--USE [QLess]
--GO
--/****** Object:  StoredProcedure [dbo].[sp_doctor_leave]    Script Date: 27-06-2026 12:26:08 ******/
--SET ANSI_NULLS ON
--GO
--SET QUOTED_IDENTIFIER ON
--GO

--ALTER   PROCEDURE [dbo].[sp_doctor_leave]
--    @operation  VARCHAR(30),
--    @leave_id   INT           = NULL,
--    @doctor_id  INT           = NULL,
--    @from_date  DATE          = NULL,
--    @to_date    DATE          = NULL,
--    @reason     NVARCHAR(200) = NULL
--AS
--BEGIN
--    SET NOCOUNT ON;

--    -- range madhle kiti future booked/in_progress appts (confirm dialog sathi)
--    IF @operation = 'COUNT_AFFECTED'
--    BEGIN
--        SELECT COUNT(*) AS cnt
--        FROM appointments a
--        JOIN doctor_time_slots  dts ON dts.slot_id        = a.slot_id
--        JOIN doctor_availability da  ON da.availability_id = dts.availability_id
--        WHERE da.doctor_id = @doctor_id
--          AND a.appointment_date BETWEEN @from_date AND @to_date
--          AND a.appointment_date >= CAST(GETDATE() AS DATE)
--          AND LOWER(a.status) IN ('booked', 'in_progress');
--        RETURN;
--    END

--    -- validate + insert, navin leave_id return
--    IF @operation = 'ADD_LEAVE'
--    BEGIN
--        IF @from_date IS NULL OR @to_date IS NULL OR @from_date > @to_date
--        BEGIN
--            SELECT CAST(NULL AS INT) AS leave_id, 'INVALID_RANGE' AS error;
--            RETURN;
--        END
--        IF @from_date < CAST(GETDATE() AS DATE)
--        BEGIN
--            SELECT CAST(NULL AS INT) AS leave_id, 'PAST_DATE' AS error;
--            RETURN;
--        END

--        INSERT INTO dbo.doctor_leave (doctor_id, from_date, to_date, reason)
--        VALUES (@doctor_id, @from_date, @to_date, @reason);

--        SELECT CAST(SCOPE_IDENTITY() AS INT) AS leave_id,
--               CAST(NULL AS VARCHAR(20))     AS error;
--        RETURN;
--    END

--    -- range madhle sagle future appts cancel + patient FCM tokens return
--    -- (token AS fcm_token alias kela -> Node madhe r.fcm_token barobar)
--    IF @operation = 'APPLY_LEAVE_CANCEL'
--    BEGIN
--        DECLARE @affected TABLE (appointment_id INT, patient_id INT);

--        INSERT INTO @affected (appointment_id, patient_id)
--        SELECT a.appointment_id, a.patient_id
--        FROM appointments a
--        JOIN doctor_time_slots  dts ON dts.slot_id        = a.slot_id
--        JOIN doctor_availability da  ON da.availability_id = dts.availability_id
--        WHERE da.doctor_id = @doctor_id
--          AND a.appointment_date BETWEEN @from_date AND @to_date
--          AND a.appointment_date >= CAST(GETDATE() AS DATE)
--          AND LOWER(a.status) IN ('booked', 'in_progress');

--        UPDATE appointments
--        SET status = 'CancleD'
--        WHERE appointment_id IN (SELECT appointment_id FROM @affected);

--        SELECT p.token AS fcm_token
--        FROM @affected af
--        JOIN patients p ON p.patient_id = af.patient_id
--        WHERE p.token IS NOT NULL
--          AND LTRIM(RTRIM(p.token)) <> '';
--        RETURN;
--    END

--    -- doctor chya "My Leaves" list sathi upcoming active leaves
--    IF @operation = 'LIST_LEAVE'
--    BEGIN
--        SELECT leave_id,
--               doctor_id,
--               CONVERT(VARCHAR(10), from_date, 23) AS from_date,
--               CONVERT(VARCHAR(10), to_date,   23) AS to_date,
--               reason
--        FROM dbo.doctor_leave
--        WHERE doctor_id = @doctor_id
--          AND is_active = 1
--          AND to_date  >= CAST(GETDATE() AS DATE)
--        ORDER BY from_date;
--        RETURN;
--    END

--    -- planned leave soft-delete (already-cancelled appts restore hot NAHIT)
--    IF @operation = 'CANCEL_LEAVE'
--    BEGIN
--        UPDATE dbo.doctor_leave
--        SET is_active = 0
--        WHERE leave_id  = @leave_id
--          AND doctor_id = @doctor_id;

--        SELECT @leave_id AS leave_id;
--        RETURN;
--    END

--    -- patient app calendar madhe greyed-out dates
--    IF @operation = 'GET_LEAVE_DATES'
--    BEGIN
--        SELECT CONVERT(VARCHAR(10), from_date, 23) AS from_date,
--               CONVERT(VARCHAR(10), to_date,   23) AS to_date
--        FROM dbo.doctor_leave
--        WHERE doctor_id = @doctor_id
--          AND is_active = 1
--          AND to_date  >= CAST(GETDATE() AS DATE)
--        ORDER BY from_date;
--        RETURN;
--    END

--    -- @from_date kontya active leave madhe yeto ka � booking hard-guard
--    IF @operation = 'IS_BLOCKED'
--    BEGIN
--        SELECT CASE WHEN EXISTS (
--            SELECT 1
--            FROM dbo.doctor_leave
--            WHERE doctor_id = @doctor_id
--              AND is_active  = 1
--              AND @from_date BETWEEN from_date AND to_date
--        ) THEN 1 ELSE 0 END AS blocked;
--        RETURN;
--    END
--END




-- 2. SP update with @clinic_id parameter
CREATE PROCEDURE [dbo].[sp_doctor_leave]
    @operation  VARCHAR(30),
    @leave_id   INT           = NULL,
    @doctor_id  INT           = NULL,
    @from_date  DATE          = NULL,
    @to_date    DATE          = NULL,
    @reason     NVARCHAR(200) = NULL,
    @clinic_id  VARCHAR(20)   = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @operation = 'COUNT_AFFECTED'
    BEGIN
        SELECT COUNT(*) AS cnt
        FROM appointments a
        JOIN doctor_time_slots  dts ON dts.slot_id        = a.slot_id
        JOIN doctor_availability da  ON da.availability_id = dts.availability_id
        WHERE da.doctor_id = @doctor_id
          AND (@clinic_id IS NULL OR da.clinic_id = @clinic_id)
          AND a.appointment_date BETWEEN @from_date AND @to_date
          AND a.appointment_date >= CAST(GETDATE() AS DATE)
          AND LOWER(a.status) IN ('booked', 'in_progress');
        RETURN;
    END

    IF @operation = 'ADD_LEAVE'
    BEGIN
        IF @from_date IS NULL OR @to_date IS NULL OR @from_date > @to_date
        BEGIN
            SELECT CAST(NULL AS INT) AS leave_id, 'INVALID_RANGE' AS error;
            RETURN;
        END
        IF @from_date < CAST(GETDATE() AS DATE)
        BEGIN
            SELECT CAST(NULL AS INT) AS leave_id, 'PAST_DATE' AS error;
            RETURN;
        END

        INSERT INTO dbo.doctor_leave (doctor_id, clinic_id, from_date, to_date, reason)
        VALUES (@doctor_id, @clinic_id, @from_date, @to_date, @reason);

        SELECT CAST(SCOPE_IDENTITY() AS INT) AS leave_id,
               CAST(NULL AS VARCHAR(20))     AS error;
        RETURN;
    END

    IF @operation = 'APPLY_LEAVE_CANCEL'
    BEGIN
        DECLARE @affected TABLE (appointment_id INT, patient_id INT);

        INSERT INTO @affected (appointment_id, patient_id)
        SELECT a.appointment_id, a.patient_id
        FROM appointments a
        JOIN doctor_time_slots  dts ON dts.slot_id        = a.slot_id
        JOIN doctor_availability da  ON da.availability_id = dts.availability_id
        WHERE da.doctor_id = @doctor_id
          AND (@clinic_id IS NULL OR da.clinic_id = @clinic_id)
          AND a.appointment_date BETWEEN @from_date AND @to_date
          AND a.appointment_date >= CAST(GETDATE() AS DATE)
          AND LOWER(a.status) IN ('booked', 'in_progress');

        UPDATE appointments
        SET status = 'CancleD'
        WHERE appointment_id IN (SELECT appointment_id FROM @affected);

        SELECT p.token AS fcm_token
        FROM @affected af
        JOIN patients p ON p.patient_id = af.patient_id
        WHERE p.token IS NOT NULL
          AND LTRIM(RTRIM(p.token)) <> '';
        RETURN;
    END

    IF @operation = 'LIST_LEAVE'
    BEGIN
        SELECT leave_id,
               doctor_id,
               clinic_id,
               CONVERT(VARCHAR(10), from_date, 23) AS from_date,
               CONVERT(VARCHAR(10), to_date,   23) AS to_date,
               reason
        FROM dbo.doctor_leave
        WHERE doctor_id = @doctor_id
          AND (@clinic_id IS NULL OR clinic_id = @clinic_id)
          AND is_active = 1
          AND to_date  >= CAST(GETDATE() AS DATE)
        ORDER BY from_date;
        RETURN;
    END

    IF @operation = 'CANCEL_LEAVE'
    BEGIN
        UPDATE dbo.doctor_leave
        SET is_active = 0
        WHERE leave_id  = @leave_id
          AND doctor_id = @doctor_id
          AND (@clinic_id IS NULL OR clinic_id = @clinic_id);

        SELECT @leave_id AS leave_id;
        RETURN;
    END

   IF @operation = 'GET_LEAVE_DATES'
BEGIN
    SELECT CONVERT(VARCHAR(10), from_date, 23) AS from_date,
           CONVERT(VARCHAR(10), to_date,   23) AS to_date
    FROM dbo.doctor_leave
    WHERE doctor_id = @doctor_id
      AND (clinic_id IS NULL OR clinic_id = @clinic_id)  -- ? ?? ???
      AND is_active = 1
      AND to_date  >= CAST(GETDATE() AS DATE)
    ORDER BY from_date;
    RETURN;
END


    IF @operation = 'IS_BLOCKED'
    BEGIN
        SELECT CASE WHEN EXISTS (
            SELECT 1
            FROM dbo.doctor_leave
            WHERE doctor_id = @doctor_id
              AND (@clinic_id IS NULL OR clinic_id = @clinic_id)
              AND is_active  = 1
              AND @from_date BETWEEN from_date AND to_date
        ) THEN 1 ELSE 0 END AS blocked;
        RETURN;
    END
END
GO
/****** Object:  StoredProcedure [dbo].[sp_doctor_login]    Script Date: 15-10-2026 12:09:44 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--USE [QLess]
--GO
--/****** Object:  StoredProcedure [dbo].[sp_doctor_login]    Script Date: 23-06-2026 11:10:09 ******/
--SET ANSI_NULLS ON
--GO
--SET QUOTED_IDENTIFIER ON
--GO

--ALTER PROCEDURE [dbo].[sp_doctor_login]
--(
--    @operation          NVARCHAR(50),
--    -- Doctor fields
--    @doctor_id          INT = NULL,
--    @name               NVARCHAR(50) = NULL,
--    @email              NVARCHAR(max) = NULL,
--    @mobile             NVARCHAR(20) = NULL,
--    @qualification      NVARCHAR(max) = NULL,
--    @license_no         NVARCHAR(50) = NULL,
--    @experience         INT = NULL,
--    @specialization     NVARCHAR(50) = NULL,
--    @role_id            INT = NULL,
--	@gender_id INT =NULL,
--	@q_start_before INT = NULL,
--	@role NVARCHAR(20) = NULL,
--	@token NVARCHAR(MAX) = NULL,
--	    @image       NVARCHAR(MAX) = NULL,
--    -- Clinic fields
--    @clinic_id          NVARCHAR(50) = NULL,
--    @clinic_name        NVARCHAR(50) = NULL,
--    @clinic_address     NVARCHAR(100) = NULL,
--    @latitude           DECIMAL(10,7) = NULL,
--    @longitude          DECIMAL(10,7) = NULL,
--    @consultation_fee   DECIMAL(10,2) = NULL,
--    @website_name       NVARCHAR(50) = NULL,
--    @clinic_email       NVARCHAR(max) = NULL,
--    @clinic_contact     NVARCHAR(20) = NULL,
--    @image_url          NVARCHAR(MAX) = NULL,
--	@sort_order INT = NULL
--)
--AS
--BEGIN
--SET NOCOUNT ON;
-----------------------------------------------------------
---- INSERT (Create Clinic + Doctor)
-----------------------------------------------------------
--IF @operation = 'Insert'
--BEGIN
--    BEGIN TRY
--        BEGIN TRANSACTION;
		
--        -- ? CHECK FIRST
--        IF EXISTS (
--            SELECT 1 
--            FROM dbo.doctor_login 
--            WHERE mobile = @mobile
--            AND active_status = 0
--        )
--        BEGIN
--            SELECT 
--                0 AS success,
--                'Mobile number already exists' AS message;
--            ROLLBACK TRANSACTION;
--            RETURN;
--        END

--        DECLARE @next_no INT;

--        -- Generate Clinic ID like CL001
--        SELECT @next_no =
--        ISNULL(MAX(CAST(SUBSTRING(clinic_id,3,10) AS INT)),0) + 1
--        FROM dbo.clinics
--        WHERE clinic_id LIKE 'CL%';

--        SET @clinic_id =
--        'CL' + RIGHT('000' + CAST(@next_no AS NVARCHAR),3);

--        -------------------------------------------------
--        -- Insert Clinic
--        -------------------------------------------------
--        INSERT INTO dbo.clinics
--        (
--            clinic_id,
--            clinic_name,
--            clinic_address,
--            latitude,
--            longitude,
--            consultation_fee,
--            website_name,
--            clinic_email,
--            clinic_contact,
--            image_url,
--            active_status,
--            is_verified
--        )
--        VALUES
--        (
--            @clinic_id,
--            @clinic_name,
--            @clinic_address,
--            @latitude,
--            @longitude,
--            @consultation_fee,
--            @website_name,
--            @clinic_email,
--            @clinic_contact,
--            @image_url,
--            0,
--            1
--        );

--        -------------------------------------------------
--        -- Insert Doctor
--        -------------------------------------------------
--        INSERT INTO dbo.doctor_login
--        (
--            name,
--            email,
--            mobile,
--            qualification,
--            license_no,
--            experience,
--            specialization,
--			created_at,
--            role_id,
--            clinic_id,
--            active_status,
--            is_verified,
--			gender_id,
--			image
--        )
--        VALUES
--        (
--            @name,
--            @email,
--            @mobile,
--            @qualification,
--            @license_no,
--            @experience,
--            @specialization,
--			getdate(),
--            @role_id,
--            @clinic_id,
--            0,
--            1,
--			@gender_id,
--			@image
--        );

--        SET @doctor_id = SCOPE_IDENTITY();

--        COMMIT TRANSACTION;

--        SELECT 
--            @doctor_id AS doctor_id,
--            @clinic_id AS clinic_id;

--    END TRY
--    BEGIN CATCH
--        ROLLBACK TRANSACTION;

--        SELECT 
--            ERROR_MESSAGE() AS ErrorMessage,
--            ERROR_LINE() AS ErrorLine;
--    END CATCH

--RETURN;
--END


--IF @operation = 'saveFirebaseToken'
--BEGIN
--	 IF @role = 'doctor'
--      UPDATE doctor_login
--      SET token = @token
--      WHERE mobile = @mobile;

--    ELSE IF @role = 'patient'
--      UPDATE Patients
--      SET token = @token
--      WHERE mobile_no = @mobile;
--END

-----------------------------------------------------------
---- UPDATE (Doctor + Clinic)
-----------------------------------------------------------
--IF @operation = 'Update'
--BEGIN
--    BEGIN TRY
--        BEGIN TRANSACTION;

--        -------------------------------------------------
--        -- Update Doctor
--        -------------------------------------------------
--        UPDATE dbo.doctor_login
--        SET
--            name = @name,
--            email = @email,
--            mobile = @mobile,
--            qualification = @qualification,
--            license_no = @license_no,
--            experience = @experience,
--            specialization = @specialization,
--            role_id = @role_id,
--			gender_id=@gender_id
--        WHERE doctor_id = @doctor_id;

--        -------------------------------------------------
--        -- Update Clinic
--        -------------------------------------------------
--        UPDATE dbo.clinics
--        SET
--            clinic_name = @clinic_name,
--            clinic_address = @clinic_address,
--            latitude = @latitude,
--            longitude = @longitude,
--            consultation_fee = @consultation_fee,
--            website_name = @website_name,
--            clinic_email = @clinic_email,
--            clinic_contact = @clinic_contact,
--            image_url = @image_url
--        WHERE clinic_id =
--        (
--            SELECT clinic_id 
--            FROM dbo.doctor_login 
--            WHERE doctor_id = @doctor_id
--        );

--        COMMIT TRANSACTION;

--        --SELECT @doctor_id AS doctor_id;
		
---- WITH this:
--DECLARE @returned_clinic_id NVARCHAR(50);
--SELECT @returned_clinic_id = clinic_id 
--FROM dbo.doctor_login 
--WHERE doctor_id = @doctor_id;

--SELECT @doctor_id AS doctor_id, @returned_clinic_id AS clinic_id;

--    END TRY
--    BEGIN CATCH
--        ROLLBACK TRANSACTION;

--        SELECT 
--            ERROR_MESSAGE() AS ErrorMessage,
--            ERROR_LINE() AS ErrorLine;
--    END CATCH

--RETURN;
--END

-----------------------------------------------------------
---- FETCH DOCTOR DETAILS
-----------------------------------------------------------
--IF @operation = 'FetchDoctor'
--BEGIN
--    SELECT 
--        d.doctor_id,
--        d.name,
--        d.email,
--        d.mobile,
--        d.qualification,
--        d.license_no,
--        d.experience,
--        d.specialization,
--        d.clinic_id,
--        c.clinic_name,
--        c.clinic_address,
--        c.consultation_fee,
--        c.clinic_contact,
--        c.clinic_email
--    FROM dbo.doctor_login d
--    LEFT JOIN dbo.clinics c
--        ON d.clinic_id = c.clinic_id
--    WHERE d.mobile = @mobile;

--RETURN;
--END




-----------------------------------------------------------
---- FETCH ALL DOCTORS
-----------------------------------------------------------
--IF @operation = 'FetchDoctors'
--BEGIN
--    SELECT * 
--    FROM dbo.doctor_login
--    WHERE clinic_id = @clinic_id
--    AND active_status = 0;
--END

-----------------------------------------------------------
---- DELETE DOCTOR (Soft Delete)
-----------------------------------------------------------
--IF @operation = 'DeleteDoctor'
--BEGIN
--    UPDATE dbo.doctor_login
--    SET active_status = 1
--    WHERE doctor_id = @doctor_id;

--    SELECT 1 AS success, 'Doctor deleted successfully' AS message;
--END




-----------------------------------------------------------
---- CHECK PHONE
-----------------------------------------------------------
--IF @operation = 'check_phone_doctor'
--BEGIN

--    SELECT *
--    FROM dbo.doctor_login_vw
--    WHERE mobile = @mobile and 
--     doc_active_status = 0 and doc_is_verified=0;

--RETURN;
--END


-----------------------------------------------------------
---- CHECK PHONE
-----------------------------------------------------------
--IF @operation = 'doctor_mobile_exist'

--BEGIN
--    SELECT 
--        doctor_id,
--        mobile,
--        doc_active_status,
--        doc_is_verified
--    FROM dbo.doctor_login_vw
--    WHERE mobile = @mobile 
--      AND doc_active_status = 0 

--    RETURN;
--END

---- DOCTOR IMAGE
--IF @operation = 'uploadDoctorImg'
--BEGIN
--    UPDATE doctor_login 
--    SET image = @image 
--    WHERE doctor_id = @doctor_id;

--    RETURN;
--END

---- CLINIC IMAGE
--IF @operation = 'uploadClinicImg'
--BEGIN
--    UPDATE clinics 
--    SET image_url = @image_url 
--    WHERE clinic_id = @clinic_id;

--    RETURN;
--END
---- CLINIC GALLERY IMAGES
--IF @operation='uploadClinicGallery'
--BEGIN

--   INSERT INTO dbo.clinic_images
--   (
--      clinic_id,
--      image_url,
--      sort_order,
--      active_status,
--      created_at
--   )
--   VALUES
--   (
--      @clinic_id,
--      @image_url,
--      @sort_order,
--      0,
--      GETDATE()
--   );

--RETURN;
--END
--IF @operation = 'Insert_Q_StartTime'
--BEGIN
--    UPDATE doctor_login
--    SET q_start_before = @q_start_before -- save in minutes
--    WHERE doctor_id = @doctor_id
--END

--IF @operation = 'fetchClinicGallery'
--BEGIN
--    SELECT clinic_image_id, clinic_id, image_url, sort_order
--    FROM dbo.clinic_images
--    WHERE clinic_id = @clinic_id
--      AND active_status = 0
--    ORDER BY sort_order;
--    RETURN;
--END

--IF @operation = 'deleteClinicGallery'
--BEGIN
--   delete from dbo.clinic_images
--    WHERE clinic_id = @clinic_id
--      AND image_url IN (
--          SELECT value 
--          FROM STRING_SPLIT(@image_url, ',')
--      );

--    SELECT @@ROWCOUNT AS deleted_count, 'Images deleted' AS message;
--    RETURN;
--END






--END

CREATE PROCEDURE [dbo].[sp_doctor_login]
(
    @operation          NVARCHAR(50),
    @doctor_id          INT = NULL,
    @name               NVARCHAR(50) = NULL,
    @email              NVARCHAR(MAX) = NULL,
    @mobile             NVARCHAR(20) = NULL,
    @qualification      NVARCHAR(MAX) = NULL,
    @license_no         NVARCHAR(50) = NULL,
    @experience         INT = NULL,
    @specialization     NVARCHAR(50) = NULL,
    @role_id            INT = NULL,
    @gender_id          INT = NULL,
    @q_start_before     INT = NULL,
    @role               NVARCHAR(20) = NULL,
    @token              NVARCHAR(MAX) = NULL,
    @image              NVARCHAR(MAX) = NULL,
    @clinic_id          NVARCHAR(50) = NULL,
    @clinic_name        NVARCHAR(50) = NULL,
    @clinic_address     NVARCHAR(100) = NULL,
    @latitude           DECIMAL(10,7) = NULL,
    @longitude          DECIMAL(10,7) = NULL,
    @consultation_fee   DECIMAL(10,2) = NULL,
    @website_name       NVARCHAR(50) = NULL,
    @clinic_email       NVARCHAR(MAX) = NULL,
    @clinic_contact     NVARCHAR(20) = NULL,
    @image_url          NVARCHAR(MAX) = NULL,
    @sort_order         INT = NULL
)
AS
BEGIN
SET NOCOUNT ON;

---------------------------------------------------------
-- INSERT
---------------------------------------------------------
IF @operation = 'Insert'
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        IF EXISTS (
            SELECT 1 FROM dbo.doctor_login
            WHERE mobile = @mobile AND active_status = 0
        )
        BEGIN
            SELECT 0 AS success, 'Mobile number already exists' AS message;
            ROLLBACK TRANSACTION;
            RETURN;
        END
		IF EXISTS (
    SELECT 1 FROM dbo.receptionist
    WHERE mobile_no = @mobile AND active_status = 1
)
BEGIN
    SELECT 0 AS success, 'This mobile is already registered as a Receptionist' AS message;
    ROLLBACK TRANSACTION;
    RETURN;
END


        DECLARE @next_no INT;
        SELECT @next_no = ISNULL(MAX(CAST(SUBSTRING(clinic_id,3,10) AS INT)),0) + 1
        FROM dbo.clinics WHERE clinic_id LIKE 'CL%';
        SET @clinic_id = 'CL' + RIGHT('000' + CAST(@next_no AS NVARCHAR), 3);

        INSERT INTO dbo.clinics
            (clinic_id, clinic_name, clinic_address, latitude, longitude,
             consultation_fee, website_name, clinic_email, clinic_contact,
             image_url, active_status, is_verified)
        VALUES
            (@clinic_id, @clinic_name, @clinic_address, @latitude, @longitude,
             @consultation_fee, @website_name, @clinic_email, @clinic_contact,
             @image_url, 0, 1);

        -- is_verified = 0: a freshly-registered doctor is PENDING admin
        -- review until someone approves them via /admin (VerifyDoctor below).
        INSERT INTO dbo.doctor_login
            (name, email, mobile, qualification, license_no, experience,
             specialization, created_at, role_id, clinic_id,
             active_status, is_verified, gender_id, image)
        VALUES
            (@name, @email, @mobile, @qualification, @license_no, @experience,
             @specialization, GETDATE(), @role_id, @clinic_id,
             0, 0, @gender_id, @image);

        SET @doctor_id = SCOPE_IDENTITY();

        UPDATE dbo.clinics
        SET doctor_id = @doctor_id
        WHERE clinic_id = @clinic_id;

        COMMIT TRANSACTION;
        SELECT @doctor_id AS doctor_id, @clinic_id AS clinic_id;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        SELECT ERROR_MESSAGE() AS ErrorMessage, ERROR_LINE() AS ErrorLine;
    END CATCH
    RETURN;
END

---------------------------------------------------------
-- saveFirebaseToken
---------------------------------------------------------
IF @operation = 'saveFirebaseToken'
BEGIN
    IF @role = 'doctor'
        UPDATE doctor_login SET token = @token WHERE mobile = @mobile;
    ELSE IF @role = 'patient'
        UPDATE Patients SET token = @token WHERE mobile_no = @mobile;
    RETURN;
END

---------------------------------------------------------
-- UPDATE
---------------------------------------------------------
IF @operation = 'Update'
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.doctor_login
        SET name = @name, email = @email, mobile = @mobile,
            qualification = @qualification, license_no = @license_no,
            experience = @experience, specialization = @specialization,
            role_id = @role_id, gender_id = @gender_id
        WHERE doctor_id = @doctor_id;

        UPDATE dbo.clinics
        SET clinic_name = @clinic_name, clinic_address = @clinic_address,
            latitude = @latitude, longitude = @longitude,
            consultation_fee = @consultation_fee, website_name = @website_name,
            clinic_email = @clinic_email, clinic_contact = @clinic_contact,
            image_url = @image_url
        WHERE clinic_id = (SELECT clinic_id FROM dbo.doctor_login WHERE doctor_id = @doctor_id);

        COMMIT TRANSACTION;

        DECLARE @returned_clinic_id NVARCHAR(50);
        SELECT @returned_clinic_id = clinic_id FROM dbo.doctor_login WHERE doctor_id = @doctor_id;
        SELECT @doctor_id AS doctor_id, @returned_clinic_id AS clinic_id;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        SELECT ERROR_MESSAGE() AS ErrorMessage, ERROR_LINE() AS ErrorLine;
    END CATCH
    RETURN;
END

---------------------------------------------------------
-- FetchDoctor
---------------------------------------------------------
IF @operation = 'FetchDoctor'
BEGIN
    SELECT d.doctor_id, d.name, d.email, d.mobile, d.qualification,
           d.license_no, d.experience, d.specialization, d.clinic_id,
           c.clinic_name, c.clinic_address, c.consultation_fee,
           c.clinic_contact, c.clinic_email
    FROM dbo.doctor_login d
    LEFT JOIN dbo.clinics c ON d.clinic_id = c.clinic_id
    WHERE d.mobile = @mobile;
    RETURN;
END

---------------------------------------------------------
-- FetchDoctors
---------------------------------------------------------
IF @operation = 'FetchDoctors'
BEGIN
    SELECT * FROM dbo.doctor_login
    WHERE clinic_id = @clinic_id AND active_status = 0;
    RETURN;
END

---------------------------------------------------------
-- DeleteDoctor
---------------------------------------------------------
IF @operation = 'DeleteDoctor'
BEGIN
    UPDATE dbo.doctor_login SET active_status = 1 WHERE doctor_id = @doctor_id;
    SELECT 1 AS success, 'Doctor deleted successfully' AS message;
    RETURN;
END

---------------------------------------------------------
-- ListPendingDoctors — admin approval queue
---------------------------------------------------------
IF @operation = 'ListPendingDoctors'
BEGIN
    SELECT doctor_id, name, email, mobile, qualification, license_no,
           experience, specialization, clinic_id, clinic_name,
           clinic_address, clinic_contact, clinic_email, doc_created_at
    FROM dbo.doctor_login_vw
    WHERE doc_active_status = 0 AND doc_is_verified = 0
    ORDER BY doc_created_at ASC;
    RETURN;
END

---------------------------------------------------------
-- VerifyDoctor — admin approval
---------------------------------------------------------
IF @operation = 'VerifyDoctor'
BEGIN
    UPDATE dbo.doctor_login SET is_verified = 1 WHERE doctor_id = @doctor_id;
    SELECT 1 AS success, 'Doctor verified' AS message;
    RETURN;
END

---------------------------------------------------------
-- check_phone_doctor
---------------------------------------------------------
IF @operation = 'check_phone_doctor'
BEGIN
    SELECT * FROM dbo.doctor_login_vw
    WHERE mobile = @mobile AND doc_active_status = 0 AND doc_is_verified = 0;
    RETURN;
END

---------------------------------------------------------
-- doctor_mobile_exist
---------------------------------------------------------
--IF @operation = 'doctor_mobile_exist'
--BEGIN
--    SELECT doctor_id, mobile, doc_active_status, doc_is_verified
--    FROM dbo.doctor_login_vw
--    WHERE mobile = @mobile AND doc_active_status = 0;
--    RETURN;
--END

IF @operation = 'doctor_mobile_exist'
BEGIN
    SELECT doctor_id, mobile, doc_active_status, doc_is_verified
    FROM dbo.doctor_login_vw
    WHERE mobile = @mobile AND doc_active_status = 0

    UNION ALL

    SELECT NULL AS doctor_id, mobile_no AS mobile, 1 AS doc_active_status, 1 AS doc_is_verified
    FROM dbo.receptionist
    WHERE mobile_no = @mobile AND active_status = 1;
    RETURN;
END

---------------------------------------------------------
-- uploadDoctorImg
---------------------------------------------------------
IF @operation = 'uploadDoctorImg'
BEGIN
    UPDATE doctor_login SET image = @image WHERE doctor_id = @doctor_id;
    RETURN;
END

---------------------------------------------------------
-- uploadClinicImg
---------------------------------------------------------
IF @operation = 'uploadClinicImg'
BEGIN
    UPDATE clinics SET image_url = @image_url WHERE clinic_id = @clinic_id;
    RETURN;
END

---------------------------------------------------------
-- uploadClinicGallery
---------------------------------------------------------
IF @operation = 'uploadClinicGallery'
BEGIN
    INSERT INTO dbo.clinic_images
        (clinic_id, image_url, sort_order, active_status, created_at)
    VALUES (@clinic_id, @image_url, @sort_order, 0, GETDATE());
    RETURN;
END

---------------------------------------------------------
-- Insert_Q_StartTime
---------------------------------------------------------
IF @operation = 'Insert_Q_StartTime'
BEGIN
    UPDATE doctor_login SET q_start_before = @q_start_before WHERE doctor_id = @doctor_id;
    RETURN;
END

---------------------------------------------------------
-- fetchClinicGallery
---------------------------------------------------------
IF @operation = 'fetchClinicGallery'
BEGIN
    SELECT clinic_image_id, clinic_id, image_url, sort_order
    FROM dbo.clinic_images
    WHERE clinic_id = @clinic_id AND active_status = 0
    ORDER BY sort_order;
    RETURN;
END

---------------------------------------------------------
-- deleteClinicGallery
---------------------------------------------------------
IF @operation = 'deleteClinicGallery'
BEGIN
    DELETE FROM dbo.clinic_images
    WHERE clinic_id = @clinic_id
      AND image_url IN (SELECT value FROM STRING_SPLIT(@image_url, ','));
    SELECT @@ROWCOUNT AS deleted_count, 'Images deleted' AS message;
    RETURN;
END

---------------------------------------------------------
-- AddClinic
---------------------------------------------------------
IF @operation = 'AddClinic'
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @next_no2 INT;
        SELECT @next_no2 = ISNULL(MAX(CAST(SUBSTRING(clinic_id,3,10) AS INT)),0) + 1
        FROM dbo.clinics WHERE clinic_id LIKE 'CL%';
        SET @clinic_id = 'CL' + RIGHT('000' + CAST(@next_no2 AS NVARCHAR), 3);

        INSERT INTO dbo.clinics
            (clinic_id, clinic_name, clinic_address, latitude, longitude,
             consultation_fee, website_name, clinic_email, clinic_contact,
             image_url, active_status, is_verified, doctor_id)
        VALUES
            (@clinic_id, @clinic_name, @clinic_address, @latitude, @longitude,
             @consultation_fee, @website_name, @clinic_email, @clinic_contact,
             @image_url, 0, 1, @doctor_id);

        COMMIT TRANSACTION;
        SELECT 1 AS success, @clinic_id AS clinic_id, 'Clinic added' AS message;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        SELECT ERROR_MESSAGE() AS ErrorMessage;
    END CATCH
    RETURN;
END

---------------------------------------------------------
-- GetDoctorClinics
---------------------------------------------------------
IF @operation = 'GetDoctorClinics'
BEGIN
    SELECT
        clinic_id, clinic_name, clinic_address,
        latitude, longitude, consultation_fee,
        clinic_email, clinic_contact,
        website_name, image_url,
        CASE WHEN clinic_id = (
            SELECT clinic_id FROM dbo.doctor_login WHERE doctor_id = @doctor_id
        ) THEN 1 ELSE 0 END AS is_primary
    FROM dbo.clinics
    WHERE doctor_id = @doctor_id
      AND active_status = 0
    ORDER BY is_primary DESC;
    RETURN;
END

---------------------------------------------------------
-- UpdateClinic
---------------------------------------------------------
IF @operation = 'UpdateClinic'
BEGIN
    UPDATE dbo.clinics
    SET clinic_name      = @clinic_name,
        clinic_address   = @clinic_address,
        latitude         = ISNULL(@latitude, latitude),
        longitude        = ISNULL(@longitude, longitude),
        consultation_fee = @consultation_fee,
        website_name     = @website_name,
        clinic_email     = @clinic_email,
        clinic_contact   = @clinic_contact
    WHERE clinic_id = @clinic_id
      AND doctor_id = @doctor_id;
    SELECT 1 AS success, @clinic_id AS clinic_id;
    RETURN;
END

---------------------------------------------------------
-- DeleteClinic
---------------------------------------------------------
IF @operation = 'DeleteClinic'
BEGIN
    -- Primary clinic (doctor_login.clinic_id shi match) delete nahi hoto
    IF EXISTS (
        SELECT 1 FROM dbo.doctor_login
        WHERE doctor_id = @doctor_id AND clinic_id = @clinic_id
    )
    BEGIN
        SELECT 0 AS success, 'Cannot delete primary clinic' AS message;
        RETURN;
    END

    UPDATE dbo.clinics
    SET active_status = 1
    WHERE clinic_id = @clinic_id
      AND doctor_id = @doctor_id;

    SELECT 1 AS success, 'Clinic deleted' AS message;
    RETURN;
END

END

GO
/****** Object:  StoredProcedure [dbo].[sp_doctor_schedule]    Script Date: 15-10-2026 12:09:44 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--USE [QLess]
--GO
--/****** Object:  StoredProcedure [dbo].[sp_doctor_schedule]    Script Date: 23-06-2026 13:21:01 ******/
--SET ANSI_NULLS ON
--GO
--SET QUOTED_IDENTIFIER ON
--GO
--ALTER PROCEDURE [dbo].[sp_doctor_schedule]
--    @operation        VARCHAR(40),
--    @doctor_id        INT  = NULL,
--    @day_of_week      VARCHAR(10) = NULL,
--    @is_enabled       BIT  = NULL,
--    @availability_id  INT  = NULL,
--    @slot_id          INT  = NULL,
--    @start_time       TIME = NULL,
--    @end_time         TIME = NULL,
--    @booking_mode     INT  = NULL,
--    @slot_duration    INT  = NULL,
--    @max_queue_length INT  = NULL
--AS
--BEGIN
--    SET NOCOUNT ON;

--    ----------------------------------------------------------------------
--    -- DELETE_ALL  (unchanged behavior, but only touches active slots)
--    ----------------------------------------------------------------------
--    IF @operation = 'DELETE_ALL'
--    BEGIN
--        UPDATE doctor_time_slots
--        SET is_active = 0
--        WHERE availability_id IN (
--            SELECT availability_id FROM doctor_availability WHERE doctor_id = @doctor_id
--        );

--        DELETE FROM doctor_availability
--        WHERE doctor_id = @doctor_id;
--    END

--    ----------------------------------------------------------------------
--    -- INSERT_DAY  (unchanged)
--    ----------------------------------------------------------------------
--    IF @operation = 'INSERT_DAY'
--    BEGIN
--        INSERT INTO doctor_availability (doctor_id, day_of_week, is_enabled)
--        VALUES (@doctor_id, @day_of_week, @is_enabled);

--        SELECT SCOPE_IDENTITY() AS availability_id;
--    END

--    ----------------------------------------------------------------------
--    -- INSERT_SLOT  (unchanged)
--    ----------------------------------------------------------------------
--    IF @operation = 'INSERT_SLOT'
--    BEGIN
--        INSERT INTO doctor_time_slots (
--            availability_id, start_time, end_time,
--            booking_mode, slot_duration, max_queue_length
--        )
--        VALUES (
--            @availability_id, @start_time, @end_time,
--            @booking_mode, @slot_duration, @max_queue_length
--        );
--    END

--    ----------------------------------------------------------------------
--    -- UPSERT_DAY
--    ----------------------------------------------------------------------
--    IF @operation = 'UPSERT_DAY'
--    BEGIN
--        DECLARE @existing_avail_id INT;

--        SELECT @existing_avail_id = availability_id
--        FROM doctor_availability
--        WHERE doctor_id = @doctor_id
--          AND day_of_week = @day_of_week;

--        IF @existing_avail_id IS NULL
--        BEGIN
--            INSERT INTO doctor_availability (doctor_id, day_of_week, is_enabled)
--            VALUES (@doctor_id, @day_of_week, @is_enabled);

--            SELECT CAST(SCOPE_IDENTITY() AS INT) AS availability_id;
--        END
--        ELSE
--        BEGIN
--            UPDATE doctor_availability
--            SET is_enabled = @is_enabled
--            WHERE availability_id = @existing_avail_id;

--            SELECT @existing_avail_id AS availability_id;
--        END
--    END

--    ----------------------------------------------------------------------
--    -- UPSERT_SLOT
--    --   - @slot_id NULL  ? INSERT
--    --   - @slot_id given ? UPDATE that row
--    ----------------------------------------------------------------------
--   IF @operation = 'UPSERT_SLOT'
--BEGIN
--    IF @slot_id IS NULL
--    BEGIN
--        -- Same key cha soft-deleted row aahe ka? Tar to reactivate kar
--        DECLARE @dead_slot_id INT;

--        SELECT @dead_slot_id = slot_id
--        FROM doctor_time_slots
--        WHERE availability_id = @availability_id
--          AND start_time      = @start_time
--          AND is_active        = 0;

--        IF @dead_slot_id IS NOT NULL
--        BEGIN
--            UPDATE doctor_time_slots
--            SET end_time         = @end_time,
--                booking_mode     = @booking_mode,
--                slot_duration    = @slot_duration,
--                max_queue_length = @max_queue_length,
--                is_active        = 1
--            WHERE slot_id = @dead_slot_id;

--            SELECT @dead_slot_id AS slot_id;
--        END
--        ELSE
--        BEGIN
--            INSERT INTO doctor_time_slots (
--                availability_id, start_time, end_time,
--                booking_mode, slot_duration, max_queue_length
--            )
--            VALUES (
--                @availability_id, @start_time, @end_time,
--                @booking_mode, @slot_duration, @max_queue_length
--            );

--            SELECT CAST(SCOPE_IDENTITY() AS INT) AS slot_id;
--        END
--    END
--    ELSE
--    BEGIN
--        UPDATE doctor_time_slots
--        SET start_time       = @start_time,
--            end_time         = @end_time,
--            booking_mode     = @booking_mode,
--            slot_duration    = @slot_duration,
--            max_queue_length = @max_queue_length,
--            is_active        = 1
--        WHERE slot_id = @slot_id
--          AND availability_id = @availability_id;

--        SELECT @slot_id AS slot_id;
--    END
--END

--    ----------------------------------------------------------------------
--    -- GET_DAY_SLOT_IDS   (only active slots)
--    ----------------------------------------------------------------------
--    IF @operation = 'GET_DAY_SLOT_IDS'
--    BEGIN
--        SELECT dts.slot_id
--        FROM doctor_time_slots dts
--        JOIN doctor_availability da ON da.availability_id = dts.availability_id
--        WHERE da.doctor_id   = @doctor_id
--          AND da.day_of_week = @day_of_week
--          AND dts.is_active  = 1;
--    END

--    ----------------------------------------------------------------------
--    -- COUNT_FUTURE_APPTS_FOR_SLOT
--    ----------------------------------------------------------------------
--      IF @operation = 'COUNT_FUTURE_APPTS_FOR_SLOT'
--    BEGIN
--        SELECT COUNT(*) AS cnt
--        FROM appointments
--        WHERE slot_id = @slot_id
--          AND appointment_date > CAST(GETDATE() AS DATE)   -- ? >= ? >  (today exclude)
--          AND LOWER(status) IN ('booked', 'in_progress');
--    END


--    ----------------------------------------------------------------------
--    -- CANCEL_FUTURE_APPTS_FOR_SLOT   ? was MISSING in your paste
--    --   - Marks future booked/in_progress appointments on this slot as cancelled
--    --   - Returns patient FCM tokens for Node to multicast
--    --   ? assumes patients.fcm_token column. Tell me if different.
--    ----------------------------------------------------------------------
--    IF @operation = 'CANCEL_FUTURE_APPTS_FOR_SLOT'
--    BEGIN
--        DECLARE @affected TABLE (appointment_id INT, patient_id INT);

--             INSERT INTO @affected (appointment_id, patient_id)
--        SELECT appointment_id, patient_id
--        FROM appointments
--        WHERE slot_id = @slot_id
--          AND appointment_date > CAST(GETDATE() AS DATE)   -- ? >= ? >
--          AND LOWER(status) IN ('booked', 'in_progress');


--        UPDATE appointments
--        SET status = 'CancleD'
--        WHERE appointment_id IN (SELECT appointment_id FROM @affected);

--        --SELECT p.token
--        --FROM @affected a
--        --JOIN patients p ON p.patient_id = a.patient_id
--        --WHERE p.token IS NOT NULL
--        --  AND LTRIM(RTRIM(p.token)) <> '';
--		SELECT
--    CASE
--        WHEN ap.user_type = 1 THEN p.token
--        WHEN ap.user_type = 2 THEN p2.token
--    END AS fcm_token
--FROM @affected a
--JOIN appointments ap
--    ON ap.appointment_id = a.appointment_id
--LEFT JOIN patients p
--    ON ap.user_type = 1 AND p.patient_id = ap.patient_id
--LEFT JOIN family_members fm
--    ON ap.user_type = 2 AND fm.member_id = ap.patient_id
--LEFT JOIN patients p2
--    ON fm.family_id = p2.patient_id
--WHERE COALESCE(
--    CASE WHEN ap.user_type = 1 THEN p.token
--         WHEN ap.user_type = 2 THEN p2.token END, '') <> '';

--    END

--    ----------------------------------------------------------------------
--    -- DELETE_SLOT   ? soft delete (preserves completed-appointment history)
--    --   - Instead of removing the row, mark inactive
--    --   - Past appointments keep their slot_id reference intact
--    ----------------------------------------------------------------------
--    IF @operation = 'DELETE_SLOT'
--    BEGIN
--        UPDATE doctor_time_slots
--        SET is_active = 0
--        WHERE slot_id = @slot_id;
--    END

--    ----------------------------------------------------------------------
--    -- GET   (only active slots returned to UI)
--    ----------------------------------------------------------------------
--    IF @operation = 'GET'
--    BEGIN
--        SELECT 
--            da.availability_id,
--            da.day_of_week,
--            da.is_enabled,
--            dts.slot_id,
--            CONVERT(VARCHAR(5), dts.start_time, 108) AS start_time,
--            CONVERT(VARCHAR(5), dts.end_time,   108) AS end_time,
--            dts.booking_mode,
--            dts.slot_duration,
--            dts.max_queue_length
--        FROM doctor_availability da
--        LEFT JOIN doctor_time_slots dts 
--            ON da.availability_id = dts.availability_id
--           AND dts.is_active = 1                       -- ? hide soft-deleted
--        WHERE da.doctor_id = @doctor_id
--        ORDER BY 
--            CASE da.day_of_week
--                WHEN 'Monday' THEN 1
--                WHEN 'Tuesday' THEN 2
--                WHEN 'Wednesday' THEN 3
--                WHEN 'Thursday' THEN 4
--                WHEN 'Friday' THEN 5
--                WHEN 'Saturday' THEN 6
--                WHEN 'Sunday' THEN 7
--            END,
--            dts.start_time;
--    END


--	    ----------------------------------------------------------------------
--    -- RESCHEDULE_FUTURE_APPTS_FOR_SLOT  ? NEW
--    ----------------------------------------------------------------------
--    IF @operation = 'RESCHEDULE_FUTURE_APPTS_FOR_SLOT'
--    BEGIN
--        DECLARE @affectedR TABLE (appointment_id INT, patient_id INT);

--             INSERT INTO @affectedR (appointment_id, patient_id)
--        SELECT appointment_id, patient_id
--        FROM appointments
--        WHERE slot_id = @slot_id
--          AND appointment_date > CAST(GETDATE() AS DATE)   -- ? >= ? >
--          AND LOWER(status) IN ('booked', 'in_progress');


--        UPDATE appointments
--        SET status = 'reschedule'
--        WHERE appointment_id IN (SELECT appointment_id FROM @affectedR);

--        SELECT p.token
--        FROM @affectedR a
--        JOIN patients p ON p.patient_id = a.patient_id
--        WHERE p.token IS NOT NULL
--          AND LTRIM(RTRIM(p.token)) <> '';
--    END

--END




-- Step 2: updated SP
CREATE PROCEDURE [dbo].[sp_doctor_schedule]
    @operation        VARCHAR(40),
    @doctor_id        INT            = NULL,
    @clinic_id        NVARCHAR(20)   = NULL,   -- ? NEW
    @day_of_week      VARCHAR(10)    = NULL,
    @is_enabled       BIT            = NULL,
    @availability_id  INT            = NULL,
    @slot_id          INT            = NULL,
    @start_time       TIME           = NULL,
    @end_time         TIME           = NULL,
    @booking_mode     INT            = NULL,
    @slot_duration    INT            = NULL,
    @max_queue_length INT            = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @operation = 'DELETE_ALL'
    BEGIN
        UPDATE doctor_time_slots SET is_active = 0
        WHERE availability_id IN (
            SELECT availability_id FROM doctor_availability
            WHERE doctor_id = @doctor_id
              AND (clinic_id = @clinic_id OR @clinic_id IS NULL)
        );
        DELETE FROM doctor_availability
        WHERE doctor_id = @doctor_id
          AND (clinic_id = @clinic_id OR @clinic_id IS NULL);
    END

    IF @operation = 'INSERT_DAY'
    BEGIN
        INSERT INTO doctor_availability (doctor_id, clinic_id, day_of_week, is_enabled)
        VALUES (@doctor_id, @clinic_id, @day_of_week, @is_enabled);
        SELECT SCOPE_IDENTITY() AS availability_id;
    END

    IF @operation = 'INSERT_SLOT'
    BEGIN
        INSERT INTO doctor_time_slots (
            availability_id, start_time, end_time,
            booking_mode, slot_duration, max_queue_length)
        VALUES (@availability_id, @start_time, @end_time,
                @booking_mode, @slot_duration, @max_queue_length);
    END

    IF @operation = 'UPSERT_DAY'
    BEGIN
        DECLARE @existing_avail_id INT;
        SELECT @existing_avail_id = availability_id
        FROM doctor_availability
        WHERE doctor_id  = @doctor_id
          AND day_of_week = @day_of_week
          AND (clinic_id = @clinic_id OR (@clinic_id IS NULL AND clinic_id IS NULL));

        IF @existing_avail_id IS NULL
        BEGIN
            INSERT INTO doctor_availability (doctor_id, clinic_id, day_of_week, is_enabled)
            VALUES (@doctor_id, @clinic_id, @day_of_week, @is_enabled);
            SELECT CAST(SCOPE_IDENTITY() AS INT) AS availability_id;
        END
        ELSE
        BEGIN
            UPDATE doctor_availability SET is_enabled = @is_enabled
            WHERE availability_id = @existing_avail_id;
            SELECT @existing_avail_id AS availability_id;
        END
    END

    -- (UPSERT_SLOT, DELETE_SLOT, COUNT_FUTURE_APPTS_FOR_SLOT,
    --  CANCEL_FUTURE_APPTS_FOR_SLOT, RESCHEDULE_FUTURE_APPTS_FOR_SLOT
    --  � no change needed, they work by availability_id/slot_id directly)

    IF @operation = 'UPSERT_SLOT'
    BEGIN
        IF @slot_id IS NULL
        BEGIN
            DECLARE @dead_slot_id INT;
            SELECT @dead_slot_id = slot_id FROM doctor_time_slots
            WHERE availability_id = @availability_id AND start_time = @start_time AND is_active = 0;

            IF @dead_slot_id IS NOT NULL
            BEGIN
                UPDATE doctor_time_slots
                SET end_time=@end_time, booking_mode=@booking_mode,
                    slot_duration=@slot_duration, max_queue_length=@max_queue_length, is_active=1
                WHERE slot_id = @dead_slot_id;
                SELECT @dead_slot_id AS slot_id;
            END
            ELSE
            BEGIN
                INSERT INTO doctor_time_slots (availability_id, start_time, end_time, booking_mode, slot_duration, max_queue_length)
                VALUES (@availability_id, @start_time, @end_time, @booking_mode, @slot_duration, @max_queue_length);
                SELECT CAST(SCOPE_IDENTITY() AS INT) AS slot_id;
            END
        END
        ELSE
        BEGIN
            UPDATE doctor_time_slots
            SET start_time=@start_time, end_time=@end_time, booking_mode=@booking_mode,
                slot_duration=@slot_duration, max_queue_length=@max_queue_length, is_active=1
            WHERE slot_id = @slot_id AND availability_id = @availability_id;
            SELECT @slot_id AS slot_id;
        END
    END

    IF @operation = 'GET_DAY_SLOT_IDS'
    BEGIN
        SELECT dts.slot_id
        FROM doctor_time_slots dts
        JOIN doctor_availability da ON da.availability_id = dts.availability_id
        WHERE da.doctor_id   = @doctor_id
          AND da.day_of_week = @day_of_week
          AND (da.clinic_id  = @clinic_id OR (@clinic_id IS NULL AND da.clinic_id IS NULL))
          AND dts.is_active  = 1;
    END

    IF @operation = 'COUNT_FUTURE_APPTS_FOR_SLOT'
    BEGIN
        SELECT COUNT(*) AS cnt FROM appointments
        WHERE slot_id = @slot_id AND appointment_date > CAST(GETDATE() AS DATE)
          AND LOWER(status) IN ('booked','in_progress');
    END

    IF @operation = 'CANCEL_FUTURE_APPTS_FOR_SLOT'
    BEGIN
        DECLARE @affected TABLE (appointment_id INT, patient_id INT);
        INSERT INTO @affected SELECT appointment_id, patient_id FROM appointments
        WHERE slot_id = @slot_id AND appointment_date > CAST(GETDATE() AS DATE)
          AND LOWER(status) IN ('booked','in_progress');

        UPDATE appointments SET status='CancleD'
        WHERE appointment_id IN (SELECT appointment_id FROM @affected);

        SELECT CASE WHEN ap.user_type=1 THEN p.token WHEN ap.user_type=2 THEN p2.token END AS fcm_token
        FROM @affected a
        JOIN appointments ap ON ap.appointment_id = a.appointment_id
        LEFT JOIN patients p ON ap.user_type=1 AND p.patient_id=ap.patient_id
        LEFT JOIN family_members fm ON ap.user_type=2 AND fm.member_id=ap.patient_id
        LEFT JOIN patients p2 ON fm.family_id=p2.patient_id
        WHERE COALESCE(CASE WHEN ap.user_type=1 THEN p.token WHEN ap.user_type=2 THEN p2.token END,'') <> '';
    END

    IF @operation = 'DELETE_SLOT'
    BEGIN
        UPDATE doctor_time_slots SET is_active=0 WHERE slot_id=@slot_id;
    END

    IF @operation = 'GET'
    BEGIN
        SELECT da.availability_id, da.day_of_week, da.is_enabled,
               dts.slot_id,
               CONVERT(VARCHAR(5), dts.start_time, 108) AS start_time,
               CONVERT(VARCHAR(5), dts.end_time,   108) AS end_time,
               dts.booking_mode, dts.slot_duration, dts.max_queue_length
        FROM doctor_availability da
        LEFT JOIN doctor_time_slots dts
            ON da.availability_id = dts.availability_id AND dts.is_active = 1
        WHERE da.doctor_id = @doctor_id
          AND (da.clinic_id = @clinic_id OR (@clinic_id IS NULL AND da.clinic_id IS NULL))
        ORDER BY CASE da.day_of_week
            WHEN 'Monday' THEN 1 WHEN 'Tuesday' THEN 2 WHEN 'Wednesday' THEN 3
            WHEN 'Thursday' THEN 4 WHEN 'Friday' THEN 5 WHEN 'Saturday' THEN 6
            WHEN 'Sunday' THEN 7 END, dts.start_time;
    END

    IF @operation = 'RESCHEDULE_FUTURE_APPTS_FOR_SLOT'
    BEGIN
        DECLARE @affectedR TABLE (appointment_id INT, patient_id INT);
        INSERT INTO @affectedR SELECT appointment_id, patient_id FROM appointments
        WHERE slot_id = @slot_id AND appointment_date > CAST(GETDATE() AS DATE)
          AND LOWER(status) IN ('booked','in_progress');

        UPDATE appointments SET status='reschedule'
        WHERE appointment_id IN (SELECT appointment_id FROM @affectedR);

        SELECT p.token FROM @affectedR a
        JOIN patients p ON p.patient_id=a.patient_id
        WHERE p.token IS NOT NULL AND LTRIM(RTRIM(p.token)) <> '';
    END
END
GO
/****** Object:  StoredProcedure [dbo].[sp_family_members]    Script Date: 15-10-2026 12:09:44 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[sp_family_members]
(
    @operation NVARCHAR(20),

    @member_id INT = NULL,
    @family_id INT = NULL,
    @name NVARCHAR(100) = NULL,
    @Gender_id INT = NULL,
    @relation_id INT = NULL,
    @DOB SMALLDATETIME = NULL,
    @mobile_no NVARCHAR(50) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

---------------------------------------------------------
-- INSERT MEMBER
---------------------------------------------------------
IF @operation = 'Insert'
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.family_members
        (
            family_id,
            name,
            Gender_id,
            relation_id,
            DOB,
            mobile_no
        )
        VALUES
        (
            @family_id,
            @name,
            @Gender_id,
            @relation_id,
            @DOB,
            @mobile_no
        );

        SET @member_id = SCOPE_IDENTITY();

        COMMIT TRANSACTION;

        SELECT @member_id AS member_id;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;

        SELECT 
            ERROR_MESSAGE() AS ErrorMessage,
            ERROR_LINE() AS ErrorLine;
    END CATCH

RETURN;
END

---------------------------------------------------------
-- UPDATE MEMBER
---------------------------------------------------------
IF @operation = 'Update'
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.family_members
        SET
            family_id = @family_id,
            name = @name,
            Gender_id = @Gender_id,
            relation_id = @relation_id,
            DOB = @DOB,
            mobile_no = @mobile_no
        WHERE member_id = @member_id;

        COMMIT TRANSACTION;

        SELECT @member_id AS member_id;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;

        SELECT 
            ERROR_MESSAGE() AS ErrorMessage,
            ERROR_LINE() AS ErrorLine;
    END CATCH

RETURN;
END

---------------------------------------------------------
-- FETCH SINGLE MEMBER
---------------------------------------------------------
IF @operation = 'FetchMember'
BEGIN
    SELECT *
    FROM dbo.family_members
    WHERE member_id = @member_id;

RETURN;
END

---------------------------------------------------------
-- FETCH ALL MEMBERS BY FAMILY
---------------------------------------------------------
IF @operation = 'AllFamilyMembers'
BEGIN
 SELECT 
    fm.member_id,
    fm.family_id,
    fm.name,
    fm.Gender_id,
    g.Gender,          -- ? ADD THIS
    fm.relation_id,
    r.relation, -- ? ADD THIS
    fm.DOB,
    fm.mobile_no
FROM dbo.family_members fm
LEFT JOIN Gender g ON fm.Gender_id = g.gender_id
LEFT JOIN Relations r ON fm.relation_id = r.relation_id
    WHERE family_id = @family_id;
END
IF @operation = 'DeleteMember'
BEGIN
    BEGIN TRY
        DELETE FROM dbo.family_members
        WHERE member_id = @member_id;

        SELECT 1 AS success, 'Member deleted successfully' AS message;
    END TRY
    BEGIN CATCH
        SELECT 0 AS success, 
               'Member is used in other records, cannot delete.' AS message;
    END CATCH
END

END

GO
/****** Object:  StoredProcedure [dbo].[sp_favorite_doctors]    Script Date: 15-10-2026 12:09:44 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[sp_favorite_doctors]
(
    @operation NVARCHAR(10),
    @patient_id INT,
    @doctor_id INT = NULL,
	 @clinic_id  NVARCHAR(50) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    -- ? Insert favorite (avoid duplicate)
    --IF @operation = 'Insert'
    --BEGIN
    --    IF NOT EXISTS (
    --        SELECT 1 FROM favorite_doctors 
    --        WHERE patient_id = @patient_id 
    --          AND doctor_id = @doctor_id
    --    )
    --    BEGIN
    --        INSERT INTO favorite_doctors (patient_id, doctor_id, is_favorite, created_at)
    --        VALUES (@patient_id, @doctor_id, 1, GETDATE());

    --        SELECT 1 AS success, SCOPE_IDENTITY() AS favorite_id, 'Added successfully' AS message;
    --    END
    --    ELSE
    --    BEGIN
    --        SELECT 0 AS success, 'Already added to favorites' AS message;
    --    END
    --END
	 IF @operation = 'Insert'
    BEGIN
        IF NOT EXISTS (
            SELECT 1 FROM favorite_doctors 
            WHERE patient_id = @patient_id 
              AND doctor_id  = @doctor_id
			  AND clinic_id=@clinic_id
        )
        BEGIN
            INSERT INTO favorite_doctors (patient_id, doctor_id, clinic_id, is_favorite, created_at)
            VALUES (@patient_id, @doctor_id, @clinic_id, 1, GETDATE());

            SELECT 1 AS success, SCOPE_IDENTITY() AS favorite_id, 'Added successfully' AS message;
        END
        ELSE
        BEGIN
            ---- Update clinic_id if it was missing
            --UPDATE favorite_doctors
            --SET clinic_id = COALESCE(@clinic_id, clinic_id)
            --WHERE patient_id = @patient_id AND doctor_id = @doctor_id;

            SELECT 0 AS success, 'Already added to favorites' AS message;
        END
    END

    -- ? Delete favorite
    ELSE IF @operation = 'Delete'
    BEGIN
        DELETE FROM favorite_doctors
        WHERE patient_id = @patient_id
          AND doctor_id = @doctor_id
		  AND clinic_id=@clinic_id;


        SELECT 1 AS success, 'Deleted successfully' AS message;
    END

    -- ? Fetch (2 cases handled)
    ELSE IF @operation = 'Fetch'
    BEGIN
        -- ?? Case 1: Check single doctor (for heart icon)
        IF @doctor_id IS NOT NULL
        BEGIN
            SELECT 
                CASE 
                    WHEN EXISTS (
                        SELECT 1 FROM favorite_doctors 
                        WHERE patient_id = @patient_id 
                          AND doctor_id = @doctor_id
						  AND clinic_id=@clinic_id
                          AND is_favorite = 1
                    )
                    THEN 1 ELSE 0 
                END AS is_favorite;
        END
        ELSE
        BEGIN
            -- ?? Case 2: Get all favorite doctors of patient
            SELECT *
            FROM favorite_doctors
            WHERE patient_id = @patient_id
              AND is_favorite = 1
            ORDER BY created_at DESC;
        END
    END
END
GO
/****** Object:  StoredProcedure [dbo].[sp_Medicin_Type]    Script Date: 15-10-2026 12:09:44 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[sp_Medicin_Type]
    @operation NVARCHAR(20) = NULL,
    @Medi_Type_Id INT = 0,
    @Medi_Type_Name NVARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @operation = 'Update'
    BEGIN
        IF @Medi_Type_Id = 0
        BEGIN
            DECLARE @new_id INT;
            SELECT TOP 1 @new_id = Medi_Type_Id FROM dbo.Medicin_Type ORDER BY Medi_Type_Id DESC;

            IF @new_id IS NULL OR @new_id = 0
                SET @new_id = 1;
            ELSE
                SET @new_id = @new_id + 1;

            INSERT INTO dbo.Medicin_Type (
                Medi_Type_Id, Medi_Type_Name
            )
            VALUES (
                @new_id, @Medi_Type_Name
            );
        END
        ELSE
        BEGIN
            UPDATE dbo.Medicin_Type
            SET Medi_Type_Name = @Medi_Type_Name
            WHERE Medi_Type_Id = @Medi_Type_Id;
        END
    END

    IF @operation = 'Select'
    BEGIN
        SELECT *
        FROM dbo.Medicin_Type
        WHERE Medi_Type_Id = @Medi_Type_Id;
    END

    IF @operation = 'Delete'
    BEGIN
        DELETE FROM dbo.Medicin_Type
        WHERE Medi_Type_Id = @Medi_Type_Id;
    END
END
GO
/****** Object:  StoredProcedure [dbo].[sp_Medicine_Master]    Script Date: 15-10-2026 12:09:44 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[sp_Medicine_Master]
    @operation        NVARCHAR(20)  = NULL,
    @medicine_id      INT           = 0,
    @doctor_id        INT           = 0,
    @medicine_name    NVARCHAR(100) = NULL,
    @medicine_type_id INT           = NULL,
    @search_query     NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- ---------------------------------------------------------
    -- INSERT: global library + per-doctor link
    -- ---------------------------------------------------------
    IF @operation = 'Insert'
    BEGIN
        DECLARE @medId INT;

        -- 1. Medicine_Master madhe (name+type) ahe ka check
        SELECT @medId = medicine_id 
        FROM dbo.Medicine_Master
        WHERE medicine_name    = @medicine_name 
          AND medicine_type_id = @medicine_type_id;

        -- 2. Naselich tar global library madhe insert
        IF @medId IS NULL
        BEGIN
            INSERT INTO dbo.Medicine_Master (medicine_name, medicine_type_id)
            VALUES (@medicine_name, @medicine_type_id);
            SET @medId = SCOPE_IDENTITY();
        END

        -- 3. Already active link asla ? duplicate prevent
        IF EXISTS (
            SELECT 1 FROM dbo.Doctor_Medicine
            WHERE doctor_id   = @doctor_id 
              AND medicine_id = @medId 
              AND is_active   = 1
        )
        BEGIN
            SELECT 'Medicine already in your list.' AS Message;
            RETURN;
        END

        -- 4. Soft-deleted link asla ? reactivate
        IF EXISTS (
            SELECT 1 FROM dbo.Doctor_Medicine
            WHERE doctor_id   = @doctor_id 
              AND medicine_id = @medId 
              AND is_active   = 0
        )
        BEGIN
            UPDATE dbo.Doctor_Medicine
            SET    is_active = 1
            WHERE  doctor_id   = @doctor_id 
              AND  medicine_id = @medId;

            SELECT 'Medicine reactivated.' AS Message;
            RETURN;
        END

        -- 5. Navin link insert
        INSERT INTO dbo.Doctor_Medicine (doctor_id, medicine_id, is_active)
        VALUES (@doctor_id, @medId, 1);

        SELECT 'Medicine added successfully.' AS Message;
    END

    -- ---------------------------------------------------------
    -- GET MEDICINE TYPES
    -- ---------------------------------------------------------
    IF @operation = 'getMedicineTypes'
    BEGIN
        SELECT * FROM dbo.Medicine_Type;
    END

    -- ---------------------------------------------------------
    -- FETCH ALL MEDICINES (per doctor list)
    -- ---------------------------------------------------------
    IF @operation = 'fetchAllMedicines'
    BEGIN
        SELECT
            m.medicine_id,
            dm.doctor_id,
            m.medicine_name,
            m.medicine_type_id,
            t.Medi_Type_Name
        FROM   dbo.Doctor_Medicine dm
        INNER JOIN dbo.Medicine_Master m ON dm.medicine_id    = m.medicine_id
        INNER JOIN dbo.Medicine_Type   t ON m.medicine_type_id = t.medicine_type_id
        WHERE  dm.doctor_id = @doctor_id
          AND  dm.is_active = 1
        ORDER BY m.medicine_name;
    END

    -- ---------------------------------------------------------
    -- GET SUGGESTIONS (NEW � global library madhun typing veli)
    -- ---------------------------------------------------------
    IF @operation = 'getSuggestions'
    BEGIN
        SELECT TOP 20
            m.medicine_id,
            m.medicine_name,
            m.medicine_type_id,
            t.Medi_Type_Name
        FROM   dbo.Medicine_Master m
        INNER JOIN dbo.Medicine_Type t ON m.medicine_type_id = t.medicine_type_id
        WHERE  m.medicine_name LIKE @search_query + '%'
        ORDER BY m.medicine_name;
    END

    -- ---------------------------------------------------------
    -- DELETE (per-doctor soft delete; library la touch nahi)
    -- ---------------------------------------------------------
    IF @operation = 'Delete'
    BEGIN
        UPDATE dbo.Doctor_Medicine
        SET    is_active = 0
        WHERE  medicine_id = @medicine_id
          AND  doctor_id   = @doctor_id
          AND  is_active   = 1;

        IF @@ROWCOUNT > 0
            SELECT 'Medicine removed from your list.' AS Message;
        ELSE
            SELECT 'No medicine found to delete.' AS Message;
    END
END
GO
/****** Object:  StoredProcedure [dbo].[sp_notification]    Script Date: 15-10-2026 12:09:44 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[sp_notification]
    @operation       VARCHAR(40),
    @notification_id INT            = NULL,
    @patient_id      INT            = NULL,
    @title           NVARCHAR(200)  = NULL,
    @body            NVARCHAR(1000) = NULL,
    @type            VARCHAR(40)    = NULL,
    @ref_id          VARCHAR(40)    = NULL,
    -- Appointment-context lookup params
    @slot_id         INT            = NULL,
    @doctor_id       INT            = NULL,
    @queue_id        INT            = NULL,
    @from_date       DATE           = NULL,
    @to_date         DATE           = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @operation = 'INSERT'
    BEGIN
        IF @patient_id IS NULL OR @title IS NULL OR @body IS NULL OR @type IS NULL
        BEGIN
            SELECT 0 AS success, 'patient_id, title, body and type are required' AS message;
            RETURN;
        END

        INSERT INTO notifications (patient_id, title, body, type, ref_id)
        VALUES (@patient_id, @title, @body, @type, @ref_id);

        SELECT 1 AS success,
               SCOPE_IDENTITY() AS notification_id,
               'Notification stored' AS message;
        RETURN;
    END

    IF @operation = 'LIST'
    BEGIN
        SELECT  notification_id, patient_id, title, body, type, ref_id, is_read, created_at
        FROM    notifications
        WHERE   patient_id = @patient_id
        ORDER BY created_at DESC;
        RETURN;
    END

    IF @operation = 'MARK_READ'
    BEGIN
        UPDATE notifications
        SET    is_read = 1
        WHERE  notification_id = @notification_id AND patient_id = @patient_id;
        SELECT 1 AS success, 'Marked as read' AS message;
        RETURN;
    END

    IF @operation = 'MARK_ALL_READ'
    BEGIN
        UPDATE notifications
        SET    is_read = 1
        WHERE  patient_id = @patient_id AND is_read = 0;
        SELECT 1 AS success, 'All marked as read' AS message;
        RETURN;
    END

    -- -- Appointment context lookups for personalized cancellation notifications --

    IF @operation = 'APPT_CONTEXT_SLOT'
    BEGIN
        SELECT a.appointment_id,
               a.appointment_date,
               a.start_time,
               CASE WHEN a.user_type = 1 THEN p.patient_id ELSE p2.patient_id END AS owner_id,
               CASE WHEN a.user_type = 1 THEN p.token      ELSE p2.token      END AS owner_token,
               d.name AS doctor_name
        FROM appointments a
        LEFT JOIN patients p        ON a.user_type = 1 AND p.patient_id = a.patient_id
        LEFT JOIN family_members fm ON a.user_type = 2 AND fm.member_id = a.patient_id
        LEFT JOIN patients p2       ON fm.family_id = p2.patient_id
        LEFT JOIN doctor_login d    ON d.doctor_id  = a.doctor_id
        WHERE a.slot_id = @slot_id
          AND a.appointment_date >= CAST(GETDATE() AS DATE)
          AND a.status IN ('booked', 'in_progress');
        RETURN;
    END

    IF @operation = 'APPT_CONTEXT_DOCTOR_RANGE'
    BEGIN
        SELECT a.appointment_id,
               a.appointment_date,
               a.start_time,
               CASE WHEN a.user_type = 1 THEN p.patient_id ELSE p2.patient_id END AS owner_id,
               CASE WHEN a.user_type = 1 THEN p.token      ELSE p2.token      END AS owner_token,
               d.name AS doctor_name
        FROM appointments a
        LEFT JOIN patients p        ON a.user_type = 1 AND p.patient_id = a.patient_id
        LEFT JOIN family_members fm ON a.user_type = 2 AND fm.member_id = a.patient_id
        LEFT JOIN patients p2       ON fm.family_id = p2.patient_id
        LEFT JOIN doctor_login d    ON d.doctor_id  = a.doctor_id
        WHERE a.doctor_id = @doctor_id
          AND a.appointment_date BETWEEN @from_date AND @to_date
          AND a.status IN ('booked', 'in_progress');
        RETURN;
    END

    IF @operation = 'APPT_CONTEXT_QUEUE'
    BEGIN
        DECLARE @qstop_time TIME;
        SELECT  @qstop_time = ts.start_time
        FROM    doctor_queue dq
        INNER JOIN doctor_time_slots ts ON dq.slot_id = ts.slot_id
        WHERE   dq.queue_id = @queue_id;

        SELECT a.appointment_id,
               a.appointment_date,
               a.start_time,
               CASE WHEN a.user_type = 1 THEN p.patient_id ELSE p2.patient_id END AS owner_id,
               CASE WHEN a.user_type = 1 THEN p.token      ELSE p2.token      END AS owner_token,
               d.name AS doctor_name
        FROM appointments a
        LEFT JOIN patients p        ON a.user_type = 1 AND p.patient_id = a.patient_id
        LEFT JOIN family_members fm ON a.user_type = 2 AND fm.member_id = a.patient_id
        LEFT JOIN patients p2       ON fm.family_id = p2.patient_id
        LEFT JOIN doctor_login d    ON d.doctor_id  = a.doctor_id
        WHERE a.doctor_id = @doctor_id
          AND a.appointment_date = CAST(GETDATE() AS DATE)
          AND a.status IN ('booked', 'skipped')
          AND (
                a.queue_id = @queue_id
                OR (a.booking_type = 2 AND a.start_time < @qstop_time)
              );
        RETURN;
    END

    SELECT 0 AS success, 'Unknown operation' AS message;
END
GO
/****** Object:  StoredProcedure [dbo].[sp_otp]    Script Date: 15-10-2026 12:09:44 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE   PROCEDURE [dbo].[sp_otp]
    @operation VARCHAR(20),
    @mobile_no VARCHAR(15),
    @otp_hash VARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -----------------------------------------
    -- SEND OTP
    -----------------------------------------
    IF @operation = 'send_otp'
    BEGIN
        -- Rate limit: max 3 OTP in last 10 min
        IF (
            SELECT COUNT(*) 
            FROM otp_verification
            WHERE mobile_no = @mobile_no
            AND created_at > DATEADD(MINUTE, -10, GETDATE())
        ) >= 3
        BEGIN
            SELECT 0 AS status, 'Too many OTP requests. Try later.' AS message;
            RETURN;
        END

        -- Delete old OTPs (optional cleanup)
        DELETE FROM otp_verification 
        WHERE mobile_no = @mobile_no;

        -- Insert new OTP
        INSERT INTO otp_verification (
            mobile_no, otp_hash, expires_at
        )
        VALUES (
            @mobile_no,
            @otp_hash,
            DATEADD(MINUTE, 5, GETDATE()) -- 5 min expiry
        );

        SELECT 1 AS status, 'OTP sent successfully' AS message;
    END

    -----------------------------------------
    -- VERIFY OTP
    -----------------------------------------
    ELSE IF @operation = 'verify_otp'
    BEGIN
        DECLARE @id INT,
                @db_otp_hash VARCHAR(255),
                @expires_at DATETIME,
                @attempts INT,
                @is_verified BIT;

        -- Get latest OTP
        SELECT TOP 1
            @id = id,
            @db_otp_hash = otp_hash,
            @expires_at = expires_at,
            @attempts = attempts,
            @is_verified = is_verified
        FROM otp_verification
        WHERE mobile_no = @mobile_no
        ORDER BY created_at DESC;

        IF @id IS NULL
        BEGIN
            SELECT 0 AS status, 'OTP not found' AS message;
            RETURN;
        END

        IF @is_verified = 1
        BEGIN
            SELECT 0 AS status, 'OTP already used' AS message;
            RETURN;
        END

        IF @expires_at < GETDATE()
        BEGIN
            SELECT 0 AS status, 'OTP expired' AS message;
            RETURN;
        END

        IF @attempts >= 5
        BEGIN
            SELECT 0 AS status, 'Too many attempts. Try again later.' AS message;
            RETURN;
        END

        -- Return hash to Node.js for comparison
        SELECT 
            1 AS status,
            @id AS otp_id,
            @db_otp_hash AS otp_hash,
            @attempts AS attempts;
    END

    -----------------------------------------
    -- UPDATE ATTEMPTS
    -----------------------------------------
    ELSE IF @operation = 'update_attempt'
    BEGIN
        UPDATE otp_verification
        SET attempts = attempts + 1
        WHERE mobile_no = @mobile_no;

        SELECT 1 AS status;
    END

    -----------------------------------------
    -- MARK VERIFIED
    -----------------------------------------
    ELSE IF @operation = 'mark_verified'
    BEGIN
        UPDATE otp_verification
        SET is_verified = 1
        WHERE mobile_no = @mobile_no;

        SELECT 1 AS status;
    END
END
GO
/****** Object:  StoredProcedure [dbo].[sp_patients]    Script Date: 15-10-2026 12:09:44 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[sp_patients]
(
    @operation NVARCHAR(50),
    @patient_id INT = NULL,
    @mobile_no NVARCHAR(50) = NULL,
    @name NVARCHAR(100) = NULL,
    @Address NVARCHAR(100) = NULL,
    @email NVARCHAR(100) = NULL,
    @gender_id INT = NULL,
    @DOB SMALLDATETIME = NULL,
    @blood_group_id INT = NULL,
    @height NVARCHAR(50) = NULL,
    @weight DECIMAL(6, 2) = NULL,
    @doctor_id int = Null,
	@img_url  NVARCHAR(MAX) = NULL,
	@clinic_id   NVARCHAR(20) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    ---------------------------------------------------------
    -- INSERT PATIENT
    ---------------------------------------------------------
    IF @operation = 'Insert'
    BEGIN
        BEGIN TRY
            BEGIN TRANSACTION;
			--------------------------------------------------
        -- CHECK MOBILE ALREADY EXISTS
        --------------------------------------------------
        IF EXISTS (
            SELECT 1
            FROM dbo.Patients
            WHERE mobile_no = @mobile_no
            AND active_status = 1
        )
        BEGIN
            SELECT
                0 AS success,
                'Mobile number already exists' AS message;

            ROLLBACK TRANSACTION;
            RETURN;
        END


            INSERT INTO dbo.Patients
            (
                name,
                mobile_no,
                email,
                Address,
                gender_id,
                DOB,
                blood_group_id,
                weight,
                role_id,
                active_status
            )
            VALUES
            (   @name,
                @mobile_no,
                @email,
                @Address,
                @gender_id,
                @DOB,
                @blood_group_id,
                @weight,
                2, -- patient role
                1  -- active
            );

            SET @patient_id = SCOPE_IDENTITY();

            COMMIT TRANSACTION;

            SELECT @patient_id AS patient_id;

        END TRY
        BEGIN CATCH
            ROLLBACK TRANSACTION;

            SELECT ERROR_MESSAGE() AS ErrorMessage,
                   ERROR_LINE() AS ErrorLine;
        END CATCH

        RETURN;
    END

    ---------------------------------------------------------
    -- UPDATE PATIENT
    ---------------------------------------------------------
    IF @operation = 'Update'
    BEGIN
        BEGIN TRY
            BEGIN TRANSACTION;

            UPDATE dbo.Patients
            SET name = @name,
                mobile_no = @mobile_no,
                email = @email,
                Address = @Address,
                gender_id = @gender_id,
                DOB = @DOB,
                blood_group_id = @blood_group_id,
                weight = @weight
            WHERE patient_id = @patient_id;

            COMMIT TRANSACTION;

            SELECT @patient_id AS patient_id;

        END TRY
        BEGIN CATCH
            ROLLBACK TRANSACTION;

            SELECT ERROR_MESSAGE() AS ErrorMessage,
                   ERROR_LINE() AS ErrorLine;
        END CATCH

        RETURN;
    END

    ---------------------------------------------------------
    -- FETCH PATIENT
    ---------------------------------------------------------
    IF @operation = 'FetchPatient'
    BEGIN
        SELECT *
        FROM dbo.Patients
        WHERE mobile_no = @mobile_no
              AND active_status = 1;

        RETURN;
    END

    ---------------------------------------------------------
    -- FETCH ALL PATIENTS
    ---------------------------------------------------------
    IF @operation = 'FetchPatients'
    BEGIN
        SELECT *
        FROM dbo.Patients
        WHERE active_status = 1;
    END

    ---------------------------------------------------------
    -- DELETE (Soft Delete)
    ---------------------------------------------------------
    IF @operation = 'DeletePatient'
    BEGIN
        UPDATE dbo.Patients
        SET active_status = 0
        WHERE patient_id = @patient_id;

        SELECT 1 AS success,
               'Patient deleted successfully' AS message;
    END

    ---------------------------------------------------------
    -- CHECK PHONE
    ---------------------------------------------------------
    IF @operation = 'check_phone_patient'
    BEGIN
        SELECT *
        FROM dbo.patient_login_vw
        WHERE mobile_no = @mobile_no;
    END

IF @operation = 'getDoctors'
BEGIN
    SELECT
        d.*,

        --------------------------------------------------
        -- CURRENT QUEUE LENGTH (appointments based)
        --------------------------------------------------
        (
            SELECT COUNT(*)
            FROM appointments a
            WHERE a.doctor_id = d.doctor_id
                  AND a.booking_type = 1
                  AND a.status = 'booked'
                  AND a.appointment_date = CAST(GETDATE() AS DATE)
        ) AS queue_length,

        qb.is_queue_available,
        qb.is_booking_started,
        qb.current_queue_length,
        qb.max_queue_length,
        qb.is_queue_full,
        qb.booking_start_time,

        --------------------------------------------------
        -- SLOT AVAILABILITY
        --------------------------------------------------
        sa.is_slot_available,

        --------------------------------------------------
        -- RECENTLY VISITED
        --------------------------------------------------
        CASE
            WHEN EXISTS
            (
                SELECT 1
                FROM appointments a2
                WHERE a2.doctor_id = d.doctor_id
                      AND a2.patient_id = @patient_id
                      AND a2.status = 'completed'
                      AND a2.appointment_date >= DATEADD(MONTH, -1, CAST(GETDATE() AS DATE))
            )
            THEN 1 ELSE 0
        END AS is_recently_visited,
	        --------------------------------------------------
        -- RATING + REVIEW COUNT (clinic-wise)
        --------------------------------------------------
        (
            SELECT AVG(CAST(rv.rating AS FLOAT))
            FROM reviews rv
            WHERE rv.doctor_id = d.doctor_id
              AND (rv.clinic_id = d.clinic_id OR rv.clinic_id IS NULL)
        ) AS rating,
        (
            SELECT COUNT(*)
            FROM reviews rv
            WHERE rv.doctor_id = d.doctor_id
              AND (rv.clinic_id = d.clinic_id OR rv.clinic_id IS NULL)
        ) AS review_count


    FROM doctor_login_vw d

    --------------------------------------------------
    -- ONLY VERIFIED DOCTORS
    --------------------------------------------------
    INNER JOIN doctor_login dl_main
        ON dl_main.doctor_id = d.doctor_id
        AND dl_main.is_verified = 0

    --------------------------------------------------
    -- QUEUE LOGIC (WITH END TIME CHECK)
    --------------------------------------------------
    OUTER APPLY
    (
        SELECT TOP 1

            --------------------------------------------------
            -- QUEUE AVAILABLE (WITH START + END WINDOW)
            --------------------------------------------------
            CASE
                WHEN GETDATE() BETWEEN
                    DATETIMEFROMPARTS(
                        YEAR(GETDATE()),
                        MONTH(GETDATE()),
                        DAY(GETDATE()),
                        DATEPART(HOUR, ts.start_time),
                        DATEPART(MINUTE, ts.start_time),
                        0,0
                    )
                    AND
                    DATETIMEFROMPARTS(
                        YEAR(GETDATE()),
                        MONTH(GETDATE()),
                        DAY(GETDATE()),
                        DATEPART(HOUR, ts.end_time),
                        DATEPART(MINUTE, ts.end_time),
                        0,0
                    )
                THEN 1
                ELSE 0
            END AS is_queue_available,

            --------------------------------------------------
            -- BOOKING START TIME
            --------------------------------------------------
            FORMAT(
                DATEADD(MINUTE,
                    -ISNULL(dl.q_start_before,0),
                    DATETIMEFROMPARTS(
                        YEAR(GETDATE()),
                        MONTH(GETDATE()),
                        DAY(GETDATE()),
                        DATEPART(HOUR, ts.start_time),
                        DATEPART(MINUTE, ts.start_time),
                        0,0
                    )
                ),
                'hh:mm tt'
            ) AS booking_start_time,

            --------------------------------------------------
            -- BOOKING STARTED
            --------------------------------------------------
            CASE
                WHEN GETDATE() >= DATEADD(MINUTE,
                    -ISNULL(dl.q_start_before,0),
                    DATETIMEFROMPARTS(
                        YEAR(GETDATE()),
                        MONTH(GETDATE()),
                        DAY(GETDATE()),
                        DATEPART(HOUR, ts.start_time),
                        DATEPART(MINUTE, ts.start_time),
                        0,0
                    )
                )
                THEN 1 ELSE 0
            END AS is_booking_started,

            --------------------------------------------------
            -- PENDING QUEUE (excludes completed/cancelled/skipped)
            --------------------------------------------------
            --(
            --    SELECT COUNT(*)
            --    FROM appointments a3
            --    JOIN doctor_time_slots ts3b
            --        ON ts3b.slot_id = a3.slot_id
            --    JOIN doctor_availability da3b
            --        ON da3b.availability_id = ts3b.availability_id
            --    WHERE a3.doctor_id = d.doctor_id
            --          AND a3.booking_type = 1
            --          AND a3.appointment_date = CAST(GETDATE() AS DATE)
            --          AND a3.status NOT IN ('completed', 'cancelled', 'cancled', 'skipped')
            --          AND (da3b.clinic_id = d.clinic_id OR da3b.clinic_id IS NULL)
            --) AS current_queue_length,

--			(
--    SELECT COUNT(*)
--    FROM appointments a3
--    JOIN doctor_time_slots ts3b
--        ON ts3b.slot_id = a3.slot_id
--    JOIN doctor_availability da3b
--        ON da3b.availability_id = ts3b.availability_id
--    LEFT JOIN doctor_queue dq3b
--        ON dq3b.queue_id = a3.queue_id
--    WHERE a3.doctor_id = d.doctor_id
--          AND a3.booking_type = 1
--          AND a3.appointment_date = CAST(GETDATE() AS DATE)
--          AND a3.status NOT IN ('completed', 'cancelled', 'cancled', 'skipped')
--          AND (da3b.clinic_id = d.clinic_id OR da3b.clinic_id IS NULL)
--          AND (dq3b.queue_status IS NULL OR dq3b.queue_status <> 3)
--) AS current_queue_length,

            --------------------------------------------------
            -- PENDING QUEUE (excludes completed/cancelled/skipped,
            -- and excludes queues the doctor has stopped or closed booking on)
            --------------------------------------------------
            (
                SELECT COUNT(*)
                FROM appointments a3
                JOIN doctor_time_slots ts3b
                    ON ts3b.slot_id = a3.slot_id
                JOIN doctor_availability da3b
                    ON da3b.availability_id = ts3b.availability_id
                LEFT JOIN doctor_queue dq3b
                    ON dq3b.queue_id = a3.queue_id
                WHERE a3.doctor_id = d.doctor_id
                      AND a3.booking_type = 1
                      AND a3.appointment_date = CAST(GETDATE() AS DATE)
                      AND a3.status NOT IN ('completed', 'cancelled', 'cancled', 'skipped')
                      AND (da3b.clinic_id = d.clinic_id OR da3b.clinic_id IS NULL)
                      AND (dq3b.queue_status IS NULL OR dq3b.queue_status <> 3)
                      AND ISNULL(dq3b.booking_closed, 0) = 0
            ) AS current_queue_length,


            --------------------------------------------------
            -- MAX QUEUE
            --------------------------------------------------
            (
                SELECT SUM(ISNULL(ts2.max_queue_length,0))
                FROM doctor_availability da2
                JOIN doctor_time_slots ts2
                    ON da2.availability_id = ts2.availability_id
				WHERE da2.doctor_id = d.doctor_id
      AND (da2.clinic_id = d.clinic_id OR da2.clinic_id IS NULL)
      AND da2.is_enabled = 1
      AND ts2.is_active = 1
      AND ts2.is_deleted = 0
      AND da2.day_of_week = DATENAME(WEEKDAY, GETDATE())
      AND ts2.booking_mode IN (1,3)
            ) AS max_queue_length,

	 CASE
    WHEN
    (
        SELECT COUNT(*)
        FROM doctor_time_slots ts3
        JOIN doctor_availability da3 ON ts3.availability_id = da3.availability_id
        WHERE da3.doctor_id = d.doctor_id
          AND (da3.clinic_id = d.clinic_id OR da3.clinic_id IS NULL)
          AND da3.is_enabled = 1
          AND ts3.is_active = 1
          AND ts3.is_deleted = 0
          AND da3.day_of_week = DATENAME(WEEKDAY, GETDATE())
          AND ts3.booking_mode IN (1,3)
    ) > 0
    AND
    (
        SELECT COUNT(*)
        FROM doctor_time_slots ts3
        JOIN doctor_availability da3 ON ts3.availability_id = da3.availability_id
        LEFT JOIN doctor_queue dq3
            ON dq3.doctor_id = d.doctor_id
            AND dq3.queue_date = CAST(GETDATE() AS DATE)
            AND dq3.slot_id = ts3.slot_id
        WHERE da3.doctor_id = d.doctor_id
          AND (da3.clinic_id = d.clinic_id OR da3.clinic_id IS NULL)
          AND da3.is_enabled = 1
          AND ts3.is_active = 1
          AND ts3.is_deleted = 0
          AND da3.day_of_week = DATENAME(WEEKDAY, GETDATE())
          AND ts3.booking_mode IN (1,3)
				  AND (ts3.max_queue_length IS NULL OR ISNULL(dq3.total_queue,0) < ts3.max_queue_length)

    ) = 0
    THEN 1 ELSE 0
END AS is_queue_full


        FROM doctor_availability da
        JOIN doctor_time_slots ts
            ON da.availability_id = ts.availability_id

        LEFT JOIN doctor_login dl
            ON dl.doctor_id = d.doctor_id

		WHERE da.doctor_id = d.doctor_id
  AND (da.clinic_id = d.clinic_id OR da.clinic_id IS NULL)
  AND da.is_enabled = 1
  AND ts.is_active = 1
  AND ts.is_deleted = 0
  AND da.day_of_week = DATENAME(WEEKDAY, GETDATE())
  AND ts.booking_mode IN (1,3)

        ORDER BY
            CASE WHEN GETDATE() BETWEEN
                DATETIMEFROMPARTS(YEAR(GETDATE()),MONTH(GETDATE()),DAY(GETDATE()),
                    DATEPART(HOUR, ts.start_time),DATEPART(MINUTE, ts.start_time),0,0)
                AND
                DATETIMEFROMPARTS(YEAR(GETDATE()),MONTH(GETDATE()),DAY(GETDATE()),
                    DATEPART(HOUR, ts.end_time),DATEPART(MINUTE, ts.end_time),0,0)
            THEN 0 ELSE 1 END,
            ts.start_time
    ) qb

    --------------------------------------------------
    -- SLOT AVAILABILITY (ANY DAY)
    --------------------------------------------------
    OUTER APPLY
    (
        SELECT TOP 1
            CASE
                WHEN EXISTS
                (
                    SELECT 1
                    FROM doctor_availability da2
                    JOIN doctor_time_slots ts2
                        ON da2.availability_id = ts2.availability_id
                    WHERE da2.doctor_id = d.doctor_id
                          AND da2.is_enabled = 1
                          AND ts2.booking_mode IN (2,3)
                )
                THEN 1 ELSE 0
            END AS is_slot_available
    ) sa
	  WHERE d.active_status = 0;
END
IF @operation = 'doctor_availability'
BEGIN
    SELECT *
    FROM doctor_availability_vw
    WHERE doctor_id = @doctor_id
      AND clinic_id = @clinic_id ;
END




---------------------------------------------------------
-- CHECK PHONE
---------------------------------------------------------
IF @operation = 'patient_mobile_exist'

BEGIN
    SELECT
        patient_id,
        mobile_no
      FROM dbo.patients
      WHERE mobile_no = @mobile_no;
    RETURN;
END


-- DOCTOR IMAGE
IF @operation = 'uploadPatientImg'
BEGIN
    UPDATE Patients
    SET img_url = @img_url
    WHERE patient_id = @patient_id;

    RETURN;
END



END
GO
/****** Object:  StoredProcedure [dbo].[sp_prescription]    Script Date: 15-10-2026 12:09:44 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- Step 2: Create fresh
CREATE PROCEDURE [dbo].[sp_prescription]
(
    @operation          NVARCHAR(50)  = NULL,
    @prescription_id    INT           = 0,
    @patient_id         INT           = 0,
    @doctor_id          INT           = NULL,
    @prescription_date  DATETIME      = NULL,
    @symptoms           NVARCHAR(MAX) = NULL,
    @diagnosis          NVARCHAR(MAX) = NULL,
    @clinical_notes     NVARCHAR(MAX) = NULL,
    @follow_up_date     DATE          = NULL,
    @advice             NVARCHAR(MAX) = NULL,
    @created_at         DATETIME      = NULL,
	 @user_type    INT           = 0,
    @presc_med_id       INT           = 0,
    @medicine_id        INT           = NULL,
    @medicine_type_id   INT           = NULL,
    @frequency          VARCHAR(50)   = NULL,
    @duration           VARCHAR(50)   = NULL,
    @timing             VARCHAR(50)   = NULL,
    @tablet_dosage      VARCHAR(20)   = NULL,
    @syrup_dosage_ml    VARCHAR(20)   = NULL,
    @inj_dosage         VARCHAR(20)   = NULL,
    @inj_route          VARCHAR(20)   = NULL,
    @drops_count        VARCHAR(10)   = NULL,
    @drops_application  VARCHAR(20)   = NULL,
    @lotion_apply_area  VARCHAR(50)   = NULL,
    @spray_puffs        VARCHAR(20)   = NULL,
    @spray_usage        VARCHAR(20)   = NULL,
	@lotion_usage      VARCHAR(50)   = NULL,
    @powder_dosage      VARCHAR(20)   = NULL,
    @powder_form        VARCHAR(50)   = NULL,
    @inhaler_puffs      VARCHAR(20)   = NULL,
    @inhaler_type       VARCHAR(30)   = NULL,
    @inhaler_technique  VARCHAR(50)   = NULL,
    @inhaler_usage      VARCHAR(50)   = NULL,
	@appointment_id INT=0,
	@clinic_id NVARCHAR(20) = NULL

)
AS
BEGIN
    SET NOCOUNT ON;
	

 IF @operation = 'Insert'
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        IF @prescription_id = 0
        BEGIN
            INSERT INTO dbo.patient_records
            (patient_id, doctor_id, prescription_date, symptoms, diagnosis,
             clinical_notes, follow_up_date, advice, created_at, user_type, appointment_id,clinic_id)
            VALUES
            (@patient_id, @doctor_id, ISNULL(@prescription_date, GETDATE()),
             @symptoms, @diagnosis, @clinical_notes, @follow_up_date,
             @advice, ISNULL(@created_at, GETDATE()), @user_type, @appointment_id,@clinic_id);

            SET @prescription_id = SCOPE_IDENTITY();
        END

        IF @medicine_id IS NOT NULL
        BEGIN
            INSERT INTO dbo.PrescriptionMedicine
                (prescription_id, medicine_id, medicine_type_id, frequency, duration,
                 timing, tablet_dosage, syrup_dosage_ml, inj_dosage, inj_route,
                 drops_count, drops_application, lotion_apply_area, spray_puffs,
                 spray_usage, lotion_usage,
                 powder_dosage, powder_form,
                 inhaler_puffs, inhaler_type, inhaler_technique, inhaler_usage)
                VALUES
                (@prescription_id, @medicine_id, @medicine_type_id, @frequency, @duration,
                 @timing, @tablet_dosage, @syrup_dosage_ml, @inj_dosage, @inj_route,
                 @drops_count, @drops_application, @lotion_apply_area, @spray_puffs,
                 @spray_usage, @lotion_usage,
                 @powder_dosage, @powder_form,
                 @inhaler_puffs, @inhaler_type, @inhaler_technique, @inhaler_usage);
        END

        --------------------------------------------------
        -- ?? GET TOKEN (PATIENT / FAMILY)
        --------------------------------------------------
        DECLARE @token NVARCHAR(MAX) = NULL;

        IF @user_type = 1
        BEGIN
            SELECT @token = token
            FROM patients
            WHERE patient_id = @patient_id;
        END
        ELSE IF @user_type = 2
        BEGIN
            SELECT @token = p.token
            FROM family_members fm
            JOIN patients p ON fm.family_id = p.patient_id
            WHERE fm.member_id = @patient_id;
        END

        COMMIT TRANSACTION;

        --------------------------------------------------
        -- ? FINAL RESPONSE
        --------------------------------------------------
        SELECT 
            1 AS success,
            'Prescription created' AS message,
            @prescription_id AS prescription_id,
            @token AS token;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;

        SELECT 
            0 AS success,
            ERROR_MESSAGE() AS message,
            NULL AS prescription_id,
            NULL AS token;
    END CATCH
END

    IF @operation = 'Update'
    BEGIN
        BEGIN TRY
            BEGIN TRANSACTION;
            UPDATE dbo.patient_records
            SET patient_id=@patient_id, doctor_id=@doctor_id,
                prescription_date=@prescription_date, symptoms=@symptoms,
                diagnosis=@diagnosis, clinical_notes=@clinical_notes,
                follow_up_date=@follow_up_date, advice=@advice, created_at=@created_at,user_type=@user_type,appointment_id=@appointment_id
            WHERE prescription_id = @prescription_id;
            UPDATE dbo.PrescriptionMedicine
           SET medicine_id=@medicine_id, medicine_type_id=@medicine_type_id,
                frequency=@frequency, duration=@duration, timing=@timing,
                tablet_dosage=@tablet_dosage, syrup_dosage_ml=@syrup_dosage_ml,
                inj_dosage=@inj_dosage, inj_route=@inj_route,
                drops_count=@drops_count, drops_application=@drops_application,
                lotion_apply_area=@lotion_apply_area, spray_puffs=@spray_puffs,
                spray_usage=@spray_usage, lotion_usage=@lotion_usage,
                powder_dosage=@powder_dosage, powder_form=@powder_form,
                inhaler_puffs=@inhaler_puffs, inhaler_type=@inhaler_type,
                inhaler_technique=@inhaler_technique, inhaler_usage=@inhaler_usage
            WHERE presc_med_id = @presc_med_id;
            COMMIT TRANSACTION;
            SELECT @prescription_id AS prescription_id;
        END TRY
        BEGIN CATCH
            ROLLBACK TRANSACTION;
            SELECT ERROR_MESSAGE() AS ErrorMessage, ERROR_LINE() AS ErrorLine;
        END CATCH
    END

    IF @operation = 'Fetch'
    BEGIN
        SELECT * FROM dbo.patient_records 
        WHERE prescription_id = @prescription_id;
        
        SELECT * FROM dbo.PrescriptionMedicine 
        WHERE prescription_id = @prescription_id;
    END

    IF @operation = 'Delete'
    BEGIN
        BEGIN TRY
            BEGIN TRANSACTION;
            DELETE FROM dbo.PrescriptionMedicine 
            WHERE prescription_id = @prescription_id;
            DELETE FROM dbo.patient_records 
            WHERE prescription_id = @prescription_id;
            COMMIT TRANSACTION;
            SELECT 1 AS success, 'Prescription deleted successfully' AS message;
        END TRY
        BEGIN CATCH
            ROLLBACK TRANSACTION;
            SELECT ERROR_MESSAGE() AS ErrorMessage, ERROR_LINE() AS ErrorLine;
        END CATCH
    END


	IF @operation = 'FollowUpReminders'
BEGIN
    SELECT
        pr.prescription_id,
        pr.appointment_id,
        pr.doctor_id,
        pr.follow_up_date,
        CASE
            WHEN pr.follow_up_date = CAST(GETDATE() AS DATE)
                THEN 'day_of'
            WHEN pr.follow_up_date = CAST(DATEADD(DAY, 1, GETDATE()) AS DATE)
                THEN 'day_before'
        END AS reminder_kind,
        (SELECT TOP 1 v.doctor_name
           FROM dbo.prescription_vw v
          WHERE v.prescription_id = pr.prescription_id) AS doctor_name,
        CASE
            WHEN pr.user_type = 1 THEN p1.token
            WHEN pr.user_type = 2 THEN p2.token
        END AS patient_token
    FROM dbo.patient_records pr
    LEFT JOIN patients p1
           ON pr.user_type = 1 AND p1.patient_id = pr.patient_id
    LEFT JOIN family_members fm
           ON pr.user_type = 2 AND fm.member_id = pr.patient_id
    LEFT JOIN patients p2
           ON pr.user_type = 2 AND p2.patient_id = fm.family_id
    WHERE pr.follow_up_date IN (
              CAST(GETDATE() AS DATE),
              CAST(DATEADD(DAY, 1, GETDATE()) AS DATE)
          );
END


-- Prescription List (1 per prescription)
IF @operation = 'PatientPrescriptionList'
BEGIN
    SELECT DISTINCT
        prescription_id,
        patient_id,
        patient_name,
        user_type,
        user_type_name,

        doctor_id,
        doctor_name as name,
        qualification,
        specialization,

        prescription_date,
        symptoms,
        diagnosis,
        clinical_notes,
        follow_up_date,
        advice,
        created_at,

        clinic_name,
        clinic_address,
        clinic_contact

    FROM dbo.prescription_vw

    WHERE 
        -- ?? Self
        patient_id = @patient_id
        
        OR 
        
        -- ???????? Family Members
        patient_id IN (
            SELECT member_id 
            FROM family_members 
            WHERE family_id = @patient_id
        )

    ORDER BY prescription_date DESC
END


-- Prescription Detail
ELSE IF @operation = 'PrescriptionDetail'
BEGIN
    SELECT *
    FROM dbo.prescription_vw
    WHERE prescription_id = @prescription_id
END

-- Appointment Wise
ELSE IF @operation = 'AppointmentWisePrescription'
BEGIN
    SELECT *
    FROM dbo.prescription_vw
    WHERE appointment_id = @appointment_id
END

-- Optional: Invalid operation
ELSE
BEGIN
    SELECT 'Invalid Operation' AS message
END
END
GO
/****** Object:  StoredProcedure [dbo].[sp_receptionist]    Script Date: 15-10-2026 12:09:44 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[sp_receptionist]
(
    @operation NVARCHAR(50),
    @recep_id INT = NULL,
    @mobile_no NVARCHAR(50) = NULL,
    @name NVARCHAR(100) = NULL,
    @Address NVARCHAR(100) = NULL,
    @email NVARCHAR(100) = NULL,
    @gender_id INT = NULL,
    @clinic_id  NVARCHAR(50) = NULL,
    @img_url NVARCHAR(MAX) = NULL,
	    @doctor_id INT = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    ---------------------------------------------------------
    -- INSERT RECEPTIONIST
    ---------------------------------------------------------
    IF @operation = 'Insert'
    BEGIN
        BEGIN TRY
            BEGIN TRANSACTION;

            IF EXISTS
            (
                SELECT 1
                FROM receptionist
                WHERE mobile_no = @mobile_no
                AND active_status = 1
            )
            BEGIN
                SELECT
                    0 AS success,
                    'Mobile number already exists' AS message;

                ROLLBACK TRANSACTION;
                RETURN;
            END
			 IF EXISTS
        (
            SELECT 1
            FROM doctor_login
            WHERE mobile = @mobile_no
            AND active_status = 1
        )
        BEGIN
            SELECT 0 AS success, 'This mobile is already registered as a Doctor' AS message;
            ROLLBACK TRANSACTION;
            RETURN;
        END

            INSERT INTO receptionist
            (
                name,
                mobile_no,
                email,
                Address,
                gender_id,
                clinic_id,
                active_status,
                created_at,
				role_id,
				doctor_id
            )
            VALUES
            (
                @name,
                @mobile_no,
                @email,
                @Address,
                @gender_id,
                @clinic_id,
                1,
                GETDATE(),
				3,
				@doctor_id
            );

            SET @recep_id = SCOPE_IDENTITY();

            COMMIT TRANSACTION;

            SELECT
                1 AS success,
                @recep_id AS recep_id,
                'Receptionist created successfully' AS message;

        END TRY
        BEGIN CATCH
            ROLLBACK TRANSACTION;

            SELECT
                0 AS success,
                ERROR_MESSAGE() AS message;
        END CATCH

        RETURN;
    END

    ---------------------------------------------------------
    -- UPDATE RECEPTIONIST
    ---------------------------------------------------------
  IF @operation = 'Update'
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE receptionist
        SET
            name      = ISNULL(@name,      name),
            mobile_no = ISNULL(@mobile_no, mobile_no),
            email     = ISNULL(@email,     email),
            Address   = ISNULL(@Address,   Address),
            gender_id = ISNULL(@gender_id, gender_id),
            clinic_id = ISNULL(@clinic_id, clinic_id),
            doctor_id = ISNULL(@doctor_id, doctor_id)
        WHERE recep_id = @recep_id;

        COMMIT TRANSACTION;

        SELECT
            1 AS success,
            @recep_id AS recep_id,
            'Receptionist updated successfully' AS message;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        SELECT 0 AS success, ERROR_MESSAGE() AS message;
    END CATCH

    RETURN;
END


    ---------------------------------------------------------
    -- FETCH BY MOBILE
    ---------------------------------------------------------
    IF @operation = 'FetchReceptionist'
    BEGIN
        SELECT *
        FROM receptionist
        WHERE mobile_no = @mobile_no
        AND active_status = 1;

        RETURN;
    END

    ---------------------------------------------------------
    -- FETCH ALL
    ---------------------------------------------------------
    IF @operation = 'FetchReceptionistList'
    BEGIN
        SELECT *
        FROM receptionist
        WHERE active_status = 1 and doctor_id=@doctor_id
        ORDER BY recep_id DESC;

        RETURN;
    END

    ---------------------------------------------------------
    -- FETCH BY ID
    ---------------------------------------------------------
    IF @operation = 'FetchById'
    BEGIN
        SELECT *
        FROM receptionist
        WHERE recep_id = @recep_id
        AND active_status = 1;

        RETURN;
    END

    ---------------------------------------------------------
    -- SOFT DELETE
    ---------------------------------------------------------
    IF @operation = 'DeleteReceptionist'
    BEGIN
        UPDATE receptionist
        SET active_status = 0
        WHERE recep_id = @recep_id;

        SELECT
            1 AS success,
            'Receptionist deleted successfully' AS message;

        RETURN;
    END

  

    ---------------------------------------------------------
    -- UPLOAD IMAGE
    ---------------------------------------------------------
    IF @operation = 'uploadReceptionistImg'
    BEGIN
        UPDATE receptionist
        SET img_url = @img_url
        WHERE recep_id = @recep_id;

        SELECT
            1 AS success,
            'Image uploaded successfully' AS message;

        RETURN;
    END
	IF @operation = 'check_phone_receptionist'
    BEGIN
        SELECT
            recep_id,
            name,
            mobile_no,
            email,
            Address,
            gender_id,
            clinic_id,
            doctor_id,
            img_url,
            active_status,
            created_at,
            role_id,
            token
        FROM receptionist
        WHERE mobile_no = @mobile_no
        AND active_status = 1;
        RETURN;
    END

END
GO
/****** Object:  StoredProcedure [dbo].[sp_review]    Script Date: 15-10-2026 12:09:44 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[sp_review]
(
    @operation NVARCHAR(10),
    @appointment_id INT = NULL,
    @doctor_id INT = NULL,
    @patient_id INT = NULL,
    -- Half-star precision: 0.5, 1.0, 1.5, ... 5.0. INT would truncate
    -- 3.5 ? 3 silently at the parameter boundary, before INSERT even
    -- reaches the DECIMAL column.
    @rating DECIMAL(2,1) = NULL,
    @comment NVARCHAR(500) = NULL,
    @reviewed_by_user_id INT = NULL,
	  @clinic_id           NVARCHAR(50)  = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    -- ? Insert review (appointment-based, avoid duplicate)
  IF @operation = 'Insert'
    BEGIN
        IF NOT EXISTS (
            SELECT 1 FROM appointments
            WHERE appointment_id = @appointment_id
              AND doctor_id      = @doctor_id
              AND patient_id     = @patient_id
              AND status         = 'completed'
        )
        BEGIN
            SELECT 0 AS success, 'Appointment not completed or invalid' AS message;
            RETURN;
        END

        IF EXISTS (
            SELECT 1 FROM reviews
            WHERE appointment_id = @appointment_id
        )
        BEGIN
            SELECT 0 AS success, 'Review already submitted' AS message;
            RETURN;
        END

        INSERT INTO reviews (appointment_id, doctor_id, patient_id, rating, comment, created_at, reviewed_by_user_id, clinic_id)
        VALUES (@appointment_id, @doctor_id, @patient_id, @rating, @comment, GETDATE(), @reviewed_by_user_id, @clinic_id);

        UPDATE appointments
        SET is_reviewed = 1
        WHERE appointment_id = @appointment_id;

        SELECT 1 AS success, SCOPE_IDENTITY() AS review_id, 'Review added' AS message;
    END

    -- ? Delete review (by appointment + patient)
    ELSE IF @operation = 'Delete'
    BEGIN
        DELETE FROM reviews
        WHERE appointment_id = @appointment_id
          AND patient_id = @patient_id;

        SELECT 1 AS success, 'Review deleted' AS message;
    END

    -- ? Fetch reviews
    ELSE IF @operation = 'Fetch'
    BEGIN
        -- Case 1: Single appointment review
        IF @appointment_id IS NOT NULL
        BEGIN
            SELECT * FROM reviews
            WHERE appointment_id = @appointment_id;
        END
        ELSE
        BEGIN
            -- Case 2: All reviews of a doctor
            SELECT
                r.review_id,
                r.appointment_id,
                r.doctor_id,
                r.patient_id,

                -- whose account submitted review
                p.name AS reviewed_by_name,

                -- actual appointment for whom
                CASE
                   WHEN r.patient_id = r.reviewed_by_user_id
                        THEN p.name
                   ELSE fm.name
                END AS patient_name,

                r.rating,
                r.comment,
                r.created_at

            FROM reviews r

            LEFT JOIN Patients p
               ON p.patient_id = r.reviewed_by_user_id

            LEFT JOIN family_members fm
               ON fm.member_id = r.patient_id


			   WHERE r.doctor_id = @doctor_id
  AND (@clinic_id IS NULL OR r.clinic_id = @clinic_id OR r.clinic_id IS NULL)
ORDER BY r.created_at DESC;


            --WHERE r.doctor_id = @doctor_id
            --ORDER BY r.created_at DESC;
        END
    END
END
GO
/****** Object:  StoredProcedure [dbo].[sp_slot_today_count]    Script Date: 15-10-2026 12:09:44 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE   PROCEDURE [dbo].[sp_slot_today_count]
    @slot_id INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT COUNT(*) AS cnt
    FROM appointments
    WHERE slot_id = @slot_id
      AND appointment_date = CAST(GETDATE() AS DATE)
      AND LOWER(status) IN ('booked', 'in_progress');
END
GO
/****** Object:  StoredProcedure [dbo].[sp_users_manage]    Script Date: 15-10-2026 12:09:44 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[sp_users_manage]
(
    @operation          NVARCHAR(50),
    @role_id            INT = NULL,
	@gender_id INT =NULL,
	@blood_group_id INT=NULL
)
AS
BEGIN
SET NOCOUNT ON;

IF @operation = 'getGenders' 
BEGIN
	select * from dbo.Gender
END

IF @operation = 'getRelations' 
BEGIN
	select * from dbo.Relations
END

IF @operation = 'getBloodGroups' 
BEGIN
	select * from dbo.blood_groups
END

END
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPane1', @value=N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[23] 4[4] 2[50] 3) )"
      End
      Begin PaneConfiguration = 1
         NumPanes = 3
         Configuration = "(H (1 [50] 4 [25] 3))"
      End
      Begin PaneConfiguration = 2
         NumPanes = 3
         Configuration = "(H (1 [50] 2 [25] 3))"
      End
      Begin PaneConfiguration = 3
         NumPanes = 3
         Configuration = "(H (4 [30] 2 [40] 3))"
      End
      Begin PaneConfiguration = 4
         NumPanes = 2
         Configuration = "(H (1 [56] 3))"
      End
      Begin PaneConfiguration = 5
         NumPanes = 2
         Configuration = "(H (2 [66] 3))"
      End
      Begin PaneConfiguration = 6
         NumPanes = 2
         Configuration = "(H (4 [50] 3))"
      End
      Begin PaneConfiguration = 7
         NumPanes = 1
         Configuration = "(V (3))"
      End
      Begin PaneConfiguration = 8
         NumPanes = 3
         Configuration = "(H (1[56] 4[18] 2) )"
      End
      Begin PaneConfiguration = 9
         NumPanes = 2
         Configuration = "(H (1 [75] 4))"
      End
      Begin PaneConfiguration = 10
         NumPanes = 2
         Configuration = "(H (1[66] 2) )"
      End
      Begin PaneConfiguration = 11
         NumPanes = 2
         Configuration = "(H (4 [60] 2))"
      End
      Begin PaneConfiguration = 12
         NumPanes = 1
         Configuration = "(H (1) )"
      End
      Begin PaneConfiguration = 13
         NumPanes = 1
         Configuration = "(V (4))"
      End
      Begin PaneConfiguration = 14
         NumPanes = 1
         Configuration = "(V (2))"
      End
      ActivePaneConfig = 0
   End
   Begin DiagramPane = 
      Begin Origin = 
         Top = 0
         Left = 0
      End
      Begin Tables = 
      End
   End
   Begin SQLPane = 
   End
   Begin DataPane = 
      Begin ParameterDefaults = ""
      End
      Begin ColumnWidths = 30
         Width = 284
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
      End
   End
   Begin CriteriaPane = 
      Begin ColumnWidths = 11
         Column = 1440
         Alias = 900
         Table = 1176
         Output = 720
         Append = 1400
         NewValue = 1170
         SortType = 1356
         SortOrder = 1416
         GroupBy = 1350
         Filter = 1356
         Or = 1350
         Or = 1350
         Or = 1350
      End
   End
End
' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'appointment_booking_vw'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPaneCount', @value=1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'appointment_booking_vw'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPane1', @value=N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[41] 4[11] 2[13] 3) )"
      End
      Begin PaneConfiguration = 1
         NumPanes = 3
         Configuration = "(H (1 [50] 4 [25] 3))"
      End
      Begin PaneConfiguration = 2
         NumPanes = 3
         Configuration = "(H (1 [50] 2 [25] 3))"
      End
      Begin PaneConfiguration = 3
         NumPanes = 3
         Configuration = "(H (4 [30] 2 [40] 3))"
      End
      Begin PaneConfiguration = 4
         NumPanes = 2
         Configuration = "(H (1 [56] 3))"
      End
      Begin PaneConfiguration = 5
         NumPanes = 2
         Configuration = "(H (2 [66] 3))"
      End
      Begin PaneConfiguration = 6
         NumPanes = 2
         Configuration = "(H (4 [50] 3))"
      End
      Begin PaneConfiguration = 7
         NumPanes = 1
         Configuration = "(V (3))"
      End
      Begin PaneConfiguration = 8
         NumPanes = 3
         Configuration = "(H (1[56] 4[18] 2) )"
      End
      Begin PaneConfiguration = 9
         NumPanes = 2
         Configuration = "(H (1 [75] 4))"
      End
      Begin PaneConfiguration = 10
         NumPanes = 2
         Configuration = "(H (1[66] 2) )"
      End
      Begin PaneConfiguration = 11
         NumPanes = 2
         Configuration = "(H (4 [60] 2))"
      End
      Begin PaneConfiguration = 12
         NumPanes = 1
         Configuration = "(H (1) )"
      End
      Begin PaneConfiguration = 13
         NumPanes = 1
         Configuration = "(V (4))"
      End
      Begin PaneConfiguration = 14
         NumPanes = 1
         Configuration = "(V (2))"
      End
      ActivePaneConfig = 0
   End
   Begin DiagramPane = 
      Begin Origin = 
         Top = 0
         Left = 0
      End
      Begin Tables = 
         Begin Table = "doctor_availability"
            Begin Extent = 
               Top = 7
               Left = 48
               Bottom = 262
               Right = 236
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "doctor_time_slots"
            Begin Extent = 
               Top = 7
               Left = 290
               Bottom = 253
               Right = 566
            End
            DisplayFlags = 280
            TopColumn = 3
         End
      End
   End
   Begin SQLPane = 
   End
   Begin DataPane = 
      Begin ParameterDefaults = ""
      End
      Begin ColumnWidths = 9
         Width = 284
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
      End
   End
   Begin CriteriaPane = 
      Begin ColumnWidths = 11
         Column = 1440
         Alias = 900
         Table = 1176
         Output = 720
         Append = 1400
         NewValue = 1170
         SortType = 1356
         SortOrder = 1416
         GroupBy = 1350
         Filter = 1356
         Or = 1350
         Or = 1350
         Or = 1350
      End
   End
End
' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'doctor_availability_vw'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPaneCount', @value=1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'doctor_availability_vw'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPane1', @value=N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[43] 4[32] 2[5] 3) )"
      End
      Begin PaneConfiguration = 1
         NumPanes = 3
         Configuration = "(H (1 [50] 4 [25] 3))"
      End
      Begin PaneConfiguration = 2
         NumPanes = 3
         Configuration = "(H (1 [50] 2 [25] 3))"
      End
      Begin PaneConfiguration = 3
         NumPanes = 3
         Configuration = "(H (4 [30] 2 [40] 3))"
      End
      Begin PaneConfiguration = 4
         NumPanes = 2
         Configuration = "(H (1 [56] 3))"
      End
      Begin PaneConfiguration = 5
         NumPanes = 2
         Configuration = "(H (2 [66] 3))"
      End
      Begin PaneConfiguration = 6
         NumPanes = 2
         Configuration = "(H (4 [50] 3))"
      End
      Begin PaneConfiguration = 7
         NumPanes = 1
         Configuration = "(V (3))"
      End
      Begin PaneConfiguration = 8
         NumPanes = 3
         Configuration = "(H (1[56] 4[18] 2) )"
      End
      Begin PaneConfiguration = 9
         NumPanes = 2
         Configuration = "(H (1 [75] 4))"
      End
      Begin PaneConfiguration = 10
         NumPanes = 2
         Configuration = "(H (1[66] 2) )"
      End
      Begin PaneConfiguration = 11
         NumPanes = 2
         Configuration = "(H (4 [60] 2))"
      End
      Begin PaneConfiguration = 12
         NumPanes = 1
         Configuration = "(H (1) )"
      End
      Begin PaneConfiguration = 13
         NumPanes = 1
         Configuration = "(V (4))"
      End
      Begin PaneConfiguration = 14
         NumPanes = 1
         Configuration = "(V (2))"
      End
      ActivePaneConfig = 0
   End
   Begin DiagramPane = 
      Begin Origin = 
         Top = 0
         Left = 0
      End
      Begin Tables = 
         Begin Table = "c"
            Begin Extent = 
               Top = 7
               Left = 48
               Bottom = 318
               Right = 251
            End
            DisplayFlags = 280
            TopColumn = 3
         End
         Begin Table = "dl"
            Begin Extent = 
               Top = 7
               Left = 299
               Bottom = 318
               Right = 493
            End
            DisplayFlags = 280
            TopColumn = 8
         End
         Begin Table = "r"
            Begin Extent = 
               Top = 7
               Left = 541
               Bottom = 126
               Right = 735
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "g"
            Begin Extent = 
               Top = 7
               Left = 783
               Bottom = 126
               Right = 977
            End
            DisplayFlags = 280
            TopColumn = 0
         End
      End
   End
   Begin SQLPane = 
   End
   Begin DataPane = 
      Begin ParameterDefaults = ""
      End
      Begin ColumnWidths = 29
         Width = 284
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
     ' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'doctor_login_vw'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPane2', @value=N'    Width = 1200
         Width = 1200
      End
   End
   Begin CriteriaPane = 
      Begin ColumnWidths = 11
         Column = 1440
         Alias = 900
         Table = 1176
         Output = 720
         Append = 1400
         NewValue = 1170
         SortType = 1356
         SortOrder = 1416
         GroupBy = 1356
         Filter = 1356
         Or = 1350
         Or = 1350
         Or = 1350
      End
   End
End
' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'doctor_login_vw'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPaneCount', @value=2 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'doctor_login_vw'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPane1', @value=N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[40] 4[20] 2[20] 3) )"
      End
      Begin PaneConfiguration = 1
         NumPanes = 3
         Configuration = "(H (1 [50] 4 [25] 3))"
      End
      Begin PaneConfiguration = 2
         NumPanes = 3
         Configuration = "(H (1 [50] 2 [25] 3))"
      End
      Begin PaneConfiguration = 3
         NumPanes = 3
         Configuration = "(H (4 [30] 2 [40] 3))"
      End
      Begin PaneConfiguration = 4
         NumPanes = 2
         Configuration = "(H (1 [56] 3))"
      End
      Begin PaneConfiguration = 5
         NumPanes = 2
         Configuration = "(H (2 [66] 3))"
      End
      Begin PaneConfiguration = 6
         NumPanes = 2
         Configuration = "(H (4 [50] 3))"
      End
      Begin PaneConfiguration = 7
         NumPanes = 1
         Configuration = "(V (3))"
      End
      Begin PaneConfiguration = 8
         NumPanes = 3
         Configuration = "(H (1[56] 4[18] 2) )"
      End
      Begin PaneConfiguration = 9
         NumPanes = 2
         Configuration = "(H (1 [75] 4))"
      End
      Begin PaneConfiguration = 10
         NumPanes = 2
         Configuration = "(H (1[66] 2) )"
      End
      Begin PaneConfiguration = 11
         NumPanes = 2
         Configuration = "(H (4 [60] 2))"
      End
      Begin PaneConfiguration = 12
         NumPanes = 1
         Configuration = "(H (1) )"
      End
      Begin PaneConfiguration = 13
         NumPanes = 1
         Configuration = "(V (4))"
      End
      Begin PaneConfiguration = 14
         NumPanes = 1
         Configuration = "(V (2))"
      End
      ActivePaneConfig = 0
   End
   Begin DiagramPane = 
      Begin Origin = 
         Top = 0
         Left = 0
      End
      Begin Tables = 
         Begin Table = "p"
            Begin Extent = 
               Top = 7
               Left = 48
               Bottom = 318
               Right = 242
            End
            DisplayFlags = 280
            TopColumn = 3
         End
         Begin Table = "r"
            Begin Extent = 
               Top = 7
               Left = 290
               Bottom = 296
               Right = 484
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "g"
            Begin Extent = 
               Top = 7
               Left = 532
               Bottom = 126
               Right = 726
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "bg"
            Begin Extent = 
               Top = 7
               Left = 774
               Bottom = 126
               Right = 998
            End
            DisplayFlags = 280
            TopColumn = 0
         End
      End
   End
   Begin SQLPane = 
   End
   Begin DataPane = 
      Begin ParameterDefaults = ""
      End
      Begin ColumnWidths = 17
         Width = 284
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
      End
   End
   Begin CriteriaPane = 
      Begin ColumnWidths = 11
         Column = 1440
         Alias = 900
         Table = 1176
         Output = 720
         Append = 1400
         NewValue = 1170
         SortTyp' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'patient_login_vw'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPane2', @value=N'e = 1356
         SortOrder = 1416
         GroupBy = 1356
         Filter = 1356
         Or = 1350
         Or = 1350
         Or = 1350
      End
   End
End
' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'patient_login_vw'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPaneCount', @value=2 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'patient_login_vw'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPane1', @value=N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[63] 4[3] 2[11] 3) )"
      End
      Begin PaneConfiguration = 1
         NumPanes = 3
         Configuration = "(H (1 [50] 4 [25] 3))"
      End
      Begin PaneConfiguration = 2
         NumPanes = 3
         Configuration = "(H (1 [50] 2 [25] 3))"
      End
      Begin PaneConfiguration = 3
         NumPanes = 3
         Configuration = "(H (4 [30] 2 [40] 3))"
      End
      Begin PaneConfiguration = 4
         NumPanes = 2
         Configuration = "(H (1 [56] 3))"
      End
      Begin PaneConfiguration = 5
         NumPanes = 2
         Configuration = "(H (2 [66] 3))"
      End
      Begin PaneConfiguration = 6
         NumPanes = 2
         Configuration = "(H (4 [50] 3))"
      End
      Begin PaneConfiguration = 7
         NumPanes = 1
         Configuration = "(V (3))"
      End
      Begin PaneConfiguration = 8
         NumPanes = 3
         Configuration = "(H (1[56] 4[18] 2) )"
      End
      Begin PaneConfiguration = 9
         NumPanes = 2
         Configuration = "(H (1 [75] 4))"
      End
      Begin PaneConfiguration = 10
         NumPanes = 2
         Configuration = "(H (1[66] 2) )"
      End
      Begin PaneConfiguration = 11
         NumPanes = 2
         Configuration = "(H (4 [60] 2))"
      End
      Begin PaneConfiguration = 12
         NumPanes = 1
         Configuration = "(H (1) )"
      End
      Begin PaneConfiguration = 13
         NumPanes = 1
         Configuration = "(V (4))"
      End
      Begin PaneConfiguration = 14
         NumPanes = 1
         Configuration = "(V (2))"
      End
      ActivePaneConfig = 0
   End
   Begin DiagramPane = 
      Begin Origin = 
         Top = 0
         Left = 0
      End
      Begin Tables = 
         Begin Table = "p"
            Begin Extent = 
               Top = 102
               Left = 48
               Bottom = 265
               Right = 258
            End
            DisplayFlags = 280
            TopColumn = 8
         End
         Begin Table = "d"
            Begin Extent = 
               Top = 7
               Left = 826
               Bottom = 436
               Right = 1020
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "pt"
            Begin Extent = 
               Top = 7
               Left = 1068
               Bottom = 356
               Right = 1268
            End
            DisplayFlags = 280
            TopColumn = 1
         End
         Begin Table = "fm"
            Begin Extent = 
               Top = 308
               Left = 568
               Bottom = 471
               Right = 762
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "pm"
            Begin Extent = 
               Top = 7
               Left = 306
               Bottom = 438
               Right = 520
            End
            DisplayFlags = 280
            TopColumn = 7
         End
         Begin Table = "mm"
            Begin Extent = 
               Top = 7
               Left = 568
               Bottom = 170
               Right = 778
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "mt"
            Begin Extent = 
               Top = 184
               Left = 592
               Bottom = 303
               Right = 805
            End
            DisplayFlags = 280
            TopColumn = 0
         ' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'prescription_vw'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPane2', @value=N'End
         Begin Table = "c"
            Begin Extent = 
               Top = 301
               Left = 48
               Bottom = 464
               Right = 251
            End
            DisplayFlags = 280
            TopColumn = 9
         End
         Begin Table = "ap"
            Begin Extent = 
               Top = 441
               Left = 299
               Bottom = 604
               Right = 516
            End
            DisplayFlags = 280
            TopColumn = 0
         End
      End
   End
   Begin SQLPane = 
   End
   Begin DataPane = 
      Begin ParameterDefaults = ""
      End
      Begin ColumnWidths = 46
         Width = 284
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 2376
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
      End
   End
   Begin CriteriaPane = 
      Begin ColumnWidths = 11
         Column = 1440
         Alias = 900
         Table = 1176
         Output = 720
         Append = 1400
         NewValue = 1170
         SortType = 1356
         SortOrder = 1416
         GroupBy = 1356
         Filter = 1356
         Or = 1350
         Or = 1350
         Or = 1350
      End
   End
End
' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'prescription_vw'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPaneCount', @value=2 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'prescription_vw'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPane1', @value=N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[40] 4[20] 2[20] 3) )"
      End
      Begin PaneConfiguration = 1
         NumPanes = 3
         Configuration = "(H (1 [50] 4 [25] 3))"
      End
      Begin PaneConfiguration = 2
         NumPanes = 3
         Configuration = "(H (1 [50] 2 [25] 3))"
      End
      Begin PaneConfiguration = 3
         NumPanes = 3
         Configuration = "(H (4 [30] 2 [40] 3))"
      End
      Begin PaneConfiguration = 4
         NumPanes = 2
         Configuration = "(H (1 [56] 3))"
      End
      Begin PaneConfiguration = 5
         NumPanes = 2
         Configuration = "(H (2 [66] 3))"
      End
      Begin PaneConfiguration = 6
         NumPanes = 2
         Configuration = "(H (4 [50] 3))"
      End
      Begin PaneConfiguration = 7
         NumPanes = 1
         Configuration = "(V (3))"
      End
      Begin PaneConfiguration = 8
         NumPanes = 3
         Configuration = "(H (1[56] 4[18] 2) )"
      End
      Begin PaneConfiguration = 9
         NumPanes = 2
         Configuration = "(H (1 [75] 4))"
      End
      Begin PaneConfiguration = 10
         NumPanes = 2
         Configuration = "(H (1[66] 2) )"
      End
      Begin PaneConfiguration = 11
         NumPanes = 2
         Configuration = "(H (4 [60] 2))"
      End
      Begin PaneConfiguration = 12
         NumPanes = 1
         Configuration = "(H (1) )"
      End
      Begin PaneConfiguration = 13
         NumPanes = 1
         Configuration = "(V (4))"
      End
      Begin PaneConfiguration = 14
         NumPanes = 1
         Configuration = "(V (2))"
      End
      ActivePaneConfig = 0
   End
   Begin DiagramPane = 
      Begin Origin = 
         Top = 0
         Left = 0
      End
      Begin Tables = 
         Begin Table = "receptionist"
            Begin Extent = 
               Top = 7
               Left = 48
               Bottom = 301
               Right = 242
            End
            DisplayFlags = 280
            TopColumn = 8
         End
         Begin Table = "clinics"
            Begin Extent = 
               Top = 14
               Left = 339
               Bottom = 177
               Right = 542
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "Gender"
            Begin Extent = 
               Top = 7
               Left = 590
               Bottom = 126
               Right = 784
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "role"
            Begin Extent = 
               Top = 7
               Left = 832
               Bottom = 126
               Right = 1026
            End
            DisplayFlags = 280
            TopColumn = 0
         End
      End
   End
   Begin SQLPane = 
   End
   Begin DataPane = 
      Begin ParameterDefaults = ""
      End
      Begin ColumnWidths = 16
         Width = 284
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
         Width = 1200
      End
   End
   Begin CriteriaPane = 
      Begin ColumnWidths = 11
         Column = 1440
         Alias = 900
         Table = 1176
         Output = 720
         Append = 1400
         NewValue = 1170
         Sort' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'receptionist_vw'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPane2', @value=N'Type = 1356
         SortOrder = 1416
         GroupBy = 1350
         Filter = 1356
         Or = 1350
         Or = 1350
         Or = 1350
      End
   End
End
' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'receptionist_vw'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPaneCount', @value=2 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'receptionist_vw'
GO
ALTER DATABASE [QLess_Prod_db] SET  READ_WRITE 
GO
`````

## `backend/.env.example`

`````
# Copy to .env and fill in real values. NEVER commit .env to git.
# Rotate any value that has ever been pushed to a remote.

# ── App ──────────────────────────────────────────────────────────────
NODE_ENV=production
PORT=3000

# ── Database (MSSQL) ─────────────────────────────────────────────────
DB_USER=
DB_PASSWORD=
DB_NAME=QLess
DB_SERVER=
DB_PORT=1433
DB_POOL_MAX=20
DB_POOL_MIN=0

# ── Auth ─────────────────────────────────────────────────────────────
# Generate with: node -e "console.log(require('crypto').randomBytes(64).toString('hex'))"
JWT_SECRET_KEY=
JWT_ACCESS_TTL=15m
REFRESH_TOKEN_SECRET=
# How long a user stays signed in without re-entering OTP (days). Default 30.
REFRESH_TOKEN_TTL_DAYS=30

# ── CORS ─────────────────────────────────────────────────────────────
# Comma-separated list of allowed browser origins.
# Native mobile clients (no Origin header) are always allowed.
CORS_ORIGINS=https://qless.vengurlatech.com

# ── Firebase Admin SDK ───────────────────────────────────────────────
# Absolute or relative path to the service-account JSON. Preferred over
# placing a JSON file at routes/serviceAccountKey.json.
GOOGLE_APPLICATION_CREDENTIALS=./secrets/firebase-admin.json

# ── Public base URL (used in returned image URLs) ────────────────────
PUBLIC_BASE_URL=https://qless.vengurlatech.com

# ── Admin panel (/admin) ─────────────────────────────────────────────
# Single shared staff credential for approving newly registered doctors.
# No admin table — this IS the account. Pick a strong, unique password.
ADMIN_USERNAME=
ADMIN_PASSWORD=
`````

## `backend/.gitignore`

`````
# Dependencies
node_modules/

# Secrets — NEVER commit these. Rotate any previously-committed value.
.env
.env.local
.env.*.local
ServiceAccount.json
serviceAccountKey.json
routes/serviceAccountKey.json
routes/**/qless-firebase-adminsdk*.json
routes/**/*-adminsdk*.json
secrets/

# Logs
*.log
npm-debug.log*

# OS / IDE
.DS_Store
.vscode/
.idea/
*.iml

# Server-local
.user.ini
uploads/temp/
`````

## `backend/package.json`

`````json
{
  "name": "donotwait",
  "version": "0.0.0",
  "private": true,
  "scripts": {
    "start": "node app.js",
    "db": "node scripts/run-sql.js"
  },
  "dependencies": {
    "axios": "^1.16.1",
    "bcryptjs": "^3.0.2",
    "cors": "^2.8.6",
    "debug": "^4.4.3",
    "dotenv": "^17.2.1",
    "express": "^4.22.2",
    "express-rate-limit": "^8.5.2",
    "firebase-admin": "^13.8.0",
    "fs-extra": "^11.2.0",
    "helmet": "^8.2.0",
    "jsonwebtoken": "^9.0.2",
    "morgan": "~1.9.1",
    "mssql": "^11.0.1",
    "multer": "^2.1.1",
    "node-cron": "^4.2.1",
    "socket.io": "^4.8.3"
  },
  "main": "app.js",
  "keywords": [],
  "author": "",
  "license": "ISC",
  "description": ""
}
`````

## `backend/web.config`

`````xml
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
  <system.webServer>
    <httpErrors existingResponse="PassThrough"/>
    <webSocket enabled="true" />

    <httpProtocol>
      <customHeaders>
        <add name="Connection" value="keep-alive"/>
      </customHeaders>
    </httpProtocol>

    <security>
      <requestFiltering>
        <verbs>
          <add verb="OPTIONS" allowed="true"/>
        </verbs>
      </requestFiltering>
    </security>

    <tracing>
      <traceFailedRequests>
        <clear/>
      </traceFailedRequests>
    </tracing>

    <handlers>
      <add name="iisnode" path="app.js" verb="*" modules="iisnode"/>
    </handlers>

    <rewrite>
      <rules>
        <rule name="NodeInspector" patternSyntax="ECMAScript" stopProcessing="true">
          <match url="^app.js\/debug[\/]?"/>
        </rule>
        <rule name="OPTIONS preflight" stopProcessing="true">
          <match url="(.*)"/>
          <conditions>
            <add input="{REQUEST_METHOD}" pattern="^OPTIONS$"/>
          </conditions>
          <action type="Rewrite" url="app.js"/>
        </rule>
        <rule name="Node.js" stopProcessing="true">
          <match url="(.*)"/>
          <action type="Rewrite" url="app.js"/>
        </rule>
      </rules>
    </rewrite>

    <iisnode
      devErrorsEnabled="true"
      debuggingEnabled="false"
      loggingEnabled="true"
      logDirectory="iisnode_logs"
      maxLogFileSizeInKB="10240"
      maxTotalLogFileSizeInKB="102400"
      maxLogFiles="20"
      nodeProcessCommandLine="C:\Program Files\nodejs\node.exe"
      nodeProcessCountPerApplication="1"
      maxConcurrentRequestsPerProcess="1024"
      maxNamedPipeConnectionRetry="200"
      namedPipeConnectionRetryDelay="250"
      maxNamedPipeConnectionPoolSize="512"
      maxNamedPipePooledConnectionAge="60000"
      asyncCompletionThreadCount="0"
      initialRequestBufferSize="4096"
      maxRequestBufferSize="65536"
      watchedFiles="*.js;node_modules\*"
      recycleSignalEnabled="false"
    />

    <directoryBrowse enabled="false"/>
  </system.webServer>

  <system.web>
    <compilation tempDirectory="C:\Inetpub\vhosts\vengurlatech.com\tmp"/>
  </system.web>
</configuration>
`````

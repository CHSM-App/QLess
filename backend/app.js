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

// Public — login + token refresh must be reachable without a valid token.
app.use('/login', loginRouter);

// Authenticated — every doctor/patient endpoint requires a valid JWT.
app.use('/doctor/users', protect, doctorUsersRouter);
app.use('/doctor/insert', protect, doctorInsertRouter);
app.use('/doctor/index', protect, doctorIndexRouter);
app.use('/patient/users', protect, patientUsersRouter);
app.use('/patient/insert', protect, patientInsertRouter);
app.use('/patient/index', protect, patientIndexRouter);

// Uploaded images — JWT-gated.
app.use('/uploads', uploadAuth, express.static(path.join(__dirname, 'uploads')));

app.get('/', (req, res) => res.send('OK'));

// 404 fallthrough
app.use((req, res) => res.status(404).json({ error: 'Not Found' }));

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
    origin: '*', // restrict in production
    methods: ['GET', 'POST'],
  },
});

app.set('io', io);

// doctorSockets: doctorId → Set<socketId>  (active connections)
// doctorStatus:  doctorId → true/false       (last known online state)
const doctorSockets = new Map();
const doctorStatus  = new Map();

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
      socket.emit('doctor_status', { doctor_id: clinicId, online: doctorStatus.get(clinicId) });
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
            AND  a.status IN ('in_progress', 'completed')
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
    doctorStatus.set(doctorId, true);
    io.to(`clinic_${doctorId}`).emit('doctor_status', { doctor_id: doctorId, online: true });
    console.log(`[DOCTOR] emitted online=true to clinic_${doctorId}`);
  });

  socket.on('leaveClinic', (clinicId) => {
    socket.leave(`clinic_${clinicId}`);
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
            doctorStatus.set(doctorId, false); // remember offline state
            io.to(`clinic_${doctorId}`).emit('doctor_status', { doctor_id: doctorId, online: false });
            console.log(`[DOCTOR] emitted online=false to clinic_${doctorId}`);
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
// Socket.IO: live queue updates and doctor online/offline status.
// attach(server, allowedOrigins) is called once by server.js; routes reach the
// instance through req.app.get('io').
const { Server } = require('socket.io');
const db = require('./db');

function attach(server, allowed) {
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

  return io;
}

module.exports = { attach };

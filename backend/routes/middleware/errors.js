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

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

// Same rule for every route at once: any 5xx JSON body is logged in full and
// replaced by a generic message + correlation id, so a catch block that does
// `res.status(500).json({ message: err.message })` can no longer leak SQL /
// driver details. 4xx bodies (validation, business messages) are untouched.
const GENERIC = 'Something went wrong. Please try again.';
function hideServerErrors(req, res, next) {
  const json = res.json.bind(res);
  res.json = (body) => {
    if (res.statusCode < 500 || !body || typeof body !== 'object') return json(body);
    const id = req.id || crypto.randomBytes(6).toString('hex');
    log.error(`[${id}] [${res.statusCode}] ${req.method} ${req.originalUrl || req.path}: ${JSON.stringify(body).slice(0, 2000)}`);
    const safe = { success: false, message: GENERIC, correlation_id: id };
    if ('error' in body) safe.error = GENERIC;
    return json(safe);
  };
  next();
}

module.exports = { serverError, hideServerErrors, GENERIC };

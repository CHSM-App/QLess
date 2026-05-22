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

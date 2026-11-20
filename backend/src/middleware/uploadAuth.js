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

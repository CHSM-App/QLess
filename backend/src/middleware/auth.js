// middleware/auth.js
const jwt = require('jsonwebtoken');
const dotenv = require('dotenv');
dotenv.config();
const log = require('./logger');

/**
 * Verifies an access token and returns its payload, or throws.
 * Only real sessions pass: the OTP loginTicket is signed with the same key
 * but carries `purpose` and no role_id — accepting it here let anyone who
 * verified their own phone skip every role and ownership check.
 */
function verifyAccessToken(token) {
  const decoded = jwt.verify(token, process.env.JWT_SECRET_KEY, { algorithms: ['HS256'] });
  if (decoded.purpose || !decoded.role_id) throw new Error('not an access token');
  return decoded;
}

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
    req.user = verifyAccessToken(token);
    next();
  } catch (err) {
    log.error('JWT verification failed: ' + err.message);
    res.status(401).json({ msg: 'Token is not valid' });
  }
};

module.exports.verifyAccessToken = verifyAccessToken;

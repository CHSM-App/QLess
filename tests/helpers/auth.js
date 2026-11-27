const jwt = require('jsonwebtoken');
const { ROLE } = require('../../src/middleware/roles');

/**
 * Signed access token shaped like the ones /login/Createlogin issues.
 * @param {object} overrides - e.g. { role_id: ROLE.RECEPTIONIST, uid: 7 }
 */
function makeToken(overrides = {}) {
  const payload = { mobile: '9876543210', role_id: ROLE.DOCTOR, uid: 1, ...overrides };
  return jwt.sign(payload, process.env.JWT_SECRET_KEY, { expiresIn: '15m' });
}

/** Authorization header object with a Bearer token. */
function authHeader(overrides = {}) {
  return { Authorization: `Bearer ${makeToken(overrides)}` };
}

module.exports = { makeToken, authHeader, ROLE };

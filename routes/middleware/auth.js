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


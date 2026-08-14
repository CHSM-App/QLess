const auth = require('./auth');

module.exports = function protect(req, res, next) {
  auth(req, res, function () {
    if (!req.user) {
      return;  // stop route execution if token invalid/expired
    }
    next();     // continue to Router
  });
};

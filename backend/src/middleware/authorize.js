const log = require('./logger');

/**
 * Route guard: allows only the listed role ids. Must run after auth/protect,
 * which puts the decoded token on req.user.
 *
 * Until this existed, role was enforced only by hiding buttons in the app —
 * anyone who could call the API could act as any role. The access token now
 * carries role_id, so the server can decide.
 *
 * Answers 403 (forbidden), never 401: 401 means "your token expired, refresh
 * it", and the app acts on that difference. A role that is simply not allowed
 * must not look like an expired session.
 */
function authorize(...allowedRoleIds) {
	const allowed = allowedRoleIds.flat().map(Number);

	return function authorizeMiddleware(req, res, next) {
		const roleId = Number(req.user && req.user.role_id);

		if (!roleId) {
			// Token predates role_id (issued before this change) — treat as
			// unauthenticated so the client signs in again rather than being
			// told it lacks permission it may actually have.
			log.error('authorize: token without role_id on ' + req.originalUrl);
			return res.status(401).json({ msg: 'Session is out of date. Please sign in again.' });
		}

		if (!allowed.includes(roleId)) {
			log.error('authorize: role ' + roleId + ' blocked on ' + req.originalUrl);
			return res.status(403).json({ msg: 'Your account does not have access to this action.' });
		}

		return next();
	};
}

module.exports = authorize;

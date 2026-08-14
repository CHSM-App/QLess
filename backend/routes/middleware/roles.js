// Single source of truth for role ids. Both the login routes (which issue
// sessions) and authorize() (which gates routes) read from here, so a role can
// never mean one thing at login and another at request time.
const ROLE = {
	DOCTOR: 1,
	PATIENT: 2,
	RECEPTIONIST: 3,
};

const ROLE_ID_BY_NAME = {
	doctor: ROLE.DOCTOR,
	patient: ROLE.PATIENT,
	receptionist: ROLE.RECEPTIONIST,
};

const ROLE_NAME_BY_ID = {
	[ROLE.DOCTOR]: 'doctor',
	[ROLE.PATIENT]: 'patient',
	[ROLE.RECEPTIONIST]: 'receptionist',
};

/**
 * Returns 1/2/3, or null when the role cannot be determined.
 * Takes the numeric id first and falls back to the role name, because
 * ManageRefreshToken does not project role_id on every operation.
 */
function resolveRoleId(roleId, roleName) {
	const asNumber = Number(roleId);
	if (ROLE_NAME_BY_ID[asNumber]) return asNumber;
	if (typeof roleName === 'string') {
		const mapped = ROLE_ID_BY_NAME[roleName.trim().toLowerCase()];
		if (mapped) return mapped;
	}
	return null;
}

module.exports = { ROLE, ROLE_ID_BY_NAME, ROLE_NAME_BY_ID, resolveRoleId };

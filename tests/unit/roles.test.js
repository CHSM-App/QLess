const { ROLE, resolveRoleId } = require('../../src/middleware/roles');

describe('resolveRoleId', () => {
  test('takes a valid numeric id first', () => {
    expect(resolveRoleId(3, 'doctor')).toBe(ROLE.RECEPTIONIST);
    expect(resolveRoleId('1', null)).toBe(ROLE.DOCTOR);
  });

  test('falls back to the role name when the id is missing or unknown', () => {
    expect(resolveRoleId(null, 'receptionist')).toBe(ROLE.RECEPTIONIST);
    expect(resolveRoleId(0, ' Patient ')).toBe(ROLE.PATIENT);
    expect(resolveRoleId(99, 'doctor')).toBe(ROLE.DOCTOR);
  });

  // The receptionist→doctor session bug: a NULL role must never become a role.
  test('returns null when neither identifies a role', () => {
    expect(resolveRoleId(null, null)).toBeNull();
    expect(resolveRoleId(undefined, '')).toBeNull();
    expect(resolveRoleId(0, 'nurse')).toBeNull();
  });
});

const { ROLES } = require('../utils/roles');
const { fail } = require('../utils/response');

const rbac = (...allowedRoles) => {
  const allowed = allowedRoles.length ? allowedRoles : Object.values(ROLES);
  return (req, res, next) => {
    const role = req.user?.role;
    if (!role || !allowed.includes(role)) {
      return fail(res, 403, `Role (${role || 'none'}) is not allowed`, {
        code: 'INSUFFICIENT_PERMISSIONS',
      });
    }
    next();
  };
};

module.exports = { rbac };


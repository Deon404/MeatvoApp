const { ROLES } = require('../utils/roles');

const rbac = (...allowedRoles) => {
  const allowed = allowedRoles.length ? allowedRoles : Object.values(ROLES);
  return (req, res, next) => {
    const role = req.user?.role;
    if (!role || !allowed.includes(role)) {
      return res.status(403).json({
        success: false,
        data: {},
        message: `Role (${role || 'none'}) is not allowed`,
      });
    }
    next();
  };
};

module.exports = { rbac };


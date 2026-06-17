const { query } = require('../db/postgres');
const { ROLES } = require('../utils/roles');
const { fail } = require('../utils/response');

/**
 * Allows users with role `delivery` or an approved delivery_partners profile.
 * Supports accounts that deliver while their primary role is still `customer`.
 */
const requireDeliveryPartner = async (req, res, next) => {
  const role = req.user?.role;
  if (role === ROLES.DELIVERY || role === ROLES.ADMIN) {
    return next();
  }

  const userId = Number(req.user?.id);
  if (!Number.isFinite(userId)) {
    return fail(res, 403, 'Authentication required', { code: 'INSUFFICIENT_PERMISSIONS' });
  }

  const { rows } = await query(
    `SELECT id FROM delivery_partners
     WHERE user_id = $1 AND approved = TRUE
     LIMIT 1`,
    [userId]
  );

  if (rows[0]) {
    return next();
  }

  return fail(res, 403, `Role (${role || 'none'}) is not allowed`, {
    code: 'INSUFFICIENT_PERMISSIONS',
  });
};

module.exports = { requireDeliveryPartner };

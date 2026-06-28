const asyncHandler = require('express-async-handler');
const { withTransaction, query } = require('../../db/postgres');
const { repairAppSettingsSchema } = require('../../db/appSettings');
const { ok, fail } = require('../../utils/response');
const { emitToAll } = require('../../socket/socket');
const { syncOperationalToStoreSettings, getMergedStoreSettings } = require('../../utils/storeSettings.util');
const { addressToText } = require('../../utils/address');
const { canTransition } = require('../../utils/orderStateMachine');
const { assertWeightReconciliationForDispatch } = require('../../utils/weightReconciliationDispatch.util');
const {
  emitAssignmentSuccess,
  emitAssignmentCancelled,
  retryAssignOrderToPartner,
  manualAssignOrderToPartner,
  assignOrderToPartner,
} = require('../../services/assignment.service');
const { signStoredImageUrl, normalizeStoredImageUrl } = require('../../utils/uploadSigning');
const { logger } = require('../../utils/logger');
const {
  restoreStockForOrder,
  shouldRestoreStockOnCancel,
} = require('../payments/payment-stock');
const {
  listOpenAdminTasks,
  resolveFailedDelivery,
} = require('../../services/failedDelivery.service');
const { isOrderBlockedFromAssignment, ADMIN_TASK_TYPES } = require('../../constants/failedDelivery.constants');
const { DEFAULT_STORE_SETTINGS, PACK_AGE } = require('../../config/businessRules');
const { enrichOrderWithPackAge } = require('../../services/packAge.service');
const { getDispatchQueueOrders } = require('../../services/dispatch.service');
const { resolveAdminTaskByOrder } = require('../../services/adminTask.service');
const { countRiderActiveOrders, refreshPartnerOperationalState } = require('../../utils/deliveryPartner.util');
const { createParamBinder, joinWhere, buildUpdateSet } = require('../../utils/sqlParams');
const {
  packOrderWithWeightReconciliation,
} = require('../../services/packingWeightReconciliation.service');
const {
  getOpsMetrics,
  resolvePeriodBounds,
  computeCommerceKpiDeltas,
  computeOpsMetricsForRange,
  normalizePeriod,
} = require('../../services/businessMetrics.service');

const redis = require('../../db/redis');
const { getPublicBaseUrl } = require('../../utils/requestBaseUrl');
const signImageField = (req, url) => signStoredImageUrl(url || '', getPublicBaseUrl(req));
const storeImageField = (url) => (url ? normalizeStoredImageUrl(url) : null);

const invalidateCatalogCache = async () => {
  await redis.deleteByPattern('products:*');
};

const dashboard = asyncHandler(async (req, res) => {
  const [
    { rows: ordersCount },
    { rows: customersCount },
    { rows: deliveryCount },
    { rows: revenue },
    { rows: todayOrdersRows },
    { rows: todayRevenueRows },
    { rows: activeRidersRows },
  ] = await Promise.all([
    query('SELECT COUNT(*)::int AS total FROM orders'),
    query("SELECT COUNT(*)::int AS total FROM users WHERE role = 'customer'"),
    query(
      `SELECT COUNT(*)::int AS total
       FROM delivery_partners dp
       JOIN users u ON u.id = dp.user_id
       WHERE u.role = 'delivery'`
    ),
    query("SELECT COALESCE(SUM(total_amount),0)::numeric(10,2) AS total FROM orders WHERE status = 'DELIVERED'"),
    query(
      `SELECT COUNT(*)::int AS total
       FROM orders
       WHERE created_at >= CURRENT_DATE`
    ),
    query(
      `SELECT COALESCE(SUM(total_amount),0)::numeric(10,2) AS total
       FROM orders
       WHERE status = 'DELIVERED' AND created_at >= CURRENT_DATE`
    ),
    query(
      `SELECT COUNT(*)::int AS total
       FROM delivery_partners dp
       JOIN users u ON u.id = dp.user_id
       WHERE dp.is_online = true
         AND u.role = 'delivery'`
    ),
  ]);

  const { rows: liveOrders } = await query(
    "SELECT COUNT(*)::int AS total FROM orders WHERE status NOT IN ('DELIVERED','CANCELLED')"
  );

  const { rows: dispatchQueueRows } = await query(
    `SELECT COUNT(*)::int AS total
     FROM orders o
     LEFT JOIN order_assignments oa
       ON oa.order_id = o.id AND oa.status IN ('ASSIGNED', 'ACCEPTED', 'PICKED')
     WHERE o.status = 'PACKED'
       AND oa.id IS NULL`
  );

  const { rows: packAgeWarningRows } = await query(
    `SELECT COUNT(*)::int AS total
     FROM orders o
     LEFT JOIN order_assignments oa
       ON oa.order_id = o.id AND oa.status IN ('ASSIGNED', 'ACCEPTED', 'PICKED')
     WHERE o.status = 'PACKED'
       AND oa.id IS NULL
       AND o.packed_at IS NOT NULL
       AND o.packed_at <= NOW() - ($1::text || ' minutes')::interval`,
    [String(PACK_AGE.warningMinutes)]
  );

  const { rows: packAgeCriticalRows } = await query(
    `SELECT COUNT(*)::int AS total
     FROM orders o
     LEFT JOIN order_assignments oa
       ON oa.order_id = o.id AND oa.status IN ('ASSIGNED', 'ACCEPTED', 'PICKED')
     WHERE o.status = 'PACKED'
       AND oa.id IS NULL
       AND o.packed_at IS NOT NULL
       AND o.packed_at <= NOW() - ($1::text || ' minutes')::interval`,
    [String(PACK_AGE.criticalMinutes)]
  );

  const { rows: openAssignmentTasks } = await query(
    `SELECT COUNT(*)::int AS total
     FROM admin_tasks
     WHERE status = 'open' AND task_type = $1`,
    [ADMIN_TASK_TYPES.ASSIGNMENT_FAILED]
  );

  return ok(
    res,
    {
      stats: {
        totalOrders: ordersCount[0].total,
        liveOrders: liveOrders[0].total,
        totalCustomers: customersCount[0].total,
        totalDeliveryPartners: deliveryCount[0].total,
        deliveredRevenue: revenue[0].total,
        todayOrders: todayOrdersRows[0].total,
        todayRevenue: todayRevenueRows[0].total,
        activeRiders: activeRidersRows[0].total,
        dispatchQueueCount: dispatchQueueRows[0].total,
        packAgeWarningCount: packAgeWarningRows[0].total,
        packAgeCriticalCount: packAgeCriticalRows[0].total,
        openAssignmentFailureTasks: openAssignmentTasks[0].total,
      },
    },
    'Dashboard'
  );
});

const mapUserRole = (role) => {
  if (role === 'delivery') return 'delivery_partner';
  return role || 'customer';
};

const mapUserRow = (u) => {
  const role = mapUserRole(u.role);
  const rider =
    role === 'delivery_partner' && u.partner_id
      ? {
          id: String(u.partner_id),
          total_deliveries: Number(u.total_deliveries || 0),
          approved: u.approved !== false,
          online: Boolean(u.is_online),
          vehicle: u.vehicle_type || '',
        }
      : null;

  return {
    id: String(u.id),
    uid: String(u.id),
    name: u.name || u.phone || 'Customer',
    phone: u.phone || '',
    email: u.email || null,
    address: addressToText(u.last_address) || '',
    role,
    is_active: u.is_active !== false,
    order_count: Number(u.order_count || 0),
    lifetime_value: Number(u.lifetime_value || 0),
    created_at: u.created_at ? new Date(u.created_at).toISOString() : null,
    ...(rider ? { rider } : {}),
  };
};

const customers = asyncHandler(async (req, res) => {
  let rows;
  try {
    ({ rows } = await query(
      `SELECT u.id, u.phone, u.name, u.role, u.created_at,
              COALESCE(u.is_active, true) AS is_active,
              (SELECT o.address FROM orders o WHERE o.customer_id = u.id ORDER BY o.created_at DESC LIMIT 1) AS last_address,
              (SELECT COUNT(*)::int FROM orders o WHERE o.customer_id = u.id) AS order_count,
              (SELECT COALESCE(SUM(o.total_amount),0)::numeric(10,2)
               FROM orders o
               WHERE o.customer_id = u.id AND o.status = 'DELIVERED') AS lifetime_value,
              dp.id AS partner_id,
              dp.approved,
              dp.is_online,
              dp.vehicle_type,
              (SELECT COUNT(*)::int
               FROM order_assignments oa
               JOIN orders o ON o.id = oa.order_id
               WHERE oa.delivery_partner_id = dp.id AND o.status = 'DELIVERED') AS total_deliveries
       FROM users u
       LEFT JOIN delivery_partners dp ON dp.user_id = u.id
       WHERE u.role IN ('customer', 'delivery', 'admin')
       ORDER BY u.created_at DESC`
    ));
  } catch (err) {
    if (err?.code !== '42703') throw err;
    ({ rows } = await query(
      `SELECT u.id, u.phone, u.name, u.role, u.created_at,
              true AS is_active,
              (SELECT o.address FROM orders o WHERE o.customer_id = u.id ORDER BY o.created_at DESC LIMIT 1) AS last_address,
              (SELECT COUNT(*)::int FROM orders o WHERE o.customer_id = u.id) AS order_count,
              (SELECT COALESCE(SUM(o.total_amount),0)::numeric(10,2)
               FROM orders o
               WHERE o.customer_id = u.id AND o.status = 'DELIVERED') AS lifetime_value,
              dp.id AS partner_id,
              dp.approved,
              dp.is_online,
              dp.vehicle_type,
              0::int AS total_deliveries
       FROM users u
       LEFT JOIN delivery_partners dp ON dp.user_id = u.id
       WHERE u.role IN ('customer', 'delivery', 'admin')
       ORDER BY u.created_at DESC`
    ));
  }

  const out = rows.map(mapUserRow);
  return ok(res, out, 'Customers');
});

const getUserDetail = asyncHandler(async (req, res) => {
  const userId = Number(req.validated.params.id);

  let userRows;
  try {
    ({ rows: userRows } = await query(
      `SELECT u.id, u.phone, u.name, u.role, u.created_at,
              COALESCE(u.is_active, true) AS is_active
       FROM users u
       WHERE u.id = $1`,
      [userId]
    ));
  } catch (err) {
    if (err?.code !== '42703') throw err;
    ({ rows: userRows } = await query(
      `SELECT u.id, u.phone, u.name, u.role, u.created_at, true AS is_active
       FROM users u
       WHERE u.id = $1`,
      [userId]
    ));
  }

  const userRow = userRows[0];
  if (!userRow) {
    return fail(res, 404, 'User not found');
  }

  const { rows: orderRows } = await query(
    `SELECT o.id, o.total_amount, o.status, o.created_at
     FROM orders o
     WHERE o.customer_id = $1
     ORDER BY o.created_at DESC
     LIMIT 50`,
    [userId]
  );

  const { rows: addressRows } = await query(
    `SELECT id, address_line1, address_line2, city, state, pincode,
            landmark, address_type, latitude, longitude, is_default, label
     FROM addresses
     WHERE user_id = $1
     ORDER BY is_default DESC, created_at DESC`,
    [userId]
  ).catch((err) => {
    if (err?.code === '42P01') return { rows: [] };
    throw err;
  });

  let riderInfo = null;
  const { rows: partnerRows } = await query(
    `SELECT dp.id, dp.approved, dp.is_online, dp.vehicle_type, dp.vehicle_number,
            dp.licence_number, dp.earnings,
            u.created_at,
            (SELECT COUNT(*)::int
             FROM order_assignments oa
             JOIN orders o ON o.id = oa.order_id
             WHERE oa.delivery_partner_id = dp.id AND o.status = 'DELIVERED') AS total_deliveries
     FROM delivery_partners dp
     JOIN users u ON u.id = dp.user_id
     WHERE dp.user_id = $1`,
    [userId]
  ).catch((err) => {
    if (err?.code === '42703' || err?.code === '42P01') return { rows: [] };
    throw err;
  });

  if (partnerRows[0] && userRow.role === 'delivery') {
    const p = partnerRows[0];
    riderInfo = {
      id: String(p.id),
      approved: Boolean(p.approved),
      online: Boolean(p.is_online),
      vehicle: p.vehicle_type || '',
      vehicle_number: p.vehicle_number || '',
      licence_number: p.licence_number || '',
      earnings: Number(p.earnings || 0),
      total_deliveries: Number(p.total_deliveries || 0),
      joined_at: p.created_at ? new Date(p.created_at).toISOString() : null,
    };
  }

  const totalOrders = orderRows.length;
  const deliveredOrders = orderRows.filter((o) => o.status === 'DELIVERED').length;
  const cancelledOrders = orderRows.filter((o) => o.status === 'CANCELLED').length;
  const totalSpent = orderRows
    .filter((o) => o.status === 'DELIVERED')
    .reduce((sum, o) => sum + Number(o.total_amount || 0), 0);

  const orders = orderRows.map((o) => ({
    id: String(o.id),
    total_price: Number(o.total_amount || 0),
    status: String(o.status || '').toLowerCase(),
    created_at: o.created_at ? new Date(o.created_at).toISOString() : null,
  }));

  const addresses = (addressRows || []).map((a) => ({
    id: String(a.id),
    address_line1: a.address_line1 || '',
    address_line2: a.address_line2 || '',
    city: a.city || '',
    state: a.state || '',
    pincode: a.pincode || '',
    landmark: a.landmark || '',
    address_type: a.address_type || 'HOME',
    is_default: Boolean(a.is_default),
    label: a.label || 'home',
  }));

  return ok(
    res,
    {
      user: {
        id: String(userRow.id),
        name: userRow.name || userRow.phone || 'Customer',
        phone: userRow.phone || '',
        email: null,
        role: mapUserRole(userRow.role),
        is_active: userRow.is_active !== false,
        created_at: userRow.created_at ? new Date(userRow.created_at).toISOString() : null,
        profile_image: null,
      },
      stats: {
        total_orders: totalOrders,
        delivered_orders: deliveredOrders,
        cancelled_orders: cancelledOrders,
        total_spent: totalSpent,
        average_order_value: deliveredOrders > 0 ? totalSpent / deliveredOrders : 0,
      },
      orders,
      addresses,
      rider_info: riderInfo,
    },
    'User detail'
  );
});

const toggleUserStatus = asyncHandler(async (req, res) => {
  const userId = Number(req.validated.params.id);
  const isActive = Boolean(req.validated.body.is_active);

  let previousIsActive;
  try {
    const { rows: prevRows } = await query(
      'SELECT is_active FROM users WHERE id = $1',
      [userId]
    );
    if (!prevRows[0]) {
      return fail(res, 404, 'User not found');
    }
    previousIsActive = prevRows[0].is_active !== false;
  } catch (err) {
    if (err?.code !== '42703') throw err;
    return fail(res, 501, 'User status toggle requires users.is_active column');
  }

  let rows;
  try {
    ({ rows } = await query(
      'UPDATE users SET is_active = $1 WHERE id = $2 RETURNING id, phone, name, role, is_active, created_at',
      [isActive, userId]
    ));
  } catch (err) {
    if (err?.code !== '42703') throw err;
    return fail(res, 501, 'User status toggle requires users.is_active column');
  }

  if (!rows[0]) {
    return fail(res, 404, 'User not found');
  }

  logger.info('admin_action', {
    adminId: req.user.id,
    action: 'toggle_user_status',
    targetId: userId,
    before: previousIsActive,
    after: isActive,
    timestamp: new Date().toISOString(),
  });

  const u = rows[0];
  return ok(
    res,
    {
      user: {
        id: String(u.id),
        name: u.name || u.phone || 'Customer',
        phone: u.phone || '',
        role: mapUserRole(u.role),
        is_active: u.is_active !== false,
        created_at: u.created_at ? new Date(u.created_at).toISOString() : null,
      },
    },
    isActive ? 'User unblocked' : 'User blocked'
  );
});

const deliveryPartners = asyncHandler(async (req, res) => {
  let rows;
  try {
    ({ rows } = await query(
      `SELECT dp.id, dp.user_id, dp.is_online, dp.current_lat, dp.current_lng, dp.vehicle_type,
              dp.approved, dp.vehicle_number, dp.licence_number, dp.bank_details, dp.earnings,
              dp.availability_status, dp.estimated_return_at, dp.estimated_return_minutes,
              dp.active_order_count,
              u.phone, u.name, u.created_at
       FROM delivery_partners dp
       JOIN users u ON u.id = dp.user_id
       WHERE u.role = 'delivery'
       ORDER BY dp.id DESC`
    ));
  } catch (err) {
    if (err?.code !== '42703') throw err;
    ({ rows } = await query(
      `SELECT dp.id, dp.user_id, dp.is_online, dp.current_lat, dp.current_lng, dp.vehicle_type,
              u.phone, u.name, u.created_at
       FROM delivery_partners dp
       JOIN users u ON u.id = dp.user_id
       WHERE u.role = 'delivery'
       ORDER BY dp.id DESC`
    ));
    rows = rows.map((r) => ({
      ...r,
      approved: true,
      vehicle_number: null,
      licence_number: null,
      bank_details: null,
      earnings: 0,
      availability_status: r.availability_status || (r.is_online ? 'available' : 'offline'),
      estimated_return_at: r.estimated_return_at ?? null,
      estimated_return_minutes: r.estimated_return_minutes ?? null,
      active_order_count: r.active_order_count ?? 0,
    }));
  }

  const out = rows.map((p) => ({
    id: String(p.id),
    user_id: String(p.user_id),
    phone: p.phone || '',
    joined_at: p.created_at ? new Date(p.created_at).toISOString() : null,
    operationalStatus: p.availability_status || (p.is_online ? 'available' : 'offline'),
    estimatedReturnMinutes:
      p.estimated_return_minutes != null ? Number(p.estimated_return_minutes) : null,
    estimatedReturnAt: p.estimated_return_at
      ? new Date(p.estimated_return_at).toISOString()
      : null,
    activeOrderCount: Number(p.active_order_count ?? 0),
    profile: {
      name: p.name || '',
      online: Boolean(p.is_online),
      approved: Boolean(p.approved),
      vehicle: p.vehicle_type || '',
      vehicleNumber: p.vehicle_number || '',
      licenceNumber: p.licence_number || '',
      bankDetails: p.bank_details || '',
      earnings: Number(p.earnings || 0),
      currentLat: p.current_lat !== null ? Number(p.current_lat) : null,
      currentLng: p.current_lng !== null ? Number(p.current_lng) : null,
      operationalStatus: p.availability_status || (p.is_online ? 'available' : 'offline'),
      estimatedReturnMinutes:
        p.estimated_return_minutes != null ? Number(p.estimated_return_minutes) : null,
      estimatedReturnAt: p.estimated_return_at
        ? new Date(p.estimated_return_at).toISOString()
        : null,
      activeOrderCount: Number(p.active_order_count ?? 0),
    },
  }));

  return ok(res, out, 'Delivery partners');
});

const toggleDeliveryPartner = asyncHandler(async (req, res) => {
  const id = Number(req.validated.params.id);
  const { rows: current } = await query(
    'SELECT id, user_id, is_online FROM delivery_partners WHERE id = $1',
    [id]
  );
  if (!current[0]) {
    return fail(res, 404, 'Delivery partner not found');
  }

  const goingOffline = current[0].is_online === true;
  if (goingOffline) {
    const activeOrderCount = await countRiderActiveOrders(id);
    if (activeOrderCount > 0) {
      return fail(
        res,
        409,
        `Cannot set rider offline with ${activeOrderCount} active ${activeOrderCount === 1 ? 'delivery' : 'deliveries'}.`,
        {
          code: 'ACTIVE_DELIVERIES_BLOCK_OFFLINE',
          activeOrderCount,
        }
      );
    }
  }

  const { rows } = await query(
    'UPDATE delivery_partners SET is_online = NOT is_online WHERE id = $1 RETURNING id, user_id, is_online',
    [id]
  );

  refreshPartnerOperationalState({
    deliveryPartnerId: id,
    io: req.app.get('io'),
    reason: rows[0]?.is_online ? 'admin_went_online' : 'admin_went_offline',
  }).catch(() => {});

  return ok(res, { deliveryPartner: rows[0] }, 'Delivery partner updated');
});

const patchDeliveryPartner = asyncHandler(async (req, res) => {
  const id = Number(req.validated.params.id);
  const patch = req.validated.body || {};

  const updated = await withTransaction(async (client) => {
    const { rows: dpRows } = await client.query(
      `SELECT dp.id, dp.user_id
       FROM delivery_partners dp
       WHERE dp.id = $1
       FOR UPDATE`,
      [id]
    );
    const dp = dpRows[0];
    if (!dp) return null;

    const hasApproved = Object.prototype.hasOwnProperty.call(patch, 'approved');
    const hasOnline = Object.prototype.hasOwnProperty.call(patch, 'online');
    const hasEarnings = Object.prototype.hasOwnProperty.call(patch, 'earnings');
    const hasVehicle = Object.prototype.hasOwnProperty.call(patch, 'vehicle');
    const hasVehicleNumber = Object.prototype.hasOwnProperty.call(patch, 'vehicleNumber');
    const hasLicenceNumber = Object.prototype.hasOwnProperty.call(patch, 'licenceNumber');
    const hasBankDetails = Object.prototype.hasOwnProperty.call(patch, 'bankDetails');
    const hasDeliveryPartnerPatch =
      hasApproved ||
      hasOnline ||
      hasEarnings ||
      hasVehicle ||
      hasVehicleNumber ||
      hasLicenceNumber ||
      hasBankDetails;

    if (hasDeliveryPartnerPatch) {
      await client.query(
        `UPDATE delivery_partners
         SET approved = CASE WHEN $1 THEN $2 ELSE approved END,
             is_online = CASE WHEN $3 THEN $4 ELSE is_online END,
             earnings = CASE WHEN $5 THEN $6 ELSE earnings END,
             vehicle_type = CASE WHEN $7 THEN $8 ELSE vehicle_type END,
             vehicle_number = CASE WHEN $9 THEN $10 ELSE vehicle_number END,
             licence_number = CASE WHEN $11 THEN $12 ELSE licence_number END,
             bank_details = CASE WHEN $13 THEN $14 ELSE bank_details END
         WHERE id = $15`,
        [
          hasApproved,
          Boolean(patch.approved),
          hasOnline,
          Boolean(patch.online),
          hasEarnings,
          Number(patch.earnings),
          hasVehicle,
          patch.vehicle || null,
          hasVehicleNumber,
          patch.vehicleNumber || null,
          hasLicenceNumber,
          patch.licenceNumber || null,
          hasBankDetails,
          patch.bankDetails || null,
          id,
        ]
      );
    }

    if (Object.prototype.hasOwnProperty.call(patch, 'name')) {
      await client.query('UPDATE users SET name = $1 WHERE id = $2', [patch.name || null, Number(dp.user_id)]);
    }

    const { rows } = await client.query(
      `SELECT dp.id, dp.is_online, dp.approved, dp.vehicle_type, dp.vehicle_number, dp.licence_number, dp.bank_details, dp.earnings,
              u.phone, u.name
       FROM delivery_partners dp
       JOIN users u ON u.id = dp.user_id
       WHERE dp.id = $1`,
      [id]
    );
    return rows[0] || null;
  });

  if (!updated) return fail(res, 404, 'Delivery partner not found');

  return ok(
    res,
    {
      id: String(updated.id),
      phone: updated.phone || '',
      profile: {
        name: updated.name || '',
        online: Boolean(updated.is_online),
        approved: Boolean(updated.approved),
        vehicle: updated.vehicle_type || '',
        vehicleNumber: updated.vehicle_number || '',
        licenceNumber: updated.licence_number || '',
        bankDetails: updated.bank_details || '',
        earnings: Number(updated.earnings || 0),
      },
    },
    'Delivery partner updated'
  );
});

const listOrdersCompat = asyncHandler(async (req, res) => {
  const limit = Number(req.validated?.query?.limit || 200);
  const offset = Number(req.validated?.query?.offset || 0);
  const fromDate = req.validated?.query?.from || null;
  const toDate = req.validated?.query?.to || null;

  const binder = createParamBinder([limit, offset]);
  const conditions = [];

  if (fromDate) {
    conditions.push(`o.created_at >= ${binder.ph(fromDate)}::date`);
  }
  if (toDate) {
    conditions.push(`o.created_at < (${binder.ph(toDate)}::date + INTERVAL '1 day')`);
  }

  const whereClause = joinWhere(conditions);
  const params = binder.params;

  const baseSelect = `
    SELECT o.id, o.customer_id, o.total_amount, o.status, o.created_at, o.address, o.packed_at,
           COALESCE(u.phone, '') AS phone,
           COALESCE(u.name, u.phone, 'Customer') AS customer_name`;

  const runQuery = async (withAssignments) => {
    if (withAssignments) {
      return query(
        `${baseSelect},
                oa.delivery_partner_id,
                ru.name AS rider_name,
                ru.phone AS rider_phone,
                (EXTRACT(EPOCH FROM o.created_at) * 1000)::bigint AS created_at_ms
         FROM orders o
         LEFT JOIN users u ON u.id = o.customer_id
         LEFT JOIN order_assignments oa ON oa.order_id = o.id
         LEFT JOIN delivery_partners dp ON dp.id = oa.delivery_partner_id
         LEFT JOIN users ru ON ru.id = dp.user_id
         ${whereClause}
         ORDER BY o.created_at DESC
         LIMIT $1 OFFSET $2`,
        params
      );
    }

    return query(
      `${baseSelect},
              NULL::bigint AS delivery_partner_id,
              NULL::text AS rider_name,
              NULL::text AS rider_phone,
              (EXTRACT(EPOCH FROM o.created_at) * 1000)::bigint AS created_at_ms
       FROM orders o
       LEFT JOIN users u ON u.id = o.customer_id
       ${whereClause}
       ORDER BY o.created_at DESC
       LIMIT $1 OFFSET $2`,
      params
    );
  };

  let rows;
  try {
    ({ rows } = await runQuery(true));
  } catch (err) {
    if (err?.code !== '42P01') throw err;
    ({ rows } = await runQuery(false));
  }

  const itemsByOrderId = {};
  if (rows.length > 0) {
    const orderIds = rows.map((row) => row.id);
    try {
      const { rows: itemRows } = await query(
        `SELECT oi.order_id, oi.product_id, oi.quantity, oi.price,
                COALESCE(p.name, 'Item') AS name
         FROM order_items oi
         LEFT JOIN products p ON p.id = oi.product_id
         WHERE oi.order_id = ANY($1::bigint[])
         ORDER BY oi.order_id, oi.id`,
        [orderIds]
      );
      for (const item of itemRows) {
        const orderId = String(item.order_id);
        if (!itemsByOrderId[orderId]) itemsByOrderId[orderId] = [];
        itemsByOrderId[orderId].push({
          id: String(item.product_id),
          name: item.name || 'Item',
          quantity: Number(item.quantity || 0),
          price: Number(item.price || 0),
        });
      }
    } catch (err) {
      if (err?.code !== '42P01') throw err;
    }
  }

  const out = rows.map((o) => {
    const hasAssignment = Boolean(o.delivery_partner_id);
    const status = o.status;
    const createdAtMs = Number(o.created_at_ms || 0);
    const customerName = o.customer_name || o.phone || 'Customer';
    const orderId = String(o.id);
    const items = itemsByOrderId[orderId] || [];

    const packAge = enrichOrderWithPackAge(o);

    return {
      id: orderId,
      customerUid: String(o.customer_id),
      phone: o.phone || '',
      customerName,
      totalAmount: Number(o.total_amount || 0),
      total_price: Number(o.total_amount || 0),
      status,
      deliveryUid: o.delivery_partner_id ? String(o.delivery_partner_id) : '',
      createdAt: createdAtMs,
      created_at: o.created_at
        ? new Date(o.created_at).toISOString()
        : new Date(createdAtMs).toISOString(),
      updatedAt: createdAtMs,
      packedAt: packAge.packedAt,
      packAgeMinutes: packAge.packAgeMinutes,
      packAgeTier: packAge.packAgeTier,
      dispatchPriority: packAge.dispatchPriority,
      user: {
        name: customerName,
        phone: o.phone || 'N/A',
      },
      items,
      address: o.address || null,
      delivery_address: o.address || null,
      assignment: o.delivery_partner_id
        ? {
            rider: {
              id: String(o.delivery_partner_id),
              user: {
                name: o.rider_name || 'Rider',
                phone: o.rider_phone || '',
              },
            },
          }
        : null,
    };
  });

  return ok(res, { orders: out }, 'Orders');
});

const assignRiderToOrder = asyncHandler(async (req, res) => {
  const orderId = Number(req.validated.params.id);
  const deliveryPartnerId = req.validated.body?.deliveryPartnerId;
  const resetAttempts = req.validated.body?.resetAttempts !== false;
  const io = req.app.get('io');

  let result;
  if (deliveryPartnerId != null && deliveryPartnerId !== '') {
    result = await manualAssignOrderToPartner({
      orderId,
      deliveryPartnerId: Number(deliveryPartnerId),
      io,
    });
  } else {
    result = await retryAssignOrderToPartner({
      orderId,
      io,
      resetAttempts,
    });
  }

  if (!result?.assigned) {
    return fail(
      res,
      400,
      result?.reason || 'Unable to assign rider',
      result || {}
    );
  }

  const { rows: assignmentRows } = await query(
    `SELECT oa.id, oa.order_id, oa.delivery_partner_id, oa.assigned_at, oa.status,
            dp.is_online, dp.current_lat, dp.current_lng,
            u.id AS user_id, u.phone AS user_phone, u.name AS user_name
     FROM order_assignments oa
     JOIN delivery_partners dp ON dp.id = oa.delivery_partner_id
     JOIN users u ON u.id = dp.user_id
     WHERE oa.order_id = $1`,
    [orderId]
  );

  return ok(
    res,
    {
      orderId,
      assignment: assignmentRows[0] || null,
      result,
    },
    'Rider assigned successfully'
  );
});

const listAdminTasksHandler = asyncHandler(async (req, res) => {
  const taskType = req.validated.query?.type || null;
  const tasks = await listOpenAdminTasks({ taskType });
  return ok(res, { tasks }, 'Admin tasks');
});

const resolveAssignmentFailureOrder = asyncHandler(async (req, res) => {
  const orderId = Number(req.validated.params.id);
  const adminUserId = Number(req.user.id);

  const resolved = await resolveAdminTaskByOrder(null, {
    orderId,
    taskType: ADMIN_TASK_TYPES.ASSIGNMENT_FAILED,
    adminUserId,
  });

  if (!resolved) {
    return fail(res, 404, 'No open assignment failure task for this order');
  }

  return ok(res, { orderId, resolved: true }, 'Assignment failure resolved');
});

const resolveFailedDeliveryOrder = asyncHandler(async (req, res) => {
  const orderId = Number(req.validated.params.id);
  const resolution = req.validated.body.resolution;
  const adminUserId = Number(req.user.id);
  const io = req.app.get('io');

  const result = await resolveFailedDelivery({
    orderId,
    adminUserId,
    resolution,
    io,
  });

  return ok(
    res,
    { order: result.order, resolution: result.resolution },
    'Failed delivery resolved'
  );
});

const patchOrderCompat = asyncHandler(async (req, res) => {
  const orderId = Number(req.validated.params.id);
  const { orderStatus, deliveryUserId } = req.validated.body || {};

  if (String(orderStatus || '').toUpperCase() === 'PACKED') {
    const io = req.app.get('io');
    try {
      const packResult = await packOrderWithWeightReconciliation({
        orderId,
        lineWeights: req.body?.items ?? req.body?.lineWeights ?? [],
        actor: req.user.id,
        actorRole: req.user.role,
        io,
      });
      const { rows } = await query(
        `SELECT o.id, o.customer_id, u.phone, o.total_amount, o.status,
                oa.delivery_partner_id,
                (EXTRACT(EPOCH FROM o.created_at) * 1000)::bigint AS created_at_ms
         FROM orders o
         JOIN users u ON u.id = o.customer_id
         LEFT JOIN order_assignments oa ON oa.order_id = o.id
         WHERE o.id = $1`,
        [orderId]
      );
      return ok(
        res,
        { ...(rows[0] || { orderId }), packResult },
        'Order packed'
      );
    } catch (error) {
      const statusCode = error.statusCode || 400;
      return fail(res, statusCode, error.message || 'Packing failed');
    }
  }

  const result = await withTransaction(async (client) => {
    const db = client;
    const { rows: oRows } = await client.query(
      `SELECT id, customer_id, status, failed_delivery_resolution, weight_reconciliation_status
       FROM orders
       WHERE id = $1
       FOR UPDATE`,
      [orderId]
    );
    const order = oRows[0];
    if (!order) return null;

    if (orderStatus === 'ASSIGNED' && isOrderBlockedFromAssignment(order)) {
      const err = new Error('Order has pending failed delivery — resolve before reassigning');
      err.statusCode = 409;
      throw err;
    }

    if (orderStatus === 'CANCELLED') {
      const { rows: partnerRows } = await client.query(
        `SELECT dp.user_id
         FROM order_assignments oa
         JOIN delivery_partners dp ON dp.id = oa.delivery_partner_id
         WHERE oa.order_id = $1`,
        [orderId]
      );
      const cancelledPartnerUserId = partnerRows[0]?.user_id ?? null;

      const { rows } = await db.query('SELECT status FROM orders WHERE id = $1', [orderId]);
      const currentStatus = rows[0]?.status;
      const newStatus = 'CANCELLED';
      if (!canTransition(currentStatus, newStatus)) {
        const err = new Error(`Cannot change order from ${currentStatus} to ${newStatus}`);
        err.statusCode = 400;
        throw err;
      }
      if (shouldRestoreStockOnCancel(currentStatus)) {
        await restoreStockForOrder(client, orderId);
      }
      await client.query('UPDATE orders SET status = $1 WHERE id = $2', ['CANCELLED', orderId]);
      await client.query('UPDATE order_assignments SET status = $1 WHERE order_id = $2', ['CANCELLED', orderId]);

      const { rows: updatedRows } = await client.query(
        `SELECT o.id, o.customer_id, u.phone, o.total_amount, o.status,
                oa.delivery_partner_id,
                (EXTRACT(EPOCH FROM o.created_at) * 1000)::bigint AS created_at_ms
         FROM orders o
         JOIN users u ON u.id = o.customer_id
         LEFT JOIN order_assignments oa ON oa.order_id = o.id
         WHERE o.id = $1`,
        [orderId]
      );

      return {
        ...(updatedRows[0] || {}),
        cancelledPartnerUserId,
        previousStatus: currentStatus,
      };
    } else if (orderStatus === 'ASSIGNED') {
      const partnerId = Number(deliveryUserId);
      if (!partnerId) {
        const err = new Error('deliveryUserId is required for ASSIGNED');
        err.statusCode = 400;
        throw err;
      }

      const { rows: dpRows } = await client.query(
        'SELECT id, approved FROM delivery_partners WHERE id = $1',
        [partnerId]
      );
      if (!dpRows[0]) {
        const err = new Error('Delivery partner not found');
        err.statusCode = 404;
        throw err;
      }

      await client.query(
        `INSERT INTO order_assignments (order_id, delivery_partner_id, status)
         VALUES ($1,$2,'ASSIGNED')
         ON CONFLICT (order_id) DO UPDATE SET delivery_partner_id = EXCLUDED.delivery_partner_id, status = 'ASSIGNED', assigned_at = NOW()`,
        [orderId, partnerId]
      );

      if (order.status === 'PLACED') {
        const { rows } = await db.query('SELECT status FROM orders WHERE id = $1', [orderId]);
        const currentStatus = rows[0]?.status;
        const newStatus = 'CONFIRMED';
        if (!canTransition(currentStatus, newStatus)) {
          const err = new Error(`Cannot change order from ${currentStatus} to ${newStatus}`);
          err.statusCode = 400;
          throw err;
        }
        await client.query('UPDATE orders SET status = $1 WHERE id = $2', ['CONFIRMED', orderId]);
      }
    } else if (orderStatus) {
      const { rows } = await db.query('SELECT status FROM orders WHERE id = $1', [orderId]);
      const currentStatus = rows[0]?.status;
      const newStatus = orderStatus;
      if (!canTransition(currentStatus, newStatus)) {
        const err = new Error(`Cannot change order from ${currentStatus} to ${newStatus}`);
        err.statusCode = 400;
        throw err;
      }
      if (String(newStatus).toUpperCase() === 'OUT_FOR_DELIVERY') {
        try {
          assertWeightReconciliationForDispatch(order.weight_reconciliation_status);
        } catch (reconErr) {
          reconErr.statusCode = 400;
          throw reconErr;
        }
      }
      await client.query('UPDATE orders SET status = $1 WHERE id = $2', [orderStatus, orderId]);
    }

    const { rows } = await client.query(
      `SELECT o.id, o.customer_id, u.phone, o.total_amount, o.status,
              oa.delivery_partner_id,
              (EXTRACT(EPOCH FROM o.created_at) * 1000)::bigint AS created_at_ms
       FROM orders o
       JOIN users u ON u.id = o.customer_id
       LEFT JOIN order_assignments oa ON oa.order_id = o.id
       WHERE o.id = $1`,
      [orderId]
    );

    // Emit to customer and admin rooms
    const io = req.app.get('io');
    if (io && rows[0]) {
      io.to(`customer_${rows[0].customer_id}`).emit('order:status_updated', {
        orderId: orderId,
        status: orderStatus || rows[0].status,
        updatedAt: new Date().toISOString()
      });

      io.to('admin_room').emit('order:updated', {
        orderId: orderId,
        status: orderStatus || rows[0].status,
        updatedAt: new Date().toISOString()
      });
    }

    return rows[0] || null;
  });

  if (!result) return fail(res, 404, 'Order not found');

  if (orderStatus === 'CANCELLED') {
    logger.info('admin_action', {
      adminId: req.user.id,
      action: 'force_cancel',
      targetId: orderId,
      before: result.previousStatus,
      after: 'CANCELLED',
      timestamp: new Date().toISOString(),
    });
  }

  const io = req.app.get('io');
  if (io) {
    if (orderStatus === 'CANCELLED') {
      if (result.cancelledPartnerUserId) {
        emitAssignmentCancelled(
          io,
          orderId,
          result.cancelledPartnerUserId,
          'order_cancelled'
        );
      }
      if (result.customer_id) {
        io.to(`customer_${result.customer_id}`).emit('order:status_updated', {
          orderId,
          status: 'CANCELLED',
          updatedAt: new Date().toISOString(),
        });
        io.to('admin_room').emit('order:updated', {
          orderId,
          status: 'CANCELLED',
          updatedAt: new Date().toISOString(),
        });
      }
    }
    if (orderStatus === 'ASSIGNED' && result.delivery_partner_id) {
      const [{ rows: orderRows }, { rows: partnerRows }] = await Promise.all([
        query(
          `SELECT id, customer_id, total_amount, address, payment_mode
           FROM orders WHERE id = $1`,
          [orderId]
        ),
        query(
          `SELECT dp.id, dp.user_id, dp.current_lat, dp.current_lng, u.name, u.phone
           FROM delivery_partners dp
           JOIN users u ON u.id = dp.user_id
           WHERE dp.id = $1`,
          [result.delivery_partner_id]
        ),
      ]);
      if (orderRows[0] && partnerRows[0]) {
        emitAssignmentSuccess(io, orderRows[0], {
          id: partnerRows[0].id,
          userId: partnerRows[0].user_id,
          name: partnerRows[0].name,
          phone: partnerRows[0].phone,
          current_lat: partnerRows[0].current_lat,
          current_lng: partnerRows[0].current_lng,
        });
      }
    }
  }

  const ioAfterPatch = req.app.get('io');
  const finalStatus = String(result.status || '').toUpperCase();
  if (
    !result.delivery_partner_id &&
    finalStatus === 'PACKED'
  ) {
    assignOrderToPartner({ orderId, io: ioAfterPatch }).catch((err) => {
      logger?.error?.('assign_after_patch_failed', {
        orderId,
        error: err.message,
      });
    });
  }

  const hasAssignment = Boolean(result.delivery_partner_id);
  const status =
    hasAssignment && ['CONFIRMED', 'PACKED'].includes(result.status) ? 'ASSIGNED' : result.status;
  const createdAt = Number(result.created_at_ms || 0);

  return ok(
    res,
    {
      id: String(result.id),
      customerUid: String(result.customer_id),
      phone: result.phone || '',
      totalAmount: Number(result.total_amount || 0),
      status,
      deliveryUid: result.delivery_partner_id ? String(result.delivery_partner_id) : '',
      createdAt,
      updatedAt: createdAt,
    },
    'Order updated'
  );
});

const listCategoriesCompat = asyncHandler(async (req, res) => {
  let rows;
  try {
    ({ rows } = await query(
      `SELECT id, name, image_url, active, sort_order
       FROM categories
       ORDER BY sort_order ASC, id DESC`
    ));
  } catch (err) {
    if (err?.code !== '42703') throw err;
    ({ rows } = await query(
      `SELECT id, name, image_url, active
       FROM categories
       ORDER BY id DESC`
    ));
    rows = rows.map((c) => ({ ...c, sort_order: 0 }));
  }

  const out = rows.map((c) => ({
    id: String(c.id),
    name: c.name,
    imageUrl: signImageField(req, c.image_url),
    isActive: Boolean(c.active),
    sortOrder: Number(c.sort_order || 0),
  }));

  return ok(res, out, 'Categories');
});

const createCategoryCompat = asyncHandler(async (req, res) => {
  const body = req.validated.body || {};
  if (!body.name) return fail(res, 400, 'name is required');

  let rows;
  try {
    ({ rows } = await query(
      `INSERT INTO categories (name, image_url, active, sort_order)
       VALUES ($1,$2,$3,$4)
       RETURNING id, name, image_url, active, sort_order`,
      [body.name, storeImageField(body.imageUrl), body.isActive !== false, Number(body.sortOrder || 0)]
    ));
  } catch (err) {
    if (err?.code !== '42703') throw err;
    ({ rows } = await query(
      `INSERT INTO categories (name, image_url, active)
       VALUES ($1,$2,$3)
       RETURNING id, name, image_url, active`,
      [body.name, storeImageField(body.imageUrl), body.isActive !== false]
    ));
    rows = rows.map((c) => ({ ...c, sort_order: 0 }));
  }

  const c = rows[0];
  await invalidateCatalogCache();
  emitToAll('catalog:categories_changed', { id: String(c.id) });
  return ok(
    res,
    { id: String(c.id), name: c.name, imageUrl: signImageField(req, c.image_url), isActive: Boolean(c.active), sortOrder: Number(c.sort_order || 0) },
    'Category created'
  );
});

const patchCategoryCompat = asyncHandler(async (req, res) => {
  const id = Number(req.validated.params.id);
  const body = req.validated.body || {};

  const hasName      = Object.prototype.hasOwnProperty.call(body, 'name');
  const hasImageUrl  = Object.prototype.hasOwnProperty.call(body, 'imageUrl');
  const hasIsActive  = Object.prototype.hasOwnProperty.call(body, 'isActive');
  const hasSortOrder = Object.prototype.hasOwnProperty.call(body, 'sortOrder');

  if (!hasName && !hasImageUrl && !hasIsActive && !hasSortOrder) {
    return fail(res, 400, 'No fields to update');
  }

  const { rows } = await query(
    `UPDATE categories
     SET name       = CASE WHEN $1 THEN $2  ELSE name       END,
         image_url  = CASE WHEN $3 THEN $4  ELSE image_url  END,
         active     = CASE WHEN $5 THEN $6  ELSE active     END,
         sort_order = CASE WHEN $7 THEN $8  ELSE sort_order END
     WHERE id = $9
     RETURNING id, name, image_url, active, sort_order`,
    [
      hasName,      body.name,
      hasImageUrl,  storeImageField(body.imageUrl),
      hasIsActive,  Boolean(body.isActive),
      hasSortOrder, Number(body.sortOrder || 0),
      id,
    ]
  );

  if (!rows[0]) return fail(res, 404, 'Category not found');

  const c = rows[0];
  await invalidateCatalogCache();
  emitToAll('catalog:categories_changed', { id: String(c.id) });
  return ok(
    res,
    { id: String(c.id), name: c.name, imageUrl: signImageField(req, c.image_url), isActive: Boolean(c.active), sortOrder: Number(c.sort_order || 0) },
    'Category updated'
  );
});

const parseWeightVariants = (wv) => {
  if (typeof wv === 'string') {
    try {
      return JSON.parse(wv);
    } catch {
      return [500];
    }
  }
  return Array.isArray(wv) && wv.length ? wv : [500];
};

const defaultWeightGrams = (wv) => parseWeightVariants(wv)[0] || 500;

const salePriceFromRow = (p) => {
  const base = Number(p.base_price_per_kg || p.price || 0);
  const grams = defaultWeightGrams(p.weight_variants);
  return Math.round(base * (grams / 1000) * 100) / 100;
};

const discountPercentFrom = (mrp, salePrice) => {
  if (mrp == null || mrp <= salePrice + 0.01) return null;
  return Math.round((1 - salePrice / mrp) * 100);
};

const normalizeMrpInput = (value) => {
  if (value === undefined) return undefined;
  if (value === null || value === '') return null;
  const n = Number(value);
  return Number.isFinite(n) && n > 0 ? n : null;
};

const mapProductAdminOut = (req, p) => {
  const weightVariants = parseWeightVariants(p.weight_variants);
  const salePrice = salePriceFromRow({ ...p, weight_variants: weightVariants });
  const mrpRaw = p.mrp != null ? Number(p.mrp) : null;
  const mrp = mrpRaw != null && mrpRaw > salePrice + 0.01 ? mrpRaw : null;

  let cutTypes = p.cut_types;
  if (typeof cutTypes === 'string') {
    try {
      cutTypes = JSON.parse(cutTypes);
    } catch {
      cutTypes = null;
    }
  }

  let marinationOptions = p.marination_options;
  if (typeof marinationOptions === 'string') {
    try {
      marinationOptions = JSON.parse(marinationOptions);
    } catch {
      marinationOptions = null;
    }
  }

  return {
    id: String(p.id),
    name: p.name,
    categoryId: p.category_id ? String(p.category_id) : '',
    salePrice,
    price: salePrice,
    mrp,
    discountPercent: discountPercentFrom(mrp, salePrice),
    basePricePerKg: Number(p.base_price_per_kg || p.price || 0),
    weightVariants,
    cutTypes: cutTypes || null,
    marinationOptions: marinationOptions || null,
    freshnessDate: p.freshness_date || null,
    unit: p.unit || '',
    stockQty: Number(p.stock),
    imageUrl: signImageField(req, p.image_url),
    description: p.description || '',
    isActive: Boolean(p.active),
    inStock: Number(p.stock) > 0,
    tags: [],
  };
};

const listProductsCompat = asyncHandler(async (req, res) => {
  const { rows } = await query(
    `SELECT id, category_id, name, description, price, base_price_per_kg, mrp,
      weight_variants, cut_types, marination_options, freshness_date,
      image_url, stock, unit, active
      FROM products
      ORDER BY id DESC`
  );

  const out = rows.map((p) => mapProductAdminOut(req, p));

  return ok(res, out, 'Products');
});

const createProductCompat = asyncHandler(async (req, res) => {
  const body = req.validated.body || {};
  if (!body.name) return fail(res, 400, 'name is required');
  if (
    typeof body.price !== 'number' &&
    typeof body.salePrice !== 'number' &&
    typeof body.basePricePerKg !== 'number'
  ) {
    return fail(res, 400, 'salePrice or price is required');
  }

  const salePrice = Number(body.salePrice ?? body.price ?? body.basePricePerKg ?? 0);
  const mrp = normalizeMrpInput(body.mrp);
  if (mrp != null && mrp <= salePrice) {
    return fail(res, 400, 'MRP must be greater than selling price');
  }

  const categoryId = body.categoryId ? String(body.categoryId).trim() : '';
  const category_id = categoryId ? Number(categoryId) : null;

  // Parse array/JSON fields
  let weightVariants = body.weightVariants || [250, 500, 1000];
  if (typeof weightVariants === 'string') {
    try { weightVariants = JSON.parse(weightVariants); } catch (e) { weightVariants = [250, 500, 1000]; }
  }

  let cutTypes = body.cutTypes || null;
  if (typeof cutTypes === 'string') {
    try { cutTypes = JSON.parse(cutTypes); } catch (e) { cutTypes = null; }
  }

  let marinationOptions = body.marinationOptions || null;
  if (typeof marinationOptions === 'string') {
    try { marinationOptions = JSON.parse(marinationOptions); } catch (e) { marinationOptions = null; }
  }

  const defaultG = defaultWeightGrams(weightVariants);
  const basePricePerKg = salePrice / (defaultG / 1000);

  const { rows } = await query(
    `INSERT INTO products (
      category_id, name, description, price, base_price_per_kg, mrp,
      weight_variants, cut_types, marination_options, freshness_date,
      image_url, stock, unit, active
    )
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14)
     RETURNING id, category_id, name, description, price, base_price_per_kg, mrp,
               weight_variants, cut_types, marination_options, freshness_date,
               image_url, stock, unit, active`,
    [
      category_id || null,
      body.name,
      body.description || null,
      salePrice,
      basePricePerKg,
      mrp,
      Array.isArray(weightVariants) ? weightVariants : [250, 500, 1000],
      Array.isArray(cutTypes) ? cutTypes : null,
      marinationOptions ? JSON.stringify(marinationOptions) : null,
      body.freshnessDate || null,
      storeImageField(body.imageUrl),
      Number(body.stockQty || 0),
      body.unit || null,
      body.isActive !== false,
    ]
  );

  const p = rows[0];
  await invalidateCatalogCache();
  emitToAll('catalog:products_changed', { id: String(p.id) });

  return ok(res, mapProductAdminOut(req, p), 'Product created');
});

const patchProductCompat = asyncHandler(async (req, res) => {
  const id = Number(req.validated.params.id);
  const body = req.validated.body || {};

  const hasSalePrice = Object.prototype.hasOwnProperty.call(body, 'salePrice');
  const hasPrice = Object.prototype.hasOwnProperty.call(body, 'price');
  const hasBasePricePerKg = Object.prototype.hasOwnProperty.call(body, 'basePricePerKg');
  const hasMrp = Object.prototype.hasOwnProperty.call(body, 'mrp');
  const hasName = Object.prototype.hasOwnProperty.call(body, 'name');
  const hasDescription = Object.prototype.hasOwnProperty.call(body, 'description');
  const hasImageUrl = Object.prototype.hasOwnProperty.call(body, 'imageUrl');
  const hasUnit = Object.prototype.hasOwnProperty.call(body, 'unit');
  const hasStockQty = Object.prototype.hasOwnProperty.call(body, 'stockQty');
  const hasIsActive = Object.prototype.hasOwnProperty.call(body, 'isActive');
  const hasCategoryId = Object.prototype.hasOwnProperty.call(body, 'categoryId');
  const hasWeightVariants = Object.prototype.hasOwnProperty.call(body, 'weightVariants');
  const hasCutTypes = Object.prototype.hasOwnProperty.call(body, 'cutTypes');
  const hasMarinationOptions = Object.prototype.hasOwnProperty.call(body, 'marinationOptions');
  const hasFreshnessDate = Object.prototype.hasOwnProperty.call(body, 'freshnessDate');

  if (
    !hasName && !hasDescription && !hasImageUrl && !hasPrice && !hasSalePrice &&
    !hasBasePricePerKg && !hasMrp && !hasUnit && !hasStockQty && !hasIsActive &&
    !hasCategoryId && !hasWeightVariants && !hasCutTypes && !hasMarinationOptions &&
    !hasFreshnessDate
  ) {
    return fail(res, 400, 'No fields to update');
  }

  const { rows: existingRows } = await query(
    `SELECT price, base_price_per_kg, mrp, weight_variants FROM products WHERE id = $1`,
    [id]
  );
  if (!existingRows[0]) return fail(res, 404, 'Product not found');
  const existing = existingRows[0];

  let variants = hasWeightVariants ? body.weightVariants : existing.weight_variants;
  if (hasWeightVariants && typeof variants === 'string') {
    try {
      variants = JSON.parse(variants);
    } catch {
      variants = [500];
    }
  }
  variants = parseWeightVariants(variants);

  const nextSalePrice = (hasSalePrice || hasPrice)
    ? Number(body.salePrice ?? body.price)
    : salePriceFromRow({ ...existing, weight_variants: variants });
  const nextBasePricePerKg = (hasSalePrice || hasPrice)
    ? nextSalePrice / (defaultWeightGrams(variants) / 1000)
    : Number(existing.base_price_per_kg || existing.price || 0);
  const nextMrp = hasMrp ? normalizeMrpInput(body.mrp) : (existing.mrp != null ? Number(existing.mrp) : null);

  if (nextMrp != null && nextMrp <= nextSalePrice) {
    return fail(res, 400, 'MRP must be greater than selling price');
  }

  let cuts = body.cutTypes;
  if (hasCutTypes && typeof cuts === 'string') {
    try {
      cuts = JSON.parse(cuts);
    } catch {
      cuts = null;
    }
  }

  let marinade = body.marinationOptions;
  if (hasMarinationOptions && typeof marinade === 'string') {
    try {
      marinade = JSON.parse(marinade);
    } catch {
      marinade = null;
    }
  }

  const categoryIdVal = hasCategoryId
    ? (() => {
        const raw = body.categoryId === null || body.categoryId === undefined
          ? ''
          : String(body.categoryId).trim();
        return raw ? Number(raw) : null;
      })()
    : null;

  const { rows } = await query(
    `UPDATE products
     SET name               = CASE WHEN $1  THEN $2  ELSE name               END,
         description        = CASE WHEN $3  THEN $4  ELSE description        END,
         image_url          = CASE WHEN $5  THEN $6  ELSE image_url          END,
         price              = CASE WHEN $7  THEN $8  ELSE price              END,
         base_price_per_kg  = CASE WHEN $7  THEN $9  ELSE base_price_per_kg  END,
         mrp                = CASE WHEN $10 THEN $11 ELSE mrp                END,
         unit               = CASE WHEN $12 THEN $13 ELSE unit               END,
         stock              = CASE WHEN $14 THEN $15 ELSE stock              END,
         active             = CASE WHEN $16 THEN $17 ELSE active             END,
         category_id        = CASE WHEN $18 THEN $19 ELSE category_id        END,
         weight_variants    = CASE WHEN $20 THEN $21 ELSE weight_variants    END,
         cut_types          = CASE WHEN $22 THEN $23 ELSE cut_types          END,
         marination_options = CASE WHEN $24 THEN $25::jsonb ELSE marination_options END,
         freshness_date     = CASE WHEN $26 THEN $27 ELSE freshness_date     END
     WHERE id = $28
     RETURNING id, category_id, name, description, price, base_price_per_kg, mrp,
               weight_variants, cut_types, marination_options, freshness_date,
               image_url, stock, unit, active`,
    [
      hasName, body.name,
      hasDescription, body.description || null,
      hasImageUrl, storeImageField(body.imageUrl),
      (hasSalePrice || hasPrice), nextSalePrice, nextBasePricePerKg,
      hasMrp, nextMrp,
      hasUnit, body.unit || null,
      hasStockQty, hasStockQty ? Number(body.stockQty) : null,
      hasIsActive, hasIsActive ? Boolean(body.isActive) : null,
      hasCategoryId, categoryIdVal,
      hasWeightVariants, variants,
      hasCutTypes, hasCutTypes ? (Array.isArray(cuts) ? cuts : null) : null,
      hasMarinationOptions, hasMarinationOptions ? (marinade ? JSON.stringify(marinade) : null) : null,
      hasFreshnessDate, body.freshnessDate || null,
      id,
    ]
  );
  if (!rows[0]) return fail(res, 404, 'Product not found');

  const p = rows[0];
  await invalidateCatalogCache();
  emitToAll('catalog:products_changed', { id: String(p.id) });

  return ok(res, mapProductAdminOut(req, p), 'Product updated');
});

const deleteProductCompat = asyncHandler(async (req, res) => {
  const id = Number(req.validated.params.id);
  const { rows } = await query(
    `UPDATE products
     SET active = FALSE
     WHERE id = $1
     RETURNING id, name, active`,
    [id]
  );
  if (!rows[0]) return fail(res, 404, 'Product not found');

  await invalidateCatalogCache();
  emitToAll('catalog:products_changed', { id: String(rows[0].id) });
  return ok(
    res,
    { id: String(rows[0].id), name: rows[0].name, isActive: Boolean(rows[0].active) },
    'Product deleted'
  );
});

const mergeBody = (req) => ({ ...(req.body || {}), ...(req.validated?.body || {}) });
const mergeParams = (req) => ({ ...(req.params || {}), ...(req.validated?.params || {}) });

const PRODUCT_UPDATE_COLUMNS = {
  name: 'name',
  description: 'description',
  price: 'price',
  category_id: 'category_id',
  categoryId: 'category_id',
  image_url: 'image_url',
  imageUrl: 'image_url',
  stock: 'stock',
  stockQty: 'stock',
  unit: 'unit',
  is_active: 'active',
  isActive: 'active',
  weight_variants: 'weight_variants',
  weightVariants: 'weight_variants',
};

// ─── PRODUCTS ─────────────────────────────────
const createProduct = asyncHandler(async (req, res) => {
  const body = mergeBody(req);
  const {
    name,
    description,
    price,
    category_id: categoryIdSnake,
    categoryId,
    image_url: imageUrlSnake,
    imageUrl,
    stock,
    stockQty,
    unit,
    weight_variants: weightVariantsSnake,
    weightVariants,
  } = body;

  if (!name) return fail(res, 400, 'name is required');
  if (price === undefined || price === null) return fail(res, 400, 'price is required');

  const category_id = categoryIdSnake ?? (categoryId ? Number(categoryId) : null);
  const image_url = storeImageField(imageUrlSnake ?? imageUrl ?? null);
  const stockVal = stock ?? stockQty ?? 0;
  let variants = weightVariantsSnake ?? weightVariants;
  if (typeof variants === 'string') {
    try {
      variants = JSON.parse(variants);
    } catch {
      variants = [250, 500, 1000];
    }
  }

  const { rows } = await query(
    `INSERT INTO products
     (name, description, price, category_id, image_url, stock, unit, weight_variants, active)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)
     RETURNING *`,
    [
      name,
      description ?? null,
      Number(price),
      category_id || null,
      image_url,
      Number(stockVal),
      unit ?? null,
      Array.isArray(variants) ? variants : [250, 500, 1000],
      body.is_active !== undefined ? Boolean(body.is_active) : body.isActive !== false,
    ]
  );

  await invalidateCatalogCache();
  emitToAll('catalog:products_changed', { id: String(rows[0].id) });
  return ok(res, rows[0], 'Product created');
});

const updateProduct = asyncHandler(async (req, res) => {
  const { id } = mergeParams(req);
  const updates = mergeBody(req);
  const { sets, params } = buildUpdateSet(PRODUCT_UPDATE_COLUMNS, updates);

  if (!sets.length) return fail(res, 400, 'No valid fields');

  params.push(Number(id));
  const { rows } = await query(
    `UPDATE products
     SET ${sets.join(', ')}, updated_at = NOW()
     WHERE id = $${params.length}
     RETURNING *`,
    params
  );

  if (!rows[0]) return fail(res, 404, 'Product not found');

  await invalidateCatalogCache();
  emitToAll('catalog:products_changed', { id: String(rows[0].id) });
  return ok(res, rows[0], 'Product updated');
});

const deleteProduct = asyncHandler(async (req, res) => {
  const { id } = mergeParams(req);
  const { rowCount } = await query('UPDATE products SET active = FALSE WHERE id = $1', [Number(id)]);
  if (!rowCount) return fail(res, 404, 'Product not found');

  await invalidateCatalogCache();
  emitToAll('catalog:products_changed', { id: String(id) });
  return ok(res, null, 'Product deactivated');
});

const updateStock = asyncHandler(async (req, res) => {
  const { id } = mergeParams(req);
  const body = mergeBody(req);
  const stock = body.stock ?? body.stockQty;
  if (stock === undefined || stock === null) {
    return fail(res, 400, 'stock is required');
  }

  const { rows } = await query(
    'UPDATE products SET stock = $1, updated_at = NOW() WHERE id = $2 RETURNING *',
    [Number(stock), Number(id)]
  );
  if (!rows[0]) return fail(res, 404, 'Product not found');

  await invalidateCatalogCache();
  emitToAll('catalog:products_changed', { id: String(rows[0].id) });
  return ok(res, rows[0], 'Stock updated');
});

// ─── CATEGORIES ───────────────────────────────
const createCategory = asyncHandler(async (req, res) => {
  const body = mergeBody(req);
  const {
    name,
    description,
    image_url: imageUrlSnake,
    imageUrl,
    color_hex: colorHexSnake,
    colorHex,
    isActive,
    is_active,
    sortOrder,
    sort_order,
  } = body;

  if (!name) return fail(res, 400, 'name is required');

  const image_url = storeImageField(imageUrlSnake ?? imageUrl ?? null);
  const color_hex = colorHexSnake ?? colorHex ?? null;
  const active = is_active !== undefined ? Boolean(is_active) : isActive !== false;

  let rows;
  try {
    ({ rows } = await query(
      `INSERT INTO categories (name, description, image_url, color_hex, active, sort_order)
       VALUES ($1,$2,$3,$4,$5,$6)
       RETURNING *`,
      [name, description ?? null, image_url, color_hex, active, Number(sortOrder ?? sort_order ?? 0)]
    ));
  } catch (err) {
    if (err?.code !== '42703') throw err;
    ({ rows } = await query(
      `INSERT INTO categories (name, image_url, active, sort_order)
       VALUES ($1,$2,$3,$4)
       RETURNING *`,
      [name, image_url, active, Number(sortOrder ?? sort_order ?? 0)]
    ));
  }

  await invalidateCatalogCache();
  emitToAll('catalog:categories_changed', { id: String(rows[0].id) });
  return ok(res, rows[0], 'Category created');
});

const updateCategory = asyncHandler(async (req, res) => {
  const { id } = mergeParams(req);
  const body = mergeBody(req);
  const name = body.name ?? null;
  const description = body.description ?? null;
  const image_url = storeImageField(body.image_url ?? body.imageUrl ?? null);
  const color_hex = body.color_hex ?? body.colorHex ?? null;

  let rows;
  try {
    ({ rows } = await query(
      `UPDATE categories
       SET name = COALESCE($1, name),
           description = COALESCE($2, description),
           image_url = COALESCE($3, image_url),
           color_hex = COALESCE($4, color_hex)
       WHERE id = $5
       RETURNING *`,
      [name, description, image_url, color_hex, Number(id)]
    ));
  } catch (err) {
    if (err?.code !== '42703') throw err;
    ({ rows } = await query(
      `UPDATE categories
       SET name = COALESCE($1, name),
           image_url = COALESCE($2, image_url)
       WHERE id = $3
       RETURNING *`,
      [name, image_url, Number(id)]
    ));
  }

  if (!rows[0]) return fail(res, 404, 'Category not found');

  await invalidateCatalogCache();
  emitToAll('catalog:categories_changed', { id: String(rows[0].id) });
  return ok(res, rows[0], 'Category updated');
});

const deleteCategory = asyncHandler(async (req, res) => {
  const { id } = mergeParams(req);
  const categoryId = Number(id);

  const { rows: countRows } = await query(
    'SELECT COUNT(*)::int AS count FROM products WHERE category_id = $1 AND active = TRUE',
    [categoryId]
  );
  if (Number(countRows[0]?.count || 0) > 0) {
    return fail(res, 400, 'Cannot delete: category has active products');
  }

  const { rowCount } = await query('DELETE FROM categories WHERE id = $1', [categoryId]);
  if (!rowCount) return fail(res, 404, 'Category not found');

  await invalidateCatalogCache();
  emitToAll('catalog:categories_changed', { id: String(categoryId) });
  return ok(res, null, 'Category deleted');
});

// ─── BANNERS ──────────────────────────────────
const listBanners = asyncHandler(async (req, res) => {
  let rows;
  try {
    ({ rows } = await query('SELECT * FROM banners ORDER BY created_at DESC'));
  } catch (err) {
    if (err?.code !== '42703') throw err;
    ({ rows } = await query('SELECT * FROM banners ORDER BY sort_order ASC, id DESC'));
  }
  return ok(res, rows, 'Banners');
});

const createBanner = asyncHandler(async (req, res) => {
  const body = mergeBody(req);
  const {
    title,
    subtitle,
    image_url: imageUrlSnake,
    imageUrl,
    link_url: linkUrlSnake,
    linkUrl,
    is_active,
    isActive,
    active,
    sort_order,
    sortOrder,
  } = body;

  const image_url = storeImageField(imageUrlSnake ?? imageUrl ?? null);
  const isActiveVal =
    is_active !== undefined
      ? Boolean(is_active)
      : isActive !== undefined
        ? Boolean(isActive)
        : active !== false;

  let rows;
  try {
    ({ rows } = await query(
      `INSERT INTO banners (title, subtitle, image_url, link_url, is_active)
       VALUES ($1,$2,$3,$4,$5)
       RETURNING *`,
      [title ?? null, subtitle ?? null, image_url, linkUrlSnake ?? linkUrl ?? null, isActiveVal]
    ));
  } catch (err) {
    if (err?.code !== '42703') throw err;
    if (!image_url) return fail(res, 400, 'image_url is required');
    ({ rows } = await query(
      `INSERT INTO banners (image_url, active, sort_order)
       VALUES ($1,$2,$3)
       RETURNING *`,
      [image_url, isActiveVal, Number(sortOrder ?? sort_order ?? 0)]
    ));
  }

  return ok(res, rows[0], 'Banner created');
});

const updateBanner = asyncHandler(async (req, res) => {
  const { id } = mergeParams(req);
  const body = mergeBody(req);
  const { title, subtitle, image_url, imageUrl, link_url, linkUrl, is_active, isActive, active } = body;
  const imageUrlVal = storeImageField(image_url ?? imageUrl ?? null);
  const isActiveVal =
    is_active !== undefined
      ? is_active
      : isActive !== undefined
        ? isActive
        : active;

  let rows;
  try {
    ({ rows } = await query(
      `UPDATE banners
       SET title = COALESCE($1, title),
           subtitle = COALESCE($2, subtitle),
           image_url = COALESCE($3, image_url),
           link_url = COALESCE($4, link_url),
           is_active = COALESCE($5, is_active)
       WHERE id = $6
       RETURNING *`,
      [title ?? null, subtitle ?? null, imageUrlVal, link_url ?? linkUrl ?? null, isActiveVal ?? null, Number(id)]
    ));
  } catch (err) {
    if (err?.code !== '42703') throw err;
    ({ rows } = await query(
      `UPDATE banners
       SET image_url = COALESCE($1, image_url),
           active = COALESCE($2, active)
       WHERE id = $3
       RETURNING *`,
      [imageUrlVal, isActiveVal ?? null, Number(id)]
    ));
  }

  if (!rows[0]) return fail(res, 404, 'Banner not found');
  return ok(res, rows[0], 'Banner updated');
});

const deleteBanner = asyncHandler(async (req, res) => {
  const { id } = mergeParams(req);
  const { rowCount } = await query('DELETE FROM banners WHERE id = $1', [Number(id)]);
  if (!rowCount) return fail(res, 404, 'Banner not found');
  return ok(res, null, 'Banner deleted');
});

// ─── SETTINGS ─────────────────────────────────
const mapOperationalRow = (row) => ({
  delivery_charge: row?.delivery_charge,
  min_order_amount: row?.min_order_amount,
  store_open: row?.store_open,
  store_acceptance_mode: row?.store_acceptance_mode ?? 'accepting',
  store_open_time: row?.store_open_time ?? null,
  store_close_time: row?.store_close_time ?? null,
  delivery_radius_km: row?.delivery_radius_km,
});

const readOperationalSettings = async () => {
  try {
    const { rows } = await query(
      `SELECT delivery_charge, min_order_amount, store_open,
              store_acceptance_mode, store_open_time, store_close_time, delivery_radius_km
       FROM app_settings
       ORDER BY updated_at DESC NULLS LAST
       LIMIT 1`
    );
    return mapOperationalRow(rows[0]);
  } catch (err) {
    if (err?.code === '42P01') return {};
    if (err?.code === '42703') {
      await repairAppSettingsSchema();
      const { rows } = await query(
        `SELECT delivery_charge, min_order_amount, store_open,
                store_acceptance_mode, store_open_time, store_close_time, delivery_radius_km
         FROM app_settings
         ORDER BY updated_at DESC NULLS LAST
         LIMIT 1`
      );
      return mapOperationalRow(rows[0]);
    }
    throw err;
  }
};

const writeOperationalSettings = async (value) => {
  const params = [
    value.delivery_charge ?? DEFAULT_STORE_SETTINGS.delivery_fee,
    value.min_order_amount ?? DEFAULT_STORE_SETTINGS.min_order_amount,
    value.store_open ?? true,
    value.store_acceptance_mode ?? 'accepting',
    value.store_open_time ?? null,
    value.store_close_time ?? null,
    value.delivery_radius_km ?? DEFAULT_STORE_SETTINGS.delivery_radius_km,
  ];

  try {
    const { rows: existing } = await query(
      `SELECT ctid FROM app_settings
       ORDER BY updated_at DESC NULLS LAST
       LIMIT 1`
    );

    if (existing[0]) {
      const { rows } = await query(
        `UPDATE app_settings
         SET delivery_charge = $1,
             min_order_amount = $2,
             store_open = $3,
             store_acceptance_mode = $4,
             store_open_time = $5,
             store_close_time = $6,
             delivery_radius_km = $7,
             updated_at = NOW()
         WHERE ctid = $8
         RETURNING delivery_charge, min_order_amount, store_open,
                   store_acceptance_mode, store_open_time, store_close_time, delivery_radius_km`,
        [...params, existing[0].ctid]
      );
      return mapOperationalRow(rows[0]);
    }

    const { rows } = await query(
      `INSERT INTO app_settings (
         delivery_charge, min_order_amount, store_open,
         store_acceptance_mode, store_open_time, store_close_time, delivery_radius_km, updated_at
       )
       VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())
       RETURNING delivery_charge, min_order_amount, store_open,
                 store_acceptance_mode, store_open_time, store_close_time, delivery_radius_km`,
      params
    );
    return mapOperationalRow(rows[0]);
  } catch (err) {
    if (err?.code === '42703') {
      await repairAppSettingsSchema();
      return writeOperationalSettings(value);
    }
    throw err;
  }
};

const getSettings = asyncHandler(async (req, res) => {
  const operational = await readOperationalSettings();

  return ok(
    res,
    {
      delivery_charge: Number(operational.delivery_charge ?? DEFAULT_STORE_SETTINGS.delivery_fee),
      min_order_amount: Number(operational.min_order_amount ?? DEFAULT_STORE_SETTINGS.min_order_amount),
      store_open: operational.store_open ?? true,
      store_acceptance_mode: operational.store_acceptance_mode ?? 'accepting',
      store_open_time: operational.store_open_time ?? null,
      store_close_time: operational.store_close_time ?? null,
      delivery_radius_km: Number(operational.delivery_radius_km ?? DEFAULT_STORE_SETTINGS.delivery_radius_km),
    },
    'Settings'
  );
});

const updateSettings = asyncHandler(async (req, res) => {
  const body = mergeBody(req);
  const {
    delivery_charge,
    min_order_amount,
    store_open,
    store_acceptance_mode,
    store_open_time,
    store_close_time,
    delivery_radius_km,
  } = body;

  const operational = await readOperationalSettings();
  const nextOperational = {
    ...operational,
    ...(store_open_time !== undefined ? { store_open_time } : {}),
    ...(store_close_time !== undefined ? { store_close_time } : {}),
    ...(delivery_charge !== undefined ? { delivery_charge } : {}),
    ...(min_order_amount !== undefined ? { min_order_amount } : {}),
    ...(delivery_radius_km !== undefined ? { delivery_radius_km } : {}),
    ...(store_open !== undefined ? { store_open } : {}),
    ...(store_acceptance_mode !== undefined ? { store_acceptance_mode } : {}),
  };
  const saved = await writeOperationalSettings(nextOperational);
  await syncOperationalToStoreSettings(saved);
  const effective = await getMergedStoreSettings({ forceRefresh: true });

  emitToAll('store:status_changed', {
    isOpen: effective.is_open,
    manualOpen: effective.manual_open,
    acceptanceMode: effective.acceptance_mode,
    closedMessage: effective.closed_message,
    capacityMessage: effective.capacity_message,
  });

  return ok(
    res,
    {
      delivery_charge: Number(saved.delivery_charge ?? DEFAULT_STORE_SETTINGS.delivery_fee),
      min_order_amount: Number(saved.min_order_amount ?? DEFAULT_STORE_SETTINGS.min_order_amount),
      store_open: saved.store_open ?? true,
      store_acceptance_mode: saved.store_acceptance_mode ?? 'accepting',
      store_open_time: saved.store_open_time ?? null,
      store_close_time: saved.store_close_time ?? null,
      delivery_radius_km: Number(saved.delivery_radius_km ?? DEFAULT_STORE_SETTINGS.delivery_radius_km),
    },
    'Settings updated'
  );
});

const listProducts = listProductsCompat;
const listCategories = listCategoriesCompat;

// Change user role function
const changeUserRole = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { role } = req.body;

  // Additional check: only admin can change roles
  if (req.user.role !== 'admin') {
    return fail(res, 403, 'Only administrators can change user roles');
  }

  // Validate role - customer, delivery partner, or admin
  if (!['customer', 'delivery_partner', 'admin'].includes(role)) {
    return fail(res, 400, 'Invalid role. Allowed: customer, delivery_partner, admin');
  }

  // Map frontend role to database role
  const dbRole = role === 'delivery_partner' ? 'delivery' : role;

  const userId = Number(id);

  const { rows: prevRows } = await query('SELECT role FROM users WHERE id = $1', [userId]);
  if (prevRows.length === 0) {
    return fail(res, 404, 'User not found');
  }
  const previousRole =
    prevRows[0].role === 'delivery' ? 'delivery_partner' : prevRows[0].role;

  // Update user role in database
  const { rows } = await query(
    'UPDATE users SET role = $1 WHERE id = $2 RETURNING id, phone, name, role',
    [dbRole, userId]
  );

  if (rows.length === 0) {
    return fail(res, 404, 'User not found');
  }

  if (dbRole === 'delivery') {
    await query(
      `INSERT INTO delivery_partners (user_id, is_online, approved)
       VALUES ($1, false, false)
       ON CONFLICT (user_id) DO NOTHING`,
      [userId]
    );
  } else {
    await query('DELETE FROM delivery_partners WHERE user_id = $1', [userId]);
  }

  // Return the updated user with frontend role format
  const updatedUser = {
    ...rows[0],
    role: rows[0].role === 'delivery' ? 'delivery_partner' : rows[0].role,
  };

  logger.info('admin_action', {
    adminId: req.user.id,
    action: 'change_role',
    targetId: userId,
    before: previousRole,
    after: role,
    timestamp: new Date().toISOString(),
  });

  return ok(res, { user: updatedUser }, 'User role updated successfully');
});

// Analytics endpoint — real operational and commerce data
const getAnalytics = asyncHandler(async (req, res) => {
  const rawPeriod = req.validated?.query?.period || req.query.period || 'week';
  const period =
    rawPeriod === 'month' ? 'month' : rawPeriod === 'today' ? 'today' : 'week';
  const normalized = normalizePeriod(period);
  const bounds = resolvePeriodBounds(normalized);
  const { start, end, previousStart, previousEnd } = bounds;

  const [
    { rows: orders },
    { rows: productRows },
    { rows: partnerRows },
    { rows: customerRows },
    { rows: ratingRows },
    { rows: productRatingRows },
    kpiDeltas,
    opsSnapshot,
  ] = await Promise.all([
    query(
      `SELECT o.id, o.total_amount, o.status, o.created_at,
              (SELECT SUM(oi.quantity) FROM order_items oi WHERE oi.order_id = o.id) as items_count
       FROM orders o
       WHERE o.created_at >= $1 AND o.created_at < $2
       ORDER BY o.created_at DESC`,
      [start.toISOString(), end.toISOString()]
    ),
    query(
      `SELECT p.id, p.name,
              COALESCE(c.name, 'Uncategorized') AS category,
              SUM(oi.quantity)::int AS quantity_sold,
              COALESCE(SUM(oi.quantity * oi.price),0)::numeric(10,2) AS revenue,
              MAX(p.stock)::int AS stock,
              COALESCE(AVG(pr.rating), 0)::numeric(3,2) AS avg_rating
       FROM order_items oi
       JOIN orders o ON o.id = oi.order_id
       JOIN products p ON p.id = oi.product_id
       LEFT JOIN categories c ON c.id = p.category_id
       LEFT JOIN product_ratings pr ON pr.product_id = p.id
       WHERE o.created_at >= $1 AND o.created_at < $2
       GROUP BY p.id, p.name, c.name
       ORDER BY revenue DESC
       LIMIT 20`,
      [start.toISOString(), end.toISOString()]
    ),
    query(
      `SELECT COALESCE(u.name, u.phone) AS name,
              COUNT(*) FILTER (WHERE o.status = 'DELIVERED')::int AS total_deliveries,
              COALESCE(AVG(rv.rider_rating), 0)::numeric(3,2) AS avg_rating,
              COUNT(*) FILTER (WHERE oa.status IN ('ACCEPTED', 'PICKED', 'DELIVERED'))::int AS accepted_count,
              COUNT(oa.id)::int AS assignment_count,
              dp.is_online
       FROM delivery_partners dp
       JOIN users u ON u.id = dp.user_id
       LEFT JOIN order_assignments oa ON oa.delivery_partner_id = dp.id
       LEFT JOIN orders o ON o.id = oa.order_id AND o.created_at >= $1 AND o.created_at < $2
       LEFT JOIN order_reviews rv ON rv.order_id = o.id
       GROUP BY dp.id, u.name, u.phone, dp.is_online
       HAVING COUNT(*) FILTER (WHERE o.status = 'DELIVERED') > 0
       ORDER BY total_deliveries DESC
       LIMIT 10`,
      [start.toISOString(), end.toISOString()]
    ),
    query(
      `SELECT u.id, COALESCE(u.name, u.phone) AS name,
              COUNT(o.id)::int AS orders,
              COALESCE(SUM(o.total_amount),0)::numeric(10,2) AS total_spent
       FROM users u
       LEFT JOIN orders o ON o.customer_id = u.id
         AND o.created_at >= $1 AND o.created_at < $2
       WHERE u.role = 'customer'
       GROUP BY u.id, u.name, u.phone
       HAVING COUNT(o.id) > 0
       ORDER BY total_spent DESC
       LIMIT 10`,
      [start.toISOString(), end.toISOString()]
    ),
    query(
      `SELECT
         COUNT(*)::int AS review_count,
         COALESCE(AVG(
           (COALESCE(rider_rating, 0) + COALESCE(product_quality_rating, 0) + COALESCE(delivery_speed_rating, 0))
           / NULLIF(
             (CASE WHEN rider_rating IS NOT NULL THEN 1 ELSE 0 END)
             + (CASE WHEN product_quality_rating IS NOT NULL THEN 1 ELSE 0 END)
             + (CASE WHEN delivery_speed_rating IS NOT NULL THEN 1 ELSE 0 END),
             0
           )
         ), 0)::numeric(3,2) AS avg_rating,
         COUNT(*) FILTER (WHERE rider_rating = 5 OR product_quality_rating = 5 OR delivery_speed_rating = 5)::int AS r5,
         COUNT(*) FILTER (WHERE rider_rating = 4 OR product_quality_rating = 4 OR delivery_speed_rating = 4)::int AS r4,
         COUNT(*) FILTER (WHERE rider_rating = 3 OR product_quality_rating = 3 OR delivery_speed_rating = 3)::int AS r3,
         COUNT(*) FILTER (WHERE rider_rating = 2 OR product_quality_rating = 2 OR delivery_speed_rating = 2)::int AS r2,
         COUNT(*) FILTER (WHERE rider_rating = 1 OR product_quality_rating = 1 OR delivery_speed_rating = 1)::int AS r1
       FROM order_reviews r
       JOIN orders o ON o.id = r.order_id
       WHERE o.created_at >= $1 AND o.created_at < $2`,
      [start.toISOString(), end.toISOString()]
    ),
    query(
      `SELECT product_id, AVG(rating)::numeric(3,2) AS avg_rating
       FROM product_ratings pr
       JOIN orders o ON o.id = pr.order_id
       WHERE o.created_at >= $1 AND o.created_at < $2
       GROUP BY product_id`,
      [start.toISOString(), end.toISOString()]
    ),
    computeCommerceKpiDeltas(start, end, previousStart, previousEnd),
    computeOpsMetricsForRange(start, end),
  ]);

  const productRatingMap = new Map(
    productRatingRows.map((r) => [Number(r.product_id), Number(r.avg_rating || 0)])
  );

  const totalRevenue = orders
    .filter((o) => o.status === 'DELIVERED')
    .reduce((sum, o) => sum + Number(o.total_amount || 0), 0);

  const totalOrders = orders.length;
  const deliveredOrders = orders.filter((o) => o.status === 'DELIVERED').length;
  const cancelledOrders = orders.filter((o) => o.status === 'CANCELLED').length;
  const pendingOrders = orders.filter(
    (o) => !['DELIVERED', 'CANCELLED'].includes(o.status)
  ).length;

  const products = productRows.map((p) => ({
    name: p.name,
    category: p.category,
    quantitySold: Number(p.quantity_sold || 0),
    revenue: Number(p.revenue || 0),
    avgRating: Number(productRatingMap.get(Number(p.id)) || p.avg_rating || 0),
    stock: Number(p.stock || 0),
    trend: null,
    profitMargin: null,
    dataAvailable: Number(p.quantity_sold || 0) > 0,
  }));

  const deliveryPartners = partnerRows.map((p) => {
    const assignmentCount = Number(p.assignment_count || 0);
    const acceptedCount = Number(p.accepted_count || 0);
    const acceptanceRate =
      assignmentCount > 0 ? Math.round((acceptedCount / assignmentCount) * 100) : null;

    return {
      name: p.name,
      totalDeliveries: Number(p.total_deliveries || 0),
      avgRating: Number(p.avg_rating || 0) || null,
      onTimePercentage: null,
      acceptanceRate,
      earnings: null,
      status: p.is_online ? 'online' : 'offline',
      dataAvailable: Number(p.total_deliveries || 0) > 0,
    };
  });

  const customersWithOrders = customerRows.filter((c) => Number(c.orders || 0) > 0);
  const returningCount = customersWithOrders.filter((c) => Number(c.orders || 0) > 1).length;
  const customerTotal = customersWithOrders.length || 0;
  const newCustomersPct =
    customerTotal > 0
      ? Math.max(0, Math.round(((customerTotal - returningCount) / customerTotal) * 100))
      : null;
  const returningCustomersPct =
    customerTotal > 0 ? Math.max(0, 100 - (newCustomersPct || 0)) : null;

  const revenueChart = [];
  const days = period === 'today' ? 1 : period === 'week' ? 7 : 30;
  for (let i = days - 1; i >= 0; i--) {
    const date = new Date(end);
    date.setDate(date.getDate() - i);
    const dayOrders = orders.filter((o) => {
      const orderDate = new Date(o.created_at);
      return orderDate.toDateString() === date.toDateString();
    });
    revenueChart.push({
      date: date.toISOString().split('T')[0],
      revenue: dayOrders
        .filter((o) => o.status === 'DELIVERED')
        .reduce((sum, o) => sum + Number(o.total_amount || 0), 0),
      orders: dayOrders.length,
    });
  }

  const hourlyHeatmap = Array(24)
    .fill(0)
    .map((_, hour) => {
      const hourOrders = orders.filter(
        (o) => new Date(o.created_at).getHours() === hour
      ).length;
      return { hour, orders: hourOrders };
    });

  const ratingRow = ratingRows[0] || {};
  const reviewCount = Number(ratingRow.review_count || 0);
  const avgRating = reviewCount > 0 ? Number(ratingRow.avg_rating || 0) : null;

  const avgDeliveryTime =
    opsSnapshot.metrics.averageEndToEndDeliveryTime?.dataAvailable
      ? opsSnapshot.metrics.averageEndToEndDeliveryTime.value
      : opsSnapshot.metrics.averageRiderTripTime?.dataAvailable
        ? opsSnapshot.metrics.averageRiderTripTime.value
        : null;

  const onTimeRate = null;

  return ok(
    res,
    {
      kpi: {
        totalRevenue: Math.round(totalRevenue),
        totalOrders,
        deliveredOrders,
        cancelledOrders,
        pendingOrders,
        avgOrderValue: deliveredOrders > 0 ? Math.round(totalRevenue / deliveredOrders) : 0,
        revenueChange: kpiDeltas.revenueChange,
        ordersChange: kpiDeltas.ordersChange,
        aovChange: kpiDeltas.aovChange,
        avgRating,
        ratingChange: null,
        avgDeliveryTime,
        deliveryChange: null,
        conversionRate: null,
        conversionChange: null,
      },
      revenueChart,
      hourlyHeatmap,
      products,
      delivery: {
        successRate:
          totalOrders > 0 ? Math.round((deliveredOrders / totalOrders) * 100) : 0,
        avgTime: avgDeliveryTime,
        onTimeRate,
        partners: deliveryPartners,
        zones: [],
        batchPercentage: opsSnapshot.metrics.batchPercentage,
        averageDispatchDelay: opsSnapshot.metrics.averageDispatchDelay,
        averagePackedTime: opsSnapshot.metrics.averagePackedTime,
        averageRiderTripTime: opsSnapshot.metrics.averageRiderTripTime,
        soloVsBatchRatio: opsSnapshot.metrics.soloVsBatchRatio,
        refundPercentage: opsSnapshot.metrics.refundPercentage,
        stockFailurePercentage: opsSnapshot.metrics.stockFailurePercentage,
        ordersCancelledByReason: opsSnapshot.metrics.ordersCancelledByReason,
        peakModeHours: opsSnapshot.metrics.peakModeHours,
      },
      customers: {
        newCustomers: newCustomersPct,
        returningCustomers: returningCustomersPct,
        topCustomers: customerRows.map((c) => ({
          name: c.name,
          orders: Number(c.orders || 0),
          totalSpent: Math.round(Number(c.total_spent || 0)),
        })),
        retentionRate:
          customerTotal > 0 ? Math.round((returningCount / customerTotal) * 100) : null,
        ratingDistribution:
          reviewCount > 0
            ? {
                5: Number(ratingRow.r5 || 0),
                4: Number(ratingRow.r4 || 0),
                3: Number(ratingRow.r3 || 0),
                2: Number(ratingRow.r2 || 0),
                1: Number(ratingRow.r1 || 0),
              }
            : null,
        dataAvailable: customerTotal > 0,
      },
      opsMetrics: opsSnapshot.metrics,
      dataCompleteness: opsSnapshot.dataCompleteness,
      period,
    },
    'Analytics data'
  );
});

const getOpsMetricsHandler = asyncHandler(async (req, res) => {
  const { period, granularity } = req.validated?.query || req.query || {};
  const result = await getOpsMetrics({ period, granularity });
  return ok(res, result, 'Operational metrics');
});

const {
  listOperationalEvents,
  getOrderOperationalTimeline,
} = require('../../services/operationalEvent.service');

const listOperationalEventsHandler = asyncHandler(async (req, res) => {
  const {
    orderId,
    riderId,
    eventType,
    from,
    to,
    limit,
    offset,
  } = req.validated?.query || {};

  const events = await listOperationalEvents({
    orderId: orderId != null ? Number(orderId) : null,
    riderId: riderId != null ? Number(riderId) : null,
    eventType: eventType || null,
    fromDate: from || null,
    toDate: to || null,
    limit,
    offset,
  });

  return ok(res, { events, count: events.length }, 'Operational events');
});

const getOrderTimelineHandler = asyncHandler(async (req, res) => {
  const orderId = Number(req.validated?.params?.id);
  const timeline = await getOrderOperationalTimeline(orderId);
  return ok(res, timeline, 'Order operational timeline');
});

module.exports = {
  dashboard,
  customers,
  getUserDetail,
  toggleUserStatus,
  deliveryPartners,
  toggleDeliveryPartner,
  patchDeliveryPartner,
  listOrdersCompat,
  patchOrderCompat,
  assignRiderToOrder,
  listAdminTasksHandler,
  resolveAssignmentFailureOrder,
  resolveFailedDeliveryOrder,
  listCategoriesCompat,
  createCategoryCompat,
  patchCategoryCompat,
  listProductsCompat,
  createProductCompat,
  patchProductCompat,
  deleteProductCompat,
  listProducts,
  createProduct,
  updateProduct,
  deleteProduct,
  updateStock,
  listCategories,
  createCategory,
  updateCategory,
  deleteCategory,
  listBanners,
  createBanner,
  updateBanner,
  deleteBanner,
  getSettings,
  updateSettings,
  changeUserRole,
  getAnalytics,
  getOpsMetricsHandler,
  listOperationalEventsHandler,
  getOrderTimelineHandler,
};

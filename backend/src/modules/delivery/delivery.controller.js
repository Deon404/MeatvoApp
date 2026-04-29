const asyncHandler = require('express-async-handler');
const { withTransaction, query } = require('../../db/postgres');
const { ok, fail } = require('../../utils/response');
const { emitToRole, emitToUser } = require('../../socket/socket');
const { ROLES } = require('../../utils/roles');
const { assignOrderToPartner } = require('../../services/assignment.service');

const STATUS_TRANSITIONS = Object.freeze({
  CONFIRMED: new Set(['OUT_FOR_DELIVERY']),
  PACKED: new Set(['OUT_FOR_DELIVERY']),
  OUT_FOR_DELIVERY: new Set(['DELIVERED']),
});

const canTransition = (fromStatus, toStatus) => {
  if (!fromStatus || !toStatus) return false;
  if (fromStatus === toStatus) return true;
  return STATUS_TRANSITIONS[fromStatus]?.has(toStatus) || false;
};

const addressToText = (addr) => {
  if (!addr) return '';
  if (typeof addr === 'string') return addr;
  const text = addr.text || addr.addressText;
  if (text) return String(text);
  const parts = [addr.line1, addr.line2, addr.city, addr.state, addr.pincode].filter(Boolean);
  return parts.join(', ');
};

const getDeliveryPartnerIdForUser = async (userId) => {
  const { rows } = await query('SELECT id FROM delivery_partners WHERE user_id = $1', [userId]);
  return rows[0]?.id ? Number(rows[0].id) : null;
};

const fetchProfile = async (userId) => {
  try {
    const { rows } = await query(
      `SELECT dp.id, dp.is_online, dp.approved, dp.vehicle_type, dp.vehicle_number, dp.licence_number, dp.bank_details, dp.earnings,
              u.phone, u.name
       FROM delivery_partners dp
       JOIN users u ON u.id = dp.user_id
       WHERE dp.user_id = $1`,
      [userId]
    );
    return rows[0] || null;
  } catch (err) {
    // Backward-compatible fallback when newer columns don't exist yet.
    if (err?.code !== '42703') throw err;
    const { rows } = await query(
      `SELECT dp.id, dp.is_online, dp.vehicle_type, u.phone, u.name
       FROM delivery_partners dp
       JOIN users u ON u.id = dp.user_id
       WHERE dp.user_id = $1`,
      [userId]
    );
    const p = rows[0];
    if (!p) return null;
    return {
      ...p,
      approved: true,
      vehicle_number: null,
      licence_number: null,
      bank_details: null,
      earnings: 0,
    };
  }
};

const getMe = asyncHandler(async (req, res) => {
  const userId = Number(req.user.id);
  const p = await fetchProfile(userId);
  if (!p) return fail(res, 400, 'Delivery partner profile not found');
  return ok(
    res,
    {
      profile: {
        id: String(p.id),
        name: p.name || '',
        phone: p.phone || '',
        online: Boolean(p.is_online),
        approved: Boolean(p.approved),
        vehicle: p.vehicle_type || '',
        vehicleNumber: p.vehicle_number || '',
        licenceNumber: p.licence_number || '',
        bankDetails: p.bank_details || '',
        earnings: Number(p.earnings || 0),
      },
    },
    'Me'
  );
});

const listAvailableOrders = asyncHandler(async (req, res) => {
  const { rows } = await query(
    `SELECT o.id, o.customer_id, o.status, o.total_amount, o.address, o.payment_mode, o.created_at
     FROM orders o
     LEFT JOIN order_assignments oa ON oa.order_id = o.id
     WHERE oa.id IS NULL AND o.status IN ('CONFIRMED','PACKED')
     ORDER BY o.created_at ASC
     LIMIT 100`
  );
  return ok(res, { orders: rows }, 'Available orders');
});

const listOrdersForDeliveryApp = asyncHandler(async (req, res) => {
  const userId = Number(req.user.id);
  const deliveryPartnerId = await getDeliveryPartnerIdForUser(userId);
  if (!deliveryPartnerId) return fail(res, 400, 'Delivery partner profile not found');

  const baseSelect = `
    SELECT o.id, o.customer_id, cu.phone AS phone, o.status, o.total_amount, o.address, o.payment_mode,
           oa.delivery_partner_id,
           (EXTRACT(EPOCH FROM o.created_at) * 1000)::bigint AS created_at_ms,
           COALESCE(
             json_agg(
               json_build_object(
                 'productId', oi.product_id::text,
                 'name', p.name,
                 'quantity', oi.quantity,
                 'unit', p.unit,
                 'price', oi.price
               )
               ORDER BY oi.id ASC
             ) FILTER (WHERE oi.id IS NOT NULL),
             '[]'::json
           ) AS items
    FROM orders o
    JOIN users cu ON cu.id = o.customer_id
    LEFT JOIN order_assignments oa ON oa.order_id = o.id
    LEFT JOIN order_items oi ON oi.order_id = o.id
    LEFT JOIN products p ON p.id = oi.product_id
  `;

  const groupBy = ' GROUP BY o.id, cu.phone, oa.delivery_partner_id ';

  const { rows: available } = await query(
    `${baseSelect}
     WHERE o.status IN ('CONFIRMED','PACKED')
       AND (oa.id IS NULL OR oa.delivery_partner_id = $1)
     ${groupBy}
     ORDER BY o.created_at ASC
     LIMIT 100`,
    [deliveryPartnerId]
  );

  const { rows: active } = await query(
    `${baseSelect}
     WHERE oa.delivery_partner_id = $1
       AND o.status = 'OUT_FOR_DELIVERY'
     ${groupBy}
     ORDER BY o.created_at DESC
     LIMIT 100`,
    [deliveryPartnerId]
  );

  const { rows: delivered } = await query(
    `${baseSelect}
     WHERE oa.delivery_partner_id = $1
       AND o.status = 'DELIVERED'
     ${groupBy}
     ORDER BY o.created_at DESC
     LIMIT 200`,
    [deliveryPartnerId]
  );

  const mapRow = (o) => ({
    id: String(o.id),
    customerUid: String(o.customer_id),
    phone: o.phone || '',
    status: o.status,
    totalAmount: Number(o.total_amount || 0),
    address: addressToText(o.address) || '',
    paymentMethod: o.payment_mode || 'COD',
    createdAt: Number(o.created_at_ms || 0),
    updatedAt: Number(o.created_at_ms || 0),
    items: Array.isArray(o.items) ? o.items : [],
  });

  return ok(res, { available: available.map(mapRow), active: active.map(mapRow), delivered: delivered.map(mapRow) }, 'Orders');
});

const acceptOrder = asyncHandler(async (req, res) => {
  const userId = Number(req.user.id);
  const orderId = Number(req.validated.params.id);

  const deliveryPartnerId = await getDeliveryPartnerIdForUser(userId);
  if (!deliveryPartnerId) return fail(res, 400, 'Delivery partner profile not found');

  const updated = await withTransaction(async (client) => {
    const { rows: orderRows } = await client.query(
      'SELECT id, status FROM orders WHERE id = $1 FOR UPDATE',
      [orderId]
    );
    const order = orderRows[0];
    if (!order) throw new Error('Order not found');
    if (!['CONFIRMED', 'PACKED'].includes(order.status)) throw new Error('Order is not available');

    const { rows: existing } = await client.query(
      'SELECT id, delivery_partner_id FROM order_assignments WHERE order_id = $1 FOR UPDATE',
      [orderId]
    );
    if (existing[0] && Number(existing[0].delivery_partner_id) !== deliveryPartnerId) {
      throw new Error('Order already assigned');
    }

    if (existing[0]) {
      await client.query('UPDATE order_assignments SET status = $1 WHERE order_id = $2', ['ACCEPTED', orderId]);
    } else {
      await client.query(
        `INSERT INTO order_assignments (order_id, delivery_partner_id, status)
         VALUES ($1,$2,'ACCEPTED')`,
        [orderId, deliveryPartnerId]
      );
    }

    const { rows: updatedRows } = await client.query(
      `UPDATE orders SET status = 'OUT_FOR_DELIVERY' WHERE id = $1
       RETURNING id, customer_id, status, total_amount, coupon_id, address, payment_mode, created_at`,
      [orderId]
    );
    
    // Emit to customer and admin rooms
    const io = req.app.get('io');
    if (io) {
      io.to(`customer_${updatedRows[0].customer_id}`).emit('order:status_updated', {
        orderId: orderId,
        status: 'OUT_FOR_DELIVERY',
        updatedAt: new Date().toISOString()
      });
      io.to(`customer_${updatedRows[0].customer_id}`).emit('order:status_update', {
        orderId: orderId,
        status: 'OUT_FOR_DELIVERY',
        timestamp: new Date().toISOString(),
      });
      
      io.to('admin_room').emit('order:updated', {
        orderId: orderId,
        status: 'OUT_FOR_DELIVERY',
        updatedAt: new Date().toISOString()
      });
    }

  return ok(res, { order: updatedRows[0] }, 'Order accepted');
});
});

const updateDeliveryOrderStatus = asyncHandler(async (req, res) => {
  const userId = Number(req.user.id);
  const orderId = Number(req.validated.params.id);
  const status = req.validated.body.status;

  const deliveryPartnerId = await getDeliveryPartnerIdForUser(userId);
  if (!deliveryPartnerId) return fail(res, 400, 'Delivery partner profile not found');

  await withTransaction(async (client) => {
    const { rows: aRows } = await client.query(
      'SELECT id FROM order_assignments WHERE order_id = $1 AND delivery_partner_id = $2 FOR UPDATE',
      [orderId, deliveryPartnerId]
    );
    if (!aRows[0]) throw new Error('Order not assigned to you');

    const { rows: orderRows } = await client.query(
      'SELECT status FROM orders WHERE id = $1 FOR UPDATE',
      [orderId]
    );
    const currentStatus = orderRows[0]?.status;
    if (!canTransition(currentStatus, status)) {
      throw new Error(`Invalid transition from ${currentStatus} to ${status}`);
    }

    const assignmentStatus = status === 'OUT_FOR_DELIVERY' ? 'PICKED' : status;
    await client.query('UPDATE order_assignments SET status = $1 WHERE order_id = $2', [
      assignmentStatus,
      orderId,
    ]);
    await client.query('UPDATE orders SET status = $1 WHERE id = $2', [status, orderId]);
  });

  const { rows } = await query(
    `SELECT id, customer_id, status, total_amount, coupon_id, address, payment_mode, created_at
     FROM orders WHERE id = $1`,
    [orderId]
  );
  
  // Emit to customer and admin rooms
  const io = req.app.get('io');
  if (io && rows[0]) {
    io.to(`customer_${rows[0].customer_id}`).emit('order:status_updated', {
      orderId: orderId,
      status: status,
      updatedAt: new Date().toISOString()
    });
    io.to(`customer_${rows[0].customer_id}`).emit('order:status_update', {
      orderId: orderId,
      status: status,
      timestamp: new Date().toISOString(),
    });
    
    io.to('admin_room').emit('order:updated', {
      orderId: orderId,
      status: status,
      updatedAt: new Date().toISOString()
    });
  }
  
  return ok(res, { order: rows[0] }, 'Order updated');
});

const updateLocation = asyncHandler(async (req, res) => {
  const userId = Number(req.user.id);
  const { lat, lng } = req.validated.body;

  const { rows } = await query(
    `UPDATE delivery_partners
     SET current_lat = $1, current_lng = $2
     WHERE user_id = $3
     RETURNING id, user_id, is_online, current_lat, current_lng, vehicle_type`,
    [lat, lng, userId]
  );
  if (!rows[0]) return fail(res, 400, 'Delivery partner profile not found');

  // Emit to customers who are tracking active assigned orders.
  const dpId = Number(rows[0].id);
  const { rows: assigned } = await query(
    `SELECT o.id AS order_id, o.customer_id
     FROM order_assignments oa
     JOIN orders o ON o.id = oa.order_id
     WHERE oa.delivery_partner_id = $1 AND o.status NOT IN ('DELIVERED','CANCELLED')`,
    [dpId]
  );
  for (const a of assigned) {
    emitToUser(Number(a.customer_id), 'delivery:location', {
      orderId: Number(a.order_id),
      deliveryPartnerId: dpId,
      lat: Number(rows[0].current_lat),
      lng: Number(rows[0].current_lng),
    });
    emitToUser(Number(a.customer_id), 'partner:location_update', {
      orderId: Number(a.order_id),
      lat: Number(rows[0].current_lat),
      lng: Number(rows[0].current_lng),
      timestamp: new Date().toISOString(),
    });
  }

  return ok(res, { deliveryPartner: rows[0] }, 'Location updated');
});

const rejectOrder = asyncHandler(async (req, res) => {
  const userId = Number(req.user.id);
  const orderId = Number(req.validated.params.id);

  const deliveryPartnerId = await getDeliveryPartnerIdForUser(userId);
  if (!deliveryPartnerId) return fail(res, 400, 'Delivery partner profile not found');

  await withTransaction(async (client) => {
    const { rows: assignmentRows } = await client.query(
      `SELECT id
       FROM order_assignments
       WHERE order_id = $1 AND delivery_partner_id = $2
       FOR UPDATE`,
      [orderId, deliveryPartnerId]
    );
    if (!assignmentRows[0]) throw new Error('Order not assigned to you');

    await client.query('UPDATE order_assignments SET status = $1 WHERE order_id = $2', ['CANCELLED', orderId]);
    await client.query(
      `UPDATE orders
       SET status = CASE WHEN status = 'OUT_FOR_DELIVERY' THEN 'PACKED' ELSE status END
       WHERE id = $1`,
      [orderId]
    );
  });

  const reassignment = await assignOrderToPartner({
    orderId,
    io: req.app.get('io'),
    excludePartnerId: deliveryPartnerId,
  });

  return ok(res, { orderId, reassignment }, 'Order rejected');
});

const getEarnings = asyncHandler(async (req, res) => {
  const userId = Number(req.user.id);
  const period = req.validated?.query?.period || 'today';
  const deliveryPartnerId = await getDeliveryPartnerIdForUser(userId);
  if (!deliveryPartnerId) return fail(res, 400, 'Delivery partner profile not found');

  let interval = "INTERVAL '1 day'";
  if (period === 'week') interval = "INTERVAL '7 days'";
  if (period === 'month') interval = "INTERVAL '30 days'";

  const { rows } = await query(
    `SELECT o.id AS order_id, o.total_amount, o.created_at
     FROM order_assignments oa
     JOIN orders o ON o.id = oa.order_id
     WHERE oa.delivery_partner_id = $1
       AND o.status = 'DELIVERED'
       AND o.created_at >= NOW() - ${interval}
     ORDER BY o.created_at DESC`,
    [deliveryPartnerId]
  );

  const breakdown = rows.map((r) => ({
    orderId: Number(r.order_id),
    amount: Math.round(Number(r.total_amount || 0) * 0.1),
    bonus: 0,
    createdAt: r.created_at,
  }));
  const total = breakdown.reduce((sum, b) => sum + b.amount + b.bonus, 0);

  return ok(
    res,
    { total, deliveries: breakdown.length, breakdown, period },
    'Earnings'
  );
});

const toggleOnline = asyncHandler(async (req, res) => {
  const userId = Number(req.user.id);
  const body = req.validated.body || {};
  const desired =
    typeof body.is_online === 'boolean' ? body.is_online : typeof body.online === 'boolean' ? body.online : undefined;

  let sql;
  const params = [];
  if (typeof desired === 'boolean') {
    sql = 'UPDATE delivery_partners SET is_online = $1 WHERE user_id = $2 RETURNING id, user_id, is_online';
    params.push(desired, userId);
  } else {
    sql =
      'UPDATE delivery_partners SET is_online = NOT is_online WHERE user_id = $1 RETURNING id, user_id, is_online';
    params.push(userId);
  }

  const { rows } = await query(sql, params);
  if (!rows[0]) return fail(res, 400, 'Delivery partner profile not found');
  return ok(res, { deliveryPartner: rows[0] }, 'Online status updated');
});

const updateProfile = asyncHandler(async (req, res) => {
  const userId = Number(req.user.id);
  const patch = req.validated.body || {};

  await withTransaction(async (client) => {
    if (Object.prototype.hasOwnProperty.call(patch, 'name')) {
      await client.query('UPDATE users SET name = $1 WHERE id = $2', [patch.name || null, userId]);
    }

    const sets = [];
    const params = [];
    if (Object.prototype.hasOwnProperty.call(patch, 'vehicle')) {
      params.push(patch.vehicle || null);
      sets.push(`vehicle_type = $${params.length}`);
    }
    if (Object.prototype.hasOwnProperty.call(patch, 'vehicleNumber')) {
      params.push(patch.vehicleNumber || null);
      sets.push(`vehicle_number = $${params.length}`);
    }
    if (Object.prototype.hasOwnProperty.call(patch, 'licenceNumber')) {
      params.push(patch.licenceNumber || null);
      sets.push(`licence_number = $${params.length}`);
    }
    if (Object.prototype.hasOwnProperty.call(patch, 'bankDetails')) {
      params.push(patch.bankDetails || null);
      sets.push(`bank_details = $${params.length}`);
    }

    if (sets.length) {
      params.push(userId);
      await client.query(`UPDATE delivery_partners SET ${sets.join(', ')} WHERE user_id = $${params.length}`, params);
    }
  });

  const p = await fetchProfile(userId);
  if (!p) return fail(res, 400, 'Delivery partner profile not found');
  return ok(
    res,
    {
      profile: {
        id: String(p.id),
        name: p.name || '',
        phone: p.phone || '',
        online: Boolean(p.is_online),
        approved: Boolean(p.approved),
        vehicle: p.vehicle_type || '',
        vehicleNumber: p.vehicle_number || '',
        licenceNumber: p.licence_number || '',
        bankDetails: p.bank_details || '',
        earnings: Number(p.earnings || 0),
      },
    },
    'Profile updated'
  );
});

module.exports = {
  getMe,
  listAvailableOrders,
  listOrdersForDeliveryApp,
  acceptOrder,
  rejectOrder,
  updateDeliveryOrderStatus,
  updateLocation,
  getEarnings,
  toggleOnline,
  updateProfile,
};

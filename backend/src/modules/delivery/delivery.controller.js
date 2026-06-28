const asyncHandler = require('express-async-handler');
const { withTransaction, query } = require('../../db/postgres');
const { ok, fail } = require('../../utils/response');
const { emitToRole, emitToUser } = require('../../socket/socket');
const { ROLES } = require('../../utils/roles');
const {
  assignOrderToPartner,
  emitAssignmentCancelled,
  emitCustomerPartnerAssigned,
  emitRouteZoneAssigned,
  clearAssignmentTimeout,
} = require('../../services/assignment.service');
const {
  markFailedDelivery,
  confirmReturnToStore,
} = require('../../services/failedDelivery.service');
const {
  instrumentRiderAcceptedAndDispatched,
  publishOperationalEventAsync,
  OPERATIONAL_EVENT_TYPES,
  ACTOR_TYPES,
} = require('../../utils/operationalEvents.util');
const { addressToText, addressToObject, cleanAddressText } = require('../../utils/address');

const ADMIN_PENDING_STATUSES = ['PLACED', 'CONFIRMED', 'PACKED'];
const ADMIN_UNASSIGNED_STATUSES = ['PLACED', 'CONFIRMED', 'PACKED'];

const ADMIN_ROUTE_ORDERS_SELECT = `
  SELECT
    o.id AS order_id,
    (o.address->>'lat')::numeric AS lat,
    (o.address->>'lng')::numeric AS lng,
    COALESCE(o.address->>'text', o.address->>'raw') AS address,
    u.name AS customer_name,
    u.phone AS customer_phone,
    o.status
  FROM orders o
  JOIN users u ON u.id = o.customer_id
  LEFT JOIN order_assignments oa ON oa.order_id = o.id`;

const ADMIN_UNASSIGNED_ORDERS_SELECT = `
  SELECT
    o.id AS order_id,
    (o.address->>'lat')::numeric AS lat,
    (o.address->>'lng')::numeric AS lng,
    COALESCE(o.address->>'text', o.address->>'raw') AS address,
    u.name AS customer_name,
    u.phone AS customer_phone,
    o.status,
    o.total_amount
  FROM orders o
  JOIN users u ON u.id = o.customer_id
  LEFT JOIN order_assignments oa ON oa.order_id = o.id`;

async function queryAdminRouteOrders(dateParam, statusList) {
  if (dateParam === 'today') {
    return query(
      `${ADMIN_ROUTE_ORDERS_SELECT}
       WHERE o.created_at::date = CURRENT_DATE
         AND o.status::text = ANY($1::text[])
       ORDER BY o.created_at ASC`,
      [statusList]
    );
  }
  return query(
    `${ADMIN_ROUTE_ORDERS_SELECT}
     WHERE o.created_at::date = $1::date
       AND o.status::text = ANY($2::text[])
     ORDER BY o.created_at ASC`,
    [dateParam, statusList]
  );
}

async function queryUnassignedRouteOrders(dateParam, statusList) {
  if (dateParam === 'today') {
    return query(
      `${ADMIN_UNASSIGNED_ORDERS_SELECT}
       WHERE o.created_at::date = CURRENT_DATE
         AND o.status::text = ANY($1::text[])
         AND oa.id IS NULL
       ORDER BY o.created_at ASC`,
      [statusList]
    );
  }
  return query(
    `${ADMIN_UNASSIGNED_ORDERS_SELECT}
     WHERE o.created_at::date = $1::date
       AND o.status::text = ANY($2::text[])
       AND oa.id IS NULL
     ORDER BY o.created_at ASC`,
    [dateParam, statusList]
  );
}
const {
  calculateDeliveryEarnings,
  recordEarningsHistory,
  updateRiderEarnings,
} = require('../../services/earnings.service');
const { DELIVERY_STATUS_TRANSITIONS, canTransition } = require('../../utils/orderStatus');
const { assertWeightReconciliationForDispatch } = require('../../utils/weightReconciliationDispatch.util');
const { ensureDeliveryOTP, verifyDeliveryOTP } = require('../../services/deliveryProof.service');

// Enhanced tracking service
const { updateRiderLocation: updateRiderLocationEnhanced } = require('../../services/tracking.service');

// Route optimization
const { optimizeRoute } = require('./route-optimizer');
const { optimizeMultiRiderRoute } = require('./zone-splitter');
const { getStoreSettings } = require('../settings/settings.controller');
const { logger } = require('../../utils/logger');
const { validateRiderProofUpload } = require('../../utils/uploadSigning');
const { storeDeliveryProof } = require('../../services/deliveryProof.service');
const {
  getDeliveryPartnerIdForUser,
  countRiderActiveOrdersForUser,
  countRiderActiveOrders,
  MAX_ACTIVE_ORDERS,
  refreshPartnerOperationalState,
} = require('../../utils/deliveryPartner.util');
const { processDispatchQueue } = require('../../services/dispatch.service');
const { reportRiderOperationalException } = require('../../services/riderException.service');

const EARNINGS_PERIOD_FILTERS = {
  today: "reh.created_at >= DATE_TRUNC('day', CURRENT_DATE)",
  week: "reh.created_at >= DATE_TRUNC('week', CURRENT_DATE)",
  month: "reh.created_at >= DATE_TRUNC('month', CURRENT_DATE)",
};

const DELIVERED_FALLBACK_PERIOD_FILTERS = {
  today: "o.updated_at >= DATE_TRUNC('day', CURRENT_DATE)",
  week: "o.updated_at >= DATE_TRUNC('week', CURRENT_DATE)",
  month: "o.updated_at >= DATE_TRUNC('month', CURRENT_DATE)",
};

async function fetchRiderRatingStats(userId) {
  try {
    const { rows } = await query(
      `SELECT
         COALESCE(ROUND(AVG(orev.rider_rating)::numeric, 1), 0) AS avg_rating,
         COUNT(orev.rider_rating) FILTER (WHERE orev.rider_rating IS NOT NULL)::int AS ratings_count
       FROM order_reviews orev
       JOIN order_assignments oa ON oa.order_id = orev.order_id
       JOIN delivery_partners dp ON dp.id = oa.delivery_partner_id
       WHERE dp.user_id = $1`,
      [userId]
    );
    return {
      avgRating: Number(rows[0]?.avg_rating || 0),
      ratingsCount: Number(rows[0]?.ratings_count || 0),
    };
  } catch (err) {
    if (err?.code === '42P01') return { avgRating: 0, ratingsCount: 0 };
    throw err;
  }
}

async function fetchLifetimeEarnings(userId, deliveryPartnerId) {
  try {
    const { rows } = await query(
      `SELECT COALESCE(SUM(reh.total_amount), 0) AS lifetime_total
       FROM rider_earnings_history reh
       WHERE reh.rider_id = $1`,
      [userId]
    );
    const historyTotal = Number(rows[0]?.lifetime_total || 0);
    if (historyTotal > 0) return historyTotal;
  } catch (err) {
    if (err?.code !== '42P01') throw err;
  }

  const { rows: partnerRows } = await query(
    'SELECT COALESCE(earnings, 0) AS earnings FROM delivery_partners WHERE user_id = $1',
    [userId]
  );
  const partnerTotal = Number(partnerRows[0]?.earnings || 0);
  if (partnerTotal > 0) return partnerTotal;

  const { rows: fallbackRows } = await query(
    `SELECT COALESCE(SUM(ROUND(o.total_amount * 0.1)), 0) AS lifetime_total
     FROM order_assignments oa
     JOIN orders o ON o.id = oa.order_id
     WHERE oa.delivery_partner_id = $1
       AND o.status = 'DELIVERED'`,
    [deliveryPartnerId]
  );
  return Number(fallbackRows[0]?.lifetime_total || 0);
}

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
    SELECT o.id, o.customer_id, cu.phone AS phone, cu.name AS customer_name, o.status, o.total_amount, o.address, o.payment_mode,
           o.failed_delivery_reason, o.failed_delivery_resolution, o.returned_at, o.return_condition,
           oa.delivery_partner_id, oa.status AS assignment_status,
           oa.assigned_at,
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

  const groupBy = ' GROUP BY o.id, cu.phone, cu.name, oa.delivery_partner_id, oa.status, oa.assigned_at ';

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
       AND (
         o.status IN ('OUT_FOR_DELIVERY', 'PICKED_UP', 'ON_THE_WAY', 'RIDER_NEARBY')
         OR (o.status = 'FAILED_DELIVERY' AND o.failed_delivery_resolution = 'PENDING')
       )
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

  const mapRow = (o) => {
    const addressObj = addressToObject(o.address) || { text: '', formatted: '' };
    return {
      id: String(o.id),
      customerUid: String(o.customer_id),
      customerName: String(o.customer_name || '').trim(),
      phone: o.phone || '',
      status: o.status,
      assignment_status: o.assignment_status || null,
      failed_delivery_reason: o.failed_delivery_reason || null,
      failed_delivery_resolution: o.failed_delivery_resolution || null,
      returned_at: o.returned_at || null,
      return_condition: o.return_condition || null,
      assigned_at: o.assigned_at || null,
      totalAmount: Number(o.total_amount || 0),
      address: addressObj,
      paymentMethod: o.payment_mode || 'COD',
      createdAt: Number(o.created_at_ms || 0),
      updatedAt: Number(o.created_at_ms || 0),
      items: Array.isArray(o.items) ? o.items : [],
    };
  };

  return ok(res, { available: available.map(mapRow), active: active.map(mapRow), delivered: delivered.map(mapRow) }, 'Orders');
});

const acceptOrder = asyncHandler(async (req, res) => {
  const userId = Number(req.user.id);
  const orderId = Number(req.validated.params.id);

  const deliveryPartnerId = await getDeliveryPartnerIdForUser(userId);
  if (!deliveryPartnerId) return fail(res, 400, 'Delivery partner profile not found');

  const updatedOrder = await withTransaction(async (client) => {
    const { rows: orderRows } = await client.query(
      'SELECT id, status, weight_reconciliation_status FROM orders WHERE id = $1 FOR UPDATE',
      [orderId]
    );
    const order = orderRows[0];
    if (!order) {
      const err = new Error('Order not found');
      err.statusCode = 404;
      throw err;
    }
    if (order.status !== 'PACKED') {
      const err = new Error('Only packed orders can be accepted by a rider');
      err.statusCode = 400;
      throw err;
    }

    const reconStatus = String(order.weight_reconciliation_status || '').toUpperCase();
    if (reconStatus !== 'COMPLETED' && reconStatus !== 'NOT_REQUIRED') {
      const err = new Error('Weight reconciliation must complete before rider can accept');
      err.statusCode = 400;
      throw err;
    }

    const { rows: existing } = await client.query(
      'SELECT id, delivery_partner_id FROM order_assignments WHERE order_id = $1 FOR UPDATE',
      [orderId]
    );
    if (existing[0] && Number(existing[0].delivery_partner_id) !== deliveryPartnerId) {
      const err = new Error('Order already assigned');
      err.statusCode = 409;
      throw err;
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

    return updatedRows[0];
  });

  clearAssignmentTimeout(orderId);

  ensureDeliveryOTP(orderId).catch(() => {});

  // Emit to customer and admin rooms after transaction commits successfully
  const io = req.app.get('io');
  if (io) {
    const { rows: partnerRows } = await query(
      `SELECT dp.id, dp.user_id, dp.current_lat, dp.current_lng, u.name, u.phone
       FROM delivery_partners dp
       JOIN users u ON u.id = dp.user_id
       WHERE dp.user_id = $1`,
      [userId]
    );
    const partner = partnerRows[0];

    io.to(`customer_${updatedOrder.customer_id}`).emit('order:status_updated', {
      orderId: orderId,
      status: 'OUT_FOR_DELIVERY',
      updatedAt: new Date().toISOString()
    });
    io.to(`customer_${updatedOrder.customer_id}`).emit('order:status_update', {
      orderId: orderId,
      status: 'OUT_FOR_DELIVERY',
      timestamp: new Date().toISOString(),
    });

    if (partner) {
      const partnerPayload = {
        orderId,
        partner: {
          id: Number(partner.id),
          name: partner.name,
          phone: partner.phone,
          lat: Number(partner.current_lat ?? 0),
          lng: Number(partner.current_lng ?? 0),
        },
        timestamp: new Date().toISOString(),
      };
      io.to(`customer_${updatedOrder.customer_id}`).emit('partner:accepted', partnerPayload);
      io.to(`customer_${updatedOrder.customer_id}`).emit('order:partner_assigned', partnerPayload);
    }

    io.to('admin_room').emit('order:updated', {
      orderId: orderId,
      status: 'OUT_FOR_DELIVERY',
      updatedAt: new Date().toISOString()
    });
  }

  instrumentRiderAcceptedAndDispatched(io, {
    orderId,
    riderId: deliveryPartnerId,
    riderUserId: userId,
    previousState: 'PACKED',
  });

  refreshPartnerOperationalState({
    deliveryPartnerId,
    io,
    reason: 'order_accepted',
  }).catch(() => {});

  return ok(res, { order: updatedOrder }, 'Order accepted');
});

const markOrderFailedDelivery = asyncHandler(async (req, res) => {
  const userId = Number(req.user.id);
  const orderId = Number(req.validated.params.id);
  const reason = req.validated.body.reason;
  const io = req.app.get('io');

  const result = await markFailedDelivery({
    orderId,
    riderUserId: userId,
    reason,
    io,
  });

  return ok(res, { order: result.order, task: result.task }, 'Failed delivery recorded');
});

const confirmOrderReturnToStore = asyncHandler(async (req, res) => {
  const userId = Number(req.user.id);
  const orderId = Number(req.validated.params.id);
  const returnCondition = req.validated.body.returnCondition;
  const io = req.app.get('io');

  const result = await confirmReturnToStore({
    orderId,
    riderUserId: userId,
    returnCondition,
    io,
  });

  return ok(res, { order: result.order }, 'Return to store confirmed');
});

const reportOperationalException = asyncHandler(async (req, res) => {
  const userId = Number(req.user.id);
  const orderId = Number(req.validated.params.id);
  const exceptionType = req.validated.body.exceptionType;
  const notes = req.validated.body.notes;
  const io = req.app.get('io');

  const result = await reportRiderOperationalException({
    orderId,
    riderUserId: userId,
    exceptionType,
    notes,
    io,
  });

  return ok(res, result, 'Operational exception reported');
});

const updateDeliveryOrderStatus = asyncHandler(async (req, res) => {
  const userId = Number(req.user.id);
  const orderId = Number(req.validated.params.id);
  const status = req.validated.body.status;
  const proofUrl = req.validated.body.proofUrl;
  const deliveryNotes = req.validated.body.deliveryNotes;
  const otp = req.validated.body.otp;

  const deliveryPartnerId = await getDeliveryPartnerIdForUser(userId);
  if (!deliveryPartnerId) return fail(res, 400, 'Delivery partner profile not found');

  if (status === 'DELIVERED') {
    if (!otp) return fail(res, 400, 'Delivery OTP is required');
    const otpResult = await verifyDeliveryOTP(orderId, otp);
    if (!otpResult.valid) return fail(res, 400, otpResult.reason);
  }

  let proofStoragePath = null;
  if (status === 'DELIVERED' && proofUrl) {
    const proofCheck = validateRiderProofUpload(proofUrl, userId);
    if (!proofCheck.valid) return fail(res, 400, proofCheck.reason);
    proofStoragePath = proofCheck.storagePath;
  }

  let previousOrderStatus = null;

  await withTransaction(async (client) => {
    const { rows: aRows } = await client.query(
      'SELECT id FROM order_assignments WHERE order_id = $1 AND delivery_partner_id = $2 FOR UPDATE',
      [orderId, deliveryPartnerId]
    );
    if (!aRows[0]) {
      const err = new Error('Order not assigned to you');
      err.statusCode = 403;
      throw err;
    }

    const { rows: orderRows } = await client.query(
      'SELECT status, weight_reconciliation_status FROM orders WHERE id = $1 FOR UPDATE',
      [orderId]
    );
    const currentStatus = orderRows[0]?.status;
    previousOrderStatus = currentStatus;
    if (!canTransition(DELIVERY_STATUS_TRANSITIONS, currentStatus, status)) {
      const err = new Error(`Invalid transition from ${currentStatus} to ${status}`);
      err.statusCode = 400;
      throw err;
    }

    if (status === 'OUT_FOR_DELIVERY') {
      try {
        assertWeightReconciliationForDispatch(orderRows[0]?.weight_reconciliation_status);
      } catch (reconErr) {
        reconErr.statusCode = 400;
        throw reconErr;
      }
    }

    const assignmentStatusByOrderStatus = {
      OUT_FOR_DELIVERY: 'ACCEPTED',
      PICKED_UP: 'PICKED',
      ON_THE_WAY: 'PICKED',
      DELIVERED: 'DELIVERED',
    };
    const assignmentStatus = assignmentStatusByOrderStatus[status] ?? status;
    await client.query('UPDATE order_assignments SET status = $1 WHERE order_id = $2', [
      assignmentStatus,
      orderId,
    ]);
    await client.query('UPDATE orders SET status = $1 WHERE id = $2', [status, orderId]);

    // LIFECYCLE FIX: mark COD payment collected when delivery completes
    if (status === 'DELIVERED') {
      await client.query(
        `UPDATE orders
         SET payment_status = 'COLLECTED', updated_at = NOW()
         WHERE id = $1 AND payment_mode = 'COD' AND payment_status = 'PENDING'`,
        [orderId]
      );
    }
  });

  if (status === 'DELIVERED' && proofStoragePath) {
    await storeDeliveryProof({
      orderId,
      riderUserId: userId,
      proofType: 'photo',
      proofUrl: proofStoragePath,
      notes: deliveryNotes || null,
    });
  }

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

  if (status === 'DELIVERED') {
    publishOperationalEventAsync(io, {
      eventType: OPERATIONAL_EVENT_TYPES.DELIVERED,
      orderId,
      actorType: ACTOR_TYPES.RIDER,
      actorId: userId,
      riderId: deliveryPartnerId,
      previousState: previousOrderStatus,
      newState: 'DELIVERED',
      metadata: {},
    });

    refreshPartnerOperationalState({
      deliveryPartnerId,
      io,
      reason: 'order_delivered',
    }).catch(() => {});
  }

  if (status === 'DELIVERED' && rows[0]) {
    try {
      const { rows: assignmentRows } = await query(
        `SELECT oa.delivery_partner_id, oa.assigned_at, oa.updated_at,
                o.total_amount, o.created_at, o.address,
                dp.user_id AS rider_user_id
         FROM order_assignments oa
         JOIN orders o ON o.id = oa.order_id
         JOIN delivery_partners dp ON dp.id = oa.delivery_partner_id
         WHERE oa.order_id = $1`,
        [orderId]
      );

      if (assignmentRows[0]) {
        const assignment = assignmentRows[0];
        let distanceKm = 2;
        const address =
          typeof assignment.address === 'string'
            ? JSON.parse(assignment.address)
            : assignment.address;
        if (address?.lat && address?.lng) {
          const { rows: storeRows } = await query(
            `SELECT center_lat, center_lng FROM store_settings ORDER BY updated_at DESC LIMIT 1`
          );
          if (storeRows[0]?.center_lat && storeRows[0]?.center_lng) {
            const { haversineDistanceKm } = require('../../utils/distance.util');
            distanceKm = haversineDistanceKm(
              Number(storeRows[0].center_lat),
              Number(storeRows[0].center_lng),
              Number(address.lat),
              Number(address.lng)
            );
          }
        }

        const earnings = await calculateDeliveryEarnings(
          {
            total_amount: Number(assignment.total_amount || 0),
            created_at: assignment.created_at,
          },
          {
            delivery_partner_id: assignment.rider_user_id,
            assigned_at: assignment.assigned_at,
            updated_at: assignment.updated_at || new Date(),
            distance_km: distanceKm,
          }
        );

        await recordEarningsHistory(orderId, assignment.rider_user_id, earnings);
        await updateRiderEarnings(assignment.rider_user_id, earnings.total);
      }
    } catch (earningsErr) {
      // Non-blocking — delivery status already committed
      console.error('delivery_earnings_update_failed', earningsErr.message);
    }

    processDispatchQueue(io).catch((err) => {
      console.error('dispatch_queue_after_delivery_failed', err.message);
    });
  }
  
  return ok(res, { order: rows[0] }, 'Order updated');
});

const updateLocation = asyncHandler(async (req, res) => {
  const userId = Number(req.user.id);
  const { lat, lng, orderId } = req.validated.body;
  const io = req.app.get('io');

  // Use enhanced tracking service with ETA calculation and nearby detection
  try {
    const result = await updateRiderLocationEnhanced({
      riderUserId: userId,
      lat,
      lng,
      orderId: orderId ? Number(orderId) : null,
      io,
    });

    // Backward compatibility - emit old events
    const { rows } = await query(
      `SELECT id, user_id, is_online, current_lat, current_lng, vehicle_type
       FROM delivery_partners WHERE user_id = $1`,
      [userId]
    );

    if (rows[0]) {
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
    }

    return ok(res, { 
      deliveryPartner: rows[0],
      tracking: result,
    }, 'Location updated with ETA calculation');
  } catch (error) {
    // Fallback to basic location update if enhanced service fails
    const { rows } = await query(
      `UPDATE delivery_partners
       SET current_lat = $1, current_lng = $2
       WHERE user_id = $3
       RETURNING id, user_id, is_online, current_lat, current_lng, vehicle_type`,
      [lat, lng, userId]
    );
    
    if (!rows[0]) return fail(res, 400, 'Delivery partner profile not found');
    return ok(res, { deliveryPartner: rows[0] }, 'Location updated');
  }
});

const rejectOrder = asyncHandler(async (req, res) => {
  const userId = Number(req.user.id);
  const orderId = Number(req.validated.params.id);

  const deliveryPartnerId = await getDeliveryPartnerIdForUser(userId);
  if (!deliveryPartnerId) return fail(res, 400, 'Delivery partner profile not found');

  await withTransaction(async (client) => {
    let { rows: assignmentRows } = await client.query(
      `SELECT id
       FROM order_assignments
       WHERE order_id = $1 AND delivery_partner_id = $2
       FOR UPDATE`,
      [orderId, deliveryPartnerId]
    );

    if (!assignmentRows[0]) {
      const { rows: existing } = await client.query(
        `SELECT delivery_partner_id FROM order_assignments WHERE order_id = $1 FOR UPDATE`,
        [orderId]
      );
      if (existing[0] && Number(existing[0].delivery_partner_id) !== deliveryPartnerId) {
        const err = new Error('Order assigned to another partner');
        err.statusCode = 403;
        throw err;
      }
      if (!existing[0]) {
        await client.query(
          `INSERT INTO order_assignments (order_id, delivery_partner_id, status, assigned_at)
           VALUES ($1, $2, 'ASSIGNED', NOW())`,
          [orderId, deliveryPartnerId]
        );
      }
      ({ rows: assignmentRows } = await client.query(
        `SELECT id FROM order_assignments
         WHERE order_id = $1 AND delivery_partner_id = $2 FOR UPDATE`,
        [orderId, deliveryPartnerId]
      ));
    }

    if (!assignmentRows[0]) {
      const err = new Error('Order not assigned to you');
      err.statusCode = 403;
      throw err;
    }

    await client.query('UPDATE order_assignments SET status = $1 WHERE order_id = $2', ['CANCELLED', orderId]);
    await client.query(
      `UPDATE orders
       SET status = CASE WHEN status = 'OUT_FOR_DELIVERY' THEN 'PACKED' ELSE status END
       WHERE id = $1`,
      [orderId]
    );
  });

  clearAssignmentTimeout(orderId);

  emitAssignmentCancelled(
    req.app.get('io'),
    orderId,
    userId,
    'partner_rejected'
  );

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

  const historyParams = [userId];
  let historyDateFilter = EARNINGS_PERIOD_FILTERS[period] || EARNINGS_PERIOD_FILTERS.today;
  if (period.startsWith('date:')) {
    historyDateFilter = 'reh.created_at::date = $2::date';
    historyParams.push(period.slice(5));
  }

  let rows = [];
  try {
    const historyResult = await query(
      `SELECT reh.order_id, reh.total_amount, reh.base_amount, reh.distance_bonus,
              reh.time_bonus, reh.peak_bonus, reh.performance_bonus, reh.created_at,
              reh.completion_rate
       FROM rider_earnings_history reh
       WHERE reh.rider_id = $1
         AND ${historyDateFilter}
       ORDER BY reh.created_at DESC`,
      historyParams
    );
    rows = historyResult.rows;
  } catch (err) {
    if (err?.code !== '42P01') throw err;
  }

  if (rows.length === 0) {
    const fallbackParams = [deliveryPartnerId];
    let fallbackDateFilter =
      DELIVERED_FALLBACK_PERIOD_FILTERS[period] ||
      DELIVERED_FALLBACK_PERIOD_FILTERS.today;
    if (period.startsWith('date:')) {
      fallbackDateFilter = 'o.updated_at::date = $2::date';
      fallbackParams.push(period.slice(5));
    }

    const fallback = await query(
      `SELECT o.id AS order_id, o.total_amount, o.updated_at AS created_at
       FROM order_assignments oa
       JOIN orders o ON o.id = oa.order_id
       WHERE oa.delivery_partner_id = $1
         AND o.status = 'DELIVERED'
         AND ${fallbackDateFilter}
       ORDER BY o.updated_at DESC`,
      fallbackParams
    );
    rows = fallback.rows.map((r) => ({
      order_id: r.order_id,
      total_amount: Math.round(Number(r.total_amount || 0) * 0.1),
      base_amount: Math.round(Number(r.total_amount || 0) * 0.1),
      distance_bonus: 0,
      time_bonus: 0,
      peak_bonus: 0,
      performance_bonus: 0,
      created_at: r.created_at,
      completion_rate: null,
    }));
  }

  const breakdown = rows.map((r) => ({
    orderId: Number(r.order_id),
    amount: Math.round(Number(r.total_amount || 0)),
    base: Math.round(Number(r.base_amount || r.total_amount || 0)),
    distanceBonus: Math.round(Number(r.distance_bonus || 0)),
    timeBonus: Math.round(Number(r.time_bonus || 0)),
    peakBonus: Math.round(Number(r.peak_bonus || 0)),
    performanceBonus: Math.round(Number(r.performance_bonus || 0)),
    bonus: Math.round(
      Number(r.distance_bonus || 0) +
      Number(r.time_bonus || 0) +
      Number(r.peak_bonus || 0) +
      Number(r.performance_bonus || 0)
    ),
    createdAt: r.created_at,
  }));
  const total = breakdown.reduce((sum, b) => sum + b.amount, 0);

  const [{ avgRating, ratingsCount }, lifetimeTotal] = await Promise.all([
    fetchRiderRatingStats(userId),
    fetchLifetimeEarnings(userId, deliveryPartnerId),
  ]);

  return ok(
    res,
    {
      total,
      lifetimeTotal,
      deliveries: breakdown.length,
      breakdown,
      period,
      rating: avgRating,
      totalRatings: ratingsCount,
      ratings_count: ratingsCount,
      completionRate: rows[0]?.completion_rate != null
        ? Number(rows[0].completion_rate)
        : 0,
    },
    'Earnings'
  );
});

const toggleOnline = asyncHandler(async (req, res) => {
  const userId = Number(req.user.id);
  const body = req.validated.body || {};
  const desired =
    typeof body.is_online === 'boolean' ? body.is_online : typeof body.online === 'boolean' ? body.online : undefined;
  const lat = body.lat != null ? Number(body.lat) : null;
  const lng = body.lng != null ? Number(body.lng) : null;
  const hasCoords = Number.isFinite(lat) && Number.isFinite(lng);

  let onlineState;
  if (typeof desired === 'boolean') {
    onlineState = desired;
  } else {
    const { rows: current } = await query('SELECT is_online FROM delivery_partners WHERE user_id = $1', [userId]);
    if (!current[0]) return fail(res, 400, 'Delivery partner profile not found');
    onlineState = !current[0].is_online;
  }

  if (!onlineState) {
    const activeOrderCount = await countRiderActiveOrdersForUser(userId);
    if (activeOrderCount > 0) {
      return fail(
        res,
        409,
        `Cannot go offline with ${activeOrderCount} active ${activeOrderCount === 1 ? 'delivery' : 'deliveries'}. Complete or return all orders first.`,
        {
          code: 'ACTIVE_DELIVERIES_BLOCK_OFFLINE',
          activeOrderCount,
          maxActiveOrders: MAX_ACTIVE_ORDERS,
        }
      );
    }
  }

  let finalLat = hasCoords ? lat : null;
  let finalLng = hasCoords ? lng : null;

  if (onlineState && !hasCoords) {
    const settings = await getStoreSettings();
    finalLat = settings.center_lat;
    finalLng = settings.center_lng;
    const riderId = await getDeliveryPartnerIdForUser(userId);
    logger.warn('rider_online_no_gps', { riderId, fallback: 'store_location' });
  }

  const willSetCoords = Number.isFinite(finalLat) && Number.isFinite(finalLng);

  let sql;
  const params = [];
  if (willSetCoords) {
    sql =
      'UPDATE delivery_partners SET is_online = $1, current_lat = $2, current_lng = $3, updated_at = NOW() WHERE user_id = $4 RETURNING id, user_id, is_online, current_lat, current_lng';
    params.push(onlineState, finalLat, finalLng, userId);
  } else {
    sql =
      'UPDATE delivery_partners SET is_online = $1, updated_at = NOW() WHERE user_id = $2 RETURNING id, user_id, is_online, current_lat, current_lng';
    params.push(onlineState, userId);
  }

  const { rows } = await query(sql, params);
  if (!rows[0]) return fail(res, 400, 'Delivery partner profile not found');

  refreshPartnerOperationalState({
    deliveryPartnerId: Number(rows[0].id),
    io: req.app.get('io'),
    reason: onlineState ? 'went_online' : 'went_offline',
  }).catch(() => {});

  return ok(res, { deliveryPartner: rows[0] }, 'Online status updated');
});

const updateProfile = asyncHandler(async (req, res) => {
  const userId = Number(req.user.id);
  const patch = req.validated.body || {};

  await withTransaction(async (client) => {
    if (Object.prototype.hasOwnProperty.call(patch, 'name')) {
      await client.query('UPDATE users SET name = $1 WHERE id = $2', [patch.name || null, userId]);
    }

    const hasVehicle = Object.prototype.hasOwnProperty.call(patch, 'vehicle');
    const hasVehicleNumber = Object.prototype.hasOwnProperty.call(patch, 'vehicleNumber');
    const hasLicenceNumber = Object.prototype.hasOwnProperty.call(patch, 'licenceNumber');
    const hasBankDetails = Object.prototype.hasOwnProperty.call(patch, 'bankDetails');

    if (hasVehicle || hasVehicleNumber || hasLicenceNumber || hasBankDetails) {
      await client.query(
        `UPDATE delivery_partners
         SET vehicle_type = CASE WHEN $1 THEN $2 ELSE vehicle_type END,
             vehicle_number = CASE WHEN $3 THEN $4 ELSE vehicle_number END,
             licence_number = CASE WHEN $5 THEN $6 ELSE licence_number END,
             bank_details = CASE WHEN $7 THEN $8 ELSE bank_details END
         WHERE user_id = $9`,
        [
          hasVehicle,
          patch.vehicle || null,
          hasVehicleNumber,
          patch.vehicleNumber || null,
          hasLicenceNumber,
          patch.licenceNumber || null,
          hasBankDetails,
          patch.bankDetails || null,
          userId,
        ]
      );
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

// ─── Route Optimization Endpoints ────────────────────────────────────────────

const getMyOptimizedRoute = asyncHandler(async (req, res) => {
  const userId = Number(req.user.id);
  const deliveryPartnerId = await getDeliveryPartnerIdForUser(userId);
  if (!deliveryPartnerId) return fail(res, 400, 'Delivery partner profile not found');

  const storeSettings = await getStoreSettings();
  const storeLat = Number(storeSettings.center_lat || 23.6583);
  const storeLng = Number(storeSettings.center_lng || 86.1764);

  const { rows } = await query(
    `SELECT 
       o.id AS order_id,
       (o.address->>'lat')::numeric AS lat,
       (o.address->>'lng')::numeric AS lng,
       COALESCE(o.address->>'text', o.address->>'raw') AS address,
       u.name AS customer_name,
       u.phone AS customer_phone
     FROM orders o
     JOIN users u ON u.id = o.customer_id
     JOIN order_assignments oa ON oa.order_id = o.id
     WHERE oa.delivery_partner_id = $1
       AND o.status IN ('CONFIRMED', 'PACKED', 'OUT_FOR_DELIVERY', 'PICKED_UP', 'ON_THE_WAY')
     ORDER BY o.created_at ASC`,
    [deliveryPartnerId]
  );

  const deliveryPoints = rows.map(row => ({
    orderId: Number(row.order_id),
    lat: Number(row.lat),
    lng: Number(row.lng),
    address: row.address || 'Address not available',
    customerName: row.customer_name || 'Customer',
    customerPhone: row.customer_phone || null,
  }));

  const optimizedRoute = optimizeRoute(storeLat, storeLng, deliveryPoints);

  return ok(res, optimizedRoute, 'Optimized route');
});

const getOptimizedRouteForRider = asyncHandler(async (req, res) => {
  const riderId = Number(req.query.riderId);
  if (!riderId) return fail(res, 400, 'riderId query parameter required');

  const { rows: dpRows } = await query(
    'SELECT id FROM delivery_partners WHERE id = $1',
    [riderId]
  );
  if (!dpRows[0]) return fail(res, 404, 'Delivery partner not found');

  const storeSettings = await getStoreSettings();
  const storeLat = Number(storeSettings.center_lat || 23.6583);
  const storeLng = Number(storeSettings.center_lng || 86.1764);

  const { rows } = await query(
    `SELECT 
       o.id AS order_id,
       (o.address->>'lat')::numeric AS lat,
       (o.address->>'lng')::numeric AS lng,
       COALESCE(o.address->>'text', o.address->>'raw') AS address,
       u.name AS customer_name,
       u.phone AS customer_phone
     FROM orders o
     JOIN users u ON u.id = o.customer_id
     JOIN order_assignments oa ON oa.order_id = o.id
     WHERE oa.delivery_partner_id = $1
       AND o.status IN ('CONFIRMED', 'PACKED', 'OUT_FOR_DELIVERY', 'PICKED_UP', 'ON_THE_WAY')
     ORDER BY o.created_at ASC`,
    [riderId]
  );

  const deliveryPoints = rows.map(row => ({
    orderId: Number(row.order_id),
    lat: Number(row.lat),
    lng: Number(row.lng),
    address: row.address || 'Address not available',
    customerName: row.customer_name || 'Customer',
    customerPhone: row.customer_phone || null,
  }));

  const optimizedRoute = optimizeRoute(storeLat, storeLng, deliveryPoints);

  return ok(res, optimizedRoute, 'Optimized route for rider');
});

const getAdminOptimizedRoute = asyncHandler(async (req, res) => {
  const dateParam = req.query.date || 'today';

  const storeSettings = await getStoreSettings();
  const storeLat = Number(storeSettings.center_lat || 23.6583);
  const storeLng = Number(storeSettings.center_lng || 86.1764);

  const { rows } = await queryAdminRouteOrders(dateParam, ADMIN_PENDING_STATUSES);

  const deliveryPoints = rows.map(row => ({
    orderId: Number(row.order_id),
    lat: Number(row.lat),
    lng: Number(row.lng),
    address: cleanAddressText(row.address) || 'Address not available',
    customerName: row.customer_name || 'Customer',
    customerPhone: row.customer_phone || null,
    status: row.status,
  }));

  const optimizedRoute = optimizeRoute(storeLat, storeLng, deliveryPoints);

  return ok(res, {
    ...optimizedRoute,
    date: dateParam,
    totalOrders: rows.length,
  }, 'Admin optimized route');
});

const assignMultiRiderRoutes = asyncHandler(async (req, res) => {
  const dateParam = req.body.date || 'today';
  const numRiders = Number(req.body.numRiders || 3);

  if (!Number.isInteger(numRiders) || numRiders < 1 || numRiders > 50) {
    return fail(res, 400, 'numRiders must be between 1 and 50');
  }

  const storeSettings = await getStoreSettings();
  const storeLat = Number(storeSettings.center_lat || 23.6583);
  const storeLng = Number(storeSettings.center_lng || 86.1764);

  const { rows } = await queryUnassignedRouteOrders(dateParam, ADMIN_UNASSIGNED_STATUSES);

  if (rows.length === 0) {
    return ok(res, {
      zones: [],
      totalOrders: 0,
      totalRiders: 0,
      message: 'No unassigned orders found for the specified date',
    }, 'No orders to assign');
  }

  const orders = rows.map(row => ({
    orderId: Number(row.order_id),
    lat: Number(row.lat),
    lng: Number(row.lng),
    address: cleanAddressText(row.address) || 'Address not available',
    customerName: row.customer_name || 'Customer',
    customerPhone: row.customer_phone || null,
    status: row.status,
    totalAmount: Number(row.total_amount || 0),
  }));

  const multiRiderPlan = optimizeMultiRiderRoute(orders, numRiders, storeLat, storeLng);

  return ok(res, {
    ...multiRiderPlan,
    date: dateParam,
    assignmentReady: true,
  }, 'Multi-rider routes optimized');
});

const bulkAssignZones = asyncHandler(async (req, res) => {
  const body = req.validated.body || req.body || {};
  const zones = Array.isArray(body.zones) ? body.zones : [];
  const riderIds = Array.isArray(body.riderIds) ? body.riderIds : [];

  if (!zones.length) {
    return fail(res, 400, 'zones array is required');
  }

  const assignmentResults = await withTransaction(async (client) => {
    const results = [];

    for (const zone of zones) {
      const zoneId = Number(zone.zoneId ?? zone.zone_id);
      const riderId = Number(
        zone.riderId ?? zone.rider_id ?? riderIds[0]
      );
      const orderIds = (zone.orderIds ?? zone.order_ids ?? [])
        .map(Number)
        .filter((id) => Number.isFinite(id) && id > 0);
      const routeOrder = (zone.routeOrder ?? zone.route_order ?? orderIds)
        .map(Number)
        .filter((id) => Number.isFinite(id) && id > 0);

      if (!Number.isFinite(zoneId) || zoneId <= 0) {
        const err = new Error('Each zone must include a valid zoneId');
        err.statusCode = 400;
        throw err;
      }
      if (!Number.isFinite(riderId) || riderId <= 0) {
        const err = new Error(`Zone ${zoneId} requires a valid riderId`);
        err.statusCode = 400;
        throw err;
      }
      if (!orderIds.length) {
        const err = new Error(`Zone ${zoneId} has no orders to assign`);
        err.statusCode = 400;
        throw err;
      }

      const { rows: partnerRows } = await client.query(
        `SELECT dp.id, dp.user_id, dp.is_online, dp.approved, dp.current_lat, dp.current_lng,
                u.name, u.phone
         FROM delivery_partners dp
         JOIN users u ON u.id = dp.user_id
         WHERE dp.id = $1`,
        [riderId]
      );
      if (!partnerRows[0]) {
        const err = new Error(`Delivery partner ${riderId} not found`);
        err.statusCode = 404;
        throw err;
      }
      if (!partnerRows[0].approved) {
        const err = new Error(`Delivery partner ${riderId} is not approved`);
        err.statusCode = 400;
        throw err;
      }

      const partner = partnerRows[0];
      const assignedOrders = [];
      const assignedOrderIds = [];

      for (const orderId of routeOrder) {
        if (!orderIds.includes(orderId)) continue;

        const { rows: orderRows } = await client.query(
          `SELECT o.id, o.customer_id, o.status, o.address, o.total_amount, o.payment_mode
           FROM orders o
           WHERE o.id = $1
           FOR UPDATE`,
          [orderId]
        );
        const order = orderRows[0];
        if (!order) {
          const err = new Error(`Order ${orderId} not found`);
          err.statusCode = 404;
          throw err;
        }
        if (!['CONFIRMED', 'PACKED'].includes(order.status)) {
          const err = new Error(
            `Order ${orderId} is not assignable (status: ${order.status})`
          );
          err.statusCode = 400;
          throw err;
        }

        const { rows: existing } = await client.query(
          `SELECT delivery_partner_id
           FROM order_assignments
           WHERE order_id = $1
           FOR UPDATE`,
          [orderId]
        );
        if (
          existing[0] &&
          Number(existing[0].delivery_partner_id) !== riderId
        ) {
          const err = new Error(
            `Order ${orderId} is already assigned to another rider`
          );
          err.statusCode = 409;
          throw err;
        }

        await client.query(
          `INSERT INTO order_assignments (order_id, delivery_partner_id, status, assigned_at)
           VALUES ($1, $2, 'ASSIGNED', NOW())
           ON CONFLICT (order_id)
           DO UPDATE SET
             delivery_partner_id = EXCLUDED.delivery_partner_id,
             status = 'ASSIGNED',
             assigned_at = NOW()`,
          [orderId, riderId]
        );

        assignedOrders.push(order);
        assignedOrderIds.push(Number(order.id));
      }

      results.push({
        zoneId,
        riderId,
        partnerUserId: Number(partner.user_id),
        orderIds: assignedOrderIds,
        routeOrder: routeOrder.filter((id) => assignedOrderIds.includes(id)),
        orders: assignedOrders,
        partner,
      });
    }

    return results;
  });

  const io = req.app.get('io');
  if (io) {
    for (const result of assignmentResults) {
      const partnerPayload = {
        id: Number(result.partner.id),
        userId: Number(result.partner.user_id),
        user_id: Number(result.partner.user_id),
        name: result.partner.name,
        phone: result.partner.phone,
        current_lat: result.partner.current_lat,
        current_lng: result.partner.current_lng,
      };

      emitRouteZoneAssigned(io, {
        zoneId: result.zoneId,
        riderUserId: result.partnerUserId,
        riderId: result.riderId,
        orderIds: result.orderIds,
        routeOrder: result.routeOrder,
      });

      for (const order of result.orders) {
        emitCustomerPartnerAssigned(io, order, partnerPayload);
      }

      io.to('admin_room').emit('order:updated', {
        zoneId: result.zoneId,
        riderId: result.riderId,
        orderIds: result.orderIds,
        status: 'ASSIGNED',
        updatedAt: new Date().toISOString(),
      });
    }
  }

  return ok(
    res,
    {
      assignedZones: assignmentResults.map((result) => ({
        zoneId: result.zoneId,
        riderId: result.riderId,
        orderIds: result.orderIds,
        routeOrder: result.routeOrder,
        orderCount: result.orderIds.length,
      })),
      totalOrders: assignmentResults.reduce(
        (sum, result) => sum + result.orderIds.length,
        0
      ),
      date: body.date || null,
    },
    'Zones assigned to riders'
  );
});

module.exports = {
  getMe,
  listAvailableOrders,
  listOrdersForDeliveryApp,
  acceptOrder,
  rejectOrder,
  markOrderFailedDelivery,
  confirmOrderReturnToStore,
  reportOperationalException,
  updateDeliveryOrderStatus,
  updateLocation,
  getEarnings,
  toggleOnline,
  updateProfile,
  getMyOptimizedRoute,
  getOptimizedRouteForRider,
  getAdminOptimizedRoute,
  assignMultiRiderRoutes,
  bulkAssignZones,
};

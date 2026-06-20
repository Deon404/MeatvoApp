const asyncHandler = require('express-async-handler');
const { pool, withTransaction, query } = require('../../db/postgres');
const { ok, created, fail } = require('../../utils/response');
const { ROLES } = require('../../utils/roles');
const { emitToRole, emitToUser } = require('../../socket/socket');
const { readCartMap, clearCart } = require('../cart/cart.service');
const { logger } = require('../../utils/logger');
const { addressToText } = require('../../utils/address');
const { canTransition } = require('../../utils/orderStateMachine');
const { ensureOrderAssigned } = require('../../services/assignment.service');

// Enhanced lifecycle imports
const {
  transitionOrderState,
  ORDER_STATES: ENHANCED_ORDER_STATES,
} = require('../../services/orderLifecycle.service');
const {
  sendOrderStateNotifications,
  sendCustomNotification,
} = require('../../services/notification.service');
const { createDeliveryOTP } = require('../../services/deliveryProof.service');
const { signStoredImageUrl } = require('../../utils/uploadSigning');
const { validateCouponForOrder } = require('../coupons/coupons.service');
const { haversineKm } = require('../delivery/route-optimizer');
const { getStoreSettings } = require('../settings/settings.controller');
const { resolveUnitSalePrice } = require('../../utils/productPricing.util');
const { resolveDeliveryCharge } = require('../../utils/orderPricing.util');
const { calculateExpressETA, calculateRiderTrackingETA } = require('../../utils/eta-calculator');

/** Push/SMS/OTP after checkout — must not block the HTTP response (FCM can take 8s+ per user). */
function schedulePostOrderSideEffects({
  result,
  customerId,
  customerPhone,
  io,
}) {
  setImmediate(() => {
    void (async () => {
      try {
        await sendOrderStateNotifications({
          orderId: result.order.id,
          newState: result.order.status,
          customerId,
          context: {
            customerPhone,
            orderAmount: result.pricing.totalAmount,
          },
          io,
        });
      } catch (error) {
        logger.error('post_order_notifications_failed', {
          orderId: result.order.id,
          error: error.message,
        });
      }

      if (result.order.payment_mode === 'COD') {
        try {
          await createDeliveryOTP(result.order.id);
          logger.info('delivery_otp_created_for_cod', { orderId: result.order.id });
        } catch (error) {
          logger.warn('delivery_otp_creation_failed', { error: error.message });
        }
      }
    })();
  });
}

const applyCoupon = asyncHandler(async (req, res) => {
  const code = req.validated.body.code;
  const orderTotal = Number(req.validated.body.orderTotal || 0);
  const userId = req.user?.id != null ? String(req.user.id) : undefined;

  const result = await validateCouponForOrder({
    code,
    orderAmount: orderTotal,
    userId,
  });
  if (!result.valid) {
    return fail(res, 400, result.reason);
  }

  const finalTotal = Math.max(0, orderTotal - result.discountAmount);
  return ok(
    res,
    {
      valid: true,
      discount: result.discountAmount,
      discountAmount: result.discountAmount,
      discountType: result.discountType,
      discountValue: result.discountValue,
      finalTotal,
      code: result.coupon.code,
    },
    'Coupon applied'
  );
});

const createOrder = asyncHandler(async (req, res) => {
  const customerId = Number(req.user.id);
  const customerPhone = req.user.phone;
  const {
    deliveryAddress,
    paymentMethod,
    lat,
    lng,
    addressId,
  } = req.validated.body;

  if (!deliveryAddress || deliveryAddress.trim().length < 10) {
    return fail(res, 400, 'Delivery address must be at least 10 characters');
  }

  const storeSettings = await getStoreSettings();
  if (!Boolean(storeSettings.is_open)) {
    return fail(
      res,
      400,
      storeSettings.closed_message ||
        'Store is closed — orders resume when we open',
      {
        code: 'STORE_CLOSED',
        closedReason: storeSettings.closed_reason ?? null,
        closedMessage: storeSettings.closed_message ?? null,
        nextOpenDisplay: storeSettings.next_open_display ?? null,
        storeOpenTime: storeSettings.store_open_time ?? null,
      }
    );
  }

  if (!['COD', 'ONLINE'].includes(paymentMethod?.toUpperCase())) {
    return fail(res, 400, 'paymentMethod must be "COD" or "ONLINE"');
  }

  let validatedAddressId = null;
  if (addressId != null && addressId !== '') {
    const aid = Number(addressId);
    if (!Number.isFinite(aid) || aid <= 0) {
      return fail(res, 400, 'Invalid addressId');
    }
    const { rows: addrRows } = await query(
      'SELECT id FROM addresses WHERE id = $1 AND user_id = $2',
      [aid, customerId]
    );
    if (!addrRows[0]) {
      return fail(res, 403, 'Address does not belong to your account');
    }
    validatedAddressId = aid;
  }

  // Order is built exclusively from the Redis cart (source of truth).
  const cartMap = await readCartMap(customerId);
  const quantities = new Map();

  for (const [productId, quantity] of Object.entries(cartMap || {})) {
    const pid = Number(productId);
    const qty = Number(quantity);
    if (Number.isFinite(pid) && pid > 0 && Number.isFinite(qty) && qty > 0) {
      quantities.set(pid, qty);
    }
  }

  const bodyItems = Array.isArray(req.body?.items) ? req.body.items : [];
  if (bodyItems.length > 0 && quantities.size > 0) {
    const clientMap = new Map();
    for (const raw of bodyItems) {
      const pid = Number(raw?.productId ?? raw?.product_id);
      const qty = Number(raw?.quantity);
      if (Number.isFinite(pid) && pid > 0 && Number.isFinite(qty) && qty > 0) {
        clientMap.set(pid, qty);
      }
    }
    const keys = new Set([...quantities.keys(), ...clientMap.keys()]);
    for (const pid of keys) {
      if (quantities.get(pid) !== clientMap.get(pid)) {
        logger.warn('cart_client_mismatch', {
          customerId,
          productId: pid,
          serverQty: quantities.get(pid) ?? 0,
          clientQty: clientMap.get(pid) ?? 0,
        });
        break;
      }
    }
  }

  const items = Array.from(quantities.entries()).map(([product_id, quantity]) => ({
    product_id,
    quantity,
  }));

  if (!items.length) {
    return fail(res, 400, 'Cart is empty. Add items via /api/cart before checkout.');
  }

  const result = await pool.transaction(async (client) => {
    const productIds = items.map(i => i.product_id);

    const prodRes = await client.query(
      `SELECT id, price, base_price_per_kg, weight_variants, stock, active
       FROM products WHERE id = ANY($1::bigint[]) FOR UPDATE`,
      [productIds]
    );
    const products = prodRes.rows;
    if (products.length !== productIds.length) {
      const err = new Error('Product not found');
      err.statusCode = 404;
      throw err;
    }

    const productById = new Map(products.map(p => [Number(p.id), p]));

    let subtotal = 0;
    for (const item of items) {
      const p = productById.get(item.product_id);
      if (!p || !p.active) {
        const err = new Error('Product inactive');
        err.statusCode = 400;
        throw err;
      }
      if (Number(p.stock) < item.quantity) {
        const err = new Error('Insufficient stock');
        err.statusCode = 400;
        throw err;
      }
      subtotal += resolveUnitSalePrice(p) * item.quantity;
    }

    const deliveryCharge = resolveDeliveryCharge(subtotal, storeSettings);
    const totalAmount = subtotal + deliveryCharge;

    const payment_mode = paymentMethod.toUpperCase();
    const shouldDeductStockNow = payment_mode === 'COD';

    // COD orders deduct immediately, ONLINE orders deduct only after payment success.
    if (shouldDeductStockNow) {
      for (const item of items) {
        await client.query('UPDATE products SET stock = stock - $1 WHERE id = $2', [
          item.quantity,
          item.product_id
        ]);
      }
    }

    // Create order
    const address = {
      text: deliveryAddress.trim(),
      raw: deliveryAddress.trim(),
      deliveryType: 'express',
    };
    const parsedLat = Number(lat);
    const parsedLng = Number(lng);
    if (Number.isFinite(parsedLat) && Number.isFinite(parsedLng)) {
      address.lat = parsedLat;
      address.lng = parsedLng;
    }
    if (validatedAddressId) {
      address.addressId = validatedAddressId;
    }
    const status = payment_mode === 'COD' ? 'CONFIRMED' : 'PLACED';

    const oRes = await client.query(
      `INSERT INTO orders (customer_id, status, total_amount, address, payment_mode)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING id, customer_id, status, total_amount, address, payment_mode, created_at`,
      [customerId, status, totalAmount, address, payment_mode]
    );
    const order = oRes.rows[0];

    // Order items
    const orderIds = [];
    const productIdsForInsert = [];
    const itemQuantities = [];
    const itemPrices = [];
    for (const item of items) {
      const p = productById.get(item.product_id);
      orderIds.push(order.id);
      productIdsForInsert.push(item.product_id);
      itemQuantities.push(item.quantity);
      itemPrices.push(resolveUnitSalePrice(p));
    }
    await client.query(
      `INSERT INTO order_items (order_id, product_id, quantity, price)
       SELECT * FROM UNNEST($1::bigint[], $2::bigint[], $3::integer[], $4::numeric[])`,
      [orderIds, productIdsForInsert, itemQuantities, itemPrices]
    );

    return {
      order,
      pricing: { subtotal, deliveryCharge, totalAmount }
    };
  });

  await clearCart(customerId);
  logger.info('order_created', { orderId: result.order.id, customerId });

  // Express ETA: prep queue + realistic travel speed (not raw map driving time).
  try {
    const orderAddress = result.order.address;
    const deliveryLat = Number(orderAddress?.lat);
    const deliveryLng = Number(orderAddress?.lng);

    if (Number.isFinite(deliveryLat) && Number.isFinite(deliveryLng)) {
      const centerLat = Number(storeSettings.center_lat || 23.6583);
      const centerLng = Number(storeSettings.center_lng || 86.1764);
      const distanceKm = haversineKm(centerLat, centerLng, deliveryLat, deliveryLng);

      let queueDepth = 0;
      try {
        const { rows: queueRows } = await query(
          `SELECT COUNT(*)::int AS count
           FROM orders
           WHERE status IN ('CONFIRMED', 'PACKING_STARTED', 'PACKED')`
        );
        queueDepth = Number(queueRows[0]?.count || 0);
      } catch (queueErr) {
        logger.warn('order_eta_queue_failed', { message: queueErr?.message });
      }

      const etaResult = calculateExpressETA({
        placedAt: new Date(),
        items,
        queueDepth,
        distanceKm,
      });

      const etaMinutes = etaResult.breakdown.totalMinutes;
      const etaTime = etaResult.etaTime;
      const etaDisplay = etaResult.etaDisplay;

      await query(
        `UPDATE orders
         SET estimated_delivery_time = $1, eta_minutes = $2
         WHERE id = $3`,
        [etaTime, etaMinutes, result.order.id]
      );

      result.order.estimated_delivery_time = etaTime;
      result.order.eta_minutes = etaMinutes;
      result.eta = {
        estimatedTime: etaTime,
        etaDisplay,
        displayTime: etaDisplay,
        minutes: etaMinutes,
        distanceKm: etaResult.breakdown.distanceKm,
        breakdown: etaResult.breakdown,
      };

      logger.info('eta_calculated', {
        orderId: result.order.id,
        distanceKm: etaResult.breakdown.distanceKm,
        etaMinutes,
        etaDisplay,
        breakdown: etaResult.breakdown,
      });
    }
  } catch (error) {
    logger.warn('eta_calculation_failed', {
      orderId: result.order.id,
      error: error.message,
    });
  }

  const io = req.app.get('io');

  // Real-time socket events are instant — keep on the hot path.
  if (io) {
    const newOrderPayload = {
      orderId: result.order.id,
      customerPhone: customerPhone,
      totalAmount: result.pricing.totalAmount,
      createdAt: new Date().toISOString(),
    };
    io.to('admin_room').emit('order:new', newOrderPayload);
    if (result.order.status === 'CONFIRMED') {
      io.to('staff_room').emit('order:new', newOrderPayload);
    }
  }

  // FCM + DB notifications and delivery OTP run after the client gets a response.
  schedulePostOrderSideEffects({
    result,
    customerId,
    customerPhone,
    io,
  });

  return ok(res, result, 'Order created successfully');
});

const listOrders = asyncHandler(async (req, res) => {
  const limit = Number(req.validated?.query?.limit || 50);
  const offset = Number(req.validated?.query?.offset || 0);

  const isAdmin = req.user.role === ROLES.ADMIN;
  const isCustomer = req.user.role === ROLES.CUSTOMER;
  const isDelivery = req.user.role === ROLES.DELIVERY;

  let sql = `
    SELECT o.id, o.customer_id, o.status, o.total_amount, o.coupon_id, o.address, o.payment_mode, o.created_at
    FROM orders o
  `;
  const params = [];
  const conditions = [];
  const nextParam = (value) => {
    params.push(value);
    return `$${params.length}`;
  };

  if (isCustomer) {
    const customerIdParam = nextParam(Number(req.user.id));
    conditions.push(`o.customer_id = ${customerIdParam}`);
  } else if (isDelivery) {
    // Delivery sees assigned orders
    sql += ' JOIN order_assignments oa ON oa.order_id = o.id JOIN delivery_partners dp ON dp.id = oa.delivery_partner_id ';
    const deliveryUserParam = nextParam(Number(req.user.id));
    conditions.push(`dp.user_id = ${deliveryUserParam}`);
  } else if (!isAdmin) {
    return fail(res, 403, 'Not allowed');
  }

  const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';
  const limitParam = nextParam(limit);
  const offsetParam = nextParam(offset);

  const { rows } = await query(
    `${sql} ${where} ORDER BY o.created_at DESC LIMIT ${limitParam} OFFSET ${offsetParam}`,
    params
  );
  return ok(res, { orders: rows }, 'Orders');
});

const getOrder = asyncHandler(async (req, res) => {
  const orderId = Number(req.validated.params.id);

  const { rows: orderRows } = await query(
    `SELECT o.id, o.customer_id, o.status, o.total_amount, o.coupon_id, o.address, o.payment_mode, o.created_at,
            o.estimated_delivery_time, o.eta_minutes, o.delivery_slot_id,
            ds.name AS slot_name, ds.start_time AS slot_start_time, ds.end_time AS slot_end_time
     FROM orders o
     LEFT JOIN delivery_slots ds ON ds.id = o.delivery_slot_id
     WHERE o.id = $1`,
    [orderId]
  );
  const order = orderRows[0];
  if (!order) return fail(res, 404, 'Order not found');

  const isAdmin = req.user.role === ROLES.ADMIN;
  const isOwner = Number(order.customer_id) === Number(req.user.id);

  let isDeliveryAssigned = false;
  if (req.user.role === ROLES.DELIVERY) {
    const { rows } = await query(
      `SELECT oa.id
       FROM order_assignments oa
       JOIN delivery_partners dp ON dp.id = oa.delivery_partner_id
       WHERE oa.order_id = $1 AND dp.user_id = $2`,
      [orderId, Number(req.user.id)]
    );
    isDeliveryAssigned = Boolean(rows[0]);
  }

  if (!isAdmin && !isOwner && !isDeliveryAssigned) return fail(res, 403, 'Not allowed');

  const { rows: items } = await query(
    `SELECT oi.id, oi.product_id, oi.quantity, oi.price,
            p.name, p.image_url, p.unit
     FROM order_items oi
     JOIN products p ON p.id = oi.product_id
     WHERE oi.order_id = $1`,
    [orderId]
  );

  const { rows: assignmentRows } = await query(
    `SELECT oa.id, oa.order_id, oa.delivery_partner_id, oa.assigned_at, oa.status,
            oa.delivery_image_url, oa.delivery_notes,
            dp.is_online, dp.current_lat, dp.current_lng, dp.vehicle_type,
            u.id AS user_id, u.phone AS user_phone, u.name AS user_name
     FROM order_assignments oa
     JOIN delivery_partners dp ON dp.id = oa.delivery_partner_id
     JOIN users u ON u.id = dp.user_id
     WHERE oa.order_id = $1
     ORDER BY CASE WHEN oa.status::text = 'CANCELLED' THEN 1 ELSE 0 END,
              oa.assigned_at DESC
     LIMIT 1`,
    [orderId]
  );

  const baseUrl = `${req.protocol}://${req.get('host')}`;
  const signedItems = items.map((item) => ({
    ...item,
    image_url: signStoredImageUrl(item.image_url || '', baseUrl),
  }));

  const assignment = assignmentRows[0]
    ? {
        ...assignmentRows[0],
        delivery_image_url: assignmentRows[0].delivery_image_url
          ? signStoredImageUrl(assignmentRows[0].delivery_image_url, baseUrl)
          : null,
      }
    : null;

  const orderWithRider = order && assignment
    ? {
        ...order,
        rider_id: assignment.user_id,
        rider_name: assignment.user_name,
        rider_phone: assignment.user_phone,
        rider_latitude: assignment.current_lat,
        rider_longitude: assignment.current_lng,
      }
    : order;

  const formatSlotTime = (value) => {
    if (!value) return '';
    const text = String(value);
    return text.length >= 5 ? text.slice(0, 5) : text;
  };

  if (orderWithRider?.slot_name) {
    const start = formatSlotTime(orderWithRider.slot_start_time);
    const end = formatSlotTime(orderWithRider.slot_end_time);
    orderWithRider.delivery_slot_label =
      end && start ? `${orderWithRider.slot_name} (${start}–${end})` : orderWithRider.slot_name;
  }

  // Refresh ETA from rider GPS → customer (fixes stale eta_minutes in DB).
  if (orderWithRider && assignment?.current_lat && assignment?.current_lng) {
    try {
      const addr =
        typeof orderWithRider.address === 'string'
          ? JSON.parse(orderWithRider.address)
          : orderWithRider.address;
      const deliveryLat = Number(addr?.lat);
      const deliveryLng = Number(addr?.lng);
      if (Number.isFinite(deliveryLat) && Number.isFinite(deliveryLng)) {
        const etaResult = calculateRiderTrackingETA({
          orderStatus: orderWithRider.status,
          riderLat: assignment.current_lat,
          riderLng: assignment.current_lng,
          deliveryLat,
          deliveryLng,
          items: items.map((item) => ({ quantity: item.quantity })),
        });
        if (etaResult) {
          orderWithRider.eta_minutes = etaResult.etaMinutes;
          orderWithRider.estimated_delivery_time = etaResult.etaTime;
          orderWithRider.rider_distance_km = etaResult.distanceKm;

          await query(
            `UPDATE orders
             SET eta_minutes = $1, estimated_delivery_time = $2
             WHERE id = $3`,
            [etaResult.etaMinutes, etaResult.etaTime, orderId]
          );
        }
      }
    } catch (etaErr) {
      logger.warn('order_get_eta_refresh_failed', {
        orderId,
        error: etaErr.message,
      });
    }
  }

  const io = req.app.get('io');
  const normalizedStatus = String(order.status || '').toUpperCase();
  if (!assignment && normalizedStatus === 'PACKED') {
    ensureOrderAssigned({ orderId, io }).catch((err) => {
      logger.error('ensure_order_assigned_failed', {
        orderId,
        error: err.message,
      });
    });
  }

  return ok(res, { order: orderWithRider, items: signedItems, assignment }, 'Order');
});

const updateOrderStatus = asyncHandler(async (req, res) => {
  const orderId = Number(req.validated.params.id);
  const status = req.validated.body.status;
  const io = req.app.get('io');

  // Get current order details
  const { rows } = await query('SELECT status, customer_id FROM orders WHERE id = $1', [orderId]);
  const currentStatus = rows[0]?.status;
  if (!currentStatus) return fail(res, 404, 'Order not found');

  if (String(currentStatus).toUpperCase() === String(status).toUpperCase()) {
    const { rows: orderRows } = await query(
      `SELECT id, customer_id, status, total_amount, coupon_id, address, payment_mode, created_at
       FROM orders WHERE id = $1`,
      [orderId]
    );
    return ok(res, { order: orderRows[0] }, 'Order status unchanged');
  }
  
  // Basic transition validation (still using old canTransition for backward compatibility)
  if (!canTransition(currentStatus, status)) {
    return fail(res, 400, `Cannot change order from ${currentStatus} to ${status}`);
  }

  // Determine actor role
  let actorRole = req.user.role;
  if (actorRole === 'delivery') {
    actorRole = 'rider';
  }

  const customerId = Number(rows[0].customer_id);

  // Customers may only update their own orders
  if (req.user.role === ROLES.CUSTOMER) {
    if (customerId !== Number(req.user.id)) {
      return fail(res, 403, 'You can only update your own orders');
    }
    const allowedCustomer = new Set(['CANCELLED']);
    if (!allowedCustomer.has(status)) {
      return fail(res, 403, 'Customers cannot set this order status');
    }
  }

  // For delivery partners, verify assignment
  if (req.user.role === ROLES.DELIVERY) {
    const { rows: assignmentRows } = await query(
      `SELECT oa.id
       FROM order_assignments oa
       JOIN delivery_partners dp ON dp.id = oa.delivery_partner_id
       WHERE oa.order_id = $1 AND dp.user_id = $2`,
      [orderId, Number(req.user.id)]
    );
    if (!assignmentRows[0]) return fail(res, 403, 'Order not assigned to you');

    const allowed = new Set(['OUT_FOR_DELIVERY', 'DELIVERED']);
    if (!allowed.has(status)) return fail(res, 400, 'Status not allowed for delivery partner');
  }

  try {
    // Use enhanced lifecycle service for state transition
    const result = await transitionOrderState({
      orderId,
      newState: status,
      actor: req.user.id,
      actorRole,
      context: { notes: req.body.notes },
      io,
    });

    // Get updated order
    const { rows: updatedRows } = await query(
      `SELECT id, customer_id, status, total_amount, coupon_id, address, payment_mode, created_at
       FROM orders WHERE id = $1`,
      [orderId]
    );

    // Update assignment status if delivered
    if (status === 'DELIVERED' && req.user.role === ROLES.DELIVERY) {
      await query('UPDATE order_assignments SET status = $1 WHERE order_id = $2', [
        'DELIVERED',
        orderId,
      ]);
    }

    return ok(res, { order: updatedRows[0], transition: result }, 'Order status updated');
  } catch (error) {
    logger.error('update_order_status_failed', {
      error: error.message,
      orderId,
      status,
      userId: req.user.id,
    });
    const clientError =
      /invalid transition|cannot trigger|payment must be|not found/i.test(
        error.message || '',
      );
    return fail(
      res,
      clientError ? 400 : 500,
      error.message || 'Failed to update order status',
    );
  }
});

// PUT /api/orders/:id/cancel - user only PLACED orders
const cancelOrder = asyncHandler(async (req, res) => {
  const orderId = Number(req.params.id || req.validated?.params?.id);
  const customerId = Number(req.user.id);

  const { rows } = await query(
    'SELECT id, status, customer_id, address FROM orders WHERE id = $1',
    [orderId]
  );
  const order = rows[0];
  if (!order) return fail(res, 404, 'Order not found');
  if (Number(order.customer_id) !== customerId) {
    return fail(res, 403, 'Not your order');
  }
  if (!['PLACED', 'CONFIRMED'].includes(order.status)) {
    return fail(res, 400, 'Order can only be cancelled from PLACED or CONFIRMED');
  }

  await withTransaction(async (client) => {
    // Restore stock
    const { rows: items } = await client.query(
      `SELECT oi.product_id, oi.quantity 
       FROM order_items oi WHERE oi.order_id = $1`,
      [orderId]
    );

    for (const item of items) {
      await client.query(
        'UPDATE products SET stock = stock + $1 WHERE id = $2',
        [item.quantity, item.product_id]
      );
    }

    // Update order
    await client.query(
      'UPDATE orders SET status = $1 WHERE id = $2',
      ['CANCELLED', orderId]
    );
  });

  logger.info('order_cancelled', { orderId, customerId });

  const io = req.app.get('io');
  
  // Send enhanced cancellation notifications
  await sendOrderStateNotifications({
    orderId,
    newState: 'CANCELLED',
    customerId,
    context: {
      reason: req.body.reason || 'Customer requested cancellation',
    },
    io,
  });

  // Backward compatibility - emit old events
  if (io) {
    const payload = {
      orderId,
      status: 'CANCELLED',
      timestamp: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };
    io.to(`customer_${customerId}`).emit('order:status_update', payload);
    io.to(`customer_${customerId}`).emit('order:status_updated', payload);
    io.to('admin_room').emit('order:updated', payload);
    io.to('staff_room').emit('order:updated', payload);
  }

  return ok(res, {}, 'Order cancelled, stock restored');
});

// GET /api/orders - paginated user orders
const getOrders = asyncHandler(async (req, res) => {
  const page = Number(req.query.page) || 1;
  const limit = Number(req.query.limit) || 50;
  const offset = (page - 1) * limit;
  const customerId = Number(req.user.id);

  const params = [customerId, limit, offset];
  const { rows } = await query(
    `SELECT id, status, total_amount, address, payment_mode, created_at,
            estimated_delivery_time, eta_minutes
     FROM orders WHERE customer_id = $1 
     ORDER BY created_at DESC LIMIT $2 OFFSET $3`,
    params
  );

  let ordersWithItems = rows;
  if (rows.length > 0) {
    const orderIds = rows.map((row) => row.id);
    const { rows: itemRows } = await query(
      `SELECT oi.order_id, oi.product_id, oi.quantity, oi.price,
              p.name, p.image_url, p.unit
       FROM order_items oi
       JOIN products p ON p.id = oi.product_id
       WHERE oi.order_id = ANY($1::int[])
       ORDER BY oi.order_id, oi.id`,
      [orderIds]
    );

    const itemsByOrderId = itemRows.reduce((acc, item) => {
      const orderId = item.order_id;
      if (!acc[orderId]) acc[orderId] = [];
      acc[orderId].push({
        product_id: item.product_id,
        quantity: item.quantity,
        price: item.price,
        name: item.name,
        image_url: item.image_url,
        unit: item.unit,
      });
      return acc;
    }, {});

    const baseUrl = `${req.protocol}://${req.get('host')}`;
    ordersWithItems = rows.map((order) => ({
      ...order,
      items: (itemsByOrderId[order.id] || []).map((item) => ({
        ...item,
        image_url: signStoredImageUrl(item.image_url || '', baseUrl),
      })),
    }));
  }

  const countParams = [customerId];
  const countRes = await query('SELECT COUNT(*)::int AS total FROM orders WHERE customer_id = $1', countParams);
  const total = Number(countRes.rows[0].total);
  const pages = Math.ceil(total / limit);

  return ok(res, { orders: ordersWithItems, total, page, pages, limit });
});

// Admin GET /api/admin/orders paginated all
const getAllOrders = asyncHandler(async (req, res) => {
  if (req.user.role !== ROLES.ADMIN) return fail(res, 403, 'Admin only');

  const page = Number(req.query.page) || 1;
  const limit = Number(req.query.limit) || 20;
  const offset = (page - 1) * limit;
  const status = req.query.status;
  const userPhone = req.query.user;

  const conditions = [];
  const params = [];
  const nextParam = (value) => {
    params.push(value);
    return `$${params.length}`;
  };

  if (status) {
    const statusParam = nextParam(status);
    conditions.push(`o.status = ${statusParam}`);
  }
  if (userPhone) {
    const userPhoneParam = nextParam(userPhone);
    conditions.push(`u.phone = ${userPhoneParam}`);
  }

  const whereClause = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';

  const limitParam = nextParam(limit);
  const offsetParam = nextParam(offset);
  const listSql = `
    SELECT o.id, o.status, o.total_amount, o.address, o.payment_mode, o.created_at, u.phone as customer_phone
    FROM orders o
    LEFT JOIN users u ON u.id = o.customer_id
    ${whereClause}
    ORDER BY o.created_at DESC
    LIMIT ${limitParam} OFFSET ${offsetParam}
  `;
  const { rows: orders } = await query(listSql, params);

  const countSql = `
    SELECT COUNT(*)::int AS total
    FROM orders o
    LEFT JOIN users u ON u.id = o.customer_id
    ${whereClause}
  `;
  const countRes = await query(countSql, params.slice(0, params.length - 2));
  const total = Number(countRes.rows[0].total);
  const pages = Math.ceil(total / limit);

  return ok(res, { orders, total, page, pages, limit });
});

module.exports = {
  createOrder,
  getOrders,
  cancelOrder,
  getAllOrders,
  getOrder,
  listOrders,
  updateOrderStatus,
  applyCoupon,
};



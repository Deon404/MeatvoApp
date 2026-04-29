const asyncHandler = require('express-async-handler');
const { withTransaction, query } = require('../../db/postgres');
const { ok, created, fail } = require('../../utils/response');
const { ROLES } = require('../../utils/roles');
const { emitToRole, emitToUser } = require('../../socket/socket');
const { readCartMap, clearCart } = require('../cart/cart.service');
const { logger } = require('../../utils/logger');

const STATUS_TRANSITIONS = Object.freeze({
  PLACED: new Set(['CONFIRMED', 'CANCELLED']),
  CONFIRMED: new Set(['PACKED', 'CANCELLED']),
  PACKED: new Set(['OUT_FOR_DELIVERY']),
  OUT_FOR_DELIVERY: new Set(['DELIVERED']),
  DELIVERED: new Set([]),
  CANCELLED: new Set([]),
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

const computeDiscount = ({ discount_type, discount_value }, amount) => {
  if (discount_type === 'FLAT') return Math.min(amount, Number(discount_value));
  const pct = Number(discount_value);
  return Math.min(amount, (amount * pct) / 100);
};

const applyCoupon = asyncHandler(async (req, res) => {
  const code = String(req.validated.body.code || '').toUpperCase();
  const orderTotal = Number(req.validated.body.orderTotal || 0);

  const { rows } = await query(
    `SELECT id, code, discount_type, discount_value, min_order_value, max_uses, used_count, active
     FROM coupons
     WHERE code = $1`,
    [code]
  );
  const coupon = rows[0];
  if (!coupon || !coupon.active) return fail(res, 400, 'Invalid coupon');
  if (orderTotal < Number(coupon.min_order_value || 0)) {
    return fail(res, 400, 'Order amount too low for this coupon');
  }
  if (coupon.max_uses !== null && Number(coupon.used_count) >= Number(coupon.max_uses)) {
    return fail(res, 400, 'Coupon usage limit reached');
  }

  const discount = computeDiscount(coupon, orderTotal);
  const finalTotal = Math.max(0, orderTotal - discount);
  return ok(res, { discount, finalTotal, code: coupon.code }, 'Coupon applied');
});

const createOrder = asyncHandler(async (req, res) => {
  const customerId = Number(req.user.id);
  const customerPhone = req.user.phone;
  const { deliveryAddress, paymentMethod } = req.validated.body;

  if (!deliveryAddress || deliveryAddress.trim().length < 10) {
    return fail(res, 400, 'Delivery address must be at least 10 characters');
  }

  if (!['COD', 'ONLINE'].includes(paymentMethod?.toUpperCase())) {
    return fail(res, 400, 'paymentMethod must be "COD" or "ONLINE"');
  }

  // Get cart
  const cartMap = await readCartMap(customerId);
  const itemsInput = Object.entries(cartMap || {})
    .map(([productId, quantity]) => ({ product_id: Number(productId), quantity: Number(quantity) }))
    .filter(it => Number.isFinite(it.product_id) && it.product_id > 0 && Number.isFinite(it.quantity) && it.quantity > 0);

  if (!itemsInput.length) return fail(res, 400, 'Cart is empty');

  // Merge & validate
  const quantities = new Map();
  for (const item of itemsInput) {
    quantities.set(item.product_id, (quantities.get(item.product_id) || 0) + item.quantity);
  }
  const items = Array.from(quantities.entries()).map(([product_id, quantity]) => ({ product_id, quantity }));

  const result = await withTransaction(async (client) => {
    const productIds = items.map(i => i.product_id);

    const prodRes = await client.query(
      'SELECT id, price, stock, active FROM products WHERE id = ANY($1::bigint[]) FOR UPDATE',
      [productIds]
    );
    const products = prodRes.rows;
    if (products.length !== productIds.length) throw new Error('Product not found');

    const productById = new Map(products.map(p => [Number(p.id), p]));

    let subtotal = 0;
    for (const item of items) {
      const p = productById.get(item.product_id);
      if (!p || !p.active) throw new Error('Product inactive');
      if (Number(p.stock) < item.quantity) throw new Error('Insufficient stock');
      subtotal += Number(p.price) * item.quantity;
    }

    // Delivery charge
    const deliveryCharge = subtotal >= 500 ? 0 : 40;
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
      raw: deliveryAddress.trim()
    };
    const status = 'PLACED';

    const oRes = await client.query(
      `INSERT INTO orders (customer_id, status, total_amount, address, payment_mode)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING id, customer_id, status, total_amount, address, payment_mode, created_at`,
      [customerId, status, totalAmount, address, payment_mode]
    );
    const order = oRes.rows[0];

    // Order items
    const values = [];
    const placeholders = [];
    for (let i = 0; i < items.length; i++) {
      const item = items[i];
      const p = productById.get(item.product_id);
      const base = i * 4;
      placeholders.push(`($${base + 1}, $${base + 2}, $${base + 3}, $${base + 4})`);
      values.push(order.id, item.product_id, item.quantity, Number(p.price));
    }
    await client.query(
      `INSERT INTO order_items (order_id, product_id, quantity, price) VALUES ${placeholders.join(',')}`,
      values
    );

    return {
      order,
      pricing: { subtotal, deliveryCharge, totalAmount }
    };
  });

  await clearCart(customerId);
  logger.info('order_created', { orderId: result.order.id, customerId });

  // Emit new order to admin room
  const io = req.app.get('io');
  if (io) {
    io.to('admin_room').emit('order:new', {
      orderId: result.order.id,
      customerPhone: customerPhone,
      totalAmount: result.pricing.totalAmount,
      createdAt: new Date().toISOString()
    });
  }

  return res.json({
    success: true,
    data: result,
    message: 'Order created successfully'
  });
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

  if (isCustomer) {
    params.push(Number(req.user.id));
    conditions.push(`o.customer_id = $${params.length}`);
  } else if (isDelivery) {
    // Delivery sees assigned orders
    sql += ' JOIN order_assignments oa ON oa.order_id = o.id JOIN delivery_partners dp ON dp.id = oa.delivery_partner_id ';
    params.push(Number(req.user.id));
    conditions.push(`dp.user_id = $${params.length}`);
  } else if (!isAdmin) {
    return fail(res, 403, 'Not allowed');
  }

  const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';
  params.push(limit);
  const limitIdx = params.length;
  params.push(offset);
  const offsetIdx = params.length;

  const { rows } = await query(
    `${sql} ${where} ORDER BY o.created_at DESC LIMIT $${limitIdx} OFFSET $${offsetIdx}`,
    params
  );
  return ok(res, { orders: rows }, 'Orders');
});

const getOrder = asyncHandler(async (req, res) => {
  const orderId = Number(req.validated.params.id);

  const { rows: orderRows } = await query(
    `SELECT o.id, o.customer_id, o.status, o.total_amount, o.coupon_id, o.address, o.payment_mode, o.created_at
     FROM orders o
     WHERE o.id = $1`,
    [orderId]
  );
  const order = orderRows[0];
  if (!order) return fail(res, 404, 'Order not found');

  const isAdmin = req.user.role === ROLES.ADMIN;
  const isCustomer = req.user.role === ROLES.CUSTOMER && Number(order.customer_id) === Number(req.user.id);

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

  if (!isAdmin && !isCustomer && !isDeliveryAssigned) return fail(res, 403, 'Not allowed');

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
            dp.is_online, dp.current_lat, dp.current_lng, dp.vehicle_type,
            u.id AS user_id, u.phone AS user_phone, u.name AS user_name
     FROM order_assignments oa
     JOIN delivery_partners dp ON dp.id = oa.delivery_partner_id
     JOIN users u ON u.id = dp.user_id
     WHERE oa.order_id = $1`,
    [orderId]
  );

  return ok(res, { order, items, assignment: assignmentRows[0] || null }, 'Order');
});

const updateOrderStatus = asyncHandler(async (req, res) => {
  const orderId = Number(req.validated.params.id);
  const status = req.validated.body.status;

  const { rows: orderRows } = await query('SELECT id, customer_id, status FROM orders WHERE id = $1', [
    orderId,
  ]);
  const order = orderRows[0];
  if (!order) return fail(res, 404, 'Order not found');

  if (req.user.role === ROLES.ADMIN) {
    if (!canTransition(order.status, status)) {
      return fail(res, 400, `Invalid transition from ${order.status} to ${status}`);
    }

    const { rows } = await query(
      `UPDATE orders SET status = $1 WHERE id = $2
       RETURNING id, customer_id, status, total_amount, coupon_id, address, payment_mode, created_at`,
      [status, orderId]
    );
    
    // Emit to customer room
    const io = req.app.get('io');
    if (io) {
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
      
      // Emit to admin room
      io.to('admin_room').emit('order:updated', {
        orderId: orderId,
        status: status,
        updatedAt: new Date().toISOString()
      });
    }
    
    return ok(res, { order: rows[0] }, 'Order status updated');
  }

  if (req.user.role === ROLES.DELIVERY) {
    // Delivery can update only assigned orders
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
    if (!canTransition(order.status, status)) {
      return fail(res, 400, `Invalid transition from ${order.status} to ${status}`);
    }

    await withTransaction(async (client) => {
      await client.query('UPDATE orders SET status = $1 WHERE id = $2', [status, orderId]);
      if (status === 'DELIVERED') {
        await client.query('UPDATE order_assignments SET status = $1 WHERE order_id = $2', [
          'DELIVERED',
          orderId,
        ]);
      }
    });

    const { rows } = await query(
      `SELECT id, customer_id, status, total_amount, coupon_id, address, payment_mode, created_at
       FROM orders WHERE id = $1`,
      [orderId]
    );
    
    // Emit to customer and admin rooms
    const io = req.app.get('io');
    if (io) {
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
  }

  return fail(res, 403, 'Not allowed');
});

// PUT /api/orders/:id/cancel - user only PLACED orders
const cancelOrder = asyncHandler(async (req, res) => {
  const orderId = Number(req.params.id || req.validated?.params?.id);
  const customerId = Number(req.user.id);

  const { rows } = await query(
    'SELECT id, status, customer_id FROM orders WHERE id = $1',
    [orderId]
  );
  const order = rows[0];
  if (!order) return fail(res, 404, 'Order not found');
  if (order.customer_id !== customerId) return fail(res, 403, 'Not your order');
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
  return res.json({ success: true, data: { message: 'Order cancelled, stock restored' } });
});

// GET /api/orders - paginated user orders
const getOrders = asyncHandler(async (req, res) => {
  const page = Number(req.query.page) || 1;
  const limit = Number(req.query.limit) || 10;
  const offset = (page - 1) * limit;
  const customerId = Number(req.user.id);

  const params = [customerId, limit, offset];
  const { rows } = await query(
    `SELECT id, status, total_amount, address, payment_mode, created_at 
     FROM orders WHERE customer_id = $1 
     ORDER BY created_at DESC LIMIT $2 OFFSET $3`,
    params
  );

  const countParams = [customerId];
  const countRes = await query('SELECT COUNT(*)::int AS total FROM orders WHERE customer_id = $1', countParams);
  const total = Number(countRes.rows[0].total);
  const pages = Math.ceil(total / limit);

  return res.json({
    success: true,
    data: { orders: rows, total, page, pages, limit }
  });
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

  if (status) {
    params.push(status);
    conditions.push('status = $' + params.length);
  }
  if (userPhone) {
    params.push(userPhone);
    conditions.push('u.phone = $' + params.length);
  }

  const where = conditions.length ? 'WHERE ' + conditions.join(' AND ') : '';
  const countWhere = conditions.length ? 'WHERE ' + conditions.join(' AND ') : '';

  params.push(limit, offset);
  const listSql = `
    SELECT o.id, o.status, o.total_amount, o.address, o.payment_mode, o.created_at, u.phone as customer_phone
    FROM orders o 
    LEFT JOIN users u ON u.id = o.customer_id
    ${where}
    ORDER BY o.created_at DESC 
    LIMIT $${params.length - 1} OFFSET $${params.length}
  `;
  const { rows: orders } = await query(listSql, params);

  const countSql = `SELECT COUNT(*)::int AS total FROM orders o ${countWhere} LEFT JOIN users u ON u.id = o.customer_id`;
  const countRes = await query(countSql, params.slice(0, params.length - 2));
  const total = Number(countRes.rows[0].total);
  const pages = Math.ceil(total / limit);

  return res.json({
    success: true,
    data: { orders, total, page, pages, limit }
  });
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



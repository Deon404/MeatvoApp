const asyncHandler = require('express-async-handler');
const { query } = require('../../db/postgres');
const { ok } = require('../../utils/response');

const KITCHEN_STATUSES = ['CONFIRMED', 'PACKING_STARTED'];

const listKitchenOrders = asyncHandler(async (req, res) => {
  const limit = Number(req.validated?.query?.limit || 100);
  const offset = Number(req.validated?.query?.offset || 0);
  const statusFilter = req.validated?.query?.status;

  const statuses = statusFilter ? [statusFilter] : KITCHEN_STATUSES;
  const params = [statuses, limit, offset];

  const baseSelect = `
    SELECT o.id, o.status, o.total_amount, o.created_at,
           ds.name AS delivery_slot_name,
           ds.start_time AS delivery_slot_start,
           ds.end_time AS delivery_slot_end,
           (EXTRACT(EPOCH FROM o.created_at) * 1000)::bigint AS created_at_ms`;

  const runQuery = async (withSlot) => {
    if (withSlot) {
      return query(
        `${baseSelect}
         FROM orders o
         LEFT JOIN delivery_slots ds ON ds.id = o.delivery_slot_id
         WHERE o.status = ANY($1::order_status[])
         ORDER BY o.created_at ASC
         LIMIT $2 OFFSET $3`,
        params
      );
    }

    return query(
      `${baseSelect},
              NULL::text AS delivery_slot_name,
              NULL::time AS delivery_slot_start,
              NULL::time AS delivery_slot_end
       FROM orders o
       WHERE o.status = ANY($1::order_status[])
       ORDER BY o.created_at ASC
       LIMIT $2 OFFSET $3`,
      params
    );
  };

  let rows;
  try {
    ({ rows } = await runQuery(true));
  } catch (err) {
    if (err?.code === '42703') {
      ({ rows } = await runQuery(false));
    } else {
      throw err;
    }
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

  const orders = rows.map((o) => {
    const orderId = String(o.id);
    const slotName = o.delivery_slot_name || null;
    const slotStart = o.delivery_slot_start || null;
    const slotEnd = o.delivery_slot_end || null;
    const deliverySlot =
      slotName || slotStart || slotEnd
        ? {
            name: slotName,
            startTime: slotStart,
            endTime: slotEnd,
          }
        : null;

    return {
      id: orderId,
      status: o.status,
      totalAmount: Number(o.total_amount || 0),
      createdAt: o.created_at,
      createdAtMs: Number(o.created_at_ms || 0),
      deliverySlot,
      items: itemsByOrderId[orderId] || [],
    };
  });

  return ok(res, { orders, count: orders.length }, 'Kitchen orders');
});

module.exports = {
  listKitchenOrders,
};

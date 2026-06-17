const PRE_STOCK_DEDUCTION_STATUSES = new Set([
  'PLACED',
  'PAYMENT_PENDING',
  'PAYMENT_VERIFIED',
]);

const shouldRestoreStockOnCancel = (currentStatus) => {
  const status = String(currentStatus || '').trim().toUpperCase();
  return status.length > 0 && !PRE_STOCK_DEDUCTION_STATUSES.has(status);
};

const reserveStockForPaidOrder = async (client, orderId) => {
  const { rows: items } = await client.query(
    `SELECT oi.product_id, oi.quantity, p.stock
     FROM order_items oi
     JOIN products p ON p.id = oi.product_id
     WHERE oi.order_id = $1
     FOR UPDATE`,
    [orderId]
  );

  for (const item of items) {
    const available = Number(item.stock || 0);
    const required = Number(item.quantity || 0);
    if (available < required) {
      const err = new Error(`Insufficient stock for product ${item.product_id}`);
      err.statusCode = 400;
      throw err;
    }
  }

  for (const item of items) {
    await client.query('UPDATE products SET stock = stock - $1 WHERE id = $2', [
      Number(item.quantity || 0),
      Number(item.product_id),
    ]);
  }
};

const restoreStockForOrder = async (client, orderId) => {
  const { rows: items } = await client.query(
    `SELECT oi.product_id, oi.quantity
     FROM order_items oi
     JOIN products p ON p.id = oi.product_id
     WHERE oi.order_id = $1
     FOR UPDATE`,
    [orderId]
  );

  for (const item of items) {
    await client.query('UPDATE products SET stock = stock + $1 WHERE id = $2', [
      Number(item.quantity || 0),
      Number(item.product_id),
    ]);
  }
};

module.exports = {
  reserveStockForPaidOrder,
  restoreStockForOrder,
  shouldRestoreStockOnCancel,
};

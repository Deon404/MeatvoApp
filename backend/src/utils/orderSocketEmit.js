/**
 * Canonical + legacy Socket.io room emits for order lifecycle events.
 */

function emitOrderLifecycleEvent(io, {
  orderId,
  customerId = null,
  riderUserId = null,
  event = 'order:status_updated',
  payload,
}) {
  if (!io || !payload) return;

  const orderRoom = `order:${orderId}`;
  io.to(orderRoom).emit(event, payload);

  if (customerId) {
    io.to(`customer_${customerId}`).emit(event, payload);
  }

  io.to('admin:orders').emit('order:updated', payload);
  io.to('admin_room').emit('order:updated', payload);
  io.to('staff:orders').emit('order:updated', payload);
  io.to('staff_room').emit('order:updated', payload);

  if (riderUserId) {
    io.to(`rider:${riderUserId}`).emit(event, payload);
    io.to(`delivery_${riderUserId}`).emit(event, payload);
  }
}

module.exports = { emitOrderLifecycleEvent };

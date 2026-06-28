/**
 * Notification Service
 * Multi-channel: socket, FCM push, DB persistence
 */

const { query } = require('../db/postgres');
const { logger } = require('../utils/logger');
const { getStateNotifications } = require('../utils/enhancedOrderStateMachine');
const { sendPushToUser } = require('../utils/fcm');

const notificationStore = new Map();

const emitNotification = (io, room, notification) => {
  if (!io || !room) return;
  io.to(room).emit('notification:new', notification);
  io.to(room).emit('notification', notification);
};

async function persistNotification(notification) {
  try {
    await query(
      `INSERT INTO user_notifications (user_id, type, title, body, data, is_read)
       VALUES ($1, $2, $3, $4, $5, FALSE)`,
      [
        notification.userId,
        notification.type || 'custom',
        notification.title,
        notification.body,
        JSON.stringify(notification.data || {}),
      ]
    );
  } catch (error) {
    logger.warn('notification_db_persist_failed', { error: error.message });
  }
}

async function sendNotification({
  userId,
  role,
  type,
  title,
  body,
  data = {},
  priority = 'normal',
  channels = ['socket', 'push'],
  io = null,
}) {
  try {
    const notification = {
      id: `notif_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      userId,
      role,
      type,
      title,
      body,
      data,
      priority,
      channels,
      createdAt: new Date().toISOString(),
      read: false,
    };

    if (!notificationStore.has(userId)) {
      notificationStore.set(userId, []);
    }
    notificationStore.get(userId).push(notification);

    const userNotifications = notificationStore.get(userId);
    if (userNotifications.length > 100) {
      notificationStore.set(userId, userNotifications.slice(-100));
    }

    await persistNotification(notification);

    if (channels.includes('push')) {
      await sendPushToUser(userId, { title, body, data: { ...data, type } });
    }

    logger.info('notification_sent', {
      notificationId: notification.id,
      userId,
      role,
      type,
      title,
    });

    return notification;
  } catch (error) {
    logger.error('notification_send_failed', { error: error.message, userId, type });
    throw error;
  }
}

async function sendOrderStateNotifications({
  orderId,
  newState,
  customerId,
  riderUserId = null,
  context = {},
  io = null,
}) {
  try {
    const notifications = getStateNotifications(newState, {
      orderId,
      ...context,
    });

    const results = {
      customer: null,
      rider: null,
      admin: null,
    };

    if (notifications.customer && customerId) {
      results.customer = await sendNotification({
        userId: customerId,
        role: 'customer',
        type: 'order_status_change',
        title: notifications.customer.title,
        body: notifications.customer.body,
        data: { orderId, state: newState },
        priority: notifications.customer.priority,
        io,
      });

      if (io) {
        emitNotification(io, `customer_${customerId}`, results.customer);
      }
    }

    if (notifications.rider && riderUserId) {
      results.rider = await sendNotification({
        userId: riderUserId,
        role: 'rider',
        type: 'order_status_change',
        title: notifications.rider.title,
        body: notifications.rider.body,
        data: { orderId, state: newState },
        priority: notifications.rider.priority,
        io,
      });

      if (io) {
        emitNotification(io, `delivery_${riderUserId}`, results.rider);
      }
    }

    if (notifications.admin) {
      const { rows: admins } = await query(
        "SELECT id FROM users WHERE role = 'admin'"
      );

      for (const admin of admins) {
        const adminNotif = await sendNotification({
          userId: admin.id,
          role: 'admin',
          type: 'order_status_change',
          title: notifications.admin.title,
          body: notifications.admin.body,
          data: { orderId, state: newState },
          priority: notifications.admin.priority,
          io,
        });

        if (!results.admin) {
          results.admin = adminNotif;
        }
      }

      if (io) {
        emitNotification(io, 'admin_room', results.admin);
      }
    }

    return results;
  } catch (error) {
    logger.error('order_state_notifications_failed', {
      error: error.message,
      orderId,
      newState,
    });
    return null;
  }
}

async function sendCustomNotification({
  userId,
  role,
  title,
  body,
  data = {},
  priority = 'normal',
  io = null,
}) {
  const notification = await sendNotification({
    userId,
    role,
    type: 'custom',
    title,
    body,
    data,
    priority,
    io,
  });

  if (io) {
    const roomMap = {
      customer: `customer_${userId}`,
      rider: `delivery_${userId}`,
      admin: 'admin_room',
    };
    const room = roomMap[role];
    emitNotification(io, room, notification);
  }

  return notification;
}

async function getUserNotifications(userId, { limit = 50, unreadOnly = false } = {}) {
  try {
    const params = [userId, limit];
    let sql = `
      SELECT id, user_id, type, title, body, data, is_read, created_at
      FROM user_notifications
      WHERE user_id = $1
    `;
    if (unreadOnly) {
      sql += ' AND is_read = FALSE';
    }
    sql += ' ORDER BY created_at DESC LIMIT $2';

    const { rows } = await query(sql, params);
    if (rows.length > 0) {
      return rows.map((row) => ({
        id: String(row.id),
        userId: row.user_id,
        type: row.type,
        title: row.title,
        body: row.body,
        data: typeof row.data === 'object' ? row.data : {},
        read: row.is_read,
        createdAt: row.created_at,
      }));
    }
  } catch (error) {
    logger.warn('notification_db_fetch_failed', { error: error.message });
  }

  const userNotifications = notificationStore.get(userId) || [];
  let filtered = userNotifications;
  if (unreadOnly) {
    filtered = filtered.filter((n) => !n.read);
  }
  return filtered.slice(-limit).reverse();
}

async function markNotificationRead(userId, notificationId) {
  try {
    const numericId = Number(String(notificationId).replace(/\D/g, ''));
    if (Number.isFinite(numericId) && numericId > 0) {
      await query(
        `UPDATE user_notifications SET is_read = TRUE, read_at = NOW()
         WHERE id = $1 AND user_id = $2`,
        [numericId, userId]
      );
      return true;
    }
  } catch (error) {
    logger.warn('notification_mark_read_db_failed', { error: error.message });
  }

  const userNotifications = notificationStore.get(userId) || [];
  const notification = userNotifications.find((n) => n.id === notificationId);
  if (notification) {
    notification.read = true;
    return true;
  }
  return false;
}

async function markAllNotificationsRead(userId) {
  try {
    await query(
      `UPDATE user_notifications SET is_read = TRUE, read_at = NOW()
       WHERE user_id = $1 AND is_read = FALSE`,
      [userId]
    );
  } catch (error) {
    logger.warn('notification_mark_all_read_db_failed', { error: error.message });
  }

  const userNotifications = notificationStore.get(userId) || [];
  let count = 0;
  for (const notification of userNotifications) {
    if (!notification.read) {
      notification.read = true;
      count++;
    }
  }
  return count;
}

async function getUnreadCount(userId) {
  try {
    const { rows } = await query(
      `SELECT COUNT(*)::int AS count FROM user_notifications
       WHERE user_id = $1 AND is_read = FALSE`,
      [userId]
    );
    if (rows[0]) return Number(rows[0].count) || 0;
  } catch (error) {
    logger.warn('notification_unread_count_db_failed', { error: error.message });
  }

  const userNotifications = notificationStore.get(userId) || [];
  return userNotifications.filter((n) => !n.read).length;
}

async function sendRiderNearbyNotification({ orderId, customerId, riderName, eta, io }) {
  return sendCustomNotification({
    userId: customerId,
    role: 'customer',
    title: 'Rider is Nearby',
    body: `${riderName} will reach in ${eta} minutes`,
    data: { orderId, eta },
    priority: 'urgent',
    io,
  });
}

async function sendLowStockAlert({ productId, productName, currentStock, io }) {
  const { rows: admins } = await query("SELECT id FROM users WHERE role = 'admin'");

  for (const admin of admins) {
    await sendCustomNotification({
      userId: admin.id,
      role: 'admin',
      title: 'Low Stock Alert',
      body: `${productName} is running low (${currentStock} left)`,
      data: { productId, currentStock },
      priority: 'high',
      io,
    });
  }
}

async function sendRiderOfflineAlert({ riderUserId, riderName, orderId, io }) {
  const { rows: admins } = await query("SELECT id FROM users WHERE role = 'admin'");

  for (const admin of admins) {
    await sendCustomNotification({
      userId: admin.id,
      role: 'admin',
      title: 'Rider Went Offline',
      body: `${riderName} went offline during delivery of order #${orderId}`,
      data: { riderUserId, orderId },
      priority: 'urgent',
      io,
    });
  }
}

module.exports = {
  sendNotification,
  sendOrderStateNotifications,
  sendCustomNotification,
  getUserNotifications,
  markNotificationRead,
  markAllNotificationsRead,
  getUnreadCount,
  sendRiderNearbyNotification,
  sendLowStockAlert,
  sendRiderOfflineAlert,
};

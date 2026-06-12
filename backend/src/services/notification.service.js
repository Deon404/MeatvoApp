/**
 * Notification Service
 * Multi-channel notification system for Customer, Admin, and Rider
 */

const { query } = require('../db/postgres');
const { logger } = require('../utils/logger');
const { getStateNotifications } = require('../utils/enhancedOrderStateMachine');

// Store notifications in memory (can be moved to Redis/DB)
const notificationStore = new Map();

/**
 * Send notification to user
 */
async function sendNotification({
  userId,
  role,
  type,
  title,
  body,
  data = {},
  priority = 'normal',
  channels = ['socket', 'sms'],
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

    // Store notification
    if (!notificationStore.has(userId)) {
      notificationStore.set(userId, []);
    }
    notificationStore.get(userId).push(notification);

    // Keep only last 100 notifications per user
    const userNotifications = notificationStore.get(userId);
    if (userNotifications.length > 100) {
      notificationStore.set(userId, userNotifications.slice(-100));
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

/**
 * Send order state change notifications to all relevant parties
 */
async function sendOrderStateNotifications({
  orderId,
  newState,
  customerId,
  riderUserId = null,
  context = {},
  io = null,
}) {
  try {
    // Get notification templates for this state
    const notifications = getStateNotifications(newState, {
      orderId,
      ...context,
    });

    const results = {
      customer: null,
      rider: null,
      admin: null,
    };

    // Send to customer
    if (notifications.customer && customerId) {
      results.customer = await sendNotification({
        userId: customerId,
        role: 'customer',
        type: 'order_status_change',
        title: notifications.customer.title,
        body: notifications.customer.body,
        data: { orderId, state: newState },
        priority: notifications.customer.priority,
      });

      // Emit via socket
      if (io) {
        io.to(`customer_${customerId}`).emit('notification:new', results.customer);
      }
    }

    // Send to rider
    if (notifications.rider && riderUserId) {
      results.rider = await sendNotification({
        userId: riderUserId,
        role: 'rider',
        type: 'order_status_change',
        title: notifications.rider.title,
        body: notifications.rider.body,
        data: { orderId, state: newState },
        priority: notifications.rider.priority,
      });

      // Emit via socket
      if (io) {
        io.to(`delivery_${riderUserId}`).emit('notification:new', results.rider);
      }
    }

    // Send to admin
    if (notifications.admin) {
      // Get all admin users
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
        });

        if (!results.admin) {
          results.admin = adminNotif;
        }
      }

      // Emit via socket
      if (io) {
        io.to('admin_room').emit('notification:new', results.admin);
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

/**
 * Send custom notification
 */
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
  });

  // Emit via socket
  if (io) {
    const roomMap = {
      customer: `customer_${userId}`,
      rider: `delivery_${userId}`,
      admin: 'admin_room',
    };
    const room = roomMap[role];
    if (room) {
      io.to(room).emit('notification:new', notification);
    }
  }

  return notification;
}

/**
 * Get user notifications
 */
async function getUserNotifications(userId, { limit = 50, unreadOnly = false } = {}) {
  const userNotifications = notificationStore.get(userId) || [];
  
  let filtered = userNotifications;
  if (unreadOnly) {
    filtered = filtered.filter(n => !n.read);
  }

  return filtered.slice(-limit).reverse();
}

/**
 * Mark notification as read
 */
async function markNotificationRead(userId, notificationId) {
  const userNotifications = notificationStore.get(userId) || [];
  const notification = userNotifications.find(n => n.id === notificationId);
  
  if (notification) {
    notification.read = true;
    logger.info('notification_marked_read', { userId, notificationId });
    return true;
  }
  
  return false;
}

/**
 * Mark all notifications as read
 */
async function markAllNotificationsRead(userId) {
  const userNotifications = notificationStore.get(userId) || [];
  let count = 0;
  
  for (const notification of userNotifications) {
    if (!notification.read) {
      notification.read = true;
      count++;
    }
  }
  
  logger.info('all_notifications_marked_read', { userId, count });
  return count;
}

/**
 * Get unread count
 */
async function getUnreadCount(userId) {
  const userNotifications = notificationStore.get(userId) || [];
  return userNotifications.filter(n => !n.read).length;
}

/**
 * Send rider nearby notification
 */
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

/**
 * Send low stock alert to admin
 */
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

/**
 * Send rider offline alert
 */
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

/**
 * Firebase Cloud Messaging — server-side push via HTTP v1 legacy endpoint.
 * Uses FCM_SERVER_KEY from env (see shared/env-manifest.json).
 */

const axios = require('axios');
const { query } = require('../db/postgres');
const { logger } = require('./logger');

const FCM_URL = 'https://fcm.googleapis.com/fcm/send';

async function getUserFcmToken(userId) {
  const { rows } = await query(
    'SELECT fcm_token FROM users WHERE id = $1 AND fcm_token IS NOT NULL AND fcm_token != \'\'',
    [userId]
  );
  return rows[0]?.fcm_token || null;
}

/**
 * Send push notification to a single user.
 * @returns {Promise<boolean>} true if sent successfully
 */
async function sendPushToUser(userId, { title, body, data = {} }) {
  const serverKey = process.env.FCM_SERVER_KEY;
  if (!serverKey || serverKey.includes('placeholder')) {
    logger.debug('fcm_skipped_no_server_key', { userId });
    return false;
  }

  const token = await getUserFcmToken(userId);
  if (!token) {
    logger.debug('fcm_skipped_no_token', { userId });
    return false;
  }

  try {
    const payload = {
      to: token,
      notification: {
        title: String(title || 'Meatvo'),
        body: String(body || ''),
        sound: 'default',
      },
      data: Object.fromEntries(
        Object.entries(data).map(([k, v]) => [k, String(v)])
      ),
      priority: 'high',
    };

    const res = await axios.post(FCM_URL, payload, {
      headers: {
        Authorization: `key=${serverKey}`,
        'Content-Type': 'application/json',
      },
      timeout: 8000,
    });

    const success = res.data?.success === 1 || res.data?.message_id != null;
    if (!success) {
      logger.warn('fcm_send_failed', { userId, response: res.data });
    }
    return success;
  } catch (error) {
    logger.error('fcm_send_error', { userId, error: error.message });
    return false;
  }
}

module.exports = {
  sendPushToUser,
  getUserFcmToken,
};

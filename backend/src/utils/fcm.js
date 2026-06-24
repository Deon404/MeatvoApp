/**
 * Firebase Cloud Messaging — server-side push.
 * Primary: Firebase Admin SDK (FIREBASE_SERVICE_ACCOUNT_JSON).
 * Fallback: legacy HTTP API (FCM_SERVER_KEY) when service account is unset.
 */

const axios = require('axios');
const { query } = require('../db/postgres');
const { logger } = require('./logger');
const { getMessaging, isFirebaseAdminReady } = require('../config/firebaseAdmin');

const FCM_LEGACY_URL = 'https://fcm.googleapis.com/fcm/send';
let legacyDeprecationLogged = false;

function stringifyData(data) {
  return Object.fromEntries(
    Object.entries(data).map(([k, v]) => [k, String(v)])
  );
}

async function getUserFcmToken(userId) {
  const { rows } = await query(
    'SELECT fcm_token FROM users WHERE id = $1 AND fcm_token IS NOT NULL AND fcm_token != \'\'',
    [userId]
  );
  return rows[0]?.fcm_token || null;
}

function logLegacyDeprecationOnce() {
  if (legacyDeprecationLogged) return;
  legacyDeprecationLogged = true;
  logger.warn('fcm_legacy_api_deprecated', {
    message:
      'Using deprecated FCM HTTP legacy API (FCM_SERVER_KEY). Set FIREBASE_SERVICE_ACCOUNT_JSON to migrate to Firebase Admin SDK.',
  });
}

async function sendPushViaAdmin(userId, token, { title, body, data }) {
  const messaging = getMessaging();
  if (!messaging) return false;

  try {
    const messageId = await messaging.send({
      token,
      notification: {
        title: String(title || 'Meatvo'),
        body: String(body || ''),
      },
      data: stringifyData(data),
      android: {
        priority: 'high',
        notification: { sound: 'default' },
      },
      apns: {
        payload: {
          aps: { sound: 'default' },
        },
      },
    });

    return Boolean(messageId);
  } catch (error) {
    logger.error('fcm_send_error', { userId, transport: 'admin', error: error.message });
    return false;
  }
}

async function sendPushViaLegacy(userId, token, { title, body, data }) {
  const serverKey = process.env.FCM_SERVER_KEY;
  if (!serverKey || serverKey.includes('placeholder')) {
    return false;
  }

  logLegacyDeprecationOnce();

  try {
    const payload = {
      to: token,
      notification: {
        title: String(title || 'Meatvo'),
        body: String(body || ''),
        sound: 'default',
      },
      data: stringifyData(data),
      priority: 'high',
    };

    const res = await axios.post(FCM_LEGACY_URL, payload, {
      headers: {
        Authorization: `key=${serverKey}`,
        'Content-Type': 'application/json',
      },
      timeout: 8000,
    });

    const success = res.data?.success === 1 || res.data?.message_id != null;
    if (!success) {
      logger.warn('fcm_send_failed', { userId, transport: 'legacy', response: res.data });
    }
    return success;
  } catch (error) {
    logger.error('fcm_send_error', { userId, transport: 'legacy', error: error.message });
    return false;
  }
}

/**
 * Send push notification to a single user.
 * @returns {Promise<boolean>} true if sent successfully
 */
async function sendPushToUser(userId, { title, body, data = {} }) {
  const token = await getUserFcmToken(userId);
  if (!token) {
    logger.debug('fcm_skipped_no_token', { userId });
    return false;
  }

  if (isFirebaseAdminReady()) {
    return sendPushViaAdmin(userId, token, { title, body, data });
  }

  const serverKey = process.env.FCM_SERVER_KEY;
  if (!serverKey || serverKey.includes('placeholder')) {
    logger.debug('fcm_skipped_no_credentials', { userId });
    return false;
  }

  return sendPushViaLegacy(userId, token, { title, body, data });
}

module.exports = {
  sendPushToUser,
  getUserFcmToken,
};

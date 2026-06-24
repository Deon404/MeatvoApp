/**
 * Firebase Admin SDK — singleton init for server-side FCM.
 * Credentials from FIREBASE_SERVICE_ACCOUNT_JSON (stringified service account JSON).
 */

const admin = require('firebase-admin');
const { logger } = require('../utils/logger');

let initAttempted = false;
let initSucceeded = false;
let messagingInstance = null;

function parseServiceAccountJson() {
  const raw = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (!raw || typeof raw !== 'string') return null;

  const trimmed = raw.trim();
  if (!trimmed || trimmed.includes('placeholder')) return null;

  try {
    const parsed = JSON.parse(trimmed);
    if (!parsed.project_id || !parsed.private_key || !parsed.client_email) {
      logger.warn('firebase_admin_invalid_service_account', {
        message: 'FIREBASE_SERVICE_ACCOUNT_JSON is missing project_id, private_key, or client_email',
      });
      return null;
    }
    return parsed;
  } catch (error) {
    logger.warn('firebase_admin_service_account_parse_failed', { error: error.message });
    return null;
  }
}

function initFirebaseAdmin() {
  if (initAttempted) return initSucceeded;
  initAttempted = true;

  const serviceAccount = parseServiceAccountJson();
  if (!serviceAccount) return false;

  try {
    if (admin.apps.length === 0) {
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
      });
    }
    messagingInstance = admin.messaging();
    initSucceeded = true;
    logger.info('firebase_admin_initialized', { projectId: serviceAccount.project_id });
  } catch (error) {
    logger.error('firebase_admin_init_failed', { error: error.message });
    initSucceeded = false;
    messagingInstance = null;
  }

  return initSucceeded;
}

function isFirebaseAdminReady() {
  return initFirebaseAdmin();
}

function getMessaging() {
  if (!initFirebaseAdmin()) return null;
  return messagingInstance;
}

module.exports = {
  isFirebaseAdminReady,
  getMessaging,
};

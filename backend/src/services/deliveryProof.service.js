/**
 * Delivery Proof Service
 * OTP verification and delivery proof collection
 */

const crypto = require('crypto');
const { query, withTransaction } = require('../db/postgres');
const { logger } = require('../utils/logger');
const redis = require('../db/redis');
const {
  validateRiderProofUpload,
  signStoredImageUrl,
} = require('../utils/uploadSigning');

// OTP storage prefix
const OTP_PREFIX = 'delivery_otp:';
const OTP_DISPLAY_PREFIX = 'delivery_otp_display:';
const OTP_EXPIRY = 10 * 60; // 10 minutes in seconds

const timingSafeEqualStr = (a, b) => {
  const ba = Buffer.from(String(a || ''));
  const bb = Buffer.from(String(b || ''));
  if (ba.length !== bb.length) return false;
  return crypto.timingSafeEqual(ba, bb);
};

const hashDeliveryOtp = (orderId, otp) => {
  const secret = process.env.OTP_HASH_SECRET;
  if (!secret) throw new Error('OTP_HASH_SECRET is required');
  return crypto
    .createHmac('sha256', secret)
    .update(String(orderId))
    .update(':')
    .update(String(otp))
    .digest('hex');
};

/**
 * Generate delivery OTP
 */
function generateOTP() {
  return String(crypto.randomInt(100000, 1000000));
}

/**
 * Create delivery OTP for order
 */
async function createDeliveryOTP(orderId) {
  try {
    const otp = generateOTP();
    const key = `${OTP_PREFIX}${orderId}`;
    const displayKey = `${OTP_DISPLAY_PREFIX}${orderId}`;
    const hashedOtp = hashDeliveryOtp(orderId, otp);

    await redis.set(key, hashedOtp, 'EX', OTP_EXPIRY);
    await redis.set(displayKey, otp, 'EX', OTP_EXPIRY);

    logger.info('delivery_otp_created', { orderId });

    return otp;
  } catch (error) {
    logger.error('create_delivery_otp_failed', {
      error: error.message,
      orderId,
    });
    throw error;
  }
}

/**
 * Verify delivery OTP
 */
async function verifyDeliveryOTP(orderId, otp) {
  try {
    const key = `${OTP_PREFIX}${orderId}`;
    const storedHash = await redis.get(key);

    if (!storedHash) {
      return {
        valid: false,
        reason: 'OTP expired or not found',
      };
    }

    const incomingHash = hashDeliveryOtp(orderId, otp);
    if (!timingSafeEqualStr(incomingHash, storedHash)) {
      return {
        valid: false,
        reason: 'Invalid OTP',
      };
    }

    await redis.del(key);
    await redis.del(`${OTP_DISPLAY_PREFIX}${orderId}`);

    logger.info('delivery_otp_verified', { orderId });

    return {
      valid: true,
    };
  } catch (error) {
    logger.error('verify_delivery_otp_failed', {
      error: error.message,
      orderId,
    });
    throw error;
  }
}

/**
 * Store delivery proof (photo/signature)
 */
async function storeDeliveryProof({
  orderId,
  riderUserId,
  proofType,
  proofUrl,
  notes = null,
  customerId = null,
  customerName = null,
}) {
  try {
    const proofCheck = validateRiderProofUpload(proofUrl, riderUserId);
    if (!proofCheck.valid) {
      const err = new Error(proofCheck.reason);
      err.statusCode = 400;
      throw err;
    }

    const storagePath = proofCheck.storagePath;

    await query(
      `UPDATE order_assignments
       SET delivery_image_url = $1,
           delivery_notes = COALESCE($2, delivery_notes),
           delivered_at = COALESCE(delivered_at, NOW())
       WHERE order_id = $3`,
      [storagePath, notes, orderId]
    );

    const proofData = {
      orderId,
      riderUserId,
      proofType,
      proofUrl: storagePath,
      notes,
      customerId,
      customerName,
      timestamp: new Date().toISOString(),
    };

    const key = `delivery_proof:${orderId}`;
    await redis.set(key, JSON.stringify(proofData));

    logger.info('delivery_proof_stored', {
      orderId,
      proofType,
      riderUserId,
    });

    return proofData;
  } catch (error) {
    logger.error('store_delivery_proof_failed', {
      error: error.message,
      orderId,
    });
    throw error;
  }
}

/**
 * Get delivery proof
 */
async function getDeliveryProof(orderId, baseUrl = '') {
  try {
    const key = `delivery_proof:${orderId}`;
    const data = await redis.get(key);

    if (data) {
      const proof = JSON.parse(data);
      if (proof.proofUrl) {
        proof.proofUrl = signStoredImageUrl(proof.proofUrl, baseUrl);
      }
      return proof;
    }

    const { rows } = await query(
      `SELECT oa.delivery_image_url, oa.delivery_notes, oa.delivered_at,
              dp.user_id AS rider_user_id
       FROM order_assignments oa
       JOIN delivery_partners dp ON dp.id = oa.delivery_partner_id
       WHERE oa.order_id = $1`,
      [orderId]
    );

    if (!rows[0]?.delivery_image_url) {
      return null;
    }

    return {
      orderId,
      riderUserId: rows[0].rider_user_id,
      proofType: 'photo',
      proofUrl: signStoredImageUrl(rows[0].delivery_image_url, baseUrl),
      notes: rows[0].delivery_notes,
      timestamp: rows[0].delivered_at,
    };
  } catch (error) {
    logger.error('get_delivery_proof_failed', {
      error: error.message,
      orderId,
    });
    return null;
  }
}

/**
 * Verify COD payment collection
 */
async function verifyCODCollection({
  orderId,
  riderUserId,
  amount,
  collectedAmount,
  notes = null,
}) {
  try {
    const difference = Math.abs(amount - collectedAmount);

    const tolerance = 5;
    const isValid = difference <= tolerance;

    if (!isValid) {
      logger.warn('cod_collection_mismatch', {
        orderId,
        expected: amount,
        collected: collectedAmount,
        difference,
      });
    }

    const verification = {
      orderId,
      riderUserId,
      expectedAmount: amount,
      collectedAmount,
      difference,
      isValid,
      notes,
      timestamp: new Date().toISOString(),
    };

    const key = `cod_verification:${orderId}`;
    await redis.set(key, JSON.stringify(verification));

    logger.info('cod_collection_verified', {
      orderId,
      isValid,
      difference,
    });

    return verification;
  } catch (error) {
    logger.error('verify_cod_collection_failed', {
      error: error.message,
      orderId,
    });
    throw error;
  }
}

/**
 * Get COD verification
 */
async function getCODVerification(orderId) {
  try {
    const key = `cod_verification:${orderId}`;
    const data = await redis.get(key);

    if (!data) {
      return null;
    }

    return JSON.parse(data);
  } catch (error) {
    logger.error('get_cod_verification_failed', {
      error: error.message,
      orderId,
    });
    return null;
  }
}

/**
 * Complete delivery with verification
 */
async function completeDeliveryWithVerification({
  orderId,
  riderUserId,
  otp = null,
  proofType = null,
  proofUrl = null,
  customerName = null,
  notes = null,
  codAmount = null,
}) {
  try {
    const result = {
      success: false,
      errors: [],
      verification: {},
    };

    if (otp) {
      const otpVerification = await verifyDeliveryOTP(orderId, otp);
      result.verification.otp = otpVerification;

      if (!otpVerification.valid) {
        result.errors.push('Invalid or expired OTP');
        return result;
      }
    }

    if (proofType && proofUrl) {
      const { rows: orderRows } = await query(
        'SELECT customer_id FROM orders WHERE id = $1',
        [orderId]
      );

      const proof = await storeDeliveryProof({
        orderId,
        riderUserId,
        proofType,
        proofUrl,
        notes,
        customerId: orderRows[0]?.customer_id,
        customerName,
      });

      result.verification.proof = proof;
    }

    if (codAmount) {
      const { rows: orderRows } = await query(
        'SELECT total_amount FROM orders WHERE id = $1',
        [orderId]
      );

      if (orderRows[0]) {
        const codVerification = await verifyCODCollection({
          orderId,
          riderUserId,
          amount: Number(orderRows[0].total_amount),
          collectedAmount: Number(codAmount),
          notes,
        });

        result.verification.cod = codVerification;

        if (!codVerification.isValid) {
          result.errors.push('COD amount mismatch');
        }
      }
    }

    result.success = result.errors.length === 0;

    return result;
  } catch (error) {
    logger.error('complete_delivery_with_verification_failed', {
      error: error.message,
      orderId,
    });
    throw error;
  }
}

/**
 * Get delivery OTP for customer display
 */
async function getDeliveryOTPForCustomer(orderId, customerId) {
  try {
    const { rows } = await query(
      'SELECT customer_id FROM orders WHERE id = $1',
      [orderId]
    );

    if (!rows[0] || rows[0].customer_id !== customerId) {
      throw new Error('Unauthorized');
    }

    const displayKey = `${OTP_DISPLAY_PREFIX}${orderId}`;
    const existing = await redis.get(displayKey);
    if (existing) {
      return existing;
    }

    return createDeliveryOTP(orderId);
  } catch (error) {
    logger.error('get_delivery_otp_for_customer_failed', {
      error: error.message,
      orderId,
      customerId,
    });
    throw error;
  }
}

/**
 * Ensure delivery OTP exists when order goes out for delivery.
 */
async function ensureDeliveryOTP(orderId) {
  try {
    const displayKey = `${OTP_DISPLAY_PREFIX}${orderId}`;
    const existing = await redis.get(displayKey);
    if (existing) return existing;
    return createDeliveryOTP(orderId);
  } catch (error) {
    logger.warn('ensure_delivery_otp_failed', {
      error: error.message,
      orderId,
    });
    return null;
  }
}

/**
 * Resend delivery OTP
 */
async function resendDeliveryOTP(orderId) {
  try {
    const key = `${OTP_PREFIX}${orderId}`;
    const displayKey = `${OTP_DISPLAY_PREFIX}${orderId}`;
    await redis.del(key);
    await redis.del(displayKey);

    const otp = await createDeliveryOTP(orderId);

    logger.info('delivery_otp_resent', { orderId });

    return otp;
  } catch (error) {
    logger.error('resend_delivery_otp_failed', {
      error: error.message,
      orderId,
    });
    throw error;
  }
}

module.exports = {
  generateOTP,
  createDeliveryOTP,
  verifyDeliveryOTP,
  storeDeliveryProof,
  getDeliveryProof,
  verifyCODCollection,
  getCODVerification,
  completeDeliveryWithVerification,
  getDeliveryOTPForCustomer,
  ensureDeliveryOTP,
  resendDeliveryOTP,
};

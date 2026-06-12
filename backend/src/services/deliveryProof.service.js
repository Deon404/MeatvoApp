/**
 * Delivery Proof Service
 * OTP verification and delivery proof collection
 */

const { query, withTransaction } = require('../db/postgres');
const { logger } = require('../utils/logger');
const redis = require('../db/redis');

// OTP storage prefix
const OTP_PREFIX = 'delivery_otp:';
const OTP_EXPIRY = 10 * 60; // 10 minutes in seconds

/**
 * Generate delivery OTP
 */
function generateOTP() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

/**
 * Create delivery OTP for order
 */
async function createDeliveryOTP(orderId) {
  try {
    const otp = generateOTP();
    const key = `${OTP_PREFIX}${orderId}`;
    
    // Store in Redis with expiry
    await redis.setex(key, OTP_EXPIRY, otp);
    
    logger.info('delivery_otp_created', { orderId, otp });
    
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
    const storedOTP = await redis.get(key);
    
    if (!storedOTP) {
      return {
        valid: false,
        reason: 'OTP expired or not found',
      };
    }
    
    if (storedOTP !== otp) {
      return {
        valid: false,
        reason: 'Invalid OTP',
      };
    }
    
    // Delete OTP after successful verification
    await redis.del(key);
    
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
    // In production, store in database
    // For now, we'll use Redis
    const proofData = {
      orderId,
      riderUserId,
      proofType,
      proofUrl,
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
async function getDeliveryProof(orderId) {
  try {
    const key = `delivery_proof:${orderId}`;
    const data = await redis.get(key);
    
    if (!data) {
      return null;
    }
    
    return JSON.parse(data);
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
    
    // Allow small differences (e.g., for rounding)
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
    
    // Store verification
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

    // Verify OTP if provided
    if (otp) {
      const otpVerification = await verifyDeliveryOTP(orderId, otp);
      result.verification.otp = otpVerification;
      
      if (!otpVerification.valid) {
        result.errors.push('Invalid or expired OTP');
        return result;
      }
    }

    // Store delivery proof if provided
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

    // Verify COD collection if applicable
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
    // Verify customer owns this order
    const { rows } = await query(
      'SELECT customer_id FROM orders WHERE id = $1',
      [orderId]
    );
    
    if (!rows[0] || rows[0].customer_id !== customerId) {
      throw new Error('Unauthorized');
    }
    
    // Get or create OTP
    const key = `${OTP_PREFIX}${orderId}`;
    let otp = await redis.get(key);
    
    if (!otp) {
      otp = await createDeliveryOTP(orderId);
    }
    
    return otp;
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
 * Resend delivery OTP
 */
async function resendDeliveryOTP(orderId) {
  try {
    // Delete old OTP
    const key = `${OTP_PREFIX}${orderId}`;
    await redis.del(key);
    
    // Create new OTP
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
  resendDeliveryOTP,
};

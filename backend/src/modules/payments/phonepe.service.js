const crypto = require('crypto');
const {
  generateChecksum,
  verifyChecksum,
  parsePhonePeWebhookBody,
} = require('../../utils/phonepeChecksum');
const axios = require('axios');
const { logger } = require('../../utils/logger');

class PhonePeService {
  constructor() {
    this.apiBase = process.env.PHONEPE_API_BASE || 'https://api.phonepe.com/v1';
    this.merchantId = process.env.PHONEPE_MERCHANT_ID;
    this.saltKey = process.env.PHONEPE_SALT_KEY;
    this.saltIndex = process.env.PHONEPE_SALT_INDEX || '1';
    this.redirectUrl = process.env.PHONEPE_REDIRECT_URL || 'http://localhost:3000/payment/return';
    this.webhookUrl = process.env.PHONEPE_WEBHOOK_URL || 'http://localhost:8080/api/payments/phonepe/webhook';

    this.isProd = String(process.env.NODE_ENV || '').toLowerCase() === 'production';

    if (!this.merchantId || !this.saltKey) {
      logger.error('phonepe_config_missing', {
        merchantId: this.merchantId ? 'configured' : 'missing',
        saltKey: this.saltKey ? 'configured' : 'missing',
      });
      if (this.isProd) {
        throw new Error('PhonePe configuration missing. Please set PHONEPE_MERCHANT_ID and PHONEPE_SALT_KEY');
      }
    }
  }

  isConfigured() {
    return Boolean(this.merchantId && this.saltKey);
  }

  /**
   * Generate checksum for PhonePe API
   * @param {string} payload - Base64 encoded payload
   * @returns {string} Checksum
   */
  generateChecksum(payload) {
    return generateChecksum(payload, this.saltKey, this.saltIndex);
  }

  /**
   * Verify PhonePe webhook signature
   * @param {string|object} payload - base64 response or JSON body
   * @param {string} signature - X-VERIFY header
   * @returns {boolean} True if signature is valid
   */
  verifyWebhookSignature(payload, signature) {
    const payloadStr = typeof payload === 'string'
      ? payload
      : parsePhonePeWebhookBody(payload).payloadForSignature;
    return verifyChecksum(payloadStr, signature, this.saltKey, this.saltIndex);
  }

  /**
   * Create payment request with PhonePe
   * @param {Object} paymentData - Payment details
   * @returns {Promise<Object>} Payment response
   */
  async createPayment(paymentData) {
    const { orderId, amount, customerPhone, customerEmail, customerName } = paymentData;
    
    const transactionId = `TXN_${orderId}_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    
    const paymentPayload = {
      merchantId: this.merchantId,
      merchantTransactionId: transactionId,
      amount: Math.round(amount * 100), // Convert to paise
      redirectUrl: this.redirectUrl,
      redirectMode: 'REDIRECT',
      callbackUrl: this.webhookUrl,
      paymentInstrument: {
        type: 'PAY_PAGE'
      },
      merchantUserId: customerPhone,
      email: customerEmail || null,
      mobileNumber: customerPhone,
      ...(customerName && { customerName })
    };

    const payload = Buffer.from(JSON.stringify(paymentPayload)).toString('base64');
    const checksum = this.generateChecksum(payload);

    try {
      const response = await axios.post(`${this.apiBase}/pg/v1/pay`, {
        request: payload
      }, {
        headers: {
          'Content-Type': 'application/json',
          'X-VERIFY': checksum,
          'X-MERCHANT-ID': this.merchantId,
          'Accept': 'application/json'
        },
        timeout: 30000 // 30 seconds timeout
      });

      if (response.data.success) {
        return {
          success: true,
          data: {
            transactionId,
            paymentUrl: response.data.data.instrumentResponse.redirectInfo.url,
            merchantTransactionId: transactionId
          }
        };
      } else {
        logger.error('PhonePe payment initiation failed', {
          response: response.data,
          paymentData
        });
        return {
          success: false,
          error: response.data.message || 'Payment initiation failed',
          code: response.data.code
        };
      }
    } catch (error) {
      logger.error('PhonePe API error', { 
        error: error.message, 
        stack: error.stack,
        paymentData 
      });
      
      if (error.response) {
        return {
          success: false,
          error: error.response.data?.message || 'Payment service error',
          code: error.response.status
        };
      }
      
      return {
        success: false,
        error: 'Payment service unavailable'
      };
    }
  }

  /**
   * Check payment status
   * @param {string} merchantTransactionId - PhonePe transaction ID
   * @returns {Promise<Object>} Payment status
   */
  async checkPaymentStatus(merchantTransactionId) {
    if (!this.isConfigured()) {
      return { success: false, error: 'PhonePe is not configured' };
    }

    const payload = `/pg/v1/status/${this.merchantId}/${merchantTransactionId}`;
    const checksum = this.generateChecksum(payload);

    try {
      const response = await axios.get(`${this.apiBase}${payload}`, {
        headers: {
          'Content-Type': 'application/json',
          'X-VERIFY': checksum,
          'X-MERCHANT-ID': this.merchantId,
          'Accept': 'application/json'
        },
        timeout: 15000 // 15 seconds timeout
      });

      if (response.data.success) {
        return {
          success: true,
          data: response.data.data
        };
      } else {
        logger.error('PhonePe status check failed', {
          response: response.data,
          merchantTransactionId
        });
        return {
          success: false,
          error: response.data.message || 'Status check failed',
          code: response.data.code
        };
      }
    } catch (error) {
      logger.error('PhonePe status check error', { 
        error: error.message, 
        merchantTransactionId 
      });
      
      if (error.response) {
        return {
          success: false,
          error: error.response.data?.message || 'Status check failed',
          code: error.response.status
        };
      }
      
      return {
        success: false,
        error: 'Status check failed'
      };
    }
  }

  /**
   * Refund payment (if needed)
   * @param {Object} refundData - Refund details
   * @returns {Promise<Object>} Refund response
   */
  async refundPayment(refundData) {
    const { originalTransactionId, amount, reason } = refundData;
    const refundTransactionId = `REF_${originalTransactionId}_${Date.now()}`;
    
    const refundPayload = {
      merchantId: this.merchantId,
      merchantTransactionId: refundTransactionId,
      originalTransactionId,
      amount: Math.round(amount * 100), // Convert to paise
      ...(reason && { reason })
    };

    const payload = Buffer.from(JSON.stringify(refundPayload)).toString('base64');
    const checksum = this.generateChecksum(payload);

    try {
      const response = await axios.post(`${this.apiBase}/pg/v1/refund`, {
        request: payload
      }, {
        headers: {
          'Content-Type': 'application/json',
          'X-VERIFY': checksum,
          'X-MERCHANT-ID': this.merchantId,
          'Accept': 'application/json'
        },
        timeout: 30000
      });

      if (response.data.success) {
        return {
          success: true,
          data: {
            refundTransactionId,
            ...response.data.data
          }
        };
      } else {
        logger.error('PhonePe refund failed', {
          response: response.data,
          refundData
        });
        return {
          success: false,
          error: response.data.message || 'Refund failed',
          code: response.data.code
        };
      }
    } catch (error) {
      logger.error('PhonePe refund error', { 
        error: error.message, 
        refundData 
      });
      
      if (error.response) {
        return {
          success: false,
          error: error.response.data?.message || 'Refund failed',
          code: error.response.status
        };
      }
      
      return {
        success: false,
        error: 'Refund service unavailable'
      };
    }
  }

  /**
   * Validate webhook payload
   * @param {Object} payload - Webhook payload
   * @param {string} signature - X-VERIFY header
   * @returns {boolean} True if valid
   */
  validateWebhook(payload, signature) {
    try {
      const payloadString = typeof payload === 'string' 
        ? payload 
        : JSON.stringify(payload, Object.keys(payload).sort());
      return this.verifyWebhookSignature(payloadString, signature);
    } catch (error) {
      logger.error('Webhook validation error', { error: error.message });
      return false;
    }
  }

  /**
   * Get merchant details (for testing)
   * @returns {Promise<Object>} Merchant details
   */
  async getMerchantDetails() {
    const payload = `/pg/v1/merchant/${this.merchantId}`;
    const checksum = this.generateChecksum(payload);

    try {
      const response = await axios.get(`${this.apiBase}${payload}`, {
        headers: {
          'Content-Type': 'application/json',
          'X-VERIFY': checksum,
          'X-MERCHANT-ID': this.merchantId,
          'Accept': 'application/json'
        }
      });

      return {
        success: true,
        data: response.data.data
      };
    } catch (error) {
      logger.error('PhonePe merchant details error', { error: error.message });
      return {
        success: false,
        error: 'Failed to fetch merchant details'
      };
    }
  }
}

module.exports = new PhonePeService();

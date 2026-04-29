const crypto = require('crypto');

/**
 * Secure logging utilities for payment system
 * Masks sensitive data and provides structured logging
 */

/**
 * Mask sensitive data for logging
 */
const maskSensitiveData = (data) => {
  if (!data || typeof data !== 'object') return data;
  
  const masked = { ...data };
  
  // Mask phone numbers (show last 4 digits)
  if (masked.phone) {
    const phone = masked.phone.toString();
    masked.phone = phone.length > 4 ? `******${phone.slice(-4)}` : '******';
  }
  
  // Mask email addresses
  if (masked.email) {
    const email = masked.email;
    const [username, domain] = email.split('@');
    if (username && domain) {
      masked.email = `${username.slice(0, 2)}***@${domain}`;
    }
  }
  
  // Mask transaction IDs (show first 4 and last 4)
  if (masked.merchantTransactionId) {
    const id = masked.merchantTransactionId;
    masked.merchantTransactionId = id.length > 8 
      ? `${id.slice(0, 4)}****${id.slice(-4)}` 
      : '****';
  }
  
  if (masked.transactionId) {
    const id = masked.transactionId;
    masked.transactionId = id.length > 8 
      ? `${id.slice(0, 4)}****${id.slice(-4)}` 
      : '****';
  }
  
  // Mask payment IDs
  if (masked.paymentId) {
    const id = masked.paymentId.toString();
    masked.paymentId = id.length > 4 ? `****${id.slice(-4)}` : '****';
  }
  
  // Remove signature values completely
  if (masked.signature) {
    delete masked.signature;
  }
  
  // Remove webhook payload (too sensitive)
  if (masked.webhookBody) {
    delete masked.webhookBody;
  }
  
  if (masked.payload) {
    delete masked.payload;
  }
  
  // Remove tokens
  if (masked.token) {
    delete masked.token;
  }
  
  return masked;
};

/**
 * Create structured log entry
 */
const createLogEntry = (event, data = {}) => {
  return {
    event,
    timestamp: new Date().toISOString(),
    ...maskSensitiveData(data)
  };
};

/**
 * Safe logging with error handling
 */
const safeLog = (logger, level, event, data = {}) => {
  try {
    const logEntry = createLogEntry(event, data);
    logger[level](logEntry);
  } catch (error) {
    // Fallback logging if structured logging fails
    console.error(`Logging failed for event: ${event}`, error.message);
  }
};

/**
 * Payment-specific logging utilities
 */
const paymentLogger = {
  /**
   * Log webhook events
   */
  webhook: {
    received: (logger, data) => {
      safeLog(logger, 'info', 'WEBHOOK_RECEIVED', {
        clientIP: data.clientIP,
        hasSignature: !!data.signature,
        transactionId: data.merchantTransactionId,
        code: data.code
      });
    },
    
    signatureInvalid: (logger, data) => {
      safeLog(logger, 'error', 'WEBHOOK_SIGNATURE_INVALID', {
        clientIP: data.clientIP,
        userAgent: data.userAgent,
        transactionId: data.merchantTransactionId
      });
    },
    
    codeInvalid: (logger, data) => {
      safeLog(logger, 'error', 'WEBHOOK_CODE_INVALID', {
        clientIP: data.clientIP,
        userAgent: data.userAgent,
        code: data.code
      });
    },
    
    dataMissing: (logger, data) => {
      safeLog(logger, 'error', 'WEBHOOK_DATA_MISSING', {
        clientIP: data.clientIP,
        userAgent: data.userAgent,
        code: data.code
      });
    },
    
    transactionUnknown: (logger, data) => {
      safeLog(logger, 'warn', 'WEBHOOK_TRANSACTION_UNKNOWN', {
        clientIP: data.clientIP,
        userAgent: data.userAgent,
        transactionId: data.merchantTransactionId
      });
    },
    
    amountMismatch: (logger, data) => {
      safeLog(logger, 'error', 'WEBHOOK_AMOUNT_MISMATCH', {
        clientIP: data.clientIP,
        userAgent: data.userAgent,
        transactionId: data.merchantTransactionId,
        expected: data.expected,
        received: data.received
      });
    },
    
    duplicateProcessed: (logger, data) => {
      safeLog(logger, 'warn', 'WEBHOOK_DUPLICATE_PROCESSED', {
        clientIP: data.clientIP,
        userAgent: data.userAgent,
        paymentId: data.paymentId,
        currentStatus: data.currentStatus,
        webhookCode: data.webhookCode,
        transactionId: data.merchantTransactionId
      });
    },
    
    processed: (logger, data) => {
      safeLog(logger, 'info', 'WEBHOOK_PROCESSED', {
        orderId: data.orderId,
        paymentId: data.paymentId,
        transactionId: data.merchantTransactionId,
        code: data.code,
        paymentStatus: data.paymentStatus,
        clientIP: data.clientIP
      });
    },
    
    processingError: (logger, data) => {
      safeLog(logger, 'error', 'WEBHOOK_PROCESSING_ERROR', {
        clientIP: data.clientIP,
        userAgent: data.userAgent,
        error: data.error,
        transactionId: data.merchantTransactionId
      });
    }
  },
  
  /**
   * Log payment initiation events
   */
  payment: {
    initiated: (logger, data) => {
      safeLog(logger, 'info', 'PAYMENT_INITIATED', {
        orderId: data.orderId,
        paymentId: data.paymentId,
        transactionId: data.transactionId,
        amount: data.amount,
        userId: data.userId
      });
    },
    
    initiationFailed: (logger, data) => {
      safeLog(logger, 'error', 'PAYMENT_INITIATION_FAILED', {
        orderId: data.orderId,
        userId: data.userId,
        error: data.error
      });
    },
    
    statusChecked: (logger, data) => {
      safeLog(logger, 'info', 'PAYMENT_STATUS_CHECKED', {
        orderId: data.orderId,
        paymentId: data.paymentId,
        status: data.status
      });
    },
    
    statusCheckFailed: (logger, data) => {
      safeLog(logger, 'error', 'PAYMENT_STATUS_CHECK_FAILED', {
        orderId: data.orderId,
        error: data.error
      });
    }
  },
  
  /**
   * Log security events
   */
  security: {
    suspiciousActivity: (logger, data) => {
      safeLog(logger, 'warn', 'SECURITY_SUSPICIOUS_ACTIVITY', {
        clientIP: data.clientIP,
        userAgent: data.userAgent,
        event: data.event,
        details: data.details
      });
    },
    
    rateLimitExceeded: (logger, data) => {
      safeLog(logger, 'warn', 'SECURITY_RATE_LIMIT_EXCEEDED', {
        clientIP: data.clientIP,
        userAgent: data.userAgent,
        endpoint: data.endpoint
      });
    }
  }
};

module.exports = {
  maskSensitiveData,
  createLogEntry,
  safeLog,
  paymentLogger
};

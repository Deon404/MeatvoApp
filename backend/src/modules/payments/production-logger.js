const winston = require('winston');
const path = require('path');

// Create logs directory if it doesn't exist
const fs = require('fs');
const logsDir = path.join(__dirname, '../../logs');
if (!fs.existsSync(logsDir)) {
  fs.mkdirSync(logsDir, { recursive: true });
}

// Custom format for production logs
const customFormat = winston.format.combine(
  winston.format.timestamp(),
  winston.format.errors({ stack: true }),
  winston.format.json(),
  winston.format.printf(({ timestamp, level, message, event, ...meta }) => {
    return JSON.stringify({
      timestamp,
      level,
      event: event || 'LOG',
      message,
      ...meta
    });
  })
);

// Create logger with rotation
const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: customFormat,
  defaultMeta: { service: 'cashfree-payments' },
  transports: [
    // Error log file - only errors
    new winston.transports.File({
      filename: path.join(logsDir, 'error.log'),
      level: 'error',
      maxsize: 10 * 1024 * 1024, // 10MB
      maxFiles: 5,
      tailable: true
    }),
    
    // Combined log file - all logs
    new winston.transports.File({
      filename: path.join(logsDir, 'combined.log'),
      maxsize: 10 * 1024 * 1024, // 10MB
      maxFiles: 5,
      tailable: true
    })
  ],
  
  // Handle uncaught exceptions and rejections
  exceptionHandlers: [
    new winston.transports.File({
      filename: path.join(logsDir, 'exceptions.log'),
      maxsize: 10 * 1024 * 1024,
      maxFiles: 3
    })
  ],
  
  rejectionHandlers: [
    new winston.transports.File({
      filename: path.join(logsDir, 'rejections.log'),
      maxsize: 10 * 1024 * 1024,
      maxFiles: 3
    })
  ]
});

// Add console transport for development (not production)
if (process.env.NODE_ENV !== 'production') {
  logger.add(new winston.transports.Console({
    format: winston.format.combine(
      winston.format.colorize(),
      winston.format.simple()
    )
  }));
}

// Safe logging wrapper to prevent crashes
const safeLogger = {
  error: (message, meta = {}) => {
    try {
      logger.error(message, meta);
    } catch (error) {
      console.error('Logger error:', error.message);
      console.error('Original message:', message);
    }
  },
  
  warn: (message, meta = {}) => {
    try {
      logger.warn(message, meta);
    } catch (error) {
      console.error('Logger error:', error.message);
      console.error('Original message:', message);
    }
  },
  
  info: (message, meta = {}) => {
    try {
      logger.info(message, meta);
    } catch (error) {
      console.error('Logger error:', error.message);
      console.error('Original message:', message);
    }
  },
  
  debug: (message, meta = {}) => {
    try {
      logger.debug(message, meta);
    } catch (error) {
      console.error('Logger error:', error.message);
      console.error('Original message:', message);
    }
  }
};

// Log rotation monitoring
const monitorLogFiles = () => {
  try {
    const files = fs.readdirSync(logsDir);
    files.forEach(file => {
      if (file.endsWith('.log')) {
        const filePath = path.join(logsDir, file);
        const stats = fs.statSync(filePath);
        const sizeInMB = stats.size / (1024 * 1024);
        
        if (sizeInMB > 15) { // Alert if file is too large
          safeLogger.warn('Log file size warning', {
            file,
            sizeInMB: Math.round(sizeInMB * 100) / 100
          });
        }
      }
    });
  } catch (error) {
    safeLogger.error('Log monitoring error', { error: error.message });
  }
};

// Monitor log files every 5 minutes
setInterval(monitorLogFiles, 5 * 60 * 1000);

// Graceful shutdown handling
const gracefulShutdown = () => {
  safeLogger.info('Logger shutting down');
  logger.end();
};

process.on('SIGTERM', gracefulShutdown);
process.on('SIGINT', gracefulShutdown);

module.exports = {
  logger: safeLogger,
  winston // Export winston instance for advanced usage
};

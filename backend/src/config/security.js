// Enhanced Security Configuration
const securityConfig = {
  // JWT Storage Strategy
  jwt: {
    // Use secure storage for mobile, fallback to localStorage for web
    getStorage: () => {
      if (window.Capacitor && Capacitor.isNativePlatform()) {
        return {
          async getItem(key) {
            return await SecureStorage.get({ key });
          },
          async setItem(key, value) {
            await SecureStorage.set({ key, value });
          },
          async removeItem(key) {
            await SecureStorage.remove({ key });
          }
        };
      }
      return localStorage;
    },
    
    // Token validation
    validateToken: (token) => {
      try {
        const payload = JSON.parse(atob(token.split('.')[1]));
        return payload.exp * 1000 > Date.now(); // Check expiry
      } catch {
        return false;
      }
    }
  },
  
  // OTP Security
  otp: {
    // Rate limiting per phone number
    rateLimit: {
      windowMs: 15 * 60 * 1000, // 15 minutes
      maxAttempts: 3,
      blockDuration: 30 * 60 * 1000 // 30 minutes block
    },
    
    // OTP validation
    validate: (phone, otp) => {
      // Phone: 10 digits, starting with 6-9
      const phoneRegex = /^[6-9]\d{9}$/;
      // OTP: 4 digits (MSG91 production template)
      const otpRegex = /^\d{4}$/;
      
      return phoneRegex.test(phone) && otpRegex.test(otp);
    }
  },
  
  // API Security
  api: {
    // Request validation
    validateRequest: (req) => {
      // Check for suspicious patterns
      const suspiciousPatterns = [
        /<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, // XSS
        /union.*select/gi, // SQL injection
        /javascript:/gi, // JS injection
        /data:.*base64/gi // Data URI
      ];
      
      const body = JSON.stringify(req.body);
      return !suspiciousPatterns.some(pattern => pattern.test(body));
    },
    
    // CORS security
    cors: {
      origins: process.env.CORS_ORIGINS?.split(',') || [],
      methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
      allowedHeaders: ['Content-Type', 'Authorization'],
      credentials: true,
      maxAge: 86400 // 24 hours
    }
  },
  
  // Input sanitization
  sanitize: {
    phone: (phone) => {
      // Remove all non-digit characters
      return phone.replace(/\D/g, '').slice(-10);
    },
    
    otp: (otp) => {
      // Remove all non-digit characters
      return otp.replace(/\D/g, '').slice(0, 4);
    }
  }
};

module.exports = securityConfig;

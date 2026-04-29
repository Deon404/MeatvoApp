// Secure Password Utilities
// Implements bcrypt-based password hashing and verification

const bcrypt = require('bcryptjs');
const crypto = require('crypto');

class PasswordUtils {
  constructor() {
    this.saltRounds = 12; // Strong salt rounds for security
    this.minPasswordLength = 8;
    this.maxPasswordLength = 128;
  }

  // Hash password with bcrypt
  async hashPassword(password) {
    try {
      // Validate password
      if (!this.validatePassword(password)) {
        throw new Error('Password does not meet security requirements');
      }

      // Generate salt and hash
      const salt = await bcrypt.genSalt(this.saltRounds);
      const hash = await bcrypt.hash(password, salt);
      
      return hash;
    } catch (error) {
      console.error('Password hashing error:', error);
      throw new Error('Failed to hash password');
    }
  }

  // Verify password against hash
  async verifyPassword(password, hash) {
    try {
      const isValid = await bcrypt.compare(password, hash);
      return isValid;
    } catch (error) {
      console.error('Password verification error:', error);
      return false;
    }
  }

  // Validate password strength
  validatePassword(password) {
    if (!password || typeof password !== 'string') {
      return false;
    }

    // Length requirements
    if (password.length < this.minPasswordLength || password.length > this.maxPasswordLength) {
      return false;
    }

    // Complexity requirements
    const hasUpperCase = /[A-Z]/.test(password);
    const hasLowerCase = /[a-z]/.test(password);
    const hasNumbers = /\d/.test(password);
    const hasSpecialChar = /[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?]/.test(password);

    // Require at least 3 of the 4 complexity rules
    const complexityScore = [hasUpperCase, hasLowerCase, hasNumbers, hasSpecialChar].filter(Boolean).length;
    
    return complexityScore >= 3;
  }

  // Generate secure random password
  generateSecurePassword(length = 12) {
    const uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const lowercase = 'abcdefghijklmnopqrstuvwxyz';
    const numbers = '0123456789';
    const specialChars = '!@#$%^&*()_+-=[]{}|;:,.<>?';
    
    const allChars = uppercase + lowercase + numbers + specialChars;
    
    let password = '';
    
    // Ensure at least one character from each category
    password += uppercase.charAt(crypto.randomInt(0, uppercase.length));
    password += lowercase.charAt(crypto.randomInt(0, lowercase.length));
    password += numbers.charAt(crypto.randomInt(0, numbers.length));
    password += specialChars.charAt(crypto.randomInt(0, specialChars.length));
    
    // Fill remaining length with random characters
    for (let i = 4; i < length; i++) {
      password += allChars.charAt(crypto.randomInt(0, allChars.length));
    }
    
    // Shuffle the password
    return password.split('').sort(() => crypto.randomInt(-1, 2)).join('');
  }

  // Check password strength
  checkPasswordStrength(password) {
    if (!password || typeof password !== 'string') {
      return { strength: 0, feedback: 'Password is required' };
    }

    let strength = 0;
    const feedback = [];

    // Length check
    if (password.length >= 8) strength += 1;
    else feedback.push('Use at least 8 characters');

    if (password.length >= 12) strength += 1;

    // Complexity checks
    if (/[a-z]/.test(password)) strength += 1;
    else feedback.push('Include lowercase letters');

    if (/[A-Z]/.test(password)) strength += 1;
    else feedback.push('Include uppercase letters');

    if (/\d/.test(password)) strength += 1;
    else feedback.push('Include numbers');

    if (/[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?]/.test(password)) strength += 1;
    else feedback.push('Include special characters');

    // Common patterns penalty
    if (/(.)\1{2,}/.test(password)) {
      strength -= 1;
      feedback.push('Avoid repeating characters');
    }

    if (/123|abc|qwe|password/i.test(password)) {
      strength -= 1;
      feedback.push('Avoid common patterns');
    }

    // Normalize strength to 0-5
    strength = Math.max(0, Math.min(5, strength));

    let strengthText = 'Very Weak';
    if (strength >= 5) strengthText = 'Very Strong';
    else if (strength >= 4) strengthText = 'Strong';
    else if (strength >= 3) strengthText = 'Medium';
    else if (strength >= 2) strengthText = 'Weak';
    else if (strength >= 1) strengthText = 'Very Weak';

    return {
      strength,
      strengthText,
      feedback
    };
  }

  // Generate password reset token
  generateResetToken() {
    return crypto.randomBytes(32).toString('hex');
  }

  // Generate secure session token
  generateSessionToken() {
    return crypto.randomBytes(64).toString('hex');
  }

  // Hash sensitive data (non-password)
  hashData(data) {
    return crypto.createHash('sha256').update(data).digest('hex');
  }

  // Verify data hash
  verifyHash(data, hash) {
    const computedHash = this.hashData(data);
    return computedHash === hash;
  }

  // Generate API key
  generateApiKey() {
    const prefix = 'mk_'; // Meatvo Key prefix
    const randomPart = crypto.randomBytes(32).toString('hex');
    return prefix + randomPart;
  }

  // Hash API key
  hashApiKey(apiKey) {
    return crypto.createHash('sha256').update(apiKey).digest('hex');
  }

  // Verify API key
  verifyApiKey(apiKey, hashedKey) {
    const computedHash = this.hashApiKey(apiKey);
    return computedHash === hashedKey;
  }
}

// Create and export instance
const passwordUtils = new PasswordUtils();

module.exports = {
  PasswordUtils,
  passwordUtils
};

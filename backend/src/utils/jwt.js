// JWT Utilities
// Secure JWT token generation, validation, and management

const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const { passwordUtils } = require('./password');

class JWTUtils {
  constructor() {
    this.accessTokenExpiry = '15m'; // 15 minutes
    this.refreshTokenExpiry = '7d'; // 7 days
    this.resetTokenExpiry = '1h'; // 1 hour
    this.issuer = 'meatvo-app';
    this.audience = 'meatvo-users';
    
    // Get secrets from environment - MUST be configured
    this.accessTokenSecret = process.env.JWT_ACCESS_SECRET;
    this.refreshTokenSecret = process.env.JWT_REFRESH_SECRET;
    this.resetTokenSecret = process.env.JWT_RESET_SECRET;
    
    // Validate secrets are configured
    if (!this.accessTokenSecret || !this.refreshTokenSecret) {
      throw new Error('JWT secrets must be configured in environment variables (JWT_ACCESS_SECRET, JWT_REFRESH_SECRET)');
    }
  }

  // Generate secure secret
  generateSecret() {
    return crypto.randomBytes(64).toString('hex');
  }

  // Generate access token
  generateAccessToken(user) {
    const payload = {
      sub: user.id,
      email: user.email || user.phone,
      role: user.role,
      permissions: user.permissions || [],
      type: 'access',
      iat: Math.floor(Date.now() / 1000),
      jti: crypto.randomUUID()
    };

    return jwt.sign(payload, this.accessTokenSecret, {
      expiresIn: this.accessTokenExpiry,
      issuer: this.issuer,
      audience: this.audience,
      algorithm: 'HS256'
    });
  }

  // Generate refresh token
  generateRefreshToken(user) {
    const payload = {
      sub: user.id,
      type: 'refresh',
      tokenVersion: user.tokenVersion || 1,
      iat: Math.floor(Date.now() / 1000),
      jti: crypto.randomUUID()
    };

    return jwt.sign(payload, this.refreshTokenSecret, {
      expiresIn: this.refreshTokenExpiry,
      issuer: this.issuer,
      audience: this.audience,
      algorithm: 'HS256'
    });
  }

  // Generate password reset token
  generatePasswordResetToken(user) {
    const payload = {
      sub: user.id,
      email: user.email || user.phone,
      type: 'reset',
      iat: Math.floor(Date.now() / 1000),
      jti: crypto.randomUUID()
    };

    return jwt.sign(payload, this.resetTokenSecret, {
      expiresIn: this.resetTokenExpiry,
      issuer: this.issuer,
      audience: this.audience,
      algorithm: 'HS256'
    });
  }

  // Verify access token
  verifyAccessToken(token) {
    try {
      const decoded = jwt.verify(token, this.accessTokenSecret, {
        issuer: this.issuer,
        audience: this.audience,
        algorithms: ['HS256']
      });

      // Ensure it's an access token
      if (decoded.type !== 'access') {
        throw new Error('Invalid token type');
      }

      return {
        valid: true,
        payload: decoded
      };
    } catch (error) {
      return {
        valid: false,
        error: error.message
      };
    }
  }

  // Verify refresh token
  verifyRefreshToken(token) {
    try {
      const decoded = jwt.verify(token, this.refreshTokenSecret, {
        issuer: this.issuer,
        audience: this.audience,
        algorithms: ['HS256']
      });

      // Ensure it's a refresh token
      if (decoded.type !== 'refresh') {
        throw new Error('Invalid token type');
      }

      return {
        valid: true,
        payload: decoded
      };
    } catch (error) {
      return {
        valid: false,
        error: error.message
      };
    }
  }

  // Verify password reset token
  verifyPasswordResetToken(token) {
    try {
      const decoded = jwt.verify(token, this.resetTokenSecret, {
        issuer: this.issuer,
        audience: this.audience,
        algorithms: ['HS256']
      });

      // Ensure it's a reset token
      if (decoded.type !== 'reset') {
        throw new Error('Invalid token type');
      }

      return {
        valid: true,
        payload: decoded
      };
    } catch (error) {
      return {
        valid: false,
        error: error.message
      };
    }
  }

  // Decode token without verification (for debugging)
  decodeToken(token) {
    try {
      return jwt.decode(token, { complete: true });
    } catch (error) {
      return null;
    }
  }

  // Get token expiration time
  getTokenExpiration(token) {
    const decoded = this.decodeToken(token);
    if (decoded && decoded.payload.exp) {
      return new Date(decoded.payload.exp * 1000);
    }
    return null;
  }

  // Check if token is expired
  isTokenExpired(token) {
    const expiration = this.getTokenExpiration(token);
    return expiration ? expiration < new Date() : true;
  }

  // Get time until token expires
  getTimeUntilExpiration(token) {
    const expiration = this.getTokenExpiration(token);
    if (!expiration) return 0;
    
    const now = new Date();
    const timeUntil = expiration.getTime() - now.getTime();
    return Math.max(0, timeUntil);
  }

  // Generate token pair (access + refresh)
  generateTokenPair(user) {
    return {
      accessToken: this.generateAccessToken(user),
      refreshToken: this.generateRefreshToken(user),
      expiresIn: this.getExpirationTime(this.accessTokenExpiry),
      tokenType: 'Bearer'
    };
  }

  // Get expiration time in milliseconds
  getExpirationTime(expiry) {
    const match = expiry.match(/(\d+)([smhd])/);
    if (!match) return 15 * 60 * 1000; // Default 15 minutes

    const value = parseInt(match[1]);
    const unit = match[2];

    switch (unit) {
      case 's': return value * 1000;
      case 'm': return value * 60 * 1000;
      case 'h': return value * 60 * 60 * 1000;
      case 'd': return value * 24 * 60 * 60 * 1000;
      default: return 15 * 60 * 1000;
    }
  }

  // Create session data for token storage
  createSessionData(user, tokens) {
    return {
      userId: user.id,
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      expiresAt: new Date(Date.now() + this.getExpirationTime(this.accessTokenExpiry)),
      refreshTokenExpiresAt: new Date(Date.now() + this.getExpirationTime(this.refreshTokenExpiry)),
      userAgent: null, // Will be set by middleware
      ipAddress: null, // Will be set by middleware
      isActive: true,
      createdAt: new Date()
    };
  }

  // Invalidate user tokens (increment token version)
  async invalidateUserTokens(userId, database) {
    try {
      // Increment token version to invalidate all existing tokens
      await database.query(
        'UPDATE users SET token_version = token_version + 1 WHERE id = $1',
        [userId]
      );

      // Mark all sessions as inactive
      await database.query(
        'UPDATE user_sessions SET is_active = false WHERE user_id = $1',
        [userId]
      );

      return true;
    } catch (error) {
      console.error('Error invalidating tokens:', error);
      return false;
    }
  }

  // Refresh access token
  async refreshAccessToken(refreshToken, user, database) {
    try {
      // Verify refresh token
      const verification = this.verifyRefreshToken(refreshToken);
      if (!verification.valid) {
        throw new Error('Invalid refresh token');
      }

      // Check if token version matches
      if (verification.payload.tokenVersion !== user.tokenVersion) {
        throw new Error('Token has been invalidated');
      }

      // Check if refresh session exists and is active
      const sessionQuery = await database.query(
        'SELECT * FROM user_sessions WHERE refresh_token = $1 AND is_active = true AND refresh_token_expires_at > NOW()',
        [refreshToken]
      );

      if (sessionQuery.rows.length === 0) {
        throw new Error('Refresh session not found or expired');
      }

      // Generate new tokens
      const newTokens = this.generateTokenPair(user);

      // Update session with new tokens
      await database.query(
        'UPDATE user_sessions SET access_token = $1, refresh_token = $2, expires_at = $3, refresh_token_expires_at = $4 WHERE id = $5',
        [
          newTokens.accessToken,
          newTokens.refreshToken,
          new Date(Date.now() + this.getExpirationTime(this.accessTokenExpiry)),
          new Date(Date.now() + this.getExpirationTime(this.refreshTokenExpiry)),
          sessionQuery.rows[0].id
        ]
      );

      return {
        accessToken: newTokens.accessToken,
        refreshToken: newTokens.refreshToken,
        expiresIn: newTokens.expiresIn
      };
    } catch (error) {
      console.error('Token refresh error:', error);
      throw error;
    }
  }

  // Extract token from Authorization header
  extractTokenFromHeader(authHeader) {
    if (!authHeader) return null;
    
    const parts = authHeader.split(' ');
    if (parts.length !== 2 || parts[0] !== 'Bearer') {
      return null;
    }
    
    return parts[1];
  }

  // Middleware to verify JWT token
  createAuthMiddleware(database) {
    return async (req, res, next) => {
      try {
        const token = this.extractTokenFromHeader(req.headers.authorization);
        
        if (!token) {
          return res.status(401).json({
            error: 'Access token required',
            code: 'TOKEN_MISSING'
          });
        }

        // Verify token
        const verification = this.verifyAccessToken(token);
        if (!verification.valid) {
          return res.status(401).json({
            error: 'Invalid or expired token',
            code: 'TOKEN_INVALID'
          });
        }

        // Get user from database
        const userQuery = await database.query(
          'SELECT id, email, phone, role, permissions, token_version, is_active FROM users WHERE id = $1',
          [verification.payload.sub]
        );

        if (userQuery.rows.length === 0) {
          return res.status(401).json({
            error: 'User not found',
            code: 'USER_NOT_FOUND'
          });
        }

        const user = userQuery.rows[0];

        // Check if user is active
        if (!user.is_active) {
          return res.status(401).json({
            error: 'User account is inactive',
            code: 'USER_INACTIVE'
          });
        }

        // Check token version
        if (verification.payload.tokenVersion !== user.token_version) {
          return res.status(401).json({
            error: 'Token has been invalidated',
            code: 'TOKEN_INVALIDATED'
          });
        }

        // Attach user to request
        req.user = user;
        req.token = token;
        
        next();
      } catch (error) {
        console.error('Auth middleware error:', error);
        return res.status(500).json({
          error: 'Authentication error',
          code: 'AUTH_ERROR'
        });
      }
    };
  }

  // Middleware to check user role
  createRoleMiddleware(requiredRole) {
    return (req, res, next) => {
      if (!req.user) {
        return res.status(401).json({
          error: 'Authentication required',
          code: 'AUTH_REQUIRED'
        });
      }

      if (req.user.role !== requiredRole) {
        return res.status(403).json({
          error: 'Insufficient permissions',
          code: 'INSUFFICIENT_PERMISSIONS'
        });
      }

      next();
    };
  }

  // Middleware to check user permissions
  createPermissionMiddleware(requiredPermission) {
    return (req, res, next) => {
      if (!req.user) {
        return res.status(401).json({
          error: 'Authentication required',
          code: 'AUTH_REQUIRED'
        });
      }

      const permissions = req.user.permissions || [];
      if (!permissions.includes(requiredPermission)) {
        return res.status(403).json({
          error: 'Insufficient permissions',
          code: 'INSUFFICIENT_PERMISSIONS'
        });
      }

      next();
    };
  }
}

// Create and export instance
const jwtUtils = new JWTUtils();

module.exports = {
  JWTUtils,
  jwtUtils
};

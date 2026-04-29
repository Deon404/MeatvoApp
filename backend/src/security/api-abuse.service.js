const crypto = require('crypto');
const { logger } = require('../utils/logger');
const { sentry } = require('../utils/sentry');

class APIAbuseService {
  constructor() {
    this.abuseAttempts = new Map(); // In production, use Redis
    this.blockedIPs = new Map(); // In production, use Redis
    this.suspiciousPatterns = new Map(); // In production, use Redis
    this.abuseWindow = 60 * 60 * 1000; // 1 hour
    this.blockDuration = 24 * 60 * 60 * 1000; // 24 hours
    this.maxAbuseScore = 100;
    this.abuseThresholds = {
      low: 20,
      medium: 50,
      high: 80,
      critical: 100
    };
  }

  /**
   * Analyze request for potential abuse
   */
  analyzeRequest(req) {
    try {
      const ip = req.ip || req.connection.remoteAddress;
      const userAgent = req.get('User-Agent') || '';
      const path = req.path;
      const method = req.method;
      const requestId = req.requestId || crypto.randomBytes(8).toString('hex');

      let abuseScore = 0;
      const detectedPatterns = [];

      // Analyze IP reputation
      const ipAnalysis = this.analyzeIP(ip);
      abuseScore += ipAnalysis.score;
      detectedPatterns.push(...ipAnalysis.patterns);

      // Analyze User-Agent
      const uaAnalysis = this.analyzeUserAgent(userAgent);
      abuseScore += uaAnalysis.score;
      detectedPatterns.push(...uaAnalysis.patterns);

      // Analyze request patterns
      const requestAnalysis = this.analyzeRequestPattern(req);
      abuseScore += requestAnalysis.score;
      detectedPatterns.push(...requestAnalysis.patterns);

      // Analyze payload for malicious content
      const payloadAnalysis = this.analyzePayload(req);
      abuseScore += payloadAnalysis.score;
      detectedPatterns.push(...payloadAnalysis.patterns);

      // Analyze rate patterns
      const rateAnalysis = this.analyzeRatePatterns(ip, path);
      abuseScore += rateAnalysis.score;
      detectedPatterns.push(...rateAnalysis.patterns);

      const result = {
        requestId,
        ip,
        userAgent,
        path,
        method,
        abuseScore,
        riskLevel: this.getRiskLevel(abuseScore),
        detectedPatterns,
        timestamp: Date.now(),
        shouldBlock: abuseScore >= this.abuseThresholds.critical
      };

      // Record abuse attempt
      this.recordAbuseAttempt(ip, result);

      // Log suspicious activity
      if (abuseScore >= this.abuseThresholds.medium) {
        logger.warn('suspicious_api_request', {
          requestId,
          ip,
          path,
          method,
          abuseScore,
          riskLevel: result.riskLevel,
          patterns: detectedPatterns
        });

        sentry.addBreadcrumb({
          message: 'Suspicious API request detected',
          category: 'security',
          level: 'warning',
          data: {
            requestId,
            ip,
            path,
            method,
            abuseScore,
            riskLevel: result.riskLevel,
            patterns: detectedPatterns
          }
        });
      }

      return result;
    } catch (error) {
      logger.error('api_abuse_analysis_error', { error: error.message });
      sentry.captureException(error);
      return {
        abuseScore: 0,
        riskLevel: 'low',
        detectedPatterns: [],
        shouldBlock: false
      };
    }
  }

  /**
   * Analyze IP address for abuse patterns
   */
  analyzeIP(ip) {
    const score = 0;
    const patterns = [];

    // Check if IP is blocked
    if (this.isIPBlocked(ip)) {
      return { score: 100, patterns: ['BLOCKED_IP'] };
    }

    // Check for private/internal IPs (shouldn't be accessing public API)
    if (this.isPrivateIP(ip)) {
      patterns.push('PRIVATE_IP_ACCESS');
      score += 10;
    }

    // Check for known proxy/VPN indicators
    if (this.isProxyIP(ip)) {
      patterns.push('PROXY_VPN_IP');
      score += 15;
    }

    // Check for suspicious IP patterns
    if (this.hasSuspiciousIPPattern(ip)) {
      patterns.push('SUSPICIOUS_IP_PATTERN');
      score += 20;
    }

    return { score, patterns };
  }

  /**
   * Analyze User-Agent for abuse patterns
   */
  analyzeUserAgent(userAgent) {
    const score = 0;
    const patterns = [];

    if (!userAgent || userAgent.length < 10) {
      patterns.push('MISSING_OR_SHORT_UA');
      return { score: 25, patterns };
    }

    // Check for bot/crawler signatures
    const botPatterns = [
      /bot/i,
      /crawler/i,
      /spider/i,
      /scraper/i,
      /curl/i,
      /wget/i,
      /python/i,
      /java/i,
      /go-http/i,
      /postman/i,
      /insomnia/i
    ];

    for (const pattern of botPatterns) {
      if (pattern.test(userAgent)) {
        patterns.push('BOT_OR_TOOL_UA');
        score += 30;
        break;
      }
    }

    // Check for automated tool signatures
    const toolPatterns = [
      /axios/i,
      /fetch/i,
      /httpie/i,
      /http-client/i
    ];

    for (const pattern of toolPatterns) {
      if (pattern.test(userAgent)) {
        patterns.push('AUTOMATED_TOOL_UA');
        score += 15;
        break;
      }
    }

    // Check for suspicious UA patterns
    if (userAgent.length > 500) {
      patterns.push('EXCESSIVELY_LONG_UA');
      score += 10;
    }

    return { score, patterns };
  }

  /**
   * Analyze request patterns
   */
  analyzeRequestPattern(req) {
    const score = 0;
    const patterns = [];

    const { path, method, query, headers } = req;

    // Check for path traversal attempts
    if (/\.\./.test(path)) {
      patterns.push('PATH_TRAVERSAL');
      score += 40;
    }

    // Check for SQL injection patterns
    const sqlPatterns = [
      /union.*select/i,
      /drop.*table/i,
      /insert.*into/i,
      /delete.*from/i,
      /update.*set/i,
      /exec\s*\(/i,
      /xp_cmdshell/i
    ];

    const requestString = JSON.stringify({ path, query, headers });
    for (const pattern of sqlPatterns) {
      if (pattern.test(requestString)) {
        patterns.push('SQL_INJECTION_ATTEMPT');
        score += 50;
        break;
      }
    }

    // Check for XSS patterns
    const xssPatterns = [
      /<script/i,
      /javascript:/i,
      /on\w+\s*=/i,
      /<iframe/i,
      /data:text\/html/i
    ];

    for (const pattern of xssPatterns) {
      if (pattern.test(requestString)) {
        patterns.push('XSS_ATTEMPT');
        score += 45;
        break;
      }
    }

    // Check for command injection
    const cmdPatterns = [
      /\|\s*rm\s/,
      /\|\s*cat\s/,
      /\|\s*ls\s/,
      /;\s*rm\s/,
      /;\s*cat\s/,
      /;\s*ls\s/,
      /&&\s*rm\s/,
      /&&\s*cat\s/,
      /&&\s*ls\s/
    ];

    for (const pattern of cmdPatterns) {
      if (pattern.test(requestString)) {
        patterns.push('COMMAND_INJECTION');
        score += 60;
        break;
      }
    }

    // Check for suspicious header combinations
    if (headers['x-forwarded-for'] && headers['x-real-ip']) {
      patterns.push('MULTIPLE_PROXY_HEADERS');
      score += 20;
    }

    return { score, patterns };
  }

  /**
   * Analyze request payload
   */
  analyzePayload(req) {
    const score = 0;
    const patterns = [];

    const { body, query } = req;

    // Analyze body for malicious content
    if (body && typeof body === 'object') {
      const bodyString = JSON.stringify(body);

      // Check for large payloads
      if (bodyString.length > 1024 * 1024) { // 1MB
        patterns.push('LARGE_PAYLOAD');
        score += 25;
      }

      // Check for nested objects (potential DoS)
      const depth = this.getObjectDepth(body);
      if (depth > 10) {
        patterns.push('DEEP_NESTING');
        score += 30;
      }

      // Check for suspicious field names
      const suspiciousFields = ['admin', 'root', 'password', 'secret', 'key', 'token'];
      for (const field of suspiciousFields) {
        if (field in body) {
          patterns.push('SUSPICIOUS_FIELD_NAME');
          score += 15;
          break;
        }
      }
    }

    // Analyze query parameters
    if (query && typeof query === 'object') {
      const queryKeys = Object.keys(query);
      if (queryKeys.length > 50) {
        patterns.push('EXCESSIVE_QUERY_PARAMS');
        score += 20;
      }

      // Check for suspicious parameter names
      const suspiciousParams = ['id', 'user', 'admin', 'debug', 'test', 'exec'];
      for (const param of suspiciousParams) {
        if (param in query) {
          patterns.push('SUSPICIOUS_QUERY_PARAM');
          score += 10;
          break;
        }
      }
    }

    return { score, patterns };
  }

  /**
   * Analyze rate patterns
   */
  analyzeRatePatterns(ip, path) {
    const score = 0;
    const patterns = [];
    const key = `${ip}:${path}`;
    const now = Date.now();

    let rateData = this.abuseAttempts.get(key) || {
      requests: [],
      uniquePaths: new Set(),
      methods: new Set()
    };

    // Clean up old requests
    rateData.requests = rateData.requests.filter(
      timestamp => now - timestamp < this.abuseWindow
    );

    // Add current request
    rateData.requests.push(now);
    rateData.uniquePaths.add(path);
    rateData.methods.add(req.method);

    // Check request rate
    const requestRate = rateData.requests.length;
    if (requestRate > 1000) { // 1000 requests per hour
      patterns.push('HIGH_REQUEST_RATE');
      score += 40;
    } else if (requestRate > 500) {
      patterns.push('ELEVATED_REQUEST_RATE');
      score += 25;
    }

    // Check path diversity (potential scraping)
    if (rateData.uniquePaths.size > 100) {
      patterns.push('HIGH_PATH_DIVERSITY');
      score += 30;
    }

    // Check method diversity
    if (rateData.methods.size > 4) {
      patterns.push('HIGH_METHOD_DIVERSITY');
      score += 15;
    }

    this.abuseAttempts.set(key, rateData);

    return { score, patterns };
  }

  /**
   * Record abuse attempt
   */
  recordAbuseAttempt(ip, analysis) {
    try {
      const key = `abuse:${ip}`;
      const attempts = this.abuseAttempts.get(key) || [];

      attempts.push({
        ...analysis,
        timestamp: Date.now()
      });

      // Keep only recent attempts
      const cutoff = Date.now() - this.abuseWindow;
      const recentAttempts = attempts.filter(attempt => attempt.timestamp > cutoff);

      this.abuseAttempts.set(key, recentAttempts);

      // Auto-block if critical abuse detected
      if (analysis.shouldBlock) {
        this.blockIP(ip, 'automatic', analysis.abuseScore);
      }
    } catch (error) {
      logger.error('abuse_attempt_recording_error', { error: error.message });
    }
  }

  /**
   * Block IP address
   */
  blockIP(ip, reason = 'manual', abuseScore = 100) {
    try {
      const blockData = {
        ip,
        blockedAt: Date.now(),
        expiresAt: Date.now() + this.blockDuration,
        reason,
        abuseScore,
        blockedBy: reason === 'manual' ? 'admin' : 'automatic'
      };

      this.blockedIPs.set(ip, blockData);

      logger.warn('ip_blocked', {
        ip,
        reason,
        abuseScore,
        expiresAt: blockData.expiresAt
      });

      sentry.addBreadcrumb({
        message: 'IP address blocked',
        category: 'security',
        level: 'error',
        data: {
          ip,
          reason,
          abuseScore,
          expiresAt: blockData.expiresAt
        }
      });

      return true;
    } catch (error) {
      logger.error('ip_blocking_error', { error: error.message });
      return false;
    }
  }

  /**
   * Check if IP is blocked
   */
  isIPBlocked(ip) {
    try {
      const blockData = this.blockedIPs.get(ip);

      if (!blockData) {
        return false;
      }

      // Check if block has expired
      if (Date.now() > blockData.expiresAt) {
        this.unblockIP(ip, 'expired');
        return false;
      }

      return true;
    } catch (error) {
      logger.error('ip_block_check_error', { error: error.message });
      return false;
    }
  }

  /**
   * Unblock IP address
   */
  unblockIP(ip, reason = 'manual') {
    try {
      const blockData = this.blockedIPs.get(ip);

      if (blockData) {
        this.blockedIPs.delete(ip);

        logger.info('ip_unblocked', {
          ip,
          reason,
          previouslyBlockedAt: blockData.blockedAt
        });

        sentry.addBreadcrumb({
          message: 'IP address unblocked',
          category: 'security',
          level: 'info',
          data: {
            ip,
            reason
          }
        });
      }

      return true;
    } catch (error) {
      logger.error('ip_unblocking_error', { error: error.message });
      return false;
    }
  }

  /**
   * Get risk level based on abuse score
   */
  getRiskLevel(score) {
    if (score >= this.abuseThresholds.critical) return 'critical';
    if (score >= this.abuseThresholds.high) return 'high';
    if (score >= this.abuseThresholds.medium) return 'medium';
    return 'low';
  }

  /**
   * Helper methods
   */
  isPrivateIP(ip) {
    const privateRanges = [
      /^10\./,
      /^172\.(1[6-9]|2[0-9]|3[0-1])\./,
      /^192\.168\./,
      /^127\./,
      /^169\.254\./,
      /^::1$/,
      /^fc00:/,
      /^fe80:/
    ];

    return privateRanges.some(range => range.test(ip));
  }

  isProxyIP(ip) {
    // This would integrate with a proxy detection service
    // For now, just check common proxy indicators
    return false;
  }

  hasSuspiciousIPPattern(ip) {
    // Check for patterns like repeated digits, sequential numbers, etc.
    return /\d{4,}/.test(ip) || /(\d)\1{3,}/.test(ip);
  }

  getObjectDepth(obj) {
    if (typeof obj !== 'object' || obj === null) {
      return 0;
    }

    let maxDepth = 0;
    for (const key in obj) {
      if (obj.hasOwnProperty(key)) {
        const depth = this.getObjectDepth(obj[key]);
        maxDepth = Math.max(maxDepth, depth);
      }
    }

    return maxDepth + 1;
  }

  /**
   * Get abuse statistics
   */
  getAbuseStats() {
    try {
      const stats = {
        totalBlockedIPs: this.blockedIPs.size,
        totalAbuseAttempts: 0,
        abuseByRiskLevel: {
          low: 0,
          medium: 0,
          high: 0,
          critical: 0
        },
        topAbusePatterns: {},
        abuseByIP: {},
        averageAbuseScore: 0
      };

      let totalScore = 0;
      let scoreCount = 0;

      // Count abuse attempts
      for (const [key, attempts] of this.abuseAttempts.entries()) {
        stats.totalAbuseAttempts += attempts.length;

        for (const attempt of attempts) {
          stats.abuseByRiskLevel[attempt.riskLevel]++;
          totalScore += attempt.abuseScore;
          scoreCount++;

          // Count patterns
          for (const pattern of attempt.detectedPatterns) {
            stats.topAbusePatterns[pattern] = (stats.topAbusePatterns[pattern] || 0) + 1;
          }
        }
      }

      if (scoreCount > 0) {
        stats.averageAbuseScore = totalScore / scoreCount;
      }

      // Sort top patterns
      stats.topAbusePatterns = Object.entries(stats.topAbusePatterns)
        .sort(([,a], [,b]) => b - a)
        .slice(0, 10)
        .reduce((obj, [pattern, count]) => {
          obj[pattern] = count;
          return obj;
        }, {});

      return stats;
    } catch (error) {
      logger.error('abuse_stats_error', { error: error.message });
      return {
        totalBlockedIPs: 0,
        totalAbuseAttempts: 0,
        abuseByRiskLevel: { low: 0, medium: 0, high: 0, critical: 0 },
        topAbusePatterns: {},
        abuseByIP: {},
        averageAbuseScore: 0
      };
    }
  }

  /**
   * Clean up expired data
   */
  cleanupExpiredData() {
    try {
      const now = Date.now();
      let cleanedBlocks = 0;
      let cleanedAttempts = 0;

      // Clean up expired IP blocks
      for (const [ip, blockData] of this.blockedIPs.entries()) {
        if (now > blockData.expiresAt) {
          this.unblockIP(ip, 'expired');
          cleanedBlocks++;
        }
      }

      // Clean up expired abuse attempts
      for (const [key, attempts] of this.abuseAttempts.entries()) {
        const recentAttempts = attempts.filter(
          attempt => now - attempt.timestamp < this.abuseWindow
        );

        if (recentAttempts.length === 0) {
          this.abuseAttempts.delete(key);
          cleanedAttempts++;
        } else {
          this.abuseAttempts.set(key, recentAttempts);
        }
      }

      if (cleanedBlocks > 0 || cleanedAttempts > 0) {
        logger.info('api_abuse_cleanup', {
          cleanedBlocks,
          cleanedAttempts
        });
      }
    } catch (error) {
      logger.error('api_abuse_cleanup_error', { error: error.message });
    }
  }
}

module.exports = new APIAbuseService();

const crypto = require('crypto');
const path = require('path');
const fs = require('fs').promises;
const { logger } = require('../utils/logger');
const { sentry } = require('../utils/sentry');

class FileSecurity {
  constructor() {
    this.allowedMimeTypes = new Set([
      'image/jpeg',
      'image/jpg',
      'image/png',
      'image/gif',
      'image/webp',
      'application/pdf',
      'text/plain',
      'application/msword',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
    ]);

    this.maxFileSize = 5 * 1024 * 1024; // 5MB
    this.scanFiles = this.scanFiles.bind(this);
    this.validateFile = this.validateFile.bind(this);
  }

  /**
   * Generate secure filename
   */
  generateSecureFilename(originalName, userId = null) {
    try {
      const ext = path.extname(originalName);
      const timestamp = Date.now();
      const random = crypto.randomBytes(8).toString('hex');
      const userPrefix = userId ? `${userId}_` : '';
      
      const secureName = `${userPrefix}${timestamp}_${random}${ext}`;
      
      logger.info('secure_filename_generated', { 
        originalName,
        secureName,
        userId 
      });

      return secureName;
    } catch (error) {
      logger.error('secure_filename_generation_failed', { 
        error: error.message,
        originalName 
      });
      throw new Error('Failed to generate secure filename');
    }
  }

  /**
   * Validate file upload
   */
  validateFile(req, res, next) {
    try {
      if (!req.file) {
        return res.status(400).json({
          success: false,
          message: 'No file uploaded',
          code: 'NO_FILE'
        });
      }

      const file = req.file;
      
      // Check file size
      if (file.size > this.maxFileSize) {
        // Clean up the file
        this.cleanupFile(file.path);
        
        return res.status(400).json({
          success: false,
          message: 'File too large. Maximum size is 5MB',
          code: 'FILE_TOO_LARGE'
        });
      }

      // Check MIME type
      if (!this.allowedMimeTypes.has(file.mimetype)) {
        // Clean up the file
        this.cleanupFile(file.path);
        
        return res.status(400).json({
          success: false,
          message: 'File type not allowed',
          code: 'INVALID_FILE_TYPE'
        });
      }

      // Check filename for suspicious patterns
      const suspiciousPatterns = [
        /\.\./,  // Path traversal
        /[<>:"|?*]/, // Invalid characters
        /\.(exe|bat|cmd|scr|pif|com)$/i, // Executable files
        /\.(php|asp|jsp|cgi|pl|py|rb|sh)$/i, // Script files
        /\.(zip|rar|tar|gz|7z)$/i // Archives (could contain malware)
      ];

      if (suspiciousPatterns.some(pattern => pattern.test(file.originalname))) {
        // Clean up the file
        this.cleanupFile(file.path);
        
        logger.warn('suspicious_filename_detected', {
          originalName: file.originalname,
          mimetype: file.mimetype,
          ip: req.ip
        });

        return res.status(400).json({
          success: false,
          message: 'Suspicious file name',
          code: 'SUSPICIOUS_FILENAME'
        });
      }

      // Generate secure filename
      const userId = req.user?.id;
      const secureFilename = this.generateSecureFilename(file.originalname, userId);
      
      // Store secure filename for later use
      req.secureFilename = secureFilename;

      next();
    } catch (error) {
      logger.error('file_validation_error', { error: error.message });
      sentry.captureException(error);
      
      // Clean up the file if it exists
      if (req.file) {
        this.cleanupFile(req.file.path);
      }
      
      res.status(500).json({
        success: false,
        message: 'File validation failed'
      });
    }
  }

  /**
   * Scan uploaded file for malware
   */
  async scanFiles(req, res, next) {
    try {
      if (!req.file) {
        return next();
      }

      const file = req.file;
      const scanResult = await this.performFileScan(file.path);

      if (!scanResult.safe) {
        // Clean up the malicious file
        this.cleanupFile(file.path);
        
        logger.error('malicious_file_detected', {
          filename: file.originalname,
          scanResult,
          ip: req.ip,
          userId: req.user?.id
        });

        sentry.addBreadcrumb({
          message: 'Malicious file upload detected',
          category: 'security',
          level: 'error',
          data: {
            filename: file.originalname,
            scanResult,
            ip: req.ip,
            userId: req.user?.id
          }
        });

        return res.status(400).json({
          success: false,
          message: 'File contains malicious content',
          code: 'MALICIOUS_FILE'
        });
      }

      logger.info('file_scan_completed', {
        filename: file.originalname,
        scanResult,
        userId: req.user?.id
      });

      next();
    } catch (error) {
      logger.error('file_scan_error', { error: error.message });
      sentry.captureException(error);
      
      // On scan error, be conservative and reject the file
      if (req.file) {
        this.cleanupFile(req.file.path);
      }
      
      res.status(500).json({
        success: false,
        message: 'File scan failed'
      });
    }
  }

  /**
   * Perform file scan (basic implementation)
   */
  async performFileScan(filePath) {
    try {
      const fileBuffer = await fs.readFile(filePath);
      
      // Basic file signature checks
      const suspiciousSignatures = [
        Buffer.from([0x4D, 0x5A]), // PE executable
        Buffer.from([0x7F, 0x45, 0x4C, 0x46]), // ELF executable
        Buffer.from([0xCA, 0xFE, 0xBA, 0xBE]), // Java class
        Buffer.from([0x3C, 0x25, 0x50, 0x44, 0x46]), // PDF (safe, but check for embedded content)
        Buffer.from([0x50, 0x4B, 0x03, 0x04]), // ZIP (could contain malicious content)
        Buffer.from([0x1F, 0x8B, 0x08]), // GZIP
        Buffer.from([0x42, 0x5A, 0x68]), // BZIP2
      ];

      // Check for suspicious file signatures
      for (const signature of suspiciousSignatures) {
        if (fileBuffer.length >= signature.length) {
          const fileSignature = fileBuffer.slice(0, signature.length);
          if (fileSignature.equals(signature)) {
            return {
              safe: false,
              reason: 'Suspicious file signature detected',
              signature: signature.toString('hex')
            };
          }
        }
      }

      // Check for embedded scripts in images
      if (filePath.match(/\.(jpg|jpeg|png|gif)$/i)) {
        const scriptPattern = /<script|javascript:|vbscript:/i;
        const fileContent = fileBuffer.toString('binary', 0, Math.min(fileBuffer.length, 1024));
        
        if (scriptPattern.test(fileContent)) {
          return {
            safe: false,
            reason: 'Embedded script detected in image'
          };
        }
      }

      // Check for common malware patterns
      const malwarePatterns = [
        /eval\s*\(/gi,
        /document\.write\s*\(/gi,
        /window\.location/gi,
        /base64_decode/gi,
        /shell_exec/gi,
        /system\s*\(/gi,
        /exec\s*\(/gi,
      ];

      const fileContent = fileBuffer.toString('utf8', 0, Math.min(fileBuffer.length, 2048));
      
      for (const pattern of malwarePatterns) {
        if (pattern.test(fileContent)) {
          return {
            safe: false,
            reason: 'Suspicious code pattern detected'
          };
        }
      }

      return {
        safe: true,
        reason: 'File passed security scan'
      };
    } catch (error) {
      logger.error('file_scan_perform_error', { error: error.message, filePath });
      return {
        safe: false,
        reason: 'Scan failed'
      };
    }
  }

  /**
   * Clean up uploaded file
   */
  async cleanupFile(filePath) {
    try {
      if (filePath) {
        await fs.unlink(filePath);
        logger.info('file_cleaned_up', { filePath });
      }
    } catch (error) {
      logger.error('file_cleanup_error', { error: error.message, filePath });
    }
  }

  /**
   * Generate file hash for integrity checking
   */
  async generateFileHash(filePath) {
    try {
      const fileBuffer = await fs.readFile(filePath);
      const hash = crypto.createHash('sha256').update(fileBuffer).digest('hex');
      
      return hash;
    } catch (error) {
      logger.error('file_hash_generation_failed', { error: error.message, filePath });
      throw new Error('Failed to generate file hash');
    }
  }

  /**
   * Verify file integrity
   */
  async verifyFileIntegrity(filePath, expectedHash) {
    try {
      const actualHash = await this.generateFileHash(filePath);
      const isValid = crypto.timingSafeEqual(
        Buffer.from(actualHash, 'hex'),
        Buffer.from(expectedHash, 'hex')
      );

      logger.info('file_integrity_verified', {
        filePath,
        isValid
      });

      return isValid;
    } catch (error) {
      logger.error('file_integrity_verification_failed', { 
        error: error.message, 
        filePath 
      });
      return false;
    }
  }

  /**
   * Get file security statistics
   */
  getFileSecurityStats() {
    return {
      allowedMimeTypes: Array.from(this.allowedMimeTypes),
      maxFileSize: this.maxFileSize,
      scanEnabled: true
    };
  }

  /**
   * Add allowed MIME type
   */
  addAllowedMimeType(mimeType) {
    this.allowedMimeTypes.add(mimeType);
    logger.info('mime_type_added', { mimeType });
  }

  /**
   * Remove allowed MIME type
   */
  removeAllowedMimeType(mimeType) {
    this.allowedMimeTypes.delete(mimeType);
    logger.info('mime_type_removed', { mimeType });
  }

  /**
   * Set max file size
   */
  setMaxFileSize(size) {
    this.maxFileSize = size;
    logger.info('max_file_size_updated', { size });
  }
}

module.exports = new FileSecurity();

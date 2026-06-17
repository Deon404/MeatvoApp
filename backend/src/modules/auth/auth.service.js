const jwt = require('jsonwebtoken');
const crypto = require('crypto');

const generateTokens = (userId) => {
  const accessToken = jwt.sign(
    { 
      id: String(userId),
      type: 'access'
    }, 
    process.env.JWT_ACCESS_SECRET, 
    {
      expiresIn: process.env.JWT_ACCESS_EXPIRY || '15m',
      issuer: 'meatvo-app',
      audience: 'meatvo-users',
      algorithm: 'HS256'
    }
  );

  const refreshToken = jwt.sign(
    { 
      id: String(userId),
      type: 'refresh'
    }, 
    process.env.JWT_REFRESH_SECRET, 
    {
      expiresIn: process.env.JWT_REFRESH_EXPIRY || '7d',
      issuer: 'meatvo-app',
      audience: 'meatvo-users',
      algorithm: 'HS256'
    }
  );

  return { accessToken, refreshToken };
};

const verifyRefreshToken = (token) => {
  try {
    const decoded = jwt.verify(token, process.env.JWT_REFRESH_SECRET, {
      algorithms: ['HS256'],
      issuer: 'meatvo-app',
      audience: 'meatvo-users',
    });
    if (decoded.type !== 'refresh') return null;
    return decoded;
  } catch {
    return null;
  }
};

const sha256 = (value) => crypto.createHash('sha256').update(value).digest('hex');

module.exports = {
  generateTokens,
  verifyRefreshToken,
  sha256,
};

const express = require('express');
const router = express.Router();

const { protect } = require('../../middlewares/auth.middleware');
const { validate } = require('../../middlewares/validate.middleware');
const { ok } = require('../../utils/response');
const { query } = require('../../db/postgres');
const { fcmTokenSchema } = require('./users.validation');

router.get('/me', protect, (req, res) => {
  return ok(
    res,
    { id: String(req.user.id), phone: req.user.phone, role: req.user.role, name: req.user.name || '' },
    'Me'
  );
});

router.post('/fcm-token', protect, validate(fcmTokenSchema), async (req, res) => {
  try {
    const { fcm_token } = req.validated.body;

    await query(
      'UPDATE users SET fcm_token = $1 WHERE id = $2',
      [fcm_token, req.user.id]
    );

    return ok(res, { success: true }, 'FCM token saved');
  } catch (error) {
    console.error('Error saving FCM token:', error);
    return res.status(500).json({ success: false, message: 'Failed to save FCM token' });
  }
});

module.exports = router;

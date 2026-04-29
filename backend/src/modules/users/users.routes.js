const express = require('express');
const router = express.Router();

const { protect } = require('../../middlewares/auth.middleware');
const { ok } = require('../../utils/response');

router.get('/me', protect, (req, res) => {
  return ok(
    res,
    { id: String(req.user.id), phone: req.user.phone, role: req.user.role, name: req.user.name || '' },
    'Me'
  );
});

module.exports = router;


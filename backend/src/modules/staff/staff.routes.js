const express = require('express');
const router = express.Router();

const { protect } = require('../../middlewares/auth.middleware');
const { rbac } = require('../../middlewares/rbac.middleware');
const { validate } = require('../../middlewares/validate.middleware');
const { ROLES } = require('../../utils/roles');
const { listKitchenOrders } = require('./staff.controller');
const { listKitchenOrdersSchema } = require('./staff.validation');

router.get(
  '/orders',
  protect,
  rbac(ROLES.STAFF),
  validate(listKitchenOrdersSchema),
  listKitchenOrders
);

module.exports = router;

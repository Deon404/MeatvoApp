const express = require('express');
const router = express.Router();

const { protect } = require('../../middlewares/auth.middleware');
const { addressCreateRateLimiter } = require('../../middlewares/rateLimiter');
const { rbac } = require('../../middlewares/rbac.middleware');
const { validate } = require('../../middlewares/validate.middleware');
const { ROLES } = require('../../utils/roles');

const {
  getAddresses,
  addAddress,
  updateAddress,
  setDefaultAddress,
  deleteAddress,
} = require('./addresses.controller');
const {
  listAddressesSchema,
  createAddressSchema,
  updateAddressSchema,
  setDefaultAddressSchema,
  deleteAddressSchema,
} = require('./addresses.validation');

// Delivery partners may also save personal addresses (same user_id scoping in controller).
const addressUsers = [protect, rbac(ROLES.CUSTOMER, ROLES.DELIVERY)];

router.get('/', ...addressUsers, validate(listAddressesSchema), getAddresses);
router.post('/', ...addressUsers, addressCreateRateLimiter, validate(createAddressSchema), addAddress);
router.patch('/:id/default', ...addressUsers, validate(setDefaultAddressSchema), setDefaultAddress);
router.patch('/:id', ...addressUsers, validate(updateAddressSchema), updateAddress);
router.delete('/:id', ...addressUsers, validate(deleteAddressSchema), deleteAddress);

module.exports = router;

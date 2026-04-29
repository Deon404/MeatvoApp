const express = require('express');
const router = express.Router();

const { protect } = require('../../middlewares/auth.middleware');
const { rbac } = require('../../middlewares/rbac.middleware');
const { validate } = require('../../middlewares/validate.middleware');
const { ROLES } = require('../../utils/roles');

const { listAddresses, createAddress, deleteAddress } = require('./addresses.controller');
const { listAddressesSchema, createAddressSchema, deleteAddressSchema } = require('./addresses.validation');

router.use(protect, rbac(ROLES.CUSTOMER));
router.get('/', validate(listAddressesSchema), listAddresses);
router.post('/', validate(createAddressSchema), createAddress);
router.delete('/:id', validate(deleteAddressSchema), deleteAddress);

module.exports = router;

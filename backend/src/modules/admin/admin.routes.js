const express = require('express');
const router = express.Router();

const { protect } = require('../../middlewares/auth.middleware');
const { rbac } = require('../../middlewares/rbac.middleware');
const { validate } = require('../../middlewares/validate.middleware');
const { ROLES } = require('../../utils/roles');
const { updateDeliveryZone, toggleStoreOpen } = require('../settings/settings.controller');

const {
  dashboard,
  customers,
  deliveryPartners,
  toggleDeliveryPartner,
  patchDeliveryPartner,
  listOrdersCompat,
  patchOrderCompat,
  listCategoriesCompat,
  createCategoryCompat,
  patchCategoryCompat,
  listProductsCompat,
  createProductCompat,
  patchProductCompat,
  deleteProductCompat,
  changeUserRole,
  getAnalytics,
} = require('./admin.controller');
const {
  dashboardSchema,
  listCustomersSchema,
  listDeliveryPartnersSchema,
  toggleDeliveryPartnerSchema,
  listOrdersCompatSchema,
  patchOrderCompatSchema,
  listCompatSchema,
  upsertCategoryCompatSchema,
  upsertProductCompatSchema,
  patchDeliveryPartnerCompatSchema,
  deleteProductCompatSchema,
  changeUserRoleSchema,
} = require('./admin.validation');
const { updateOrderStatus } = require('../orders/orders.controller');
const { updateOrderStatusSchema } = require('../orders/orders.validation');

const { getTheme, getBanner, putTheme, putBanner } = require('../settings/settings.controller');
const { getSchema, putThemeSchema, putBannerSchema } = require('../settings/settings.validation');

router.use(protect, rbac(ROLES.ADMIN));

router.get('/dashboard', validate(dashboardSchema), dashboard);
router.get('/customers', validate(listCustomersSchema), customers);
router.get('/delivery-partners', validate(listDeliveryPartnersSchema), deliveryPartners);
router.patch('/users/:id/role', validate(changeUserRoleSchema), changeUserRole);
router.put('/delivery-partners/:id/toggle', validate(toggleDeliveryPartnerSchema), toggleDeliveryPartner);
router.patch('/delivery-partners/:id', validate(patchDeliveryPartnerCompatSchema), patchDeliveryPartner);

router.get('/orders', validate(listOrdersCompatSchema), listOrdersCompat);
router.patch('/orders/:id', validate(patchOrderCompatSchema), patchOrderCompat);
router.patch('/orders/:id/status', validate(updateOrderStatusSchema), updateOrderStatus);

router.get('/categories', validate(listCompatSchema), listCategoriesCompat);
router.post('/categories', validate(upsertCategoryCompatSchema), createCategoryCompat);
router.patch('/categories/:id', validate(upsertCategoryCompatSchema), patchCategoryCompat);

router.get('/products', validate(listCompatSchema), listProductsCompat);
router.post('/products', validate(upsertProductCompatSchema), createProductCompat);
router.patch('/products/:id', validate(upsertProductCompatSchema), patchProductCompat);
router.put('/products/:id', validate(upsertProductCompatSchema), patchProductCompat);
router.delete('/products/:id', validate(deleteProductCompatSchema), deleteProductCompat);

router.get('/settings/banner', validate(getSchema), getBanner);
router.put('/settings/banner', validate(putBannerSchema), putBanner);
router.get('/settings/theme', validate(getSchema), getTheme);
router.put('/settings/theme', validate(putThemeSchema), putTheme);

router.get('/analytics', validate(listCompatSchema), getAnalytics);

// Delivery zone + store open/close (TASK-002, TASK-005)
router.put('/store/delivery-zone', updateDeliveryZone);
router.patch('/store/toggle', toggleStoreOpen);

module.exports = router;

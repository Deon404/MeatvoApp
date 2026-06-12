const express = require('express');
const router = express.Router();

const { protect } = require('../../middlewares/auth.middleware');
const { rbac } = require('../../middlewares/rbac.middleware');
const { validate } = require('../../middlewares/validate.middleware');
const { ROLES } = require('../../utils/roles');
const {
  updateDeliveryZone,
  toggleStoreOpen,
  getBanner,
  putBanner,
  getTheme,
  putTheme,
} = require('../settings/settings.controller');

const {
  dashboard,
  customers,
  getUserDetail,
  toggleUserStatus,
  deliveryPartners,
  toggleDeliveryPartner,
  patchDeliveryPartner,
  listOrdersCompat,
  patchOrderCompat,
  listProducts,
  createProduct,
  updateProduct,
  deleteProduct,
  updateStock,
  listCategories,
  createCategory,
  updateCategory,
  deleteCategory,
  listBanners,
  createBanner,
  updateBanner,
  deleteBanner,
  getSettings,
  updateSettings,
  changeUserRole,
  getAnalytics,
} = require('./admin.controller');
const {
  dashboardSchema,
  listCustomersSchema,
  getUserDetailSchema,
  toggleUserStatusSchema,
  listDeliveryPartnersSchema,
  toggleDeliveryPartnerSchema,
  listOrdersCompatSchema,
  patchOrderCompatSchema,
  listCompatSchema,
  upsertCategoryCompatSchema,
  upsertProductCompatSchema,
  patchDeliveryPartnerCompatSchema,
  deleteProductCompatSchema,
  updateStockSchema,
  deleteCategorySchema,
  upsertBannerSchema,
  deleteBannerSchema,
  updateSettingsSchema,
  changeUserRoleSchema,
  updateDeliveryZoneSchema,
  toggleStoreOpenSchema,
} = require('./admin.validation');
const { updateOrderStatus, getOrder } = require('../orders/orders.controller');
const { updateOrderStatusSchema, getOrderSchema } = require('../orders/orders.validation');

const { getAdminFirebaseConfig } = require('../firebase/firebase.controller');
const { getSchema, putThemeSchema, putBannerSchema } = require('../settings/settings.validation');
const fileSecurity = require('../../security/file.security');
const {
  uploadImageMiddleware,
  handleMulterError,
  uploadImage,
} = require('../uploads/uploads.controller');

const adminOnly = [protect, rbac(ROLES.ADMIN)];

router.get('/dashboard', ...adminOnly, validate(dashboardSchema), dashboard);
router.get('/customers', ...adminOnly, validate(listCustomersSchema), customers);
router.get('/users', ...adminOnly, validate(listCustomersSchema), customers);
router.get('/users/:id', ...adminOnly, validate(getUserDetailSchema), getUserDetail);
router.patch('/users/:id/status', ...adminOnly, validate(toggleUserStatusSchema), toggleUserStatus);
router.get('/delivery-partners', ...adminOnly, validate(listDeliveryPartnersSchema), deliveryPartners);
router.patch('/users/:id/role', ...adminOnly, validate(changeUserRoleSchema), changeUserRole);
router.put('/delivery-partners/:id/toggle', ...adminOnly, validate(toggleDeliveryPartnerSchema), toggleDeliveryPartner);
router.patch('/delivery-partners/:id', ...adminOnly, validate(patchDeliveryPartnerCompatSchema), patchDeliveryPartner);

router.get('/orders', ...adminOnly, validate(listOrdersCompatSchema), listOrdersCompat);
router.get('/orders/:id', ...adminOnly, validate(getOrderSchema), getOrder);
router.patch('/orders/:id', ...adminOnly, validate(patchOrderCompatSchema), patchOrderCompat);
router.patch('/orders/:id/status', ...adminOnly, validate(updateOrderStatusSchema), updateOrderStatus);

// PRODUCTS
router.get('/products', ...adminOnly, validate(listCompatSchema), listProducts);
router.post('/products', ...adminOnly, validate(upsertProductCompatSchema), createProduct);
router.patch('/products/:id', ...adminOnly, validate(upsertProductCompatSchema), updateProduct);
router.put('/products/:id', ...adminOnly, validate(upsertProductCompatSchema), updateProduct);
router.delete('/products/:id', ...adminOnly, validate(deleteProductCompatSchema), deleteProduct);
router.patch('/products/:id/stock', ...adminOnly, validate(updateStockSchema), updateStock);

// CATEGORIES
router.get('/categories', ...adminOnly, validate(listCompatSchema), listCategories);
router.post('/categories', ...adminOnly, validate(upsertCategoryCompatSchema), createCategory);
router.patch('/categories/:id', ...adminOnly, validate(upsertCategoryCompatSchema), updateCategory);
router.delete('/categories/:id', ...adminOnly, validate(deleteCategorySchema), deleteCategory);

// BANNERS
router.get('/banners', ...adminOnly, validate(listCompatSchema), listBanners);
router.post('/banners', ...adminOnly, validate(upsertBannerSchema), createBanner);
router.patch('/banners/:id', ...adminOnly, validate(upsertBannerSchema), updateBanner);
router.delete('/banners/:id', ...adminOnly, validate(deleteBannerSchema), deleteBanner);

// SETTINGS
router.get('/settings', ...adminOnly, validate(listCompatSchema), getSettings);
router.patch('/settings', ...adminOnly, validate(updateSettingsSchema), updateSettings);
router.get('/settings/banner', ...adminOnly, validate(getSchema), getBanner);
router.put('/settings/banner', ...adminOnly, validate(putBannerSchema), putBanner);
router.get('/settings/theme', ...adminOnly, validate(getSchema), getTheme);
router.put('/settings/theme', ...adminOnly, validate(putThemeSchema), putTheme);

router.get('/analytics', ...adminOnly, validate(listCompatSchema), getAnalytics);

router.get('/firebase-config', ...adminOnly, getAdminFirebaseConfig);

// IMAGE UPLOAD
router.post(
  '/upload/image',
  ...adminOnly,
  uploadImageMiddleware,
  handleMulterError,
  fileSecurity.validateFile,
  fileSecurity.scanFiles,
  uploadImage
);

// Delivery zone + store open/close (TASK-002, TASK-005)
router.put('/store/delivery-zone', ...adminOnly, validate(updateDeliveryZoneSchema), updateDeliveryZone);
router.patch('/store/toggle', ...adminOnly, validate(toggleStoreOpenSchema), toggleStoreOpen);

// Route optimization for admins
const { getAdminOptimizedRoute, assignMultiRiderRoutes } = require('../delivery/delivery.controller');
router.get('/delivery/route/optimize', ...adminOnly, getAdminOptimizedRoute);
router.post('/delivery/assign-routes', ...adminOnly, assignMultiRiderRoutes);

module.exports = router;

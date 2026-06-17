const express = require('express');
const router = express.Router();

const { protect, optionalAuth } = require('../../middlewares/auth.middleware');
const { rbac } = require('../../middlewares/rbac.middleware');
const { validate } = require('../../middlewares/validate.middleware');
const { ROLES } = require('../../utils/roles');

const {
  listProducts,
  getProductById,
  getProductRating,
  getCategories,
  getFeaturedProducts,
  searchProducts,
  createProduct,
  updateProduct,
  deleteProduct,
} = require('./products.controller');

const {
  listProductsSchema,
  getProductByIdSchema,
  getCategoriesSchema,
  getFeaturedProductsSchema,
  searchProductsSchema,
  createProductSchema,
  updateProductSchema,
  deleteProductSchema,
} = require('./products.validation');

router.get('/', optionalAuth, validate(listProductsSchema), listProducts);

router.get('/categories', optionalAuth, getCategories);

router.get('/featured', optionalAuth, getFeaturedProducts);

router.get('/search', optionalAuth, searchProducts);

router.get('/:id/rating', optionalAuth, getProductRating);

router.get('/:id', optionalAuth, getProductById);

router.post('/', protect, rbac(ROLES.ADMIN), validate(createProductSchema), createProduct);

router.put('/:id', protect, rbac(ROLES.ADMIN), validate(updateProductSchema), updateProduct);

router.delete('/:id', protect, rbac(ROLES.ADMIN), validate(deleteProductSchema), deleteProduct);

router.post('/admin/products', protect, rbac(ROLES.ADMIN), validate(createProductSchema), createProduct);

router.put('/admin/products/:id', protect, rbac(ROLES.ADMIN), validate(updateProductSchema), updateProduct);

router.delete('/admin/products/:id', protect, rbac(ROLES.ADMIN), validate(deleteProductSchema), deleteProduct);

module.exports = router;


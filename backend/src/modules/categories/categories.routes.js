const express = require('express');
const router = express.Router();

const { protect, optionalAuth } = require('../../middlewares/auth.middleware');
const { rbac } = require('../../middlewares/rbac.middleware');
const { validate } = require('../../middlewares/validate.middleware');
const { ROLES } = require('../../utils/roles');

const {
  listCategories,
  createCategory,
  updateCategory,
  deleteCategory,
} = require('./categories.controller');

const {
  listCategoriesSchema,
  createCategorySchema,
  updateCategorySchema,
  deleteCategorySchema,
} = require('./categories.validation');

router.get('/', optionalAuth, validate(listCategoriesSchema), listCategories);

router.post('/', protect, rbac(ROLES.ADMIN), validate(createCategorySchema), createCategory);
router.put('/:id', protect, rbac(ROLES.ADMIN), validate(updateCategorySchema), updateCategory);
router.delete('/:id', protect, rbac(ROLES.ADMIN), validate(deleteCategorySchema), deleteCategory);

module.exports = router;


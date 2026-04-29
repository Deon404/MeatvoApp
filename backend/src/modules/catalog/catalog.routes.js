const express = require('express');
const router = express.Router();

const { validate } = require('../../middlewares/validate.middleware');
const { listCategoriesSchema, listProductsSchema } = require('./catalog.validation');
const { listCategories, listProducts } = require('./catalog.controller');

router.get('/categories', validate(listCategoriesSchema), listCategories);
router.get('/products', validate(listProductsSchema), listProducts);

module.exports = router;


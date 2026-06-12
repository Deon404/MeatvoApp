const express = require('express');
const router = express.Router();

const { protect } = require('../../middlewares/auth.middleware');
const { validate } = require('../../middlewares/validate.middleware');
const {
    getCartSchema,
    addToCartSchema,
    updateCartItemSchema,
    removeFromCartSchema,
    clearCartSchema,
    getCartCountSchema
} = require('./cart.validation');
const {
    getCart,
    addToCart,
    updateCartItem,
    removeFromCart,
    clearCart,
    getCartCount
} = require('./cart.controller');

router.get('/', protect, validate(getCartSchema), getCart);
router.get('/count', protect, validate(getCartCountSchema), getCartCount);

router.post('/', protect, validate(addToCartSchema), addToCart);
router.post('/add', protect, validate(addToCartSchema), addToCart);
router.put('/:itemId', protect, validate(updateCartItemSchema), updateCartItem);
router.put('/update', protect, validate(updateCartItemSchema), updateCartItem);
router.delete('/:itemId', protect, validate(removeFromCartSchema), removeFromCart);
router.delete('/remove/:productId', protect, validate(removeFromCartSchema), removeFromCart);
router.delete('/', protect, validate(clearCartSchema), clearCart);
router.delete('/clear', protect, validate(clearCartSchema), clearCart);

module.exports = router;


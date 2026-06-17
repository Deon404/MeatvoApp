/**
 * Delivery Slots Controller
 * Legacy slot endpoints — express delivery only; slots are no longer used.
 */

const asyncHandler = require('express-async-handler');
const { ok, fail } = require('../../utils/response');

/**
 * @deprecated Express delivery only — returns empty list.
 * @route GET /api/delivery/slots?date=YYYY-MM-DD
 */
const getAvailableSlots = asyncHandler(async (req, res) => {
    return ok(
        res,
        { slots: [], deprecated: true, message: 'Express delivery only — slots are no longer used' },
        'Delivery slots deprecated'
    );
});

/**
 * @deprecated Slot booking is handled via checkout flow (POST /api/orders).
 * @route POST /api/delivery/slots/:id/book
 */
const bookSlot = asyncHandler(async (req, res) => {
    return fail(res, 410, 'Delivery slots are deprecated — use express checkout.');
});

/**
 * @deprecated
 * @route POST /api/delivery/slots/:id/release
 */
const releaseSlot = asyncHandler(async (req, res) => {
    return fail(res, 410, 'Delivery slots are deprecated.');
});

/**
 * @deprecated
 * @route GET /api/delivery/slots/:id
 */
const getSlotById = asyncHandler(async (req, res) => {
    return fail(res, 410, 'Delivery slots are deprecated — use express checkout.');
});

module.exports = {
    getAvailableSlots,
    bookSlot,
    releaseSlot,
    getSlotById,
};

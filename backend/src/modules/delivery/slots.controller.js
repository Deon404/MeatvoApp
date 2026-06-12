/**
 * Delivery Slots Controller
 * Handles delivery time slot availability and booking
 */

const asyncHandler = require('express-async-handler');
const { query, withTransaction } = require('../../db/postgres');
const { ok, fail } = require('../../utils/response');
const redis = require('../../db/redis');
const { combineDateAndTime } = require('../../utils/eta-calculator');

const CACHE_TTL_SLOTS = 300; // 5min cache
const DEFAULT_CAPACITY = 20;

/**
 * Format slot time for display
 * @param {string} time - TIME value from database
 * @returns {string} - Formatted time string (e.g., "7:00 AM")
 */
const formatTime = (time) => {
    if (!time) return '';
    const [hours, minutes] = String(time).split(':');
    const hour = parseInt(hours);
    const min = parseInt(minutes.split('.')[0]);
    const ampm = hour >= 12 ? 'PM' : 'AM';
    const displayHour = hour % 12 || 12;
    const displayMin = min < 10 ? `0${min}` : min;
    return `${displayHour}:${displayMin} ${ampm}`;
};

const formatDateKey = (value) => {
    if (!value) return '';
    if (typeof value === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(value)) {
        return value;
    }
    const date = new Date(value);
    const y = date.getFullYear();
    const m = String(date.getMonth() + 1).padStart(2, '0');
    const d = String(date.getDate()).padStart(2, '0');
    return `${y}-${m}-${d}`;
};

const isSlotPast = (slot) => {
    const slotEnd = combineDateAndTime(slot.slot_date, slot.end_time);
    return slotEnd < new Date();
};

const formatSlotRow = (slot) => {
    const remaining = Math.max(0, Number(slot.remaining ?? (slot.capacity - slot.booked)));
    const isFull = slot.is_full === true || remaining <= 0;
    const isPast = isSlotPast(slot);

    return {
        id: slot.id,
        name: slot.name,
        time: `${formatTime(slot.start_time)} - ${formatTime(slot.end_time)}`,
        date: formatDateKey(slot.slot_date),
        capacity: slot.capacity,
        booked: slot.booked,
        remaining,
        available: !isFull && !isPast,
        isFull,
        isPast,
        isToday: formatDateKey(slot.slot_date) === formatDateKey(new Date()),
    };
};

/**
 * Get available delivery slots
 * @route GET /api/delivery/slots?date=YYYY-MM-DD
 */
const getAvailableSlots = asyncHandler(async (req, res) => {
    const requestedDate = req.query.date;

    // Ensure slots are generated
    await query('SELECT auto_generate_delivery_slots()');

    let slots;

    if (requestedDate) {
        // Validate date format
        const dateRegex = /^\d{4}-\d{2}-\d{2}$/;
        if (!dateRegex.test(requestedDate)) {
            return fail(res, 400, 'Date must be in YYYY-MM-DD format', { code: 'INVALID_DATE_FORMAT' });
        }

        // Get slots for specific date
        const { rows } = await query(
            `SELECT id, name, start_time, end_time, slot_date, capacity, booked,
              COALESCE(max_orders, 15) AS max_orders,
              COALESCE(current_orders, booked, 0) AS current_orders,
              (capacity - booked) AS remaining,
              (booked >= capacity) AS is_full
       FROM delivery_slots
       WHERE slot_date = $1 AND is_active = true
       ORDER BY 
         CASE name WHEN 'Morning' THEN 0 ELSE 1 END`,
            [requestedDate]
        );
        slots = rows;
    } else {
        // Get slots for today and next 7 days
        const { rows } = await query(
            `SELECT id, name, start_time, end_time, slot_date, capacity, booked,
              COALESCE(max_orders, 15) AS max_orders,
              COALESCE(current_orders, booked, 0) AS current_orders,
              (capacity - booked) AS remaining,
              (booked >= capacity) AS is_full
       FROM delivery_slots
       WHERE slot_date >= CURRENT_DATE 
         AND slot_date < CURRENT_DATE + INTERVAL '7 days'
         AND is_active = true
       ORDER BY slot_date, 
         CASE name WHEN 'Morning' THEN 0 ELSE 1 END
       LIMIT 20`
        );
        slots = rows;
    }

    // Format slots for response
    const formattedSlots = slots.map(formatSlotRow);

    // Filter out full and past slots from customer-facing response
    const availableSlots = formattedSlots.filter(slot => slot.available);

    return ok(res, { 
        slots: availableSlots,
        allSlots: formattedSlots // Include all for admin/debugging
    }, 'Delivery slots');
});

/**
 * Book a slot (increment booked count)
 * @deprecated Slot booking is handled via checkout flow (POST /api/orders).
 * @route POST /api/delivery/slots/:id/book
 */
const bookSlot = asyncHandler(async (req, res) => {
    return fail(res, 410, 'Slot booking is handled via checkout flow.');
});

/**
 * Release a slot (decrement booked count)
 * @route POST /api/delivery/slots/:id/release
 */
const releaseSlot = asyncHandler(async (req, res) => {
    const slotId = Number(req.params.id);
    const quantity = Number(req.body.quantity || 1);

    if (!Number.isInteger(slotId) || slotId <= 0) {
        return fail(res, 400, 'Invalid slot id');
    }
    if (!Number.isInteger(quantity) || quantity <= 0) {
        return fail(res, 400, 'Invalid quantity');
    }

    await withTransaction(async (client) => {
        // Update booked count
        await client.query(
            'UPDATE delivery_slots SET booked = GREATEST(0, booked - $1) WHERE id = $2',
            [quantity, slotId]
        );
    });

    // Clear cache
    await redis.del('delivery:slots:*');

    return ok(res, { message: 'Slot released successfully' }, 'Slot released');
});

/**
 * Get slot by ID
 * @route GET /api/delivery/slots/:id
 */
const getSlotById = asyncHandler(async (req, res) => {
    const slotId = Number(req.params.id);

    if (!Number.isInteger(slotId) || slotId <= 0) {
        return fail(res, 400, 'Invalid slot id');
    }

    const { rows } = await query(
        `SELECT id, name, start_time, end_time, slot_date, capacity, booked,
            (capacity - booked) AS remaining,
            (booked >= capacity) AS is_full
     FROM delivery_slots
     WHERE id = $1`,
        [slotId]
    );

    if (!rows[0]) {
        return fail(res, 404, 'Slot not found');
    }

    const slot = rows[0];
    const formattedSlot = formatSlotRow({
        ...slot,
        remaining: slot.remaining,
        is_full: slot.is_full,
    });

    return ok(res, { slot: formattedSlot }, 'Slot details');
});

/**
 * Admin: Update slot capacity
 * @route PUT /api/admin/delivery/slots/:id/capacity
 */
const updateSlotCapacity = asyncHandler(async (req, res) => {
    const slotId = Number(req.params.id);
    const capacity = Number(req.body.capacity);

    if (!Number.isInteger(slotId) || slotId <= 0) {
        return fail(res, 400, 'Invalid slot id');
    }
    if (!Number.isInteger(capacity) || capacity < 1) {
        return fail(res, 400, 'Invalid capacity');
    }

    const { rows } = await query(
        'UPDATE delivery_slots SET capacity = $1 WHERE id = $2 RETURNING *',
        [capacity, slotId]
    );

    if (!rows[0]) {
        return fail(res, 404, 'Slot not found');
    }

    // Clear cache
    await redis.del('delivery:slots:*');

    return ok(res, { slot: rows[0] }, 'Capacity updated');
});

module.exports = {
    getAvailableSlots,
    bookSlot,
    releaseSlot,
    getSlotById,
    updateSlotCapacity
};
/**
 * Delivery Slots Controller
 * Handles delivery time slot availability and booking
 */

const asyncHandler = require('express-async-handler');
const { query, withTransaction } = require('../../db/postgres');
const { ok, fail } = require('../../utils/response');
const redis = require('../../db/redis');

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
            return fail(res, 400, 'INVALID_DATE_FORMAT', 'Date must be in YYYY-MM-DD format');
        }

        // Get slots for specific date
        const { rows } = await query(
            `SELECT id, name, start_time, end_time, slot_date, capacity, booked,
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
    const formattedSlots = slots.map(slot => ({
        id: slot.id,
        name: slot.name,
        time: `${formatTime(slot.start_time)} - ${formatTime(slot.end_time)}`,
        date: slot.slot_date,
        capacity: slot.capacity,
        booked: slot.booked,
        remaining: Math.max(0, slot.remaining),
        isFull: slot.is_full || slot.remaining <= 0,
        isToday: slot.slot_date === new Date().toISOString().split('T')[0]
    }));

    return ok(res, { slots: formattedSlots }, 'Delivery slots');
});

/**
 * Book a slot (increment booked count)
 * @route POST /api/delivery/slots/:id/book
 */
const bookSlot = asyncHandler(async (req, res) => {
    const slotId = req.params.id;
    const quantity = req.body.quantity || 1;

    const result = await withTransaction(async (client) => {
        // Get slot
        const { rows: slotRows } = await client.query(
            'SELECT * FROM delivery_slots WHERE id = $1 FOR UPDATE',
            [slotId]
        );

        if (!slotRows[0]) {
            throw { status: 404, message: 'Slot not found' };
        }

        const slot = slotRows[0];

        // Check availability
        const remaining = slot.capacity - slot.booked;
        if (remaining < quantity) {
            throw { status: 400, code: 'SLOT_FULL', message: 'Slot is full or insufficient capacity' };
        }

        // Check if slot is in the past
        if (new Date(slot.slot_date) < new Date().setHours(0, 0, 0, 0)) {
            throw { status: 400, code: 'INVALID_SLOT', message: 'Cannot book past slots' };
        }

        // Update booked count
        await client.query(
            'UPDATE delivery_slots SET booked = booked + $1 WHERE id = $2',
            [quantity, slotId]
        );

        // Return updated slot
        const { rows } = await client.query(
            'SELECT * FROM delivery_slots WHERE id = $1',
            [slotId]
        );

        return rows[0];
    });

    const formattedSlot = {
        id: result.id,
        name: result.name,
        time: `${formatTime(result.start_time)} - ${formatTime(result.end_time)}`,
        date: result.slot_date,
        capacity: result.capacity,
        booked: result.booked,
        remaining: Math.max(0, result.capacity - result.booked),
        isFull: result.booked >= result.capacity
    };

    // Clear cache
    await redis.del('delivery:slots:*');

    return ok(res, { slot: formattedSlot }, 'Slot booked successfully');
});

/**
 * Release a slot (decrement booked count)
 * @route POST /api/delivery/slots/:id/release
 */
const releaseSlot = asyncHandler(async (req, res) => {
    const slotId = req.params.id;
    const quantity = req.body.quantity || 1;

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
    const slotId = req.params.id;

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
    const formattedSlot = {
        id: slot.id,
        name: slot.name,
        time: `${formatTime(slot.start_time)} - ${formatTime(slot.end_time)}`,
        date: slot.slot_date,
        capacity: slot.capacity,
        booked: slot.booked,
        remaining: Math.max(0, slot.remaining),
        isFull: slot.is_full || slot.remaining <= 0
    };

    return ok(res, { slot: formattedSlot }, 'Slot details');
});

/**
 * Admin: Update slot capacity
 * @route PUT /api/admin/delivery/slots/:id/capacity
 */
const updateSlotCapacity = asyncHandler(async (req, res) => {
    const slotId = req.params.id;
    const { capacity } = req.body;

    if (!capacity || capacity < 1) {
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
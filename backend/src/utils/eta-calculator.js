/**
 * ETA (Estimated Time of Arrival) Calculator
 *
 * Calculates delivery ETAs based on slot timing, packing queue, distance, and buffer.
 */

/**
 * Parse time string (HH:MM:SS or HH:MM) to components.
 * @param {string|Object} timeInput
 * @returns {{ hours: number, minutes: number, seconds: number }}
 */
function parseTimeString(timeInput) {
  let timeStr = timeInput;

  if (typeof timeInput === 'object' && timeInput !== null) {
    timeStr = timeInput.toString();
  }

  if (typeof timeStr !== 'string') {
    return { hours: 0, minutes: 0, seconds: 0 };
  }

  const parts = timeStr.split(':');
  return {
    hours: parseInt(parts[0], 10) || 0,
    minutes: parseInt(parts[1], 10) || 0,
    seconds: parseInt(parts[2], 10) || 0,
  };
}

/**
 * Combine a calendar date with a TIME value into a Date.
 * @param {Date|string} slotDate
 * @param {string|Object} timeValue
 * @returns {Date}
 */
function combineDateAndTime(slotDate, timeValue) {
  const date = new Date(slotDate);
  const parts = parseTimeString(timeValue);
  date.setHours(parts.hours, parts.minutes, parts.seconds, 0);
  return date;
}

/**
 * Format ETA for customer display: "by 12:30 PM" or "in ~45 mins".
 * @param {Date} etaTime
 * @param {Date} [referenceTime]
 * @returns {string}
 */
function formatETA(etaTime, referenceTime = new Date()) {
  if (!(etaTime instanceof Date) || isNaN(etaTime.getTime())) {
    return 'Not available';
  }

  const diffMs = etaTime.getTime() - referenceTime.getTime();
  const diffMins = Math.max(0, Math.round(diffMs / 60000));
  const sameDay = etaTime.toDateString() === referenceTime.toDateString();

  if (sameDay && diffMins > 5 && diffMins <= 120) {
    if (diffMins < 60) {
      return `in ~${diffMins} mins`;
    }
    const hours = Math.floor(diffMins / 60);
    const mins = diffMins % 60;
    if (mins === 0) return `in ~${hours} hr`;
    return `in ~${hours} hr ${mins} mins`;
  }

  const hours = etaTime.getHours();
  const minutes = etaTime.getMinutes();
  const ampm = hours >= 12 ? 'PM' : 'AM';
  const displayHours = hours % 12 || 12;
  const displayMinutes = minutes.toString().padStart(2, '0');

  return `by ${displayHours}:${displayMinutes} ${ampm}`;
}

/**
 * Calculate ETA for an order.
 *
 * @param {Date|string} slotStartTime - Slot start timestamp or HH:MM time string
 * @param {Date|string} slotEndTime - Slot end timestamp or HH:MM time string
 * @param {number} ordersInSlot - Orders in this slot (packing queue)
 * @param {number} deliveryDistanceKm - Store-to-delivery distance in km
 * @param {Date} [slotDate] - Required when slot times are HH:MM strings
 * @returns {Object}
 */
function calculateETA(slotStartTime, slotEndTime, ordersInSlot, deliveryDistanceKm, slotDate = null) {
  if (typeof ordersInSlot !== 'number' || ordersInSlot < 0) {
    ordersInSlot = 0;
  }

  if (typeof deliveryDistanceKm !== 'number' || deliveryDistanceKm < 0) {
    deliveryDistanceKm = 0;
  }

  const packingMinutes = Math.min(ordersInSlot * 3, 45);
  const deliveryMinutes = (deliveryDistanceKm / 20) * 60;
  const bufferMinutes = 10;
  const etaMinutes = packingMinutes + deliveryMinutes + bufferMinutes;

  const slotStart =
    slotStartTime instanceof Date
      ? new Date(slotStartTime.getTime())
      : combineDateAndTime(slotDate || new Date(), slotStartTime);

  const slotEnd =
    slotEndTime instanceof Date
      ? new Date(slotEndTime.getTime())
      : combineDateAndTime(slotDate || new Date(), slotEndTime);

  const eta = new Date(slotStart.getTime() + etaMinutes * 60000);
  const hardCap = new Date(slotEnd.getTime() + 30 * 60000);
  const cappedEta = eta > hardCap ? hardCap : eta;

  return {
    etaTime: cappedEta,
    etaMinutes: Math.round(etaMinutes),
    etaDisplay: formatETA(cappedEta),
    breakdown: {
      packingMinutes,
      deliveryMinutes: Math.ceil(deliveryMinutes),
      bufferMinutes,
      totalMinutes: Math.round(etaMinutes),
      distanceKm: Number(deliveryDistanceKm.toFixed(2)),
      wasCapped: eta > hardCap,
    },
  };
}

/**
 * Calculate ETA range for a delivery slot.
 */
function calculateETARange(slotStartTime, slotEndTime, ordersInSlot, minDistanceKm, maxDistanceKm, slotDate = null) {
  const minETA = calculateETA(slotStartTime, slotEndTime, ordersInSlot, minDistanceKm, slotDate);
  const maxETA = calculateETA(slotStartTime, slotEndTime, ordersInSlot, maxDistanceKm, slotDate);

  return {
    earliestETA: minETA.etaTime,
    latestETA: maxETA.etaTime,
    displayRange: `${minETA.etaDisplay} - ${maxETA.etaDisplay}`,
    minETA,
    maxETA,
  };
}

/**
 * Check if an order is likely to be delayed beyond the slot end.
 */
function isLikelyDelayed(etaTime, slotEndTime, slotDate = null) {
  if (!(etaTime instanceof Date) || isNaN(etaTime.getTime())) {
    return false;
  }

  const slotEnd =
    slotEndTime instanceof Date
      ? slotEndTime
      : combineDateAndTime(slotDate || new Date(), slotEndTime);

  return etaTime > slotEnd;
}

module.exports = {
  calculateETA,
  calculateETARange,
  isLikelyDelayed,
  formatETA,
  parseTimeString,
  combineDateAndTime,
};

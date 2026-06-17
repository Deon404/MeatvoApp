/**
 * ETA (Estimated Time of Arrival) Calculator
 *
 * Express delivery ETAs use prep queue + travel distance.
 * Legacy slot-based calculateETA is retained for backward compatibility.
 */

const EXPRESS_SLA_MINUTES = 60;
const EXPRESS_AVG_SPEED_KMH = 22;

const OUT_FOR_DELIVERY_STATUSES = new Set([
  'OUT_FOR_DELIVERY',
  'ON_THE_WAY',
  'ON_WAY',
  'PICKED_UP',
  'RIDER_NEARBY',
]);

const TRAFFIC_FACTORS = {
  7: 1.3,
  8: 1.4,
  9: 1.3,
  12: 1.2,
  13: 1.2,
  17: 1.4,
  18: 1.5,
  19: 1.3,
  20: 1.2,
  default: 1.0,
};

function getTrafficMultiplier(date = new Date()) {
  const hour = date.getHours();
  return TRAFFIC_FACTORS[hour] || TRAFFIC_FACTORS.default;
}

/**
 * Compute preparation minutes from cart line items and kitchen queue depth.
 * @param {Array<{ quantity?: number }>} items
 * @param {number} queueDepth
 */
function computePrepMinutes(items = [], queueDepth = 0) {
  const basePrep = 10;
  const perLineItem = 3;
  const perExtraUnit = 1;
  const queueMinutesPerOrder = 4;
  const maxPrep = 35;

  let itemPrep = 0;
  for (const item of items) {
    const qty = Math.max(1, Number(item.quantity) || 1);
    itemPrep += perLineItem + Math.max(0, qty - 1) * perExtraUnit;
  }

  const queuePrep = Math.min(Math.max(0, queueDepth) * queueMinutesPerOrder, 20);
  return Math.min(basePrep + itemPrep + queuePrep, maxPrep);
}

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
 * Express delivery ETA — prep + travel + buffer, capped at 1-hour SLA for display.
 *
 * @param {Object} params
 * @param {Date} [params.placedAt]
 * @param {Array<{ quantity?: number }>} [params.items]
 * @param {number} [params.queueDepth]
 * @param {number} params.distanceKm
 * @param {number} [params.trafficMultiplier]
 */
function calculateExpressETA({
  placedAt = new Date(),
  items = [],
  queueDepth = 0,
  distanceKm = 0,
  trafficMultiplier,
} = {}) {
  const referenceTime = placedAt instanceof Date ? placedAt : new Date(placedAt);
  const safeDistance =
    typeof distanceKm === 'number' && distanceKm >= 0 ? distanceKm : 0;
  const traffic = trafficMultiplier ?? getTrafficMultiplier(referenceTime);

  const prepMinutes = computePrepMinutes(items, queueDepth);
  const travelMinutes = ((safeDistance / EXPRESS_AVG_SPEED_KMH) * 60) * traffic;
  const bufferMinutes = 5;
  const totalMinutes = Math.round(prepMinutes + travelMinutes + bufferMinutes);
  const displayMinutes = Math.min(totalMinutes, EXPRESS_SLA_MINUTES);
  const etaTime = new Date(referenceTime.getTime() + totalMinutes * 60000);

  return {
    etaTime,
    etaMinutes: displayMinutes,
    etaDisplay: formatETA(etaTime, referenceTime),
    breakdown: {
      prepMinutes: Math.round(prepMinutes),
      travelMinutes: Math.ceil(travelMinutes),
      bufferMinutes,
      queueDepth: Math.max(0, Number(queueDepth) || 0),
      totalMinutes,
      displayMinutes,
      distanceKm: Number(safeDistance.toFixed(2)),
      trafficMultiplier: traffic,
      slaCapMinutes: EXPRESS_SLA_MINUTES,
    },
  };
}

/**
 * Live tracking ETA from rider GPS → customer address.
 * Before pickup: prep + rider travel. After pickup: travel only.
 */
function calculateRiderTrackingETA({
  orderStatus = 'CONFIRMED',
  riderLat,
  riderLng,
  deliveryLat,
  deliveryLng,
  items = [],
  queueDepth = 0,
  referenceTime = new Date(),
} = {}) {
  const { haversineDistanceKm } = require('./distance.util');

  const rLat = Number(riderLat);
  const rLng = Number(riderLng);
  const dLat = Number(deliveryLat);
  const dLng = Number(deliveryLng);

  if (![rLat, rLng, dLat, dLng].every(Number.isFinite)) {
    return null;
  }

  const straightKm = haversineDistanceKm(rLat, rLng, dLat, dLng);
  const roadDistanceKm = straightKm * 1.2;
  const traffic = getTrafficMultiplier(referenceTime);
  const travelMinutes = ((roadDistanceKm / EXPRESS_AVG_SPEED_KMH) * 60) * traffic;

  const normalized = String(orderStatus || '').toUpperCase();
  const prepMinutes = OUT_FOR_DELIVERY_STATUSES.has(normalized)
    ? 0
    : computePrepMinutes(items, queueDepth);
  const bufferMinutes = OUT_FOR_DELIVERY_STATUSES.has(normalized) ? 2 : 5;
  const totalMinutes = Math.round(prepMinutes + travelMinutes + bufferMinutes);
  const etaTime = new Date(referenceTime.getTime() + totalMinutes * 60000);

  return {
    etaTime,
    etaMinutes: totalMinutes,
    etaDisplay: formatETA(etaTime, referenceTime),
    distanceKm: Number(straightKm.toFixed(2)),
    roadDistanceKm: Number(roadDistanceKm.toFixed(2)),
    breakdown: {
      prepMinutes: Math.round(prepMinutes),
      travelMinutes: Math.ceil(travelMinutes),
      bufferMinutes,
      totalMinutes,
      trafficMultiplier: traffic,
    },
  };
}

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
  calculateExpressETA,
  calculateRiderTrackingETA,
  calculateETARange,
  isLikelyDelayed,
  formatETA,
  parseTimeString,
  combineDateAndTime,
  computePrepMinutes,
  getTrafficMultiplier,
  EXPRESS_SLA_MINUTES,
};

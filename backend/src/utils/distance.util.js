/**
 * distance.util.js
 * Haversine formula — calculates great-circle distance between two lat/lng points.
 * Used by: delivery zone check, rider distance display.
 */

const EARTH_RADIUS_KM = 6371;
const { STORE } = require('../config/businessRules');

/**
 * Converts degrees to radians.
 * @param {number} deg
 * @returns {number}
 */
const toRad = (deg) => (deg * Math.PI) / 180;

/**
 * Calculates the distance in kilometres between two geographic coordinates
 * using the Haversine formula.
 *
 * @param {number} lat1 - Latitude of point 1 (decimal degrees)
 * @param {number} lng1 - Longitude of point 1 (decimal degrees)
 * @param {number} lat2 - Latitude of point 2 (decimal degrees)
 * @param {number} lng2 - Longitude of point 2 (decimal degrees)
 * @returns {number} Distance in kilometres (rounded to 2 decimal places)
 */
const haversineDistanceKm = (lat1, lng1, lat2, lng2) => {
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);

  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) *
      Math.cos(toRad(lat2)) *
      Math.sin(dLng / 2) *
      Math.sin(dLng / 2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  const distance = EARTH_RADIUS_KM * c;

  return Math.round(distance * 100) / 100; // 2 decimal places
};

/**
 * Checks whether a given lat/lng point is within a specified radius of a center point.
 *
 * @param {number} centerLat  - Store center latitude
 * @param {number} centerLng  - Store center longitude
 * @param {number} pointLat   - Customer/point latitude
 * @param {number} pointLng   - Customer/point longitude
 * @param {number} radiusKm   - Delivery radius in kilometres (default 5)
 * @returns {{ deliverable: boolean, distanceKm: number }}
 */
const isWithinDeliveryZone = (centerLat, centerLng, pointLat, pointLng, radiusKm = STORE.deliveryRadiusKm) => {
  const distanceKm = haversineDistanceKm(centerLat, centerLng, pointLat, pointLng);
  return {
    deliverable: distanceKm <= radiusKm,
    distanceKm,
  };
};

module.exports = { haversineDistanceKm, isWithinDeliveryZone };

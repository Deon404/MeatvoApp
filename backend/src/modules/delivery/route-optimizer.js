/**
 * Nearest-neighbor TSP route optimizer for multi-stop delivery.
 */

const AVG_SPEED_KMH = 20;
const STOP_MINUTES = 5;

/**
 * Haversine distance between two coordinates in kilometres.
 */
function haversineKm(lat1, lng1, lat2, lng2) {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLng = ((lng2 - lng1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

/**
 * Optimize delivery route using nearest-neighbor heuristic.
 *
 * @param {number} storeLat
 * @param {number} storeLng
 * @param {Array} deliveryPoints
 * @returns {Object}
 */
function optimizeRoute(storeLat, storeLng, deliveryPoints = []) {
  if (!deliveryPoints.length) {
    return {
      route: [],
      totalDistanceKm: 0,
      estimatedMinutes: 0,
      storeLocation: { lat: storeLat, lng: storeLng },
      totalStops: 0,
    };
  }

  const validPoints = deliveryPoints.filter(
    (p) => Number.isFinite(Number(p.lat)) && Number.isFinite(Number(p.lng))
  );

  const visited = new Set();
  const route = [];
  let currentLat = storeLat;
  let currentLng = storeLng;
  let totalDistanceKm = 0;

  while (visited.size < validPoints.length) {
    let nearestIdx = -1;
    let nearestDist = Infinity;

    for (let i = 0; i < validPoints.length; i++) {
      if (visited.has(i)) continue;
      const point = validPoints[i];
      const dist = haversineKm(currentLat, currentLng, Number(point.lat), Number(point.lng));
      if (dist < nearestDist) {
        nearestDist = dist;
        nearestIdx = i;
      }
    }

    if (nearestIdx < 0) break;

    const nearest = validPoints[nearestIdx];
    visited.add(nearestIdx);
    totalDistanceKm += nearestDist;

    route.push({
      stopNumber: route.length + 1,
      orderId: nearest.orderId,
      lat: Number(nearest.lat),
      lng: Number(nearest.lng),
      address: nearest.address || 'Address not available',
      customerName: nearest.customerName || 'Customer',
      customerPhone: nearest.customerPhone || null,
      distanceFromPrevKm: Number(nearestDist.toFixed(2)),
      status: nearest.status,
    });

    currentLat = Number(nearest.lat);
    currentLng = Number(nearest.lng);
  }

  const travelMinutes = Math.ceil((totalDistanceKm / AVG_SPEED_KMH) * 60);
  const estimatedMinutes = travelMinutes + route.length * STOP_MINUTES;

  return {
    route,
    totalDistanceKm: Number(totalDistanceKm.toFixed(2)),
    estimatedMinutes,
    storeLocation: { lat: storeLat, lng: storeLng },
    totalStops: route.length,
  };
}

module.exports = { haversineKm, optimizeRoute };

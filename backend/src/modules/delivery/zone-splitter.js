/**
 * K-means clustering for zone-based order splitting across multiple riders.
 */

const { haversineKm, optimizeRoute } = require('./route-optimizer');

/**
 * Calculate average value from array of numbers.
 */
function avg(values) {
  if (!values || values.length === 0) return 0;
  const sum = values.reduce((acc, val) => acc + val, 0);
  return sum / values.length;
}

/**
 * Pick random centroids from orders array.
 */
function pickRandomCentroids(orders, numCentroids) {
  const shuffled = [...orders].sort(() => Math.random() - 0.5);
  return shuffled.slice(0, numCentroids).map(order => ({
    lat: order.lat,
    lng: order.lng,
  }));
}

/**
 * Find index of nearest centroid for a given order.
 */
function findNearestCentroidIndex(order, centroids) {
  let nearestIdx = 0;
  let nearestDist = Infinity;

  for (let i = 0; i < centroids.length; i++) {
    const dist = haversineKm(order.lat, order.lng, centroids[i].lat, centroids[i].lng);
    if (dist < nearestDist) {
      nearestDist = dist;
      nearestIdx = i;
    }
  }

  return nearestIdx;
}

/**
 * Balance zones to ensure no zone is empty or overloaded.
 * If a zone is empty, it borrows orders from the largest zone.
 * If zones are heavily unbalanced (e.g., 8 orders vs 2), redistribute.
 */
function balanceZones(zones, numRiders) {
  if (!zones || zones.length === 0) return zones;

  // Remove empty zones and collect orders
  const nonEmptyZones = zones.filter(zone => zone.length > 0);
  
  if (nonEmptyZones.length === 0) return zones;
  if (nonEmptyZones.length >= numRiders) return zones;

  // If we have fewer non-empty zones than riders, try to split largest zone
  while (nonEmptyZones.length < numRiders) {
    const largestZone = nonEmptyZones.reduce((max, zone) => 
      zone.length > max.length ? zone : max
    );

    if (largestZone.length <= 1) break;

    // Split the largest zone in half
    const midpoint = Math.floor(largestZone.length / 2);
    const newZone = largestZone.splice(midpoint);
    nonEmptyZones.push(newZone);
  }

  // Iteratively balance zones to ensure better distribution
  // Keep redistributing until zones are reasonably balanced
  let iterations = 0;
  const maxIterations = 10;
  
  while (iterations < maxIterations) {
    const sorted = [...nonEmptyZones].sort((a, b) => b.length - a.length);
    const largest = sorted[0];
    const smallest = sorted[sorted.length - 1];
    
    // Stop if zones are reasonably balanced (ratio <= 2:1)
    if (largest.length <= smallest.length * 2 || largest.length <= 2) {
      break;
    }
    
    // Calculate how many orders to move to achieve better balance
    const totalOrders = nonEmptyZones.reduce((sum, z) => sum + z.length, 0);
    const avgSize = totalOrders / nonEmptyZones.length;
    
    // Move enough orders to bring largest closer to average
    const targetLargest = Math.ceil(avgSize * 1.2); // Allow 20% above average
    const targetSmallest = Math.floor(avgSize * 0.8); // Allow 20% below average
    
    let toMove = 0;
    if (largest.length > targetLargest && smallest.length < targetSmallest) {
      // Move orders to bring both closer to their targets
      toMove = Math.min(
        largest.length - targetLargest,
        targetSmallest - smallest.length,
        Math.floor((largest.length - smallest.length) / 2)
      );
    }
    
    if (toMove > 0 && largest.length > toMove) {
      const movedOrders = largest.splice(-toMove);
      smallest.push(...movedOrders);
    } else {
      break;
    }
    
    iterations++;
  }

  return nonEmptyZones;
}

/**
 * Split orders into zones using K-means clustering.
 *
 * @param {Array} orders - Array of orders with lat, lng, orderId, customerName, address
 * @param {number} numRiders - Number of riders (zones)
 * @returns {Array} Array of zones with orders and centroids
 */
function splitOrdersIntoZones(orders, numRiders) {
  if (!orders || orders.length === 0) {
    return [];
  }

  // If orders <= riders, each order gets its own zone
  if (orders.length <= numRiders) {
    return orders.map((order, i) => ({
      zoneId: i + 1,
      orders: [order],
      centroid: { lat: order.lat, lng: order.lng },
    }));
  }

  // Initialize centroids randomly from orders
  let centroids = pickRandomCentroids(orders, numRiders);

  // K-means iterations (10 iterations)
  for (let iteration = 0; iteration < 10; iteration++) {
    // Assign each order to nearest centroid
    const zones = Array.from({ length: numRiders }, () => []);

    for (const order of orders) {
      const nearestIdx = findNearestCentroidIndex(order, centroids);
      zones[nearestIdx].push(order);
    }

    // Recalculate centroids (average lat/lng of zone)
    centroids = zones.map(zone => {
      if (zone.length === 0) {
        return { lat: 0, lng: 0 };
      }
      return {
        lat: avg(zone.map(o => o.lat)),
        lng: avg(zone.map(o => o.lng)),
      };
    });
  }

  // Final assignment with balanced zones
  const finalZones = Array.from({ length: numRiders }, () => []);
  for (const order of orders) {
    const nearestIdx = findNearestCentroidIndex(order, centroids);
    finalZones[nearestIdx].push(order);
  }

  // Balance zones if one is empty or heavily unbalanced
  const balancedZones = balanceZones(finalZones, numRiders);

  // Recalculate final centroids after balancing
  return balancedZones.map((zone, i) => ({
    zoneId: i + 1,
    orders: zone,
    centroid: {
      lat: avg(zone.map(o => o.lat)),
      lng: avg(zone.map(o => o.lng)),
    },
  }));
}

/**
 * Optimize routes for multiple riders by splitting orders into zones.
 *
 * @param {Array} orders - Array of orders with lat, lng, orderId, customerName, address
 * @param {number} numRiders - Number of riders
 * @param {number} storeLat - Store latitude
 * @param {number} storeLng - Store longitude
 * @returns {Object} Multi-rider route plan with zones
 */
function optimizeMultiRiderRoute(orders, numRiders, storeLat, storeLng) {
  if (!orders || orders.length === 0) {
    return {
      zones: [],
      totalOrders: 0,
      totalRiders: 0,
      storeLat,
      storeLng,
    };
  }

  // Filter out orders with invalid coordinates
  const validOrders = orders.filter(
    order => Number.isFinite(order.lat) && Number.isFinite(order.lng)
  );

  if (validOrders.length === 0) {
    return {
      zones: [],
      totalOrders: 0,
      totalRiders: 0,
      storeLat,
      storeLng,
    };
  }

  // Split orders into zones using K-means
  const zones = splitOrdersIntoZones(validOrders, numRiders);

  // Optimize route for each zone
  const optimizedZones = zones.map((zone, i) => {
    const routeOptimization = optimizeRoute(storeLat, storeLng, zone.orders);

    return {
      zoneId: zone.zoneId,
      riderSlot: i + 1,
      orderCount: zone.orders.length,
      totalDistanceKm: routeOptimization.totalDistanceKm,
      estimatedMinutes: routeOptimization.estimatedMinutes,
      centroid: zone.centroid,
      route: routeOptimization.route,
    };
  });

  return {
    zones: optimizedZones,
    totalOrders: validOrders.length,
    totalRiders: zones.length,
    storeLat,
    storeLng,
  };
}

module.exports = {
  splitOrdersIntoZones,
  optimizeMultiRiderRoute,
  pickRandomCentroids,
  findNearestCentroidIndex,
  balanceZones,
  avg,
};

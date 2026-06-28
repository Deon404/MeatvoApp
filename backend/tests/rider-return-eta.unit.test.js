const { haversineKm } = require('../src/modules/delivery/route-optimizer');
const { ETA, ROUTING, getTrafficMultiplier } = require('../src/config/businessRules');

/**
 * Pure-function replica of return ETA segment math for unit testing (no DB).
 */
function estimateReturnMinutesFromStops({ riderLat, riderLng, stops, storeLat, storeLng, avgSpeedKmh = 25 }) {
  let currentLat = riderLat;
  let currentLng = riderLng;
  let totalMinutes = 0;
  const remaining = [...stops];

  while (remaining.length) {
    let nearestIdx = 0;
    let nearestDist = Infinity;
    for (let i = 0; i < remaining.length; i++) {
      const dist = haversineKm(currentLat, currentLng, remaining[i].lat, remaining[i].lng);
      if (dist < nearestDist) {
        nearestDist = dist;
        nearestIdx = i;
      }
    }
    const stop = remaining.splice(nearestIdx, 1)[0];
    const roadKm = nearestDist * ETA.roadDistanceFactor;
    totalMinutes += Math.ceil((roadKm / ROUTING.avgSpeedKmh) * 60 * getTrafficMultiplier());
    totalMinutes += ROUTING.stopMinutes;
    currentLat = stop.lat;
    currentLng = stop.lng;
  }

  const returnDist = haversineKm(currentLat, currentLng, storeLat, storeLng);
  const returnRoadKm = returnDist * ETA.roadDistanceFactor;
  totalMinutes += Math.ceil((returnRoadKm / avgSpeedKmh) * 60 * getTrafficMultiplier());
  totalMinutes += ETA.bufferMinutes;

  return totalMinutes;
}

describe('rider return ETA — unit (no DB)', () => {
  const store = { lat: 12.9716, lng: 77.5946 };

  test('single stop adds stop time plus return leg', () => {
    const minutes = estimateReturnMinutesFromStops({
      riderLat: store.lat,
      riderLng: store.lng,
      stops: [{ lat: 12.972, lng: 77.595 }],
      storeLat: store.lat,
      storeLng: store.lng,
      avgSpeedKmh: 25,
    });
    expect(minutes).toBeGreaterThan(ROUTING.stopMinutes);
    expect(minutes).toBeLessThan(60);
  });

  test('multiple stops increase ETA vs single stop', () => {
    const single = estimateReturnMinutesFromStops({
      riderLat: store.lat,
      riderLng: store.lng,
      stops: [{ lat: 12.972, lng: 77.595 }],
      storeLat: store.lat,
      storeLng: store.lng,
    });
    const multi = estimateReturnMinutesFromStops({
      riderLat: store.lat,
      riderLng: store.lng,
      stops: [
        { lat: 12.972, lng: 77.595 },
        { lat: 12.973, lng: 77.596 },
      ],
      storeLat: store.lat,
      storeLng: store.lng,
    });
    expect(multi).toBeGreaterThan(single);
  });

  test('traffic multiplier is applied', () => {
    const hour = new Date().getHours();
    const factor = getTrafficMultiplier();
    expect(factor).toBe(ETA.trafficFactors[hour] ?? ETA.trafficFactors.default);
  });
});

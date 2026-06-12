/**
 * Earnings Service
 * Advanced earnings calculation for delivery partners
 * Formula: Base + Distance Bonus + Time Bonus + Peak Bonus + Performance Bonus
 */

const { query } = require('../db/postgres');

// Earnings configuration
const EARNINGS_CONFIG = {
  BASE_PERCENTAGE: 0.10, // 10% of order amount
  MIN_BASE_AMOUNT: 30, // Minimum ₹30 per delivery
  
  // Distance bonuses
  DISTANCE_FREE_KM: 2, // First 2 km included in base
  DISTANCE_RATE_PER_KM: 5, // ₹5 per km beyond free distance
  
  // Time bonuses
  TIME_FREE_MINUTES: 20, // First 20 minutes included
  TIME_RATE_PER_MINUTE: 2, // ₹2 per minute beyond free time
  
  // Peak hour multiplier
  PEAK_MULTIPLIER: 1.5, // 1.5x base during peak
  PEAK_HOURS: [
    { start: 12, end: 14 }, // Lunch: 12 PM - 2 PM
    { start: 19, end: 21 }, // Dinner: 7 PM - 9 PM
  ],
  
  // Performance bonus
  PERFORMANCE_BONUS_AMOUNT: 20, // ₹20 bonus
  PERFORMANCE_MIN_RATING: 4.5,
  PERFORMANCE_MIN_COMPLETION_RATE: 0.95,
};

/**
 * Check if a time falls within peak hours
 */
function isPeakHour(date) {
  const hour = date.getHours();
  return EARNINGS_CONFIG.PEAK_HOURS.some(
    peak => hour >= peak.start && hour < peak.end
  );
}

/**
 * Get rider performance metrics
 */
async function getRiderPerformanceMetrics(riderId) {
  const { rows } = await query(
    `SELECT 
      COALESCE(AVG(rating), 0) as avg_rating,
      COUNT(CASE WHEN status = 'DELIVERED' THEN 1 END) as delivered_count,
      COUNT(CASE WHEN status = 'CANCELLED' THEN 1 END) as cancelled_count,
      COUNT(*) as total_assignments
     FROM order_assignments
     WHERE delivery_partner_id = $1
     AND created_at >= NOW() - INTERVAL '30 days'`,
    [riderId]
  );

  if (!rows[0] || rows[0].total_assignments === 0) {
    return {
      rating: 0,
      completionRate: 0,
      deliveredCount: 0,
    };
  }

  const data = rows[0];
  const completionRate = data.total_assignments > 0
    ? (parseInt(data.delivered_count) / parseInt(data.total_assignments))
    : 0;

  return {
    rating: parseFloat(data.avg_rating) || 0,
    completionRate,
    deliveredCount: parseInt(data.delivered_count) || 0,
  };
}

/**
 * Calculate earnings for a single delivery
 */
async function calculateDeliveryEarnings(orderData, assignmentData) {
  const {
    total_amount: totalAmount,
    created_at: createdAt,
  } = orderData;

  const {
    delivery_partner_id: riderId,
    assigned_at: assignedAt,
    updated_at: completedAt,
    distance_km: distanceKm,
  } = assignmentData;

  // Base earnings (10% of order, minimum ₹30)
  const baseAmount = Math.max(
    totalAmount * EARNINGS_CONFIG.BASE_PERCENTAGE,
    EARNINGS_CONFIG.MIN_BASE_AMOUNT
  );

  // Distance bonus (beyond 2 km)
  const distance = distanceKm || 0;
  const extraDistance = Math.max(0, distance - EARNINGS_CONFIG.DISTANCE_FREE_KM);
  const distanceBonus = extraDistance * EARNINGS_CONFIG.DISTANCE_RATE_PER_KM;

  // Time bonus (beyond 20 minutes)
  const deliveryTimeMinutes = assignedAt && completedAt
    ? (new Date(completedAt) - new Date(assignedAt)) / (1000 * 60)
    : 0;
  const extraTime = Math.max(0, deliveryTimeMinutes - EARNINGS_CONFIG.TIME_FREE_MINUTES);
  const timeBonus = extraTime * EARNINGS_CONFIG.TIME_RATE_PER_MINUTE;

  // Peak hour bonus
  const orderDate = new Date(createdAt);
  const isPeak = isPeakHour(orderDate);
  const peakBonus = isPeak ? (baseAmount * (EARNINGS_CONFIG.PEAK_MULTIPLIER - 1)) : 0;

  // Performance bonus
  const performance = await getRiderPerformanceMetrics(riderId);
  const qualifiesForBonus = 
    performance.rating >= EARNINGS_CONFIG.PERFORMANCE_MIN_RATING &&
    performance.completionRate >= EARNINGS_CONFIG.PERFORMANCE_MIN_COMPLETION_RATE;
  const performanceBonus = qualifiesForBonus 
    ? EARNINGS_CONFIG.PERFORMANCE_BONUS_AMOUNT 
    : 0;

  // Calculate total
  const total = baseAmount + distanceBonus + timeBonus + peakBonus + performanceBonus;

  return {
    base: Math.round(baseAmount),
    distanceBonus: Math.round(distanceBonus),
    timeBonus: Math.round(timeBonus),
    peakBonus: Math.round(peakBonus),
    performanceBonus,
    total: Math.round(total),
    breakdown: {
      orderAmount: Math.round(totalAmount),
      distanceKm: Number(distance.toFixed(2)),
      deliveryTimeMinutes: Math.round(deliveryTimeMinutes),
      isPeakHour: isPeak,
      riderRating: Number(performance.rating.toFixed(2)),
      completionRate: Number((performance.completionRate * 100).toFixed(1)),
    },
  };
}

/**
 * Record earnings in history
 */
async function recordEarningsHistory(orderId, riderId, earnings) {
  // Create earnings history table if it doesn't exist
  await query(`
    CREATE TABLE IF NOT EXISTS rider_earnings_history (
      id BIGSERIAL PRIMARY KEY,
      order_id BIGINT REFERENCES orders(id),
      rider_id BIGINT,
      base_amount DECIMAL(10,2),
      distance_bonus DECIMAL(10,2),
      time_bonus DECIMAL(10,2),
      peak_bonus DECIMAL(10,2),
      performance_bonus DECIMAL(10,2),
      total_amount DECIMAL(10,2),
      order_amount DECIMAL(10,2),
      distance_km DECIMAL(10,2),
      delivery_time_minutes INTEGER,
      is_peak_hour BOOLEAN,
      rider_rating DECIMAL(3,2),
      completion_rate DECIMAL(5,2),
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  `);

  await query(
    `INSERT INTO rider_earnings_history 
     (order_id, rider_id, base_amount, distance_bonus, time_bonus, 
      peak_bonus, performance_bonus, total_amount, order_amount,
      distance_km, delivery_time_minutes, is_peak_hour, 
      rider_rating, completion_rate)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)`,
    [
      orderId,
      riderId,
      earnings.base,
      earnings.distanceBonus,
      earnings.timeBonus,
      earnings.peakBonus,
      earnings.performanceBonus,
      earnings.total,
      earnings.breakdown.orderAmount,
      earnings.breakdown.distanceKm,
      earnings.breakdown.deliveryTimeMinutes,
      earnings.breakdown.isPeakHour,
      earnings.breakdown.riderRating,
      earnings.breakdown.completionRate,
    ]
  );
}

/**
 * Update rider's total earnings
 */
async function updateRiderEarnings(riderId, earningsAmount) {
  await query(
    `UPDATE delivery_partners 
     SET earnings = COALESCE(earnings, 0) + $1,
         updated_at = CURRENT_TIMESTAMP
     WHERE user_id = $2`,
    [earningsAmount, riderId]
  );
}

/**
 * Get earnings breakdown for a time period
 */
async function getEarningsBreakdown(riderId, period = 'today') {
  let dateFilter = '';
  
  switch (period) {
    case 'today':
      dateFilter = "AND DATE(created_at) = CURRENT_DATE";
      break;
    case 'week':
      dateFilter = "AND created_at >= DATE_TRUNC('week', CURRENT_DATE)";
      break;
    case 'month':
      dateFilter = "AND created_at >= DATE_TRUNC('month', CURRENT_DATE)";
      break;
    default:
      dateFilter = '';
  }

  const { rows } = await query(
    `SELECT 
      COUNT(*) as delivery_count,
      COALESCE(SUM(base_amount), 0) as total_base,
      COALESCE(SUM(distance_bonus), 0) as total_distance_bonus,
      COALESCE(SUM(time_bonus), 0) as total_time_bonus,
      COALESCE(SUM(peak_bonus), 0) as total_peak_bonus,
      COALESCE(SUM(performance_bonus), 0) as total_performance_bonus,
      COALESCE(SUM(total_amount), 0) as total_earnings,
      COALESCE(AVG(distance_km), 0) as avg_distance,
      COALESCE(AVG(delivery_time_minutes), 0) as avg_delivery_time
     FROM rider_earnings_history
     WHERE rider_id = $1 ${dateFilter}`,
    [riderId]
  );

  return rows[0] || {
    delivery_count: 0,
    total_base: 0,
    total_distance_bonus: 0,
    total_time_bonus: 0,
    total_peak_bonus: 0,
    total_performance_bonus: 0,
    total_earnings: 0,
    avg_distance: 0,
    avg_delivery_time: 0,
  };
}

/**
 * Get projected earnings for pending orders
 */
async function getProjectedEarnings(riderId) {
  const { rows } = await query(
    `SELECT o.id, o.total_amount, o.created_at, oa.distance_km
     FROM orders o
     JOIN order_assignments oa ON oa.order_id = o.id
     WHERE oa.delivery_partner_id = (
       SELECT id FROM delivery_partners WHERE user_id = $1
     )
     AND oa.status IN ('ASSIGNED', 'ACCEPTED', 'PICKED')
     AND o.status NOT IN ('DELIVERED', 'CANCELLED')`,
    [riderId]
  );

  let totalProjected = 0;

  for (const order of rows) {
    const earnings = await calculateDeliveryEarnings(order, {
      delivery_partner_id: riderId,
      assigned_at: order.created_at,
      updated_at: new Date(),
      distance_km: order.distance_km || 2,
    });
    totalProjected += earnings.total;
  }

  return {
    pendingOrdersCount: rows.length,
    projectedEarnings: Math.round(totalProjected),
  };
}

module.exports = {
  calculateDeliveryEarnings,
  recordEarningsHistory,
  updateRiderEarnings,
  getEarningsBreakdown,
  getProjectedEarnings,
  getRiderPerformanceMetrics,
  EARNINGS_CONFIG,
};

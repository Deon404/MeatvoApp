/**
 * Freshness Utility
 * Handles product freshness checks and badge generation
 * 
 * Rules:
 * - Products auto-hidden if freshness_date > 2 days old
 * - "Fresh Today" badge if freshness_date == TODAY
 */

const FRESHNESS_THRESHOLD_DAYS = 2;

/**
 * Check if a product is within freshness window
 * @param {string|Date|null} freshnessDate - ISO date string or Date object
 * @returns {boolean} - true if product is fresh (within 2 days)
 */
const isProductFresh = (freshnessDate) => {
    if (!freshnessDate) return true; // No freshness date = always fresh (legacy products)

    const freshDate = new Date(freshnessDate);
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    freshDate.setHours(0, 0, 0, 0);

    const diffTime = today - freshDate;
    const diffDays = Math.floor(diffTime / (1000 * 60 * 60 * 24));

    return diffDays <= FRESHNESS_THRESHOLD_DAYS;
};

/**
 * Get freshness badge text for display
 * @param {string|Date|null} freshnessDate - ISO date string or Date object
 * @returns {string|null} - "Fresh Today" | "Day 2" | null (expired)
 */
const getFreshnessBadge = (freshnessDate) => {
    if (!freshnessDate) return null; // No freshness date = no badge

    const freshDate = new Date(freshnessDate);
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    freshDate.setHours(0, 0, 0, 0);

    const diffTime = today - freshDate;
    const diffDays = Math.floor(diffTime / (1000 * 60 * 60 * 24));

    if (diffDays === 0) return 'Fresh Today';
    if (diffDays === 1) return 'Day 2';
    if (diffDays === 2) return 'Last Day';

    return null; // Expired
};

/**
 * Get freshness date formatted for display
 * @param {string|Date|null} freshnessDate - ISO date string or Date object
 * @returns {string} - Formatted date or "N/A"
 */
const formatFreshnessDate = (freshnessDate) => {
    if (!freshnessDate) return 'N/A';

    const date = new Date(freshnessDate);
    const options = { month: 'short', day: 'numeric' };
    return date.toLocaleDateString('en-IN', options);
};

/**
 * Calculate days remaining until expiry
 * @param {string|Date|null} freshnessDate - ISO date string or Date object
 * @returns {number} - Days remaining (0 = today, negative = expired)
 */
const getDaysRemaining = (freshnessDate) => {
    if (!freshnessDate) return Infinity;

    const freshDate = new Date(freshnessDate);
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    freshDate.setHours(0, 0, 0, 0);

    const diffTime = freshDate - today;
    const diffDays = Math.floor(diffTime / (1000 * 60 * 60 * 24));

    return diffDays;
};

/**
 * SQL WHERE clause for fresh products only
 * Use this in product queries to filter out expired products
 * @returns {string} - SQL condition string
 */
const getFreshnessWhereClause = () => {
    return `(freshness_date IS NULL OR freshness_date >= CURRENT_DATE - INTERVAL '${FRESHNESS_THRESHOLD_DAYS} days')`;
};

module.exports = {
    isProductFresh,
    getFreshnessBadge,
    formatFreshnessDate,
    getDaysRemaining,
    getFreshnessWhereClause,
    FRESHNESS_THRESHOLD_DAYS
};
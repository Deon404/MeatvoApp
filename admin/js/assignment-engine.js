/**
 * Assignment Engine Module
 * Handles order assignment to delivery partners
 * SINGLE SOURCE - No duplicates
 */

import { API } from './api.js';
import { showToast } from './ui-utils.js';

/**
 * AssignmentEngine Class
 * Manages order assignment logic and partner selection
 */
export class AssignmentEngine {
    constructor() {
        this.availablePartners = [];
        this.activeAssignments = new Map();
        this.isInitialized = false;
    }

    /**
     * Initialize the assignment engine
     */
    async init() {
        if (this.isInitialized) return;
        
        try {
            await this.loadAvailablePartners();
            this.isInitialized = true;
            console.log('AssignmentEngine: Initialized');
        } catch (error) {
            console.error('AssignmentEngine: Init failed:', error);
            throw error;
        }
    }

    /**
     * Load available delivery partners
     */
    async loadAvailablePartners() {
        try {
            this.availablePartners = await API.getAvailablePartners();
            return this.availablePartners;
        } catch (error) {
            console.error('Failed to load partners:', error);
            this.availablePartners = [];
            return [];
        }
    }

    /**
     * Get best partner for an order based on various factors
     */
    async findBestPartner(order, options = {}) {
        const {
            prioritizeLocation = true,
            prioritizeRating = true,
            maxDistance = 5000 // meters
        } = options;

        if (this.availablePartners.length === 0) {
            await this.loadAvailablePartners();
        }

        if (this.availablePartners.length === 0) {
            return null;
        }

        // Score each partner
        const scoredPartners = this.availablePartners.map(partner => {
            let score = 0;

            // Base availability score
            if (partner.isOnline) score += 10;
            if (partner.isActive) score += 10;

            // Distance score (if location data available)
            if (prioritizeLocation && partner.location && order.location) {
                const distance = this.calculateDistance(
                    partner.location,
                    order.location
                );
                if (distance <= maxDistance) {
                    score += Math.max(0, 50 - (distance / 100));
                }
            }

            // Rating score
            if (prioritizeRating && partner.rating) {
                score += partner.rating * 5;
            }

            // Workload penalty (fewer active orders = better)
            const activeOrders = partner.activeOrders || 0;
            score -= activeOrders * 10;

            return { partner, score };
        });

        // Sort by score descending
        scoredPartners.sort((a, b) => b.score - a.score);

        // Return best partner or null
        return scoredPartners[0]?.partner || null;
    }

    /**
     * Calculate distance between two coordinates (Haversine formula)
     */
    calculateDistance(loc1, loc2) {
        const R = 6371000; // Earth's radius in meters
        const lat1 = loc1.lat * Math.PI / 180;
        const lat2 = loc2.lat * Math.PI / 180;
        const deltaLat = (loc2.lat - loc1.lat) * Math.PI / 180;
        const deltaLng = (loc2.lng - loc1.lng) * Math.PI / 180;

        const a = Math.sin(deltaLat/2) * Math.sin(deltaLat/2) +
                  Math.cos(lat1) * Math.cos(lat2) *
                  Math.sin(deltaLng/2) * Math.sin(deltaLng/2);
        const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));

        return R * c;
    }

    /**
     * Assign order to a specific partner
     */
    async assignOrder(orderId, partnerId) {
        try {
            await API.assignOrder(orderId, partnerId);
            
            this.activeAssignments.set(orderId, {
                partnerId,
                assignedAt: new Date(),
                status: 'assigned'
            });

            showToast('Order assigned successfully', 'success');
            return true;
        } catch (error) {
            console.error('Assignment error:', error);
            showToast('Failed to assign order', 'error');
            return false;
        }
    }

    /**
     * Auto-assign order to best available partner
     */
    async autoAssign(order, options = {}) {
        const partner = await this.findBestPartner(order, options);
        
        if (!partner) {
            showToast('No available delivery partners', 'warning');
            return false;
        }

        return await this.assignOrder(order.id, partner.id);
    }

    /**
     * Get assignment status for an order
     */
    getAssignmentStatus(orderId) {
        return this.activeAssignments.get(orderId) || null;
    }

    /**
     * Update assignment status
     */
    updateAssignmentStatus(orderId, status) {
        const assignment = this.activeAssignments.get(orderId);
        if (assignment) {
            assignment.status = status;
            assignment.updatedAt = new Date();
        }
    }

    /**
     * Release assignment (e.g., when order is cancelled)
     */
    releaseAssignment(orderId) {
        this.activeAssignments.delete(orderId);
    }

    /**
     * Get all active assignments
     */
    getActiveAssignments() {
        return Array.from(this.activeAssignments.entries()).map(([orderId, data]) => ({
            orderId,
            ...data
        }));
    }

    /**
     * Refresh partner availability
     */
    async refresh() {
        this.isInitialized = false;
        await this.init();
    }
}

// Create singleton instance
export const assignmentEngine = new AssignmentEngine();

export default assignmentEngine;

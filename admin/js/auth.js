/**
 * Authentication Module
 * Handles login, logout, and auth guards
 */

import { API } from './api.js';

/**
 * Auth Guard - Check if user is authenticated and has admin role
 * Call this at the start of protected pages
 */
export function authGuard() {
    const token = localStorage.getItem('accessToken') || localStorage.getItem('adminToken');
    const userStr = localStorage.getItem('user') || localStorage.getItem('adminUser');
    
    if (!token) {
        window.location.href = '/admin/admin-login.html';
        return false;
    }
    
    try {
        const user = userStr ? JSON.parse(userStr) : null;
        
        if (!user || user.role !== 'admin') {
            localStorage.removeItem('accessToken');
            localStorage.removeItem('user');
            window.location.href = '/admin/admin-login.html';
            return false;
        }
        
        return true;
    } catch (error) {
        console.error('AuthGuard: Error parsing user:', error);
        localStorage.removeItem('accessToken');
        localStorage.removeItem('user');
        window.location.href = '/admin/admin-login.html';
        return false;
    }
}

/**
 * Get current user info
 */
export function getCurrentUser() {
    try {
        const userStr = localStorage.getItem('user');
        return userStr ? JSON.parse(userStr) : null;
    } catch {
        return null;
    }
}

/**
 * Get auth token
 */
export function getToken() {
    return localStorage.getItem('accessToken');
}

/**
 * Store auth data after login
 */
export function setAuth(token, user, expiresIn = 86400) {
    localStorage.setItem('accessToken', token);
    localStorage.setItem('adminToken', token);
    localStorage.setItem('user', JSON.stringify(user));
    localStorage.setItem('adminUser', JSON.stringify(user));
    
    // Calculate and store expiry
    const expiry = Date.now() + (expiresIn * 1000);
    localStorage.setItem('tokenExpiry', expiry.toString());
}

/**
 * Clear auth data on logout
 */
export function clearAuth() {
    localStorage.removeItem('accessToken');
    localStorage.removeItem('adminToken');
    localStorage.removeItem('refreshToken');
    localStorage.removeItem('user');
    localStorage.removeItem('adminUser');
    localStorage.removeItem('tokenExpiry');
}

/**
 * Logout user
 */
export function logout() {
    clearAuth();
    window.location.href = '/admin/admin-login.html';
}

/**
 * Check if token is expired
 */
export function isTokenExpired() {
    const expiry = localStorage.getItem('tokenExpiry');
    if (!expiry) return true;
    return Date.now() > parseInt(expiry);
}

/**
 * Validate phone number (Indian format)
 */
export function validatePhone(phone) {
    // Remove any non-digits
    const cleaned = phone.replace(/\D/g, '');
    
    // Should be 10 digits starting with 6-9
    return /^[6-9]\d{9}$/.test(cleaned);
}

/**
 * Format phone number with country code
 */
export function formatPhone(phone) {
    const cleaned = phone.replace(/\D/g, '');
    return '+91' + cleaned.slice(-10);
}

/**
 * Send OTP to phone number
 */
export async function sendOTP(phone) {
    const formattedPhone = formatPhone(phone);
    const data = await API.sendOTP(formattedPhone);
    return { ...data, formattedPhone };
}

/**
 * Verify OTP and complete login
 */
export async function verifyOTP(phone, otp) {
    const formattedPhone = formatPhone(phone);

    const data = await API.verifyOTP(formattedPhone, otp);
    if (data.success && data.data) {
        const accessToken = data.data.accessToken || data.data.token;
        setAuth(accessToken, data.data.user, 86400);
        if (data.data.refreshToken) {
            localStorage.setItem('refreshToken', data.data.refreshToken);
        }
    }
    return data;
}

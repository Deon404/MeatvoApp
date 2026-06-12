/**
 * API Configuration
 * Central API configuration with AsyncStorage token management
 */

import AsyncStorage from '@react-native-async-storage/async-storage';

const API_BASE_URL = 'https://subscribers-organisms-patio-cameron.trycloudflare.com';

export const API_CONFIG = {
  BASE_URL: API_BASE_URL,
  ENDPOINTS: {
    // Auth
    SEND_OTP: '/api/auth/send-otp',
    VERIFY_OTP: '/api/auth/verify-otp',
    REFRESH_TOKEN: '/api/auth/refresh-token',
    LOGOUT: '/api/auth/logout',

    // Products
    PRODUCTS: '/api/products',
    PRODUCT_BY_ID: (id: string) => `/api/products/${id}`,
    PRODUCTS_BY_CATEGORY: (category: string) => `/api/products?category=${category}`,
    FEATURED_PRODUCTS: '/api/products?featured=true',
    
    // Cart
    CART: '/api/cart',
    CART_ITEM: (itemId: string) => `/api/cart/${itemId}`,
    CART_CLEAR: '/api/cart/clear',
    
    // Orders
    ORDERS: '/api/orders',
    ORDER_BY_ID: (id: string) => `/api/orders/${id}`,
    ORDER_CANCEL: (id: string) => `/api/orders/${id}/cancel`,
    
    // Addresses
    ADDRESSES: '/api/addresses',
    ADDRESS_BY_ID: (id: string) => `/api/addresses/${id}`,
    
    // User
    USER_PROFILE: '/api/users/profile',
    USER_UPDATE: '/api/users/profile',
    
    // Categories
    CATEGORIES: '/api/categories',
    
    // Banners
    BANNERS: '/api/banners',
  },
  STORAGE_KEYS: {
    ACCESS_TOKEN: 'access_token',
    REFRESH_TOKEN: 'refresh_token',
    USER_DATA: 'user_data',
    USER_ID: 'user_id',
    USER_ROLE: 'user_role',
  },
};

export interface ApiResponse<T = any> {
  success: boolean;
  data?: T;
  message?: string;
  error?: string;
}

export class ApiError extends Error {
  constructor(
    message: string,
    public statusCode?: number,
    public response?: any
  ) {
    super(message);
    this.name = 'ApiError';
  }
}

export async function getAuthToken(): Promise<string | null> {
  try {
    return await AsyncStorage.getItem(API_CONFIG.STORAGE_KEYS.ACCESS_TOKEN);
  } catch (error) {
    console.error('Error getting auth token:', error);
    return null;
  }
}

export async function setAuthToken(token: string): Promise<void> {
  try {
    await AsyncStorage.setItem(API_CONFIG.STORAGE_KEYS.ACCESS_TOKEN, token);
  } catch (error) {
    console.error('Error setting auth token:', error);
  }
}

export async function removeAuthToken(): Promise<void> {
  try {
    await AsyncStorage.removeItem(API_CONFIG.STORAGE_KEYS.ACCESS_TOKEN);
    await AsyncStorage.removeItem(API_CONFIG.STORAGE_KEYS.REFRESH_TOKEN);
    await AsyncStorage.removeItem(API_CONFIG.STORAGE_KEYS.USER_DATA);
  } catch (error) {
    console.error('Error removing auth token:', error);
  }
}

export async function apiRequest<T = any>(
  endpoint: string,
  options: RequestInit = {}
): Promise<T> {
  const token = await getAuthToken();
  
  const headers: HeadersInit = {
    'Content-Type': 'application/json',
    ...(options.headers || {}),
  };

  if (token) {
    headers['Authorization'] = `Bearer ${token}`;
  }

  try {
    const response = await fetch(`${API_CONFIG.BASE_URL}${endpoint}`, {
      ...options,
      headers,
    });

    const data = await response.json();

    if (!response.ok) {
      throw new ApiError(
        data.message || data.error || 'Request failed',
        response.status,
        data
      );
    }

    return data;
  } catch (error) {
    if (error instanceof ApiError) {
      throw error;
    }
    throw new ApiError(
      error instanceof Error ? error.message : 'Network error'
    );
  }
}

export default {
  API_CONFIG,
  apiRequest,
  getAuthToken,
  setAuthToken,
  removeAuthToken,
};

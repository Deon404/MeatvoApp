/**
 * API Configuration - Single Source of Truth
 * All admin calls go through this module.
 */

const ORIGIN = window.location.origin || 'http://localhost:8080';
export const API_BASE = `${ORIGIN}/api`;
export const API_V1_BASE = `${ORIGIN}/api/v1`;

const getAccessToken = () => localStorage.getItem('accessToken') || localStorage.getItem('adminToken');
const getRefreshToken = () => localStorage.getItem('refreshToken');

const setTokens = ({ accessToken, refreshToken }) => {
    if (accessToken) {
        localStorage.setItem('accessToken', accessToken);
        localStorage.setItem('adminToken', accessToken);
    }
    if (refreshToken) {
        localStorage.setItem('refreshToken', refreshToken);
    }
};

const clearTokens = () => {
    localStorage.removeItem('accessToken');
    localStorage.removeItem('refreshToken');
    localStorage.removeItem('adminToken');
    localStorage.removeItem('user');
    localStorage.removeItem('adminUser');
};

const toQuery = (params = {}) => {
    const clean = Object.fromEntries(
        Object.entries(params).filter(([, value]) => value !== undefined && value !== null && value !== '')
    );
    const query = new URLSearchParams(clean).toString();
    return query ? `?${query}` : '';
};

const unwrapData = (payload) => {
    if (!payload || typeof payload !== 'object') return payload;
    return payload.data !== undefined ? payload.data : payload;
};

const refreshAccessToken = async () => {
    const refreshToken = getRefreshToken();
    if (!refreshToken) return false;

    const response = await fetch(`${API_BASE}/auth/refresh-token`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ refreshToken }),
    });

    const payload = await response.json().catch(() => ({}));
    if (!response.ok || !payload?.success) return false;
    const data = unwrapData(payload);
    setTokens({ accessToken: data?.accessToken || data?.token, refreshToken: data?.refreshToken });
    return true;
};

export async function apiRequest(endpoint, options = {}) {
    const base = options.base || API_V1_BASE;
    const url = `${base}${endpoint}`;
    const retryOnAuth = options.retryOnAuth !== false;

    const headers = {
        'Content-Type': 'application/json',
        ...(options.headers || {}),
    };
    const token = getAccessToken();
    if (token) headers.Authorization = `Bearer ${token}`;

    const response = await fetch(url, {
        ...options,
        headers,
    });

    if (response.status === 401 && retryOnAuth) {
        const refreshed = await refreshAccessToken();
        if (refreshed) {
            return apiRequest(endpoint, { ...options, retryOnAuth: false });
        }
        clearTokens();
        window.location.href = '/admin/admin-login.html';
        throw new Error('Unauthorized');
    }

    const payload = await response.json().catch(() => ({}));
    if (!response.ok || payload?.success === false || payload?.ok === false) {
        const message = payload?.message || payload?.error?.message || `HTTP ${response.status}`;
        throw new Error(message);
    }
    return payload;
}

export const API = {
    // Auth
    sendOTP: (phone) =>
        apiRequest('/auth/send-otp', {
            base: API_BASE,
            method: 'POST',
            body: JSON.stringify({ phone }),
        }),
    verifyOTP: (phone, otp) =>
        apiRequest('/auth/verify-otp', {
            base: API_BASE,
            method: 'POST',
            body: JSON.stringify({ phone, otp }),
        }),

    // Dashboard
    async getDashboardStats() {
        const payload = await apiRequest('/admin/dashboard');
        return unwrapData(payload)?.stats || {};
    },
    async getRecentOrders(limit = 10) {
        const payload = await apiRequest(`/admin/orders${toQuery({ limit })}`);
        return unwrapData(payload)?.orders || [];
    },
    async getPendingOrders() {
        const payload = await apiRequest('/admin/orders');
        const orders = unwrapData(payload)?.orders || [];
        return orders.filter((o) => ['PLACED', 'CONFIRMED', 'PACKED'].includes(o.status));
    },

    // Orders
    async getOrders(params = {}) {
        const payload = await apiRequest(`/admin/orders${toQuery(params)}`);
        return unwrapData(payload)?.orders || [];
    },
    async getOrder(id) {
        const payload = await apiRequest(`/orders/${id}`);
        return unwrapData(payload)?.order || null;
    },
    updateOrderStatus: (id, status) =>
        apiRequest(`/admin/orders/${id}/status`, {
            method: 'PATCH',
            body: JSON.stringify({ status }),
        }),
    assignOrder: (orderId, deliveryPartnerId) =>
        apiRequest(`/admin/orders/${orderId}`, {
            method: 'PATCH',
            body: JSON.stringify({ orderStatus: 'ASSIGNED', deliveryUserId: deliveryPartnerId }),
        }),

    // Products
    async getProducts() {
        const payload = await apiRequest('/admin/products');
        return unwrapData(payload);
    },
    createProduct: (data) =>
        apiRequest('/admin/products', {
            method: 'POST',
            body: JSON.stringify(data),
        }),
    updateProduct: (id, data) =>
        apiRequest(`/admin/products/${id}`, {
            method: 'PUT',
            body: JSON.stringify(data),
        }),
    deleteProduct: (id) =>
        apiRequest(`/admin/products/${id}`, {
            method: 'DELETE',
        }),

    // Delivery
    async getDeliveryPartners() {
        const payload = await apiRequest('/admin/delivery-partners');
        return unwrapData(payload);
    },
    async getAvailablePartners() {
        const all = await this.getDeliveryPartners();
        return (all || []).filter((p) => Boolean(p?.profile?.online));
    },

    // Customers
    async getCustomers() {
        const payload = await apiRequest('/admin/customers');
        return unwrapData(payload);
    },

    // Analytics
    getAnalytics: (period = 'today') => apiRequest(`/admin/analytics${toQuery({ period })}`),
};

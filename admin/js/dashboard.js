/**
 * Dashboard Module
 * Main dashboard functionality for admin panel
 */

import { API } from './api.js';
import { authGuard, getCurrentUser, logout } from './auth.js';
import { assignmentEngine } from './assignment-engine.js';
import { showToast, formatCurrency, formatDate, getStatusBadge, confirmDialog, escapeHtml } from './ui-utils.js';

// Dashboard state
let currentSection = 'dashboard';
let dashboardData = null;
let adminSocket = null;

/**
 * Initialize the dashboard
 */
export async function initDashboard() {
    // Auth guard - redirect if not authenticated
    if (!authGuard()) return;
    
    try {
        setupNavigation();
        setupUserInfo();
        
        await assignmentEngine.init();
        await loadDashboardData();
        
        setupAutoRefresh();
    } catch (error) {
        console.error('Dashboard: Init failed:', error);
        showToast('Failed to load dashboard', 'error');
    }
}

/**
 * Setup navigation handlers
 */
function setupNavigation() {
    const navItems = document.querySelectorAll('.nav-item');
    const sections = document.querySelectorAll('.section');
    
    navItems.forEach(item => {
        item.addEventListener('click', () => {
            const section = item.dataset.section;
            if (!section) return;
            
            // Update nav active state
            navItems.forEach(n => n.classList.remove('active'));
            item.classList.add('active');
            
            // Show section
            sections.forEach(s => s.classList.remove('active'));
            const targetSection = document.getElementById(`section-${section}`);
            if (targetSection) {
                targetSection.classList.add('active');
                currentSection = section;
                
                // Load section-specific data
                loadSectionData(section);
            }
        });
    });
    
    // Mobile menu toggle
    const menuToggle = document.getElementById('menu-toggle');
    const sidebar = document.getElementById('sidebar');
    
    if (menuToggle) {
        menuToggle.addEventListener('click', () => {
            sidebar?.classList.toggle('open');
        });
    }
    
    // Logout button
    const logoutBtn = document.getElementById('logout-btn');
    if (logoutBtn) {
        logoutBtn.addEventListener('click', logout);
    }
}

/**
 * Setup user info in header
 */
function setupUserInfo() {
    const user = getCurrentUser();
    if (!user) return;
    
    const nameEl = document.getElementById('admin-name');
    const roleEl = document.getElementById('admin-role');
    
    if (nameEl) nameEl.textContent = user.name || user.phone || 'Admin';
    if (roleEl) roleEl.textContent = user.role || 'Administrator';
}

/**
 * Load dashboard data
 */
async function loadDashboardData() {
    try {
        const [stats, recentOrders] = await Promise.all([
            API.getDashboardStats(),
            API.getRecentOrders(5)
        ]);
        
        dashboardData = { stats, orders: recentOrders };
        
        renderDashboardStats(dashboardData.stats);
        renderRecentOrders(dashboardData.orders);
        
    } catch (error) {
        console.error('Failed to load dashboard data:', error);
        showToast('Failed to load dashboard data', 'error');
    }
}

/**
 * Render dashboard stats cards
 */
function renderDashboardStats(stats) {
    if (!stats) return;
    
    const statsGrid = document.getElementById('stats-grid');
    if (!statsGrid) return;
    
    const cards = [
        { label: 'Total Orders', value: stats.totalOrders || 0, icon: '📦' },
        { label: 'Revenue', value: formatCurrency(stats.deliveredRevenue || 0), icon: '💰' },
        { label: 'Active Orders', value: stats.liveOrders || 0, icon: '🚚' },
        { label: 'Customers', value: stats.totalCustomers || 0, icon: '👥' }
    ];
    
    statsGrid.innerHTML = cards.map(card => `
        <div class="stat-card">
            <div class="stat-icon">${card.icon}</div>
            <div class="stat-value">${card.value}</div>
            <div class="stat-label">${card.label}</div>
            ${card.change ? `
                <div class="stat-change ${card.change >= 0 ? 'positive' : 'negative'}">
                    ${card.change >= 0 ? '↑' : '↓'} ${Math.abs(card.change)}%
                </div>
            ` : ''}
        </div>
    `).join('');
}

/**
 * Render recent orders table
 */
function renderRecentOrders(orders) {
    const container = document.getElementById('recent-orders-table');
    if (!container) return;
    
    if (!orders || orders.length === 0) {
        container.innerHTML = '<p class="empty-state">No recent orders</p>';
        return;
    }
    
    container.innerHTML = `
        <table class="data-table">
            <thead>
                <tr>
                    <th>Order ID</th>
                    <th>Customer</th>
                    <th>Amount</th>
                    <th>Status</th>
                    <th>Time</th>
                </tr>
            </thead>
            <tbody>
                ${orders.map(order => `
                    <tr data-order-id="${escapeHtml(order.id)}">
                        <td>#${escapeHtml(order.id)}</td>
                        <td>${escapeHtml(order.customerName || order.customerPhone || 'Unknown')}</td>
                        <td>${formatCurrency(order.total)}</td>
                        <td>${getStatusBadge(order.status)}</td>
                        <td>${formatDate(order.createdAt)}</td>
                    </tr>
                `).join('')}
            </tbody>
        </table>
    `;
    
    // Add click handlers
    container.querySelectorAll('tbody tr').forEach(row => {
        row.addEventListener('click', () => {
            const orderId = row.dataset.orderId;
            showOrderDetails(orderId);
        });
    });
}

/**
 * Load section-specific data
 */
async function loadSectionData(section) {
    try {
        switch (section) {
            case 'orders':
                await loadOrdersSection();
                break;
            case 'products':
                await loadProductsSection();
                break;
            case 'delivery':
                await loadDeliverySection();
                break;
            case 'customers':
                await loadCustomersSection();
                break;
        }
    } catch (error) {
        console.error(`Failed to load ${section} data:`, error);
    }
}

/**
 * Load orders section
 */
async function loadOrdersSection() {
    const container = document.getElementById('orders-list');
    if (!container || container.dataset.loaded) return;
    
    try {
        const orders = await API.getOrders({ limit: 50 });
        
        renderOrdersList(orders, container);
        setupOrdersTableActions(container);
        container.dataset.loaded = 'true';
    } catch (error) {
        container.innerHTML = '<p class="error-state">Failed to load orders</p>';
    }
}

/**
 * Render orders list
 */
function renderOrdersList(orders, container) {
    if (orders.length === 0) {
        container.innerHTML = '<p class="empty-state">No orders found</p>';
        return;
    }
    
    container.innerHTML = `
        <table class="data-table">
            <thead>
                <tr>
                    <th>Order ID</th>
                    <th>Customer</th>
                    <th>Items</th>
                    <th>Total</th>
                    <th>Status</th>
                    <th>Actions</th>
                </tr>
            </thead>
            <tbody>
                ${orders.map(order => `
                    <tr data-order-id="${escapeHtml(order.id)}">
                        <td>#${escapeHtml(order.id)}</td>
                        <td>${escapeHtml(order.phone || 'Unknown')}</td>
                        <td>${order.items?.length || 0} items</td>
                        <td>${formatCurrency(order.totalAmount || order.total || 0)}</td>
                        <td>${getStatusBadge(order.status)}</td>
                        <td>
                            <button class="btn-sm" data-action="view" data-order-id="${escapeHtml(order.id)}">View</button>
                            ${String(order.status || '').toUpperCase() === 'PLACED' ? `
                                <button class="btn-sm btn-primary" data-action="assign" data-order-id="${escapeHtml(order.id)}">Assign</button>
                            ` : ''}
                        </td>
                    </tr>
                `).join('')}
            </tbody>
        </table>
    `;
}

/**
 * Orders table action delegation handler
 */
function setupOrdersTableActions(container) {
    container.addEventListener('click', (e) => {
        const btn = e.target.closest('button[data-action]');
        if (!btn) return;
        const orderId = btn.dataset.orderId;
        if (!orderId) return;
        if (btn.dataset.action === 'view') showOrderDetails(orderId);
        if (btn.dataset.action === 'assign') window.assignOrder?.(orderId);
    });
}

/**
 * Load products section
 */
async function loadProductsSection() {
    const container = document.getElementById('products-list');
    if (!container || container.dataset.loaded) return;
    
    try {
        const products = await API.getProducts();
        
        renderProductsList(products, container);
        container.addEventListener('click', (e) => {
            const btn = e.target.closest('button[data-action]');
            if (!btn) return;
            const pid = btn.dataset.productId;
            if (!pid) return;
            if (btn.dataset.action === 'edit') window.editProduct?.(pid);
            if (btn.dataset.action === 'delete') window.deleteProduct?.(pid);
        });
        container.dataset.loaded = 'true';
    } catch (error) {
        container.innerHTML = '<p class="error-state">Failed to load products</p>';
    }
}

/**
 * Render products list
 */
function renderProductsList(products, container) {
    if (products.length === 0) {
        container.innerHTML = '<p class="empty-state">No products found</p>';
        return;
    }
    
    container.innerHTML = `
        <div class="products-grid">
            ${products.map(product => `
                <div class="product-card" data-product-id="${escapeHtml(product.id)}">
                    <img src="${escapeHtml(product.imageUrl || '/assets/images/placeholder-food.jpg')}" alt="${escapeHtml(product.name)}">
                    <div class="product-info">
                        <h4>${escapeHtml(product.name)}</h4>
                        <p class="product-price">${formatCurrency(product.price || 0)}</p>
                        <p class="product-stock">${(product.stockQty || 0) > 0 ? `${escapeHtml(String(product.stockQty))} in stock` : 'Out of stock'}</p>
                    </div>
                    <div class="product-actions">
                        <button class="btn-sm" data-action="edit" data-product-id="${escapeHtml(product.id)}">Edit</button>
                        <button class="btn-sm btn-danger" data-action="delete" data-product-id="${escapeHtml(product.id)}">Delete</button>
                    </div>
                </div>
            `).join('')}
        </div>
    `;
}

/**
 * Load delivery partners section
 */
async function loadDeliverySection() {
    const container = document.getElementById('delivery-list');
    if (!container || container.dataset.loaded) return;
    
    try {
        const partners = await API.getDeliveryPartners();
        
        renderDeliveryList(partners, container);
        container.dataset.loaded = 'true';
    } catch (error) {
        container.innerHTML = '<p class="error-state">Failed to load delivery partners</p>';
    }
}

/**
 * Render delivery partners list
 */
function renderDeliveryList(partners, container) {
    if (partners.length === 0) {
        container.innerHTML = '<p class="empty-state">No delivery partners found</p>';
        return;
    }
    
    container.innerHTML = `
        <table class="data-table">
            <thead>
                <tr>
                    <th>Name</th>
                    <th>Phone</th>
                    <th>Status</th>
                    <th>Rating</th>
                    <th>Active Orders</th>
                </tr>
            </thead>
            <tbody>
                ${partners.map(partner => `
                    <tr>
                        <td>${escapeHtml(partner.name || 'Unknown')}</td>
                        <td>${escapeHtml(partner.phone || '')}</td>
                        <td>
                            <span class="status-dot ${partner?.profile?.online ? 'online' : 'offline'}"></span>
                            ${partner?.profile?.online ? 'Online' : 'Offline'}
                        </td>
                        <td>N/A</td>
                        <td>0</td>
                    </tr>
                `).join('')}
            </tbody>
        </table>
    `;
}

/**
 * Load customers section
 */
async function loadCustomersSection() {
    const container = document.getElementById('customers-list');
    if (!container || container.dataset.loaded) return;
    
    try {
        const customers = await API.getCustomers();
        
        renderCustomersList(customers, container);
        container.dataset.loaded = 'true';
    } catch (error) {
        container.innerHTML = '<p class="error-state">Failed to load customers</p>';
    }
}

/**
 * Render customers list
 */
function renderCustomersList(customers, container) {
    if (customers.length === 0) {
        container.innerHTML = '<p class="empty-state">No customers found</p>';
        return;
    }
    
    container.innerHTML = `
        <table class="data-table">
            <thead>
                <tr>
                    <th>Name</th>
                    <th>Phone</th>
                    <th>Orders</th>
                    <th>Total Spent</th>
                </tr>
            </thead>
            <tbody>
                ${customers.map(customer => `
                    <tr>
                        <td>${escapeHtml(customer.name || 'Unknown')}</td>
                        <td>${escapeHtml(customer.phone || '')}</td>
                        <td>—</td>
                        <td>—</td>
                    </tr>
                `).join('')}
            </tbody>
        </table>
    `;
}

/**
 * Show order details modal
 */
async function showOrderDetails(orderId) {
    try {
        const order = await API.getOrder(orderId);
        if (!order) {
            showToast('Order not found', 'error');
            return;
        }

        const existing = document.getElementById('order-detail-modal');
        if (existing) existing.remove();

        const modal = document.createElement('div');
        modal.id = 'order-detail-modal';
        modal.style.cssText = `
            position:fixed;inset:0;background:rgba(0,0,0,0.5);
            display:flex;align-items:center;justify-content:center;z-index:10000;
        `;

        const items = Array.isArray(order.items)
            ? order.items.map(i => `<li>${escapeHtml(i.name || i.productName || 'Item')} × ${i.qty || i.quantity || 1} — ${formatCurrency(i.total || i.price || 0)}</li>`).join('')
            : '';

        const panel = document.createElement('div');
        panel.style.cssText = 'background:white;padding:24px;border-radius:12px;max-width:480px;width:90%;max-height:80vh;overflow-y:auto;';
        panel.innerHTML = `
            <h3 style="margin:0 0 16px">Order #${escapeHtml(orderId)}</h3>
            <p><strong>Customer:</strong> ${escapeHtml(order.customerName || order.customerPhone || 'Unknown')}</p>
            <p><strong>Status:</strong> ${getStatusBadge(order.status)}</p>
            <p><strong>Total:</strong> ${formatCurrency(order.total || order.totalAmount || 0)}</p>
            ${items ? `<ul style="margin:8px 0;padding-left:20px">${items}</ul>` : ''}
            <button id="order-detail-close" style="margin-top:16px;padding:8px 20px;background:#EF4444;color:white;border:none;border-radius:8px;cursor:pointer;">Close</button>
        `;

        modal.appendChild(panel);
        document.body.appendChild(modal);

        modal.querySelector('#order-detail-close').onclick = () => modal.remove();
        modal.onclick = (e) => { if (e.target === modal) modal.remove(); };
    } catch {
        showToast('Failed to load order details', 'error');
    }
}

/**
 * Setup auto-refresh for dashboard data
 */
function setupAutoRefresh() {
    // Refresh every 30 seconds when on dashboard
    setInterval(() => {
        if (currentSection === 'dashboard') {
            loadDashboardData();
        }
    }, 30000);
}

async function setupRealtimeOrders() {
    try {
        if (adminSocket) return;
        const socketScriptUrl = `${window.location.origin}/socket.io/socket.io.js`;
        if (!window.io) {
            await new Promise((resolve, reject) => {
                const script = document.createElement('script');
                script.src = socketScriptUrl;
                script.onload = resolve;
                script.onerror = reject;
                document.head.appendChild(script);
            });
        }

        const token = localStorage.getItem('accessToken') || localStorage.getItem('adminToken');
        if (!token || !window.io) return;

        adminSocket = window.io(window.location.origin, {
            auth: { token },
            path: '/ws',
            transports: ['websocket'],
        });

        adminSocket.on('connect', () => {
            adminSocket.emit('join_admin_room');
        });

        adminSocket.on('order:new', async () => {
            await loadDashboardData();
            if (currentSection === 'orders') await loadOrdersSection();
            showToast('New order received', 'info');
        });

        adminSocket.on('order:status_update', async () => {
            await loadDashboardData();
            if (currentSection === 'orders') await loadOrdersSection();
        });
    } catch (error) {
        console.warn('Realtime orders unavailable', error);
    }
}

// Expose functions to global scope for onclick handlers
window.viewOrder = (id) => showOrderDetails(id);
window.assignOrder = async (id) => {
    const success = await assignmentEngine.autoAssign({ id });
    if (success) {
        const container = document.getElementById('orders-list');
        if (container) container.dataset.loaded = '';
        loadSectionData('orders');
    }
};
window.editProduct = (id) => showToast(`Edit product ${id} - Coming soon`, 'info');
window.deleteProduct = (id) => {
    confirmDialog('Are you sure you want to delete this product?', async () => {
        try {
            await API.deleteProduct(id);
            showToast('Product deleted', 'success');
            loadSectionData('products');
        } catch (error) {
            showToast('Failed to delete product', 'error');
        }
    });
};

setupRealtimeOrders();

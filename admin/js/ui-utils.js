/**
 * UI Utilities Module
 * Common UI helpers for the admin panel
 */

/**
 * Escape HTML to prevent XSS attacks
 */
export function escapeHtml(str) {
    const map = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#039;' };
    return String(str ?? '').replace(/[&<>"']/g, m => map[m]);
}

/**
 * Show toast notification
 */
export function showToast(message, type = 'info', duration = 3000) {
    // Remove existing toast
    const existing = document.getElementById('toast-notification');
    if (existing) existing.remove();
    
    const colors = {
        success: '#10B981',
        error: '#EF4444',
        warning: '#F59E0B',
        info: '#3B82F6'
    };
    
    const icons = {
        success: '✓',
        error: '✕',
        warning: '⚠',
        info: 'ℹ'
    };
    
    const toast = document.createElement('div');
    toast.id = 'toast-notification';
    toast.style.cssText = `
        position: fixed;
        bottom: 24px;
        right: 24px;
        background: ${colors[type]};
        color: white;
        padding: 12px 20px;
        border-radius: 8px;
        box-shadow: 0 4px 12px rgba(0,0,0,0.15);
        z-index: 10000;
        font-weight: 500;
        display: flex;
        align-items: center;
        gap: 8px;
        animation: slideIn 0.3s ease;
    `;
    const iconSpan = document.createElement('span');
    iconSpan.style.fontSize = '16px';
    iconSpan.textContent = icons[type] || 'ℹ';

    const msgSpan = document.createElement('span');
    msgSpan.textContent = message;

    toast.appendChild(iconSpan);
    toast.appendChild(msgSpan);
    
    document.body.appendChild(toast);
    
    setTimeout(() => {
        toast.style.animation = 'slideOut 0.3s ease forwards';
        setTimeout(() => toast.remove(), 300);
    }, duration);
}

/**
 * Format currency
 */
export function formatCurrency(amount) {
    return new Intl.NumberFormat('en-IN', {
        style: 'currency',
        currency: 'INR',
        minimumFractionDigits: 0
    }).format(amount);
}

/**
 * Format date
 */
export function formatDate(dateStr) {
    const date = new Date(dateStr);
    return new Intl.DateTimeFormat('en-IN', {
        day: 'numeric',
        month: 'short',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
    }).format(date);
}

/**
 * Format relative time
 */
export function formatRelativeTime(dateStr) {
    const date = new Date(dateStr);
    const now = new Date();
    const diff = Math.floor((now - date) / 1000);
    
    if (diff < 60) return 'Just now';
    if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
    if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
    return `${Math.floor(diff / 86400)}d ago`;
}

/**
 * Get status badge HTML
 */
export function getStatusBadge(status) {
    const normalized = String(status || '').toLowerCase();
    const colors = {
        'pending': { bg: '#FEF3C7', text: '#92400E', label: 'Pending' },
        'placed': { bg: '#FEF3C7', text: '#92400E', label: 'Placed' },
        'confirmed': { bg: '#DBEAFE', text: '#1E40AF', label: 'Confirmed' },
        'preparing': { bg: '#E0E7FF', text: '#3730A3', label: 'Preparing' },
        'packed': { bg: '#E0E7FF', text: '#3730A3', label: 'Packed' },
        'ready': { bg: '#D1FAE5', text: '#065F46', label: 'Ready' },
        'out_for_delivery': { bg: '#C7D2FE', text: '#3730A3', label: 'Out for Delivery' },
        'delivered': { bg: '#D1FAE5', text: '#065F46', label: 'Delivered' },
        'cancelled': { bg: '#FEE2E2', text: '#991B1B', label: 'Cancelled' }
    };
    
    const style = colors[normalized] || { bg: '#F3F4F6', text: '#4B5563', label: escapeHtml(status) };
    
    return `<span style="
        display: inline-block;
        padding: 4px 12px;
        border-radius: 20px;
        font-size: 12px;
        font-weight: 600;
        background: ${style.bg};
        color: ${style.text};
    ">${style.label}</span>`;
}

/**
 * Debounce function
 */
export function debounce(func, wait) {
    let timeout;
    return function executedFunction(...args) {
        const later = () => {
            clearTimeout(timeout);
            func(...args);
        };
        clearTimeout(timeout);
        timeout = setTimeout(later, wait);
    };
}

/**
 * Create loading spinner HTML
 */
export function getSpinner(size = 16) {
    return `<div style="
        width: ${size}px;
        height: ${size}px;
        border: 2px solid rgba(255,255,255,0.3);
        border-radius: 50%;
        border-top-color: currentColor;
        animation: spin 0.8s linear infinite;
        display: inline-block;
    "></div>`;
}

/**
 * Confirm dialog
 */
export function confirmDialog(message, onConfirm, onCancel) {
    const overlay = document.createElement('div');
    overlay.style.cssText = `
        position: fixed;
        inset: 0;
        background: rgba(0,0,0,0.5);
        display: flex;
        align-items: center;
        justify-content: center;
        z-index: 10000;
    `;
    
    overlay.innerHTML = `
        <div style="
            background: white;
            padding: 24px;
            border-radius: 12px;
            max-width: 400px;
            width: 90%;
            text-align: center;
        ">
            <div style="font-size: 48px; margin-bottom: 16px;">⚠️</div>
            <h3 style="margin: 0 0 12px; font-size: 18px;">Confirm Action</h3>
            <p style="margin: 0 0 24px; color: #6B7280;">${escapeHtml(message)}</p>
            <div style="display: flex; gap: 12px; justify-content: center;">
                <button id="confirm-cancel" style="
                    padding: 10px 20px;
                    border: 1px solid #E5E7EB;
                    background: white;
                    border-radius: 8px;
                    cursor: pointer;
                    font-weight: 500;
                ">Cancel</button>
                <button id="confirm-ok" style="
                    padding: 10px 20px;
                    border: none;
                    background: #EF4444;
                    color: white;
                    border-radius: 8px;
                    cursor: pointer;
                    font-weight: 500;
                ">Confirm</button>
            </div>
        </div>
    `;
    
    document.body.appendChild(overlay);
    
    overlay.querySelector('#confirm-cancel').onclick = () => {
        overlay.remove();
        onCancel?.();
    };
    
    overlay.querySelector('#confirm-ok').onclick = () => {
        overlay.remove();
        onConfirm();
    };
    
    overlay.onclick = (e) => {
        if (e.target === overlay) {
            overlay.remove();
            onCancel?.();
        }
    };
}

// Add keyframes for animations
const style = document.createElement('style');
style.textContent = `
    @keyframes spin { to { transform: rotate(360deg); } }
    @keyframes slideIn { 
        from { transform: translateX(100%); opacity: 0; }
        to { transform: translateX(0); opacity: 1; }
    }
    @keyframes slideOut { 
        from { transform: translateX(0); opacity: 1; }
        to { transform: translateX(100%); opacity: 0; }
    }
`;
document.head.appendChild(style);

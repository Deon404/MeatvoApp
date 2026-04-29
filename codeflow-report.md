# CodeFlow Analysis Report

**Repository:** Local Folder
**Analyzed:** 4/28/2026, 1:14:32 PM

## Summary


| Metric           | Value      |
| ---------------- | ---------- |
| Health Score     | 70/100 (C) |
| Files            | 413        |
| Functions        | 2048       |
| Lines of Code    | 131,045    |
| Dependencies     | 1149       |
| Unused Functions | 32         |
| Security Issues  | 99         |


## Security Issues

### HIGH: SQL Injection Risk

- **File:** `admin/js/dashboard.js`
- **Description:** String concatenation in SQL queries. Use parameterized queries instead.
- **Code:** `<button class="btn-sm btn-danger" onclick="deleteProduct('${product.id}')">Delet`

### HIGH: XSS Vulnerability

- **File:** `admin/js/dashboard.js`
- **Description:** Direct HTML injection can lead to XSS attacks. Sanitize user input.

### HIGH: XSS Vulnerability

- **File:** `admin/js/ui-utils.js`
- **Description:** Direct HTML injection can lead to XSS attacks. Sanitize user input.

### HIGH: XSS Vulnerability

- **File:** `admin/admin-cleaned.html`
- **Description:** Direct HTML injection can lead to XSS attacks. Sanitize user input.

### HIGH: SQL Injection Risk

- **File:** `admin/admin.html`
- **Description:** String concatenation in SQL queries. Use parameterized queries instead.
- **Code:** `<button class="btn btn-sm btn-danger" onclick="deleteProduct('${p.id}')">Delete<`

### HIGH: XSS Vulnerability

- **File:** `admin/admin.html`
- **Description:** Direct HTML injection can lead to XSS attacks. Sanitize user input.

### HIGH: SQL Injection Risk

- **File:** `admin/admin-original-backup.html`
- **Description:** String concatenation in SQL queries. Use parameterized queries instead.
- **Code:** `<button class="btn btn-sm btn-danger" onclick="deleteProduct('${p.id}')">Del</bu`

### HIGH: XSS Vulnerability

- **File:** `admin/admin-original-backup.html`
- **Description:** Direct HTML injection can lead to XSS attacks. Sanitize user input.

### HIGH: XSS Vulnerability

- **File:** `admin/admin-login.html`
- **Description:** Direct HTML injection can lead to XSS attacks. Sanitize user input.

### HIGH: Hardcoded Secret

- **File:** `android/app/src/main/assets/public/admin/admin.html` (line 1160)
- **Description:** Credentials should never be hardcoded. Use environment variables or a secrets manager.
- **Code:** `const ADMIN_PASSWORD = "123400";`

### HIGH: XSS Vulnerability

- **File:** `android/app/src/main/assets/public/admin/admin.html`
- **Description:** Direct HTML injection can lead to XSS attacks. Sanitize user input.

### HIGH: Hardcoded Secret

- **File:** `android/app/src/main/assets/public/customer/customer.html` (line 3108)
- **Description:** Credentials should never be hardcoded. Use environment variables or a secrets manager.
- **Code:** `// const GOOGLE_MAPS_API_KEY = "AIzaSyCSgsXf19L5ACc5ULBq415940S4q0jVvzQ";`

### HIGH: Hardcoded Secret

- **File:** `android/app/src/main/assets/public/customer/customer.html` (line 3196)
- **Description:** Credentials should never be hardcoded. Use environment variables or a secrets manager.
- **Code:** `token: 'authToken',`

### HIGH: SQL Injection Risk

- **File:** `android/app/src/main/assets/public/customer/customer.html`
- **Description:** String concatenation in SQL queries. Use parameterized queries instead.
- **Code:** `const response = await fetch(`[https://nominatim.openstreetmap.org/reverse?format`](https://nominatim.openstreetmap.org/reverse?format`)

### HIGH: XSS Vulnerability

- **File:** `android/app/src/main/assets/public/customer/customer.html`
- **Description:** Direct HTML injection can lead to XSS attacks. Sanitize user input.

### HIGH: XSS Vulnerability

- **File:** `android/app/src/main/assets/public/delivery/delivery.html`
- **Description:** Direct HTML injection can lead to XSS attacks. Sanitize user input.

### HIGH: XSS Vulnerability

- **File:** `android/app/src/main/assets/public/src/js/pages/real-otp-login.js`
- **Description:** Direct HTML injection can lead to XSS attacks. Sanitize user input.

### HIGH: XSS Vulnerability

- **File:** `android/app/src/main/assets/public/index.html`
- **Description:** Direct HTML injection can lead to XSS attacks. Sanitize user input.

### HIGH: SQL Injection Risk

- **File:** `backend/src/controllers/auth.controller.js`
- **Description:** String concatenation in SQL queries. Use parameterized queries instead.
- **Code:** `ON CONFLICT (key) DO UPDATE SET attempts = login_attempts.attempts + 1, expires_`

### HIGH: SQL Injection Risk

- **File:** `backend/src/modules/admin/admin.controller.js`
- **Description:** String concatenation in SQL queries. Use parameterized queries instead.
- **Code:** `await client.query(`UPDATE delivery_partners SET ${dpSets.join(', ')} WHERE id =`

### HIGH: SQL Injection Risk

- **File:** `backend/src/modules/auth/auth.controller.js`
- **Description:** String concatenation in SQL queries. Use parameterized queries instead.
- **Code:** `return crypto.createHmac('sha256', secret).update(`${phone}:${otp}`).digest('hex`

### HIGH: Hardcoded Secret

- **File:** `backend/src/modules/auth/mfa.routes.js` (line 162)
- **Description:** Credentials should never be hardcoded. Use environment variables or a secrets manager.
- **Code:** `const user = { id: userId, mfaSecret: 'demo', mfaEnabled: true };`

### HIGH: SQL Injection Risk

- **File:** `backend/src/modules/delivery/delivery.controller.js`
- **Description:** String concatenation in SQL queries. Use parameterized queries instead.
- **Code:** `await client.query(`UPDATE delivery_partners SET ${sets.join(', ')} WHERE user_i`

### HIGH: SQL Injection Risk

- **File:** `backend/src/modules/delivery/slots.controller.js`
- **Description:** String concatenation in SQL queries. Use parameterized queries instead.
- **Code:** `'UPDATE delivery_slots SET booked = booked + $1 WHERE id = $2',`

### HIGH: SQL Injection Risk

- **File:** `backend/src/modules/orders/orders.controller.js`
- **Description:** String concatenation in SQL queries. Use parameterized queries instead.
- **Code:** ``INSERT INTO order_items (order_id, product_id, quantity, price) VALUES ${placeh`

### HIGH: SQL Injection Risk

- **File:** `backend/src/utils/jwt.js`
- **Description:** String concatenation in SQL queries. Use parameterized queries instead.
- **Code:** `'UPDATE users SET token_version = token_version + 1 WHERE id = $1',`

### HIGH: XSS Vulnerability

- **File:** `customer/cart.html`
- **Description:** Direct HTML injection can lead to XSS attacks. Sanitize user input.

### HIGH: XSS Vulnerability

- **File:** `customer/checkout.html`
- **Description:** Direct HTML injection can lead to XSS attacks. Sanitize user input.

### HIGH: Hardcoded Secret

- **File:** `customer/customer-original-backup.html` (line 3108)
- **Description:** Credentials should never be hardcoded. Use environment variables or a secrets manager.
- **Code:** `// const GOOGLE_MAPS_API_KEY = "AIzaSyCSgsXf19L5ACc5ULBq415940S4q0jVvzQ";`

### HIGH: Hardcoded Secret

- **File:** `customer/customer-original-backup.html` (line 3196)
- **Description:** Credentials should never be hardcoded. Use environment variables or a secrets manager.
- **Code:** `token: 'authToken',`

### HIGH: SQL Injection Risk

- **File:** `customer/customer-original-backup.html`
- **Description:** String concatenation in SQL queries. Use parameterized queries instead.
- **Code:** `const response = await fetch(`[https://nominatim.openstreetmap.org/reverse?format`](https://nominatim.openstreetmap.org/reverse?format`)

### HIGH: XSS Vulnerability

- **File:** `customer/customer-original-backup.html`
- **Description:** Direct HTML injection can lead to XSS attacks. Sanitize user input.

### HIGH: Hardcoded Secret

- **File:** `customer/customer.html` (line 3375)
- **Description:** Credentials should never be hardcoded. Use environment variables or a secrets manager.
- **Code:** `// const GOOGLE_MAPS_API_KEY = "AIzaSyCSgsXf19L5ACc5ULBq415940S4q0jVvzQ";`

### HIGH: Hardcoded Secret

- **File:** `customer/customer.html` (line 3541)
- **Description:** Credentials should never be hardcoded. Use environment variables or a secrets manager.
- **Code:** `token: 'accessToken',`

### HIGH: SQL Injection Risk

- **File:** `customer/customer.html`
- **Description:** String concatenation in SQL queries. Use parameterized queries instead.
- **Code:** `const response = await fetch(`[https://nominatim.openstreetmap.org/reverse?format`](https://nominatim.openstreetmap.org/reverse?format`)

### HIGH: XSS Vulnerability

- **File:** `customer/customer.html`
- **Description:** Direct HTML injection can lead to XSS attacks. Sanitize user input.

### HIGH: Hardcoded Secret

- **File:** `delivery/delivery-original-backup.html` (line 1809)
- **Description:** Credentials should never be hardcoded. Use environment variables or a secrets manager.
- **Code:** `GOOGLE_MAPS_API_KEY: 'YOUR_GOOGLE_MAPS_API_KEY', // Replace with actual API key`

### HIGH: XSS Vulnerability

- **File:** `delivery/delivery-original-backup.html`
- **Description:** Direct HTML injection can lead to XSS attacks. Sanitize user input.

### HIGH: Hardcoded Secret

- **File:** `delivery/delivery.html` (line 1814)
- **Description:** Credentials should never be hardcoded. Use environment variables or a secrets manager.
- **Code:** `GOOGLE_MAPS_API_KEY: 'YOUR_GOOGLE_MAPS_API_KEY', // Replace with actual API key`

### HIGH: XSS Vulnerability

- **File:** `delivery/delivery.html`
- **Description:** Direct HTML injection can lead to XSS attacks. Sanitize user input.

### HIGH: Hardcoded Secret

- **File:** `monitoring/prometheus/prometheus.yml` (line 126)
- **Description:** Credentials should never be hardcoded. Use environment variables or a secrets manager.
- **Code:** `#       password: "password"`

### HIGH: XSS Vulnerability

- **File:** `src/js/pages/customer/order-tracking.js`
- **Description:** Direct HTML injection can lead to XSS attacks. Sanitize user input.

### HIGH: XSS Vulnerability

- **File:** `src/js/pages/real-otp-login.js`
- **Description:** Direct HTML injection can lead to XSS attacks. Sanitize user input.

### HIGH: XSS Vulnerability

- **File:** `src/js/App.js`
- **Description:** Direct HTML injection can lead to XSS attacks. Sanitize user input.

### HIGH: SQL Injection Risk

- **File:** `src/js/cart.js`
- **Description:** String concatenation in SQL queries. Use parameterized queries instead.

### HIGH: Hardcoded Secret

- **File:** `docker-compose.yml` (line 6)
- **Description:** Credentials should never be hardcoded. Use environment variables or a secrets manager.
- **Code:** `POSTGRES_PASSWORD: "786404"`

### HIGH: Hardcoded Secret

- **File:** `docker-compose.yml` (line 45)
- **Description:** Credentials should never be hardcoded. Use environment variables or a secrets manager.
- **Code:** `JWT_ACCESS_SECRET: "dev_access_secret_change_me"`

### HIGH: Hardcoded Secret

- **File:** `docker-compose.yml` (line 46)
- **Description:** Credentials should never be hardcoded. Use environment variables or a secrets manager.
- **Code:** `JWT_REFRESH_SECRET: "dev_refresh_secret_change_me"`

### HIGH: Hardcoded Secret

- **File:** `docker-compose.yml` (line 47)
- **Description:** Credentials should never be hardcoded. Use environment variables or a secrets manager.
- **Code:** `OTP_HASH_SECRET: "dev_otp_hash_secret_change_me"`

### HIGH: Hardcoded Secret

- **File:** `docker-compose.yml` (line 52)
- **Description:** Credentials should never be hardcoded. Use environment variables or a secrets manager.
- **Code:** `DEV_AUTH_BYPASS_SECRET: "dev_login_secret"`

### HIGH: XSS Vulnerability

- **File:** `login.html`
- **Description:** Direct HTML injection can lead to XSS attacks. Sanitize user input.

### HIGH: SQL Injection Risk

- **File:** `test-admin-products.js`
- **Description:** String concatenation in SQL queries. Use parameterized queries instead.
- **Code:** `log(`Update: ${res.status} ${res.data?.message || 'OK'}`, 'info');`

### MEDIUM: Function Constructor

- **File:** `admin/js/ui-utils.js`
- **Description:** Function constructor is similar to eval(). Consider alternatives.

### LOW: Debug Statements

- **File:** `admin/admin-cleaned.html`
- **Description:** 4 console statements found. Remove before production.

### LOW: Debug Statements

- **File:** `admin/admin.html`
- **Description:** 11 console statements found. Remove before production.

### LOW: Debug Statements

- **File:** `admin/admin-original-backup.html`
- **Description:** 11 console statements found. Remove before production.

### LOW: Debug Statements

- **File:** `android/app/src/main/assets/public/customer/customer.html`
- **Description:** 5 console statements found. Remove before production.

### LOW: Debug Statements

- **File:** `android/app/src/main/assets/public/src/js/config/api-config.js`
- **Description:** 8 console statements found. Remove before production.

### LOW: Debug Statements

- **File:** `android/app/src/main/assets/public/index.html`
- **Description:** 10 console statements found. Remove before production.

### LOW: Code Comments

- **File:** `backend/docs/webhook-security-fixes.md`
- **Description:** 1 TODO/FIXME comments found. Address before release.

### LOW: Code Comments

- **File:** `backend/src/controllers/auth.controller.js`
- **Description:** 2 TODO/FIXME comments found. Address before release.

### LOW: Debug Statements

- **File:** `backend/src/legacy/tracking-server.js`
- **Description:** 16 console statements found. Remove before production.

### LOW: Debug Statements

- **File:** `backend/src/legacy/notifications.js`
- **Description:** 6 console statements found. Remove before production.

### LOW: Debug Statements

- **File:** `backend/src/modules/auth/auth.controller.js`
- **Description:** 18 console statements found. Remove before production.

### LOW: Debug Statements

- **File:** `backend/src/socket/socket.js`
- **Description:** 4 console statements found. Remove before production.

### LOW: Code Comments

- **File:** `backend/src/utils/msg91.js`
- **Description:** 3 TODO/FIXME comments found. Address before release.

### LOW: Debug Statements

- **File:** `backend/otp-e2e-check.js`
- **Description:** 6 console statements found. Remove before production.

### LOW: Code Comments

- **File:** `backend/package-lock.json`
- **Description:** 1 TODO/FIXME comments found. Address before release.

### LOW: Debug Statements

- **File:** `backend/run-migrations.js`
- **Description:** 10 console statements found. Remove before production.

### LOW: Code Comments

- **File:** `customer/cart.html`
- **Description:** 2 TODO/FIXME comments found. Address before release.

### LOW: Debug Statements

- **File:** `customer/customer-original-backup.html`
- **Description:** 6 console statements found. Remove before production.

### LOW: Debug Statements

- **File:** `customer/customer.html`
- **Description:** 6 console statements found. Remove before production.

### LOW: Code Comments

- **File:** `customer-app/android/app/build.gradle.kts`
- **Description:** 2 TODO/FIXME comments found. Address before release.

### LOW: Debug Statements

- **File:** `delivery/delivery-original-backup.html`
- **Description:** 16 console statements found. Remove before production.

### LOW: Debug Statements

- **File:** `delivery/delivery.html`
- **Description:** 16 console statements found. Remove before production.

### LOW: Debug Statements

- **File:** `docs/old docs/firebase-notifications.md`
- **Description:** 7 console statements found. Remove before production.

### LOW: Debug Statements

- **File:** `docs/old docs/msg91-otp-configuration.md`
- **Description:** 11 console statements found. Remove before production.

### LOW: Debug Statements

- **File:** `docs/old docs/performance-optimization.md`
- **Description:** 7 console statements found. Remove before production.

### LOW: Code Comments

- **File:** `docs/old docs/production-architecture.md`
- **Description:** 2 TODO/FIXME comments found. Address before release.

### LOW: Debug Statements

- **File:** `src/js/config/api-config.js`
- **Description:** 8 console statements found. Remove before production.

### LOW: Debug Statements

- **File:** `src/js/pages/customer/order-tracking.js`
- **Description:** 7 console statements found. Remove before production.

### LOW: Debug Statements

- **File:** `src/js/services/notification-sounds.js`
- **Description:** 8 console statements found. Remove before production.

### LOW: Debug Statements

- **File:** `src/js/services/delivery-gps-tracking.js`
- **Description:** 18 console statements found. Remove before production.

### LOW: Debug Statements

- **File:** `src/js/services/realtime-tracking.js`
- **Description:** 15 console statements found. Remove before production.

### LOW: Debug Statements

- **File:** `src/js/App.js`
- **Description:** 13 console statements found. Remove before production.

### LOW: Code Comments

- **File:** `PROJECT_BRAIN.md`
- **Description:** 1 TODO/FIXME comments found. Address before release.

### LOW: Debug Statements

- **File:** `test-admin-auth.js`
- **Description:** 12 console statements found. Remove before production.

### LOW: Debug Statements

- **File:** `test-admin-orders.js`
- **Description:** 12 console statements found. Remove before production.

### LOW: Debug Statements

- **File:** `test-admin-delivery.js`
- **Description:** 12 console statements found. Remove before production.

### LOW: Debug Statements

- **File:** `test-admin-products.js`
- **Description:** 14 console statements found. Remove before production.

### LOW: Debug Statements

- **File:** `test-analytics.js`
- **Description:** 18 console statements found. Remove before production.

### LOW: Debug Statements

- **File:** `test-cart-api.js`
- **Description:** 14 console statements found. Remove before production.

### LOW: Debug Statements

- **File:** `test-api-final.js`
- **Description:** 21 console statements found. Remove before production.

### LOW: Debug Statements

- **File:** `test-api-connectivity.js`
- **Description:** 12 console statements found. Remove before production.

### LOW: Debug Statements

- **File:** `test-product-api.js`
- **Description:** 12 console statements found. Remove before production.

### LOW: Debug Statements

- **File:** `test-otp-4digit.js`
- **Description:** 13 console statements found. Remove before production.

### LOW: Debug Statements

- **File:** `test-payment-api.js`
- **Description:** 13 console statements found. Remove before production.

### LOW: Debug Statements

- **File:** `test-order-api.js`
- **Description:** 13 console statements found. Remove before production.

### LOW: Debug Statements

- **File:** `test-tracking-api.js`
- **Description:** 14 console statements found. Remove before production.

## Unused Functions (32)

These functions have zero calls (internal or external) and may be dead code:

### `respondToReview()`

- **File:** `admin/admin-cleaned.html`
- **Line:** 1278
- **Lines of code:** 13

```
        async function respondToReview(reviewId, response) {
            try {
                await apiJson(`/api/admin/reviews/${reviewId}/respond`, {
                    method: 'POST',
                    body: { response }
                });
                await loadReviews();
                showToast('Response added successfully', 'success');
            } catch (error) {
                console.error('Failed to respond to review:', error);
                showToast('Failed to add response', 'error');
            }
        }
```

### `API_BASE_CANDIDATES()`

- **File:** `admin/admin.html`
- **Line:** 4035
- **Lines of code:** 16

```
                            const API_BASE_CANDIDATES = (() => {
                                const manual = (localStorage.getItem('MEATVO_API_BASE') || '').trim();
                                const list = [
                                    manual,
                                    'http://127.0.0.1:8080',
                                    'http://localhost:8080',
                                    'http://127.0.0.1:8081',
                                    'http://localhost:8081'
                                ]
                                    .filter(Boolean)
                                    .map(v => String(v).replace(/\/$/, ''));
                                return [...new Set(list)];
                            })();

                            let API_BASE = API_BASE_CANDIDATES[0];
  // ...
```

### `syncCategories()`

- **File:** `admin/admin.html`
- **Line:** 4981
- **Lines of code:** 16

```
                            async function syncCategories() {
                                // Legacy Firebase sync (no longer used after catalog API migration)
                                return;
                            }
                            // Orders
                            window.openAssignModal = (id) => {
                                state.editingId = id;
                                const sel = document.getElementById('assignPartnerSelect');
                                sel.innerHTML = '<option value="">Select Partner</option>' +
                                    state.partners.filter(p => p.approved).map(p => `<option value="${p.uid}">${p.name} (${p.online ? 'Online' : 'Offline'})</option>`).join('');
                                document.getElementById('assignModal').classList.add('active');
                            };

                            document.getElementById('confirmAssignBtn').addEventListener('click', async () => {
                                const pid = document.getElementById('assignPartnerSelect').value;
  // ...
```

### `requestAdminNotificationPermission()`

- **File:** `admin/admin.html`
- **Line:** 5381
- **Lines of code:** 16

```
                            async function requestAdminNotificationPermission() {
                                try {
                                    if (!('Notification' in window)) {
                                        console.log('This browser does not support notifications');
                                        return false;
                                    }

                                    if (Notification.permission === 'granted') {
                                        return await getAdminFCMToken();
                                    }

                                    if (Notification.permission !== 'denied') {
                                        showAdminPermissionBanner();
                                        return false;
                                    }
  // ...
```

### `initCouponSystem()`

- **File:** `admin/admin.html`
- **Line:** 7318
- **Lines of code:** 16

```
                                function initCouponSystem() {
                                    renderCouponsList();
                                    updateCouponStats();
                                }

                                // Render coupons list
                                function renderCouponsList() {
                                    const couponsList = document.getElementById('couponsList');
                                    if (!couponsList) return;

                                    couponsList.innerHTML = coupons.map(coupon => `
        <div class="coupon-card ${coupon.isActive ? 'active' : 'inactive'}">
          <div class="coupon-header">
            <h4>${coupon.code}</h4>
            <span class="coupon-status">${coupon.isActive ? 'Active' : 'Inactive'}</span>
  // ...
```

### `validateAdminPassword()`

- **File:** `admin/admin-original-backup.html`
- **Line:** 3929
- **Lines of code:** 16

```
              function validateAdminPassword(password) {
                // In production, this should be validated against a secure backend
                if (!password) return false;

                // Basic password requirements
                if (password.length < 8) return false;
                if (!/[A-Z]/.test(password)) return false;
                if (!/[0-9]/.test(password)) return false;

                return true;
              }

              // Secure Token Management
              class SecureTokenManager {
                constructor() {
  // ...
```

### `getFilteredCoupons()`

- **File:** `admin/admin-original-backup.html`
- **Line:** 7335
- **Lines of code:** 16

```
              function getFilteredCoupons() {
                const now = new Date();

                return coupons.filter(coupon => {
                  switch (currentCouponFilter) {
                    case 'active':
                      return coupon.isActive && new Date(coupon.startDate) <= now && new Date(coupon.endDate) >= now;
                    case 'expired':
                      return new Date(coupon.endDate) < now;
                    case 'scheduled':
                      return new Date(coupon.startDate) > now;
                    default:
                      return true;
                  }
                });
  // ...
```

### `getCouponTypeLabel()`

- **File:** `admin/admin-original-backup.html`
- **Line:** 7366
- **Lines of code:** 16

```
              function getCouponTypeLabel(type) {
                const labels = {
                  'percentage': '% Off',
                  'flat': '₹ Off',
                  'free_delivery': 'Free Delivery',
                  'bogo': 'BOGO'
                };
                return labels[type] || type;
              }

              // Get coupon value display
              function getCouponValueDisplay(coupon) {
                switch (coupon.type) {
                  case 'percentage':
                    return `${coupon.value}%${coupon.maxDiscount ? ` (max ₹${coupon.maxDiscount})` : ''}`;
  // ...
```

### `getCouponValueDisplay()`

- **File:** `admin/admin-original-backup.html`
- **Line:** 7377
- **Lines of code:** 16

```
              function getCouponValueDisplay(coupon) {
                switch (coupon.type) {
                  case 'percentage':
                    return `${coupon.value}%${coupon.maxDiscount ? ` (max ₹${coupon.maxDiscount})` : ''}`;
                  case 'flat':
                    return `₹${coupon.value}`;
                  case 'free_delivery':
                    return 'Free';
                  case 'bogo':
                    return 'Buy X Get Y';
                  default:
                    return 'N/A';
                }
              }

  // ...
```

### `getCouponStatus()`

- **File:** `admin/admin-original-backup.html`
- **Line:** 7393
- **Lines of code:** 16

```
              function getCouponStatus(coupon) {
                const now = new Date();
                const startDate = new Date(coupon.startDate);
                const endDate = new Date(coupon.endDate);

                if (!coupon.isActive) return 'inactive';
                if (now < startDate) return 'scheduled';
                if (now > endDate) return 'expired';
                if (coupon.usageLimit.total > 0 && coupon.currentUsage >= coupon.usageLimit.total) return 'exhausted';
                return 'active';
              }

              // Show create coupon modal
              function showCreateCouponModal() {
                editingCouponId = null;
  // ...
```

### `loadProductsFromFirebase()`

- **File:** `android/app/src/main/assets/public/customer/customer.html`
- **Line:** 3923
- **Lines of code:** 16

```
    function loadProductsFromFirebase() {
      try {
        console.log('Loading products from database...');
        const productsRef = database.ref('/products');
        productsRef.on('value', (snapshot) => {
          products = [];
          if (snapshot.exists()) {
            snapshot.forEach((child) => {
              products.push({
                id: child.key,
                ...child.val()
              });
            });
            console.log(`Loaded ${products.length} products`);
          } else {
  // ...
```

### `updatetrackingETA()`

- **File:** `android/app/src/main/assets/public/customer/customer.html`
- **Line:** 4709
- **Lines of code:** 16

```
    function updatetrackingETA(driverLat, driverLng, customerLat, customerLng) {
      if (!window.google || !window.google.maps) return;

      if (!directionsService) directionsService = new google.maps.DirectionsService();

      directionsService.route({
        origin: { lat: driverLat, lng: driverLng },
        destination: { lat: customerLat, lng: customerLng },
        travelMode: google.maps.TravelMode.DRIVING
      }, (response, status) => {
        if (status === 'OK') {
          const route = response.routes[0].legs[0];
          const distance = route.distance.text;
          const duration = route.duration.text;

  // ...
```

### `openProductDetail()`

- **File:** `android/app/src/main/assets/public/customer/customer.html`
- **Line:** 5133
- **Lines of code:** 16

```
    function openProductDetail(productId) {
      const product = products.find(p => p.id === productId);
      if (!product) return;

      const detailSection = document.getElementById('productDetailSection');

      // Populate Data
      document.getElementById('detailImage').src = product.imageUrl || 'https://via.placeholder.com/400?text=No+Image';
      document.getElementById('detailName').textContent = product.name;
      document.getElementById('detailUnit').textContent = product.unit || '1 piece';
      document.getElementById('detailPrice').textContent = `₹${product.price || 0}`;

      // Description
      const descEl = document.getElementById('detailDescription');
      if (product.description) {
  // ...
```

### `updateDetailQty()`

- **File:** `android/app/src/main/assets/public/customer/customer.html`
- **Line:** 5252
- **Lines of code:** 14

```
    function updateDetailQty(productId, change) {
      if (change > 0) {
        addToCart(productId);
      } else {
        removeFromCart(productId);
      }

      // Re-render controls to reflect new state
      const product = products.find(p => p.id === productId);
      if (product) {
        renderProductDetailControls(product);
        updateDetailCartBadge();
      }
    }
```

### `servicesJSON()`

- **File:** `android/app/build.gradle`
- **Line:** 57
- **Lines of code:** 8

```
    def servicesJSON = file('google-services.json')
    if (servicesJSON.text) {
        apply plugin: 'com.google.gms.google-services'
    }
} catch(Exception e) {
    logger.info("google-services.json not found, google-services plugin not applied. Push Notifications won't work")
}

```

### `escapeHtml()`

- **File:** `customer/customer-original-backup.html`
- **Line:** 4747
- **Lines of code:** 5

```
    function escapeHtml(text) {
      const div = document.createElement('div');
      div.textContent = text;
      return div.innerHTML;
    }
```

### `quickAddToCart()`

- **File:** `customer/customer.html`
- **Line:** 6419
- **Lines of code:** 14

```
    async function quickAddToCart(productId) {
      const product = products.find(p => p.id === productId);
      if (!product) return;
      
      // Animate button
      const btn = event.target;
      btn.style.transform = 'scale(0.8)';
      setTimeout(() => btn.style.transform = '', 200);
      
      // Add to cart logic (reuse existing)
      await addToCart(productId);
      
      showToast(`✓ ${product.name} added to cart`, 'success');
    }
```

### `toggleLanguage()`

- **File:** `delivery/delivery-original-backup.html`
- **Line:** 338
- **Lines of code:** 6

```
    function toggleLanguage() {
      const currentLang = I18n.currentLang;
      const newLang = currentLang === 'en' ? 'hi' : 'en';
      I18n.setLanguage(newLang);
      showToast(`Language changed to ${newLang === 'hi' ? 'हिंदी' : 'English'}`, 'success');
    }
```

### `startNavigation()`

- **File:** `delivery/delivery-original-backup.html`
- **Line:** 1925
- **Lines of code:** 14

```
    function startNavigation(customerLat, customerLng) {
      const store = STORE_LOCATION;
      
      // For Capacitor (mobile app)
      if (window.Capacitor) {
        // Use native navigation
        const url = `geo:${customerLat},${customerLng}?q=${customerLat},${customerLng}(Delivery)`;
        window.open(url, '_system');
      } else {
        // Web fallback - Google Maps directions
        const url = `https://www.google.com/maps/dir/?api=1&origin=${store.lat},${store.lng}&destination=${customerLat},${customerLng}&travelmode=driving`;
        window.open(url, '_blank');
      }
    }
```

### `manualStatusUpdate()`

- **File:** `delivery/delivery-original-backup.html`
- **Line:** 2059
- **Lines of code:** 11

```
    function manualStatusUpdate(status) {
      if (window.realtimeSocket && currentOrderId) {
        window.realtimeSocket.emit('delivery:manual_status_update', {
          orderId: currentOrderId,
          status: status,
          timestamp: new Date().toISOString()
        });
        
        showToast(`📍 Status updated: ${status.replace('_', ' ')}`, 'success');
      }
    }
```

### `openWebDirections()`

- **File:** `delivery/delivery-original-backup.html`
- **Line:** 2206
- **Lines of code:** 10

```
    function openWebDirections(customerLat, customerLng) {
      if (!customerLat || !customerLng) {
        showToast('Customer location not available', 'error');
        return;
      }
      
      const store = STORE_LOCATION;
      const url = `https://www.google.com/maps/dir/?api=1&origin=${store.lat},${store.lng}&destination=${customerLat},${customerLng}&travelmode=driving`;
      window.open(url, '_blank');
    }
```

### `requestEmergencyReassign()`

- **File:** `delivery/delivery-original-backup.html`
- **Line:** 3392
- **Lines of code:** 16

```
    async function requestEmergencyReassign(orderId, reason) {
      try {
        const response = await fetch(`/api/delivery/orders/${orderId}/emergency-reassign`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ reason })
        });
        
        if (!response.ok) throw new Error('Failed to request reassignment');
        
        showToast('Emergency reassignment requested', 'info');
        addAssignmentLogEntry(`Emergency reassignment requested for Order #${orderId.substring(0, 6)}: ${reason}`, 'warning');
        
        // Notify admin
        if (window.realtimeSocket) {
  // ...
```

### `requestNotificationPermission()`

- **File:** `delivery/delivery-original-backup.html`
- **Line:** 3505
- **Lines of code:** 16

```
    async function requestNotificationPermission() {
      try {
        if (!('Notification' in window)) {
          console.log('This browser does not support notifications');
          return false;
        }

        if (Notification.permission === 'granted') {
          return await getFCMToken();
        }

        if (Notification.permission !== 'denied') {
          showPermissionBanner();
          return false;
        }
  // ...
```

### `grantNotificationPermission()`

- **File:** `delivery/delivery-original-backup.html`
- **Line:** 3549
- **Lines of code:** 11

```
    async function grantNotificationPermission() {
      const permission = await Notification.requestPermission();
      hidePermissionBanner();
      
      if (permission === 'granted') {
        showToast('Notifications enabled! You\'ll receive order assignments instantly.', 'success');
        await getFCMToken();
      } else {
        showToast('Notifications disabled. You may miss important order assignments.', 'warning');
      }
    }
```

### `denyNotificationPermission()`

- **File:** `delivery/delivery-original-backup.html`
- **Line:** 3562
- **Lines of code:** 5

```
    function denyNotificationPermission() {
      hidePermissionBanner();
      localStorage.setItem('notificationPermission', 'denied');
      showToast('Notifications disabled. You can enable them anytime in settings.', 'info');
    }
```

### `acceptOrderFromNotification()`

- **File:** `delivery/delivery-original-backup.html`
- **Line:** 3690
- **Lines of code:** 8

```
    async function acceptOrderFromNotification(orderId) {
      // Remove notification
      const notifications = document.querySelectorAll('.fcm-notification');
      notifications.forEach(n => n.remove());
      
      // Accept the order
      await acceptAssignedOrder();
    }
```

### `rejectOrderFromNotification()`

- **File:** `delivery/delivery-original-backup.html`
- **Line:** 3700
- **Lines of code:** 8

```
    async function rejectOrderFromNotification(orderId) {
      // Remove notification
      const notifications = document.querySelectorAll('.fcm-notification');
      notifications.forEach(n => n.remove());
      
      // Reject the order
      await rejectAssignedOrder('notification_reject');
    }
```

### `acceptEmergencyOrder()`

- **File:** `delivery/delivery-original-backup.html`
- **Line:** 3710
- **Lines of code:** 11

```
    async function acceptEmergencyOrder(orderId) {
      // Remove notification
      const notifications = document.querySelectorAll('.fcm-notification');
      notifications.forEach(n => n.remove());
      
      // Accept with priority flag
      if (currentAssignment) {
        currentAssignment.isEmergency = true;
      }
      await acceptAssignedOrder();
    }
```

### `clearAppBadge()`

- **File:** `delivery/delivery-original-backup.html`
- **Line:** 3776
- **Lines of code:** 5

```
    function clearAppBadge() {
      if ('clearAppBadge' in navigator) {
        navigator.clearAppBadge();
      }
    }
```

### `apiPost()`

- **File:** `src/js/utils/api.js`
- **Line:** 101
- **Lines of code:** 8

```
async function apiPost(endpoint, body) {
  const res = await apiCall(endpoint, {
    method: 'POST',
    body: JSON.stringify(body)
  });
  if (!res) return { success: false, message: 'Authentication failed' };
  return res.json();
}
```

### `apiPut()`

- **File:** `src/js/utils/api.js`
- **Line:** 116
- **Lines of code:** 8

```
async function apiPut(endpoint, body) {
  const res = await apiCall(endpoint, {
    method: 'PUT',
    body: JSON.stringify(body)
  });
  if (!res) return { success: false, message: 'Authentication failed' };
  return res.json();
}
```

### `apiDelete()`

- **File:** `src/js/utils/api.js`
- **Line:** 130
- **Lines of code:** 5

```
async function apiDelete(endpoint) {
  const res = await apiCall(endpoint, { method: 'DELETE' });
  if (!res) return { success: false, message: 'Authentication failed' };
  return res.json();
}
```

## Design Patterns

### Singleton

Ensures a class has only one instance. Common for configuration, logging, or connection pools.

**Files:** `cart_provider.dart`

### Factory

Creates objects without specifying exact class. Enables loose coupling and extensibility.

**Files:** `dashboard.js`, `ui-utils.js`, `admin-cleaned.html`, `admin.html`, `admin-original-backup.html`NaN more)

### Observer/Event

Defines a subscription mechanism for event-driven architecture. Great for decoupling.

**Files:** `dashboard.js`, `admin-cleaned.html`, `admin.html`, `admin-original-backup.html`, `admin-login.html`NaN more)

### Higher-Order Component

Functions that take a component and return an enhanced component.

**Files:** `redis.js`

### Context Provider

React Context for global state. Alternative to prop drilling.

**Files:** `AndroidManifest.xml`, `dart_plugin_registrant.dart`, `GeneratedPluginRegistrant.java`, `router.dart`, `auth_provider.dart`NaN more)

### Modules

VBA Modules for reusable code and business logic.

**Files:** `modules.xml`

## Anti-Patterns

### God Object

Files with too many responsibilities (15+ functions). Consider splitting into smaller modules.

**Affected files:** `api.js`, `dashboard.js`, `admin-cleaned.html`, `admin.html`, `admin-original-backup.html`

### Long File

Files over 500 lines are harder to maintain. Consider breaking into smaller modules.

**Affected files:** `dashboard.js`, `admin-cleaned.html`, `admin.html`, `admin-original-backup.html`, `admin-login.html`

### VBA God Module

VBA modules with 20+ procedures. Consider splitting into smaller modules.

**Affected files:** `api.js`, `admin-cleaned.html`, `admin.html`, `admin-original-backup.html`, `admin.html`

## Architecture Issues

### 32 Unused Functions

Functions not called from other files

**Affected:** `respondToReview`, `API_BASE_CANDIDATES`, `syncCategories`, `requestAdminNotificationPermission`, `initCouponSystem`

### 26 Large Files

Files with 15+ functions

**Affected:** `api.js (25 fns)`, `dashboard.js (18 fns)`, `admin-cleaned.html (55 fns)`, `admin.html (232 fns)`, `admin-original-backup.html (312 fns)`

### 25 Highly Coupled

Files imported by 8+ others

**Affected:** `admin-original-backup.html (163 imports)`, `admin.html (73 imports)`, `delivery.html (73 imports)`, `customer-original-backup.html (72 imports)`, `customer.html (72 imports)`

### 3 Circular Dependencies

Files that import each other

**Affected:** `admin-original-backup.html ↔ admin.html`, `admin.html ↔ delivery-original-backup.html`, `delivery.html ↔ delivery-original-backup.html`

### 106 Duplicate Function Names

Same function name in multiple files

**Affected:** `apiRequest (6 files)`, `getToken (4 files)`, `apiJson (7 files)`, `saveAssignmentRules (3 files)`, `convertToCSV (3 files)`

### 34 Similar Code Blocks

Copy-paste code detected

**Affected:** `calculateDistance, calculateDistance, calculateDistance, calculateDistance`, `getAssignmentStatus, releaseAssignment, refresh, getAccessToken, sendOTP, verifyOTP, updateOrderStatus, assignOrder, createProduct, updateProduct, later, confirmDialog, logout, validateOTP, validateEmail, addCSRFToHeaders, clearLoginAttempts, loginSuccess, if, renderDeliveryAnalytics, if, renderDeliveryAnalytics, switch, getAdminToken, getAuthToken, apiGet, getDeliveryToken, showError, validatePhoneNumber, displayProducts, displayCategories, addition_isCorrect, getItem, setItem, removeItem, phone, otp, clearLoginAttempts, parseQuery, handleClientError, handleServerError, updateSessionActivity, jsonRateLimitHandler, getRemainingBackupCodes, gracefulShutdown, getFileSecurityStats, setMaxFileSize, emitToUser, verifyHash, verifyApiKey, ok, created, fail, changeAddress, changeAddress, getAuthToken, apiGet, isUPIAvailable, escapeHtml, validateEmail, addCSRFToHeaders, clearLoginAttempts, getAuthToken, apiGet, isUPIAvailable, escapeHtml, switchLocation, joinMembership, callDriver, messageDriver, viewDetails, contactSupport, updateDynamicContent, isWithinDeliveryZone, sortOrdersByDistance, getDeliveryToken, showError, updateDynamicContent, isWithinDeliveryZone, sortOrdersByDistance, validateEmail, addCSRFToHeaders, clearLoginAttempts, getDeliveryToken, showError, getAPIConfig, formatTime, formatDistance, validatePhoneNumber, clearLoginAttempts, hasRole, redirectByRole, displayProducts, displayCategories`, `getDashboardStats, getRecentOrders, getOrders, getOrder, getCurrentUser, getPhoneNumber, getApiRequests, getRequestId, isTokenExpired, getClient, toggleLanguage, toggleLanguage, getPhoneNumber, getUser`, `getProducts, getDeliveryPartners, getCustomers, showOrderDetails, formatCurrency, validatePhone, formatPhone, sendOTP, validatePhone, closeManualAssignmentModal, closeAssignmentRulesModal, closeBulkAssignModal, updateStats, if, getCouponValueDisplay, updateStats, if, setLoginError, loginSuccess, closeSidebar, closeAddressModal, loadBannerFromApi, closeCategoryProducts, closeCheckoutModal, changeCheckoutAddress, loadThemeFromApi, closeProductDetail, stopLocationTracking, handlePhoneKeyPress, goToSuccessStep, stopResendTimer, showError, clearError, get, getAll, reload, del, startHeartbeat, securityHeaders, generateOtpCode, sha256, asyncMiddleware, asyncMiddleware, generateChecksum, createLogEntry, hasSuspiciousIPPattern, addAllowedMimeType, removeAllowedMimeType, isSessionValid, monitorSecurityEvents, addSensitiveKeyPattern, removeSensitiveKeyPattern, getEligiblePartners, emitToRole, emitToAll, formatFreshnessDate, decodeToken, invalidateUserTokens, generateSessionToken, generateApiKey, saveCartToLocal, closeAddressModal, loadBannerFromApi, closeCategoryProducts, closeCheckoutModal, changeCheckoutAddress, loadThemeFromApi, closeProductDetail, validatePhone, closeAddressModal, loadBannerFromApi, closeCategoryProducts, closeCheckoutModal, changeCheckoutAddress, loadThemeFromApi, closeProductDetail, setupEventListeners, startNavigation, openWebDirections, stopLocationTracking, clearAppBadge, calculateAverage, setupEventListeners, startNavigation, openWebDirections, validatePhone, stopLocationTracking, clearAppBadge, calculateAverage, isStepCompleted, formatDateTime, shouldFollowPartner, panToPartner, startUIUpdates, updateUI, showConnectionWarning, hideConnectionWarning, handlePhoneKeyPress, goToSuccessStep, stopResendTimer, showError, clearError, getApiBase, isTokenExpired, stopTokenRefresh, obfuscate, deobfuscate, validatePhone, isDeliveryPartner, hasPermission, setCache, handleHeartbeat, handleError, stopHeartbeat, getUser, setTokens`, `renderOrdersList, renderDeliveryList, renderCustomersList, getSpinner, renderCustomerAnalytics, if, if, renderCustomerAnalytics, if, if, if, validate, generateTokens, createPayment, getSecurityStats, testPayment, t, t, createMapIcons, redirectBasedOnRole, processPosition, log, log, log, log, log, log, log, log, log, log, log`

### 57 Architecture Violations

Lower layers importing from higher layers

**Affected:** `utils → ui`, `config → ui`, `modules → ui`, `config → data`, `config → data`

### 68 High Complexity Files

Files with complexity score >30

**Affected:** `admin-original-backup.html (688)`, `customer.html (636)`, `customer-original-backup.html (578)`, `admin.html (569)`, `customer.html (514)`

## File Details


| File                           | Folder                                                  | Layer      | Lines | Functions |
| ------------------------------ | ------------------------------------------------------- | ---------- | ----- | --------- |
| `README.md`                    | .expo                                                   | note       | 16    | 0         |
| `settings.json`                | .expo                                                   | config     | 9     | 0         |
| `ci-cd.yml`                    | .github/workflows                                       | utils      | 303   | 0         |
| `appearance.json`              | .obsidian                                               | utils      | 1     | 0         |
| `app.json`                     | .obsidian                                               | utils      | 1     | 0         |
| `core-plugins.json`            | .obsidian                                               | utils      | 33    | 0         |
| `workspace.json`               | .obsidian                                               | utils      | 181   | 0         |
| `workspace-state.json`         | .openclaw                                               | utils      | 5     | 0         |
| `assignment-engine.js`         | admin/js                                                | utils      | 209   | 11        |
| `api.js`                       | admin/js                                                | utils      | 185   | 25        |
| `dashboard.js`                 | admin/js                                                | utils      | 524   | 18        |
| `ui-utils.js`                  | admin/js                                                | utils      | 241   | 9         |
| `auth.js`                      | admin/js                                                | utils      | 149   | 11        |
| `admin-layout.css`             | admin                                                   | utils      | 865   | 0         |
| `admin-cleaned.html`           | admin                                                   | utils      | 1914  | 55        |
| `admin.html`                   | admin                                                   | utils      | 7937  | 232       |
| `admin-original-backup.html`   | admin                                                   | utils      | 8684  | 312       |
| `layout-structure.md`          | admin                                                   | note       | 180   | 0         |
| `index.html`                   | admin                                                   | utils      | 11    | 0         |
| `admin-login.html`             | admin                                                   | utils      | 552   | 1         |
| `BACKEND_AGENT.md`             | Agents                                                  | note       | 43    | 0         |
| `PM_AGENT.md`                  | Agents                                                  | note       | 29    | 0         |
| `FRONTEND_AGENT.md`            | Agents                                                  | note       | 70    | 0         |
| `QA_AGENT.md`                  | Agents                                                  | note       | 37    | 0         |
| `SECURITY_AGENT.md`            | Agents                                                  | note       | 36    | 0         |
| `checksums.lock`               | android/.gradle/8.10.2/checksums                        | utils      | 1     | 0         |
| `gc.properties`                | android/.gradle/8.10.2/dependencies-accessors           | utils      | 0     | 0         |
| `executionHistory.lock`        | android/.gradle/8.10.2/executionHistory                 | utils      | 1     | 0         |
| `fileHashes.lock`              | android/.gradle/8.10.2/fileHashes                       | utils      | 2     | 0         |
| `gc.properties`                | android/.gradle/8.10.2                                  | utils      | 0     | 0         |
| `checksums.lock`               | android/.gradle/8.14.3/checksums                        | utils      | 1     | 0         |
| `executionHistory.lock`        | android/.gradle/8.14.3/executionHistory                 | utils      | 1     | 0         |
| `fileHashes.lock`              | android/.gradle/8.14.3/fileHashes                       | utils      | 2     | 0         |
| `gc.properties`                | android/.gradle/8.14.3                                  | utils      | 0     | 0         |
| `buildOutputCleanup.lock`      | android/.gradle/buildOutputCleanup                      | utils      | 1     | 0         |
| `cache.properties`             | android/.gradle/buildOutputCleanup                      | utils      | 3     | 0         |
| `gc.properties`                | android/.gradle/vcs-1                                   | utils      | 0     | 0         |
| `config.properties`            | android/.gradle                                         | config     | 3     | 0         |
| `deviceStreaming.xml`          | android/.idea/caches                                    | utils      | 1462  | 0         |
| `.gitignore`                   | android/.idea                                           | utils      | 4     | 0         |
| `compiler.xml`                 | android/.idea                                           | utils      | 6     | 0         |
| `migrations.xml`               | android/.idea                                           | data       | 10    | 0         |
| `misc.xml`                     | android/.idea                                           | utils      | 10    | 0         |
| `deploymentTargetSelector.xml` | android/.idea                                           | utils      | 10    | 0         |
| `gradle.xml`                   | android/.idea                                           | utils      | 26    | 0         |
| `runConfigurations.xml`        | android/.idea                                           | utils      | 17    | 0         |
| `workspace.xml`                | android/.idea                                           | utils      | 126   | 0         |
| `ExampleInstrumentedTest.java` | android/app/src/androidTest/java/com/getcapacitor/myapp | utils      | 27    | 1         |
| `admin-login.html`             | android/app/src/main/assets/public/admin                | utils      | 24    | 0         |
| `admin.html`                   | android/app/src/main/assets/public/admin                | utils      | 2124  | 26        |
| `customer.html`                | android/app/src/main/assets/public/customer             | utils      | 5647  | 71        |
| `delivery-login.html`          | android/app/src/main/assets/public/delivery             | utils      | 24    | 0         |
| `delivery.html`                | android/app/src/main/assets/public/delivery             | utils      | 1707  | 18        |
| `components.css`               | android/app/src/main/assets/public/src/assets/css       | components | 585   | 0         |
| `critical.css`                 | android/app/src/main/assets/public/src/assets/css       | utils      | 112   | 0         |
| `layouts.css`                  | android/app/src/main/assets/public/src/assets/css       | utils      | 276   | 0         |
| `product-cards.css`            | android/app/src/main/assets/public/src/assets/css       | utils      | 414   | 0         |
| `design-system.css`            | android/app/src/main/assets/public/src/assets/css       | utils      | 215   | 0         |
| `real-otp-login.css`           | android/app/src/main/assets/public/src/assets/css       | utils      | 457   | 0         |
| `api-config.js`                | android/app/src/main/assets/public/src/js/config        | config     | 125   | 6         |
| `real-otp-login.js`            | android/app/src/main/assets/public/src/js/pages         | ui         | 631   | 29        |
| `customer-login.html`          | android/app/src/main/assets/public/src                  | utils      | 24    | 0         |
| `cordova.js`                   | android/app/src/main/assets/public                      | utils      | 1     | 0         |
| `cordova_plugins.js`           | android/app/src/main/assets/public                      | utils      | 1     | 0         |
| `index.html`                   | android/app/src/main/assets/public                      | utils      | 537   | 8         |
| `capacitor.config.json`        | android/app/src/main/assets                             | utils      | 45    | 0         |
| `capacitor.plugins.json`       | android/app/src/main/assets                             | utils      | 23    | 0         |
| `MainActivity.java`            | android/app/src/main/java/com/meatvo/app                | utils      | 6     | 0         |
| `ic_launcher_background.xml`   | android/app/src/main/res/drawable                       | utils      | 171   | 0         |
| `ic_launcher_foreground.xml`   | android/app/src/main/res/drawable-v24                   | utils      | 35    | 0         |
| `activity_main.xml`            | android/app/src/main/res/layout                         | utils      | 13    | 0         |
| `ic_launcher.xml`              | android/app/src/main/res/mipmap-anydpi-v26              | utils      | 5     | 0         |
| `ic_launcher_round.xml`        | android/app/src/main/res/mipmap-anydpi-v26              | utils      | 5     | 0         |
| `ic_launcher_background.xml`   | android/app/src/main/res/values                         | utils      | 4     | 0         |
| `strings.xml`                  | android/app/src/main/res/values                         | utils      | 8     | 0         |
| `styles.xml`                   | android/app/src/main/res/values                         | utils      | 22    | 0         |
| `config.xml`                   | android/app/src/main/res/xml                            | config     | 6     | 0         |
| `file_paths.xml`               | android/app/src/main/res/xml                            | utils      | 5     | 0         |
| `AndroidManifest.xml`          | android/app/src/main                                    | utils      | 49    | 0         |
| `ExampleUnitTest.java`         | android/app/src/test/java/com/getcapacitor/myapp        | test       | 19    | 1         |
| `.gitignore`                   | android/app                                             | utils      | 3     | 0         |
| `build.gradle`                 | android/app                                             | utils      | 64    | 1         |
| `capacitor.build.gradle`       | android/app                                             | utils      | 24    | 0         |
| `AndroidManifest.xml`          | android/capacitor-cordova-android-plugins/src/main      | utils      | 8     | 0         |
| `build.gradle`                 | android/capacitor-cordova-android-plugins               | utils      | 59    | 1         |
| `cordova.variables.gradle`     | android/capacitor-cordova-android-plugins               | utils      | 7     | 0         |
| `gradle-wrapper.properties`    | android/gradle/wrapper                                  | utils      | 8     | 0         |
| `.gitignore`                   | android                                                 | utils      | 102   | 0         |
| `build.gradle`                 | android                                                 | utils      | 30    | 1         |
| `capacitor.settings.gradle`    | android                                                 | utils      | 19    | 0         |
| `variables.gradle`             | android                                                 | utils      | 16    | 0         |
| `gradle.properties`            | android                                                 | utils      | 23    | 0         |
| `settings.gradle`              | android                                                 | config     | 5     | 0         |
| `local.properties`             | android                                                 | utils      | 9     | 0         |
| `components.css`               | assets/css                                              | components | 585   | 0         |
| `critical.css`                 | assets/css                                              | utils      | 112   | 0         |
| `design-system.css`            | assets/css                                              | utils      | 215   | 0         |
| `layouts.css`                  | assets/css                                              | utils      | 276   | 0         |
| `real-otp-login.css`           | assets/css                                              | utils      | 457   | 0         |
| `product-cards.css`            | assets/css                                              | utils      | 414   | 0         |


*...and 313 more files*
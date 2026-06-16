# Meatvo API Quick Start Guide

**5-Minute Quick Reference**

---

## 📋 Overview

The Meatvo API is a RESTful API for a hyperlocal meat delivery platform with:
- **80+ REST endpoints** across 11 modules
- **JWT authentication** with OTP-based login
- **Real-time updates** via Socket.io
- **Rate limiting** to prevent abuse
- **PhonePe payment integration**

---

## 🔗 Base URLs

| Environment | URL |
|-------------|-----|
| Development | `http://localhost:8080/api` |
| Production | `https://api.meatvo.com/api` |

---

## 🔐 Quick Authentication

### Step 1: Send OTP

```bash
POST /auth/send-otp
Content-Type: application/json

{
  "phone": "+919876543210"
}
```

### Step 2: Verify OTP & Get Tokens

```bash
POST /auth/verify-otp
Content-Type: application/json

{
  "phone": "+919876543210",
  "otp": "1234"
}

# Response includes:
{
  "data": {
    "accessToken": "eyJhbG...",
    "refreshToken": "eyJhbG...",
    "user": { ... }
  }
}
```

### Step 3: Use Access Token

```bash
GET /products
Authorization: Bearer eyJhbG...
```

---

## 📚 API Modules

| Module | Endpoints | Description |
|--------|-----------|-------------|
| **Auth** | 8 | OTP login, JWT refresh, MFA |
| **Users** | 2 | Profile, FCM tokens |
| **Addresses** | 5 | CRUD delivery addresses |
| **Products** | 7 | Browse, search, CRUD (admin) |
| **Categories** | 4 | Product categories |
| **Cart** | 6 | Redis-backed shopping cart |
| **Orders** | 6 | Place orders, track, cancel |
| **Payments** | 4 | PhonePe integration |
| **Delivery** | 13 | Slots, rider operations |
| **Coupons** | 3 | Discount codes |
| **Banners** | 3 | Promotional banners |
| **Settings** | 4 | Store config |
| **Admin** | 15+ | Dashboard, management |

---

## 🚀 Common Use Cases

### 1. Browse Products

```bash
GET /products?page=1&limit=20&categoryId=3
# Public, no auth required
```

### 2. Add to Cart

```bash
POST /cart
Authorization: Bearer {token}
Content-Type: application/json

{
  "productId": 1,
  "quantity": 2
}
```

### 3. Place Order

```bash
POST /orders
Authorization: Bearer {token}
Content-Type: application/json

{
  "deliveryAddress": "123 Main St, Dhanbad",
  "paymentMethod": "COD",
  "addressId": 1,
  "deliverySlotId": 5
}
```

### 4. Track Order

```bash
GET /orders/1001
Authorization: Bearer {token}

# Response:
{
  "data": {
    "id": 1001,
    "status": "OUT_FOR_DELIVERY",
    "deliveryPartnerId": 5,
    ...
  }
}
```

---

## 🎭 User Roles

| Role | Description | Access Level |
|------|-------------|--------------|
| **customer** | Regular users | Own data only |
| **delivery** | Delivery partners | Assigned orders |
| **admin** | Administrators | Full system access |

---

## ⚡ Rate Limits

| Endpoint | Limit | Window |
|----------|-------|--------|
| General API | 300 req | 15 min |
| Auth Routes | 60 req | 15 min |
| OTP Send | 10 req | 10 min per phone |
| OTP Verify | 3 attempts | Before block |
| Payments | 10 req | 1 min |

---

## 🔴 Common Error Codes

| Code | HTTP Status | Meaning |
|------|-------------|---------|
| `VALIDATION_ERROR` | 400 | Invalid input |
| `UNAUTHORIZED` | 401 | Missing/invalid token |
| `FORBIDDEN` | 403 | Insufficient permissions |
| `NOT_FOUND` | 404 | Resource doesn't exist |
| `RATE_LIMITED` | 429 | Too many requests |
| `OTP_EXPIRED` | 401 | OTP expired (10 min) |
| `OTP_INVALID` | 401 | Wrong OTP code |
| `PHONE_BLOCKED` | 401 | Too many failed attempts |
| `INVALID_COUPON` | 400 | Coupon invalid/expired |

---

## 📦 Response Format

### Success (2xx)

```json
{
  "success": true,
  "ok": true,
  "data": { ... },
  "message": "Success message"
}
```

### Error (4xx/5xx)

```json
{
  "success": false,
  "ok": false,
  "error": {
    "message": "Error description",
    "code": "ERROR_CODE"
  },
  "data": {},
  "message": "Error description"
}
```

---

## 🔌 Real-Time Events

### Connect to WebSocket

```javascript
import io from 'socket.io-client';

const socket = io('http://localhost:8080', {
  auth: { token: accessToken }
});
```

### Customer Events

- `order:status` - Order status updates
- `rider:location` - Delivery partner location

### Delivery Partner Events

- `order:new` - New order available
- `order:assigned` - Order assigned to you

### Admin Events

- `order:placed` - Customer placed new order

---

## 🛠️ Tools & Resources

### 1. OpenAPI Specification
```yaml
# docs/API_SPECIFICATION.yaml
# Use with Swagger UI, Postman, code generators
```

### 2. Full API Reference
```markdown
# docs/API_REFERENCE.md
# Complete endpoint docs with examples
```

### 3. Postman Collection
```bash
# Import OpenAPI spec into Postman
File → Import → docs/API_SPECIFICATION.yaml
```

### 4. Generate Client SDK
```bash
# JavaScript
openapi-generator-cli generate \
  -i docs/API_SPECIFICATION.yaml \
  -g javascript \
  -o clients/js

# Python
openapi-generator-cli generate \
  -i docs/API_SPECIFICATION.yaml \
  -g python \
  -o clients/python
```

---

## 💻 Code Examples

### JavaScript (Axios)

```javascript
import axios from 'axios';

const api = axios.create({
  baseURL: 'http://localhost:8080/api',
  headers: {
    'Authorization': `Bearer ${accessToken}`
  }
});

// Get products
const products = await api.get('/products?page=1&limit=20');

// Add to cart
const cart = await api.post('/cart', {
  productId: 1,
  quantity: 2
});

// Place order
const order = await api.post('/orders', {
  deliveryAddress: '123 Main St',
  paymentMethod: 'COD',
  addressId: 1
});
```

### Flutter/Dart

```dart
import 'package:dio/dio.dart';

final dio = Dio(
  BaseOptions(
    baseUrl: 'http://localhost:8080/api',
    headers: {'Authorization': 'Bearer $accessToken'},
  ),
);

// Get products
final products = await dio.get('/products', 
  queryParameters: {'page': 1, 'limit': 20}
);

// Add to cart
final cart = await dio.post('/cart', data: {
  'productId': 1,
  'quantity': 2,
});

// Place order
final order = await dio.post('/orders', data: {
  'deliveryAddress': '123 Main St',
  'paymentMethod': 'COD',
  'addressId': 1,
});
```

### Python (Requests)

```python
import requests

headers = {'Authorization': f'Bearer {access_token}'}
base_url = 'http://localhost:8080/api'

# Get products
products = requests.get(
    f'{base_url}/products',
    params={'page': 1, 'limit': 20}
)

# Add to cart
cart = requests.post(
    f'{base_url}/cart',
    json={'productId': 1, 'quantity': 2},
    headers=headers
)

# Place order
order = requests.post(
    f'{base_url}/orders',
    json={
        'deliveryAddress': '123 Main St',
        'paymentMethod': 'COD',
        'addressId': 1
    },
    headers=headers
)
```

---

## 🔒 Security Best Practices

1. **Always use HTTPS** in production
2. **Store tokens securely** (HttpOnly cookies, secure storage)
3. **Never log tokens** or sensitive data
4. **Implement token refresh** before expiration
5. **Validate all input** on client side
6. **Handle errors gracefully** with proper messages
7. **Use MFA** for admin accounts

---

## 🐛 Debugging Tips

### Check Token Expiration

```javascript
// JWT tokens expire after 1 hour
// Decode token to check expiration
const payload = JSON.parse(atob(token.split('.')[1]));
console.log('Expires at:', new Date(payload.exp * 1000));
```

### Handle Token Refresh

```javascript
// Intercept 401 errors and refresh token
axios.interceptors.response.use(
  response => response,
  async error => {
    if (error.response?.status === 401) {
      // Refresh token and retry
      const newToken = await refreshAccessToken();
      error.config.headers.Authorization = `Bearer ${newToken}`;
      return axios.request(error.config);
    }
    throw error;
  }
);
```

### Monitor Rate Limits

```javascript
// Check rate limit headers
console.log('Limit:', response.headers['ratelimit-limit']);
console.log('Remaining:', response.headers['ratelimit-remaining']);
console.log('Reset:', response.headers['ratelimit-reset']);
```

---

## 📞 Support

**Questions?**
- API Documentation: `docs/API_REFERENCE.md`
- OpenAPI Spec: `docs/API_SPECIFICATION.yaml`
- Technical Support: engineering@meatvo.com

---

## 🎯 Next Steps

1. **Read Full Documentation**  
   → `docs/API_REFERENCE.md`

2. **Import OpenAPI Spec**  
   → Use Swagger UI or Postman

3. **Test Endpoints**  
   → Start with auth flow

4. **Build Integration**  
   → Use code examples above

5. **Monitor Performance**  
   → Check rate limits & errors

---

**Happy Coding! 🚀**

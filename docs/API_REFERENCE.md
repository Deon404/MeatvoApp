# Meatvo API Reference

**Version:** 1.0.0  
**Last Updated:** June 2026

---

## Table of Contents

1. [Overview](#overview)
2. [Authentication](#authentication)
3. [Rate Limiting](#rate-limiting)
4. [Error Handling](#error-handling)
5. [API Endpoints](#api-endpoints)
   - [Authentication](#authentication-endpoints)
   - [Users](#users-endpoints)
   - [Addresses](#addresses-endpoints)
   - [Products](#products-endpoints)
   - [Categories](#categories-endpoints)
   - [Cart](#cart-endpoints)
   - [Orders](#orders-endpoints)
   - [Payments](#payments-endpoints)
   - [Delivery](#delivery-endpoints)
   - [Coupons](#coupons-endpoints)
   - [Banners](#banners-endpoints)
   - [Settings](#settings-endpoints)
   - [Admin](#admin-endpoints)
6. [WebSocket Events](#websocket-events)
7. [Code Examples](#code-examples)

---

## Overview

The Meatvo API is a RESTful API for a hyperlocal raw meat delivery platform. It provides comprehensive endpoints for:

- **Customer Operations**: Browse products, manage cart, place orders, track deliveries
- **Delivery Partner Operations**: Accept orders, update delivery status, track earnings
- **Admin Operations**: Manage products, orders, users, and system settings

### Base URLs

- **Development**: `http://localhost:8080/api`
- **Production**: `https://api.meatvo.com/api`

### Technology Stack

- **Runtime**: Node.js (CommonJS)
- **Framework**: Express 5
- **Database**: PostgreSQL
- **Cache**: Redis (cart data)
- **Real-time**: Socket.io
- **Security**: JWT (HS256), OTP via MSG91
- **Payments**: PhonePe Gateway

---

## Authentication

### JWT Token-Based Authentication

Meatvo uses JWT tokens for authentication. The authentication flow:

1. **Request OTP**: Send phone number to `/auth/send-otp`
2. **Verify OTP**: Submit OTP to `/auth/verify-otp` to receive JWT tokens
3. **Use Access Token**: Include access token in `Authorization` header for protected endpoints
4. **Refresh Token**: Use `/auth/refresh-token` when access token expires

### Token Details

| Token Type | Expiration | Storage |
|------------|------------|---------|
| Access Token | 1 hour | Memory / Secure Storage |
| Refresh Token | 30 days | Secure Storage |

### Authorization Header Format

```
Authorization: Bearer <access_token>
```

### User Roles

- **customer**: Regular users who place orders
- **delivery**: Delivery partners
- **admin**: Administrators with full access

### MFA (Multi-Factor Authentication)

Optional MFA using TOTP (Time-based One-Time Password) with authenticator apps like Google Authenticator or Authy.

---

## Rate Limiting

Rate limits are enforced to prevent abuse and ensure fair usage.

| Endpoint Category | Rate Limit | Window |
|-------------------|------------|--------|
| General API | 300 requests | 15 minutes per IP |
| Auth Routes | 60 requests | 15 minutes per IP |
| OTP Requests | 10 requests | 10 minutes per phone |
| OTP Verification | 3 attempts | Before phone block |
| Payment Initiation | 10 requests | 1 minute per user |
| Token Refresh | 10 requests | 1 minute per IP |
| Admin Routes | 100 requests | 15 minutes per IP |
| PhonePe Webhook | 10 requests | 1 minute per IP |

### Rate Limit Headers

```http
RateLimit-Limit: 300
RateLimit-Remaining: 299
RateLimit-Reset: 1686740400
```

### Rate Limit Response

```json
{
  "success": false,
  "ok": false,
  "error": {
    "message": "Too many requests. Try again later.",
    "code": "RATE_LIMITED"
  },
  "message": "Too many requests. Try again later."
}
```

---

## Error Handling

### Standard Error Response Format

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

### HTTP Status Codes

| Status Code | Meaning |
|-------------|---------|
| 200 | Success |
| 201 | Created |
| 400 | Bad Request / Validation Error |
| 401 | Unauthorized |
| 403 | Forbidden |
| 404 | Not Found |
| 429 | Too Many Requests |
| 500 | Internal Server Error |
| 503 | Service Unavailable |

### Error Codes

| Error Code | Description |
|------------|-------------|
| `VALIDATION_ERROR` | Request validation failed |
| `UNAUTHORIZED` | Authentication required or invalid token |
| `FORBIDDEN` | Insufficient permissions |
| `NOT_FOUND` | Resource not found |
| `RATE_LIMITED` | Too many requests |
| `OTP_EXPIRED` | OTP has expired (10 minutes) |
| `OTP_INVALID` | OTP verification failed |
| `PHONE_BLOCKED` | Too many failed OTP attempts |
| `PAYMENT_FAILED` | Payment processing failed |
| `ORDER_NOT_CANCELLABLE` | Order cannot be cancelled |
| `INSUFFICIENT_STOCK` | Product out of stock |
| `INVALID_COUPON` | Coupon code is invalid or expired |
| `SERVER_ERROR` | Internal server error |

### Validation Error Response

```json
{
  "success": false,
  "ok": false,
  "error": {
    "message": "Validation failed",
    "code": "VALIDATION_ERROR"
  },
  "data": {
    "issues": [
      {
        "field": "phone",
        "message": "Phone must be E.164 format (e.g. +919999999999)"
      }
    ]
  },
  "message": "Validation failed"
}
```

---

## API Endpoints

---

## Authentication Endpoints

### POST /auth/send-otp

Send OTP to phone number for authentication.

**Rate Limit:** 10 OTP requests per 10 minutes per phone, 100 requests per 15 minutes per IP

**Authentication:** None (Public)

**Request Body:**

```json
{
  "phone": "+919876543210",
  "resend": false
}
```

**Validation Rules:**

- `phone`: Required, E.164 format (e.g., +919876543210)
- `resend`: Optional boolean

**Success Response (200):**

```json
{
  "success": true,
  "ok": true,
  "data": {
    "phone": "+919876543210",
    "expiresIn": 600
  },
  "message": "OTP sent successfully"
}
```

**Error Responses:**

- `429` - Rate limit exceeded
- `400` - Invalid phone format
- `500` - SMS service unavailable

---

### POST /auth/verify-otp

Verify OTP and receive JWT tokens.

**Rate Limit:** 3 verification attempts per phone before blocking, 100 requests per 15 minutes per IP

**Authentication:** None (Public)

**Request Body:**

```json
{
  "phone": "+919876543210",
  "otp": "1234",
  "mfaToken": "123456"
}
```

**Validation Rules:**

- `phone`: Required, E.164 format
- `otp`: Required, 4-digit numeric string
- `mfaToken`: Optional, 6-digit string (required if MFA enabled)

**Success Response (200):**

```json
{
  "success": true,
  "ok": true,
  "data": {
    "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "user": {
      "id": 1,
      "phone": "+919876543210",
      "name": "John Doe",
      "role": "customer",
      "mfaEnabled": false
    }
  },
  "message": "Login successful"
}
```

**Error Responses:**

- `401` - Invalid OTP (code: `OTP_INVALID`)
- `401` - Expired OTP (code: `OTP_EXPIRED`)
- `401` - Phone blocked (code: `PHONE_BLOCKED`)
- `400` - Validation error

---

### POST /auth/refresh-token

Refresh access token using refresh token.

**Rate Limit:** 10 requests per minute per IP

**Authentication:** None (uses refresh token in body)

**Request Body:**

```json
{
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Success Response (200):**

```json
{
  "success": true,
  "ok": true,
  "data": {
    "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  },
  "message": "Token refreshed"
}
```

---

### GET /auth/me

Get current authenticated user information.

**Authentication:** Required (Bearer Token)

**Success Response (200):**

```json
{
  "success": true,
  "ok": true,
  "data": {
    "id": 1,
    "phone": "+919876543210",
    "name": "John Doe",
    "role": "customer",
    "mfaEnabled": false
  },
  "message": "User retrieved"
}
```

---

### POST /auth/logout

Logout and invalidate refresh token.

**Authentication:** Required (Bearer Token)

**Success Response (200):**

```json
{
  "success": true,
  "ok": true,
  "data": {},
  "message": "Logged out successfully"
}
```

---

### POST /auth/mfa/setup

Initialize MFA setup and get QR code.

**Authentication:** Required (Bearer Token)

**Success Response (200):**

```json
{
  "success": true,
  "ok": true,
  "data": {
    "secret": "JBSWY3DPEHPK3PXP",
    "qrCode": "data:image/png;base64,iVBORw0KGgoAAAANSUhEUg..."
  },
  "message": "MFA setup initiated"
}
```

---

### POST /auth/mfa/enable

Enable MFA after verifying token.

**Authentication:** Required (Bearer Token)

**Request Body:**

```json
{
  "secret": "JBSWY3DPEHPK3PXP",
  "token": "123456"
}
```

**Validation Rules:**

- `secret`: Required, min 32 characters
- `token`: Required, 6-digit numeric string

**Success Response (200):**

```json
{
  "success": true,
  "ok": true,
  "data": {},
  "message": "MFA enabled successfully"
}
```

---

### POST /auth/mfa/disable

Disable MFA after verifying token.

**Authentication:** Required (Bearer Token)

**Request Body:**

```json
{
  "token": "123456"
}
```

**Success Response (200):**

```json
{
  "success": true,
  "ok": true,
  "data": {},
  "message": "MFA disabled successfully"
}
```

---

## Users Endpoints

### GET /users/me

Get current user profile.

**Authentication:** Required (Bearer Token)  
**Roles:** All

**Success Response (200):**

```json
{
  "success": true,
  "ok": true,
  "data": {
    "id": "1",
    "phone": "+919876543210",
    "role": "customer",
    "name": "John Doe"
  },
  "message": "Me"
}
```

---

### POST /users/fcm-token

Update Firebase Cloud Messaging token for push notifications.

**Authentication:** Required (Bearer Token)  
**Roles:** All

**Request Body:**

```json
{
  "fcm_token": "dXQFG7zRTDy8..."
}
```

**Success Response (200):**

```json
{
  "success": true,
  "ok": true,
  "data": {
    "success": true
  },
  "message": "FCM token saved"
}
```

---

## Addresses Endpoints

### GET /addresses

List all addresses for authenticated user.

**Authentication:** Required (Bearer Token)  
**Roles:** Customer, Delivery Partner

**Success Response (200):**

```json
{
  "success": true,
  "ok": true,
  "data": [
    {
      "id": 1,
      "userId": 1,
      "label": "home",
      "addressLine1": "123 Main Street",
      "addressLine2": "Apartment 4B",
      "city": "Dhanbad",
      "state": "Jharkhand",
      "pincode": "826001",
      "landmark": "Near Central Park",
      "lat": 23.7957,
      "lng": 86.4304,
      "isDefault": true,
      "createdAt": "2026-06-01T10:30:00.000Z"
    }
  ],
  "message": "Addresses retrieved"
}
```

---

### POST /addresses

Create a new delivery address.

**Authentication:** Required (Bearer Token)  
**Roles:** Customer, Delivery Partner

**Request Body:**

```json
{
  "label": "home",
  "addressLine1": "123 Main Street",
  "addressLine2": "Apartment 4B",
  "city": "Dhanbad",
  "state": "Jharkhand",
  "pincode": "826001",
  "landmark": "Near Central Park",
  "lat": 23.7957,
  "lng": 86.4304,
  "isDefault": false
}
```

**Validation Rules:**

- `addressLine1`: Required, min 5 chars, max 300 chars
- `addressLine2`: Optional, max 300 chars
- `city`: Optional, max 100 chars, default "Dhanbad"
- `state`: Optional, max 100 chars, default "Jharkhand"
- `pincode`: Optional, max 10 chars
- `landmark`: Optional, max 120 chars
- `label`: Optional, enum: `home`, `work`, `other`, default `home`
- `lat`: Optional, number, default 23.7957
- `lng`: Optional, number, default 86.4304
- `isDefault`: Optional, boolean, default false

**Success Response (201):**

```json
{
  "success": true,
  "ok": true,
  "data": {
    "id": 2,
    "userId": 1,
    "label": "home",
    "addressLine1": "123 Main Street",
    "addressLine2": "Apartment 4B",
    "city": "Dhanbad",
    "state": "Jharkhand",
    "pincode": "826001",
    "landmark": "Near Central Park",
    "lat": 23.7957,
    "lng": 86.4304,
    "isDefault": false,
    "createdAt": "2026-06-13T10:30:00.000Z"
  },
  "message": "Address created"
}
```

---

### PATCH /addresses/:id

Update an existing address.

**Authentication:** Required (Bearer Token)  
**Roles:** Customer, Delivery Partner

**Request Body:** (All fields optional)

```json
{
  "addressLine1": "456 New Street",
  "city": "Ranchi",
  "isDefault": true
}
```

**Success Response (200):**

```json
{
  "success": true,
  "ok": true,
  "data": {
    "id": 2,
    "addressLine1": "456 New Street",
    "city": "Ranchi",
    "isDefault": true
  },
  "message": "Address updated"
}
```

---

### PATCH /addresses/:id/default

Set address as default.

**Authentication:** Required (Bearer Token)  
**Roles:** Customer, Delivery Partner

**Success Response (200):**

```json
{
  "success": true,
  "ok": true,
  "data": {},
  "message": "Default address updated"
}
```

---

### DELETE /addresses/:id

Delete an address.

**Authentication:** Required (Bearer Token)  
**Roles:** Customer, Delivery Partner

**Success Response (200):**

```json
{
  "success": true,
  "ok": true,
  "data": {},
  "message": "Address deleted"
}
```

---

## Products Endpoints

### GET /products

List products with pagination and filtering.

**Authentication:** Optional  
**Roles:** Public

**Query Parameters:**

- `page` (integer, min: 1, default: 1) - Page number
- `limit` (integer, min: 1, max: 100, default: 20) - Items per page
- `categoryId` (integer) - Filter by category ID
- `min_price` (number) - Minimum price filter
- `max_price` (number) - Maximum price filter
- `q` (string) - Search query
- `includeInactive` (boolean) - Include inactive products (admin only)

**Success Response (200):**

```json
{
  "success": true,
  "ok": true,
  "data": {
    "products": [
      {
        "id": 1,
        "categoryId": 3,
        "name": "Chicken Breast",
        "description": "Fresh boneless chicken breast",
        "price": 250,
        "mrp": 300,
        "imageUrl": "https://cdn.meatvo.com/products/chicken-breast.jpg",
        "stock": 50,
        "unit": "kg",
        "active": true,
        "createdAt": "2026-05-01T10:00:00.000Z"
      }
    ],
    "pagination": {
      "page": 1,
      "limit": 20,
      "total": 45,
      "totalPages": 3
    }
  },
  "message": "Products retrieved"
}
```

---

### GET /products/:id

Get product by ID.

**Authentication:** Optional  
**Roles:** Public

**Success Response (200):**

```json
{
  "success": true,
  "ok": true,
  "data": {
    "id": 1,
    "categoryId": 3,
    "name": "Chicken Breast",
    "description": "Fresh boneless chicken breast",
    "price": 250,
    "mrp": 300,
    "imageUrl": "https://cdn.meatvo.com/products/chicken-breast.jpg",
    "stock": 50,
    "unit": "kg",
    "active": true,
    "createdAt": "2026-05-01T10:00:00.000Z"
  },
  "message": "Product retrieved"
}
```

---

### GET /products/featured

Get featured products.

**Authentication:** Optional  
**Roles:** Public

**Success Response (200):**

```json
{
  "success": true,
  "ok": true,
  "data": [
    {
      "id": 1,
      "name": "Chicken Breast",
      "price": 250,
      "imageUrl": "https://cdn.meatvo.com/products/chicken-breast.jpg"
    }
  ],
  "message": "Featured products retrieved"
}
```

---

### GET /products/search

Search products by name or description.

**Authentication:** Optional  
**Roles:** Public

**Query Parameters:**

- `q` (string, min: 2, max: 100, required) - Search query

**Success Response (200):**

```json
{
  "success": true,
  "ok": true,
  "data": [
    {
      "id": 1,
      "name": "Chicken Breast",
      "description": "Fresh boneless chicken breast",
      "price": 250
    }
  ],
  "message": "Search results"
}
```

---

### POST /products

Create a new product (Admin only).

**Authentication:** Required (Bearer Token)  
**Roles:** Admin

**Request Body:**

```json
{
  "category_id": 3,
  "name": "Mutton Leg",
  "description": "Premium quality mutton leg",
  "price": 650,
  "mrp": 750,
  "image_url": "https://cdn.meatvo.com/products/mutton-leg.jpg",
  "stock": 20,
  "unit": "kg",
  "active": true
}
```

**Validation Rules:**

- `name`: Required, min 3 chars, max 100 chars
- `price`: Required, min 0, max 10000
- `category_id`: Optional, positive integer
- `description`: Optional, max 500 chars
- `mrp`: Optional, min 0
- `image_url`: Optional, valid URL
- `stock`: Optional, min 0, default 0
- `unit`: Optional, max 20 chars
- `active`: Optional, boolean, default true

**Success Response (201):**

```json
{
  "success": true,
  "ok": true,
  "data": {
    "id": 25,
    "categoryId": 3,
    "name": "Mutton Leg",
    "description": "Premium quality mutton leg",
    "price": 650,
    "mrp": 750,
    "imageUrl": "https://cdn.meatvo.com/products/mutton-leg.jpg",
    "stock": 20,
    "unit": "kg",
    "active": true,
    "createdAt": "2026-06-13T10:30:00.000Z"
  },
  "message": "Product created"
}
```

---

### PUT /products/:id

Update product (Admin only).

**Authentication:** Required (Bearer Token)  
**Roles:** Admin

**Request Body:** (All fields optional)

```json
{
  "price": 680,
  "stock": 15,
  "active": false
}
```

**Success Response (200):**

```json
{
  "success": true,
  "ok": true,
  "data": {
    "id": 25,
    "price": 680,
    "stock": 15,
    "active": false
  },
  "message": "Product updated"
}
```

---

### DELETE /products/:id

Delete product (Admin only).

**Authentication:** Required (Bearer Token)  
**Roles:** Admin

**Success Response (200):**

```json
{
  "success": true,
  "ok": true,
  "data": {},
  "message": "Product deleted"
}
```

---

## Categories Endpoints

### GET /categories

List all categories.

**Authentication:** Optional  
**Roles:** Public

**Success Response (200):**

```json
{
  "success": true,
  "ok": true,
  "data": [
    {
      "id": 1,
      "name": "Chicken",
      "description": "Fresh chicken products",
      "imageUrl": "https://cdn.meatvo.com/categories/chicken.jpg",
      "active": true,
      "createdAt": "2026-01-01T00:00:00.000Z"
    },
    {
      "id": 2,
      "name": "Mutton",
      "description": "Premium mutton cuts",
      "imageUrl": "https://cdn.meatvo.com/categories/mutton.jpg",
      "active": true,
      "createdAt": "2026-01-01T00:00:00.000Z"
    }
  ],
  "message": "Categories retrieved"
}
```

---

### POST /categories

Create category (Admin only).

**Authentication:** Required (Bearer Token)  
**Roles:** Admin

**Request Body:**

```json
{
  "name": "Fish",
  "description": "Fresh fish and seafood",
  "imageUrl": "https://cdn.meatvo.com/categories/fish.jpg",
  "active": true
}
```

**Validation Rules:**

- `name`: Required, min 2 chars, max 100 chars
- `description`: Optional, max 500 chars
- `imageUrl`: Optional, valid URL
- `active`: Optional, boolean, default true

**Success Response (201):**

```json
{
  "success": true,
  "ok": true,
  "data": {
    "id": 5,
    "name": "Fish",
    "description": "Fresh fish and seafood",
    "imageUrl": "https://cdn.meatvo.com/categories/fish.jpg",
    "active": true,
    "createdAt": "2026-06-13T10:30:00.000Z"
  },
  "message": "Category created"
}
```

---

### PUT /categories/:id

Update category (Admin only).

**Authentication:** Required (Bearer Token)  
**Roles:** Admin

**Success Response (200):**

```json
{
  "success": true,
  "ok": true,
  "data": {
    "id": 5,
    "name": "Seafood",
    "active": true
  },
  "message": "Category updated"
}
```

---

### DELETE /categories/:id

Delete category (Admin only).

**Authentication:** Required (Bearer Token)  
**Roles:** Admin

**Success Response (200):**

```json
{
  "success": true,
  "ok": true,
  "data": {},
  "message": "Category deleted"
}
```

---

## Cart Endpoints

**Note:** Cart data is stored in Redis and tied to the authenticated user.

### GET /cart

Get current user's cart.

**Authentication:** Required (Bearer Token)  
**Roles:** Customer

**Success Response (200):**

```json
{
  "success": true,
  "ok": true,
  "data": {
    "items": [
      {
        "productId": 1,
        "quantity": 2,
        "product": {
          "id": 1,
          "name": "Chicken Breast",
          "price": 250,
          "imageUrl": "https://cdn.meatvo.com/products/chicken-breast.jpg",
          "unit": "kg"
        }
      }
    ],
    "total": 500,
    "itemCount": 2
  },
  "message": "Cart retrieved"
}
```

---

### POST /cart

Add item to cart.

**Authentication:** Required (Bearer Token)  
**Roles:** Customer

**Request Body:**

```json
{
  "productId": 1,
  "quantity": 2
}
```

**Validation Rules:**

- `productId`: Required, positive integer
- `quantity`: Required, integer, min 1, max 10

**Success Response (200):**

```json
{
  "success": true,
  "ok": true,
  "data": {
    "items": [
      {
        "productId": 1,
        "quantity": 2
      }
    ],
    "total": 500,
    "itemCount": 2
  },
  "message": "Item added to cart"
}
```

---

### PUT /cart/:itemId

Update cart item quantity.

**Authentication:** Required (Bearer Token)  
**Roles:** Customer

**Request Body:**

```json
{
  "quantity": 3
}
```

**Validation Rules:**

- `quantity`: Required, integer, min 0, max 10 (0 removes item)

**Success Response (200):**

```json
{
  "success": true,
  "ok": true,
  "data": {
    "items": [
      {
        "productId": 1,
        "quantity": 3
      }
    ],
    "total": 750,
    "itemCount": 3
  },
  "message": "Cart updated"
}
```

---

### DELETE /cart/:itemId

Remove item from cart.

**Authentication:** Required (Bearer Token)  
**Roles:** Customer

**Success Response (200):**

```json
{
  "success": true,
  "ok": true,
  "data": {},
  "message": "Item removed from cart"
}
```

---

### DELETE /cart

Clear entire cart.

**Authentication:** Required (Bearer Token)  
**Roles:** Customer

**Success Response (200):**

```json
{
  "success": true,
  "ok": true,
  "data": {},
  "message": "Cart cleared"
}
```

---

### GET /cart/count

Get cart item count.

**Authentication:** Required (Bearer Token)  
**Roles:** Customer

**Success Response (200):**

```json
{
  "success": true,
  "ok": true,
  "data": {
    "count": 5
  },
  "message": "Cart count retrieved"
}
```

---

## Orders Endpoints

### POST /orders

Create a new order from cart.

**Authentication:** Required (Bearer Token)  
**Roles:** Customer

**Request Body:**

```json
{
  "deliveryAddress": "123 Main Street, Dhanbad, Jharkhand - 826001",
  "paymentMethod": "COD",
  "lat": 23.7957,
  "lng": 86.4304,
  "addressId": 1,
  "deliverySlotId": 5,
  "deliverySlot": {
    "name": "Morning",
    "date": "2026-06-14",
    "time": "8:00 AM - 11:00 AM"
  },
  "couponCode": "FIRST50"
}
```

**Validation Rules:**

- `deliveryAddress`: Required, min 10 chars, max 500 chars
- `paymentMethod`: Required, enum: `COD`, `ONLINE`
- `lat`: Optional, number
- `lng`: Optional, number
- `addressId`: Optional, positive integer
- `deliverySlotId`: Optional, positive integer
- `deliverySlot`: Optional, object with `name`, `date`, `time`
- `couponCode`: Optional, min 2 chars, max 40 chars

**Success Response (201):**

```json
{
  "success": true,
  "ok": true,
  "data": {
    "id": 1001,
    "userId": 1,
    "orderNumber": "MVO1001",
    "status": "PLACED",
    "paymentMethod": "COD",
    "paymentStatus": "PENDING",
    "total": 500,
    "discount": 50,
    "finalTotal": 450,
    "deliveryAddress": "123 Main Street, Dhanbad, Jharkhand - 826001",
    "deliverySlot": {
      "name": "Morning",
      "date": "2026-06-14",
      "time": "8:00 AM - 11:00 AM"
    },
    "items": [
      {
        "productId": 1,
        "name": "Chicken Breast",
        "quantity": 2,
        "price": 250
      }
    ],
    "createdAt": "2026-06-13T10:30:00.000Z"
  },
  "message": "Order placed successfully"
}
```

**Note:** Cart is automatically cleared after successful order placement.

---

### GET /orders

List orders for authenticated user.

**Authentication:** Required (Bearer Token)  
**Roles:** Customer, Delivery Partner, Admin

**Success Response (200):**

```json
{
  "success": true,
  "ok": true,
  "data": [
    {
      "id": 1001,
      "orderNumber": "MVO1001",
      "status": "DELIVERED",
      "paymentMethod": "COD",
      "total": 450,
      "createdAt": "2026-06-13T10:30:00.000Z"
    }
  ],
  "message": "Orders retrieved"
}
```

---

### GET /orders/:id

Get order details by ID.

**Authentication:** Required (Bearer Token)  
**Roles:** Customer (own orders), Delivery Partner (assigned orders), Admin

**Success Response (200):**

```json
{
  "success": true,
  "ok": true,
  "data": {
    "id": 1001,
    "userId": 1,
    "orderNumber": "MVO1001",
    "status": "OUT_FOR_DELIVERY",
    "paymentMethod": "COD",
    "paymentStatus": "PENDING",
    "total": 450,
    "deliveryAddress": "123 Main Street, Dhanbad",
    "deliveryPartnerId": 5,
    "items": [
      {
        "productId": 1,
        "name": "Chicken Breast",
        "quantity": 2,
        "price": 250
      }
    ],
    "createdAt": "2026-06-13T10:30:00.000Z",
    "updatedAt": "2026-06-13T11:00:00.000Z"
  },
  "message": "Order retrieved"
}
```

---

### PUT /orders/:id/cancel

Cancel an order.

**Authentication:** Required (Bearer Token)  
**Roles:** Customer (own orders)

**Success Response (200):**

```json
{
  "success": true,
  "ok": true,
  "data": {},
  "message": "Order cancelled successfully"
}
```

**Error Response (400):**

```json
{
  "success": false,
  "ok": false,
  "error": {
    "message": "Order cannot be cancelled at this stage",
    "code": "ORDER_NOT_CANCELLABLE"
  },
  "message": "Order cannot be cancelled at this stage"
}
```

**Note:** Orders can only be cancelled if status is `PLACED` or `CONFIRMED`.

---

### POST /orders/apply-coupon

Validate and apply coupon code.

**Authentication:** Required (Bearer Token)  
**Roles:** Customer

**Request Body:**

```json
{
  "code": "FIRST50",
  "orderTotal": 500
}
```

**Validation Rules:**

- `code`: Required, min 2 chars, max 40 chars
- `orderTotal`: Required, min 0

**Success Response (200):**

```json
{
  "success": true,
  "ok": true,
  "data": {
    "discount": 50,
    "finalTotal": 450,
    "coupon": {
      "code": "FIRST50",
      "discountType": "FIXED",
      "discountValue": 50
    }
  },
  "message": "Coupon applied"
}
```

**Error Response (400):**

```json
{
  "success": false,
  "ok": false,
  "error": {
    "message": "Invalid or expired coupon",
    "code": "INVALID_COUPON"
  },
  "message": "Invalid or expired coupon"
}
```

---

### PUT /orders/:id/status

Update order status (Admin only).

**Authentication:** Required (Bearer Token)  
**Roles:** Admin

**Request Body:**

```json
{
  "status": "CONFIRMED"
}
```

**Validation Rules:**

- `status`: Required, enum: `PLACED`, `CONFIRMED`, `PACKED`, `OUT_FOR_DELIVERY`, `DELIVERED`, `CANCELLED`

**Success Response (200):**

```json
{
  "success": true,
  "ok": true,
  "data": {},
  "message": "Order status updated"
}
```

---

## Payments Endpoints

### POST /payments/initiate

Initiate PhonePe payment for an order.

**Rate Limit:** 10 requests per minute per user

**Authentication:** Required (Bearer Token)  
**Roles:** Customer

**Request Body:**

```json
{
  "orderId": 1001
}
```

**Validation Rules:**

- `orderId`: Required, positive integer

**Success Response (200):**

```json
{
  "success": true,
  "ok": true,
  "data": {
    "paymentUrl": "https://mercury.phonepe.com/transact/pg?token=...",
    "merchantTransactionId": "MVO1001_1686740400"
  },
  "message": "Payment initiated"
}
```

---

### POST /payments/verify

Verify payment status.

**Rate Limit:** 10 requests per minute per user

**Authentication:** Required (Bearer Token)  
**Roles:** Customer

**Request Body:**

```json
{
  "merchantTransactionId": "MVO1001_1686740400"
}
```

**Validation Rules:**

- Either `transactionId` or `merchantTransactionId` is required

**Success Response (200):**

```json
{
  "success": true,
  "ok": true,
  "data": {
    "status": "SUCCESS",
    "amount": 450,
    "transactionId": "T1234567890"
  },
  "message": "Payment verified"
}
```

---

### GET /payments/:orderId/status

Get payment status for an order.

**Authentication:** Required (Bearer Token)  
**Roles:** Customer

**Success Response (200):**

```json
{
  "success": true,
  "ok": true,
  "data": {
    "status": "SUCCESS",
    "paymentMethod": "ONLINE"
  },
  "message": "Payment status retrieved"
}
```

---

### POST /payments/webhook

PhonePe webhook endpoint (called by PhonePe gateway).

**Rate Limit:** 10 requests per minute per IP

**Authentication:** None (signature verified)

**Note:** This endpoint is called automatically by PhonePe when payment status changes.

---

## Delivery Endpoints

### GET /delivery/slots

Get available delivery time slots.

**Authentication:** None (Public)

**Success Response (200):**

```json
{
  "success": true,
  "ok": true,
  "data": [
    {
      "id": 1,
      "name": "Morning",
      "date": "2026-06-14",
      "startTime": "08:00",
      "endTime": "11:00",
      "capacity": 20,
      "booked": 5,
      "available": true
    },
    {
      "id": 2,
      "name": "Afternoon",
      "date": "2026-06-14",
      "startTime": "12:00",
      "endTime": "15:00",
      "capacity": 20,
      "booked": 18,
      "available": true
    }
  ],
  "message": "Delivery slots retrieved"
}
```

---

### GET /delivery/me

Get delivery partner profile and stats.

**Authentication:** Required (Bearer Token)  
**Roles:** Delivery Partner

**Success Response (200):**

```json
{
  "success": true,
  "ok": true,
  "data": {
    "id": 5,
    "userId": 10,
    "name": "Rahul Kumar",
    "phone": "+919876543210",
    "vehicle": "Motorcycle",
    "vehicleNumber": "JH05AB1234",
    "isOnline": true,
    "currentLat": 23.7957,
    "currentLng": 86.4304,
    "totalDeliveries": 150,
    "totalEarnings": 15000,
    "rating": 4.5
  },
  "message": "Profile retrieved"
}
```

---

### GET /delivery/orders

List orders assigned to delivery partner.

**Authentication:** Required (Bearer Token)  
**Roles:** Delivery Partner

**Success Response (200):**

```json
{
  "success": true,
  "ok": true,
  "data": [
    {
      "id": 1001,
      "orderNumber": "MVO1001",
      "status": "OUT_FOR_DELIVERY",
      "deliveryAddress": "123 Main Street, Dhanbad",
      "customerPhone": "+919876543210",
      "total": 450
    }
  ],
  "message": "Orders retrieved"
}
```

---

### GET /delivery/orders/available

List unassigned orders available for claiming.

**Authentication:** Required (Bearer Token)  
**Roles:** Delivery Partner

**Success Response (200):**

```json
{
  "success": true,
  "ok": true,
  "data": [
    {
      "id": 1002,
      "orderNumber": "MVO1002",
      "status": "PACKED",
      "deliveryAddress": "456 Park Avenue, Dhanbad",
      "distance": 2.5,
      "deliverySlot": "Morning (8:00 AM - 11:00 AM)"
    }
  ],
  "message": "Available orders retrieved"
}
```

---

### POST /delivery/orders/:id/accept

Accept/claim an available order.

**Authentication:** Required (Bearer Token)  
**Roles:** Delivery Partner

**Success Response (200):**

```json
{
  "success": true,
  "ok": true,
  "data": {},
  "message": "Order accepted"
}
```

---

### POST /delivery/orders/:id/reject

Reject an assigned order.

**Authentication:** Required (Bearer Token)  
**Roles:** Delivery Partner

**Request Body:**

```json
{
  "reason": "Vehicle breakdown"
}
```

**Success Response (200):**

```json
{
  "success": true,
  "ok": true,
  "data": {},
  "message": "Order rejected"
}
```

---

### PUT /delivery/orders/:id/status

Update delivery status of an order.

**Authentication:** Required (Bearer Token)  
**Roles:** Delivery Partner

**Request Body:**

```json
{
  "status": "OUT_FOR_DELIVERY"
}
```

**Validation Rules:**

- `status`: Required, enum: `OUT_FOR_DELIVERY`, `PICKED_UP`, `ON_THE_WAY`, `DELIVERED`

**Success Response (200):**

```json
{
  "success": true,
  "ok": true,
  "data": {},
  "message": "Status updated"
}
```

---

### PUT /delivery/location

Update delivery partner's GPS location.

**Authentication:** Required (Bearer Token)  
**Roles:** Delivery Partner

**Request Body:**

```json
{
  "lat": 23.7957,
  "lng": 86.4304,
  "orderId": 1001
}
```

**Validation Rules:**

- `lat`: Required, number
- `lng`: Required, number
- `orderId`: Optional, positive integer

**Success Response (200):**

```json
{
  "success": true,
  "ok": true,
  "data": {},
  "message": "Location updated"
}
```

**Note:** Location updates trigger real-time Socket.io events to customers tracking their orders.

---

### POST /delivery/online

Toggle delivery partner's online/offline status.

**Authentication:** Required (Bearer Token)  
**Roles:** Delivery Partner

**Request Body:**

```json
{
  "is_online": true,
  "lat": 23.7957,
  "lng": 86.4304
}
```

**Success Response (200):**

```json
{
  "success": true,
  "ok": true,
  "data": {
    "is_online": true
  },
  "message": "Status updated"
}
```

---

### GET /delivery/earnings

Get delivery partner earnings.

**Authentication:** Required (Bearer Token)  
**Roles:** Delivery Partner

**Query Parameters:**

- `period` (string) - enum: `today`, `week`, `month`, default: `today`

**Success Response (200):**

```json
{
  "success": true,
  "ok": true,
  "data": {
    "totalEarnings": 1500,
    "deliveriesCount": 15,
    "period": "today"
  },
  "message": "Earnings retrieved"
}
```

---

### PATCH /delivery/profile

Update delivery partner profile.

**Authentication:** Required (Bearer Token)  
**Roles:** Delivery Partner

**Request Body:**

```json
{
  "name": "Rahul Kumar Singh",
  "vehicle": "Bike",
  "vehicleNumber": "JH05CD5678",
  "licenceNumber": "DL1234567890",
  "bankDetails": "Account: 1234567890, IFSC: SBIN0001234"
}
```

**Success Response (200):**

```json
{
  "success": true,
  "ok": true,
  "data": {},
  "message": "Profile updated"
}
```

---

## Coupons Endpoints

### GET /coupons

List all active coupons.

**Authentication:** Optional  
**Roles:** Public

**Success Response (200):**

```json
{
  "success": true,
  "ok": true,
  "data": [
    {
      "id": 1,
      "code": "FIRST50",
      "discountType": "FIXED",
      "discountValue": 50,
      "minOrderAmount": 300,
      "maxDiscount": null,
      "validFrom": "2026-06-01T00:00:00.000Z",
      "validUntil": "2026-12-31T23:59:59.000Z",
      "usageLimit": 100,
      "usedCount": 45,
      "active": true
    }
  ],
  "message": "Coupons retrieved"
}
```

---

### POST /coupons

Create a new coupon (Admin only).

**Authentication:** Required (Bearer Token)  
**Roles:** Admin

**Request Body:**

```json
{
  "code": "SUMMER2026",
  "discountType": "PERCENTAGE",
  "discountValue": 20,
  "minOrderAmount": 500,
  "maxDiscount": 100,
  "validFrom": "2026-06-01T00:00:00.000Z",
  "validUntil": "2026-08-31T23:59:59.000Z",
  "usageLimit": 500,
  "active": true
}
```

**Validation Rules:**

- `code`: Required, min 2 chars, max 40 chars
- `discountType`: Required, enum: `PERCENTAGE`, `FIXED`
- `discountValue`: Required, min 0
- `minOrderAmount`: Optional, min 0
- `maxDiscount`: Optional, min 0 (used for PERCENTAGE type)
- `validFrom`: Optional, ISO date-time
- `validUntil`: Optional, ISO date-time
- `usageLimit`: Optional, min 1
- `active`: Optional, boolean, default true

**Success Response (201):**

```json
{
  "success": true,
  "ok": true,
  "data": {
    "id": 5,
    "code": "SUMMER2026",
    "discountType": "PERCENTAGE",
    "discountValue": 20,
    "minOrderAmount": 500,
    "maxDiscount": 100,
    "validFrom": "2026-06-01T00:00:00.000Z",
    "validUntil": "2026-08-31T23:59:59.000Z",
    "usageLimit": 500,
    "usedCount": 0,
    "active": true
  },
  "message": "Coupon created"
}
```

---

### POST /coupons/validate

Validate a coupon code.

**Authentication:** Optional  
**Roles:** Public

**Request Body:**

```json
{
  "code": "FIRST50"
}
```

**Success Response (200):**

```json
{
  "success": true,
  "ok": true,
  "data": {
    "id": 1,
    "code": "FIRST50",
    "discountType": "FIXED",
    "discountValue": 50,
    "minOrderAmount": 300,
    "valid": true
  },
  "message": "Coupon is valid"
}
```

---

## Banners Endpoints

### GET /banners

List all active promotional banners.

**Authentication:** Optional  
**Roles:** Public

**Success Response (200):**

```json
{
  "success": true,
  "ok": true,
  "data": [
    {
      "id": 1,
      "title": "Summer Sale",
      "imageUrl": "https://cdn.meatvo.com/banners/summer-sale.jpg",
      "linkUrl": "/products?category=chicken",
      "position": 1,
      "active": true,
      "createdAt": "2026-06-01T00:00:00.000Z"
    }
  ],
  "message": "Banners retrieved"
}
```

---

### POST /banners

Create a new banner (Admin only).

**Authentication:** Required (Bearer Token)  
**Roles:** Admin

**Request Body:**

```json
{
  "title": "Monsoon Special",
  "imageUrl": "https://cdn.meatvo.com/banners/monsoon-special.jpg",
  "linkUrl": "/products?featured=true",
  "position": 2,
  "active": true
}
```

**Validation Rules:**

- `title`: Required, min 2 chars, max 100 chars
- `imageUrl`: Required, valid URL
- `linkUrl`: Optional, valid URL
- `position`: Optional, min 0, default 0
- `active`: Optional, boolean, default true

**Success Response (201):**

```json
{
  "success": true,
  "ok": true,
  "data": {
    "id": 5,
    "title": "Monsoon Special",
    "imageUrl": "https://cdn.meatvo.com/banners/monsoon-special.jpg",
    "linkUrl": "/products?featured=true",
    "position": 2,
    "active": true,
    "createdAt": "2026-06-13T10:30:00.000Z"
  },
  "message": "Banner created"
}
```

---

### DELETE /banners/:id

Delete a banner (Admin only).

**Authentication:** Required (Bearer Token)  
**Roles:** Admin

**Success Response (200):**

```json
{
  "success": true,
  "ok": true,
  "data": {},
  "message": "Banner deleted"
}
```

---

## Settings Endpoints

### GET /settings/theme

Get app theme configuration.

**Authentication:** Optional  
**Roles:** Public

**Success Response (200):**

```json
{
  "success": true,
  "ok": true,
  "data": {
    "primaryColor": "#C8102E",
    "secondaryColor": "#E8293F",
    "logoUrl": "https://cdn.meatvo.com/logo.png"
  },
  "message": "Theme settings retrieved"
}
```

---

### GET /store/status

Get store open/closed status.

**Authentication:** Optional  
**Roles:** Public

**Success Response (200):**

```json
{
  "success": true,
  "ok": true,
  "data": {
    "isOpen": true,
    "message": "Store is open"
  },
  "message": "Store status retrieved"
}
```

---

### POST /store/check-delivery

Check if delivery is available to a location.

**Authentication:** Optional  
**Roles:** Public

**Request Body:**

```json
{
  "lat": 23.7957,
  "lng": 86.4304
}
```

**Success Response (200):**

```json
{
  "success": true,
  "ok": true,
  "data": {
    "available": true,
    "message": "Delivery available"
  },
  "message": "Delivery availability checked"
}
```

---

## Admin Endpoints

### GET /admin/dashboard

Get dashboard statistics.

**Rate Limit:** 100 requests per 15 minutes per IP

**Authentication:** Required (Bearer Token)  
**Roles:** Admin

**Success Response (200):**

```json
{
  "success": true,
  "ok": true,
  "data": {
    "totalOrders": 1500,
    "totalRevenue": 450000,
    "activeUsers": 350,
    "activeRiders": 12,
    "pendingOrders": 15
  },
  "message": "Dashboard data retrieved"
}
```

---

### GET /admin/customers

List all customers.

**Authentication:** Required (Bearer Token)  
**Roles:** Admin

**Success Response (200):**

```json
{
  "success": true,
  "ok": true,
  "data": [
    {
      "id": 1,
      "phone": "+919876543210",
      "name": "John Doe",
      "role": "customer",
      "active": true,
      "totalOrders": 25,
      "totalSpent": 12500,
      "createdAt": "2026-01-15T10:00:00.000Z"
    }
  ],
  "message": "Customers retrieved"
}
```

---

### GET /admin/users/:id

Get detailed user information.

**Authentication:** Required (Bearer Token)  
**Roles:** Admin

**Success Response (200):**

```json
{
  "success": true,
  "ok": true,
  "data": {
    "id": 1,
    "phone": "+919876543210",
    "name": "John Doe",
    "role": "customer",
    "active": true,
    "mfaEnabled": false,
    "totalOrders": 25,
    "totalSpent": 12500,
    "addresses": [],
    "createdAt": "2026-01-15T10:00:00.000Z"
  },
  "message": "User detail retrieved"
}
```

---

### PATCH /admin/users/:id/status

Enable or disable a user account.

**Authentication:** Required (Bearer Token)  
**Roles:** Admin

**Request Body:**

```json
{
  "active": false
}
```

**Success Response (200):**

```json
{
  "success": true,
  "ok": true,
  "data": {},
  "message": "User status updated"
}
```

---

### PATCH /admin/users/:id/role

Change a user's role.

**Authentication:** Required (Bearer Token)  
**Roles:** Admin

**Request Body:**

```json
{
  "role": "delivery"
}
```

**Validation Rules:**

- `role`: Required, enum: `customer`, `delivery`, `admin`

**Success Response (200):**

```json
{
  "success": true,
  "ok": true,
  "data": {},
  "message": "User role updated"
}
```

---

### GET /admin/delivery-partners

List all delivery partners.

**Authentication:** Required (Bearer Token)  
**Roles:** Admin

**Success Response (200):**

```json
{
  "success": true,
  "ok": true,
  "data": [
    {
      "id": 5,
      "userId": 10,
      "name": "Rahul Kumar",
      "phone": "+919876543210",
      "vehicle": "Motorcycle",
      "vehicleNumber": "JH05AB1234",
      "isOnline": true,
      "totalDeliveries": 150,
      "totalEarnings": 15000,
      "rating": 4.5
    }
  ],
  "message": "Delivery partners retrieved"
}
```

---

### GET /admin/orders

List all orders with filtering and pagination.

**Authentication:** Required (Bearer Token)  
**Roles:** Admin

**Query Parameters:**

- `page` (integer, min: 1, default: 1)
- `limit` (integer, min: 1, max: 100, default: 20)
- `status` (string) - Filter by status
- `user` (string) - Filter by user ID

**Success Response (200):**

```json
{
  "success": true,
  "ok": true,
  "data": {
    "orders": [],
    "pagination": {
      "page": 1,
      "limit": 20,
      "total": 1500,
      "totalPages": 75
    }
  },
  "message": "Orders retrieved"
}
```

---

### PATCH /admin/products/:id/stock

Update product stock quantity.

**Authentication:** Required (Bearer Token)  
**Roles:** Admin

**Request Body:**

```json
{
  "stock": 50
}
```

**Success Response (200):**

```json
{
  "success": true,
  "ok": true,
  "data": {},
  "message": "Stock updated"
}
```

---

### PATCH /admin/store/toggle

Open or close the store.

**Authentication:** Required (Bearer Token)  
**Roles:** Admin

**Request Body:**

```json
{
  "isOpen": false
}
```

**Success Response (200):**

```json
{
  "success": true,
  "ok": true,
  "data": {
    "isOpen": false
  },
  "message": "Store status updated"
}
```

---

### POST /admin/upload/image

Upload an image for products, banners, etc.

**Authentication:** Required (Bearer Token)  
**Roles:** Admin

**Request Body (multipart/form-data):**

- `image` (file) - Image file (JPG, PNG, WebP, max 5MB)

**Success Response (201):**

```json
{
  "success": true,
  "ok": true,
  "data": {
    "url": "https://cdn.meatvo.com/uploads/product-12345.jpg"
  },
  "message": "Image uploaded"
}
```

---

## WebSocket Events

Meatvo uses Socket.io for real-time updates. Connect to the WebSocket server at the same base URL.

### Connection

```javascript
import io from 'socket.io-client';

const socket = io('http://localhost:8080', {
  auth: {
    token: 'your_jwt_access_token'
  }
});

socket.on('connect', () => {
  console.log('Connected to WebSocket');
});
```

### Events

#### Customer Events

**`order:status` - Order status update**

Emitted when order status changes.

```json
{
  "orderId": 1001,
  "status": "OUT_FOR_DELIVERY",
  "message": "Your order is out for delivery"
}
```

**`rider:location` - Rider location update**

Emitted when delivery partner's location updates (for active orders).

```json
{
  "orderId": 1001,
  "riderId": 5,
  "lat": 23.7957,
  "lng": 86.4304,
  "timestamp": "2026-06-13T11:00:00.000Z"
}
```

#### Delivery Partner Events

**`order:new` - New order available**

Emitted when a new order becomes available for claiming.

```json
{
  "orderId": 1002,
  "orderNumber": "MVO1002",
  "deliveryAddress": "456 Park Avenue",
  "distance": 2.5
}
```

**`order:assigned` - Order assigned**

Emitted when an order is assigned to the delivery partner.

```json
{
  "orderId": 1001,
  "orderNumber": "MVO1001",
  "customerName": "John Doe",
  "customerPhone": "+919876543210"
}
```

#### Admin Events

**`order:placed` - New order placed**

Emitted when a customer places a new order.

```json
{
  "orderId": 1003,
  "orderNumber": "MVO1003",
  "userId": 1,
  "total": 450,
  "paymentMethod": "COD"
}
```

---

## Code Examples

### JavaScript/Node.js

#### Authentication Flow

```javascript
const axios = require('axios');

const API_BASE = 'http://localhost:8080/api';

// Step 1: Send OTP
async function sendOTP(phone) {
  const response = await axios.post(`${API_BASE}/auth/send-otp`, {
    phone: '+919876543210'
  });
  console.log(response.data);
}

// Step 2: Verify OTP
async function verifyOTP(phone, otp) {
  const response = await axios.post(`${API_BASE}/auth/verify-otp`, {
    phone,
    otp
  });
  
  const { accessToken, refreshToken } = response.data.data;
  
  // Store tokens securely
  localStorage.setItem('accessToken', accessToken);
  localStorage.setItem('refreshToken', refreshToken);
  
  return response.data.data;
}

// Step 3: Make authenticated request
async function getProfile() {
  const accessToken = localStorage.getItem('accessToken');
  
  const response = await axios.get(`${API_BASE}/auth/me`, {
    headers: {
      'Authorization': `Bearer ${accessToken}`
    }
  });
  
  return response.data.data;
}

// Step 4: Refresh token
async function refreshAccessToken() {
  const refreshToken = localStorage.getItem('refreshToken');
  
  const response = await axios.post(`${API_BASE}/auth/refresh-token`, {
    refreshToken
  });
  
  const { accessToken } = response.data.data;
  localStorage.setItem('accessToken', accessToken);
  
  return accessToken;
}
```

#### Cart Operations

```javascript
// Add to cart
async function addToCart(productId, quantity) {
  const accessToken = localStorage.getItem('accessToken');
  
  const response = await axios.post(
    `${API_BASE}/cart`,
    { productId, quantity },
    {
      headers: { 'Authorization': `Bearer ${accessToken}` }
    }
  );
  
  return response.data.data;
}

// Get cart
async function getCart() {
  const accessToken = localStorage.getItem('accessToken');
  
  const response = await axios.get(`${API_BASE}/cart`, {
    headers: { 'Authorization': `Bearer ${accessToken}` }
  });
  
  return response.data.data;
}

// Update cart item
async function updateCartItem(productId, quantity) {
  const accessToken = localStorage.getItem('accessToken');
  
  const response = await axios.put(
    `${API_BASE}/cart/${productId}`,
    { quantity },
    {
      headers: { 'Authorization': `Bearer ${accessToken}` }
    }
  );
  
  return response.data.data;
}
```

#### Place Order

```javascript
async function placeOrder(orderData) {
  const accessToken = localStorage.getItem('accessToken');
  
  const response = await axios.post(
    `${API_BASE}/orders`,
    {
      deliveryAddress: orderData.address,
      paymentMethod: 'COD',
      addressId: orderData.addressId,
      deliverySlotId: orderData.slotId,
      couponCode: orderData.couponCode
    },
    {
      headers: { 'Authorization': `Bearer ${accessToken}` }
    }
  );
  
  return response.data.data;
}
```

---

### Flutter/Dart

#### Authentication Flow

```dart
import 'package:dio/dio.dart';

class ApiService {
  final Dio dio = Dio(
    BaseOptions(
      baseUrl: 'http://localhost:8080/api',
      connectTimeout: Duration(seconds: 30),
      receiveTimeout: Duration(seconds: 30),
    ),
  );

  // Send OTP
  Future<void> sendOTP(String phone) async {
    final response = await dio.post('/auth/send-otp', data: {
      'phone': phone,
    });
    
    print(response.data);
  }

  // Verify OTP
  Future<Map<String, dynamic>> verifyOTP(String phone, String otp) async {
    final response = await dio.post('/auth/verify-otp', data: {
      'phone': phone,
      'otp': otp,
    });
    
    final accessToken = response.data['data']['accessToken'];
    final refreshToken = response.data['data']['refreshToken'];
    
    // Store tokens securely
    await storage.write(key: 'accessToken', value: accessToken);
    await storage.write(key: 'refreshToken', value: refreshToken);
    
    return response.data['data'];
  }

  // Get profile
  Future<Map<String, dynamic>> getProfile() async {
    final accessToken = await storage.read(key: 'accessToken');
    
    final response = await dio.get(
      '/auth/me',
      options: Options(
        headers: {'Authorization': 'Bearer $accessToken'},
      ),
    );
    
    return response.data['data'];
  }
}
```

---

### Python

#### Authentication Flow

```python
import requests

API_BASE = 'http://localhost:8080/api'

class MeatvoAPI:
    def __init__(self):
        self.access_token = None
        self.refresh_token = None
    
    def send_otp(self, phone):
        response = requests.post(
            f'{API_BASE}/auth/send-otp',
            json={'phone': phone}
        )
        return response.json()
    
    def verify_otp(self, phone, otp):
        response = requests.post(
            f'{API_BASE}/auth/verify-otp',
            json={'phone': phone, 'otp': otp}
        )
        data = response.json()['data']
        
        self.access_token = data['accessToken']
        self.refresh_token = data['refreshToken']
        
        return data
    
    def get_profile(self):
        headers = {'Authorization': f'Bearer {self.access_token}'}
        response = requests.get(
            f'{API_BASE}/auth/me',
            headers=headers
        )
        return response.json()['data']
    
    def get_products(self, page=1, limit=20):
        response = requests.get(
            f'{API_BASE}/products',
            params={'page': page, 'limit': limit}
        )
        return response.json()['data']
    
    def place_order(self, order_data):
        headers = {'Authorization': f'Bearer {self.access_token}'}
        response = requests.post(
            f'{API_BASE}/orders',
            json=order_data,
            headers=headers
        )
        return response.json()['data']
```

---

## Additional Notes

### Security Best Practices

1. **Always use HTTPS in production**
2. **Store JWT tokens securely** (e.g., HttpOnly cookies, secure storage)
3. **Never log or expose tokens** in client-side code
4. **Implement token refresh** before access token expiration
5. **Validate all input** on both client and server
6. **Use MFA** for admin accounts

### Performance Tips

1. **Implement caching** for product catalogs
2. **Use pagination** for large lists
3. **Optimize image sizes** before upload
4. **Batch API requests** when possible
5. **Use WebSocket** for real-time updates instead of polling

### Error Handling

Always handle errors gracefully:

```javascript
try {
  const response = await axios.get('/api/products');
  // Handle success
} catch (error) {
  if (error.response) {
    // Server responded with error
    const { code, message } = error.response.data.error;
    
    switch (code) {
      case 'UNAUTHORIZED':
        // Redirect to login
        break;
      case 'RATE_LIMITED':
        // Show rate limit message
        break;
      default:
        // Show generic error
    }
  } else if (error.request) {
    // Network error
    console.error('Network error:', error.request);
  } else {
    // Other error
    console.error('Error:', error.message);
  }
}
```

---

**End of API Reference**

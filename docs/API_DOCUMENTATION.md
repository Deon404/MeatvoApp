# Meatvo — API Documentation

**Version:** 1.0  
**Date:** June 12, 2026  
**Base URL:** `https://api.meatvo.com/api/v1`  
**Protocol:** HTTPS only

---

## 1. API Overview

### 1.1 Architecture
- **Style:** RESTful API
- **Format:** JSON (request & response)
- **Authentication:** JWT Bearer tokens
- **Versioning:** URL path (`/api/v1`)
- **Rate Limiting:** 100 requests/minute per user

### 1.2 HTTP Status Codes

| Code | Meaning | Usage |
|------|---------|-------|
| 200 | OK | Successful GET/PUT/PATCH request |
| 201 | Created | Successful POST request creating resource |
| 204 | No Content | Successful DELETE request |
| 400 | Bad Request | Invalid request parameters/body |
| 401 | Unauthorized | Missing or invalid authentication token |
| 403 | Forbidden | Insufficient permissions for resource |
| 404 | Not Found | Resource not found |
| 409 | Conflict | Resource conflict (duplicate entry) |
| 422 | Unprocessable Entity | Validation failed |
| 429 | Too Many Requests | Rate limit exceeded |
| 500 | Internal Server Error | Server-side error |
| 503 | Service Unavailable | Server maintenance or overload |

### 1.3 Standard Response Format

**Success Response:**
```json
{
  "success": true,
  "data": {
    // Response payload
  },
  "message": "Operation successful",
  "timestamp": "2026-06-12T14:30:00Z"
}
```

**Error Response:**
```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Phone number is required",
    "details": [
      {
        "field": "phone",
        "constraint": "isNotEmpty",
        "message": "phone should not be empty"
      }
    ]
  },
  "timestamp": "2026-06-12T14:30:00Z",
  "requestId": "req_7f3b9c8a"
}
```

---

## 2. Authentication Module

### 2.1 Send OTP

**Endpoint:** `POST /auth/send-otp`  
**Access:** Public  
**Description:** Initiates phone authentication by sending a 6-digit OTP via SMS.

**Request Body:**
```json
{
  "phone": "+919876543210"
}
```

**Validation Rules:**
- `phone`: Required, valid E.164 format (e.g., `+91` followed by 10 digits)

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "message": "OTP sent successfully",
    "expiresIn": 300
  }
}
```

**Error Responses:**
- `400`: Invalid phone format
- `429`: Too many OTP requests (rate limit: 3 per hour per phone)

---

### 2.2 Verify OTP

**Endpoint:** `POST /auth/verify-otp`  
**Access:** Public  
**Description:** Verifies OTP and returns JWT access & refresh tokens.

**Request Body:**
```json
{
  "phone": "+919876543210",
  "otp": "123456"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "expiresIn": 900,
    "user": {
      "id": "uuid-v4",
      "phone": "+919876543210",
      "name": "John Doe",
      "email": "john@example.com",
      "role": "CUSTOMER",
      "isActive": true,
      "createdAt": "2026-01-15T10:00:00Z"
    }
  }
}
```

**Error Responses:**
- `400`: Invalid or expired OTP
- `401`: OTP verification failed (max 3 attempts)

---

### 2.3 Refresh Token

**Endpoint:** `POST /auth/refresh`  
**Access:** Public (requires refresh token)  
**Description:** Exchanges refresh token for new access token.

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
  "data": {
    "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "expiresIn": 900
  }
}
```

**Error Responses:**
- `401`: Invalid or expired refresh token

---

### 2.4 Logout

**Endpoint:** `POST /auth/logout`  
**Access:** Authenticated  
**Description:** Invalidates current refresh token.

**Headers:**
```
Authorization: Bearer <access_token>
```

**Success Response (200):**
```json
{
  "success": true,
  "message": "Logged out successfully"
}
```

---

## 3. User Profile Module

### 3.1 Get Current User

**Endpoint:** `GET /users/me`  
**Access:** Authenticated  
**Description:** Returns current user's profile.

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "id": "uuid-v4",
    "phone": "+919876543210",
    "email": "john@example.com",
    "name": "John Doe",
    "role": "CUSTOMER",
    "profileImageUrl": "https://cdn.meatvo.com/profiles/uuid.jpg",
    "isActive": true,
    "isPhoneVerified": true,
    "isEmailVerified": false,
    "lastLoginAt": "2026-06-12T10:00:00Z",
    "createdAt": "2026-01-15T10:00:00Z"
  }
}
```

---

### 3.2 Update Profile

**Endpoint:** `PATCH /users/me`  
**Access:** Authenticated  
**Description:** Updates user profile information.

**Request Body:**
```json
{
  "name": "John Updated",
  "email": "john.updated@example.com"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "id": "uuid-v4",
    "name": "John Updated",
    "email": "john.updated@example.com"
  }
}
```

---

### 3.3 Upload Profile Picture

**Endpoint:** `POST /users/me/profile-picture`  
**Access:** Authenticated  
**Content-Type:** `multipart/form-data`  
**Description:** Uploads profile picture to Cloudflare R2.

**Request Body:**
```
file: <image_file> (max 5MB, formats: jpg, png, webp)
```

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "profileImageUrl": "https://cdn.meatvo.com/profiles/uuid-v4.jpg"
  }
}
```

---

## 4. Address Module

### 4.1 List Addresses

**Endpoint:** `GET /addresses`  
**Access:** Authenticated (Customer)  
**Description:** Returns all addresses for current user.

**Success Response (200):**
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid-v4",
      "label": "Home",
      "addressLine1": "123 MG Road",
      "addressLine2": "Apt 4B",
      "landmark": "Near City Mall",
      "city": "Bangalore",
      "state": "Karnataka",
      "pincode": "560001",
      "latitude": 12.9716,
      "longitude": 77.5946,
      "isDefault": true,
      "createdAt": "2026-01-20T10:00:00Z"
    }
  ]
}
```

---

### 4.2 Create Address

**Endpoint:** `POST /addresses`  
**Access:** Authenticated (Customer)  
**Description:** Adds a new delivery address.

**Request Body:**
```json
{
  "label": "Work",
  "addressLine1": "456 Koramangala",
  "addressLine2": "Floor 3",
  "landmark": "Near Jyoti Nivas College",
  "city": "Bangalore",
  "state": "Karnataka",
  "pincode": "560095",
  "latitude": 12.9352,
  "longitude": 77.6245,
  "isDefault": false
}
```

**Validation Rules:**
- All fields except `addressLine2`, `landmark`, `isDefault` are required
- `latitude`: -90 to 90, `longitude`: -180 to 180
- `pincode`: 6 digits (India)

**Success Response (201):**
```json
{
  "success": true,
  "data": {
    "id": "uuid-v4",
    "label": "Work",
    // ... full address object
  }
}
```

---

### 4.3 Update Address

**Endpoint:** `PATCH /addresses/:id`  
**Access:** Authenticated (Customer, own addresses only)  
**Description:** Updates an existing address.

**Request Body:**
```json
{
  "label": "Office",
  "isDefault": true
}
```

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "id": "uuid-v4",
    "label": "Office",
    "isDefault": true
    // ... updated address
  }
}
```

---

### 4.4 Delete Address

**Endpoint:** `DELETE /addresses/:id`  
**Access:** Authenticated (Customer, own addresses only)  
**Description:** Deletes an address.

**Success Response (204):**
```
No content
```

---

## 5. Product Catalog Module

### 5.1 List Products

**Endpoint:** `GET /products`  
**Access:** Public  
**Description:** Returns paginated product list with filters.

**Query Parameters:**
| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `categoryId` | UUID | Filter by category | - |
| `search` | string | Search in name/description | - |
| `minPrice` | number | Minimum price filter | - |
| `maxPrice` | number | Maximum price filter | - |
| `isAvailable` | boolean | Only available products | true |
| `isFeatured` | boolean | Only featured products | - |
| `page` | number | Page number | 1 |
| `limit` | number | Items per page | 20 |
| `sortBy` | string | Sort field (price, name) | createdAt |
| `sortOrder` | string | asc / desc | desc |

**Example Request:**
```
GET /products?categoryId=uuid&minPrice=100&maxPrice=500&page=1&limit=20
```

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "items": [
      {
        "id": "uuid-v4",
        "name": "Chicken Breast Boneless",
        "slug": "chicken-breast-boneless",
        "description": "Fresh boneless chicken breast, hygienically cleaned",
        "shortDescription": "Premium boneless breast",
        "categoryId": "uuid-category",
        "category": {
          "id": "uuid-category",
          "name": "Chicken",
          "slug": "chicken"
        },
        "price": 299.00,
        "mrp": 349.00,
        "unit": "kg",
        "unitValue": 0.5,
        "stockQuantity": 45,
        "imageUrl": "https://cdn.meatvo.com/products/chicken-breast.jpg",
        "images": [
          "https://cdn.meatvo.com/products/chicken-breast-1.jpg",
          "https://cdn.meatvo.com/products/chicken-breast-2.jpg"
        ],
        "tags": ["boneless", "chicken", "protein"],
        "isAvailable": true,
        "isFeatured": false,
        "nutritionInfo": {
          "calories": 165,
          "protein": 31,
          "fat": 3.6,
          "carbs": 0
        },
        "createdAt": "2026-01-10T10:00:00Z"
      }
    ],
    "meta": {
      "totalItems": 150,
      "itemCount": 20,
      "itemsPerPage": 20,
      "totalPages": 8,
      "currentPage": 1
    }
  }
}
```

---

### 5.2 Get Product Details

**Endpoint:** `GET /products/:id`  
**Access:** Public  
**Description:** Returns detailed product information.

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "id": "uuid-v4",
    "name": "Chicken Breast Boneless",
    // ... full product object (same as list)
  }
}
```

**Error Responses:**
- `404`: Product not found

---

### 5.3 Search Products

**Endpoint:** `GET /products/search`  
**Access:** Public  
**Description:** Full-text search in product names and descriptions.

**Query Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `q` | string | Search query (required) |
| `page` | number | Page number |
| `limit` | number | Items per page |

**Example Request:**
```
GET /products/search?q=chicken%20boneless&page=1&limit=10
```

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "items": [ /* product array */ ],
    "meta": { /* pagination meta */ }
  }
}
```

---

### 5.4 List Categories

**Endpoint:** `GET /categories`  
**Access:** Public  
**Description:** Returns hierarchical category tree.

**Success Response (200):**
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid-v4",
      "name": "Chicken",
      "slug": "chicken",
      "description": "Fresh chicken products",
      "imageUrl": "https://cdn.meatvo.com/categories/chicken.jpg",
      "parentId": null,
      "displayOrder": 1,
      "isActive": true,
      "children": [
        {
          "id": "uuid-child",
          "name": "Fresh Cuts",
          "slug": "chicken-fresh-cuts",
          "parentId": "uuid-v4",
          "displayOrder": 1,
          "children": []
        }
      ]
    }
  ]
}
```

---

## 6. Cart Module

### 6.1 Get Cart

**Endpoint:** `GET /cart`  
**Access:** Authenticated (Customer)  
**Description:** Returns current user's cart (synced with Redis).

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "items": [
      {
        "productId": "uuid-v4",
        "product": {
          "id": "uuid-v4",
          "name": "Chicken Breast Boneless",
          "price": 299.00,
          "imageUrl": "https://cdn.meatvo.com/products/chicken-breast.jpg",
          "unit": "kg",
          "unitValue": 0.5
        },
        "quantity": 2,
        "subtotal": 598.00
      }
    ],
    "summary": {
      "itemCount": 2,
      "subtotal": 598.00,
      "estimatedDeliveryFee": 30.00,
      "estimatedTotal": 628.00
    }
  }
}
```

---

### 6.2 Add to Cart

**Endpoint:** `POST /cart/items`  
**Access:** Authenticated (Customer)  
**Description:** Adds or updates product quantity in cart.

**Request Body:**
```json
{
  "productId": "uuid-v4",
  "quantity": 2
}
```

**Validation Rules:**
- `quantity`: Positive integer, max 10 per product

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "items": [ /* updated cart items */ ],
    "summary": { /* updated summary */ }
  }
}
```

**Error Responses:**
- `400`: Product out of stock
- `400`: Quantity exceeds available stock

---

### 6.3 Update Cart Item

**Endpoint:** `PATCH /cart/items/:productId`  
**Access:** Authenticated (Customer)  
**Description:** Updates quantity for a cart item.

**Request Body:**
```json
{
  "quantity": 3
}
```

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "items": [ /* updated cart */ ],
    "summary": { /* updated summary */ }
  }
}
```

---

### 6.4 Remove from Cart

**Endpoint:** `DELETE /cart/items/:productId`  
**Access:** Authenticated (Customer)  
**Description:** Removes product from cart.

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "items": [ /* updated cart */ ],
    "summary": { /* updated summary */ }
  }
}
```

---

### 6.5 Clear Cart

**Endpoint:** `DELETE /cart`  
**Access:** Authenticated (Customer)  
**Description:** Removes all items from cart.

**Success Response (204):**
```
No content
```

---

## 7. Order Module

### 7.1 Create Order

**Endpoint:** `POST /orders`  
**Access:** Authenticated (Customer)  
**Description:** Places a new order from cart items.

**Request Body:**
```json
{
  "addressId": "uuid-v4",
  "deliverySlotId": "uuid-slot",
  "paymentMethod": "ONLINE",
  "couponCode": "FIRST50",
  "notes": "Please deliver to back entrance"
}
```

**Validation Rules:**
- `addressId`: Must belong to current user
- `deliverySlotId`: Must be active and available
- `paymentMethod`: ONLINE or COD
- `couponCode`: Optional, validated for eligibility

**Success Response (201):**
```json
{
  "success": true,
  "data": {
    "order": {
      "id": "uuid-v4",
      "orderNumber": "ORD-20260612-001",
      "userId": "uuid-user",
      "status": "PENDING",
      "subtotal": 598.00,
      "deliveryFee": 30.00,
      "discount": 50.00,
      "tax": 35.64,
      "totalAmount": 613.64,
      "paymentMethod": "ONLINE",
      "paymentStatus": "PENDING",
      "items": [
        {
          "productId": "uuid-v4",
          "productName": "Chicken Breast Boneless",
          "quantity": 2,
          "unitPrice": 299.00,
          "subtotal": 598.00
        }
      ],
      "createdAt": "2026-06-12T14:30:00Z"
    },
    "payment": {
      "razorpayOrderId": "order_abc123xyz",
      "amount": 613.64,
      "currency": "INR"
    }
  }
}
```

**Error Responses:**
- `400`: Cart is empty
- `400`: Invalid address or delivery slot
- `400`: Coupon invalid/expired

---

### 7.2 Get Order Details

**Endpoint:** `GET /orders/:id`  
**Access:** Authenticated (Customer - own orders, Rider - assigned orders, Admin - all)  
**Description:** Returns detailed order information.

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "id": "uuid-v4",
    "orderNumber": "ORD-20260612-001",
    "status": "OUT_FOR_DELIVERY",
    "user": {
      "id": "uuid-user",
      "name": "John Doe",
      "phone": "+919876543210"
    },
    "address": {
      "addressLine1": "123 MG Road",
      "city": "Bangalore",
      "pincode": "560001",
      "latitude": 12.9716,
      "longitude": 77.5946
    },
    "rider": {
      "id": "uuid-rider",
      "name": "Rider Name",
      "phone": "+919876543211",
      "currentLocation": {
        "latitude": 12.9700,
        "longitude": 77.5950
      }
    },
    "items": [
      {
        "productId": "uuid-v4",
        "productName": "Chicken Breast Boneless",
        "productImageUrl": "https://cdn.meatvo.com/products/chicken-breast.jpg",
        "quantity": 2,
        "unitPrice": 299.00,
        "subtotal": 598.00
      }
    ],
    "subtotal": 598.00,
    "deliveryFee": 30.00,
    "discount": 50.00,
    "tax": 35.64,
    "totalAmount": 613.64,
    "paymentMethod": "ONLINE",
    "paymentStatus": "PAID",
    "deliverySlot": {
      "label": "Morning (8 AM - 12 PM)",
      "startTime": "08:00",
      "endTime": "12:00"
    },
    "statusLogs": [
      {
        "status": "PENDING",
        "timestamp": "2026-06-12T14:30:00Z"
      },
      {
        "status": "CONFIRMED",
        "timestamp": "2026-06-12T14:35:00Z"
      },
      {
        "status": "OUT_FOR_DELIVERY",
        "timestamp": "2026-06-12T15:00:00Z",
        "location": {
          "latitude": 12.9700,
          "longitude": 77.5950
        }
      }
    ],
    "createdAt": "2026-06-12T14:30:00Z",
    "updatedAt": "2026-06-12T15:00:00Z"
  }
}
```

---

### 7.3 List Orders

**Endpoint:** `GET /orders`  
**Access:** Authenticated (Customer - own orders, Rider - assigned orders, Admin - all)  
**Description:** Returns paginated order list.

**Query Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `status` | string | Filter by status |
| `page` | number | Page number |
| `limit` | number | Items per page |

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "items": [ /* order array */ ],
    "meta": {
      "totalItems": 50,
      "currentPage": 1,
      "totalPages": 5
    }
  }
}
```

---

### 7.4 Cancel Order

**Endpoint:** `POST /orders/:id/cancel`  
**Access:** Authenticated (Customer - own orders before PICKED_UP)  
**Description:** Cancels an order and initiates refund if paid.

**Request Body:**
```json
{
  "reason": "Changed mind"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "orderId": "uuid-v4",
    "status": "CANCELLED",
    "refundStatus": "INITIATED",
    "refundAmount": 613.64
  }
}
```

**Error Responses:**
- `400`: Order cannot be cancelled (already picked up/delivered)

---

### 7.5 Update Order Status (Rider/Admin)

**Endpoint:** `PATCH /orders/:id/status`  
**Access:** Authenticated (Rider - assigned orders, Admin - all)  
**Description:** Updates order status (rider updates during delivery).

**Request Body:**
```json
{
  "status": "PICKED_UP",
  "notes": "Order picked up from store",
  "location": {
    "latitude": 12.9716,
    "longitude": 77.5946
  }
}
```

**Valid Status Transitions:**
```
PENDING → CONFIRMED → PREPARING → READY → PICKED_UP → OUT_FOR_DELIVERY → DELIVERED
         ↓                                    ↓
     CANCELLED                            CANCELLED
```

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "orderId": "uuid-v4",
    "status": "PICKED_UP",
    "updatedAt": "2026-06-12T15:00:00Z"
  }
}
```

---

## 8. Payment Module

### 8.1 Initiate Payment

**Endpoint:** `POST /payments/initiate`  
**Access:** Authenticated (Customer)  
**Description:** Creates Razorpay order for payment (called after order creation).

**Request Body:**
```json
{
  "orderId": "uuid-v4"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "razorpayOrderId": "order_abc123xyz",
    "amount": 61364,
    "currency": "INR",
    "key": "rzp_live_xxxxxxxxxxxx"
  }
}
```

---

### 8.2 Verify Payment

**Endpoint:** `POST /payments/verify`  
**Access:** Authenticated (Customer)  
**Description:** Verifies payment signature after Razorpay checkout.

**Request Body:**
```json
{
  "razorpayOrderId": "order_abc123xyz",
  "razorpayPaymentId": "pay_def456uvw",
  "razorpaySignature": "signature_string"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "paymentStatus": "SUCCESS",
    "orderId": "uuid-v4",
    "orderStatus": "CONFIRMED"
  }
}
```

**Error Responses:**
- `400`: Invalid signature (payment verification failed)

---

### 8.3 Razorpay Webhook

**Endpoint:** `POST /payments/webhook`  
**Access:** Public (IP whitelisted, signature verified)  
**Description:** Receives payment status updates from Razorpay.

**Request Body (Razorpay format):**
```json
{
  "event": "payment.captured",
  "payload": {
    "payment": {
      "entity": {
        "id": "pay_def456uvw",
        "order_id": "order_abc123xyz",
        "amount": 61364,
        "status": "captured"
      }
    }
  }
}
```

**Success Response (200):**
```json
{
  "success": true,
  "message": "Webhook processed"
}
```

---

## 9. Delivery Module

### 9.1 Get Delivery Slots

**Endpoint:** `GET /delivery/slots`  
**Access:** Public  
**Description:** Returns available delivery time slots.

**Success Response (200):**
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid-v4",
      "label": "Morning (8 AM - 12 PM)",
      "startTime": "08:00",
      "endTime": "12:00",
      "capacity": 50,
      "availableSlots": 32,
      "isActive": true
    },
    {
      "id": "uuid-v5",
      "label": "Afternoon (12 PM - 4 PM)",
      "startTime": "12:00",
      "endTime": "16:00",
      "capacity": 50,
      "availableSlots": 45,
      "isActive": true
    }
  ]
}
```

---

### 9.2 Check Delivery Availability

**Endpoint:** `POST /delivery/check-availability`  
**Access:** Public  
**Description:** Checks if delivery is available for a pincode/location.

**Request Body:**
```json
{
  "pincode": "560001"
}
```

**OR**

```json
{
  "latitude": 12.9716,
  "longitude": 77.5946
}
```

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "isAvailable": true,
    "estimatedDeliveryTime": 30,
    "deliveryFee": 30.00,
    "minOrderValue": 0
  }
}
```

**If not serviceable:**
```json
{
  "success": true,
  "data": {
    "isAvailable": false,
    "message": "Delivery not available in your area"
  }
}
```

---

### 9.3 Get Rider Orders (Rider Dashboard)

**Endpoint:** `GET /delivery/rider/orders`  
**Access:** Authenticated (Rider)  
**Description:** Returns orders assigned to the current rider.

**Query Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `status` | string | Filter by status (READY, PICKED_UP, OUT_FOR_DELIVERY) |

**Success Response (200):**
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid-v4",
      "orderNumber": "ORD-20260612-001",
      "status": "READY",
      "customer": {
        "name": "John Doe",
        "phone": "+919876543210"
      },
      "address": {
        "addressLine1": "123 MG Road",
        "city": "Bangalore",
        "latitude": 12.9716,
        "longitude": 77.5946
      },
      "totalAmount": 613.64,
      "paymentMethod": "ONLINE",
      "scheduledAt": "2026-06-12T16:00:00Z",
      "distance": 2.5
    }
  ]
}
```

---

### 9.4 Update Rider Location

**Endpoint:** `POST /delivery/rider/location`  
**Access:** Authenticated (Rider)  
**Description:** Updates rider's current GPS location (called every 10 seconds during active delivery).

**Request Body:**
```json
{
  "latitude": 12.9716,
  "longitude": 77.5946,
  "accuracy": 10.5,
  "speed": 25.0,
  "bearing": 180.0
}
```

**Success Response (200):**
```json
{
  "success": true,
  "message": "Location updated"
}
```

---

## 10. Admin Module

### 10.1 Dashboard Stats

**Endpoint:** `GET /admin/dashboard`  
**Access:** Authenticated (Admin)  
**Description:** Returns dashboard statistics.

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "today": {
      "orders": 125,
      "revenue": 52350.00,
      "newCustomers": 15
    },
    "thisWeek": {
      "orders": 780,
      "revenue": 325000.00
    },
    "thisMonth": {
      "orders": 3200,
      "revenue": 1350000.00
    },
    "activeOrders": {
      "pending": 12,
      "confirmed": 25,
      "outForDelivery": 18
    },
    "topProducts": [
      {
        "productId": "uuid-v4",
        "productName": "Chicken Breast Boneless",
        "orderCount": 145,
        "revenue": 43355.00
      }
    ]
  }
}
```

---

### 10.2 Manage Products

**Create Product:**  
`POST /admin/products`

**Update Product:**  
`PATCH /admin/products/:id`

**Delete Product:**  
`DELETE /admin/products/:id`

**Request Body (Create/Update):**
```json
{
  "name": "Chicken Breast Boneless",
  "description": "Fresh boneless chicken breast",
  "categoryId": "uuid-category",
  "price": 299.00,
  "mrp": 349.00,
  "unit": "kg",
  "unitValue": 0.5,
  "stockQuantity": 100,
  "isAvailable": true,
  "isFeatured": false,
  "tags": ["boneless", "chicken"]
}
```

---

### 10.3 Manage Orders

**List All Orders:**  
`GET /admin/orders`

**Update Order:**  
`PATCH /admin/orders/:id`

**Assign Rider:**  
`POST /admin/orders/:id/assign-rider`

**Request Body:**
```json
{
  "riderId": "uuid-rider"
}
```

---

## 11. WebSocket Events (Real-Time)

### 11.1 Connection

**Endpoint:** `wss://api.meatvo.com`  
**Authentication:** JWT token in query param or header

```javascript
// Client connection
const socket = io('wss://api.meatvo.com', {
  auth: {
    token: '<access_token>'
  }
});
```

---

### 11.2 Customer Events

**Join Order Room:**
```javascript
socket.emit('join_order', { orderId: 'uuid-v4' });
```

**Listen for Order Updates:**
```javascript
socket.on('order_status_update', (data) => {
  // { orderId, status, timestamp }
});

socket.on('order_location_update', (data) => {
  // { orderId, riderId, latitude, longitude, timestamp }
});
```

---

### 11.3 Rider Events

**Send Location Updates:**
```javascript
socket.emit('rider_location_update', {
  latitude: 12.9716,
  longitude: 77.5946
});
```

**Listen for New Orders:**
```javascript
socket.on('new_order_assigned', (data) => {
  // { orderId, orderNumber, customer, address }
});
```

---

## 12. Rate Limiting

### 12.1 Rate Limit Tiers

| Endpoint Pattern | Limit | Window |
|------------------|-------|--------|
| `/auth/send-otp` | 3 requests | 1 hour per phone |
| `/auth/verify-otp` | 5 requests | 5 minutes |
| `/auth/*` | 20 requests | 15 minutes |
| `/products/*` (GET) | 100 requests | 1 minute |
| `/orders` (POST) | 10 requests | 5 minutes |
| `/admin/*` | 200 requests | 1 minute |
| Default | 100 requests | 1 minute |

### 12.2 Rate Limit Headers

```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 87
X-RateLimit-Reset: 1686580800
```

**429 Response:**
```json
{
  "success": false,
  "error": {
    "code": "RATE_LIMIT_EXCEEDED",
    "message": "Too many requests. Please try again in 45 seconds.",
    "retryAfter": 45
  }
}
```

---

## 13. Pagination

### 13.1 Standard Pagination

**Query Parameters:**
- `page`: Page number (default: 1)
- `limit`: Items per page (default: 20, max: 100)

**Response Meta:**
```json
{
  "meta": {
    "totalItems": 150,
    "itemCount": 20,
    "itemsPerPage": 20,
    "totalPages": 8,
    "currentPage": 1,
    "hasNextPage": true,
    "hasPreviousPage": false
  }
}
```

---

## 14. Error Codes Reference

| Code | HTTP Status | Description |
|------|-------------|-------------|
| `VALIDATION_ERROR` | 400 | Request validation failed |
| `INVALID_CREDENTIALS` | 401 | Invalid OTP or token |
| `UNAUTHORIZED` | 401 | Missing authentication |
| `FORBIDDEN` | 403 | Insufficient permissions |
| `NOT_FOUND` | 404 | Resource not found |
| `CONFLICT` | 409 | Duplicate entry (e.g., phone already exists) |
| `OUT_OF_STOCK` | 400 | Product out of stock |
| `INVALID_COUPON` | 400 | Coupon invalid or expired |
| `PAYMENT_FAILED` | 400 | Payment verification failed |
| `RATE_LIMIT_EXCEEDED` | 429 | Too many requests |
| `INTERNAL_ERROR` | 500 | Server error |

---

## 15. Postman Collection

**Download:** [Meatvo API Postman Collection](https://api.meatvo.com/docs/postman-collection.json)

**Swagger UI:** [https://api.meatvo.com/docs](https://api.meatvo.com/docs)

---

**Next Documents:**
- [Security Architecture](./SECURITY_ARCHITECTURE.md) — Authentication & security
- [Infrastructure](./INFRASTRUCTURE.md) — Deployment & DevOps
- [Scalability Strategy](./SCALABILITY.md) — Scaling for growth

---

*Document Classification: Confidential — API Specification*

# Enhanced Order Lifecycle Documentation

## Overview

Complete order lifecycle system with real-time communication between Customer, Admin, and Rider (Delivery Partner).

## Order States

### Complete State Flow

```
PLACED
  ↓
PAYMENT_PENDING (for online payment)
  ↓
PAYMENT_VERIFIED (admin verifies)
  ↓
CONFIRMED
  ↓
PACKING_STARTED (admin starts packing)
  ↓
PACKED (ready for delivery)
  ↓
RIDER_ASSIGNED (auto/manual assignment)
  ↓
RIDER_ACCEPTED (rider accepts)
  ↓
OUT_FOR_DELIVERY (rider picked up)
  ↓
RIDER_NEARBY (within 500m)
  ↓
DELIVERED (completed with OTP/proof)
```

### Alternative Flows

- **Cancellation**: Can happen at PLACED, CONFIRMED, PACKING_STARTED, PACKED
- **Rejection**: RIDER_REJECTED → back to PACKED for reassignment
- **Refund**: CANCELLED or DELIVERED → REFUNDED (if needed)

## Communication Matrix

### Stage 1: Order Placement

**State**: `PLACED`

| Role     | What They See | Actions Available | Notifications |
|----------|--------------|------------------|---------------|
| Customer | "Order placed successfully" | - Cancel order | ✅ "Order #{orderId} placed" |
| Admin    | "New order from {phone}" | - Verify payment<br>- Confirm order<br>- Cancel order | ✅ "New order from {phone}" |
| Rider    | Nothing yet | None | - |

**Socket Events**:
- `order:new` → admin_room
- `order:status_updated` → customer_{id}

---

### Stage 2: Payment Verification (Online Payment Only)

**State**: `PAYMENT_PENDING` → `PAYMENT_VERIFIED`

| Role     | What They See | Actions Available | Notifications |
|----------|--------------|------------------|---------------|
| Customer | "Payment being verified" | None | ✅ "Payment verification in progress" |
| Admin    | "Verify payment for order #{orderId}" | - Verify payment<br>- Cancel order | ✅ "Verify payment" |
| Rider    | Nothing | None | - |

**API Endpoint**:
```http
POST /api/orders/:id/verify-payment
Authorization: Bearer {admin_token}
```

---

### Stage 3: Order Confirmation

**State**: `CONFIRMED`

| Role     | What They See | Actions Available | Notifications |
|----------|--------------|------------------|---------------|
| Customer | "Order confirmed, will be prepared soon" | - Cancel order | ✅ "Order confirmed" |
| Admin    | "Order confirmed, ready for packing" | - Start packing<br>- Cancel order | ✅ "Order confirmed" |
| Rider    | Nothing | None | - |

---

### Stage 4: Packing

**State**: `PACKING_STARTED` → `PACKED`

| Role     | What They See | Actions Available | Notifications |
|----------|--------------|------------------|---------------|
| Customer | "Your order is being prepared" | None | ✅ "Order being prepared" |
| Admin    | "Order being packed" | - Mark as packed<br>- Cancel order | - |
| Rider    | Nothing | None | - |

**API Endpoints**:
```http
POST /api/orders/:id/start-packing
POST /api/orders/:id/mark-packed
```

---

### Stage 5: Rider Assignment

**State**: `RIDER_ASSIGNED`

| Role     | What They See | Actions Available | Notifications |
|----------|--------------|------------------|---------------|
| Customer | "Delivery partner assigned: {name}" | - Track rider<br>- Call rider | ✅ "{riderName} will deliver" |
| Admin    | "Assigned to {riderName}" | - Reassign<br>- Cancel assignment | ✅ "Rider assigned" |
| Rider    | "New order: {address}" | - Accept<br>- Reject | ✅ "New order assigned" |

**Socket Events**:
- `order:partner_assigned` → customer_{id}
- `order:assigned` → delivery_{userId}
- `order:updated` → admin_room

**API Endpoint**:
```http
POST /api/orders/:id/accept
Authorization: Bearer {rider_token}
```

---

### Stage 6: Rider Acceptance

**State**: `RIDER_ACCEPTED`

| Role     | What They See | Actions Available | Notifications |
|----------|--------------|------------------|---------------|
| Customer | "{riderName} preparing to pick up" | - Track rider<br>- Call rider | ✅ "Rider accepted order" |
| Admin    | "Rider accepted" | - Monitor | ✅ "Rider accepted" |
| Rider    | "Navigate to pickup location" | - Start delivery<br>- Reject | - |

---

### Stage 7: Out for Delivery

**State**: `OUT_FOR_DELIVERY`

| Role     | What They See | Actions Available | Notifications |
|----------|--------------|------------------|---------------|
| Customer | "{riderName} is on the way<br>ETA: {X} mins" | - Track live<br>- Call rider | ✅ "Order on the way" |
| Admin    | "Order in transit" | - Monitor | ✅ "Order in transit" |
| Rider    | "Navigate to customer" | - Update location<br>- Mark nearby<br>- Mark delivered | - |

**Real-time Tracking**:
- Rider location updates every 5-10 seconds
- ETA calculated automatically based on:
  - Distance to customer
  - Vehicle type (bike: 25km/h, scooter: 30km/h, etc.)
  - Traffic buffer (20%)

**API Endpoint**:
```http
POST /api/orders/location
Authorization: Bearer {rider_token}
Body: {
  "lat": 28.7041,
  "lng": 77.1025,
  "orderId": 123
}
```

**Socket Events**:
- `rider:location_update` → customer_{id}, admin_room
- `rider:eta_update` → customer_{id}

---

### Stage 8: Rider Nearby

**State**: `RIDER_NEARBY` (Auto-triggered when within 500m)

| Role     | What They See | Actions Available | Notifications |
|----------|--------------|------------------|---------------|
| Customer | "🔔 Rider is nearby (5 min away)" | - Track live<br>- Call rider<br>- View OTP | ✅ URGENT: "Rider arriving" |
| Admin    | "Rider nearby customer" | - Monitor | - |
| Rider    | "Approaching customer" | - Mark delivered | - |

**Customer gets Delivery OTP**:
```http
GET /api/orders/:id/delivery-otp
Authorization: Bearer {customer_token}

Response: {
  "otp": "123456"
}
```

---

### Stage 9: Delivery Completion

**State**: `DELIVERED`

| Role     | What They See | Actions Available | Notifications |
|----------|--------------|------------------|---------------|
| Customer | "Order delivered!<br>Rate your experience" | - Rate order<br>- Report issue | ✅ "Order delivered" |
| Admin    | "Order completed by {riderName}" | - View details | ✅ "Order completed" |
| Rider    | "Delivery completed<br>Earnings: ₹{amount}" | - Next order | ✅ "Delivery completed" |

**Delivery Verification** (Rider endpoint):
```http
POST /api/orders/:id/complete
Authorization: Bearer {rider_token}
Body: {
  "otp": "123456",               // Customer's delivery OTP
  "proofType": "photo",          // or "signature"
  "proofUrl": "https://...",     // Uploaded proof
  "customerName": "John Doe",    // Who received
  "notes": "Delivered to gate",  // Optional
  "codAmount": 500               // For COD orders
}
```

**Verification Steps**:
1. OTP verification (if provided)
2. Delivery proof stored (photo/signature)
3. COD amount verification (for COD orders)
4. Auto-update rider earnings (10% of order value)
5. Send completion notifications to all parties

---

## Real-time Notifications

### Notification Structure

```javascript
{
  "id": "notif_...",
  "userId": 123,
  "role": "customer",
  "type": "order_status_change",
  "title": "Order Confirmed",
  "body": "Your order has been confirmed",
  "data": {
    "orderId": 456,
    "state": "CONFIRMED"
  },
  "priority": "high",  // normal, high, urgent
  "createdAt": "2026-06-05T...",
  "read": false
}
```

### Notification API

```http
# Get notifications
GET /api/notifications?limit=50&unreadOnly=true

# Mark as read
POST /api/notifications/:id/read

# Mark all as read
POST /api/notifications/read-all

# Get unread count
GET /api/notifications/unread-count
```

### Socket Events

**Customer Receives**:
- `notification:new` - New notification
- `order:status_updated` - Order status changed
- `order:partner_assigned` - Rider assigned
- `rider:location_update` - Rider location updated
- `rider:eta_update` - ETA changed

**Admin Receives**:
- `notification:new` - New notification
- `order:new` - New order placed
- `order:updated` - Order updated
- `order:partner_assigned` - Rider assigned
- `order:assignment_failed` - No rider available
- `rider:potentially_offline` - Rider might be offline

**Rider Receives**:
- `notification:new` - New notification
- `order:assigned` - New order assigned
- `order:status_updated` - Order status changed
- `order:assignment_cancelled` - Assignment cancelled

---

## ETA Calculation

### Formula

```
ETA (minutes) = (Distance in km / Vehicle Speed) × 60 × 1.2
                                                        ↑
                                                    20% buffer
```

### Vehicle Speeds

- Bike: 25 km/h
- Scooter: 30 km/h
- Bicycle: 15 km/h
- Car: 35 km/h

### Example

```
Distance: 3 km
Vehicle: Scooter (30 km/h)
ETA = (3 / 30) × 60 × 1.2 = 7.2 minutes ≈ 8 minutes
```

---

## API Summary

### Order Lifecycle Endpoints

| Method | Endpoint | Role | Description |
|--------|----------|------|-------------|
| POST | `/api/orders/:id/transition` | All | Generic state transition |
| GET | `/api/orders/:id/timeline` | All | Get order timeline |
| GET | `/api/orders/:id/actions` | All | Get available actions |
| GET | `/api/orders/:id/tracking` | All | Get tracking info |

### Admin Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/orders/:id/verify-payment` | Verify online payment |
| POST | `/api/orders/:id/start-packing` | Start packing |
| POST | `/api/orders/:id/mark-packed` | Mark as packed |

### Rider Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/orders/:id/accept` | Accept order |
| POST | `/api/orders/:id/start-delivery` | Start delivery |
| POST | `/api/orders/location` | Update location |
| POST | `/api/orders/:id/complete` | Complete delivery |

### Customer Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/orders/:id/delivery-otp` | Get delivery OTP |
| GET | `/api/orders/:id/tracking` | Track order |

---

## Integration Guide

### 1. Add Routes to Main App

```javascript
// In backend/index.js or routes/index.js
const enhancedOrdersRoutes = require('./modules/orders/enhancedOrders.routes');
app.use('/api/orders', enhancedOrdersRoutes);
```

### 2. Socket.IO Integration

Already integrated! Just ensure:
- `io` instance passed to controllers via `req.app.set('io', io)`
- Clients join appropriate rooms:
  - Customer: `customer_{userId}`
  - Admin: `admin_room`
  - Rider: `delivery_{userId}`

### 3. Client-side Socket Listeners

**Customer App**:
```javascript
socket.on('notification:new', (notification) => {
  showNotification(notification);
});

socket.on('order:status_updated', ({ orderId, status }) => {
  updateOrderStatus(orderId, status);
});

socket.on('rider:location_update', ({ lat, lng, eta }) => {
  updateRiderMarker(lat, lng);
  updateETA(eta);
});
```

**Admin App**:
```javascript
socket.on('order:new', ({ orderId, customerPhone }) => {
  playSound();
  addToOrderList(orderId);
});

socket.on('order:updated', ({ orderId, status }) => {
  refreshOrderList();
});
```

**Rider App**:
```javascript
socket.on('order:assigned', ({ orderId, address }) => {
  showNewOrderAlert(orderId, address);
});

socket.on('order:assignment_cancelled', ({ orderId, reason }) => {
  removeFromList(orderId);
});
```

---

## State Machine Validation

All state transitions are validated:

1. **Valid Transition**: Must be allowed by state machine
2. **Actor Permission**: User role must be authorized
3. **Order Ownership**: Customer/Rider must have access

**Example**:
```
PACKED → OUT_FOR_DELIVERY: ✅ Valid
PLACED → DELIVERED: ❌ Invalid (skips states)
CONFIRMED → PACKED (by customer): ❌ No permission
```

---

## Best Practices

### For Frontend Developers

1. **Always listen to socket events** for real-time updates
2. **Show ETA updates** to customers during delivery
3. **Handle offline scenarios** gracefully
4. **Cache notifications** for offline viewing
5. **Request location permissions** early in rider app

### For Backend Developers

1. **Use state machine** for all transitions
2. **Always emit socket events** after state changes
3. **Log all state transitions** for debugging
4. **Handle concurrent requests** with database locks
5. **Implement retry logic** for failed assignments

---

## Monitoring & Analytics

Track these metrics:

- **Order lifecycle time**: PLACED → DELIVERED
- **Assignment success rate**: % of orders assigned successfully
- **Average ETA accuracy**: Actual vs predicted
- **Rider acceptance rate**: % of assignments accepted
- **Delivery verification rate**: % with OTP/proof

---

## Troubleshooting

### Order stuck in RIDER_ASSIGNED

**Cause**: Rider not accepting
**Solution**: Auto-reassign after 5 minutes

### ETA not updating

**Cause**: Rider not sending location updates
**Solution**: Alert admin if no update for 5 minutes

### OTP not working

**Cause**: Redis connection issue or OTP expired
**Solution**: Regenerate OTP or allow manual verification

---

## Future Enhancements

1. **Multi-stop deliveries**: One rider, multiple orders
2. **Route optimization**: Best path for rider
3. **Predicted ETA with ML**: Learn from historical data
4. **Customer delivery preferences**: Contact-less, specific instructions
5. **Rider performance scoring**: Rating, speed, reliability

---

## Support

For issues or questions:
- Check logs: `backend/logs/`
- Socket events: Use Socket.IO admin UI
- State transitions: Check `order_lifecycle.service.js` logs

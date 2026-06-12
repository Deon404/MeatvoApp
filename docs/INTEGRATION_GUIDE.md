# Integration Guide: Enhanced Order Lifecycle

## Quick Start

This guide will help you integrate the enhanced order lifecycle system into your MeatvoApp.

## Step 1: Install Dependencies

All dependencies are already in your `package.json`. Just ensure Redis is running:

```bash
# Check if Redis is running
redis-cli ping
# Should return: PONG

# If not running, start Redis
redis-server
```

## Step 2: Add Routes to Main App

Add the enhanced routes to your main Express app:

```javascript
// In backend/index.js (or your main app file)

// Import the new routes
const enhancedOrdersRoutes = require('./src/modules/orders/enhancedOrders.routes');

// Mount the routes
app.use('/api/orders', enhancedOrdersRoutes);

// Note: This should be AFTER authentication middleware setup
```

## Step 3: Update Socket.IO Setup

Your socket setup is already good! Just ensure the `io` instance is available to controllers:

```javascript
// This is already in your code, but verify:
app.set('io', io);
```

## Step 4: Frontend Integration

### Customer App

```javascript
// Initialize socket connection
import io from 'socket.io-client';

const socket = io('YOUR_BACKEND_URL', {
  path: '/ws',
  auth: {
    token: 'YOUR_JWT_TOKEN'
  }
});

// Join customer room
socket.emit('join_customer_room', customerId);

// Listen for order updates
socket.on('order:status_updated', (data) => {
  console.log('Order status:', data.status);
  // Update UI
});

socket.on('rider:location_update', (data) => {
  console.log('Rider location:', data.lat, data.lng);
  console.log('ETA:', data.eta, 'minutes');
  // Update map marker
});

socket.on('notification:new', (notification) => {
  console.log('New notification:', notification.title);
  // Show notification banner
});

// Get delivery OTP when order is out for delivery
async function getDeliveryOTP(orderId) {
  const response = await fetch(`/api/orders/${orderId}/delivery-otp`, {
    headers: {
      'Authorization': `Bearer ${token}`
    }
  });
  const data = await response.json();
  console.log('Delivery OTP:', data.otp);
  // Display OTP to customer
}

// Track order in real-time
async function trackOrder(orderId) {
  const response = await fetch(`/api/orders/${orderId}/tracking`, {
    headers: {
      'Authorization': `Bearer ${token}`
    }
  });
  const tracking = await response.json();
  console.log('Tracking:', tracking);
  // Update map with rider location
  // Show ETA
}
```

### Admin Panel

```javascript
// Initialize socket
const socket = io('YOUR_BACKEND_URL', {
  path: '/ws',
  auth: {
    token: 'YOUR_JWT_TOKEN'
  }
});

// Join admin room
socket.emit('join_admin_room');

// Listen for new orders
socket.on('order:new', (data) => {
  console.log('New order:', data.orderId);
  playNotificationSound();
  addOrderToList(data);
});

// Listen for order updates
socket.on('order:updated', (data) => {
  console.log('Order updated:', data.orderId, data.status);
  updateOrderInList(data);
});

// Verify payment
async function verifyPayment(orderId) {
  const response = await fetch(`/api/orders/${orderId}/verify-payment`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    }
  });
  return response.json();
}

// Start packing
async function startPacking(orderId) {
  const response = await fetch(`/api/orders/${orderId}/start-packing`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`
    }
  });
  return response.json();
}

// Mark as packed
async function markPacked(orderId) {
  const response = await fetch(`/api/orders/${orderId}/mark-packed`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`
    }
  });
  return response.json();
}
```

### Rider App

```javascript
// Initialize socket
const socket = io('YOUR_BACKEND_URL', {
  path: '/ws',
  auth: {
    token: 'YOUR_JWT_TOKEN'
  }
});

// Join delivery room
socket.emit('join_delivery_room', userId);

// Listen for order assignments
socket.on('order:assigned', (data) => {
  console.log('New order assigned:', data.orderId);
  showOrderAcceptDialog(data);
});

// Accept order
async function acceptOrder(orderId) {
  const response = await fetch(`/api/orders/${orderId}/accept`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`
    }
  });
  return response.json();
}

// Start delivery
async function startDelivery(orderId) {
  const response = await fetch(`/api/orders/${orderId}/start-delivery`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`
    }
  });
  return response.json();
}

// Update location (call this every 5-10 seconds during delivery)
async function updateLocation(lat, lng, orderId) {
  const response = await fetch('/api/orders/location', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      lat,
      lng,
      orderId
    })
  });
  return response.json();
}

// Complete delivery
async function completeDelivery(orderId, otp, proofUrl, codAmount) {
  const response = await fetch(`/api/orders/${orderId}/complete`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      otp,              // Customer's OTP
      proofType: 'photo',
      proofUrl,         // Upload image first, then pass URL
      customerName: 'Customer Name',
      codAmount         // Only for COD orders
    })
  });
  return response.json();
}

// Start location tracking when delivery begins
function startLocationTracking(orderId) {
  if (navigator.geolocation) {
    locationWatchId = navigator.geolocation.watchPosition(
      (position) => {
        updateLocation(
          position.coords.latitude,
          position.coords.longitude,
          orderId
        );
      },
      (error) => {
        console.error('Location error:', error);
      },
      {
        enableHighAccuracy: true,
        timeout: 10000,
        maximumAge: 0
      }
    );
  }
}

// Stop tracking when delivery is complete
function stopLocationTracking() {
  if (locationWatchId) {
    navigator.geolocation.clearWatch(locationWatchId);
  }
}
```

## Step 5: Testing the Flow

### Test Scenario 1: Complete Order Flow

1. **Customer places order** (existing API)
   - Order state: `PLACED` or `CONFIRMED` (COD)

2. **Admin verifies payment** (if online payment)
   ```bash
   POST /api/orders/1/verify-payment
   ```
   - State changes: `PLACED` → `PAYMENT_VERIFIED` → `CONFIRMED`

3. **Admin starts packing**
   ```bash
   POST /api/orders/1/start-packing
   ```
   - State: `CONFIRMED` → `PACKING_STARTED`

4. **Admin marks as packed**
   ```bash
   POST /api/orders/1/mark-packed
   ```
   - State: `PACKING_STARTED` → `PACKED`
   - Auto-assigns rider

5. **Rider accepts order**
   ```bash
   POST /api/orders/1/accept
   ```
   - State: `RIDER_ASSIGNED` → `RIDER_ACCEPTED`

6. **Rider starts delivery**
   ```bash
   POST /api/orders/1/start-delivery
   ```
   - State: `RIDER_ACCEPTED` → `OUT_FOR_DELIVERY`

7. **Rider updates location** (continuously)
   ```bash
   POST /api/orders/location
   Body: { lat: 28.7041, lng: 77.1025, orderId: 1 }
   ```
   - Customer sees live tracking
   - ETA updates automatically

8. **Customer gets OTP**
   ```bash
   GET /api/orders/1/delivery-otp
   ```
   - Returns 6-digit OTP

9. **Rider completes delivery**
   ```bash
   POST /api/orders/1/complete
   Body: {
     otp: "123456",
     proofType: "photo",
     proofUrl: "https://...",
     codAmount: 500
   }
   ```
   - State: `OUT_FOR_DELIVERY` → `DELIVERED`
   - Rider earnings updated

### Test Scenario 2: Order Cancellation

```bash
# Customer cancels order (before packing)
PUT /api/orders/1/cancel
```

### Test Scenario 3: Rider Rejection

```bash
# Rider rejects order
POST /api/orders/1/reject
```
- State: `RIDER_ASSIGNED` → `PACKED`
- Auto-reassigns to another rider

## Step 6: Monitoring

### Check Socket Connections

```javascript
// In your backend
io.on('connection', (socket) => {
  console.log('User connected:', socket.userId, socket.userRole);
});
```

### Check Notifications

```bash
GET /api/notifications?limit=10
GET /api/notifications/unread-count
```

### Check Order Timeline

```bash
GET /api/orders/1/timeline
```

Returns:
```json
{
  "timeline": [
    {
      "state": "PLACED",
      "timestamp": "2026-06-05T...",
      "completed": true
    },
    {
      "state": "CONFIRMED",
      "timestamp": "2026-06-05T...",
      "completed": true,
      "current": true
    },
    {
      "state": "PACKED",
      "completed": false
    }
  ]
}
```

## Step 7: Error Handling

### Common Errors

**1. Invalid State Transition**
```json
{
  "error": "Invalid state transition from PLACED to DELIVERED"
}
```
**Solution**: Follow the correct state flow

**2. Unauthorized State Trigger**
```json
{
  "error": "Your role (customer) cannot trigger state PACKED"
}
```
**Solution**: Only authorized roles can trigger specific states

**3. OTP Expired**
```json
{
  "error": "OTP expired or not found"
}
```
**Solution**: Request new OTP (valid for 10 minutes)

## Step 8: Production Checklist

- [ ] Redis is running and accessible
- [ ] Socket.IO CORS configured correctly
- [ ] All API endpoints return proper responses
- [ ] Socket events are being emitted
- [ ] Notifications are being created
- [ ] ETA calculation is accurate
- [ ] OTP generation and verification works
- [ ] Delivery proof upload works
- [ ] COD verification is accurate
- [ ] State transitions are logged
- [ ] Error handling is comprehensive

## Performance Optimization

### 1. Redis Connection Pooling

Already handled by your Redis client.

### 2. Socket.IO Rooms

Ensure users join appropriate rooms:
```javascript
socket.join(`customer_${userId}`);
socket.join(`delivery_${userId}`);
socket.join('admin_room');
```

### 3. Rate Limiting

Location updates from riders:
- Max: Once every 5 seconds
- Implemented in socket middleware

### 4. Database Indexes

Ensure indexes on:
```sql
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_order_assignments_order_id ON order_assignments(order_id);
CREATE INDEX idx_order_assignments_partner_id ON order_assignments(delivery_partner_id);
```

## Troubleshooting

### Issue: Socket not connecting

**Check:**
1. Is backend running?
2. Is JWT token valid?
3. Is CORS configured correctly?

```javascript
// Frontend
socket.on('connect_error', (error) => {
  console.error('Socket connection error:', error);
});
```

### Issue: Notifications not appearing

**Check:**
1. Is user authenticated?
2. Are socket listeners set up?
3. Is Redis running?

### Issue: ETA not updating

**Check:**
1. Is rider sending location updates?
2. Is orderId passed in location update?
3. Is customer address valid with lat/lng?

## Next Steps

1. **Review the documentation**: Read `ORDER_LIFECYCLE.md`
2. **Test the API**: Use Postman or your API client
3. **Integrate frontend**: Follow the examples above
4. **Monitor logs**: Check for any errors
5. **Test real scenarios**: Place test orders and track them

## Support

If you encounter issues:

1. Check backend logs
2. Check Redis connection
3. Verify socket events in browser console
4. Check API responses
5. Review state machine rules in `enhancedOrderStateMachine.js`

---

**Happy Integration! 🚀**

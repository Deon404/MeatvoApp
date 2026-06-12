# Migration Guide: Old to Enhanced Lifecycle

## Overview

Your existing order controllers have been **updated to use the new enhanced lifecycle system** while maintaining **100% backward compatibility** with existing clients.

## What Changed

### ✅ Updated Files

1. **`backend/src/modules/orders/orders.controller.js`**
   - ✅ Now uses enhanced notification service
   - ✅ State transitions use new lifecycle service
   - ✅ Delivery OTP auto-created for COD orders
   - ✅ Backward compatible socket events maintained

2. **`backend/src/modules/delivery/delivery.controller.js`**
   - ✅ Location updates now include ETA calculation
   - ✅ Auto "nearby" detection at 500m
   - ✅ Backward compatible events maintained

3. **`backend/src/utils/lifecycleCompatibility.js`** (NEW)
   - State mapping between old and new
   - Transform helpers for API responses
   - Display state utilities

## Backward Compatibility

### Your Existing API Still Works!

All your current endpoints work exactly as before:

```javascript
// Old endpoints still work
POST /api/orders           // Create order
PUT /api/orders/:id        // Update status
PUT /api/orders/:id/cancel // Cancel order
GET /api/orders/:id        // Get order
```

### Socket Events

Old socket events are still emitted alongside new ones:

```javascript
// Old events (still working)
'order:new'
'order:status_updated'
'order:status_update'

// New events (also emitted)
'notification:new'
'rider:location_update' (with ETA)
```

### State Names

Clients using old state names will work fine:

```javascript
// Old states (still supported)
'PLACED', 'CONFIRMED', 'PACKED', 'OUT_FOR_DELIVERY', 'DELIVERED'

// New intermediate states (mapped to old for compatibility)
'PAYMENT_PENDING' -> shows as 'PLACED' to old clients
'PACKING_STARTED' -> shows as 'CONFIRMED' to old clients
'RIDER_ASSIGNED' -> shows as 'PACKED' to old clients
'RIDER_NEARBY' -> shows as 'OUT_FOR_DELIVERY' to old clients
```

## Migration Strategies

### Strategy 1: Gradual Migration (Recommended)

Keep using your existing endpoints, but add new features progressively:

**Phase 1: Start using enhanced features**
```javascript
// In your frontend, add new event listeners
socket.on('notification:new', (notif) => {
  // New notification system
});

socket.on('rider:location_update', ({ eta }) => {
  // New ETA updates
});

// Keep old listeners for now
socket.on('order:status_updated', (data) => {
  // Still works
});
```

**Phase 2: Adopt new endpoints**
```javascript
// Start using new endpoints
GET /api/orders/:id/tracking      // Real-time tracking
GET /api/orders/:id/timeline      // Order progress
GET /api/orders/:id/delivery-otp  // For customers
POST /api/orders/location          // Rider location with ETA
```

**Phase 3: Use enhanced states**
```javascript
// Add header to request enhanced states
fetch('/api/orders/123', {
  headers: {
    'X-Enhanced-States': 'true'
  }
});

// Response will include:
{
  status: 'RIDER_NEARBY',        // Enhanced state
  enhancedStatus: 'RIDER_NEARBY',
  displayStatus: 'Arriving Soon',
  isIntermediateState: true
}
```

### Strategy 2: Immediate Full Migration

Switch all clients to enhanced endpoints:

1. Update frontend to use new routes
2. Add enhanced state handling
3. Implement new UI features

## Feature Comparison

| Feature | Old System | Enhanced System |
|---------|-----------|-----------------|
| **States** | 6 basic | 13 detailed |
| **Notifications** | Socket only | Notification center + Socket |
| **Tracking** | Status only | Live location + ETA |
| **Delivery Proof** | None | OTP + Photo + Signature |
| **Location Updates** | Basic | With ETA + nearby detection |
| **Payment Flow** | Manual | Verification workflow |

## Testing Your Migration

### Step 1: Test Existing Functionality

```bash
# Verify old endpoints still work
curl -X POST http://localhost:3000/api/orders \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"deliveryAddress": "...", "paymentMethod": "COD"}'

# Should work exactly as before
```

### Step 2: Test New Features

```bash
# Test delivery OTP
curl http://localhost:3000/api/orders/123/delivery-otp \
  -H "Authorization: Bearer $CUSTOMER_TOKEN"

# Test tracking with ETA
curl http://localhost:3000/api/orders/123/tracking \
  -H "Authorization: Bearer $TOKEN"

# Test location with ETA calculation
curl -X POST http://localhost:3000/api/orders/location \
  -H "Authorization: Bearer $RIDER_TOKEN" \
  -d '{"lat": 28.7041, "lng": 77.1025, "orderId": 123}'
```

### Step 3: Verify Notifications

```javascript
// Connect socket and verify both old and new events
socket.on('order:status_updated', (data) => {
  console.log('Old event:', data);
});

socket.on('notification:new', (notif) => {
  console.log('New notification:', notif);
});
```

## Common Issues

### Issue: Getting old states when expecting new ones

**Solution**: Add header to request:
```javascript
headers: { 'X-Enhanced-States': 'true' }
```

### Issue: ETA not showing

**Solution**: Rider must pass `orderId` in location update:
```javascript
POST /api/orders/location
{
  "lat": 28.7041,
  "lng": 77.1025,
  "orderId": 123  // ← Required for ETA
}
```

### Issue: Duplicate notifications

**Cause**: Both old and new event listeners active  
**Solution**: Gradually remove old listeners as you adopt new ones

## Rollback Plan

If you need to rollback to pure old system:

1. **Keep using old endpoints only**
2. **Ignore new socket events**
3. **Don't use enhanced state header**

The system will work exactly as before.

## Performance Impact

### Database Queries

- ✅ No additional queries for basic operations
- ✅ Enhanced features only query when called
- ✅ Backward compatible queries unchanged

### Socket Events

- ✅ Old events: Still emit (no change)
- ➕ New events: Additional (opt-in)

### Memory Usage

- ✅ Notification storage: In-memory with 100 limit per user
- ✅ Location cache: In-memory with TTL
- ✅ OTP storage: Redis with 10-min expiry

## API Response Transformation

### Example: Order Object

**With `X-Enhanced-States: false` (default)**:
```json
{
  "id": 123,
  "status": "PACKED",           // Old state
  "customer_id": 456,
  "total_amount": 500
}
```

**With `X-Enhanced-States: true`**:
```json
{
  "id": 123,
  "status": "RIDER_ASSIGNED",   // Enhanced state
  "enhancedStatus": "RIDER_ASSIGNED",
  "displayStatus": "Delivery Partner Assigned",
  "isIntermediateState": true,
  "customer_id": 456,
  "total_amount": 500
}
```

## State Mapping Reference

| Enhanced State | Maps to Old State | Visible to Customer |
|---------------|-------------------|---------------------|
| PLACED | PLACED | Yes |
| PAYMENT_PENDING | PLACED | "Payment verification..." |
| PAYMENT_VERIFIED | CONFIRMED | "Payment confirmed" |
| CONFIRMED | CONFIRMED | Yes |
| PACKING_STARTED | CONFIRMED | "Preparing..." |
| PACKED | PACKED | Yes |
| RIDER_ASSIGNED | PACKED | "Delivery partner assigned" |
| RIDER_ACCEPTED | PACKED | "Delivery partner on way" |
| RIDER_REJECTED | PACKED | "Finding delivery partner" |
| OUT_FOR_DELIVERY | OUT_FOR_DELIVERY | Yes |
| RIDER_NEARBY | OUT_FOR_DELIVERY | "Arriving soon!" |
| DELIVERED | DELIVERED | Yes |
| CANCELLED | CANCELLED | Yes |

## Code Examples

### Using Compatibility Helper

```javascript
const {
  transformOrderForOldClient,
  supportsEnhancedStates,
} = require('../utils/lifecycleCompatibility');

// In your controller
const order = await getOrderFromDB(orderId);

if (supportsEnhancedStates(req)) {
  // Send enhanced state
  return ok(res, order);
} else {
  // Transform for old client
  return ok(res, transformOrderForOldClient(order));
}
```

### Gradually Adopting New States

```javascript
// Frontend code
function getOrderStatusDisplay(order) {
  // Try enhanced status first
  if (order.displayStatus) {
    return order.displayStatus; // "Arriving Soon"
  }
  
  // Fall back to old status
  return getOldStatusDisplay(order.status); // "Out for Delivery"
}
```

## Benefits of Migration

### For Customers
- ✅ Real-time tracking with live map
- ✅ Accurate ETA updates
- ✅ "Nearby" notifications
- ✅ Delivery OTP for security
- ✅ Better status visibility

### For Admin
- ✅ Payment verification workflow
- ✅ Packing status tracking
- ✅ Better order monitoring
- ✅ Delivery proof verification

### For Riders
- ✅ Automatic ETA calculation
- ✅ Delivery proof collection
- ✅ OTP verification
- ✅ Better earnings tracking

## Next Steps

1. ✅ **Your existing code works** - No immediate action needed
2. 📱 **Test new features** - Try new endpoints
3. 🚀 **Gradual migration** - Adopt features one by one
4. 📚 **Read docs** - Check ORDER_LIFECYCLE.md for details

## Need Help?

- **Compatibility issues**: Check `lifecycleCompatibility.js`
- **New features**: Check `ORDER_LIFECYCLE.md`
- **Integration**: Check `INTEGRATION_GUIDE.md`
- **API reference**: Check `IMPLEMENTATION_SUMMARY.md`

---

**You're Ready! Your system is now enhanced with zero breaking changes. 🎉**

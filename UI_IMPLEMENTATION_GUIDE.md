# Licious-Style Delivery Partner UI Implementation Guide

This document provides the complete design specifications and implementation approach for the remaining UI components.

## Completed Backend & Architecture (9/12 todos)

✅ Route optimization endpoints fixed and mounted
✅ Location tracking consolidated with smart batching  
✅ Order status system unified with migration
✅ Centralized Riverpod state management for riders
✅ Advanced earnings calculation (base + distance + time + peak + performance)
✅ Intelligent assignment algorithm with multi-factor scoring
✅ Real-time ETA recalculation with traffic factors
✅ Offline queue system with auto-sync
✅ Performance analytics dashboard with charts

## Remaining UI Implementation (3 todos)

### 1. Dashboard Redesign

**File:** `frontend/lib/screens/rider/rider_dashboard_screen.dart`

**Key Design Principles:**
- 64dp online/offline toggle at top (thumb-accessible)
- Earnings front and center (48sp bold)
- Color-coded order cards (🔴 new, 🟢 active, ⚪ completed)
- 56-60dp tap targets minimum
- High contrast (WCAG AAA)

**Layout Structure:**
```dart
Column(
  children: [
    // Header with online toggle
    _buildHeader(),  // 64dp height
    
    // Earnings summary card
    _buildEarningsCard(),  // Today, week, month pills
    
    // Active orders list
    _buildActiveOrdersList(),  // Color-coded cards
    
    // Route shortcut
    _buildRouteButton(),  // Floating action style
  ],
)
```

**Component Specifications:**

**Online/Offline Toggle:**
```dart
Container(
  height: 64,
  padding: EdgeInsets.symmetric(horizontal: 24),
  child: Row(
    children: [
      CircleAvatar(size: 48, child: profile picture),
      Spacer(),
      GestureDetector(
        onTap: () => ref.read(riderProvider.notifier).toggleOnlineStatus(),
        child: Container(
          width: 160,
          height: 48,
          decoration: BoxDecoration(
            color: isOnline ? Color(0xFF00C853) : Colors.grey,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Icon(Icons.circle, color: Colors.white),
              Text(isOnline ? 'ONLINE' : 'OFFLINE', 18sp, bold),
            ],
          ),
        ),
      ),
    ],
  ),
)
```

**Earnings Card:**
```dart
Container(
  margin: EdgeInsets.all(16),
  padding: EdgeInsets.all(20),
  decoration: BoxDecoration(
    gradient: LinearGradient([Color(0xFFE31E24), Color(0xFFB71C1C)]),
    borderRadius: BorderRadius.circular(16),
    boxShadow: elevation,
  ),
  child: Column(
    children: [
      Text('TODAY'S EARNINGS', 14sp, white),
      SizedBox(height: 8),
      Text('₹${earnings.today}', 48sp, bold, white),
      SizedBox(height: 16),
      Row(
        children: [
          _buildPill('Weekly', '₹${earnings.week}'),
          _buildPill('Monthly', '₹${earnings.month}'),
        ],
      ),
    ],
  ),
)
```

**Order Cards (Action Cards):**
```dart
Container(
  height: 120,  // Fixed height for consistency
  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  padding: EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
      color: statusColor,  // Red for new, green for active
      width: 3,
    ),
  ),
  child: Row(
    children: [
      // Status indicator (colored circle)
      Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: statusColor,
          shape: BoxShape.circle,
        ),
      ),
      SizedBox(width: 16),
      // Order info
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order #${order.id}', 18sp, bold),
            Text('${order.distance} km • ₹${order.earnings}', 14sp),
            Text(order.address, 12sp, grey, maxLines: 1),
          ],
        ),
      ),
      // Action buttons (60dp height, 120dp width)
      if (order.status == 'ASSIGNED')
        _buildAcceptRejectButtons(),
      if (order.status == 'ACCEPTED')
        _buildNavigateButton(),
    ],
  ),
)
```

### 2. Order Detail Redesign (Progressive Disclosure)

**File:** `frontend/lib/screens/rider/rider_order_detail_screen.dart`

**Design Philosophy:** Show only what's needed for current stage

**Stage 1: New Assignment**
```dart
Scaffold(
  body: Column(
    children: [
      // Large status header
      Container(
        height: 80,
        color: Color(0xFFE31E24),
        child: Center(
          child: Text(
            'NEW ORDER #${order.id}',
            style: TextStyle(32sp, bold, white),
          ),
        ),
      ),
      
      // Earnings preview
      Container(
        padding: EdgeInsets.all(20),
        child: Text(
          '₹${order.earnings} earnings • ${order.distance} km',
          style: TextStyle(20sp, bold),
        ),
      ),
      
      // Locations
      _buildLocationCard('PICKUP', order.pickupAddress),
      _buildLocationCard('DELIVERY', order.deliveryAddress),
      
      // Items list (collapsed by default)
      ExpansionTile(title: 'ORDER ITEMS (${items.length})'),
      
      Spacer(),
      
      // Giant accept button (64dp height)
      Container(
        height: 64,
        margin: EdgeInsets.all(16),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF00C853),
            shape: RoundedRectangleBorder(borderRadius: 12),
          ),
          onPressed: () => acceptOrder(),
          child: Text('ACCEPT ORDER', 18sp, bold),
        ),
      ),
      
      // Small reject text button
      TextButton(
        onPressed: () => rejectOrder(),
        child: Text('Reject', 14sp, grey),
      ),
    ],
  ),
)
```

**Stage 2: En Route (Map Dominant)**
```dart
Stack(
  children: [
    // Map takes 70% of screen
    GoogleMap(
      initialCameraPosition: riderLocation,
      markers: {riderMarker, destinationMarker},
      polylines: {routePolyline},
    ),
    
    // Bottom sheet with next action
    DraggableScrollableSheet(
      initialChildSize: 0.3,
      minChildSize: 0.3,
      maxChildSize: 0.6,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // ETA banner
              Container(
                padding: EdgeInsets.all(16),
                color: Color(0xFFFFF9C4),
                child: Row(
                  children: [
                    Icon(Icons.access_time),
                    SizedBox(width: 8),
                    Text('${order.distance} km • ${order.eta} min', 16sp, bold),
                  ],
                ),
              ),
              
              // Destination info
              ListTile(
                leading: Icon(Icons.location_on, size: 32),
                title: Text(order.address, 16sp, bold),
                subtitle: Text('Customer: ${order.customerName}'),
              ),
              
              // Action buttons (60dp height each)
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      'NAVIGATE',
                      Icons.navigation,
                      () => launchNavigation(),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _buildActionButton(
                      'CALL',
                      Icons.phone,
                      () => callCustomer(),
                    ),
                  ),
                ],
              ),
              
              // Mark as picked up/delivered (appears when <100m)
              if (order.distance < 0.1)
                Container(
                  height: 64,
                  width: double.infinity,
                  margin: EdgeInsets.all(16),
                  child: ElevatedButton(
                    child: Text('MARK AS ${nextStatus}', 18sp, bold),
                    onPressed: () => updateStatus(),
                  ),
                ),
            ],
          ),
        );
      },
    ),
  ],
)
```

**Stage 3: Delivery Completion (Swipe to Complete)**
```dart
Column(
  children: [
    // Customer info card
    _buildCustomerCard(),
    
    // Payment reminder (if COD)
    if (order.paymentMode == 'COD')
      Container(
        padding: EdgeInsets.all(20),
        color: Color(0xFFFFF9C4),
        child: Row(
          children: [
            Icon(Icons.currency_rupee, size: 32),
            SizedBox(width: 12),
            Text('COLLECT ₹${order.amount}', 20sp, bold),
          ],
        ),
      ),
    
    Spacer(),
    
    // Swipe to complete gesture
    Container(
      height: 80,
      margin: EdgeInsets.all(20),
      child: SlideToConfirm(
        text: 'SWIPE TO COMPLETE →',
        onConfirm: () => markAsDelivered(),
        backgroundColor: Color(0xFF00C853),
        foregroundColor: Colors.white,
      ),
    ),
  ],
)
```

### 3. Route Map Enhancement

**File:** `frontend/lib/screens/rider/delivery_map_screen.dart`

**Layout:**
```dart
Scaffold(
  body: Stack(
    children: [
      // Map (70% of screen)
      GoogleMap(
        markers: stopMarkers,  // Numbered 1-6
        polylines: {optimizedRoute},  // Colored polyline
        initialCameraPosition: showingAllStops,
      ),
      
      // Top info card
      Positioned(
        top: 60,
        left: 16,
        right: 16,
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: elevation,
          ),
          child: Row(
            children: [
              Icon(Icons.route, color: Color(0xFFE31E24)),
              SizedBox(width: 12),
              Text('TODAY'S ROUTE', 16sp, bold),
              Spacer(),
              Text('${stops.length} stops', 14sp, grey),
            ],
          ),
        ),
      ),
      
      // Bottom sheet with stop list
      DraggableScrollableSheet(
        initialChildSize: 0.25,
        minChildSize: 0.15,
        maxChildSize: 0.7,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  margin: EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                
                // Total earnings preview
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      Text('Total Earnings:', 16sp),
                      Spacer(),
                      Text('₹${totalEarnings}', 24sp, bold, green),
                    ],
                  ),
                ),
                
                Divider(),
                
                // Stop list
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: stops.length,
                    itemBuilder: (context, index) {
                      final stop = stops[index];
                      return _buildStopCard(index + 1, stop);
                    },
                  ),
                ),
                
                // Start route button (if not started)
                if (!routeStarted)
                  Container(
                    height: 64,
                    width: double.infinity,
                    margin: EdgeInsets.all(16),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFE31E24),
                      ),
                      onPressed: () => startRoute(),
                      child: Text('START ROUTE', 18sp, bold),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    ],
  ),
)
```

**Stop Card:**
```dart
Container(
  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  padding: EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: stop.completed ? Colors.grey[100] : Colors.white,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
      color: stop.completed ? Colors.grey : Color(0xFFE31E24),
      width: 2,
    ),
  ),
  child: Row(
    children: [
      // Stop number
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: stop.completed ? Colors.grey : Color(0xFFE31E24),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text('$index', 18sp, bold, white),
        ),
      ),
      SizedBox(width: 16),
      
      // Stop info
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order #${stop.orderId}', 16sp, bold),
            Text(stop.address, 14sp, grey, maxLines: 1),
            Text('${stop.distance} km • ₹${stop.earnings}', 12sp, grey),
          ],
        ),
      ),
      
      // Status icon
      Icon(
        stop.completed ? Icons.check_circle : Icons.circle_outlined,
        color: stop.completed ? Colors.green : Colors.grey,
        size: 28,
      ),
    ],
  ),
)
```

## Design System Tokens

**Colors:**
```dart
class AppColors {
  static const primary = Color(0xFFE31E24);  // Licious red
  static const primaryDark = Color(0xFFB71C1C);
  static const success = Color(0xFF00C853);
  static const warning = Color(0xFFFFB300);
  static const error = Color(0xFFD32F2F);
  static const background = Color(0xFFFAFAFA);
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Colors.black87;
  static const textSecondary = Colors.black60;
}
```

**Typography:**
```dart
class AppTypography {
  static const h1 = TextStyle(fontSize: 32, fontWeight: FontWeight.bold);
  static const h2 = TextStyle(fontSize: 24, fontWeight: FontWeight.bold);
  static const h3 = TextStyle(fontSize: 20, fontWeight: FontWeight.bold);
  static const body1 = TextStyle(fontSize: 16, fontWeight: FontWeight.normal);
  static const body2 = TextStyle(fontSize: 14, fontWeight: FontWeight.normal);
  static const caption = TextStyle(fontSize: 12, color: Colors.black60);
  static const button = TextStyle(fontSize: 18, fontWeight: FontWeight.w600);
}
```

**Spacing:**
```dart
class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  
  static const buttonHeight = 60.0;
  static const cardRadius = 12.0;
  static const screenPadding = 16.0;
}
```

## Implementation Checklist

### Dashboard
- [ ] Create online/offline toggle widget (64dp)
- [ ] Implement earnings summary card with gradient
- [ ] Build color-coded order cards (120dp height)
- [ ] Add haptic feedback on actions
- [ ] Integrate with RiderProvider
- [ ] Add pull-to-refresh
- [ ] Implement floating route button

### Order Detail
- [ ] Create stage-based layouts (3 stages)
- [ ] Implement progressive disclosure
- [ ] Build swipe-to-complete widget
- [ ] Add map integration for stage 2
- [ ] Implement proximity detection (<100m)
- [ ] Add smooth transitions between stages
- [ ] Integrate offline queue for status updates

### Route Map
- [ ] Implement draggable bottom sheet
- [ ] Create stop list with completion status
- [ ] Add numbered map markers
- [ ] Draw optimized route polyline
- [ ] Implement start route functionality
- [ ] Add re-optimize route button
- [ ] Show total earnings preview

## Testing Requirements

1. **Accessibility:** All tap targets ≥56dp, WCAG AAA contrast
2. **Performance:** Smooth 60fps animations, <200ms response
3. **Offline:** All critical actions queued and synced
4. **Responsive:** Works on small (5") and large (6.7") screens
5. **Dark Mode:** All screens support system dark mode

## Integration with Backend

All UI components use:
- `RiderProvider` for state management
- `OfflineService` for offline queue
- `RiderLocationService` for GPS tracking
- `RiderService` for API calls

Socket.IO events handled:
- `order:assigned` → Show notification + update active orders
- `route:zone_assigned` → Refresh route map
- `eta:updated` → Update order detail ETA

## Next Steps

1. Implement dashboard redesign using specifications above
2. Create order detail progressive disclosure
3. Enhance route map with draggable sheet
4. Test on physical devices (especially outdoor use)
5. Gather rider feedback and iterate
6. Run database migration for order statuses
7. Deploy backend changes
8. Roll out to beta riders

## Estimated Completion

- Dashboard: 4-6 hours
- Order Detail: 6-8 hours
- Route Map: 4-6 hours
- Testing & Polish: 4-6 hours
**Total: 18-26 hours of focused development**

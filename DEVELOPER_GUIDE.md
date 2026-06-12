# Delivery Tracking Feature - Developer Guide

## Overview

This guide explains how to use the new bi-directional delivery tracking features that enable seamless communication between customers and delivery partners.

## Architecture

```
Customer App                     Backend                    Delivery Partner App
─────────────                    ───────                    ─────────────────────
OrderDetailScreen                Socket.IO                  RiderOrderDetailScreen
├─ DeliveryPartnerContactCard    ├─ partner:accepted        ├─ CustomerContactCard
│  ├─ Call button                ├─ delivery:location       │  ├─ Call button
│  └─ SMS button                 └─ customer:location       │  └─ SMS button
└─ DeliveryTrackingMap                                      └─ RiderNavigationMap
   (existing)                                                  ├─ Route display
                                                               ├─ ETA/Distance
                                                               └─ Launch Maps
```

## Customer Side Usage

### 1. OrderDetailScreen Integration

The `DeliveryPartnerContactCard` is automatically displayed when a delivery partner is assigned:

```dart
// Already integrated in OrderDetailScreen
if (_order!.riderId != null)
  DeliveryPartnerContactCard(
    order: _order!,
    showAnimation: _showPartnerCardAnimation,
    onRefresh: _loadOrderDetails,
  ),
```

**States**:
- **Searching**: Shown when order is placed but no rider assigned yet
- **Assigned**: Shows rider name, phone, and action buttons
- **Animation**: Slides in smoothly when `partner:accepted` socket event received

### 2. Contact Actions

**Making a Call**:
```dart
final service = ContactActionService();
await service.makeCall(phoneNumber);
```

**Sending SMS**:
```dart
final service = ContactActionService();
await service.sendSMS(phoneNumber, message: 'Optional message');
```

**Error Handling**:
```dart
if (!success && context.mounted) {
  service.showContactError(context, 'call', phoneNumber);
}
```

## Delivery Partner Side Usage

### 1. RiderOrderDetailScreen Integration

The rider screen now has three main enhancements:

#### a. Navigation Drawer

Access via hamburger menu:
```dart
drawer: _buildNavigationDrawer(),
```

Menu items:
- Active Orders
- Earnings
- Profile
- Settings
- Logout

#### b. Customer Contact Card

Shows customer info with actions:
```dart
CustomerContactCard(
  order: orderModel,
  onRefresh: _loadOrderDetails,
)
```

**Features**:
- Customer name and avatar
- Delivery address
- Order ID badge
- Call/SMS buttons

#### c. Navigation Map

Full-featured map with route guidance:
```dart
RiderNavigationMap(
  order: orderModel,
  showTraffic: false,
  onRouteUpdate: (eta, distance) {
    // Handle route updates
  },
)
```

### 2. Location Tracking Service

**Start Tracking** (automatically called when order is accepted):
```dart
final locationService = RiderLocationService();
locationService.startSendingLocation(orderId);
```

**Stop Tracking** (automatically called when order is completed):
```dart
locationService.stopSendingLocation();
```

**How it works**:
1. Primary: Updates on 50m movement (battery efficient)
2. Backup: Updates every 30 seconds (ensures regular updates)
3. Sends to backend REST API + Socket.IO

### 3. Navigation Service

**Calculate Route**:
```dart
final navService = NavigationService();
final route = await navService.calculateRoute(
  origin: LatLng(riderLat, riderLng),
  destination: LatLng(customerLat, customerLng),
);

if (route != null) {
  print('ETA: ${route.duration}');
  print('Distance: ${route.distance}');
  // Use route.polylinePoints for map display
}
```

**Launch Google Maps**:
```dart
await navService.launchGoogleMapsNavigation(
  destination: LatLng(customerLat, customerLng),
  origin: LatLng(riderLat, riderLng),
);
```

**Format Helpers**:
```dart
// Format ETA
String eta = navService.formatETA(durationSeconds); // "15 mins"

// Format distance
String distance = navService.formatDistance(distanceMeters); // "2.5 km"

// Format arrival time
DateTime arrival = navService.getEstimatedArrivalTime(durationSeconds);
String arrivalText = navService.formatArrivalTime(arrival); // "Arriving at 3:45 PM"
```

## Socket Integration

### Customer Side

**Listen for Partner Acceptance**:
```dart
void _listenToPartnerAcceptance() {
  SocketService().onPartnerAccepted((data) {
    if (data['orderId'] == widget.orderId) {
      setState(() {
        _showPartnerCardAnimation = true;
      });
      _loadOrderDetails();
    }
  });
}
```

### Delivery Partner Side

**Subscribe to Customer Location** (optional for future enhancement):
```dart
SocketService().subscribeToCustomerLocation(orderId);
SocketService().onCustomerLocation((data) {
  final lat = data['lat'];
  final lng = data['lng'];
  // Update customer marker if live tracking is enabled
});
```

## Backend Requirements

### Socket Events to Implement

#### 1. partner:accepted
Emit when delivery partner accepts an order:
```javascript
// Emit to customer's room when rider accepts
io.to(`user:${customerId}`).emit('partner:accepted', {
  orderId: orderId,
  riderId: riderId,
  riderName: riderName,
  riderPhone: riderPhone
});
```

#### 2. customer:location (Optional)
Emit customer location to rider:
```javascript
// When rider subscribes
socket.on('subscribe:customer_location', ({ orderId }) => {
  // Join room for this order's location updates
  socket.join(`order:${orderId}:location`);
});

// Broadcast customer location
io.to(`order:${orderId}:location`).emit('customer:location', {
  orderId: orderId,
  lat: customerLat,
  lng: customerLng
});
```

### REST Endpoint (Optional Fallback)

```javascript
// GET /api/delivery/customer-location/:orderId
router.get('/customer-location/:orderId', authenticateRider, async (req, res) => {
  const order = await Order.findById(req.params.orderId);
  
  // Verify rider is assigned to this order
  if (order.riderId !== req.user.id) {
    return res.status(403).json({ message: 'Not authorized' });
  }
  
  res.json({
    latitude: order.deliveryLatitude,
    longitude: order.deliveryLongitude,
    address: order.deliveryAddress,
    customerName: order.customer.name,
    customerPhone: order.customer.phone
  });
});
```

## Customization

### Theming

Both contact cards use Material You design and automatically adapt to app theme:

```dart
// Colors are taken from Theme.of(context).colorScheme
final colorScheme = Theme.of(context).colorScheme;

// Primary: Main action buttons
// Secondary/Tertiary: Info cards, badges
// Surface: Card backgrounds
```

### Button Variants

`ContactActionButton` supports multiple styles:

```dart
ContactActionButton(
  icon: Icons.phone,
  label: 'Call',
  variant: ContactActionButtonVariant.filled,    // Default
  // variant: ContactActionButtonVariant.outlined,
  // variant: ContactActionButtonVariant.text,
  // variant: ContactActionButtonVariant.tonal,
  isLoading: false,
  iconOnly: false,  // Set true for icon-only buttons
  onPressed: () => {},
)
```

### Map Customization

```dart
RiderNavigationMap(
  order: order,
  showTraffic: true,  // Enable traffic layer
  onRouteUpdate: (eta, distance) {
    // Custom handling of route updates
    print('Updated ETA: $eta, Distance: $distance');
  },
)
```

## Testing

### Unit Tests

```dart
// Test ContactActionService
test('should format phone number correctly', () {
  final service = ContactActionService();
  expect(service.isValidPhoneNumber('+1234567890'), true);
  expect(service.isValidPhoneNumber('invalid'), false);
});

// Test NavigationService
test('should format ETA correctly', () {
  final service = NavigationService();
  expect(service.formatETA(90), '2 mins');
  expect(service.formatETA(3600), '1 hour');
});
```

### Widget Tests

```dart
testWidgets('DeliveryPartnerContactCard shows rider info', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: DeliveryPartnerContactCard(
        order: mockOrder,
      ),
    ),
  );
  
  expect(find.text('John Doe'), findsOneWidget);
  expect(find.text('+1234567890'), findsOneWidget);
  expect(find.byIcon(Icons.phone), findsOneWidget);
});
```

### Integration Tests

```dart
testWidgets('Customer can call delivery partner', (tester) async {
  await tester.pumpWidget(MyApp());
  
  // Navigate to order detail
  await tester.tap(find.text('View Order'));
  await tester.pumpAndSettle();
  
  // Tap call button
  await tester.tap(find.byIcon(Icons.phone));
  await tester.pumpAndSettle();
  
  // Verify phone dialer was launched
  // (mock url_launcher in test)
});
```

## Troubleshooting

### Common Issues

#### 1. Location permission denied
```dart
// Check and request permissions
final hasPermission = await MapsService().hasLocationPermission();
if (!hasPermission) {
  final permission = await MapsService().requestLocationPermission();
  // Handle denied case
}
```

#### 2. Google Maps not opening
```dart
// The service automatically falls back to browser
// Check if Google Maps app is installed:
final uri = Uri.parse('googlemaps://');
final canLaunch = await canLaunchUrl(uri);
```

#### 3. Socket not connecting
```dart
// Ensure token is valid
await SocketService().connect();

// Check connection status
if (!SocketService().isConnected) {
  print('Socket not connected');
  // Show offline UI
}
```

#### 4. Route not calculating
```dart
// Check if coordinates are valid
if (order.deliveryLatitude == null || order.deliveryLongitude == null) {
  // Show error: "Delivery location not available"
}

// Check network connection
try {
  final route = await navService.calculateRoute(...);
  if (route == null) {
    // Show error: "Unable to calculate route"
  }
} catch (e) {
  // Handle network error
}
```

## Performance Optimization

### Battery Optimization

The smart location tracking is already optimized:
- Updates only on 50m movement (not every GPS tick)
- 30s max interval prevents battery drain during idle
- Automatically stops when delivery is complete

### Memory Management

```dart
@override
void dispose() {
  // Always stop location tracking
  _locationService.stopSendingLocation();
  
  // Cancel socket listeners
  SocketService().offPartnerAccepted();
  SocketService().offCustomerLocation();
  
  super.dispose();
}
```

## Security Considerations

### Phone Number Privacy

Phone numbers are only shown to:
- Customers: After delivery partner accepts order
- Delivery partners: Only for assigned orders

### Location Privacy

- Customer location is only sent to assigned delivery partner
- Delivery partner location is only sent to customer with active order
- Location tracking stops automatically when order is completed

## Future Enhancements

### Possible Additions

1. **In-app Chat**: Real-time messaging between customer and partner
2. **Voice Calls**: In-app calling without revealing phone numbers
3. **Delivery Photo**: Partner can upload delivery proof
4. **Live Customer Location**: Optional live tracking of customer (if moving)
5. **Route History**: Save and replay delivery routes
6. **Background Location**: Continue tracking even when app is in background

### Extension Points

```dart
// Add custom actions to contact cards
class CustomContactCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CustomerContactCard(order: order),
        // Add custom widgets here
        ElevatedButton(
          onPressed: () => launchInAppChat(),
          child: Text('Open Chat'),
        ),
      ],
    );
  }
}
```

---

**Questions?** Check the implementation summary in `IMPLEMENTATION_SUMMARY.md` or refer to inline code documentation.

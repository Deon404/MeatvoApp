# Quick Testing Guide - Delivery Tracking

## Prerequisites

Before testing, ensure:
1. Backend server is running with Socket.IO enabled
2. Google Maps API key is configured in `.env`
3. Location permissions are granted on test devices
4. Both customer and rider test accounts are set up

## Test Scenarios

### Scenario 1: Customer Views Delivery Partner Contact

**Steps**:
1. Login as customer
2. Place a new order
3. **Expected**: See "Searching for delivery partner..." card with loading spinner
4. Admin assigns delivery partner to order (via admin panel)
5. Backend emits `partner:accepted` socket event
6. **Expected**: Card slides in with animation showing:
   - Delivery partner name
   - Phone number
   - Status badge ("On the way")
   - Call and Message buttons

**Test Actions**:
- Tap **Call** button
  - **Expected**: Phone dialer opens with partner's number
- Tap **Message** button
  - **Expected**: SMS app opens with partner's number pre-filled

**Error Cases**:
- If phone app can't launch: Error dialog appears
- If no partner assigned after 30s: Refresh to check status

---

### Scenario 2: Delivery Partner Navigates to Customer

**Steps**:
1. Login as delivery partner
2. Navigate to active orders list
3. Accept an order assignment
4. Open order detail screen
5. **Expected**: Screen shows:
   - Customer contact card at top with:
     - Customer name
     - Phone number
     - Delivery address
     - Call/Message buttons
   - Navigation map in middle with:
     - Customer location (red marker)
     - Current rider location (blue dot)
     - Route polyline (dashed blue line)
     - ETA and distance at bottom
     - Traffic toggle button (top right)
     - Center map button (top right)
   - Order details below map

**Test Actions**:

**A. Contact Customer**:
- Tap **Call Customer** button
  - **Expected**: Phone dialer opens
- Tap **Message** button
  - **Expected**: SMS app opens

**B. Navigation**:
- Move 50+ meters away
  - **Expected**: 
    - Map updates position
    - Route recalculates
    - ETA/distance updates
    - Location sent to backend
- Wait 30 seconds without moving
  - **Expected**: Location sent to backend anyway
- Tap **Navigate** button
  - **Expected**: Google Maps app opens with route
  - **Fallback**: If Maps not installed, opens in browser

**C. Map Controls**:
- Tap **Traffic** button
  - **Expected**: Traffic layer toggles on/off
- Tap **Center** button
  - **Expected**: Map animates to show both rider and customer locations

**D. Navigation Drawer**:
- Tap hamburger menu icon
  - **Expected**: Drawer opens with menu items:
    - Active Orders
    - Earnings
    - Profile
    - Settings
    - Logout

---

### Scenario 3: Real-time Location Tracking

**Setup**: Two devices (or emulator + physical device)
- Device A: Customer account
- Device B: Delivery partner account

**Steps**:
1. Device B (Rider): Accept order and start delivery
2. Device A (Customer): Open order detail screen
3. **Expected**: Customer sees rider's location on map (existing feature)
4. Device B (Rider): Move around with GPS enabled
5. **Expected on Device A**: 
   - Rider marker updates on map every 50m or 30s
   - Route line updates
   - ETA updates

**Monitor**:
- Socket connection status (should show "Connected" in logs)
- Location update frequency (check logs)
- Battery usage (should be < 5% per hour)

---

### Scenario 4: Edge Cases

#### A. No Location Permission
1. Deny location permission
2. Open rider order detail
3. **Expected**: 
   - Map shows "Location permission needed" message
   - Prompt to enable location in settings

#### B. No Network Connection
1. Turn off WiFi and mobile data
2. Try to calculate route
3. **Expected**:
   - Last known route is cached and shown
   - "No network" warning appears
   - ETA shows as "Calculating..." or last known value

#### C. Invalid Phone Number
1. Order with invalid/missing phone number
2. **Expected**:
   - Call/SMS buttons are disabled OR
   - Tapping shows "Phone number not available" error

#### D. Google Maps Not Installed
1. Tap **Navigate** button on device without Google Maps
2. **Expected**:
   - Opens in web browser as fallback
   - Shows route on maps.google.com

#### E. Order Cancelled During Delivery
1. Admin cancels order while rider is en route
2. **Expected**:
   - Location tracking stops automatically
   - Map stops updating
   - Customer no longer sees rider location

---

## Performance Checks

### Location Update Frequency
Monitor logs for location updates:
```
[RiderLocation] Sending location update (movement trigger)
[RiderLocation] Sending location update (30s timer)
```

**Expected**:
- Updates every 50m when moving
- Updates every 30s when stationary
- No updates when delivery is complete

### Battery Impact
Check battery usage in device settings:
- **Acceptable**: 3-7% per hour during active delivery
- **High**: > 10% per hour (investigate if this occurs)

### Memory Usage
Monitor app memory in Android Studio/Xcode:
- **Acceptable**: < 200MB for entire app
- **High**: > 300MB (investigate if this occurs)

### Network Usage
Check data usage:
- **Location updates**: ~1KB per update
- **Route calculation**: ~10-50KB per calculation
- **Expected per hour**: < 5MB for location + routes

---

## Verification Checklist

### Customer Side
- [ ] Delivery partner card appears after assignment
- [ ] Card shows correct partner name and phone
- [ ] Card has slide-in animation
- [ ] Call button opens phone dialer
- [ ] SMS button opens messaging app
- [ ] Card shows appropriate status badge
- [ ] Card displays in both map and list views
- [ ] Loading state shows before partner assigned

### Delivery Partner Side
- [ ] Customer contact card displays correctly
- [ ] Customer name and phone are accurate
- [ ] Delivery address is complete
- [ ] Call button works
- [ ] SMS button works
- [ ] Navigation map loads
- [ ] Customer marker appears on map
- [ ] Route polyline is visible
- [ ] ETA and distance are accurate
- [ ] Traffic toggle works
- [ ] Center map button works
- [ ] Navigate button launches Google Maps
- [ ] Navigation drawer opens and works
- [ ] Location updates every 50m
- [ ] Location updates every 30s max

### Real-time Features
- [ ] Customer sees partner location updates
- [ ] Partner sees route recalculate on movement
- [ ] Socket connection is stable
- [ ] Updates continue in background (when app is open)
- [ ] Updates stop when delivery is complete

### Error Handling
- [ ] Location permission denial is handled
- [ ] Network errors show appropriate messages
- [ ] Invalid phone numbers don't crash app
- [ ] Google Maps fallback works
- [ ] Socket disconnection is handled gracefully

---

## Common Issues & Solutions

### Issue: Map not loading
**Solution**: 
- Check Google Maps API key in `.env`
- Verify Maps SDK is enabled in Google Cloud Console
- Check device has internet connection

### Issue: Location not updating
**Solution**:
- Verify location permissions are granted
- Check GPS is enabled on device
- Ensure order status is "accepted" or "out_for_delivery"
- Check logs for location service errors

### Issue: Call/SMS buttons not working
**Solution**:
- Verify device has phone/SMS capabilities
- Check `url_launcher` permissions in manifest
- Test with valid phone number format

### Issue: Route calculation fails
**Solution**:
- Check Directions API is enabled in Google Cloud Console
- Verify API key has Directions API access
- Check network connection
- Verify start and end coordinates are valid

### Issue: Socket events not received
**Solution**:
- Verify backend Socket.IO is running on `/ws` path
- Check JWT token is valid
- Monitor socket connection logs
- Test backend socket events with Postman or socket.io-client

---

## Debug Commands

### Check Socket Connection
```dart
// Add to debug panel
Text('Socket: ${SocketService().isConnected ? "Connected" : "Disconnected"}')
```

### Monitor Location Updates
```dart
// Add to rider service
debugPrint('[RiderLocation] Update sent at ${DateTime.now()}');
debugPrint('[RiderLocation] Lat: $lat, Lng: $lng');
```

### Test Route Calculation
```dart
// Add temporary button
ElevatedButton(
  onPressed: () async {
    final route = await NavigationService().calculateRoute(
      origin: LatLng(12.9716, 77.5946),  // Bangalore
      destination: LatLng(13.0827, 80.2707),  // Chennai
    );
    print('Route: ${route?.duration}, ${route?.distance}');
  },
  child: Text('Test Route'),
)
```

---

## Performance Profiling

### Using Flutter DevTools

1. Start app in profile mode: `flutter run --profile`
2. Open DevTools: `flutter pub global run devtools`
3. Monitor:
   - **CPU**: Should stay < 20% when idle
   - **Memory**: Should be stable around 150-200MB
   - **Network**: Spikes during route calculations only

### Using Android Studio Profiler

1. Run app on Android device
2. Open Android Profiler
3. Monitor:
   - **CPU**: Minimal usage when not moving
   - **Memory**: No memory leaks
   - **Network**: Small periodic packets (location updates)
   - **Battery**: < 5% drain per hour

---

## Sign-off Checklist

Before marking as complete:

### Functionality
- [ ] All 4 test scenarios pass
- [ ] All edge cases handled gracefully
- [ ] Performance meets requirements
- [ ] No crashes or ANRs
- [ ] UI is responsive and smooth

### Code Quality
- [ ] No linter errors
- [ ] Code is documented
- [ ] Error handling is comprehensive
- [ ] Memory leaks are fixed

### Documentation
- [ ] Implementation summary is accurate
- [ ] Developer guide is complete
- [ ] This testing guide covers all scenarios
- [ ] Backend requirements are documented

### Ready for Production
- [ ] Tested on both iOS and Android
- [ ] Tested on different screen sizes
- [ ] Tested with slow network
- [ ] Tested with low battery mode
- [ ] User acceptance testing complete

---

**Testing Complete!** 🎉

Once all items are checked, the feature is ready for production deployment.

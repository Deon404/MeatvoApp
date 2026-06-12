# Rider Order Assignment Alert Implementation

## Overview
Implemented a prominent auto-dismissing bottom sheet alert when riders receive new order assignments via Socket.IO.

## What Was Implemented

### 1. Rider Dashboard Screen Updates
**File:** `old_meatvo/lib/screens/rider/rider_dashboard_screen.dart`

#### Added Features:
- **AudioPlayer integration** for notification sound
- **Auto-dismiss bottom sheet** with 30-second countdown
- **Accept/Reject actions** for incoming orders
- **Visual countdown timer** with circular progress indicator

#### Key Changes:

##### Import AudioPlayer
```dart
import 'package:audioplayers/audioplayers.dart';
```

##### Modified Socket Event Handler
The `_handleAssignmentAssigned()` method now:
1. Plays notification sound
2. Shows modal bottom sheet instead of snackbar
3. Displays prominent alert with order details

##### New Methods Added:
- `_showNewOrderAlert(Map orderData)` - Shows the bottom sheet alert
- `_acceptOrder(orderId)` - Handles order acceptance
- `_rejectOrder(orderId)` - Handles order rejection

### 2. NewOrderAlertSheet Widget

A new bottom sheet widget featuring:

- **Countdown Timer Ring:** 
  - Animated circular progress (30 seconds)
  - Large countdown number in center
  - Auto-dismisses when timer reaches 0

- **Order Information:**
  - "New Order!" heading
  - Order ID display
  - Total amount (if provided)

- **Action Buttons:**
  - **Reject button** (outlined, left side)
  - **Accept button** (elevated, right side, 2x width)
  - Both buttons close sheet and trigger respective actions

### 3. Notification Sound Setup

#### Directory Structure:
```
old_meatvo/
  └── assets/
      └── sounds/
          ├── README.md (instructions)
          └── new_order.mp3(to be added)
```

#### Sound Integration:
- Uses `audioplayers` package (already in `pubspec.yaml`)
- Plays on bottom sheet appearance
- Graceful error handling if sound file missing

## User Experience Flow

1. **Order Assignment Trigger:**
   - Backend calls `assignOrderToPartner()` for new orders
   - Socket event `order:assigned` emitted to rider

2. **Rider App Response:**
   - Notification sound plays
   - Bottom sheet slides up (cannot be dismissed by tapping outside)
   - 30-second countdown begins

3. **Rider Actions:**
   - **Accept:** Order assigned, sheet closes, success message shown
   - **Reject:** Order cancelled, reassigned to next rider, warning message shown
   - **Timeout:** Sheet auto-closes after 30 seconds (no action taken)

4. **Post-Action:**
   - Dashboard refreshes
   - Order list updates
   - SnackBar shows result

## Technical Details

### Socket Event Data Structure
```dart
{
  'orderId': 123,
  'totalAmount': 450.00,
  'amount': 450.00,
  'address': {...},
  'paymentMode': 'COD',
  'timestamp': '2026-06-08T12:00:00.000Z'
}
```

### Timer Implementation
```dart
TweenAnimationBuilder<double>(
  tween: Tween(begin: 1.0, end: 0.0),
  duration: Duration(seconds: 30),
  onEnd: () => Navigator.pop(context),
  builder: (ctx, value, _) => CircularProgressIndicator(...)
)
```

### Audio Playback
```dart
try {
  _audioPlayer.play(AssetSource('sounds/new_order.mp3'));
} catch (e) {
  debugPrint('Failed to play notification sound: $e');
}
```

## Dependencies

Already included in `pubspec.yaml`:
- ✅ `audioplayers: ^6.1.0`
- ✅ `socket_io_client: ^2.0.3+1`

## Next Steps for User

### 1. Add Notification Sound
Download or create `new_order.mp3` and place in:
```
old_meatvo/assets/sounds/new_order.mp3
```

See `assets/sounds/README.md` for sound file requirements and resources.

### 2. Test the Flow
1. Ensure backend server is running
2. Create a new order as customer
3. Verify rider receives socket event
4. Check that bottom sheet appears with sound
5. Test Accept/Reject actions

### 3. Optional Customization

#### Change Timer Duration
Modify line in `NewOrderAlertSheet`:
```dart
duration: const Duration(seconds: 45),  // Change from 30
```

#### Customize Colors
Current brand color: `Color(0xFFC8102E)` (Meatvo red)

Update in `NewOrderAlertSheet` for different colors.

#### Adjust Button Sizes
Modify the `flex` property:
```dart
Expanded(flex: 2, ...)  // Accept button 2x width
```

## Error Handling

- ✅ Invalid order ID handling
- ✅ Network error handling for accept/reject
- ✅ Sound playback failure (graceful degradation)
- ✅ Context safety checks (mounted checks)

## Color Scheme

- **Primary Red:** `#C8102E`
- **Background:** `#EEEEEE` (timer track)
- **Text Secondary:** `#6B6B6B`

## Files Modified

1. ✅ `backend/src/modules/orders/orders.controller.js` (auto-assignment)
2. ✅ `old_meatvo/lib/screens/rider/rider_dashboard_screen.dart` (alert UI)
3. ✅ `old_meatvo/assets/sounds/README.md` (sound instructions)

## Status

- ✅ Backend auto-assignment implemented
- ✅ Rider alert UI implemented
- ✅ Sound directory created
- ⏳ Sound file to be added by user

---

**Implementation Date:** June 8, 2026  
**Backend:** Node.js + Socket.IO  
**Frontend:** Flutter 3.9.2

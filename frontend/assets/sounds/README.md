# Sound Assets

## Required File: new_order.mp3

### Download Instructions

1. **Visit**: https://freesound.org/people/InspectorJ/sounds/411749/
2. **Click**: "Download" button (you may need to create a free account)
3. **Save As**: `new_order.mp3`
4. **Place in**: `c:\project\MeatvoApp\old_meatvo\assets\sounds\new_order.mp3`

### Alternative Free Sound Sources

If the above link doesn't work, you can download a notification beep from:
- **Pixabay**: https://pixabay.com/sound-effects/search/notification/
- **Zapsplat**: https://www.zapsplat.com/sound-effect-category/notifications-and-alerts/
- **Freesound**: https://freesound.org/search/?q=notification+beep

### File Format
- **Format**: MP3
- **Duration**: 1-3 seconds recommended
- **Size**: Keep under 500KB for optimal app performance

### Usage in App
This sound plays when a new order is assigned to the rider via socket notification.

**File**: `rider_dashboard_screen.dart`
```dart
_audioPlayer.play(AssetSource('sounds/new_order.mp3'));
```

---

**Status**: ⚠️ File needs to be downloaded manually and placed in this directory

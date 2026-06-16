# Location Background Image

## Overview
The `location_bg.png` image is used as a subtle background in location-related screens to enhance the visual appeal and add depth to the illustration.

## Current Usage
This image appears in:
- Location Permission Screen (`location_permission_screen.dart`)
- Location Setup Screen (`location_setup_screen.dart`)
- Location Permission Dialog (`permission_dialog.dart`)

## Image Specifications
- **Format**: PNG (supports transparency)
- **Aspect Ratio**: Square (1:1) recommended
- **Colors**: Warm pink/coral tones matching Meatvo brand (#FFE8E5, #FFD4CF)
- **Style**: Soft, blurred, abstract
- **Opacity**: Image is displayed at 20% opacity in the app
- **Shape**: Displayed in a circular clip

## Customization
To replace with your own image:

1. Create or select a suitable image with these characteristics:
   - Subtle, not too busy (will be shown at low opacity)
   - Warm, inviting colors (preferably pink/coral/peachy tones)
   - Location/delivery/neighborhood theme (optional but recommended)
   - High resolution (at least 800x800px)

2. Replace the file at: `assets/images/location_bg.png`

3. The app will automatically use the new image (no code changes needed)

## Design Tips
- Keep details minimal - the image is just a background texture
- Avoid sharp contrasts or busy patterns
- The image should complement, not distract from the main illustration elements (house, pin, bag, shield)
- Consider warm tones that match the Meatvo brand color (#E53935)

## Technical Notes
- Image is loaded with error handling - if it fails to load, a solid color fallback is shown
- Displayed inside a circular clip (68% of illustration size)
- Layered behind the CustomPaint illustration elements
- Always centered within the illustration area

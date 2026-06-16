// =============================================================================
// responsive_guide.dart
// -----------------------------------------------------------------------------
// MeatvoApp — Responsive Design Contract (READ ONLY DOCUMENTATION FILE)
//
// This file intentionally contains NO executable code. It exists purely as
// the canonical rulebook for how every screen, widget, and bottom sheet in
// this project MUST handle sizing, spacing, fonts, and safe areas.
//
// All sizing helpers referenced below (`R.init`, `R.sw`, `R.sh`, `R.fontSize`,
// `R.isSmallScreen`, `sheetBottomPadding`, etc.) live in:
//     lib/utils/responsive_helper.dart
//
// If you are touching ANY UI file in this project, follow these rules without
// exception. Reviewers will reject PRs that violate them.
// =============================================================================


// -----------------------------------------------------------------------------
// RULE 1 — ALWAYS initialize R at the top of every build() method
// -----------------------------------------------------------------------------
// Before you call R.sw(...) or R.sh(...) inside a build() method, you MUST
// call R.init(context) on the very first line. This caches the MediaQueryData
// so the percent-based helpers can resolve screen dimensions reliably.
//
// CORRECT:
//   @override
//   Widget build(BuildContext context) {
//     R.init(context);                       // <-- first line, no exceptions
//     return Scaffold( ... );
//   }
//
// WRONG:
//   @override
//   Widget build(BuildContext context) {
//     return Container(width: R.sw(50));     // <-- R was never initialized
//   }
//
// NOTE: If you are calling the helpers from inside a Builder, LayoutBuilder,
// or any nested context, prefer passing `context` explicitly:
//     R.sw(50, context)   //  safe even without R.init
//     R.sh(2,  context)   //  safe even without R.init
// -----------------------------------------------------------------------------


// -----------------------------------------------------------------------------
// RULE 2 — Use R.sw(percent) for widths, R.sh(percent) for heights
// -----------------------------------------------------------------------------
// The `percent` argument is on a 0–100 scale (NOT 0.0–1.0). Think of it as
// "percentage of the screen".
//
//     R.sw(100)  -> full screen width
//     R.sw(50)   -> half screen width
//     R.sw(4)    -> 4% of screen width (good for horizontal gutters)
//     R.sh(2)    -> 2% of screen height (good for vertical spacing)
//     R.sh(8)    -> 8% of screen height (good for header / hero blocks)
//
// CORRECT:
//   SizedBox(height: R.sh(2, context))
//   Container(width: R.sw(90, context))
//   Padding(padding: EdgeInsets.symmetric(horizontal: R.sw(4, context)))
//
// WRONG:
//   R.sw(0.5)   //  0.5% of screen width — almost certainly a bug
//   R.sh(0.02)  //  0.02% of screen height — almost certainly a bug
//
// If you find yourself reaching for a fractional API (0.0–1.0), you are using
// the legacy `sw(context, fraction)` / `sh(context, fraction)` helpers. Those
// exist only for backwards compatibility — DO NOT use them in new code.
// -----------------------------------------------------------------------------


// -----------------------------------------------------------------------------
// RULE 3 — Use R.fontSize(base, context) for ALL Text fontSize values
// -----------------------------------------------------------------------------
// Raw `fontSize: 14` is forbidden. Every Text style must scale with the
// device width so small phones don’t overflow and large phones don’t look
// childish. The helper clamps between 0.85x and 1.2x of the base size.
//
// CORRECT:
//   Text(
//     'Add to cart',
//     style: TextStyle(fontSize: R.fontSize(14, context)),
//   )
//
//   TextStyle(
//     fontSize: R.fontSize(20, context),
//     fontWeight: FontWeight.w700,
//   )
//
// WRONG:
//   Text('Add to cart', style: TextStyle(fontSize: 14))
//   Text('Total', style: TextStyle(fontSize: 20 * MediaQuery.of(context).textScaleFactor))
//
// This rule applies to every Text widget, theme override, and inline
// TextStyle in the codebase — including AppBar titles, snackbars, and
// bottom-sheet headers.
// -----------------------------------------------------------------------------


// -----------------------------------------------------------------------------
// RULE 4 — Use R.isSmallScreen(context) for conditional small-phone layouts
// -----------------------------------------------------------------------------
// A "small screen" is defined as a logical height of less than 600px (think
// older budget Androids common in the Indian market — our primary audience).
// On those devices, hide non-essential rows, shrink hero banners, and prefer
// single-column layouts.
//
// CORRECT:
//   if (R.isSmallScreen(context)) {
//     return _CompactProductCard(product: p);
//   }
//   return _StandardProductCard(product: p);
//
//   SizedBox(height: R.isSmallScreen(context) ? R.sh(1, context) : R.sh(2, context))
//
// WRONG:
//   if (MediaQuery.of(context).size.height < 600) { ... }   //  duplicate logic
//   if (Platform.isAndroid) { ... }                          //  wrong dimension
//
// Always go through R.isSmallScreen so the threshold stays in one place.
// -----------------------------------------------------------------------------


// -----------------------------------------------------------------------------
// RULE 5 — For bottom sheets, use sheetBottomPadding(context)
// -----------------------------------------------------------------------------
// Bottom sheets must respect the keyboard inset, the home indicator / gesture
// bar, AND leave breathing room. Hardcoding `bottom: 16` will cut off the
// last button on phones with a gesture bar, and clip behind the keyboard on
// forms.
//
// Use `sheetBottomPadding(context)` (defined in responsive_helper.dart) or
// `modalSheetInsets(context)` if you need full EdgeInsets.
//
// CORRECT:
//   Padding(
//     padding: EdgeInsets.only(bottom: sheetBottomPadding(context)),
//     child: PremiumButton(label: 'Confirm', onPressed: _submit),
//   )
//
//   Container(
//     padding: modalSheetInsets(context, horizontal: 20, top: 20),
//     child: _sheetContent(),
//   )
//
// WRONG:
//   Padding(padding: EdgeInsets.only(bottom: 16), child: ...)   //  clipped by keyboard
//   Padding(padding: EdgeInsets.only(bottom: 24), child: ...)   //  ignores gesture bar
//
// Forms inside bottom sheets must additionally wrap their scroll body in the
// keyboardAwareForm() helper so the input stays above the keyboard.
// -----------------------------------------------------------------------------


// -----------------------------------------------------------------------------
// RULE 6 — Never hardcode pixel values for spacing / sizing
// -----------------------------------------------------------------------------
// Hardcoded pixel literals like `SizedBox(height: 16)` or `padding:
// EdgeInsets.all(24)` look correct on the developer's pixel-9-class phone
// and break on every other device.
//
// Translate logical pixels into a screen-height percent using `R.sh` (and
// `R.sw` for horizontal). A rough conversion table for a 720-tall design:
//
//     ~ 8  px ≈ R.sh(1, context)
//     ~16  px ≈ R.sh(2, context)
//     ~24  px ≈ R.sh(3, context)
//     ~32  px ≈ R.sh(4, context)
//
// CORRECT:
//   SizedBox(height: R.sh(2, context))
//   Padding(padding: EdgeInsets.symmetric(
//     horizontal: R.sw(4, context),
//     vertical:   R.sh(1.5, context),
//   ))
//
// WRONG:
//   SizedBox(height: 16)
//   Padding(padding: EdgeInsets.all(24))
//   const SizedBox(height: 8)
//
// EXCEPTIONS (the only places hardcoded numbers are allowed):
//   - Border radii (e.g. BorderRadius.circular(12))
//   - Border / stroke widths (e.g. width: 1)
//   - Icon sizes inside design-system atoms (already tokenized)
//   - Animation curves / durations
// Everything else MUST go through R.sh / R.sw.
// -----------------------------------------------------------------------------


// -----------------------------------------------------------------------------
// RULE 7 — SafeArea MUST wrap every Scaffold body
// -----------------------------------------------------------------------------
// Every screen-level Scaffold body must be wrapped in a SafeArea so content
// never lands under the notch, status bar, or gesture indicator. This is
// non-negotiable, even when you "think" the AppBar covers it.
//
// CORRECT:
//   return Scaffold(
//     appBar: PremiumAppBar(title: 'Cart'),
//     body: SafeArea(
//       child: Column( ... ),
//     ),
//   );
//
//   return Scaffold(
//     body: SafeArea(
//       top: true,
//       bottom: false,                       // disable only when you know why
//       child: HomeBody(),
//     ),
//   );
//
// WRONG:
//   return Scaffold(body: Column(children: [...]));   //  notch overlap on iPhones
//   return Scaffold(body: ListView(...));              //  status-bar bleed on Android
//
// NOTES:
//   - Bottom sheets (showModalBottomSheet) are NOT Scaffolds; their bottom
//     safety is handled by `sheetBottomPadding(context)` from RULE 5.
//   - If you turn off `bottom: false` on SafeArea, you are responsible for
//     padding the bottom yourself using `R.bottomPadding(context)`.
// -----------------------------------------------------------------------------


// =============================================================================
// QUICK CHECKLIST (copy-paste into PR descriptions)
// -----------------------------------------------------------------------------
//   [ ] R.init(context) is the first line of every build()
//   [ ] All widths use R.sw(percent) where percent is 0–100
//   [ ] All heights use R.sh(percent) where percent is 0–100
//   [ ] Every Text fontSize routes through R.fontSize(base, context)
//   [ ] Small-screen branches use R.isSmallScreen(context)
//   [ ] Bottom sheets use sheetBottomPadding / modalSheetInsets
//   [ ] No hardcoded SizedBox / EdgeInsets pixel values
//   [ ] Every Scaffold body is wrapped in SafeArea
// =============================================================================

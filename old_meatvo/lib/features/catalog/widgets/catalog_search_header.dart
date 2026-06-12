import 'package:flutter/material.dart';

import '../../../design_system/theme/meatvo_theme_extensions.dart';
import '../../../ui/atoms/safe_icon_tap.dart';

/// Pinned search header used inside `CatalogScreen`.
///
/// Renders the search field + optional back button. Designed to be used
/// inside a `SliverPersistentHeader` via [CatalogSearchHeaderDelegate] —
/// using `SliverAppBar.flexibleSpace` for a widget that contains a
/// `TextField + Expanded + IconButton` triggers
/// "BoxConstraints forces an infinite width" on some devices, so we drive
/// the layout ourselves with a delegate that owns the extent.
class CatalogSearchHeader extends StatefulWidget {
  const CatalogSearchHeader({
    super.key,
    required this.controller,
    required this.onChanged,
    this.showBack = false,
  });

  /// Toolbar height (excludes the status-bar inset).
  ///
  /// 56 (field) + 8 (top inner pad) + 8 (bottom inner pad) = 72.
  static const double kToolbarHeight = 72;

  static const double _fieldHeight = 56;

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool showBack;

  @override
  State<CatalogSearchHeader> createState() => _CatalogSearchHeaderState();
}

class _CatalogSearchHeaderState extends State<CatalogSearchHeader> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final hasText = widget.controller.text.isNotEmpty;

    return Material(
      color: mv.surfaceCard,
      elevation: 0,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          widget.showBack ? 4 : mv.spacing.md,
          mv.spacing.xs,
          mv.spacing.md,
          mv.spacing.xs,
        ),
        // IMPORTANT: both action icons here used to be `IconButton`s. The
        // back button sat in a 56-px row and the clear button sat inside
        // the TextField's suffix slot — both contexts that fight the
        // `_RenderInputPadding(48×48)` IconButton injects. We replaced
        // both with `SafeIconTap` which has no input-padding and therefore
        // cannot crash on tight rows.
        child: Row(
          children: [
            if (widget.showBack)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: SafeIconTap(
                  icon: Icons.arrow_back_rounded,
                  color: mv.textPrimary,
                  size: 44,
                  iconSize: 22,
                  onTap: () => Navigator.of(context).maybePop(),
                ),
              ),
            Expanded(
              child: SizedBox(
                height: CatalogSearchHeader._fieldHeight,
                child: TextField(
                  controller: widget.controller,
                  onChanged: widget.onChanged,
                  decoration: InputDecoration(
                    hintText: 'Search chicken, mutton, fish...',
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: mv.textMuted,
                    ),
                    suffixIcon: hasText
                        ? Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: SafeIconTap(
                              icon: Icons.close_rounded,
                              color: mv.textMuted,
                              onTap: () {
                                widget.controller.clear();
                                widget.onChanged('');
                              },
                            ),
                          )
                        : null,
                    suffixIconConstraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sliver delegate that hosts [CatalogSearchHeader] with the status-bar
/// inset baked in. Using a delegate (instead of `SliverAppBar.flexibleSpace`)
/// guarantees the inner `Row > Expanded > TextField` always receives a
/// finite width constraint, even on devices that mis-handle the
/// `flexibleSpace` slot during the first frame.
class CatalogSearchHeaderDelegate extends SliverPersistentHeaderDelegate {
  CatalogSearchHeaderDelegate({
    required this.topPadding,
    required this.controller,
    required this.onChanged,
    this.showBack = false,
  });

  final double topPadding;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool showBack;

  @override
  double get minExtent => topPadding + CatalogSearchHeader.kToolbarHeight;

  @override
  double get maxExtent => minExtent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    // We deliberately do NOT wrap in Column here. A Column inside the sliver
    // can collapse the cross-axis width to its child's intrinsic width, which
    // bubbles `infinite-width` constraints down to the inner TextField on
    // certain devices. Instead we use ColoredBox + Padding so the persistent
    // header occupies the full sliver crossAxisExtent.
    return ColoredBox(
      color: context.meatvo.surfaceCard,
      child: Padding(
        padding: EdgeInsets.only(top: topPadding),
        child: SizedBox(
          height: CatalogSearchHeader.kToolbarHeight,
          width: double.infinity,
          child: CatalogSearchHeader(
            controller: controller,
            onChanged: onChanged,
            showBack: showBack,
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant CatalogSearchHeaderDelegate oldDelegate) {
    return topPadding != oldDelegate.topPadding ||
        showBack != oldDelegate.showBack ||
        controller != oldDelegate.controller ||
        onChanged != oldDelegate.onChanged;
  }
}

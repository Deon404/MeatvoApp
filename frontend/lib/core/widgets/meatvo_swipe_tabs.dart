import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design_system/theme/meatvo_theme_extensions.dart';
import '../../design_system/tokens/meatvo_colors.dart';

/// A single tab entry for [MeatvoSwipeTabs].
class MeatvoTabItem {
  const MeatvoTabItem({
    required this.label,
    this.enabled = true,
  });

  final String label;
  final bool enabled;
}

/// Swipeable tab bar with animated pill indicator and [TabBarView] body.
///
/// The parent must own the [controller] (typically via
/// [SingleTickerProviderStateMixin]) and call [TabController.addListener]
/// for side-effects such as data reloads.
class MeatvoSwipeTabs extends StatelessWidget {
  const MeatvoSwipeTabs({
    super.key,
    required this.tabs,
    required this.children,
    required this.controller,
    this.isScrollable = false,
    this.onIndexChanged,
    this.headerPadding,
    this.allowDisabledTabs = false,
  });

  final List<MeatvoTabItem> tabs;
  final List<Widget> children;
  final TabController controller;
  final bool isScrollable;
  final ValueChanged<int>? onIndexChanged;
  final EdgeInsetsGeometry? headerPadding;
  final bool allowDisabledTabs;

  void _handleTabTapped(int index) {
    if (!allowDisabledTabs && !tabs[index].enabled) return;
    controller.animateTo(index);
  }

  @override
  Widget build(BuildContext context) {
    assert(
      tabs.length == children.length,
      'MeatvoSwipeTabs requires tabs and children to have the same length',
    );
    assert(
      tabs.length == controller.length,
      'MeatvoSwipeTabs tab count must match TabController length',
    );

    final mv = context.meatvo;
    final padding = headerPadding ??
        EdgeInsets.fromLTRB(
          mv.spacing.md,
          mv.spacing.sm,
          mv.spacing.md,
          mv.spacing.xs,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: padding,
          child: _MeatvoTabBar(
            tabs: tabs,
            controller: controller,
            isScrollable: isScrollable,
            onTabTapped: _handleTabTapped,
          ),
        ),
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollEndNotification &&
                  controller.indexIsChanging == false) {
                final index = controller.index;
                if (allowDisabledTabs || tabs[index].enabled) {
                  onIndexChanged?.call(index);
                }
              }
              return false;
            },
            child: TabBarView(
              controller: controller,
              physics: const PageScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              children: children,
            ),
          ),
        ),
      ],
    );
  }
}

/// Call from the parent's [TabController] listener to enforce enabled tabs
/// and fire [onIndexChanged] with haptic feedback.
class MeatvoSwipeTabsHelper {
  MeatvoSwipeTabsHelper({
    required this.tabs,
    required this.controller,
    this.onIndexChanged,
    this.snapBackFromDisabled = true,
  });

  final List<MeatvoTabItem> tabs;
  final TabController controller;
  final ValueChanged<int>? onIndexChanged;
  final bool snapBackFromDisabled;
  int lastReportedIndex = 0;

  void handleTabChange() {
    if (controller.indexIsChanging) return;

    final index = controller.index;
    if (index < 0 || index >= tabs.length) return;

    if (!tabs[index].enabled) {
      if (!snapBackFromDisabled) {
        if (index == lastReportedIndex) return;
        lastReportedIndex = index;
        HapticFeedback.selectionClick();
        onIndexChanged?.call(index);
        return;
      }

      final previous = lastReportedIndex;
      final forward = index > previous;
      final fallback = _nearestEnabledIndex(previous, direction: forward ? 1 : -1) ??
          _nearestEnabledIndex(previous, direction: forward ? -1 : 1) ??
          previous;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.animateTo(fallback);
      });
      return;
    }

    if (index == lastReportedIndex) return;
    lastReportedIndex = index;
    HapticFeedback.selectionClick();
    onIndexChanged?.call(index);
  }

  int? _nearestEnabledIndex(int fromIndex, {required int direction}) {
    for (var step = 1; step <= tabs.length; step++) {
      final candidate = fromIndex + (step * direction);
      if (candidate < 0 || candidate >= tabs.length) return null;
      if (tabs[candidate].enabled) return candidate;
    }
    return null;
  }
}

class _MeatvoTabBar extends StatelessWidget {
  const _MeatvoTabBar({
    required this.tabs,
    required this.controller,
    required this.isScrollable,
    required this.onTabTapped,
  });

  final List<MeatvoTabItem> tabs;
  final TabController controller;
  final bool isScrollable;
  final ValueChanged<int> onTabTapped;

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;

    final tabBar = TabBar(
      controller: controller,
      isScrollable: isScrollable,
      tabAlignment: isScrollable ? TabAlignment.start : TabAlignment.fill,
      dividerColor: Colors.transparent,
      indicatorSize: TabBarIndicatorSize.tab,
      indicator: BoxDecoration(
        color: mv.brandPrimary,
        borderRadius: BorderRadius.circular(mv.radii.pill),
        boxShadow: [
          BoxShadow(
            color: mv.brandPrimary.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      labelColor: MeatvoColors.white,
      unselectedLabelColor: mv.textSecondary,
      labelStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      splashFactory: NoSplash.splashFactory,
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      labelPadding: EdgeInsets.symmetric(
        horizontal: isScrollable ? mv.spacing.sm : 0,
      ),
      onTap: onTabTapped,
      tabs: [
        for (final tab in tabs)
          Tab(
            child: Opacity(
              opacity: tab.enabled ? 1 : 0.45,
              child: Text(tab.label),
            ),
          ),
      ],
    );

    if (isScrollable) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: mv.surfaceCard,
          borderRadius: BorderRadius.circular(mv.radii.pill),
          border: Border.all(color: mv.border),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: tabBar,
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: mv.surfaceCard,
        borderRadius: BorderRadius.circular(mv.radii.pill),
        border: Border.all(color: mv.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: tabBar,
      ),
    );
  }
}

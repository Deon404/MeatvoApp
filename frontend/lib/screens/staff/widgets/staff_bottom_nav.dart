import 'package:flutter/material.dart';

import '../staff_theme.dart';

class StaffBottomNav extends StatelessWidget {
  const StaffBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _kitchenIconAsset = 'assets/icons/staff_kitchen.png';

  static const _labels = ['Butcher', 'Profile'];
  static const _profileIconSize = 24.0;
  static const _butcherIconSize = 38.0;
  static const _iconLabelGap = 2.0;

  Widget _buildIcon(int index, Color color) {
    return SizedBox(
      height: _butcherIconSize,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: index == 0
            ? Image.asset(
                _kitchenIconAsset,
                width: _butcherIconSize,
                height: _butcherIconSize,
                fit: BoxFit.contain,
                color: color,
                colorBlendMode: BlendMode.srcIn,
                filterQuality: FilterQuality.high,
              )
            : Icon(
                Icons.person_rounded,
                color: color,
                size: _profileIconSize,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: StaffColors.navBar,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(_labels.length, (index) {
              final selected = index == currentIndex;
              final color =
                  selected ? StaffColors.accent : StaffColors.textSecondary;

              return Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onTap(index),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildIcon(index, color),
                        const SizedBox(height: _iconLabelGap),
                        Text(
                          _labels[index],
                          style: StaffTextStyles.caption.copyWith(
                            color: color,
                            fontWeight:
                                selected ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../constants/home_strings.dart';
import '../../design_system/theme/meatvo_theme_extensions.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final top = MediaQuery.paddingOf(context).top;

    return Positioned(
      top: top,
      left: 0,
      right: 0,
      child: Material(
        color: mv.brandPrimaryDark,
        elevation: 0,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: mv.spacing.md,
            vertical: mv.spacing.xs,
          ),
          child: Row(
            children: [
              const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
              SizedBox(width: mv.spacing.xs),
              Expanded(
                child: Text(
                  HomeStrings.offlineBanner,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Colors.white,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

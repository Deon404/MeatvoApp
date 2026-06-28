import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../support/support_contact_sheet.dart';

/// Help button for order tracking header — opens support contact sheet.
class OrderTrackingHelpButton extends StatelessWidget {
  const OrderTrackingHelpButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => showSupportContactSheet(context),
      icon: const Icon(Icons.support_agent_rounded, color: AppColors.white),
      tooltip: 'Help & Support',
    );
  }
}

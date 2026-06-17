import 'package:flutter/material.dart';

import '../../config/support_config.dart';
import '../../core/constants/app_constants.dart';
import '../../services/contact_action_service.dart';

/// Help button for order tracking header — calls support.
class OrderTrackingHelpButton extends StatelessWidget {
  const OrderTrackingHelpButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => ContactActionService().makeCall(SupportConfig.phone),
      icon: const Icon(Icons.support_agent_rounded, color: AppColors.white),
      tooltip: 'Help & Support',
    );
  }
}

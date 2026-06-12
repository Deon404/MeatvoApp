import 'package:flutter/material.dart';

import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/onboarding/post_auth_gate_screen.dart';
import '../screens/rider/rider_dashboard_screen.dart';
import '../utils/role_access.dart' show isDeliveryPartnerRole;

/// Central post-auth routing — customers go through location gate first.
Widget destinationAfterAuth({String? role}) {
  final normalized = role?.toLowerCase().trim() ?? '';
  if (normalized == 'admin') return const AdminDashboardScreen();
  if (isDeliveryPartnerRole(role)) {
    return const RiderDashboardScreen();
  }
  return const PostAuthGateScreen();
}

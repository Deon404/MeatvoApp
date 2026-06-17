import 'package:flutter/material.dart';

import '../app_navigator_key.dart';
import '../navigation/app_destinations.dart';
import '../services/auth_service.dart';
import '../services/rider_service.dart';
import 'role_access_exception.dart';

bool isDeliveryPartnerRole(String? role) {
  final normalized = role?.toLowerCase().trim() ?? '';
  return normalized == 'rider' ||
      normalized == 'delivery' ||
      normalized == 'delivery_partner';
}

bool isStaffRole(String? role) {
  return role?.toLowerCase().trim() == 'staff';
}

String roleAccessDeniedMessage(String _) {
  return 'This section is not available.';
}

/// Refresh profile from backend and navigate to the correct home screen.
Future<void> redirectToRoleHome({String? role, String? message}) async {
  String? resolvedRole = role;
  if (resolvedRole == null) {
    final user = await AuthService().getMe();
    resolvedRole = user?.role;
  }

  final nav = appNavigatorKey.currentState;
  if (nav == null) return;

  if (message != null) {
    final messenger = ScaffoldMessenger.maybeOf(nav.context);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange.shade800,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  nav.pushAndRemoveUntil(
    MaterialPageRoute<void>(
      builder: (_) => destinationAfterAuth(role: resolvedRole),
    ),
    (_) => false,
  );
}

Future<void> handleRoleAccessDenied(RoleAccessException error) async {
  await redirectToRoleHome(role: error.role);
}

/// Returns false and redirects when the user is not a delivery partner.
Future<bool> ensureDeliveryPartnerAccess(BuildContext context) async {
  final user = await AuthService().getMe();
  if (user == null) {
    await AuthService().signOut();
    if (context.mounted) {
      await redirectToRoleHome(message: 'Session expired. Please sign in again.');
    }
    return false;
  }

  if (isDeliveryPartnerRole(user.role)) {
    return true;
  }

  try {
    await RiderService().getRiderProfile();
    return true;
  } catch (_) {
    // No approved delivery partner profile.
  }

  if (context.mounted) {
    await redirectToRoleHome(role: user.role);
  }
  return false;
}

/// Returns false and redirects when the user is not kitchen staff.
Future<bool> ensureStaffAccess(BuildContext context) async {
  final user = await AuthService().getMe();
  if (user == null) {
    await AuthService().signOut();
    if (context.mounted) {
      await redirectToRoleHome(message: 'Session expired. Please sign in again.');
    }
    return false;
  }

  if (isStaffRole(user.role)) {
    return true;
  }

  if (context.mounted) {
    await redirectToRoleHome(role: user.role);
  }
  return false;
}

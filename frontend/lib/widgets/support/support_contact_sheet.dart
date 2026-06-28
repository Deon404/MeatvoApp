import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/support_config.dart';
import '../../core/constants/app_constants.dart';

/// Bottom sheet with Meatvo support phone, email, and FAQ.
Future<void> showSupportContactSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Help & Support',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.call_outlined, color: AppColors.primary),
              title: const Text('Call us'),
              subtitle: Text(SupportConfig.phoneDisplay),
              onTap: () {
                Navigator.pop(sheetContext);
                launchUrl(Uri.parse('tel:${SupportConfig.phone}'));
              },
            ),
            ListTile(
              leading: const Icon(Icons.mail_outline, color: AppColors.primary),
              title: const Text('Email'),
              subtitle: Text(SupportConfig.email),
              onTap: () {
                Navigator.pop(sheetContext);
                launchUrl(Uri.parse('mailto:${SupportConfig.email}'));
              },
            ),
            ListTile(
              leading: const Icon(Icons.help_outline, color: AppColors.primary),
              title: const Text('FAQ'),
              subtitle: const Text('Common questions about orders & delivery'),
              onTap: () {
                Navigator.pop(sheetContext);
                launchUrl(
                  Uri.parse(SupportConfig.faqUrl),
                  mode: LaunchMode.externalApplication,
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

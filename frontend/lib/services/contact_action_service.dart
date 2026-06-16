import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Service for handling contact actions (call, SMS)
class ContactActionService {
  /// Launch phone dialer with the provided phone number
  Future<bool> makeCall(String phoneNumber) async {
    try {
      final cleanNumber = _cleanPhoneNumber(phoneNumber);
      if (cleanNumber.isEmpty) {
        throw Exception('Invalid phone number');
      }

      final uri = Uri(scheme: 'tel', path: cleanNumber);
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri);
      } else {
        throw Exception('Could not launch phone dialer');
      }
    } catch (e) {
      debugPrint('Error making call: $e');
      return false;
    }
  }

  /// Open SMS app with pre-filled phone number
  Future<bool> sendSMS(String phoneNumber, {String? message}) async {
    try {
      final cleanNumber = _cleanPhoneNumber(phoneNumber);
      if (cleanNumber.isEmpty) {
        throw Exception('Invalid phone number');
      }

      final uri = Uri(
        scheme: 'sms',
        path: cleanNumber,
        queryParameters: message != null ? {'body': message} : null,
      );

      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri);
      } else {
        throw Exception('Could not launch SMS app');
      }
    } catch (e) {
      debugPrint('Error sending SMS: $e');
      return false;
    }
  }

  /// Show error dialog when contact action fails
  void showContactError(BuildContext context, String action, String phoneNumber) {
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Unable to $action'),
        content: Text(
          'Could not open the $action app. Please try again or contact $phoneNumber manually.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Clean phone number by removing spaces, dashes, and parentheses
  String _cleanPhoneNumber(String phoneNumber) {
    return phoneNumber.replaceAll(RegExp(r'[\s\-\(\)]'), '');
  }

  /// Validate phone number format
  bool isValidPhoneNumber(String phoneNumber) {
    final cleanNumber = _cleanPhoneNumber(phoneNumber);
    // Basic validation: at least 10 digits
    return cleanNumber.length >= 10 && RegExp(r'^\+?\d+$').hasMatch(cleanNumber);
  }
}

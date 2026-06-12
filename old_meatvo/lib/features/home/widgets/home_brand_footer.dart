import 'package:flutter/material.dart';

/// Brand footer with Meatvo logo and slogan (similar to Blinkit style).
class HomeBrandFooter extends StatelessWidget {
  const HomeBrandFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(
        children: [
          // Divider line
          Container(
            height: 1,
            color: Colors.grey.shade200,
          ),
          const SizedBox(height: 24),
          // Meatvo brand name
          Text(
            'MEATVO',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.red.shade600,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          // Tagline
          Text(
            '100% Fresh • Store to Home • Same Day Delivery',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade400,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

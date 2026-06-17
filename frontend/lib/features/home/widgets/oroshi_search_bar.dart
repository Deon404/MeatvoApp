import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Oroshi-style static search bar — taps navigate to SearchScreen.
class OroshiSearchBar extends StatelessWidget {
  const OroshiSearchBar({
    super.key,
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFEEEEEE),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              Icon(
                Icons.search_rounded,
                color: Colors.grey.shade500,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Search for chicken, fish, eggs...',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              Icon(
                Icons.mic_none_rounded,
                color: Colors.grey.shade500,
                size: 20,
              ),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}

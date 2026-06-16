import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_constants.dart';

class MeatvoLogoText extends StatelessWidget {
  const MeatvoLogoText({super.key, this.fontSize = 32});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Meatvo',
      style: GoogleFonts.poppins(
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }
}

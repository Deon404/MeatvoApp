import 'package:flutter/material.dart';

import 'legal_document_screen.dart';

class AboutMeatvoScreen extends StatelessWidget {
  const AboutMeatvoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalDocumentScreen(
      title: 'About Meatvo',
      sections: [
        LegalSection(
          title: 'Our Promise',
          body: 'Meatvo delivers fresh, hygienically packed meat '
              'directly from trusted local sources to your '
              'doorstep in Bokaro, Jharkhand.',
        ),
        LegalSection(
          title: 'Halal Certification',
          body: 'All meat sold on Meatvo is sourced from '
              'halal-certified suppliers and processed following '
              'Islamic halal guidelines. Our chicken and mutton '
              'undergo proper halal slaughtering practices, '
              'ensuring compliance with religious dietary '
              'requirements.',
        ),
        LegalSection(
          title: 'FSSAI License',
          body: 'Meatvo operates under a valid FSSAI (Food Safety '
              'and Standards Authority of India) license, ensuring '
              'our food handling, storage, and delivery practices '
              'meet national food safety standards. '
              'License No: 21125181000115',
        ),
        LegalSection(
          title: 'Freshness Standards',
          body: 'We do not stock pre-cut meat for extended '
              'periods. All orders are packed fresh on the day '
              'of delivery to ensure maximum quality and safety.',
        ),
        LegalSection(
          title: 'Quality Checks',
          body: 'Every batch is inspected for freshness, color, '
              'and texture before packing. We maintain a strict '
              'cold chain from sourcing to delivery.',
        ),
      ],
    );
  }
}

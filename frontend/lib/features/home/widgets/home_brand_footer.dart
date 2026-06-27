import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../services/app_info_service.dart';

/// Brand footer — MEATVO wordmark, made-with-love tagline, pubspec version.
class HomeBrandFooter extends StatefulWidget {
  const HomeBrandFooter({
    super.key,
    this.align = CrossAxisAlignment.start,
    this.textAlign = TextAlign.start,
  });

  final CrossAxisAlignment align;
  final TextAlign textAlign;

  @override
  State<HomeBrandFooter> createState() => _HomeBrandFooterState();
}

class _HomeBrandFooterState extends State<HomeBrandFooter> {
  late final Future<AppInfo> _appInfoFuture;

  @override
  void initState() {
    super.initState();
    _appInfoFuture = AppInfoService().fetchAppInfo();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 48),
      child: FutureBuilder<AppInfo>(
        future: _appInfoFuture,
        builder: (context, snapshot) {
          final version = snapshot.data?.appVersion;

          return Column(
            crossAxisAlignment: widget.align,
            children: [
              Text(
                'MEATVO',
                textAlign: widget.textAlign,
                style: GoogleFonts.poppins(
                  fontSize: 52,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMuted.withValues(alpha: 0.55),
                  letterSpacing: -1,
                  height: 1,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: widget.align == CrossAxisAlignment.center
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  Text(
                    'Meatvo made with love ',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textMuted,
                      height: 1.2,
                    ),
                  ),
                  const Icon(
                    Icons.favorite,
                    size: 14,
                    color: AppColors.primary,
                  ),
                ],
              ),
              if (version != null) ...[
                const SizedBox(height: 6),
                Text(
                  'ver. $version',
                  textAlign: widget.textAlign,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textMuted.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

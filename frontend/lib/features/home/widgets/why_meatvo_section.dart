import 'package:flutter/material.dart';

import '../../../constants/home_strings.dart';
import '../../../design_system/theme/meatvo_theme_extensions.dart';
import '../../../design_system/tokens/meatvo_durations.dart';
import '../../../ui/shells/section_header.dart';

class WhyMeatvoSection extends StatelessWidget {
  const WhyMeatvoSection({super.key});

  static const _items = [
    _WhyItem(
      icon: Icons.ac_unit_rounded,
      title: 'Cold-chain fresh',
      subtitle: 'Packed chilled, delivered fast',
      color: Color(0xFF2D6A4F),
    ),
    _WhyItem(
      icon: Icons.verified_user_rounded,
      title: 'Trusted sourcing',
      subtitle: 'Hygienic cuts from vetted partners',
      color: Color(0xFFB31217),
    ),
    _WhyItem(
      icon: Icons.schedule_rounded,
      title: 'Slots that fit you',
      subtitle: 'Same-day delivery in your area',
      color: Color(0xFF8B5E3C),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final listHeight = (152 * textScale).clamp(132.0, 180.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: HomeStrings.whyMeatvoTitle),
        SizedBox(height: mv.spacing.sm),
        SizedBox(
          height: listHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: mv.spacing.md),
            itemCount: _items.length,
            separatorBuilder: (_, __) => SizedBox(width: mv.spacing.sm),
            itemBuilder: (context, index) {
              final item = _items[index];
              return _WhyCard(item: item);
            },
          ),
        ),
        SizedBox(height: mv.spacing.md),
      ],
    );
  }
}

class _WhyItem {
  const _WhyItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
}

class _WhyCard extends StatefulWidget {
  const _WhyCard({required this.item});

  final _WhyItem item;

  @override
  State<_WhyCard> createState() => _WhyCardState();
}

class _WhyCardState extends State<_WhyCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final item = widget.item;

    return GestureDetector(
      onTapDown: (_) => setState(() => _hovered = true),
      onTapUp: (_) => setState(() => _hovered = false),
      onTapCancel: () => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 0.97 : 1,
        duration: MeatvoDurations.fast,
        curve: MeatvoDurations.curve,
        child: Container(
          width: 200,
          padding: EdgeInsets.all(mv.spacing.md),
          decoration: BoxDecoration(
            color: mv.surfaceCard,
            borderRadius: BorderRadius.circular(mv.radii.lg),
            border: Border.all(color: mv.border),
            boxShadow: mv.shadowSm,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                mv.surfaceCard,
                item.color.withValues(alpha: 0.06),
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(mv.radii.sm),
                ),
                child: Icon(item.icon, color: item.color, size: 22),
              ),
              SizedBox(height: mv.spacing.sm),
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: mv.textPrimary,
                    ),
              ),
              SizedBox(height: mv.spacing.xxs),
              Text(
                item.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: mv.textSecondary,
                      height: 1.3,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../design_system/theme/meatvo_theme_extensions.dart';
import '../../../utils/responsive_helper.dart';
import '../../../ui/atoms/meatvo_chip.dart';

class CatalogFilterSheet extends StatelessWidget {
  const CatalogFilterSheet({
    super.key,
    required this.selectedSort,
    required this.onApply,
  });

  final String selectedSort;
  final ValueChanged<String> onApply;

  static const sortOptions = [
    'All',
    'Price ↑',
    'Weight',
    'Offers',
    'In Stock',
  ];

  static Future<String?> show(
    BuildContext context, {
    required String selectedSort,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => CatalogFilterSheet(
        selectedSort: selectedSort,
        onApply: (sort) => Navigator.of(ctx).pop(sort),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    var localSort = selectedSort;

    return StatefulBuilder(
      builder: (context, setState) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            mv.spacing.md,
            mv.spacing.sm,
            mv.spacing.md,
            sheetBottomPadding(context, extra: mv.spacing.md),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: mv.border,
                    borderRadius: BorderRadius.circular(mv.radii.pill),
                  ),
                ),
              ),
              SizedBox(height: mv.spacing.md),
              Text(
                'Sort & filter',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              SizedBox(height: mv.spacing.md),
              Wrap(
                spacing: mv.spacing.xs,
                runSpacing: mv.spacing.xs,
                children: sortOptions.map((option) {
                  return MeatvoChip(
                    label: option,
                    selected: localSort == option,
                    onTap: () => setState(() => localSort = option),
                  );
                }).toList(),
              ),
              SizedBox(height: mv.spacing.lg),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    onApply(localSort);
                  },
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';

import '../../config/google_maps_setup.dart';
import '../../core/constants/app_constants.dart';
import '../../design_system/tokens/meatvo_spacing.dart';
import '../../services/maps_service.dart';
import '../../utils/responsive_helper.dart';

/// Places autocomplete bottom sheet for address search.
class LocationSearchSheet extends StatefulWidget {
  const LocationSearchSheet({super.key});

  static Future<Map<String, dynamic>?> show(BuildContext context) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: sheetBottomPadding(ctx, extra: 0)),
        child: const LocationSearchSheet(),
      ),
    );
  }

  @override
  State<LocationSearchSheet> createState() => _LocationSearchSheetState();
}

class _LocationSearchSheetState extends State<LocationSearchSheet> {
  final MapsService _maps = MapsService();
  final _controller = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().length < 3) {
      setState(() {
        _results = [];
        _errorMessage = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final results = await _maps.searchPlacesAutocomplete(query);
      if (mounted) {
        setState(() {
          _results = results;
          _errorMessage = _maps.lastPlacesError ??
              (results.isEmpty ? 'No locations found. Try a nearby landmark.' : null);
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _select(Map<String, dynamic> place) async {
    final placeId = place['place_id'] as String?;
    if (placeId == null || placeId.isEmpty) {
      Navigator.pop(context, place);
      return;
    }
    setState(() => _loading = true);
    final details = await _maps.getPlaceDetails(placeId);
    if (!mounted) return;
    setState(() => _loading = false);
    Navigator.pop(context, details ?? place);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: sh(context, 0.55).clamp(320.0, 520.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: MeatvoSpacing.sm),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(MeatvoSpacing.md),
              child: Text(
                'Search location',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: MeatvoSpacing.md),
              child: TextField(
                controller: _controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Area, street, society…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _loading
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: _search,
              ),
            ),
            const SizedBox(height: MeatvoSpacing.sm),
            if (_errorMessage != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: MeatvoSpacing.md),
                child: Text(
                  _errorMessage!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.red,
                      ),
                ),
              ),
              const SizedBox(height: MeatvoSpacing.xs),
            ],
            if (!GoogleMapsSetup.hasConfiguredApiKey)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: MeatvoSpacing.md),
                child: Text(
                  'Maps key missing — enable Places API in Google Cloud and update .env',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ),
            Expanded(
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final item = _results[index];
                  return ListTile(
                    leading: const Icon(Icons.place_outlined),
                    title: Text(item['description'] as String? ?? ''),
                    subtitle: Text(item['secondary_text'] as String? ?? ''),
                    onTap: () => _select(item),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

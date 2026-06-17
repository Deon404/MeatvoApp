import 'package:flutter/material.dart';

import '../../config/google_maps_setup.dart';
import '../../core/constants/app_constants.dart';
import '../../services/maps_service.dart';
import '../../services/recent_location_search_service.dart';
import '../../widgets/location/location_flow_helper.dart';

/// Zappfresh-style full-page locality search.
class SearchLocalityScreen extends StatefulWidget {
  const SearchLocalityScreen({super.key});

  @override
  State<SearchLocalityScreen> createState() => _SearchLocalityScreenState();
}

class _SearchLocalityScreenState extends State<SearchLocalityScreen> {
  final MapsService _maps = MapsService();
  final RecentLocationSearchService _recentService =
      RecentLocationSearchService();
  final _controller = TextEditingController();

  List<Map<String, dynamic>> _results = [];
  List<Map<String, dynamic>> _recent = [];
  bool _loading = false;
  bool _gpsLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadRecent() async {
    final recent = await _recentService.getRecent();
    if (mounted) setState(() => _recent = recent);
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
              (results.isEmpty ? 'No locations found.' : null);
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectPlace(Map<String, dynamic> place) async {
    setState(() => _loading = true);
    final placeId = place['place_id'] as String?;
    Map<String, dynamic>? resolved = place;

    if (placeId != null && placeId.isNotEmpty) {
      resolved = await _maps.getPlaceDetails(placeId) ?? place;
    }

    if (!mounted) return;
    setState(() => _loading = false);

    await _recentService.addPlace(resolved);
    if (mounted) Navigator.of(context).pop(resolved);
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _gpsLoading = true);
    try {
      final position = await resolveDeliveryLocation(context);
      if (position == null || !mounted) return;

      final address = await _maps.getAddressFromCoordinates(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      final payload = {
        'latitude': position.latitude,
        'longitude': position.longitude,
        if (address != null) ...address,
      };

      await _recentService.addPlace(payload);
      if (mounted) Navigator.of(context).pop(payload);
    } finally {
      if (mounted) setState(() => _gpsLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showRecent = _controller.text.trim().length < 3 && _recent.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Search city and locality'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search a new address',
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
                filled: true,
                fillColor: AppColors.greyLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.button),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: _search,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: _ActionRow(
              icon: Icons.my_location_rounded,
              label: 'Use your current location',
              loading: _gpsLoading,
              onTap: _gpsLoading ? null : _useCurrentLocation,
              filled: true,
            ),
          ),
          if (!GoogleMapsSetup.hasConfiguredApiKey)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                'Maps key missing — set GOOGLE_MAPS_API_KEY in .env',
                style: AppTextStyles.caption,
              ),
            ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              child: Text(
                _errorMessage!,
                style: AppTextStyles.caption.copyWith(color: AppColors.error),
              ),
            ),
          if (showRecent) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Text(
                'Recent search',
                style: AppTextStyles.h3.copyWith(fontSize: 15),
              ),
            ),
          ],
          Expanded(
            child: ListView.separated(
              itemCount: showRecent ? _recent.length : _results.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = showRecent ? _recent[index] : _results[index];
                final title = showRecent
                    ? (item['primary_text'] as String? ?? 'Location')
                    : (item['description'] as String? ?? '');
                final subtitle = showRecent
                    ? (item['secondary_text'] as String? ?? '')
                    : (item['secondary_text'] as String? ?? '');

                return ListTile(
                  leading: Icon(
                    Icons.location_on_rounded,
                    color: AppColors.primary,
                  ),
                  title: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: subtitle.isNotEmpty
                      ? Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        )
                      : null,
                  onTap: () => _selectPlace(item),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool loading;
  final bool filled;

  const _ActionRow({
    required this.icon,
    required this.label,
    this.onTap,
    this.loading = false,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? AppColors.primary : AppColors.primaryLight,
      borderRadius: BorderRadius.circular(AppRadius.button),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.button),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 14,
          ),
          child: Row(
            children: [
              Icon(icon, color: filled ? Colors.white : AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: filled ? Colors.white : AppColors.primary,
                  ),
                ),
              ),
              if (loading)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: filled ? Colors.white : AppColors.primary,
                  ),
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: filled ? Colors.white : AppColors.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

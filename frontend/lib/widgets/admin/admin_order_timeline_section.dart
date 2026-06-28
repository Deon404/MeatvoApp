import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
import '../../services/admin_service.dart';

/// Expandable operational timeline for a single admin order.
class AdminOrderTimelineSection extends StatefulWidget {
  final String orderId;

  const AdminOrderTimelineSection({super.key, required this.orderId});

  @override
  State<AdminOrderTimelineSection> createState() =>
      _AdminOrderTimelineSectionState();
}

class _AdminOrderTimelineSectionState extends State<AdminOrderTimelineSection> {
  final _adminService = AdminService();
  final _dateFormat = DateFormat('MMM d, yyyy • hh:mm:ss a');

  List<Map<String, dynamic>> _events = [];
  bool _expanded = false;
  bool _loading = false;
  String? _error;

  Future<void> _loadTimeline() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final events = await _adminService.getOrderTimeline(widget.orderId);
      if (!mounted) return;
      setState(() {
        _events = events;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _onExpansionChanged(bool expanded) {
    setState(() => _expanded = expanded);
    if (expanded && _events.isEmpty && _error == null) {
      _loadTimeline();
    }
  }

  String _formatEventType(String? value) {
    if (value == null || value.isEmpty) return 'Event';
    return value
        .split('_')
        .map((part) =>
            part.isEmpty ? part : part[0].toUpperCase() + part.substring(1).toLowerCase())
        .join(' ');
  }

  String _formatActor(Map<String, dynamic> event) {
    final actorType = event['actorType']?.toString() ?? 'SYSTEM';
    final actorId = event['actorId'];
    if (actorId != null) {
      return '$actorType #$actorId';
    }
    return actorType;
  }

  DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        initiallyExpanded: false,
        onExpansionChanged: _onExpansionChanged,
        leading: const Icon(Icons.timeline, color: AppColors.textSecondary, size: 20),
        title: const Text(
          'Order Timeline',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          _expanded && _events.isNotEmpty
              ? '${_events.length} events'
              : 'Operational event history',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        children: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.primary, fontSize: 12),
              ),
            )
          else if (_events.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No operational events recorded yet.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            )
          else
            ..._events.map(_buildEventTile),
        ],
      ),
    );
  }

  Widget _buildEventTile(Map<String, dynamic> event) {
    final timestamp = _parseTimestamp(event['timestamp']);
    final metadata = event['metadata'];
    final metadataMap = metadata is Map
        ? Map<String, dynamic>.from(metadata)
        : <String, dynamic>{};
    final hasMetadata = metadataMap.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.divider),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatEventType(event['eventType']?.toString()),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              if (timestamp != null)
                Text(
                  _dateFormat.format(timestamp.toLocal()),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              event['description']?.toString() ??
                  _formatEventType(event['eventType']?.toString()),
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
          trailing: hasMetadata
              ? const Icon(Icons.unfold_more, size: 18, color: AppColors.textSecondary)
              : null,
          children: hasMetadata
              ? [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Actor: ${_formatActor(event)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...metadataMap.entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '${entry.key}: ${entry.value}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                ]
              : [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Actor: ${_formatActor(event)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// Model representing a recent stock-related activity (picking).
class RecentActivity {
  final int id;
  final String name;
  final String model;
  final String type;
  final String state;
  final DateTime date;

  RecentActivity({
    required this.id,
    required this.name,
    required this.model,
    required this.type,
    required this.state,
    required this.date,
  });

  factory RecentActivity.fromPicking(Map<String, dynamic> data) {
    return RecentActivity(
      id: data['id'] as int,
      name: (data['name'] ?? '').toString(),
      model: 'stock.picking',
      type: (data['picking_type_code'] ?? '').toString(),
      state: (data['state'] ?? '').toString(),
      date:
          _parseDate(data['scheduled_date']) ??
          _parseDate(data['write_date']) ??
          DateTime.now(),
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    try {
      if (v is String && v.isNotEmpty) {
        return DateTime.tryParse(v);
      }
    } catch (_) {}
    return null;
  }

  IconData iconForType() {
    switch (type) {
      case 'incoming':
        return Icons.call_received_outlined;
      case 'outgoing':
        return Icons.call_made_outlined;
      case 'internal':
        return Icons.sync_alt;
      default:
        return HugeIcons.strokeRoundedCalendar03;
    }
  }

  Color colorForState(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    switch (state) {
      case 'assigned':
        return scheme.primary;
      case 'done':
        return Colors.green;
      case 'cancel':
        return Colors.red;
      case 'waiting':
      case 'confirmed':
        return Colors.orange;
      default:
        return Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
    }
  }
}

/// Model representing a scheduled Odoo activity for the current user.
class TodayActivity {
  final int id;
  final String resModel;
  final int resId;
  final String? summary;
  final String? note;
  final DateTime? deadline;

  TodayActivity({
    required this.id,
    required this.resModel,
    required this.resId,
    this.summary,
    this.note,
    this.deadline,
  });

  factory TodayActivity.fromMap(Map<String, dynamic> data) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
      return null;
    }

    return TodayActivity(
      id: data['id'] as int,
      resModel: (data['res_model'] ?? '').toString(),
      resId: (data['res_id'] ?? 0) as int,
      summary: (data['summary'] ?? '').toString(),
      note: (data['note'] ?? '').toString(),
      deadline: parseDate(data['date_deadline']),
    );
  }

  String displayTitle() {
    if (summary != null && summary!.trim().isNotEmpty) return summary!;
    return resModel;
  }
}

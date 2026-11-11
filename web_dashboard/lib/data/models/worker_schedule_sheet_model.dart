import 'dart:convert';

class ScheduleEntryModel {
  final String entryId;
  final String userId;
  final String workerName;
  final String assignedAreaId;
  final String assignedAreaName;
  final String dayOff; // e.g. "Saturday and Sunday", "Sunday", "Monday and Tuesday"
  final String timeSchedule; // e.g. "04:00 AM – 01:00 PM"
  final String statusRemarks; // e.g. "Signed", "Raffle Draw Batch 1"

  ScheduleEntryModel({
    required this.entryId,
    required this.userId,
    required this.workerName,
    required this.assignedAreaId,
    required this.assignedAreaName,
    required this.dayOff,
    required this.timeSchedule,
    this.statusRemarks = '',
  });

  ScheduleEntryModel copyWith({
    String? entryId,
    String? userId,
    String? workerName,
    String? assignedAreaId,
    String? assignedAreaName,
    String? dayOff,
    String? timeSchedule,
    String? statusRemarks,
  }) {
    return ScheduleEntryModel(
      entryId: entryId ?? this.entryId,
      userId: userId ?? this.userId,
      workerName: workerName ?? this.workerName,
      assignedAreaId: assignedAreaId ?? this.assignedAreaId,
      assignedAreaName: assignedAreaName ?? this.assignedAreaName,
      dayOff: dayOff ?? this.dayOff,
      timeSchedule: timeSchedule ?? this.timeSchedule,
      statusRemarks: statusRemarks ?? this.statusRemarks,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'entry_id': entryId,
      'user_id': userId,
      'worker_name': workerName,
      'assigned_area_id': assignedAreaId,
      'assigned_area_name': assignedAreaName,
      'day_off': dayOff,
      'time_schedule': timeSchedule,
      'status_remarks': statusRemarks,
    };
  }

  factory ScheduleEntryModel.fromJson(Map<String, dynamic> json) {
    return ScheduleEntryModel(
      entryId: json['entry_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      workerName: json['worker_name']?.toString() ?? '',
      assignedAreaId: json['assigned_area_id']?.toString() ?? '',
      assignedAreaName: json['assigned_area_name']?.toString() ?? '',
      dayOff: json['day_off']?.toString() ?? 'Saturday and Sunday',
      timeSchedule: json['time_schedule']?.toString() ?? '04:00 AM – 01:00 PM',
      statusRemarks: json['status_remarks']?.toString() ?? '',
    );
  }

  /// Helper to check if a specific DateTime is the worker's scheduled day off
  bool isDayOff(DateTime date) {
    final lower = dayOff.toLowerCase();
    switch (date.weekday) {
      case DateTime.monday:
        return lower.contains('mon');
      case DateTime.tuesday:
        return lower.contains('tue');
      case DateTime.wednesday:
        return lower.contains('wed');
      case DateTime.thursday:
        return lower.contains('thu');
      case DateTime.friday:
        return lower.contains('fri');
      case DateTime.saturday:
        return lower.contains('sat');
      case DateTime.sunday:
        return lower.contains('sun');
      default:
        return false;
    }
  }
}

class ScheduleSheetModel {
  final String sheetId;
  final String sheetName; // 'Street Cleaners', 'Parks and Plaza'
  final int month; // 1-12
  final int year; // e.g. 2026
  final List<ScheduleEntryModel> entries;

  ScheduleSheetModel({
    required this.sheetId,
    required this.sheetName,
    required this.month,
    required this.year,
    required this.entries,
  });

  ScheduleSheetModel copyWith({
    String? sheetId,
    String? sheetName,
    int? month,
    int? year,
    List<ScheduleEntryModel>? entries,
  }) {
    return ScheduleSheetModel(
      sheetId: sheetId ?? this.sheetId,
      sheetName: sheetName ?? this.sheetName,
      month: month ?? this.month,
      year: year ?? this.year,
      entries: entries ?? this.entries,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sheet_id': sheetId,
      'sheet_name': sheetName,
      'month': month,
      'year': year,
      'entries': entries.map((e) => e.toJson()).toList(),
    };
  }

  factory ScheduleSheetModel.fromJson(Map<String, dynamic> json) {
    var rawEntries = json['entries'];
    List<ScheduleEntryModel> list = [];
    if (rawEntries is String) {
      try {
        rawEntries = jsonDecode(rawEntries);
      } catch (_) {}
    }
    if (rawEntries is List) {
      list = rawEntries
          .whereType<Map>()
          .map((m) => ScheduleEntryModel.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    }

    return ScheduleSheetModel(
      sheetId: json['sheet_id']?.toString() ?? '',
      sheetName: json['sheet_name']?.toString() ?? 'Street Cleaners',
      month: (json['month'] as num?)?.toInt() ?? DateTime.now().month,
      year: (json['year'] as num?)?.toInt() ?? DateTime.now().year,
      entries: list,
    );
  }
}

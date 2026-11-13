class TimePresetModel {
  final String presetId;
  final String name;
  final String startTime; // e.g. "06:00 AM" or "06:00"
  final String endTime;   // e.g. "11:00 AM" or "11:00"
  final String defaultDayOff; // e.g. "Saturday, Sunday"

  const TimePresetModel({
    required this.presetId,
    required this.name,
    required this.startTime,
    required this.endTime,
    this.defaultDayOff = 'Saturday, Sunday',
  });

  String get formattedSchedule => '$startTime – $endTime';

  TimePresetModel copyWith({
    String? presetId,
    String? name,
    String? startTime,
    String? endTime,
    String? defaultDayOff,
  }) {
    return TimePresetModel(
      presetId: presetId ?? this.presetId,
      name: name ?? this.name,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      defaultDayOff: defaultDayOff ?? this.defaultDayOff,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'preset_id': presetId,
      'name': name,
      'start_time': startTime,
      'end_time': endTime,
      'default_day_off': defaultDayOff,
    };
  }

  factory TimePresetModel.fromJson(Map<String, dynamic> json) {
    return TimePresetModel(
      presetId: json['preset_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      startTime: json['start_time']?.toString() ?? '08:00 AM',
      endTime: json['end_time']?.toString() ?? '05:00 PM',
      defaultDayOff: json['default_day_off']?.toString() ?? 'Saturday, Sunday',
    );
  }

  static List<TimePresetModel> defaultPresets() {
    return const [
      TimePresetModel(
        presetId: 'preset-am',
        name: 'Morning Shift (AM)',
        startTime: '06:00 AM',
        endTime: '11:00 AM',
        defaultDayOff: 'Saturday, Sunday',
      ),
      TimePresetModel(
        presetId: 'preset-pm',
        name: 'Afternoon Shift (PM)',
        startTime: '01:00 PM',
        endTime: '05:00 PM',
        defaultDayOff: 'Saturday, Sunday',
      ),
      TimePresetModel(
        presetId: 'preset-full',
        name: 'Whole Day (Full)',
        startTime: '08:00 AM',
        endTime: '05:00 PM',
        defaultDayOff: 'Saturday, Sunday',
      ),
    ];
  }
}

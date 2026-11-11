import 'package:flutter/material.dart';

enum ShiftStatus {
  beforeShift,
  activeShift,
  afterShift,
  restDay,
  unassigned,
}

class ShiftValidationResult {
  final bool allowed;
  final bool isLate;
  final int lateMinutes;
  final String lateFormatted;
  final String reasonCeb;
  final String reasonEng;

  const ShiftValidationResult({
    required this.allowed,
    this.isLate = false,
    this.lateMinutes = 0,
    this.lateFormatted = '',
    this.reasonCeb = '',
    this.reasonEng = '',
  });

  String getReason(bool isCebuano) => isCebuano ? reasonCeb : reasonEng;
}

class ShiftEvaluation {
  final ShiftStatus status;
  final String shiftLabel;
  final String daysLabel;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final Duration? timeUntilStart;
  final Duration? timeUntilEnd;
  final bool isStartingSoon;

  const ShiftEvaluation({
    required this.status,
    this.shiftLabel = 'Unassigned',
    this.daysLabel = '',
    this.startTime,
    this.endTime,
    this.timeUntilStart,
    this.timeUntilEnd,
    this.isStartingSoon = false,
  });
}

class ScheduleHelper {
  /// Evaluates the worker's shift state relative to [now] (defaults to DateTime.now())
  static ShiftEvaluation evaluateShift({required String? schedule, DateTime? now}) {
    final current = now ?? DateTime.now();

    if (schedule == null || schedule.trim().isEmpty || schedule.trim().toLowerCase() == 'unassigned') {
      return const ShiftEvaluation(status: ShiftStatus.unassigned);
    }

    // 1. Separate Days part and Time part
    // Example formats: "Mon-Fri 06:00 - 11:00", "Mon,Tue,Wed,Thu,Fri 08:00 - 17:00", "06:00 - 11:00"
    final cleanSched = schedule.trim();
    final parts = cleanSched.split(' ');
    String daysPart = 'Mon-Fri';
    String timePart = cleanSched;

    if (parts.length >= 2 && (parts.first.contains('-') || parts.first.contains(',')) && !parts.first.contains(':')) {
      daysPart = parts.first;
      timePart = cleanSched.substring(daysPart.length).trim();
    }

    // 2. Check if today is a scheduled working day
    if (!isWorkingDay(current, daysPart)) {
      return ShiftEvaluation(
        status: ShiftStatus.restDay,
        shiftLabel: timePart,
        daysLabel: daysPart,
      );
    }

    // 3. Parse start & end times
    final times = timePart.split('-').map((t) => t.trim()).toList();
    if (times.length < 2) {
      return ShiftEvaluation(
        status: ShiftStatus.activeShift,
        shiftLabel: timePart,
        daysLabel: daysPart,
      );
    }

    final startTod = _parseTimeOfDay(times[0]);
    final endTod = _parseTimeOfDay(times[1]);

    if (startTod == null || endTod == null) {
      return ShiftEvaluation(
        status: ShiftStatus.activeShift,
        shiftLabel: timePart,
        daysLabel: daysPart,
      );
    }

    final startDateTime = DateTime(current.year, current.month, current.day, startTod.hour, startTod.minute);
    final endDateTime = DateTime(current.year, current.month, current.day, endTod.hour, endTod.minute);

    if (current.isBefore(startDateTime)) {
      final diff = startDateTime.difference(current);
      return ShiftEvaluation(
        status: ShiftStatus.beforeShift,
        shiftLabel: '${times[0]} - ${times[1]}',
        daysLabel: daysPart,
        startTime: startTod,
        endTime: endTod,
        timeUntilStart: diff,
        isStartingSoon: diff.inMinutes <= 60 && diff.inMinutes >= 0,
      );
    } else if (current.isAfter(endDateTime)) {
      return ShiftEvaluation(
        status: ShiftStatus.afterShift,
        shiftLabel: '${times[0]} - ${times[1]}',
        daysLabel: daysPart,
        startTime: startTod,
        endTime: endTod,
      );
    } else {
      final diffEnd = endDateTime.difference(current);
      return ShiftEvaluation(
        status: ShiftStatus.activeShift,
        shiftLabel: '${times[0]} - ${times[1]}',
        daysLabel: daysPart,
        startTime: startTod,
        endTime: endTod,
        timeUntilEnd: diffEnd,
      );
    }
  }

  /// Checks if [date] falls on one of the active working days specified in [daysString]
  static bool isWorkingDay(DateTime date, String daysString) {
    final clean = daysString.trim().toLowerCase();
    final weekday = date.weekday; // 1 = Mon, 7 = Sun

    if (clean.contains('mon-fri') || clean.contains('mon - fri')) {
      return weekday >= 1 && weekday <= 5;
    }
    if (clean.contains('mon-sat') || clean.contains('mon - sat')) {
      return weekday >= 1 && weekday <= 6;
    }
    if (clean.contains('mon-sun') || clean.contains('mon - sun') || clean.contains('all') || clean.contains('daily') || clean.contains('everyday')) {
      return true;
    }

    const dayNames = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    final currentDayName = dayNames[weekday - 1];

    final tokens = clean.split(',').map((t) => t.trim()).toList();
    for (final token in tokens) {
      if (token.startsWith(currentDayName)) return true;
    }

    return false;
  }

  static TimeOfDay? _parseTimeOfDay(String timeStr) {
    try {
      final clean = timeStr.trim().toLowerCase();
      final isPm = clean.contains('pm');
      final isAm = clean.contains('am');
      final numPart = clean.replaceAll(RegExp(r'[^\d:]'), '');
      final parts = numPart.split(':');
      if (parts.isEmpty) return null;

      var hour = int.parse(parts[0]);
      final minute = parts.length > 1 ? int.parse(parts[1]) : 0;

      if (isPm && hour < 12) hour += 12;
      if (isAm && hour == 12) hour = 0;

      return TimeOfDay(hour: hour, minute: minute);
    } catch (_) {
      return null;
    }
  }

  static String formatDuration(Duration d, {bool verbose = false}) {
    final hours = d.inHours;
    final mins = d.inMinutes % 60;
    if (verbose) {
      if (hours > 0 && mins > 0) {
        return '$hours hr and $mins min';
      } else if (hours > 0) {
        return '$hours hr';
      }
      return '$mins min';
    }
    if (hours > 0) {
      return '${hours}h ${mins}m';
    }
    return '${mins}m';
  }

  /// Cebuano localized banner and reminder messages
  static String getCebuanoShiftNotice(ShiftEvaluation eval, {String? areaName}) {
    final location = areaName != null && areaName.isNotEmpty ? ' sa $areaName' : '';
    switch (eval.status) {
      case ShiftStatus.beforeShift:
        final waitStr = eval.timeUntilStart != null ? ' (Magsugod sa ${formatDuration(eval.timeUntilStart!, verbose: true)})' : '';
        return 'Pahinumdom: Ang imong iskedyul magsugod sa ${eval.shiftLabel}$location$waitStr. Palihug siguroha nga anaa ka sa lugar sa dili pa mag-Time In.';
      case ShiftStatus.activeShift:
        return 'Aktibong Iskedyul: ${eval.shiftLabel}$location. Palihug pag-Time In sulod sa imong geofence.';
      case ShiftStatus.afterShift:
        return 'Nahuman na ang imong iskedyul karong adlawa$location. Salamat sa imong serbisyo! Pwede na nimo i-submit ang imong accomplishment proof.';
      case ShiftStatus.restDay:
        return 'Adlaw sa Pagpahulay (Rest Day). Walay iskedyul sa trabaho karong adlawa.';
      case ShiftStatus.unassigned:
        return 'Wala pay na-assign nga iskedyul sa trabaho.';
    }
  }

  /// English localized banner and reminder messages
  static String getEnglishShiftNotice(ShiftEvaluation eval, {String? areaName}) {
    final location = areaName != null && areaName.isNotEmpty ? ' at $areaName' : '';
    switch (eval.status) {
      case ShiftStatus.beforeShift:
        final waitStr = eval.timeUntilStart != null ? ' (Starts in ${formatDuration(eval.timeUntilStart!, verbose: true)})' : '';
        return 'Notice: Your work shift starts at ${eval.shiftLabel}$location$waitStr. Please be in your assigned sector before timing in.';
      case ShiftStatus.activeShift:
        return 'Active Shift: ${eval.shiftLabel}$location. Please log your Time-in within the geofence.';
      case ShiftStatus.afterShift:
        return 'Shift completed for today$location. Thank you for your service! You can now submit your accomplishment proof.';
      case ShiftStatus.restDay:
        return 'Rest Day. No work schedule assigned for today.';
      case ShiftStatus.unassigned:
        return 'No shift schedule assigned yet.';
    }
  }

  /// Checks whether a worker is permitted to Time-In given their [eval].
  /// Allows Time-In during [ShiftStatus.activeShift] or within [earlyBufferMinutes] (default 30 mins) before shift.
  static ShiftValidationResult canTimeInNow(ShiftEvaluation eval, {int earlyBufferMinutes = 30, DateTime? now}) {
    if (eval.status == ShiftStatus.unassigned) {
      return const ShiftValidationResult(allowed: true);
    }

    if (eval.status == ShiftStatus.restDay) {
      return const ShiftValidationResult(
        allowed: false,
        reasonCeb: 'Adlaw sa Pagpahulay karon (Rest Day). Wala kay gitakdang iskedyul sa trabaho karong adlawa.',
        reasonEng: 'Rest Day today. You have no scheduled work shift for today.',
      );
    }

    if (eval.status == ShiftStatus.beforeShift) {
      final minsUntil = eval.timeUntilStart?.inMinutes ?? 999;
      if (minsUntil <= earlyBufferMinutes) {
        return const ShiftValidationResult(allowed: true);
      }

      final shiftDuration = eval.timeUntilStart ?? Duration(minutes: minsUntil);
      final shiftWaitEng = formatDuration(shiftDuration, verbose: true);
      final shiftHours = shiftDuration.inHours;
      final shiftRemMins = shiftDuration.inMinutes % 60;
      final shiftWaitCeb = (shiftHours > 0 && shiftRemMins > 0)
          ? '$shiftHours hr ug $shiftRemMins min'
          : (shiftHours > 0 ? '$shiftHours hr' : '$shiftRemMins min');

      final waitMins = minsUntil - earlyBufferMinutes;
      final waitDuration = Duration(minutes: waitMins);
      final waitFormattedEng = formatDuration(waitDuration, verbose: true);
      final waitHours = waitDuration.inHours;
      final waitRemMins = waitDuration.inMinutes % 60;
      final waitFormattedCeb = (waitHours > 0 && waitRemMins > 0)
          ? '$waitHours hr ug $waitRemMins min'
          : (waitHours > 0 ? '$waitHours hr' : '$waitRemMins min');

      String earlyOpenStr = '$earlyBufferMinutes mins early';
      if (eval.startTime != null) {
        final totalMinutes = eval.startTime!.hour * 60 + eval.startTime!.minute - earlyBufferMinutes;
        final openHour = ((totalMinutes ~/ 60) + 24) % 24;
        final openMinute = (totalMinutes % 60 + 60) % 60;
        final isPm = openHour >= 12;
        final h12 = openHour == 0 ? 12 : (openHour > 12 ? openHour - 12 : openHour);
        final mStr = openMinute.toString().padLeft(2, '0');
        final ampm = isPm ? 'PM' : 'AM';
        earlyOpenStr = '$h12:$mStr $ampm';
      }

      return ShiftValidationResult(
        allowed: false,
        reasonCeb: 'Sayo ra kaayo para mag-Time-In. Ang imong iskedyul magsugod sa ${eval.shiftLabel} (sa $shiftWaitCeb). Mabuksan ang Time-In $earlyBufferMinutes minutos sa dili pa magsugod sa $earlyOpenStr (sa $waitFormattedCeb).',
        reasonEng: 'Too early for Time-In. Your shift starts at ${eval.shiftLabel} (in $shiftWaitEng). Time-In opens $earlyBufferMinutes minutes early at $earlyOpenStr (in $waitFormattedEng).',
      );
    }

    if (eval.status == ShiftStatus.activeShift || eval.status == ShiftStatus.afterShift) {
      if (eval.startTime != null) {
        final current = now ?? DateTime.now();
        final nowMins = current.hour * 60 + current.minute;
        final startMins = eval.startTime!.hour * 60 + eval.startTime!.minute;
        final diff = nowMins - startMins;

        if (diff > 0) {
          final lateHours = diff ~/ 60;
          final lateMins = diff % 60;
          final formattedLate = lateHours > 0
              ? (lateMins > 0 ? '${lateHours}h ${lateMins}m late' : '${lateHours}h late')
              : '${lateMins}m late';
          final formattedLateCeb = lateHours > 0
              ? (lateMins > 0 ? '$lateHours hr ug $lateMins min naulahi' : '$lateHours hr naulahi')
              : '$lateMins min naulahi';

          return ShiftValidationResult(
            allowed: true,
            isLate: true,
            lateMinutes: diff,
            lateFormatted: formattedLate,
            reasonCeb: 'Naulahi og $formattedLateCeb (Iskedyul: ${eval.shiftLabel}).',
            reasonEng: 'Late by $formattedLate (Scheduled shift: ${eval.shiftLabel}).',
          );
        }
      }
      return const ShiftValidationResult(allowed: true);
    }

    return const ShiftValidationResult(allowed: true);
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/attendance_model.dart';
import '../../../data/models/leave_request_model.dart';
import '../../../data/models/worker_schedule_sheet_model.dart';
import '../../../data/repositories/repository_provider.dart';

enum CellAttendanceStatus {
  present, // Green (on time within schedule/grace period)
  late, // Yellow (timed in after scheduled start + grace period)
  absent, // Red (expected to work, past shift end, no time in)
  dayOff, // White (scheduled rest day - NEVER classified as absent)
  onLeave, // Grey (approved leave request)
  pendingFuture, // Off-white / neutral (shift not yet started or future date)
}

class WeeklyAttendanceMatrixWidget extends ConsumerStatefulWidget {
  final DateTime selectedWeekStart; // Always a Sunday
  final Function(DateTime newWeekStart) onWeekChanged;

  const WeeklyAttendanceMatrixWidget({
    super.key,
    required this.selectedWeekStart,
    required this.onWeekChanged,
  });

  @override
  ConsumerState<WeeklyAttendanceMatrixWidget> createState() => _WeeklyAttendanceMatrixWidgetState();
}

class _WeeklyAttendanceMatrixWidgetState extends ConsumerState<WeeklyAttendanceMatrixWidget> {
  String? _selectedSheetName;

  DateTime get _sunday => widget.selectedWeekStart;
  List<DateTime> get _weekDays => List.generate(7, (i) => _sunday.add(Duration(days: i)));

  void _previousWeek() {
    widget.onWeekChanged(_sunday.subtract(const Duration(days: 7)));
  }

  void _nextWeek() {
    widget.onWeekChanged(_sunday.add(const Duration(days: 7)));
  }

  void _currentWeek() {
    final now = DateTime.now();
    final sunday = now.subtract(Duration(days: now.weekday % 7));
    widget.onWeekChanged(DateTime(sunday.year, sunday.month, sunday.day));
  }

  /// Parses scheduled shift start time string like "04:00 AM – 01:00 PM" into TimeOfDay
  TimeOfDay? _parseStartTime(String scheduleStr) {
    try {
      final parts = scheduleStr.split(RegExp(r'[-–]'));
      if (parts.isEmpty) return null;
      final startStr = parts.first.trim();
      final dt = DateFormat('hh:mm a').parseLoose(startStr);
      return TimeOfDay(hour: dt.hour, minute: dt.minute);
    } catch (_) {
      return null;
    }
  }

  /// Parses scheduled shift end time string like "04:00 AM – 01:00 PM" into TimeOfDay
  TimeOfDay? _parseEndTime(String scheduleStr) {
    try {
      final parts = scheduleStr.split(RegExp(r'[-–]'));
      if (parts.length < 2) return null;
      final endStr = parts[1].trim();
      final dt = DateFormat('hh:mm a').parseLoose(endStr);
      return TimeOfDay(hour: dt.hour, minute: dt.minute);
    } catch (_) {
      return null;
    }
  }

  /// Evaluates attendance cell status according to strict operational rules:
  /// - Grey: On Leave (approved leave request)
  /// - White: Scheduled Day Off (NEVER marked absent)
  /// - Green: Present / On-Time
  /// - Yellow: Late (timed in after scheduled start + 15m grace period)
  /// - Red: Absent (only if shift end cutoff has elapsed and no time-in)
  /// - Neutral: Shift not started yet or future date
  CellAttendanceStatus _evaluateAttendance({
    required ScheduleEntryModel worker,
    required DateTime date,
    required List<AttendanceModel> workerLogsForDay,
    List<LeaveRequestModel> activeLeaves = const [],
  }) {
    // 1. Approved Leave Rule: Overrides normal work day and displays grey
    final dateMidnight = DateTime(date.year, date.month, date.day);
    final hasApprovedLeave = activeLeaves.any((l) {
      if (l.userId != worker.userId && l.workerName.toLowerCase() != worker.workerName.toLowerCase()) return false;
      if (l.status.toLowerCase() != 'approved') return false;
      final start = DateTime.tryParse(l.startDate);
      final end = DateTime.tryParse(l.endDate);
      if (start == null || end == null) return false;
      final sMidnight = DateTime(start.year, start.month, start.day);
      final eMidnight = DateTime(end.year, end.month, end.day);
      return !dateMidnight.isBefore(sMidnight) && !dateMidnight.isAfter(eMidnight);
    });

    if (hasApprovedLeave) {
      return CellAttendanceStatus.onLeave;
    }

    // 2. Day Off Rule: Never classified as absent
    if (worker.isDayOff(date)) {
      return CellAttendanceStatus.dayOff;
    }

    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final targetMidnight = DateTime(date.year, date.month, date.day);

    // If future date, pending
    if (targetMidnight.isAfter(todayMidnight)) {
      return CellAttendanceStatus.pendingFuture;
    }

    // Check for qualifying time-in punch
    final timeInLog = workerLogsForDay.where((l) => l.actionType == 'time-in' || l.actionType == 'time-in-substitute').toList();
    if (timeInLog.isNotEmpty) {
      final punch = timeInLog.first;
      final scheduledStart = _parseStartTime(worker.timeSchedule);
      if (scheduledStart == null) {
        return CellAttendanceStatus.present;
      }
      // Scheduled start on target date with 15-minute grace period
      final shiftStartDt = DateTime(date.year, date.month, date.day, scheduledStart.hour, scheduledStart.minute);
      final graceCutoff = shiftStartDt.add(const Duration(minutes: 15));

      if (punch.timestamp.isAfter(graceCutoff)) {
        return CellAttendanceStatus.late;
      }
      return CellAttendanceStatus.present;
    }

    // If target date is today, check if shift has completed or cutoff reached
    if (targetMidnight.isAtSameMomentAs(todayMidnight)) {
      final scheduledEnd = _parseEndTime(worker.timeSchedule);
      if (scheduledEnd != null) {
        final shiftEndDt = DateTime(date.year, date.month, date.day, scheduledEnd.hour, scheduledEnd.minute);
        if (now.isAfter(shiftEndDt)) {
          return CellAttendanceStatus.absent;
        }
      }
      return CellAttendanceStatus.pendingFuture;
    }

    // Past date with no qualifying time-in record -> Absent
    return CellAttendanceStatus.absent;
  }

  void _showCellDetailsDialog({
    required BuildContext context,
    required ScheduleEntryModel worker,
    required DateTime date,
    required CellAttendanceStatus status,
    required List<AttendanceModel> logs,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: _getStatusColor(status),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black26),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${worker.workerName} • ${DateFormat('EEE, MMM d').format(date)}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow('Status', _getStatusLabel(status), isBold: true),
              _detailRow('Assigned Area', worker.assignedAreaName),
              _detailRow('Shift Schedule', worker.timeSchedule),
              _detailRow('Scheduled Day Off', worker.dayOff),
              const Divider(height: 20),
              const Text('Logged Punches for Date:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 6),
              if (logs.isEmpty)
                Text(
                  status == CellAttendanceStatus.dayOff
                      ? 'No punches logged (Worker was on scheduled rest day).'
                      : status == CellAttendanceStatus.absent
                          ? 'No punches logged for this working date (Marked Absent).'
                          : 'No punches recorded yet.',
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontStyle: FontStyle.italic),
                )
              else
                ...logs.map((l) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Icon(
                            l.actionType == 'time-in'
                                ? Icons.login
                                : l.actionType == 'time-out'
                                    ? Icons.logout
                                    : Icons.free_breakfast,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(l.actionType.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          Text(DateFormat('hh:mm:ss a').format(l.timestamp), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        ],
                      ),
                    )),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text('$label:', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
          Expanded(child: Text(value, style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.w500))),
        ],
      ),
    );
  }

  Color _getStatusColor(CellAttendanceStatus status) {
    switch (status) {
      case CellAttendanceStatus.present:
        return const Color(0xFF22C55E); // Green
      case CellAttendanceStatus.late:
        return const Color(0xFFFACC15); // Yellow
      case CellAttendanceStatus.absent:
        return const Color(0xFFEF4444); // Red
      case CellAttendanceStatus.dayOff:
        return Colors.white; // White
      case CellAttendanceStatus.onLeave:
        return const Color(0xFF94A3B8); // Slate / Grey
      case CellAttendanceStatus.pendingFuture:
        return const Color(0xFFF1F5F9); // Light Slate
    }
  }

  String _getStatusLabel(CellAttendanceStatus status) {
    switch (status) {
      case CellAttendanceStatus.present:
        return 'Present (On-Time)';
      case CellAttendanceStatus.late:
        return 'Late Time-In';
      case CellAttendanceStatus.absent:
        return 'Absent (No Record)';
      case CellAttendanceStatus.dayOff:
        return 'Scheduled Day Off';
      case CellAttendanceStatus.onLeave:
        return 'On Approved Leave';
      case CellAttendanceStatus.pendingFuture:
        return 'Pending / Scheduled';
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = ScheduleSheetsQuery(month: _sunday.month, year: _sunday.year);
    final sheetsAsync = ref.watch(scheduleSheetsProvider(query));
    final sheets = sheetsAsync.value ?? [];

    if (_selectedSheetName == null && sheets.isNotEmpty) {
      _selectedSheetName = sheets.first.sheetName;
    }

    final activeSheet = sheets.firstWhere(
      (s) => s.sheetName == _selectedSheetName,
      orElse: () => sheets.isNotEmpty ? sheets.first : ScheduleSheetModel(sheetId: '', sheetName: 'Street Cleaners', month: _sunday.month, year: _sunday.year, entries: []),
    );

    // Retrieve attendance logs and approved leaves for the week
    final attendanceAsync = ref.watch(attendanceProvider);
    final allLogs = attendanceAsync.value ?? [];

    final leavesAsync = ref.watch(leaveRequestsProvider);
    final allLeaves = leavesAsync.value ?? [];

    final weekFormatted = '${DateFormat('MMM d').format(_weekDays.first)} – ${DateFormat('MMM d, yyyy').format(_weekDays.last)}';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar: Weekly Navigation, Sheet Switcher, Legend
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                // Week Navigator Controls
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, size: 20),
                      tooltip: 'Previous Week',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: _previousWeek,
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _sunday,
                          firstDate: DateTime(2022),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          final sun = picked.subtract(Duration(days: picked.weekday % 7));
                          widget.onWeekChanged(DateTime(sun.year, sun.month, sun.day));
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.date_range, size: 16, color: Color(0xFF107C41)),
                            const SizedBox(width: 6),
                            Text(
                              weekFormatted,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, size: 20),
                      tooltip: 'Next Week',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: _nextWeek,
                    ),
                    const SizedBox(width: 6),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: const Size(0, 28),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      onPressed: _currentWeek,
                      child: const Text('Current Week', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                    ),
                  ],
                ),

                // Sheet Category Selector (Street Cleaners vs Parks and Plaza)
                if (sheets.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Sheet:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                      const SizedBox(width: 6),
                      Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: sheets.any((s) => s.sheetName == _selectedSheetName)
                                ? _selectedSheetName
                                : sheets.first.sheetName,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF107C41)),
                            items: sheets.map((s) {
                              return DropdownMenuItem(value: s.sheetName, child: Text(s.sheetName));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedSheetName = val);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),

                // Color Legend
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _legendItem(const Color(0xFF22C55E), 'Present'),
                    const SizedBox(width: 10),
                    _legendItem(const Color(0xFFFACC15), 'Late'),
                    const SizedBox(width: 10),
                    _legendItem(const Color(0xFFEF4444), 'Absent'),
                    const SizedBox(width: 10),
                    _legendItem(const Color(0xFF94A3B8), 'On Leave'),
                    const SizedBox(width: 10),
                    _legendItem(Colors.white, 'Day Off', hasBorder: true),
                  ],
                ),
              ],
            ),
          ),

          // Spreadsheet Matrix Table
          activeSheet.entries.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.event_note_outlined, size: 36, color: AppColors.textMuted),
                        const SizedBox(height: 8),
                        Text(
                          'No active workers found in schedule sheet "${activeSheet.sheetName}" for ${DateFormat('MMMM yyyy').format(_sunday)}.',
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Open "Manage Worker Schedules" above to assign personnel following the monthly raffle draw.',
                          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    const colWidthNo = 50.0;
                    const colWidthName = 180.0;
                    const colWidthArea = 160.0;
                    const colWidthDay = 100.0;
                    const totalTableWidth = colWidthNo + colWidthName + colWidthArea + (7 * colWidthDay); // 1090.0

                    return ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: 138,
                        maxHeight: 280,
                      ),
                      child: Scrollbar(
                        thumbVisibility: activeSheet.entries.length > 5,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: totalTableWidth < (constraints.maxWidth) ? constraints.maxWidth : totalTableWidth,
                              child: Table(
                                columnWidths: const {
                                  0: FixedColumnWidth(colWidthNo),
                                  1: FixedColumnWidth(colWidthName),
                                  2: FixedColumnWidth(colWidthArea),
                                  3: FlexColumnWidth(1),
                                  4: FlexColumnWidth(1),
                                  5: FlexColumnWidth(1),
                                  6: FlexColumnWidth(1),
                                  7: FlexColumnWidth(1),
                                  8: FlexColumnWidth(1),
                                  9: FlexColumnWidth(1),
                                },
                                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                                border: const TableBorder(
                                  horizontalInside: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                                  verticalInside: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                                ),
                                children: [
                                  // --- HEADING ROW ---
                                  TableRow(
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFF1F5F9),
                                    ),
                                    children: [
                                      // 1. No.
                                      Container(
                                        height: 46,
                                        alignment: Alignment.center,
                                        child: const Text(
                                          'No.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: AppColors.textPrimary),
                                        ),
                                      ),
                                      // 2. Worker's Name
                                      Container(
                                        height: 46,
                                        alignment: Alignment.center,
                                        child: const Text(
                                          "Worker's Name",
                                          textAlign: TextAlign.center,
                                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: AppColors.textPrimary),
                                        ),
                                      ),
                                      // 3. Assigned Area
                                      Container(
                                        height: 46,
                                        alignment: Alignment.center,
                                        child: const Text(
                                          'Assigned Area',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: AppColors.textPrimary),
                                        ),
                                      ),
                                      // 4-10: 7 Days of Week (Sunday - Saturday)
                                      ..._weekDays.map((day) {
                                        final dayName = DateFormat('EEEE').format(day);
                                        final fullDate = DateFormat('MMM d, yyyy').format(day);
                                        final isToday = day.year == DateTime.now().year && day.month == DateTime.now().month && day.day == DateTime.now().day;

                                        return Container(
                                          height: 46,
                                          color: isToday ? const Color(0xFF107C41).withValues(alpha: 0.12) : null,
                                          alignment: Alignment.center,
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            children: [
                                              Text(
                                                dayName,
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 11,
                                                  color: isToday ? const Color(0xFF107C41) : AppColors.textPrimary,
                                                ),
                                              ),
                                              Text(
                                                fullDate,
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                                  color: isToday ? const Color(0xFF107C41) : AppColors.textMuted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                    ],
                                  ),

                                  // --- DATA ROWS ---
                                  ...List.generate(activeSheet.entries.length, (index) {
                                    final worker = activeSheet.entries[index];
                                    final rowNumber = index + 1;

                                    return TableRow(
                                      children: [
                                        // 1. No. (Centered)
                                        Container(
                                          height: 46,
                                          alignment: Alignment.center,
                                          child: Text(
                                            '$rowNumber',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted),
                                          ),
                                        ),
                                        // 2. Worker's Name (Centered)
                                        Container(
                                          height: 46,
                                          alignment: Alignment.center,
                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                          child: Text(
                                            worker.workerName,
                                            textAlign: TextAlign.center,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                          ),
                                        ),
                                        // 3. Assigned Area (Centered)
                                        Container(
                                          height: 46,
                                          alignment: Alignment.center,
                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.location_on, size: 12, color: AppColors.textMuted),
                                              const SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  worker.assignedAreaName,
                                                  textAlign: TextAlign.center,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // 4-10: 7 Days Attendance Indicators (Centered)
                                        ..._weekDays.map((date) {
                                          final logsForDay = allLogs.where((l) {
                                            return (l.userId == worker.userId || l.workerName == worker.workerName) &&
                                                l.timestamp.year == date.year &&
                                                l.timestamp.month == date.month &&
                                                l.timestamp.day == date.day;
                                          }).toList();

                                          final status = _evaluateAttendance(
                                            worker: worker,
                                            date: date,
                                            workerLogsForDay: logsForDay,
                                            activeLeaves: allLeaves,
                                          );

                                          final color = _getStatusColor(status);

                                          return InkWell(
                                            onTap: () => _showCellDetailsDialog(
                                              context: context,
                                              worker: worker,
                                              date: date,
                                              status: status,
                                              logs: logsForDay,
                                            ),
                                            child: Container(
                                              height: 46,
                                              alignment: Alignment.center,
                                              child: Tooltip(
                                                message: '${worker.workerName} • ${DateFormat('EEE, MMM d').format(date)}: ${_getStatusLabel(status)}',
                                                child: Container(
                                                  width: 32,
                                                  height: 26,
                                                  decoration: BoxDecoration(
                                                    color: color,
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(
                                                      color: status == CellAttendanceStatus.dayOff
                                                          ? const Color(0xFFCBD5E1)
                                                          : Colors.black12,
                                                      width: 1,
                                                    ),
                                                  ),
                                                  alignment: Alignment.center,
                                                  child: status == CellAttendanceStatus.dayOff
                                                      ? const Text('OFF', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))
                                                      : status == CellAttendanceStatus.onLeave
                                                          ? const Text('LV', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white))
                                                          : status == CellAttendanceStatus.pendingFuture
                                                              ? const Text('-', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)))
                                                              : null,
                                                ),
                                              ),
                                            ),
                                          );
                                        }),
                                      ],
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label, {bool hasBorder = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: hasBorder ? const Color(0xFF94A3B8) : Colors.black12),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
      ],
    );
  }
}

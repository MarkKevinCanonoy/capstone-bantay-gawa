import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/toast_notification.dart';
import '../../core/widgets/confirmation_dialog.dart';
import '../../data/models/user_model.dart';
import '../../data/models/work_area_model.dart';
import '../../data/models/attendance_model.dart';
import '../../data/models/accomplishment_model.dart';
import '../../data/repositories/repository_provider.dart';
import '../../core/utils/file_downloader_helper.dart';
import '../../core/utils/official_report_pdf_helper.dart';

class ReportsView extends ConsumerStatefulWidget {
  const ReportsView({super.key});

  @override
  ConsumerState<ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends ConsumerState<ReportsView> {
  String _selectedReportType = 'attendance';
  String _selectedDateRange = 'week';
  String _selectedArea = 'all';
  String _selectedWorker = 'all';

  // Enhanced Date Filtering State
  int _selectedYear = 2026;
  int _selectedMonth = 9;
  int _selectedWeek = 0; // 0 = Whole Month, 1 = Week 1, 2 = Week 2, 3 = Week 3, 4 = Week 4, 5 = Week 5
  late DateTime _customStartDate;
  late DateTime _customEndDate;

  static const List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  bool _isPointInPolygon(double lat, double lng, List<LatLng> polygon) {
    if (polygon.length < 3) return true;
    bool isInside = false;
    for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      if (((polygon[i].latitude > lat) != (polygon[j].latitude > lat)) &&
          (lng <
              (polygon[j].longitude - polygon[i].longitude) *
                      (lat - polygon[i].latitude) /
                      (polygon[j].latitude - polygon[i].latitude) +
                  polygon[i].longitude)) {
        isInside = !isInside;
      }
    }
    return isInside;
  }

  double _computeDistanceMeters(double lat1, double lng1, double lat2, double lng2) {
    const double r = 6371000;
    final double phi1 = lat1 * math.pi / 180;
    final double phi2 = lat2 * math.pi / 180;
    final double deltaPhi = (lat2 - lat1) * math.pi / 180;
    final double deltaLambda = (lng2 - lng1) * math.pi / 180;

    final double a = math.sin(deltaPhi / 2) * math.sin(deltaPhi / 2) +
        math.cos(phi1) * math.cos(phi2) * math.sin(deltaLambda / 2) * math.sin(deltaLambda / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  double? _computeMinDistanceToPolygonMeters(double lat, double lng, List<LatLng> polygon) {
    if (polygon.isEmpty) return null;
    double minDistance = double.infinity;
    for (final point in polygon) {
      final d = _computeDistanceMeters(lat, lng, point.latitude, point.longitude);
      if (d < minDistance) {
        minDistance = d;
      }
    }
    return minDistance;
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
    _customStartDate = now.subtract(const Duration(days: 7));
    _customEndDate = now;
  }

  DateTimeRange _computeEffectiveDateRange() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day, 0, 0, 0);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    switch (_selectedDateRange) {
      case 'today':
        return DateTimeRange(start: todayStart, end: todayEnd);
      case '3_days':
        final start = todayStart.subtract(const Duration(days: 2));
        return DateTimeRange(start: start, end: todayEnd);
      case 'week':
        final start = todayStart.subtract(const Duration(days: 6));
        return DateTimeRange(start: start, end: todayEnd);
      case '14_days':
        final start = todayStart.subtract(const Duration(days: 13));
        return DateTimeRange(start: start, end: todayEnd);
      case 'month':
        final start = DateTime(now.year, now.month, 1, 0, 0, 0);
        final lastDay = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        return DateTimeRange(start: start, end: lastDay);
      case '30_days':
        final start = todayStart.subtract(const Duration(days: 29));
        return DateTimeRange(start: start, end: todayEnd);
      case 'last_month':
        final prevMonthFirst = DateTime(now.year, now.month - 1, 1, 0, 0, 0);
        final prevMonthLast = DateTime(now.year, now.month, 0, 23, 59, 59);
        return DateTimeRange(start: prevMonthFirst, end: prevMonthLast);
      case 'month_week':
        final year = _selectedYear;
        final month = _selectedMonth;
        if (_selectedWeek == 0) {
          final start = DateTime(year, month, 1, 0, 0, 0);
          final end = DateTime(year, month + 1, 0, 23, 59, 59);
          return DateTimeRange(start: start, end: end);
        } else {
          final startDay = (_selectedWeek - 1) * 7 + 1;
          final maxDayInMonth = DateTime(year, month + 1, 0).day;
          final clampedStartDay = startDay <= maxDayInMonth ? startDay : maxDayInMonth;
          final calculatedEnd = _selectedWeek * 7;
          final endDay = calculatedEnd < maxDayInMonth ? calculatedEnd : maxDayInMonth;
          final start = DateTime(year, month, clampedStartDay, 0, 0, 0);
          final end = DateTime(year, month, endDay, 23, 59, 59);
          return DateTimeRange(start: start, end: end);
        }
      case 'custom':
        final start = DateTime(_customStartDate.year, _customStartDate.month, _customStartDate.day, 0, 0, 0);
        final end = DateTime(_customEndDate.year, _customEndDate.month, _customEndDate.day, 23, 59, 59);
        return DateTimeRange(start: start, end: end);
      default:
        return DateTimeRange(start: todayStart.subtract(const Duration(days: 6)), end: todayEnd);
    }
  }

  String _formatDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String _getDateRangeLabel() {
    final range = _computeEffectiveDateRange();
    final startStr = _formatDate(range.start);
    final endStr = _formatDate(range.end);

    switch (_selectedDateRange) {
      case 'today':
        return 'Today ($startStr)';
      case '3_days':
        return 'Past 3 Days ($startStr to $endStr)';
      case 'week':
        return 'Past 7 Days ($startStr to $endStr)';
      case '14_days':
        return 'Past 14 Days ($startStr to $endStr)';
      case 'month':
        return 'This Month ($startStr to $endStr)';
      case '30_days':
        return 'Past 30 Days ($startStr to $endStr)';
      case 'last_month':
        return 'Last Month ($startStr to $endStr)';
      case 'month_week':
        final monthName = _monthNames[_selectedMonth - 1];
        final weekName = _selectedWeek == 0 ? 'All Weeks' : 'Week $_selectedWeek';
        return '$monthName $_selectedYear - $weekName ($startStr to $endStr)';
      case 'custom':
        return 'Custom ($startStr to $endStr)';
      default:
        return '$startStr to $endStr';
    }
  }

  String _getDateRangeSummaryLabel() {
    final range = _computeEffectiveDateRange();
    final startStr = '${range.start.month}/${range.start.day}';
    final endStr = '${range.end.month}/${range.end.day}/${range.end.year}';

    switch (_selectedDateRange) {
      case 'today':
        return 'Today ($startStr)';
      case '3_days':
        return '3 Days ($startStr - $endStr)';
      case 'week':
        return '7 Days ($startStr - $endStr)';
      case '14_days':
        return '14 Days ($startStr - $endStr)';
      case 'month':
        return 'This Month (${_monthNames[range.start.month - 1]})';
      case '30_days':
        return '30 Days ($startStr - $endStr)';
      case 'last_month':
        return 'Last Month (${_monthNames[range.start.month - 1]})';
      case 'month_week':
        final monthName = _monthNames[_selectedMonth - 1];
        final weekName = _selectedWeek == 0 ? 'All' : 'Wk $_selectedWeek';
        return '$monthName $weekName ($startStr - $endStr)';
      case 'custom':
        return 'Custom ($startStr - $endStr)';
      default:
        return '$startStr - $endStr';
    }
  }

  Future<void> _pickStartDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _customStartDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light().copyWith(
              primary: AppColors.accentBlue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _customStartDate = picked;
        if (_customEndDate.isBefore(picked)) {
          _customEndDate = picked;
        }
      });
    }
  }

  Future<void> _pickEndDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _customEndDate.isBefore(_customStartDate) ? _customStartDate : _customEndDate,
      firstDate: _customStartDate,
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light().copyWith(
              primary: AppColors.accentBlue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _customEndDate = picked;
      });
    }
  }

  ({
    List<AttendanceModel> attendance,
    List<WorkAreaModel> areas,
    List<UserModel> workers,
    List<AccomplishmentModel> accomplishments,
  }) _getFilteredData() {
    final currentUser = ref.read(currentUserProvider);
    final rawWorkAreas = ref.read(workAreasProvider).value ?? [];
    final rawEmployees = ref.read(employeesProvider).value ?? [];
    final rawAttendance = ref.read(attendanceProvider).value ?? [];
    final rawAccomplishments = ref.read(accomplishmentsProvider).value ?? [];

    final availableAreas = currentUser.role == UserRole.supervisor
        ? rawWorkAreas.where((a) => a.supervisorId == currentUser.userId).toList()
        : rawWorkAreas;

    final availableWorkers = currentUser.role == UserRole.supervisor
        ? rawEmployees
            .where((u) => u.role == UserRole.worker && availableAreas.any((a) => a.workareaId == u.assignedAreaId))
            .toList()
        : rawEmployees.where((u) => u.role == UserRole.worker).toList();

    final effectiveRange = _computeEffectiveDateRange();
    final rangeStartDay = DateTime(effectiveRange.start.year, effectiveRange.start.month, effectiveRange.start.day);
    final rangeEndDay = DateTime(effectiveRange.end.year, effectiveRange.end.month, effectiveRange.end.day, 23, 59, 59);

    final filteredAttendance = rawAttendance.where((log) {
      final matchesArea = _selectedArea == 'all' || log.workareaId == _selectedArea;
      final matchesWorker = _selectedWorker == 'all' || log.userId == _selectedWorker;
      final matchesDate = (log.timestamp.isAfter(effectiveRange.start) || log.timestamp.isAtSameMomentAs(effectiveRange.start)) &&
                          (log.timestamp.isBefore(effectiveRange.end) || log.timestamp.isAtSameMomentAs(effectiveRange.end));
      return matchesArea && matchesWorker && matchesDate;
    }).toList();

    final filteredAreas = availableAreas.where((a) {
      return _selectedArea == 'all' || a.workareaId == _selectedArea;
    }).toList();

    final filteredWorkers = availableWorkers.where((w) {
      final matchesArea = _selectedArea == 'all' || w.assignedAreaId == _selectedArea;
      final matchesWorker = _selectedWorker == 'all' || w.userId == _selectedWorker;
      return matchesArea && matchesWorker;
    }).toList();

    final filteredAccomplishments = rawAccomplishments.where((acc) {
      final matchesArea = _selectedArea == 'all' || acc.workareaId == _selectedArea;
      final matchesWorker = _selectedWorker == 'all' || acc.userId == _selectedWorker;
      final accDate = DateTime.tryParse(acc.capturedDate);
      bool matchesDate = true;
      if (accDate != null) {
        final target = DateTime(accDate.year, accDate.month, accDate.day, 12, 0, 0);
        matchesDate = (target.isAfter(rangeStartDay) || target.isAtSameMomentAs(rangeStartDay)) &&
                      (target.isBefore(rangeEndDay) || target.isAtSameMomentAs(rangeEndDay));
      }
      return matchesArea && matchesWorker && matchesDate;
    }).toList();

    int statusPriority(String status) {
      final s = status.toLowerCase();
      if (s == 'pending') return 1;
      if (s == 'approved' || s == 'accepted') return 2;
      if (s == 'denied' || s == 'rejected') return 3;
      return 2;
    }

    filteredAccomplishments.sort((a, b) {
      final rankA = statusPriority(a.status);
      final rankB = statusPriority(b.status);
      if (rankA != rankB) return rankA.compareTo(rankB);
      final cmp = b.capturedDate.compareTo(a.capturedDate);
      return cmp != 0 ? cmp : b.capturedTime.compareTo(a.capturedTime);
    });

    return (
      attendance: filteredAttendance,
      areas: filteredAreas,
      workers: filteredWorkers,
      accomplishments: filteredAccomplishments,
    );
  }

  void _showSendReportToAdminDialog() {
    final currentUser = ref.read(currentUserProvider);
    final filtered = _getFilteredData();
    final noteController = TextEditingController();

    int recordCount = 0;
    if (_selectedReportType == 'attendance') {
      recordCount = filtered.attendance.length;
    } else if (_selectedReportType == 'area_performance') {
      recordCount = filtered.areas.length;
    } else if (_selectedReportType == 'worker_performance') {
      recordCount = filtered.workers.length;
    } else {
      recordCount = filtered.accomplishments.length;
    }

    final typeLabel = _selectedReportType == 'attendance'
        ? 'Attendance Summary'
        : _selectedReportType == 'area_performance'
            ? 'Area Performance'
            : _selectedReportType == 'worker_performance'
                ? 'Worker Performance'
                : 'Accomplishment Report';

    ConfirmationDialog.show(
      context,
      title: 'Send Report Copy to Admin',
      message: 'Transmit an official supervisory report audit copy to Central Administration.',
      confirmLabel: 'Send to Admin',
      confirmVariant: ButtonVariant.primary,
      contentWidget: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.statusOptimalBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.accentBlue.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Report Type:', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        typeLabel,
                        textAlign: TextAlign.end,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Date Horizon:', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getDateRangeLabel(),
                        textAlign: TextAlign.end,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Sector Scope:', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedArea == 'all'
                            ? (currentUser.assignedAreaName ?? 'Assigned Sectors')
                            : _selectedArea,
                        textAlign: TextAlign.end,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.accentBlue),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Compiled Records:', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$recordCount records',
                        textAlign: TextAlign.end,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text('Transmittal Remarks / Audit Notes (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: noteController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'e.g. Verified 100% on-site completion for morning shift. Requesting review for relief shift staffing.',
            ),
          ),
        ],
      ),
      onConfirm: () async {
        final note = noteController.text.trim();
        final summary = '$typeLabel (${_getDateRangeLabel()}) — $recordCount records compiled.';
        await ref.read(dataRepositoryProvider).sendReportToAdmin(
              reportType: typeLabel,
              summary: summary,
              note: note.isNotEmpty ? note : null,
              supervisorId: currentUser.userId,
              supervisorName: currentUser.fullName,
            );
        if (mounted) {
          ToastNotification.show(
            context,
            message: 'Report transmittal memo sent to Central Admin.',
            type: ToastType.success,
          );
        }
      },
    );
  }

  void _exportPdf() async {
    final currentUser = ref.read(currentUserProvider);
    final filtered = _getFilteredData();
    final workAreas = filtered.areas;
    final employees = filtered.workers;
    final attendance = filtered.attendance;
    final accomplishments = filtered.accomplishments;

    String reportTitle = 'Attendance Compliance & Verification Audit';
    String subtitle = 'Verified biometric clock-in and clock-out activity logs across Ormoc sectors.';
    List<String> headers = ['Worker Name', 'Work Sector', 'Time In', 'Time Out', 'Geofence Compliance', 'Verification'];
    List<List<String>> dataRows = [];
    PdfPageFormat pageFormat = PdfPageFormat.a4;
    Map<int, pw.TableColumnWidth>? columnWidths;

    if (_selectedReportType == 'area_performance') {
      reportTitle = 'Work Area Performance & Sector Coverage Audit';
      subtitle = 'Geofence boundaries, assigned personnel quotas, and active supervisory oversight.';
      headers = ['Sector Name', 'Supervising Officer', 'Assigned Personnel', 'Coverage Area', 'Status'];
      dataRows = workAreas.map((a) => [
        a.name,
        a.supervisorName,
        '${a.assignedCount} Personnel',
        WorkAreaModel.formatPolygonArea(a.polygon),
        a.status.toUpperCase(),
      ]).toList();
      columnWidths = {
        0: const pw.FlexColumnWidth(2.0),
        1: const pw.FlexColumnWidth(2.2),
        2: const pw.FlexColumnWidth(1.6),
        3: const pw.FlexColumnWidth(1.2),
        4: const pw.FlexColumnWidth(1.2),
      };
    } else if (_selectedReportType == 'worker_performance') {
      reportTitle = 'Worker Performance & Standing Audit';
      subtitle = 'Workforce compliance ratings, operational reliability, and sector postings.';
      headers = ['Personnel Name', 'Assigned Sector', 'Designation', 'Compliance Status', 'Standing'];
      dataRows = employees.where((e) => e.role == UserRole.worker).map((e) => [
        e.fullName,
        e.assignedAreaName ?? 'Unassigned',
        e.roleDisplayName,
        e.creditScore >= 80 ? 'Good Standing' : e.creditScore >= 50 ? 'Under Review' : 'Action Required',
        e.creditScore >= 80 ? 'Optimal' : e.creditScore >= 50 ? 'Warning' : 'Critical',
      ]).toList();
      columnWidths = {
        0: const pw.FlexColumnWidth(2.2),
        1: const pw.FlexColumnWidth(2.0),
        2: const pw.FlexColumnWidth(1.6),
        3: const pw.FlexColumnWidth(1.2),
        4: const pw.FlexColumnWidth(1.2),
      };
    } else if (_selectedReportType == 'accomplishments') {
      reportTitle = 'Field Accomplishment Proof & Task Completion Audit';
      subtitle = 'Geotagged proof submissions, timestamp logs, and supervisor review endorsements.';
      headers = ['Personnel Name', 'Work Sector', 'Captured Date', 'Time', 'Coordinates', 'Review Status'];
      dataRows = accomplishments.map((acc) => [
        acc.workerName,
        acc.areaName,
        acc.capturedDate,
        acc.capturedTime,
        '${acc.capturedLat.toStringAsFixed(4)}, ${acc.capturedLng.toStringAsFixed(4)}',
        acc.status.toUpperCase(),
      ]).toList();
      columnWidths = {
        0: const pw.FlexColumnWidth(2.0),
        1: const pw.FlexColumnWidth(1.8),
        2: const pw.FlexColumnWidth(1.4),
        3: const pw.FlexColumnWidth(1.2),
        4: const pw.FlexColumnWidth(2.0),
        5: const pw.FlexColumnWidth(1.4),
      };
    } else {
      // Default: Attendance
      dataRows = attendance.map((log) {
        final matchingArea = workAreas.where((a) => a.workareaId == log.workareaId || a.name.toLowerCase() == log.areaName.toLowerCase()).firstOrNull;
        final bool hasCoords = log.gpsLat != 0.0 && log.gpsLng != 0.0;
        final bool isInside = (matchingArea != null && matchingArea.polygon.length >= 3 && hasCoords)
            ? _isPointInPolygon(log.gpsLat, log.gpsLng, matchingArea.polygon)
            : !log.hasWarning;
        return [
          log.workerName,
          log.areaName,
          log.timeIn,
          log.timeOut,
          !hasCoords ? 'NO GPS' : isInside ? 'IN-ZONE' : 'OUT-OF-BOUNDS',
          log.isVerified ? 'VERIFIED' : 'PENDING',
        ];
      }).toList();
      columnWidths = {
        0: const pw.FlexColumnWidth(2.2),
        1: const pw.FlexColumnWidth(2.0),
        2: const pw.FlexColumnWidth(1.4),
        3: const pw.FlexColumnWidth(1.4),
        4: const pw.FlexColumnWidth(1.8),
        5: const pw.FlexColumnWidth(1.4),
      };
    }

    final sectorLabel = _selectedArea == 'all'
        ? (currentUser.role == UserRole.supervisor ? (currentUser.assignedAreaName ?? 'Assigned Sectors') : 'All Ormoc Sectors')
        : _selectedArea;

    try {
      final pdfBytes = await OfficialReportPdfHelper.generateAuditPdf(
        reportTitle: reportTitle,
        subtitle: subtitle,
        headers: headers,
        dataRows: dataRows,
        generatedBy: currentUser,
        dateRangeLabel: _getDateRangeLabel(),
        sectorLabel: sectorLabel,
        columnWidths: columnWidths,
        pageFormat: pageFormat,
      );

      final dateTag = '${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}';
      final filename = 'BantayGawa_${_selectedReportType}_$dateTag.pdf';
      downloadBytes(
        filename: filename,
        bytes: pdfBytes,
        mimeType: 'application/pdf',
      );

      if (mounted) {
        ToastNotification.show(context, message: 'Official PDF report downloaded ($filename).', type: ToastType.success);
      }
    } catch (e) {
      if (mounted) {
        ToastNotification.show(context, message: 'Failed to generate PDF: $e', type: ToastType.error);
      }
    }
  }

  void _exportCsv() {
    final currentUser = ref.read(currentUserProvider);
    final filtered = _getFilteredData();
    final workAreas = filtered.areas;
    final employees = filtered.workers;
    final attendance = filtered.attendance;
    final accomplishments = filtered.accomplishments;

    List<List<String>> dataRows = [];

    if (_selectedReportType == 'area_performance') {
      dataRows = [
        ['Work Area ID', 'Area Name', 'Supervisor', 'Assigned Workers', 'Status'],
        ...workAreas.map((a) => [a.workareaId, a.name, a.supervisorName, '${a.assignedCount}', a.status]),
      ];
    } else if (_selectedReportType == 'worker_performance') {
      dataRows = [
        ['User ID', 'Worker Name', 'Role', 'Assigned Area', 'Compliance Status', 'Standing'],
        ...employees.where((e) => e.role == UserRole.worker).map((e) => [
          e.userId,
          e.fullName,
          e.roleDisplayName,
          e.assignedAreaName ?? 'Unassigned',
          e.creditScore >= 80 ? 'Good Standing' : e.creditScore >= 50 ? 'Under Review' : 'Action Required',
          e.creditScore >= 80 ? 'Optimal' : e.creditScore >= 50 ? 'Warning' : 'Critical',
        ]),
      ];
    } else if (_selectedReportType == 'accomplishments') {
      dataRows = [
        ['Accomplishment ID', 'Worker Name', 'Area Name', 'Date', 'Time', 'Latitude', 'Longitude', 'Status'],
        ...accomplishments.map((a) => [
          a.accomplishmentId,
          a.workerName,
          a.areaName,
          a.capturedDate,
          a.capturedTime,
          '${a.capturedLat}',
          '${a.capturedLng}',
          a.status,
        ]),
      ];
    } else {
      dataRows = [
        ['Attendance ID', 'Worker Name', 'Employee ID', 'Work Area', 'Time In', 'Time Out', 'Geofence Compliance', 'GPS Coordinates', 'Face Match', 'Verified'],
        ...attendance.map((log) {
          final matchingArea = workAreas.where((a) => a.workareaId == log.workareaId || a.name.toLowerCase() == log.areaName.toLowerCase()).firstOrNull;
          final bool hasCoords = log.gpsLat != 0.0 && log.gpsLng != 0.0;
          final bool isInside = (matchingArea != null && matchingArea.polygon.length >= 3 && hasCoords)
              ? _isPointInPolygon(log.gpsLat, log.gpsLng, matchingArea.polygon)
              : !log.hasWarning;
          final complianceStr = !hasCoords ? 'NO GPS SIGNAL' : (isInside ? 'IN-ZONE COMPLIANT' : 'OUT-OF-BOUNDS');
          final coordsStr = hasCoords ? '${log.gpsLat.toStringAsFixed(5)}, ${log.gpsLng.toStringAsFixed(5)}' : 'N/A';
          return [
            log.attendanceId,
            log.workerName,
            log.workerEmpId,
            log.areaName,
            log.timeIn,
            log.timeOut,
            complianceStr,
            coordsStr,
            log.faceMatch ? 'TRUE' : 'FALSE',
            log.isVerified ? 'TRUE' : 'FALSE',
          ];
        }),
      ];
    }

    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final sectorLabel = _selectedArea == 'all'
        ? (currentUser.role == UserRole.supervisor ? (currentUser.assignedAreaName ?? 'Assigned Sectors') : 'All Ormoc Sectors')
        : _selectedArea;

    final csvRows = <List<String>>[
      // Official Agency Header
      ['REPUBLIC OF THE PHILIPPINES - CITY GOVERNMENT OF ORMOC'],
      ['CITY ENVIRONMENT AND NATURAL RESOURCES OFFICE (ENRO)'],
      ['BANTAYGAWA - ENRO ORMOC CITY PORTAL - OFFICIAL AUDIT EXPORT'],
      [''],
      ['Report Category:', _selectedReportType.toUpperCase()],
      ['Reporting Scope:', _getDateRangeLabel()],
      ['Sector Scope:', sectorLabel],
      ['Generated By:', '${currentUser.fullName} (${currentUser.roleDisplayName})'],
      ['Generated On:', dateStr],
      ['Total Records:', '${dataRows.length - 1}'],
      [''],
      ...dataRows,
      [''],
      ['OFFICIAL LGU SIGNATORIES'],
      ['Prepared By:', currentUser.fullName, currentUser.role == UserRole.admin ? 'System Administrator / Head Clerk' : 'Field Operations Supervisor'],
      ['Verified / Reviewed By:', 'FIELD OPERATIONS SUPERVISOR', 'City ENRO Ormoc'],
      ['Approved By:', 'CITY ENRO DEPARTMENT HEAD', 'City Environment & Natural Resources Office, LGU Ormoc City'],
    ];

    final csvString = csvRows.map((r) => r.map((c) => '"${c.replaceAll('"', '""')}"').join(',')).join('\n');
    final dateTag = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    final fileName = 'BantayGawa_${_selectedReportType}_$dateTag.csv';

    downloadFile(
      filename: fileName,
      content: csvString,
    );

    ToastNotification.show(
      context,
      message: 'Downloaded $fileName (${dataRows.length - 1} records).',
      type: ToastType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final workAreasAsync = ref.watch(workAreasProvider);
    final employeesAsync = ref.watch(employeesProvider);
    final attendanceAsync = ref.watch(attendanceProvider);
    final accomplishmentsAsync = ref.watch(accomplishmentsProvider);

    final rawWorkAreas = workAreasAsync.value ?? [];
    final rawEmployees = employeesAsync.value ?? [];

    // Filter work areas based on supervisor role (UC-05 Alt Flow 1)
    final availableAreas = currentUser.role == UserRole.supervisor
        ? rawWorkAreas.where((a) => a.supervisorId == currentUser.userId).toList()
        : rawWorkAreas;

    final availableWorkers = rawEmployees.where((u) => u.role == UserRole.worker).toList();

    // Retrieve active filtered data across Area, Worker, and Date Range
    final filtered = _getFilteredData();
    final filteredAttendance = filtered.attendance;
    final filteredAreas = filtered.areas;
    final filteredWorkers = filtered.workers;
    final filteredAccomplishments = filtered.accomplishments;

    int activeRecordCount = 0;
    if (_selectedReportType == 'area_performance') {
      activeRecordCount = filteredAreas.length;
    } else if (_selectedReportType == 'worker_performance') {
      activeRecordCount = filteredWorkers.length;
    } else if (_selectedReportType == 'accomplishments') {
      activeRecordCount = filteredAccomplishments.length;
    } else {
      activeRecordCount = filteredAttendance.length;
    }

    final isCategoryLoading = (_selectedReportType == 'accomplishments' && accomplishmentsAsync.isLoading && filteredAccomplishments.isEmpty) ||
        (_selectedReportType == 'attendance' && attendanceAsync.isLoading && filteredAttendance.isEmpty);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Analytical Reports & Exports', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    Text(
                      currentUser.role == UserRole.admin
                          ? 'Generate, preview, and download compliance audits across all Ormoc sectors.'
                          : 'Attendance summaries and worker logs scoped to your assigned work areas.',
                      style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Row(
                children: [
                  if (currentUser.role == UserRole.supervisor) ...[
                    AppButton(
                      label: 'Send Report to Admin',
                      icon: Icons.send_outlined,
                      variant: ButtonVariant.secondary,
                      onPressed: _showSendReportToAdminDialog,
                    ),
                    const SizedBox(width: 12),
                  ],
                  AppButton(
                    label: 'Export CSV / Excel',
                    icon: Icons.table_chart_outlined,
                    variant: ButtonVariant.secondary,
                    onPressed: _exportCsv,
                  ),
                  const SizedBox(width: 12),
                  AppButton(
                    label: 'Export Official PDF',
                    icon: Icons.picture_as_pdf_outlined,
                    variant: ButtonVariant.primary,
                    onPressed: _exportPdf,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Filters Card
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 220,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Report Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        key: ValueKey('report_type_$_selectedReportType'),
                        isExpanded: true,
                        initialValue: _selectedReportType,
                        items: const [
                          DropdownMenuItem(value: 'attendance', child: Text('Attendance Summary')),
                          DropdownMenuItem(value: 'area_performance', child: Text('Area Performance')),
                          DropdownMenuItem(value: 'worker_performance', child: Text('Worker Performance')),
                          DropdownMenuItem(value: 'accomplishments', child: Text('Accomplishment Report')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedReportType = val);
                        },
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 210,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Date Range', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        key: ValueKey('date_range_$_selectedDateRange'),
                        isExpanded: true,
                        initialValue: _selectedDateRange,
                        items: const [
                          DropdownMenuItem(value: 'today', child: Text('Today')),
                          DropdownMenuItem(value: '3_days', child: Text('Past 3 Days')),
                          DropdownMenuItem(value: 'week', child: Text('Past 7 Days (Week)')),
                          DropdownMenuItem(value: '14_days', child: Text('Past 14 Days (2 Weeks)')),
                          DropdownMenuItem(value: 'month', child: Text('This Month')),
                          DropdownMenuItem(value: '30_days', child: Text('Past 30 Days')),
                          DropdownMenuItem(value: 'last_month', child: Text('Last Month')),
                          DropdownMenuItem(value: 'month_week', child: Text('Month & Week of Month...')),
                          DropdownMenuItem(value: 'custom', child: Text('Custom Date Range...')),
                        ],
                        onChanged: (val) {
                          if (val == null) return;
                          setState(() => _selectedDateRange = val);
                        },
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_selectedDateRange == 'month_week') ...[
                  SizedBox(
                    width: 140,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Month', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<int>(
                          key: ValueKey('month_$_selectedMonth'),
                          isExpanded: true,
                          initialValue: _selectedMonth,
                          items: [
                            for (int m = 1; m <= 12; m++)
                              DropdownMenuItem(value: m, child: Text(_monthNames[m - 1])),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedMonth = val);
                          },
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Year', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<int>(
                          key: ValueKey('year_$_selectedYear'),
                          isExpanded: true,
                          initialValue: _selectedYear,
                          items: [
                            for (int y = DateTime.now().year - 2; y <= DateTime.now().year + 2; y++)
                              DropdownMenuItem(value: y, child: Text('$y')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedYear = val);
                          },
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Week of Month', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<int>(
                          key: ValueKey('week_$_selectedWeek'),
                          isExpanded: true,
                          initialValue: _selectedWeek,
                          items: const [
                            DropdownMenuItem(value: 0, child: Text('Entire Month (All)')),
                            DropdownMenuItem(value: 1, child: Text('Week 1 (Days 1–7)')),
                            DropdownMenuItem(value: 2, child: Text('Week 2 (Days 8–14)')),
                            DropdownMenuItem(value: 3, child: Text('Week 3 (Days 15–21)')),
                            DropdownMenuItem(value: 4, child: Text('Week 4 (Days 22–28)')),
                            DropdownMenuItem(value: 5, child: Text('Week 5 (Days 29–End)')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedWeek = val);
                          },
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_selectedDateRange == 'custom') ...[
                  SizedBox(
                    width: 155,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('From Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () => _pickStartDate(context),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.accentBlue),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _formatDate(_customStartDate),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 155,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('To Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () => _pickEndDate(context),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.event_available_outlined, size: 16, color: AppColors.accentBlue),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _formatDate(_customEndDate),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                SizedBox(
                  width: 220,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Work Area / Sector', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        key: ValueKey('area_$_selectedArea'),
                        isExpanded: true,
                        initialValue: _selectedArea,
                        items: [
                          const DropdownMenuItem(value: 'all', child: Text('All Monitored Sectors')),
                          ...availableAreas.map((area) => DropdownMenuItem(
                                value: area.workareaId,
                                child: Text(area.name, overflow: TextOverflow.ellipsis),
                              )),
                        ],
                        onChanged: (val) => setState(() => _selectedArea = val!),
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Field Worker', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        key: ValueKey('worker_$_selectedWorker'),
                        isExpanded: true,
                        initialValue: _selectedWorker,
                        items: [
                          const DropdownMenuItem(value: 'all', child: Text('All Field Workers')),
                          ...availableWorkers.map((w) => DropdownMenuItem(
                                value: w.userId,
                                child: Text(w.fullName, overflow: TextOverflow.ellipsis),
                              )),
                        ],
                        onChanged: (val) => setState(() => _selectedWorker = val!),
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Preview Table Header with Active Date Horizon Chip
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'REPORT PREVIEW: ${_selectedReportType.replaceAll('_', ' ').toUpperCase()}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 0.6),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.accentBlue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.accentBlue.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.date_range, size: 12, color: AppColors.accentBlue),
                        const SizedBox(width: 5),
                        Text(
                          _getDateRangeSummaryLabel(),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.accentBlue),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Text('Showing $activeRecordCount record(s) ready for compilation', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 10),

          // Preview Table / Empty State
          Expanded(
            child: AppCard(
              padding: EdgeInsets.zero,
              child: isCategoryLoading
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: AppColors.accentBlue),
                          SizedBox(height: 16),
                          Text(
                            'Compiling report records from cloud...',
                            style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    )
                  : activeRecordCount == 0
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.search_off_outlined, size: 48, color: AppColors.textMuted),
                            const SizedBox(height: 12),
                            const Text(
                              'No records found matching the selected filter criteria.',
                              style: TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Try adjusting your date horizon, work area, or worker filters.',
                              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        const minWidth = 1000.0;
                        final isWide = constraints.maxWidth >= minWidth;

                        Widget tableWidget = _buildReportTable(
                          _selectedReportType,
                          filteredAttendance,
                          filteredAreas,
                          filteredWorkers,
                          filteredAccomplishments,
                        );

                        if (!isWide) {
                          tableWidget = SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: minWidth,
                              child: tableWidget,
                            ),
                          );
                        }

                        return SingleChildScrollView(
                          child: tableWidget,
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String label, {String? tooltip}) {
    final text = Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.textMuted,
        letterSpacing: 0.5,
      ),
    );

    if (tooltip == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: text,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Tooltip(
        message: tooltip,
        preferBelow: false,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 11, height: 1.3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: text),
            const SizedBox(width: 4),
            const Icon(Icons.help_outline_rounded, size: 13, color: AppColors.accentBlue),
          ],
        ),
      ),
    );
  }

  void _inspectProofModal(AccomplishmentModel proof) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: AppColors.surface,
        titlePadding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
        contentPadding: const EdgeInsets.symmetric(horizontal: 28),
        actionsPadding: const EdgeInsets.fromLTRB(28, 16, 28, 24),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primaryNavy.withValues(alpha: 0.1),
                    child: const Icon(Icons.person, color: AppColors.primaryNavy, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          proof.workerName,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${proof.areaName} • Submitted on ${proof.capturedDate} at ${proof.capturedTime}',
                          style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            StatusBadge(
              label: proof.status.toUpperCase(),
              type: proof.status == 'approved'
                  ? BadgeType.success
                  : proof.status == 'denied'
                      ? BadgeType.danger
                      : BadgeType.warning,
            ),
          ],
        ),
        content: SizedBox(
          width: 720,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 320,
                  width: double.infinity,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.black87,
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildReportProofImage(proof),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          color: Colors.black.withValues(alpha: 0.85),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.access_time_rounded, size: 14, color: Colors.yellowAccent),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${proof.capturedDate} ${proof.capturedTime}',
                                    style: const TextStyle(color: Colors.yellowAccent, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                                  ),
                                  const SizedBox(width: 16),
                                  const Icon(Icons.location_on_rounded, size: 14, color: Colors.white),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${proof.capturedLat.toStringAsFixed(5)}° N, ${proof.capturedLng.toStringAsFixed(5)}° E',
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.accentEmerald.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppColors.accentEmerald, width: 0.8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.verified_rounded, size: 12, color: AppColors.accentEmerald),
                                    SizedBox(width: 4),
                                    Text('BURNED WATERMARK VERIFIED', style: TextStyle(color: AppColors.accentEmerald, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (proof.message.isNotEmpty) ...[
                  const Text('Field Accomplishment Notes', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(proof.message, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.4)),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          AppButton(
            label: 'Close',
            variant: ButtonVariant.secondary,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  static final Map<String, Uint8List> _reportImageMemoryCache = {};
  static final Map<String, Future<Uint8List?>> _pendingReportDownloads = {};

  Widget _buildReportProofImage(AccomplishmentModel proof) {
    final cleanUrl = proof.imageUrl.trim();
    final isNetwork = cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://');
    final isBase64 = cleanUrl.startsWith('data:image') ||
        (!isNetwork && cleanUrl.length > 100 && !cleanUrl.startsWith('/') && !cleanUrl.startsWith('file://'));

    Widget? imageContent;
    if (_reportImageMemoryCache.containsKey(cleanUrl)) {
      imageContent = Image.memory(
        _reportImageMemoryCache[cleanUrl]!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    } else if (isNetwork) {
      imageContent = Image.network(
        cleanUrl,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) {
          if (_reportImageMemoryCache.containsKey(cleanUrl)) {
            return Image.memory(
              _reportImageMemoryCache[cleanUrl]!,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            );
          }
          final future = _pendingReportDownloads.putIfAbsent(
            cleanUrl,
            () => _tryDownloadSupabaseStorage(cleanUrl),
          );
          return FutureBuilder<Uint8List?>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
                return Image.memory(
                  snapshot.data!,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                );
              }
              return _buildReportProofPlaceholder(proof);
            },
          );
        },
      );
    } else if (isBase64) {
      try {
        String cleanBase64 = cleanUrl.contains(',') ? cleanUrl.split(',').last : cleanUrl;
        cleanBase64 = cleanBase64.replaceAll(RegExp(r'\s+'), '');
        final bytes = base64Decode(cleanBase64);
        imageContent = Image.memory(
          bytes,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => _buildReportProofPlaceholder(proof),
        );
      } catch (e) {
        debugPrint('Reports view Base64 decoding error: $e');
        imageContent = null;
      }
    }

    if (imageContent != null) {
      return imageContent;
    }
    return _buildReportProofPlaceholder(proof);
  }

  Future<Uint8List?> _tryDownloadSupabaseStorage(String url) async {
    if (_reportImageMemoryCache.containsKey(url)) {
      return _reportImageMemoryCache[url];
    }
    try {
      final uri = Uri.tryParse(url);
      if (uri == null) return null;
      final segments = uri.pathSegments;
      final publicIdx = segments.indexOf('public');
      if (publicIdx != -1 && publicIdx + 2 < segments.length) {
        final bucket = segments[publicIdx + 1];
        final path = segments.sublist(publicIdx + 2).join('/');
        final bytes = await Supabase.instance.client.storage.from(bucket).download(path);
        _reportImageMemoryCache[url] = bytes;
        return bytes;
      }
    } catch (_) {}
    return null;
  }

  Widget _buildReportProofPlaceholder(AccomplishmentModel proof) {
    return Container(
      color: Colors.grey.shade900,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.camera_alt_outlined, color: Colors.white54, size: 40),
            const SizedBox(height: 8),
            Text(
              'Proof: ${proof.accomplishmentId.substring(0, proof.accomplishmentId.length.clamp(0, 8))}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportTable(
    String reportType,
    List<AttendanceModel> attendance,
    List<WorkAreaModel> areas,
    List<UserModel> workers,
    List<AccomplishmentModel> accomplishments,
  ) {
    if (reportType == 'area_performance') {
      return Table(
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        columnWidths: const {
          0: FlexColumnWidth(2.2), // WORK AREA
          1: FlexColumnWidth(2.0), // SUPERVISOR
          2: FlexColumnWidth(1.8), // ASSIGNED PERSONNEL
          3: FlexColumnWidth(1.3), // STATUS
          4: FlexColumnWidth(1.6), // CALCULATED BOUNDARY
        },
        children: [
          TableRow(
            decoration: const BoxDecoration(
              color: AppColors.surfaceSubtle,
              border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
            ),
            children: [
              _buildHeaderCell('WORK AREA'),
              _buildHeaderCell('SUPERVISOR'),
              _buildHeaderCell('ASSIGNED PERSONNEL'),
              _buildHeaderCell('STATUS'),
              _buildHeaderCell('CALCULATED BOUNDARY'),
            ],
          ),
          ...areas.map((a) {
            return TableRow(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.borderSubtle, width: 1)),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.accentBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.location_on_outlined, size: 16, color: AppColors.accentBlue),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(a.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Text(a.supervisorName, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Text('${a.assignedCount} Active Workers', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: StatusBadge(
                      label: a.status.toUpperCase(),
                      type: a.status.toLowerCase() == 'active' ? BadgeType.success : BadgeType.neutral,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Text(
                    a.areaSqKm.isNotEmpty
                        ? a.areaSqKm
                        : (a.polygon.isNotEmpty ? 'Perimeter Defined' : 'Unbounded'),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                  ),
                ),
              ],
            );
          }),
        ],
      );
    }

    if (reportType == 'worker_performance') {
      return Table(
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        columnWidths: const {
          0: FlexColumnWidth(2.2), // WORKER NAME
          1: FlexColumnWidth(2.0), // ASSIGNED AREA
          2: FlexColumnWidth(1.6), // COMPLIANCE STATUS
          3: FlexColumnWidth(1.5), // STANDING LEVEL
          4: FlexColumnWidth(1.6), // SCHEDULE
        },
        children: [
          TableRow(
            decoration: const BoxDecoration(
              color: AppColors.surfaceSubtle,
              border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
            ),
            children: [
              _buildHeaderCell('WORKER NAME'),
              _buildHeaderCell('ASSIGNED AREA'),
              _buildHeaderCell('COMPLIANCE STATUS'),
              _buildHeaderCell('STANDING LEVEL'),
              _buildHeaderCell('SCHEDULE'),
            ],
          ),
          ...workers.map((w) {
            return TableRow(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.borderSubtle, width: 1)),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: AppColors.accentBlue,
                        child: Text(
                          w.initials,
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(w.fullName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                            Text(w.username, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Text(w.assignedAreaName ?? 'Unassigned', style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Text(
                    w.creditScore >= 80 ? 'Good Standing' : w.creditScore >= 50 ? 'Under Review' : 'Action Required',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: w.creditScore >= 80
                          ? AppColors.successText
                          : w.creditScore >= 50
                              ? AppColors.warningText
                              : AppColors.dangerText,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: StatusBadge(
                      label: w.creditScore >= 80 ? 'OPTIMAL' : w.creditScore >= 50 ? 'WARNING' : 'CRITICAL',
                      type: w.creditScore >= 80 ? BadgeType.success : w.creditScore >= 50 ? BadgeType.warning : BadgeType.danger,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Text(w.schedule, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ),
              ],
            );
          }),
        ],
      );
    }

    if (reportType == 'accomplishments') {
      return Table(
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        columnWidths: const {
          0: FlexColumnWidth(1.2), // PROOF PHOTO
          1: FlexColumnWidth(2.0), // FIELD WORKER
          2: FlexColumnWidth(1.8), // WORK AREA
          3: FlexColumnWidth(1.8), // DATE & TIME
          4: FlexColumnWidth(1.8), // BURNED GPS
          5: FlexColumnWidth(1.4), // STATUS
        },
        children: [
          TableRow(
            decoration: const BoxDecoration(
              color: AppColors.surfaceSubtle,
              border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
            ),
            children: [
              _buildHeaderCell('PROOF PHOTO'),
              _buildHeaderCell('FIELD WORKER'),
              _buildHeaderCell('WORK AREA'),
              _buildHeaderCell('DATE & TIME'),
              _buildHeaderCell('BURNED GPS'),
              _buildHeaderCell('STATUS'),
            ],
          ),
          ...accomplishments.map((acc) {
            return TableRow(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.borderSubtle, width: 1)),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => _inspectProofModal(acc),
                      child: Tooltip(
                        message: 'Click to inspect full photo & metadata',
                        child: Container(
                          width: 44,
                          height: 44,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                            color: Colors.black87,
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              _buildReportProofImage(acc),
                              Positioned(
                                bottom: 2,
                                right: 2,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.black87,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.zoom_in, size: 10, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: AppColors.accentEmerald,
                        child: Text(
                          acc.workerName.isNotEmpty ? acc.workerName[0] : 'W',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(acc.workerName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Text(acc.areaName, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Text('${acc.capturedDate} ${acc.capturedTime}', style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.pin_drop_outlined, size: 14, color: AppColors.accentBlue),
                      const SizedBox(width: 4),
                      Text(
                        '${acc.capturedLat.toStringAsFixed(4)}, ${acc.capturedLng.toStringAsFixed(4)}',
                        style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: StatusBadge(
                      label: acc.status.toUpperCase(),
                      type: acc.status == 'approved' ? BadgeType.success : acc.status == 'denied' ? BadgeType.danger : BadgeType.warning,
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      );
    }

    // Default: Attendance Summary
    return Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: const {
        0: FlexColumnWidth(2.2), // WORKER NAME
        1: FlexColumnWidth(1.9), // SECTOR
        2: FlexColumnWidth(1.2), // TIME-IN
        3: FlexColumnWidth(1.2), // TIME-OUT
        4: FlexColumnWidth(2.2), // GEOFENCE COMPLIANCE
        5: FlexColumnWidth(1.6), // AUDIT VERIFICATION
      },
      children: [
        TableRow(
          decoration: const BoxDecoration(
            color: AppColors.surfaceSubtle,
            border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
          ),
          children: [
            _buildHeaderCell('WORKER NAME'),
            _buildHeaderCell('SECTOR'),
            _buildHeaderCell('TIME-IN'),
            _buildHeaderCell('TIME-OUT'),
            _buildHeaderCell(
              'GEOFENCE COMPLIANCE',
              tooltip: 'Location Verification: Verifies via GPS whether attendance was recorded inside the assigned sector boundary.',
            ),
            _buildHeaderCell('AUDIT VERIFICATION'),
          ],
        ),
        ...attendance.map((log) {
          final matchingArea = areas.where((a) => a.workareaId == log.workareaId || a.name.toLowerCase() == log.areaName.toLowerCase()).firstOrNull;
          final bool hasCoords = log.gpsLat != 0.0 && log.gpsLng != 0.0;
          final bool isInside = (matchingArea != null && matchingArea.polygon.length >= 3 && hasCoords)
              ? _isPointInPolygon(log.gpsLat, log.gpsLng, matchingArea.polygon)
              : !log.hasWarning;

          double? breachMeters;
          if (!isInside && hasCoords && matchingArea != null && matchingArea.polygon.isNotEmpty) {
            breachMeters = _computeMinDistanceToPolygonMeters(log.gpsLat, log.gpsLng, matchingArea.polygon);
          }

          final complianceStatusText = !hasCoords
              ? 'No GPS Lock'
              : isInside
                  ? 'In-Zone (On-Site)'
                  : (breachMeters != null && breachMeters > 0)
                      ? 'Out-of-Bounds (+${breachMeters.round()}m)'
                      : 'Out-of-Bounds';

          final complianceColor = !hasCoords
              ? AppColors.textMuted
              : isInside
                  ? const Color(0xFF059669)
                  : AppColors.brightRed;

          final complianceIcon = !hasCoords
              ? Icons.location_off_outlined
              : isInside
                  ? Icons.check_circle_rounded
                  : Icons.cancel_outlined;

          return TableRow(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.borderSubtle, width: 1)),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: AppColors.primaryNavy,
                      child: Text(
                        log.workerName.isNotEmpty ? log.workerName[0] : 'W',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(log.workerName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          if (log.workerEmpId.isNotEmpty)
                            Text(log.workerEmpId, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Text(log.areaName, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Text(log.timeIn, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Text(log.timeOut, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(complianceIcon, color: complianceColor, size: 15),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            complianceStatusText,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: complianceColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (hasCoords) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${log.gpsLat.toStringAsFixed(5)}°, ${log.gpsLng.toStringAsFixed(5)}°',
                        style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontFamily: 'monospace'),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: StatusBadge(
                    label: log.isVerified ? 'VERIFIED' : 'PENDING AUDIT',
                    type: log.isVerified ? BadgeType.success : BadgeType.warning,
                    icon: log.isVerified ? Icons.verified_user_outlined : Icons.hourglass_empty_rounded,
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }
}

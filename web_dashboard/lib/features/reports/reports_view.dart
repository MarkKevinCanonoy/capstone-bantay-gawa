import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/toast_notification.dart';
import '../../data/models/user_model.dart';
import '../../data/models/work_area_model.dart';
import '../../data/models/attendance_model.dart';
import '../../data/models/accomplishment_model.dart';
import '../../data/repositories/repository_provider.dart';

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

    final availableWorkers = rawEmployees.where((u) => u.role == UserRole.worker).toList();

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

    return (
      attendance: filteredAttendance,
      areas: filteredAreas,
      workers: filteredWorkers,
      accomplishments: filteredAccomplishments,
    );
  }

  void _exportPdf() async {
    final currentUser = ref.read(currentUserProvider);
    final filtered = _getFilteredData();
    final workAreas = filtered.areas;
    final employees = filtered.workers;
    final attendance = filtered.attendance;
    final accomplishments = filtered.accomplishments;

    final pdf = pw.Document();

    String reportTitle = 'Attendance Summary Audit';
    List<String> headers = ['Worker Name', 'Work Area', 'Time In', 'Time Out', 'Face Match', 'Status'];
    List<List<String>> dataRows = [];

    if (_selectedReportType == 'area_performance') {
      reportTitle = 'Work Area Performance & Coverage Audit';
      headers = ['Area Name', 'Supervisor', 'Assigned Workers', 'Status', 'Area Coverage'];
      dataRows = workAreas.map((a) => [
        a.name,
        a.supervisorName,
        '${a.assignedCount} Personnel',
        a.status,
        a.areaSqKm,
      ]).toList();
    } else if (_selectedReportType == 'worker_performance') {
      reportTitle = 'Worker Performance & Star Credit Audit';
      headers = ['Worker Name', 'Assigned Area', 'Role', 'Credit Points', 'Standing'];
      dataRows = employees.where((e) => e.role == UserRole.worker).map((e) => [
        e.fullName,
        e.assignedAreaName ?? 'Unassigned',
        e.roleDisplayName,
        '${e.creditScore} / 100',
        e.creditScore >= 80 ? 'Optimal' : e.creditScore >= 50 ? 'Warning' : 'Critical',
      ]).toList();
    } else if (_selectedReportType == 'accomplishments') {
      reportTitle = 'Field Accomplishment & Proof Audit';
      headers = ['Worker Name', 'Work Area', 'Date', 'Time', 'GPS Coordinates', 'Review Status'];
      dataRows = accomplishments.map((acc) => [
        acc.workerName,
        acc.areaName,
        acc.capturedDate,
        acc.capturedTime,
        '${acc.capturedLat.toStringAsFixed(4)}, ${acc.capturedLng.toStringAsFixed(4)}',
        acc.status.toUpperCase(),
      ]).toList();
    } else {
      // Default: Attendance
      dataRows = attendance.map((log) => [
        log.workerName,
        log.areaName,
        log.timeIn,
        log.timeOut,
        log.faceMatch ? 'Yes' : 'No',
        log.isVerified ? 'Verified' : 'Unverified',
      ]).toList();
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('BantayGawa - $reportTitle', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                        pw.Text('Environment and Natural Resources Office (ENRO) - Ormoc City', style: const pw.TextStyle(fontSize: 11)),
                      ],
                    ),
                    pw.Text('Generated: 2026-09-28', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Text('Generated by: ${currentUser.fullName} (${currentUser.roleDisplayName}) | Range: ${_getDateRangeLabel()}', style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 16),
              pw.TableHelper.fromTextArray(
                headers: headers,
                data: dataRows,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                cellStyle: const pw.TextStyle(fontSize: 9),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
    if (mounted) {
      ToastNotification.show(context, message: 'PDF report generated for $reportTitle.', type: ToastType.success);
    }
  }

  void _exportCsv() {
    final filtered = _getFilteredData();
    final workAreas = filtered.areas;
    final employees = filtered.workers;
    final attendance = filtered.attendance;
    final accomplishments = filtered.accomplishments;

    List<List<String>> rows = [];

    if (_selectedReportType == 'area_performance') {
      rows = [
        ['Work Area ID', 'Area Name', 'Supervisor', 'Assigned Workers', 'Status', 'Coverage'],
        ...workAreas.map((a) => [a.workareaId, a.name, a.supervisorName, '${a.assignedCount}', a.status, a.areaSqKm]),
      ];
    } else if (_selectedReportType == 'worker_performance') {
      rows = [
        ['User ID', 'Worker Name', 'Role', 'Assigned Area', 'Credit Score', 'Standing'],
        ...employees.where((e) => e.role == UserRole.worker).map((e) => [
          e.userId,
          e.fullName,
          e.roleDisplayName,
          e.assignedAreaName ?? 'Unassigned',
          '${e.creditScore}',
          e.creditScore >= 80 ? 'Optimal' : e.creditScore >= 50 ? 'Warning' : 'Critical',
        ]),
      ];
    } else if (_selectedReportType == 'accomplishments') {
      rows = [
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
      rows = [
        ['Attendance ID', 'Worker Name', 'Employee ID', 'Work Area', 'Time In', 'Time Out', 'Face Match', 'Verified'],
        ...attendance.map((log) => [
          log.attendanceId,
          log.workerName,
          log.workerEmpId,
          log.areaName,
          log.timeIn,
          log.timeOut,
          log.faceMatch ? 'TRUE' : 'FALSE',
          log.isVerified ? 'TRUE' : 'FALSE',
        ]),
      ];
    }

    final csvString = rows.map((r) => r.map((c) => '"$c"').join(',')).join('\n');
    debugPrint('CSV Export Generated (${csvString.length} bytes)');

    ToastNotification.show(
      context,
      message: 'CSV exported: ${rows.length - 1} records (${_getDateRangeSummaryLabel()}).',
      type: ToastType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final workAreasAsync = ref.watch(workAreasProvider);
    final employeesAsync = ref.watch(employeesProvider);
    ref.watch(attendanceProvider);
    ref.watch(accomplishmentsProvider);

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
                    const Text('Analytical Reports & Exports (UC-05)', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    Text(
                      currentUser.role == UserRole.admin
                          ? 'Generate, preview, and download compliance audits across all Ormoc sectors.'
                          : 'Attendance summaries and worker logs scoped to your assigned work areas (UC-05).',
                      style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Row(
                children: [
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
          const SizedBox(height: 20),

          // Filters Card (UC-05 Step 3)
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
                      const Text('Report Type (SRS)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
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
                        decoration: const InputDecoration(),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Date Horizon / Range', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
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
                        decoration: const InputDecoration(),
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
                          decoration: const InputDecoration(),
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
                          items: const [
                            DropdownMenuItem(value: 2025, child: Text('2025')),
                            DropdownMenuItem(value: 2026, child: Text('2026')),
                            DropdownMenuItem(value: 2027, child: Text('2027')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedYear = val);
                          },
                          decoration: const InputDecoration(),
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
                          decoration: const InputDecoration(),
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
                      const Text('Work Area (Dynamic)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
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
                        decoration: const InputDecoration(),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Worker Filter (Dynamic)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
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
                        decoration: const InputDecoration(),
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

          // Preview Table / Empty State (UC-05 Step 4 & Alt Flow 2)
          Expanded(
            child: AppCard(
              padding: EdgeInsets.zero,
              child: activeRecordCount == 0
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.search_off_outlined, size: 48, color: AppColors.textMuted),
                            const SizedBox(height: 12),
                            const Text(
                              'No records found matching the selected filter criteria (UC-05).',
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
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: _buildReportTable(
                          _selectedReportType,
                          filteredAttendance,
                          filteredAreas,
                          filteredWorkers,
                          filteredAccomplishments,
                        ),
                      ),
                    ),
            ),
          ),
        ],
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
      return DataTable(
        horizontalMargin: 20,
        columnSpacing: 24,
        columns: const [
          DataColumn(label: Text('WORK AREA', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('SUPERVISOR', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('ASSIGNED PERSONNEL', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('STATUS', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('CALCULATED BOUNDARY', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
        rows: areas.map((a) {
          return DataRow(
            cells: [
              DataCell(Text(a.name, style: const TextStyle(fontWeight: FontWeight.w600))),
              DataCell(Text(a.supervisorName)),
              DataCell(Text('${a.assignedCount} Active Workers')),
              DataCell(StatusBadge(label: a.status.toUpperCase(), type: a.status.toLowerCase() == 'active' ? BadgeType.success : BadgeType.neutral)),
              DataCell(Text(a.areaSqKm)),
            ],
          );
        }).toList(),
      );
    }

    if (reportType == 'worker_performance') {
      return DataTable(
        horizontalMargin: 20,
        columnSpacing: 24,
        columns: const [
          DataColumn(label: Text('WORKER NAME', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('ASSIGNED AREA', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('CREDIT SCORE', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('STANDING LEVEL', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('SCHEDULE', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
        rows: workers.map((w) {
          return DataRow(
            cells: [
              DataCell(Text(w.fullName, style: const TextStyle(fontWeight: FontWeight.w600))),
              DataCell(Text(w.assignedAreaName ?? 'Unassigned')),
              DataCell(Text('${w.creditScore} / 100', style: const TextStyle(fontWeight: FontWeight.bold))),
              DataCell(StatusBadge(
                label: w.creditScore >= 80 ? 'OPTIMAL' : w.creditScore >= 50 ? 'WARNING' : 'CRITICAL',
                type: w.creditScore >= 80 ? BadgeType.success : w.creditScore >= 50 ? BadgeType.warning : BadgeType.danger,
              )),
              DataCell(Text(w.schedule)),
            ],
          );
        }).toList(),
      );
    }

    if (reportType == 'accomplishments') {
      return DataTable(
        horizontalMargin: 20,
        columnSpacing: 24,
        columns: const [
          DataColumn(label: Text('FIELD WORKER', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('WORK AREA', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('DATE & TIME', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('BURNED GPS', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('STATUS', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
        rows: accomplishments.map((acc) {
          return DataRow(
            cells: [
              DataCell(Text(acc.workerName, style: const TextStyle(fontWeight: FontWeight.w600))),
              DataCell(Text(acc.areaName)),
              DataCell(Text('${acc.capturedDate} ${acc.capturedTime}')),
              DataCell(Text('${acc.capturedLat.toStringAsFixed(4)}, ${acc.capturedLng.toStringAsFixed(4)}', style: const TextStyle(fontFamily: 'monospace'))),
              DataCell(StatusBadge(
                label: acc.status.toUpperCase(),
                type: acc.status == 'approved' ? BadgeType.success : acc.status == 'denied' ? BadgeType.danger : BadgeType.warning,
              )),
            ],
          );
        }).toList(),
      );
    }

    // Default: Attendance Summary
    return DataTable(
      horizontalMargin: 20,
      columnSpacing: 24,
      columns: const [
        DataColumn(label: Text('WORKER NAME', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(label: Text('SECTOR', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(label: Text('TIME-IN', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(label: Text('TIME-OUT', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(label: Text('GEOFENCE ACCURACY', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(label: Text('AUDIT VERIFICATION', style: TextStyle(fontWeight: FontWeight.bold))),
      ],
      rows: attendance.map((log) {
        return DataRow(
          cells: [
            DataCell(Text(log.workerName, style: const TextStyle(fontWeight: FontWeight.w600))),
            DataCell(Text(log.areaName)),
            DataCell(Text(log.timeIn)),
            DataCell(Text(log.timeOut)),
            DataCell(
              Row(
                children: [
                  Icon(
                    log.hasWarning ? Icons.cancel_outlined : Icons.check_circle_outline,
                    color: log.hasWarning ? AppColors.brightRed : Colors.green,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(log.hasWarning ? 'Out-of-Bounds' : '100% In-Zone'),
                ],
              ),
            ),
            DataCell(
              Text(log.isVerified ? 'Verified by Supervisor' : 'Pending Audit', style: TextStyle(color: log.isVerified ? Colors.green : AppColors.warningText, fontWeight: FontWeight.w600)),
            ),
          ],
        );
      }).toList(),
    );
  }
}

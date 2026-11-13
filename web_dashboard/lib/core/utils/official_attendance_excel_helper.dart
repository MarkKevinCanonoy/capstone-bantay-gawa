import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import '../../data/models/worker_schedule_sheet_model.dart';
import '../../features/attendance/widgets/weekly_attendance_matrix_widget.dart';

class OfficialAttendanceExcelHelper {
  /// Builds a highly professional, official, styled .xlsx workbook
  /// for the ENRO Ormoc City Monthly Attendance Register.
  static Future<List<int>> generateMonthlyAttendanceWorkbook({
    required List<ScheduleSheetModel> sheets,
    required DateTime monthStart,
    required CellAttendanceStatus Function({
      required ScheduleEntryModel worker,
      required DateTime date,
    }) evaluateStatus,
    Map<String, String>? workerStatusMap,
  }) async {
    final workbook = xlsio.Workbook();

    final targetYear = monthStart.year;
    final targetMonth = monthStart.month;
    final monthLabel = DateFormat('MMMM yyyy').format(monthStart);
    final daysInMonth = DateTime(targetYear, targetMonth + 1, 0).day;
    final monthDates = List.generate(daysInMonth, (i) => DateTime(targetYear, targetMonth, i + 1));

    // Load official logo base64
    String? logoBase64;
    try {
      final logoBytes = await rootBundle.load('assets/images/logo.png');
      final list = logoBytes.buffer.asUint8List(logoBytes.offsetInBytes, logoBytes.lengthInBytes);
      logoBase64 = base64.encode(list);
    } catch (_) {
      try {
        final sealBytes = await rootBundle.load('official_seal.png');
        final list = sealBytes.buffer.asUint8List(sealBytes.offsetInBytes, sealBytes.lengthInBytes);
        logoBase64 = base64.encode(list);
      } catch (_) {}
    }

    final totalCols = 6 + daysInMonth + 4; // No, Name, Status, Sector, Schedule, DayOff + Days + 4 summaries
    final lastColLetter = _getColumnLetter(totalCols);

    for (int sIdx = 0; sIdx < sheets.length; sIdx++) {
      final sheetData = sheets[sIdx];
      final xlsio.Worksheet sheet = sIdx == 0 ? workbook.worksheets[0] : workbook.worksheets.add();
      
      // Clean sheet tab name (Excel allows max 31 characters, no invalid chars)
      var tabTitle = sheetData.sheetName.replaceAll(RegExp(r'[:\\/?*\[\]]'), ' ').trim();
      if (tabTitle.length > 28) tabTitle = tabTitle.substring(0, 28);
      sheet.name = tabTitle.isNotEmpty ? tabTitle : 'Sheet ${sIdx + 1}';

      // 1. Column Widths
      sheet.getRangeByName('A1').columnWidth = 10.0;  // No. / Logo Column (widened to accommodate and center seal)
      sheet.getRangeByName('B1').columnWidth = 26.0;  // Worker's Name
      sheet.getRangeByName('C1').columnWidth = 14.0;  // Status (Active / Terminated)
      sheet.getRangeByName('D1').columnWidth = 22.0;  // Assigned Sector
      sheet.getRangeByName('E1').columnWidth = 24.0;  // Shift Schedule (widened to comfortably fit full range)
      sheet.getRangeByName('F1').columnWidth = 20.0;  // Day Off (widened to comfortably fit multiple days)

      for (int d = 0; d < daysInMonth; d++) {
        final colLetter = _getColumnLetter(7 + d);
        sheet.getRangeByName('${colLetter}1').columnWidth = 5.2; // Compact day column
      }

      final pCol = _getColumnLetter(7 + daysInMonth);
      final lCol = _getColumnLetter(7 + daysInMonth + 1);
      final aCol = _getColumnLetter(7 + daysInMonth + 2);
      final lvCol = _getColumnLetter(7 + daysInMonth + 3);

      sheet.getRangeByName('${pCol}1').columnWidth = 7.5;
      sheet.getRangeByName('${lCol}1').columnWidth = 7.5;
      sheet.getRangeByName('${aCol}1').columnWidth = 7.5;
      sheet.getRangeByName('${lvCol}1').columnWidth = 7.5;

      // 2. Official Header Block
      sheet.getRangeByName('A1').rowHeight = 14.0;
      sheet.getRangeByName('A2:A4').rowHeight = 22.0;

      final logoRange = sheet.getRangeByName('A2:A4');
      logoRange.merge();
      logoRange.cellStyle.hAlign = xlsio.HAlignType.center;
      logoRange.cellStyle.vAlign = xlsio.VAlignType.center;

      // Embed Official Seal / Logo if available (Row 2 to 4, Column A - cell A2 spanning to A4)
      if (logoBase64 != null) {
        try {
          final picture = sheet.pictures.addBase64(2, 1, logoBase64); // Cell A2 (Row 2, Column 1)
          picture.width = 64;
          picture.height = 64;
        } catch (_) {}
      }

      // Republic & City Header Titles
      final r1 = sheet.getRangeByName('B1:${lastColLetter}1');
      r1.merge();
      r1.text = 'REPUBLIC OF THE PHILIPPINES';
      r1.cellStyle.fontName = 'Arial';
      r1.cellStyle.fontSize = 9;
      r1.cellStyle.bold = true;
      r1.cellStyle.fontColor = '#64748B';
      r1.cellStyle.hAlign = xlsio.HAlignType.left;
      r1.cellStyle.vAlign = xlsio.VAlignType.center;

      final r2 = sheet.getRangeByName('B2:${lastColLetter}2');
      r2.merge();
      r2.text = 'CITY GOVERNMENT OF ORMOC';
      r2.cellStyle.fontName = 'Arial';
      r2.cellStyle.fontSize = 14;
      r2.cellStyle.bold = true;
      r2.cellStyle.fontColor = '#08284B'; // Midnight Navy
      r2.cellStyle.hAlign = xlsio.HAlignType.left;
      r2.cellStyle.vAlign = xlsio.VAlignType.center;

      final r3 = sheet.getRangeByName('B3:${lastColLetter}3');
      r3.merge();
      r3.text = 'ENVIRONMENT AND NATURAL RESOURCES OFFICE (ENRO)';
      r3.cellStyle.fontName = 'Arial';
      r3.cellStyle.fontSize = 11;
      r3.cellStyle.bold = true;
      r3.cellStyle.fontColor = '#167346'; // Forest Green
      r3.cellStyle.hAlign = xlsio.HAlignType.left;
      r3.cellStyle.vAlign = xlsio.VAlignType.center;

      final r4 = sheet.getRangeByName('B4:${lastColLetter}4');
      r4.merge();
      r4.text = 'Bantay Gawa Mobile Attendance System';
      r4.cellStyle.fontName = 'Arial';
      r4.cellStyle.fontSize = 9;
      r4.cellStyle.fontColor = '#64748B';
      r4.cellStyle.hAlign = xlsio.HAlignType.left;
      r4.cellStyle.vAlign = xlsio.VAlignType.center;

      // Divider Row
      final divRow = sheet.getRangeByName('A5:${lastColLetter}5');
      divRow.merge();
      divRow.rowHeight = 6.0;
      divRow.cellStyle.backColor = '#08284B';

      // Meta Ribbon: Period, Generated Date, Office
      sheet.getRangeByName('A6').rowHeight = 22.0;
      final metaRange = sheet.getRangeByName('A6:${lastColLetter}6');
      metaRange.merge();
      metaRange.text = 'REPORT: OFFICIAL MONTHLY ATTENDANCE REGISTER   |   PERIOD: $monthLabel   |   OFFICE: ENRO Ormoc City   |   GENERATED: ${DateFormat('dd/MM/yyyy hh:mm a').format(DateTime.now())}';
      metaRange.cellStyle.fontName = 'Arial';
      metaRange.cellStyle.fontSize = 9;
      metaRange.cellStyle.bold = true;
      metaRange.cellStyle.fontColor = '#1E293B';
      metaRange.cellStyle.backColor = '#F1F5F9';
      metaRange.cellStyle.hAlign = xlsio.HAlignType.left;
      metaRange.cellStyle.vAlign = xlsio.VAlignType.center;
      metaRange.cellStyle.borders.bottom.lineStyle = xlsio.LineStyle.thin;
      metaRange.cellStyle.borders.bottom.color = '#CBD5E1';

      // Section Banner
      sheet.getRangeByName('A7').rowHeight = 24.0;
      final sectionRange = sheet.getRangeByName('A7:${lastColLetter}7');
      sectionRange.merge();
      sectionRange.text = 'SECTION UNIT: ${sheetData.sheetName.toUpperCase()}';
      sectionRange.cellStyle.fontName = 'Arial';
      sectionRange.cellStyle.fontSize = 11;
      sectionRange.cellStyle.bold = true;
      sectionRange.cellStyle.fontColor = '#FFFFFF';
      sectionRange.cellStyle.backColor = '#0F172A'; // Dark Navy Banner
      sectionRange.cellStyle.hAlign = xlsio.HAlignType.left;
      sectionRange.cellStyle.vAlign = xlsio.VAlignType.center;

      // 3. Table Column Headers (Row 8)
      sheet.getRangeByName('A8').rowHeight = 28.0;

      final headers = <String>[
        'No.',
        "Worker's Full Name",
        'Status',
        'Assigned Sector',
        'Shift Schedule',
        'Day Off',
        ...monthDates.map((d) => DateFormat('dd\nMMM').format(d)),
        'Pres\n(P)',
        'Late\n(L)',
        'Abs\n(A)',
        'Leave\n(LV)',
      ];

      for (int c = 0; c < headers.length; c++) {
        final colLetter = _getColumnLetter(c + 1);
        final cell = sheet.getRangeByName('${colLetter}8');
        cell.text = headers[c];
        cell.cellStyle.fontName = 'Arial';
        cell.cellStyle.fontSize = 9;
        cell.cellStyle.bold = true;
        cell.cellStyle.wrapText = true;
        cell.cellStyle.hAlign = xlsio.HAlignType.center;
        cell.cellStyle.vAlign = xlsio.VAlignType.center;
        cell.cellStyle.backColor = '#1E293B';
        cell.cellStyle.fontColor = '#FFFFFF';
        cell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
        cell.cellStyle.borders.all.color = '#475569';
      }

      // 4. Data Rows (Row 9 onwards)
      int currentRow = 9;
      for (int i = 0; i < sheetData.entries.length; i++) {
        final worker = sheetData.entries[i];
        final isEven = i % 2 == 0;
        final rowBg = isEven ? '#FFFFFF' : '#F8FAFC'; // Zebra striping

        sheet.getRangeByName('A$currentRow').rowHeight = 20.0;

        // No.
        final noCell = sheet.getRangeByName('A$currentRow');
        noCell.number = (i + 1).toDouble();
        noCell.cellStyle.hAlign = xlsio.HAlignType.center;
        noCell.cellStyle.vAlign = xlsio.VAlignType.center;
        noCell.cellStyle.backColor = rowBg;
        noCell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
        noCell.cellStyle.borders.all.color = '#E2E8F0';

        // Worker Name
        final nameCell = sheet.getRangeByName('B$currentRow');
        nameCell.text = worker.workerName;
        nameCell.cellStyle.bold = true;
        nameCell.cellStyle.vAlign = xlsio.VAlignType.center;
        nameCell.cellStyle.backColor = rowBg;
        nameCell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
        nameCell.cellStyle.borders.all.color = '#E2E8F0';

        // Status (Active / Terminated)
        final statusRaw = (workerStatusMap != null ? workerStatusMap[worker.userId] : null) ?? 'Active';
        final isTerminated = statusRaw.toLowerCase() == 'terminated';
        final statusCell = sheet.getRangeByName('C$currentRow');
        statusCell.text = isTerminated ? 'Terminated' : 'Active';
        statusCell.cellStyle.hAlign = xlsio.HAlignType.center;
        statusCell.cellStyle.vAlign = xlsio.VAlignType.center;
        statusCell.cellStyle.bold = true;
        statusCell.cellStyle.backColor = isTerminated ? '#FEE2E2' : '#DCFCE7';
        statusCell.cellStyle.fontColor = isTerminated ? '#991B1B' : '#166534';
        statusCell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
        statusCell.cellStyle.borders.all.color = '#E2E8F0';

        // Assigned Sector
        final sectorCell = sheet.getRangeByName('D$currentRow');
        sectorCell.text = worker.assignedAreaName;
        sectorCell.cellStyle.vAlign = xlsio.VAlignType.center;
        sectorCell.cellStyle.backColor = rowBg;
        sectorCell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
        sectorCell.cellStyle.borders.all.color = '#E2E8F0';

        // Shift Schedule
        final schedCell = sheet.getRangeByName('E$currentRow');
        schedCell.text = worker.timeSchedule;
        schedCell.cellStyle.vAlign = xlsio.VAlignType.center;
        schedCell.cellStyle.backColor = rowBg;
        schedCell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
        schedCell.cellStyle.borders.all.color = '#E2E8F0';

        // Day Off
        final dayOffCell = sheet.getRangeByName('F$currentRow');
        dayOffCell.text = worker.dayOff;
        dayOffCell.cellStyle.hAlign = xlsio.HAlignType.center;
        dayOffCell.cellStyle.vAlign = xlsio.VAlignType.center;
        dayOffCell.cellStyle.backColor = rowBg;
        dayOffCell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
        dayOffCell.cellStyle.borders.all.color = '#E2E8F0';

        int presentCount = 0;
        int lateCount = 0;
        int absentCount = 0;
        int leaveCount = 0;

        // Daily Attendance Cells with Professional Color Highlights
        for (int d = 0; d < daysInMonth; d++) {
          final date = monthDates[d];
          final colLetter = _getColumnLetter(7 + d);
          final dayCell = sheet.getRangeByName('$colLetter$currentRow');
          
          final status = evaluateStatus(worker: worker, date: date);

          String code = '-';
          String cellBg = rowBg;
          String cellFg = '#64748B';
          bool isBold = false;

          switch (status) {
            case CellAttendanceStatus.present:
              code = 'P';
              cellBg = '#DCFCE7'; // Soft Emerald Green
              cellFg = '#166534'; // Dark Emerald Text
              isBold = true;
              presentCount++;
              break;
            case CellAttendanceStatus.late:
              code = 'L';
              cellBg = '#FEF3C7'; // Soft Amber Yellow
              cellFg = '#92400E'; // Dark Amber Text
              isBold = true;
              lateCount++;
              break;
            case CellAttendanceStatus.absent:
              code = 'A';
              cellBg = '#FEE2E2'; // Soft Rose Red
              cellFg = '#991B1B'; // Dark Red Text
              isBold = true;
              absentCount++;
              break;
            case CellAttendanceStatus.onLeave:
              code = 'LV';
              cellBg = '#E2E8F0'; // Soft Slate Grey
              cellFg = '#475569'; // Slate Grey Text
              isBold = true;
              leaveCount++;
              break;
            case CellAttendanceStatus.dayOff:
              code = 'OFF';
              cellBg = '#F1F5F9'; // Light Neutral Slate
              cellFg = '#94A3B8'; // Slate Muted
              break;
            case CellAttendanceStatus.pendingFuture:
              code = '-';
              cellBg = rowBg;
              cellFg = '#CBD5E1';
              break;
          }

          dayCell.text = code;
          dayCell.cellStyle.hAlign = xlsio.HAlignType.center;
          dayCell.cellStyle.vAlign = xlsio.VAlignType.center;
          dayCell.cellStyle.backColor = cellBg;
          dayCell.cellStyle.fontColor = cellFg;
          dayCell.cellStyle.bold = isBold;
          dayCell.cellStyle.fontSize = 8.5;
          dayCell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
          dayCell.cellStyle.borders.all.color = '#CBD5E1';
        }

        // Summary Counts
        final presCell = sheet.getRangeByName('$pCol$currentRow');
        presCell.number = presentCount.toDouble();
        presCell.cellStyle.hAlign = xlsio.HAlignType.center;
        presCell.cellStyle.vAlign = xlsio.VAlignType.center;
        presCell.cellStyle.bold = true;
        presCell.cellStyle.backColor = '#F0FDF4';
        presCell.cellStyle.fontColor = '#15803D';
        presCell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
        presCell.cellStyle.borders.all.color = '#BBF7D0';

        final lateSummaryCell = sheet.getRangeByName('$lCol$currentRow');
        lateSummaryCell.number = lateCount.toDouble();
        lateSummaryCell.cellStyle.hAlign = xlsio.HAlignType.center;
        lateSummaryCell.cellStyle.vAlign = xlsio.VAlignType.center;
        lateSummaryCell.cellStyle.bold = true;
        lateSummaryCell.cellStyle.backColor = '#FFFBEB';
        lateSummaryCell.cellStyle.fontColor = '#B45309';
        lateSummaryCell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
        lateSummaryCell.cellStyle.borders.all.color = '#FDE68A';

        final absSummaryCell = sheet.getRangeByName('$aCol$currentRow');
        absSummaryCell.number = absentCount.toDouble();
        absSummaryCell.cellStyle.hAlign = xlsio.HAlignType.center;
        absSummaryCell.cellStyle.vAlign = xlsio.VAlignType.center;
        absSummaryCell.cellStyle.bold = true;
        absSummaryCell.cellStyle.backColor = '#FEF2F2';
        absSummaryCell.cellStyle.fontColor = '#B91C1C';
        absSummaryCell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
        absSummaryCell.cellStyle.borders.all.color = '#FECACA';

        final lvSummaryCell = sheet.getRangeByName('$lvCol$currentRow');
        lvSummaryCell.number = leaveCount.toDouble();
        lvSummaryCell.cellStyle.hAlign = xlsio.HAlignType.center;
        lvSummaryCell.cellStyle.vAlign = xlsio.VAlignType.center;
        lvSummaryCell.cellStyle.bold = true;
        lvSummaryCell.cellStyle.backColor = '#EEF2FF';
        lvSummaryCell.cellStyle.fontColor = '#4338CA';
        lvSummaryCell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
        lvSummaryCell.cellStyle.borders.all.color = '#C7D2FE';

        currentRow++;
      }

      // 5. Attendance Legend Block
      currentRow++; // 1 empty spacer row
      sheet.getRangeByName('A$currentRow').rowHeight = 20.0;
      final legendTitle = sheet.getRangeByName('A$currentRow:$lastColLetter$currentRow');
      legendTitle.merge();
      legendTitle.text = 'ATTENDANCE AUDIT CODES & LEGEND:';
      legendTitle.cellStyle.fontName = 'Arial';
      legendTitle.cellStyle.fontSize = 9;
      legendTitle.cellStyle.bold = true;
      legendTitle.cellStyle.fontColor = '#475569';
      legendTitle.cellStyle.hAlign = xlsio.HAlignType.left;
      legendTitle.cellStyle.vAlign = xlsio.VAlignType.center;

      currentRow++;
      sheet.getRangeByName('A$currentRow').rowHeight = 22.0;

      // P
      final legP = sheet.getRangeByName('A$currentRow:D$currentRow');
      legP.merge();
      legP.text = '  [P] Present (On-Time inside Geofence)';
      legP.cellStyle.backColor = '#DCFCE7';
      legP.cellStyle.fontColor = '#166534';
      legP.cellStyle.bold = true;
      legP.cellStyle.fontSize = 9;
      legP.cellStyle.vAlign = xlsio.VAlignType.center;

      // L
      final legL = sheet.getRangeByName('E$currentRow:H$currentRow');
      legL.merge();
      legL.text = '  [L] Late (>15 mins grace period)';
      legL.cellStyle.backColor = '#FEF3C7';
      legL.cellStyle.fontColor = '#92400E';
      legL.cellStyle.bold = true;
      legL.cellStyle.fontSize = 9;
      legL.cellStyle.vAlign = xlsio.VAlignType.center;

      // A
      final legA = sheet.getRangeByName('I$currentRow:L$currentRow');
      legA.merge();
      legA.text = '  [A] Absent (No Punch)';
      legA.cellStyle.backColor = '#FEE2E2';
      legA.cellStyle.fontColor = '#991B1B';
      legA.cellStyle.bold = true;
      legA.cellStyle.fontSize = 9;
      legA.cellStyle.vAlign = xlsio.VAlignType.center;

      // LV
      final legLV = sheet.getRangeByName('M$currentRow:P$currentRow');
      legLV.merge();
      legLV.text = '  [LV] Approved Leave';
      legLV.cellStyle.backColor = '#E2E8F0';
      legLV.cellStyle.fontColor = '#475569';
      legLV.cellStyle.bold = true;
      legLV.cellStyle.fontSize = 9;
      legLV.cellStyle.vAlign = xlsio.VAlignType.center;

      // OFF
      final legOff = sheet.getRangeByName('Q$currentRow:T$currentRow');
      legOff.merge();
      legOff.text = '  [OFF] Scheduled Rest Day';
      legOff.cellStyle.backColor = '#F1F5F9';
      legOff.cellStyle.fontColor = '#64748B';
      legOff.cellStyle.bold = true;
      legOff.cellStyle.fontSize = 9;
      legOff.cellStyle.vAlign = xlsio.VAlignType.center;

      // 6. Certification & Sign-off Blocks (Print-Ready)
      currentRow += 2;
      sheet.getRangeByName('A$currentRow').rowHeight = 18.0;

      final signHeader1 = sheet.getRangeByName('B$currentRow:E$currentRow');
      signHeader1.merge();
      signHeader1.text = 'Prepared and Certified Correct:';
      signHeader1.cellStyle.fontColor = '#64748B';
      signHeader1.cellStyle.fontSize = 9;
      signHeader1.cellStyle.italic = true;

      final signHeader2 = sheet.getRangeByName('J$currentRow:N$currentRow');
      signHeader2.merge();
      signHeader2.text = 'Verified and Approved:';
      signHeader2.cellStyle.fontColor = '#64748B';
      signHeader2.cellStyle.fontSize = 9;
      signHeader2.cellStyle.italic = true;

      currentRow += 3;
      sheet.getRangeByName('A$currentRow').rowHeight = 20.0;

      final signLine1 = sheet.getRangeByName('B$currentRow:E$currentRow');
      signLine1.merge();
      signLine1.text = '_______________________________________';
      signLine1.cellStyle.bold = true;

      final signLine2 = sheet.getRangeByName('J$currentRow:N$currentRow');
      signLine2.merge();
      signLine2.text = '_______________________________________';
      signLine2.cellStyle.bold = true;

      currentRow++;
      final signTitle1 = sheet.getRangeByName('B$currentRow:E$currentRow');
      signTitle1.merge();
      signTitle1.text = 'Timekeeper / Field Supervisor';
      signTitle1.cellStyle.bold = true;
      signTitle1.cellStyle.fontSize = 10;
      signTitle1.cellStyle.fontColor = '#0F172A';

      final signTitle2 = sheet.getRangeByName('J$currentRow:N$currentRow');
      signTitle2.merge();
      signTitle2.text = 'City ENRO Department Head';
      signTitle2.cellStyle.bold = true;
      signTitle2.cellStyle.fontSize = 10;
      signTitle2.cellStyle.fontColor = '#0F172A';
    }

    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();
    return bytes;
  }

  /// Converts 1-based column integer into Excel column letter (e.g., 1 -> A, 27 -> AA)
  static String _getColumnLetter(int colNumber) {
    var num = colNumber;
    var letter = '';
    while (num > 0) {
      final rem = (num - 1) % 26;
      letter = String.fromCharCode(65 + rem) + letter;
      num = ((num - rem) / 26).floor();
    }
    return letter;
  }
}

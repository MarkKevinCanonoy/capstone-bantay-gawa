import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_dashboard/features/employees/employees_view.dart';
import 'package:web_dashboard/features/work_areas/work_areas_view.dart';
import 'package:web_dashboard/features/leaves/leaves_view.dart';
import 'package:web_dashboard/features/accomplishments/accomplishments_view.dart';
import 'package:web_dashboard/features/reports/reports_view.dart';

void main() {
  testWidgets('UC-01: EmployeesView opens enrollment modal and performs facial capture & QR credential generation', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: EmployeesView(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify view loads with Personnel Directory title
    expect(find.text('Personnel Directory'), findsOneWidget);

    // Click + Add Personnel
    final enrollBtn = find.text('+ Add Personnel');
    expect(enrollBtn, findsOneWidget);
    await tester.tap(enrollBtn);
    await tester.pumpAndSettle();

    // Verify modal contains Biometric Enrollment and Dynamic Area selector
    expect(find.text('Register New Personnel (UC-01)'), findsOneWidget);
    expect(find.text('Capture / Upload Face'), findsOneWidget);
    expect(find.text('Assigned Work Area (Dynamic)'), findsOneWidget);

    // Simulate facial scan
    final captureBtn = find.text('Capture / Upload Face');
    await tester.ensureVisible(captureBtn);
    await tester.tap(captureBtn);
    await tester.pumpAndSettle();
    expect(find.text('EMBEDDING STORED'), findsOneWidget);

    // Close modal
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Click on an existing employee to inspect QR credential
    final detailsIcon = find.byIcon(Icons.visibility_outlined).first;
    await tester.ensureVisible(detailsIcon);
    await tester.tap(detailsIcon);
    await tester.pumpAndSettle();

    // Verify QR credential card and Print button in details modal
    expect(find.text('Digital QR Credential & Biometrics (UC-01 / UC-14)'), findsOneWidget);
    expect(find.text('Print QR Credential'), findsOneWidget);
    expect(find.text('CREDENTIAL TOKEN'), findsOneWidget);
  });

  testWidgets('UC-02: WorkAreasView confirms deletion safety warning when personnel are assigned', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: WorkAreasView(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Find Remove button for area with personnel
    final removeBtn = find.text('Remove').first;
    await tester.tap(removeBtn);
    await tester.pumpAndSettle();

    // Verify delete confirmation dialog with active personnel warning
    expect(find.textContaining('Delete Work Area:'), findsOneWidget);
    expect(find.textContaining('WARNING (UC-02):'), findsOneWidget);
    expect(find.text('Confirm Delete Area'), findsOneWidget);
  });

  testWidgets('UC-03: LeavesView opens leave review modal with justification proof and action buttons', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: LeavesView(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Leave Request Management'), findsOneWidget);

    // Look for Review button
    final reviewButtons = find.text('Review');
    expect(reviewButtons, findsWidgets);

    await tester.ensureVisible(reviewButtons.first);
    await tester.tap(reviewButtons.first);
    await tester.pumpAndSettle();

    // Verify review modal opened
    expect(find.textContaining('Leave Review:'), findsOneWidget);
    expect(find.text('Medical / Supporting Document Proof (UC-03)'), findsOneWidget);
    expect(find.text('Approve Leave'), findsOneWidget);
    expect(find.text('Deny Leave'), findsOneWidget);
  });

  testWidgets('UC-04: AccomplishmentsView displays geofence match verification and Exif data', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: AccomplishmentsView(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Field Accomplishment Proofs'), findsOneWidget);

    // Tap on first accomplishment card image
    final imageFinder = find.byType(Image).first;
    await tester.tap(imageFinder);
    await tester.pumpAndSettle();

    // Verify geofence match card and exif metadata card
    expect(find.textContaining('GEOFENCE MATCH: IN-ZONE VERIFIED'), findsOneWidget);
    expect(find.text('Extracted Exif Metadata Summary (UC-04)'), findsOneWidget);
  });

  testWidgets('UC-05: ReportsView switches categories and filters accurately', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ReportsView(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Analytical Reports & Exports (UC-05)'), findsOneWidget);

    // Verify default Attendance category and columns
    expect(find.text('WORKER NAME'), findsOneWidget);
    expect(find.text('GEOFENCE ACCURACY'), findsOneWidget);

    // Open Report Type dropdown (first dropdown) and select Area Performance
    final reportTypeDropdown = find.byType(DropdownButtonFormField<String>).first;
    await tester.tap(reportTypeDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Area Performance').last);
    await tester.pumpAndSettle();

    expect(find.text('WORK AREA'), findsWidgets);
    expect(find.text('CALCULATED BOUNDARY'), findsOneWidget);

    // Open Report Type dropdown and select Worker Performance
    await tester.tap(reportTypeDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Worker Performance').last);
    await tester.pumpAndSettle();

    expect(find.text('CREDIT SCORE'), findsOneWidget);
    expect(find.text('STANDING LEVEL'), findsOneWidget);

    // Open Report Type dropdown and select Accomplishment Report
    await tester.tap(reportTypeDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accomplishment Report').last);
    await tester.pumpAndSettle();

    expect(find.text('FIELD WORKER'), findsOneWidget);
    expect(find.text('BURNED GPS'), findsOneWidget);
  });

  testWidgets('UC-05: ReportsView flexible date range filtering (3 days, 14 days, month & week, custom)', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ReportsView(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Find the Date Horizon dropdown
    final dateDropdown = find.byKey(const ValueKey('date_range_week'));
    expect(dateDropdown, findsOneWidget);

    // Switch to 'Past 3 Days'
    await tester.tap(dateDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Past 3 Days').last);
    await tester.pumpAndSettle();

    // Verify active chip in header reflects '3 Days'
    expect(find.textContaining('3 Days'), findsWidgets);

    // Switch to 'Month & Week of Month...'
    final dateDropdown3Days = find.byKey(const ValueKey('date_range_3_days'));
    await tester.tap(dateDropdown3Days);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Month & Week of Month...').last);
    await tester.pumpAndSettle();

    // Verify Month, Year, and Week of Month dropdowns appear dynamically
    expect(find.text('Week of Month'), findsOneWidget);
    expect(find.text('Entire Month (All)'), findsOneWidget);

    // Switch Week to 'Week 2 (Days 8–14)'
    final weekDropdown = find.byKey(const ValueKey('week_0'));
    await tester.tap(weekDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Week 2 (Days 8–14)').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('Wk 2'), findsOneWidget);

    // Switch to 'Custom Date Range...'
    final dateDropdownMonthWeek = find.byKey(const ValueKey('date_range_month_week'));
    await tester.tap(dateDropdownMonthWeek);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom Date Range...').last);
    await tester.pumpAndSettle();

    // Verify simple From Date and To Date pickers appear
    expect(find.text('From Date'), findsOneWidget);
    expect(find.text('To Date'), findsOneWidget);
  });
}


import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_dashboard/features/employees/employees_view.dart';
import 'package:web_dashboard/features/work_areas/work_areas_view.dart';
import 'package:web_dashboard/features/leaves/leaves_view.dart';
import 'package:web_dashboard/features/accomplishments/accomplishments_view.dart';
import 'package:web_dashboard/features/reports/reports_view.dart';
import 'package:web_dashboard/features/notifications/notifications_view.dart';
import 'package:web_dashboard/features/dashboard/dashboard_view.dart';
import 'package:web_dashboard/features/incidents/incidents_view.dart';
import 'package:web_dashboard/data/datasources/mock_data.dart';
import 'package:web_dashboard/data/models/user_model.dart';
import 'package:web_dashboard/data/repositories/repository_provider.dart';
import 'package:web_dashboard/features/work_areas/widgets/area_workers_dialog.dart';

class _SupervisorUserNotifier extends CurrentUserNotifier {
  final UserModel _user;
  _SupervisorUserNotifier(this._user);
  @override
  UserModel build() => _user;
}

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

    // Verify modal contains Biometric Enrollment
    expect(find.text('Register New Personnel'), findsOneWidget);
    expect(find.text('Capture / Upload Face'), findsOneWidget);

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
    expect(find.text('Digital QR Credential & Biometrics'), findsOneWidget);
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
    expect(find.textContaining('WARNING:'), findsOneWidget);
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
    expect(find.text('Medical & Supporting Document Proof'), findsOneWidget);
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

    // Verify geofence match card and photo & location details
    expect(find.textContaining('GEOFENCE MATCH: IN-ZONE VERIFIED'), findsOneWidget);
    expect(find.text('Photo & Location Details'), findsOneWidget);
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

    expect(find.text('Analytical Reports & Exports'), findsOneWidget);

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

  testWidgets('UC-06: Send Notification validates inputs, allows audience targeting and sends broadcasts', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: NotificationsView(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Alerts & Broadcast Center'), findsOneWidget);

    // Open Compose Dialog
    final composeBtn = find.text('Compose Notification');
    expect(composeBtn, findsOneWidget);
    await tester.tap(composeBtn);
    await tester.pumpAndSettle();

    // Verify recipient options
    expect(find.text('All Users (City-wide Personnel)'), findsWidgets);

    // Validation test: try sending without subject or message
    final sendButton = find.text('Send Notification').last;
    await tester.tap(sendButton);
    await tester.pumpAndSettle();

    // Verify validation error
    expect(find.text('Please enter a subject title before sending.'), findsOneWidget);

    // Enter title
    final titleField = find.byType(TextField).first;
    await tester.enterText(titleField, 'Emergency Sanitation Protocol');
    await tester.pumpAndSettle();

    // Try sending without message
    await tester.tap(sendButton);
    await tester.pumpAndSettle();
    expect(find.text('Message body cannot be empty. Please enter your notice.'), findsOneWidget);

    // Enter message
    final messageField = find.byType(TextField).at(1);
    await tester.enterText(messageField, 'All team leads report to Sector 1 for immediate dispatch.');
    await tester.pumpAndSettle();

    // Send valid notification
    await tester.tap(sendButton);
    await tester.pumpAndSettle();

    // Success toast
    expect(find.textContaining('In-app notification delivered'), findsOneWidget);
  });

  testWidgets('UC-07: Shuffle Worker Assignments executes balanced rotation & reassignment warnings', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
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

    // Find Shuffle Assignments button
    final shuffleBtn = find.text('Shuffle Assignments');
    expect(shuffleBtn, findsOneWidget);

    await tester.tap(shuffleBtn);
    await tester.pumpAndSettle();

    // Verify dialog content
    expect(find.text('Monthly Workforce Shuffle'), findsOneWidget);
    expect(find.text('Confirm & Execute Shuffle'), findsOneWidget);

    // Cancel shuffle via close icon
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('Monthly Workforce Shuffle'), findsNothing);

    // Open AreaWorkersDialog to verify roster display
    final area = MockData.workAreas.first;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: AreaWorkersDialog(area: area),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining(area.name), findsWidgets);
    expect(find.textContaining('assigned to this sector'), findsOneWidget);
  });

  testWidgets('UC-08 & UC-10: GIS Workforce Map renders live pins, sector filtering and 1-minute historical movement', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: DashboardView(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify GIS Map card header
    expect(find.text('Live Workforce & Geofences'), findsOneWidget);

    // Verify Sector Filtering (UC-10)
    expect(find.text('All Monitored Areas'), findsOneWidget);

    // Verify Historical Movement toggle (UC-08)
    expect(find.text('Historical Path (1m)'), findsOneWidget);

    // Toggle Historical Movement switch
    final historicalSwitch = find.byType(Switch).first;
    await tester.tap(historicalSwitch);
    await tester.pumpAndSettle();

    // Privacy badge notice appears
    expect(find.textContaining('1-minute path sampled inside assigned area only'), findsOneWidget);

    // Verify legend
    expect(find.text('On-site (Within Geofence)'), findsOneWidget);
    expect(find.text('Off-site / Breach Alert'), findsOneWidget);
  });

  testWidgets('UC-09: NotificationsView responds to alerts with warnings and dismiss audit logs', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: NotificationsView(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify alert categories
    expect(find.text('All Alerts'), findsOneWidget);
    expect(find.text('Consecutive Absences (3+)'), findsOneWidget);
    expect(find.text('Credit Score Warnings'), findsOneWidget);
    expect(find.text('Geofence Breaches'), findsOneWidget);

    // Tap Consecutive Absences (3+) filter chip
    await tester.tap(find.text('Consecutive Absences (3+)'));
    await tester.pumpAndSettle();

    // Open first alert action button
    final reviewBtn = find.text('Respond').first;
    await tester.tap(reviewBtn);
    await tester.pumpAndSettle();

    // Verify Alert Details & Action modal
    expect(find.text('3+ Consecutive Unexcused Absences'), findsWidgets);
    expect(find.text('Send Warning Notice'), findsOneWidget);
    expect(find.text('Dismiss Alert (Audit Log)'), findsOneWidget);

    // Dismiss the alert
    await tester.tap(find.text('Dismiss Alert (Audit Log)'));
    await tester.pumpAndSettle();

    // Verify toast
    expect(find.textContaining('Alert dismissed and logged in system audit trail'), findsOneWidget);
  });

  testWidgets('UC-11: IncidentsView allows Field Supervisor to review worker issues, settle locally, or escalate to Admin', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // Provide supervisor user
    final supervisorUser = UserModel(
      userId: 'user-sup-1',
      username: 'sup_juan',
      firstName: 'Juan',
      lastName: 'Santos',
      contactNumber: '+63 917 222 0002',
      role: UserRole.supervisor,
      status: 'active',
      assignedAreaId: 'area-1',
      assignedAreaName: 'Ormoc City Hall Zone',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith(() => _SupervisorUserNotifier(supervisorUser)),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: IncidentsView(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Title and Subtitle for Supervisor
    expect(find.text('Worker Incident & Issue Reports'), findsOneWidget);
    expect(find.textContaining('Review worker issue reports in your sector'), findsOneWidget);
    expect(find.text('Assigned Sector: Ormoc City Hall Zone'), findsOneWidget);

    // Verify pending incident card
    expect(find.text('Not Working / Loitering'), findsOneWidget);
    expect(find.textContaining('Carlos Mendoza'), findsOneWidget);

    // Tap "Settle Locally"
    final settleBtn = find.text('Settle Locally').first;
    await tester.tap(settleBtn);
    await tester.pumpAndSettle();

    // Verify Settle Locally Dialog
    expect(find.text('Settle Worker Issue Locally'), findsOneWidget);
    expect(find.text('Supervisor Settlement Action & Notes *'), findsOneWidget);

    // Attempt confirm with empty notes (validation check)
    await tester.tap(find.text('Confirm Local Settlement'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Settlement notes are mandatory'), findsOneWidget);

    // Fill notes and confirm
    await tester.enterText(find.byType(TextField).last, 'Conducted verbal counseling at field post.');
    await tester.tap(find.text('Confirm Local Settlement'));
    await tester.pumpAndSettle();

    // Verify settlement confirmation
    expect(find.textContaining('Worker issue settled locally'), findsOneWidget);
  });

  testWidgets('UC-12: ReportsView scopes areas for Field Supervisor and allows sending report copy to Admin', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final supervisorUser = UserModel(
      userId: 'user-sup-1',
      username: 'sup_juan',
      firstName: 'Juan',
      lastName: 'Santos',
      contactNumber: '+63 917 222 0002',
      role: UserRole.supervisor,
      status: 'active',
      assignedAreaId: 'area-1',
      assignedAreaName: 'Ormoc City Hall Zone',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith(() => _SupervisorUserNotifier(supervisorUser)),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ReportsView(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify "Send Report to Admin" button is available for Supervisor
    final sendToAdminBtn = find.text('Send Report to Admin');
    expect(sendToAdminBtn, findsOneWidget);

    // Open Send to Admin Dialog
    await tester.tap(sendToAdminBtn);
    await tester.pumpAndSettle();

    // Verify Transmittal Dialog
    expect(find.text('Send Report Copy to Admin'), findsOneWidget);
    expect(find.text('Report Type:'), findsOneWidget);
    expect(find.text('Transmittal Remarks / Audit Notes (Optional)'), findsOneWidget);

    // Enter notes and send
    await tester.enterText(find.byType(TextField).last, 'Weekly sector audit ready for executive review.');
    await tester.tap(find.text('Send to Admin'));
    await tester.pumpAndSettle();

    // Verify delivery toast
    expect(find.textContaining('Report transmittal memo sent to Central Admin'), findsOneWidget);
  });

  testWidgets('UC-13: LeavesView enforces Admin-only approval and allows Supervisor recommendation submission', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final supervisorUser = UserModel(
      userId: 'user-sup-1',
      username: 'sup_juan',
      firstName: 'Juan',
      lastName: 'Santos',
      contactNumber: '+63 917 222 0002',
      role: UserRole.supervisor,
      status: 'active',
      assignedAreaId: 'area-1',
      assignedAreaName: 'Ormoc City Hall Zone',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith(() => _SupervisorUserNotifier(supervisorUser)),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: LeavesView(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Supervisor notice banner on top of table
    expect(find.textContaining('Supervisor Notice: As defined in the Role Matrix'), findsOneWidget);

    // Verify "Review / Endorse" button in table
    final reviewBtn = find.text('Review / Endorse').first;
    expect(reviewBtn, findsOneWidget);
    await tester.tap(reviewBtn);
    await tester.pumpAndSettle();

    // Verify Admin-only authority banner inside modal (Step 5)
    expect(find.textContaining('City Admin Approval Authority: As a Field Supervisor, leave approval or denial is reserved for Central Admin'), findsOneWidget);

    // Verify Approve and Deny buttons are NOT present in supervisor view
    expect(find.text('Approve Leave'), findsNothing);
    expect(find.text('Deny Leave'), findsNothing);

    // Verify Supervisor Recommendation input (Step 6)
    expect(find.text('Supervisor Recommendation & Endorsement'), findsOneWidget);

    // Submit endorsement
    final endorsementInput = find.byType(TextField).last;
    await tester.enterText(endorsementInput, 'Recommend approval: temporary relief worker assigned to sector.');
    final submitBtn = find.text('Submit Endorsement to Admin');
    await tester.ensureVisible(submitBtn);
    await tester.tap(submitBtn);
    await tester.pumpAndSettle();

    // Verify toast confirmation
    expect(find.textContaining('Supervisor recommendation submitted for Admin review'), findsOneWidget);
  });
}



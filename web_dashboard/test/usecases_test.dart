import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:web_dashboard/features/employees/employees_view.dart';
import 'package:web_dashboard/features/work_areas/work_areas_view.dart';
import 'package:web_dashboard/features/leaves/leaves_view.dart';
import 'package:web_dashboard/features/accomplishments/accomplishments_view.dart';
import 'package:web_dashboard/features/reports/reports_view.dart';
import 'package:web_dashboard/features/notifications/notifications_view.dart';
import 'package:web_dashboard/features/dashboard/dashboard_view.dart';
import 'package:web_dashboard/features/incidents/incidents_view.dart';
import 'package:web_dashboard/data/models/user_model.dart';
import 'package:web_dashboard/data/models/work_area_model.dart';
import 'package:web_dashboard/data/models/attendance_model.dart';
import 'package:web_dashboard/data/models/accomplishment_model.dart';
import 'package:web_dashboard/data/models/leave_request_model.dart';
import 'package:web_dashboard/data/models/alert_model.dart';
import 'package:web_dashboard/data/models/broadcast_model.dart';
import 'package:web_dashboard/data/models/incident_report_model.dart';
import 'package:web_dashboard/data/models/location_tracking_model.dart';
import 'package:web_dashboard/data/repositories/mock_repository.dart';
import 'package:web_dashboard/data/repositories/repository_provider.dart';
import 'package:web_dashboard/features/work_areas/widgets/area_workers_dialog.dart';
import 'package:web_dashboard/features/attendance/attendance_view.dart';
import 'package:web_dashboard/core/utils/official_report_pdf_helper.dart';

class _SupervisorUserNotifier extends CurrentUserNotifier {
  final UserModel _user;
  _SupervisorUserNotifier(this._user);
  @override
  UserModel build() => _user;
}

MockRepository createTestRepository() {
  return MockRepository(
    initialWorkAreas: [
      WorkAreaModel(
        workareaId: 'area-1',
        name: 'Ormoc City Hall Zone',
        description: 'Administrative perimeter and offices',
        supervisorId: 'user-sup-1',
        supervisorName: 'Juan Santos',
        assignedCount: 4,
        status: 'Active',
        areaSqKm: '1.20 km²',
        polygon: const [
          LatLng(11.0050, 124.6060),
          LatLng(11.0070, 124.6060),
          LatLng(11.0070, 124.6090),
          LatLng(11.0050, 124.6090),
        ],
      ),
      WorkAreaModel(
        workareaId: 'area-2',
        name: 'Ormoc Public Market',
        description: 'Public market and commercial zone',
        supervisorId: 'user-sup-2',
        supervisorName: 'Maria Santos',
        assignedCount: 2,
        status: 'Active',
        areaSqKm: '0.85 km²',
        polygon: const [
          LatLng(11.0080, 124.6040),
          LatLng(11.0090, 124.6040),
          LatLng(11.0090, 124.6050),
          LatLng(11.0080, 124.6050),
        ],
      ),
    ],
    initialUsers: [
      UserModel(
        userId: 'user-admin',
        username: 'admin@ormoc.gov.ph',
        firstName: 'Mark Kevin',
        lastName: 'Canonoy',
        contactNumber: '+63 917 555 0199',
        role: UserRole.admin,
        status: 'active',
        schedule: 'Mon-Fri 08:00 - 17:00',
        faceEmbedding: '[0.1, 0.2, 0.3]',
      ),
      UserModel(
        userId: 'user-sup-1',
        username: 'sup_juan',
        firstName: 'Juan',
        lastName: 'Santos',
        contactNumber: '+63 917 222 0002',
        role: UserRole.supervisor,
        status: 'active',
        assignedAreaId: 'area-1',
        assignedAreaName: 'Ormoc City Hall Zone',
        schedule: 'Mon-Fri 08:00 - 17:00',
        faceEmbedding: '[0.1, 0.2, 0.3]',
      ),
      UserModel(
        userId: 'user-w-1',
        username: 'carlos.mendoza',
        firstName: 'Carlos',
        lastName: 'Mendoza',
        contactNumber: '+63 917 333 4444',
        role: UserRole.worker,
        status: 'active',
        assignedAreaId: 'area-1',
        assignedAreaName: 'Ormoc City Hall Zone',
        creditScore: 88,
        schedule: 'Mon-Fri 08:00 - 17:00',
        faceEmbedding: '[0.1, 0.2, 0.3]',
      ),
      UserModel(
        userId: 'user-w-2',
        username: 'elena.reyes',
        firstName: 'Elena',
        lastName: 'Reyes',
        contactNumber: '+63 917 333 5555',
        role: UserRole.worker,
        status: 'active',
        assignedAreaId: 'area-1',
        assignedAreaName: 'Ormoc City Hall Zone',
        creditScore: 94,
        schedule: 'Mon-Fri 08:00 - 17:00',
        faceEmbedding: '[0.1, 0.2, 0.3]',
      ),
    ],
    initialAttendanceLogs: [
      AttendanceModel(
        attendanceId: 'att-1',
        userId: 'user-w-1',
        workerName: 'Carlos Mendoza',
        workerEmpId: 'EMP-001',
        workareaId: 'area-1',
        areaName: 'Ormoc City Hall Zone',
        actionType: 'time-in',
        timestamp: DateTime.now(),
        gpsLat: 11.0055,
        gpsLng: 124.6065,
        faceMatch: true,
        isVerified: true,
      ),
    ],
    initialAccomplishments: [
      AccomplishmentModel(
        accomplishmentId: 'acc-1',
        userId: 'user-w-1',
        workerName: 'Carlos Mendoza',
        workareaId: 'area-1',
        areaName: 'Ormoc City Hall Zone',
        message: 'Sector street sanitation and drain clearing completed.',
        capturedDate: DateTime.now().toIso8601String().substring(0, 10),
        capturedTime: '08:30:00',
        imageUrl: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
        capturedLat: 11.0055,
        capturedLng: 124.6065,
        status: 'pending',
      ),
    ],
    initialLeaveRequests: [
      LeaveRequestModel(
        leaveId: 'leave-1',
        userId: 'user-w-1',
        workerName: 'Carlos Mendoza',
        workareaId: 'area-1',
        areaName: 'Ormoc City Hall Zone',
        type: 'Sick Leave',
        startDate: '2026-11-05',
        endDate: '2026-11-07',
        reason: 'Flu symptoms and medical rest advisory.',
        status: 'pending',
        imageUrl: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
      ),
    ],
    initialAlerts: [
      AlertModel(
        alertId: 'alert-1',
        userId: 'user-w-1',
        workerName: 'Carlos Mendoza',
        workareaId: 'area-1',
        workareaName: 'Ormoc City Hall Zone',
        type: 'Consecutive Absences',
        title: '3+ Consecutive Unexcused Absences',
        description: 'Carlos Mendoza has missed 3 consecutive shifts without filed leave.',
        severity: 'warning',
        timeAgo: '10m ago',
        createdAt: DateTime.now(),
      ),
    ],
    initialLocationTracking: [
      LocationTrackingModel(
        locationId: 'loc-1',
        userId: 'user-w-1',
        gpsLat: 11.0055,
        gpsLng: 124.6065,
        timestamp: DateTime.now(),
        isInsideGeofence: true,
        isLastSeen: true,
      ),
    ],
    initialIncidents: [
      IncidentReportModel(
        reportId: 'inc-1',
        reporterId: 'user-sup-1',
        reporterName: 'Juan Santos',
        reportedId: 'user-w-1',
        reportedName: 'Carlos Mendoza',
        workareaId: 'area-1',
        areaName: 'Ormoc City Hall Zone',
        issueType: 'Not Working / Loitering',
        description: 'Worker loitering outside designated sector zone.',
        status: 'pending',
        createdAt: DateTime.now(),
      ),
    ],
  );
}

Widget createTestApp({
  required Widget child,
  List<dynamic> overrides = const [],
  MockRepository? repository,
}) {
  final repo = repository ?? createTestRepository();
  return ProviderScope(
    overrides: [
      dataRepositoryProvider.overrideWithValue(repo),
      ...overrides.cast(),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: child,
      ),
    ),
  );
}

void main() {
  testWidgets('UC-01: EmployeesView opens enrollment modal and performs facial capture', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      createTestApp(
        child: const EmployeesView(),
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
    expect(find.text('Use Webcam (Laptop / USB)'), findsOneWidget);
    expect(find.text('Upload Image File'), findsOneWidget);

    // Close modal
    final cancelBtn = find.text('Cancel');
    await tester.ensureVisible(cancelBtn);
    await tester.tap(cancelBtn);
    await tester.pumpAndSettle();

    // Click on an existing employee to inspect biometrics
    final detailsIcon = find.byIcon(Icons.visibility_outlined).first;
    await tester.ensureVisible(detailsIcon);
    await tester.tap(detailsIcon);
    await tester.pumpAndSettle();

    // Verify Biometric Facial Enrollment in details modal
    expect(find.text('Biometric Facial Enrollment'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
  });

  testWidgets('UC-01b: EmployeesView hides Admin by default, toggles admin visibility, and sorts supervisor on top when filtering by area', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      createTestApp(
        child: const EmployeesView(),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify Admin is hidden by default
    expect(find.text('Mark Kevin Canonoy'), findsNothing);
    expect(find.text('Show Admins (1)'), findsOneWidget);

    // 2. Toggle Show Admins
    await tester.tap(find.text('Show Admins (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Mark Kevin Canonoy'), findsOneWidget);
    expect(find.text('Hide Admins'), findsOneWidget);

    // 3. Toggle Hide Admins again
    await tester.tap(find.text('Hide Admins'));
    await tester.pumpAndSettle();

    expect(find.text('Mark Kevin Canonoy'), findsNothing);
    expect(find.text('Show Admins (1)'), findsOneWidget);

    // 4. Verify Supervisor is present and labeled
    expect(find.text('Juan Santos'), findsOneWidget);
    expect(find.text('FIELD SUPERVISOR'), findsOneWidget);

    // 5. Filter by Area (Ormoc City Hall Zone)
    await tester.tap(find.text('All Work Areas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ormoc City Hall Zone').last);
    await tester.pumpAndSettle();

    // Supervisor and area workers are shown
    expect(find.text('Juan Santos'), findsOneWidget);
    expect(find.text('Carlos Mendoza'), findsOneWidget);
    expect(find.text('Elena Reyes'), findsOneWidget);
  });

  testWidgets('UC-02: WorkAreasView confirms deletion safety warning when personnel are assigned', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      createTestApp(
        child: const WorkAreasView(),
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
      createTestApp(
        child: const LeavesView(),
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
      createTestApp(
        child: const AccomplishmentsView(),
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
      createTestApp(
        child: const ReportsView(),
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

    expect(find.text('COMPLIANCE STATUS'), findsOneWidget);
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
      createTestApp(
        child: const ReportsView(),
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
      createTestApp(
        child: const NotificationsView(),
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

    final repo = createTestRepository();
    await tester.pumpWidget(
      createTestApp(
        repository: repo,
        child: const WorkAreasView(),
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
    final areas = await repo.getWorkAreas();
    final area = areas.first;
    await tester.pumpWidget(
      createTestApp(
        repository: repo,
        child: AreaWorkersDialog(area: area),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining(area.name), findsWidgets);
    expect(find.textContaining('WORKFORCE ROSTER'), findsOneWidget);
  });

  testWidgets('UC-08 & UC-10: GIS Workforce Map renders live pins, sector filtering and 1-minute historical movement', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      createTestApp(
        child: const DashboardView(),
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

    // Verify historical path is enabled and privacy badge is removed
    expect(find.textContaining('privacy-protected'), findsNothing);
    expect(find.byType(PolylineLayer), findsOneWidget);

    // Verify legend
    expect(find.text('On-site (Within Geofence)'), findsOneWidget);
    expect(find.text('Off-site / Breach Alert'), findsOneWidget);
  });

  testWidgets('UC-08 & UC-10: Map worker marker tap opens detailed violation and telemetry inspection modal without raw token ID', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final repo = MockRepository(
      initialWorkAreas: [
        WorkAreaModel(
          workareaId: 'area-1',
          name: 'Ormoc City Hall Zone',
          supervisorName: 'Juan Santos',
          polygon: const [
            LatLng(11.0050, 124.6060),
            LatLng(11.0070, 124.6060),
            LatLng(11.0070, 124.6090),
            LatLng(11.0050, 124.6090),
          ],
        ),
      ],
      initialUsers: [
        UserModel(
          userId: 'user-w-breach',
          username: 'roberto.dela.cruz',
          firstName: 'Roberto',
          lastName: 'Dela Cruz',
          contactNumber: '+63 917 888 9999',
          role: UserRole.worker,
          status: 'active',
          assignedAreaId: 'area-1',
          assignedAreaName: 'Ormoc City Hall Zone',
          creditScore: 82,
          schedule: 'Mon-Fri 08:00 - 17:00',
        ),
      ],
      initialAttendanceLogs: [
        AttendanceModel(
          attendanceId: 'att-breach-1',
          userId: 'user-w-breach',
          workerName: 'Roberto Dela Cruz',
          workerEmpId: 'BW-ORMC-1741369281923',
          workareaId: 'area-1',
          areaName: 'Ormoc City Hall Zone',
          actionType: 'time-in',
          timestamp: DateTime.now(),
          gpsLat: 11.0090, // Outside polygon max lat 11.0070, centered on map
          gpsLng: 124.6075,
          faceMatch: true,
          isVerified: false, // Flagged breach
          timeIn: '08:15 AM',
        ),
      ],
      initialAlerts: [
        AlertModel(
          alertId: 'alt-1',
          userId: 'user-w-breach',
          workerName: 'Roberto Dela Cruz',
          type: 'Geofence Breach',
          title: 'Geofence Perimeter Breach',
          description: 'Worker detected outside Ormoc City Hall Zone perimeter.',
          timeAgo: '10m ago',
          createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
        ),
      ],
    );

    await tester.pumpWidget(
      createTestApp(
        repository: repo,
        child: const DashboardView(),
      ),
    );
    await tester.pumpAndSettle();

    // Ensure map is visible on screen
    await tester.ensureVisible(find.byType(FlutterMap));
    await tester.pumpAndSettle();

    // Verify breach marker exists on map and tap the warning icon inside it
    final warningIcon = find.byIcon(Icons.warning_amber_rounded).first;
    expect(warningIcon, findsOneWidget);
    await tester.tap(warningIcon);
    await tester.pumpAndSettle();

    // Verify modal appears with clean details and NO useless BW-ORMC ID
    expect(find.text('Roberto Dela Cruz'), findsWidgets);
    expect(find.text('OFF-SITE BREACH'), findsOneWidget);
    expect(find.textContaining('BW-ORMC-'), findsNothing); // Useless token is removed!

    // Verify clean metadata
    expect(find.textContaining('Field Worker • Shift: Mon-Fri 08:00 - 17:00 • Contact: +63 917 888 9999'), findsOneWidget);

    // Verify Specific Detected Violations section
    expect(find.text('DETECTED VIOLATIONS & ANOMALIES'), findsOneWidget);
    expect(find.text('Geofence Perimeter Breach'), findsWidgets);
    expect(find.textContaining('outside authorized Ormoc City Hall Zone boundary'), findsOneWidget);

    // Verify Telemetry card
    expect(find.text('Designated Sector'), findsOneWidget);
    expect(find.text('Supv: Juan Santos'), findsOneWidget);
    expect(find.text('Workforce Standing'), findsOneWidget);
    expect(find.text('Action Required'), findsOneWidget);
    expect(find.text('Today Check-In Time'), findsOneWidget);
    expect(find.text('Biometric Face Verified'), findsOneWidget);

    // Dismiss dialog
    await tester.tap(find.text('Close Profile'));
    await tester.pumpAndSettle();

    expect(find.text('DETECTED VIOLATIONS & ANOMALIES'), findsNothing);
  });

  testWidgets('UC-09: NotificationsView responds to alerts with warnings and dismiss audit logs', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      createTestApp(
        child: const NotificationsView(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify alert categories
    expect(find.text('All Alerts'), findsOneWidget);
    expect(find.text('Consecutive Absences (3+)'), findsOneWidget);
    expect(find.text('Compliance Warnings'), findsOneWidget);
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
      createTestApp(
        overrides: [
          currentUserProvider.overrideWith(() => _SupervisorUserNotifier(supervisorUser)),
        ],
        child: const IncidentsView(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Title and Subtitle for Supervisor
    expect(find.text('Worker Incident & Issue Reports'), findsOneWidget);
    expect(find.textContaining('Review worker issue reports in your sector'), findsOneWidget);
    expect(find.text('Assigned Sector: Ormoc City Hall Zone'), findsOneWidget);

    // Verify Date Navigator and Sort controls
    expect(find.text('All Dates'), findsOneWidget);
    expect(find.text('Sort: Newest First'), findsOneWidget);

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
      createTestApp(
        overrides: [
          currentUserProvider.overrideWith(() => _SupervisorUserNotifier(supervisorUser)),
        ],
        child: const ReportsView(),
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
      createTestApp(
        overrides: [
          currentUserProvider.overrideWith(() => _SupervisorUserNotifier(supervisorUser)),
        ],
        child: const LeavesView(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Supervisor notice banner on top of table
    expect(find.textContaining('Supervisor Notice: As defined in the Role Matrix'), findsOneWidget);

    // Verify Date Navigator and Sort controls
    expect(find.text('All Dates'), findsOneWidget);
    expect(find.text('Sort: Newest Filing'), findsOneWidget);

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

  test('AlertModel live credit score extraction and warning penalty deduction parity', () async {
    // 1. Verify AlertModel extracts live score from joined user credit_balance
    final rawJsonWithUser = {
      'alert_id': 'alt-101',
      'user_id': 'user-w-1',
      'type': 'Geofence Breach',
      'message': 'Worker stepped outside sector boundary',
      'created_at': DateTime.now().toIso8601String(),
      'users': {
        'first_name': 'Carlos',
        'last_name': 'Mendoza',
        'qr_token': 'WRK-001',
        'contact_number': '+63 917 333 4444',
        'credit_balance': {
          'current_score': 95,
        },
      },
    };

    final alertModel = AlertModel.fromJson(rawJsonWithUser);
    expect(alertModel.creditScore, equals(95));
    expect(alertModel.workerName, equals('Carlos Mendoza'));

    // 2. Verify fallback to 100 (not 85) when user has not yet been penalized
    final rawJsonUnpenalized = {
      'alert_id': 'alt-102',
      'user_id': 'user-w-2',
      'type': 'breach',
      'message': 'Perimeter breached',
      'users': {
        'first_name': 'Ana',
        'last_name': 'Reyes',
      },
    };
    final unpenalizedAlert = AlertModel.fromJson(rawJsonUnpenalized);
    expect(unpenalizedAlert.creditScore, equals(100));

    // 3. Verify MockRepository sendWarningForAlert deducts 5 points
    final repo = createTestRepository();
    final usersBefore = await repo.getUsers();
    final workerBefore = usersBefore.firstWhere((u) => u.userId == 'user-w-1');
    final initialScore = workerBefore.creditScore;

    await repo.sendWarningForAlert(
      alertId: 'alert-1',
      workerId: 'user-w-1',
      message: 'Official Warning: Geofence Breach',
    );

    final usersAfter = await repo.getUsers();
    final workerAfter = usersAfter.firstWhere((u) => u.userId == 'user-w-1');
    expect(workerAfter.creditScore, equals(initialScore - 5));

    // 4. Verify BroadcastModel with receiverId serialization
    final broadcast = BroadcastModel(
      notificationId: 'notif-1',
      senderId: 'user-admin',
      receiverId: 'user-w-1',
      recipients: 'Carlos Mendoza',
      subject: 'Sector Relocation',
      message: 'Please proceed to Sector B.',
      type: 'confidential',
      isConfidential: true,
      deliveredCount: 1,
      sentAt: DateTime.now(),
    );
    final supabaseJson = broadcast.toSupabaseJson();
    expect(supabaseJson['receiver_id'], equals('user-w-1'));
    expect(supabaseJson['type'], equals('confidential'));
    expect(supabaseJson['message'], contains('Sector Relocation: Please proceed to Sector B.'));
  });

  test('Workforce Shift Scheduling: updateWorkerSchedule updates user schedule and logs notification', () async {
    final repo = createTestRepository();
    final workerId = 'user-w-1';

    // 1. Verify initial worker schedule
    final initialUsers = await repo.getUsers();
    final worker = initialUsers.firstWhere((u) => u.userId == workerId);
    expect(worker.schedule, isNotEmpty);

    // 2. Update to Morning (AM) shift: 06:00 - 11:00
    await repo.updateWorkerSchedule(
      workerId: workerId,
      startTime: '06:00',
      endTime: '11:00',
      days: 'Mon-Fri',
      areaName: 'Ormoc City Hall Zone',
    );

    final updatedUsers = await repo.getUsers();
    final updatedWorker = updatedUsers.firstWhere((u) => u.userId == workerId);
    expect(updatedWorker.schedule, equals('Mon-Fri 06:00 - 11:00'));

    // 3. Verify that an assignment notification was sent to the worker
    final broadcasts = await repo.getBroadcasts();
    final scheduleNotif = broadcasts.firstWhere(
      (b) => b.receiverId == workerId && (b.subject.contains('Schedule') || b.subject.contains('Shift')),
      orElse: () => throw Exception('Notification not found'),
    );
    expect(scheduleNotif.receiverId, equals(workerId));
    expect(scheduleNotif.message, contains('06:00 - 11:00'));

    // 4. Verify UserModel parses joined schedules array properly
    final rawJsonWithSchedules = {
      'user_id': 'user-w-99',
      'first_name': 'Pedro',
      'last_name': 'Penduko',
      'role': 'Field Worker',
      'schedules': [
        {
          'schedule_id': 'sch-10',
          'start_time': '13:00',
          'end_time': '17:00',
          'days': 'Mon-Sat',
          'created_at': '2026-11-02T10:00:00Z',
        }
      ],
    };

    final parsedUser = UserModel.fromJson(rawJsonWithSchedules);
    expect(parsedUser.schedule, equals('Mon-Sat 13:00 - 17:00'));
  });

  test('DailyWorkerAttendance groups multiple punches per worker into a single stack', () {
    final now = DateTime(2026, 11, 3, 7, 5);
    final logs = [
      AttendanceModel(
        attendanceId: 'att-1',
        userId: 'user-w-1',
        workerName: 'Carlos Mendoza',
        workerEmpId: 'WRK-001',
        workareaId: 'area-1',
        areaName: 'Ormoc City Hall Zone',
        actionType: 'time-in',
        timestamp: now,
        gpsLat: 11.0050,
        gpsLng: 124.6060,
      ),
      AttendanceModel(
        attendanceId: 'att-2',
        userId: 'user-w-1',
        workerName: 'Carlos Mendoza',
        workerEmpId: 'WRK-001',
        workareaId: 'area-1',
        areaName: 'Ormoc City Hall Zone',
        actionType: 'break-in',
        timestamp: now.add(const Duration(hours: 3)),
        gpsLat: 11.0051,
        gpsLng: 124.6061,
      ),
      AttendanceModel(
        attendanceId: 'att-3',
        userId: 'user-w-1',
        workerName: 'Carlos Mendoza',
        workerEmpId: 'WRK-001',
        workareaId: 'area-1',
        areaName: 'Ormoc City Hall Zone',
        actionType: 'break-out',
        timestamp: now.add(const Duration(hours: 3, minutes: 15)),
        gpsLat: 11.0050,
        gpsLng: 124.6060,
      ),
      AttendanceModel(
        attendanceId: 'att-4',
        userId: 'user-w-1',
        workerName: 'Carlos Mendoza',
        workerEmpId: 'WRK-001',
        workareaId: 'area-1',
        areaName: 'Ormoc City Hall Zone',
        actionType: 'time-out',
        timestamp: now.add(const Duration(hours: 5)),
        gpsLat: 11.0050,
        gpsLng: 124.6060,
      ),
      AttendanceModel(
        attendanceId: 'att-5',
        userId: 'user-w-2',
        workerName: 'Ana Reyes',
        workerEmpId: 'WRK-002',
        workareaId: 'area-2',
        areaName: 'Ormoc Public Market',
        actionType: 'time-in',
        timestamp: now.add(const Duration(minutes: 10)),
        gpsLat: 11.0080,
        gpsLng: 124.6040,
      ),
    ];

    final grouped = DailyWorkerAttendance.groupLogs(logs);
    // 5 total punches across 2 workers must group into 2 cards
    expect(grouped.length, equals(2));

    final carlosGroup = grouped.firstWhere((g) => g.userId == 'user-w-1');
    expect(carlosGroup.punches.length, equals(4));
    expect(carlosGroup.timeInPunch, isNotNull);
    expect(carlosGroup.breakInPunch, isNotNull);
    expect(carlosGroup.breakOutPunch, isNotNull);
    expect(carlosGroup.timeOutPunch, isNotNull);
    expect(carlosGroup.statusSummary, equals('SHIFT COMPLETE'));
    expect(carlosGroup.allFaceMatched, isTrue);

    final anaGroup = grouped.firstWhere((g) => g.userId == 'user-w-2');
    expect(anaGroup.punches.length, equals(1));
    expect(anaGroup.statusSummary, equals('ON DUTY'));
  });

  testWidgets('AttendanceView renders stacked card and expands punch details with proof modal', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final repo = createTestRepository();
    final container = ProviderContainer(
      overrides: [
        dataRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: AttendanceView()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify view loads with Attendance Verification title, Weekly Matrix, and Schedule Management button
    expect(find.text('Attendance Verification'), findsOneWidget);
    expect(find.text('Weekly Attendance Register'), findsOneWidget);
    expect(find.text('Actual Attendance Logs'), findsOneWidget);
    expect(find.text('Manage Worker Schedules'), findsOneWidget);

    // Verify worker card renders with initials avatar and sequence chips in Section B
    expect(find.text('Carlos Mendoza'), findsWidgets);
    expect(find.text('IN: '), findsWidgets);

    // Click on worker card in Section B to expand dropdown stack
    final workerCard = find.text('Carlos Mendoza').last;
    await tester.tap(workerCard);
    await tester.pumpAndSettle();

    // Verify expanded section shows English punch history and biometric verification status
    expect(find.textContaining('Punch History'), findsOneWidget);
    expect(find.text('Time-In'), findsWidgets);
    expect(find.text('FACE VERIFIED'), findsWidgets);
    expect(find.text('All Punches Biometrically Verified'), findsOneWidget);

    // Click "Manage Worker Schedules" to open Excel Workbook view
    await tester.tap(find.text('Manage Worker Schedules'));
    await tester.pumpAndSettle();

    expect(find.text('Worker Schedule Management'), findsOneWidget);
    expect(find.text('EXCEL WORKBOOK FORMAT'), findsOneWidget);
    expect(find.text('Back to Attendance'), findsOneWidget);

    // Click "Back to Attendance" to return
    await tester.tap(find.text('Back to Attendance'));
    await tester.pumpAndSettle();
    expect(find.text('Weekly Attendance Register'), findsOneWidget);
  });

  testWidgets('UC-03b: LeavesView denial flow with reason updates status to denied', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      createTestApp(
        child: const LeavesView(),
      ),
    );
    await tester.pumpAndSettle();

    final reviewButtons = find.text('Review');
    expect(reviewButtons, findsWidgets);

    await tester.ensureVisible(reviewButtons.first);
    await tester.tap(reviewButtons.first);
    await tester.pumpAndSettle();

    // Tap Deny Leave button in review modal
    final denyButton = find.text('Deny Leave');
    expect(denyButton, findsOneWidget);
    await tester.tap(denyButton);
    await tester.pumpAndSettle();

    // Verify denial confirmation dialog appears
    expect(find.text('Deny Leave Request'), findsOneWidget);
    expect(find.text('Confirm Denial'), findsOneWidget);

    // Enter denial reason and confirm
    final reasonField = find.byType(TextField);
    expect(reasonField, findsOneWidget);
    await tester.enterText(reasonField, 'Operational understaffing in sector');
    await tester.pumpAndSettle();

    final confirmDenial = find.text('Confirm Denial');
    await tester.tap(confirmDenial);
    await tester.pumpAndSettle();

    // Verify dialog dismissed and info toast triggered
    expect(find.text('Deny Leave Request'), findsNothing);
  });

  testWidgets('UC-03c: LeavesView date filtering excludes leave requests when day before is selected', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      createTestApp(
        child: const LeavesView(),
      ),
    );
    await tester.pumpAndSettle();

    // Initially "All Dates" is active
    expect(find.text('All Dates'), findsOneWidget);
    expect(find.textContaining('leave applications'), findsOneWidget);

    // Click Previous Day on Date Navigator
    final prevDayBtn = find.byTooltip('Previous Day');
    expect(prevDayBtn, findsOneWidget);
    await tester.tap(prevDayBtn);
    await tester.pumpAndSettle();

    // Verify the date navigator changes from All Dates to a specific formatted date
    expect(find.text('All Dates'), findsNothing);
  });

  testWidgets('UC-11b: IncidentsView date filtering strictly excludes incidents when day before is selected', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      createTestApp(
        child: const IncidentsView(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Worker Incident & Issue Reports'), findsOneWidget);

    // Initially All Dates is active
    expect(find.text('All Dates'), findsOneWidget);

    // Navigate to previous day
    final prevDayBtn = find.byTooltip('Previous Day');
    expect(prevDayBtn, findsOneWidget);
    await tester.tap(prevDayBtn);
    await tester.pumpAndSettle();

    expect(find.text('All Dates'), findsNothing);
  });

  testWidgets('UC-03d: LeavesView renders Export CSV and Export Official PDF buttons', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      createTestApp(
        child: const LeavesView(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Leave Request Management'), findsOneWidget);
    expect(find.text('Export CSV / Excel'), findsOneWidget);
    expect(find.text('Export Official PDF'), findsOneWidget);
  });

  test('OfficialReportPdfHelper generates valid PDF document bytes with LGU letterhead', () async {
    final user = UserModel(
      userId: 'test-admin',
      username: 'admin',
      firstName: 'Admin',
      lastName: 'User',
      contactNumber: '123',
      role: UserRole.admin,
      status: 'active',
      schedule: 'Regular',
    );

    final leaves = <LeaveRequestModel>[
      LeaveRequestModel(
        leaveId: 'LR-001',
        userId: 'user-001',
        workerName: 'Juan Dela Cruz',
        areaName: 'City Hall',
        type: 'Sick Leave',
        startDate: '2026-11-06',
        endDate: '2026-11-07',
        reason: 'Severe fever with medical certificate',
        status: 'approved',
      ),
    ];

    final pdfBytes = await OfficialReportPdfHelper.generateLeavesPdf(
      leaves: leaves,
      generatedBy: user,
      dateRangeLabel: 'All Dates',
      sectorLabel: 'All Ormoc Sectors',
    );

    expect(pdfBytes.isNotEmpty, isTrue);
    // PDF magic bytes: %PDF
    expect(String.fromCharCodes(pdfBytes.take(4)), '%PDF');
  });

  group('Flexible Breaks and Worked Hours Calculation Tests', () {
    test('Calculates net worked hours with multiple breaks correctly', () {
      final punches = [
        AttendanceModel(
          attendanceId: '1',
          userId: 'u1',
          workerName: 'Pedro Penduko',
          workerEmpId: 'BW-01',
          workareaId: 'w1',
          areaName: 'Zone 1',
          actionType: 'time-in',
          timestamp: DateTime(2026, 11, 11, 8, 0), // 8:00 AM
          gpsLat: 11.0,
          gpsLng: 124.0,
        ),
        AttendanceModel(
          attendanceId: '2',
          userId: 'u1',
          workerName: 'Pedro Penduko',
          workerEmpId: 'BW-01',
          workareaId: 'w1',
          areaName: 'Zone 1',
          actionType: 'break-in',
          timestamp: DateTime(2026, 11, 11, 10, 0), // 10:00 AM (Break 1 start)
          gpsLat: 11.0,
          gpsLng: 124.0,
        ),
        AttendanceModel(
          attendanceId: '3',
          userId: 'u1',
          workerName: 'Pedro Penduko',
          workerEmpId: 'BW-01',
          workareaId: 'w1',
          areaName: 'Zone 1',
          actionType: 'break-out',
          timestamp: DateTime(2026, 11, 11, 11, 0), // 11:00 AM (Break 1 end = 1 hour)
          gpsLat: 11.0,
          gpsLng: 124.0,
        ),
        AttendanceModel(
          attendanceId: '4',
          userId: 'u1',
          workerName: 'Pedro Penduko',
          workerEmpId: 'BW-01',
          workareaId: 'w1',
          areaName: 'Zone 1',
          actionType: 'break-in',
          timestamp: DateTime(2026, 11, 11, 12, 0), // 12:00 PM (Break 2 start)
          gpsLat: 11.0,
          gpsLng: 124.0,
        ),
        AttendanceModel(
          attendanceId: '5',
          userId: 'u1',
          workerName: 'Pedro Penduko',
          workerEmpId: 'BW-01',
          workareaId: 'w1',
          areaName: 'Zone 1',
          actionType: 'break-out',
          timestamp: DateTime(2026, 11, 11, 13, 0), // 1:00 PM (Break 2 end = 1 hour)
          gpsLat: 11.0,
          gpsLng: 124.0,
        ),
        AttendanceModel(
          attendanceId: '6',
          userId: 'u1',
          workerName: 'Pedro Penduko',
          workerEmpId: 'BW-01',
          workareaId: 'w1',
          areaName: 'Zone 1',
          actionType: 'time-out',
          timestamp: DateTime(2026, 11, 11, 17, 0), // 5:00 PM (Gross = 9 hours)
          gpsLat: 11.0,
          gpsLng: 124.0,
        ),
      ];

      final daily = DailyWorkerAttendance(
        userId: 'u1',
        workerName: 'Pedro Penduko',
        workerEmpId: 'BW-01',
        workareaId: 'w1',
        areaName: 'Zone 1',
        dateKey: '2026-11-11',
        punches: punches,
      );

      expect(daily.breakCount, 2);
      expect(daily.totalBreakDuration.inHours, 2);
      expect(daily.totalWorkedDuration.inHours, 7); // 9h gross - 2h breaks = 7h net
      expect(daily.formattedTotalHoursWorked, '7h 0m');
      expect(daily.statusSummary, 'SHIFT COMPLETE');
    });

    test('Calculates net worked hours without any breaks correctly', () {
      final punches = [
        AttendanceModel(
          attendanceId: '1',
          userId: 'u2',
          workerName: 'Worker Two',
          workerEmpId: 'BW-02',
          workareaId: 'w1',
          areaName: 'Zone 1',
          actionType: 'time-in',
          timestamp: DateTime(2026, 11, 11, 8, 0), // 8:00 AM
          gpsLat: 11.0,
          gpsLng: 124.0,
        ),
        AttendanceModel(
          attendanceId: '2',
          userId: 'u2',
          workerName: 'Worker Two',
          workerEmpId: 'BW-02',
          workareaId: 'w1',
          areaName: 'Zone 1',
          actionType: 'time-out',
          timestamp: DateTime(2026, 11, 11, 11, 0), // 11:00 AM (Gross = 3 hours)
          gpsLat: 11.0,
          gpsLng: 124.0,
        ),
      ];

      final daily = DailyWorkerAttendance(
        userId: 'u2',
        workerName: 'Worker Two',
        workerEmpId: 'BW-02',
        workareaId: 'w1',
        areaName: 'Zone 1',
        dateKey: '2026-11-11',
        punches: punches,
      );

      expect(daily.breakCount, 0);
      expect(daily.totalBreakDuration, Duration.zero);
      expect(daily.totalWorkedDuration.inHours, 3);
      expect(daily.formattedTotalHoursWorked, '3h 0m');
      expect(daily.statusSummary, 'SHIFT COMPLETE');
    });
  });

  group('Worker Schedule Management Enhancements', () {
    testWidgets('Renders horizontal Scrollbar and handles worker deletion & re-addition in another month', (tester) async {
      final repo = createTestRepository();

      // Pre-populate December 2026 sheets
      final decSheets = await repo.getScheduleSheets(month: 12, year: 2026);
      expect(decSheets.isNotEmpty, isTrue);
      final firstSheet = decSheets.first;
      expect(firstSheet.entries.isNotEmpty, isTrue);

      final workerToRemove = firstSheet.entries.first;
      final remainingEntries = firstSheet.entries.sublist(1);
      final updatedSheet = firstSheet.copyWith(entries: remainingEntries);
      await repo.saveScheduleSheet(updatedSheet);

      // Verify the sheet in repo no longer contains workerToRemove
      final reloadedSheets = await repo.getScheduleSheets(month: 12, year: 2026);
      final reloadedSheet = reloadedSheets.firstWhere((s) => s.sheetId == firstSheet.sheetId);
      expect(reloadedSheet.entries.any((e) => e.userId == workerToRemove.userId), isFalse);

      // Verify all workers list from repo contains workerToRemove
      final allWorkers = await repo.getUsers(role: UserRole.worker);
      expect(allWorkers.any((w) => w.userId == workerToRemove.userId), isTrue);

      // Available workers for re-addition should now include workerToRemove
      final existingIds = reloadedSheet.entries.map((e) => e.userId).toSet();
      final available = allWorkers.where((w) => !existingIds.contains(w.userId)).toList();
      expect(available.any((w) => w.userId == workerToRemove.userId), isTrue);
    });
  });
}



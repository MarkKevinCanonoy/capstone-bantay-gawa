import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:web_dashboard/core/widgets/app_button.dart';
import 'package:web_dashboard/core/widgets/user_avatar.dart';
import 'package:web_dashboard/core/widgets/app_header.dart';
import 'package:web_dashboard/data/models/alert_model.dart';
import 'package:web_dashboard/data/models/attendance_model.dart';
import 'package:web_dashboard/data/models/user_model.dart';
import 'package:web_dashboard/data/models/work_area_model.dart';
import 'package:web_dashboard/data/models/worker_schedule_sheet_model.dart';
import 'package:web_dashboard/data/repositories/mock_repository.dart';
import 'package:web_dashboard/data/repositories/repository_provider.dart';
import 'package:web_dashboard/features/attendance/attendance_view.dart';
import 'package:web_dashboard/features/work_areas/widgets/area_workers_dialog.dart';
import 'package:web_dashboard/features/work_areas/work_areas_view.dart';
import 'package:web_dashboard/features/employees/employees_view.dart';
import 'package:web_dashboard/features/incidents/incidents_view.dart';
import 'package:web_dashboard/features/attendance/worker_schedule_management_view.dart';
import 'package:web_dashboard/features/notifications/notifications_view.dart';

class _CustomUserNotifier extends CurrentUserNotifier {
  final UserModel _user;
  _CustomUserNotifier(this._user);
  @override
  UserModel build() => _user;
}

Widget createTestApp({
  required Widget child,
  required MockRepository repository,
  List<dynamic> overrides = const [],
}) {
  return ProviderScope(
    overrides: [
      dataRepositoryProvider.overrideWithValue(repository),
      ...overrides.cast(),
    ],
    child: MaterialApp(
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final supervisorUser = UserModel(
    userId: 'user-sup-1',
    username: 'jsantos',
    firstName: 'Juan',
    lastName: 'Santos',
    role: UserRole.supervisor,
    assignedAreaId: 'area-1',
    assignedAreaName: 'Ormoc City Hall Zone',
    contactNumber: '+63 912 345 6789',
    qrToken: 'TOKEN_SUP_1',
    creditScore: 100,
    status: 'active',
  );

  final worker1 = UserModel(
    userId: 'user-w1',
    username: 'rgarcia',
    firstName: 'Ramon',
    lastName: 'Garcia',
    role: UserRole.worker,
    assignedAreaId: 'area-1',
    assignedAreaName: 'Ormoc City Hall Zone',
    contactNumber: '+63 920 111 2222',
    qrToken: 'TOKEN_W1',
    creditScore: 92,
    status: 'active',
  );

  final worker2 = UserModel(
    userId: 'user-w2',
    username: 'mlopez',
    firstName: 'Maria',
    lastName: 'Lopez',
    role: UserRole.worker,
    assignedAreaId: 'area-2',
    assignedAreaName: 'Market Zone',
    contactNumber: '+63 920 333 4444',
    qrToken: 'TOKEN_W2',
    creditScore: 85,
    status: 'active',
  );

  final unassignedWorker = UserModel(
    userId: 'user-w3',
    username: 'pdelacruz',
    firstName: 'Pedro',
    lastName: 'Dela Cruz',
    role: UserRole.worker,
    assignedAreaId: null,
    assignedAreaName: null,
    contactNumber: '+63 920 555 6666',
    qrToken: 'TOKEN_W3',
    creditScore: 78,
    status: 'active',
  );

  final area1 = WorkAreaModel(
    workareaId: 'area-1',
    name: 'Ormoc City Hall Zone',
    description: 'City Hall Sector',
    supervisorId: 'user-sup-1',
    supervisorName: 'Juan Santos',
    assignedCount: 1,
    status: 'Active',
    areaSqKm: '1.20 km²',
    polygon: [
      const LatLng(11.005, 124.605),
      const LatLng(11.009, 124.605),
      const LatLng(11.009, 124.610),
      const LatLng(11.005, 124.610),
    ],
  );

  final area2 = WorkAreaModel(
    workareaId: 'area-2',
    name: 'Market Zone',
    description: 'Public Market Sector',
    supervisorId: 'user-sup-2',
    supervisorName: 'Other Supervisor',
    assignedCount: 1,
    status: 'Active',
    areaSqKm: '0.80 km²',
    polygon: [
      const LatLng(11.010, 124.610),
      const LatLng(11.015, 124.610),
      const LatLng(11.015, 124.615),
      const LatLng(11.010, 124.615),
    ],
  );

  MockRepository createRepo() {
    return MockRepository(
      initialUsers: [supervisorUser, worker1, worker2, unassignedWorker],
      initialWorkAreas: [area1, area2],
      initialIncidents: [],
      initialScheduleSheets: [
        ScheduleSheetModel(
          sheetId: 'sheet-1',
          sheetName: 'Ormoc City Hall Zone',
          month: 11,
          year: 2026,
          entries: [
            ScheduleEntryModel(
              entryId: 'entry-1',
              userId: 'user-w1',
              workerName: 'Ramon Garcia',
              assignedAreaId: 'area-1',
              assignedAreaName: 'Ormoc City Hall Zone',
              dayOff: 'Sunday',
              timeSchedule: '06:00 AM – 03:00 PM',
              statusRemarks: 'Active',
            ),
          ],
        ),
        ScheduleSheetModel(
          sheetId: 'sheet-2',
          sheetName: 'Market Zone',
          month: 11,
          year: 2026,
          entries: [
            ScheduleEntryModel(
              entryId: 'entry-2',
              userId: 'user-w2',
              workerName: 'Maria Lopez',
              assignedAreaId: 'area-2',
              assignedAreaName: 'Market Zone',
              dayOff: 'Monday',
              timeSchedule: '08:00 AM – 05:00 PM',
              statusRemarks: 'Active',
            ),
          ],
        ),
      ],
    );
  }

  testWidgets('UserAvatar non-flicker: caches image provider and enables gaplessPlayback', (tester) async {
    const testBase64 = 'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: UserAvatar(
            photoUrl: testBase64,
            initials: 'JS',
            radius: 20,
          ),
        ),
      ),
    );

    expect(find.byType(UserAvatar), findsOneWidget);
    final imageWidgetFinder = find.byType(Image);
    expect(imageWidgetFinder, findsOneWidget);

    final imageWidget = tester.widget<Image>(imageWidgetFinder);
    expect(imageWidget.gaplessPlayback, isTrue);
    expect(imageWidget.fit, equals(BoxFit.cover));

    // Rebuild with same URL - provider should be identical from static cache
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: UserAvatar(
            photoUrl: testBase64,
            initials: 'JS',
            radius: 20,
          ),
        ),
      ),
    );

    final reImageWidget = tester.widget<Image>(find.byType(Image));
    expect(identical(imageWidget.image, reImageWidget.image), isTrue,
        reason: 'ImageProvider must have identical object identity across rebuilds to prevent flickering');
  });

  testWidgets('AreaWorkersDialog supervisor scoping: only displays workers assigned to supervisor sector', (tester) async {
    final repo = createRepo();

    await tester.pumpWidget(
      createTestApp(
        repository: repo,
        overrides: [
          currentUserProvider.overrideWith(() => _CustomUserNotifier(supervisorUser)),
        ],
        child: AreaWorkersDialog(area: area1),
      ),
    );

    await tester.pumpAndSettle();

    // Verification: Supervisor subtitle is displayed
    expect(find.text('Assigned personnel roster for supervisory oversight.'), findsOneWidget);

    // Verification: Worker 1 (in area-1) is visible
    expect(find.text('Ramon Garcia'), findsOneWidget);

    // Verification: Worker 2 (in area-2) and Unassigned worker must NOT be visible to supervisor
    expect(find.text('Maria Lopez'), findsNothing);
    expect(find.text('Pedro Dela Cruz'), findsNothing);

    // Verification: Admin mutation buttons ('+ Assign', 'Unassign', 'Shift') must NOT be visible
    expect(find.text('+ Assign'), findsNothing);
    expect(find.text('Unassign'), findsNothing);
    expect(find.text('Shift'), findsNothing);
  });

  testWidgets('IncidentsView: supervisor can report worker issue scoped to their sector', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repo = createRepo();

    await tester.pumpWidget(
      createTestApp(
        repository: repo,
        overrides: [
          currentUserProvider.overrideWith(() => _CustomUserNotifier(supervisorUser)),
        ],
        child: const IncidentsView(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify '+ Report Worker Issue' button is present
    final reportBtn = find.text('+ Report Worker Issue');
    expect(reportBtn, findsOneWidget);

    // Tap '+ Report Worker Issue'
    await tester.tap(reportBtn);
    await tester.pumpAndSettle();

    // Modal dialog opens
    expect(find.text('Report Worker Issue'), findsOneWidget);
    expect(find.text('Submit formal disciplinary report to Central Admin (US-19, UC-11).'), findsOneWidget);

    // Worker dropdown: Ramon Garcia is in sector
    expect(find.textContaining('Ramon Garcia'), findsWidgets);

    // Enter description (TextField with hintText)
    final descField = find.widgetWithText(TextField, 'Detail the observed breach, time, and circumstances...');
    await tester.enterText(descField, 'Worker abandoned site without prior notification.');
    await tester.pumpAndSettle();

    // Submit report
    final submitBtn = find.text('Submit to Admin');
    expect(submitBtn, findsOneWidget);
    await tester.tap(submitBtn);
    await tester.pumpAndSettle();

    // Verify report was dispatched to repository
    final incidentsInRepo = await repo.getIncidents();
    expect(incidentsInRepo.length, equals(1));
    expect(incidentsInRepo.first.reportedName, equals('Ramon Garcia'));
    expect(incidentsInRepo.first.reporterId, equals(supervisorUser.userId));
    expect(incidentsInRepo.first.isEscalated, isTrue);
  });

  testWidgets('WorkerScheduleManagementView supervisor scoping: read-only mode and sector sheets only', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repo = createRepo();

    await tester.pumpWidget(
      createTestApp(
        repository: repo,
        overrides: [
          currentUserProvider.overrideWith(() => _CustomUserNotifier(supervisorUser)),
        ],
        child: WorkerScheduleManagementView(onBackToDashboard: () {}),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Supervisor header
    expect(find.text('Team Schedule Roster'), findsOneWidget);
    expect(find.text('Read-Only Team Roster'), findsOneWidget);

    // Verify 'Save Schedule' button is hidden
    expect(find.text('Save Schedule'), findsNothing);

    // Verify 'Add Sheet' and 'Add Worker' buttons are hidden
    expect(find.text('Add Sheet'), findsNothing);
    expect(find.text('Add Worker'), findsNothing);

    // Verify supervisor assigned sector sheet is shown ('Ormoc City Hall Zone')
    expect(find.text('Ormoc City Hall Zone'), findsWidgets);
    expect(find.text('Ramon Garcia'), findsOneWidget);

    // Market Zone sheet (other supervisor) must NOT be shown as an active tab
    expect(find.text('Maria Lopez'), findsNothing);
  });

  testWidgets('AppHeader: switching to supervisor and back to admin preserves markkevincanonoy99@gmail.com account identity', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final adminMark = UserModel(
      userId: 'admin-mark-1',
      username: 'markkevincanonoy99@gmail.com',
      firstName: 'Mark Kevin',
      lastName: 'Canonoy',
      role: UserRole.admin,
      contactNumber: '+63 917 555 0199',
      status: 'active',
    );

    final repo = MockRepository(
      initialUsers: [adminMark, supervisorUser, worker1, worker2],
      initialWorkAreas: [area1, area2],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dataRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          home: Scaffold(
            appBar: const PreferredSize(
              preferredSize: Size.fromHeight(64),
              child: AppHeader(),
            ),
            body: Consumer(
              builder: (context, ref, _) {
                final user = ref.watch(currentUserProvider);
                return Center(
                  child: Text('ACTIVE_USER: ${user.fullName} (${user.username})'),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify initial user is Mark Kevin Canonoy
    expect(find.text('ACTIVE_USER: Mark Kevin Canonoy (markkevincanonoy99@gmail.com)'), findsOneWidget);

    // 1. Open popup menu
    final profileButton = find.byTooltip('Account & Profile');
    expect(profileButton, findsOneWidget);
    await tester.tap(profileButton);
    await tester.pumpAndSettle();

    // 2. Tap 'Switch to Supervisor View'
    final switchToSupervisor = find.text('Switch to Supervisor View');
    expect(switchToSupervisor, findsOneWidget);
    await tester.tap(switchToSupervisor);
    await tester.pumpAndSettle();

    // Verify switched to Juan Santos
    expect(find.text('ACTIVE_USER: Juan Santos (jsantos)'), findsOneWidget);

    // 3. Open popup menu again
    await tester.tap(profileButton);
    await tester.pumpAndSettle();

    // 4. Tap 'Switch to Admin View'
    final switchToAdmin = find.text('Switch to Admin View');
    expect(switchToAdmin, findsOneWidget);
    await tester.tap(switchToAdmin);
    await tester.pumpAndSettle();

    // Verify user is restored to Mark Kevin Canonoy (markkevincanonoy99@gmail.com)
    expect(find.text('ACTIVE_USER: Mark Kevin Canonoy (markkevincanonoy99@gmail.com)'), findsOneWidget);
    expect(find.text('ACTIVE_USER: Administrator ()'), findsNothing);
  });

  testWidgets('NotificationsView: supervisor recipient dropdown excludes own user and only shows sector workers', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final supervisorKitchie = UserModel(
      userId: 'user-sup-kitchie',
      username: 'knadal',
      firstName: 'Kitchie',
      lastName: 'Nadal',
      role: UserRole.supervisor,
      assignedAreaId: 'area-1',
      assignedAreaName: 'Ormoc City Hall Zone',
      contactNumber: '+63 918 123 4567',
      status: 'active',
    );

    final kitchieArea = area1.copyWith(
      supervisorId: supervisorKitchie.userId,
      supervisorName: supervisorKitchie.fullName,
    );

    final repo = MockRepository(
      initialUsers: [supervisorKitchie, worker1, worker2, unassignedWorker],
      initialWorkAreas: [kitchieArea, area2],
    );

    await tester.pumpWidget(
      createTestApp(
        repository: repo,
        overrides: [
          currentUserProvider.overrideWith(() => _CustomUserNotifier(supervisorKitchie)),
        ],
        child: const NotificationsView(),
      ),
    );

    await tester.pumpAndSettle();

    // Switch to Broadcasts & Notices tab (tab index 1)
    final broadcastTab = find.textContaining('Broadcasts & Notices');
    expect(broadcastTab, findsOneWidget);
    await tester.tap(broadcastTab);
    await tester.pumpAndSettle();

    // Verify In-Page composer Target Audience selector defaults to sector team
    expect(find.text('My Assigned Team (Sector Workers)'), findsWidgets);

    // Switch to 'Specific Worker in My Team'
    final audienceDropdown = find.text('My Assigned Team (Sector Workers)').first;
    await tester.tap(audienceDropdown);
    await tester.pumpAndSettle();

    final specificOption = find.text('Specific Worker in My Team').last;
    await tester.tap(specificOption);
    await tester.pumpAndSettle();

    // Verify recipient picker is displayed
    expect(find.text('Select Recipient *'), findsOneWidget);

    // Verify Ramon Garcia (worker in supervisor area-1) is present
    expect(find.textContaining('Ramon Garcia'), findsWidgets);

    // CRITICAL VERIFICATION: Supervisor herself ('Kitchie Nadal') must NEVER appear in recipient dropdown
    expect(find.textContaining('Kitchie Nadal'), findsNothing);

    // CRITICAL VERIFICATION: Worker from other area ('Maria Lopez' in area-2) must NEVER appear
    expect(find.textContaining('Maria Lopez'), findsNothing);
  });

  testWidgets('NotificationsView: supervisor can settle alert locally and escalate to admin', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final supervisorKitchie = UserModel(
      userId: 'user-sup-kitchie',
      username: 'knadal',
      firstName: 'Kitchie',
      lastName: 'Nadal',
      role: UserRole.supervisor,
      assignedAreaId: 'area-1',
      assignedAreaName: 'Ormoc City Hall Zone',
      contactNumber: '+63 918 123 4567',
      status: 'active',
    );

    final breachAlert = AlertModel(
      alertId: 'alert-test-breach',
      userId: 'user-w1',
      workerName: 'Ramon Garcia',
      workerEmpId: 'TOKEN_W1',
      workerContact: '+63 920 111 2222',
      creditScore: 92,
      workareaId: 'area-1',
      workareaName: 'Ormoc City Hall Zone',
      supervisorId: 'user-sup-kitchie',
      supervisorName: 'Kitchie Nadal',
      type: 'Geofence Breach',
      title: 'Geofence Boundary Breach',
      description: 'Worker Ramon Garcia moved outside Ormoc City Hall Zone boundary.',
      timeAgo: 'Just now',
      createdAt: DateTime.now(),
      isResolved: false,
    );

    final repo = MockRepository(
      initialUsers: [supervisorKitchie, worker1],
      initialWorkAreas: [area1],
      initialAlerts: [breachAlert],
    );

    await tester.pumpWidget(
      createTestApp(
        repository: repo,
        overrides: [
          currentUserProvider.overrideWith(() => _CustomUserNotifier(supervisorKitchie)),
        ],
        child: const NotificationsView(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify alert card is visible
    expect(find.text('Geofence Boundary Breach'), findsWidgets);

    // Tap 'Respond' button on the alert card
    final respondBtn = find.text('Respond');
    expect(respondBtn, findsOneWidget);
    await tester.tap(respondBtn);
    await tester.pumpAndSettle();

    // Verify Alert Inspection Modal is displayed with supervisor operational actions
    expect(find.text('AFFECTED FIELD WORKER DETAILS'), findsOneWidget);
    expect(find.text('Settle Locally (On-Site)'), findsOneWidget);
    expect(find.text('Direct Worker to Post'), findsOneWidget);
    expect(find.text('Escalate to Admin'), findsOneWidget);

    // Tap 'Settle Locally (On-Site)'
    final settleBtn = find.text('Settle Locally (On-Site)');
    await tester.tap(settleBtn);
    await tester.pumpAndSettle();

    // Verify alert is marked resolved in repository
    final updatedAlerts = await repo.getAlerts();
    expect(updatedAlerts.first.isResolved, isTrue);
    expect(updatedAlerts.first.responseAction, equals('settled_locally'));
  });

  testWidgets('WorkAreasView: admin can dynamically unassign a supervisor from an area via card action button', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final adminUser = UserModel(
      userId: 'admin-mark-1',
      username: 'markkevincanonoy99@gmail.com',
      firstName: 'Mark Kevin',
      lastName: 'Canonoy',
      role: UserRole.admin,
      contactNumber: '+63 917 555 0199',
      status: 'active',
    );

    final repo = MockRepository(
      initialUsers: [adminUser, supervisorUser, worker1],
      initialWorkAreas: [area1],
    );

    await tester.pumpWidget(
      createTestApp(
        repository: repo,
        overrides: [
          currentUserProvider.overrideWith(() => _CustomUserNotifier(adminUser)),
        ],
        child: const WorkAreasView(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Juan Santos is shown as assigned supervisor on the card
    expect(find.text('Juan Santos'), findsOneWidget);

    // Verify direct 'Unassign' button is visible next to supervisor name
    final unassignBtn = find.text('Unassign');
    expect(unassignBtn, findsOneWidget);

    // Tap 'Unassign' button
    await tester.tap(unassignBtn);
    await tester.pumpAndSettle();

    // Verify confirmation modal opens
    expect(find.text('Unassign Supervisor'), findsOneWidget);
    expect(find.textContaining('Are you sure you want to unassign Juan Santos'), findsOneWidget);

    // Confirm unassignment in dialog
    final confirmUnassign = find.widgetWithText(AppButton, 'Unassign');
    await tester.tap(confirmUnassign);
    await tester.pumpAndSettle();

    // Verify work area in repository now has supervisorId = null and 'No supervisor'
    final areasInRepo = await repo.getWorkAreas();
    expect(areasInRepo.first.supervisorId, isNull);
    expect(areasInRepo.first.supervisorName, equals('No supervisor'));

    // Verify supervisor user in repository now has assignedAreaId = null
    final usersInRepo = await repo.getUsers();
    final supInRepo = usersInRepo.firstWhere((u) => u.userId == supervisorUser.userId);
    expect(supInRepo.assignedAreaId, isNull);

    // Verify UI card now displays 'No supervisor assigned'
    expect(find.text('No supervisor assigned'), findsOneWidget);
    expect(find.text('Juan Santos'), findsNothing);
  });

  testWidgets('WorkAreasView: editing area and selecting No supervisor (Unassigned) clears supervisor', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final adminUser = UserModel(
      userId: 'admin-mark-1',
      username: 'markkevincanonoy99@gmail.com',
      firstName: 'Mark Kevin',
      lastName: 'Canonoy',
      role: UserRole.admin,
      contactNumber: '+63 917 555 0199',
      status: 'active',
    );

    final repo = MockRepository(
      initialUsers: [adminUser, supervisorUser, worker1],
      initialWorkAreas: [area1],
    );

    await tester.pumpWidget(
      createTestApp(
        repository: repo,
        overrides: [
          currentUserProvider.overrideWith(() => _CustomUserNotifier(adminUser)),
        ],
        child: const WorkAreasView(),
      ),
    );

    await tester.pumpAndSettle();

    // Tap 'Edit' button on area card
    final editBtn = find.text('Edit');
    expect(editBtn, findsOneWidget);
    await tester.tap(editBtn);
    await tester.pumpAndSettle();

    // Verify Edit Area dialog opens
    expect(find.textContaining('Edit Work Area'), findsOneWidget);

    // Tap Assigned Supervisor dropdown (currently showing Juan Santos)
    final supDropdown = find.textContaining('Juan Santos').last;
    await tester.tap(supDropdown);
    await tester.pumpAndSettle();

    // Select 'No supervisor (Unassigned)'
    final unassignedOption = find.text('No supervisor (Unassigned)').last;
    await tester.tap(unassignedOption);
    await tester.pumpAndSettle();

    // Save changes
    final saveBtn = find.text('Save Changes');
    await tester.tap(saveBtn);
    await tester.pumpAndSettle();

    // Verify repository is updated dynamically
    final areasInRepo = await repo.getWorkAreas();
    expect(areasInRepo.first.supervisorId, isNull);
    expect(areasInRepo.first.supervisorName, equals('No supervisor'));

    // Verify UI reflects unassigned state
    expect(find.text('No supervisor assigned'), findsOneWidget);
  });

  testWidgets('EmployeesView: admin can dynamically assign and unassign a supervisor from an area', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final adminUser = UserModel(
      userId: 'admin-mark-1',
      username: 'markkevincanonoy99@gmail.com',
      firstName: 'Mark Kevin',
      lastName: 'Canonoy',
      role: UserRole.admin,
      contactNumber: '+63 917 555 0199',
      status: 'active',
    );

    final repo = MockRepository(
      initialUsers: [adminUser, supervisorUser, worker1],
      initialWorkAreas: [area1],
    );

    await tester.pumpWidget(
      createTestApp(
        repository: repo,
        overrides: [
          currentUserProvider.overrideWith(() => _CustomUserNotifier(adminUser)),
        ],
        child: const EmployeesView(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Juan Santos has assigned area in the table
    expect(find.text('Juan Santos'), findsOneWidget);
    expect(find.text('Ormoc City Hall Zone'), findsWidgets);

    // Find the 'Reassign / Unassign Area' button tooltip for Juan Santos
    final assignBtn = find.byTooltip('Reassign / Unassign Area').first;
    expect(assignBtn, findsOneWidget);
    await tester.tap(assignBtn);
    await tester.pumpAndSettle();

    // Verify modal opens
    expect(find.text('Assign Supervisor Sector'), findsOneWidget);

    // Open dropdown and select 'Unassigned (No designated sector)'
    final areaDropdown = find.textContaining('Ormoc City Hall Zone').last;
    await tester.tap(areaDropdown);
    await tester.pumpAndSettle();

    final unassignOption = find.text('Unassigned (No designated sector)').last;
    await tester.tap(unassignOption);
    await tester.pumpAndSettle();

    // Tap 'Unassign Sector' button
    final unassignActionBtn = find.widgetWithText(AppButton, 'Unassign Sector');
    await tester.tap(unassignActionBtn);
    await tester.pumpAndSettle();

    // Verify area in repo has cleared supervisor
    final areasInRepo = await repo.getWorkAreas();
    expect(areasInRepo.first.supervisorId, isNull);
    expect(areasInRepo.first.supervisorName, equals('No supervisor'));
  });

  testWidgets('AttendanceView: unassigned supervisor does not leak workers or work areas', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final unassignedSupervisor = UserModel(
      userId: 'user-sup-unassigned',
      username: 'kitchienadal',
      firstName: 'Kitchie',
      lastName: 'Nadal',
      role: UserRole.supervisor,
      assignedAreaId: null,
      assignedAreaName: 'Unassigned',
      contactNumber: '+63 912 999 8888',
      status: 'active',
    );

    final unassignedArea = WorkAreaModel(
      workareaId: 'area-1',
      name: 'Ormoc City Hall Zone',
      description: 'City Hall Sector',
      supervisorId: null,
      supervisorName: 'No supervisor',
      assignedCount: 1,
      status: 'Active',
      polygon: [
        const LatLng(11.005, 124.605),
        const LatLng(11.009, 124.605),
        const LatLng(11.009, 124.610),
        const LatLng(11.005, 124.610),
      ],
    );

    final log1 = AttendanceModel(
      attendanceId: 'att-1',
      userId: worker1.userId,
      workerName: worker1.fullName,
      workerEmpId: 'BW-ORMC-001',
      workareaId: 'area-1',
      areaName: 'Ormoc City Hall Zone',
      actionType: 'time-in',
      timestamp: DateTime.now(),
      gpsLat: 11.006,
      gpsLng: 124.606,
      faceMatch: true,
      isSynced: true,
      isVerified: true,
    );

    final repo = MockRepository(
      initialUsers: [unassignedSupervisor, worker1, worker2],
      initialWorkAreas: [unassignedArea, area2],
      initialAttendanceLogs: [log1],
    );

    await tester.pumpWidget(
      createTestApp(
        repository: repo,
        overrides: [
          currentUserProvider.overrideWith(() => _CustomUserNotifier(unassignedSupervisor)),
        ],
        child: const AttendanceView(),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Weekly Attendance Matrix must show the empty state message and NOT leak worker1 or area
    expect(find.text('No work areas currently assigned to your supervisory oversight.'), findsWidgets);

    // 2. The roster entries and worker attendance cards should NOT show Ramon Garcia or Ormoc City Hall Zone
    expect(find.text('Ramon Garcia'), findsNothing);
    expect(find.text('Maria Lopez'), findsNothing);

    // 3. Sector dropdown should show 'No Assigned Sectors'
    expect(find.text('No Assigned Sectors'), findsOneWidget);

    // 4. Punch summary counts should be 0
    expect(find.text('0 active personnel'), findsOneWidget);
    expect(find.text('0 total punches'), findsOneWidget);
  });
}

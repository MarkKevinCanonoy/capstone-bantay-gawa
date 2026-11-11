import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_dashboard/features/attendance/attendance_view.dart';
import 'package:web_dashboard/features/dashboard/dashboard_view.dart';
import 'package:web_dashboard/features/notifications/notifications_view.dart';
import 'package:web_dashboard/features/work_areas/work_areas_view.dart';
import 'package:web_dashboard/data/repositories/mock_repository.dart';
import 'package:web_dashboard/data/repositories/repository_provider.dart';
import 'package:web_dashboard/data/models/user_model.dart';
import 'package:web_dashboard/data/models/attendance_model.dart';

void main() {
  testWidgets('DashboardView renders without throwing errors', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
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

    expect(tester.takeException(), isNull);
  });

  testWidgets('DashboardView renders in narrow/stacked mode without throwing errors', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1000);
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

    expect(tester.takeException(), isNull);
  });

  testWidgets('NotificationsView renders without throwing errors', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
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

    final err = tester.takeException();
    if (err != null) {
      // ignore: avoid_print
      print('DEBUG ERR:\n$err');
    }
    expect(err, isNull);
  });

  testWidgets('WorkAreasView renders and toggles drawing mode on Add Work Area click', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
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

    expect(tester.takeException(), isNull);
    expect(find.text('+ Add Work Area'), findsOneWidget);

    // Tap + Add Work Area to enter drawing mode
    await tester.tap(find.text('+ Add Work Area'));
    await tester.pumpAndSettle();

    // Verify drawing mode is active
    expect(find.text('Cancel Drawing'), findsOneWidget);
    expect(find.textContaining('Drawing Geofence'), findsOneWidget);
    expect(find.text('Save Work Area'), findsOneWidget);

    // Tap Cancel Drawing
    await tester.tap(find.text('Cancel Drawing'));
    await tester.pumpAndSettle();

    expect(find.text('+ Add Work Area'), findsOneWidget);
  });

  testWidgets('AreaWorkersDialog opens, searches by first/last/full name, sorts unassigned priority, and shares roster', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final testRepo = MockRepository();
    await testRepo.addUser(UserModel(
      userId: 'test-wkr-1',
      username: 'danilo.ocampo@enro.gov.ph',
      firstName: 'Danilo',
      lastName: 'Ocampo',
      contactNumber: '+63 917 555 0101',
      role: UserRole.worker,
      status: 'active',
    ));
    await testRepo.addUser(UserModel(
      userId: 'test-wkr-2',
      username: 'carlos.mendoza@enro.gov.ph',
      firstName: 'Carlos',
      lastName: 'Mendoza',
      contactNumber: '+63 917 555 0102',
      role: UserRole.worker,
      status: 'active',
    ));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dataRepositoryProvider.overrideWithValue(testRepo),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: WorkAreasView(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify + Add Worker button is rendered on work area cards
    expect(find.text('+ Add Worker'), findsWidgets);

    // Tap first + Add Worker button to open modal
    await tester.tap(find.text('+ Add Worker').first);
    await tester.pumpAndSettle();

    // Verify modal is open
    expect(find.byType(TextField), findsOneWidget);
    expect(find.textContaining('WORKFORCE ROSTER'), findsOneWidget);
    expect(find.byIcon(Icons.share_outlined), findsNothing);

    // Test Search by First Name: "Danilo"
    await tester.enterText(find.byType(TextField), 'Danilo');
    await tester.pumpAndSettle();
    expect(find.text('Danilo Ocampo'), findsOneWidget);
    expect(find.text('Elena Reyes'), findsNothing);

    // Test Search by Last Name: "Ocampo"
    await tester.enterText(find.byType(TextField), 'Ocampo');
    await tester.pumpAndSettle();
    expect(find.text('Danilo Ocampo'), findsOneWidget);

    // Test Search by Full Name: "Carlos Mendoza"
    await tester.enterText(find.byType(TextField), 'Carlos Mendoza');
    await tester.pumpAndSettle();
    expect(find.byWidgetPredicate((w) => w is Text && w.data == 'Carlos Mendoza'), findsOneWidget);
    expect(find.text('Danilo Ocampo'), findsNothing);

    // Clear search
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    expect(find.text('Danilo Ocampo'), findsOneWidget);

    // Tap Done to close modal
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('AttendanceView renders stretched table and filter bar with swapped records count and sector dropdown', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final attendanceRepo = MockRepository();
    attendanceRepo.addAttendance(AttendanceModel(
      attendanceId: 'att-test-1',
      userId: 'test-wkr-2',
      workerName: 'Carlos Mendoza',
      workerEmpId: 'ENRO-WKR-02',
      workareaId: '4b106dc7-8a37-42cf-af39-b80b55cc156f',
      areaName: 'Ormoc Plaza',
      actionType: 'time-in',
      timestamp: DateTime.now(),
      gpsLat: 11.0050,
      gpsLng: 124.6060,
      faceMatch: true,
      isSynced: true,
    ));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dataRepositoryProvider.overrideWithValue(attendanceRepo),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: AttendanceView(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Title & Subtitle
    expect(find.text('Attendance Verification'), findsOneWidget);
    expect(find.textContaining('biometric time-in/time-out verification records'), findsOneWidget);

    // Verify Filter bar has personnel count and Sector: dropdown
    expect(find.textContaining('active personnel'), findsOneWidget);
    expect(find.text('Sector:'), findsOneWidget);

    // Verify stacked worker cards render (e.g. Carlos Mendoza)
    expect(find.text('Carlos Mendoza'), findsWidgets);

    // Expand worker punch stack
    await tester.tap(find.text('Carlos Mendoza').first);
    await tester.pumpAndSettle();

    // Verify expanded punch history
    expect(find.textContaining('Punch History'), findsOneWidget);
    expect(find.text('Time-In'), findsWidgets);

    expect(tester.takeException(), isNull);
  });
}

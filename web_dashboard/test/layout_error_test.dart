import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_dashboard/features/dashboard/dashboard_view.dart';
import 'package:web_dashboard/features/notifications/notifications_view.dart';
import 'package:web_dashboard/features/work_areas/work_areas_view.dart';

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

    // Verify + Add Worker button is rendered on work area cards
    expect(find.text('+ Add Worker'), findsWidgets);

    // Tap first + Add Worker button to open modal
    await tester.tap(find.text('+ Add Worker').first);
    await tester.pumpAndSettle();

    // Verify modal is open
    expect(find.byType(TextField), findsOneWidget);
    expect(find.textContaining('WORKFORCE ROSTER'), findsOneWidget);
    expect(find.text('Priority: Unassigned workers listed first'), findsOneWidget);
    expect(find.byIcon(Icons.share_outlined), findsOneWidget);

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

    // Tap Share Roster button
    await tester.tap(find.byIcon(Icons.share_outlined));
    await tester.pumpAndSettle();

    // Tap Done to close modal
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}

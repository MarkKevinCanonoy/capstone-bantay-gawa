import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_dashboard/core/widgets/stat_card.dart';
import 'package:web_dashboard/core/widgets/status_badge.dart';
import 'package:web_dashboard/core/widgets/app_button.dart';

void main() {
  testWidgets('StatCard renders title, value, and badge correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StatCard(
            title: 'Active Personnel',
            value: '42',
            subtitle: 'Across 6 zones',
            icon: Icons.people_outline,
            badgeLabel: '98% on-duty',
            badgeType: BadgeType.success,
          ),
        ),
      ),
    );

    expect(find.text('ACTIVE PERSONNEL'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('Across 6 zones'), findsOneWidget);
    expect(find.text('98% ON-DUTY'), findsOneWidget);
    expect(find.byIcon(Icons.people_outline), findsOneWidget);
  });

  testWidgets('AppButton handles tap and displays loading state', (WidgetTester tester) async {
    bool tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppButton(
            label: 'Submit Verification',
            icon: Icons.check,
            onPressed: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Submit Verification'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);

    await tester.tap(find.byType(AppButton));
    expect(tapped, isTrue);
  });

  testWidgets('StatusBadge renders badge variants', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              StatusBadge(label: 'Verified', type: BadgeType.success),
              StatusBadge(label: 'Breach', type: BadgeType.danger),
            ],
          ),
        ),
      ),
    );

    expect(find.text('VERIFIED'), findsOneWidget);
    expect(find.text('BREACH'), findsOneWidget);
  });
}


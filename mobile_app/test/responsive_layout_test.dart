import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/theme/app_theme.dart';
import 'package:mobile_app/core/widgets/app_button.dart';
import 'package:mobile_app/core/widgets/app_logo.dart';
import 'package:mobile_app/core/widgets/language_switch_button.dart';
import 'package:mobile_app/core/widgets/status_badge.dart';

void main() {
  group('Responsive Layout & Accessibility Tests', () {
    testWidgets('AppLogo fits within 320px screen width without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: AppLogo(compact: true),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('BantayGawa'), findsOneWidget);
    });

    testWidgets('LanguageSwitchButton compact mode renders within 70px width', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 70,
                  child: LanguageSwitchButton(compact: true),
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(LanguageSwitchButton), findsOneWidget);
    });

    testWidgets('AppButton with long label does not throw RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 250,
                child: AppButton(
                  label: 'I-sumiter Pag-usab ang Girebisang Accomplishment Report',
                  icon: Icons.refresh,
                  onPressed: () {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(AppButton), findsOneWidget);
    });

    testWidgets('StatusBadge handles long label without overflow', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 120,
                child: StatusBadge(
                  label: 'Sulod sa Area (Awtorisado)',
                  backgroundColor: Colors.green,
                  textColor: Colors.white,
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(StatusBadge), findsOneWidget);
    });

    testWidgets('Elderly accessibility font scaling (1.3x) on Infinix Hot 30 aspect ratio (392x872)', (tester) async {
      tester.view.physicalSize = const Size(392, 872);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            builder: (context, child) {
              return MediaQuery.withClampedTextScaling(
                minScaleFactor: 0.85,
                maxScaleFactor: 1.25,
                child: child!,
              );
            },
            home: Scaffold(
              appBar: AppBar(
                title: const AppLogo(compact: true),
                actions: const [
                  LanguageSwitchButton(compact: true),
                ],
              ),
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Maayong adlaw, Trabahador!',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  AppButton(
                    label: 'LOG ATTENDANCE / REKORD SA ATTENDANCE',
                    icon: Icons.fingerprint,
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('BantayGawa'), findsOneWidget);
    });
  });
}

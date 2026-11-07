import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/localization/app_translations.dart';
import 'package:mobile_app/core/localization/locale_provider.dart';
import 'package:mobile_app/core/widgets/app_logo.dart';
import 'package:mobile_app/core/widgets/language_switch_button.dart';
import 'package:mobile_app/features/profile/profile_view.dart';

void main() {
  group('UI Components & Language Toggle Tests', () {
    testWidgets('AppLogo renders brand shield and text properly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppLogo(compact: true),
          ),
        ),
      );

      expect(find.byType(Image), findsOneWidget);
      final image = tester.widget<Image>(find.byType(Image));
      expect((image.image as AssetImage).assetName, equals('assets/images/logo.png'));
      expect(find.text('BantayGawa'), findsOneWidget);
      expect(find.text('ENRO Ormoc City'), findsOneWidget);
    });

    testWidgets('LanguageSwitchButton displays CEB and ENG segments and toggles state', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: LanguageSwitchButton(),
            ),
          ),
        ),
      );

      // Verify both labels are visible
      expect(find.text('CEB'), findsOneWidget);
      expect(find.text('ENG'), findsOneWidget);

      // Initial state is Cebuano
      final container = ProviderScope.containerOf(tester.element(find.byType(LanguageSwitchButton)));
      expect(container.read(localeProvider), equals(AppLanguage.cebuano));

      // Tap to toggle
      await tester.tap(find.byType(LanguageSwitchButton));
      await tester.pumpAndSettle();

      // Verified toggled to English
      expect(container.read(localeProvider), equals(AppLanguage.english));

      // Tap again to toggle back to Cebuano
      await tester.tap(find.byType(LanguageSwitchButton));
      await tester.pumpAndSettle();

      expect(container.read(localeProvider), equals(AppLanguage.cebuano));
    });

    testWidgets('ProfileView renders without crashing', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ProfileView(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(ProfileView), findsOneWidget);
      expect(find.text('FIELD WORKER'), findsOneWidget);
    });
  });
}

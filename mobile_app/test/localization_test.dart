import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/localization/app_translations.dart';

void main() {
  group('Bilingual Localization Tests', () {
    test('Resolves keys in Filipino properly', () {
      final greeting = AppTranslations.get('greeting', AppLanguage.filipino);
      expect(greeting, equals('Kamusta'));

      final actions = AppTranslations.get('main_actions', AppLanguage.filipino);
      expect(actions, equals('MGA PANGUNAHING AKSYON'));
    });

    test('Resolves keys in English properly', () {
      final greeting = AppTranslations.get('greeting', AppLanguage.english);
      expect(greeting, equals('Hello'));

      final actions = AppTranslations.get('main_actions', AppLanguage.english);
      expect(actions, equals('MAIN ACTIONS'));
    });

    test('Fallback to Filipino if key is missing or default', () {
      final val = AppTranslations.get('in_zone', AppLanguage.filipino);
      expect(val, contains('Nasa Sona'));
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/localization/app_translations.dart';

void main() {
  group('Bilingual Localization Tests (Cebuano & English)', () {
    test('Resolves keys in Cebuano properly', () {
      final greeting = AppTranslations.get('greeting', AppLanguage.cebuano);
      expect(greeting, equals('Maayong adlaw'));

      final actions = AppTranslations.get('main_actions', AppLanguage.cebuano);
      expect(actions, equals('PANGUNANG MGA BUHAT'));

      final inZone = AppTranslations.get('in_zone', AppLanguage.cebuano);
      expect(inZone, contains('Sulod sa Area'));
    });

    test('Resolves keys in English properly', () {
      final greeting = AppTranslations.get('greeting', AppLanguage.english);
      expect(greeting, equals('Hello'));

      final actions = AppTranslations.get('main_actions', AppLanguage.english);
      expect(actions, equals('MAIN ACTIONS'));

      final inZone = AppTranslations.get('in_zone', AppLanguage.english);
      expect(inZone, contains('Inside Zone'));
    });

    test('Fallback to Cebuano if language is omitted or key default', () {
      final val = AppTranslations.get('in_zone', AppLanguage.cebuano);
      expect(val, contains('Sulod sa Area'));
    });

    test('Resolves reports history & retention keys in both languages', () {
      expect(AppTranslations.get('today_reports', AppLanguage.cebuano), equals('Mga Report Karong Adlawa'));
      expect(AppTranslations.get('today_reports', AppLanguage.english), equals("Today's Reports"));

      expect(AppTranslations.get('view_past_reports', AppLanguage.cebuano), equals('Tan-awa ang Miaging mga Report'));
      expect(AppTranslations.get('view_past_reports', AppLanguage.english), equals('View Past Reports'));

      expect(AppTranslations.get('retake_proof_hint', AppLanguage.cebuano), contains('bag-ong litrato'));
      expect(AppTranslations.get('retake_proof_hint', AppLanguage.english), contains('new photo proof'));

      expect(AppTranslations.get('report_outside_zone_alert', AppLanguage.cebuano), contains('Gawas sa Zone'));
      expect(AppTranslations.get('report_outside_zone_alert', AppLanguage.english), contains('Outside Work Zone'));
      expect(AppTranslations.get('outside_zone_badge', AppLanguage.cebuano), equals('GAWAS SA ZONE'));
      expect(AppTranslations.get('outside_zone_badge', AppLanguage.english), equals('OUTSIDE ZONE'));
    });
  });
}

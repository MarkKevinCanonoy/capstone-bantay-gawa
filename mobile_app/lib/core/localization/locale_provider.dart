import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'app_translations.dart';

class LocaleNotifier extends Notifier<AppLanguage> {
  static const String _storageKey = 'bantaygawa_user_language';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  @override
  AppLanguage build() {
    _loadPreference();
    return AppLanguage.cebuano; // Default to Cebuano (Bisaya) for Ormoc City field workers
  }

  Future<void> _loadPreference() async {
    final saved = await _storage.read(key: _storageKey);
    if (saved == 'english') {
      state = AppLanguage.english;
    } else {
      state = AppLanguage.cebuano;
    }
  }

  Future<void> setLanguage(AppLanguage language) async {
    state = language;
    await _storage.write(
      key: _storageKey,
      value: language == AppLanguage.english ? 'english' : 'cebuano',
    );
  }

  Future<void> toggleLanguage() async {
    final next = state == AppLanguage.cebuano ? AppLanguage.english : AppLanguage.cebuano;
    await setLanguage(next);
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, AppLanguage>(() {
  return LocaleNotifier();
});

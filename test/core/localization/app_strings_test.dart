import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_retaguarda/core/localization/app_strings.dart';

void main() {
  group('AppStrings', () {
    late AppStrings strings;

    setUp(() async {
      strings = AppStrings();
      await strings.initialize();
    });

    test('is singleton', () {
      final strings1 = AppStrings();
      final strings2 = AppStrings();

      expect(identical(strings1, strings2), true);
    });

    test('initializes with default Portuguese', () {
      expect(strings.currentLocale, AppLocale.pt);
    });

    test('gets string by key', () {
      final loginStr = strings.get('login');
      expect(loginStr, 'Entrar');
    });

    test('returns key if not found', () {
      final unknown = strings.get('unknown_key');
      expect(unknown, 'unknown_key');
    });

    test('switches to English', () async {
      await strings.setLocale(AppLocale.en);

      expect(strings.currentLocale, AppLocale.en);
      expect(strings.get('login'), 'Sign In');
    });

    test('switches to Spanish', () async {
      await strings.setLocale(AppLocale.es);

      expect(strings.currentLocale, AppLocale.es);
      expect(strings.get('login'), 'Iniciar sesión');
    });

    test('different locales have different strings', () async {
      final ptLogin = strings.get('login');

      await strings.setLocale(AppLocale.en);
      final enLogin = strings.get('login');

      expect(ptLogin, isNot(enLogin));
    });

    test('returns all available locales', () {
      final locales = strings.availableLocales;

      expect(locales, contains(AppLocale.pt));
      expect(locales, contains(AppLocale.en));
      expect(locales, contains(AppLocale.es));
    });

    test('calls callback on locale change', () async {
      var callCount = 0;
      var lastLocale = AppLocale.pt;

      strings.setOnLocaleChanged((locale) {
        callCount++;
        lastLocale = locale;
      });

      await strings.setLocale(AppLocale.en);
      expect(callCount, 1);
      expect(lastLocale, AppLocale.en);

      await strings.setLocale(AppLocale.es);
      expect(callCount, 2);
      expect(lastLocale, AppLocale.es);
    });

    test('handles locale with correct translations', () async {
      await strings.setLocale(AppLocale.pt);
      expect(strings.get('theme'), 'Tema');

      await strings.setLocale(AppLocale.en);
      expect(strings.get('theme'), 'Theme');

      await strings.setLocale(AppLocale.es);
      expect(strings.get('theme'), 'Tema');
    });

    test('locale contains common keys', () {
      expect(strings.get('app_name'), isNotEmpty);
      expect(strings.get('login'), isNotEmpty);
      expect(strings.get('back'), isNotEmpty);
      expect(strings.get('save'), isNotEmpty);
    });
  });
}

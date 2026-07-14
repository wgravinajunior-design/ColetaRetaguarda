import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_retaguarda/core/theme/app_theme.dart';

void main() {
  group('AppTheme', () {
    late AppTheme theme;

    setUp(() {
      theme = AppTheme();
    });

    test('is singleton', () {
      final theme1 = AppTheme();
      final theme2 = AppTheme();

      expect(identical(theme1, theme2), true);
    });

    test('starts with light mode', () {
      expect(theme.isDarkMode, false);
    });

    test('toggles dark mode', () async {
      expect(theme.isDarkMode, false);

      await theme.toggleTheme();
      expect(theme.isDarkMode, true);

      await theme.toggleTheme();
      expect(theme.isDarkMode, false);
    });

    test('sets dark mode', () async {
      await theme.setDarkMode(true);
      expect(theme.isDarkMode, true);

      await theme.setDarkMode(false);
      expect(theme.isDarkMode, false);
    });

    test('light theme has correct colors', () {
      final lightTheme = AppTheme.getLightTheme();

      expect(lightTheme.brightness, Brightness.light);
      expect(lightTheme.useMaterial3, true);
      expect(lightTheme.appBarTheme.backgroundColor, isNotNull);
    });

    test('dark theme has correct colors', () {
      final darkTheme = AppTheme.getDarkTheme();

      expect(darkTheme.brightness, Brightness.dark);
      expect(darkTheme.useMaterial3, true);
      expect(darkTheme.appBarTheme.backgroundColor, isNotNull);
    });

    test('calls callback on theme change', () async {
      var callCount = 0;
      theme.setOnThemeChanged((_) => callCount++);

      await theme.toggleTheme();
      expect(callCount, 1);

      await theme.toggleTheme();
      expect(callCount, 2);
    });

    test('themes differ', () {
      final lightTheme = AppTheme.getLightTheme();
      final darkTheme = AppTheme.getDarkTheme();

      expect(lightTheme.brightness, isNot(darkTheme.brightness));
      expect(
        lightTheme.scaffoldBackgroundColor,
        isNot(darkTheme.scaffoldBackgroundColor),
      );
    });
  });
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gerencia tema claro/escuro da aplicação
class AppTheme {
  static final AppTheme _instance = AppTheme._internal();

  factory AppTheme() {
    return _instance;
  }

  AppTheme._internal();

  static const String _themeModeKey = 'theme_mode';

  bool _isDarkMode = false;
  Function(bool)? _onThemeChanged;

  bool get isDarkMode => _isDarkMode;

  /// Registra callback para mudanças de tema
  void setOnThemeChanged(Function(bool) callback) {
    _onThemeChanged = callback;
  }

  /// Carrega preferência de tema do armazenamento
  Future<void> loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDarkMode = prefs.getBool(_themeModeKey) ?? false;
    } catch (e) {
      _isDarkMode = false;
    }
  }

  /// Alterna tema
  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    await _saveThemePreference();
    _onThemeChanged?.call(_isDarkMode);
  }

  /// Define modo escuro
  Future<void> setDarkMode(bool dark) async {
    if (_isDarkMode == dark) return;
    _isDarkMode = dark;
    await _saveThemePreference();
    _onThemeChanged?.call(_isDarkMode);
  }

  /// Salva preferência
  Future<void> _saveThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_themeModeKey, _isDarkMode);
    } catch (e) {
      debugPrint('Erro ao salvar tema: $e');
    }
  }

  /// Retorna tema claro
  static ThemeData getLightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2E7D32), // Verde
        brightness: Brightness.light,
      ),
      appBarTheme: AppBarTheme(
        elevation: 2,
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  /// Retorna tema escuro
  static ThemeData getDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF81C784), // Verde claro
        brightness: Brightness.dark,
      ),
      appBarTheme: AppBarTheme(
        elevation: 2,
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: const Color(0xFF81C784),
        foregroundColor: Colors.black87,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: const Color(0xFF212121),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        filled: true,
        fillColor: const Color(0xFF2C2C2C),
      ),
      scaffoldBackgroundColor: const Color(0xFF121212),
    );
  }
}

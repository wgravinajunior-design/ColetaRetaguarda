import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Implementa rate limiting para proteger contra força bruta no login
class RateLimiter {
  static final RateLimiter _instance = RateLimiter._internal();

  factory RateLimiter() {
    return _instance;
  }

  RateLimiter._internal();

  // Configurações de rate limiting
  static const int maxAttempts = 5;
  static const Duration lockoutDuration = Duration(minutes: 15);
  static const Duration attemptWindow = Duration(minutes: 15);

  final Map<String, List<DateTime>> _attemptHistory = {};
  final Map<String, DateTime> _lockoutUntil = {};

  /// Verifica se um usuário pode tentar fazer login
  /// Retorna uma mensagem de erro se bloqueado, null se permitido
  Future<String?> canAttemptLogin(String username) async {
    final now = DateTime.now();
    final lockoutKey = 'lockout_$username';
    final attemptsKey = 'attempts_$username';

    final prefs = await SharedPreferences.getInstance();

    // Verifica se está bloqueado
    final lockoutStr = prefs.getString(lockoutKey);
    if (lockoutStr != null) {
      final lockedUntil = DateTime.parse(lockoutStr);
      if (now.isBefore(lockedUntil)) {
        final remainingMinutes = lockedUntil.difference(now).inMinutes;
        return 'Conta bloqueada por $remainingMinutes minutos. Tente novamente mais tarde.';
      } else {
        // Desbloqueou, limpar
        await prefs.remove(lockoutKey);
        await prefs.remove(attemptsKey);
      }
    }

    // Limpa tentativas antigas
    final attemptsStr = prefs.getString(attemptsKey);
    if (attemptsStr != null) {
      try {
        final attempts = attemptsStr.split(',').map(DateTime.parse).toList();
        final recentAttempts = attempts
            .where((t) => now.difference(t).compareTo(attemptWindow) < 0)
            .toList();

        if (recentAttempts.length >= maxAttempts) {
          // Bloquear por lockoutDuration
          final blockUntil = now.add(lockoutDuration);
          await prefs.setString(lockoutKey, blockUntil.toIso8601String());
          return 'Máximo de tentativas excedido. Conta bloqueada por 15 minutos.';
        }
      } catch (e) {
        debugPrint('Erro ao processar histórico de tentativas: $e');
      }
    }

    return null; // Permitido
  }

  /// Registra uma tentativa de login falhada
  Future<void> recordFailedAttempt(String username) async {
    final prefs = await SharedPreferences.getInstance();
    final attemptsKey = 'attempts_$username';
    final now = DateTime.now();

    final attemptsStr = prefs.getString(attemptsKey) ?? '';
    final attempts = attemptsStr.isEmpty
        ? <String>[]
        : attemptsStr.split(',').map((s) {
            try {
              return DateTime.parse(s).toIso8601String();
            } catch (e) {
              return null;
            }
          }).whereType<String>().toList();

    attempts.add(now.toIso8601String());
    await prefs.setString(attemptsKey, attempts.join(','));

    debugPrint(
      '[RateLimit] Failed login attempt for $username (${attempts.length}/$maxAttempts)',
    );
  }

  /// Limpa histórico de tentativas após login bem-sucedido
  Future<void> clearLoginAttempts(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('attempts_$username');
    await prefs.remove('lockout_$username');
    debugPrint('[RateLimit] Cleared login attempts for $username');
  }

  /// Reseta limiter (para testes)
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _attemptHistory.clear();
    _lockoutUntil.clear();
  }
}

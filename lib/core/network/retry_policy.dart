import 'dart:math' as math;
import '../logging/app_logger.dart';

/// Política de retry com backoff exponencial
class RetryPolicy {
  final int maxAttempts;
  final Duration initialDelay;
  final double backoffMultiplier;
  final Duration maxDelay;

  const RetryPolicy({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(seconds: 1),
    this.backoffMultiplier = 2.0,
    this.maxDelay = const Duration(seconds: 30),
  });

  /// Calcula o delay para a tentativa especificada
  Duration _getDelay(int attempt) {
    final multiplier = math.pow(backoffMultiplier, (attempt - 1).toDouble());
    final delay = initialDelay * multiplier;
    return delay > maxDelay ? maxDelay : delay;
  }

  /// Executa uma função com retry automático
  Future<T> execute<T>(
    Future<T> Function() operation,
    String operationName, {
    bool Function(Object)? isRetryable,
  }) async {
    final AppLogger logger = AppLogger();
    int attempt = 0;

    while (attempt < maxAttempts) {
      attempt++;
      try {
        logger.debug('RetryPolicy', 'Tentativa $attempt de $maxAttempts: $operationName');
        return await operation();
      } catch (e) {
        final isRetryableError = isRetryable?.call(e) ?? _defaultIsRetryable(e);

        if (!isRetryableError || attempt >= maxAttempts) {
          logger.error('RetryPolicy', 'Falha final após $attempt tentativas: $operationName');
          rethrow;
        }

        final delay = _getDelay(attempt);
        logger.warning(
          'RetryPolicy',
          'Tentativa $attempt falhou. Aguardando ${delay.inSeconds}s antes de retry...',
        );

        await Future.delayed(delay);
      }
    }

    throw Exception('Todas as tentativas falharam para: $operationName');
  }

  /// Determina se um erro é recuperável
  bool _defaultIsRetryable(Object error) {
    final errorMessage = error.toString().toLowerCase();

    // Erros que são retriáveis
    if (errorMessage.contains('socket') || errorMessage.contains('connection') ||
        errorMessage.contains('timeout') || errorMessage.contains('network')) {
      return true;
    }

    // Erros HTTP 5xx são retriáveis (erro do servidor)
    if (errorMessage.contains('500') || errorMessage.contains('502') ||
        errorMessage.contains('503') || errorMessage.contains('504')) {
      return true;
    }

    return false;
  }
}

/// Classe helper para retries
class RetryHelper {
  static final RetryHelper _instance = RetryHelper._internal();

  factory RetryHelper() {
    return _instance;
  }

  RetryHelper._internal();

  final RetryPolicy _defaultPolicy = const RetryPolicy();

  /// Executa uma operação com retry usando a política padrão
  Future<T> retryWithDefault<T>(
    Future<T> Function() operation,
    String operationName,
  ) {
    return _defaultPolicy.execute(operation, operationName);
  }

  /// Executa uma operação com retry usando uma política customizada
  Future<T> retryWithPolicy<T>(
    Future<T> Function() operation,
    String operationName,
    RetryPolicy policy,
  ) {
    return policy.execute(operation, operationName);
  }
}

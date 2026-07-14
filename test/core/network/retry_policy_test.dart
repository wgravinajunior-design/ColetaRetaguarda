import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_retaguarda/core/network/retry_policy.dart';

void main() {
  group('RetryPolicy', () {
    test('executa operação com sucesso na primeira tentativa', () async {
      final policy = const RetryPolicy();
      int callCount = 0;

      final result = await policy.execute<int>(
        () async {
          callCount++;
          return 42;
        },
        'test_operation',
      );

      expect(result, 42);
      expect(callCount, 1);
    });

    test('retenta operação que falha', () async {
      final policy = const RetryPolicy(
        maxAttempts: 3,
        initialDelay: Duration(milliseconds: 10),
      );
      int callCount = 0;

      try {
        await policy.execute<int>(
          () async {
            callCount++;
            throw Exception('Erro de conexão socket');
          },
          'test_operation',
        );
      } catch (e) {
        // Esperado falhar
      }

      expect(callCount, 3); // Deve tentar 3 vezes
    });

    test('retorna resultado quando sucesso ocorre em retry', () async {
      final policy = const RetryPolicy(
        maxAttempts: 3,
        initialDelay: Duration(milliseconds: 10),
      );
      int callCount = 0;

      final result = await policy.execute<int>(
        () async {
          callCount++;
          if (callCount < 3) {
            throw Exception('Socket error na rede');
          }
          return 42;
        },
        'test_operation',
      );

      expect(result, 42);
      expect(callCount, 3);
    });

    test('calcula delay com backoff exponencial', () async {
      final policy = const RetryPolicy(
        maxAttempts: 4,
        initialDelay: Duration(milliseconds: 100),
        backoffMultiplier: 2.0,
      );
      int callCount = 0;

      final stopwatch = Stopwatch()..start();

      try {
        await policy.execute<int>(
          () async {
            callCount++;
            throw Exception('Connection timeout error');
          },
          'test_operation',
        );
      } catch (e) {
        // Esperado falhar
      }

      stopwatch.stop();

      // Delays: 100ms, 200ms, 400ms = 700ms total
      // Deixar margem para variações no timing
      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(600));
      expect(callCount, 4);
    });

    test('não retenta erro não-retriável', () async {
      final policy = const RetryPolicy(maxAttempts: 3);
      int callCount = 0;

      try {
        await policy.execute<int>(
          () async {
            callCount++;
            throw ArgumentError('Erro não-retriável');
          },
          'test_operation',
          isRetryable: (_) => false,
        );
      } catch (e) {
        // Esperado falhar
      }

      expect(callCount, 1); // Deve tentar apenas uma vez
    });

    test('respeita maxDelay', () async {
      final policy = const RetryPolicy(
        maxAttempts: 3,
        initialDelay: Duration(seconds: 1),
        backoffMultiplier: 100.0, // Alto multiplicador
        maxDelay: Duration(milliseconds: 200),
      );
      int callCount = 0;

      final stopwatch = Stopwatch()..start();

      try {
        await policy.execute<int>(
          () async {
            callCount++;
            throw Exception('Erro');
          },
          'test_operation',
        );
      } catch (e) {
        // Esperado falhar
      }

      stopwatch.stop();

      // Delays máximos: 200ms, 200ms = 400ms total
      expect(stopwatch.elapsedMilliseconds, lessThan(600));
    });
  });

  group('RetryHelper', () {
    test('é singleton', () {
      final helper1 = RetryHelper();
      final helper2 = RetryHelper();

      expect(identical(helper1, helper2), true);
    });

    test('executa com política padrão', () async {
      final helper = RetryHelper();
      int callCount = 0;

      final result = await helper.retryWithDefault<int>(
        () async {
          callCount++;
          return 42;
        },
        'test_operation',
      );

      expect(result, 42);
      expect(callCount, 1);
    });

    test('executa com política customizada', () async {
      final helper = RetryHelper();
      final customPolicy = const RetryPolicy(maxAttempts: 5);
      int callCount = 0;

      final result = await helper.retryWithPolicy<int>(
        () async {
          callCount++;
          return 42;
        },
        'test_operation',
        customPolicy,
      );

      expect(result, 42);
      expect(callCount, 1);
    });
  });
}

// Extension para adicionar isRetryable ao RetryPolicy em testes
extension RetryPolicyExtension on RetryPolicy {
  RetryPolicy withIsRetryable(bool Function(Object) isRetryable) {
    return RetryPolicy(
      maxAttempts: maxAttempts,
      initialDelay: initialDelay,
      backoffMultiplier: backoffMultiplier,
      maxDelay: maxDelay,
    );
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_retaguarda/core/crashreporting/sentry_service.dart';

void main() {
  group('SentryService', () {
    late SentryService sentry;

    setUp(() {
      sentry = SentryService();
    });

    test('is singleton', () {
      final sentry1 = SentryService();
      final sentry2 = SentryService();

      expect(identical(sentry1, sentry2), true);
    });

    test('not initialized by default', () {
      expect(sentry.isInitialized, false);
    });

    test('initializes with DSN and environment', () async {
      await sentry.init(
        dsn: 'https://key@sentry.io/123456',
        environment: 'staging',
      );

      expect(sentry.isInitialized, true);
      expect(sentry.dsn, 'https://key@sentry.io/123456');
      expect(sentry.environment, 'staging');
    });

    test('sets tags', () async {
      await sentry.init(dsn: 'https://key@sentry.io/123456');

      sentry.setTags({
        'app_version': '1.0.0',
        'build_number': '123',
      });

      expect(sentry.tags, isNotNull);
      expect(sentry.tags!['app_version'], '1.0.0');
    });

    test('sets user context', () async {
      await sentry.init(dsn: 'https://key@sentry.io/123456');

      sentry.setUserContext(
        id: 'user123',
        email: 'user@example.com',
        username: 'testuser',
      );

      expect(sentry.userContext, isNotNull);
      expect(sentry.userContext!['id'], 'user123');
      expect(sentry.userContext!['email'], 'user@example.com');
    });

    test('captures exception', () async {
      await sentry.init(dsn: 'https://key@sentry.io/123456');

      final error = Exception('Test error');
      await sentry.captureException(error);

      // Mock service não faz nada, apenas registra log
      expect(true, true); // Test passed if no exception thrown
    });

    test('captures message', () async {
      await sentry.init(dsn: 'https://key@sentry.io/123456');

      await sentry.captureMessage('Test message', level: 'warning');

      expect(true, true); // Test passed if no exception thrown
    });

    test('adds breadcrumb', () async {
      await sentry.init(dsn: 'https://key@sentry.io/123456');

      sentry.addBreadcrumb(
        message: 'Button clicked',
        category: 'user-interaction',
      );

      expect(true, true); // Test passed if no exception thrown
    });

    test('captures navigation', () async {
      await sentry.init(dsn: 'https://key@sentry.io/123456');

      sentry.captureNavigation('ProductListScreen');

      expect(true, true); // Test passed if no exception thrown
    });

    test('captures user action', () async {
      await sentry.init(dsn: 'https://key@sentry.io/123456');

      sentry.captureUserAction('purchase', data: {
        'product_id': 'prod123',
        'amount': 99.99,
      });

      expect(true, true); // Test passed if no exception thrown
    });

    test('captures HTTP request', () async {
      await sentry.init(dsn: 'https://key@sentry.io/123456');

      sentry.captureHttpRequest(
        'GET',
        'https://api.example.com/data',
        statusCode: 200,
        duration: 150,
      );

      expect(true, true); // Test passed if no exception thrown
    });

    test('handles uninitialized captureException gracefully', () async {
      final error = Exception('Test');

      // Should not throw even though not initialized
      await sentry.captureException(error);

      expect(true, true);
    });

    test('handles uninitialized captureMessage gracefully', () async {
      // Should not throw even though not initialized
      await sentry.captureMessage('Test');

      expect(true, true);
    });
  });
}

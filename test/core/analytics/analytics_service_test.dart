import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_retaguarda/core/analytics/analytics_service.dart';

void main() {
  group('AnalyticsService', () {
    late AnalyticsService analytics;

    setUp(() {
      analytics = AnalyticsService();
      analytics.clearHistory();
      analytics.setEnabled(true);
    });

    test('is singleton', () {
      final analytics1 = AnalyticsService();
      final analytics2 = AnalyticsService();

      expect(identical(analytics1, analytics2), true);
    });

    test('tracks simple event', () {
      analytics.trackEvent('test_event');

      final history = analytics.getHistory();
      expect(history.length, 1);
      expect(history[0].name, 'test_event');
    });

    test('tracks event with parameters', () {
      analytics.trackEvent('purchase', parameters: {'amount': 99.99});

      final history = analytics.getHistory();
      expect(history.length, 1);
      expect(history[0].name, 'purchase');
      expect(history[0].parameters!['amount'], 99.99);
    });

    test('tracks screen view', () {
      analytics.trackScreenView('HomeScreen');

      final history = analytics.getHistory();
      expect(history.length, 1);
      expect(history[0].name, 'screen_view');
      expect(history[0].parameters!['screen_name'], 'HomeScreen');
    });

    test('tracks button click', () {
      analytics.trackButtonClick('Login', screenName: 'LoginScreen');

      final history = analytics.getHistory();
      expect(history.length, 1);
      expect(history[0].name, 'button_click');
      expect(history[0].parameters!['button_name'], 'Login');
    });

    test('tracks form submit', () {
      analytics.trackFormSubmit('LoginForm', fields: {'username': 'test'});

      final history = analytics.getHistory();
      expect(history.length, 1);
      expect(history[0].name, 'form_submit');
      expect(history[0].parameters!['form_name'], 'LoginForm');
    });

    test('tracks error', () {
      analytics.trackError('404', errorMessage: 'Not Found');

      final history = analytics.getHistory();
      expect(history.length, 1);
      expect(history[0].name, 'error');
      expect(history[0].parameters!['error_code'], '404');
    });

    test('tracks search', () {
      analytics.trackSearch('dairy products', resultCount: 42, duration: 150);

      final history = analytics.getHistory();
      expect(history.length, 1);
      expect(history[0].name, 'search');
      expect(history[0].parameters!['search_query'], 'dairy products');
      expect(history[0].parameters!['result_count'], 42);
    });

    test('tracks transaction', () {
      analytics.trackTransaction(
        'TX123',
        amount: 499.99,
        currency: 'BRL',
      );

      final history = analytics.getHistory();
      expect(history.length, 1);
      expect(history[0].name, 'transaction');
      expect(history[0].parameters!['transaction_id'], 'TX123');
      expect(history[0].parameters!['amount'], 499.99);
    });

    test('disables analytics', () {
      analytics.setEnabled(false);
      analytics.trackEvent('test');

      expect(analytics.getHistory(), isEmpty);
    });

    test('calls callback on event', () {
      var callCount = 0;
      analytics.setOnEvent((_) => callCount++);

      analytics.trackEvent('event1');
      expect(callCount, 1);

      analytics.trackEvent('event2');
      expect(callCount, 2);
    });

    test('generates summary', () {
      analytics.trackEvent('screen_view');
      analytics.trackEvent('button_click');
      analytics.trackEvent('screen_view');

      final summary = analytics.generateSummary();

      expect(summary, contains('Analytics Summary'));
      expect(summary, contains('Total events: 3'));
      expect(summary, contains('screen_view'));
      expect(summary, contains('button_click'));
    });

    test('clears history', () {
      analytics.trackEvent('test1');
      analytics.trackEvent('test2');
      expect(analytics.getHistory().length, 2);

      analytics.clearHistory();
      expect(analytics.getHistory(), isEmpty);
    });
  });
}

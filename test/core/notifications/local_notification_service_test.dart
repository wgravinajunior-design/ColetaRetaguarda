import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_retaguarda/core/notifications/local_notification_service.dart';

void main() {
  group('LocalNotificationService', () {
    late LocalNotificationService notificationService;

    setUp(() {
      notificationService = LocalNotificationService();
      notificationService.clearHistory();
    });

    test('is singleton', () {
      final service1 = LocalNotificationService();
      final service2 = LocalNotificationService();

      expect(identical(service1, service2), true);
    });

    test('shows info notification', () {
      notificationService.showInfo('Test', 'This is a test');

      final history = notificationService.getHistory();
      expect(history.length, 1);
      expect(history[0].type, NotificationType.info);
      expect(history[0].title, 'Test');
    });

    test('shows success notification', () {
      notificationService.showSuccess('Success', 'Operation completed');

      final history = notificationService.getHistory();
      expect(history.length, 1);
      expect(history[0].type, NotificationType.success);
    });

    test('shows warning notification', () {
      notificationService.showWarning('Warning', 'Be careful');

      final history = notificationService.getHistory();
      expect(history.length, 1);
      expect(history[0].type, NotificationType.warning);
    });

    test('shows error notification', () {
      notificationService.showError('Error', 'Something went wrong');

      final history = notificationService.getHistory();
      expect(history.length, 1);
      expect(history[0].type, NotificationType.error);
    });

    test('stores notification data', () {
      notificationService.showInfo('Test', 'Message', data: {'key': 'value'});

      final history = notificationService.getHistory();
      expect(history[0].data, isNotNull);
      expect(history[0].data!['key'], 'value');
    });

    test('filters by type', () {
      notificationService.showInfo('Info', 'Message');
      notificationService.showSuccess('Success', 'Message');
      notificationService.showError('Error', 'Message');

      final errors = notificationService.getByType(NotificationType.error);
      expect(errors.length, 1);
      expect(errors[0].type, NotificationType.error);
    });

    test('removes notification', () {
      notificationService.showInfo('Test', 'Message');
      final history = notificationService.getHistory();
      final notifId = history[0].id;

      notificationService.removeNotification(notifId);
      expect(notificationService.getHistory(), isEmpty);
    });

    test('clears history', () {
      notificationService.showInfo('Test', 'Message');
      notificationService.showSuccess('Success', 'Message');

      expect(notificationService.getHistory().length, 2);

      notificationService.clearHistory();
      expect(notificationService.getHistory(), isEmpty);
    });

    test('calls callback on notification', () {
      var callCount = 0;
      notificationService.setOnNotification((_) => callCount++);

      notificationService.showInfo('Test', 'Message');
      expect(callCount, 1);

      notificationService.showSuccess('Success', 'Message');
      expect(callCount, 2);
    });

    test('generates summary', () {
      notificationService.showInfo('Info', 'Message');
      notificationService.showSuccess('Success', 'Message');
      notificationService.showError('Error', 'Message');

      final summary = notificationService.generateSummary();

      expect(summary, contains('Notification Summary'));
      expect(summary, contains('Total notifications: 3'));
      expect(summary, contains('info: 1'));
      expect(summary, contains('success: 1'));
      expect(summary, contains('error: 1'));
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_retaguarda/core/logging/app_logger.dart';

void main() {
  group('AppLogger', () {
    late AppLogger logger;

    setUp(() {
      logger = AppLogger();
      logger.clearHistory();
    });

    test('creates singleton instance', () {
      final logger1 = AppLogger();
      final logger2 = AppLogger();

      expect(identical(logger1, logger2), true);
    });

    test('logs info message', () {
      logger.info('TestTag', 'Test message');

      final history = logger.getHistory();
      expect(history, isNotEmpty);
      expect(history.last.level, LogLevel.info);
      expect(history.last.tag, 'TestTag');
      expect(history.last.message, 'Test message');
    });

    test('logs warning message', () {
      logger.warning('TestTag', 'Warning message');

      final history = logger.getHistory();
      expect(history.last.level, LogLevel.warning);
    });

    test('logs error with exception', () {
      final error = Exception('Test error');
      logger.error('TestTag', 'Error occurred', error);

      final history = logger.getHistory();
      expect(history.last.level, LogLevel.error);
      expect(history.last.error, error);
    });

    test('filters history by log level', () {
      logger.info('Tag1', 'Info message');
      logger.warning('Tag2', 'Warning message');
      logger.error('Tag3', 'Error message');

      final warnings = logger.getHistory(minLevel: LogLevel.warning);

      expect(warnings.length, 2); // Warning + Error
      expect(warnings.every((e) => e.level.index >= LogLevel.warning.index), true);
    });

    test('maintains history size limit', () {
      for (int i = 0; i < 1100; i++) {
        logger.info('Tag$i', 'Message $i');
      }

      final history = logger.getHistory();
      expect(history.length, lessThanOrEqualTo(1000));
    });

    test('clears history', () {
      logger.info('Tag', 'Message');
      expect(logger.getHistory(), isNotEmpty);

      logger.clearHistory();
      expect(logger.getHistory(), isEmpty);
    });

    test('exports logs as string', () {
      logger.info('Tag1', 'Message 1');
      logger.warning('Tag2', 'Message 2');

      final exported = logger.exportLogs();
      expect(exported, isNotEmpty);
      expect(exported, contains('Tag1'));
      expect(exported, contains('Tag2'));
    });

    test('calls log callback', () {
      var callCount = 0;
      logger.setOnLogCallback((_) => callCount++);

      logger.info('Tag', 'Message');
      expect(callCount, 1);

      logger.warning('Tag', 'Message');
      expect(callCount, 2);
    });

    test('log entry tostring includes all data', () {
      final error = Exception('Test');
      logger.error('MyTag', 'My message', error);

      final history = logger.getHistory();
      final logEntry = history.last;
      final logString = logEntry.toString();

      expect(logString, contains('ERROR'));
      expect(logString, contains('MyTag'));
      expect(logString, contains('My message'));
    });
  });
}

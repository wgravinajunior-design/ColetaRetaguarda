import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_retaguarda/core/performance/performance_monitor.dart';

void main() {
  group('PerformanceMonitor', () {
    late PerformanceMonitor monitor;

    setUp(() {
      monitor = PerformanceMonitor();
      monitor.clearMetrics();
      monitor.setEnabled(true);
    });

    test('is singleton', () {
      final monitor1 = PerformanceMonitor();
      final monitor2 = PerformanceMonitor();

      expect(identical(monitor1, monitor2), true);
    });

    test('records operation time', () async {
      final timer = monitor.startOperation('testOp');
      await Future.delayed(const Duration(milliseconds: 50));
      timer.complete();

      final metrics = monitor.getMetrics('testOp');
      expect(metrics, isNotNull);
      expect(metrics!.count, 1);
      expect(metrics.averageDuration.inMilliseconds, greaterThanOrEqualTo(50));
    });

    test('tracks multiple operations independently', () async {
      // Operation 1
      final timer1 = monitor.startOperation('op1');
      await Future.delayed(const Duration(milliseconds: 30));
      timer1.complete();

      // Operation 2
      final timer2 = monitor.startOperation('op2');
      await Future.delayed(const Duration(milliseconds: 60));
      timer2.complete();

      final metrics1 = monitor.getMetrics('op1');
      final metrics2 = monitor.getMetrics('op2');

      expect(metrics1!.count, 1);
      expect(metrics2!.count, 1);
      expect(metrics2.averageDuration.inMilliseconds, greaterThan(metrics1.averageDuration.inMilliseconds));
    });

    test('calculates average duration', () async {
      for (int i = 0; i < 3; i++) {
        final timer = monitor.startOperation('avg');
        await Future.delayed(const Duration(milliseconds: 30));
        timer.complete();
      }

      final metrics = monitor.getMetrics('avg');
      expect(metrics!.count, 3);
      expect(metrics.averageDuration.inMilliseconds, greaterThanOrEqualTo(30));
    });

    test('tracks min and max duration', () async {
      final timer1 = monitor.startOperation('minmax');
      await Future.delayed(const Duration(milliseconds: 10));
      timer1.complete();

      final timer2 = monitor.startOperation('minmax');
      await Future.delayed(const Duration(milliseconds: 50));
      timer2.complete();

      final metrics = monitor.getMetrics('minmax');
      expect(metrics!.minDuration.inMilliseconds, lessThan(metrics.maxDuration.inMilliseconds));
    });

    test('tracks result size', () {
      final timer = monitor.startOperation('sized');
      timer.setResultSize(1024);
      timer.complete();

      final metrics = monitor.getMetrics('sized');
      expect(metrics!.averageResultSize, 1024);
    });

    test('noop timer works when disabled', () {
      monitor.setEnabled(false);

      final timer = monitor.startOperation('disabled');
      final duration = timer.complete();

      expect(duration, Duration.zero);
      expect(monitor.getMetrics('disabled'), isNull);
    });

    test('generates performance report', () {
      final timer = monitor.startOperation('report_test');
      timer.complete();

      final report = monitor.generateReport();

      expect(report, contains('Performance Report'));
      expect(report, contains('report_test'));
      expect(report, contains('Count: 1'));
    });

    test('clears all metrics', () {
      final timer = monitor.startOperation('clear_test');
      timer.complete();

      expect(monitor.getAllMetrics(), isNotEmpty);

      monitor.clearMetrics();

      expect(monitor.getAllMetrics(), isEmpty);
    });

    test('returns all metrics', () {
      for (int i = 0; i < 3; i++) {
        final timer = monitor.startOperation('op$i');
        timer.complete();
      }

      final allMetrics = monitor.getAllMetrics();
      expect(allMetrics.length, 3);
    });

    test('handles slow operations', () async {
      final timer = monitor.startOperation('slow');
      await Future.delayed(const Duration(milliseconds: 600));
      timer.complete();

      final metrics = monitor.getMetrics('slow');
      expect(metrics!.averageDuration.inMilliseconds, greaterThan(500));
    });
  });
}

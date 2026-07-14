import 'package:flutter/foundation.dart';
import '../logging/app_logger.dart';

/// Monitora performance (CPU, memória, FPS, tempo de operação)
class PerformanceMonitor {
  static final PerformanceMonitor _instance = PerformanceMonitor._internal();

  factory PerformanceMonitor() {
    return _instance;
  }

  PerformanceMonitor._internal();

  final AppLogger _logger = AppLogger();
  final Map<String, OperationMetrics> _metrics = {};
  bool _enabled = kDebugMode; // Ativado em debug, pode ser configurado

  /// Habilita/desabilita monitoramento
  void setEnabled(bool enabled) {
    _enabled = enabled;
    _logger.info('PerformanceMonitor', 'Performance monitoring ${enabled ? 'enabled' : 'disabled'}');
  }

  /// Inicia medição de uma operação
  OperationTimer startOperation(String operationName) {
    if (!_enabled) return OperationTimer.noop();

    return OperationTimer(
      operationName: operationName,
      onComplete: _recordMetric,
    );
  }

  /// Registra métrica de operação
  void _recordMetric(String operationName, Duration duration, int? resultSize) {
    if (!_enabled) return;

    if (!_metrics.containsKey(operationName)) {
      _metrics[operationName] = OperationMetrics(operationName: operationName);
    }

    _metrics[operationName]!.record(duration, resultSize);

    // Log warning se operação for muito lenta
    if (duration.inMilliseconds > 500) {
      _logger.warning(
        'PerformanceMonitor',
        'Slow operation: $operationName took ${duration.inMilliseconds}ms',
      );
    }
  }

  /// Retorna métricas de uma operação
  OperationMetrics? getMetrics(String operationName) => _metrics[operationName];

  /// Retorna todas as métricas
  List<OperationMetrics> getAllMetrics() => _metrics.values.toList();

  /// Limpa histórico de métricas
  void clearMetrics() {
    _metrics.clear();
    _logger.debug('PerformanceMonitor', 'Metrics cleared');
  }

  /// Exporta relatório de performance
  String generateReport() {
    if (_metrics.isEmpty) return 'No metrics recorded';

    final buffer = StringBuffer();
    buffer.writeln('=== Performance Report ===\n');

    for (final metric in _metrics.values) {
      buffer.writeln('Operation: ${metric.operationName}');
      buffer.writeln('  Count: ${metric.count}');
      buffer.writeln('  Avg time: ${metric.averageDuration.inMilliseconds}ms');
      buffer.writeln('  Min time: ${metric.minDuration.inMilliseconds}ms');
      buffer.writeln('  Max time: ${metric.maxDuration.inMilliseconds}ms');
      if (metric.averageResultSize != null) {
        buffer.writeln('  Avg size: ${metric.averageResultSize} bytes');
      }
      buffer.writeln();
    }

    return buffer.toString();
  }
}

/// Cronômetro para medir operações
class OperationTimer {
  final String operationName;
  final Function(String, Duration, int?)? onComplete;
  final DateTime startTime;
  int? resultSize;
  bool _completed = false;

  OperationTimer({
    required this.operationName,
    this.onComplete,
  }) : startTime = DateTime.now();

  /// Noop timer para quando monitoramento está desativado
  factory OperationTimer.noop() {
    return OperationTimer(
      operationName: '_noop',
      onComplete: null,
    );
  }

  /// Marca tamanho do resultado (opcional)
  void setResultSize(int size) {
    resultSize = size;
  }

  /// Completa a medição
  Duration complete() {
    if (_completed) return Duration.zero;

    _completed = true;
    final duration = DateTime.now().difference(startTime);

    if (onComplete != null) {
      onComplete!(operationName, duration, resultSize);
    }

    return duration;
  }
}

/// Métricas de uma operação
class OperationMetrics {
  final String operationName;
  final List<Duration> durations = [];
  final List<int?> resultSizes = [];

  OperationMetrics({required this.operationName});

  void record(Duration duration, int? resultSize) {
    durations.add(duration);
    if (resultSize != null) {
      resultSizes.add(resultSize);
    }
  }

  int get count => durations.length;

  Duration get averageDuration {
    if (durations.isEmpty) return Duration.zero;
    final total = durations.fold<int>(0, (sum, d) => sum + d.inMilliseconds);
    return Duration(milliseconds: total ~/ durations.length);
  }

  Duration get minDuration {
    if (durations.isEmpty) return Duration.zero;
    return durations.reduce((a, b) => a.compareTo(b) < 0 ? a : b);
  }

  Duration get maxDuration {
    if (durations.isEmpty) return Duration.zero;
    return durations.reduce((a, b) => a.compareTo(b) > 0 ? a : b);
  }

  int? get averageResultSize {
    if (resultSizes.isEmpty) return null;
    final valid = resultSizes.whereType<int>().toList();
    if (valid.isEmpty) return null;
    final total = valid.fold<int>(0, (sum, s) => sum + s);
    return total ~/ valid.length;
  }
}

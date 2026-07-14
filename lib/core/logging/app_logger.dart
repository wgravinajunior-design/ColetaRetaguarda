import 'package:flutter/foundation.dart';

/// Níveis de log
enum LogLevel {
  debug,   // Informações de debug
  info,    // Informações gerais
  warning, // Avisos
  error,   // Erros
  fatal,   // Erros críticos
}

/// Logger centralizado para a aplicação
class AppLogger {
  static final AppLogger _instance = AppLogger._internal();

  factory AppLogger() {
    return _instance;
  }

  AppLogger._internal();

  final List<LogEntry> _history = [];
  final int _maxHistorySize = 1000;
  Function(LogEntry)? _onLog;

  /// Registra callback para novos logs (ex: enviar para Sentry)
  void setOnLogCallback(Function(LogEntry) callback) {
    _onLog = callback;
  }

  /// Log de debug (apenas em debug mode)
  void debug(String tag, String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      _log(LogLevel.debug, tag, message, error, stackTrace);
    }
  }

  /// Log de informação
  void info(String tag, String message) {
    _log(LogLevel.info, tag, message);
  }

  /// Log de aviso
  void warning(String tag, String message, [Object? error]) {
    _log(LogLevel.warning, tag, message, error);
  }

  /// Log de erro
  void error(String tag, String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.error, tag, message, error, stackTrace);
  }

  /// Log de erro crítico (não impede execução, mas registra)
  void fatal(String tag, String message, Object error, StackTrace stackTrace) {
    _log(LogLevel.fatal, tag, message, error, stackTrace);
  }

  void _log(
    LogLevel level,
    String tag,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      tag: tag,
      message: message,
      error: error,
      stackTrace: stackTrace,
    );

    _history.add(entry);

    // Manter limite de histórico
    if (_history.length > _maxHistorySize) {
      _history.removeAt(0);
    }

    // Imprimir no console
    debugPrint(entry.toString());

    // Chamar callback (ex: enviar para analytics/crash reporting)
    _onLog?.call(entry);
  }

  /// Retorna histórico de logs
  List<LogEntry> getHistory({LogLevel? minLevel}) {
    if (minLevel == null) return List.from(_history);

    return _history.where((e) => e.level.index >= minLevel.index).toList();
  }

  /// Limpa histórico
  void clearHistory() {
    _history.clear();
  }

  /// Exporta logs para análise
  String exportLogs({LogLevel? minLevel}) {
    final entries = getHistory(minLevel: minLevel);
    return entries.map((e) => e.toString()).join('\n');
  }
}

/// Entrada de log
class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String tag;
  final String message;
  final Object? error;
  final StackTrace? stackTrace;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
    this.error,
    this.stackTrace,
  });

  @override
  String toString() {
    final time = timestamp.toString().split('.')[0];
    final levelStr = level.name.toUpperCase().padRight(7);
    final errorStr = error != null ? '\n  Error: $error' : '';
    final stackStr = stackTrace != null ? '\n  Stack: ${stackTrace.toString().split('\n').first}' : '';

    return '[$time] $levelStr [$tag] $message$errorStr$stackStr';
  }
}

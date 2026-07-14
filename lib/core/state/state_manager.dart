import 'package:flutter/foundation.dart';
import 'app_state.dart';
import '../logging/app_logger.dart';

/// Gerencia múltiplos estados de operação
class StateManager extends ChangeNotifier {
  static final StateManager _instance = StateManager._internal();

  factory StateManager() => _instance;

  StateManager._internal();

  final AppLogger _logger = AppLogger();
  final Map<String, AppState> _states = {};

  /// Obtém estado de uma operação
  AppState? getState(String key) => _states[key];

  /// Obtém estado com tipo genérico
  AppState<T>? getTypedState<T>(String key) {
    final state = _states[key];
    if (state != null && state is AppState<T>) {
      return state;
    }
    return null;
  }

  /// Define estado como loading
  void setLoading(String key, {String? message}) {
    _states[key] = AppState.loading(message: message);
    _logger.debug('StateManager', 'set $key to LOADING');
    notifyListeners();
  }

  /// Define estado como sucesso
  void setSuccess<T>(String key, T data, {String? message}) {
    _states[key] = AppState.success(data, message: message);
    _logger.debug('StateManager', 'set $key to SUCCESS');
    notifyListeners();
  }

  /// Define estado como erro
  void setError(String key, String error) {
    _states[key] = AppState.error(error);
    _logger.debug('StateManager', 'set $key to ERROR: $error');
    notifyListeners();
  }

  /// Define estado como vazio
  void setEmpty(String key, {String? message}) {
    _states[key] = AppState.empty(message: message);
    _logger.debug('StateManager', 'set $key to EMPTY');
    notifyListeners();
  }

  /// Define estado como idle
  void setIdle(String key) {
    _states[key] = AppState.idle();
    _logger.debug('StateManager', 'set $key to IDLE');
    notifyListeners();
  }

  /// Reseta estado
  void reset(String key) {
    _states.remove(key);
    _logger.debug('StateManager', 'reset $key');
    notifyListeners();
  }

  /// Reseta todos os estados
  void resetAll() {
    _states.clear();
    _logger.debug('StateManager', 'reset all states');
    notifyListeners();
  }

  /// Executa operação assíncrona com gerenciamento de estado
  Future<T> executeAsync<T>(
    String key,
    Future<T> Function() operation, {
    String? loadingMessage,
    String Function(Object error)? errorMapper,
  }) async {
    setLoading(key, message: loadingMessage);

    try {
      final result = await operation();
      setSuccess(key, result);
      return result;
    } catch (e) {
      final errorMsg = errorMapper?.call(e) ?? e.toString();
      setError(key, errorMsg);
      rethrow;
    }
  }

  /// Obtém múltiplos estados
  Map<String, AppState> getStates(List<String> keys) {
    return {for (var key in keys) key: _states[key] ?? AppState.idle()};
  }

  /// Verifica se alguma operação está carregando
  bool anyLoading(List<String> keys) {
    return keys.any((key) => _states[key]?.isLoading ?? false);
  }

  /// Verifica se alguma operação tem erro
  bool anyError(List<String> keys) {
    return keys.any((key) => _states[key]?.isError ?? false);
  }

  /// Obtém todos os erros
  Map<String, String> getErrors(List<String> keys) {
    final errors = <String, String>{};
    for (final key in keys) {
      final state = _states[key];
      if (state?.isError ?? false) {
        errors[key] = state!.error ?? 'Unknown error';
      }
    }
    return errors;
  }

  /// Retorna estatísticas dos estados
  Map<String, dynamic> getStats() {
    int idle = 0, loading = 0, success = 0, error = 0, empty = 0;

    for (final state in _states.values) {
      switch (state.status) {
        case AppStateStatus.idle:
          idle++;
          break;
        case AppStateStatus.loading:
          loading++;
          break;
        case AppStateStatus.success:
          success++;
          break;
        case AppStateStatus.error:
          error++;
          break;
        case AppStateStatus.empty:
          empty++;
          break;
      }
    }

    return {
      'total': _states.length,
      'idle': idle,
      'loading': loading,
      'success': success,
      'error': error,
      'empty': empty,
    };
  }

  @override
  void dispose() {
    _states.clear();
    _logger.info('StateManager', 'Disposed');
    super.dispose();
  }
}

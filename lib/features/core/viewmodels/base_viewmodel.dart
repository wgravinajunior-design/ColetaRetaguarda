import 'package:flutter/foundation.dart';
import '../../../core/state/state_manager.dart';
import '../../../core/cache/cache_manager.dart';
import '../../../core/logging/app_logger.dart';

// Importar a extensão para usar cacheKey(), apiGetCacheKey(), etc
extension CacheKeyHelpers on String {
  String cacheKey(String suffix) => '$this:$suffix';
  String apiGetCacheKey() => 'api:get:$this';
  String listCacheKey() => 'list:$this';
  String detailsCacheKey() => 'detail:$this';
}

enum ViewModelState { idle, loading, success, error }

abstract class BaseViewModel<T> extends ChangeNotifier {
  ViewModelState _state = ViewModelState.idle;
  String? _errorMessage;
  List<T> _items = [];

  final StateManager _stateManager = StateManager();
  final CacheManager cacheManager = CacheManager();
  final AppLogger _logger = AppLogger();

  // Getters protegidos para subclasses
  StateManager get stateManager => _stateManager;
  AppLogger get logger => _logger;

  ViewModelState get state => _state;
  String? get errorMessage => _errorMessage;
  List<T> get items => _items;
  bool get isLoading => _state == ViewModelState.loading;
  bool get isError => _state == ViewModelState.error;

  void _setState(ViewModelState state, {String? error}) {
    _state = state;
    _errorMessage = error;
    notifyListeners();
  }

  void setLoading() => _setState(ViewModelState.loading);
  void setSuccess() => _setState(ViewModelState.success);
  void setIdle() => _setState(ViewModelState.idle);
  void setError(String message) => _setState(ViewModelState.error, error: message);

  void setItems(List<T> items) {
    _items = items;
    _setState(ViewModelState.success);
  }

  void clearError() => _errorMessage = null;

  /// Obtém chave única para este ViewModel
  String get stateKey => runtimeType.toString();

  /// Usa StateManager para operação assíncrona com cache
  Future<T?> executeWithCache<R>(
    String cacheKey,
    Future<R> Function() operation,
    T Function(R) transform, {
    Duration? cacheTtl,
  }) async {
    try {
      // Tenta cache primeiro
      final cached = cacheManager.get<R>(cacheKey);
      if (cached != null) {
        _logger.debug(runtimeType.toString(), 'Cache HIT: $cacheKey');
        return transform(cached);
      }

      setLoading();
      final result = await operation();
      cacheManager.put(cacheKey, result, ttl: cacheTtl);
      final transformed = transform(result);
      setSuccess();
      return transformed;
    } catch (e) {
      final message = e.toString();
      setError(message);
      _logger.error(runtimeType.toString(), 'Error: $message');
      return null;
    }
  }

  /// Usa StateManager para operação assíncrona simples
  Future<T?> executeAsync<R>(
    Future<R> Function() operation,
    T Function(R) transform,
  ) async {
    try {
      setLoading();
      final result = await operation();
      final transformed = transform(result);
      setSuccess();
      return transformed;
    } catch (e) {
      final message = e.toString();
      setError(message);
      _logger.error(runtimeType.toString(), 'Error: $message');
      return null;
    }
  }
}
